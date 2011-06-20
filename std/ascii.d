// Written in the D programming language.

/++
    Simple ASCII character classification functions.
    For Unicode classification, see $(LINK2 std_uni.html, std.uni).
    References:
        $(LINK2 http://www.digitalmars.com/d/ascii-table.html, ASCII Table),
        $(LINK2 http://en.wikipedia.org/wiki/Ascii, Wikipedia)
    Macros:
        WIKI=Phobos/StdASCII

    Copyright: Copyright 2000 -
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(WEB digitalmars.com, Walter Bright) and Jonathan M Davis
    Source:    $(PHOBOSSRC std/_ascii.d)
  +/
module std.ascii;

version(unittest) import std.range;


immutable hexDigits      = "0123456789ABCDEF";           /// 0..9A..F
immutable fullHexDigits  = "0123456789ABCDEFabcdef";     /// 0..9A..Fa..f
immutable digits         = "0123456789";                 /// 0..9
immutable octalDigits    = "01234567";                   /// 0..7
immutable lowercase      = "abcdefghijklmnopqrstuvwxyz"; /// a..z
immutable letters        = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ~
                           "abcdefghijklmnopqrstuvwxyz"; /// A..Za..z
immutable uppercase      = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"; /// A..Z
immutable whitespace     = " \t\v\r\n\f";                /// ASCII whitespace


version(Windows)
{
    /// Newline sequence for this system.
    immutable newline = "\r\n";
}
else version(Posix)
{
    /// Newline sequence for this system.
    immutable newline = "\n";
}
else
    static assert(0, "Unsupported OS");


/++
    Returns whether $(D c) is a letter or a number (0..9, a..z, A..Z).
  +/
bool isAlphaNum(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & (_ALP|_DIG)) : false;
}

unittest
{
    foreach(c; chain(digits, octalDigits, fullHexDigits, letters, lowercase, uppercase))
        assert(isAlphaNum(c));

    foreach(c; whitespace)
        assert(!isAlphaNum(c));
}


/++
    Returns whether $(D c) is an ASCII letter (A..Z, a..z).
  +/
bool isAlpha(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _ALP) : false;
}

unittest
{
    foreach(c; chain(letters, lowercase, uppercase))
        assert(isAlpha(c));

    foreach(c; chain(digits, octalDigits, whitespace))
        assert(!isAlpha(c));
}


/++
    Returns whether $(D c) is a lowercase ASCII letter (a..z).
  +/
bool isAsciiLower(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _LC) : false;
}

unittest
{
    foreach(c; lowercase)
        assert(isAsciiLower(c));

    foreach(c; chain(digits, uppercase, whitespace))
        assert(!isAsciiLower(c));
}


/++
    Returns whether $(D c) is an uppercase ASCII letter (A..Z).
  +/
bool isAsciiUpper(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _UC) : false;
}

unittest
{
    foreach(c; uppercase)
        assert(isAsciiUpper(c));

    foreach(c; chain(digits, lowercase, whitespace))
        assert(!isAsciiUpper(c));
}


/++
    Returns whether $(D c) is a digit (0..9).
  +/
bool isDigit(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _DIG) : false;
}

unittest
{
    foreach(c; digits)
        assert(isDigit(c));

    foreach(c; chain(letters, whitespace))
        assert(!isDigit(c));
}


/++
    Returns whether $(D c) is a digit in base 8 (0..7).
  +/
bool isOctalDigit(dchar c) @safe pure nothrow
{
    return c >= '0' && c <= '7';
}

unittest
{
    foreach(c; octalDigits)
        assert(isOctalDigit(c));

    foreach(c; chain(letters, ['8', '9'], whitespace))
        assert(!isOctalDigit(c));
}


/++
    Returns whether $(D c) is a digit in base 16 (0..9, A..F, a..f).
  +/
bool isHexDigit(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _HEX) : false;
}

unittest
{
    foreach(c; fullHexDigits)
        assert(isHexDigit(c));

    foreach(c; chain(lowercase[6 .. $], uppercase[6 .. $], whitespace))
        assert(!isHexDigit(c));
}


/++
    Whether or not $(D c) is a whitespace character. That includes the space,
    tab, vertical tab, form feed, carriage return, and linefeed characters.
  +/
bool isAsciiWhite(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _SPC) : false;
}

unittest
{
    foreach(c; whitespace)
        assert(isAsciiWhite(c));

    foreach(c; chain(digits, letters))
        assert(!isAsciiWhite(c));
}


