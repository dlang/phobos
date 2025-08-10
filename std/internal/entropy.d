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
import std.traits;
import std.typecons;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

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

/+
    Building blocks
 +/
private
{
    /++
        A “Chunks” implementation that works with `void[]`.
     +/
    struct VoidChunks()
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

/++
    Entropy Source implementations
 +/
private struct Implementation
{
static:

    version (all)
    @(EntropySourceID.none)
    struct None
    {
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

    version (Posix)
    template CharDevImpl(EntropySourceID id, string path)
    {
        @id
        struct CharDev
        {
            import core.stdc.stdio : FILE, fclose, fopen, fread;
            import core.sys.posix.unistd;

            private
            {
                enum string _path = path ~ "\0";
                FILE* _file = null;
            }

        @nogc nothrow @safe:

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
    }

    version (Posix)
    alias CharDevURandom = CharDevImpl!(EntropySourceID.charDevURandom, "/dev/urandom").CharDev;

    version (Posix)
    alias CharDevRandom = CharDevImpl!(EntropySourceID.charDevRandom, "/dev/random").CharDev;

    version (linux)
    @(EntropySourceID.getrandom)
    struct Getrandom
    {
    @nogc nothrow @safe:

        EntropyStatus open() scope
        {
            return (testAvailability())
                ? EntropyStatus.ok
                : EntropyStatus.unavailable;
        }

        private bool testAvailability() scope @trusted
        {
            import core.sys.linux.errno : ENOSYS, errno;

            const got = syscallGetrandom(null, 0, 0);
            if (got == -1)
                if (errno == ENOSYS)
                    return false;

            return true;
        }

        void close() scope
        {
            // no-op
        }

        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            return syscallGetrandomLoop(buffer, 0);
        }

        private static auto syscallGetrandom(scope void* buf, size_t buflen, uint flags) @system
        {
            import core.sys.linux.sys.syscall : SYS_getrandom;
            import core.sys.linux.unistd : syscall;

            return syscall(SYS_getrandom, buf, buflen, flags);
        }

        private static EntropyStatus syscallGetrandomLoop(scope void[] buffer, uint flags) @system
        {
            import core.sys.linux.errno : EINTR, ENOSYS, errno;

            while (buffer.length > 0)
            {
                const got = syscallGetrandom(buffer.ptr, buffer.length, flags);

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
    @(EntropySourceID.arc4random)
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
    @(EntropySourceID.getentropy)
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
            foreach (chunk; VoidChunks!()(buffer, 256))
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
    @(EntropySourceID.bcryptGenRandom)
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
            if (!_hBcrypt)
                return EntropyStatus.unavailableLibrary;

            _ptrBCryptGenRandom = cast(typeof(_ptrBCryptGenRandom)) GetProcAddress(_hBcrypt, "BCryptGenRandom");
            if (!_ptrBCryptGenRandom)
                return EntropyStatus.unavailable;

            return EntropyStatus.ok;
        }

        void close() scope @trusted
        {
            import core.sys.windows.winbase : FreeLibrary;

            if (_hBcrypt is null)
                return;

            if (!FreeLibrary(_hBcrypt))
                return; // Error

            _hBcrypt = null;
            _ptrBCryptGenRandom = null;
        }

        EntropyStatus getEntropy(scope void[] buffer) scope @trusted
        {
            foreach (chunk; VoidChunks!()(buffer, ULONG.max))
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

// idOf!(T) and friends
private
{
    enum hasValidEntropySourceID(T) = (getUDAs!(T, EntropySourceID).length == 1);

    template idOf(EntropySource)
    if (hasValidEntropySourceID!EntropySource)
    {
        enum idOf = getUDAs!(EntropySource, EntropySourceID)[0];
    }

    @safe unittest
    {
        static assert(idOf!(Implementation.None) == EntropySourceID.none);
        version (Posix)
        {
            static assert(idOf!(Implementation.CharDevRandom) == EntropySourceID.charDevRandom);
            static assert(idOf!(Implementation.CharDevURandom) == EntropySourceID.charDevURandom);
        }
    }
}

// Constraints for `multiSourceImpl`
private
{
    enum isNoneImplementation(T) = is(T == Implementation.None);
    enum isNotNoneImplementation(T) = !isNoneImplementation!(T);
    enum hasValidConfigurableID(T) = (
        hasValidEntropySourceID!(T)
        && (idOf!(T) != EntropySourceID.none)
        && (idOf!(T) != EntropySourceID.tryAll)
    );
}

/++
    Multi-source implementation code

    `SupportedSources` to be provided sorted by priority in descending order.
 +/
private mixin template multiSourceImpl(SupportedSources...)
if (
    is(SupportedSources == NoDuplicates!SupportedSources)
    && allSatisfy!(isNotNoneImplementation, SupportedSources)
    && allSatisfy!(hasValidConfigurableID, SupportedSources)
)
{
    private alias AllSupportedSources = AliasSeq!(SupportedSources, Implementation.None);
    private alias DefaultSource = AllSupportedSources[0];

    private enum isSupportedSource(T) = (staticIndexOf!(T, AllSupportedSources) >= 0);

    private struct AutoClosed(TSubject)
    {
        TSubject subject;

        @disable this();
        @disable this(this);

        this(TSubject subject) @nogc nothrow pure @safe
        {
            this.subject = subject;
        }

        ~this() scope @safe
        {
            subject.close();
        }
    }

    private alias AutoClosedSources = staticMap!(AutoClosed, AllSupportedSources);
    private alias AutoClosedHandle = SumType!(AutoClosedSources);
    private alias RefCountedHandle = SafeRefCounted!(AutoClosedHandle, RefCountedAutoInitialize.no);

    /++
        Handle to an opened entropy source

        Depending on the underlying implementation, this handle might only be a dummy.
        Some implementations build upon handles themselves,
        hence this generic wrapper has to provide support for doing so.
     +/
    struct EntropySourceHandle
    {
        private
        {
            RefCountedHandle handle;
        }

        private this(RefCountedHandle handle) @nogc nothrow @safe
        {
            this.handle = handle;
        }

        private static typeof(this) pack(EntropySource)(EntropySource source) @safe
        {
            return EntropySourceHandle(
                safeRefCounted(AutoClosedHandle(AutoClosed!EntropySource(source)))
            );
        }

        public @nogc nothrow @safe
        {
            /++
                Retrieves random data from the corresponding system CSPRNG.

                Params:
                    buffer = An output buffer to store the retrieved entropy in.
                            The length of it will determine the amount of random data to
                            be obtained.

                            This function always attempts to fill the entire buffer.
                            Therefore, it can block, spin or report an error.

                Returns:
                    An `EntropyStatus` that either reports success
                    or the type of error that has occurred.

                    In case of an error, the data in `buffer` MUST NOT be used.
             +/
            EntropyStatus getEntropy(scope void[] buffer)
            {
                return handle.borrow!((ref scope borrowed)
                    => borrowed.match!((ref scope matched)
                        => matched.subject.getEntropy(buffer)
                    )
                );
            }

            /++
                Retrieves a suitable error message to the provided status code.

                The exact error messages are determined by the underlying
                implementation.
             +/
            string getErrorMessage(EntropyStatus status) const
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

                if (status == EntropyStatus.ok)
                    return null;

                const specificErrorMessage = handle.borrow!((ref scope borrowed)
                    => borrowed.match!((ref scope matched)
                        => matched.subject.getErrorMessage(status)
                    )
                );

                return (specificErrorMessage is null)
                    ? genericErrorMessage(status)
                    : specificErrorMessage;
            }
        }
    }

    ///
    enum EntropySourceID defaultEntropySource = idOf!(DefaultSource);

    private static _entropySource = defaultEntropySource;

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

    ///
    struct EntropySourceOpenResult
    {
        private
        {
            EntropyStatus _status;
            EntropySourceHandle _handle;
        }

        public @nogc nothrow @safe
        {
            EntropyStatus status() const pure => _status;
            bool isOK() const pure => (status == EntropyStatus.ok);
            string errorMessage() const => _handle.getErrorMessage(_status);

            inout(EntropySourceHandle) handle() inout
            {
                if (!isOK)
                    assert(false, "Trying to retrieve handle after a failed opening.");

                return _handle;
            }
        }
    }

    private struct DetailedEntropySourceOpenResult
    {
        EntropySourceID sourceID;
        EntropySourceOpenResult result;

        bool isOK() const @nogc nothrow pure @safe => result.isOK;
    }

    private DetailedEntropySourceOpenResult openEntropySourceByType(EntropySource)()
    {
        auto source = EntropySource();
        const status = source.open();

        return DetailedEntropySourceOpenResult(
            idOf!(EntropySource),
            EntropySourceOpenResult(
                status,
                EntropySourceHandle.pack(source),
            )
        );
    }

    @nogc nothrow @safe
    {
        private DetailedEntropySourceOpenResult openEntropySourceTryAll()
        {
            DetailedEntropySourceOpenResult result;

            static foreach (EntropySource; SupportedSources)
            {
                result = openEntropySourceByType!EntropySource();
                if (result.isOK)
                    return result;
            }

            return openEntropySourceByType!(Implementation.None)();
        }

        private DetailedEntropySourceOpenResult openEntropySourceByID(EntropySourceID id)
        {
            if (id == EntropySourceID.tryAll)
                return openEntropySourceTryAll();

            if (id == EntropySourceID.none)
                return openEntropySourceByType!(Implementation.None)();

            static foreach (EntropySource; SupportedSources)
            {
                if (id == idOf!(EntropySource))
                    return openEntropySourceByType!EntropySource();
            }

            return DetailedEntropySourceOpenResult(
                id,
                EntropySourceOpenResult(EntropyStatus.unavailablePlatform)
            );
        }

        /++
            Opens a handle to the requested system CSPRNG.

            In general, it’s a $(B bad idea) to let users pick sources themselves.
            A sane option should be used by default instead.

            This overload only exists because it is used by Phobos.
         +/
        EntropySourceOpenResult openEntropySource(EntropySourceID id)
        {
            return openEntropySourceByID(id).result;
        }

        /++
            Opens a handle to an applicable system CSPRNG.
         +/
        EntropySourceOpenResult openEntropySource()
        {
            auto result = openEntropySourceByID(_entropySource);

            // Save used entropy source for later if applicable.
            if ((_entropySource == EntropySourceID.tryAll) && result.result.isOK)
                _entropySource = result.sourceID;

            return result.result;
        }
    }
}

// Platform configurations
version (Darwin) mixin multiSourceImpl!(
    Implementation.ARC4Random,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (DragonFlyBSD) mixin multiSourceImpl!(
    Implementation.Getentropy,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (FreeBSD) mixin multiSourceImpl!(
    Implementation.Getentropy,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (linux) mixin multiSourceImpl!(
    Implementation.Getrandom,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (NetBSD) mixin multiSourceImpl!(
    Implementation.ARC4Random,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (OpenBSD) mixin multiSourceImpl!(
    Implementation.ARC4Random,
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (Posix) mixin multiSourceImpl!(
    Implementation.CharDevURandom,
    Implementation.CharDevRandom,
);
else version (Windows) mixin multiSourceImpl!(
    Implementation.BCryptGenRandom,
);
else mixin multiSourceImpl!(
);

// One-shot functions
private @nogc nothrow @safe
{
    EntropyStatus getEntropy(scope void[] buffer)
    {
        auto opened = openEntropySource();
        if (!opened.isOK)
            return opened.status;

        return opened.handle.getEntropy(buffer);
    }

    EntropyStatus getEntropy(scope ubyte[] buffer)
    {
        return getEntropy(cast(void[]) buffer);
    }

    EntropyStatus getEntropy(scope void* ptr, size_t length) @system
    {
        return getEntropy(ptr[0 .. length]);
    }
}

// getEntropy() or crash:
// If the system let us down, we'll let the system down.
package(std) @nogc nothrow @safe
{
    void getEntropyOrCrash(scope void[] buffer)
    {
        auto opened = openEntropySource(EntropySourceID.tryAll);
        if (!opened.isOK)
            assert(false, opened.errorMessage);

        auto handle = opened.handle;
        const status = handle.getEntropy(buffer);
        if (status != EntropyStatus.ok)
            assert(false, handle.getErrorMessage(status));
    }

    void getEntropyOrCrash(scope void* ptr, size_t length) @system
    {
        return getEntropyOrCrash(ptr[0 .. length]);
    }
}

// Self-test: Detect potentially unsuitable default entropy source.
@safe unittest
{
    static bool isUnavailable(EntropyStatus status)
    {
        return (
            status == EntropyStatus.unavailable ||
            status == EntropyStatus.unavailableLibrary ||
            status == EntropyStatus.unavailablePlatform
        );
    }

    auto buffer = new ubyte[](32);
    forceEntropySource(defaultEntropySource);
    const status = getEntropy(buffer);

    assert(
        !isUnavailable(status),
        "The default entropy source for the target platform"
        ~ " is unavailable on this machine. Please consider"
        ~ " patching it to accommodate to your environment."
    );
    assert(status == EntropyStatus.ok);
}

// Self-test: Detect faulty implementation.
@system unittest
{
    forceEntropySource(defaultEntropySource);

    bool test() @system
    {
        static immutable pattern = 0xDEAD_BEEF_1337_0000;
        long number = pattern;
        const status = getEntropy(&number, number.sizeof);
        assert(status == EntropyStatus.ok);
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

        const status = getEntropy(data[]);
        assert(status == EntropyStatus.ok);

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
