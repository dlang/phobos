// Written in the D programming language.

/**
This package is currently in a nascent state and may be subject to
change. Please do not use it yet, but stick to $(MREF std, math).

Copyright: Copyright The D Language Foundation 2000 - 2011.
           D implementations of exp, expm1, exp2, log, log10, log1p, and log2
           functions are based on the CEPHES math library, which is Copyright
           (C) 2001 Stephen L. Moshier $(LT)steve@moshier.net$(GT) and are
           incorporated herein by permission of the author. The author reserves
           the right to distribute this material elsewhere under different
           copying permissions. These modifications are distributed here under
           the following terms:
License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
           Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
Source: $(PHOBOSSRC std/math/exponential.d)

Macros:
    TABLE_SV = <table border="1" cellpadding="4" cellspacing="0">
               <caption>Special Values</caption>
               $0</table>
    NAN = $(RED NAN)
    PLUSMN = &plusmn;
    INFIN = &infin;
    PLUSMNINF = &plusmn;&infin;
    LT = &lt;
    GT = &gt;
 */

module std.math.exponential;

import std.traits :  isFloatingPoint, isIntegral, Largest, Unqual;

static import core.math;

version (DigitalMars)
{
    version = INLINE_YL2X;        // x87 has opcodes for these
}

/**
 * Compute the value of x $(SUPERSCRIPT n), where n is an integer
 */
Unqual!F pow(F, G)(F x, G n) @nogc @trusted pure nothrow
if (isFloatingPoint!(F) && isIntegral!(G))
{
    import std.math : abs, floor, isNaN, log2;
    import std.traits : Unsigned;

    // NaN ^^ 0 is an exception defined by IEEE (yields 1 instead of NaN)
    if (isNaN(x)) return n ? x : 1.0;

    real p = 1.0, v = void;
    Unsigned!(Unqual!G) m = n;

    if (n < 0)
    {
        if (n == -1) return 1 / x;

        m = cast(typeof(m))(0 - n);
        v = p / x;
    }
    else
    {
        switch (n)
        {
        case 0:
            return 1.0;
        case 1:
            return x;
        default:
        }

        v = x;
    }

    // Bail out early, if we can estimate that the result is infinity or 0.0:
    //
    // We use the following two conclusions:
    //
    //    m * floor(log2(abs(v))) >= F.max_exp
    // =>             abs(v) ^^ m >  F.max == nextDown(F.infinity)
    //
    //    m * (bias - ex - 1) >= bias + F.mant_dig - 1
    // =>         abs(v) ^^ m <  2 ^^ (-bias - F.mant_dig + 2) == nextUp(0.0)
    //
    // floor(log2(abs(v))) == ex - bias can be directly taken from the
    // exponent of the floating point represantation, to avoid long
    // calculations here.

    enum uint bias = F.max_exp - 1;

    static if (is(F == float))
    {
        float f = cast(float) v;
        uint ival = () @trusted { return *cast(uint*) &f; }();
        ulong ex = (ival >> 23) & 255;
    }
    else static if (is(F == double) || (is(T == real) && T.mant_dig == double.mant_dig))
    {
        double d = cast(double) v;
        ulong ival = () @trusted { return *cast(ulong*) &d; }();
        ulong ex = (ival >> 52) & 2047;
    }
    else static if (is (F == real) && real.mant_dig == 64)
    {
        ulong ex = void;
        if (__ctfe)
        {
            // in CTFE we cannot access the bit patterns and have therefore to
            // fall back to the (slower) general case
            // skipping subnormals by setting ex = bias
            ex = abs(v) == F.infinity ? 2 * bias + 1 :
                (abs(v) < F.min_normal ? bias : cast(ulong) (floor(log2(abs(v))) + bias));
        }
        else
        {
            ulong[2] ival = () @trusted { return *cast(ulong[2]*) &v; }();
            ex = ival[1] & 32767;
        }
    }
    else
    {
        // ToDo: Add special treatment for other reals too.

        // In the general case we have to fall back to log2, which is slower, but still
        // a certain speed gain compared to not bailing out early.
            // skipping subnormals by setting ex = bias
        ulong ex = abs(v) == F.infinity ? 2 * bias + 1 :
            (abs(v) < F.min_normal ? bias : cast(ulong) (floor(log2(abs(v))) + bias));
    }

    // m * (...) can exceed ulong.max, we therefore first check m >= (...).
    // This is sufficient to know that the result will be infinity or 0.0
    // and at the same time it guards against an overflow.
    if (ex > bias && (m >= F.max_exp || m * (ex - bias) >= F.max_exp))
        return (m % 2 == 0 || v > 0) ? F.infinity : -F.infinity;
    else if (ex < bias - 1
             && (m >= bias + F.mant_dig - 1 || m * (bias - ex - 1) >= bias + F.mant_dig - 1))
        return 0.0;

    while (1)
    {
        if (m & 1)
            p *= v;
        m >>= 1;
        if (!m)
            break;
        v *= v;
    }
    return p;
}

