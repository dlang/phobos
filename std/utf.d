// Written in the D programming language.

/**
 * Encode and decode UTF-8, UTF-16 and UTF-32 strings.
 *
 * For Win32 systems, the C wchar_t type is UTF-16 and corresponds to the D
 * wchar type.
 * For linux systems, the C wchar_t type is UTF-32 and corresponds to
 * the D utf.dchar type.
 *
 * UTF character support is restricted to (\u0000 &lt;= character &lt;= \U0010FFFF).
 *
 * See_Also:
 *  $(LINK2 http://en.wikipedia.org/wiki/Unicode, Wikipedia)<br>
 *  $(LINK http://www.cl.cam.ac.uk/~mgk25/unicode.html#utf-8)<br>
 *  $(LINK http://anubis.dkuug.dk/JTC1/SC2/WG2/docs/n1335)
 * Macros:
 *  WIKI = Phobos/StdUtf
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_utf.d)
 */
/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.utf;

import std.conv;       // to, assumeUnique
import std.exception;  // enforce, assumeUnique
import std.range;      // walkLength
import std.traits;     // isSomeChar, isSomeString

//debug=utf;           // uncomment to turn on debugging printf's

debug (utf) import core.stdc.stdio : printf;

version(unittest)
{
    import core.exception;
    import std.string;
}

//Remove when softDeprec and hardDeprec have been removed.
import std.metastrings;


/**********************************
 * Exception class that is thrown upon any errors.
 */
class UtfException : Exception
{
    //size_t idx;   /// index in string of where error occurred
    uint[4] sequence;
    size_t len;

    this(string s, dchar[] data...)
    {
        len = data.length;
        foreach (i, e; data) sequence[i] = e;
        super(s);
    }

    override string toString()
    {
        string result;

        if (len > 0)
        {
            result = "Invalid UTF sequence:";
            foreach (i; 0 .. len)
                result ~= " " ~ to!string(sequence[i], 16);
        }
        if (super.msg.length > 0)
        {
            if (result.length > 0)
                result ~= " - ";
            result ~= super.msg;
        }

        return result;
    }
}


/*******************************
 * Test if c is a valid UTF-32 character.
 *
 * \uFFFE and \uFFFF are considered valid by this function,
 * as they are permitted for internal use by an application,
 * but they are not allowed for interchange by the Unicode standard.
 *
 * Returns: true if it is, false if not.
 */
@safe
pure nothrow bool isValidDchar(dchar c)
{
    /* Note: FFFE and FFFF are specifically permitted by the
     * Unicode standard for application internal use, but are not
     * allowed for interchange.
     * (thanks to Arcane Jill)
     */

    return c < 0xD800 ||
          (c > 0xDFFF && c <= 0x10FFFF /*&& c != 0xFFFE && c != 0xFFFF*/);
}

unittest
{
    debug(utf) printf("utf.isValidDchar.unittest\n");
    assert(isValidDchar(cast(dchar)'a') == true);
    assert(isValidDchar(cast(dchar)0x1FFFFF) == false);

    assert(!isValidDchar(cast(dchar)0x00D800));
    assert(!isValidDchar(cast(dchar)0x00DBFF));
    assert(!isValidDchar(cast(dchar)0x00DC00));
    assert(!isValidDchar(cast(dchar)0x00DFFF));
    assert(isValidDchar(cast(dchar)0x00FFFE));
    assert(isValidDchar(cast(dchar)0x00FFFF));
    assert(isValidDchar(cast(dchar)0x01FFFF));
    assert(isValidDchar(cast(dchar)0x10FFFF));
    assert(!isValidDchar(cast(dchar)0x110000));
}


