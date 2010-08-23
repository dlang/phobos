// Written in the D programming language.

/**
 * Support COM on Windows systems.
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.windows.iunknown;

private import std.c.windows.windows;

pragma(lib, "uuid.lib");

alias int HRESULT;

enum : int
{
        S_OK = 0,
        E_NOINTERFACE = cast(int)0x80004002,
}

struct GUID {          // size is 16
    align(1):
        DWORD Data1;
        WORD   Data2;
        WORD   Data3;
        BYTE  Data4[8];
}

alias GUID IID;

extern (C)
{
    extern IID IID_IUnknown;
}

class IUnknown
{
    HRESULT QueryInterface(IID* riid, out IUnknown pvObject)
    {
        if (riid == &IID_IUnknown)
        {
            pvObject = this;
            AddRef();
            return S_OK;
        }
        else
        {   pvObject = null;
            return E_NOINTERFACE;
        }
    }

    ULONG AddRef()
    {
        return ++count;
    }

    ULONG Release()
    {
        if (--count == 0)
        {
            // free object
            return 0;
        }
        return count;
    }

    int count = 1;
}