///
@safe pure nothrow @nogc unittest
{
    import std.math : feqrel;

    assert(pow(2.0, 5) == 32.0);
    assert(pow(1.5, 9).feqrel(38.4433) > 16);
    assert(pow(real.nan, 2) is real.nan);
    assert(pow(real.infinity, 2) == real.infinity);
}

@safe pure nothrow @nogc unittest
{
    import std.math : isClose, feqrel;

    // Make sure it instantiates and works properly on immutable values and
    // with various integer and float types.
    immutable real x = 46;
    immutable float xf = x;
    immutable double xd = x;
    immutable uint one = 1;
    immutable ushort two = 2;
    immutable ubyte three = 3;
    immutable ulong eight = 8;

    immutable int neg1 = -1;
    immutable short neg2 = -2;
    immutable byte neg3 = -3;
    immutable long neg8 = -8;


    assert(pow(x,0) == 1.0);
    assert(pow(xd,one) == x);
    assert(pow(xf,two) == x * x);
    assert(pow(x,three) == x * x * x);
    assert(pow(x,eight) == (x * x) * (x * x) * (x * x) * (x * x));

    assert(pow(x, neg1) == 1 / x);

    assert(isClose(pow(xd, neg2), cast(double) (1 / (x * x)), 1e-25));
    assert(isClose(pow(xf, neg8), cast(float) (1 / ((x * x) * (x * x) * (x * x) * (x * x))), 1e-15));

    assert(feqrel(pow(x, neg3),  1 / (x * x * x)) >= real.mant_dig - 1);
}

@safe @nogc nothrow unittest
{
    import std.math : equalsDigit;

    assert(equalsDigit(pow(2.0L, 10L), 1024, 19));
}

// https://issues.dlang.org/show_bug.cgi?id=21601
@safe @nogc nothrow pure unittest
{
    // When reals are large enough the results of pow(b, e) can be
    // calculated correctly, if b is of type float or double and e is
    // not too large.
    static if (real.mant_dig >= 64)
    {
        // expected result: 3.790e-42
        assert(pow(-513645318757045764096.0f, -2) > 0.0);

        // expected result: 3.763915357831797e-309
        assert(pow(-1.6299717435255677e+154, -2) > 0.0);
    }
}

@safe @nogc nothrow unittest
{
    import std.math : isClose, isInfinity;

    static float f1 = 19100.0f;
    static float f2 = 0.000012f;

    assert(isClose(pow(f1,9), 3.3829868e+38f));
    assert(isInfinity(pow(f1,10)));
    assert(pow(f2,9) > 0.0f);
    assert(isClose(pow(f2,10), 0.0f, 0.0, float.min_normal));

    static double d1 = 21800.0;
    static double d2 = 0.000012;

    assert(isClose(pow(d1,71), 1.0725339442974e+308));
    assert(isInfinity(pow(d1,72)));
    assert(pow(d2,65) > 0.0f);
    assert(isClose(pow(d2,66), 0.0, 0.0, double.min_normal));

    static if (real.mant_dig == 64) // x87
    {
        static real r1 = 21950.0L;
        static real r2 = 0.000011L;

        assert(isClose(pow(r1,1136), 7.4066175654969242752260330529e+4931L));
        assert(isInfinity(pow(r1,1137)));
        assert(pow(r2,998) > 0.0L);
        assert(isClose(pow(r2,999), 0.0L, 0.0, real.min_normal));
    }
}

