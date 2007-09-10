
// Written by Walter Bright
// Copyright (c) 2002-2003 Digital Mars
// All Rights Reserved
// www.digitalmars.com

// Conversion building blocks. These differ from the C equivalents by
// checking for overflow and not allowing whitespace.

module std.conv;

//debug=conv;		// uncomment to turn on debugging printf's



/************** Exceptions ****************/

class ConvError : Error
{
    this(char[] s)
    {
	super("Error: conversion " ~ s);
    }
}

private void conv_error(char[] s)
{
    throw new ConvError(s);
}

class ConvOverflowError : Error
{
    this(char[] s)
    {
	super("Error: overflow " ~ s);
    }
}

private void conv_overflow(char[] s)
{
    throw new ConvOverflowError(s);
}

/***************************************************************
 * Convert character string to int.
 * Grammar:
 *	['+'|'-'] digit {digit}
 */

int toInt(char[] s)
{
    int length = s.length;

    if (!length)
	goto Lerr;

    int sign = 0;
    int v = 0;

    for (int i = 0; i < length; i++)
    {
	char c = s[i];
	if (c >= '0' && c <= '9')
	{
	    uint v1 = v;
	    v = v * 10 + (c - '0');
	    if (cast(uint)v < v1)
		goto Loverflow;
	}
	else if (c == '-' && i == 0)
	{
	    sign = -1;
	    if (length == 1)
		goto Lerr;
	}
	else if (c == '+' && i == 0)
	{
	    if (length == 1)
		goto Lerr;
	}
	else
	    goto Lerr;
    }
    if (sign == -1)
    {
	if (cast(uint)v > 0x80000000)
	    goto Loverflow;
	v = -v;
    }
    else
    {
	if (cast(uint)v > 0x7FFFFFFF)
	    goto Loverflow;
    }
    return v;

Loverflow:
    conv_overflow(s);

Lerr:
    conv_error(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toInt.unittest\n");

    int i;

    i = toInt("0");
    assert(i == 0);

    i = toInt("+0");
    assert(i == 0);

    i = toInt("-0");
    assert(i == 0);

    i = toInt("6");
    assert(i == 6);

    i = toInt("+23");
    assert(i == 23);

    i = toInt("-468");
    assert(i == -468);

    i = toInt("2147483647");
    assert(i == 0x7FFFFFFF);

    i = toInt("-2147483648");
    assert(i == 0x80000000);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"xx",
	"123h",
	"2147483648",
	"-2147483649",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toInt(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}


/*******************************************************
 * Convert character string to uint.
 * Grammar:
 *	digit {digit}
 */

uint toUint(char[] s)
{
    int length = s.length;

    if (!length)
	goto Lerr;

    uint v = 0;

    for (int i = 0; i < length; i++)
    {
	char c = s[i];
	if (c >= '0' && c <= '9')
	{
	    uint v1 = v;
	    v = v * 10 + (c - '0');
	    if (v < v1)
		goto Loverflow;
	}
	else
	    goto Lerr;
    }
    return v;

Loverflow:
    conv_overflow(s);

Lerr:
    conv_error(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toUint.unittest\n");

    uint i;

    i = toUint("0");
    assert(i == 0);

    i = toUint("6");
    assert(i == 6);

    i = toUint("23");
    assert(i == 23);

    i = toUint("468");
    assert(i == 468);

    i = toUint("2147483647");
    assert(i == 0x7FFFFFFF);

    i = toUint("4294967295");
    assert(i == 0xFFFFFFFF);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"+5",
	"-78",
	"xx",
	"123h",
	"4294967296",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toUint(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}

/***************************************************************
 * Convert character string to long.
 * Grammar:
 *	['+'|'-'] digit {digit}
 */

long toLong(char[] s)
{
    int length = s.length;

    if (!length)
	goto Lerr;

    int sign = 0;
    long v = 0;

    for (int i = 0; i < length; i++)
    {
	char c = s[i];
	if (c >= '0' && c <= '9')
	{
	    ulong v1 = v;
	    v = v * 10 + (c - '0');
	    if (cast(ulong)v < v1)
		goto Loverflow;
	}
	else if (c == '-' && i == 0)
	{
	    sign = -1;
	    if (length == 1)
		goto Lerr;
	}
	else if (c == '+' && i == 0)
	{
	    if (length == 1)
		goto Lerr;
	}
	else
	    goto Lerr;
    }
    if (sign == -1)
    {
	if (cast(ulong)v > 0x8000000000000000)
	    goto Loverflow;
	v = -v;
    }
    else
    {
	if (cast(ulong)v > 0x7FFFFFFFFFFFFFFF)
	    goto Loverflow;
    }
    return v;

Loverflow:
    conv_overflow(s);

Lerr:
    conv_error(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toLong.unittest\n");

    long i;

    i = toLong("0");
    assert(i == 0);

    i = toLong("+0");
    assert(i == 0);

    i = toLong("-0");
    assert(i == 0);

    i = toLong("6");
    assert(i == 6);

    i = toLong("+23");
    assert(i == 23);

    i = toLong("-468");
    assert(i == -468);

    i = toLong("2147483647");
    assert(i == 0x7FFFFFFF);

    i = toLong("-2147483648");
    assert(i == -0x80000000L);

    i = toLong("9223372036854775807");
    assert(i == 0x7FFFFFFFFFFFFFFF);

    i = toLong("-9223372036854775808");
    assert(i == 0x8000000000000000);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"xx",
	"123h",
	"9223372036854775808",
	"-9223372036854775809",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toLong(errors[j]);
	    printf("l = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}


/*******************************************************
 * Convert character string to ulong.
 * Grammar:
 *	digit {digit}
 */

ulong toUlong(char[] s)
{
    int length = s.length;

    if (!length)
	goto Lerr;

    ulong v = 0;

    for (int i = 0; i < length; i++)
    {
	char c = s[i];
	if (c >= '0' && c <= '9')
	{
	    ulong v1 = v;
	    v = v * 10 + (c - '0');
	    if (v < v1)
		goto Loverflow;
	}
	else
	    goto Lerr;
    }
    return v;

Loverflow:
    conv_overflow(s);

Lerr:
    conv_error(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toUlong.unittest\n");

    ulong i;

    i = toUlong("0");
    assert(i == 0);

    i = toUlong("6");
    assert(i == 6);

    i = toUlong("23");
    assert(i == 23);

    i = toUlong("468");
    assert(i == 468);

    i = toUlong("2147483647");
    assert(i == 0x7FFFFFFF);

    i = toUlong("4294967295");
    assert(i == 0xFFFFFFFF);

    i = toUlong("9223372036854775807");
    assert(i == 0x7FFFFFFFFFFFFFFF);

    i = toUlong("18446744073709551615");
    assert(i == 0xFFFFFFFFFFFFFFFF);


    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"+5",
	"-78",
	"xx",
	"123h",
	"18446744073709551616",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toUlong(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}


/***************************************************************
 * Convert character string to short.
 * Grammar:
 *	['+'|'-'] digit {digit}
 */

short toShort(char[] s)
{
    int v = toInt(s);

    if (v != cast(short)v)
	goto Loverflow;

    return cast(short)v;

Loverflow:
    conv_overflow(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toShort.unittest\n");

    short i;

    i = toShort("0");
    assert(i == 0);

    i = toShort("+0");
    assert(i == 0);

    i = toShort("-0");
    assert(i == 0);

    i = toShort("6");
    assert(i == 6);

    i = toShort("+23");
    assert(i == 23);

    i = toShort("-468");
    assert(i == -468);

    i = toShort("32767");
    assert(i == 0x7FFF);

    i = toShort("-32768");
    assert(i == cast(short)0x8000);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"xx",
	"123h",
	"32768",
	"-32769",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toShort(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}


/*******************************************************
 * Convert character string to ushort.
 * Grammar:
 *	digit {digit}
 */

ushort toUshort(char[] s)
{
    uint v = toUint(s);

    if (v != cast(ushort)v)
	goto Loverflow;

    return cast(ushort)v;

Loverflow:
    conv_overflow(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toUshort.unittest\n");

    ushort i;

    i = toUshort("0");
    assert(i == 0);

    i = toUshort("6");
    assert(i == 6);

    i = toUshort("23");
    assert(i == 23);

    i = toUshort("468");
    assert(i == 468);

    i = toUshort("32767");
    assert(i == 0x7FFF);

    i = toUshort("65535");
    assert(i == 0xFFFF);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"+5",
	"-78",
	"xx",
	"123h",
	"65536",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toUshort(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}


/***************************************************************
 * Convert character string to byte.
 * Grammar:
 *	['+'|'-'] digit {digit}
 */

byte toByte(char[] s)
{
    int v = toInt(s);

    if (v != cast(byte)v)
	goto Loverflow;

    return cast(byte)v;

Loverflow:
    conv_overflow(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toByte.unittest\n");

    byte i;

    i = toByte("0");
    assert(i == 0);

    i = toByte("+0");
    assert(i == 0);

    i = toByte("-0");
    assert(i == 0);

    i = toByte("6");
    assert(i == 6);

    i = toByte("+23");
    assert(i == 23);

    i = toByte("-68");
    assert(i == -68);

    i = toByte("127");
    assert(i == 0x7F);

    i = toByte("-128");
    assert(i == cast(byte)0x80);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"xx",
	"123h",
	"128",
	"-129",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toByte(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}


/*******************************************************
 * Convert character string to ubyte.
 * Grammar:
 *	digit {digit}
 */

ubyte toUbyte(char[] s)
{
    uint v = toUint(s);

    if (v != cast(ubyte)v)
	goto Loverflow;

    return cast(ubyte)v;

Loverflow:
    conv_overflow(s);
    return 0;
}

unittest
{
    debug(conv) printf("conv.toUbyte.unittest\n");

    ubyte i;

    i = toUbyte("0");
    assert(i == 0);

    i = toUbyte("6");
    assert(i == 6);

    i = toUbyte("23");
    assert(i == 23);

    i = toUbyte("68");
    assert(i == 68);

    i = toUbyte("127");
    assert(i == 0x7F);

    i = toUbyte("255");
    assert(i == 0xFF);

    static char[][] errors =
    [
	"",
	"-",
	"+",
	"-+",
	" ",
	" 0",
	"0 ",
	"- 0",
	"1-",
	"+5",
	"-78",
	"xx",
	"123h",
	"256",
    ];

    for (int j = 0; j < errors.length; j++)
    {
	i = 47;
	try
	{
	    i = toUbyte(errors[j]);
	    printf("i = %d\n", i);
	}
	catch (Error e)
	{
	    debug(conv) e.print();
	    i = 3;
	}
	assert(i == 3);
    }
}



