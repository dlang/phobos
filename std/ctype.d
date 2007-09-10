
// Written by Walter Bright
// Copyright (c) 2001-2004 Digital Mars
// All Rights Reserved
// www.digitalmars.com

// Simple char classification functions

// BUG: need to upgrade to unicode

module std.ctype;

int isalnum(dchar c)	{ return _ctype[1 + c] & (_ALP|_DIG); }
int isalpha(dchar c)	{ return _ctype[1 + c] & (_ALP); }
int iscntrl(dchar c)	{ return _ctype[1 + c] & (_CTL); }
int isdigit(dchar c)	{ return _ctype[1 + c] & (_DIG); }
int isgraph(dchar c)	{ return _ctype[1 + c] & (_ALP|_DIG|_PNC); }
int islower(dchar c)	{ return _ctype[1 + c] & (_LC); }
int isprint(dchar c)	{ return _ctype[1 + c] & (_ALP|_DIG|_PNC|_BLK); }
int ispunct(dchar c)	{ return _ctype[1 + c] & (_PNC); }
int isspace(dchar c)	{ return _ctype[1 + c] & (_SPC); }
int isupper(dchar c)	{ return _ctype[1 + c] & (_UC); }
int isxdigit(dchar c)	{ return _ctype[1 + c] & (_HEX); }
int isascii(dchar c)	{ return c <= 0x7F; }

dchar tolower(dchar c)
    out (result)
    {
	assert(!isupper(result));
    }
    body
    {
	return isupper(c) ? c + (cast(dchar)'a' - 'A') : c;
    }

dchar toupper(dchar c)
    out (result)
    {
	assert(!islower(result));
    }
    body
    {
	return islower(c) ? c - (cast(dchar)'a' - 'A') : c;
    }

private:

enum
{
    _SPC =	8,
    _CTL =	0x20,
    _BLK =	0x40,
    _HEX =	0x80,
    _UC  =	1,
    _LC  =	2,
    _PNC =	0x10,
    _DIG =	4,
    _ALP =	_UC|_LC,
}

ubyte _ctype[257] =
[	0,
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

	// the remaining 128 bytes are 0
];


unittest
{
    assert(isspace(' '));
    assert(!isspace('z'));
    assert(toupper('a') == 'A');
    assert(tolower('Q') == 'q');
    assert(!isxdigit('G'));
}
