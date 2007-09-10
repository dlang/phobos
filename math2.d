/*
 * Copyright (c) 2002
 * Pavel "EvilOne" Minayev
 *
 * Permission to use, copy, modify, distribute and sell this software
 * and its documentation for any purpose is hereby granted without fee,
 * provided that the above copyright notice appear in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation.  Author makes no representations about
 * the suitability of this software for any purpose. It is provided
 * "as is" without express or implied warranty.
 */
 
module math2;
import intrinsic;
private import math, string, c.stdlib, c.stdio;

//debug=math2;

/****************************************
 * compare floats with given precision
 */

bit feq(extended a, extended b)
{
	return feq(a, b, 0.000001);
} 
 
bit feq(extended a, extended b, extended eps)
{
	return abs(a - b) <= eps;
}

/*********************************
 * Modulus
 */
 
int abs(int n)
{
	return n > 0 ? n : -n;
}
 
long abs(long n)
{
	return n > 0 ? n : -n;
}

extended abs(extended n)
{
	// just let the compiler handle it
	return intrinsic.fabs(n);
}

/*********************************
 * Square
 */

int sqr(int n)
{
	return n * n;
}
 
long sqr(long n)
{
	return n * n;
} 
 
extended sqr(extended n)
{
	return n * n;
}

unittest
{
	assert(sqr(sqr(3)) == 81);
}

private ushort fp_cw_chop = 7999;

/*********************************
 * Integer part
 */
 
extended trunc(extended n)
{
	ushort cw;
	asm
	{
		fstcw cw;
		fldcw fp_cw_chop;
		fld n;
		frndint;
		fldcw cw;
	}	
}

unittest
{
	assert(feq(trunc(+123.456), +123.0L));
	assert(feq(trunc(-123.456), -123.0L));
}

/*********************************
 * Fractional part
 */
 
extended frac(extended n)
{
	return n - trunc(n);
}

unittest
{
	assert(feq(frac(+123.456), +0.456L));
	assert(feq(frac(-123.456), -0.456L));
}

/*********************************
 * Polynomial of X
 */
 
extended poly(extended x, extended[] coefficients)
{
	debug (math2) printf("poly(), coefficients.length = %d\n", coefficients.length);
	if (!coefficients.length)
		return 0;
	extended result = coefficients[coefficients.length - 1];
	for (int i = coefficients.length - 2; i >= 0; i--)
		result = result * x + coefficients[i];
	return result;
}

unittest
{
	debug (math2) printf("unittest.poly()\n");
	static extended[4] k = [ 4, 3, 2, 1 ];
	assert(feq(poly(2, k), cast(extended) 8 * 1 + 4 * 2 + 2 * 3 + 4));
}

/*********************************
 * Sign
 */

int sign(int n)
{
	return (n > 0 ? +1 : (n < 0 ? -1 : 0));
}

unittest
{
	assert(sign(0) == 0);
	assert(sign(+666) == +1);
	assert(sign(-666) == -1);
}
 
int sign(long n)
{
	return (n > 0 ? +1 : (n < 0 ? -1 : 0));
}

unittest
{
	assert(sign(0) == 0);
	assert(sign(+666L) == +1);
	assert(sign(-666L) == -1);
}
 
int sign(extended n)
{
	return (n > 0 ? +1 : (n < 0 ? -1 : 0));
}

unittest
{
	assert(sign(0.0L) == 0);
	assert(sign(+123.456L) == +1);
	assert(sign(-123.456L) == -1);
}

/**********************************************************
 * Cycles <-> radians <-> grads <-> degrees conversions
 */
 
extended cycle2deg(extended c)
{
	return c * 360;
}

extended cycle2rad(extended c)
{
	return c * PI * 2;
}

extended cycle2grad(extended c)
{
	return c * 400;
}

extended deg2cycle(extended d)
{
	return d / 360;
}

extended deg2rad(extended d)
{
	return d / 180 * PI;
}

extended deg2grad(extended d)
{
	return d / 90 * 100;
}

extended rad2deg(extended r)
{
	return r / PI * 180;
}

