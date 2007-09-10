// math.d

/**
 * Macros:
 *	WIKI = StdMath
 *
 *	TABLE_SV = <table border=1 cellpadding=4 cellspacing=0>
 *		<caption>Special Values</caption>
 *		$0</table>
 *
 *	NAN = $(RED NAN)
 *	SUP = <span style="vertical-align:super;font-size:smaller">$0</span>
 *	GAMMA =  &#915;
 *	INTEGRAL = &#8747;
 */

/*
 * Author:
 *	Walter Bright
 * Copyright:
 *	Copyright (c) 2001-2005 by Digital Mars,
 *	All Rights Reserved,
 *	www.digitalmars.com
 * License:
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  <ul>
 *  <li> The origin of this software must not be misrepresented; you must not
 *       claim that you wrote the original software. If you use this software
 *       in a product, an acknowledgment in the product documentation would be
 *       appreciated but is not required.
 *  </li>
 *  <li> Altered source versions must be plainly marked as such, and must not
 *       be misrepresented as being the original software.
 *  </li>
 *  <li> This notice may not be removed or altered from any source
 *       distribution.
 *  </li>
 *  </ul>
 */


module std.math;

//debug=math;		// uncomment to turn on debugging printf's

private import std.stdio;
private import std.c.stdio;
private import std.string;
private import std.c.math;

class NotImplemented : Error
{
    this(char[] msg)
    {
	super(msg ~ "not implemented");
    }
}

const real E =		2.7182818284590452354L;  /** e */
const real LOG2T =	0x1.a934f0979a3715fcp+1; /** log<sub>2</sub>10 */ // 3.32193 fldl2t
const real LOG2E =	0x1.71547652b82fe178p+0; /** log<sub>2</sub>e */ // 1.4427 fldl2e
const real LOG2 =	0x1.34413509f79fef32p-2; /** log<sub>10</sub>2 */ // 0.30103 fldlg2
const real LOG10E =	0.43429448190325182765;  /** log<sub>10</sub>e */
const real LN2 =	0x1.62e42fefa39ef358p-1; /** ln 2 */	// 0.693147 fldln2
const real LN10 =	2.30258509299404568402;  /** ln 10 */
const real PI =		0x1.921fb54442d1846ap+1; /** &pi; */ // 3.14159 fldpi
const real PI_2 =	1.57079632679489661923;  /** &pi; / 2 */
const real PI_4 =	0.78539816339744830962;  /** &pi; / 4 */
const real M_1_PI =	0.31830988618379067154;  /** 1 / &pi; */
const real M_2_PI =	0.63661977236758134308;  /** 2 / &pi; */
const real M_2_SQRTPI =	1.12837916709551257390;  /** 2 / &radic;&pi; */
const real SQRT2 =	1.41421356237309504880;  /** &radic;2 */
const real SQRT1_2 =	0.70710678118654752440;  /** &radic;&frac12 */

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


/***********************************
 * Returns cosine of x. x is in radians.
 *
 *	$(TABLE_SV
 *	$(TR $(TH x)               $(TH cos(x)) $(TH invalid?)	)
 *	$(TR $(TD $(NAN))          $(TD $(NAN)) $(TD yes)	)
 *	$(TR $(TD &plusmn;&infin;) $(TD $(NAN)) $(TD yes)	)
 *	)
 */

real cos(real x);	/* intrinsic */

/***********************************
 * Returns sine of x. x is in radians.
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> sin(x)      <th>invalid?
 *	<tr> <td> $(NAN)          <td> $(NAN)      <td> yes
 *	<tr> <td> &plusmn;0.0     <td> &plusmn;0.0 <td> no
 *	<tr> <td> &plusmn;&infin; <td> $(NAN)      <td> yes
 *	)
 */

real sin(real x);	/* intrinsic */


/****************************************************************************
 * Returns tangent of x. x is in radians.
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> tan(x)      <th> invalid?
 *	<tr> <td> $(NAN)          <td> $(NAN)      <td> yes
 *	<tr> <td> &plusmn;0.0     <td> &plusmn;0.0 <td> no
 *	<tr> <td> &plusmn;&infin; <td> $(NAN)      <td> yes
 *	)
 */

real tan(real x)
{
    asm
    {
	fld	x[EBP]			; // load theta
	fxam				; // test for oddball values
	fstsw	AX			;
	sahf				;
	jc	trigerr			; // x is NAN, infinity, or empty
					  // 387's can handle denormals
SC18:	fptan				;
	fstp	ST(0)			; // dump X, which is always 1
	fstsw	AX			;
	sahf				;
	jnp	Lret			; // C2 = 1 (x is out of range)

	// Do argument reduction to bring x into range
	fldpi				;
	fxch				;
SC17:	fprem1				;
	fstsw	AX			;
	sahf				;
	jp	SC17			;
	fstp	ST(1)			; // remove pi from stack
	jmp	SC18			;

trigerr:
	fstp	ST(0)			; // dump theta
    }
    return real.nan;

Lret:
    ;
}

unittest
{
    static real vals[][2] =	// angle,tan
    [
	    [   0,   0],
	    [   .5,  .5463024898],
	    [   1,   1.557407725],
	    [   1.5, 14.10141995],
	    [   2,  -2.185039863],
	    [   2.5,-.7470222972],
	    [   3,  -.1425465431],
	    [   3.5, .3745856402],
	    [   4,   1.157821282],
	    [   4.5, 4.637332055],
	    [   5,  -3.380515006],
	    [   5.5,-.9955840522],
	    [   6,  -.2910061914],
	    [   6.5, .2202772003],
	    [   10,  .6483608275],

	    // special angles
	    [   PI_4,	1],
	    //[	PI_2,	real.infinity],
	    [   3*PI_4,	-1],
	    [   PI,	0],
	    [   5*PI_4,	1],
	    //[	3*PI_2,	-real.infinity],
	    [   7*PI_4,	-1],
	    [   2*PI,	0],

	    // overflow
	    [   real.infinity,	real.nan],
	    [   real.nan,	real.nan],
	    [   1e+100,		real.nan],
    ];
    int i;

    for (i = 0; i < vals.length; i++)
    {
	real x = vals[i][0];
	real r = vals[i][1];
	real t = tan(x);

	//printf("tan(%Lg) = %Lg, should be %Lg\n", x, t, r);
	assert(mfeq(r, t, .0000001));

	x = -x;
	r = -r;
	t = tan(x);
	//printf("tan(%Lg) = %Lg, should be %Lg\n", x, t, r);
	assert(mfeq(r, t, .0000001));
    }
}

