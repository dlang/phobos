// Written in the D programming language.

/*
   Helper functions for formatting floating point numbers.

   Copyright: Copyright The D Language Foundation 2019 -

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: Bernhard Seckinger

   Source: $(PHOBOSSRC std/format/internal/floats.d)
 */

module std.format.internal.floats;

import std.format.spec : FormatSpec;

package(std.format) enum ctfpMessage = "Cannot format reals at compile-time.";

package(std.format) enum RoundingMode { up, down, toZero, toNearestTiesToEven, toNearestTiesAwayFromZero }

package(std.format) auto printFloat(T, Char)(return char[] buf, T val, FormatSpec!Char f,
                                             RoundingMode rm = RoundingMode.toNearestTiesToEven)
if (is(T == float) || is(T == double)
    || (is(T == real) && (T.mant_dig == double.mant_dig || T.mant_dig == 64)))
{
    static if (is(T == real) && T.mant_dig == 64)
    {
        ulong mnt = void;
        int exp = void;
        string sgn = "";

        if (__ctfe)
        {
            import std.math : abs, floor, isInfinity, isNaN, log2;

            if (isNaN(val) || isInfinity(val))
                exp = 32767;
            else if (abs(val) < real.min_normal)
                exp = 0;
            else
                exp = cast(int) (val.abs.log2.floor() + 16383);

            if (exp == 32767)
            {
                // NaN or infinity
                mnt = isNaN(val) ? ((1L << 63) - 1) : 0;
            }
            else if (exp > 16382 + 64) // bias + bits of ulong
            {
                val /= 2.0L ^^ (exp - (16382 + 64));
                mnt = (cast(ulong) abs(val)) & ((1L << 63) - 1);
            }
            else
            {
                auto delta = 16382 + 64 - (exp == 0 ? 1 : exp); // -1 in case of subnormals
                if (delta > 16383)
                {
                    // need two steps to avoid overflow
                    val *= 2.0L ^^ 16383;
                    delta -= 16383;
                }
                val *= 2.0L ^^ delta;
                mnt = (cast(ulong) abs(val)) & ((1L << 63) - 1);
            }

            double d = cast(double) val;
            ulong ival = () @trusted { return *cast(ulong*) &d; }();
            if ((ival >> 63) & 1) sgn = "-";
        }
        else
        {
            ulong[2] ival = () @trusted { return *cast(ulong[2]*) &val; }();
            mnt = ival[0] & ((1L << 63) - 1);
            exp = ival[1] & 32767;
            if ((ival[1] >> 15) & 1) sgn = "-";
        }
    }
    else
    {
        static if (is(T == float))
        {
            ulong ival = () @trusted { return *cast(uint*) &val; }();
        }
        else
        {
            ulong ival = () @trusted { return *cast(ulong*) &val; }();
        }

        import std.math : log2;
        enum log2_max_exp = cast(int) log2(T.max_exp);

        ulong mnt = ival & ((1L << (T.mant_dig - 1)) - 1);
        int exp = (ival >> (T.mant_dig - 1)) & ((1L << (log2_max_exp + 1)) - 1);
        string sgn = (ival >> (T.mant_dig + log2_max_exp)) & 1 ? "-" : "";
    }

    enum maxexp = 2 * T.max_exp - 1;

    if (sgn == "" && f.flPlus) sgn = "+";
    if (sgn == "" && f.flSpace) sgn = " ";

    assert(f.spec == 'a' || f.spec == 'A'
           || f.spec == 'e' || f.spec == 'E'
           || f.spec == 'f' || f.spec == 'F'
           || f.spec == 'g' || f.spec == 'G', "unsupported format specifier");
    bool is_upper = f.spec == 'A' || f.spec == 'E' || f.spec=='F' || f.spec=='G';

    // special treatment for nan and inf
    if (exp == maxexp)
    {
        import std.algorithm.comparison : max;

        size_t length = max(f.width, sgn.length + 3);
        char[] result = length <= buf.length ? buf[0 .. length] : new char[length];
        result[] = ' ';

        auto offset = f.flDash ? 0 : (result.length - 3);

        if (sgn != "")
        {
            if (f.flDash) ++offset;
            result[offset-1] = sgn[0];
        }

        result[offset .. offset + 3] = (mnt == 0) ? ( is_upper ? "INF" : "inf" ) : ( is_upper ? "NAN" : "nan" );

        return result;
    }

    if (T.mant_dig == 64)
        assert(false); // not yet implemented

    final switch (f.spec)
    {
        case 'a': case 'A':
            return printFloatA(buf, val, f, rm, sgn, exp, mnt, is_upper);
        case 'e': case 'E':
            return printFloatE!false(buf, val, f, rm, sgn, exp, mnt, is_upper);
        case 'f': case 'F':
            return printFloatF!false(buf, val, f, rm, sgn, exp, mnt, is_upper);
        case 'g': case 'G':
            return printFloatG(buf, val, f, rm, sgn, exp, mnt, is_upper);
    }
}

private auto printFloatA(T, Char)(return char[] buf, T val, FormatSpec!Char f, RoundingMode rm,
                                  string sgn, int exp, ulong mnt, bool is_upper)