extended rad2cycle(extended r)
{
	return r / (PI * 2);
}

extended rad2grad(extended r)
{
	return r / PI * 200;
}

extended grad2deg(extended g)
{
	return g / 100 * 90;
}

extended grad2cycle(extended g)
{
	return g / 400;
}

extended grad2rad(extended g)
{
	return g / 200 * PI;
}

unittest
{
	assert(feq(cycle2deg(0.5), 180));
	assert(feq(cycle2rad(0.5), PI));
	assert(feq(cycle2grad(0.5), 200));
	assert(feq(deg2cycle(180), 0.5));
	assert(feq(deg2rad(180), PI));
	assert(feq(deg2grad(180), 200));
	assert(feq(rad2deg(PI), 180));
	assert(feq(rad2cycle(PI), 0.5));
	assert(feq(rad2grad(PI), 200));
	assert(feq(grad2deg(200), 180));
	assert(feq(grad2cycle(200), 0.5));
	assert(feq(grad2rad(200), PI));
}

/************************************
 * Arithmetic average of values
 */
 
extended avg(extended[] n)
{
	extended result = 0;
	for (uint i = 0; i < n.length; i++)
		result += n[i];
	return result / n.length;
}

unittest
{
	static extended[4] n = [ 1, 2, 4, 5 ];
	assert(feq(avg(n), 3));
}

/*************************************
 * Sum of values
 */

int sum(int[] n)
{
	long result = 0;
	for (uint i = 0; i < n.length; i++)
		result += n[i];
	return result;
}

unittest
{
	static int[3] n = [ 1, 2, 3 ];
	assert(sum(n) == 6);
}
 
long sum(long[] n)
{
	long result = 0;
	for (uint i = 0; i < n.length; i++)
		result += n[i];
	return result;
}

unittest
{
	static long[3] n = [ 1, 2, 3 ];
	assert(sum(n) == 6);
}
 
extended sum(extended[] n)
{
	extended result = 0;
	for (uint i = 0; i < n.length; i++)
		result += n[i];
	return result;
}

unittest
{
	static extended[3] n = [ 1, 2, 3 ];
	assert(feq(sum(n), 6));
}

/*************************************
 * The smallest value
 */

int min(int[] n)
{
	int result = int.max;
	for (uint i = 0; i < n.length; i++)
		if (n[i] < result)
			result = n[i];
	return result;
}

unittest
{
	static int[3] n = [ 2, -1, 0 ];
	assert(min(n) == -1);
}
 
long min(long[] n)
{
	long result = long.max;
	for (uint i = 0; i < n.length; i++)
		if (n[i] < result)
			result = n[i];
	return result;
}

unittest
{
	static long[3] n = [ 2, -1, 0 ];
	assert(min(n) == -1);
}

extended min(extended[] n)
{
	extended result = extended.max;
	for (uint i = 0; i < n.length; i++)
	{
		if (n[i] < result)
			result = n[i];
	}
	return result;
}

unittest
{
	static extended[3] n = [ 2.0, -1.0, 0.0 ];
	assert(feq(min(n), -1));
}

int min(int a, int b)
{
	return a < b ? a : b;
}

unittest
{
	assert(min(1, 2) == 1);
}

long min(long a, long b)
{
	return a < b ? a : b;
}

unittest
{
	assert(min(1L, 2L) == 1);
}

extended min(extended a, extended b)
{
	return a < b ? a : b;
}

unittest
{
	assert(feq(min(1.0L, 2.0L), 1.0L));
}

/*************************************
 * The largest value
 */

int max(int[] n)
{
	int result = int.min;
	for (uint i = 0; i < n.length; i++)
		if (n[i] > result)
			result = n[i];
	return result;
}

unittest
{
	static int[3] n = [ 0, 2, -1 ];
	assert(max(n) == 2);
}
 
long max(long[] n)
{
	long result = long.min;
	for (uint i = 0; i < n.length; i++)
		if (n[i] > result)
			result = n[i];
	return result;
}