/++
    Returns whether $(D c) is a control character.
  +/
bool isControl(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _CTL) : false;
}

unittest
{
    foreach(dchar c; iota(0, 32))
        assert(isControl(c));
    assert(isControl(127));

    foreach(c; chain(digits, letters, [' ']))
        assert(!isControl(c));
}


/++
    Whether or not $(D c) is a punctuation character. That includes all ASCII
    characters which are not control characters, letters, digits, or whitespace.
  +/
bool isPunct(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _PNC) : false;
}

unittest
{
    foreach(dchar c; iota(0, 128))
    {
        if(isControl(c) || isAlphaNum(c) || c == ' ')
            assert(!isPunct(c));
        else
            assert(isPunct(c));
    }
}


/++
    Whether or not $(D c) is a printable character other than the space
    character.
  +/
bool isGraph(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & (_ALP|_DIG|_PNC)) : false;
}

unittest
{
    foreach(dchar c; iota(0, 128))
    {
        if(isControl(c) || c == ' ')
            assert(!isGraph(c));
        else
            assert(isGraph(c));
    }
}

/++
    Whether or not $(D c) is a printable character - including the space
    character.
  +/
bool isPrint(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & (_ALP|_DIG|_PNC|_BLK)) : false;
}

unittest
{
    foreach(dchar c; iota(0, 128))
    {
        if(isControl(c))
            assert(!isPrint(c));
        else
            assert(isPrint(c));
    }
}


/++
    Whether or not $(D c) is in the ASCII character set - i.e. in the range
    0..0x7F.
  +/
bool isASCII(dchar c) @safe pure nothrow
{
    return c <= 0x7F;
}

unittest
{
    foreach(dchar c; iota(0, 128))
        assert(isASCII(c));

    assert(!isASCII(128));
}


/++
    If $(D c) is an uppercase ASCII character, then its corresponding lowercase
    letter is returned. Otherwise, $(D c) is returned.
  +/
dchar toAsciiLower(dchar c) @safe pure nothrow
out(result)
{
    assert(!isAsciiUpper(result));
}
body
{
    return isAsciiUpper(c) ? c + cast(dchar)('a' - 'A') : c;
}

unittest
{
    foreach(i, c; uppercase)
        assert(toAsciiLower(c) == lowercase[i]);

    foreach(dchar c; iota(0, 128))
    {
        if(c < 'A' || c > 'Z')
            assert(toAsciiLower(c) == c);
    }
}


/++
    If $(D c) is a lowercase ASCII character, then its corresponding uppercase
    letter is returned. Otherwise, $(D c) is returned.
  +/
dchar toAsciiUpper(dchar c) @safe pure nothrow
out(result)
{
    assert(!isAsciiLower(result));
}
body
{
    return isAsciiLower(c) ? c - cast(dchar)('a' - 'A') : c;
}

unittest
{
    foreach(i, c; lowercase)
        assert(toAsciiUpper(c) == uppercase[i]);

    foreach(dchar c; iota(0, 128))
    {
        if(c < 'a' || c > 'z')
            assert(toAsciiUpper(c) == c);
    }
}


//==============================================================================
// Private Section.
//==============================================================================
private:

enum
{
    _SPC =      8,
    _CTL =      0x20,
    _BLK =      0x40,
    _HEX =      0x80,
    _UC  =      1,
    _LC  =      2,
    _PNC =      0x10,
    _DIG =      4,
    _ALP =      _UC|_LC,
}

immutable ubyte _ctype[128] =
[
        _CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,
        _CTL,_CTL|_SPC,_CTL|_SPC,_CTL|_SPC,_CTL|_SPC,_CTL|_SPC,_CTL,_CTL,
        _CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,
        _CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,_CTL,
        _SPC|_BLK,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _PNC,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,
        _DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,_DIG|_HEX,
        _PNC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _PNC,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC|_HEX,_UC,
        _UC,_UC,_UC,_UC,_UC,_UC,_UC,_UC,
        _UC,_UC,_UC,_UC,_UC,_UC,_UC,_UC,
        _UC,_UC,_UC,_PNC,_PNC,_PNC,_PNC,_PNC,
        _PNC,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC|_HEX,_LC,
        _LC,_LC,_LC,_LC,_LC,_LC,_LC,_LC,
        _LC,_LC,_LC,_LC,_LC,_LC,_LC,_LC,
        _LC,_LC,_LC,_PNC,_PNC,_PNC,_PNC,_CTL
];