if (is(T == float) || is(T == double)
    || (is(T == real) && (T.mant_dig == double.mant_dig || T.mant_dig == 64)))
{
    import std.algorithm.comparison : max;

    enum int bias = T.max_exp - 1;

    static if (is(T == float) || (is(T == real) && T.mant_dig == 64))
    {
        mnt <<= 1; // make mnt dividable by 4
        enum mant_len = T.mant_dig;
    }
    else
        enum mant_len = T.mant_dig - 1;
    static assert(mant_len % 4 == 0, "mantissa with wrong length");

    // print full mantissa
    char[(mant_len - 1) / 4 + 1] hex_mant;
    size_t hex_mant_pos = 0;
    size_t pos = mant_len;

    auto gap = 39 - 32 * is_upper;
    while (pos >= 4 && (mnt & ((1L << pos) - 1)) != 0)
    {
        pos -= 4;
        size_t tmp = (mnt >> pos) & 15;
        // For speed reasons the better readable
        // ... = tmp < 10 ? ('0' + tmp) : ((is_upper ? 'A' : 'a') + tmp - 10))
        // has been replaced with an expression without branches, doing the same
        hex_mant[hex_mant_pos++] = cast(char) (tmp + gap * ((tmp + 6) >> 4) + '0');
    }

    // save integer part
    auto first = exp == 0 ? '0' : '1';

    // print exponent
    if (exp == 0 && mnt == 0)
        exp = 0; // special treatment for 0.0
    else if (exp == 0)
        exp = 1 - bias; // denormalized number
    else
        exp -= bias;

    auto exp_sgn = exp >= 0 ? '+' : '-';
    if (exp < 0) exp = -exp;

    static if (is(T == float))
        enum max_exp_digits = 4;
    else
        enum max_exp_digits = 5;

    char[max_exp_digits] exp_str;
    size_t exp_pos = max_exp_digits;

    do
    {
        exp_str[--exp_pos] = '0' + exp % 10;
        exp /= 10;
    } while (exp > 0);

    exp_str[--exp_pos] = exp_sgn;

    // calculate needed buffer width
    auto precision = f.precision == f.UNSPECIFIED ? hex_mant_pos : f.precision;
    bool dot = precision > 0 || f.flHash;

    size_t width = sgn.length + 3 + (dot ? 1 : 0) + precision + 1 + (max_exp_digits - exp_pos);

    size_t length = max(width,f.width);
    char[] buffer = length <= buf.length ? buf[0 .. length] : new char[length];
    size_t b_pos = 0;

    size_t delta = f.width - width; // only used, when f.width > width

    // fill buffer
    if (!f.flDash && !f.flZero && f.width > width)
    {
        buffer[b_pos .. b_pos + delta] = ' ';
        b_pos += delta;
    }

    if (sgn != "") buffer[b_pos++] = sgn[0];
    buffer[b_pos++] = '0';
    buffer[b_pos++] = is_upper ? 'X' : 'x';

    if (!f.flDash && f.flZero && f.width > width)
    {
        buffer[b_pos .. b_pos + delta] = '0';
        b_pos += delta;
    }

    buffer[b_pos++] = first;
    if (dot) buffer[b_pos++] = '.';
    if (precision < hex_mant_pos)
    {
        buffer[b_pos .. b_pos + precision] = hex_mant[0 .. precision];
        b_pos += precision;

        enum roundType { ZERO, LOWER, FIVE, UPPER }
        roundType next;

        if (hex_mant[precision] == '0')
            next = roundType.ZERO;
        else if (hex_mant[precision] < '8')
            next = roundType.LOWER;
        else if (hex_mant[precision] > '8')
            next = roundType.UPPER;
        else
            next = roundType.FIVE;

        if (next == roundType.ZERO || next == roundType.FIVE)
        {
            foreach (i;precision + 1 .. hex_mant_pos)
            {
                if (hex_mant[i] > '0')
                {
                    next = next == roundType.ZERO ? roundType.LOWER : roundType.UPPER;
                    break;
                }
            }
        }

        bool roundUp = false;

        if (rm == RoundingMode.up)
            roundUp = next != roundType.ZERO && sgn != "-";
        else if (rm == RoundingMode.down)
            roundUp = next != roundType.ZERO && sgn == "-";
        else if (rm == RoundingMode.toZero)
            roundUp = false;
        else
        {
            assert(rm == RoundingMode.toNearestTiesToEven || rm == RoundingMode.toNearestTiesAwayFromZero,
                   "RoundingMode is not toNearest");
            roundUp = next == roundType.UPPER;

            if (next == roundType.FIVE)
            {
                // IEEE754 allows for two different ways of implementing roundToNearest:

                // Round to nearest, ties away from zero
                if (rm == RoundingMode.toNearestTiesAwayFromZero)
                    roundUp = true;
                else
                {
                    // Round to nearest, ties to even
                    auto last = buffer[b_pos-1];
                    if (last == '.') last = buffer[b_pos-2];
                    roundUp = (last <= '9' && last % 2 != 0) || (last >= '9' && last % 2 == 0);
                }
            }
        }

        if (roundUp)
        {
            foreach_reverse (i;b_pos - precision - 2 .. b_pos)
            {
                if (buffer[i] == '.') continue;
                if (buffer[i] == 'f' || buffer[i] == 'F')
                    buffer[i] = '0';
                else
                {
                    if (buffer[i] == '9')
                        buffer[i] = is_upper ? 'A' : 'a';
                    else
                        buffer[i]++;
                    break;
                }
            }
        }
    }
    else
    {
        buffer[b_pos .. b_pos + hex_mant_pos] = hex_mant[0 .. hex_mant_pos];
        buffer[b_pos + hex_mant_pos .. b_pos + precision] = '0';
        b_pos += precision;
    }

    buffer[b_pos++] = is_upper ? 'P' : 'p';
    buffer[b_pos .. b_pos + (max_exp_digits - exp_pos)] = exp_str[exp_pos .. $];
    b_pos += max_exp_digits - exp_pos;

    if (f.flDash && f.width > width)
    {
        buffer[b_pos .. b_pos + delta] = ' ';
        b_pos += delta;
    }

    return buffer[0 .. b_pos];
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    char[256] buf;
    assert(printFloat(buf[], float.nan, f) == "nan");
    assert(printFloat(buf[], -float.nan, f) == "-nan");
    assert(printFloat(buf[], float.infinity, f) == "inf");
    assert(printFloat(buf[], -float.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0f, f) == "0x0p+0");
    assert(printFloat(buf[], -0.0f, f) == "-0x0p+0");

    assert(printFloat(buf[], double.nan, f) == "nan");
    assert(printFloat(buf[], -double.nan, f) == "-nan");
    assert(printFloat(buf[], double.infinity, f) == "inf");
    assert(printFloat(buf[], -double.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0, f) == "0x0p+0");
    assert(printFloat(buf[], -0.0, f) == "-0x0p+0");

    assert(printFloat(buf[], real.nan, f) == "nan");
    assert(printFloat(buf[], -real.nan, f) == "-nan");
    assert(printFloat(buf[], real.infinity, f) == "inf");
    assert(printFloat(buf[], -real.infinity, f) == "-inf");

    import std.math : nextUp;

    assert(printFloat(buf[], nextUp(0.0f), f) == "0x0.000002p-126");
    assert(printFloat(buf[], float.epsilon, f) == "0x1p-23");
    assert(printFloat(buf[], float.min_normal, f) == "0x1p-126");
    assert(printFloat(buf[], float.max, f) == "0x1.fffffep+127");

    assert(printFloat(buf[], nextUp(0.0), f) == "0x0.0000000000001p-1022");
    assert(printFloat(buf[], double.epsilon, f) == "0x1p-52");
    assert(printFloat(buf[], double.min_normal, f) == "0x1p-1022");
    assert(printFloat(buf[], double.max, f) == "0x1.fffffffffffffp+1023");

    import std.math : E, PI, PI_2, PI_4, M_1_PI, M_2_PI, M_2_SQRTPI,
                      LN10, LN2, LOG2, LOG2E, LOG2T, LOG10E, SQRT2, SQRT1_2;

    assert(printFloat(buf[], cast(float) E, f) == "0x1.5bf0a8p+1");
    assert(printFloat(buf[], cast(float) PI, f) == "0x1.921fb6p+1");
    assert(printFloat(buf[], cast(float) PI_2, f) == "0x1.921fb6p+0");
    assert(printFloat(buf[], cast(float) PI_4, f) == "0x1.921fb6p-1");
    assert(printFloat(buf[], cast(float) M_1_PI, f) == "0x1.45f306p-2");
    assert(printFloat(buf[], cast(float) M_2_PI, f) == "0x1.45f306p-1");
    assert(printFloat(buf[], cast(float) M_2_SQRTPI, f) == "0x1.20dd76p+0");
    assert(printFloat(buf[], cast(float) LN10, f) == "0x1.26bb1cp+1");
    assert(printFloat(buf[], cast(float) LN2, f) == "0x1.62e43p-1");
    assert(printFloat(buf[], cast(float) LOG2, f) == "0x1.344136p-2");
    assert(printFloat(buf[], cast(float) LOG2E, f) == "0x1.715476p+0");
    assert(printFloat(buf[], cast(float) LOG2T, f) == "0x1.a934fp+1");
    assert(printFloat(buf[], cast(float) LOG10E, f) == "0x1.bcb7b2p-2");
    assert(printFloat(buf[], cast(float) SQRT2, f) == "0x1.6a09e6p+0");
    assert(printFloat(buf[], cast(float) SQRT1_2, f) == "0x1.6a09e6p-1");

    assert(printFloat(buf[], cast(double) E, f) == "0x1.5bf0a8b145769p+1");
    assert(printFloat(buf[], cast(double) PI, f) == "0x1.921fb54442d18p+1");
    assert(printFloat(buf[], cast(double) PI_2, f) == "0x1.921fb54442d18p+0");
    assert(printFloat(buf[], cast(double) PI_4, f) == "0x1.921fb54442d18p-1");
    assert(printFloat(buf[], cast(double) M_1_PI, f) == "0x1.45f306dc9c883p-2");
    assert(printFloat(buf[], cast(double) M_2_PI, f) == "0x1.45f306dc9c883p-1");
    assert(printFloat(buf[], cast(double) M_2_SQRTPI, f) == "0x1.20dd750429b6dp+0");
    assert(printFloat(buf[], cast(double) LN10, f) == "0x1.26bb1bbb55516p+1");
    assert(printFloat(buf[], cast(double) LN2, f) == "0x1.62e42fefa39efp-1");
    assert(printFloat(buf[], cast(double) LOG2, f) == "0x1.34413509f79ffp-2");
    assert(printFloat(buf[], cast(double) LOG2E, f) == "0x1.71547652b82fep+0");
    assert(printFloat(buf[], cast(double) LOG2T, f) == "0x1.a934f0979a371p+1");
    assert(printFloat(buf[], cast(double) LOG10E, f) == "0x1.bcb7b1526e50ep-2");
    assert(printFloat(buf[], cast(double) SQRT2, f) == "0x1.6a09e667f3bcdp+0");
    assert(printFloat(buf[], cast(double) SQRT1_2, f) == "0x1.6a09e667f3bcdp-1");

}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.precision = 3;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "0x1.000p+0");
    assert(printFloat(buf[], 3.3f, f) == "0x1.a66p+1");
    assert(printFloat(buf[], 2.9f, f) == "0x1.733p+1");

    assert(printFloat(buf[], 1.0, f) == "0x1.000p+0");
    assert(printFloat(buf[], 3.3, f) == "0x1.a66p+1");
    assert(printFloat(buf[], 2.9, f) == "0x1.733p+1");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.precision = 0;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "0x1p+0");
    assert(printFloat(buf[], 3.3f, f) == "0x2p+1");
    assert(printFloat(buf[], 2.9f, f) == "0x1p+1");

    assert(printFloat(buf[], 1.0, f) == "0x1p+0");
    assert(printFloat(buf[], 3.3, f) == "0x2p+1");
    assert(printFloat(buf[], 2.9, f) == "0x1p+1");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.precision = 0;
    f.flHash = true;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "0x1.p+0");
    assert(printFloat(buf[], 3.3f, f) == "0x2.p+1");
    assert(printFloat(buf[], 2.9f, f) == "0x1.p+1");

    assert(printFloat(buf[], 1.0, f) == "0x1.p+0");
    assert(printFloat(buf[], 3.3, f) == "0x2.p+1");
    assert(printFloat(buf[], 2.9, f) == "0x1.p+1");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.width = 22;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "                0x1p+0");
    assert(printFloat(buf[], 3.3f, f) == "         0x1.a66666p+1");
    assert(printFloat(buf[], 2.9f, f) == "         0x1.733334p+1");

    assert(printFloat(buf[], 1.0, f) == "                0x1p+0");
    assert(printFloat(buf[], 3.3, f) == "  0x1.a666666666666p+1");
    assert(printFloat(buf[], 2.9, f) == "  0x1.7333333333333p+1");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.width = 22;
    f.flDash = true;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "0x1p+0                ");
    assert(printFloat(buf[], 3.3f, f) == "0x1.a66666p+1         ");
    assert(printFloat(buf[], 2.9f, f) == "0x1.733334p+1         ");

    assert(printFloat(buf[], 1.0, f) == "0x1p+0                ");
    assert(printFloat(buf[], 3.3, f) == "0x1.a666666666666p+1  ");
    assert(printFloat(buf[], 2.9, f) == "0x1.7333333333333p+1  ");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.width = 22;
    f.flZero = true;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "0x00000000000000001p+0");
    assert(printFloat(buf[], 3.3f, f) == "0x0000000001.a66666p+1");
    assert(printFloat(buf[], 2.9f, f) == "0x0000000001.733334p+1");

    assert(printFloat(buf[], 1.0, f) == "0x00000000000000001p+0");
    assert(printFloat(buf[], 3.3, f) == "0x001.a666666666666p+1");
    assert(printFloat(buf[], 2.9, f) == "0x001.7333333333333p+1");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.width = 22;
    f.flPlus = true;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == "               +0x1p+0");
    assert(printFloat(buf[], 3.3f, f) == "        +0x1.a66666p+1");
    assert(printFloat(buf[], 2.9f, f) == "        +0x1.733334p+1");

    assert(printFloat(buf[], 1.0, f) == "               +0x1p+0");
    assert(printFloat(buf[], 3.3, f) == " +0x1.a666666666666p+1");
    assert(printFloat(buf[], 2.9, f) == " +0x1.7333333333333p+1");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.width = 22;
    f.flDash = true;
    f.flSpace = true;
    char[32] buf;

    assert(printFloat(buf[], 1.0f, f) == " 0x1p+0               ");
    assert(printFloat(buf[], 3.3f, f) == " 0x1.a66666p+1        ");
    assert(printFloat(buf[], 2.9f, f) == " 0x1.733334p+1        ");

    assert(printFloat(buf[], 1.0, f) == " 0x1p+0               ");
    assert(printFloat(buf[], 3.3, f) == " 0x1.a666666666666p+1 ");
    assert(printFloat(buf[], 2.9, f) == " 0x1.7333333333333p+1 ");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.precision = 1;
    char[32] buf;

    assert(printFloat(buf[], 0x1.18p0,  f, RoundingMode.toNearestTiesAwayFromZero) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.28p0,  f, RoundingMode.toNearestTiesAwayFromZero) == "0x1.3p+0");
    assert(printFloat(buf[], 0x1.1ap0,  f, RoundingMode.toNearestTiesAwayFromZero) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.16p0,  f, RoundingMode.toNearestTiesAwayFromZero) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.10p0,  f, RoundingMode.toNearestTiesAwayFromZero) == "0x1.1p+0");
    assert(printFloat(buf[], -0x1.18p0, f, RoundingMode.toNearestTiesAwayFromZero) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.28p0, f, RoundingMode.toNearestTiesAwayFromZero) == "-0x1.3p+0");
    assert(printFloat(buf[], -0x1.1ap0, f, RoundingMode.toNearestTiesAwayFromZero) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.16p0, f, RoundingMode.toNearestTiesAwayFromZero) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.10p0, f, RoundingMode.toNearestTiesAwayFromZero) == "-0x1.1p+0");

    assert(printFloat(buf[], 0x1.18p0,  f) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.28p0,  f) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.1ap0,  f) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.16p0,  f) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.10p0,  f) == "0x1.1p+0");
    assert(printFloat(buf[], -0x1.18p0, f) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.28p0, f) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.1ap0, f) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.16p0, f) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.10p0, f) == "-0x1.1p+0");

    assert(printFloat(buf[], 0x1.18p0,  f, RoundingMode.toZero) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.28p0,  f, RoundingMode.toZero) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.1ap0,  f, RoundingMode.toZero) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.16p0,  f, RoundingMode.toZero) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.10p0,  f, RoundingMode.toZero) == "0x1.1p+0");
    assert(printFloat(buf[], -0x1.18p0, f, RoundingMode.toZero) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.28p0, f, RoundingMode.toZero) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.1ap0, f, RoundingMode.toZero) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.16p0, f, RoundingMode.toZero) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.10p0, f, RoundingMode.toZero) == "-0x1.1p+0");

    assert(printFloat(buf[], 0x1.18p0,  f, RoundingMode.up) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.28p0,  f, RoundingMode.up) == "0x1.3p+0");
    assert(printFloat(buf[], 0x1.1ap0,  f, RoundingMode.up) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.16p0,  f, RoundingMode.up) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.10p0,  f, RoundingMode.up) == "0x1.1p+0");
    assert(printFloat(buf[], -0x1.18p0, f, RoundingMode.up) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.28p0, f, RoundingMode.up) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.1ap0, f, RoundingMode.up) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.16p0, f, RoundingMode.up) == "-0x1.1p+0");
    assert(printFloat(buf[], -0x1.10p0, f, RoundingMode.up) == "-0x1.1p+0");

    assert(printFloat(buf[], 0x1.18p0,  f, RoundingMode.down) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.28p0,  f, RoundingMode.down) == "0x1.2p+0");
    assert(printFloat(buf[], 0x1.1ap0,  f, RoundingMode.down) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.16p0,  f, RoundingMode.down) == "0x1.1p+0");
    assert(printFloat(buf[], 0x1.10p0,  f, RoundingMode.down) == "0x1.1p+0");
    assert(printFloat(buf[], -0x1.18p0, f, RoundingMode.down) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.28p0, f, RoundingMode.down) == "-0x1.3p+0");
    assert(printFloat(buf[], -0x1.1ap0, f, RoundingMode.down) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.16p0, f, RoundingMode.down) == "-0x1.2p+0");
    assert(printFloat(buf[], -0x1.10p0, f, RoundingMode.down) == "-0x1.1p+0");
}

// for 100% coverage
@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    f.precision = 3;
    char[32] buf;

    assert(printFloat(buf[], 0x1.19f81p0, f) == "0x1.1a0p+0");
    assert(printFloat(buf[], 0x1.19f01p0, f) == "0x1.19fp+0");
}

@safe unittest
{
    auto f = FormatSpec!dchar("");
    f.spec = 'A';
    f.precision = 3;
    char[32] buf;

    assert(printFloat(buf[], 0x1.19f81p0, f) == "0X1.1A0P+0");
    assert(printFloat(buf[], 0x1.19f01p0, f) == "0X1.19FP+0");
}

private auto printFloatE(bool g, T, Char)(return char[] buf, T val, FormatSpec!Char f, RoundingMode rm,
                                          string sgn, int exp, ulong mnt, bool is_upper)