unittest
{
	static long[3] n = [ 0, 2, -1 ];
	assert(max(n) == 2);
}

extended max(extended[] n)
{
	extended result = extended.min;
	for (uint i = 0; i < n.length; i++)
		if (n[i] > result)
			result = n[i];
	return result;
}

unittest
{
	static extended[3] n = [ 0.0, 2.0, -1.0 ];
	assert(feq(max(n), 2));
}

int max(int a, int b)
{
	return a > b ? a : b;
}

unittest
{
	assert(max(1, 2) == 2);
}

long max(long a, long b)
{
	return a > b ? a : b;
}

unittest
{
	assert(max(1L, 2L) == 2);
}

extended max(extended a, extended b)
{
	return a > b ? a : b;
}

unittest
{
	assert(feq(max(1.0L, 2.0L), 2.0L));
}

/*************************************
 * Arccosine
 */

extended acos(extended x) 
{
	return atan2(intrinsic.sqrt(1 - x * x), x);
}

unittest
{
	assert(feq(acos(0.5), PI / 3));
}

/*************************************
 * Arcsine
 */


extended asin(extended x)
{
	return atan2(x, intrinsic.sqrt(1 - x * x));
}

unittest
{
	assert(feq(asin(0.5), PI / 6));
}


/*************************************
 * Arctangent
 */

extended atan(extended x)
{
	asm
	{
		fld x;
		fld1;
		fpatan;
		fwait;
	}
}

unittest
{
	assert(feq(atan(intrinsic.sqrt(3)), PI / 3));
}


/*************************************
 * Arctangent y/x
 */

extended atan2(extended y, extended x)
{
	asm
	{
		fld y;
		fld x;
		fpatan;
		fwait;
	}
}

unittest
{
	assert(feq(atan2(1, intrinsic.sqrt(3)), PI / 6));
}


/*************************************
 * Arccotangent
 */

extended acot(extended x)
{
	return tan(1.0 / x);
}

unittest
{
	assert(feq(acot(cot(0.000001)), 0.000001));
}

/*************************************
 * Arcsecant
 */

extended asec(extended x)
{
	return intrinsic.cos(1.0 / x);
}


/*************************************
 * Arccosecant
 */

extended acosec(extended x)
{
	return intrinsic.sin(1.0 / x);
}

/*************************************
 * Tangent
 */

extended tan(extended x)
{
	asm
	{
		fld x;
		fptan;
		fstp ST(0);
		fwait;
	}
}

unittest
{
	assert(feq(tan(PI / 3), intrinsic.sqrt(3)));
}

/*************************************
 * Cotangent
 */

extended cot(extended x)
{
	asm
	{
		fld x;
		fptan;
		fdivrp;
		fwait;
	}
}

unittest
{
	assert(feq(cot(PI / 6), intrinsic.sqrt(3)));
}

/*************************************
 * Secant
 */

extended sec(extended x)
{
	asm
	{
		fld x;
		fcos;
		fld1;
		fdivrp;
		fwait;
	}
}


/*************************************
 * Cosecant
 */

extended cosec(extended x)
{
	asm
	{
		fld x;
		fsin;
		fld1;
		fdivrp;
		fwait;
	}
}

/*************************************
 * Hypotenuse of right triangle
 */

extended hypot(extended x, extended y)
{
	asm
	{
		fld y;
		fabs;
		fld x;
		fabs;
		fcom;
		fnstsw AX;
		test AH, 0x45;
		jnz _1;
		fxch ST(1);
_1:		fldz;
		fcomp;
		fnstsw AX;
		test AH, 0x40;
		jz _2;
		fstp ST(0);
		jmp _3;
_2:		fdiv ST, ST(1);
		fmul ST, ST(0);
		fld1;
		fadd;
		fsqrt;
		fmul;
_3:		fwait;
	}
}

unittest
{
	assert(feq(hypot(3, 4), 5));
}

/*********************************************
 * Extract mantissa and exponent from float
 */