/***************
 * Calculates the arc cosine of x,
 * returning a value ranging from -&pi;/2 to &pi;/2.
 *
 *	$(TABLE_SV
 *      <tr> <th> x        <th> acos(x) <th> invalid?
 *      <tr> <td> &gt;1.0  <td> $(NAN)  <td> yes
 *      <tr> <td> &lt;-1.0 <td> $(NAN)  <td> yes
 *      <tr> <td> $(NAN)   <td> $(NAN)  <td> yes
 *      )
 */
real acos(real x)		{ return std.c.math.acosl(x); }

/***************
 * Calculates the arc sine of x,
 * returning a value ranging from -&pi;/2 to &pi;/2.
 *
 *	$(TABLE_SV
 *	<tr> <th> x        <th> asin(x)  <th> invalid?
 *	<tr> <td> &plusmn;0.0    <td> &plusmn;0.0    <td> no
 *	<tr> <td> &gt;1.0  <td> $(NAN)   <td> yes
 *	<tr> <td> &lt;-1.0 <td> $(NAN)   <td> yes
 *       )
 */
real asin(real x)		{ return std.c.math.asinl(x); }

/***************
 * Calculates the arc tangent of x,
 * returning a value ranging from -&pi;/2 to &pi;/2.
 *
 *	$(TABLE_SV
 *	<tr> <th> x           <th> atan(x)  <th> invalid?
 *	<tr> <td> &plusmn;0.0       <td> &plusmn;0.0    <td> no
 *	<tr> <td> &plusmn;&infin;  <td> $(NAN)   <td> yes
 *       )
 */
real atan(real x)		{ return std.c.math.atanl(x); }

/***************
 * Calculates the arc tangent of y / x,
 * returning a value ranging from -&pi;/2 to &pi;/2.
 *
 *	$(TABLE_SV
 *	<tr> <th> x           <th> y         <th> atan(x, y)
 *	<tr> <td> $(NAN)      <td> anything  <td> $(NAN) 
 *	<tr> <td> anything    <td> $(NAN)    <td> $(NAN) 
 *	<tr> <td> &plusmn;0.0       <td> &gt; 0.0  <td> &plusmn;0.0 
 *	<tr> <td> &plusmn;0.0       <td> &plusmn;0.0     <td> &plusmn;0.0 
 *	<tr> <td> &plusmn;0.0       <td> &lt; 0.0  <td> &plusmn;&pi; 
 *	<tr> <td> &plusmn;0.0       <td> -0.0      <td> &plusmn;&pi;
 *	<tr> <td> &gt; 0.0    <td> &plusmn;0.0     <td> &pi;/2 
 *	<tr> <td> &lt; 0.0    <td> &plusmn;0.0     <td> &pi;/2 
 *	<tr> <td> &gt; 0.0    <td> &infin;  <td> &plusmn;0.0 
 *	<tr> <td> &plusmn;&infin;  <td> anything  <td> &plusmn;&pi;/2 
 *	<tr> <td> &gt; 0.0    <td> -&infin; <td> &plusmn;&pi; 
 *	<tr> <td> &plusmn;&infin;  <td> &infin;  <td> &plusmn;&pi;/4 	
 *	<tr> <td> &plusmn;&infin;  <td> -&infin; <td> &plusmn;3&pi;/4
 *      )
 */
real atan2(real x, real y)	{ return std.c.math.atan2l(x,y); }

/***********************************
 * Calculates the hyperbolic cosine of x.
 *
 *	$(TABLE_SV
 *	<tr> <th> x                <th> cosh(x)     <th> invalid?
 *	<tr> <td> &plusmn;&infin;  <td> &plusmn;0.0 <td> no 
 *      )
 */
real cosh(real x)		{ return std.c.math.coshl(x); }

/***********************************
 * Calculates the hyperbolic sine of x.
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> sinh(x)         <th> invalid?
 *	<tr> <td> &plusmn;0.0     <td> &plusmn;0.0     <td> no
 *	<tr> <td> &plusmn;&infin; <td> &plusmn;&infin; <td> no
 *      )
 */
real sinh(real x)		{ return std.c.math.sinhl(x); }

/***********************************
 * Calculates the hyperbolic tangent of x.
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> tanh(x)      <th> invalid?
 *	<tr> <td> &plusmn;0.0 	  <td> &plusmn;0.0  <td> no 
 *	<tr> <td> &plusmn;&infin; <td> &plusmn;1.0  <td> no
 *      )
 */
real tanh(real x)		{ return std.c.math.tanhl(x); }

//real acosh(real x)		{ return std.c.math.acoshl(x); }
//real asinh(real x)		{ return std.c.math.asinhl(x); }
//real atanh(real x)		{ return std.c.math.atanhl(x); }

/*****************************************
 * Returns x rounded to a long value using the current rounding mode.
 * If the integer value of x is
 * greater than long.max, the result is
 * indeterminate.
 */
long rndtol(real x);	/* intrinsic */


/*****************************************
 * Returns x rounded to a long value using the FE_TONEAREST rounding mode.
 * If the integer value of x is
 * greater than long.max, the result is
 * indeterminate.
 */
extern (C) real rndtonl(real x);

/***************************************
 * Compute square root of x.
 *
 *	$(TABLE_SV
 *	<tr> <th> x        <th> sqrt(x)  <th> invalid?
 *	<tr> <td> -0.0     <td> -0.0     <td> no
 *	<tr> <td> &lt;0.0  <td> $(NAN)   <td> yes
 *	<tr> <td> +&infin; <td> +&infin; <td> no
 *	)
 */

float sqrt(float x);	/* intrinsic */
double sqrt(double x);	/* intrinsic */	/// ditto
real sqrt(real x);	/* intrinsic */ /// ditto

creal sqrt(creal z)
{
    creal c;
    real x,y,w,r;

    if (z == 0)
    {
	c = 0;
    }
    else
    {	real z_re = z.re;
	real z_im = z.im;

	x = fabs(z_re);
	y = fabs(z_im);
	if (x >= y)
	{
	    r = y / x;
	    w = sqrt(x) * sqrt(0.5 * (1 + sqrt(1 + r * r)));
	}
	else
	{
	    r = x / y;
	    w = sqrt(y) * sqrt(0.5 * (r + sqrt(1 + r * r)));
	}

	if (z_re >= 0)
	{
	    c = w + (z_im / (w + w)) * 1.0i;
	}
	else
	{
	    if (z_im < 0)
		w = -w;
	    c = z_im / (w + w) + w * 1.0i;
	}
    }
    return c;
}