if (is(T == float) || is(T == double)
    || (is(T == real) && (T.mant_dig == double.mant_dig || T.mant_dig == 64)))
{
    import std.conv : to;
    import std.algorithm.comparison : max;

    enum int bias = T.max_exp - 1;

    static if (!g)
    {
        if (f.precision == f.UNSPECIFIED)
            f.precision = 6;
    }

    // special treatment for 0.0
    if (exp == 0 && mnt == 0)
        return printFloat0!g(buf, f, sgn, is_upper);

    // add leading 1 for normalized values or correct exponent for denormalied values
    if (exp != 0)
        mnt |= 1L << (T.mant_dig - 1);
    else
        exp = 1;
    exp -= bias;

    // estimate the number of bytes needed left and right of the decimal point
    // the speed of the algorithm depends on being as accurate as possible with
    // this estimate

    // Default for the right side is the number of digits given by f.precision plus one for the dot
    // plus 6 more for e+...
    auto max_right = f.precision + 7;

    // If the exponent is <= 0 there is only the sign and one digit left of the dot else
    // we have to estimate the number of digits. The factor between exp, which is the number of
    // digits in binary system and the searched number is log_2(10). We round this down to 3.32 to
    // get a conservative estimate. We need to add 3, because of the sign, the fact, that the
    // logarithm is one to small and because we need to round up instead of down, which to!int does.
    // And then we might need one more digit in case of a rounding overflow.
    auto max_left = exp > 0 ? to!int(exp / 3.32) + 4 : 3;

    // If the result is not left justified, we may need to add more digits here for getting the
    // correct width.
    if (!f.flDash)
    {
        static if (g)
            // %g cannot reduce the value by max_right due to trailing zeros, which are removed later
            max_left = max(max_left, f.width + max_left);
        else
            max_left = max(max_left, f.width - max_right + max_left + 1);
    }

    // If the result is left justified, we may need to add more digits to the right. This strongly
    // depends, on the exponent, see above. This time, we need to be conservative in the other direction
    // for not missing a digit; therefore we round log_2(10) up to 3.33.
    if (exp > 0 && f.flDash)
        max_right = max(max_right, f.width - to!int(exp / 3.33) - 2);
    else if (f.flDash)
        max_right = max(max_right, f.width);

    size_t length = max_left + max_right;
    char[] buffer = length <= buf.length ? buf[0 .. length] : new char[length];
    size_t start = max_left;
    size_t left = max_left;
    size_t right = max_left;

    int final_exp = 0;

    enum roundType { ZERO, LOWER, FIVE, UPPER }
    roundType next;

    // Depending on exp, we will use one of three algorithms:
    //
    // Algorithm A: For large exponents (exp >= T.mant_dig)
    // Algorithm B: For small exponents (exp < T.mant_dig - 61)
    // Algorithm C: For exponents close to 0.
    //
    // Algorithm A:
    //   The number to print looks like this: mantissa followed by several zeros.
    //
    //   We know, that there is no fractional part, so we can just use integer division,
    //   consecutivly dividing by 10 and writing down the remainder from right to left.
    //   Unfortunately the integer is too large to fit in an ulong, so we use something
    //   like BigInt: An array of ulongs. We only use 60 bits of that ulongs, because
    //   this simplifies (and speeds up) the division to come.
    //
    //   For the division we use integer division with reminder for each ulong and put
    //   the reminder of each step in the first 4 bits of ulong of the next step (think of
    //   long division for the rationale behind this). The final reminder is the next
    //   digit (from right to left).
    //
    //   This results in the output we would have for the %f specifier. We now adjust this
    //   for %e: First we calculate the place, where the exponent should be printed, filling
    //   up with zeros if needed and second we move the leftmost digit one to the left
    //   and inserting a dot.
    //
    //   After that we decide on the rounding type, using the digits right of the position,
    //   where the exponent will be printed (currently they are still there, but will be
    //   overwritten later).
    //
    // Algorithm B:
    //   The number to print looks like this: zero dot several zeros followed by the mantissa
    //
    //   We know, that the number has no integer part. The algorithm consecutivly multiplies
    //   by 10. The integer part (rounded down) after the multiplication is the next digit
    //   (from left to right). This integer part is removed after each step.
    //   Again, the number is represented as an array of ulongs, with only 60 bits used of
    //   every ulong.
    //
    //   For the multiplication we use normal integer multiplication, which can result in digits
    //   in the uppermost 4 bits. These 4 digits are the carry which is added to the result
    //   of the next multiplication and finally the last carry is the next digit.
    //
    //   Other than for the %f specifier, this multiplication is splitted into two almost
    //   identical parts. The first part lasts as long as we find zeros. We need to do this
    //   to calculate the correct exponent.
    //
    //   The second part will stop, when only zeros remain or when we've got enough digits
    //   for the requested precision. In the second case, we have to find out, which rounding
    //   we have. Aside from special cases we do this by calculating one more digit.
    //
    // Algorithm C:
    //   This time, we know, that the integral part and the fractional part each fit into a
    //   ulong. The mantissa might be partially in both parts or completely in the fractional
    //   part.
    //
    //   We first calculate the integral part by consecutive division by 10. Depending on the
    //   precision this might result in more digits, than we need. In that case we calculate
    //   the position of the exponent and the rounding type.
    //
    //   If there is no integral part, we need to find the first non zero digit. We do this by
    //   consecutive multiplication by 10, saving the first non zero digit followed by a dot.
    //
    //   In either case, we continue filling up with the fractional part until we have enough
    //   digits. If still necessary, we decide the rounding type, mainly by looking at the
    //   next digit.

    ulong[18] bigbuf;
    if (exp >= T.mant_dig)
    {
        // large number without fractional digits
        //
        // As this number does not fit in a ulong, we use an array of ulongs. We only use 60 of the 64 bits,
        // because this makes it much more easy to implement the division by 10.
        int count = exp / 60 + 1;

        // saved in big endian format
        ulong[] mybig = bigbuf[0 .. count];

        // only the first or the first two ulongs contain the mantiassa. The rest are zeros.
        int lower = 60 - (exp - T.mant_dig + 1) % 60;
        if (lower < T.mant_dig)
        {
            mybig[0] = mnt >> lower;
            mybig[1] = (mnt & ((1L << lower) - 1)) << 60 - lower;
        }
        else
            mybig[0] = (mnt & ((1L << lower) - 1)) << 60 - lower;

        // Generation of digits by consecutive division with reminder by 10.
        int msu = 0; // Most significant ulong; when it get's zero, we can ignore it further on
        while (msu < count - 1 || mybig[$ - 1] != 0)
        {
            ulong mod = 0;
            foreach (i;msu .. count)
            {
                mybig[i] |= mod << 60;
                mod = mybig[i] % 10;
                mybig[i] /= 10;
            }
            if (mybig[msu] == 0)
                ++msu;

            buffer[--left] = cast(byte) ('0' + mod);
            ++final_exp;
        }
        --final_exp;

        static if (g)
            start = left + f.precision;
        else
            start = left + f.precision + 1;

        // we need more zeros for precision
        if (right < start)
            buffer[right .. start] = '0';

        // move leftmost digit one more left and add dot between
        buffer[left - 1] = buffer[left];
        buffer[left] = '.';
        --left;

        // rounding type
        if (start >= right)
            next = roundType.ZERO;
        else if (buffer[start] != '0' && buffer[start] != '5')
            next = buffer[start] > '5' ? roundType.UPPER : roundType.LOWER;
        else
        {
            next = buffer[start] == '5' ? roundType.FIVE : roundType.ZERO;
            foreach (i; start + 1 .. right)
                if (buffer[i] > '0')
                {
                    next = next == roundType.FIVE ? roundType.UPPER : roundType.LOWER;
                    break;
                }
        }

        right = start;
        if (f.precision == 0 && !f.flHash) --right;
    }
    else if (exp + 61 < T.mant_dig)
    {
        // small number without integer digits
        //
        // Again this number does not fit in a ulong and we use an array of ulongs. And again we
        // only use 60 bits, because this simplifies the multiplication by 10.
        int count = (T.mant_dig - exp - 2) / 60 + 1;

        // saved in little endian format
        ulong[] mybig = bigbuf[0 .. count];

        // only the last or the last two ulongs contain the mantiassa. Because of little endian
        // format these are the ulongs at index 0 and 1. The rest are zeros.
        int upper = 60 - (-exp - 1) % 60;
        if (upper < T.mant_dig)
        {
            mybig[0] = (mnt & ((1L << (T.mant_dig - upper)) - 1)) << 60 - (T.mant_dig - upper);
            mybig[1] = mnt >> (T.mant_dig - upper);
        }
        else
            mybig[0] = mnt << (upper - T.mant_dig);

        int lsu = 0; // Least significant ulong; when it get's zero, we can ignore it further on

        // adding zeros, until we reach first nonzero
        while (lsu < count - 1 || mybig[$ - 1]!=0)
        {
            ulong over = 0;
            foreach (i; lsu .. count)
            {
                mybig[i] = mybig[i] * 10 + over;
                over = mybig[i] >> 60;
                mybig[i] &= (1L << 60) - 1;
            }
            if (mybig[lsu] == 0)
                ++lsu;
            --final_exp;

            if (over != 0)
            {
                buffer[right++] = cast(byte) ('0' + over);
                buffer[right++] = '.';
                break;
            }
        }

        if (f.precision == 0 && !f.flHash) --right;

        // adding more digits
        static if (g)
            start = right - 1;
        else
            start = right;
        while ((lsu < count - 1 || mybig[$ - 1] != 0) && right - start < f.precision)
        {
            ulong over = 0;
            foreach (i;lsu .. count)
            {
                mybig[i] = mybig[i] * 10 + over;
                over = mybig[i] >> 60;
                mybig[i] &= (1L << 60) - 1;
            }
            if (mybig[lsu] == 0)
                ++lsu;

            buffer[right++] = cast(byte) ('0' + over);
        }

        // filling up with zeros to match precision
        if (right < start + f.precision)
        {
            buffer[right .. start + f.precision] = '0';
            right = start + f.precision;
        }

        // rounding type
        if (lsu >= count - 1 && mybig[count - 1] == 0)
            next = roundType.ZERO;
        else if (lsu == count - 1 && mybig[lsu] == 1L << 59)
            next = roundType.FIVE;
        else
        {
            ulong over = 0;
            foreach (i;lsu .. count)
            {
                mybig[i] = mybig[i] * 10 + over;
                over = mybig[i] >> 60;
                mybig[i] &= (1L << 60) - 1;
            }
            next = over >= 5 ? roundType.UPPER : roundType.LOWER;
        }
    }
    else
    {
        // medium sized number, probably with integer and fractional digits
        // this is fastest, because both parts fit into a ulong each
        ulong int_part = mnt >> (T.mant_dig - 1 - exp);
        ulong frac_part = mnt & ((1L << (T.mant_dig - 1 - exp)) - 1);

        start = 0;

        // could we already decide on the rounding mode in the integer part?
        bool found = false;

        if (int_part > 0)
        {
            // integer part, if there is something to print
            while (int_part >= 10)
            {
                buffer[--left] = '0' + (int_part % 10);
                int_part /= 10;
                ++final_exp;
                ++start;
            }

            buffer[--left] = '.';
            buffer[--left] = cast(byte) ('0' + int_part);

            static if (g)
                auto limit = f.precision + 1;
            else
                auto limit = f.precision + 2;

            if (right - left > limit)
            {
                auto old_right = right;
                right = left + limit;

                if (buffer[right] == '5' || buffer[right] == '0')
                {
                    next = buffer[right] == '5' ? roundType.FIVE : roundType.ZERO;
                    if (frac_part != 0)
                        next = next == roundType.FIVE ? roundType.UPPER : roundType.LOWER;
                    else
                        foreach (i;right + 1 .. old_right)
                            if (buffer[i] > '0')
                            {
                                next = next == roundType.FIVE ? roundType.UPPER : roundType.LOWER;
                                break;
                            }
                }
                else
                    next = buffer[right] > '5' ? roundType.UPPER : roundType.LOWER;
                found = true;
            }
        }
        else
        {
            // fractional part, skipping leading zeros
            while (frac_part != 0)
            {
                --final_exp;
                frac_part *= 10;
                auto tmp = frac_part >> (T.mant_dig - 1 - exp);
                frac_part &= ((1L << (T.mant_dig - 1 - exp)) - 1);
                if (tmp > 0)
                {
                    buffer[right++] = cast(byte) ('0' + tmp);
                    buffer[right++] = '.';
                    break;
                }
            }

            next = roundType.ZERO;
        }

        if (f.precision == 0 && !f.flHash) right--;

        static if (g)
            size_t limit = f.precision - 1;
        else
            size_t limit = f.precision;

        // the fractional part after the zeros
        while (frac_part != 0 && start < limit)
        {
            frac_part *= 10;
            buffer[right++] = cast(byte) ('0' + (frac_part >> (T.mant_dig - 1 - exp)));
            frac_part &= ((1L << (T.mant_dig - 1 - exp)) - 1);
            ++start;
        }

        static if (g)
            limit = right - left - 1;
        else
            limit = start;

        if (limit < f.precision)
        {
            buffer[right .. right + f.precision - limit] = '0';
            right += f.precision - limit;
            start = f.precision;
        }

        // rounding mode, if not allready known
        if (frac_part != 0 && !found)
        {
            frac_part *= 10;
            auto nextDigit = frac_part >> (T.mant_dig - 1 - exp);
            frac_part &= ((1L << (T.mant_dig - 1 - exp)) - 1);

            if (nextDigit == 5 && frac_part == 0)
                next = roundType.FIVE;
            else if (nextDigit >= 5)
                next = roundType.UPPER;
            else
                next = roundType.LOWER;
        }
    }

    // rounding
    bool roundUp = false;
    if (rm == RoundingMode.up)
        roundUp = next != roundType.ZERO && sgn != "-";
    else if (rm == RoundingMode.down)
        roundUp = next != roundType.ZERO && sgn == "-";
    else if (rm == RoundingMode.toZero)
        roundUp = false;
    else
    {
        assert(rm == RoundingMode.toNearestTiesToEven || rm == RoundingMode.toNearestTiesAwayFromZero,
               "RoundingMode is not toNearest");
        roundUp = next == roundType.UPPER;

        if (next == roundType.FIVE)
        {
            // IEEE754 allows for two different ways of implementing roundToNearest:

            // Round to nearest, ties away from zero
            if (rm == RoundingMode.toNearestTiesAwayFromZero)
                roundUp = true;
            else
            {
                // Round to nearest, ties to even
                auto last = buffer[right-1];
                if (last == '.') last = buffer[right-2];
                roundUp = last % 2 != 0;
            }
        }
    }

    if (roundUp)
    {
        foreach_reverse (i;left .. right)
        {
            if (buffer[i] == '.') continue;
            if (buffer[i] == '9')
                buffer[i] = '0';
            else
            {
                buffer[i]++;
                goto printFloat_done;
            }
        }

        // one more digit to the left, so we need to shift everything and increase exponent
        buffer[--left] = '1';
        buffer[left + 2] = buffer[left + 1];
        if (f.flHash || f.precision != 0)
            buffer[left + 1] = '.';
        right--;
        final_exp++;

printFloat_done:
    }

    static if (g)
    {
        if (!f.flHash)
        {
            // removing trailing 0s
            while (right > left && buffer[right - 1]=='0')
                right--;
            if (right > left && buffer[right - 1]=='.')
                right--;
        }
    }

    // printing exponent
    buffer[right++] = is_upper ? 'E' : 'e';
    buffer[right++] = final_exp >= 0 ? '+' : '-';

    if (final_exp < 0) final_exp = -final_exp;

    static if (is(T == float))
        enum max_exp_digits = 2;
    else
        enum max_exp_digits = 3;

    char[max_exp_digits] exp_str;
    size_t exp_pos = max_exp_digits;

    do
    {
        exp_str[--exp_pos] = '0' + final_exp%10;
        final_exp /= 10;
    } while (final_exp > 0);
    if (max_exp_digits - exp_pos == 1)
        exp_str[--exp_pos] = '0';

    buffer[right .. right + max_exp_digits - exp_pos] = exp_str[exp_pos .. $];
    right += max_exp_digits - exp_pos;

    // sign and padding
    bool need_sgn = false;
    if (sgn != "")
    {
        // when padding with zeros we need to postpone adding the sign
        if (right - left < f.width && !f.flDash && f.flZero)
            need_sgn = true;
        else
            buffer[--left] = sgn[0];
    }

    if (right - left < f.width)
    {
        if (f.flDash)
        {
            // padding right
            buffer[right .. f.width + left] = ' ';
            right = f.width + left;
        }
        else
        {
            // padding left
            buffer[right - f.width .. left] = f.flZero ? '0' : ' ';
            left = right - f.width;
        }
    }

    if (need_sgn)
        buffer[left] = sgn[0];

    return buffer[left .. right];
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    assert(printFloat(buf[], float.nan, f) == "nan");
    assert(printFloat(buf[], -float.nan, f) == "-nan");
    assert(printFloat(buf[], float.infinity, f) == "inf");
    assert(printFloat(buf[], -float.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0f, f) == "0.000000e+00");
    assert(printFloat(buf[], -0.0f, f) == "-0.000000e+00");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "9.999946e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-9.999946e-41");
    assert(printFloat(buf[], 1e-30f, f) == "1.000000e-30");
    assert(printFloat(buf[], -1e-30f, f) == "-1.000000e-30");
    assert(printFloat(buf[], 1e-10f, f) == "1.000000e-10");
    assert(printFloat(buf[], -1e-10f, f) == "-1.000000e-10");
    assert(printFloat(buf[], 0.1f, f) == "1.000000e-01");
    assert(printFloat(buf[], -0.1f, f) == "-1.000000e-01");
    assert(printFloat(buf[], 10.0f, f) == "1.000000e+01");
    assert(printFloat(buf[], -10.0f, f) == "-1.000000e+01");
    assert(printFloat(buf[], 1e30f, f) == "1.000000e+30");
    assert(printFloat(buf[], -1e30f, f) == "-1.000000e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "1.401298e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-1.401298e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    f.width = 20;
    f.precision = 10;

    assert(printFloat(buf[], float.nan, f) == "                 nan");
    assert(printFloat(buf[], -float.nan, f) == "                -nan");
    assert(printFloat(buf[], float.infinity, f) == "                 inf");
    assert(printFloat(buf[], -float.infinity, f) == "                -inf");
    assert(printFloat(buf[], 0.0f, f) == "    0.0000000000e+00");
    assert(printFloat(buf[], -0.0f, f) == "   -0.0000000000e+00");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "    9.9999461011e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "   -9.9999461011e-41");
    assert(printFloat(buf[], 1e-30f, f) == "    1.0000000032e-30");
    assert(printFloat(buf[], -1e-30f, f) == "   -1.0000000032e-30");
    assert(printFloat(buf[], 1e-10f, f) == "    1.0000000134e-10");
    assert(printFloat(buf[], -1e-10f, f) == "   -1.0000000134e-10");
    assert(printFloat(buf[], 0.1f, f) == "    1.0000000149e-01");
    assert(printFloat(buf[], -0.1f, f) == "   -1.0000000149e-01");
    assert(printFloat(buf[], 10.0f, f) == "    1.0000000000e+01");
    assert(printFloat(buf[], -10.0f, f) == "   -1.0000000000e+01");
    assert(printFloat(buf[], 1e30f, f) == "    1.0000000150e+30");
    assert(printFloat(buf[], -1e30f, f) == "   -1.0000000150e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "    1.4012984643e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "   -1.4012984643e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    f.width = 20;
    f.precision = 10;
    f.flDash = true;

    assert(printFloat(buf[], float.nan, f) == "nan                 ");
    assert(printFloat(buf[], -float.nan, f) == "-nan                ");
    assert(printFloat(buf[], float.infinity, f) == "inf                 ");
    assert(printFloat(buf[], -float.infinity, f) == "-inf                ");
    assert(printFloat(buf[], 0.0f, f) == "0.0000000000e+00    ");
    assert(printFloat(buf[], -0.0f, f) == "-0.0000000000e+00   ");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "9.9999461011e-41    ");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-9.9999461011e-41   ");
    assert(printFloat(buf[], 1e-30f, f) == "1.0000000032e-30    ");
    assert(printFloat(buf[], -1e-30f, f) == "-1.0000000032e-30   ");
    assert(printFloat(buf[], 1e-10f, f) == "1.0000000134e-10    ");
    assert(printFloat(buf[], -1e-10f, f) == "-1.0000000134e-10   ");
    assert(printFloat(buf[], 0.1f, f) == "1.0000000149e-01    ");
    assert(printFloat(buf[], -0.1f, f) == "-1.0000000149e-01   ");
    assert(printFloat(buf[], 10.0f, f) == "1.0000000000e+01    ");
    assert(printFloat(buf[], -10.0f, f) == "-1.0000000000e+01   ");
    assert(printFloat(buf[], 1e30f, f) == "1.0000000150e+30    ");
    assert(printFloat(buf[], -1e30f, f) == "-1.0000000150e+30   ");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "1.4012984643e-45    ");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-1.4012984643e-45   ");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    f.width = 20;
    f.precision = 10;
    f.flZero = true;

    assert(printFloat(buf[], float.nan, f) == "                 nan");
    assert(printFloat(buf[], -float.nan, f) == "                -nan");
    assert(printFloat(buf[], float.infinity, f) == "                 inf");
    assert(printFloat(buf[], -float.infinity, f) == "                -inf");
    assert(printFloat(buf[], 0.0f, f) == "00000.0000000000e+00");
    assert(printFloat(buf[], -0.0f, f) == "-0000.0000000000e+00");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "00009.9999461011e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-0009.9999461011e-41");
    assert(printFloat(buf[], 1e-30f, f) == "00001.0000000032e-30");
    assert(printFloat(buf[], -1e-30f, f) == "-0001.0000000032e-30");
    assert(printFloat(buf[], 1e-10f, f) == "00001.0000000134e-10");
    assert(printFloat(buf[], -1e-10f, f) == "-0001.0000000134e-10");
    assert(printFloat(buf[], 0.1f, f) == "00001.0000000149e-01");
    assert(printFloat(buf[], -0.1f, f) == "-0001.0000000149e-01");
    assert(printFloat(buf[], 10.0f, f) == "00001.0000000000e+01");
    assert(printFloat(buf[], -10.0f, f) == "-0001.0000000000e+01");
    assert(printFloat(buf[], 1e30f, f) == "00001.0000000150e+30");
    assert(printFloat(buf[], -1e30f, f) == "-0001.0000000150e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "00001.4012984643e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-0001.4012984643e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    f.precision = 1;

    assert(printFloat(buf[], 11.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "1.2e+01");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "1.3e+01");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.toNearestTiesAwayFromZero) == "1.2e+01");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.toNearestTiesAwayFromZero) == "1.1e+01");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.toNearestTiesAwayFromZero) == "1.1e+01");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "-1.2e+01");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "-1.3e+01");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.toNearestTiesAwayFromZero) == "-1.2e+01");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.toNearestTiesAwayFromZero) == "-1.1e+01");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.toNearestTiesAwayFromZero) == "-1.1e+01");

    assert(printFloat(buf[], 11.5f, f) == "1.2e+01");
    assert(printFloat(buf[], 12.5f, f) == "1.2e+01");
    assert(printFloat(buf[], 11.7f, f) == "1.2e+01");
    assert(printFloat(buf[], 11.3f, f) == "1.1e+01");
    assert(printFloat(buf[], 11.0f, f) == "1.1e+01");
    assert(printFloat(buf[], -11.5f, f) == "-1.2e+01");
    assert(printFloat(buf[], -12.5f, f) == "-1.2e+01");
    assert(printFloat(buf[], -11.7f, f) == "-1.2e+01");
    assert(printFloat(buf[], -11.3f, f) == "-1.1e+01");
    assert(printFloat(buf[], -11.0f, f) == "-1.1e+01");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.toZero) == "1.1e+01");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.toZero) == "1.2e+01");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.toZero) == "1.1e+01");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.toZero) == "1.1e+01");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.toZero) == "1.1e+01");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.toZero) == "-1.1e+01");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.toZero) == "-1.2e+01");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.toZero) == "-1.1e+01");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.toZero) == "-1.1e+01");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.toZero) == "-1.1e+01");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.up) == "1.2e+01");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.up) == "1.3e+01");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.up) == "1.2e+01");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.up) == "1.2e+01");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.up) == "1.1e+01");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.up) == "-1.1e+01");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.up) == "-1.2e+01");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.up) == "-1.1e+01");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.up) == "-1.1e+01");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.up) == "-1.1e+01");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.down) == "1.1e+01");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.down) == "1.2e+01");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.down) == "1.1e+01");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.down) == "1.1e+01");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.down) == "1.1e+01");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.down) == "-1.2e+01");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.down) == "-1.3e+01");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.down) == "-1.2e+01");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.down) == "-1.2e+01");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.down) == "-1.1e+01");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    assert(printFloat(buf[], double.nan, f) == "nan");
    assert(printFloat(buf[], -double.nan, f) == "-nan");
    assert(printFloat(buf[], double.infinity, f) == "inf");
    assert(printFloat(buf[], -double.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0, f) == "0.000000e+00");
    assert(printFloat(buf[], -0.0, f) == "-0.000000e+00");
    // / 1000 needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], 1e-307 / 1000, f) == "1.000000e-310");
    assert(printFloat(buf[], -1e-307 / 1000, f) == "-1.000000e-310");
    assert(printFloat(buf[], 1e-30, f) == "1.000000e-30");
    assert(printFloat(buf[], -1e-30, f) == "-1.000000e-30");
    assert(printFloat(buf[], 1e-10, f) == "1.000000e-10");
    assert(printFloat(buf[], -1e-10, f) == "-1.000000e-10");
    assert(printFloat(buf[], 0.1, f) == "1.000000e-01");
    assert(printFloat(buf[], -0.1, f) == "-1.000000e-01");
    assert(printFloat(buf[], 10.0, f) == "1.000000e+01");
    assert(printFloat(buf[], -10.0, f) == "-1.000000e+01");
    assert(printFloat(buf[], 1e300, f) == "1.000000e+300");
    assert(printFloat(buf[], -1e300, f) == "-1.000000e+300");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0), f) == "4.940656e-324");
    assert(printFloat(buf[], nextDown(-0.0), f) == "-4.940656e-324");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    assert(printFloat(buf[], real.nan, f) == "nan");
    assert(printFloat(buf[], -real.nan, f) == "-nan");
    assert(printFloat(buf[], real.infinity, f) == "inf");
    assert(printFloat(buf[], -real.infinity, f) == "-inf");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';

    import std.math : nextUp;

    double eps = nextUp(0.0);
    f.precision = 1000;
    assert(printFloat(buf[], eps, f) ==
           "4.9406564584124654417656879286822137236505980261432476442558568250067550727020875186529983636163599"
           ~"23797965646954457177309266567103559397963987747960107818781263007131903114045278458171678489821036"
           ~"88718636056998730723050006387409153564984387312473397273169615140031715385398074126238565591171026"
           ~"65855668676818703956031062493194527159149245532930545654440112748012970999954193198940908041656332"
           ~"45247571478690147267801593552386115501348035264934720193790268107107491703332226844753335720832431"
           ~"93609238289345836806010601150616980975307834227731832924790498252473077637592724787465608477820373"
           ~"44696995336470179726777175851256605511991315048911014510378627381672509558373897335989936648099411"
           ~"64205702637090279242767544565229087538682506419718265533447265625000000000000000000000000000000000"
           ~"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000e-324");

    f.precision = 50;
    assert(printFloat(buf[], double.max, f) ==
           "1.79769313486231570814527423731704356798070567525845e+308");
    assert(printFloat(buf[], double.epsilon, f) ==
           "2.22044604925031308084726333618164062500000000000000e-16");

    f.precision = 10;
    assert(printFloat(buf[], 1.0/3.0, f) == "3.3333333333e-01");
    assert(printFloat(buf[], 1.0/7.0, f) == "1.4285714286e-01");
    assert(printFloat(buf[], 1.0/9.0, f) == "1.1111111111e-01");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'e';
    f.precision = 15;

    import std.math : E, PI, PI_2, PI_4, M_1_PI, M_2_PI, M_2_SQRTPI,
                      LN10, LN2, LOG2, LOG2E, LOG2T, LOG10E, SQRT2, SQRT1_2;

    assert(printFloat(buf[], cast(double) E, f) == "2.718281828459045e+00");
    assert(printFloat(buf[], cast(double) PI, f) == "3.141592653589793e+00");
    assert(printFloat(buf[], cast(double) PI_2, f) == "1.570796326794897e+00");
    assert(printFloat(buf[], cast(double) PI_4, f) == "7.853981633974483e-01");
    assert(printFloat(buf[], cast(double) M_1_PI, f) == "3.183098861837907e-01");
    assert(printFloat(buf[], cast(double) M_2_PI, f) == "6.366197723675814e-01");
    assert(printFloat(buf[], cast(double) M_2_SQRTPI, f) == "1.128379167095513e+00");
    assert(printFloat(buf[], cast(double) LN10, f) == "2.302585092994046e+00");
    assert(printFloat(buf[], cast(double) LN2, f) == "6.931471805599453e-01");
    assert(printFloat(buf[], cast(double) LOG2, f) == "3.010299956639812e-01");
    assert(printFloat(buf[], cast(double) LOG2E, f) == "1.442695040888963e+00");
    assert(printFloat(buf[], cast(double) LOG2T, f) == "3.321928094887362e+00");
    assert(printFloat(buf[], cast(double) LOG10E, f) == "4.342944819032518e-01");
    assert(printFloat(buf[], cast(double) SQRT2, f) == "1.414213562373095e+00");
    assert(printFloat(buf[], cast(double) SQRT1_2, f) == "7.071067811865476e-01");
}