@safe @nogc nothrow pure unittest
{
    import std.math : isClose;

    enum f1 = 19100.0f;
    enum f2 = 0.000012f;

    static assert(isClose(pow(f1,9), 3.3829868e+38f));
    static assert(pow(f1,10) > float.max);
    static assert(pow(f2,9) > 0.0f);
    static assert(isClose(pow(f2,10), 0.0f, 0.0, float.min_normal));

    enum d1 = 21800.0;
    enum d2 = 0.000012;

    static assert(isClose(pow(d1,71), 1.0725339442974e+308));
    static assert(pow(d1,72) > double.max);
    static assert(pow(d2,65) > 0.0f);
    static assert(isClose(pow(d2,66), 0.0, 0.0, double.min_normal));

    static if (real.mant_dig == 64) // x87
    {
        enum r1 = 21950.0L;
        enum r2 = 0.000011L;

        static assert(isClose(pow(r1,1136), 7.4066175654969242752260330529e+4931L));
        static assert(pow(r1,1137) > real.max);
        static assert(pow(r2,998) > 0.0L);
        static assert(isClose(pow(r2,999), 0.0L, 0.0, real.min_normal));
    }
}

/**
 * Compute the power of two integral numbers.
 *
 * Params:
 *     x = base
 *     n = exponent
 *
 * Returns:
 *     x raised to the power of n. If n is negative the result is 1 / pow(x, -n),
 *     which is calculated as integer division with remainder. This may result in
 *     a division by zero error.
 *
 *     If both x and n are 0, the result is 1.
 *
 * Throws:
 *     If x is 0 and n is negative, the result is the same as the result of a
 *     division by zero.
 */
typeof(Unqual!(F).init * Unqual!(G).init) pow(F, G)(F x, G n) @nogc @trusted pure nothrow
if (isIntegral!(F) && isIntegral!(G))
{
    import std.traits : isSigned;

    typeof(return) p, v = void;
    Unqual!G m = n;

    static if (isSigned!(F))
    {
        if (x == -1) return cast(typeof(return)) (m & 1 ? -1 : 1);
    }
    static if (isSigned!(G))
    {
        if (x == 0 && m <= -1) return x / 0;
    }
    if (x == 1) return 1;
    static if (isSigned!(G))
    {
        if (m < 0) return 0;
    }

    switch (m)
    {
    case 0:
        p = 1;
        break;

    case 1:
        p = x;
        break;

    case 2:
        p = x * x;
        break;

    default:
        v = x;
        p = 1;
        while (1)
        {
            if (m & 1)
                p *= v;
            m >>= 1;
            if (!m)
                break;
            v *= v;
        }
        break;
    }
    return p;
}

///
@safe pure nothrow @nogc unittest
{
    assert(pow(2, 3) == 8);
    assert(pow(3, 2) == 9);

    assert(pow(2, 10) == 1_024);
    assert(pow(2, 20) == 1_048_576);
    assert(pow(2, 30) == 1_073_741_824);

    assert(pow(0, 0) == 1);

    assert(pow(1, -5) == 1);
    assert(pow(1, -6) == 1);
    assert(pow(-1, -5) == -1);
    assert(pow(-1, -6) == 1);

    assert(pow(-2, 5) == -32);
    assert(pow(-2, -5) == 0);
    assert(pow(cast(double) -2, -5) == -0.03125);
}

