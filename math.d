// math.d
// Written by Walter Bright
// Copyright (c) 2001 Digital Mars
// All Rights Reserved
// www.digitalmars.com

import c.stdio;

extern (C)
{
    // BUG: these have double arguments, but we need extended
    extended acos(double);
    extended asin(double);
    extended atan(double);
    extended atan2(double, double);
    extended cos(double);
    extended sin(double);
    extended tan(double);
    extended cosh(double);
    extended sinh(double);
    extended tanh(double);
    extended exp(double);
    extended frexp(double,int *);
    extended ldexp(double,int);
    extended log(double);
    extended log10(double);
    extended modf(double, double *);
    extended pow(double, double);
    extended sqrt(double);
    extended ceil(double);
    extended floor(double);
    extended log1p(double);
    extended expm1(double);
    extended atof(char *);
    extended hypot(double, double);
}

const extended PI = 		3.14159265358979323846;
const extended LOG2 =		0.30102999566398119521;
const extended LN2 =		0.6931471805599453094172321;
const extended LOG2T =		3.32192809488736234787;
const extended LOG2E =		1.4426950408889634074;
const extended E =		2.7182818284590452354;
const extended LOG10E =		0.43429448190325182765;
const extended LN10 =		2.30258509299404568402;
const extended PI_2 =		1.57079632679489661923;
const extended PI_4 =		0.78539816339744830962;
const extended M_1_PI =		0.31830988618379067154;
const extended M_2_PI =		0.63661977236758134308;
const extended M_2_SQRTPI =	1.12837916709551257390;
const extended SQRT2 =		1.41421356237309504880;
const extended SQRT1_2 =	0.70710678118654752440;

/*
	Octal versions:
	PI/64800	0.00001 45530 36176 77347 02143 15351 61441 26767
	PI/180		0.01073 72152 11224 72344 25603 54276 63351 22056
	PI/8		0.31103 75524 21026 43021 51423 06305 05600 67016
	SQRT(1/PI)	0.44067 27240 41233 33210 65616 51051 77327 77303
	2/PI		0.50574 60333 44710 40522 47741 16537 21752 32335
	PI/4		0.62207 73250 42055 06043 23046 14612 13401 56034
	SQRT(2/PI)	0.63041 05147 52066 24106 41762 63612 00272 56161

	PI		3.11037 55242 10264 30215 14230 63050 56006 70163
	LOG2		0.23210 11520 47674 77674 61076 11263 26013 37111
 */


/*********************************
 * Is number a nan?
 */

int isnan(extended e)
{
    ushort* pe = (ushort *)&e;
    ulong*  ps = (ulong *)&e;

    return (pe[4] & 0x7FFF) == 0x7FFF &&
	    *ps & 0x7FFFFFFFFFFFFFFF;
}

unittest
{
    assert(isnan(float.nan));
    assert(isnan(-double.nan));
    assert(isnan(extended.nan));

    assert(!isnan(53.6));
    assert(!isnan(float.infinity));
}

/*********************************
 * Is number finite?
 */

int isfinite(extended e)
{
    ushort* pe = (ushort *)&e;

    return (pe[4] & 0x7FFF) != 0x7FFF;
}

unittest
{
    assert(isfinite(1.23));
    assert(!isfinite(double.infinity));
    assert(!isfinite(float.nan));
}


/*********************************
 * Is number normalized?
 * Need one for each format because subnormal floats might
 * be converted to normal extendeds.
 */

int isnormal(float f)
{
    uint *p = (uint *)&f;
    uint e;

    e = *p & 0x7F800000;
    //printf("e = x%x, *p = x%x\n", e, *p);
    return e && e != 0x7F800000;
}

int isnormal(double d)
{
    uint *p = (uint *)&d;
    uint e;

    e = p[1] & 0x7FF00000;
    return e && e != 0x7FF00000;
}

int isnormal(extended e)
{
    ushort* pe = (ushort *)&e;
    long*   ps = (long *)&e;

    return (pe[4] & 0x7FFF) != 0x7FFF && *ps < 0;
}

unittest
{
    float f = 3;
    double d = 500;
    extended e = 10e+48;

    assert(isnormal(f));
    assert(isnormal(d));
    assert(isnormal(e));
}

/*********************************
 * Is number subnormal? (Also called "denormal".)
 * Subnormals have a 0 exponent and a 0 most significant mantissa bit.
 * Need one for each format because subnormal floats might
 * be converted to normal extendeds.
 */

int issubnormal(float f)
{
    uint *p = (uint *)&f;

    //printf("*p = x%x\n", *p);
    return (*p & 0x7F800000) == 0 && *p & 0x007FFFFF;
}

unittest
{
    float f = 3.0;

    for (f = 1.0; !issubnormal(f); f /= 2)
	assert(f != 0);
}

int issubnormal(double d)
{
    uint *p = (uint *)&d;

    return (p[1] & 0x7FF00000) == 0 && (p[0] || p[1] & 0x000FFFFF);
}

unittest
{
    double f;

    for (f = 1; !issubnormal(f); f /= 2)
	assert(f != 0);
}

int issubnormal(extended e)
{
    ushort* pe = (ushort *)&e;
    long*   ps = (long *)&e;

    return (pe[4] & 0x7FFF) == 0 && *ps > 0;
}

unittest
{
    extended f;

    for (f = 1; !issubnormal(f); f /= 2)
	assert(f != 0);
}

/*********************************
 * Is number infinity?
 */

int isinf(extended e)
{
    ushort* pe = (ushort *)&e;
    ulong*  ps = (ulong *)&e;

    return (pe[4] & 0x7FFF) == 0x7FFF &&
	    *ps == 0x8000000000000000;
}

unittest
{
    assert(isinf(float.infinity));
    assert(!isinf(float.nan));
    assert(isinf(double.infinity));
    assert(isinf(-extended.infinity));

    assert(isinf(-1.0 / 0.0));
}

/*********************************
 * Get sign bit.
 */

int signbit(extended e)
{
    ubyte* pe = (ubyte *)&e;

    return (pe[9] & 0x80) != 0;
}

unittest
{
    assert(!signbit(float.nan));
    assert(signbit(-float.nan));
    assert(!signbit(168.1234));
    assert(signbit(-168.1234));
    assert(!signbit(0.0));
    assert(signbit(-0.0));
}

/*********************************
 * Copy sign.
 */

extended copysign(extended to, extended from)
{
    ubyte* pto   = (ubyte *)&to;
    ubyte* pfrom = (ubyte *)&from;

    pto[9] &= 0x7F;
    pto[9] |= pfrom[9] & 0x80;

    return to;
}

unittest
{
    extended e;

    e = copysign(21, 23.8);
    assert(e == 21);

    e = copysign(-21, 23.8);
    assert(e == 21);

    e = copysign(21, -23.8);
    assert(e == -21);

    e = copysign(-21, -23.8);
    assert(e == -21);

    e = copysign(extended.nan, -23.8);
    assert(isnan(e) && signbit(e));
}
