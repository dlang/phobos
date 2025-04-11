// Written in the D programming language.

/+
    Windows entropy providers.

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Elias Batek
    Source:    $(PHOBOSSRC std/internal/entropy/windows.d)
 +/
module std.internal.entropy.windows;

version (Windows):
@nogc nothrow:

import core.sys.windows.bcrypt : BCryptGenRandom, BCRYPT_USE_SYSTEM_PREFERRED_RNG;
import core.sys.windows.windef : HMODULE, PUCHAR, ULONG;
import core.sys.windows.ntdef : NT_SUCCESS;
import std.internal.entropy.common;

package(std.internal.entropy):

EntropyResult getEntropyViaBCryptGenRandom(scope void[] buffer) @trusted
{
    const loaded = loadBcrypt();
    if (loaded != EntropyStatus.ok)
        return EntropyResult(loaded, EntropySource.bcryptGenRandom);

    const status = callBcryptGenRandom(buffer);
    return EntropyResult(status, EntropySource.bcryptGenRandom);
}

private:

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
