// Written in the D programming language.

/+
    CSPRNG library prototype.

    This code has not been audited.
    Do not use for cryptographic purposes.

    The terms $(I entropy) and $(I entropy sources) here do refer to
    cryptographically-safe random numbers and higher-level generators of such
    — typically powered by an entropy pool provided by the operating system.

    An example of similar usage of said terminology would be the `getentropy()`
    function provided by
    $(LINK2 https://man.freebsd.org/cgi/man.cgi?query=getentropy&apropos=0&sektion=3&manpath=FreeBSD+14.2-RELEASE&arch=default&format=html,
    FreeBSD).

    This library does not interact with any actual low-level entropy sources
    by itself. Instead it interfaces with system-provided CSPRNGs that are
    typically seeded through aforementioned entropy sources by the operating
    system as needed.

    See_also:
        $(LINK https://blog.cr.yp.to/20140205-entropy.html),
        $(LINK https://cr.yp.to/talks/2014.10.18/slides-djb-20141018-a4.pdf)

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy.d)
 +/
module std.internal.entropy;

import std.meta;
import std.sumtype;
import std.typecons;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin) mixin entropyImpl!(
    EntropySource.arc4random,
    Implementation.ARC4Random,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (DragonFlyBSD) mixin entropyImpl!(
    EntropySourceID.getentropy,
    Implementation.Getentropy,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (FreeBSD) mixin entropyImpl!(
    EntropySourceID.getentropy,
    Implementation.Getentropy,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (linux) mixin entropyImpl!(
    EntropySourceID.getrandom,
    Implementation.Getrandom,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (NetBSD) mixin entropyImpl!(
    EntropySourceID.arc4random,
    Implementation.ARC4Random,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (OpenBSD) mixin entropyImpl!(
    EntropySourceID.arc4random,
    Implementation.ARC4Random,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (Posix) mixin entropyImpl!(
    EntropySourceID.charDevURandom,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (Windows) mixin entropyImpl!(
    EntropySourceID.bcryptGenRandom,
    Implementation.BCryptGenRandom,
);
else mixin entropyImpl!(
    EntropySourceID.none,
);

/+
    Building blocks and implementation helpers
 +/
private
{
    /++
        A “Chunks” implementation that works with `void[]`.
     +/
    struct VoidChunks
    {
        void[] _data;
        size_t _chunkSize;

    @nogc nothrow pure @safe:

        this(void[] data, size_t chunkSize)
        {
            _data = data;
            _chunkSize = chunkSize;
        }

        bool empty() const
        {
            return _data.length == 0;
        }

        inout(void)[] front() inout
        {
            if (_data.length < _chunkSize)
                return _data;

            return _data[0 .. _chunkSize];
        }

        void popFront()
        {
            if (_data.length <= _chunkSize)
            {
                _data = null;
                return;
            }

            _data = _data[_chunkSize .. $];
        }
    }

    template isValidSupportedSource(alias SupportedSource)
    {
        enum isValidSupportedSource = (
            is(SupportedSource == struct) &&
            is(typeof(SupportedSource.id) == EntropySourceID) &&
            SupportedSource.id != EntropySourceID.tryAll &&
            SupportedSource.id != EntropySourceID.none
        );
    }

    /++
        `getEntropyImpl()` implementation helper.
        To be instantiated and mixed in with platform-specific configuration.

        Params:
            defaultSource = Default entropy source of the platform
            SupportedSources = Sequence of `SrcFunPair`
                               representing the supported sources of the platform
    +/
    mixin template entropyImpl(EntropySourceID defaultSource, SupportedSources...)
    if (allSatisfy!(isValidSupportedSource, SupportedSources))
    {
    private:
        /// Preconfigured entropy source preset of the platform.
        enum defaultEntropySource = defaultSource;

        alias _InnerEntropySourceHandle = SumType!(
            Implementation.None,
            SupportedSources,
        );

    @nogc nothrow @safe:

        EntropyStatus _openEntropySourceImpl(out EntropySourceHandle.Inner handle) @safe
        {
            switch (_entropySource)
            {
                static foreach (Source; SupportedSources)
                {{
                    case Source.id:
                        auto  source = Source();
                        const status = source.open();
                        () @trusted { handle = EntropySourceHandle.Inner(source); }();
                        return status;
                }}

                case EntropySourceID.tryAll:
                {
                    const status = _tryOpenEntropySources(handle);
                    handle.saveSourceForNextUse();
                    return status;
                }

                case EntropySourceID.none:
                    auto none = Implementation.None();
                    () @trusted { handle = EntropySourceHandle.Inner(none); }();
                    return none.open();

                default:
                    return EntropyStatus.unavailablePlatform;
            }
        }

        EntropyStatus openEntropySourceImpl(out EntropySourceHandle.InnerRefCounted handle) @safe
        {
            EntropySourceHandle.Inner innerHandle;
            const status = _openEntropySourceImpl(innerHandle);
            handle = safeRefCounted(innerHandle);

            return status;
        }

        EntropyStatus _tryOpenEntropySources(out EntropySourceHandle.Inner handle) @safe
        {
            static foreach (Source; SupportedSources)
            {{
                auto  source = Source();
                const status = source.open();
                if (status == EntropyStatus.ok)
                {
                    () @trusted { handle = EntropySourceHandle.Inner(source); }();
                    return status;
                }
            }}

            auto fallback = Implementation.None();
            () @trusted { handle = EntropySourceHandle.Inner(fallback); }();
            return fallback.open();
        }
    }

    auto matchCall(string methodName, Args...)(ref scope EntropySourceHandle.Inner source, Args args) @nogc @safe
    {
        import std.array : join;
        import std.string : chomp;

        enum methodCall = (args.length == 0)
            ? `matched.` ~ methodName
            : `matched.` ~ methodName ~ `(args)`;
        enum handler(T) = `(ref scope `
            ~ __traits(fullyQualifiedName, T)
                .chomp(".CharDev") /+ quick'n'dirty workaround +/
            ~ ` matched) @safe => ` ~ methodCall;
        enum handlers = `AliasSeq!(` ~ [staticMap!(handler, EntropySourceHandle.Inner.Types)].join(",\n") ~ `)`;

        return source.match!(mixin(handlers));
    }

    auto borrowMatchCall(string methodName, Args...)(EntropySourceHandle.InnerRefCounted source, Args args) @nogc @safe
    {
        return source.borrow!((EntropySourceHandle.Inner borrowed) => matchCall!methodName(borrowed, args));
    }
}

// Self-test: Detect potentially unsuitable default entropy source.
@safe unittest
{
    auto buffer = new ubyte[](32);
    forceEntropySource(defaultEntropySource);
    const result = getEntropy(buffer);

    assert(
        !result.isUnavailable,
        "The default entropy source for the target platform"
        ~ " is unavailable on this machine. Please consider"
        ~ " patching it to accommodate to your environment."
    );
    assert(result.isOK);
}

// Self-test: Detect faulty implementation.
@system unittest
{
    forceEntropySource(defaultEntropySource);

    bool test() @system
    {
        static immutable pattern = 0xDEAD_BEEF_1337_0000;
        long number = pattern;
        const result = getEntropy(&number, number.sizeof);
        assert(result.isOK);
        return number != pattern;
    }

    size_t timesFailed = 0;
    foreach (n; 0 .. 3)
        if (!test())
            ++timesFailed;

    assert(
        timesFailed <= 1,
        "Suspicious random data: Potential security issue or really unlucky; please retry."
    );
}

// Self-test: Detect faulty implementation.
@safe unittest
{
    forceEntropySource(defaultEntropySource);

    bool test() @safe
    {
        ubyte[32] data;
        data[] = 0;

        const result = getEntropy(data[]);
        assert(result.isOK);

        size_t zeros = 0;
        foreach (b; data)
            if (b == 0)
                ++zeros;

        enum threshold = 24;
        return zeros < threshold;
    }

    size_t timesFailed = 0;
    foreach (n; 0 .. 3)
        if (!test())
            ++timesFailed;

    assert(
        timesFailed <= 1,
        "Suspicious random data: Potential security issue or really unlucky; please retry."
    );
}

@nogc nothrow:

// Flagship function
/++
    Opens a handle to an applicable system CSPRNG.
 +/
EntropyStatus openEntropySource(out EntropySourceHandle handle) @safe
{
    EntropySourceHandle.InnerRefCounted innerHandle;
    const status = openEntropySourceImpl(innerHandle);
    handle = EntropySourceHandle(innerHandle);
    return status;
}

// Flagship function
EntropyStatus getEntropy(EntropySourceHandle source, scope void[] buffer) @safe
{
    return source.handle.borrowMatchCall!"getEntropy"(buffer);
}

string getErrorMessage(EntropySourceHandle source, EntropyStatus status) @safe
{
    static string genericErrorMessage(EntropyStatus status)
    {
        if (status == EntropyStatus.unavailable ||
            status == EntropyStatus.unavailableLibrary)
            return "getEntropy(): An entropy source was unavailable.";
        if (status == EntropyStatus.unavailablePlatform)
            return "getEntropy(): The requested entropy source is not supported on this platform.";
        if (status == EntropyStatus.readError)
            return "getEntropy(): Could not retrieve entropy from the selected source.";

        return "getEntropy(): An unknown error occurred.";
    }

    const msg = source.handle.borrowMatchCall!"getErrorMessage"(status);
    if (msg is null)
        return genericErrorMessage(status);

    return msg;
}

EntropySourceID id(EntropySourceHandle source) @safe
{
    return source.handle.borrowMatchCall!"id"();
}

private EntropySourceID id(EntropySourceHandle.Inner source) @safe
{
    return source.matchCall!"id"();
}

// Legacy flagship function
/++
    Retrieves random data from an applicable system CSPRNG.

    Params:
        buffer = An output buffer to store the retrieved entropy in.
                 The length of it will determine the amount of random data to
                 be obtained.

                 This function (and all overloads) always attempt to fill
                 the entire buffer. Therefore, they can block, spin or report
                 an error.

    Returns:
        An `EntropyResult` that either reports success
        or the type of error that has occurred.

        In case of an error, the data in `buffer` MUST NOT be used.
        The recommended way to check for success is through the `isOK()`
        helper function.
 +/
EntropyResult getEntropy(scope void[] buffer) @safe
{
    EntropySourceHandle handle;
    const statusOpen = openEntropySource(handle);
    if (statusOpen != EntropyStatus.ok)
        return EntropyResult(statusOpen, handle.id);

    const statusGet = handle.getEntropy(buffer);
    return EntropyResult(statusGet, handle.id);
}

///
@safe unittest
{
    int[4] bytes;
    if (getEntropy(cast(void[]) bytes).isOK)
    {
        // Success; data in `bytes` may be used.
    }

    assert((cast(void[]) bytes).length == bytes.sizeof);
}

// Convenience overload
/// ditto
EntropyResult getEntropy(scope ubyte[] buffer) @safe
{
    return getEntropy(cast(void[]) buffer);
}

///
@safe unittest
{
    ubyte[16] bytes;
    if (getEntropy(bytes).isOK)
    {
        // Success; data in `bytes` may be used.
    }
}

// Convenience wrapper
/// ditto
/++
    Retrieves random data from an applicable system CSPRNG.

    Params:
        buffer = An output buffer to store the retrieved entropy in.
        length = Length of the provided `buffer`.
                 Specifying a wrong value here, will lead to memory corruption.

    Returns:
        An `EntropyResult` that either reports success
        or the type of error that has occurred.

        In case of an error, the data in `buffer` MUST NOT be used.
        The recommended way to check for success is through the `isOK()`
        helper function.
 +/
EntropyResult getEntropy(scope void* buffer, size_t length) @system
{
    return getEntropy(buffer[0 .. length]);
}

///
@system unittest
{
    ubyte[16] bytes;
    if (getEntropy(cast(void*) bytes.ptr, bytes.length).isOK)
    {
        // Success; data in `bytes` may be used.
    }
}

///
@system unittest
{
    int number = void;
    if (getEntropy(&number, number.sizeof).isOK)
    {
        // Success; value of `number` may be used.
    }
}

/++
    Manually set the entropy source to use for the current thread.

    As a rule of thumb, this SHOULD NOT be done.

    It might be useful in cases where the default entropy source — as chosen by
    the maintainer of the used compiler package — is unavailable on a system.
    Usually, `EntropySourceID.tryAll` will be the most reasonable option
    in such cases.

    Params:
        source = The requested default entropy source to use for the current thread.

    Examples:

    ---
    // Using `forceEntropySource` almost always is a bad idea.
    // As a rule of thumb, this SHOULD NOT be done.
    forceEntropySource(EntropySourceID.none);
    ---
 +/
void forceEntropySource(EntropySourceID source) @safe
{
    _entropySource = source;
}

// (In-)Convenience wrapper
/++
    Retrieves random data from the requested entropy source.

    In general, it’s a $(B bad idea) to let users pick sources themselves.
    A sane option should be used by default instead.

    This overload only exists because its used by Phobos.

    See_also:
        Use `forceEntropySource` instead.

    Params:
        buffer = An output buffer to store the retrieved entropy in.
                 The length of it will determine the amount of entropy to be
                 obtained.
        length = Length of the provided `buffer`.
                 Specifying a wrong value here, will lead to memory corruption.
        source = The entropy source to use for the operation.

    Returns:
        An `EntropyResult` that either reports success
        or the type of error that has occurred.

        In case of an error, the data in `buffer` MUST NOT be used.
        The recommended way to check for success is through the `isOK()`
        helper function.
 +/
EntropyResult getEntropy(scope void* buffer, size_t length, EntropySourceID source) @system
{
    const sourcePrevious = _entropySource;
    scope (exit) _entropySource = sourcePrevious;

    _entropySource = source;
    return getEntropy(buffer[0 .. length]);
}

///
@system unittest
{
    ubyte[4] bytes;

    // `EntropySourceID.none` always fails.
    assert(!getEntropy(bytes.ptr, bytes.length, EntropySourceID.none).isOK);
}

/++
    A CSPRNG suitable to retrieve cryptographically-secure random data from.

    (No actual low-level entropy sources are provided on purpose.)
 +/
enum EntropySourceID
{
    /// Implements a $(I hunting) strategy for finding an entropy source that
    /// is available at runtime.
    ///
    /// Try supported sources one-by-one until one is available.
    /// This exists to enable the use of this the entropy library
    /// in a backwards compatibility way.
    ///
    /// It is recommended against using this in places that do not strictly
    /// have to to meet compatibility requirements.
    /// Like any kind of crypto-agility, this approach may suffer from
    /// practical issues.
    ///
    /// See_also:
    /// While the following article focuses on cipher agility in protocols,
    /// it elaborates why agility can lead to problems:
    /// $(LINK https://web.archive.org/web/20191102211148/https://paragonie.com/blog/2019/10/against-agility-in-cryptography-protocols)
    tryAll = -1,

    /// Always fail.
    none = 0,

    /// `/dev/urandom`
    charDevURandom = 1,

    /// `/dev/random`
    charDevRandom = 2,

    /// `getrandom` syscall or wrapper
    getrandom = 3,

    /// `arc4random`
    arc4random = 4,

    // `getentropy`
    getentropy = 5,

    /// Windows legacy CryptoAPI
    cryptGenRandom = 6,

    /// Windows Cryptography API: Next Generation (“BCrypt”)
    bcryptGenRandom = 7,
}

///
enum EntropyStatus
{
    /// catch-all error
    unknownError = 1,

    /// success
    ok = 0,

    /// An entropy source was unavailable.
    unavailable,

    /// A dependency providing the entropy source turned out unavailable.
    unavailableLibrary,

    /// The requested entropy source is not supported on this platform.
    unavailablePlatform,

    /// Could not retrieve entropy from the selected source.
    readError,
}

/++
    Status report returned by legacy `getEntropy` functions.

    Use the `isOK` helper function to test for success.
 +/
struct EntropyResult
{
    ///
    EntropyStatus status = EntropyStatus.unknownError;

    ///
    EntropySourceID source;

    /++
        Returns:
            A human-readable status message.
     +/
    string toString() const @nogc nothrow pure @safe
    {
        if (status == EntropyStatus.ok)
            return "getEntropy(): OK.";

        if (source == EntropySourceID.none)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): Error - No suitable entropy source was available.";
        }
        else if (source == EntropySourceID.getrandom)
        {
            if (status == EntropyStatus.unavailableLibrary)
                return "getEntropy(): `dlopen(\"libc\")` failed.";
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `dlsym(\"libc\", \"getrandom\")` failed.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): `getrandom()` failed.";
        }
        else if (source == EntropySourceID.getentropy)
        {
            if (status == EntropyStatus.readError)
                return "getEntropy(): `getentropy()` failed.";
        }
        else if (source == EntropySourceID.charDevURandom)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `/dev/urandom` is unavailable.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): Reading from `/dev/urandom` failed.";
        }
        else if (source == EntropySourceID.charDevURandom)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `/dev/random` is unavailable.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): Reading from `/dev/random` failed.";
        }
        else if (source == EntropySourceID.bcryptGenRandom)
        {
            if (status == EntropyStatus.unavailableLibrary)
                return "getEntropy(): `LoadLibraryA(\"Bcrypt.dll\")` failed.";
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `GetProcAddress(hBcrypt , \"BCryptGenRandom\")` failed.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): `BCryptGenRandom()` failed.";
        }

        // generic errors
        {
            if (status == EntropyStatus.unavailable ||
                status == EntropyStatus.unavailableLibrary)
                return "getEntropy(): An entropy source was unavailable.";
            if (status == EntropyStatus.unavailablePlatform)
                return "getEntropy(): The requested entropy source is not supported on this platform.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): Could not retrieve entropy from the selected source.";

            return "getEntropy(): An unknown error occurred.";
        }
    }
}