/**********************
 * Calculates e$(SUP x).
 *
 *	$(TABLE_SV
 *	<tr> <th> x        <th> exp(x)
 *	<tr> <td> +&infin; <td> +&infin; 
 *	<tr> <td> -&infin; <td> +0.0 
 *	)
 */
real exp(real x)		{ return std.c.math.expl(x); }

/**********************
 * Calculates 2$(SUP x).
 *
 *	$(TABLE_SV
 *	<tr> <th> x <th> exp2(x)
 *	<tr> <td> +&infin; <td> +&infin; 
 *	<tr> <td> -&infin; <td> +0.0 
 *	)
 */
real exp2(real x)		{ return std.c.math.exp2l(x); }

/******************************************
 * Calculates the value of the natural logarithm base (e)
 * raised to the power of x, minus 1.
 *
 * For very small x, expm1(x) is more accurate 
 * than exp(x)-1. 
 *
 *	$(TABLE_SV
 *	<tr> <th> x           <th> e$(SUP x)-1
 *	<tr> <td> &plusmn;0.0 <td> &plusmn;0.0
 *	<tr> <td> +&infin;    <td> +&infin;
 *	<tr> <td> -&infin;    <td> -1.0
 *	)
 */

real expm1(real x)		{ return std.c.math.expm1l(x); }


/*********************************************************************
 * Separate floating point value into significand and exponent.
 *
 * Returns:
 *	Calculate and return <i>x</i> and exp such that
 *	value =<i>x</i>*2$(SUP exp) and
 *	.5 &lt;= |<i>x</i>| &lt; 1.0<br>
 *	<i>x</i> has same sign as value.
 *
 *	$(TABLE_SV
 *	<tr> <th> value          <th> returns        <th> exp
 *	<tr> <td> &plusmn;0.0    <td> &plusmn;0.0    <td> 0
 *	<tr> <td> +&infin;       <td> +&infin;       <td> int.max
 *	<tr> <td> -&infin;       <td> -&infin;       <td> int.min
 *	<tr> <td> &plusmn;$(NAN) <td> &plusmn;$(NAN) <td> int.min
 *	)
 */


real frexp(real value, out int exp)
{
    ushort* vu = cast(ushort*)&value;
    long* vl = cast(long*)&value;
    uint ex;

    // If exponent is non-zero
    ex = vu[4] & 0x7FFF;
    if (ex)
    {
	if (ex == 0x7FFF)
	{   // infinity or NaN
	    if (*vl &  0x7FFFFFFFFFFFFFFF)	// if NaN
	    {	*vl |= 0xC000000000000000;	// convert $(NAN)S to $(NAN)Q
		exp = int.min;
	    }
	    else if (vu[4] & 0x8000)
	    {	// negative infinity
		exp = int.min;
	    }
	    else
	    {	// positive infinity
		exp = int.max;
	    }
	}
	else
	{
	    exp = ex - 0x3FFE;
	    vu[4] = (0x8000 & vu[4]) | 0x3FFE;
	}
    }
    else if (!*vl)
    {
	// value is +-0.0
	exp = 0;
    }
    else
    {	// denormal
	int i = -0x3FFD;

	do
	{
	    i--;
	    *vl <<= 1;
	} while (*vl > 0);
	exp = i;
        vu[4] = (0x8000 & vu[4]) | 0x3FFE;
    }
    return value;
}


unittest
{
    static real vals[][3] =	// x,frexp,exp
    [
	[0.0,	0.0,	0],
	[-0.0,	-0.0,	0],
	[1.0,	.5,	1],
	[-1.0,	-.5,	1],
	[2.0,	.5,	2],
	[155.67e20,	0x1.A5F1C2EB3FE4Fp-1,	74],	// normal
	[1.0e-320,	0.98829225,		-1063],
	[real.min,	.5,		-16381],
	[real.min/2.0L,	.5,		-16382],	// denormal

	[real.infinity,real.infinity,int.max],
	[-real.infinity,-real.infinity,int.min],
	[real.nan,real.nan,int.min],
	[-real.nan,-real.nan,int.min],

	// Don't really support signalling nan's in D
	//[real.nans,real.nan,int.min],
	//[-real.nans,-real.nan,int.min],
    ];
    int i;

    for (i = 0; i < vals.length; i++)
    {
	real x = vals[i][0];
	real e = vals[i][1];
	int exp = cast(int)vals[i][2];
	int eptr;
	real v = frexp(x, eptr);

	//printf("frexp(%Lg) = %.8Lg, should be %.8Lg, eptr = %d, should be %d\n", x, v, e, eptr, exp);
	assert(mfeq(e, v, .0000001));
	assert(exp == eptr);
    }
}


/******************************************
 * Extracts the exponent of x as a signed integral value.
 *
 * If x is not a special value, the result is the same as
 * <tt>cast(int)logb(x)</tt>.
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th>ilogb(x)     <th> Range error?
 *	<tr> <td> 0               <td> FP_ILOGB0   <td> yes
 *	<tr> <td> &plusmn;&infin; <td> +&infin;    <td> no
 *	<tr> <td> $(NAN)          <td> FP_ILOGBNAN <td> no
 *	)
 */
int ilogb(real x)		{ return std.c.math.ilogbl(x); }

alias std.c.math.FP_ILOGB0   FP_ILOGB0;
alias std.c.math.FP_ILOGBNAN FP_ILOGBNAN;


/*******************************************
 * Compute n * 2$(SUP exp)
 * References: frexp
 */

real ldexp(real n, int exp);	/* intrinsic */

/**************************************
 * Calculate the natural logarithm of x.
 *
 *	$(TABLE_SV
 *	<tr> <th> x           <th> log(x)   <th> divide by 0? <th> invalid?
 *	<tr> <td> &plusmn;0.0 <td> -&infin; <td> yes          <td> no
 *	<tr> <td> &lt; 0.0    <td> $(NAN)   <td> no           <td> yes
 *	<tr> <td> +&infin;    <td> +&infin; <td> no           <td> no
 *	)
 */

real log(real x)		{ return std.c.math.logl(x); }

/**************************************
 * Calculate the base-10 logarithm of x.
 *
 *	$(TABLE_SV
 *	<tr> <th> x           <th> log10(x) <th> divide by 0? <th> invalid?
 *	<tr> <td> &plusmn;0.0 <td> -&infin; <td> yes          <td> no
 *	<tr> <td> &lt; 0.0    <td> $(NAN)   <td> no           <td> yes
 *	<tr> <td> +&infin;    <td> +&infin; <td> no           <td> no
 *	)
 */