extended frexp(extended x, out int exponent)
{
	asm
	{
		fld x;
		mov EDX, exponent;
		mov dword ptr [EDX], 0;
		ftst;
		fstsw AX;
		fwait;
		sahf;
		jz done;
		fxtract;
		fxch;	
		fistp dword ptr [EDX];
		fld1;
		fchs;
		fxch;
		fscale;
		inc dword ptr [EDX];
		fstp ST(1);
done:
		fwait;
	}
}

unittest
{
	int exponent;
	extended mantissa = frexp(123.456, exponent);
	assert(feq(mantissa * pow(2, exponent), 123.456));
}

/**********************************************
 * Make a float out of mantissa and exponent
 */

extended ldexp(extended x, int exponent)
{
	asm
	{
		fild exponent;
		fld x;
		fscale;
		fstp ST(1);
		fwait;
	}
}

unittest
{
	assert(feq(ldexp(666, 10), 666 * 1024));
}

/*************************************
 * Round to nearest int > x
 */

long ceil(extended x)
{
	return frac(x) > 0 ? trunc(x) + 1 : trunc(x);
}

unittest
{
	assert(ceil(+123.456) == +124);
	assert(ceil(-123.456) == -123);
}

/*************************************
 * Round to nearest int < x
 */

long floor(extended x)
{
	return frac(x) < 0 ? trunc(x) - 1 : trunc(x);
}

unittest
{
	assert(floor(+123.456) == +123);
	assert(floor(-123.456) == -124);
}

/*************************************
 * Base 10 logarithm
 */

extended log10(extended x)
{
	asm
	{
		fldlg2;
		fld x;
		fyl2x;
		fwait;
	}
}

unittest
{
	assert(feq(log10(1000), 3));
}

/*************************************
 * Base 2 logarithm
 */

extended log2(extended x)
{
	asm
	{
		fld1;
		fld x;
		fyl2x;
		fwait;
	}
}

unittest
{
	assert(feq(log2(1024), 10));
}

/*************************************
 * Natural logarithm
 */

extended log(extended x)
{
	asm
	{
		fldln2;
		fld x;
		fyl2x;
		fwait;
	}
}

unittest
{
	assert(feq(log(E), 1));
}

/*************************************
 * Natural logarithm of (x + 1)
 */

extended log1p(extended x)
{
	asm
	{
		fldln2;
		fld x;
		fyl2xp1;
		fwait;
	}
}

unittest
{
	assert(feq(log1p(E - 1), 1));
}

/*************************************
 * Logarithm
 */

extended log(extended x, extended base)
{
	asm
	{
		fld1;
		fld x;
		fyl2x;
		fld1;
		fld base;
		fyl2x;
		fdiv;
		fwait;
	}
}

unittest
{
	assert(feq(log(81, 3), 4));
}

/*************************************
 * (base + 1) logarithm of x
 */

extended log1p(extended x, extended base)
{
	asm
	{
		fld1;
		fld x;
		fyl2x;
		fld1;
		fld base;
		fyl2xp1;
		fdiv;
		fwait;
	}
}

unittest
{
	assert(feq(log1p(81, 3 - 1), 4));
}

/*************************************
 * Exponent
 */

extended exp(extended x)
{
	asm
	{
		fld x;
		fldl2e;
		fmul;
		fld ST(0);
		frndint;
		fsub ST(1), ST;
		fxch ST(1);
		f2xm1;
		fld1;
		fadd;
		fscale;
		fstp ST(1);
		fwait;
	}
}

unittest
{
	assert(feq(exp(3), E * E * E));
}

/*************************************
 * Base to exponent
 */

extended pow(extended base, extended exponent)
{
	return exp(exponent * log(base));
}

unittest
{
	assert(feq(pow(2, 10), 1024));
}

/*************************************
 * Hyperbolic cosine
 */

extended cosh(extended x)
{
	extended z = exp(x) / 2;
	return z + 0.25 / z;
}

unittest
{
	assert(feq(cosh(1), (E + 1.0 / E) / 2));
}

/*************************************
 * Hyperbolic sine
 */

extended sinh(extended x)
{
	extended z = exp(x) / 2;
	return z - 0.25 / z;
}