///
@safe unittest
{
    ubyte[4] data;
    EntropyResult result = getEntropy(data[]);

    if (result.isOK)
    {
        // Success; data in `bytes` may be used.
    }
    else
    {
        // Failure

        if (result.isUnavailable)
        {
            // System’s entropy source was unavailable.
        }

        // Call `toString` to obtain a user-readable error message.
        assert(result.toString() !is null);
        assert(result.toString().length > 0);
    }
}

/++
    Determines whether an `EntropyResult` reports the success of an operation.

    Params:
        value = test subject

    Returns:
        `true` on success
 +/
pragma(inline, true) bool isOK(const EntropyResult value) pure @safe
{
    return value.status == EntropyStatus.ok;
}

/++
    Determines whether an `EntropyResult` reports the unvailability of the
    requested entropy source.

    Params:
        value = test subject

    Returns:
        `true` if entropy source requested to use with the operation was unavailable.
 +/
pragma(inline, true) bool isUnavailable(const EntropyResult value) pure @safe
{
    return (
        value.status == EntropyStatus.unavailable ||
        value.status == EntropyStatus.unavailableLibrary ||
        value.status == EntropyStatus.unavailablePlatform
    );
}

package(std):

// If the system let us down, we'll let the system down.
pragma(inline, true) void crashOnError(const EntropyResult value) pure @safe
{
    if (value.isOK)
        return;

    assert(false, value.toString());
}