@safe pure nothrow @nogc unittest
{
    immutable int one = 1;
    immutable byte two = 2;
    immutable ubyte three = 3;
    immutable short four = 4;
    immutable long ten = 10;

    assert(pow(two, three) == 8);
    assert(pow(two, ten) == 1024);
    assert(pow(one, ten) == 1);
    assert(pow(ten, four) == 10_000);
    assert(pow(four, 10) == 1_048_576);
    assert(pow(three, four) == 81);
}

// https://issues.dlang.org/show_bug.cgi?id=7006
@safe pure nothrow @nogc unittest
{
    assert(pow(5, -1) == 0);
    assert(pow(-5, -1) == 0);
    assert(pow(5, -2) == 0);
    assert(pow(-5, -2) == 0);
    assert(pow(-1, int.min) == 1);
    assert(pow(-2, int.min) == 0);

    assert(pow(4294967290UL,2) == 18446744022169944100UL);
    assert(pow(0,uint.max) == 0);
}

/**Computes integer to floating point powers.*/
real pow(I, F)(I x, F y) @nogc @trusted pure nothrow
if (isIntegral!I && isFloatingPoint!F)
{
    return pow(cast(real) x, cast(Unqual!F) y);
}

///
@safe pure nothrow @nogc unittest
{
    assert(pow(2, 5.0) == 32.0);
    assert(pow(7, 3.0) == 343.0);
    assert(pow(2, real.nan) is real.nan);
    assert(pow(2, real.infinity) == real.infinity);
}

/**
 * Calculates x$(SUPERSCRIPT y).
 *
 * $(TABLE_SV
 * $(TR $(TH x) $(TH y) $(TH pow(x, y))
 *      $(TH div 0) $(TH invalid?))
 * $(TR $(TD anything)      $(TD $(PLUSMN)0.0)                $(TD 1.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(GT) 1)    $(TD +$(INFIN))                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(LT) 1)    $(TD +$(INFIN))                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(GT) 1)    $(TD -$(INFIN))                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(LT) 1)    $(TD -$(INFIN))                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD +$(INFIN))      $(TD $(GT) 0.0)                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD +$(INFIN))      $(TD $(LT) 0.0)                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD odd integer $(GT) 0.0)      $(TD -$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD $(GT) 0.0, not odd integer) $(TD +$(INFIN))
 *      $(TD no)        $(TD no))
 * $(TR $(TD -$(INFIN))      $(TD odd integer $(LT) 0.0)      $(TD -0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD $(LT) 0.0, not odd integer) $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD $(PLUSMN)1.0)   $(TD $(PLUSMN)$(INFIN))          $(TD -$(NAN))
 *      $(TD no)        $(TD yes) )
 * $(TR $(TD $(LT) 0.0)      $(TD finite, nonintegral)        $(TD $(NAN))
 *      $(TD no)        $(TD yes))
 * $(TR $(TD $(PLUSMN)0.0)   $(TD odd integer $(LT) 0.0)      $(TD $(PLUSMNINF))
 *      $(TD yes)       $(TD no) )
 * $(TR $(TD $(PLUSMN)0.0)   $(TD $(LT) 0.0, not odd integer) $(TD +$(INFIN))
 *      $(TD yes)       $(TD no))
 * $(TR $(TD $(PLUSMN)0.0)   $(TD odd integer $(GT) 0.0)      $(TD $(PLUSMN)0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD $(PLUSMN)0.0)   $(TD $(GT) 0.0, not odd integer) $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * )
 */
