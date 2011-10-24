// Written in the D programming language.

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 *  $(LINK2 std_ascii.html, std.ascii) instead.)
 *
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

import std.ascii;


/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 *       $(D std.ascii.isAlphaNum) instead.)
 *
 * Returns !=0 if c is a letter in the range (0..9, a..z, A..Z).
 */
pure int isalnum(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG) : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 *       $(D std.ascii.isAlpha) instead.)
 *
 * Returns !=0 if c is an ascii upper or lower case letter.
 */
pure int isalpha(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP)      : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ctype.ascii.isControl) instead.)
 *
 * Returns !=0 if c is a control character.
 */
pure int iscntrl(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_CTL)      : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isDigit) instead.)
 *
 * Returns !=0 if c is a digit.
 */
pure int isdigit(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_DIG)      : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isLower) instead.)
 *
 * Returns !=0 if c is lower case ascii letter.
 */
pure int islower(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_LC)       : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isPunctuation) instead.)
 *
 * Returns !=0 if c is a punctuation character.
 */
pure int ispunct(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_PNC)      : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isWhite) instead.)
 *
 * Returns !=0 if c is a space, tab, vertical tab, form feed,
 * carriage return, or linefeed.
 */
pure int isspace(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_SPC)      : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isUpper) instead.)
 *
 * Returns !=0 if c is an upper case ascii character.
 */
pure int isupper(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_UC)       : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isHexDigit) instead.)
 *
 * Returns !=0 if c is a hex digit (0..9, a..f, A..F).
 */
pure int isxdigit(dchar c) { return (c <= 0x7F) ? _ctype[c] & (_HEX)      : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isGraphical) instead.)
 *
 * Returns !=0 if c is a printing character except for the space character.
 */
pure int isgraph(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC) : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isPrintable) instead.)
 *
 * Returns !=0 if c is a printing character including the space character.
 */
pure int isprint(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC|_BLK) : 0; }

/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.isASCII) instead.)
 *
 * Returns !=0 if c is in the ascii character set, i.e. in the range 0..0x7F.
 */
pure int isascii(dchar c)  { return c <= 0x7F; }


/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.toLower) instead.)
 *
 * If c is an upper case ascii character,
 * return the lower case equivalent, otherwise return c.
 */
pure dchar tolower(dchar c)
{
    return std.ascii.toLower(c);
}


/**
 * $(RED Scheduled for deprecation in January 2012. Please use
 * $(D std.ascii.toUpper) instead.)
 *
 * If c is a lower case ascii character,
 * return the upper case equivalent, otherwise return c.
 */
pure dchar toupper(dchar c)
{
    return std.ascii.toUpper(c);
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