/++
    Depending on the underlying implementation, this handle might only be a dummy.
    Some implementations build upon handles themselves,
    hence this generic wrapper has to provide support for doing so.
 +/
struct EntropySourceHandle
{
    private
    {
        alias Inner = _InnerEntropySourceHandle;
        alias InnerRefCounted = SafeRefCounted!(
            EntropySourceHandle.Inner,
            RefCountedAutoInitialize.no
        );
    }

    private
    {
        InnerRefCounted handle;
    }

    private this(InnerRefCounted handle) @nogc nothrow pure @safe
    {
        this.handle = handle;
    }
}

private
{
    static EntropySourceID _entropySource = defaultEntropySource;

    void saveSourceForNextUse(EntropySourceHandle.Inner source) @safe
    {
        if (source.id == EntropySourceID.none)
            return;

        _entropySource = source.id;
    }
}

private struct Implementation
{
static:

    version(all)
    struct None
    {
        enum id = EntropySourceID.none;

    @nogc nothrow @safe:

        EntropyStatus open() scope
        {
            return EntropyStatus.unavailable;
        }

        void close() scope
        {
            // no-op
        }

        EntropyStatus getEntropy(scope void[]) scope
        {
            return EntropyStatus.unavailable;
        }

        static string getErrorMessage(EntropyStatus status)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): Error - No suitable entropy source was available.";