unittest
{
	assert(feq(sinh(1), (E - 1.0 / E) / 2));
}

/*************************************
 * Hyperbolic tangent
 */

private extended tanh_domain;

extended tanh(extended x)
{
	if (x > tanh_domain)
		return 1;
	else if (x < -tanh_domain)
		return -1;
	else
	{
		extended z = sqr(exp(x));
		return (z - 1) / (z + 1);
	}
}

unittest
{
	assert(feq(tanh(1), sinh(1) / cosh(1)));
}

/*************************************
 * Hyperbolic cotangent
 */

extended coth(extended x)
{
	return 1 / tanh(x);
}

unittest
{
	assert(feq(coth(1), cosh(1) / sinh(1)));
}

/*************************************
 * Hyperbolic secant
 */

extended sech(extended x)
{
	return 1 / cosh(x);
}

/*************************************
 * Hyperbolic cosecant
 */

extended cosech(extended x)
{
	return 1 / sinh(x);
}

/*************************************
 * Hyperbolic arccosine
 */

extended acosh(extended x)
{
	if (x <= 1)
		return 0;
	else if (x > 1.0e10)
		return log(2) + log(x);
	else
		return log(x + intrinsic.sqrt((x - 1) * (x + 1)));
}

unittest
{
	assert(acosh(0.5) == 0);
	assert(feq(acosh(cosh(3)), 3));
}

/*************************************
 * Hyperbolic arcsine
 */

extended asinh(extended x)
{
	if (!x)
		return 0;
	else if (x > 1.0e10)
		return log(2) + log(1.0e10);
	else if (x < -1.0e10)
		return -log(2) - log(1.0e10);
	else
	{
		extended z = x * x;
		return x > 0 ? 
			log1p(x + z / (1.0 + intrinsic.sqrt(1.0 + z))) :
			-log1p(-x + z / (1.0 + intrinsic.sqrt(1.0 + z)));
	}
}

unittest
{
	assert(asinh(0) == 0);
	assert(feq(asinh(sinh(3)), 3));
}

/*************************************
 * Hyperbolic arctangent
 */

extended atanh(extended x)
{
	if (!x)
		return 0;
	else
	{
		if (x >= 1)
			return extended.max;
		else if (x <= -1)
			return -extended.max;
		else
			return x > 0 ?
				0.5 * log1p((2.0 * x) / (1.0 - x)) :
				-0.5 * log1p((-2.0 * x) / (1.0 + x));
	}
}

unittest
{
	assert(atanh(0) == 0);
	assert(feq(atanh(tanh(0.5)), 0.5));
}

/*************************************
 * Hyperbolic arccotangent
 */

extended acoth(extended x)
{
	return 1 / acot(x);
}

unittest
{
	assert(feq(acoth(coth(0.01)), 100));
}

/*************************************
 * Hyperbolic arcsecant
 */

extended asech(extended x)
{
	return 1 / asec(x);
}

/*************************************
 * Hyperbolic arccosecant
 */

extended acosech(extended x)
{
	return 1 / acosec(x);
}

/*************************************
 * Convert string to float
 */

