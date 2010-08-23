// Written in the D programming language.

/**
 * Convert Win32 error code to string.
 *
 * Copyright: Copyright Digital Mars 2006 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Credits:   Based on code written by Regan Heath
 *
 *          Copyright Digital Mars 2006 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.windows.syserror;

private import std.windows.charset;
private import std.c.windows.windows;

string sysErrorString(uint errcode)
{
    char[] result;
    char* buffer;
    DWORD r;

    r = FormatMessageA(
            FORMAT_MESSAGE_ALLOCATE_BUFFER |
            FORMAT_MESSAGE_FROM_SYSTEM |
            FORMAT_MESSAGE_IGNORE_INSERTS,
            null,
            errcode,
            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
            cast(LPTSTR)&buffer,
            0,
            null);

    /* Remove \r\n from error string */
    if (r >= 2)
        r -= 2;

    /* Create 0 terminated copy on GC heap because fromMBSz()
     * may return it.
     */
    result = new char[r + 1];
    result[0 .. r] = buffer[0 .. r];
    result[r] = 0;

    auto res = std.windows.charset.fromMBSz(cast(immutable)result.ptr);

    LocalFree(cast(HLOCAL)buffer);
    return res;
}
