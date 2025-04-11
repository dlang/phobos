// Written in the D programming language.

/+
    Non-backend-specific functionality.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy/common.d)
 +/
module std.internal.entropy.common;

@nogc nothrow:

///
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

    /// Windows legacy
    cryptGenRandom = 6,

    /// Windows modern
    bcryptGenRandom = 7,
}

///
enum EntropyStatus
{
    ok = 0,
    unknownError = 1,
    unavailable,
    unavailableLibrary,
    unavailablePlatform,
    readError,
}

///
struct EntropyResult
{
    EntropyStatus status;
    EntropySource source;

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

///
pragma(inline, true) bool isOK(const EntropyResult value) pure @safe
{
    return value.status == EntropyStatus.ok;
}

///
pragma(inline, true) bool isUnavailable(const EntropyResult value) pure @safe
{
    return (
        value.status == EntropyStatus.unavailable ||
        value.status == EntropyStatus.unavailableLibrary ||
        value.status == EntropyStatus.unavailablePlatform
    );
}

package(std.internal.entropy):

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
