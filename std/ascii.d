// Written in the D programming language.

/++
    Functions which operate on ASCII characters.

    All of the functions in std.ascii accept Unicode characters but effectively
    ignore them if they're not ASCII. All $(D isX) functions return $(D false)
    for non-ASCII characters, and all $(D toX) functions do nothing to non-ASCII
    characters.

    For functions which operate on Unicode characters, see
    $(LINK2 std_uni.html, std.uni).

    References:
        $(LINK2 http://www.digitalmars.com/d/ascii-table.html, ASCII Table),
        $(WEB en.wikipedia.org/wiki/Ascii, Wikipedia)

    Macros:
        WIKI=Phobos/StdASCII

    Copyright: Copyright 2000 - 2013
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(WEB digitalmars.com, Walter Bright) and Jonathan M Davis
    Source:    $(PHOBOSSRC std/_ascii.d)
  +/
module std.ascii;

import std.traits;

version(unittest)
{
    import std.range;
    import std.typetuple;
    alias STD_ASCII_TEST_TYPES = TypeTuple!(char, ubyte, wchar, dchar, uint);
}


immutable hexDigits      = "0123456789ABCDEF";           /// 0..9A..F
immutable lowerHexDigits = "0123456789abcdef";           /// 0..9a..f
immutable fullHexDigits  = "0123456789ABCDEFabcdef";     /// 0..9A..Fa..f
immutable digits         = "0123456789";                 /// 0..9
immutable octalDigits    = "01234567";                   /// 0..7
immutable lowercase      = "abcdefghijklmnopqrstuvwxyz"; /// a..z
immutable letters        = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ~
                           "abcdefghijklmnopqrstuvwxyz"; /// A..Za..z
immutable uppercase      = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"; /// A..Z
immutable whitespace     = " \t\v\r\n\f";                /// ASCII whitespace

/**
Letter case specifier.
 */
enum LetterCase : bool
{
    upper, /// Upper case letters
    lower  /// Lower case letters
}

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
bool isAlphaNum(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & (_ALP|_DIG));
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; chain(digits, octalDigits, fullHexDigits, letters, lowercase, uppercase))
            assert(isAlphaNum(cast(C)c));

        foreach(c; whitespace)
            assert(!isAlphaNum(cast(C)c));
    }
}


/++
    Returns whether $(D c) is an ASCII letter (A..Z, a..z).
  +/
bool isAlpha(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _ALP) : false;
}
bool isAlpha(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _ALP);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; chain(letters, lowercase, uppercase))
            assert(isAlpha(cast(C)c));

        foreach(c; chain(digits, octalDigits, whitespace))
            assert(!isAlpha(cast(C)c));
    }
}


/++
    Returns whether $(D c) is a lowercase ASCII letter (a..z).
  +/
bool isLower(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _LC) : false;
}
bool isLower(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _LC);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; lowercase)
            assert(isLower(cast(C)c));

        foreach(c; chain(digits, uppercase, whitespace))
            assert(!isLower(cast(C)c));
    }
}


/++
    Returns whether $(D c) is an uppercase ASCII letter (A..Z).
  +/
bool isUpper(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _UC) : false;
}
bool isUpper(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _UC);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; uppercase)
            assert(isUpper(cast(C)c));

        foreach(c; chain(digits, lowercase, whitespace))
            assert(!isUpper(cast(C)c));
    }
}


/++
    Returns whether $(D c) is a digit (0..9).
  +/
bool isDigit(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _DIG) : false;
}
bool isDigit(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _DIG);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; digits)
            assert(isDigit(cast(C)c));

        foreach(c; chain(letters, whitespace))
            assert(!isDigit(cast(C)c));
    }
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
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; octalDigits)
            assert(isOctalDigit(cast(C)c));

        foreach(c; chain(letters, ['8', '9'], whitespace))
            assert(!isOctalDigit(cast(C)c));
    }
}


/++
    Returns whether $(D c) is a digit in base 16 (0..9, A..F, a..f).
  +/
bool isHexDigit(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _HEX) : false;
}
bool isHexDigit(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _HEX);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; fullHexDigits)
            assert(isHexDigit(cast(C)c));

        foreach(c; chain(lowercase[6 .. $], uppercase[6 .. $], whitespace))
            assert(!isHexDigit(cast(C)c));
    }
}


/++
    Whether or not $(D c) is a whitespace character. That includes the space,
    tab, vertical tab, form feed, carriage return, and linefeed characters.
  +/
bool isWhite(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _SPC) : false;
}
bool isWhite(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _SPC);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(c; whitespace)
            assert(isWhite(cast(C)c));

        foreach(c; chain(digits, letters))
            assert(!isWhite(cast(C)c));
    }
}


/++
    Returns whether $(D c) is a control character.
  +/
bool isControl(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _CTL) : false;
}
bool isControl(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _CTL);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(C c; 0 .. 32)
            assert(isControl(c));
        assert(isControl(cast(C)127));

        foreach(c; chain(digits, letters, [' ']))
            assert(!isControl(cast(C)c));
    }
}


