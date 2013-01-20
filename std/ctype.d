// Written in the D programming language.

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
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
 * $(RED Deprecated. It will be removed in March 2013. Please use
 *       $(D std.ascii.isAlphaNum) instead.)
 *
 * Returns !=0 if c is a letter in the range (0..9, a..z, A..Z).
 */
deprecated("Please use std.ascii.isAlphaNum instead.")
pure int isalnum(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG) : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 *       $(D std.ascii.isAlpha) instead.)
 *
 * Returns !=0 if c is an ascii upper or lower case letter.
 */
deprecated("Please use std.ascii.isAlpha instead.")
pure int isalpha(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP)      : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ctype.ascii.isControl) instead.)
 *
 * Returns !=0 if c is a control character.
 */
deprecated("Please use std.ascii.isControl instead.")
pure int iscntrl(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_CTL)      : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isDigit) instead.)
 *
 * Returns !=0 if c is a digit.
 */
deprecated("Please use std.ascii.isDigit instead.")
pure int isdigit(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_DIG)      : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isLower) instead.)
 *
 * Returns !=0 if c is lower case ascii letter.
 */
deprecated("Please use std.ascii.isLower instead.")
pure int islower(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_LC)       : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isPunctuation) instead.)
 *
 * Returns !=0 if c is a punctuation character.
 */
deprecated("Please use std.ascii.isPunctuation instead.")
pure int ispunct(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_PNC)      : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isWhite) instead.)
 *
 * Returns !=0 if c is a space, tab, vertical tab, form feed,
 * carriage return, or linefeed.
 */
deprecated("Please use std.ascii.isWhite instead.")
pure int isspace(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_SPC)      : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isUpper) instead.)
 *
 * Returns !=0 if c is an upper case ascii character.
 */
deprecated("Please use std.ascii.isUpper instead.")
pure int isupper(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_UC)       : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isHexDigit) instead.)
 *
 * Returns !=0 if c is a hex digit (0..9, a..f, A..F).
 */
deprecated("Please use std.ascii.isHexDigit instead.")
pure int isxdigit(dchar c) { return (c <= 0x7F) ? _ctype[c] & (_HEX)      : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isGraphical) instead.)
 *
 * Returns !=0 if c is a printing character except for the space character.
 */
deprecated("Please use std.ascii.isGraphical instead.")
pure int isgraph(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC) : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isPrintable) instead.)
 *
 * Returns !=0 if c is a printing character including the space character.
 */
deprecated("Please use std.ascii.isPrintable instead.")
pure int isprint(dchar c)  { return (c <= 0x7F) ? _ctype[c] & (_ALP|_DIG|_PNC|_BLK) : 0; }

/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.isASCII) instead.)
 *
 * Returns !=0 if c is in the ascii character set, i.e. in the range 0..0x7F.
 */
deprecated("Please use std.ascii.isASCII instead.")
pure int isascii(dchar c)  { return c <= 0x7F; }


/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.toLower) instead.)
 *
 * If c is an upper case ascii character,
 * return the lower case equivalent, otherwise return c.
 */
deprecated("Please use std.ascii.toLower instead.")
pure dchar tolower(dchar c)
{
    return std.ascii.toLower(c);
}


/**
 * $(RED Deprecated. It will be removed in March 2013. Please use
 * $(D std.ascii.toUpper) instead.)
 *
 * If c is a lower case ascii character,
 * return the upper case equivalent, otherwise return c.
 */
deprecated("Please use std.ascii.toUpper instead.")
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

