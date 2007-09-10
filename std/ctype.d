
// Written by Walter Bright
// Copyright (c) 2001-2003 Digital Mars
// All Rights Reserved
// www.digitalmars.com

// Simple char classification functions

module std.ctype;

int isalnum(char c)	{ return _ctype[1 + c] & (_ALP|_DIG); }
int isalpha(char c)	{ return _ctype[1 + c] & (_ALP); }
int iscntrl(char c)	{ return _ctype[1 + c] & (_CTL); }
int isdigit(char c)	{ return _ctype[1 + c] & (_DIG); }
int isgraph(char c)	{ return _ctype[1 + c] & (_ALP|_DIG|_PNC); }
int islower(char c)	{ return _ctype[1 + c] & (_LC); }
int isprint(char c)	{ return _ctype[1 + c] & (_ALP|_DIG|_PNC|_BLK); }
int ispunct(char c)	{ return _ctype[1 + c] & (_PNC); }
int isspace(char c)	{ return _ctype[1 + c] & (_SPC); }
int isupper(char c)	{ return _ctype[1 + c] & (_UC); }
int isxdigit(char c)	{ return _ctype[1 + c] & (_HEX); }
int isascii(char c)	{ return c <= 0x7F; }

char tolower(char c)
    out (result)
    {
	assert(!isupper(result));
    }
    body
    {
	return isupper(c) ? c + (cast(char)'a' - 'A') : c;
    }

char toupper(char c)
    out (result)
    {
	assert(!islower(result));
    }
    body
    {
	return islower(c) ? c - (cast(char)'a' - 'A') : c;
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
