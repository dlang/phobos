// Written in the D programming language.

/**
 * Convert Win32 error code to string.
 *
 * Copyright: Copyright Digital Mars 2006 - 2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Credits:   Based on code written by Regan Heath
 *
 *          Copyright Digital Mars 2006 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.windows.syserror;
import std.traits : isSomeString;

version (StdDdoc)
{
    private
    {
        alias DWORD = uint;
        enum LANG_NEUTRAL = 0, SUBLANG_DEFAULT = 1;
    }

    /// Query the text for a Windows error code (as returned by $(LINK2
    /// http://msdn.microsoft.com/en-us/library/windows/desktop/ms679360.aspx,
    /// $(D GetLastError))) as a D string.
    string sysErrorString(
        DWORD errCode,
        // MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT) is the user's default language
        int langId = LANG_NEUTRAL,
        int subLangId = SUBLANG_DEFAULT) @trusted;

    /*********************
     * Thrown if errors that set $(LINK2
     * http://msdn.microsoft.com/en-us/library/windows/desktop/ms679360.aspx,
     * $(D GetLastError)) occur.
     */
    class WindowsException : Exception
    {
        private alias DWORD = int;
        final @property DWORD code(); /// $(D GetLastError)'s return value.
        @disable this(int dummy);
    }

    /++
        If $(D !!value) is true, $(D value) is returned. Otherwise,
        $(D new WindowsException(GetLastError(), msg)) is thrown.
        $(D WindowsException) assumes that the last operation set
        $(D GetLastError()) appropriately.

        Example:
        --------------------
        wenforce(DeleteFileA("junk.tmp"), "DeleteFile failed");
        --------------------
     +/
    T wenforce(T, S)(T value, lazy S msg = null,
        string file = __FILE__, size_t line = __LINE__) @safe
        if (isSomeString!S);
}
else:

version (Windows):

import std.windows.charset;
import std.array : appender;
import std.conv : to;
import std.format : formattedWrite;
import core.sys.windows.windows;

string sysErrorString(
    DWORD errCode,
    // MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT) is the user's default language
    int langId = LANG_NEUTRAL,
    int subLangId = SUBLANG_DEFAULT) @trusted
{
    auto buf = appender!string();

    if (!putSysError(errCode, buf, MAKELANGID(langId, subLangId)))
    {
        throw new Exception(
            "failed getting error string for WinAPI error code: " ~
            sysErrorString(GetLastError()));
    }

    return buf.data;
}

bool putSysError(Writer)(DWORD code, Writer w, /*WORD*/int langId = 0)
{
    wchar *lpMsgBuf = null;
    auto res = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        code,
        langId,
        cast(LPWSTR)&lpMsgBuf,
        0,
        null);
    scope(exit) if (lpMsgBuf) LocalFree(lpMsgBuf);

    if (lpMsgBuf)
    {
        import std.string : strip;
        w.put(lpMsgBuf[0..res].strip());
        return true;
    }
    else
        return false;
}


class WindowsException : Exception
{
    import core.sys.windows.windows;

    final @property DWORD code() { return _code; } /// $(D GetLastError)'s return value.
    private DWORD _code;

    this(DWORD code, string str=null, string file = null, size_t line = 0) @trusted
    {
        _code = code;

        auto buf = appender!string();

        if (str != null)
        {
            buf.put(str);
            buf.put(": ");
        }

        auto success = putSysError(code, buf);
        formattedWrite(buf, success ? " (error %d)" : "Error %d", code);

        super(buf.data, file, line);
    }
}


T wenforce(T, S)(T value, lazy S msg = null,
    string file = __FILE__, size_t line = __LINE__) if (isSomeString!S)
{
    if (!value)
        throw new WindowsException(GetLastError(), to!string(msg), file, line);
    return value;
}

version(Windows)
unittest
{
    import std.exception;
    import std.string;
    import std.algorithm : startsWith, endsWith;

    auto e = collectException!WindowsException(
        DeleteFileA("unexisting.txt").wenforce("DeleteFile")
    );
    assert(e.code == ERROR_FILE_NOT_FOUND);
    assert(e.msg.startsWith("DeleteFile: "));
    // can't test the entire message, as it depends on Windows locale
    assert(e.msg.endsWith(" (error 2)"));
}
