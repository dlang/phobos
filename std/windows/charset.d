// Written in the D programming language.

/**
 * Support UTF-8 on Windows 95, 98 and ME systems.
 *
 * Macros:
 *      WIKI = Phobos/StdWindowsCharset
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 */
/*          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.windows.charset;

private import std.conv;
private import std.c.windows.windows;
private import std.windows.syserror;
private import std.utf;
private import std.string;

/******************************************
 * Converts the UTF-8 string s into a null-terminated string in a Windows
 * 8-bit character set.
 *
 * Params:
 * s = UTF-8 string to convert.
 * codePage = is the number of the target codepage, or
 *   0 - ANSI,
 *   1 - OEM,
 *   2 - Mac
 *
 * Authors:
 *      yaneurao, Walter Bright, Stewart Gordon
 */

const(char)* toMBSz(in char[] s, uint codePage = 0)
{
    // Only need to do this if any chars have the high bit set
    foreach (char c; s)
    {
        if (c >= 0x80)
        {
            char[] result;
            int readLen;
            auto ws = std.utf.toUTF16z(s);
            result.length = WideCharToMultiByte(codePage, 0, ws, -1, null, 0,
                    null, null);

            if (result.length)
            {
                readLen = WideCharToMultiByte(codePage, 0, ws, -1, result.ptr,
                        to!int(result.length), null, null);
            }

            if (!readLen || readLen != result.length)
            {
                throw new Exception("Couldn't convert string: " ~
                        sysErrorString(GetLastError()));
            }

            return result.ptr;
        }
    }
    return std.string.toStringz(s);
}


/**********************************************
 * Converts the null-terminated string s from a Windows 8-bit character set
 * into a UTF-8 char array.
 *
 * Params:
 * s = UTF-8 string to convert.
 * codePage = is the number of the source codepage, or
 *   0 - ANSI,
 *   1 - OEM,
 *   2 - Mac
 * Authors: Stewart Gordon, Walter Bright
 */

string fromMBSz(immutable(char)* s, int codePage = 0)
{
    const(char)* c;

    for (c = s; *c != 0; c++)
    {
        if (*c >= 0x80)
        {
            wchar[] result;
            int readLen;

            result.length = MultiByteToWideChar(codePage, 0, s, -1, null, 0);

            if (result.length)
            {
                readLen = MultiByteToWideChar(codePage, 0, s, -1, result.ptr,
                        to!int(result.length));
            }

            if (!readLen || readLen != result.length)
            {
                throw new Exception("Couldn't convert string: " ~
                    sysErrorString(GetLastError()));
            }

            return std.utf.toUTF8(result[0 .. result.length-1]); // omit trailing null
        }
    }
    return s[0 .. c-s];         // string is ASCII, no conversion necessary
}


