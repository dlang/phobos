// Written in the D programming language.

/+
    Entropy library prototype.

    This code has not been audited.
    Do not use for cryptographic purposes.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy.d)
 +/
module std.internal.entropy.entropy;

import std.meta;

// Self-test
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

@nogc nothrow:

// Flagship function
/++
    Retrieves random data from an applicable system CSPRNG.

    Params:
        buffer = An output buffer to store the retrieved entropy in.
                 The length of it will determine the amount of entropy to be
                 obtained.

                 This functions (and all overloads) always attempts to fill
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
    return getEntropyImpl(buffer);
}

// Convenience overload
/// ditto
EntropyResult getEntropy(scope ubyte[] buffer) @safe
{
    return getEntropy(cast(void[]) buffer);
}

// Convenience wrapper
/// ditto
/++
    Retrieves random data from an applicable system CSPRNG.

    Params:
        buffer = An output buffer to store the retrieved entropy in.
        length = Length of the provided `buffer`.
                 Specifying a wrong value here, will lead to memory corruption.
 +/
EntropyResult getEntropy(scope void* buffer, size_t length) @system
{
    return getEntropy(buffer[0 .. length]);
}

/++
    Manually set the entropy source to use.

    As a rule of thumb, this SHOULD NOT be done.

    It might be useful in cases where the default entropy source chosen by
    the maintainer of the used compiler package is unavailable on a system.
    Usually, `EntropySource.tryAll` will be the most reasonable option
    in such cases.
 +/
void forceEntropySource(EntropySource source) @safe
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
 +/
EntropyResult getEntropy(scope void* buffer, size_t length, EntropySource source) @system
{
    const sourcePrevious = _entropySource;
    scope (exit) _entropySource = sourcePrevious;

    _entropySource = source;
    return getEntropy(buffer[0 .. length]);
}

/++
    A CSPRNG suitable to retrieve entropy (cryptographically-secure random data) from.
 +/
enum EntropySource
{
    /// Try supported sources one-by-one until one is available.
    /// This exists to enable the use of this the entropy library
    /// in a backwards compatibility way.
    tryAll = -1,

    /// Always fail.
    none = 0,

    /// `/dev/urandom`
    charDevURandom = 1,

    /// `/dev/random`
    charDevRandom = 2,

    /// `getrandom` syscall wrapper
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
    /// success
    ok = 0,

    /// catch-all error
    unknownError = 1,

    /// An entropy source was unavailable.
    unavailable,

    /// A dependency providing the entropy source turned out unavailable.
    unavailableLibrary,

    /// The requested entropy source is not supported on this platform.
    unavailablePlatform,

    /// Could not retrieve entropy from the selected source.
    readError,
}

///
struct EntropyResult

    {///
    EntropyStatus status;

    ///
    EntropySource source;

    ///
    string toString() const @nogc nothrow pure @safe
    {
        if (status == EntropyStatus.ok)
            return "getEntropy(): OK.";

        if (source == EntropySource.none)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): Error - No suitable entropy source was available.";
        }
        else if (source == EntropySource.getrandom)
        {
            if (status == EntropyStatus.unavailableLibrary)
                return "getEntropy(): `dlopen(\"libc\")` failed.";
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `dlsym(\"libc\", \"getrandom\")` failed.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): `getrandom()` failed.";
        }
        else if (source == EntropySource.getentropy)
        {
            if (status == EntropyStatus.readError)
                return "getEntropy(): `getentropy()` failed.";
        }
        else if (source == EntropySource.charDevURandom)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `/dev/urandom` is unavailable.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): Reading from `/dev/urandom` failed.";
        }
        else if (source == EntropySource.charDevURandom)
        {
            if (status == EntropyStatus.unavailable)
                return "getEntropy(): `/dev/random` is unavailable.";
            if (status == EntropyStatus.readError)
                return "getEntropy(): Reading from `/dev/random` failed.";
        }
        else if (source == EntropySource.bcryptGenRandom)
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

/++
    Determines whether an `EntropyResult` reports the success of an operation.
 +/
pragma(inline, true) bool isOK(const EntropyResult value) pure @safe
{
    return value.status == EntropyStatus.ok;
}

