// Written in the D programming language.

/**
 * Convert Win32 error code to string.
 *
 * Copyright: Copyright Digital Mars 2006 - 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Credits:   Based on code written by Regan Heath
 *
 *          Copyright Digital Mars 2006 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.windows.syserror;
version (Windows):

import std.windows.charset;
import core.sys.windows.windows;

// MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT) is the user's default language
string sysErrorString(
    uint errCode,
    int langId = LANG_NEUTRAL,
    int subLangId = SUBLANG_DEFAULT) @trusted
{
    wchar* pWideMessage;

    DWORD length = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        errCode,
        MAKELANGID(langId, subLangId),
        cast(LPWSTR)&pWideMessage,
        0,
        null);

    if(length == 0)
    {
        throw new Exception(
            "failed getting error string for WinAPI error code: " ~
            sysErrorString(GetLastError()));
    }

    scope(exit) LocalFree(cast(HLOCAL)pWideMessage);

    /* Remove \r\n from error string */
    if (length >= 2)
        length -= 2;

    static int wideToNarrow(wchar[] wide, char[] narrow) nothrow
    {
        return WideCharToMultiByte(
            CP_UTF8,
            0, // No WC_COMPOSITECHECK, as system error messages are precomposed
            wide.ptr,
            cast(int)wide.length,
            narrow.ptr,
            cast(int)narrow.length,
            null,
            null);
    }

    auto wideMessage = pWideMessage[0 .. length];

    int requiredCodeUnits = wideToNarrow(wideMessage, null);

    // If FormatMessage with FORMAT_MESSAGE_FROM_SYSTEM succeeds,
    // there's no reason for the returned UTF-16 to be invalid.
    assert(requiredCodeUnits > 0);

    auto message = new char[requiredCodeUnits];
    auto writtenLength = wideToNarrow(wideMessage, message);

    assert(writtenLength > 0); // Ditto

    return cast(immutable)message[0 .. writtenLength];
}
