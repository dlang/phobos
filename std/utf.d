// Written in the D programming language.

/++
    Encode and decode UTF-8, UTF-16 and UTF-32 strings.

    UTF character support is restricted to
    $(D '\u0000' &lt;= character &lt;= '\U0010FFFF').

    See_Also:
        $(LINK2 http://en.wikipedia.org/wiki/Unicode, Wikipedia)<br>
        $(LINK http://www.cl.cam.ac.uk/~mgk25/unicode.html#utf-8)<br>
        $(LINK http://anubis.dkuug.dk/JTC1/SC2/WG2/docs/n1335)
    Macros:
        WIKI = Phobos/StdUtf

    Copyright: Copyright Digital Mars 2000 - 2012.
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(WEB digitalmars.com, Walter Bright) and Jonathan M Davis
    Source:    $(PHOBOSSRC std/_utf.d)
   +/
module std.utf;

import std.conv;       // to, assumeUnique
import std.exception;  // enforce, assumeUnique
import std.range;      // walkLength
import std.traits;     // isSomeChar, isSomeString
import std.typetuple;  // TypeTuple

//debug=utf;           // uncomment to turn on debugging printf's

debug (utf) import core.stdc.stdio : printf;

version(unittest)
{
    import core.exception;
    import std.string;
}


/++
    Exception thrown on errors in std.utf functions.
  +/
class UTFException : Exception
{
    uint[4] sequence;
    size_t  len;


    UTFException setSequence(uint[] data...) @safe pure nothrow
    {
        import std.algorithm;

        assert(data.length <= 4);

        len = min(data.length, 4);
        sequence[0 .. len] = data[0 .. len];

        return this;
    }


    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }


    this(string msg, size_t index, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        import std.string;
        super(msg ~ format(" (at index %s)", index), file, line, next);
    }


    override string toString()
    {
        import std.string;
        if(len == 0)
            return super.toString();

        string result = "Invalid UTF sequence:";

        foreach(i; sequence[0 .. len])
            result ~= format(" %02x", i);

        if(super.msg.length > 0)
        {
            result ~= " - ";
            result ~= super.msg;
        }

        return result;
    }
}


// Explicitly undocumented. It will be removed in November 2013.
deprecated("Please use std.utf.UTFException instead.") alias UTFException UtfException;


/++
    Returns whether $(D c) is a valid UTF-32 character.

    $(D '\uFFFE') and $(D '\uFFFF') are considered valid by $(D isValidDchar),
    as they are permitted for internal use by an application, but they are
    not allowed for interchange by the Unicode standard.
  +/
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


/++
    $(D stride) returns the length of the UTF-8 sequence starting at $(D index)
    in $(D str).

    $(D stride) works with both UTF-8 strings and ranges of $(D char). If no
    index is passed, then an input range will work, but if an index is passed,
    then a random-access range is required.

    $(D index) defaults to $(D 0) if none is passed.

    Returns:
        The number of bytes in the UTF-8 sequence.

    Throws:
        May throw a $(D UTFException) if $(D str[index]) is not the start of a
        valid UTF-8 sequence.

    Notes:
        $(D stride) will only analize the first $(D str[index]) element. It
        will not fully verify the validity of UTF-8 sequence, nor even verify
        the presence of the sequence: it will not actually guarantee that
        $(D index + stride(str, index) <= str.length).
  +/
uint stride(S)(auto ref S str, size_t index)
    if (is(S : const char[]) ||
        (isRandomAccessRange!S && is(Unqual!(ElementType!S) == char)))
{
    static if (is(typeof(str.length) : ulong))
        assert(index < str.length, "Past the end of the UTF-8 sequence");
    immutable c = str[index];

    if (c < 0x80)
        return 1;
    else
        return strideImpl(c, index);
}

/// Ditto
uint stride(S)(auto ref S str)
    if (is(S : const char[]) ||
        (isInputRange!S && is(Unqual!(ElementType!S) == char)))
{
    static if (is(S : const char[]))
        immutable c = str[0];
    else
        immutable c = str.front;

    if (c < 0x80)
        return 1;
    else
        return strideImpl(c, 0);
}

private uint strideImpl(char c, size_t index) @trusted pure
in { assert(c & 0x80); }
body
{
    import core.bitop;
    immutable msbs = 7 - bsr(~c);
    if (msbs < 2 || msbs > 6)
        throw new UTFException("Invalid UTF-8 sequence", index);
    return msbs;
}

unittest
{
    static void test(string s, dchar c, size_t i = 0, size_t line = __LINE__)
    {
        enforce(stride(s, i) == codeLength!char(c),
                new AssertError(format("Unit test failure string: %s", s), __FILE__, line));

        enforce(stride(RandomCU!char(s), i) == codeLength!char(c),
                new AssertError(format("Unit test failure range: %s", s), __FILE__, line));

        auto refRandom = new RefRandomCU!char(s);
        immutable randLen = refRandom.length;
        enforce(stride(refRandom, i) == codeLength!char(c),
                new AssertError(format("Unit test failure rand ref range: %s", s), __FILE__, line));
        enforce(refRandom.length == randLen,
                new AssertError(format("Unit test failure rand ref range length: %s", s), __FILE__, line));

        if (i == 0)
        {
            enforce(stride(s) == codeLength!char(c),
                    new AssertError(format("Unit test failure string 0: %s", s), __FILE__, line));

            enforce(stride(InputCU!char(s)) == codeLength!char(c),
                    new AssertError(format("Unit test failure range 0: %s", s), __FILE__, line));

            auto refBidir = new RefBidirCU!char(s);
            immutable bidirLen = refBidir.length;
            enforce(stride(refBidir) == codeLength!char(c),
                    new AssertError(format("Unit test failure bidir ref range code length: %s", s), __FILE__, line));
            enforce(refBidir.length == bidirLen,
                    new AssertError(format("Unit test failure bidir ref range length: %s", s), __FILE__, line));
        }
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

    foreach(S; TypeTuple!(char[], const char[], string))
    {
        enum str = to!S("hello world");
        static assert(isSafe!((){stride(str, 0);}));
        static assert(isSafe!((){stride(str);}));
        static assert((functionAttributes!((){stride(str, 0);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){stride(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/++
    $(D strideBack) returns the length of the UTF-8 sequence ending one code
    unit before $(D index) in $(D str).

    $(D strideBack) works with both UTF-8 strings and bidirectional ranges of
    $(D char). If no index is passed, then a bidirectional range will work, but
    if an index is passed, then a random-access range is required.

    $(D index) defaults to $(D str.length) if none is passed.

    Returns:
        The number of bytes in the UTF-8 sequence.

    Throws:
        May throw a $(D UTFException) if $(D str[index]) is not one past the
        end of a valid UTF-8 sequence.

    Notes:
        $(D strideBack) will not fully verify the validity of the UTF-8
        sequence. It will, however, guarantee that
        $(D index - stride(str, index)) is a valid index.
  +/
uint strideBack(S)(auto ref S str, size_t index)
    if (is(S : const char[]) ||
        (isRandomAccessRange!S && is(Unqual!(ElementType!S) == char)))
{
    static if (is(typeof(str.length) : ulong))
        assert(index <= str.length, "Past the end of the UTF-8 sequence");
    assert (index > 0, "Not the end of the UTF-8 sequence");

    if ((str[index-1] & 0b1100_0000) != 0b1000_0000)
        return 1;

    if (index >= 4) //single verification for most common case
    {
        foreach(i; TypeTuple!(2, 3, 4))
        {
            if ((str[index-i] & 0b1100_0000) != 0b1000_0000)
                return i;
        }
    }
    else
    {
        foreach(i; TypeTuple!(2, 3))
        {
            if (index >= i && (str[index-i] & 0b1100_0000) != 0b1000_0000)
                return i;
        }
    }
    throw new UTFException("Not the end of the UTF sequence", index);
}

/// Ditto
uint strideBack(S)(auto ref S str)
    if (is(S : const char[]) ||
       (isRandomAccessRange!S && hasLength!S && is(Unqual!(ElementType!S) == char)))
{
    return strideBack(str, str.length);
}

uint strideBack(S)(auto ref S str)
    if (isBidirectionalRange!S && is(Unqual!(ElementType!S) == char) && !isRandomAccessRange!S)
{
    assert(!str.empty, "Past the end of the UTF-8 sequence");
    auto temp = str.save;
    foreach(i; TypeTuple!(1, 2, 3, 4))
    {
        if ((temp.back & 0b1100_0000) != 0b1000_0000) return i;
        temp.popBack();
        if (temp.empty) break;
    }
    throw new UTFException("The last code unit is not the end of the UTF-8 sequence");
}

unittest
{
    static void test(string s, dchar c, size_t i = size_t.max, size_t line = __LINE__)
    {
        enforce(strideBack(s, i == size_t.max ? s.length : i) == codeLength!char(c),
                new AssertError(format("Unit test failure string: %s", s), __FILE__, line));

        enforce(strideBack(RandomCU!char(s), i == size_t.max ? s.length : i) == codeLength!char(c),
                new AssertError(format("Unit test failure range: %s", s), __FILE__, line));

        auto refRandom = new RefRandomCU!char(s);
        immutable randLen = refRandom.length;
        enforce(strideBack(refRandom, i == size_t.max ? s.length : i) == codeLength!char(c),
                new AssertError(format("Unit test failure rand ref range: %s", s), __FILE__, line));
        enforce(refRandom.length == randLen,
                new AssertError(format("Unit test failure rand ref range length: %s", s), __FILE__, line));

        if (i == size_t.max)
        {
            enforce(strideBack(s) == codeLength!char(c),
                    new AssertError(format("Unit test failure string code length: %s", s), __FILE__, line));

            enforce(strideBack(BidirCU!char(s)) == codeLength!char(c),
                    new AssertError(format("Unit test failure range code length: %s", s), __FILE__, line));

            auto refBidir = new RefBidirCU!char(s);
            immutable bidirLen = refBidir.length;
            enforce(strideBack(refBidir) == codeLength!char(c),
                    new AssertError(format("Unit test failure bidir ref range code length: %s", s), __FILE__, line));
            enforce(refBidir.length == bidirLen,
                    new AssertError(format("Unit test failure bidir ref range length: %s", s), __FILE__, line));
        }
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

    foreach(S; TypeTuple!(char[], const char[], string))
    {
        enum str = to!S("hello world");
        static assert(isSafe!((){strideBack(str, 0);}));
        static assert(isSafe!((){strideBack(str);}));
        static assert((functionAttributes!((){strideBack(str, 0);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){strideBack(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/++
    $(D stride) returns the length of the UTF-16 sequence starting at $(D index)
    in $(D str).

    $(D stride) works with both UTF-16 strings and ranges of $(D wchar). If no
    index is passed, then an input range will work, but if an index is passed,
    then a random-access range is required.

    $(D index) defaults to $(D 0) if none is passed.

    Returns:
        The number of bytes in the UTF-16 sequence.

    Throws:
        May throw a $(D UTFException) if $(D str[index]) is not the start of a
        valid UTF-16 sequence.

    Notes:
        $(D stride) will only analize the first $(D str[index]) element. It
        will not fully verify the validity of UTF-16 sequence, nor even verify
        the presence of the sequence: it will not actually guarantee that
        $(D index + stride(str, index) <= str.length).
  +/
uint stride(S)(auto ref S str, size_t index)
    if (is(S : const wchar[]) ||
        (isRandomAccessRange!S && is(Unqual!(ElementType!S) == wchar)))
{
    static if (is(typeof(str.length) : ulong))
        assert(index < str.length, "Past the end of the UTF-16 sequence");
    immutable uint u = str[index];
    return 1 + (u >= 0xD800 && u <= 0xDBFF);
}

/// Ditto
uint stride(S)(auto ref S str) @safe pure
    if (is(S : const wchar[]))
{
    return stride(str, 0);
}

uint stride(S)(auto ref S str)
    if (isInputRange!S && is(Unqual!(ElementType!S) == wchar))
{
    assert (!str.empty, "UTF-16 sequence is empty");
    immutable uint u = str.front;
    return 1 + (u >= 0xD800 && u <= 0xDBFF);
}

@trusted unittest
{
    static void test(wstring s, dchar c, size_t i = 0, size_t line = __LINE__)
    {
        enforce(stride(s, i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure string: %s", s), __FILE__, line));

        enforce(stride(RandomCU!wchar(s), i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure range: %s", s), __FILE__, line));

        auto refRandom = new RefRandomCU!wchar(s);
        immutable randLen = refRandom.length;
        enforce(stride(refRandom, i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure rand ref range: %s", s), __FILE__, line));
        enforce(refRandom.length == randLen,
                new AssertError(format("Unit test failure rand ref range length: %s", s), __FILE__, line));

        if (i == 0)
        {
            enforce(stride(s) == codeLength!wchar(c),
                    new AssertError(format("Unit test failure string 0: %s", s), __FILE__, line));

            enforce(stride(InputCU!wchar(s)) == codeLength!wchar(c),
                    new AssertError(format("Unit test failure range 0: %s", s), __FILE__, line));

            auto refBidir = new RefBidirCU!wchar(s);
            immutable bidirLen = refBidir.length;
            enforce(stride(refBidir) == codeLength!wchar(c),
                    new AssertError(format("Unit test failure bidir ref range code length: %s", s), __FILE__, line));
            enforce(refBidir.length == bidirLen,
                    new AssertError(format("Unit test failure bidir ref range length: %s", s), __FILE__, line));
        }
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

    foreach(S; TypeTuple!(wchar[], const wchar[], wstring))
    {
        enum str = to!S("hello world");
        static assert(isSafe!((){stride(str, 0);}));
        static assert(isSafe!((){stride(str);}));
        static assert((functionAttributes!((){stride(str, 0);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){stride(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/++
    $(D strideBack) returns the length of the UTF-16 sequence ending one code
    unit before $(D index) in $(D str).

    $(D strideBack) works with both UTF-16 strings and ranges of $(D wchar). If
    no index is passed, then a bidirectional range will work, but if an index is
    passed, then a random-access range is required.

    $(D index) defaults to $(D str.length) if none is passed.

    Returns:
        The number of bytes in the UTF-16 sequence.

    Throws:
        May throw a $(D UTFException) if $(D str[index]) is not one past the
        end of a valid UTF-16 sequence.

    Notes:
        $(D stride) will only analize the element at $(D str[index - 1])
        element. It will not fully verify the validity of UTF-16 sequence, nor
        even verify the presence of the sequence: it will not actually
        guarantee that $(D stride(str, index) <= index).
  +/
//UTF-16 is self synchronizing: The length of strideBack can be found from
//the value of a single wchar
uint strideBack(S)(auto ref S str, size_t index)
    if (is(S : const wchar[]) ||
        (isRandomAccessRange!S && is(Unqual!(ElementType!S) == wchar)))
{
    static if (is(typeof(str.length) : ulong))
        assert(index <= str.length, "Past the end of the UTF-16 sequence");
    assert (index > 0, "Not the end of a UTF-16 sequence");

    immutable c2 = str[index-1];
    return 1 + (0xDC00 <= c2 && c2 < 0xE000);
}

/// Ditto
uint strideBack(S)(auto ref S str)
    if (is(S : const wchar[]) ||
        (isBidirectionalRange!S && is(Unqual!(ElementType!S) == wchar)))
{
    assert (!str.empty, "UTF-16 sequence is empty");

    static if (is(S : const(wchar)[]))
        immutable c2 = str[$ - 1];
    else
        immutable c2 = str.back;

    return 1 + (0xDC00 <= c2 && c2 <= 0xE000);
}

unittest
{
    static void test(wstring s, dchar c, size_t i = size_t.max, size_t line = __LINE__)
    {
        enforce(strideBack(s, i == size_t.max ? s.length : i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure string: %s", s), __FILE__, line));

        enforce(strideBack(RandomCU!wchar(s), i == size_t.max ? s.length : i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure range: %s", s), __FILE__, line));

        auto refRandom = new RefRandomCU!wchar(s);
        immutable randLen = refRandom.length;
        enforce(strideBack(refRandom, i == size_t.max ? s.length : i) == codeLength!wchar(c),
                new AssertError(format("Unit test failure rand ref range: %s", s), __FILE__, line));
        enforce(refRandom.length == randLen,
                new AssertError(format("Unit test failure rand ref range length: %s", s), __FILE__, line));

        if (i == size_t.max)
        {
            enforce(strideBack(s) == codeLength!wchar(c),
                    new AssertError(format("Unit test failure string code length: %s", s), __FILE__, line));

            enforce(strideBack(BidirCU!wchar(s)) == codeLength!wchar(c),
                    new AssertError(format("Unit test failure range code length: %s", s), __FILE__, line));

            auto refBidir = new RefBidirCU!wchar(s);
            immutable bidirLen = refBidir.length;
            enforce(strideBack(refBidir) == codeLength!wchar(c),
                    new AssertError(format("Unit test failure bidir ref range code length: %s", s), __FILE__, line));
            enforce(refBidir.length == bidirLen,
                    new AssertError(format("Unit test failure bidir ref range length: %s", s), __FILE__, line));
        }
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

    foreach(S; TypeTuple!(wchar[], const wchar[], wstring))
    {
        enum str = to!S("hello world");
        static assert(isSafe!((){strideBack(str, 0);}));
        static assert(isSafe!((){strideBack(str);}));
        static assert((functionAttributes!((){strideBack(str, 0);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){strideBack(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/++
    $(D stride) returns the length of the UTF-32 sequence starting at $(D index)
    in $(D str).

    $(D stride) works with both UTF-32 strings and ranges of $(D dchar).

    Returns:
        The number of bytes in the UTF-32 sequence (always $(D 1)).

    Throws:
        Never.
  +/
uint stride(S)(auto ref S str, size_t index = 0)
    if (is(S : const dchar[]) ||
        (isInputRange!S && is(Unqual!(ElementEncodingType!S) == dchar)))
{
    static if (is(typeof(str.length) : ulong))
        assert(index < str.length, "Past the end of the UTF-32 sequence");
    else
        assert(!str.empty, "UTF-32 sequence is empty.");
    return 1;
}

unittest
{
    static void test(dstring s, dchar c, size_t i = 0, size_t line = __LINE__)
    {
        enforce(stride(s, i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure string: %s", s), __FILE__, line));

        enforce(stride(RandomCU!dchar(s), i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure range: %s", s), __FILE__, line));

        auto refRandom = new RefRandomCU!dchar(s);
        immutable randLen = refRandom.length;
        enforce(stride(refRandom, i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure rand ref range: %s", s), __FILE__, line));
        enforce(refRandom.length == randLen,
                new AssertError(format("Unit test failure rand ref range length: %s", s), __FILE__, line));

        if (i == 0)
        {
            enforce(stride(s) == codeLength!dchar(c),
                    new AssertError(format("Unit test failure string 0: %s", s), __FILE__, line));

            enforce(stride(InputCU!dchar(s)) == codeLength!dchar(c),
                    new AssertError(format("Unit test failure range 0: %s", s), __FILE__, line));

            auto refBidir = new RefBidirCU!dchar(s);
            immutable bidirLen = refBidir.length;
            enforce(stride(refBidir) == codeLength!dchar(c),
                    new AssertError(format("Unit test failure bidir ref range code length: %s", s), __FILE__, line));
            enforce(refBidir.length == bidirLen,
                    new AssertError(format("Unit test failure bidir ref range length: %s", s), __FILE__, line));
        }
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

    foreach(S; TypeTuple!(dchar[], const dchar[], dstring))
    {
        enum str = to!S("hello world");
        static assert(isSafe!((){stride(str, 0);}));
        static assert(isSafe!((){stride(str);}));
        static assert((functionAttributes!((){stride(str, 0);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){stride(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/++
    $(D strideBack) returns the length of the UTF-32 sequence ending one code
    unit before $(D index) in $(D str).

    $(D strideBack) works with both UTF-32 strings and ranges of $(D dchar). If
    no index is passed, then a bidirectional range will work, but if an index is
    passed, then a random-access range is required.

    $(D index) defaults to $(D str.length) if none is passed.

    Returns:
        The number of bytes in the UTF-32 sequence (always $(D 1)).

    Throws:
        Never.
  +/
uint strideBack(S)(auto ref S str, size_t index)
    if (isRandomAccessRange!S && is(Unqual!(ElementEncodingType!S) == dchar))
{
    static if (is(typeof(str.length) : ulong))
        assert(index <= str.length, "Past the end of the UTF-32 sequence");
    assert (index > 0, "Not the end of the UTF-32 sequence");
    return 1;
}

/// Ditto
uint strideBack(S)(auto ref S str)
    if (isBidirectionalRange!S && is(Unqual!(ElementEncodingType!S) == dchar))
{
    assert(!str.empty, "Empty UTF-32 sequence");
    return 1;
}

unittest
{
    static void test(dstring s, dchar c, size_t i = size_t.max, size_t line = __LINE__)
    {
        enforce(strideBack(s, i == size_t.max ? s.length : i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure string: %s", s), __FILE__, line));

        enforce(strideBack(RandomCU!dchar(s), i == size_t.max ? s.length : i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure range: %s", s), __FILE__, line));

        auto refRandom = new RefRandomCU!dchar(s);
        immutable randLen = refRandom.length;
        enforce(strideBack(refRandom, i == size_t.max ? s.length : i) == codeLength!dchar(c),
                new AssertError(format("Unit test failure rand ref range: %s", s), __FILE__, line));
        enforce(refRandom.length == randLen,
                new AssertError(format("Unit test failure rand ref range length: %s", s), __FILE__, line));

        if (i == size_t.max)
        {
            enforce(strideBack(s) == codeLength!dchar(c),
                    new AssertError(format("Unit test failure string code length: %s", s), __FILE__, line));

            enforce(strideBack(BidirCU!dchar(s)) == codeLength!dchar(c),
                    new AssertError(format("Unit test failure range code length: %s", s), __FILE__, line));

            auto refBidir = new RefBidirCU!dchar(s);
            immutable bidirLen = refBidir.length;
            enforce(strideBack(refBidir) == codeLength!dchar(c),
                    new AssertError(format("Unit test failure bidir ref range code length: %s", s), __FILE__, line));
            enforce(refBidir.length == bidirLen,
                    new AssertError(format("Unit test failure bidir ref range length: %s", s), __FILE__, line));
        }
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

    foreach(S; TypeTuple!(dchar[], const dchar[], dstring))
    {
        enum str = to!S("hello world");
        static assert(isSafe!((){strideBack(str, 0);}));
        static assert(isSafe!((){strideBack(str);}));
        static assert((functionAttributes!((){strideBack(str, 0);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){strideBack(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/++
    Given $(D index) into $(D str) and assuming that $(D index) is at the start
    of a UTF sequence, $(D toUCSindex) determines the number of UCS characters
    up to $(D index). So, $(D index) is the index of a code unit at the
    beginning of a code point, and the return value is how many code points into
    the string that that code point is.

Examples:
--------------------
assert(toUCSindex(`hello world`, 7) == 7);
assert(toUCSindex(`hello world`w, 7) == 7);
assert(toUCSindex(`hello world`d, 7) == 7);

assert(toUCSindex(`Ma Chérie`, 7) == 6);
assert(toUCSindex(`Ma Chérie`w, 7) == 7);
assert(toUCSindex(`Ma Chérie`d, 7) == 7);

assert(toUCSindex(`さいごの果実 / ミツバチと科学者`, 9) == 3);
assert(toUCSindex(`さいごの果実 / ミツバチと科学者`w, 9) == 9);
assert(toUCSindex(`さいごの果実 / ミツバチと科学者`d, 9) == 9);
--------------------
  +/
size_t toUCSindex(C)(const(C)[] str, size_t index) @safe pure
    if(isSomeChar!C)
{
    static if(is(Unqual!C == dchar))
        return index;
    else
    {
        size_t n = 0;
        size_t j = 0;

        for(; j < index; ++n)
            j += stride(str, j);

        if(j > index)
        {
            static if(is(Unqual!C == char))
                throw new UTFException("Invalid UTF-8 sequence", index);
            else
                throw new UTFException("Invalid UTF-16 sequence", index);
        }

        return n;
    }
}

unittest
{
    assert(toUCSindex(`hello world`, 7) == 7);
    assert(toUCSindex(`hello world`w, 7) == 7);
    assert(toUCSindex(`hello world`d, 7) == 7);

    assert(toUCSindex(`Ma Chérie`, 7) == 6);
    assert(toUCSindex(`Ma Chérie`w, 7) == 7);
    assert(toUCSindex(`Ma Chérie`d, 7) == 7);

    assert(toUCSindex(`さいごの果実 / ミツバチと科学者`, 9) == 3);
    assert(toUCSindex(`さいごの果実 / ミツバチと科学者`w, 9) == 9);
    assert(toUCSindex(`さいごの果実 / ミツバチと科学者`d, 9) == 9);
}


/++
    Given a UCS index $(D n) into $(D str), returns the UTF index.
    So, $(D n) is how many code points into the string the code point is, and
    the array index of the code unit is returned.

Examples:
--------------------
assert(toUTFindex(`hello world`, 7) == 7);
assert(toUTFindex(`hello world`w, 7) == 7);
assert(toUTFindex(`hello world`d, 7) == 7);

assert(toUTFindex(`Ma Chérie`, 6) == 7);
assert(toUTFindex(`Ma Chérie`w, 7) == 7);
assert(toUTFindex(`Ma Chérie`d, 7) == 7);

assert(toUTFindex(`さいごの果実 / ミツバチと科学者`, 3) == 9);
assert(toUTFindex(`さいごの果実 / ミツバチと科学者`w, 9) == 9);
assert(toUTFindex(`さいごの果実 / ミツバチと科学者`d, 9) == 9);
--------------------
  +/
size_t toUTFindex(in char[] str, size_t n) @safe pure
{
    size_t i;
    while (n--)
        i += stride(str, i);
    return i;
}

/// ditto
size_t toUTFindex(in wchar[] str, size_t n) @safe pure nothrow
{
    size_t i;

    while (n--)
    {
        wchar u = str[i];

        i += 1 + (u >= 0xD800 && u <= 0xDBFF);
    }

    return i;
}

/// ditto
size_t toUTFindex(in dchar[] str, size_t n) @safe pure nothrow
{
    return n;
}


/* =================== Decode ======================= */

/++
    Decodes and returns the code point starting at $(D str[index]). $(D index)
    is advanced to one past the decoded code point. If the code point is not
    well-formed, then a $(D UTFException) is thrown and $(D index) remains
    unchanged.

    decode will only work with strings and random access ranges of code units
    with length and slicing, whereas $(LREF decodeFront) will work with any
    input range of code units.

    Throws:
        $(LREF UTFException) if $(D str[index]) is not the start of a valid UTF
        sequence.
  +/
dchar decode(S)(auto ref S str, ref size_t index)
    if (!isSomeString!S &&
        isRandomAccessRange!S && hasSlicing!S && hasLength!S && isSomeChar!(ElementType!S))
in
{
    assert(index < str.length, "Attempted to decode past the end of a string");
}
out (result)
{
    assert(isValidDchar(result));
}
body
{
    if (str[index] < codeUnitLimit!S)
        return str[index++];
    return decodeImpl!true(str, index);
}

dchar decode(S)(auto ref S str, ref size_t index) @trusted pure
    if (isSomeString!S)
in
{
    assert(index < str.length, "Attempted to decode past the end of a string");
}
out (result)
{
    assert(isValidDchar(result));
}
body
{
    if (str[index] < codeUnitLimit!S)
        return str[index++];
    return decodeImpl!true(str, index);
}

/++
    $(D decodeFront) is a variant of $(LREF decode) which specifically decodes
    the first code point. Unlike $(LREF decode), $(D decodeFront) accepts any
    input range of code units (rather than just a string or random access
    range). It also takes the range by $(D ref) and pops off the elements as it
    decodes them. If $(D numCodeUnits) is passed in, it gets set to the number
    of code units which were in the code point which was decoded.

    Throws:
        $(LREF UTFException) if $(D str.front) is not the start of a valid UTF
        sequence. If an exception is thrown, then there is no guarantee as to
        the number of code units which were popped off, as it depends on the
        type of range being used and how many code units had to be popped off
        before the code point was determined to be invalid.
  +/
dchar decodeFront(S)(ref S str, out size_t numCodeUnits)
    if (!isSomeString!S && isInputRange!S && isSomeChar!(ElementType!S))
in
{
    assert(!str.empty);
}
out (result)
{
    assert(isValidDchar(result));
}
body
{
    immutable fst = str.front;

    if (fst < codeUnitLimit!S)
    {
        str.popFront();
        numCodeUnits = 1;
        return fst;
    }

    //@@@BUG@@@ 8521 forces canIndex to be done outside of decodeImpl, which
    //is undesirable, since not all overloads of decodeImpl need it. So, it
    //should be moved back into decodeImpl once bug# 8521 has been fixed.
    enum canIndex = isRandomAccessRange!S && hasSlicing!S && hasLength!S;
    immutable retval = decodeImpl!canIndex(str, numCodeUnits);

    // The other range types were already popped by decodeImpl.
    static if (isRandomAccessRange!S && hasSlicing!S && hasLength!S)
        str = str[numCodeUnits .. str.length];

    return retval;
}

dchar decodeFront(S)(ref S str, out size_t numCodeUnits) @trusted pure
    if (isSomeString!S)
in
{
    assert(!str.empty);
}
out (result)
{
    assert(isValidDchar(result));
}
body
{
    if (str[0] < codeUnitLimit!S)
    {
        numCodeUnits = 1;
        immutable retval = str[0];
        str = str[1 .. $];
        return retval;
    }

    immutable retval = decodeImpl!true(str, numCodeUnits);
    str = str[numCodeUnits .. $];
    return retval;
}

/++ Ditto +/
dchar decodeFront(S)(ref S str)
    if (isInputRange!S && isSomeChar!(ElementType!S))
{
    size_t numCodeUnits;
    return decodeFront(str, numCodeUnits);
}

// Gives the maximum value that a code unit for the given range type can hold.
private template codeUnitLimit(S)
   if (isSomeChar!(ElementEncodingType!S))
{
    static if (is(Unqual!(ElementEncodingType!S) == char))
        enum char codeUnitLimit = 0x80;
    else static if (is(Unqual!(ElementEncodingType!S) == wchar))
        enum wchar codeUnitLimit = 0xD800;
    else
        enum dchar codeUnitLimit = 0xD800;
}

/*
 * For strings, this function does its own bounds checking to give a
 * more useful error message when attempting to decode past the end of a string.
 * Subsequently it uses a pointer instead of an array to avoid
 * redundant bounds checking.
 */
private dchar decodeImpl(bool canIndex, S)(auto ref S str, ref size_t index)
    if (is(S : const char[]) || (isInputRange!S && is(Unqual!(ElementEncodingType!S) == char)))
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

    /* Dchar bitmask for different numbers of UTF-8 code units.
     */
    enum bitMask = [(1 << 7) - 1, (1 << 11) - 1, (1 << 16) - 1, (1 << 21) - 1];

    static if (is(S : const char[]))
        auto pstr = str.ptr + index;
    else static if (isRandomAccessRange!S && hasSlicing!S && hasLength!S)
        auto pstr = str[index .. str.length];
    else
        alias str pstr;

    //@@@BUG@@@ 8521 forces this to be done outside of decodeImpl
    //enum canIndex = is(S : const char[]) || (isRandomAccessRange!S && hasSlicing!S && hasLength!S);

    static if (canIndex)
    {
        immutable length = str.length - index;
        ubyte fst = pstr[0];
    }
    else
    {
        ubyte fst = pstr.front;
        pstr.popFront();
    }

    static if (canIndex)
    {
        static UTFException exception(S)(S str, string msg)
        {
            uint[4] sequence = void;
            size_t i;

            do
            {
                sequence[i] = str[i];
            } while (++i < str.length && i < 4 && (str[i] & 0xC0) == 0x80);

            return (new UTFException(msg, i)).setSequence(sequence[0 .. i]);
        }
    }

    UTFException invalidUTF()
    {
        static if (canIndex)
           return exception(pstr[0 .. length], "Invalid UTF-8 sequence");
        else
        {
            //We can't include the invalid sequence with input strings without
            //saving each of the code units along the way, and we can't do it with
            //forward ranges without saving the entire range. Both would incur a
            //cost for the decoding of every character just to provide a better
            //error message for the (hopefully) rare case when an invalid UTF-8
            //sequence is encountered, so we don't bother trying to include the
            //invalid sequence here, unlike with strings and sliceable ranges.
           return new UTFException("Invalid UTF-8 sequence");
        }
    }

    UTFException outOfBounds()
    {
        static if (canIndex)
           return exception(pstr[0 .. length], "Attempted to decode past the end of a string");
        else
           return new UTFException("Attempted to decode past the end of a string");
    }

    assert(fst & 0x80);
    ubyte tmp = void;
    dchar d = fst; // upper control bits are masked out later
    fst <<= 1;

    foreach(i; TypeTuple!(1, 2, 3))
    {

        static if (canIndex)
        {
            if (i == length)
                throw outOfBounds();
        }
        else
        {
            if (pstr.empty)
                throw outOfBounds();
        }

        static if (canIndex)
            tmp = pstr[i];
        else
        {
            tmp = pstr.front;
            pstr.popFront();
        }

        if ((tmp & 0xC0) != 0x80)
            throw invalidUTF();

        d = (d << 6) | (tmp & 0x3F);
        fst <<= 1;

        if (!(fst & 0x80)) // no more bytes
        {
            d &= bitMask[i]; // mask out control bits

            // overlong, could have been encoded with i bytes
            if ((d & ~bitMask[i - 1]) == 0)
                throw invalidUTF();

            // check for surrogates only needed for 3 bytes
            static if (i == 2)
            {
                if (!isValidDchar(d))
                    throw invalidUTF();
            }

            index += i + 1;
            return d;
        }
    }

    throw invalidUTF();
}

private dchar decodeImpl(bool canIndex, S)(auto ref S str, ref size_t index)
    if (is(S : const wchar[]) || (isInputRange!S && is(Unqual!(ElementEncodingType!S) == wchar)))
{
    static if (is(S : const wchar[]))
        auto pstr = str.ptr + index;
    else static if (isRandomAccessRange!S && hasSlicing!S && hasLength!S)
        auto pstr = str[index .. str.length];
    else
        alias str pstr;

    //@@@BUG@@@ 8521 forces this to be done outside of decodeImpl
    //enum canIndex = is(S : const wchar[]) || (isRandomAccessRange!S && hasSlicing!S && hasLength!S);

    static if (canIndex)
    {
        immutable length = str.length - index;
        uint u = pstr[0];
    }
    else
    {
        uint u = pstr.front;
        pstr.popFront();
    }

    UTFException exception(string msg)
    {
        static if (canIndex)
            return (new UTFException(msg)).setSequence(pstr[0]);
        else
            return new UTFException(msg);
    }

    string msg;
    assert(u >= 0xD800);

    if (u <= 0xDBFF)
    {
        static if (canIndex)
            immutable onlyOneCodeUnit = length == 1;
        else
            immutable onlyOneCodeUnit = pstr.empty;

        if (onlyOneCodeUnit)
            throw exception("surrogate UTF-16 high value past end of string");

        static if (canIndex)
            immutable uint u2 = pstr[1];
        else
        {
            immutable uint u2 = pstr.front;
            pstr.popFront();
        }

        if (u2 < 0xDC00 || u2 > 0xDFFF)
            throw exception("surrogate UTF-16 low value out of range");

        u = ((u - 0xD7C0) << 10) + (u2 - 0xDC00);
        index += 2;
    }
    else if (u >= 0xDC00 && u <= 0xDFFF)
        throw exception("unpaired surrogate UTF-16 value");
    else
        ++index;

    // Note: u+FFFE and u+FFFF are specifically permitted by the
    // Unicode standard for application internal use (see isValidDchar)

    return cast(dchar)u;
}

private dchar decodeImpl(bool canIndex, S)(auto ref S str, ref size_t index)
    if (is(S : const dchar[]) || (isInputRange!S && is(Unqual!(ElementEncodingType!S) == dchar)))
{
    static if (is(S : const dchar[]))
        auto pstr = str.ptr;
    else
        alias str pstr;

    static if (is(S : const dchar[]) || (isRandomAccessRange!S && hasSlicing!S && hasLength!S))
    {
        if (!isValidDchar(pstr[index]))
            throw (new UTFException("Invalid UTF-32 value")).setSequence(pstr[index]);
        return pstr[index++];
    }
    else
    {
        if (!isValidDchar(pstr.front))
            throw (new UTFException("Invalid UTF-32 value")).setSequence(pstr.front);
        ++index;
        immutable retval = pstr.front;
        pstr.popFront();
        return retval;
    }
}

version(unittest) private void testDecode(R)(R range,
                                             size_t index,
                                             dchar expectedChar,
                                             size_t expectedIndex,
                                             size_t line = __LINE__)
{
    static if(hasLength!R)
        immutable lenBefore = range.length;

    static if (isRandomAccessRange!R)
    {
        {
            immutable result = decode(range, index);
            enforce(result == expectedChar,
                    new AssertError(format("decode: Wrong character: %s", result), __FILE__, line));
            enforce(index == expectedIndex,
                    new AssertError(format("decode: Wrong index: %s", index), __FILE__, line));
            static if(hasLength!R)
            {
                enforce(range.length == lenBefore,
                        new AssertError(format("decode: length changed: %s", range.length), __FILE__, line));
            }
        }
    }
}

version(unittest) private void testDecodeFront(R)(ref R range,
                                                  dchar expectedChar,
                                                  size_t expectedNumCodeUnits,
                                                  size_t line = __LINE__)
{
    static if(hasLength!R)
        immutable lenBefore = range.length;

    size_t numCodeUnits;
    immutable result = decodeFront(range, numCodeUnits);
    enforce(result == expectedChar,
            new AssertError(format("decodeFront: Wrong character: %s", result), __FILE__, line));
    enforce(numCodeUnits == expectedNumCodeUnits,
            new AssertError(format("decodeFront: Wrong numCodeUnits: %s", numCodeUnits), __FILE__, line));

    static if (hasLength!R)
    {
        enforce(range.length == lenBefore - numCodeUnits,
                new AssertError(format("decodeFront: wrong length: %s", range.length), __FILE__, line));
    }
}

version(unittest) private void testBothDecode(R)(R range,
                                                 dchar expectedChar,
                                                 size_t expectedIndex,
                                                 size_t line = __LINE__)
{
    testDecode(range, 0, expectedChar, expectedIndex, line);
    testDecodeFront(range, expectedChar, expectedIndex, line);
}

version(unittest) private void testBadDecode(R)(R range, size_t index, size_t line = __LINE__)
{
    immutable initialIndex = index;

    static if (hasLength!R)
        immutable lenBefore = range.length;

    static if (isRandomAccessRange!R)
    {
        assertThrown!UTFException(decode(range, index), null, __FILE__, line);
        enforce(index == initialIndex,
                new AssertError(format("decode: Wrong index: %s", index), __FILE__, line));
        static if (hasLength!R)
        {
            enforce(range.length == lenBefore,
                    new AssertError(format("decode: length changed:", range.length), __FILE__, line));
        }
    }

    if (initialIndex == 0)
        assertThrown!UTFException(decodeFront(range, index), null, __FILE__, line);
}

unittest
{
    foreach (S; TypeTuple!(to!string, InputCU!char, RandomCU!char,
                           (string s) => new RefBidirCU!char(s),
                           (string s) => new RefRandomCU!char(s)))
    {
        debug(utf) printf("utf.decode.unittest\n");
        enum sHasLength = hasLength!(typeof(S("abcd")));

        {
            auto range = S("abcd");
            testDecode(range, 0, 'a', 1);
            testDecode(range, 1, 'b', 2);
            testDecodeFront(range, 'a', 1);
            testDecodeFront(range, 'b', 1);
            assert(decodeFront(range) == 'c');
            assert(decodeFront(range) == 'd');
        }

        {
            auto range = S("ウェブサイト");
            testDecode(range, 0, 'ウ', 3);
            testDecode(range, 3, 'ェ', 6);
            testDecodeFront(range, 'ウ', 3);
            testDecodeFront(range, 'ェ', 3);
            assert(decodeFront(range) == 'ブ');
            assert(decodeFront(range) == 'サ');
        }

        testBothDecode(S("\xC2\xA9"), '\u00A9', 2);
        testBothDecode(S("\xE2\x89\xA0"), '\u2260', 3);

        foreach (str; ["\xE2\x89", // too short
                       "\xC0\x8A",
                       "\xE0\x80\x8A",
                       "\xF0\x80\x80\x8A",
                       "\xF8\x80\x80\x80\x8A",
                       "\xFC\x80\x80\x80\x80\x8A"])
        {
            testBadDecode(S(str), 0);
            testBadDecode(S(str), 1);
        }

        //Invalid UTF-8 sequence where the first code unit is valid.
        testBothDecode(S("\xEF\xBF\xBE"), cast(dchar)0xFFFE, 3);
        testBothDecode(S("\xEF\xBF\xBF"), cast(dchar)0xFFFF, 3);

        //Invalid UTF-8 sequence where the first code unit isn't valid.
        testBadDecode(S("\xED\xA0\x80"), 0);
        testBadDecode(S("\xED\xAD\xBF"), 0);
        testBadDecode(S("\xED\xAE\x80"), 0);
        testBadDecode(S("\xED\xAF\xBF"), 0);
        testBadDecode(S("\xED\xB0\x80"), 0);
        testBadDecode(S("\xED\xBE\x80"), 0);
        testBadDecode(S("\xED\xBF\xBF"), 0);
    }
}

unittest
{
    foreach (S; TypeTuple!(to!wstring, InputCU!wchar, RandomCU!wchar,
                           (wstring s) => new RefBidirCU!wchar(s),
                           (wstring s) => new RefRandomCU!wchar(s)))
    {
        testBothDecode(S([cast(wchar)0x1111]), cast(dchar)0x1111, 1);
        testBothDecode(S([cast(wchar)0xD800, cast(wchar)0xDC00]), cast(dchar)0x10000, 2);
        testBothDecode(S([cast(wchar)0xDBFF, cast(wchar)0xDFFF]), cast(dchar)0x10FFFF, 2);
        testBothDecode(S([cast(wchar)0xFFFE]), cast(dchar)0xFFFE, 1);
        testBothDecode(S([cast(wchar)0xFFFF]), cast(dchar)0xFFFF, 1);

        testBadDecode(S([ cast(wchar)0xD801 ]), 0);
        testBadDecode(S([ cast(wchar)0xD800, cast(wchar)0x1200 ]), 0);

        {
            auto range = S("ウェブサイト");
            testDecode(range, 0, 'ウ', 1);
            testDecode(range, 1, 'ェ', 2);
            testDecodeFront(range, 'ウ', 1);
            testDecodeFront(range, 'ェ', 1);
            assert(decodeFront(range) == 'ブ');
            assert(decodeFront(range) == 'サ');
        }
    }

    foreach (S; TypeTuple!(to!wstring, RandomCU!wchar, (wstring s) => new RefRandomCU!wchar(s)))
    {
        auto str = S([cast(wchar)0xD800, cast(wchar)0xDC00,
                      cast(wchar)0x1400,
                      cast(wchar)0xDAA7, cast(wchar)0xDDDE]);
        testDecode(str, 0, cast(dchar)0x10000, 2);
        testDecode(str, 2, cast(dchar)0x1400, 3);
        testDecode(str, 3, cast(dchar)0xB9DDE, 5);
    }
}

unittest
{
    foreach(S; TypeTuple!(to!dstring, RandomCU!dchar, InputCU!dchar,
                          (dstring s) => new RefBidirCU!dchar(s),
                          (dstring s) => new RefRandomCU!dchar(s)))
    {
        testBothDecode(S([cast(dchar)0x1111]), cast(dchar)0x1111, 1);
        testBothDecode(S([cast(dchar)0x10000]), cast(dchar)0x10000, 1);
        testBothDecode(S([cast(dchar)0x10FFFF]), cast(dchar)0x10FFFF, 1);
        testBothDecode(S([cast(dchar)0xFFFE]), cast(dchar)0xFFFE, 1);
        testBothDecode(S([cast(dchar)0xFFFF]), cast(dchar)0xFFFF, 1);

        testBadDecode(S([cast(dchar)0xD800]), 0);
        testBadDecode(S([cast(dchar)0xDFFE]), 0);
        testBadDecode(S([cast(dchar)0x110000]), 0);

        {
            auto range = S("ウェブサイト");
            testDecode(range, 0, 'ウ', 1);
            testDecode(range, 1, 'ェ', 2);
            testDecodeFront(range, 'ウ', 1);
            testDecodeFront(range, 'ェ', 1);
            assert(decodeFront(range) == 'ブ');
            assert(decodeFront(range) == 'サ');
        }
    }

    foreach (S; TypeTuple!(to!dstring, RandomCU!dchar, (dstring s) => new RefRandomCU!dchar(s)))
    {
        auto str = S([cast(dchar)0x10000, cast(dchar)0x1400, cast(dchar)0xB9DDE]);
        testDecode(str, 0, 0x10000, 1);
        testDecode(str, 1, 0x1400, 2);
        testDecode(str, 2, 0xB9DDE, 3);
    }
}

unittest
{
    foreach(S; TypeTuple!(char[], const(char)[], string,
                          wchar[], const(wchar)[], wstring,
                          dchar[], const(dchar)[], dstring))
    {
        static assert(isSafe!((){S str; size_t i = 0; decode(str, i);}));
        static assert(isSafe!((){S str; size_t i = 0; decodeFront(str, i);}));
        static assert(isSafe!((){S str; decodeFront(str);}));
        static assert((functionAttributes!((){S str; size_t i = 0; decode(str, i);}) & FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){S str; size_t i = 0; decodeFront(str, i);}) &
                      FunctionAttribute.pure_) != 0);
        static assert((functionAttributes!((){S str; decodeFront(str);}) & FunctionAttribute.pure_) != 0);
    }
}


/* =================== Encode ======================= */

/++
    Encodes $(D c) into the static array, $(D buf), and returns the actual
    length of the encoded character (a number between $(D 1) and $(D 4) for
    $(D char[4]) buffers and a number between $(D 1) and $(D 2) for
    $(D wchar[2]) buffers).

    Throws:
        $(D UTFException) if $(D c) is not a valid UTF code point.
  +/
size_t encode(ref char[4] buf, dchar c) @safe pure
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
            throw (new UTFException("Encoding a surrogate code point in UTF-8")).setSequence(c);

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
    throw (new UTFException("Encoding an invalid code point in UTF-8")).setSequence(c);
}

unittest
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

    assertThrown!UTFException(encode(buf, cast(dchar)0xD800));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0x110000));
}


/// Ditto
size_t encode(ref wchar[2] buf, dchar c) @safe pure
{
    if (c <= 0xFFFF)
    {
        if (0xD800 <= c && c <= 0xDFFF)
            throw (new UTFException("Encoding an isolated surrogate code point in UTF-16")).setSequence(c);

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
    throw (new UTFException("Encoding an invalid code point in UTF-16")).setSequence(c);
}

unittest
{
    wchar[2] buf;

    assert(encode(buf, '\u0000') == 1 && buf[0 .. 1] == "\u0000");
    assert(encode(buf, '\uD7FF') == 1 && buf[0 .. 1] == "\uD7FF");
    assert(encode(buf, '\uE000') == 1 && buf[0 .. 1] == "\uE000");
    assert(encode(buf, 0xFFFE) == 1 && buf[0] == 0xFFFE);
    assert(encode(buf, 0xFFFF) == 1 && buf[0] == 0xFFFF);
    assert(encode(buf, '\U00010000') == 2 && buf[0 .. 2] == "\U00010000");
    assert(encode(buf, '\U0010FFFF') == 2 && buf[0 .. 2] == "\U0010FFFF");

    assertThrown!UTFException(encode(buf, cast(dchar)0xD800));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0x110000));
}


/++
    Encodes $(D c) in $(D str)'s encoding and appends it to $(D str).

    Throws:
        $(D UTFException) if $(D c) is not a valid UTF code point.
  +/
void encode(ref char[] str, dchar c) @safe pure
{
    char[] r = str;

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
                throw (new UTFException("Encoding a surrogate code point in UTF-8")).setSequence(c);

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
            throw (new UTFException("Encoding an invalid code point in UTF-8")).setSequence(c);
        }
        r ~= buf[0 .. L];
    }
    str = r;
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

unittest
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

    assertThrown!UTFException(encode(buf, cast(dchar)0xD800));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0x110000));
}

/// ditto
void encode(ref wchar[] str, dchar c) @safe pure
{
    wchar[] r = str;

    if (c <= 0xFFFF)
    {
        if (0xD800 <= c && c <= 0xDFFF)
            throw (new UTFException("Encoding an isolated surrogate code point in UTF-16")).setSequence(c);

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
        throw (new UTFException("Encoding an invalid code point in UTF-16")).setSequence(c);
    }

    str = r;
}

unittest
{
    wchar[] buf;

    encode(buf, '\u0000'); assert(buf[0] == '\u0000');
    encode(buf, '\uD7FF'); assert(buf[1] == '\uD7FF');
    encode(buf, '\uE000'); assert(buf[2] == '\uE000');
    encode(buf, 0xFFFE); assert(buf[3] == 0xFFFE);
    encode(buf, 0xFFFF); assert(buf[4] == 0xFFFF);
    encode(buf, '\U00010000'); assert(buf[5 .. $] == "\U00010000");
    encode(buf, '\U0010FFFF'); assert(buf[7 .. $] == "\U0010FFFF");

    assertThrown!UTFException(encode(buf, cast(dchar)0xD800));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0x110000));
}

/// ditto
void encode(ref dchar[] str, dchar c) @safe pure
{
    if ((0xD800 <= c && c <= 0xDFFF) || 0x10FFFF < c)
        throw (new UTFException("Encoding an invalid code point in UTF-32")).setSequence(c);

    assert(isValidDchar(c));
    str ~= c;
}

unittest
{
    dchar[] buf;

    encode(buf, '\u0000'); assert(buf[0] == '\u0000');
    encode(buf, '\uD7FF'); assert(buf[1] == '\uD7FF');
    encode(buf, '\uE000'); assert(buf[2] == '\uE000');
    encode(buf, 0xFFFE ); assert(buf[3] == 0xFFFE);
    encode(buf, 0xFFFF ); assert(buf[4] == 0xFFFF);
    encode(buf, '\U0010FFFF'); assert(buf[5] == '\U0010FFFF');

    assertThrown!UTFException(encode(buf, cast(dchar)0xD800));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDBFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDC00));
    assertThrown!UTFException(encode(buf, cast(dchar)0xDFFF));
    assertThrown!UTFException(encode(buf, cast(dchar)0x110000));
}


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
ubyte codeLength(C)(dchar c) @safe pure nothrow
    if(isSomeChar!C)
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


/++
    Returns the number of code units that are required to encode $(D str)
    in a string whose character type is $(D C). This is particularly useful
    when slicing one string with the length of another and the two string
    types use different character types.

Examples:
------
assert(codeLength!char("hello world") ==
       to!string("hello world").length);
assert(codeLength!wchar("hello world") ==
       to!wstring("hello world").length);
assert(codeLength!dchar("hello world") ==
       to!dstring("hello world").length);

assert(codeLength!char(`プログラミング`) ==
       to!string(`プログラミング`).length);
assert(codeLength!wchar(`プログラミング`) ==
       to!wstring(`プログラミング`).length);
assert(codeLength!dchar(`プログラミング`) ==
       to!dstring(`プログラミング`).length);

string haystack = `Être sans la verité, ça, ce ne serait pas bien.`;
wstring needle = `Être sans la verité`;
assert(haystack[codeLength!char(needle) .. $] ==
       `, ça, ce ne serait pas bien.`);
------
  +/
size_t codeLength(C, InputRange)(InputRange input)
	if(isInputRange!InputRange && is(ElementType!InputRange : dchar))
{
	alias Unqual!(ElementEncodingType!InputRange) EncType;
	static if(isSomeString!InputRange && is(EncType == C) && is(typeof(input.length)))
		return input.length;
	else
	{
        size_t total = 0;

        foreach(dchar c; input)
            total += codeLength!C(c);

        return total;
	}
}
   

//Verify Examples.
unittest
{
    assert(codeLength!char("hello world") ==
           to!string("hello world").length);
    assert(codeLength!wchar("hello world") ==
           to!wstring("hello world").length);
    assert(codeLength!dchar("hello world") ==
           to!dstring("hello world").length);

    assert(codeLength!char(`プログラミング`) ==
           to!string(`プログラミング`).length);
    assert(codeLength!wchar(`プログラミング`) ==
           to!wstring(`プログラミング`).length);
    assert(codeLength!dchar(`プログラミング`) ==
           to!dstring(`プログラミング`).length);

    string haystack = `Être sans la verité, ça, ce ne serait pas bien.`;
    wstring needle = `Être sans la verité`;
    assert(haystack[codeLength!char(needle) .. $] ==
           `, ça, ce ne serait pas bien.`);
}

unittest
{
    foreach(S; TypeTuple!(char[], const char[], string,
                          wchar[], const wchar[], wstring,
                          dchar[], const dchar[], dstring))
    {
        foreach(C; TypeTuple!(char, wchar, dchar))
        {
            assert(codeLength!C(to!S("Walter Bright")) == to!(C[])("Walter Bright").length);
            assert(codeLength!C(to!S(`言語`)) == to!(C[])(`言語`).length);
            assert(codeLength!C(to!S(`ウェブサイト@La_Verité.com`)) ==
                   to!(C[])(`ウェブサイト@La_Verité.com`).length);
			assert(codeLength!C(to!S(`ウェブサイト@La_Verité.com`).filter!(x => true)()) ==
                   to!(C[])(`ウェブサイト@La_Verité.com`).length);
        }
    }
}


/* =================== Validation ======================= */

/++
    Checks to see if $(D str) is well-formed unicode or not.

    Throws:
        $(D UTFException) if $(D str) is not well-formed.
  +/
void validate(S)(in S str) @safe pure
    if(isSomeString!S)
{
    immutable len = str.length;
    for (size_t i = 0; i < len; )
    {
        decode(str, i);
    }
}


/* =================== Conversion to UTF8 ======================= */

pure
{

char[] toUTF8(out char[4] buf, dchar c) nothrow @safe
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
string toUTF8(in char[] s) @safe
{
    validate(s);
    return s.idup;
}

/// ditto
string toUTF8(in wchar[] s) @trusted
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
string toUTF8(in dchar[] s) @trusted
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

wchar[] toUTF16(ref wchar[2] buf, dchar c) nothrow @safe
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
wstring toUTF16(in char[] s) @trusted
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
wstring toUTF16(in wchar[] s) @safe
{
    validate(s);
    return s.idup;
}

/// ditto
pure wstring toUTF16(in dchar[] s) @trusted
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


/* =================== Conversion to UTF32 ======================= */

/*****
 * Encodes string $(D_PARAM s) into UTF-32 and returns the encoded string.
 */
dstring toUTF32(in char[] s) @trusted
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
dstring toUTF32(in wchar[] s) @trusted
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
dstring toUTF32(in dchar[] s) @safe
{
    validate(s);
    return s.idup;
}

} // Convert functions are @safe


/* =================== toUTFz ======================= */

/++
    Returns a C-style zero-terminated string equivalent to $(D str). $(D str)
    must not contain embedded $(D '\0')'s as any C function will treat the first
    $(D '\0') that it sees as the end of the string. If $(D str.empty) is
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
template toUTFz(P)
{
    P toUTFz(S)(S str) @system
    {
        return toUTFzImpl!(P, S)(str);
    }
}

/++ Ditto +/
template toUTFz(P, S)
{
    P toUTFz(S str) @system
    {
        return toUTFzImpl!(P, S)(str);
    }
}

private P toUTFzImpl(P, S)(S str) @system
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
        return toUTFzImpl!(P, const(C)[])(cast(const(C)[])str);
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

        return toUTFzImpl!(P, const(C)[])(cast(const(C)[])str);
    }
}

private P toUTFzImpl(P, S)(S str) @system
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

private P toUTFzImpl(P, S)(S str)
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
        alias Unqual!(ElementEncodingType!S) C;

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
                new AssertError(format("Unit test failed: %s %s", P.stringof, S.stringof),
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


/++
    $(D toUTF16z) is a convenience function for $(D toUTFz!(const(wchar)*)).

    Encodes string $(D s) into UTF-16 and returns the encoded string.
    $(D toUTF16z) is suitable for calling the 'W' functions in the Win32 API
    that take an $(D LPWSTR) or $(D LPCWSTR) argument.
  +/
const(wchar)* toUTF16z(C)(const(C)[] str)
    if(isSomeChar!C)
{
    return toUTFz!(const(wchar)*)(str);
}

unittest
{
    import std.typetuple;

    //toUTFz is already thoroughly tested, so this will just verify that
    //toUTF16z compiles properly for the various string types.
    foreach(S; TypeTuple!(string, wstring, dstring))
        static assert(__traits(compiles, toUTF16z(to!S("hello world"))));
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


/++
    Returns the total number of code points encoded in $(D str).

    Supercedes: This function supercedes $(LREF toUCSindex).

    Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252

    Throws:
        $(D UTFException) if $(D str) is not well-formed.
  +/
size_t count(C)(const(C)[] str) @trusted pure
    if(isSomeChar!C)
{
    return walkLength(str);
}

unittest
{
    assert(count("") == 0);
    assert(count("a") == 1);
    assert(count("abc") == 3);
    assert(count("\u20AC100") == 4);
}


// Ranges of code units for testing.
version(unittest)
{
    struct InputCU(C)
    {
        @property bool empty() { return _str.empty; }
        @property C front() { return _str[0]; }
        void popFront() { _str = _str[1 .. $]; }

        this(inout(C)[] str)
        {
            _str = to!(C[])(str);
        }

        C[] _str;
    }

    struct BidirCU(C)
    {
        @property bool empty() { return _str.empty; }
        @property C front() { return _str[0]; }
        void popFront() { _str = _str[1 .. $]; }
        @property C back() { return _str[$ - 1]; }
        void popBack() { _str = _str[0 .. $ - 1]; }
        @property auto save() { return BidirCU(_str); }
        @property size_t length() { return _str.length; }

        this(inout(C)[] str)
        {
            _str = to!(C[])(str);
        }

        C[] _str;
    }

    struct RandomCU(C)
    {
        @property bool empty() { return _str.empty; }
        @property C front() { return _str[0]; }
        void popFront() { _str = _str[1 .. $]; }
        @property C back() { return _str[$ - 1]; }
        void popBack() { _str = _str[0 .. $ - 1]; }
        @property auto save() { return RandomCU(_str); }
        @property size_t length() { return _str.length; }
        C opIndex(size_t i) { return _str[i]; }
        auto opSlice(size_t i, size_t j) { return RandomCU(_str[i .. j]); }

        this(inout(C)[] str)
        {
            _str = to!(C[])(str);
        }

        C[] _str;
    }

    class RefBidirCU(C)
    {
        @property bool empty() { return _str.empty; }
        @property C front() { return _str[0]; }
        void popFront() { _str = _str[1 .. $]; }
        @property C back() { return _str[$ - 1]; }
        void popBack() { _str = _str[0 .. $ - 1]; }
        @property auto save() { return new RefBidirCU(_str); }
        @property size_t length() { return _str.length; }

        this(inout(C)[] str)
        {
            _str = to!(C[])(str);
        }

        C[] _str;
    }

    class RefRandomCU(C)
    {
        @property bool empty() { return _str.empty; }
        @property C front() { return _str[0]; }
        void popFront() { _str = _str[1 .. $]; }
        @property C back() { return _str[$ - 1]; }
        void popBack() { _str = _str[0 .. $ - 1]; }
        @property auto save() { return new RefRandomCU(_str); }
        @property size_t length() { return _str.length; }
        C opIndex(size_t i) { return _str[i]; }
        auto opSlice(size_t i, size_t j) { return new RefRandomCU(_str[i .. j]); }

        this(inout(C)[] str)
        {
            _str = to!(C[])(str);
        }

        C[] _str;
    }
}