real log10(real x)		{ return std.c.math.log10l(x); }

/******************************************
 *	Calculates the natural logarithm of 1 + x.
 *
 *	For very small x, log1p(x) will be more accurate than 
 *	log(1 + x). 
 *
 *	$(TABLE_SV
 *	<tr> <th> x           <th> log1p(x)    <th> divide by 0? <th> invalid?
 *	<tr> <td> &plusmn;0.0 <td> &plusmn;0.0 <td> no           <td> no
 *	<tr> <td> -1.0        <td> -&infin;    <td> yes          <td> no
 *	<tr> <td> &lt;-1.0    <td> $(NAN)      <td> no           <td> yes
 *	<tr> <td> +&infin;    <td> -&infin;    <td> no           <td> no
 *	)
 */

real log1p(real x)		{ return std.c.math.log1pl(x); }

/***************************************
 * Calculates the base-2 logarithm of x:
 * log<sub>2</sub>x
 *
 *	$(TABLE_SV
 *	<tr> <th> x 	      <th> log2(x)  <th> divide by 0? <th> invalid?
 *	<tr> <td> &plusmn;0.0 <td> -&infin; <td> yes          <td> no 
 *	<tr> <td> &lt; 0.0    <td> $(NAN)   <td> no           <td> yes 
 *	<tr> <td> +&infin;    <td> +&infin; <td> no           <td> no 
 *	)
 */
real log2(real x)		{ return std.c.math.log2l(x); }

/*****************************************
 * Extracts the exponent of x as a signed integral value.
 *
 * If x is subnormal, it is treated as if it were normalized.
 * For a positive, finite x: 
 *
 * <pre>
 * 1 &lt;= <i>x</i> * FLT_RADIX$(SUP -logb(x)) &lt; FLT_RADIX 
 * </pre>
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> logb(x)  <th> Divide by 0? 
 *	<tr> <td> &plusmn;&infin; <td> +&infin; <td> no
 *	<tr> <td> &plusmn;0.0     <td> -&infin; <td> yes 
 *	)
 */
real logb(real x)		{ return std.c.math.logbl(x); }

/************************************
 * Calculates the remainder from the calculation x/y.
 * Returns:
 * The value of x - i * y, where i is the number of times that y can 
 * be completely subtracted from x. The result has the same sign as x. 
 *
 *	$(TABLE_SV
 *	<tr> <th> x                 <th> y               <th> modf(x, y) 	<th> invalid?
 *	<tr> <td> &plusmn;0.0       <td> not 0.0         <td> &plusmn;0.0 	<td> no
 *	<tr> <td> &plusmn;&infin;   <td> anything        <td> $(NAN) 		<td> yes
 *	<tr> <td> anything          <td> &plusmn;0.0     <td> $(NAN) 		<td> yes
 *	<tr> <td> !=&plusmn;&infin; <td> &plusmn;&infin; <td> x 		<td> no
 *	)
 */
real modf(real x, inout real y)	{ return std.c.math.modfl(x,&y); }

/*************************************
 * Efficiently calculates x * 2$(SUP n).
 *
 * scalbn handles underflow and overflow in 
 * the same fashion as the basic arithmetic operators. 
 *
 *	$(TABLE_SV
 *	<tr> <th> x                <th> scalb(x)
 *	<tr> <td> &plusmn;&infin; <td> &plusmn;&infin; 
 *	<tr> <td> &plusmn;0.0      <td> &plusmn;0.0 
 *	)
 */
real scalbn(real x, int n)
{
    version (linux)
	return std.c.math.scalbnl(x, n);
    else
	throw new NotImplemented("scalbn");
}

/***************
 * Calculates the cube root x.
 *
 *	$(TABLE_SV
 *	<tr> <th> <i>x</i>	<th> cbrt(x)    <th> invalid?
 *	<tr> <td> &plusmn;0.0	<td> &plusmn;0.0	<td> no 
 *	<tr> <td> $(NAN)	<td> $(NAN) 	<td> yes 
 *	<tr> <td> &plusmn;&infin;	<td> &plusmn;&infin; <td> no 
 *	)
 */
real cbrt(real x)		{ return std.c.math.cbrtl(x); }


/*******************************
 * Returns |x|
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> fabs(x)
 *	<tr> <td> &plusmn;0.0     <td> +0.0 
 *	<tr> <td> &plusmn;&infin; <td> +&infin; 
 *	)
 */
real fabs(real x);	/* intrinsic */


/***********************************************************************
 * Calculates the length of the 
 * hypotenuse of a right-angled triangle with sides of length x and y. 
 * The hypotenuse is the value of the square root of 
 * the sums of the squares of x and y:
 *
 *	sqrt(x&sup2; + y&sup2;)
 *
 * Note that hypot(x, y), hypot(y, x) and
 * hypot(x, -y) are equivalent.
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> y           <th> hypot(x, y) <th> invalid?
 *	<tr> <td> x               <td> &plusmn;0.0 <td> |x|         <td> no
 *	<tr> <td> &plusmn;&infin; <td> y           <td> +&infin;    <td> no
 *	<tr> <td> &plusmn;&infin; <td> $(NAN)      <td> +&infin;    <td> no
 *	)
 */

real hypot(real x, real y)
{
    /*
     * This is based on code from:
     * Cephes Math Library Release 2.1:  January, 1989
     * Copyright 1984, 1987, 1989 by Stephen L. Moshier
     * Direct inquiries to 30 Frost Street, Cambridge, MA 02140
     */

    const int PRECL = 32;
    const int MAXEXPL = real.max_exp; //16384;
    const int MINEXPL = real.min_exp; //-16384;

    real xx, yy, b, re, im;
    int ex, ey, e;

    // Note, hypot(INFINITY, NAN) = INFINITY.
    if (isinf(x) || isinf(y))
	return real.infinity;

    if (isnan(x))
	return x;
    if (isnan(y))
	return y;

    re = fabs(x);
    im = fabs(y);

    if (re == 0.0)
	return im;
    if (im == 0.0)
	return re;

    // Get the exponents of the numbers
    xx = frexp(re, ex);
    yy = frexp(im, ey);

    // Check if one number is tiny compared to the other
    e = ex - ey;
    if (e > PRECL)
	return re;
    if (e < -PRECL)
	return im;

    // Find approximate exponent e of the geometric mean.
    e = (ex + ey) >> 1;

    // Rescale so mean is about 1
    xx = ldexp(re, -e);
    yy = ldexp(im, -e);

    // Hypotenuse of the right triangle
    b = sqrt(xx * xx  +  yy * yy);

    // Compute the exponent of the answer.
    yy = frexp(b, ey);
    ey = e + ey;

    // Check it for overflow and underflow.
    if (ey > MAXEXPL + 2)
    {
	//return __matherr(_OVERFLOW, INFINITY, x, y, "hypotl");
	return real.infinity;
    }
    if (ey < MINEXPL - 2)
	return 0.0;

    // Undo the scaling
    b = ldexp(b, e);
    return b;
}

