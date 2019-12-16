// Written in the D programming language.

/* Contains elementary mathematical functions, and low-level
 * floating-point operations for processors with no asm support.
 *
 * All of these functions are subject to change, and are intended
 * for internal use only.
 *
 * Copyright: Copyright The D Language Foundation 2000 - 2011.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
 *            Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
 * Source: $(PHOBOSSRC std/internal/math/mathnoasm.d)
 */
module std.internal.math.mathnoasm;

static import core.math;
import std.math : floatTraits, RealFormat, PI, PI_4,
       isNaN, isInfinity, signbit, floor, poly;

/////////////////////////////////////////////////////////////////////////////

T tan(T)(T x) @safe pure nothrow @nogc
{
    // Coefficients for tan(x) and PI/4 split into three parts.
    enum realFormat = floatTraits!T.realFormat;
    static if (realFormat == RealFormat.ieeeQuadruple)
    {
        static immutable T[6] P = [
            2.883414728874239697964612246732416606301E10L,
            -2.307030822693734879744223131873392503321E9L,
            5.160188250214037865511600561074819366815E7L,
            -4.249691853501233575668486667664718192660E5L,
            1.272297782199996882828849455156962260810E3L,
            -9.889929415807650724957118893791829849557E-1L
        ];
        static immutable T[7] Q = [
            8.650244186622719093893836740197250197602E10L,
            -4.152206921457208101480801635640958361612E10L,
            2.758476078803232151774723646710890525496E9L,
            -5.733709132766856723608447733926138506824E7L,
            4.529422062441341616231663543669583527923E5L,
            -1.317243702830553658702531997959756728291E3L,
            1.0
        ];

        enum T P1 =
            7.853981633974483067550664827649598009884357452392578125E-1L;
        enum T P2 =
            2.8605943630549158983813312792950660807511260829685741796657E-18L;
        enum T P3 =
            2.1679525325309452561992610065108379921905808E-35L;
    }
    else static if (realFormat == RealFormat.ieeeExtended ||
                    realFormat == RealFormat.ieeeDouble)
    {
        static immutable T[3] P = [
           -1.7956525197648487798769E7L,
            1.1535166483858741613983E6L,
           -1.3093693918138377764608E4L,
        ];
        static immutable T[5] Q = [
           -5.3869575592945462988123E7L,
            2.5008380182335791583922E7L,
           -1.3208923444021096744731E6L,
            1.3681296347069295467845E4L,
            1.0000000000000000000000E0L,
        ];

        enum T P1 = 7.853981554508209228515625E-1L;
        enum T P2 = 7.946627356147928367136046290398E-9L;
        enum T P3 = 3.061616997868382943065164830688E-17L;
    }
    else static if (realFormat == RealFormat.ieeeSingle)
    {
        static immutable T[6] P = [
            3.33331568548E-1,
            1.33387994085E-1,
            5.34112807005E-2,
            2.44301354525E-2,
            3.11992232697E-3,
            9.38540185543E-3,
        ];

        enum T P1 = 0.78515625;
        enum T P2 = 2.4187564849853515625E-4;
        enum T P3 = 3.77489497744594108E-8;
    }
    else
        static assert(0, "no coefficients for tan()");

    // Special cases.
    if (x == cast(T) 0.0 || isNaN(x))
        return x;
    if (isInfinity(x))
        return T.nan;

    // Make argument positive but save the sign.
    bool sign = false;
    if (signbit(x))
    {
        sign = true;
        x = -x;
    }

    // Compute x mod PI/4.
    static if (realFormat == RealFormat.ieeeSingle)
    {
        enum T FOPI = 4 / PI;
        int j = cast(int) (FOPI * x);
        T y = j;
        T z;
    }
    else
    {
        T y = floor(x / cast(T) PI_4);
        // Strip high bits of integer part.
        enum T highBitsFactor = (realFormat == RealFormat.ieeeDouble ? 0x1p3 : 0x1p4);
        enum T highBitsInv = 1.0 / highBitsFactor;
        T z = y * highBitsInv;
        // Compute y - 2^numHighBits * (y / 2^numHighBits).
        z = y - highBitsFactor * floor(z);

        // Integer and fraction part modulo one octant.
        int j = cast(int)(z);
    }

    // Map zeros and singularities to origin.
    if (j & 1)
    {
        j += 1;
        y += cast(T) 1.0;
    }

    z = ((x - y * P1) - y * P2) - y * P3;
    const T zz = z * z;

    enum T zzThreshold = (realFormat == RealFormat.ieeeSingle ? 1.0e-4L :
                          realFormat == RealFormat.ieeeDouble ? 1.0e-14L : 1.0e-20L);
    if (zz > zzThreshold)
    {
        static if (realFormat == RealFormat.ieeeSingle)
            y = z + z * (zz * poly(zz, P));
        else
            y = z + z * (zz * poly(zz, P) / poly(zz, Q));
    }
    else
        y = z;

    if (j & 2)
        y = (cast(T) -1.0) / y;

    return (sign) ? -y : y;
}