/++
    Whether or not $(D c) is a punctuation character. That includes all ASCII
    characters which are not control characters, letters, digits, or whitespace.
  +/
bool isPunctuation(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _PNC) : false;
}
bool isPunctuation(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & _PNC);
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(C c; 0 .. 128)
        {
            if(isControl(c) || isAlphaNum(c) || c == ' ')
                assert(!isPunctuation(c));
            else
                assert(isPunctuation(c));
        }
    }
}


/++
    Whether or not $(D c) is a printable character other than the space
    character.
  +/
bool isGraphical(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & (_ALP|_DIG|_PNC)) : false;
}
bool isGraphical(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & (_ALP|_DIG|_PNC));
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(C c; 0 .. 128)
        {
            if(isControl(c) || c == ' ')
                assert(!isGraphical(c));
            else
                assert(isGraphical(c));
        }
    }
}

/++
    Whether or not $(D c) is a printable character - including the space
    character.
  +/
bool isPrintable(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & (_ALP|_DIG|_PNC|_BLK)) : false;
}
bool isPrintable(char c) @safe pure nothrow
{
    return cast(bool)(_ctype[c] & (_ALP|_DIG|_PNC|_BLK));
}

unittest
{
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(C c; 0 .. 128)
        {
            if(isControl(c))
                assert(!isPrintable(c));
            else
                assert(isPrintable(c));
        }
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
    foreach(C; STD_ASCII_TEST_TYPES)
    {
        foreach(C c; 0 .. 128)
            assert(isASCII(c));

        assert(!isASCII(cast(C)128));
    }
}


/++
    If $(D c) is an uppercase ASCII character, then its corresponding lowercase
    letter is returned. Otherwise, $(D c) is returned.

    $(D C) can be any type which implicitly converts to $(D dchar). In the case
    where it's a built-in type, $(D Unqual!C) is returned, whereas if it's a
    user-defined type, $(D dchar) is returned.
  +/
auto toLower(C)(C c)
    if(is(C : dchar))
{
    static if(isScalarType!C)
        return isUpper(c) ? cast(Unqual!C)(c + 'a' - 'A') : cast(Unqual!C)c;
    else
        return toLower!dchar(c);
}

unittest
{
    foreach(C; TypeTuple!(char, wchar, dchar, immutable char, ubyte))
    {
        foreach(i, c; uppercase)
            assert(toLower(cast(C)c) == lowercase[i]);

        foreach(C c; 0 .. 128)
        {
            if(c < 'A' || c > 'Z')
                assert(toLower(c) == c);
            else
                assert(toLower(c) != c);
        }

        foreach(C c; 128 .. C.max)
            assert(toLower(c) == c);
    }

    static assert(isSafe!(toLower!char));
    static assert((functionAttributes!((){'a'.toLower();}) & FunctionAttribute.pure_) != 0);
    static assert((functionAttributes!((){'a'.toLower();}) & FunctionAttribute.nothrow_) != 0);

    static struct Char { dchar c; alias c this; }
    static assert(is(typeof(Char('A').toLower()) == dchar));
    assert(Char('A').toLower() == 'a');
    assert(Char('a').toLower() == 'a');
}


/++
    If $(D c) is a lowercase ASCII character, then its corresponding uppercase
    letter is returned. Otherwise, $(D c) is returned.

    $(D C) can be any type which implicitly converts to $(D dchar). In the case
    where it's a built-in type, $(D Unqual!C) is returned, whereas if it's a
    user-defined type, $(D dchar) is returned.
  +/
auto toUpper(C)(C c)
    if(is(C : dchar))
{
    static if(isScalarType!C)
        return isLower(c) ? cast(Unqual!C)(c - ('a' - 'A')) : cast(Unqual!C)c;
    else
        return toUpper!dchar(c);
}

unittest
{
    foreach(C; TypeTuple!(char, wchar, dchar, immutable char, ubyte))
    {
        foreach(i, c; lowercase)
            assert(toUpper(cast(C)c) == uppercase[i]);

        foreach(C c; 0 .. 128)
        {
            if(c < 'a' || c > 'z')
                assert(toUpper(c) == c);
            else
                assert(toUpper(c) != c);
        }

        foreach(C c; 128 .. C.max)
            assert(toUpper(c) == c);
    }

    static assert(isSafe!(toUpper!char));
    static assert((functionAttributes!((){'a'.toUpper();}) & FunctionAttribute.pure_) != 0);
    static assert((functionAttributes!((){'a'.toUpper();}) & FunctionAttribute.nothrow_) != 0);

    static struct Char { dchar c; alias c this; }
    static assert(is(typeof(Char('a').toUpper()) == dchar));
    assert(Char('a').toUpper() == 'A');
    assert(Char('A').toUpper() == 'A');
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

immutable ubyte[256] _ctype =
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