Unqual!(Largest!(F, G)) pow(F, G)(F x, G y) @nogc @trusted pure nothrow
if (isFloatingPoint!(F) && isFloatingPoint!(G))
{
    import std.math : exp2, fabs, isInfinity, isNaN, log2, signbit, sqrt;

    alias Float = typeof(return);

    static real impl(real x, real y) @nogc pure nothrow
    {
        // Special cases.
        if (isNaN(y))
            return y;
        if (isNaN(x) && y != 0.0)
            return x;

        // Even if x is NaN.
        if (y == 0.0)
            return 1.0;
        if (y == 1.0)
            return x;

        if (isInfinity(y))
        {
            if (isInfinity(x))
            {
                if (!signbit(y) && !signbit(x))
                    return F.infinity;
                else
                    return F.nan;
            }
            else if (fabs(x) > 1)
            {
                if (signbit(y))
                    return +0.0;
                else
                    return F.infinity;
            }
            else if (fabs(x) == 1)
            {
                return F.nan;
            }
            else // < 1
            {
                if (signbit(y))
                    return F.infinity;
                else
                    return +0.0;
            }
        }
        if (isInfinity(x))
        {
            if (signbit(x))
            {
                long i = cast(long) y;
                if (y > 0.0)
                {
                    if (i == y && i & 1)
                        return -F.infinity;
                    else if (i == y)
                        return F.infinity;
                    else
                        return -F.nan;
                }
                else if (y < 0.0)
                {
                    if (i == y && i & 1)
                        return -0.0;
                    else if (i == y)
                        return +0.0;
                    else
                        return F.nan;
                }
            }
            else
            {
                if (y > 0.0)
                    return F.infinity;
                else if (y < 0.0)
                    return +0.0;
            }
        }

        if (x == 0.0)
        {
            if (signbit(x))
            {
                long i = cast(long) y;
                if (y > 0.0)
                {
                    if (i == y && i & 1)
                        return -0.0;
                    else
                        return +0.0;
                }
                else if (y < 0.0)
                {
                    if (i == y && i & 1)
                        return -F.infinity;
                    else
                        return F.infinity;
                }
            }
            else
            {
                if (y > 0.0)
                    return +0.0;
                else if (y < 0.0)
                    return F.infinity;
            }
        }
        if (x == 1.0)
            return 1.0;

        if (y >= F.max)
        {
            if ((x > 0.0 && x < 1.0) || (x > -1.0 && x < 0.0))
                return 0.0;
            if (x > 1.0 || x < -1.0)
                return F.infinity;
        }
        if (y <= -F.max)
        {
            if ((x > 0.0 && x < 1.0) || (x > -1.0 && x < 0.0))
                return F.infinity;
            if (x > 1.0 || x < -1.0)
                return 0.0;
        }

        if (x >= F.max)
        {
            if (y > 0.0)
                return F.infinity;
            else
                return 0.0;
        }
        if (x <= -F.max)
        {
            long i = cast(long) y;
            if (y > 0.0)
            {
                if (i == y && i & 1)
                    return -F.infinity;
                else
                    return F.infinity;
            }
            else if (y < 0.0)
            {
                if (i == y && i & 1)
                    return -0.0;
                else
                    return +0.0;
            }
        }

        // Integer power of x.
        long iy = cast(long) y;
        if (iy == y && fabs(y) < 32_768.0)
            return pow(x, iy);

        real sign = 1.0;
        if (x < 0)
        {
            // Result is real only if y is an integer
            // Check for a non-zero fractional part
            enum maxOdd = pow(2.0L, real.mant_dig) - 1.0L;
            static if (maxOdd > ulong.max)
            {
                // Generic method, for any FP type
                if (floor(y) != y)
                    return sqrt(x); // Complex result -- create a NaN

                const hy = 0.5 * y;
                if (floor(hy) != hy)
                    sign = -1.0;
            }
            else
            {
                // Much faster, if ulong has enough precision
                const absY = fabs(y);
                if (absY <= maxOdd)
                {
                    const uy = cast(ulong) absY;
                    if (uy != absY)
                        return sqrt(x); // Complex result -- create a NaN

                    if (uy & 1)
                        sign = -1.0;
                }
            }
            x = -x;
        }
        version (INLINE_YL2X)
        {
            // If x > 0, x ^^ y == 2 ^^ ( y * log2(x) )
            // TODO: This is not accurate in practice. A fast and accurate
            // (though complicated) method is described in:
            // "An efficient rounding boundary test for pow(x, y)
            // in double precision", C.Q. Lauter and V. Lefèvre, INRIA (2007).
            return sign * exp2( core.math.yl2x(x, y) );
        }
        else
        {
            // If x > 0, x ^^ y == 2 ^^ ( y * log2(x) )
            // TODO: This is not accurate in practice. A fast and accurate
            // (though complicated) method is described in:
            // "An efficient rounding boundary test for pow(x, y)
            // in double precision", C.Q. Lauter and V. Lefèvre, INRIA (2007).
            Float w = exp2(y * log2(x));
            return sign * w;
        }
    }
    return impl(x, y);
}