extended atof(char[] s)
{
	if (!s.length)
		return extended.nan;
	extended result = 0;
	uint i = 0;
	while (s[i] == "\t" || s[i] == " ")
		if (++i >= s.length)
			return extended.nan;
	bit neg = false;
	if (s[i] == "-")
	{
		neg = true;
		i++;
	}
	else if (s[i] == "+")
		i++;
	if (i >= s.length)
		return extended.nan;
	bit hex;
	if (s[s.length - 1] == "h")
	{
		hex = true;
		s.length = s.length - 1;
	}
	else if (i + 1 < s.length && s[i] == "0" && s[i+1] == "x")
	{
		hex = true;
		i += 2;
		if (i >= s.length)
			return extended.nan;
	}
	else
		hex = false;
	while (s[i] != ".")
	{
		if (hex)
		{
			if ((s[i] == "p" || s[i] == "P"))
				break;
			result *= 0x10;
		}
		else
		{
			if ((s[i] == "e" || s[i] == "E"))
				break;
			result *= 10;
		}
		if (s[i] >= "0" && s[i] <= "9")
			result += s[i] - "0";
		else if (hex)
		{
			if (s[i] >= "a" && s[i] <= "f")
				result += s[i] - "a" + 10;
			else if (s[i] >= "A" && s[i] <= "F")
				result += s[i] - "A" + 10;
			else
				return extended.nan;
		}
		else
			return extended.nan;
		if (++i >= s.length)
			goto done;
	}
	if (s[i] == ".")
	{
		if (++i >= s.length)
			goto done;
		ulong k = 1;
		while (true)
		{
			if (hex)
			{
				if ((s[i] == "p" || s[i] == "P"))
					break;
				result *= 0x10;
			}
			else
			{
				if ((s[i] == "e" || s[i] == "E"))
					break;
				result *= 10;
			}
			k *= (hex ? 0x10 : 10);
			if (s[i] >= "0" && s[i] <= "9")
				result += s[i] - "0";
			else if (hex)
			{
				if (s[i] >= "a" && s[i] <= "f")
					result += s[i] - "a" + 10;
				else if (s[i] >= "A" && s[i] <= "F")
					result += s[i] - "A" + 10;
				else
					return extended.nan;
			}
			else
				return extended.nan;
			if (++i >= s.length)
			{
				result /= k;
				goto done;
			}
		}
		result /= k;
	}
	if (++i >= s.length)
		return extended.nan;
	bit eneg = false;
	if (s[i] == "-")
	{
		eneg = true;
		i++;
	}
	else if (s[i] == "+")
		i++;
	if (i >= s.length)
		return extended.nan;
	int e = 0;
	while (i < s.length)
	{
		e *= 10;
		if (s[i] >= "0" && s[i] <= "9")
			e += s[i] - "0";
		else
			return extended.nan;
		i++;
	}
	if (eneg)
		e = -e;
	result *= pow(hex ? 2 : 10, e);
done:	
	return neg ? -result : result;
}

unittest
{
	assert(feq(atof("123"), 123));
	assert(feq(atof("+123"), +123));
	assert(feq(atof("-123"), -123));
	assert(feq(atof("123e2"), 12300));
	assert(feq(atof("123e+2"), 12300));
	assert(feq(atof("123e-2"), 1.23));
	assert(feq(atof("123."), 123));
	assert(feq(atof("123.E-2"), 1.23));
	assert(feq(atof(".456"), .456));
	assert(feq(atof("123.456"), 123.456));
	assert(feq(atof("1.23456E+2"), 123.456));
	assert(feq(atof("1A2h"), 1A2h));
	assert(feq(atof("1a2h"), 1a2h));
	assert(feq(atof("0x1A2"), 0x1A2));
	assert(feq(atof("0x1a2p2"), 0x1a2p2));
	assert(feq(atof("0x1a2p+2"), 0x1a2p+2));
	assert(feq(atof("0x1a2p-2"), 0x1a2p-2));
	assert(feq(atof("0x1A2.3B4"), 0x1A2.3B4p0));
	assert(feq(atof("0x1a2.3b4P2"), 0x1a2.3b4P2));
}

/*************************************
 * Convert float to string
 */
 
char[] toString(extended x)
{
	char[1024] buffer;
	char* p = buffer;
	uint psize = buffer.length;
	int count;
	while (true)
	{
		version(Win32)
		{
			count = _snprintf(p, psize, "%Lg", x);
			if (count != -1)
				break;
			psize *= 2;
		}
		else version(linux)
		{
			count = snprintf(p, psize, "%Lg", x);
			if (count == -1)
				psize *= 2;
			else if (count >= psize)
				psize = count + 1;
			else
				break;
		}
		p = cast(char*) alloca(psize);
	}
	return p[0 .. count];
}

unittest
{
	assert(!cmp(toString(123.456), "123.456"));
}

/*************************************
 * Static constructor
 */

static this()
{
	tanh_domain = log(extended.max) / 2;
}