/++
    Determines whether an `EntropyResult` reports the unvailability of the
    requested entropy source.
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

    struct SrcFunPair(EntropySource source, alias func)
    {
        enum  src = source;
        alias fun = func;
    }

    template isValidSupportedSource(SupportedSource)
    {
        enum isValidSupportedSource = (
            is(SupportedSource == SrcFunPair!Args, Args...) &&
            SupportedSource.src != EntropySource.tryAll &&
            SupportedSource.src != EntropySource.none
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
    mixin template entropyImpl(EntropySource defaultSource, SupportedSources...)
    if (allSatisfy!(isValidSupportedSource, SupportedSources))
    {
    private:
        /// Preconfigured entropy source preset of the platform.
        enum defaultEntropySource = defaultSource;

        EntropyResult getEntropyImpl(scope void[] buffer) @safe
        {
            switch (_entropySource)
            {
                static foreach (source; SupportedSources)
                {
                    case source.src:
                        return source.fun(buffer);
                }

            case EntropySource.tryAll:
                {
                    const result = _tryEntropySources(buffer);
                    result.saveSourceForNextUse();
                    return result;
                }

            case EntropySource.none:
                return getEntropyViaNone(buffer);

            default:
                return EntropyResult(EntropyStatus.unavailablePlatform, _entropySource);
            }
        }

        EntropyResult _tryEntropySources(scope void[] buffer) @safe
        {
            EntropyResult result;

            static foreach (source; SupportedSources)
            {
                result = source.fun(buffer);
                if (!result.isUnavailable)
                    return result;
            }

            result = EntropyResult(
                EntropyStatus.unavailable,
                EntropySource.none,
            );

            return result;
        }
    }
}

version (Darwin) mixin entropyImpl!(
    EntropySource.arc4random,
    SrcFunPair!(EntropySource.arc4random, getEntropyViaARC4Random),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (DragonFlyBSD) mixin entropyImpl!(
    EntropySource.getentropy,
    SrcFunPair!(EntropySource.getentropy, getEntropyViaGetentropy),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (FreeBSD) mixin entropyImpl!(
    EntropySource.getentropy,
    SrcFunPair!(EntropySource.getentropy, getEntropyViaGetentropy),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (linux) mixin entropyImpl!(
    EntropySource.getrandom,
    SrcFunPair!(EntropySource.getrandom, getEntropyViaGetrandom),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (NetBSD) mixin entropyImpl!(
    EntropySource.arc4random,
    SrcFunPair!(EntropySource.arc4random, getEntropyViaARC4Random),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (OpenBSD) mixin entropyImpl!(
    EntropySource.arc4random,
    SrcFunPair!(EntropySource.arc4random, getEntropyViaARC4Random),
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (Posix) mixin entropyImpl!(
    EntropySource.charDevURandom,
    SrcFunPair!(EntropySource.charDevURandom, getEntropyViaCharDevURandom),
    SrcFunPair!(EntropySource.charDevRandom, getEntropyViaCharDevRandom),
);
else version (Windows) mixin entropyImpl!(
    EntropySource.bcryptGenRandom,
    SrcFunPair!(EntropySource.bcryptGenRandom, getEntropyViaBCryptGenRandom),
);
else mixin entropyImpl!(
    EntropySource.none,
);

private
{
    static EntropySource _entropySource = defaultEntropySource;

    void saveSourceForNextUse(const EntropyResult result) @safe
    {
        if (!result.isOK)
            return;

        _entropySource = result.source;
    }
}

version (all)
{
private:

    EntropyResult getEntropyViaNone(scope void[]) @safe
    {
        return EntropyResult(EntropyStatus.unavailable, EntropySource.none);
    }
}

// dlopen() + dlsym() wrapper
version (Posix)
{
private:

version (Posix)
{
    EntropyResult getEntropyViaCharDevURandom(scope void[] buffer) @trusted
    {
        const status = getEntropyViaCharDev(buffer, "/dev/urandom".ptr);
        return EntropyResult(status, EntropySource.charDevURandom);
    }

    EntropyResult getEntropyViaCharDevRandom(scope void[] buffer) @trusted
    {
        const status = getEntropyViaCharDev(buffer, "/dev/random".ptr);
        return EntropyResult(status, EntropySource.charDevRandom);
    }

    EntropyStatus getEntropyViaCharDev(scope void[] buffer, const(char)* charDevName) @system
    {
        import core.stdc.stdio : fclose, fopen, fread;

        auto charDev = fopen(charDevName, "r");
        if (charDev is null)
            return EntropyStatus.unavailable;

        scope (exit)
            fclose(charDev);

        const bytesRead = fread(buffer.ptr, 1, buffer.length, charDev);
        if (bytesRead != buffer.length)
            return EntropyStatus.readError;

        return EntropyStatus.ok;
    }
}

version (linux)
{
private:

    EntropyResult getEntropyViaGetrandom(scope void[] buffer) @trusted
    {
        const loaded = loadGetrandom();
        if (loaded != EntropyStatus.ok)
            return EntropyResult(loaded, EntropySource.getrandom);

        const status = callGetrandom(buffer);
        return EntropyResult(status, EntropySource.getrandom);
    }

    alias GetrandomFunction = extern(C) ssize_t function(
        void* buf,
        size_t buflen,
        uint flags,
    ) @system nothrow @nogc;

    static void* _getrandomLib = null;
    static GetrandomFunction _getrandomFun = null;

    EntropyStatus callGetrandom(scope void[] buffer) @system
    {
        /+
            getrandom(2):
            If the urandom source has been initialized, reads of up to 256
            bytes will always return as many bytes as requested and will not
            be interrupted by signals.  No such guarantees apply for larger
            buffer sizes.
        +/
        foreach (chunk; VoidChunks(buffer, 256))
        {
            const readBytes = _getrandomFun(chunk.ptr, chunk.length, 0);
            if (readBytes != chunk.length)
                return EntropyStatus.readError;
        }

        return EntropyStatus.ok;
    }

    EntropyStatus loadGetrandom() @system
    {
        static bool loadLib()
        {
            static immutable namesLibC = [
                "libc.so",
                "libc.so.6",
            ];

            foreach (name; namesLibC)
            {
                _getrandomLib = loadLibrary(name.ptr);
                if (_getrandomLib !is null)
                    return true;
            }

            return false;
        }

        static bool loadFun()
        {
            _getrandomFun = cast(GetrandomFunction) loadFunction(_getrandomLib, "getrandom");
            return (_getrandomFun !is null);
        }

        if (_getrandomFun !is null)
            return EntropyStatus.ok;

        if (_getrandomLib is null)
        {
            const libLoaded = loadLib();
            if (!libLoaded)
                return EntropyStatus.unavailableLibrary;
        }

        const funLoaded = loadFun();
        if (!funLoaded)
            return EntropyStatus.unavailable;

        return EntropyStatus.ok;
    }

    void freeGetrandom() @system
    {
        if (_getrandomLib is null)
            return;

        _getrandomFun = null;
        unloadLibrary(_getrandomLib);
        _getrandomLib = null;
    }

    static ~this() @system
    {
        freeGetrandom();
    }
}

// BSD
private
{
    version (OSX)
        version = Darwin;
    else version (iOS)
        version = Darwin;
    else version (TVOS)
        version = Darwin;
    else version (WatchOS)
        version = Darwin;

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
    {
        EntropyResult getEntropyViaARC4Random(scope void[] buffer) @trusted
        {
            arc4random_buf(buffer.ptr, buffer.length);
            return EntropyResult(EntropyStatus.ok, EntropySource.arc4random);
        }

        private extern(C) void arc4random_buf(scope void* buf, size_t nbytes) @system;
    }

    version (UseGetentropy)
    {
        EntropyResult getEntropyViaGetentropy(scope void[] buffer) @trusted
        {
            const status = callGetentropy(buffer);
            return EntropyResult(status, EntropySource.getentropy);
        }

        private EntropyStatus callGetentropy(scope void[] buffer) @system
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

        private extern(C) int getentropy(scope void* buf, size_t buflen) @system;
    }
}

version (Windows)
{
    import core.sys.windows.bcrypt : BCryptGenRandom, BCRYPT_USE_SYSTEM_PREFERRED_RNG;
    import core.sys.windows.windef : HMODULE, PUCHAR, ULONG;
    import core.sys.windows.ntdef : NT_SUCCESS;

private:

    EntropyResult getEntropyViaBCryptGenRandom(scope void[] buffer) @trusted
    {
        const loaded = loadBcrypt();
        if (loaded != EntropyStatus.ok)
            return EntropyResult(loaded, EntropySource.bcryptGenRandom);

        const status = callBcryptGenRandom(buffer);
        return EntropyResult(status, EntropySource.bcryptGenRandom);
    }

    EntropyStatus callBcryptGenRandom(scope void[] buffer) @system
    {
        foreach (chunk; VoidChunks(buffer, ULONG.max))
        {
            assert(chunk.length <= ULONG.max, "Bad chunk length.");

            const gotRandom = ptrBCryptGenRandom(
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

    static
    {
        HMODULE hBcrypt = null;
        typeof(BCryptGenRandom)* ptrBCryptGenRandom;
    }

    EntropyStatus loadBcrypt() @system
    {
        import core.sys.windows.winbase : GetProcAddress, LoadLibraryA;

        if (hBcrypt !is null)
            return EntropyStatus.ok;

        hBcrypt = LoadLibraryA("Bcrypt.dll");
        if (!hBcrypt)
            return EntropyStatus.unavailableLibrary;

        ptrBCryptGenRandom = cast(typeof(ptrBCryptGenRandom)) GetProcAddress(hBcrypt , "BCryptGenRandom");
        if (!ptrBCryptGenRandom)
            return EntropyStatus.unavailable;

        return EntropyStatus.ok;
    }

    // Will free `Bcrypt.dll`.
    void freeBcrypt() @system
    {
        import core.sys.windows.winbase : FreeLibrary;

        if (hBcrypt is null)
            return;

        if (!FreeLibrary(hBcrypt))
        {
            return; // Error
        }

        hBcrypt = null;
        ptrBCryptGenRandom = null;
    }

    static ~this() @system
    {
        freeBcrypt();
    }
}