///
@safe pure nothrow @nogc unittest
{
    import std.math : isClose;

    assert(isClose(pow(2.0, 3.0), 8.0));
    assert(isClose(pow(1.5, 10.0), 57.6650390625));

    // square root of 9
    assert(isClose(pow(9.0, 0.5), 3.0));
    // 10th root of 1024
    assert(isClose(pow(1024.0, 0.1), 2.0));

    assert(isClose(pow(-4.0, 3.0), -64.0));

    // reciprocal of 4 ^^ 2
    assert(isClose(pow(4.0, -2.0), 0.0625));
    // reciprocal of (-2) ^^ 3
    assert(isClose(pow(-2.0, -3.0), -0.125));

    assert(isClose(pow(-2.5, 3.0), -15.625));
    // reciprocal of 2.5 ^^ 3
    assert(isClose(pow(2.5, -3.0), 0.064));
    // reciprocal of (-2.5) ^^ 3
    assert(isClose(pow(-2.5, -3.0), -0.064));

    // reciprocal of square root of 4
    assert(isClose(pow(4.0, -0.5), 0.5));

    // per definition
    assert(isClose(pow(0.0, 0.0), 1.0));
}

///
@safe pure nothrow @nogc unittest
{
    import std.math : isClose;

    // the result is a complex number
    // which cannot be represented as floating point number
    import std.math : isNaN;
    assert(isNaN(pow(-2.5, -1.5)));

    // use the ^^-operator of std.complex instead
    import std.complex : complex;
    auto c1 = complex(-2.5, 0.0);
    auto c2 = complex(-1.5, 0.0);
    auto result = c1 ^^ c2;
    // exact result apparently depends on `real` precision => increased tolerance
    assert(isClose(result.re, -4.64705438e-17, 2e-4));
    assert(isClose(result.im, 2.52982e-1, 2e-4));
}

@safe pure nothrow @nogc unittest
{
    import std.math : isNaN;

    assert(pow(1.5, real.infinity) == real.infinity);
    assert(pow(0.5, real.infinity) == 0.0);
    assert(pow(1.5, -real.infinity) == 0.0);
    assert(pow(0.5, -real.infinity) == real.infinity);
    assert(pow(real.infinity, 1.0) == real.infinity);
    assert(pow(real.infinity, -1.0) == 0.0);
    assert(pow(real.infinity, real.infinity) == real.infinity);
    assert(pow(-real.infinity, 1.0) == -real.infinity);
    assert(pow(-real.infinity, 2.0) == real.infinity);
    assert(pow(-real.infinity, -1.0) == -0.0);
    assert(pow(-real.infinity, -2.0) == 0.0);
    assert(isNaN(pow(1.0, real.infinity)));
    assert(pow(0.0, -1.0) == real.infinity);
    assert(pow(real.nan, 0.0) == 1.0);
    assert(isNaN(pow(real.nan, 3.0)));
    assert(isNaN(pow(3.0, real.nan)));
}

@safe @nogc nothrow unittest
{
    import std.math : equalsDigit;

    assert(equalsDigit(pow(2.0L, 10.0L), 1024, 19));
}