unittest
{
    static real vals[][3] =	// x,y,hypot
    [
	[	0,	0,	0],
	[	0,	-0,	0],
	[	3,	4,	5],
	[	-300,	-400,	500],
	[	real.min, real.min, 4.75473e-4932L],
	[	real.max/2, real.max/2, 0x1.6a09e667f3bcc908p+16383L /*8.41267e+4931L*/],
	[	real.infinity, real.nan, real.infinity],
	[	real.nan, real.nan, real.nan],
    ];
    int i;

    for (i = 0; i < vals.length; i++)
    {
	real x = vals[i][0];
	real y = vals[i][1];
	real z = vals[i][2];
	real h = hypot(x, y);

	//printf("hypot(%Lg, %Lg) = %Lg, should be %Lg\n", x, y, h, z);
	//if (!mfeq(z, h, .0000001))
	    //printf("%La\n", h);
	assert(mfeq(z, h, .0000001));
    }
}

/**********************************
 * Returns the error function of x.
 *
 * <img src="erf.gif" alt="error function">
 */
real erf(real x)		{ return std.c.math.erfl(x); }

/**********************************
 * Returns the complementary error function of x, which is 1 - erf(x).
 *
 * <img src="erfc.gif" alt="complementary error function">
 */
real erfc(real x)		{ return std.c.math.erfcl(x); }

/***********************************
 * Natural logarithm of gamma function.
 *
 * Returns the base e (2.718...) logarithm of the absolute
 * value of the gamma function of the argument.
 *
 * For reals, lgamma is equivalent to log(fabs(tgamma(x))).
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> log$(GAMMA)(x) <th>invalid?
 *	<tr> <td> NaN             <td> NaN           <td> yes
 *	<tr> <td> integer <= 0    <td> +&infin;      <td> yes
 *	<tr> <td> 1, 2            <td> +0.0          <td> no
 *	<tr> <td> &plusmn;&infin;  <td> +&infin;      <td> no
 *	)
 */
/* Documentation prepared by Don Clugston */
real lgamma(real x)
{
    return std.c.math.lgammal(x);

    // Use etc.gamma.lgamma for those C systems that are missing it
}

/***********************************
 *  The gamma function, $(GAMMA)(x)
 *
 *  Generalizes the factorial function to real and complex numbers.
 *  Like x!, $(GAMMA)(x+1) = x*$(GAMMA)(x).
 *
 *  Mathematically, if z.re > 0 then
 *   $(GAMMA)(z) =<big>$(INTEGRAL)<sub><small>0</small></sub><sup>&infin;</sup></big>t<sup>z-1</sup>e<sup>-t</sup>dt
 *
 *	$(TABLE_SV
 *	<tr> <th> x               <th> $(GAMMA)(x)   <th>invalid?
 *	<tr> <td> NAN             <td> NAN           <td> yes
 *	<tr> <td> &plusmn;0.0     <td> &plusmn;&infin;      <td> yes
 *	<tr> <td> integer > 0     <td> (x-1)!        <td> no
 *	<tr> <td> integer < 0     <td> NAN           <td> yes
 *	<tr> <td> +&infin;        <td> +&infin;      <td> no
 *	<tr> <td> -&infin;        <td> NAN           <td> yes
 *	)
 *
 *  References:
 *     cephes, $(LINK http://en.wikipedia.org/wiki/Gamma_function)
 */
/* Documentation prepared by Don Clugston */
real tgamma(real x)
{
    return std.c.math.tgammal(x);

    // Use etc.gamma.tgamma for those C systems that are missing it
}

/**************************************
 * Returns the value of x rounded upward to the next integer
 * (toward positive infinity).
 */
real ceil(real x)		{ return std.c.math.ceill(x); }

/**************************************
 * Returns the value of x rounded downward to the next integer
 * (toward negative infinity).
 */
real floor(real x)		{ return std.c.math.floorl(x); }

/******************************************
 * Rounds x to the nearest integer value, using the current rounding 
 * mode.
 *
 * Unlike the rint functions, nearbyint does not raise the 
 * FE_INEXACT exception. 
 */
real nearbyint(real x) { return std.c.math.nearbyintl(x); }

/**********************************
 * Rounds x to the nearest integer value, using the current rounding
 * mode.
 * If the return value is not equal to x, the FE_INEXACT
 * exception is raised.
 * <b>nearbyint</b> performs
 * the same operation, but does not set the FE_INEXACT exception.
 */
real rint(real x);	/* intrinsic */

/***************************************
 * Rounds x to the nearest integer value, using the current rounding
 * mode.
 */
long lrint(real x)
{
    version (linux)
	return std.c.math.llrintl(x);
    else
	throw new NotImplemented("lrint");
}

/*******************************************
 * Return the value of x rounded to the nearest integer.
 * If the fractional part of x is exactly 0.5, the return value is rounded to
 * the even integer. 
 */
real round(real x) { return std.c.math.roundl(x); }

/**********************************************
 * Return the value of x rounded to the nearest integer.
 *
 * If the fractional part of x is exactly 0.5, the return value is rounded
 * away from zero.
 */
long lround(real x)
{
    version (linux)
	return std.c.math.llroundl(x);
    else
	throw new NotImplemented("lround");
}

/****************************************************
 * Returns the integer portion of x, dropping the fractional portion. 
 *
 * This is also know as "chop" rounding. 
 */
real trunc(real x) { return std.c.math.truncl(x); }

/****************************************************
 * Calculate the remainder x REM y, following IEC 60559.
 *
 * REM is the value of x - y * n, where n is the integer nearest the exact 
 * value of x / y.
 * If |n - x / y| == 0.5, n is even.
 * If the result is zero, it has the same sign as x.
 * Otherwise, the sign of the result is the sign of x / y.
 * Precision mode has no affect on the remainder functions.
 *
 * remquo returns n in the parameter n.
 *
 *	$(TABLE_SV
 *	<tr> <th> x                  <th> y               <th> remainder(x, y)  <th> n   <th> invalid?
 *	<tr> <td> &plusmn;0.0        <td> not 0.0         <td> &plusmn;0.0 	<td> 0.0 <td> no
 *	<tr> <td> &plusmn;&infin;    <td> anything        <td> $(NAN)		<td> ?   <td> yes
 *	<tr> <td> anything           <td> &plusmn;0.0     <td> $(NAN) 		<td> ?   <td> yes
 *	<tr> <td> != &plusmn;&infin; <td> &plusmn;&infin; <td> x 		<td> ?   <td> no
 *	)
 */