@safe pure
{

private immutable ubyte[256] UTF8stride =
[
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,0xFF,0xFF,
];

/**
 * stride() returns the length of a UTF-8 sequence starting at index $(D_PARAM i)
 * in string $(D_PARAM s).
 * Returns:
 *  The number of bytes in the UTF-8 sequence.
 * Throws:
 *  UtfException if s[i] is not the start of the UTF-8 sequence.
 */
uint stride(in char[] s, size_t i)
{
    immutable result = UTF8stride[s[i]];
    if (result == 0xFF)
        throw new UtfException("Not the start of the UTF-8 sequence");
    return result;
}

@trusted unittest
{
    static void test(string s, dchar c, size_t i = 0, size_t line = __LINE__)
    {
        enforce(stride(s, i) == codeLength!char(c),
                new AssertError(format("Unit test failure: %s", s), __FILE__, line));
    }

    test("a", 'a');
    test(" ", ' ');
    test("\u2029", '\u2029'); //paraSep
    test("\u0100", '\u0100');
    test("\u0430", '\u0430');
    test("\U00010143", '\U00010143');
    test("abcdefcdef", 'a');
    test("hello\U00010143\u0100\U00010143", 'h', 0);
    test("hello\U00010143\u0100\U00010143", 'e', 1);
    test("hello\U00010143\u0100\U00010143", 'l', 2);
    test("hello\U00010143\u0100\U00010143", 'l', 3);
    test("hello\U00010143\u0100\U00010143", 'o', 4);
    test("hello\U00010143\u0100\U00010143", '\U00010143', 5);
    test("hello\U00010143\u0100\U00010143", '\u0100', 9);
    test("hello\U00010143\u0100\U00010143", '\U00010143', 11);
}

/**
 * strideBack() returns the length of a UTF-8 sequence ending before index $(D_PARAM i)
 * in string $(D_PARAM s).
 * Returns:
 *  The number of bytes in the UTF-8 sequence.
 * Throws:
 *  UtfException if s[i-1] is not the end of the UTF-8 sequence.
 */
uint strideBack(in char[] s, size_t i)
{
    if (i >= 1 && (s[i-1] & 0b1100_0000) != 0b1000_0000)
        return 1;
    else if (i >= 2 && (s[i-2] & 0b1100_0000) != 0b1000_0000)
        return 2;
    else if (i >= 3 && (s[i-3] & 0b1100_0000) != 0b1000_0000)
        return 3;
    else if (i >= 4 && (s[i-4] & 0b1100_0000) != 0b1000_0000)
        return 4;
    else
        throw new UtfException("Not the end of the UTF sequence");
}

@trusted unittest
{
    static void test(string s, dchar c, size_t i = size_t.max, size_t line = __LINE__)
    {
        enforce(strideBack(s, i == size_t.max ? s.length : i) == codeLength!char(c),
                new AssertError(format("Unit test failure: %s", s), __FILE__, line));
    }

    test("a", 'a');
    test(" ", ' ');
    test("\u2029", '\u2029'); //paraSep
    test("\u0100", '\u0100');
    test("\u0430", '\u0430');
    test("\U00010143", '\U00010143');
    test("abcdefcdef", 'f');
    test("\U00010143\u0100\U00010143hello", 'o', 15);
    test("\U00010143\u0100\U00010143hello", 'l', 14);
    test("\U00010143\u0100\U00010143hello", 'l', 13);
    test("\U00010143\u0100\U00010143hello", 'e', 12);
    test("\U00010143\u0100\U00010143hello", 'h', 11);
    test("\U00010143\u0100\U00010143hello", '\U00010143', 10);
    test("\U00010143\u0100\U00010143hello", '\u0100', 6);
    test("\U00010143\u0100\U00010143hello", '\U00010143', 4);
}

/**
 * stride() returns the length of a UTF-16 sequence starting at index $(D_PARAM i)
 * in string $(D_PARAM s).
 */
nothrow uint stride(in wchar[] s, size_t i)
{
    immutable uint u = s[i];
    return 1 + (u >= 0xD800 && u <= 0xDBFF);
}

@trusted unittest
{
    static void test(wstring s, dchar c, size_t i = 0, size_t line = __LINE__)
    {
        enforce(stride(s, i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure: %s", s), __FILE__, line));
    }

    test("a", 'a');
    test(" ", ' ');
    test("\u2029", '\u2029'); //paraSep
    test("\u0100", '\u0100');
    test("\u0430", '\u0430');
    test("\U00010143", '\U00010143');
    test("abcdefcdef", 'a');
    test("hello\U00010143\u0100\U00010143", 'h', 0);
    test("hello\U00010143\u0100\U00010143", 'e', 1);
    test("hello\U00010143\u0100\U00010143", 'l', 2);
    test("hello\U00010143\u0100\U00010143", 'l', 3);
    test("hello\U00010143\u0100\U00010143", 'o', 4);
    test("hello\U00010143\u0100\U00010143", '\U00010143', 5);
    test("hello\U00010143\u0100\U00010143", '\u0100', 7);
    test("hello\U00010143\u0100\U00010143", '\U00010143', 8);
}

/**
 * strideBack() returns the length of a UTF-16 sequence ending before index $(D_PARAM i)
 * in string $(D_PARAM s).
 */
uint strideBack(in wchar[] s, size_t i)
{
    if (i == 0 || (s[i-1] >= 0xD800 && s[i-1] <= 0xDBFF))
        throw new UtfException("Not the end of the UTF-16 sequence");
    if (i <= 1)
        return 1;
    immutable c = s[i - 2];
    return 1 + (c >= 0xD800 && c <= 0xDBFF);
}

@trusted unittest
{
    static void test(wstring s, dchar c, size_t i = size_t.max, size_t line = __LINE__)
    {
        enforce(strideBack(s, i == size_t.max ? s.length : i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure: %s", s), __FILE__, line));
    }

    test("a", 'a');
    test(" ", ' ');
    test("\u2029", '\u2029'); //paraSep
    test("\u0100", '\u0100');
    test("\u0430", '\u0430');
    test("\U00010143", '\U00010143');
    test("abcdefcdef", 'f');
    test("\U00010143\u0100\U00010143hello", 'o', 10);
    test("\U00010143\u0100\U00010143hello", 'l', 9);
    test("\U00010143\u0100\U00010143hello", 'l', 8);
    test("\U00010143\u0100\U00010143hello", 'e', 7);
    test("\U00010143\u0100\U00010143hello", 'h', 6);
    test("\U00010143\u0100\U00010143hello", '\U00010143', 5);
    test("\U00010143\u0100\U00010143hello", '\u0100', 3);
    test("\U00010143\u0100\U00010143hello", '\U00010143', 2);
}

/**
 * stride() returns the length of a UTF-32 sequence starting at index $(D_PARAM i)
 * in string $(D_PARAM s).
 * Returns: The return value will always be 1.
 */
nothrow uint stride(in dchar[] s, size_t i)
{
    return 1;
}

@trusted unittest
{
    static void test(dstring s, dchar c, size_t i = 0, size_t line = __LINE__)
    {
        enforce(stride(s, i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure: %s", s), __FILE__, line));
    }

    test("a", 'a');
    test(" ", ' ');
    test("\u2029", '\u2029'); //paraSep
    test("\u0100", '\u0100');
    test("\u0430", '\u0430');
    test("\U00010143", '\U00010143');
    test("abcdefcdef", 'a');
    test("hello\U00010143\u0100\U00010143", 'h', 0);
    test("hello\U00010143\u0100\U00010143", 'e', 1);
    test("hello\U00010143\u0100\U00010143", 'l', 2);
    test("hello\U00010143\u0100\U00010143", 'l', 3);
    test("hello\U00010143\u0100\U00010143", 'o', 4);
    test("hello\U00010143\u0100\U00010143", '\U00010143', 5);
    test("hello\U00010143\u0100\U00010143", '\u0100', 6);
    test("hello\U00010143\u0100\U00010143", '\U00010143', 7);
}

/**
 * strideBack() returns the length of a UTF-32 sequence ending before index $(D_PARAM i)
 * in string $(D_PARAM s).
 * Returns: The return value will always be 1.
 */
nothrow uint strideBack(in dchar[] s, size_t i)
{
    return 1;
}

@trusted unittest
{
    static void test(dstring s, dchar c, size_t i = size_t.max, size_t line = __LINE__)
    {
        enforce(strideBack(s, i == size_t.max ? s.length : i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure: %s", s), __FILE__, line));
    }

    test("a", 'a');
    test(" ", ' ');
    test("\u2029", '\u2029'); //paraSep
    test("\u0100", '\u0100');
    test("\u0430", '\u0430');
    test("\U00010143", '\U00010143');
    test("abcdefcdef", 'f');
    test("\U00010143\u0100\U00010143hello", 'o', 8);
    test("\U00010143\u0100\U00010143hello", 'l', 7);
    test("\U00010143\u0100\U00010143hello", 'l', 6);
    test("\U00010143\u0100\U00010143hello", 'e', 5);
    test("\U00010143\u0100\U00010143hello", 'h', 4);
    test("\U00010143\u0100\U00010143hello", '\U00010143', 3);
    test("\U00010143\u0100\U00010143hello", '\u0100', 2);
    test("\U00010143\u0100\U00010143hello", '\U00010143', 1);
}

}  // stride functions are @safe and pure


@safe pure
{

/*******************************************
 * Given an index $(D_PARAM i) into an array of characters $(D_PARAM s[]),
 * and assuming that index $(D_PARAM i) is at the start of a UTF character,
 * determine the number of UCS characters up to that index $(D_PARAM i).
 */
size_t toUCSindex(in char[] s, size_t i)
{
    size_t n;
    size_t j;

    for (j = 0; j < i; )
    {
        j += stride(s, j);
        n++;
    }
    if (j > i)
    {
        throw new UtfException("1invalid UTF-8 sequence");
    }

    return n;
}

/// ditto
size_t toUCSindex(in wchar[] s, size_t i)
{
    size_t n;
    size_t j;

    for (j = 0; j < i; )
    {
        j += stride(s, j);
        n++;
    }
    if (j > i)
    {
        throw new UtfException("2invalid UTF-16 sequence");
    }

    return n;
}

/// ditto
nothrow size_t toUCSindex(in dchar[] s, size_t i)
{
    return i;
}


/******************************************
 * Given a UCS index $(D_PARAM n) into an array of characters $(D_PARAM s[]),
 * return the UTF index.
 */
size_t toUTFindex(in char[] s, size_t n)
{
    size_t i;

    while (n--)
    {
        uint j = UTF8stride[s[i]];
        if (j == 0xFF)
            throw new UtfException("3invalid UTF-8 sequence ", s[i]);
        i += j;
    }

    return i;
}

/// ditto
nothrow size_t toUTFindex(in wchar[] s, size_t n)
{
    size_t i;

    while (n--)
    {
        wchar u = s[i];

        i += 1 + (u >= 0xD800 && u <= 0xDBFF);
    }

    return i;
}

/// ditto
nothrow size_t toUTFindex(in dchar[] s, size_t n)
{
    return n;
}

}  // toUTF and toUCS index functions are @safe and pure


/* =================== Decode ======================= */

@trusted  // I think those functions should be @safe and pure.
{

/***************
 * Decodes and returns character starting at s[idx]. $(D_PARAM idx) is
 * advanced past the decoded character. If the character is not well formed,
 * a $(D UtfException) is thrown and $(D_PARAM idx) remains unchanged.
 */
dchar decode(in char[] s, ref size_t idx)
out (result)
{
    assert(isValidDchar(result));
}
body
{
    enforce(idx < s.length, "Attempted to decode past the end of a string");

    size_t len = s.length;
    dchar V;
    size_t i = idx;
    char u = s[i];

    if (u & 0x80)
    {
        /* The following encodings are valid, except for the 5 and 6 byte
         * combinations:
         *  0xxxxxxx
         *  110xxxxx 10xxxxxx
         *  1110xxxx 10xxxxxx 10xxxxxx
         *  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
         *  111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
         *  1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
         */
        uint n = 1;
        for (; ; n++)
        {
            if (n > 4)
                goto Lerr;      // only do the first 4 of 6 encodings
            if (((u << n) & 0x80) == 0)
            {
                if (n == 1)
                    goto Lerr;
                break;
            }
        }

        // Pick off (7 - n) significant bits of B from first byte of octet
        V = cast(dchar)(u & ((1 << (7 - n)) - 1));

        if (i + n > len)
            goto Lerr;          // off end of string

        /* The following combinations are overlong, and illegal:
         *  1100000x (10xxxxxx)
         *  11100000 100xxxxx (10xxxxxx)
         *  11110000 1000xxxx (10xxxxxx 10xxxxxx)
         *  11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
         *  11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
         */
        auto u2 = s[i + 1];
        if ((u & 0xFE) == 0xC0 ||
            (u == 0xE0 && (u2 & 0xE0) == 0x80) ||
            (u == 0xF0 && (u2 & 0xF0) == 0x80) ||
            (u == 0xF8 && (u2 & 0xF8) == 0x80) ||
            (u == 0xFC && (u2 & 0xFC) == 0x80))
            goto Lerr;          // overlong combination

        foreach (j; 1 .. n)
        {
            u = s[i + j];
            if ((u & 0xC0) != 0x80)
                goto Lerr;          // trailing bytes are 10xxxxxx
            V = (V << 6) | (u & 0x3F);
        }
        if (!isValidDchar(V))
            goto Lerr;
        i += n;
    }
    else
    {
        V = cast(dchar)u;
        i++;
    }

    idx = i;
    return V;

  Lerr:
    //printf("\ndecode: idx = %d, i = %d, length = %d s = \n'%.*s'\n%x\n"
    //"'%.*s'\n", idx, i, s.length, s, s[i], s[i .. $]);
    throw new UtfException(text("dchar decode(in char[], ref size_t): "
                    "Invalid UTF-8 sequence ", cast(const ubyte[])s,
                    " around index ", i));
}

unittest
{
    size_t i;
    dchar c;

    debug(utf) printf("utf.decode.unittest\n");

    static string s1 = "abcd";
    i = 0;
    c = decode(s1, i);
    assert(c == cast(dchar)'a');
    assert(i == 1);
    c = decode(s1, i);
    assert(c == cast(dchar)'b');
    assert(i == 2);

    static string s2 = "\xC2\xA9";
    i = 0;
    c = decode(s2, i);
    assert(c == cast(dchar)'\u00A9');
    assert(i == 2);

    static string s3 = "\xE2\x89\xA0";
    i = 0;
    c = decode(s3, i);
    assert(c == cast(dchar)'\u2260');
    assert(i == 3);

    static string[] s4 = [
        "\xE2\x89",     // too short
        "\xC0\x8A",
        "\xE0\x80\x8A",
        "\xF0\x80\x80\x8A",
        "\xF8\x80\x80\x80\x8A",
        "\xFC\x80\x80\x80\x80\x8A",
    ];

    for (int j = 0; j < s4.length; j++)
    {
        try
        {
            i = 0;
            c = decode(s4[j], i);
            assert(0);
        }
        catch (UtfException u)
        {
            i = 23;
            delete u;
        }

        assert(i == 23);
    }
}

@trusted unittest
{
    size_t i;

    i = 0; assert(decode("\xEF\xBF\xBE"c, i) == cast(dchar)0xFFFE);
    i = 0; assert(decode("\xEF\xBF\xBF"c, i) == cast(dchar)0xFFFF);
    i = 0;
    assertThrown!UtfException(decode("\xED\xA0\x80"c, i));
    assertThrown!UtfException(decode("\xED\xAD\xBF"c, i));
    assertThrown!UtfException(decode("\xED\xAE\x80"c, i));
    assertThrown!UtfException(decode("\xED\xAF\xBF"c, i));
    assertThrown!UtfException(decode("\xED\xB0\x80"c, i));
    assertThrown!UtfException(decode("\xED\xBE\x80"c, i));
    assertThrown!UtfException(decode("\xED\xBF\xBF"c, i));
}

/// ditto
dchar decode(in wchar[] s, ref size_t idx)
out (result)
{
    assert(isValidDchar(result));
}
body
{
    enforce(idx < s.length, "Attempted to decode past the end of a string");

    string msg;
    dchar V;
    size_t i = idx;
    uint u = s[i];

    if (u & ~0x7F)
    {
        if (u >= 0xD800 && u <= 0xDBFF)
        {
            uint u2;

            if (i + 1 == s.length)
            {
                msg = "surrogate UTF-16 high value past end of string";
                goto Lerr;
            }
            u2 = s[i + 1];
            if (u2 < 0xDC00 || u2 > 0xDFFF)
            {
                msg = "surrogate UTF-16 low value out of range";
                goto Lerr;
            }
            u = ((u - 0xD7C0) << 10) + (u2 - 0xDC00);
            i += 2;
        }
        else if (u >= 0xDC00 && u <= 0xDFFF)
        {
            msg = "unpaired surrogate UTF-16 value";
            goto Lerr;
        }
        else
            i++;
        // Note: u+FFFE and u+FFFF are specifically permitted by the
        // Unicode standard for application internal use (see isValidDchar)
    }
    else
    {
        i++;
    }

    idx = i;
    return cast(dchar)u;

  Lerr:
    throw new UtfException(msg, s[i]);
}

unittest
{
    size_t i;

    i = 0; assert(decode([ cast(wchar)0xFFFE ], i) == cast(dchar)0xFFFE && i == 1);
    i = 0; assert(decode([ cast(wchar)0xFFFF ], i) == cast(dchar)0xFFFF && i == 1);
}


/// ditto
dchar decode(in dchar[] s, ref size_t idx)
{
    enforce(idx < s.length, "Attempted to decode past the end of a string");

    size_t i = idx;
    dchar c = s[i];

    if (!isValidDchar(c))
        goto Lerr;
    idx = i + 1;
    return c;

  Lerr:
    throw new UtfException("5invalid UTF-32 value", c);
}

}  // Decode functions are @trusted


/* =================== Encode ======================= */

@safe // pure  @@@NOTE@@@ unittest is a function. Currently, unittest is affected by applying attributes.
{

/*******************************
 * Encodes character $(D_PARAM c) into fixed-size array $(D_PARAM s).
 * Returns the actual length of the encoded character (a number between 1 and
 * 4 for $(D char[4]) buffers, and between 1 and 2 for $(D wchar[2]) buffers).
 */
pure size_t encode(ref char[4] buf, dchar c)
{
    if (c <= 0x7F)
    {
        assert(isValidDchar(c));
        buf[0] = cast(char)c;
        return 1;
    }
    if (c <= 0x7FF)
    {
        assert(isValidDchar(c));
        buf[0] = cast(char)(0xC0 | (c >> 6));
        buf[1] = cast(char)(0x80 | (c & 0x3F));
        return 2;
    }
    if (c <= 0xFFFF)
    {
        if (0xD800 <= c && c <= 0xDFFF)
            throw new UtfException("encoding a surrogate code point in UTF-8", c);

        assert(isValidDchar(c));
        buf[0] = cast(char)(0xE0 | (c >> 12));
        buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf[2] = cast(char)(0x80 | (c & 0x3F));
        return 3;
    }
    if (c <= 0x10FFFF)
    {
        assert(isValidDchar(c));
        buf[0] = cast(char)(0xF0 | (c >> 18));
        buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
        buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf[3] = cast(char)(0x80 | (c & 0x3F));
        return 4;
    }

    assert(!isValidDchar(c));
    throw new UtfException("encoding an invalid code point in UTF-8", c);
}

@trusted unittest
{
    char[4] buf;

    assert(encode(buf, '\u0000') == 1 && buf[0 .. 1] == "\u0000");
    assert(encode(buf, '\u007F') == 1 && buf[0 .. 1] == "\u007F");
    assert(encode(buf, '\u0080') == 2 && buf[0 .. 2] == "\u0080");
    assert(encode(buf, '\u07FF') == 2 && buf[0 .. 2] == "\u07FF");
    assert(encode(buf, '\u0800') == 3 && buf[0 .. 3] == "\u0800");
    assert(encode(buf, '\uD7FF') == 3 && buf[0 .. 3] == "\uD7FF");
    assert(encode(buf, '\uE000') == 3 && buf[0 .. 3] == "\uE000");
    assert(encode(buf, 0xFFFE) == 3 && buf[0 .. 3] == "\xEF\xBF\xBE");
    assert(encode(buf, 0xFFFF) == 3 && buf[0 .. 3] == "\xEF\xBF\xBF");
    assert(encode(buf, '\U00010000') == 4 && buf[0 .. 4] == "\U00010000");
    assert(encode(buf, '\U0010FFFF') == 4 && buf[0 .. 4] == "\U0010FFFF");

    assertThrown!UtfException(encode(buf, cast(dchar)0xD800));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0x110000));
}


/// Ditto
pure size_t encode(ref wchar[2] buf, dchar c)
{
    if (c <= 0xFFFF)
    {
        if (0xD800 <= c && c <= 0xDFFF)
            throw new UtfException("encoding an isolated surrogate code point in UTF-16", c);

        assert(isValidDchar(c));
        buf[0] = cast(wchar)c;
        return 1;
    }
    if (c <= 0x10FFFF)
    {
        assert(isValidDchar(c));
        buf[0] = cast(wchar)((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
        buf[1] = cast(wchar)(((c - 0x10000) & 0x3FF) + 0xDC00);
        return 2;
    }

    assert(!isValidDchar(c));
    throw new UtfException("encoding an invalid code point in UTF-16", c);
}

@trusted unittest
{
    wchar[2] buf;

    assert(encode(buf, '\u0000') == 1 && buf[0 .. 1] == "\u0000");
    assert(encode(buf, '\uD7FF') == 1 && buf[0 .. 1] == "\uD7FF");
    assert(encode(buf, '\uE000') == 1 && buf[0 .. 1] == "\uE000");
    assert(encode(buf, 0xFFFE) == 1 && buf[0] == 0xFFFE);
    assert(encode(buf, 0xFFFF) == 1 && buf[0] == 0xFFFF);
    assert(encode(buf, '\U00010000') == 2 && buf[0 .. 2] == "\U00010000");
    assert(encode(buf, '\U0010FFFF') == 2 && buf[0 .. 2] == "\U0010FFFF");

    assertThrown!UtfException(encode(buf, cast(dchar)0xD800));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0x110000));
}


/*******************************
 * Encodes character $(D_PARAM c) and appends it to array $(D_PARAM s[]).
 */
pure void encode(ref char[] s, dchar c)
{
    char[] r = s;

    if (c <= 0x7F)
    {
        assert(isValidDchar(c));
        r ~= cast(char)c;
    }
    else
    {
        char[4] buf;
        uint L;

        if (c <= 0x7FF)
        {
            assert(isValidDchar(c));
            buf[0] = cast(char)(0xC0 | (c >> 6));
            buf[1] = cast(char)(0x80 | (c & 0x3F));
            L = 2;
        }
        else if (c <= 0xFFFF)
        {
            if (0xD800 <= c && c <= 0xDFFF)
                throw new UtfException("encoding a surrogate code point in UTF-8", c);

            assert(isValidDchar(c));
            buf[0] = cast(char)(0xE0 | (c >> 12));
            buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
            buf[2] = cast(char)(0x80 | (c & 0x3F));
            L = 3;
        }
        else if (c <= 0x10FFFF)
        {
            assert(isValidDchar(c));
            buf[0] = cast(char)(0xF0 | (c >> 18));
            buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
            buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
            buf[3] = cast(char)(0x80 | (c & 0x3F));
            L = 4;
        }
        else
        {
            assert(!isValidDchar(c));
            throw new UtfException("encoding an invalid code point in UTF-8", c);
        }
        r ~= buf[0 .. L];
    }
    s = r;
}

unittest
{
    debug(utf) printf("utf.encode.unittest\n");

    char[] s = "abcd".dup;
    encode(s, cast(dchar)'a');
    assert(s.length == 5);
    assert(s == "abcda");

    encode(s, cast(dchar)'\u00A9');
    assert(s.length == 7);
    assert(s == "abcda\xC2\xA9");
    //assert(s == "abcda\u00A9");   // BUG: fix compiler

    encode(s, cast(dchar)'\u2260');
    assert(s.length == 10);
    assert(s == "abcda\xC2\xA9\xE2\x89\xA0");
}

@trusted unittest
{
    char[] buf;

    encode(buf, '\u0000'); assert(buf[0 .. $] == "\u0000");
    encode(buf, '\u007F'); assert(buf[1 .. $] == "\u007F");
    encode(buf, '\u0080'); assert(buf[2 .. $] == "\u0080");
    encode(buf, '\u07FF'); assert(buf[4 .. $] == "\u07FF");
    encode(buf, '\u0800'); assert(buf[6 .. $] == "\u0800");
    encode(buf, '\uD7FF'); assert(buf[9 .. $] == "\uD7FF");
    encode(buf, '\uE000'); assert(buf[12 .. $] == "\uE000");
    encode(buf, 0xFFFE); assert(buf[15 .. $] == "\xEF\xBF\xBE");
    encode(buf, 0xFFFF); assert(buf[18 .. $] == "\xEF\xBF\xBF");
    encode(buf, '\U00010000'); assert(buf[21 .. $] == "\U00010000");
    encode(buf, '\U0010FFFF'); assert(buf[25 .. $] == "\U0010FFFF");

    assertThrown!UtfException(encode(buf, cast(dchar)0xD800));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0x110000));
}

/// ditto
pure void encode(ref wchar[] s, dchar c)
{
    wchar[] r = s;

    if (c <= 0xFFFF)
    {
        if (0xD800 <= c && c <= 0xDFFF)
            throw new UtfException("encoding an isolated surrogate code point in UTF-16", c);

        assert(isValidDchar(c));
        r ~= cast(wchar)c;
    }
    else if (c <= 0x10FFFF)
    {
        wchar[2] buf;

        assert(isValidDchar(c));
        buf[0] = cast(wchar)((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
        buf[1] = cast(wchar)(((c - 0x10000) & 0x3FF) + 0xDC00);
        r ~= buf;
    }
    else
    {
        assert(!isValidDchar(c));
        throw new UtfException("encoding an invalid code point in UTF-16", c);
    }

    s = r;
}

@trusted unittest
{
    wchar[] buf;

    encode(buf, '\u0000'); assert(buf[0] == '\u0000');
    encode(buf, '\uD7FF'); assert(buf[1] == '\uD7FF');
    encode(buf, '\uE000'); assert(buf[2] == '\uE000');
    encode(buf, 0xFFFE); assert(buf[3] == 0xFFFE);
    encode(buf, 0xFFFF); assert(buf[4] == 0xFFFF);
    encode(buf, '\U00010000'); assert(buf[5 .. $] == "\U00010000");
    encode(buf, '\U0010FFFF'); assert(buf[7 .. $] == "\U0010FFFF");

    assertThrown!UtfException(encode(buf, cast(dchar)0xD800));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0x110000));
}

/// ditto
pure void encode(ref dchar[] s, dchar c)
{
    if ((0xD800 <= c && c <= 0xDFFF) || 0x10FFFF < c)
        throw new UtfException("encoding an invalid code point in UTF-32", c);

    assert(isValidDchar(c));
    s ~= c;
}

@trusted unittest
{
    dchar[] buf;

    encode(buf, '\u0000'); assert(buf[0] == '\u0000');
    encode(buf, '\uD7FF'); assert(buf[1] == '\uD7FF');
    encode(buf, '\uE000'); assert(buf[2] == '\uE000');
    encode(buf, 0xFFFE ); assert(buf[3] == 0xFFFE);
    encode(buf, 0xFFFF ); assert(buf[4] == 0xFFFF);
    encode(buf, '\U0010FFFF'); assert(buf[5] == '\U0010FFFF');

    assertThrown!UtfException(encode(buf, cast(dchar)0xD800));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UtfException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UtfException(encode(buf, cast(dchar)0x110000));
}

}  // Encode functions are @safe and pure


/++
    Returns the number of code units that are required to encode the code point
    $(D c) when $(D C) is the character type used to encode it.

Examples:
------
assert(codeLength!char('a') == 1);
assert(codeLength!wchar('a') == 1);
assert(codeLength!dchar('a') == 1);

assert(codeLength!char('\U0010FFFF') == 4);
assert(codeLength!wchar('\U0010FFFF') == 2);
assert(codeLength!dchar('\U0010FFFF') == 1);
------
  +/
@safe
pure nothrow ubyte codeLength(C)(dchar c)
{
    static if (C.sizeof == 1)
    {
        return
            c <= 0x7F ? 1
            : c <= 0x7FF ? 2
            : c <= 0xFFFF ? 3
            : c <= 0x10FFFF ? 4
            : (assert(false), 6);
    }
    else static if (C.sizeof == 2)
    {
        return c <= 0xFFFF ? 1 : 2;
    }
    else
    {
        static assert(C.sizeof == 4);
        return 1;
    }
}

//Verify Examples.
unittest
{
    assert(codeLength!char('a') == 1);
    assert(codeLength!wchar('a') == 1);
    assert(codeLength!dchar('a') == 1);

    assert(codeLength!char('\U0010FFFF') == 4);
    assert(codeLength!wchar('\U0010FFFF') == 2);
    assert(codeLength!dchar('\U0010FFFF') == 1);
}


/* =================== Validation ======================= */

/***********************************
 * Checks to see if string is well formed or not. $(D S) can be an array
 * of $(D char), $(D wchar), or $(D dchar). Throws a $(D UtfException)
 * if it is not. Use to check all untrusted input for correctness.
 */
@safe
void validate(S)(in S s) if (isSomeString!S)
{
    immutable len = s.length;
    for (size_t i = 0; i < len; )
    {
        decode(s, i);
    }
}


/* =================== Conversion to UTF8 ======================= */

@trusted
{

char[] toUTF8(out char[4] buf, dchar c)
in
{
    assert(isValidDchar(c));
}
body
{
    if (c <= 0x7F)
    {
        buf[0] = cast(char)c;
        return buf[0 .. 1];
    }
    else if (c <= 0x7FF)
    {
        buf[0] = cast(char)(0xC0 | (c >> 6));
        buf[1] = cast(char)(0x80 | (c & 0x3F));
        return buf[0 .. 2];
    }
    else if (c <= 0xFFFF)
    {
        buf[0] = cast(char)(0xE0 | (c >> 12));
        buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf[2] = cast(char)(0x80 | (c & 0x3F));
        return buf[0 .. 3];
    }
    else if (c <= 0x10FFFF)
    {
        buf[0] = cast(char)(0xF0 | (c >> 18));
        buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
        buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf[3] = cast(char)(0x80 | (c & 0x3F));
        return buf[0 .. 4];
    }

    assert(0);
}


/*******************
 * Encodes string $(D_PARAM s) into UTF-8 and returns the encoded string.
 */
string toUTF8(in char[] s)
{
    validate(s);
    return s.idup;
}

/// ditto
string toUTF8(in wchar[] s)
{
    char[] r;
    size_t i;
    size_t slen = s.length;

    r.length = slen;
    for (i = 0; i < slen; i++)
    {
        wchar c = s[i];

        if (c <= 0x7F)
            r[i] = cast(char)c;     // fast path for ascii
        else
        {
            r.length = i;
            while (i < slen)
                encode(r, decode(s, i));
            break;
        }
    }

    return r.assumeUnique();
}

/// ditto
pure string toUTF8(in dchar[] s)
{
    char[] r;
    size_t i;
    size_t slen = s.length;

    r.length = slen;
    for (i = 0; i < slen; i++)
    {
        dchar c = s[i];

        if (c <= 0x7F)
            r[i] = cast(char)c;     // fast path for ascii
        else
        {
            r.length = i;
            foreach (dchar d; s[i .. slen])
            {
                encode(r, d);
            }
            break;
        }
    }

    return r.assumeUnique();
}


/* =================== Conversion to UTF16 ======================= */

pure wchar[] toUTF16(ref wchar[2] buf, dchar c)
in
{
    assert(isValidDchar(c));
}
body
{
    if (c <= 0xFFFF)
    {
        buf[0] = cast(wchar)c;
        return buf[0 .. 1];
    }
    else
    {
        buf[0] = cast(wchar)((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
        buf[1] = cast(wchar)(((c - 0x10000) & 0x3FF) + 0xDC00);
        return buf[0 .. 2];
    }
}

/****************
 * Encodes string $(D s) into UTF-16 and returns the encoded string.
 */
wstring toUTF16(in char[] s)
{
    wchar[] r;
    size_t slen = s.length;

    r.length = slen;
    r.length = 0;
    for (size_t i = 0; i < slen; )
    {
        dchar c = s[i];
        if (c <= 0x7F)
        {
            i++;
            r ~= cast(wchar)c;
        }
        else
        {
            c = decode(s, i);
            encode(r, c);
        }
    }

    return r.assumeUnique();  // ok because r is unique
}

/// ditto
wstring toUTF16(in wchar[] s)
{
    validate(s);
    return s.idup;
}

/// ditto
pure wstring toUTF16(in dchar[] s)
{
    wchar[] r;
    size_t slen = s.length;

    r.length = slen;
    r.length = 0;
    for (size_t i = 0; i < slen; i++)
    {
        encode(r, s[i]);
    }

    return r.assumeUnique();  // ok because r is unique
}

/++
    $(RED Scheduled for deprecation in February 2012.
          Please use $(LREF toUTFz) instead.)

    Encodes string $(D s) into UTF-16 and returns the encoded string.
    $(D toUTF16z) is suitable for calling the 'W' functions in the Win32 API
    that take an $(D LPWSTR) or $(D LPCWSTR) argument.
  +/
version(StdDdoc) const(wchar)* toUTF16z(in char[] s);
else const(wchar)* toUTF16z(C)(in C[] s)
    if(is(Unqual!C == char))
{
    pragma(msg, softDeprec!("2.055", "February 2012", "toUTF16z", "toUTFz"));

    wchar[] r;
    size_t slen = s.length;

    r.length = slen + 1;
    r.length = 0;
    for (size_t i = 0; i < slen; )
    {
        dchar c = s[i];
        if (c <= 0x7F)
        {
            i++;
            r ~= cast(wchar)c;
        }
        else
        {
            c = decode(s, i);
            encode(r, c);
        }
    }
    r ~= "\000";

    return r.ptr;
}


/* =================== Conversion to UTF32 ======================= */

/*****
 * Encodes string $(D_PARAM s) into UTF-32 and returns the encoded string.
 */
dstring toUTF32(in char[] s)
{
    dchar[] r;
    size_t slen = s.length;
    size_t j = 0;

    r.length = slen;        // r[] will never be longer than s[]
    for (size_t i = 0; i < slen; )
    {
        dchar c = s[i];
        if (c >= 0x80)
            c = decode(s, i);
        else
            i++;        // c is ascii, no need for decode
        r[j++] = c;
    }

    return r[0 .. j].assumeUnique(); // legit because it's unique
}

/// ditto
dstring toUTF32(in wchar[] s)
{
    dchar[] r;
    size_t slen = s.length;
    size_t j = 0;

    r.length = slen;        // r[] will never be longer than s[]
    for (size_t i = 0; i < slen; )
    {
        dchar c = s[i];
        if (c >= 0x80)
            c = decode(s, i);
        else
            i++;        // c is ascii, no need for decode
        r[j++] = c;
    }

    return r[0 .. j].assumeUnique();  // legit because it's unique
}

/// ditto
dstring toUTF32(in dchar[] s)
{
    validate(s);
    return s.idup;
}

} // Convert functions are @safe


/* =================== toUTFz ======================= */

/++
    Returns a C-style zero-terminated string equivalent to $(D str). $(D str)
    must not contain embedded $(D '\0')'s as any C function will treat the first
    $(D '\0') that it sees a the end of the string. If $(D str.empty) is
    $(D true), then a string containing only $(D '\0') is returned.

    $(D toUTFz) accepts any type of string and is templated on the type of
    character pointer that you wish to convert to. It will avoid allocating a
    new string if it can, but there's a decent chance that it will end up having
    to allocate a new string - particularly when dealing with character types
    other than $(D char).

    $(RED Warning 1:) If the result of $(D toUTFz) equals $(D str.ptr), then if
    anything alters the character one past the end of $(D str) (which is the
    $(D '\0') character terminating the string), then the string won't be
    zero-terminated anymore. The most likely scenarios for that are if you
    append to $(D str) and no reallocation takes place or when $(D str) is a
    slice of a larger array, and you alter the character in the larger array
    which is one character past the end of $(D str). Another case where it could
    occur would be if you had a mutable character array immediately after
    $(D str) in memory (for example, if they're member variables in a
    user-defined type with one declared right after the other) and that
    character array happened to start with $(D '\0'). Such scenarios will never
    occur if you immediately use the zero-terminated string after calling
    $(D toUTFz) and the C function using it doesn't keep a reference to it.
    Also, they are unlikely to occur even if you save the zero-terminated string
    (the cases above would be among the few examples of where it could happen).
    However, if you save the zero-terminate string and want to be absolutely
    certain that the string stays zero-terminated, then simply append a
    $(D '\0') to the string and use its $(D ptr) property rather than calling
    $(D toUTFz).

    $(RED Warning 2:) When passing a character pointer to a C function, and the
    C function keeps it around for any reason, make sure that you keep a
    reference to it in your D code. Otherwise, it may go away during a garbage
    collection cycle and cause a nasty bug when the C code tries to use it.

    Examples:
--------------------
auto p1 = toUTFz!(char*)("hello world");
auto p2 = toUTFz!(const(char)*)("hello world");
auto p3 = toUTFz!(immutable(char)*)("hello world");
auto p4 = toUTFz!(char*)("hello world"d);
auto p5 = toUTFz!(const(wchar)*)("hello world");
auto p6 = toUTFz!(immutable(dchar)*)("hello world"w);
--------------------
  +/
P toUTFz(P, S)(S str) @system
    if(isSomeString!S && isPointer!P && isSomeChar!(typeof(*P.init)) &&
       is(Unqual!(typeof(*P.init)) == Unqual!(ElementEncodingType!S)) &&
       is(immutable(Unqual!(ElementEncodingType!S)) == ElementEncodingType!S))
//immutable(C)[] -> C*, const(C)*, or immutable(C)*
{
    if(str.empty)
    {
        typeof(*P.init)[] retval = ['\0'];

        return retval.ptr;
    }

    alias Unqual!(ElementEncodingType!S) C;

    //If the P is mutable, then we have to make a copy.
    static if(is(Unqual!(typeof(*P.init)) == typeof(*P.init)))
        return toUTFz!(P, const(C)[])(cast(const(C)[])str);
    else
    {
        immutable p = str.ptr + str.length;

        // Peek past end of str, if it's 0, no conversion necessary.
        // Note that the compiler will put a 0 past the end of static
        // strings, and the storage allocator will put a 0 past the end
        // of newly allocated char[]'s.
        // Is p dereferenceable? A simple test: if the p points to an
        // address multiple of 4, then conservatively assume the pointer
        // might be pointing to a new block of memory, which might be
        // unreadable. Otherwise, it's definitely pointing to valid
        // memory.
        if((cast(size_t)p & 3) && *p == '\0')
            return str.ptr;

        return toUTFz!(P, const(C)[])(cast(const(C)[])str);
    }
}

P toUTFz(P, S)(S str) @system
    if(isSomeString!S && isPointer!P && isSomeChar!(typeof(*P.init)) &&
       is(Unqual!(typeof(*P.init)) == Unqual!(ElementEncodingType!S)) &&
       !is(immutable(Unqual!(ElementEncodingType!S)) == ElementEncodingType!S))
//C[] or const(C)[] -> C*, const(C)*, or immutable(C)*
{
    alias ElementEncodingType!S InChar;
    alias typeof(*P.init) OutChar;

    //const(C)[] -> const(C)* or
    //C[] -> C* or const(C)*
    static if((is(const(Unqual!InChar) == InChar) && is(const(Unqual!OutChar) == OutChar)) ||
              (!is(const(Unqual!InChar) == InChar) && !is(immutable(Unqual!OutChar) == OutChar)))
    {
        auto p = str.ptr + str.length;

        if((cast(size_t)p & 3) && *p == '\0')
            return str.ptr;

        str ~= '\0';
        return str.ptr;
    }
    //const(C)[] -> C* or immutable(C)* or
    //C[] -> immutable(C)*
    else
    {
        auto copy = uninitializedArray!(Unqual!OutChar[])(str.length + 1);
        copy[0 .. $ - 1] = str[];
        copy[$ - 1] = '\0';

        return cast(P)copy.ptr;
    }
}

P toUTFz(P, S)(S str)
    if(isSomeString!S && isPointer!P && isSomeChar!(typeof(*P.init)) &&
       !is(Unqual!(typeof(*P.init)) == Unqual!(ElementEncodingType!S)))
//C1[], const(C1)[], or immutable(C1)[] -> C2*, const(C2)*, or immutable(C2)*
{
    auto retval = appender!(typeof(*P.init)[])();

    foreach(dchar c; str)
        retval.put(c);
    retval.put('\0');

    return cast(P)retval.data.ptr;
}

//Verify Examples.
unittest
{
    auto p1 = toUTFz!(char*)("hello world");
    auto p2 = toUTFz!(const(char)*)("hello world");
    auto p3 = toUTFz!(immutable(char)*)("hello world");
    auto p4 = toUTFz!(char*)("hello world"d);
    auto p5 = toUTFz!(const(wchar)*)("hello world");
    auto p6 = toUTFz!(immutable(dchar)*)("hello world"w);
}

unittest
{
    import core.exception;
    import std.algorithm;
    import std.metastrings;
    import std.typetuple;

    size_t zeroLen(C)(const(C)* ptr)
    {
        size_t len = 0;

        while(*ptr != '\0')
        {
            ++ptr;
            ++len;
        }

        return len;
    }

    foreach(S; TypeTuple!(string, wstring, dstring))
    {
        alias Unqual!(typeof(S.init[0])) C;

        auto s1 = to!S("hello\U00010143\u0100\U00010143");
        auto temp = new C[](s1.length + 1);
        temp[0 .. $ - 1] = s1[0 .. $];
        temp[$ - 1] = '\n';
        --temp.length;
        auto s2 = assumeUnique(temp);
        assert(s1 == s2);

        foreach(P; TypeTuple!(C*, const(C)*, immutable(C)*))
        {
            auto p1 = toUTFz!P(s1);
            assert(p1[0 .. s1.length] == s1);
            assert(p1[s1.length] == '\0');

            auto p2 = toUTFz!P(s2);
            assert(p2[0 .. s2.length] == s2);
            assert(p2[s2.length] == '\0');
        }
    }

    void test(P, S)(S s, size_t line = __LINE__)
    {
        auto p = toUTFz!P(s);
        immutable len = zeroLen(p);
        enforce(cmp(s, p[0 .. len]) == 0,
                new AssertError(Format!("Unit test failed: %s %s", P.stringof, S.stringof),
                                __FILE__, line));
    }

    foreach(P; TypeTuple!(wchar*, const(wchar)*, immutable(wchar)*,
                          dchar*, const(dchar)*, immutable(dchar)*))
    {
        test!P("hello\U00010143\u0100\U00010143");
    }

    foreach(P; TypeTuple!(char*, const(char)*, immutable(char)*,
                          dchar*, const(dchar)*, immutable(dchar)*))
    {
        test!P("hello\U00010143\u0100\U00010143"w);
    }

    foreach(P; TypeTuple!(char*, const(char)*, immutable(char)*,
                          wchar*, const(wchar)*, immutable(wchar)*))
    {
        test!P("hello\U00010143\u0100\U00010143"d);
    }

    foreach(S; TypeTuple!(char[], wchar[], dchar[],
                          const(char)[], const(wchar)[], const(dchar)[]))
    {
        auto s = to!S("hello\U00010143\u0100\U00010143");

        foreach(P; TypeTuple!(char*, wchar*, dchar*,
                              const(char)*, const(wchar)*, const(dchar)*,
                              immutable(char)*, immutable(wchar)*, immutable(dchar)*))
        {
            test!P(s);
        }
    }
}


/* ================================ tests ================================== */

unittest
{
    debug(utf) printf("utf.toUTF.unittest\n");

    string c;
    wstring w;
    dstring d;

    c = "hello";
    w = toUTF16(c);
    assert(w == "hello");
    d = toUTF32(c);
    assert(d == "hello");
    c = toUTF8(w);
    assert(c == "hello");
    d = toUTF32(w);
    assert(d == "hello");

    c = toUTF8(d);
    assert(c == "hello");
    w = toUTF16(d);
    assert(w == "hello");


    c = "hel\u1234o";
    w = toUTF16(c);
    assert(w == "hel\u1234o");
    d = toUTF32(c);
    assert(d == "hel\u1234o");

    c = toUTF8(w);
    assert(c == "hel\u1234o");
    d = toUTF32(w);
    assert(d == "hel\u1234o");

    c = toUTF8(d);
    assert(c == "hel\u1234o");
    w = toUTF16(d);
    assert(w == "hel\u1234o");


    c = "he\U0010AAAAllo";
    w = toUTF16(c);
    //foreach (wchar c; w) printf("c = x%x\n", c);
    //foreach (wchar c; cast(wstring)"he\U0010AAAAllo") printf("c = x%x\n", c);
    assert(w == "he\U0010AAAAllo");
    d = toUTF32(c);
    assert(d == "he\U0010AAAAllo");

    c = toUTF8(w);
    assert(c == "he\U0010AAAAllo");
    d = toUTF32(w);
    assert(d == "he\U0010AAAAllo");

    c = toUTF8(d);
    assert(c == "he\U0010AAAAllo");
    w = toUTF16(d);
    assert(w == "he\U0010AAAAllo");
}


/**
 * Returns the total number of code points encoded in a string.
 *
 * The input to this function MUST be validly encoded.
 *
 * Supercedes: This function supercedes $(D std.utf.toUCSindex()).
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *  s = the string to be counted
 */
@trusted
size_t count(E)(const(E)[] s) if (isSomeChar!E)
{
    static if (E.sizeof < 4)
    {
        return walkLength(s);
        //size_t result = 0;
        //while (!s.empty)
        //{
        //    ++result;
        //    s.popFront();
        //}
        //return result;
    }
    else
    {
        return s.length;
    }
}

unittest
{
    assert(count("") == 0);
    assert(count("a") == 1);
    assert(count("abc") == 3);
    assert(count("\u20AC100") == 4);
}


template softDeprec(string vers, string date, string oldFunc, string newFunc)
{
    enum softDeprec = Format!("Notice: As of Phobos %s, std.utf.%s has been scheduled " ~
                              "for deprecation in %s. Please use std.utf.%s instead.",
                              vers, oldFunc, date, newFunc);
}