@safe pure nothrow @nogc unittest
{
    import std.math : isClose, isIdentical, isNaN, PI;

    // Test all the special values.  These unittests can be run on Windows
    // by temporarily changing the version (linux) to version (all).
    immutable float zero = 0;
    immutable real one = 1;
    immutable double two = 2;
    immutable float three = 3;
    immutable float fnan = float.nan;
    immutable double dnan = double.nan;
    immutable real rnan = real.nan;
    immutable dinf = double.infinity;
    immutable rninf = -real.infinity;

    assert(pow(fnan, zero) == 1);
    assert(pow(dnan, zero) == 1);
    assert(pow(rnan, zero) == 1);

    assert(pow(two, dinf) == double.infinity);
    assert(isIdentical(pow(0.2f, dinf), +0.0));
    assert(pow(0.99999999L, rninf) == real.infinity);
    assert(isIdentical(pow(1.000000001, rninf), +0.0));
    assert(pow(dinf, 0.001) == dinf);
    assert(isIdentical(pow(dinf, -0.001), +0.0));
    assert(pow(rninf, 3.0L) == rninf);
    assert(pow(rninf, 2.0L) == real.infinity);
    assert(isIdentical(pow(rninf, -3.0), -0.0));
    assert(isIdentical(pow(rninf, -2.0), +0.0));

    // @@@BUG@@@ somewhere
    version (OSX) {} else assert(isNaN(pow(one, dinf)));
    version (OSX) {} else assert(isNaN(pow(-one, dinf)));
    assert(isNaN(pow(-0.2, PI)));
    // boundary cases. Note that epsilon == 2^^-n for some n,
    // so 1/epsilon == 2^^n is always even.
    assert(pow(-1.0L, 1/real.epsilon - 1.0L) == -1.0L);
    assert(pow(-1.0L, 1/real.epsilon) == 1.0L);
    assert(isNaN(pow(-1.0L, 1/real.epsilon-0.5L)));
    assert(isNaN(pow(-1.0L, -1/real.epsilon+0.5L)));

    assert(pow(0.0, -3.0) == double.infinity);
    assert(pow(-0.0, -3.0) == -double.infinity);
    assert(pow(0.0, -PI) == double.infinity);
    assert(pow(-0.0, -PI) == double.infinity);
    assert(isIdentical(pow(0.0, 5.0), 0.0));
    assert(isIdentical(pow(-0.0, 5.0), -0.0));
    assert(isIdentical(pow(0.0, 6.0), 0.0));
    assert(isIdentical(pow(-0.0, 6.0), 0.0));

    // https://issues.dlang.org/show_bug.cgi?id=14786 fixed
    immutable real maxOdd = pow(2.0L, real.mant_dig) - 1.0L;
    assert(pow(-1.0L,  maxOdd) == -1.0L);
    assert(pow(-1.0L, -maxOdd) == -1.0L);
    assert(pow(-1.0L, maxOdd + 1.0L) == 1.0L);
    assert(pow(-1.0L, -maxOdd + 1.0L) == 1.0L);
    assert(pow(-1.0L, maxOdd - 1.0L) == 1.0L);
    assert(pow(-1.0L, -maxOdd - 1.0L) == 1.0L);

    // Now, actual numbers.
    assert(isClose(pow(two, three), 8.0));
    assert(isClose(pow(two, -2.5), 0.1767766953));

    // Test integer to float power.
    immutable uint twoI = 2;
    assert(isClose(pow(twoI, three), 8.0));
}

// https://issues.dlang.org/show_bug.cgi?id=20508
@safe pure nothrow @nogc unittest
{
    import std.math : isNaN;

    assert(isNaN(pow(-double.infinity, 0.5)));

    assert(isNaN(pow(-real.infinity, real.infinity)));
    assert(isNaN(pow(-real.infinity, -real.infinity)));
    assert(isNaN(pow(-real.infinity, 1.234)));
    assert(isNaN(pow(-real.infinity, -0.751)));
    assert(pow(-real.infinity, 0.0) == 1.0);
}