// for 100% coverage
@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'E';
    f.precision = 80;
    assert(printFloat(buf[], 5.62776e+12f, f) ==
           "5.62775982080000000000000000000000000000000000000000000000000000000000000000000000E+12");

    f.precision = 49;
    assert(printFloat(buf[], 2.5997869e-12f, f) ==
           "2.5997869221999758693186777236405760049819946289062E-12");

    f.precision = 6;
    assert(printFloat(buf[], -1.1418613e+07f, f) == "-1.141861E+07");
    assert(printFloat(buf[], -1.368281e+07f, f) == "-1.368281E+07");

    f.precision = 0;
    assert(printFloat(buf[], 709422.0f, f, RoundingMode.up) == "8E+05");

    f.precision = 1;
    assert(printFloat(buf[], -245.666f, f) == "-2.5E+02");
}

private auto printFloatF(bool g, T, Char)(return char[] buf, T val, FormatSpec!Char f, RoundingMode rm,
                                          string sgn, int exp, ulong mnt, bool is_upper)
if (is(T == float) || is(T == double)
    || (is(T == real) && (T.mant_dig == double.mant_dig || T.mant_dig == 64)))
{
    import std.conv : to;
    import std.algorithm.comparison : max;
    import std.math : log10, abs, floor, ceil;

    enum int bias = T.max_exp - 1;

    static if (!g)
    {
        if (f.precision == f.UNSPECIFIED)
            f.precision = 6;
    }

    // special treatment for 0.0
    if (exp == 0 && mnt == 0)
        return printFloat0!g(buf, f, sgn, is_upper);

    // add leading 1 for normalized values or correct exponent for denormalied values
    if (exp != 0)
        mnt |= 1L << (T.mant_dig - 1);
    else
        exp = 1;
    exp -= bias;

    // estimate the number of bytes needed left and right of the decimal point
    // the speed of the algorithm depends on being as accurate as possible with
    // this estimate

    // Default for the right side is the number of digits given by f.precision plus one for the dot.
    static if (g)
        auto max_right = max(0, f.precision - cast(int) val.abs.log10.floor + 1);
    else
        auto max_right = f.precision + 1;

    // If the exponent is <= 0 there is only the sign and one digit left of the dot, else
    // we have to estimate the number of digits. The factor between exp, which is the number of
    // digits in binary system and the searched number is log_2(10). We round this down to 3.32 to
    // get a conservative estimate. We need to add 3, because of the sign, the fact, that the
    // logarithm is one to small and because we need to round up instead of down, which to!int does.
    static if (g)
        auto max_left = max(2, 2 + cast(int) val.abs.log10.ceil);
    else
        auto max_left = exp > 0 ? to!int(exp / 3.32) + 3 : 2;

    // If the result is not left justified, we may need to add more digits here for getting the
    // correct width.
    if (!f.flDash)
    {
        static if (g)
            // %g cannot reduce the value by max_right due to trailing zeros, which are removed later
            max_left = max(max_left, f.width);
        else
            max_left = max(max_left, f.width - max_right + 2);
    }

    // If the result is left justified, we may need to add more digits to the right. This strongly
    // depends, on the exponent, see above. This time, we need to be conservative in the other direction
    // for not missing a digit; therefore we round log_2(10) up to 3.33.
    if (exp > 0 && f.flDash)
        max_right = max(max_right, f.width - to!int(exp / 3.33) - 1);
    else if (f.flDash)
        max_right = max(max_right, f.width - 1);

    size_t length = max_left + max_right;
    char[] buffer = length <= buf.length ? buf[0 .. length] : new char[length];
    size_t start = max_left;
    size_t left = max_left;
    size_t right = max_left;

    // for rounding we need to know if the rest of the number is exactly 0, between 0 and 0.5, 0.5 or above 0.5
    enum roundType { ZERO, LOWER, FIVE, UPPER }
    roundType next;

    // Depending on exp, we will use one of three algorithms:
    //
    // Algorithm A: For large exponents (exp >= T.mant_dig)
    // Algorithm B: For small exponents (exp < T.mant_dig - 61)
    // Algorithm C: For exponents close to 0.
    //
    // Algorithm A:
    //   The number to print looks like this: mantissa followed by several zeros.
    //
    //   We know, that there is no fractional part, so we can just use integer division,
    //   consecutivly dividing by 10 and writing down the remainder from right to left.
    //   Unfortunately the integer is too large to fit in an ulong, so we use something
    //   like BigInt: An array of ulongs. We only use 60 bits of that ulongs, because
    //   this simplifies (and speeds up) the division to come.
    //
    //   For the division we use integer division with reminder for each ulong and put
    //   the reminder of each step in the first 4 bits of ulong of the next step (think of
    //   long division for the rationale behind this). The final reminder is the next
    //   digit (from right to left).
    //
    // Algorithm B:
    //   The number to print looks like this: zero dot several zeros followed by the mantissa
    //
    //   We know, that the number has no integer part. The algorithm consecutivly multiplies
    //   by 10. The integer part (rounded down) after the multiplication is the next digit
    //   (from left to right). This integer part is removed after each step.
    //   Again, the number is represented as an array of ulongs, with only 60 bits used of
    //   every ulong.
    //
    //   For the multiplication we use normal integer multiplication, which can result in digits
    //   in the uppermost 4 bits. These 4 digits are the carry which is added to the result
    //   of the next multiplication and finally the last carry is the next digit.
    //
    //   The calculation will stop, when only zeros remain or when we've got enough digits
    //   for the requested precision. In the second case, we have to find out, which rounding
    //   we have. Aside from special cases we do this by calculating one more digit.
    //
    // Algorithm C:
    //   This time, we know, that the integral part and the fractional part each fit into a
    //   ulong. The mantissa might be partially in both parts or completely in the fractional
    //   part.
    //
    //   We first calculate the integral part by consecutive division by 10. Then we calculate
    //   the fractional part by consecutive multiplication by 10. Again only until we have enough
    //   digits. Finally, we decide the rounding type, mainly by looking at the next digit.

    ulong[18] bigbuf;
    if (exp >= T.mant_dig)
    {
        // large number without fractional digits
        //
        // As this number does not fit in a ulong, we use an array of ulongs. We only use 60 of the 64 bits,
        // because this makes it much more easy to implement the division by 10.
        int count = exp / 60 + 1;

        // saved in big endian format
        ulong[] mybig = bigbuf[0 .. count];

        // only the first or the first two ulongs contain the mantiassa. The rest are zeros.
        int lower = 60 - (exp - T.mant_dig + 1) % 60;
        if (lower < T.mant_dig)
        {
            mybig[0] = mnt >> lower;
            mybig[1] = (mnt & ((1L << lower) - 1)) << 60 - lower;
        }
        else
            mybig[0] = (mnt & ((1L << lower) - 1)) << 60 - lower;

        // Generation of digits by consecutive division with reminder by 10.
        int msu = 0; // Most significant ulong; when it get's zero, we can ignore it furtheron
        while (msu < count - 1 || mybig[$ - 1] != 0)
        {
            ulong mod = 0;
            foreach (i;msu .. count)
            {
                mybig[i] |= mod << 60;
                mod = mybig[i] % 10;
                mybig[i] /= 10;
            }
            if (mybig[msu] == 0)
                ++msu;

            buffer[--left] = cast(byte) ('0' + mod);
        }

        if (f.precision > 0 || f.flHash) buffer[right++] = '.';

        static if (g) start = left; // count precision from first digit

        next = roundType.ZERO;
    }
    else if (exp + 61 < T.mant_dig)
    {
        // small number without integer digits
        //
        // Again this number does not fit in a ulong and we use an array of ulongs. And again we
        // only use 60 bits, because this simplifies the multiplication by 10.
        int count = (T.mant_dig - exp - 2) / 60 + 1;

        // saved in little endian format
        ulong[] mybig = bigbuf[0 .. count];

        // only the last or the last two ulongs contain the mantiassa. Because of little endian
        // format these are the ulongs at index 0 and 1. The rest are zeros.
        int upper = 60 - (-exp - 1) % 60;
        if (upper < T.mant_dig)
        {
            mybig[0] = (mnt & ((1L << (T.mant_dig - upper)) - 1)) << 60 - (T.mant_dig - upper);
            mybig[1] = mnt >> (T.mant_dig - upper);
        }
        else
            mybig[0] = mnt << (upper - T.mant_dig);

        buffer[--left] = '0'; // 0 left of the dot

        if (f.precision > 0 || f.flHash) buffer[right++] = '.';

        static if (g)
        {
            // precision starts at first non zero, so we move start
            // to the right, until we found first non zero, thus avoiding
            // a premature break of the loop
            bool found = false;
            start = left + 1;
        }

        // Generation of digits by consecutive multiplication by 10.
        int lsu = 0; // Least significant ulong; when it get's zero, we can ignore it furtheron
        while ((lsu < count - 1 || mybig[$ - 1] != 0) && right - start - 1 < f.precision)
        {
            ulong over = 0;
            foreach (i;lsu .. count)
            {
                mybig[i] = mybig[i] * 10 + over;
                over = mybig[i] >> 60;
                mybig[i] &= (1L << 60) - 1;
            }
            if (mybig[lsu] == 0)
                ++lsu;

            buffer[right++] = cast(byte) ('0' + over);

            static if (g)
            {
                if (buffer[right - 1] != '0')
                    found = true;
                else if (!found)
                    start++;
            }
        }

        if (lsu >= count - 1 && mybig[count - 1] == 0)
            next = roundType.ZERO;
        else if (lsu == count - 1 && mybig[lsu] == 1L << 59)
            next = roundType.FIVE;
        else
        {
            ulong over = 0;
            foreach (i;lsu .. count)
            {
                mybig[i] = mybig[i] * 10 + over;
                over = mybig[i] >> 60;
                mybig[i] &= (1L << 60) - 1;
            }
            next = over >= 5 ? roundType.UPPER : roundType.LOWER;
        }
    }
    else
    {
        // medium sized number, probably with integer and fractional digits
        // this is fastest, because both parts fit into a ulong each
        ulong int_part = mnt >> (T.mant_dig - 1 - exp);
        ulong frac_part = mnt & ((1L << (T.mant_dig - 1 - exp)) - 1);

        static if (g) auto found = int_part > 0; // searching first non zero

        // creating int part
        if (int_part == 0)
            buffer[--left] = '0';
        else
            while (int_part > 0)
            {
                buffer[--left] = '0' + (int_part % 10);
                int_part /= 10;
            }

        if (f.precision > 0 || f.flHash)
            buffer[right++] = '.';

        // creating frac part
        static if (g) start = left + (found ? 0 : 1);
        while (frac_part != 0 && right - start - 1 < f.precision)
        {
            frac_part *= 10;
            buffer[right++] = cast(byte)('0' + (frac_part >> (T.mant_dig - 1 - exp)));

            static if (g)
            {
                if (buffer[right - 1] != '0')
                    found = true;
                else if (!found)
                    start++;
            }

            frac_part &= ((1L << (T.mant_dig - 1 - exp)) - 1);
        }

        if (frac_part == 0)
            next = roundType.ZERO;
        else
        {
            frac_part *= 10;
            auto nextDigit = frac_part >> (T.mant_dig - 1 - exp);
            frac_part &= ((1L << (T.mant_dig - 1 - exp)) - 1);

            if (nextDigit == 5 && frac_part == 0)
                next = roundType.FIVE;
            else if (nextDigit >= 5)
                next = roundType.UPPER;
            else
                next = roundType.LOWER;
        }
    }

    // rounding
    bool roundUp = false;

    if (rm == RoundingMode.up)
        roundUp = next != roundType.ZERO && sgn != "-";
    else if (rm == RoundingMode.down)
        roundUp = next != roundType.ZERO && sgn == "-";
    else if (rm == RoundingMode.toZero)
        roundUp = false;
    else
    {
        assert(rm == RoundingMode.toNearestTiesToEven || rm == RoundingMode.toNearestTiesAwayFromZero,
               "RoundingMode is not toNearest");
        roundUp = next == roundType.UPPER;

        if (next == roundType.FIVE)
        {
            // IEEE754 allows for two different ways of implementing roundToNearest:

            // Round to nearest, ties away from zero
            if (rm == RoundingMode.toNearestTiesAwayFromZero)
                roundUp = true;
            else
            {
                // Round to nearest, ties to even
                auto last = buffer[right - 1];
                if (last == '.') last = buffer[right - 2];
                roundUp = last % 2 != 0;
            }
        }
    }

    if (f.precision > 0 || f.flHash)
    {
        // adding zeros
        buffer[right .. f.precision + start + 1] = '0';
        right = f.precision + start + 1;
    }

    if (roundUp)
    {
        foreach_reverse (i;left .. right)
        {
            if (buffer[i] == '.') continue;
            if (buffer[i] == '9')
                buffer[i] = '0';
            else
            {
                buffer[i]++;
                static if (g)
                {
                    // in case of 0.0...009...9 => 0.0...010...0 we have to remove
                    // the right most digit to get the precision right
                    if (buffer[i] == '1')
                    {
                        foreach (j;left .. i)
                            if (buffer[j] != '0' && buffer[j] != '.') goto printFloat_done;
                        right--;
                    }
                }
                goto printFloat_done;
            }
        }
        buffer[--left] = '1';
printFloat_done:
    }

    static if (g)
    {
        if (!f.flHash)
        {
            // removing trailing 0s
            while (right > left && buffer[right - 1]=='0')
                right--;
            if (right > left && buffer[right - 1]=='.')
                right--;
        }
    }

    // sign and padding
    bool need_sgn = false;
    if (sgn != "")
    {
        // when padding with zeros we need to postpone adding the sign
        if (right - left < f.width && !f.flDash && f.flZero)
            need_sgn = true;
        else
            buffer[--left] = sgn[0];
    }

    if (right - left < f.width)
    {
        if (f.flDash)
        {
            // padding right
            buffer[right .. f.width + left] = ' ';
            right = f.width + left;
        }
        else
        {
            // padding left
            buffer[right - f.width .. left] = f.flZero ? '0' : ' ';
            left = right - f.width;
        }
    }

    if (need_sgn)
        buffer[left] = sgn[0];

    return buffer[left .. right];
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    assert(printFloat(buf[], float.nan, f) == "nan");
    assert(printFloat(buf[], -float.nan, f) == "-nan");
    assert(printFloat(buf[], float.infinity, f) == "inf");
    assert(printFloat(buf[], -float.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0f, f) == "0.000000");
    assert(printFloat(buf[], -0.0f, f) == "-0.000000");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "0.000000");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-0.000000");
    assert(printFloat(buf[], 1e-30f, f) == "0.000000");
    assert(printFloat(buf[], -1e-30f, f) == "-0.000000");
    assert(printFloat(buf[], 1e-10f, f) == "0.000000");
    assert(printFloat(buf[], -1e-10f, f) == "-0.000000");
    assert(printFloat(buf[], 0.1f, f) == "0.100000");
    assert(printFloat(buf[], -0.1f, f) == "-0.100000");
    assert(printFloat(buf[], 10.0f, f) == "10.000000");
    assert(printFloat(buf[], -10.0f, f) == "-10.000000");
    assert(printFloat(buf[], 1e30f, f) == "1000000015047466219876688855040.000000");
    assert(printFloat(buf[], -1e30f, f) == "-1000000015047466219876688855040.000000");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "0.000000");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-0.000000");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    f.width = 20;
    f.precision = 10;

    assert(printFloat(buf[], float.nan, f) == "                 nan");
    assert(printFloat(buf[], -float.nan, f) == "                -nan");
    assert(printFloat(buf[], float.infinity, f) == "                 inf");
    assert(printFloat(buf[], -float.infinity, f) == "                -inf");
    assert(printFloat(buf[], 0.0f, f) == "        0.0000000000");
    assert(printFloat(buf[], -0.0f, f) == "       -0.0000000000");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "        0.0000000000");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "       -0.0000000000");
    assert(printFloat(buf[], 1e-30f, f) == "        0.0000000000");
    assert(printFloat(buf[], -1e-30f, f) == "       -0.0000000000");
    assert(printFloat(buf[], 1e-10f, f) == "        0.0000000001");
    assert(printFloat(buf[], -1e-10f, f) == "       -0.0000000001");
    assert(printFloat(buf[], 0.1f, f) == "        0.1000000015");
    assert(printFloat(buf[], -0.1f, f) == "       -0.1000000015");
    assert(printFloat(buf[], 10.0f, f) == "       10.0000000000");
    assert(printFloat(buf[], -10.0f, f) == "      -10.0000000000");
    assert(printFloat(buf[], 1e30f, f) == "1000000015047466219876688855040.0000000000");
    assert(printFloat(buf[], -1e30f, f) == "-1000000015047466219876688855040.0000000000");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "        0.0000000000");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "       -0.0000000000");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    f.width = 20;
    f.precision = 10;
    f.flDash = true;

    assert(printFloat(buf[], float.nan, f) == "nan                 ");
    assert(printFloat(buf[], -float.nan, f) == "-nan                ");
    assert(printFloat(buf[], float.infinity, f) == "inf                 ");
    assert(printFloat(buf[], -float.infinity, f) == "-inf                ");
    assert(printFloat(buf[], 0.0f, f) == "0.0000000000        ");
    assert(printFloat(buf[], -0.0f, f) == "-0.0000000000       ");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "0.0000000000        ");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-0.0000000000       ");
    assert(printFloat(buf[], 1e-30f, f) == "0.0000000000        ");
    assert(printFloat(buf[], -1e-30f, f) == "-0.0000000000       ");
    assert(printFloat(buf[], 1e-10f, f) == "0.0000000001        ");
    assert(printFloat(buf[], -1e-10f, f) == "-0.0000000001       ");
    assert(printFloat(buf[], 0.1f, f) == "0.1000000015        ");
    assert(printFloat(buf[], -0.1f, f) == "-0.1000000015       ");
    assert(printFloat(buf[], 10.0f, f) == "10.0000000000       ");
    assert(printFloat(buf[], -10.0f, f) == "-10.0000000000      ");
    assert(printFloat(buf[], 1e30f, f) == "1000000015047466219876688855040.0000000000");
    assert(printFloat(buf[], -1e30f, f) == "-1000000015047466219876688855040.0000000000");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "0.0000000000        ");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-0.0000000000       ");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    f.width = 20;
    f.precision = 10;
    f.flZero = true;

    assert(printFloat(buf[], float.nan, f) == "                 nan");
    assert(printFloat(buf[], -float.nan, f) == "                -nan");
    assert(printFloat(buf[], float.infinity, f) == "                 inf");
    assert(printFloat(buf[], -float.infinity, f) == "                -inf");
    assert(printFloat(buf[], 0.0f, f) == "000000000.0000000000");
    assert(printFloat(buf[], -0.0f, f) == "-00000000.0000000000");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "000000000.0000000000");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-00000000.0000000000");
    assert(printFloat(buf[], 1e-30f, f) == "000000000.0000000000");
    assert(printFloat(buf[], -1e-30f, f) == "-00000000.0000000000");
    assert(printFloat(buf[], 1e-10f, f) == "000000000.0000000001");
    assert(printFloat(buf[], -1e-10f, f) == "-00000000.0000000001");
    assert(printFloat(buf[], 0.1f, f) == "000000000.1000000015");
    assert(printFloat(buf[], -0.1f, f) == "-00000000.1000000015");
    assert(printFloat(buf[], 10.0f, f) == "000000010.0000000000");
    assert(printFloat(buf[], -10.0f, f) == "-00000010.0000000000");
    assert(printFloat(buf[], 1e30f, f) == "1000000015047466219876688855040.0000000000");
    assert(printFloat(buf[], -1e30f, f) == "-1000000015047466219876688855040.0000000000");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "000000000.0000000000");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-00000000.0000000000");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    f.precision = 0;

    // ties away from zero
    assert(printFloat(buf[], 11.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "12");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "13");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.toNearestTiesAwayFromZero) == "12");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.toNearestTiesAwayFromZero) == "11");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.toNearestTiesAwayFromZero) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "-12");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "-13");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.toNearestTiesAwayFromZero) == "-12");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.toNearestTiesAwayFromZero) == "-11");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.toNearestTiesAwayFromZero) == "-11");

    // ties to even
    assert(printFloat(buf[], 11.5f, f) == "12");
    assert(printFloat(buf[], 12.5f, f) == "12");
    assert(printFloat(buf[], 11.7f, f) == "12");
    assert(printFloat(buf[], 11.3f, f) == "11");
    assert(printFloat(buf[], 11.0f, f) == "11");
    assert(printFloat(buf[], -11.5f, f) == "-12");
    assert(printFloat(buf[], -12.5f, f) == "-12");
    assert(printFloat(buf[], -11.7f, f) == "-12");
    assert(printFloat(buf[], -11.3f, f) == "-11");
    assert(printFloat(buf[], -11.0f, f) == "-11");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.toZero) == "12");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.toZero) == "-11");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.toZero) == "-12");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.toZero) == "-11");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.toZero) == "-11");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.toZero) == "-11");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.up) == "12");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.up) == "13");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.up) == "12");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.up) == "12");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.up) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.up) == "-11");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.up) == "-12");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.up) == "-11");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.up) == "-11");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.up) == "-11");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.down) == "12");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.down) == "-12");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.down) == "-13");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.down) == "-12");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.down) == "-12");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.down) == "-11");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    assert(printFloat(buf[], double.nan, f) == "nan");
    assert(printFloat(buf[], -double.nan, f) == "-nan");
    assert(printFloat(buf[], double.infinity, f) == "inf");
    assert(printFloat(buf[], -double.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0, f) == "0.000000");
    assert(printFloat(buf[], -0.0, f) == "-0.000000");
    // / 1000 needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], 1e-307 / 1000, f) == "0.000000");
    assert(printFloat(buf[], -1e-307 / 1000, f) == "-0.000000");
    assert(printFloat(buf[], 1e-30, f) == "0.000000");
    assert(printFloat(buf[], -1e-30, f) == "-0.000000");
    assert(printFloat(buf[], 1e-10, f) == "0.000000");
    assert(printFloat(buf[], -1e-10, f) == "-0.000000");
    assert(printFloat(buf[], 0.1, f) == "0.100000");
    assert(printFloat(buf[], -0.1, f) == "-0.100000");
    assert(printFloat(buf[], 10.0, f) == "10.000000");
    assert(printFloat(buf[], -10.0, f) == "-10.000000");
    assert(printFloat(buf[], 1e300, f) ==
           "100000000000000005250476025520442024870446858110815915491585411551180245798890819578637137508044786"
          ~"404370444383288387817694252323536043057564479218478670698284838720092657580373783023379478809005936"
          ~"895323497079994508111903896764088007465274278014249457925878882005684283811566947219638686545940054"
          ~"0160.000000");
    assert(printFloat(buf[], -1e300, f) ==
           "-100000000000000005250476025520442024870446858110815915491585411551180245798890819578637137508044786"
          ~"404370444383288387817694252323536043057564479218478670698284838720092657580373783023379478809005936"
          ~"895323497079994508111903896764088007465274278014249457925878882005684283811566947219638686545940054"
          ~"0160.000000");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0), f) == "0.000000");
    assert(printFloat(buf[], nextDown(-0.0), f) == "-0.000000");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    assert(printFloat(buf[], real.nan, f) == "nan");
    assert(printFloat(buf[], -real.nan, f) == "-nan");
    assert(printFloat(buf[], real.infinity, f) == "inf");
    assert(printFloat(buf[], -real.infinity, f) == "-inf");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';

    import std.math : nextUp;

    double eps = nextUp(0.0);
    f.precision = 1000;
    assert(printFloat(buf[], eps, f) ==
           "0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"00000000000000000000000000000049406564584124654417656879286822137236505980261432476442558568250067"
           ~"55072702087518652998363616359923797965646954457177309266567103559397963987747960107818781263007131"
           ~"90311404527845817167848982103688718636056998730723050006387409153564984387312473397273169615140031"
           ~"71538539807412623856559117102665855668676818703956031062493194527159149245532930545654440112748012"
           ~"97099995419319894090804165633245247571478690147267801593552386115501348035264934720193790268107107"
           ~"49170333222684475333572083243193609238289345836806010601150616980975307834227731832924790498252473"
           ~"07763759272478746560847782037344696995336470179726777175851256605511991315048911014510378627381672"
           ~"509558373897335989937");

    f.precision = 0;
    assert(printFloat(buf[], double.max, f) ==
           "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878"
           ~"17154045895351438246423432132688946418276846754670353751698604991057655128207624549009038932894407"
           ~"58685084551339423045832369032229481658085593321233482747978262041447231687381771809192998812504040"
           ~"26184124858368");

    f.precision = 50;
    assert(printFloat(buf[], double.epsilon, f) ==
           "0.00000000000000022204460492503130808472633361816406");

    f.precision = 10;
    assert(printFloat(buf[], 1.0/3.0, f) == "0.3333333333");
    assert(printFloat(buf[], 1.0/7.0, f) == "0.1428571429");
    assert(printFloat(buf[], 1.0/9.0, f) == "0.1111111111");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    f.precision = 15;

    import std.math : E, PI, PI_2, PI_4, M_1_PI, M_2_PI, M_2_SQRTPI,
                      LN10, LN2, LOG2, LOG2E, LOG2T, LOG10E, SQRT2, SQRT1_2;

    assert(printFloat(buf[], cast(double) E, f) == "2.718281828459045");
    assert(printFloat(buf[], cast(double) PI, f) == "3.141592653589793");
    assert(printFloat(buf[], cast(double) PI_2, f) == "1.570796326794897");
    assert(printFloat(buf[], cast(double) PI_4, f) == "0.785398163397448");
    assert(printFloat(buf[], cast(double) M_1_PI, f) == "0.318309886183791");
    assert(printFloat(buf[], cast(double) M_2_PI, f) == "0.636619772367581");
    assert(printFloat(buf[], cast(double) M_2_SQRTPI, f) == "1.128379167095513");
    assert(printFloat(buf[], cast(double) LN10, f) == "2.302585092994046");
    assert(printFloat(buf[], cast(double) LN2, f) == "0.693147180559945");
    assert(printFloat(buf[], cast(double) LOG2, f) == "0.301029995663981");
    assert(printFloat(buf[], cast(double) LOG2E, f) == "1.442695040888963");
    assert(printFloat(buf[], cast(double) LOG2T, f) == "3.321928094887362");
    assert(printFloat(buf[], cast(double) LOG10E, f) == "0.434294481903252");
    assert(printFloat(buf[], cast(double) SQRT2, f) == "1.414213562373095");
    assert(printFloat(buf[], cast(double) SQRT1_2, f) == "0.707106781186548");
}