real remainder(real x, real y) { return std.c.math.remainderl(x, y); }

real remquo(real x, real y, out int n)	/// ditto
{
    version (linux)
	return std.c.math.remquol(x, y, &n);
    else
	throw new NotImplemented("remquo");
}

/*********************************
 * Returns !=0 if e is a NaN.
 */

int isnan(real e)
{
    ushort* pe = cast(ushort *)&e;
    ulong*  ps = cast(ulong *)&e;

    return (pe[4] & 0x7FFF) == 0x7FFF &&
	    *ps & 0x7FFFFFFFFFFFFFFF;
}

unittest
{
    assert(isnan(float.nan));
    assert(isnan(-double.nan));
    assert(isnan(real.nan));

    assert(!isnan(53.6));
    assert(!isnan(float.infinity));
}

/*********************************
 * Returns !=0 if e is finite.
 */

int isfinite(real e)
{
    ushort* pe = cast(ushort *)&e;

    return (pe[4] & 0x7FFF) != 0x7FFF;
}

unittest
{
    assert(isfinite(1.23));
    assert(!isfinite(double.infinity));
    assert(!isfinite(float.nan));
}


/*********************************
 * Returns !=0 if x is normalized.
 */

/* Need one for each format because subnormal floats might
 * be converted to normal reals.
 */

int isnormal(float x)
{
    uint *p = cast(uint *)&x;
    uint e;

    e = *p & 0x7F800000;
    //printf("e = x%x, *p = x%x\n", e, *p);
    return e && e != 0x7F800000;
}

/// ditto

int isnormal(double d)
{
    uint *p = cast(uint *)&d;
    uint e;

    e = p[1] & 0x7FF00000;
    return e && e != 0x7FF00000;
}

/// ditto

int isnormal(real e)
{
    ushort* pe = cast(ushort *)&e;
    long*   ps = cast(long *)&e;

    return (pe[4] & 0x7FFF) != 0x7FFF && *ps < 0;
}

unittest
{
    float f = 3;
    double d = 500;
    real e = 10e+48;

    assert(isnormal(f));
    assert(isnormal(d));
    assert(isnormal(e));
}

/*********************************
 * Is number subnormal? (Also called "denormal".)
 * Subnormals have a 0 exponent and a 0 most significant mantissa bit.
 */

/* Need one for each format because subnormal floats might
 * be converted to normal reals.
 */

int issubnormal(float f)
{
    uint *p = cast(uint *)&f;

    //printf("*p = x%x\n", *p);
    return (*p & 0x7F800000) == 0 && *p & 0x007FFFFF;
}

unittest
{
    float f = 3.0;

    for (f = 1.0; !issubnormal(f); f /= 2)
	assert(f != 0);
}

/// ditto

int issubnormal(double d)
{
    uint *p = cast(uint *)&d;

    return (p[1] & 0x7FF00000) == 0 && (p[0] || p[1] & 0x000FFFFF);
}

unittest
{
    double f;

    for (f = 1; !issubnormal(f); f /= 2)
	assert(f != 0);
}

/// ditto

int issubnormal(real e)
{
    ushort* pe = cast(ushort *)&e;
    long*   ps = cast(long *)&e;

    return (pe[4] & 0x7FFF) == 0 && *ps > 0;
}

unittest
{
    real f;

    for (f = 1; !issubnormal(f); f /= 2)
	assert(f != 0);
}

/*********************************
 * Return !=0 if e is &plusmn;&infin;.
 */

int isinf(real e)
{
    ushort* pe = cast(ushort *)&e;
    ulong*  ps = cast(ulong *)&e;

    return (pe[4] & 0x7FFF) == 0x7FFF &&
	    *ps == 0x8000000000000000;
}

unittest
{
    assert(isinf(float.infinity));
    assert(!isinf(float.nan));
    assert(isinf(double.infinity));
    assert(isinf(-real.infinity));

    assert(isinf(-1.0 / 0.0));
}

/*********************************
 * Return 1 if sign bit of e is set, 0 if not.
 */

int signbit(real e)
{
    ubyte* pe = cast(ubyte *)&e;

//printf("e = %Lg\n", e);
    return (pe[9] & 0x80) != 0;
}

unittest
{
    debug (math) printf("math.signbit.unittest\n");
    assert(!signbit(float.nan));
    assert(signbit(-float.nan));
    assert(!signbit(168.1234));
    assert(signbit(-168.1234));
    assert(!signbit(0.0));
    assert(signbit(-0.0));
}

/*********************************
 * Return a value composed of to with from's sign bit.
 */

real copysign(real to, real from)
{
    ubyte* pto   = cast(ubyte *)&to;
    ubyte* pfrom = cast(ubyte *)&from;

    pto[9] &= 0x7F;
    pto[9] |= pfrom[9] & 0x80;

    return to;
}

unittest
{
    real e;

    e = copysign(21, 23.8);
    assert(e == 21);

    e = copysign(-21, 23.8);
    assert(e == 21);

    e = copysign(21, -23.8);
    assert(e == -21);

    e = copysign(-21, -23.8);
    assert(e == -21);

    e = copysign(real.nan, -23.8);
    assert(isnan(e) && signbit(e));
}

/******************************************
 * Creates a quiet NAN with the information from tagp[] embedded in it.
 */
real nan(char[] tagp) { return std.c.math.nanl(toStringz(tagp)); }

/******************************************
 * Calculates the next representable value after x in the direction of y. 
 *
 * If y > x, the result will be the next largest floating-point value;
 * if y < x, the result will be the next smallest value.
 * If x == y, the result is y.
 * The FE_INEXACT and FE_OVERFLOW exceptions will be raised if x is finite and
 * the function result is infinite. The FE_INEXACT and FE_UNDERFLOW 
 * exceptions will be raised if the function value is subnormal, and x is 
 * not equal to y. 
 */
real nextafter(real x, real y)
{
    version (linux)
	return std.c.math.nextafterl(x, y);
    else
	throw new NotImplemented("nextafter");
}