            return null;
        }
    }

    version(Posix)
    struct CharDev(EntropySourceID sourceID, string path)
    {
        import core.stdc.stdio : FILE, fclose, fopen, fread;

        private
        {
            enum string _path = path ~ "\0";
            FILE* _file = null;
        }

    @nogc nothrow @safe:

        enum id = sourceID;

        EntropyStatus open() scope @trusted
        {
            _file = fopen(_path.ptr, "r");

            if (_file is null)
                return EntropyStatus.unavailable;

            return EntropyStatus.ok;
        }

        void close() scope @trusted
        {
            if (_file is null)
                return;

            fclose(_file);
        }

        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            if (_file is null)
                return EntropyStatus.unavailable;

            const bytesRead = fread(buffer.ptr, 1, buffer.length, _file);
            if (bytesRead != buffer.length)
                return EntropyStatus.readError;

            return EntropyStatus.ok;
        }

        static string getErrorMessage(EntropyStatus status)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `" ~ path ~ "` is unavailable.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): Reading from `" ~ path ~ "` failed.";

            return null;
        }
    }

    version(Posix)
    alias CharDevURandom = CharDev!(
        EntropySourceID.charDevURandom,
        "/dev/urandom",
    );

    version(Posix)
    alias CharDevRandom = CharDev!(
        EntropySourceID.charDevRandom,
        "/dev/random",
    );

    version(linux)
    struct Getrandom
    {

        enum id = EntropySourceID.getrandom;

    @nogc nothrow @safe:

        EntropyStatus open() scope
        {
            return EntropyStatus.ok;
        }

        void close() scope
        {
            // no-op
        }

        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            return syscallGetrandom(buffer, 0);
        }

        private EntropyStatus syscallGetrandom(scope void[] buffer, uint flags) scope @system
        {
            import core.sys.linux.errno : EINTR, ENOSYS, errno;
            import core.sys.linux.sys.syscall : SYS_getrandom;
            import core.sys.linux.unistd : syscall;

            while (buffer.length > 0)
            {
                const got = syscall(SYS_getrandom, buffer.ptr, buffer.length, flags);

                if (got == -1)
                {
                    switch (errno)
                    {
                    case EINTR:
                        break; // That’s fine.
                    case ENOSYS:
                        return EntropyStatus.unavailable;
                    default:
                        return EntropyStatus.readError;
                    }
                }

                if (got > 0)
                    buffer = buffer[got .. $];
            }

            return EntropyStatus.ok;
        }

        static string getErrorMessage(EntropyStatus status)
        {
            if (status == EntropyStatus.readError)
                return "getEntropy(): `syscall(SYS_getrandom, …)` failed.";

            return null;
        }
    }

    // BSD
    version (Darwin)
        version = SecureARC4Random;
    version (DragonFlyBSD)
        version = UseGetentropy;
    version (FreeBSD)
        version = UseGetentropy;
    version (NetBSD)
        version = SecureARC4Random;
    version (OpenBSD)
        version = SecureARC4Random;

    version (SecureARC4Random)
    struct ARC4Random
    {
    @nogc nothrow @safe:

        EntropyStatus open() scope
        {
            return EntropyStatus.ok;
        }

        void close() scope
        {
            // no-op
        }

        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            arc4random_buf(buffer.ptr, buffer.length);
            return EntropyStatus.ok;
        }

        private static
        {
            extern(C) void arc4random_buf(scope void* buf, size_t nbytes) @system;
        }

        static string getErrorMessage(EntropyStatus status)
        {
            // `arc4random_buf()` will always succeed (or segfault).
            return null;
        }
    }

    version (UseGetentropy)
    struct Getentropy
    {
    @nogc nothrow @safe:

        EntropyStatus open() scope
        {
            return EntropyStatus.ok;
        }

        void close() scope
        {
            // no-op
        }

        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            /+
                genentropy(3):
                The maximum buflen permitted is 256 bytes.
            +/
            foreach (chunk; VoidChunks(buffer, 256))
            {
                const status = getentropy(buffer.ptr, buffer.length);
                if (status != 0)
                    return EntropyStatus.readError;
            }

            return EntropyStatus.ok;
        }

        private static
        {
            extern(C) int getentropy(scope void* buf, size_t buflen) @system;
        }

        static string getErrorMessage(EntropyStatus status)
        {
            if (status == EntropyStatus.readError)
                return "getEntropy(): `getentropy()` failed.";

            return null;
        }
    }

    version (Windows)
    struct BCryptGenRandom
    {
        import core.sys.windows.bcrypt : BCryptGenRandom, BCRYPT_USE_SYSTEM_PREFERRED_RNG;
        import core.sys.windows.windef : HMODULE, PUCHAR, ULONG;
        import core.sys.windows.ntdef : NT_SUCCESS;

        private
        {
            HMODULE _hBcrypt = null;
            typeof(BCryptGenRandom)* _ptrBCryptGenRandom;
        }

    @nogc nothrow @safe:

        EntropyStatus open() scope @trusted
        {
            import core.sys.windows.winbase : GetProcAddress, LoadLibraryA;

            if (_hBcrypt !is null)
                return EntropyStatus.ok;

            _hBcrypt = LoadLibraryA("bcrypt.dll");
            if (!hBcrypt)
                return EntropyStatus.unavailableLibrary;

            _ptrBCryptGenRandom = cast(typeof(_ptrBCryptGenRandom)) GetProcAddress(_hBcrypt, "BCryptGenRandom");
            if (!_ptrBCryptGenRandom)
                return EntropyStatus.unavailable;

            return EntropyStatus.ok;
        }

        void close() scope @trusted
        {
            import core.sys.windows.winbase : FreeLibrary;

            if (hBcrypt is null)
                return;

            if (!FreeLibrary(hBcrypt))
                return; // Error

            hBcrypt = null;
            ptrBCryptGenRandom = null;
        }


        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            foreach (chunk; VoidChunks(buffer, ULONG.max))
            {
                assert(chunk.length <= ULONG.max, "Bad chunk length.");

                const gotRandom = _ptrBCryptGenRandom(
                    null,
                    cast(PUCHAR) buffer.ptr,
                    cast(ULONG) buffer.length,
                    BCRYPT_USE_SYSTEM_PREFERRED_RNG,
                );

                if (!NT_SUCCESS(gotRandom))
                    return EntropyStatus.readError;
            }

            return EntropyStatus.ok;
        }

        static string getErrorMessage(EntropyStatus status)
        {
            if (status == EntropyStatus.unavailableLibrary)
                return "getEntropy(): `LoadLibraryA(\"bcrypt.dll\")` failed.";
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `GetProcAddress(hBcrypt , \"BCryptGenRandom\")` failed.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): `BCryptGenRandom()` failed.";

            return null;
        }
    }
}