// for 100% coverage
@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'f';
    f.precision = 1;
    assert(printFloat(buf[], 9.99, f) == "10.0");

    import std.math : nextUp;

    float eps = nextUp(0.0f);

    f.precision = 148;
    assert(printFloat(buf[], eps, f, RoundingMode.toZero) ==
           "0.0000000000000000000000000000000000000000000014012984643248170709237295832899161312802619418765157"
           ~"717570682838897910826858606014866381883621215820312");

    f.precision = 149;
    assert(printFloat(buf[], eps, f, RoundingMode.toZero) ==
           "0.0000000000000000000000000000000000000000000014012984643248170709237295832899161312802619418765157"
           ~"7175706828388979108268586060148663818836212158203125");
}

private auto printFloatG(T, Char)(return char[] buf, T val, FormatSpec!Char f, RoundingMode rm,
                                  string sgn, int exp, ulong mnt, bool is_upper)
if (is(T == float) || is(T == double)
    || (is(T == real) && (T.mant_dig == double.mant_dig || T.mant_dig == 64)))
{
    import core.math : abs = fabs;

    if (f.precision == f.UNSPECIFIED)
        f.precision = 6;

    if (f.precision == 0)
        f.precision = 1;

    bool useE = false;

    final switch (rm)
    {
    case RoundingMode.up:
        useE = abs(val) >= 10.0 ^^ f.precision - (val > 0 ? 1 : 0)
            || abs(val) < 0.0001 - (val > 0 ? (10.0 ^^ (-4 - f.precision)) : 0);
        break;
    case RoundingMode.down:
        useE = abs(val) >= 10.0 ^^ f.precision - (val < 0 ? 1 : 0)
            || abs(val) < 0.0001 - (val < 0 ? (10.0 ^^ (-4 - f.precision)) : 0);
        break;
    case RoundingMode.toZero:
        useE = abs(val) >= 10.0 ^^ f.precision
            || abs(val) < 0.0001;
        break;
    case RoundingMode.toNearestTiesToEven:
    case RoundingMode.toNearestTiesAwayFromZero:
        useE = abs(val) >= 10.0 ^^ f.precision - 0.5
            || abs(val) < 0.0001 - 0.5 * (10.0 ^^ (-4 - f.precision));
        break;
    }

    if (useE)
        return printFloatE!true(buf, val, f, rm, sgn, exp, mnt, is_upper);
    else
        return printFloatF!true(buf, val, f, rm, sgn, exp, mnt, is_upper);
}