//real nexttoward(real x, real y) { return std.c.math.nexttowardl(x, y); }

/*******************************************
 * Returns the positive difference between x and y.
 * Returns:
 *	<table border=1 cellpadding=4 cellspacing=0>
 *	<tr> <th> x, y   <th> fdim(x, y)
 *	<tr> <td> x > y  <td> x - y
 *	<tr> <td> x <= y <td> +0.0
 *	</table>
 */
real fdim(real x, real y) { return (x > y) ? x - y : +0.0; }

/****************************************
 * Returns the larger of x and y.
 */
real fmax(real x, real y) { return x > y ? x : y; }

/****************************************
 * Returns the smaller of x and y.
 */
real fmin(real x, real y) { return x < y ? x : y; }

/**************************************
 * Returns (x * y) + z, rounding only once according to the
 * current rounding mode.
 */
real fma(real x, real y, real z) { return (x * y) + z; }

/*******************************************************************
 * Fast integral powers.
 */

real pow(real x, uint n)
{
    real p;

    switch (n)
    {
	case 0:
	    p = 1.0;
	    break;

	case 1:
	    p = x;
	    break;

	case 2:
	    p = x * x;
	    break;

	default:
	    p = 1.0;
	    while (1)
	    {
		if (n & 1)
		    p *= x;
		n >>= 1;
		if (!n)
		    break;
		x *= x;
	    }
	    break;
    }
    return p;
}

/// ditto

real pow(real x, int n)
{
    if (n < 0)
	return pow(x, cast(real)n);
    else
	return pow(x, cast(uint)n);
}

/*********************************************
 * Calculates x$(SUP y).
 *
 * $(TABLE_SV
 * <tr>
 * <th> x <th> y <th> pow(x, y) <th> div 0 <th> invalid?
 * <tr>
 * <td> anything 	<td> &plusmn;0.0 	<td> 1.0 	<td> no 	<td> no 
 * <tr>
 * <td> |x| &gt; 1 	<td> +&infin; 		<td> +&infin; 	<td> no 	<td> no 
 * <tr>
 * <td> |x| &lt; 1 	<td> +&infin; 		<td> +0.0 	<td> no 	<td> no 
 * <tr>
 * <td> |x| &gt; 1 	<td> -&infin; 		<td> +0.0 	<td> no 	<td> no 
 * <tr>
 * <td> |x| &lt; 1 	<td> -&infin; 		<td> +&infin; 	<td> no 	<td> no 
 * <tr>
 * <td> +&infin; 	<td> &gt; 0.0 		<td> +&infin; 	<td> no 	<td> no 
 * <tr>
 * <td> +&infin; 	<td> &lt; 0.0 		<td> +0.0 	<td> no 	<td> no 
 * <tr>
 * <td> -&infin; 	<td> odd integer &gt; 0.0	<td> -&infin; 	<td> no 	<td> no 
 * <tr>
 * <td> -&infin;  	<td> &gt; 0.0, not odd integer	<td> +&infin; 	<td> no 	<td> no
 * <tr>
 * <td> -&infin; 	<td> odd integer &lt; 0.0  	<td> -0.0 	<td> no 	<td> no 
 * <tr>
 * <td> -&infin; 	<td> &lt; 0.0, not odd integer 	<td> +0.0 	<td> no 	<td> no 
 * <tr>
 * <td> &plusmn;1.0 	<td> &plusmn;&infin; 		<td> $(NAN) 	<td> no 	<td> yes 
 * <tr>
 * <td> &lt; 0.0 	<td> finite, nonintegral 	<td> $(NAN) 	<td> no 	<td> yes
 * <tr>
 * <td> &plusmn;0.0 	<td> odd integer &lt; 0.0	<td> &plusmn;&infin; <td> yes 	<td> no 
 * <tr>
 * <td> &plusmn;0.0 	<td> &lt; 0.0, not odd integer 	<td> +&infin; 	<td> yes 	<td> no
 * <tr>
 * <td> &plusmn;0.0 	<td> odd integer &gt; 0.0	<td> &plusmn;0.0 <td> no 	<td> no 
 * <tr>
 * <td> &plusmn;0.0 	<td> &gt; 0.0, not odd integer 	<td> +0.0 	<td> no 	<td> no 
 * )
 */

real pow(real x, real y)
{
    version (linux) // C pow() often does not handle special values correctly
    {
	if (isnan(y))
	    return real.nan;

	if (y == 0)
	    return 1;		// even if x is $(NAN)
	if (isnan(x) && y != 0)
	    return real.nan;
	if (isinf(y))
	{
	    if (fabs(x) > 1)
	    {
		if (signbit(y))
		    return +0.0;
		else
		    return real.infinity;
	    }
	    else if (fabs(x) == 1)
	    {
		return real.nan;
	    }
	    else // < 1
	    {
		if (signbit(y))
		    return real.infinity;
		else
		    return +0.0;
	    }
	}
	if (isinf(x))
	{
	    if (signbit(x))
	    {   long i;

		i = cast(long)y;
		if (y > 0)
		{
		    if (i == y && i & 1)
			return -real.infinity;
		    else
			return real.infinity;
		}
		else if (y < 0)
		{
		    if (i == y && i & 1)
			return -0.0;
		    else
			return +0.0;
		}
	    }
	    else
	    {
		if (y > 0)
		    return real.infinity;
		else if (y < 0)
		    return +0.0;
	    }
	}

	if (x == 0.0)
	{
	    if (signbit(x))
	    {   long i;

		i = cast(long)y;
		if (y > 0)
		{
		    if (i == y && i & 1)
			return -0.0;
		    else
			return +0.0;
		}
		else if (y < 0)
		{
		    if (i == y && i & 1)
			return -real.infinity;
		    else
			return real.infinity;
		}
	    }
	    else
	    {
		if (y > 0)
		    return +0.0;
		else if (y < 0)
		    return real.infinity;
	    }
	}
    }
    return std.c.math.powl(x, y);
}

unittest
{
    real x = 46;

    assert(pow(x,0) == 1.0);
    assert(pow(x,1) == x);
    assert(pow(x,2) == x * x);
    assert(pow(x,3) == x * x * x);
    assert(pow(x,8) == (x * x) * (x * x) * (x * x) * (x * x));
}

/****************************************
 * Simple function to compare two floating point values
 * to a specified precision.
 * Returns:
 *	1	match
 *	0	nomatch
 */

private int mfeq(real x, real y, real precision)
{
    if (x == y)
	return 1;
    if (isnan(x))
	return isnan(y);
    if (isnan(y))
	return 0;
    return fabs(x - y) <= precision;
}

