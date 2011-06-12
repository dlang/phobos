// Written in the D programming language.

/**
 * Simple ASCII character classification functions.
 * For Unicode classification, see $(LINK2 std_uni.html, std.uni).
 * References:
 *      $(LINK2 http://www.digitalmars.com/d/ascii-table.html, ASCII Table),
 *      $(LINK2 http://en.wikipedia.org/wiki/Ascii, Wikipedia)
 * Macros:
 *      WIKI=Phobos/StdCtype
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright) and Jonathan M Davis
 * Source:    $(PHOBOSSRC std/_ctype.d)
 */
module std.ctype;

version(unittest) import std.range;


immutable hexDigits      = "0123456789ABCDEF";           /// 0..9A..F
immutable fullHexDigits  = "0123456789ABCDEFabcdef";     /// 0..9A..Fa..f
immutable digits         = "0123456789";                 /// 0..9
immutable octDigits      = "01234567";                   /// 0..7
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


/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isAlphaNum) instead.)
 *
 * Returns !=0 if c is a letter in the range (0..9, a..z, A..Z).
 */
?/pure int isalnum(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG) : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isAlpha) instead.)
 *
 * Returns !=0 if c is an ascii upper or lower case letter.
 */
pure int isalpha(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP)      : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isControl) instead.)
 *
 * Returns !=0 if c is a control character.
 */
pure int iscntrl(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_CTL)      : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isDigit) instead.)
 *
 * Returns !=0 if c is a digit.
 */
pure int isdigit(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_DIG)      : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isLower) instead.)
 *
 * Returns !=0 if c is lower case ascii letter.
 */
pure int islower(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_LC)       : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isPunct) instead.)
 *
 * Returns !=0 if c is a punctuation character.
 */
pure int ispunct(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_PNC)      : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isWhite) instead.)
 *
 * Returns !=0 if c is a space, tab, vertical tab, form feed,
 * carriage return, or linefeed.
 */
pure int isspace(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_SPC)      : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isUpper) instead.)
 *
 * Returns !=0 if c is an upper case ascii character.
 */
pure int isupper(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_UC)       : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isHexDigit) instead.)
 *
 * Returns !=0 if c is a hex digit (0..9, a..f, A..F).
 */
pure int isxdigit(dchar c) { return (c <= 0x7F) ? _ctype[c] & (_HEX)      : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isGraph) instead.)
 *
 * Returns !=0 if c is a printing character except for the space character.
 */
pure int isgraph(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC) : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isPrint) instead.)
 *
 * Returns !=0 if c is a printing character including the space character.
 */
pure int isprint(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC|_BLK) : 0; }

/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D isASCII) instead.)
 *
 * Returns !=0 if c is in the ascii character set, i.e. in the range 0..0x7F.
 */
pure int isascii(dchar c)  { return c <= 0x7F; }


/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D toLower) instead.)
 *
 * If c is an upper case ascii character,
 * return the lower case equivalent, otherwise return c.
 */
pure dchar tolower(dchar c)
    out (result)
    {
        assert(!isupper(result));
    }
    body
    {
        return isupper(c) ? c + (cast(dchar)'a' - 'A') : c;
    }


/**
 * $(RED Scheduled for deprecation in December 2011. Please use $(D toUpper) instead.)
 *
 * If c is a lower case ascii character,
 * return the upper case equivalent, otherwise return c.
 */
pure dchar toupper(dchar c)
    out (result)
    {
        assert(!islower(result));
    }
    body
    {
        return islower(c) ? c - (cast(dchar)'a' - 'A') : c;
    }


/++
    Returns whether $(D c) is a letter or a number (0..9, a..z, A..Z).
  +/
bool isAlphaNum(dchar c) @safe pure nothrow nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & (_ALP|_DIG)) : false;
}

unittest
{
    foreach(c; chain(digits, octDigits, fullHexDigits, letters, lowercase, uppercase))
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

    foreach(c; chain(digits, octDigits, whitespace))
        assert(!isAlpha(c));
}


/++
    Returns whether $(D c) is a lowercase ASCII letter (a..z).
  +/
bool isLower(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _LC) : false;
}

unittest
{
    foreach(c; lowercase)
        assert(isLower(c));

    foreach(c; chain(digits, uppercase, whitespace))
        assert(!isLower(c));
}


/++
    Returns whether $(D c) is an uppercase ASCII letter (A..Z).
  +/
bool isUpper(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _UC) : false;
}

unittest
{
    foreach(c; uppercase)
        assert(isUpper(c));

    foreach(c; chain(digits, lowercase, whitespace))
        assert(!isUpper(c));
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
bool isOctDigit(dchar c) @safe pure nothrow
{
    //I'd edit _ctype to have a flag for octal except that something calling
    //the int versions of the other functions might actually rely on the exact
    //integer value returned for some reason, and so messing with _ctype
    //and its flags could break that. _ctype can be edited appropriately after
    //the int versions have been removed.
    return c >= '0' && c <= '7';
}

unittest
{
    foreach(c; octDigits)
        assert(isOctDigit(c));

    foreach(c; chain(letters, ['8', '9'], whitespace))
        assert(!isOctDigit(c));
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
bool isWhite(dchar c) @safe pure nothrow
{
    return c <= 0x7F ? cast(bool)(_ctype[c] & _SPC) : false;
}

unittest
{
    foreach(c; whitespace)
        assert(isWhite(c));

    foreach(c; chain(digits, letters))
        assert(!isWhite(c));
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
dchar toLower(dchar c) @safe pure nothrow
out(result)
{
    assert(!isUpper(result));
}
body
{
    return isUpper(c) ? c + cast(dchar)('a' - 'A') : c;
}

unittest
{
    foreach(i, c; uppercase)
        assert(toLower(c) == lowercase[i]);

    foreach(dchar c; iota(0, 128))
    {
        if(c < 'A' || c > 'Z')
            assert(toLower(c) == c);
    }
}


/++
    If $(D c) is a lowercase ASCII character, then its corresponding uppercase
    letter is returned. Otherwise, $(D c) is returned.
  +/
dchar toUpper(dchar c) @safe pure nothrow
out(result)
{
    assert(!isLower(result));
}
body
{
    return isLower(c) ? c - cast(dchar)('a' - 'A') : c;
}

unittest
{
    foreach(i, c; lowercase)
        assert(toUpper(c) == uppercase[i]);

    foreach(dchar c; iota(0, 128))
    {
        if(c < 'a' || c > 'z')
            assert(toUpper(c) == c);
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