@safe unittest
{
    // This one tests the switch between e-like and f-like output.
    // There is a small gap left between the two, where the used
    // variation is not clearly defined. This is intentional and due
    // to the way, D handles floating point numbers. On different
    // computers with different reals the results may vary in this gap.

    import std.math : nextDown, nextUp;

    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';

    double val = 999999.5;
    assert(printFloat(buf[], val.nextUp, f) == "1e+06");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f) == "999999");

    val = 0.00009999995;
    assert(printFloat(buf[], val.nextUp, f) == "0.0001");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f) == "9.99999e-05");

    val = 1000000;
    assert(printFloat(buf[], val.nextUp, f, RoundingMode.toZero) == "1e+06");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f, RoundingMode.toZero) == "999999");

    val = 0.0001;
    assert(printFloat(buf[], val.nextUp, f, RoundingMode.toZero) == "0.0001");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f, RoundingMode.toZero) == "9.99999e-05");

    val = 999999;
    assert(printFloat(buf[], val.nextUp, f, RoundingMode.up) == "1e+06");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f, RoundingMode.up) == "999999");

    // 0.0000999999 is actually represented as 0.0000999998999..., which is
    // less than 0.0000999999, so we need to use nextUp to get the corner case here
    val = nextUp(0.0000999999);
    assert(printFloat(buf[], val.nextUp, f, RoundingMode.up) == "0.0001");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f, RoundingMode.up) == "9.99999e-05");

    val = 1000000;
    assert(printFloat(buf[], val.nextUp, f, RoundingMode.down) == "1e+06");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f, RoundingMode.down) == "999999");

    val = 0.0001;
    assert(printFloat(buf[], val.nextUp, f, RoundingMode.down) == "0.0001");
    val = nextDown(val);
    assert(printFloat(buf[], val.nextDown, f, RoundingMode.down) == "9.99999e-05");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    assert(printFloat(buf[], float.nan, f) == "nan");
    assert(printFloat(buf[], -float.nan, f) == "-nan");
    assert(printFloat(buf[], float.infinity, f) == "inf");
    assert(printFloat(buf[], -float.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0f, f) == "0");
    assert(printFloat(buf[], -0.0f, f) == "-0");

    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "9.99995e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-9.99995e-41");
    assert(printFloat(buf[], 1e-30f, f) == "1e-30");
    assert(printFloat(buf[], -1e-30f, f) == "-1e-30");
    assert(printFloat(buf[], 1e-10f, f) == "1e-10");
    assert(printFloat(buf[], -1e-10f, f) == "-1e-10");
    assert(printFloat(buf[], 0.1f, f) == "0.1");
    assert(printFloat(buf[], -0.1f, f) == "-0.1");
    assert(printFloat(buf[], 10.0f, f) == "10");
    assert(printFloat(buf[], -10.0f, f) == "-10");
    assert(printFloat(buf[], 1e30f, f) == "1e+30");
    assert(printFloat(buf[], -1e30f, f) == "-1e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "1.4013e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-1.4013e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.width = 20;
    f.precision = 10;

    assert(printFloat(buf[], float.nan, f) == "                 nan");
    assert(printFloat(buf[], -float.nan, f) == "                -nan");
    assert(printFloat(buf[], float.infinity, f) == "                 inf");
    assert(printFloat(buf[], -float.infinity, f) == "                -inf");
    assert(printFloat(buf[], 0.0f, f) == "                   0");
    assert(printFloat(buf[], -0.0f, f) == "                  -0");
    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "     9.999946101e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "    -9.999946101e-41");
    assert(printFloat(buf[], 1e-30f, f) == "     1.000000003e-30");
    assert(printFloat(buf[], -1e-30f, f) == "    -1.000000003e-30");
    assert(printFloat(buf[], 1e-10f, f) == "     1.000000013e-10");
    assert(printFloat(buf[], -1e-10f, f) == "    -1.000000013e-10");
    assert(printFloat(buf[], 0.1f, f) == "        0.1000000015");
    assert(printFloat(buf[], -0.1f, f) == "       -0.1000000015");
    assert(printFloat(buf[], 10.0f, f) == "                  10");
    assert(printFloat(buf[], -10.0f, f) == "                 -10");
    assert(printFloat(buf[], 1e30f, f) == "     1.000000015e+30");
    assert(printFloat(buf[], -1e30f, f) == "    -1.000000015e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "     1.401298464e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "    -1.401298464e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.width = 20;
    f.precision = 10;
    f.flDash = true;

    assert(printFloat(buf[], float.nan, f) == "nan                 ");
    assert(printFloat(buf[], -float.nan, f) == "-nan                ");
    assert(printFloat(buf[], float.infinity, f) == "inf                 ");
    assert(printFloat(buf[], -float.infinity, f) == "-inf                ");
    assert(printFloat(buf[], 0.0f, f) == "0                   ");
    assert(printFloat(buf[], -0.0f, f) == "-0                  ");

    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "9.999946101e-41     ");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-9.999946101e-41    ");
    assert(printFloat(buf[], 1e-30f, f) == "1.000000003e-30     ");
    assert(printFloat(buf[], -1e-30f, f) == "-1.000000003e-30    ");
    assert(printFloat(buf[], 1e-10f, f) == "1.000000013e-10     ");
    assert(printFloat(buf[], -1e-10f, f) == "-1.000000013e-10    ");
    assert(printFloat(buf[], 0.1f, f) == "0.1000000015        ");
    assert(printFloat(buf[], -0.1f, f) == "-0.1000000015       ");
    assert(printFloat(buf[], 10.0f, f) == "10                  ");
    assert(printFloat(buf[], -10.0f, f) == "-10                 ");
    assert(printFloat(buf[], 1e30f, f) == "1.000000015e+30     ");
    assert(printFloat(buf[], -1e30f, f) == "-1.000000015e+30    ");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "1.401298464e-45     ");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-1.401298464e-45    ");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.width = 20;
    f.precision = 10;
    f.flZero = true;

    assert(printFloat(buf[], float.nan, f) == "                 nan");
    assert(printFloat(buf[], -float.nan, f) == "                -nan");
    assert(printFloat(buf[], float.infinity, f) == "                 inf");
    assert(printFloat(buf[], -float.infinity, f) == "                -inf");
    assert(printFloat(buf[], 0.0f, f) == "00000000000000000000");
    assert(printFloat(buf[], -0.0f, f) == "-0000000000000000000");

    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "000009.999946101e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-00009.999946101e-41");
    assert(printFloat(buf[], 1e-30f, f) == "000001.000000003e-30");
    assert(printFloat(buf[], -1e-30f, f) == "-00001.000000003e-30");
    assert(printFloat(buf[], 1e-10f, f) == "000001.000000013e-10");
    assert(printFloat(buf[], -1e-10f, f) == "-00001.000000013e-10");
    assert(printFloat(buf[], 0.1f, f) == "000000000.1000000015");
    assert(printFloat(buf[], -0.1f, f) == "-00000000.1000000015");
    assert(printFloat(buf[], 10.0f, f) == "00000000000000000010");
    assert(printFloat(buf[], -10.0f, f) == "-0000000000000000010");
    assert(printFloat(buf[], 1e30f, f) == "000001.000000015e+30");
    assert(printFloat(buf[], -1e30f, f) == "-00001.000000015e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "000001.401298464e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-00001.401298464e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.precision = 10;
    f.flHash = true;

    assert(printFloat(buf[], float.nan, f) == "nan");
    assert(printFloat(buf[], -float.nan, f) == "-nan");
    assert(printFloat(buf[], float.infinity, f) == "inf");
    assert(printFloat(buf[], -float.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0f, f) == "0.000000000");
    assert(printFloat(buf[], -0.0f, f) == "-0.000000000");

    // cast needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], cast(float) 1e-40, f) == "9.999946101e-41");
    assert(printFloat(buf[], cast(float) -1e-40, f) == "-9.999946101e-41");
    assert(printFloat(buf[], 1e-30f, f) == "1.000000003e-30");
    assert(printFloat(buf[], -1e-30f, f) == "-1.000000003e-30");
    assert(printFloat(buf[], 1e-10f, f) == "1.000000013e-10");
    assert(printFloat(buf[], -1e-10f, f) == "-1.000000013e-10");
    assert(printFloat(buf[], 0.1f, f) == "0.1000000015");
    assert(printFloat(buf[], -0.1f, f) == "-0.1000000015");
    assert(printFloat(buf[], 10.0f, f) == "10.00000000");
    assert(printFloat(buf[], -10.0f, f) == "-10.00000000");
    assert(printFloat(buf[], 1e30f, f) == "1.000000015e+30");
    assert(printFloat(buf[], -1e30f, f) == "-1.000000015e+30");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0f), f) == "1.401298464e-45");
    assert(printFloat(buf[], nextDown(-0.0f), f) == "-1.401298464e-45");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.precision = 2;

    assert(printFloat(buf[], 11.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "12");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "13");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.toNearestTiesAwayFromZero) == "12");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.toNearestTiesAwayFromZero) == "11");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.toNearestTiesAwayFromZero) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "-12");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.toNearestTiesAwayFromZero) == "-13");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.toNearestTiesAwayFromZero) == "-12");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.toNearestTiesAwayFromZero) == "-11");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.toNearestTiesAwayFromZero) == "-11");

    // ties to even
    assert(printFloat(buf[], 11.5f, f) == "12");
    assert(printFloat(buf[], 12.5f, f) == "12");
    assert(printFloat(buf[], 11.7f, f) == "12");
    assert(printFloat(buf[], 11.3f, f) == "11");
    assert(printFloat(buf[], 11.0f, f) == "11");
    assert(printFloat(buf[], -11.5f, f) == "-12");
    assert(printFloat(buf[], -12.5f, f) == "-12");
    assert(printFloat(buf[], -11.7f, f) == "-12");
    assert(printFloat(buf[], -11.3f, f) == "-11");
    assert(printFloat(buf[], -11.0f, f) == "-11");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.toZero) == "12");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.toZero) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.toZero) == "-11");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.toZero) == "-12");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.toZero) == "-11");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.toZero) == "-11");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.toZero) == "-11");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.up) == "12");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.up) == "13");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.up) == "12");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.up) == "12");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.up) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.up) == "-11");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.up) == "-12");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.up) == "-11");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.up) == "-11");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.up) == "-11");

    assert(printFloat(buf[], 11.5f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], 12.5f, f, RoundingMode.down) == "12");
    assert(printFloat(buf[], 11.7f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], 11.3f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], 11.0f, f, RoundingMode.down) == "11");
    assert(printFloat(buf[], -11.5f, f, RoundingMode.down) == "-12");
    assert(printFloat(buf[], -12.5f, f, RoundingMode.down) == "-13");
    assert(printFloat(buf[], -11.7f, f, RoundingMode.down) == "-12");
    assert(printFloat(buf[], -11.3f, f, RoundingMode.down) == "-12");
    assert(printFloat(buf[], -11.0f, f, RoundingMode.down) == "-11");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';

    assert(printFloat(buf[], double.nan, f) == "nan");
    assert(printFloat(buf[], -double.nan, f) == "-nan");
    assert(printFloat(buf[], double.infinity, f) == "inf");
    assert(printFloat(buf[], -double.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0, f) == "0");
    assert(printFloat(buf[], -0.0, f) == "-0");

    // / 1000 needed due to https://issues.dlang.org/show_bug.cgi?id=20361
    assert(printFloat(buf[], 1e-307 / 1000, f) == "1e-310");
    assert(printFloat(buf[], -1e-307 / 1000, f) == "-1e-310");
    assert(printFloat(buf[], 1e-30, f) == "1e-30");
    assert(printFloat(buf[], -1e-30, f) == "-1e-30");
    assert(printFloat(buf[], 1e-10, f) == "1e-10");
    assert(printFloat(buf[], -1e-10, f) == "-1e-10");
    assert(printFloat(buf[], 0.1, f) == "0.1");
    assert(printFloat(buf[], -0.1, f) == "-0.1");
    assert(printFloat(buf[], 10.0, f) == "10");
    assert(printFloat(buf[], -10.0, f) == "-10");
    assert(printFloat(buf[], 1e300, f) == "1e+300");
    assert(printFloat(buf[], -1e300, f) == "-1e+300");

    import std.math : nextUp, nextDown;
    assert(printFloat(buf[], nextUp(0.0), f) == "4.94066e-324");
    assert(printFloat(buf[], nextDown(-0.0), f) == "-4.94066e-324");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';

    assert(printFloat(buf[], real.nan, f) == "nan");
    assert(printFloat(buf[], -real.nan, f) == "-nan");
    assert(printFloat(buf[], real.infinity, f) == "inf");
    assert(printFloat(buf[], -real.infinity, f) == "-inf");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';

    import std.math : nextUp;

    double eps = nextUp(0.0);
    f.precision = 1000;
    assert(printFloat(buf[], eps, f) ==
           "4.940656458412465441765687928682213723650598026143247644255856825006"
           ~ "755072702087518652998363616359923797965646954457177309266567103559"
           ~ "397963987747960107818781263007131903114045278458171678489821036887"
           ~ "186360569987307230500063874091535649843873124733972731696151400317"
           ~ "153853980741262385655911710266585566867681870395603106249319452715"
           ~ "914924553293054565444011274801297099995419319894090804165633245247"
           ~ "571478690147267801593552386115501348035264934720193790268107107491"
           ~ "703332226844753335720832431936092382893458368060106011506169809753"
           ~ "078342277318329247904982524730776375927247874656084778203734469699"
           ~ "533647017972677717585125660551199131504891101451037862738167250955"
           ~ "837389733598993664809941164205702637090279242767544565229087538682"
           ~ "506419718265533447265625e-324");

    f.precision = 50;
    assert(printFloat(buf[], double.max, f) ==
           "1.7976931348623157081452742373170435679807056752584e+308");
    assert(printFloat(buf[], double.epsilon, f) ==
           "2.220446049250313080847263336181640625e-16");

    f.precision = 10;
    assert(printFloat(buf[], 1.0/3.0, f) == "0.3333333333");
    assert(printFloat(buf[], 1.0/7.0, f) == "0.1428571429");
    assert(printFloat(buf[], 1.0/9.0, f) == "0.1111111111");
}