private int iabs(int i)
{
    return i >= 0 ? i : -i;
}
 

/**************************************
 * To what precision is x equal to y?
 *
 * Returns: the number of mantissa bits which are equal in x and y.
 * eg, 0x1.F8p+60 and 0x1.F1p+60 are equal to 5 bits of precision.
 *
 *	$(TABLE_SV
 *	<tr> <th> x      <th> y         <th> feqrel(x, y)
 *	<tr> <td> x      <td> x         <td> real.mant_dig
 *	<tr> <td> x      <td> &gt;= 2*x <td> 0
 *	<tr> <td> x      <td> &lt;= x/2 <td> 0
 *	<tr> <td> $(NAN) <td> any       <td> 0
 *	<tr> <td> any    <td> $(NAN)    <td> 0
 *	)
 */

int feqrel(real x, real y)
{
    /* Public Domain. Author: Don Clugston, 18 Aug 2005.
     */

    if (x == y)
	return real.mant_dig; // ensure diff!=0, cope with INF.

    real diff = fabs(x - y);

    ushort *pa = cast(ushort *)(&x);
    ushort *pb = cast(ushort *)(&y);
    ushort *pd = cast(ushort *)(&diff);

    // The difference in abs(exponent) between x or y and abs(x-y)
    // is equal to the number of mantissa bits of x which are
    // equal to y. If negative, x and y have different exponents.
    // If positive, x and y are equal to 'bitsdiff' bits.
    // AND with 0x7FFF to form the absolute value.
    // To avoid out-by-1 errors, we subtract 1 so it rounds down
    // if the exponents were different. This means 'bitsdiff' is
    // always 1 lower than we want, except that if bitsdiff==0,
    // they could have 0 or 1 bits in common.
    int bitsdiff = ( ((pa[4]&0x7FFF) + (pb[4]&0x7FFF)-1)>>1) - pd[4];

    if (pd[4] == 0)
    {	// Difference is denormal
	// For denormals, we need to add the number of zeros that
	// lie at the start of diff's mantissa.
	// We do this by multiplying by 2^real.mant_dig
	diff *= 0x1p+63;
	return bitsdiff + real.mant_dig - pd[4];
    }

    if (bitsdiff > 0)
	return bitsdiff + 1; // add the 1 we subtracted before

    // Avoid out-by-1 errors when factor is almost 2.
    return (bitsdiff == 0) ? (pa[4] == pb[4]) : 0;
}

unittest
{
   // Exact equality
   assert(feqrel(real.max,real.max)==real.mant_dig);
   assert(feqrel(0,0)==real.mant_dig);
   assert(feqrel(7.1824,7.1824)==real.mant_dig);
   assert(feqrel(real.infinity,real.infinity)==real.mant_dig);

   // a few bits away from exact equality
   real w=1;
   for (int i=1; i<real.mant_dig-1; ++i) {
      assert(feqrel(1+w*real.epsilon,1)==real.mant_dig-i);
      assert(feqrel(1-w*real.epsilon,1)==real.mant_dig-i);
      assert(feqrel(1,1+(w-1)*real.epsilon)==real.mant_dig-i+1);
      w*=2;
   }
   assert(feqrel(1.5+real.epsilon,1.5)==real.mant_dig-1);
   assert(feqrel(1.5-real.epsilon,1.5)==real.mant_dig-1);
   assert(feqrel(1.5-real.epsilon,1.5+real.epsilon)==real.mant_dig-2);

   // Numbers that are close
   assert(feqrel(0x1.Bp+84, 0x1.B8p+84)==5);
   assert(feqrel(0x1.8p+10, 0x1.Cp+10)==2);
   assert(feqrel(1.5*(1-real.epsilon), 1)==2);
   assert(feqrel(1.5, 1)==1);
   assert(feqrel(2*(1-real.epsilon), 1)==1);

   // Factors of 2
   assert(feqrel(real.max,real.infinity)==0);
   assert(feqrel(2*(1-real.epsilon), 1)==1);
   assert(feqrel(1, 2)==0);
   assert(feqrel(4, 1)==0);

   // Extreme inequality
   assert(feqrel(real.nan,real.nan)==0);
   assert(feqrel(0,-real.nan)==0);
   assert(feqrel(real.nan,real.infinity)==0);
   assert(feqrel(real.infinity,-real.infinity)==0);
   assert(feqrel(-real.max,real.infinity)==0);
   assert(feqrel(real.max,-real.max)==0);
}


/***********************************
 * Evaluate polynomial A(x) = a<sub>0</sub> + a<sub>1</sub>x + a<sub>2</sub>x&sup2; + a<sub>3</sub>x&sup3; ...
 *
 * Uses Horner's rule A(x) = a<sub>0</sub> + x(a<sub>1</sub> + x(a<sub>2</sub> + x(a<sub>3</sub> + ...)))
 * Params:
 *	A =	array of coefficients a<sub>0</sub>, a<sub>1</sub>, etc.
 */ 
real poly(real x, real[] A)
in
{
    assert(A.length > 0);
}
body
{
    version (D_InlineAsm_X86)
    {
	asm	// assembler by W. Bright
	{
	    // EDX = (A.length - 1) * real.sizeof
	    mov     ECX,A[EBP]		; // ECX = A.length
	    dec     ECX			;
	    lea     EDX,[ECX][ECX*8]	;
	    add     EDX,ECX		;
	    add     EDX,A+4[EBP]	;
	    fld     real ptr [EDX]	; // ST0 = coeff[ECX]
	    jecxz   return_ST		;
	    fld     x[EBP]		; // ST0 = x
	    fxch    ST(1)		; // ST1 = x, ST0 = r
	    align   4			;
    L2:     fmul    ST,ST(1)		; // r *= x
	    fld     real ptr -10[EDX]	;
	    sub     EDX,10		; // deg--
	    faddp   ST(1),ST		;
	    dec     ECX			;
	    jne     L2			;
	    fxch    ST(1)		; // ST1 = r, ST0 = x
	    fstp    ST(0)		; // dump x
	    align   4			;
    return_ST:				;
	    ;
	}
    }
    else
    {
	int i = A.length - 1;
	real r = A[i];
	while (--i >= 0)
	{
	    r *= x;
	    r += A[i];
	}
	return r;
    }
}

unittest
{
    debug (math) printf("math.poly.unittest\n");
    real x = 3.1;
    static real pp[] = [56.1, 32.7, 6];

    assert( poly(x, pp) == (56.1L + (32.7L + 6L * x) * x) );
}


