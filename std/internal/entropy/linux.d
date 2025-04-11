// Written in the D programming language.

/+
    Linux entropy providers.

    While the syscall was introduced in Linux 3.17 (Q4 2014) already,
    corresponding libc wrappers where added much later. The GNU C library
    only added it with the release of v2.25 (Q1 2017).

    While a few LTS distributions did backport the syscall function to even
    older kernel branches, the C library wrapper did usually not receive the
    same treatment and is still sometimes unavailable on systems in the wild.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy/linux.d)
 +/
module std.internal.entropy.linux;

version (linux):
@nogc nothrow:

import core.sys.posix.sys.types : ssize_t;
import std.internal.entropy.common;
import std.internal.entropy.posix;

package(std.internal.entropy):

EntropyResult getEntropyViaGetrandom(scope void[] buffer) @trusted
{
    const loaded = loadGetrandom();
    if (loaded != EntropyStatus.ok)
        return EntropyResult(loaded, EntropySource.getrandom);

    const status = callGetrandom(buffer);
    return EntropyResult(status, EntropySource.getrandom);
}

private:

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