@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.precision = 15;

    import std.math : E, PI, PI_2, PI_4, M_1_PI, M_2_PI, M_2_SQRTPI,
                      LN10, LN2, LOG2, LOG2E, LOG2T, LOG10E, SQRT2, SQRT1_2;

    assert(printFloat(buf[], cast(double) E, f) == "2.71828182845905");
    assert(printFloat(buf[], cast(double) PI, f) == "3.14159265358979");
    assert(printFloat(buf[], cast(double) PI_2, f) == "1.5707963267949");
    assert(printFloat(buf[], cast(double) PI_4, f) == "0.785398163397448");
    assert(printFloat(buf[], cast(double) M_1_PI, f) == "0.318309886183791");
    assert(printFloat(buf[], cast(double) M_2_PI, f) == "0.636619772367581");
    assert(printFloat(buf[], cast(double) M_2_SQRTPI, f) == "1.12837916709551");
    assert(printFloat(buf[], cast(double) LN10, f) == "2.30258509299405");
    assert(printFloat(buf[], cast(double) LN2, f) == "0.693147180559945");
    assert(printFloat(buf[], cast(double) LOG2, f) == "0.301029995663981");
    assert(printFloat(buf[], cast(double) LOG2E, f) == "1.44269504088896");
    assert(printFloat(buf[], cast(double) LOG2T, f) == "3.32192809488736");
    assert(printFloat(buf[], cast(double) LOG10E, f) == "0.434294481903252");
    assert(printFloat(buf[], cast(double) SQRT2, f) == "1.4142135623731");
    assert(printFloat(buf[], cast(double) SQRT1_2, f) == "0.707106781186548");
}

// for 100% coverage
@safe unittest
{
    char[256] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'g';
    f.precision = 0;

    assert(printFloat(buf[], 0.009999, f) == "0.01");
}

