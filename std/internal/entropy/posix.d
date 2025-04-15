// Written in the D programming language.

/+
    POSIX entropy providers.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy/posix.d)
 +/
module std.internal.entropy.posix;

version (Posix):
@nogc nothrow:

import std.internal.entropy.common;

package(std.internal.entropy):

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

// dlopen() + dlsym() wrapper
version (Posix) package(std.internal.entropy)
{
    static import core.sys.posix.dlfcn;

    void* loadLibrary(const(char)* name) @system
    {
        return core.sys.posix.dlfcn.dlopen(
            name,
            core.sys.posix.dlfcn.RTLD_LAZY,
        );
    }

    alias unloadLibrary = core.sys.posix.dlfcn.dlclose;
    alias loadFunction = core.sys.posix.dlfcn.dlsym;
}

private:

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
