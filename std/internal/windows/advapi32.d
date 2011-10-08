// Written in the D programming language.

/**
 * The only purpose of this module is to do the static construction for
 * std.windows.registry, to eliminate cyclic construction errors.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Kenji Hara
 * Source:    $(PHOBOSSRC std/internal/windows/_advapi32.d)
 */
module std.internal.windows.advapi32;

version(Win32):

private import core.sys.windows.windows;

pragma(lib, "advapi32.lib");

immutable bool isWow64;

shared static this()
{
    // WOW64 is the x86 emulator that allows 32-bit Windows-based applications to run seamlessly on 64-bit Windows
    // IsWow64Process Function - Minimum supported client - Windows Vista, Windows XP with SP2
    alias extern(Windows) BOOL function(HANDLE, PBOOL) fptr_t;
    auto hKernel = GetModuleHandleA("kernel32");
    auto IsWow64Process = cast(fptr_t) GetProcAddress(hKernel, "IsWow64Process");
    BOOL bIsWow64;
    isWow64 = IsWow64Process && IsWow64Process(GetCurrentProcess(), &bIsWow64) && bIsWow64;
}

HMODULE hAdvapi32 = null;
extern (Windows)
{
    LONG function(in HKEY hkey, in LPCSTR lpSubKey, in REGSAM samDesired, in DWORD reserved) pRegDeleteKeyExA;
    LONG function(in HKEY hkey, in LPCWSTR lpSubKey, in REGSAM samDesired, in DWORD reserved) pRegDeleteKeyExW;
}

void loadAdvapi32()
{
    if (!hAdvapi32)
    {
        hAdvapi32 = LoadLibraryA("Advapi32.dll");
        if (!hAdvapi32)
            throw new Exception(`LoadLibraryA("Advapi32.dll")`);

        pRegDeleteKeyExA = cast(typeof(pRegDeleteKeyExA)) GetProcAddress(hAdvapi32 , "RegDeleteKeyExA");
        if (!pRegDeleteKeyExA)
            throw new Exception(`GetProcAddress(hAdvapi32 , "RegDeleteKeyExA")`);
        pRegDeleteKeyExW = cast(typeof(pRegDeleteKeyExW)) GetProcAddress(hAdvapi32 , "RegDeleteKeyExW");
        if (!pRegDeleteKeyExW)
            throw new Exception(`GetProcAddress(hAdvapi32 , "RegDeleteKeyExW")`);
    }
}

// It will free Advapi32.dll, which may be loaded for RegDeleteKeyEx function
private void freeAdvapi32()
{
    if (hAdvapi32)
    {
        pRegDeleteKeyExA = null;
        pRegDeleteKeyExW = null;
        hAdvapi32 = null;
        if (!FreeLibrary(hAdvapi32))
            throw new Exception(`FreeLibrary(hAdvapi32)`);
    }
}

static ~this()
{
    freeAdvapi32();
}