private auto printFloat0(bool g, Char)(return char[] buf, FormatSpec!Char f, string sgn, bool is_upper)
{
    import std.algorithm.comparison : max;

    static if (g)
    {
        if (!f.flHash)
        {
            auto length = max(f.width, 1 + sgn.length);
            char[] result = length <= buf.length ? buf[0 .. length] : new char[length];
            result[] = '0';

            if (f.flDash)
            {
                if (sgn != "")
                    result[0] = sgn[0];
                result[1 + sgn.length .. $] = ' ';
            }
            else
            {
                if (f.flZero)
                {
                    if (sgn != "")
                        result[0] = sgn[0];
                }
                else
                {
                    if (sgn != "")
                        result[$ - 2] = sgn[0];
                    result[0 .. $ - 1 - sgn.length] = ' ';
                }
            }
            return result;
        }
    }

    // with e or E qualifier, we need 4 more bytes for E+00 at the end
    auto E = (f.spec == 'e' || f.spec == 'E') ? 4 : 0;

    auto length = f.precision + ((f.precision == 0 && !f.flHash) ? 1 : 2) + sgn.length + E;
    static if (g) length--;
    length = max(f.width, length);

    char[] result = length <= buf.length ? buf[0 .. length] : new char[length];
    result[] = '0';

    if (f.flDash)
    {
        if (sgn != "")
            result[0] = sgn[0];

        int dot_pos = cast(int) (sgn.length + 1);
        if (f.precision > 0 || f.flHash)
            result[dot_pos] = '.';

        auto exp_start = dot_pos + ((f.precision > 0 || f.flHash) ? 1 : 0) + f.precision;
        static if (g) exp_start--;
        if (exp_start + E < result.length)
            result[exp_start + E .. $] = ' ';

        if (E)
        {
            result[exp_start] = is_upper ? 'E' : 'e';
            result[exp_start + 1] = '+';
        }
    }
    else
    {
        int sign_pos = cast(int) (result.length - (E + 2));
        if (f.precision > 0 || f.flHash)
        {
            int dot_pos = cast(int) (result.length - f.precision);
            static if (!g) dot_pos -= E + 1;
            result[dot_pos] = '.';
            sign_pos = dot_pos - 2;
        }

        if (f.flZero)
            sign_pos = 0;
        else
        {
            static if (g)
                auto leading_spaces = sign_pos > 0 || sgn.length == 0;
            else
                auto leading_spaces = sign_pos > 0;

            if (leading_spaces)
                result[0 .. sign_pos + (sgn.length == 0 ? 1 : 0)] = ' ';
        }

        if (sgn != "")
            result[sign_pos] = sgn[0];

        if (E)
        {
            result[$ - 3] = '+';
            result[$ - 4] = is_upper ? 'E' : 'e';
        }
    }

    return result;
}

// check no allocations
@system unittest
{
    import core.memory;
    auto stats = GC.stats;

    char[512] buf;
    auto f = FormatSpec!dchar("");
    f.spec = 'a';
    assert(printFloat(buf[], float.nan, f) == "nan");
    assert(printFloat(buf[], -float.infinity, f) == "-inf");
    assert(printFloat(buf[], 0.0f, f) == "0x0p+0");

    assert(printFloat(buf[], -double.nan, f) == "-nan");
    assert(printFloat(buf[], double.infinity, f) == "inf");
    assert(printFloat(buf[], -0.0, f) == "-0x0p+0");

    import std.math : nextUp, E;

    assert(printFloat(buf[], nextUp(0.0f), f) == "0x0.000002p-126");
    assert(printFloat(buf[], cast(float) E, f) == "0x1.5bf0a8p+1");

    f.spec = 'E';
    f.precision = 80;
    assert(printFloat(buf[], 5.62776e+12f, f) ==
           "5.62775982080000000000000000000000000000000000000000000000000000000000000000000000E+12");

    f.precision = 6;
    assert(printFloat(buf[], -1.1418613e+07f, f) == "-1.141861E+07");

    f.precision = 20;
    assert(printFloat(buf[], double.max, f) == "1.79769313486231570815E+308");
    assert(printFloat(buf[], nextUp(0.0), f) == "4.94065645841246544177E-324");

    f.precision = 494;
    assert(printFloat(buf[], 1.0, f).length == 500);

    f.spec = 'f';
    f.precision = 15;
    assert(printFloat(buf[], cast(double) E, f) == "2.718281828459045");

    f.precision = 20;
    assert(printFloat(buf[], double.max, f).length == 330);
    assert(printFloat(buf[], nextUp(0.0), f) == "0.00000000000000000000");

    f.precision = 498;
    assert(printFloat(buf[], 1.0, f).length == 500);

    f.spec = 'g';
    f.precision = 15;
    assert(printFloat(buf[], cast(double) E, f) == "2.71828182845905");

    f.precision = 20;
    assert(printFloat(buf[], double.max, f) == "1.7976931348623157081e+308");
    assert(printFloat(buf[], nextUp(0.0), f) == "4.9406564584124654418e-324");

    f.flHash = true;
    f.precision = 499;
    assert(printFloat(buf[], 1.0, f).length == 500);

    assert(GC.stats.usedSize == stats.usedSize);
}

//////////////////////////////////////////////////////////////////

// version = printFloatTest;

version (printFloatTest)
{
    // Known bugs in snprintf:
    //
    // * 20396: Subnormal floats (but not doubles) are printed wrong with %a and %A
    //          Affected versions: CRuntime_Glibc, OSX, MinGW, CRuntime_Microsoft
    //          This difference is expected in 0.098% of all cases of the first test.
    //          Bit pattern of subnormals: x 00000000 xxxxxxxxxxxxxxxxxxxxxxx
    //
    // * 20288: Sometimes strange behaviour with NaNs and Infs; the test may even crash
    //          Affected versions: CRuntime_Microsoft
    //
    // * 20320 and 9889: Rounding problems with -m64 on win32 and %f and %F qualifier
    //                   Affected versions: CRuntime_Microsoft
    //
    // * 21641: In really rare circumstances (about 1 out of a billion) numbers formatted
    //          with %g are formatted wrong.

    // Change this, if you want to run the test for a different amount of time.
    // The duration is used for both tests, so the total duration is twice this duration.
    static duration = 15; // minutes

    @system unittest
    {
        import std.math : FloatingPointControl;
        import std.random : uniform, Random;
        import std.stdio : writefln, stderr;
        import std.datetime : MonoTime;
        import core.stdc.stdio : snprintf;
        import std.conv : to;

        FloatingPointControl fpctrl;

        auto math_rounding = [FloatingPointControl.roundDown, FloatingPointControl.roundUp,
                              FloatingPointControl.roundToZero, FloatingPointControl.roundToNearest];
        auto format_rounding = [RoundingMode.down, RoundingMode.up,
                                RoundingMode.toZero, RoundingMode.toNearestTiesToEven];
        auto string_rounding = ["down","up","toZero","toNearest"];

        writefln("testing printFloat with float values for %s minutes", duration);

        union A
        {
            float f;
            uint u;
        }

        uint seed = uniform(0,uint.max);
        writefln("using seed %s",seed);
        auto rnd = Random(seed);

        ulong checks = 0;
        ulong wrong = 0;
        long last_delta = -1;

        auto start = MonoTime.currTime;
        while (true)
        {
            auto delta = (MonoTime.currTime-start).total!"minutes";
            if (delta >= duration) break;
            if (delta > last_delta)
            {
                last_delta = delta;
                stderr.writef("%s / %s\r", delta, duration);
            }

            ++checks;

            A a;
            a.u = uniform!"[]"(0,uint.max,rnd);

            auto f = FormatSpec!dchar("");
            f.flDash = uniform(0,2,rnd)==0;
            f.flPlus = uniform(0,2,rnd)==0;
            f.flZero = uniform(0,2,rnd)==0;
            f.flSpace = uniform(0,2,rnd)==0;
            f.flHash = uniform(0,2,rnd)==0;
            f.width = uniform(0,200,rnd);
            f.precision = uniform(0,201,rnd);
            if (f.precision == 200) f.precision = f.UNSPECIFIED;
            f.spec = "aAeEfFgG"[uniform(0,8,rnd)];

            auto rounding = uniform(0,4,rnd);

            // old

            fpctrl.rounding = math_rounding[rounding];

            char[1 /*%*/ + 5 /*flags*/ + 3 /*width.prec*/ + 2 /*format*/
                 + 1 /*\0*/] sprintfSpec = void;
            sprintfSpec[0] = '%';
            uint i = 1;
            if (f.flDash) sprintfSpec[i++] = '-';
            if (f.flPlus) sprintfSpec[i++] = '+';
            if (f.flZero) sprintfSpec[i++] = '0';
            if (f.flSpace) sprintfSpec[i++] = ' ';
            if (f.flHash) sprintfSpec[i++] = '#';
            sprintfSpec[i .. i + 3] = "*.*";
            i += 3;
            sprintfSpec[i++] = f.spec;
            sprintfSpec[i] = 0;

            char[512] buf2 = void;
            immutable n = snprintf(buf2.ptr, buf2.length,
                                   sprintfSpec.ptr,
                                   f.width,
                                   // negative precision is same as no precision specified
                                   f.precision == f.UNSPECIFIED ? -1 : f.precision,
                                   a.f);

            auto old_value = buf2[0 .. n];

            // new

            char[512] buf = void;
            auto new_value = printFloat(buf[], a.f, f, format_rounding[rounding]);

            // compare

            if (new_value != old_value)
            {
                if (wrong == 0) // only report first miss
                {
                    import std.format : format;
                    auto tmp = format("%032b", a.u);
                    writefln("bitpattern: %s %s %s", tmp[0 .. 1], tmp[1 .. 9], tmp [9 .. $]);
                    writefln("spec: '%%%s%s%s%s%s%s%s%s'",
                             f.flDash ? "-" : "",
                             f.flPlus ? "+" : "",
                             f.flZero ? "0" : "",
                             f.flSpace ? " " : "",
                             f.flHash ? "#" : "",
                             f.width > 0 ? to!string(f.width) : "",
                             f.precision != f.UNSPECIFIED ? "."~to!string(f.precision) : "",
                             f.spec
                            );
                    writefln("rounding mode: %s",string_rounding[rounding]);
                    writefln("new: >%s<", new_value);
                    writefln("old: >%s<", old_value);
                }
                ++wrong;
            }
        }

        writefln("%s checks run, %s (%.2f%%) checks produced different results", checks, wrong, 100.0*wrong/checks);
    }

    @system unittest
    {
        import std.math : FloatingPointControl;
        import std.random : uniform, Random;
        import std.stdio : writefln, stderr;
        import std.datetime : MonoTime;
        import core.stdc.stdio : snprintf;
        import std.conv : to;

        FloatingPointControl fpctrl;

        auto math_rounding = [FloatingPointControl.roundDown, FloatingPointControl.roundUp,
                              FloatingPointControl.roundToZero, FloatingPointControl.roundToNearest];
        auto format_rounding = [RoundingMode.down, RoundingMode.up,
                                RoundingMode.toZero, RoundingMode.toNearestTiesToEven];
        auto string_rounding = ["down","up","toZero","toNearest"];

        writefln("testing printFloat with double values for %s minutes", duration);

        union A
        {
            double f;
            uint[2] u;
        }

        uint seed = uniform(0,uint.max);
        writefln("using seed %s",seed);
        auto rnd = Random(seed);

        ulong checks = 0;
        ulong wrong = 0;
        long last_delta = -1;

        auto start = MonoTime.currTime;
        while (true)
        {
            auto delta = (MonoTime.currTime-start).total!"minutes";
            if (delta >= duration) break;
            if (delta > last_delta)
            {
                last_delta = delta;
                stderr.writef("%s / %s\r", delta, duration);
            }

            ++checks;

            A a;
            a.u[0] = uniform!"[]"(0,uint.max,rnd);
            a.u[1] = uniform!"[]"(0,uint.max,rnd);

            auto f = FormatSpec!dchar("");
            f.flDash = uniform(0,2,rnd) == 0;
            f.flPlus = uniform(0,2,rnd) == 0;
            f.flZero = uniform(0,2,rnd) == 0;
            f.flSpace = uniform(0,2,rnd) == 0;
            f.flHash = uniform(0,2,rnd) == 0;
            f.width = uniform(0,200,rnd);
            f.precision = uniform(0,201,rnd);
            if (f.precision == 200) f.precision = f.UNSPECIFIED;
            f.spec = "aAeEfFgG"[uniform(0,8,rnd)];

            auto rounding = uniform(0,4,rnd);

            // old

            fpctrl.rounding = math_rounding[rounding];

            char[1 /*%*/ + 5 /*flags*/ + 3 /*width.prec*/ + 2 /*format*/
                 + 1 /*\0*/] sprintfSpec = void;
            sprintfSpec[0] = '%';
            uint i = 1;
            if (f.flDash) sprintfSpec[i++] = '-';
            if (f.flPlus) sprintfSpec[i++] = '+';
            if (f.flZero) sprintfSpec[i++] = '0';
            if (f.flSpace) sprintfSpec[i++] = ' ';
            if (f.flHash) sprintfSpec[i++] = '#';
            sprintfSpec[i .. i + 3] = "*.*";
            i += 3;
            sprintfSpec[i++] = f.spec;
            sprintfSpec[i] = 0;

            char[512] buf2 = void;
            immutable n = snprintf(buf2.ptr, buf2.length,
                                   sprintfSpec.ptr,
                                   f.width,
                                   // negative precision is same as no precision specified
                                   f.precision == f.UNSPECIFIED ? -1 : f.precision,
                                   a.f);

            auto old_value = buf2[0 .. n];

            // new

            char[512] buf = void;
            auto new_value = printFloat(buf[], a.f, f, format_rounding[rounding]);

            // compare

            if (new_value != old_value)
            {
                if (wrong == 0) // only report first miss
                {
                    import std.format : format;
                    auto tmp = format("%064b", a.u);
                    writefln("bitpattern: %s %s %s", tmp[0 .. 1], tmp[1 .. 11], tmp [11 .. $]);
                    writefln("spec: '%%%s%s%s%s%s%s%s%s'",
                             f.flDash ? "-" : "",
                             f.flPlus ? "+" : "",
                             f.flZero ? "0" : "",
                             f.flSpace ? " " : "",
                             f.flHash ? "#" : "",
                             f.width > 0 ? to!string(f.width) : "",
                             f.precision != f.UNSPECIFIED ? "."~to!string(f.precision) : "",
                             f.spec
                            );
                    writefln("rounding mode: %s",string_rounding[rounding]);
                    writefln("new: >%s<", new_value);
                    writefln("old: >%s<", old_value);
                }
                ++wrong;
            }
        }

        writefln("%s checks run, %s (%.2f%%) checks produced different results", checks, wrong, 100.0*wrong/checks);
    }
}
