// Written in the D programming language.

/**
 * Contains the elementary mathematical functions (powers, roots,
 * and trigonometric functions), and low-level floating-point operations.
 * Mathematical special functions are available in `std.mathspecial`.
 *
$(SCRIPT inhibitQuickIndex = 1;)

$(DIVC quickindex,
$(BOOKTABLE ,
$(TR $(TH Category) $(TH Members) )
$(TR $(TDNW $(SUBMODULE Constants, constants)) $(TD
    $(SUBREF constants, E)
    $(SUBREF constants, PI)
    $(SUBREF constants, PI_2)
    $(SUBREF constants, PI_4)
    $(SUBREF constants, M_1_PI)
    $(SUBREF constants, M_2_PI)
    $(SUBREF constants, M_2_SQRTPI)
    $(SUBREF constants, LN10)
    $(SUBREF constants, LN2)
    $(SUBREF constants, LOG2)
    $(SUBREF constants, LOG2E)
    $(SUBREF constants, LOG2T)
    $(SUBREF constants, LOG10E)
    $(SUBREF constants, SQRT2)
    $(SUBREF constants, SQRT1_2)
))
$(TR $(TDNW $(SUBMODULE Algebraic, algebraic)) $(TD
    $(SUBREF algebraic, abs)
    $(SUBREF algebraic, fabs)
    $(SUBREF algebraic, sqrt)
    $(SUBREF algebraic, cbrt)
    $(SUBREF algebraic, hypot)
    $(SUBREF algebraic, poly)
    $(SUBREF algebraic, nextPow2)
    $(SUBREF algebraic, truncPow2)
))
$(TR $(TDNW $(SUBMODULE Trigonometry, trigonometry)) $(TD
    $(SUBREF trigonometry, sin)
    $(SUBREF trigonometry, cos)
    $(SUBREF trigonometry, tan)
    $(SUBREF trigonometry, asin)
    $(SUBREF trigonometry, acos)
    $(SUBREF trigonometry, atan)
    $(SUBREF trigonometry, atan2)
    $(SUBREF trigonometry, sinh)
    $(SUBREF trigonometry, cosh)
    $(SUBREF trigonometry, tanh)
    $(SUBREF trigonometry, asinh)
    $(SUBREF trigonometry, acosh)
    $(SUBREF trigonometry, atanh)
))
$(TR $(TDNW $(SUBMODULE Rounding, rounding)) $(TD
    $(SUBREF rounding, ceil)
    $(SUBREF rounding, floor)
    $(SUBREF rounding, round)
    $(SUBREF rounding, lround)
    $(SUBREF rounding, trunc)
    $(SUBREF rounding, rint)
    $(SUBREF rounding, lrint)
    $(SUBREF rounding, nearbyint)
    $(SUBREF rounding, rndtol)
    $(SUBREF rounding, quantize)
))
$(TR $(TDNW Exponentiation & Logarithms) $(TD
    $(SUBREF exponential, pow)
    $(MYREF exp) $(MYREF exp2) $(MYREF expm1) $(MYREF ldexp)
    $(MYREF frexp) $(MYREF log) $(MYREF log2) $(MYREF log10) $(MYREF logb)
    $(MYREF ilogb) $(MYREF log1p) $(MYREF scalbn)
))
$(TR $(TDNW $(SUBMODULE Remainder, remainder)) $(TD
    $(SUBREF remainder, fmod)
    $(SUBREF remainder, modf)
    $(SUBREF remainder, remainder)
    $(SUBREF remainder, remquo)
))
$(TR $(TDNW Floating-point operations) $(TD
    $(MYREF approxEqual) $(MYREF feqrel) $(MYREF fdim) $(MYREF fmax)
    $(MYREF fmin) $(MYREF fma) $(MYREF isClose) $(MYREF nextDown) $(MYREF nextUp)
    $(MYREF nextafter) $(MYREF NaN) $(MYREF getNaNPayload)
    $(MYREF cmp)
))
$(TR $(TDNW $(SUBMODULE Introspection, traits)) $(TD
    $(SUBREF traits, isFinite)
    $(SUBREF traits, isIdentical)
    $(SUBREF traits, isInfinity)
    $(SUBREF traits, isNaN)
    $(SUBREF traits, isNormal)
    $(SUBREF traits, isSubnormal)
    $(SUBREF traits, signbit)
    $(SUBREF traits, sgn)
    $(SUBREF traits, copysign)
    $(SUBREF traits, isPowerOf2)
))
$(TR $(TDNW Hardware Control) $(TD
    $(MYREF IeeeFlags) $(MYREF FloatingPointControl)
))
)
)

 * The functionality closely follows the IEEE754-2008 standard for
 * floating-point arithmetic, including the use of camelCase names rather
 * than C99-style lower case names. All of these functions behave correctly
 * when presented with an infinity or NaN.
 *
 * The following IEEE 'real' formats are currently supported:
 * $(UL
 * $(LI 64 bit Big-endian  'double' (eg PowerPC))
 * $(LI 128 bit Big-endian 'quadruple' (eg SPARC))
 * $(LI 64 bit Little-endian 'double' (eg x86-SSE2))
 * $(LI 80 bit Little-endian, with implied bit 'real80' (eg x87, Itanium))
 * $(LI 128 bit Little-endian 'quadruple' (not implemented on any known processor!))
 * $(LI Non-IEEE 128 bit Big-endian 'doubledouble' (eg PowerPC) has partial support)
 * )
 * Unlike C, there is no global 'errno' variable. Consequently, almost all of
 * these functions are pure nothrow.
 *
 * Macros:
 *      TABLE_SV = <table border="1" cellpadding="4" cellspacing="0">
 *              <caption>Special Values</caption>
 *              $0</table>
 *      SVH = $(TR $(TH $1) $(TH $2))
 *      SV  = $(TR $(TD $1) $(TD $2))
 *      TH3 = $(TR $(TH $1) $(TH $2) $(TH $3))
 *      TD3 = $(TR $(TD $1) $(TD $2) $(TD $3))
 *      TABLE_DOMRG = <table border="1" cellpadding="4" cellspacing="0">
 *              $(SVH Domain X, Range Y)
                $(SV $1, $2)
 *              </table>
 *      DOMAIN=$1
 *      RANGE=$1

 *      NAN = $(RED NAN)
 *      SUP = <span style="vertical-align:super;font-size:smaller">$0</span>
 *      GAMMA = &#915;
 *      THETA = &theta;
 *      INTEGRAL = &#8747;
 *      INTEGRATE = $(BIG &#8747;<sub>$(SMALL $1)</sub><sup>$2</sup>)
 *      POWER = $1<sup>$2</sup>
 *      SUB = $1<sub>$2</sub>
 *      BIGSUM = $(BIG &Sigma; <sup>$2</sup><sub>$(SMALL $1)</sub>)
 *      CHOOSE = $(BIG &#40;) <sup>$(SMALL $1)</sup><sub>$(SMALL $2)</sub> $(BIG &#41;)
 *      PLUSMN = &plusmn;
 *      INFIN = &infin;
 *      PLUSMNINF = &plusmn;&infin;
 *      PI = &pi;
 *      LT = &lt;
 *      GT = &gt;
 *      SQRT = &radic;
 *      HALF = &frac12;
 *
 *      SUBMODULE = $(MREF_ALTTEXT $1, std, math, $2)
 *      SUBREF = $(REF_ALTTEXT $(TT $2), $2, std, math, $1)$(NBSP)
 *
 * Copyright: Copyright The D Language Foundation 2000 - 2011.
 *            D implementations of tan, atan, atan2, exp, expm1, exp2, log, log10, log1p,
 *            log2, floor, ceil and lrint functions are based on the CEPHES math library,
 *            which is Copyright (C) 2001 Stephen L. Moshier $(LT)steve@moshier.net$(GT)
 *            and are incorporated herein by permission of the author.  The author
 *            reserves the right to distribute this material elsewhere under different
 *            copying permissions.  These modifications are distributed here under
 *            the following terms:
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
 *            Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
 * Source: $(PHOBOSSRC std/math/package.d)
 */
module std.math;

public import std.math.algebraic;
public import std.math.constants;
public import std.math.exponential;
public import std.math.floats;
public import std.math.hardware;
public import std.math.remainder;
public import std.math.rounding;
public import std.math.traits;
public import std.math.trigonometry;

static import core.math;
static import core.stdc.math;
static import core.stdc.fenv;
import std.traits :  CommonType, isFloatingPoint, isIntegral, isNumeric,
    isSigned, isUnsigned, Largest, Unqual;

// @@@DEPRECATED_2.102@@@
// Note: Exposed accidentally, should be deprecated / removed
deprecated("std.meta.AliasSeq was unintentionally available from std.math "
           ~ "and will be removed after 2.102. Please import std.meta instead")
public import std.meta : AliasSeq;

version (DigitalMars)
{
    version = INLINE_YL2X;        // x87 has opcodes for these
}

version (X86)       version = X86_Any;
version (X86_64)    version = X86_Any;
version (PPC)       version = PPC_Any;
version (PPC64)     version = PPC_Any;
version (MIPS32)    version = MIPS_Any;
version (MIPS64)    version = MIPS_Any;
version (AArch64)   version = ARM_Any;
version (ARM)       version = ARM_Any;
version (S390)      version = IBMZ_Any;
version (SPARC)     version = SPARC_Any;
version (SPARC64)   version = SPARC_Any;
version (SystemZ)   version = IBMZ_Any;
version (RISCV32)   version = RISCV_Any;
version (RISCV64)   version = RISCV_Any;

version (D_InlineAsm_X86)    version = InlineAsm_X86_Any;
version (D_InlineAsm_X86_64) version = InlineAsm_X86_Any;

version (InlineAsm_X86_Any) version = InlineAsm_X87;
version (InlineAsm_X87)
{
    static assert(real.mant_dig == 64);
    version (CRuntime_Microsoft) version = InlineAsm_X87_MSVC;
}

version (X86_64) version = StaticallyHaveSSE;
version (X86) version (OSX) version = StaticallyHaveSSE;

version (StaticallyHaveSSE)
{
    private enum bool haveSSE = true;
}
else version (X86)
{
    static import core.cpuid;
    private alias haveSSE = core.cpuid.sse;
}

version (D_SoftFloat)
{
    // Some soft float implementations may support IEEE floating flags.
    // The implementation here supports hardware flags only and is so currently
    // only available for supported targets.
}
else version (X86_Any)   version = IeeeFlagsSupport;
else version (PPC_Any)   version = IeeeFlagsSupport;
else version (RISCV_Any) version = IeeeFlagsSupport;
else version (MIPS_Any)  version = IeeeFlagsSupport;
else version (ARM_Any)   version = IeeeFlagsSupport;

// Struct FloatingPointControl is only available if hardware FP units are available.
version (D_HardFloat)
{
    // FloatingPointControl.clearExceptions() depends on version IeeeFlagsSupport
    version (IeeeFlagsSupport) version = FloatingPointControlSupport;
}

package(std.math)
{
    static if (real.sizeof > double.sizeof)
        enum uint useDigits = 16;
    else
        enum uint useDigits = 15;

    /******************************************
     * Compare floating point numbers to n decimal digits of precision.
     * Returns:
     *  1       match
     *  0       nomatch
     */

    package(std.math) bool equalsDigit(real x, real y, uint ndigits) @safe nothrow @nogc
    {
        import core.stdc.stdio : sprintf;

        if (signbit(x) != signbit(y))
            return 0;

        if (isInfinity(x) && isInfinity(y))
            return 1;
        if (isInfinity(x) || isInfinity(y))
            return 0;

        if (isNaN(x) && isNaN(y))
            return 1;
        if (isNaN(x) || isNaN(y))
            return 0;

        char[30] bufx;
        char[30] bufy;
        assert(ndigits < bufx.length);

        int ix;
        int iy;
        version (CRuntime_Microsoft)
            alias real_t = double;
        else
            alias real_t = real;

        () @trusted {
            ix = sprintf(bufx.ptr, is(real_t == real) ? "%.*Lg" : "%.*g", ndigits, cast(real_t) x);
            iy = sprintf(bufy.ptr, is(real_t == real) ? "%.*Lg" : "%.*g", ndigits, cast(real_t) y);
        } ();

        assert(ix < bufx.length && ix > 0);
        assert(ix < bufy.length && ix > 0);

        return bufx[0 .. ix] == bufy[0 .. iy];
    }
}

/**
 * Calculates e$(SUPERSCRIPT x).
 *
 *  $(TABLE_SV
 *    $(TR $(TH x)             $(TH e$(SUPERSCRIPT x)) )
 *    $(TR $(TD +$(INFIN))     $(TD +$(INFIN)) )
 *    $(TR $(TD -$(INFIN))     $(TD +0.0)      )
 *    $(TR $(TD $(NAN))        $(TD $(NAN))    )
 *  )
 */
pragma(inline, true)
real exp(real x) @trusted pure nothrow @nogc // TODO: @safe
{
    version (InlineAsm_X87)
    {
        //  e^^x = 2^^(LOG2E*x)
        // (This is valid because the overflow & underflow limits for exp
        // and exp2 are so similar).
        if (!__ctfe)
            return exp2Asm(LOG2E*x);
    }
    return expImpl(x);
}

/// ditto
pragma(inline, true)
double exp(double x) @safe pure nothrow @nogc { return __ctfe ? cast(double) exp(cast(real) x) : expImpl(x); }

/// ditto
pragma(inline, true)
float exp(float x) @safe pure nothrow @nogc { return __ctfe ? cast(float) exp(cast(real) x) : expImpl(x); }

///
@safe unittest
{
    assert(exp(0.0) == 1.0);
    assert(exp(3.0).feqrel(E * E * E) > 16);
}

private T expImpl(T)(T x) @safe pure nothrow @nogc
{
    alias F = floatTraits!T;
    static if (F.realFormat == RealFormat.ieeeSingle)
    {
        static immutable T[6] P = [
            5.0000001201E-1,
            1.6666665459E-1,
            4.1665795894E-2,
            8.3334519073E-3,
            1.3981999507E-3,
            1.9875691500E-4,
        ];

        enum T C1 = 0.693359375;
        enum T C2 = -2.12194440e-4;

        // Overflow and Underflow limits.
        enum T OF = 88.72283905206835;
        enum T UF = -103.278929903431851103; // ln(2^-149)
    }
    else static if (F.realFormat == RealFormat.ieeeDouble)
    {
        // Coefficients for exp(x)
        static immutable T[3] P = [
            9.99999999999999999910E-1L,
            3.02994407707441961300E-2L,
            1.26177193074810590878E-4L,
        ];
        static immutable T[4] Q = [
            2.00000000000000000009E0L,
            2.27265548208155028766E-1L,
            2.52448340349684104192E-3L,
            3.00198505138664455042E-6L,
        ];

        // C1 + C2 = LN2.
        enum T C1 = 6.93145751953125E-1;
        enum T C2 = 1.42860682030941723212E-6;

        // Overflow and Underflow limits.
        enum T OF =  7.09782712893383996732E2;  // ln((1-2^-53) * 2^1024)
        enum T UF = -7.451332191019412076235E2; // ln(2^-1075)
    }
    else static if (F.realFormat == RealFormat.ieeeExtended ||
                    F.realFormat == RealFormat.ieeeExtended53)
    {
        // Coefficients for exp(x)
        static immutable T[3] P = [
            9.9999999999999999991025E-1L,
            3.0299440770744196129956E-2L,
            1.2617719307481059087798E-4L,
        ];
        static immutable T[4] Q = [
            2.0000000000000000000897E0L,
            2.2726554820815502876593E-1L,
            2.5244834034968410419224E-3L,
            3.0019850513866445504159E-6L,
        ];

        // C1 + C2 = LN2.
        enum T C1 = 6.9314575195312500000000E-1L;
        enum T C2 = 1.4286068203094172321215E-6L;

        // Overflow and Underflow limits.
        enum T OF =  1.1356523406294143949492E4L;  // ln((1-2^-64) * 2^16384)
        enum T UF = -1.13994985314888605586758E4L; // ln(2^-16446)
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        // Coefficients for exp(x) - 1
        static immutable T[5] P = [
            9.999999999999999999999999999999999998502E-1L,
            3.508710990737834361215404761139478627390E-2L,
            2.708775201978218837374512615596512792224E-4L,
            6.141506007208645008909088812338454698548E-7L,
            3.279723985560247033712687707263393506266E-10L
        ];
        static immutable T[6] Q = [
            2.000000000000000000000000000000000000150E0,
            2.368408864814233538909747618894558968880E-1L,
            3.611828913847589925056132680618007270344E-3L,
            1.504792651814944826817779302637284053660E-5L,
            1.771372078166251484503904874657985291164E-8L,
            2.980756652081995192255342779918052538681E-12L
        ];

        // C1 + C2 = LN2.
        enum T C1 = 6.93145751953125E-1L;
        enum T C2 = 1.428606820309417232121458176568075500134E-6L;

        // Overflow and Underflow limits.
        enum T OF =  1.135583025911358400418251384584930671458833e4L;
        enum T UF = -1.143276959615573793352782661133116431383730e4L;
    }
    else
        static assert(0, "Not implemented for this architecture");

    // Special cases.
    if (isNaN(x))
        return x;
    if (x > OF)
        return real.infinity;
    if (x < UF)
        return 0.0;

    // Express: e^^x = e^^g * 2^^n
    //   = e^^g * e^^(n * LOG2E)
    //   = e^^(g + n * LOG2E)
    T xx = floor((cast(T) LOG2E) * x + cast(T) 0.5);
    const int n = cast(int) xx;
    x -= xx * C1;
    x -= xx * C2;

    static if (F.realFormat == RealFormat.ieeeSingle)
    {
        xx = x * x;
        x = poly(x, P) * xx + x + 1.0f;
    }
    else
    {
        // Rational approximation for exponential of the fractional part:
        //  e^^x = 1 + 2x P(x^^2) / (Q(x^^2) - P(x^^2))
        xx = x * x;
        const T px = x * poly(xx, P);
        x = px / (poly(xx, Q) - px);
        x = (cast(T) 1.0) + (cast(T) 2.0) * x;
    }

    // Scale by power of 2.
    x = ldexp(x, n);

    return x;
}

@safe @nogc nothrow unittest
{
    version (FloatingPointControlSupport)
    {
        FloatingPointControl ctrl;
        if (FloatingPointControl.hasExceptionTraps)
            ctrl.disableExceptions(FloatingPointControl.allExceptions);
        ctrl.rounding = FloatingPointControl.roundToNearest;
    }

    static void testExp(T)()
    {
        enum realFormat = floatTraits!T.realFormat;
        static if (realFormat == RealFormat.ieeeQuadruple)
        {
            static immutable T[2][] exptestpoints =
            [ //  x               exp(x)
                [ 1.0L,           E                                        ],
                [ 0.5L,           0x1.a61298e1e069bc972dfefab6df34p+0L     ],
                [ 3.0L,           E*E*E                                    ],
                [ 0x1.6p+13L,     0x1.6e509d45728655cdb4840542acb5p+16250L ], // near overflow
                [ 0x1.7p+13L,     T.infinity                               ], // close overflow
                [ 0x1p+80L,       T.infinity                               ], // far overflow
                [ T.infinity,     T.infinity                               ],
                [-0x1.18p+13L,    0x1.5e4bf54b4807034ea97fef0059a6p-12927L ], // near underflow
                [-0x1.625p+13L,   0x1.a6bd68a39d11fec3a250cd97f524p-16358L ], // ditto
                [-0x1.62dafp+13L, 0x0.cb629e9813b80ed4d639e875be6cp-16382L ], // near underflow - subnormal
                [-0x1.6549p+13L,  0x0.0000000000000000000000000001p-16382L ], // ditto
                [-0x1.655p+13L,   0                                        ], // close underflow
                [-0x1p+30L,       0                                        ], // far underflow
            ];
        }
        else static if (realFormat == RealFormat.ieeeExtended ||
                        realFormat == RealFormat.ieeeExtended53)
        {
            static immutable T[2][] exptestpoints =
            [ //  x               exp(x)
                [ 1.0L,           E                            ],
                [ 0.5L,           0x1.a61298e1e069bc97p+0L     ],
                [ 3.0L,           E*E*E                        ],
                [ 0x1.1p+13L,     0x1.29aeffefc8ec645p+12557L  ], // near overflow
                [ 0x1.7p+13L,     T.infinity                   ], // close overflow
                [ 0x1p+80L,       T.infinity                   ], // far overflow
                [ T.infinity,     T.infinity                   ],
                [-0x1.18p+13L,    0x1.5e4bf54b4806db9p-12927L  ], // near underflow
                [-0x1.625p+13L,   0x1.a6bd68a39d11f35cp-16358L ], // ditto
                [-0x1.62dafp+13L, 0x1.96c53d30277021dp-16383L  ], // near underflow - subnormal
                [-0x1.643p+13L,   0x1p-16444L                  ], // ditto
                [-0x1.645p+13L,   0                            ], // close underflow
                [-0x1p+30L,       0                            ], // far underflow
            ];
        }
        else static if (realFormat == RealFormat.ieeeDouble)
        {
            static immutable T[2][] exptestpoints =
            [ //  x,             exp(x)
                [ 1.0L,          E                        ],
                [ 0.5L,          0x1.a61298e1e069cp+0L    ],
                [ 3.0L,          E*E*E                    ],
                [ 0x1.6p+9L,     0x1.93bf4ec282efbp+1015L ], // near overflow
                [ 0x1.7p+9L,     T.infinity               ], // close overflow
                [ 0x1p+80L,      T.infinity               ], // far overflow
                [ T.infinity,    T.infinity               ],
                [-0x1.6p+9L,     0x1.44a3824e5285fp-1016L ], // near underflow
                [-0x1.64p+9L,    0x0.06f84920bb2d4p-1022L ], // near underflow - subnormal
                [-0x1.743p+9L,   0x0.0000000000001p-1022L ], // ditto
                [-0x1.8p+9L,     0                        ], // close underflow
                [-0x1p+30L,      0                        ], // far underflow
            ];
        }
        else static if (realFormat == RealFormat.ieeeSingle)
        {
            static immutable T[2][] exptestpoints =
            [ //  x,             exp(x)
                [ 1.0L,          E                ],
                [ 0.5L,          0x1.a61299p+0L   ],
                [ 3.0L,          E*E*E            ],
                [ 0x1.62p+6L,    0x1.99b988p+127L ], // near overflow
                [ 0x1.7p+6L,     T.infinity       ], // close overflow
                [ 0x1p+80L,      T.infinity       ], // far overflow
                [ T.infinity,    T.infinity       ],
                [-0x1.5cp+6L,    0x1.666d0ep-126L ], // near underflow
                [-0x1.7p+6L,     0x0.026a42p-126L ], // near underflow - subnormal
                [-0x1.9cp+6L,    0x0.000002p-126L ], // ditto
                [-0x1.ap+6L,     0                ], // close underflow
                [-0x1p+30L,      0                ], // far underflow
            ];
        }
        else
            static assert(0, "No exp() tests for real type!");

        const minEqualMantissaBits = T.mant_dig - 2;
        T x;
        version (IeeeFlagsSupport) IeeeFlags f;
        foreach (ref pair; exptestpoints)
        {
            version (IeeeFlagsSupport) resetIeeeFlags();
            x = exp(pair[0]);
            //printf("exp(%La) = %La, should be %La\n", cast(real) pair[0], cast(real) x, cast(real) pair[1]);
            assert(feqrel(x, pair[1]) >= minEqualMantissaBits);
        }

        // Ideally, exp(0) would not set the inexact flag.
        // Unfortunately, fldl2e sets it!
        // So it's not realistic to avoid setting it.
        assert(exp(cast(T) 0.0) == 1.0);

        // NaN propagation. Doesn't set flags, bcos was already NaN.
        version (IeeeFlagsSupport)
        {
            resetIeeeFlags();
            x = exp(T.nan);
            f = ieeeFlags;
            assert(isIdentical(abs(x), T.nan));
            assert(f.flags == 0);

            resetIeeeFlags();
            x = exp(-T.nan);
            f = ieeeFlags;
            assert(isIdentical(abs(x), T.nan));
            assert(f.flags == 0);
        }
        else
        {
            x = exp(T.nan);
            assert(isIdentical(abs(x), T.nan));

            x = exp(-T.nan);
            assert(isIdentical(abs(x), T.nan));
        }

        x = exp(NaN(0x123));
        assert(isIdentical(x, NaN(0x123)));
    }

    import std.meta : AliasSeq;
    foreach (T; AliasSeq!(real, double, float))
        testExp!T();

    // High resolution test (verified against GNU MPFR/Mathematica).
    assert(exp(0.5L) == 0x1.A612_98E1_E069_BC97_2DFE_FAB6_DF34p+0L);

    assert(equalsDigit(exp(3.0L), E * E * E, useDigits));
}

/**
 * Calculates the value of the natural logarithm base (e)
 * raised to the power of x, minus 1.
 *
 * For very small x, expm1(x) is more accurate
 * than exp(x)-1.
 *
 *  $(TABLE_SV
 *    $(TR $(TH x)             $(TH e$(SUPERSCRIPT x)-1)  )
 *    $(TR $(TD $(PLUSMN)0.0)  $(TD $(PLUSMN)0.0) )
 *    $(TR $(TD +$(INFIN))     $(TD +$(INFIN))    )
 *    $(TR $(TD -$(INFIN))     $(TD -1.0)         )
 *    $(TR $(TD $(NAN))        $(TD $(NAN))       )
 *  )
 */
pragma(inline, true)
real expm1(real x) @trusted pure nothrow @nogc // TODO: @safe
{
    version (InlineAsm_X87)
    {
        if (!__ctfe)
            return expm1Asm(x);
    }
    return expm1Impl(x);
}

/// ditto
pragma(inline, true)
double expm1(double x) @safe pure nothrow @nogc
{
    return __ctfe ? cast(double) expm1(cast(real) x) : expm1Impl(x);
}

/// ditto
pragma(inline, true)
float expm1(float x) @safe pure nothrow @nogc
{
    // no single-precision version in Cephes => use double precision
    return __ctfe ? cast(float) expm1(cast(real) x) : cast(float) expm1Impl(cast(double) x);
}

///
@safe unittest
{
    assert(isIdentical(expm1(0.0), 0.0));
    assert(expm1(1.0).feqrel(1.71828) > 16);
    assert(expm1(2.0).feqrel(6.3890) > 16);
}

version (InlineAsm_X87)
private real expm1Asm(real x) @trusted pure nothrow @nogc
{
    version (X86)
    {
        enum PARAMSIZE = (real.sizeof+3)&(0xFFFF_FFFC); // always a multiple of 4
        asm pure nothrow @nogc
        {
            /*  expm1() for x87 80-bit reals, IEEE754-2008 conformant.
             * Author: Don Clugston.
             *
             *    expm1(x) = 2^^(rndint(y))* 2^^(y-rndint(y)) - 1 where y = LN2*x.
             *    = 2rndy * 2ym1 + 2rndy - 1, where 2rndy = 2^^(rndint(y))
             *     and 2ym1 = (2^^(y-rndint(y))-1).
             *    If 2rndy  < 0.5*real.epsilon, result is -1.
             *    Implementation is otherwise the same as for exp2()
             */
            naked;
            fld real ptr [ESP+4] ; // x
            mov AX, [ESP+4+8]; // AX = exponent and sign
            sub ESP, 12+8; // Create scratch space on the stack
            // [ESP,ESP+2] = scratchint
            // [ESP+4..+6, +8..+10, +10] = scratchreal
            // set scratchreal mantissa = 1.0
            mov dword ptr [ESP+8], 0;
            mov dword ptr [ESP+8+4], 0x80000000;
            and AX, 0x7FFF; // drop sign bit
            cmp AX, 0x401D; // avoid InvalidException in fist
            jae L_extreme;
            fldl2e;
            fmulp ST(1), ST; // y = x*log2(e)
            fist dword ptr [ESP]; // scratchint = rndint(y)
            fisub dword ptr [ESP]; // y - rndint(y)
            // and now set scratchreal exponent
            mov EAX, [ESP];
            add EAX, 0x3fff;
            jle short L_largenegative;
            cmp EAX,0x8000;
            jge short L_largepositive;
            mov [ESP+8+8],AX;
            f2xm1; // 2ym1 = 2^^(y-rndint(y)) -1
            fld real ptr [ESP+8] ; // 2rndy = 2^^rndint(y)
            fmul ST(1), ST;  // ST=2rndy, ST(1)=2rndy*2ym1
            fld1;
            fsubp ST(1), ST; // ST = 2rndy-1, ST(1) = 2rndy * 2ym1 - 1
            faddp ST(1), ST; // ST = 2rndy * 2ym1 + 2rndy - 1
            add ESP,12+8;
            ret PARAMSIZE;

L_extreme:  // Extreme exponent. X is very large positive, very
            // large negative, infinity, or NaN.
            fxam;
            fstsw AX;
            test AX, 0x0400; // NaN_or_zero, but we already know x != 0
            jz L_was_nan;  // if x is NaN, returns x
            test AX, 0x0200;
            jnz L_largenegative;
L_largepositive:
            // Set scratchreal = real.max.
            // squaring it will create infinity, and set overflow flag.
            mov word  ptr [ESP+8+8], 0x7FFE;
            fstp ST(0);
            fld real ptr [ESP+8];  // load scratchreal
            fmul ST(0), ST;        // square it, to create havoc!
L_was_nan:
            add ESP,12+8;
            ret PARAMSIZE;
L_largenegative:
            fstp ST(0);
            fld1;
            fchs; // return -1. Underflow flag is not set.
            add ESP,12+8;
            ret PARAMSIZE;
        }
    }
    else version (X86_64)
    {
        asm pure nothrow @nogc
        {
            naked;
        }
        version (Win64)
        {
            asm pure nothrow @nogc
            {
                fld   real ptr [RCX];  // x
                mov   AX,[RCX+8];      // AX = exponent and sign
            }
        }
        else
        {
            asm pure nothrow @nogc
            {
                fld   real ptr [RSP+8];  // x
                mov   AX,[RSP+8+8];      // AX = exponent and sign
            }
        }
        asm pure nothrow @nogc
        {
            /*  expm1() for x87 80-bit reals, IEEE754-2008 conformant.
             * Author: Don Clugston.
             *
             *    expm1(x) = 2^(rndint(y))* 2^(y-rndint(y)) - 1 where y = LN2*x.
             *    = 2rndy * 2ym1 + 2rndy - 1, where 2rndy = 2^(rndint(y))
             *     and 2ym1 = (2^(y-rndint(y))-1).
             *    If 2rndy  < 0.5*real.epsilon, result is -1.
             *    Implementation is otherwise the same as for exp2()
             */
            sub RSP, 24;       // Create scratch space on the stack
            // [RSP,RSP+2] = scratchint
            // [RSP+4..+6, +8..+10, +10] = scratchreal
            // set scratchreal mantissa = 1.0
            mov dword ptr [RSP+8], 0;
            mov dword ptr [RSP+8+4], 0x80000000;
            and AX, 0x7FFF; // drop sign bit
            cmp AX, 0x401D; // avoid InvalidException in fist
            jae L_extreme;
            fldl2e;
            fmul ; // y = x*log2(e)
            fist dword ptr [RSP]; // scratchint = rndint(y)
            fisub dword ptr [RSP]; // y - rndint(y)
            // and now set scratchreal exponent
            mov EAX, [RSP];
            add EAX, 0x3fff;
            jle short L_largenegative;
            cmp EAX,0x8000;
            jge short L_largepositive;
            mov [RSP+8+8],AX;
            f2xm1; // 2^(y-rndint(y)) -1
            fld real ptr [RSP+8] ; // 2^rndint(y)
            fmul ST(1), ST;
            fld1;
            fsubp ST(1), ST;
            fadd;
            add RSP,24;
            ret;

L_extreme:  // Extreme exponent. X is very large positive, very
            // large negative, infinity, or NaN.
            fxam;
            fstsw AX;
            test AX, 0x0400; // NaN_or_zero, but we already know x != 0
            jz L_was_nan;  // if x is NaN, returns x
            test AX, 0x0200;
            jnz L_largenegative;
L_largepositive:
            // Set scratchreal = real.max.
            // squaring it will create infinity, and set overflow flag.
            mov word  ptr [RSP+8+8], 0x7FFE;
            fstp ST(0);
            fld real ptr [RSP+8];  // load scratchreal
            fmul ST(0), ST;        // square it, to create havoc!
L_was_nan:
            add RSP,24;
            ret;

L_largenegative:
            fstp ST(0);
            fld1;
            fchs; // return -1. Underflow flag is not set.
            add RSP,24;
            ret;
        }
    }
    else
        static assert(0);
}

private T expm1Impl(T)(T x) @safe pure nothrow @nogc
{
    // Coefficients for exp(x) - 1 and overflow/underflow limits.
    enum realFormat = floatTraits!T.realFormat;
    static if (realFormat == RealFormat.ieeeQuadruple)
    {
        static immutable T[8] P = [
            2.943520915569954073888921213330863757240E8L,
            -5.722847283900608941516165725053359168840E7L,
            8.944630806357575461578107295909719817253E6L,
            -7.212432713558031519943281748462837065308E5L,
            4.578962475841642634225390068461943438441E4L,
            -1.716772506388927649032068540558788106762E3L,
            4.401308817383362136048032038528753151144E1L,
            -4.888737542888633647784737721812546636240E-1L
        ];

        static immutable T[9] Q = [
            1.766112549341972444333352727998584753865E9L,
            -7.848989743695296475743081255027098295771E8L,
            1.615869009634292424463780387327037251069E8L,
            -2.019684072836541751428967854947019415698E7L,
            1.682912729190313538934190635536631941751E6L,
            -9.615511549171441430850103489315371768998E4L,
            3.697714952261803935521187272204485251835E3L,
            -8.802340681794263968892934703309274564037E1L,
            1.0
        ];

        enum T OF = 1.1356523406294143949491931077970764891253E4L;
        enum T UF = -1.143276959615573793352782661133116431383730e4L;
    }
    else static if (realFormat == RealFormat.ieeeExtended)
    {
        static immutable T[5] P = [
           -1.586135578666346600772998894928250240826E4L,
            2.642771505685952966904660652518429479531E3L,
           -3.423199068835684263987132888286791620673E2L,
            1.800826371455042224581246202420972737840E1L,
           -5.238523121205561042771939008061958820811E-1L,
        ];
        static immutable T[6] Q = [
           -9.516813471998079611319047060563358064497E4L,
            3.964866271411091674556850458227710004570E4L,
           -7.207678383830091850230366618190187434796E3L,
            7.206038318724600171970199625081491823079E2L,
           -4.002027679107076077238836622982900945173E1L,
            1.0
        ];

        enum T OF =  1.1356523406294143949492E4L;
        enum T UF = -4.5054566736396445112120088E1L;
    }
    else static if (realFormat == RealFormat.ieeeDouble)
    {
        static immutable T[3] P = [
            9.9999999999999999991025E-1,
            3.0299440770744196129956E-2,
            1.2617719307481059087798E-4,
        ];
        static immutable T[4] Q = [
            2.0000000000000000000897E0,
            2.2726554820815502876593E-1,
            2.5244834034968410419224E-3,
            3.0019850513866445504159E-6,
        ];
    }
    else
        static assert(0, "no coefficients for expm1()");

    static if (realFormat == RealFormat.ieeeDouble) // special case for double precision
    {
        if (x < -0.5 || x > 0.5)
            return exp(x) - 1.0;
        if (x == 0.0)
            return x;

        const T xx = x * x;
        x = x * poly(xx, P);
        x = x / (poly(xx, Q) - x);
        return x + x;
    }
    else
    {
        // C1 + C2 = LN2.
        enum T C1 = 6.9314575195312500000000E-1L;
        enum T C2 = 1.428606820309417232121458176568075500134E-6L;

        // Special cases.
        if (x > OF)
            return real.infinity;
        if (x == cast(T) 0.0)
            return x;
        if (x < UF)
            return -1.0;

        // Express x = LN2 (n + remainder), remainder not exceeding 1/2.
        int n = cast(int) floor((cast(T) 0.5) + x / cast(T) LN2);
        x -= n * C1;
        x -= n * C2;

        // Rational approximation:
        //  exp(x) - 1 = x + 0.5 x^^2 + x^^3 P(x) / Q(x)
        T px = x * poly(x, P);
        T qx = poly(x, Q);
        const T xx = x * x;
        qx = x + ((cast(T) 0.5) * xx + xx * px / qx);

        // We have qx = exp(remainder LN2) - 1, so:
        //  exp(x) - 1 = 2^^n (qx + 1) - 1 = 2^^n qx + 2^^n - 1.
        px = ldexp(cast(T) 1.0, n);
        x = px * qx + (px - cast(T) 1.0);

        return x;
    }
}

@safe @nogc nothrow unittest
{
    static void testExpm1(T)()
    {
        // NaN
        assert(isNaN(expm1(cast(T) T.nan)));

        static immutable T[] xs = [ -2, -0.75, -0.3, 0.0, 0.1, 0.2, 0.5, 1.0 ];
        foreach (x; xs)
        {
            const T e = expm1(x);
            const T r = exp(x) - 1;

            //printf("expm1(%Lg) = %Lg, should approximately be %Lg\n", cast(real) x, cast(real) e, cast(real) r);
            assert(isClose(r, e, CommonDefaultFor!(T,T), CommonDefaultFor!(T,T)));
        }
    }

    import std.meta : AliasSeq;
    foreach (T; AliasSeq!(real, double))
        testExpm1!T();
}

/**
 * Calculates 2$(SUPERSCRIPT x).
 *
 *  $(TABLE_SV
 *    $(TR $(TH x)             $(TH exp2(x))   )
 *    $(TR $(TD +$(INFIN))     $(TD +$(INFIN)) )
 *    $(TR $(TD -$(INFIN))     $(TD +0.0)      )
 *    $(TR $(TD $(NAN))        $(TD $(NAN))    )
 *  )
 */
pragma(inline, true)
real exp2(real x) @nogc @trusted pure nothrow // TODO: @safe
{
    version (InlineAsm_X87)
    {
        if (!__ctfe)
            return exp2Asm(x);
    }
    return exp2Impl(x);
}

/// ditto
pragma(inline, true)
double exp2(double x) @nogc @safe pure nothrow { return __ctfe ? cast(double) exp2(cast(real) x) : exp2Impl(x); }

/// ditto
pragma(inline, true)
float exp2(float x) @nogc @safe pure nothrow { return __ctfe ? cast(float) exp2(cast(real) x) : exp2Impl(x); }

///
@safe unittest
{
    assert(isIdentical(exp2(0.0), 1.0));
    assert(exp2(2.0).feqrel(4.0) > 16);
    assert(exp2(8.0).feqrel(256.0) > 16);
}

@safe unittest
{
    version (CRuntime_Microsoft) {} else // aexp2/exp2f/exp2l not implemented
    {
        assert( core.stdc.math.exp2f(0.0f) == 1 );
        assert( core.stdc.math.exp2 (0.0)  == 1 );
        assert( core.stdc.math.exp2l(0.0L) == 1 );
    }
}

version (InlineAsm_X87)
private real exp2Asm(real x) @nogc @trusted pure nothrow
{
    version (X86)
    {
        enum PARAMSIZE = (real.sizeof+3)&(0xFFFF_FFFC); // always a multiple of 4

        asm pure nothrow @nogc
        {
            /*  exp2() for x87 80-bit reals, IEEE754-2008 conformant.
             * Author: Don Clugston.
             *
             * exp2(x) = 2^^(rndint(x))* 2^^(y-rndint(x))
             * The trick for high performance is to avoid the fscale(28cycles on core2),
             * frndint(19 cycles), leaving f2xm1(19 cycles) as the only slow instruction.
             *
             * We can do frndint by using fist. BUT we can't use it for huge numbers,
             * because it will set the Invalid Operation flag if overflow or NaN occurs.
             * Fortunately, whenever this happens the result would be zero or infinity.
             *
             * We can perform fscale by directly poking into the exponent. BUT this doesn't
             * work for the (very rare) cases where the result is subnormal. So we fall back
             * to the slow method in that case.
             */
            naked;
            fld real ptr [ESP+4] ; // x
            mov AX, [ESP+4+8]; // AX = exponent and sign
            sub ESP, 12+8; // Create scratch space on the stack
            // [ESP,ESP+2] = scratchint
            // [ESP+4..+6, +8..+10, +10] = scratchreal
            // set scratchreal mantissa = 1.0
            mov dword ptr [ESP+8], 0;
            mov dword ptr [ESP+8+4], 0x80000000;
            and AX, 0x7FFF; // drop sign bit
            cmp AX, 0x401D; // avoid InvalidException in fist
            jae L_extreme;
            fist dword ptr [ESP]; // scratchint = rndint(x)
            fisub dword ptr [ESP]; // x - rndint(x)
            // and now set scratchreal exponent
            mov EAX, [ESP];
            add EAX, 0x3fff;
            jle short L_subnormal;
            cmp EAX,0x8000;
            jge short L_overflow;
            mov [ESP+8+8],AX;
L_normal:
            f2xm1;
            fld1;
            faddp ST(1), ST; // 2^^(x-rndint(x))
            fld real ptr [ESP+8] ; // 2^^rndint(x)
            add ESP,12+8;
            fmulp ST(1), ST;
            ret PARAMSIZE;

L_subnormal:
            // Result will be subnormal.
            // In this rare case, the simple poking method doesn't work.
            // The speed doesn't matter, so use the slow fscale method.
            fild dword ptr [ESP];  // scratchint
            fld1;
            fscale;
            fstp real ptr [ESP+8]; // scratchreal = 2^^scratchint
            fstp ST(0);         // drop scratchint
            jmp L_normal;

L_extreme:  // Extreme exponent. X is very large positive, very
            // large negative, infinity, or NaN.
            fxam;
            fstsw AX;
            test AX, 0x0400; // NaN_or_zero, but we already know x != 0
            jz L_was_nan;  // if x is NaN, returns x
            // set scratchreal = real.min_normal
            // squaring it will return 0, setting underflow flag
            mov word  ptr [ESP+8+8], 1;
            test AX, 0x0200;
            jnz L_waslargenegative;
L_overflow:
            // Set scratchreal = real.max.
            // squaring it will create infinity, and set overflow flag.
            mov word  ptr [ESP+8+8], 0x7FFE;
L_waslargenegative:
            fstp ST(0);
            fld real ptr [ESP+8];  // load scratchreal
            fmul ST(0), ST;        // square it, to create havoc!
L_was_nan:
            add ESP,12+8;
            ret PARAMSIZE;
        }
    }
    else version (X86_64)
    {
        asm pure nothrow @nogc
        {
            naked;
        }
        version (Win64)
        {
            asm pure nothrow @nogc
            {
                fld   real ptr [RCX];  // x
                mov   AX,[RCX+8];      // AX = exponent and sign
            }
        }
        else
        {
            asm pure nothrow @nogc
            {
                fld   real ptr [RSP+8];  // x
                mov   AX,[RSP+8+8];      // AX = exponent and sign
            }
        }
        asm pure nothrow @nogc
        {
            /*  exp2() for x87 80-bit reals, IEEE754-2008 conformant.
             * Author: Don Clugston.
             *
             * exp2(x) = 2^(rndint(x))* 2^(y-rndint(x))
             * The trick for high performance is to avoid the fscale(28cycles on core2),
             * frndint(19 cycles), leaving f2xm1(19 cycles) as the only slow instruction.
             *
             * We can do frndint by using fist. BUT we can't use it for huge numbers,
             * because it will set the Invalid Operation flag is overflow or NaN occurs.
             * Fortunately, whenever this happens the result would be zero or infinity.
             *
             * We can perform fscale by directly poking into the exponent. BUT this doesn't
             * work for the (very rare) cases where the result is subnormal. So we fall back
             * to the slow method in that case.
             */
            sub RSP, 24; // Create scratch space on the stack
            // [RSP,RSP+2] = scratchint
            // [RSP+4..+6, +8..+10, +10] = scratchreal
            // set scratchreal mantissa = 1.0
            mov dword ptr [RSP+8], 0;
            mov dword ptr [RSP+8+4], 0x80000000;
            and AX, 0x7FFF; // drop sign bit
            cmp AX, 0x401D; // avoid InvalidException in fist
            jae L_extreme;
            fist dword ptr [RSP]; // scratchint = rndint(x)
            fisub dword ptr [RSP]; // x - rndint(x)
            // and now set scratchreal exponent
            mov EAX, [RSP];
            add EAX, 0x3fff;
            jle short L_subnormal;
            cmp EAX,0x8000;
            jge short L_overflow;
            mov [RSP+8+8],AX;
L_normal:
            f2xm1;
            fld1;
            fadd; // 2^(x-rndint(x))
            fld real ptr [RSP+8] ; // 2^rndint(x)
            add RSP,24;
            fmulp ST(1), ST;
            ret;

L_subnormal:
            // Result will be subnormal.
            // In this rare case, the simple poking method doesn't work.
            // The speed doesn't matter, so use the slow fscale method.
            fild dword ptr [RSP];  // scratchint
            fld1;
            fscale;
            fstp real ptr [RSP+8]; // scratchreal = 2^scratchint
            fstp ST(0);         // drop scratchint
            jmp L_normal;

L_extreme:  // Extreme exponent. X is very large positive, very
            // large negative, infinity, or NaN.
            fxam;
            fstsw AX;
            test AX, 0x0400; // NaN_or_zero, but we already know x != 0
            jz L_was_nan;  // if x is NaN, returns x
            // set scratchreal = real.min
            // squaring it will return 0, setting underflow flag
            mov word  ptr [RSP+8+8], 1;
            test AX, 0x0200;
            jnz L_waslargenegative;
L_overflow:
            // Set scratchreal = real.max.
            // squaring it will create infinity, and set overflow flag.
            mov word  ptr [RSP+8+8], 0x7FFE;
L_waslargenegative:
            fstp ST(0);
            fld real ptr [RSP+8];  // load scratchreal
            fmul ST(0), ST;        // square it, to create havoc!
L_was_nan:
            add RSP,24;
            ret;
        }
    }
    else
        static assert(0);
}

private T exp2Impl(T)(T x) @nogc @safe pure nothrow
{
    // Coefficients for exp2(x)
    enum realFormat = floatTraits!T.realFormat;
    static if (realFormat == RealFormat.ieeeQuadruple)
    {
        static immutable T[5] P = [
            9.079594442980146270952372234833529694788E12L,
            1.530625323728429161131811299626419117557E11L,
            5.677513871931844661829755443994214173883E8L,
            6.185032670011643762127954396427045467506E5L,
            1.587171580015525194694938306936721666031E2L
        ];

        static immutable T[6] Q = [
            2.619817175234089411411070339065679229869E13L,
            1.490560994263653042761789432690793026977E12L,
            1.092141473886177435056423606755843616331E10L,
            2.186249607051644894762167991800811827835E7L,
            1.236602014442099053716561665053645270207E4L,
            1.0
        ];
    }
    else static if (realFormat == RealFormat.ieeeExtended)
    {
        static immutable T[3] P = [
            2.0803843631901852422887E6L,
            3.0286971917562792508623E4L,
            6.0614853552242266094567E1L,
        ];
        static immutable T[4] Q = [
            6.0027204078348487957118E6L,
            3.2772515434906797273099E5L,
            1.7492876999891839021063E3L,
            1.0000000000000000000000E0L,
        ];
    }
    else static if (realFormat == RealFormat.ieeeDouble)
    {
        static immutable T[3] P = [
            1.51390680115615096133E3L,
            2.02020656693165307700E1L,
            2.30933477057345225087E-2L,
        ];
        static immutable T[3] Q = [
            4.36821166879210612817E3L,
            2.33184211722314911771E2L,
            1.00000000000000000000E0L,
        ];
    }
    else static if (realFormat == RealFormat.ieeeSingle)
    {
        static immutable T[6] P = [
            6.931472028550421E-001L,
            2.402264791363012E-001L,
            5.550332471162809E-002L,
            9.618437357674640E-003L,
            1.339887440266574E-003L,
            1.535336188319500E-004L,
        ];
    }
    else
        static assert(0, "no coefficients for exp2()");

    // Overflow and Underflow limits.
    enum T OF = T.max_exp;
    enum T UF = T.min_exp - 1;

    // Special cases.
    if (isNaN(x))
        return x;
    if (x > OF)
        return real.infinity;
    if (x < UF)
        return 0.0;

    static if (realFormat == RealFormat.ieeeSingle) // special case for single precision
    {
        // The following is necessary because range reduction blows up.
        if (x == 0.0f)
            return 1.0f;

        // Separate into integer and fractional parts.
        const T i = floor(x);
        int n = cast(int) i;
        x -= i;
        if (x > 0.5f)
        {
            n += 1;
            x -= 1.0f;
        }

        // Rational approximation:
        //  exp2(x) = 1.0 + x P(x)
        x = 1.0f + x * poly(x, P);
    }
    else
    {
        // Separate into integer and fractional parts.
        const T i = floor(x + cast(T) 0.5);
        int n = cast(int) i;
        x -= i;

        // Rational approximation:
        //  exp2(x) = 1.0 + 2x P(x^^2) / (Q(x^^2) - P(x^^2))
        const T xx = x * x;
        const T px = x * poly(xx, P);
        x = px / (poly(xx, Q) - px);
        x = (cast(T) 1.0) + (cast(T) 2.0) * x;
    }

    // Scale by power of 2.
    x = ldexp(x, n);

    return x;
}

@safe @nogc nothrow unittest
{
    assert(feqrel(exp2(0.5L), SQRT2) >= real.mant_dig -1);
    assert(exp2(8.0L) == 256.0);
    assert(exp2(-9.0L)== 1.0L/512.0);

    static void testExp2(T)()
    {
        // NaN
        const T specialNaN = NaN(0x0123L);
        assert(isIdentical(exp2(specialNaN), specialNaN));

        // over-/underflow
        enum T OF = T.max_exp;
        enum T UF = T.min_exp - T.mant_dig;
        assert(isIdentical(exp2(OF + 1), cast(T) T.infinity));
        assert(isIdentical(exp2(UF - 1), cast(T) 0.0));

        static immutable T[2][] vals =
        [
            // x, exp2(x)
            [  0.0, 1.0 ],
            [ -0.0, 1.0 ],
            [  0.5, SQRT2 ],
            [  8.0, 256.0 ],
            [ -9.0, 1.0 / 512 ],
        ];

        foreach (ref val; vals)
        {
            const T x = val[0];
            const T r = val[1];
            const T e = exp2(x);

            //printf("exp2(%Lg) = %Lg, should be %Lg\n", cast(real) x, cast(real) e, cast(real) r);
            assert(isClose(r, e));
        }
    }

    import std.meta : AliasSeq;
    foreach (T; AliasSeq!(real, double, float))
        testExp2!T();
}

/*********************************************************************
 * Separate floating point value into significand and exponent.
 *
 * Returns:
 *      Calculate and return $(I x) and $(I exp) such that
 *      value =$(I x)*2$(SUPERSCRIPT exp) and
 *      .5 $(LT)= |$(I x)| $(LT) 1.0
 *
 *      $(I x) has same sign as value.
 *
 *      $(TABLE_SV
 *      $(TR $(TH value)           $(TH returns)         $(TH exp))
 *      $(TR $(TD $(PLUSMN)0.0)    $(TD $(PLUSMN)0.0)    $(TD 0))
 *      $(TR $(TD +$(INFIN))       $(TD +$(INFIN))       $(TD int.max))
 *      $(TR $(TD -$(INFIN))       $(TD -$(INFIN))       $(TD int.min))
 *      $(TR $(TD $(PLUSMN)$(NAN)) $(TD $(PLUSMN)$(NAN)) $(TD int.min))
 *      )
 */
T frexp(T)(const T value, out int exp) @trusted pure nothrow @nogc
if (isFloatingPoint!T)
{
    if (__ctfe)
    {
        // Handle special cases.
        if (value == 0) { exp = 0; return value; }
        if (value == T.infinity) { exp = int.max; return value; }
        if (value == -T.infinity || value != value) { exp = int.min; return value; }
        // Handle ordinary cases.
        // In CTFE there is no performance advantage for having separate
        // paths for different floating point types.
        T absValue = value < 0 ? -value : value;
        int expCount;
        static if (T.mant_dig > double.mant_dig)
        {
            for (; absValue >= 0x1.0p+1024L; absValue *= 0x1.0p-1024L)
                expCount += 1024;
            for (; absValue < 0x1.0p-1021L; absValue *= 0x1.0p+1021L)
                expCount -= 1021;
        }
        const double dval = cast(double) absValue;
        int dexp = cast(int) (((*cast(const long*) &dval) >>> 52) & 0x7FF) + double.min_exp - 2;
        dexp++;
        expCount += dexp;
        absValue *= 2.0 ^^ -dexp;
        // If the original value was subnormal or if it was a real
        // then absValue can still be outside the [0.5, 1.0) range.
        if (absValue < 0.5)
        {
            assert(T.mant_dig > double.mant_dig || isSubnormal(value));
            do
            {
                absValue += absValue;
                expCount--;
            } while (absValue < 0.5);
        }
        else
        {
            assert(absValue < 1 || T.mant_dig > double.mant_dig);
            for (; absValue >= 1; absValue *= T(0.5))
                expCount++;
        }
        exp = expCount;
        return value < 0 ? -absValue : absValue;
    }

    Unqual!T vf = value;
    ushort* vu = cast(ushort*)&vf;
    static if (is(immutable T == immutable float))
        int* vi = cast(int*)&vf;
    else
        long* vl = cast(long*)&vf;
    int ex;
    alias F = floatTraits!T;

    ex = vu[F.EXPPOS_SHORT] & F.EXPMASK;
    static if (F.realFormat == RealFormat.ieeeExtended ||
               F.realFormat == RealFormat.ieeeExtended53)
    {
        if (ex)
        {   // If exponent is non-zero
            if (ex == F.EXPMASK) // infinity or NaN
            {
                if (*vl &  0x7FFF_FFFF_FFFF_FFFF)  // NaN
                {
                    *vl |= 0xC000_0000_0000_0000;  // convert NaNS to NaNQ
                    exp = int.min;
                }
                else if (vu[F.EXPPOS_SHORT] & 0x8000)   // negative infinity
                    exp = int.min;
                else   // positive infinity
                    exp = int.max;

            }
            else
            {
                exp = ex - F.EXPBIAS;
                vu[F.EXPPOS_SHORT] = (0x8000 & vu[F.EXPPOS_SHORT]) | 0x3FFE;
            }
        }
        else if (!*vl)
        {
            // vf is +-0.0
            exp = 0;
        }
        else
        {
            // subnormal

            vf *= F.RECIP_EPSILON;
            ex = vu[F.EXPPOS_SHORT] & F.EXPMASK;
            exp = ex - F.EXPBIAS - T.mant_dig + 1;
            vu[F.EXPPOS_SHORT] = ((-1 - F.EXPMASK) & vu[F.EXPPOS_SHORT]) | 0x3FFE;
        }
        return vf;
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        if (ex)     // If exponent is non-zero
        {
            if (ex == F.EXPMASK)
            {
                // infinity or NaN
                if (vl[MANTISSA_LSB] |
                    (vl[MANTISSA_MSB] & 0x0000_FFFF_FFFF_FFFF))  // NaN
                {
                    // convert NaNS to NaNQ
                    vl[MANTISSA_MSB] |= 0x0000_8000_0000_0000;
                    exp = int.min;
                }
                else if (vu[F.EXPPOS_SHORT] & 0x8000)   // negative infinity
                    exp = int.min;
                else   // positive infinity
                    exp = int.max;
            }
            else
            {
                exp = ex - F.EXPBIAS;
                vu[F.EXPPOS_SHORT] = F.EXPBIAS | (0x8000 & vu[F.EXPPOS_SHORT]);
            }
        }
        else if ((vl[MANTISSA_LSB] |
            (vl[MANTISSA_MSB] & 0x0000_FFFF_FFFF_FFFF)) == 0)
        {
            // vf is +-0.0
            exp = 0;
        }
        else
        {
            // subnormal
            vf *= F.RECIP_EPSILON;
            ex = vu[F.EXPPOS_SHORT] & F.EXPMASK;
            exp = ex - F.EXPBIAS - T.mant_dig + 1;
            vu[F.EXPPOS_SHORT] = F.EXPBIAS | (0x8000 & vu[F.EXPPOS_SHORT]);
        }
        return vf;
    }
    else static if (F.realFormat == RealFormat.ieeeDouble)
    {
        if (ex) // If exponent is non-zero
        {
            if (ex == F.EXPMASK)   // infinity or NaN
            {
                if (*vl == 0x7FF0_0000_0000_0000)  // positive infinity
                {
                    exp = int.max;
                }
                else if (*vl == 0xFFF0_0000_0000_0000) // negative infinity
                    exp = int.min;
                else
                { // NaN
                    *vl |= 0x0008_0000_0000_0000;  // convert NaNS to NaNQ
                    exp = int.min;
                }
            }
            else
            {
                exp = (ex - F.EXPBIAS) >> 4;
                vu[F.EXPPOS_SHORT] = cast(ushort)((0x800F & vu[F.EXPPOS_SHORT]) | 0x3FE0);
            }
        }
        else if (!(*vl & 0x7FFF_FFFF_FFFF_FFFF))
        {
            // vf is +-0.0
            exp = 0;
        }
        else
        {
            // subnormal
            vf *= F.RECIP_EPSILON;
            ex = vu[F.EXPPOS_SHORT] & F.EXPMASK;
            exp = ((ex - F.EXPBIAS) >> 4) - T.mant_dig + 1;
            vu[F.EXPPOS_SHORT] =
                cast(ushort)(((-1 - F.EXPMASK) & vu[F.EXPPOS_SHORT]) | 0x3FE0);
        }
        return vf;
    }
    else static if (F.realFormat == RealFormat.ieeeSingle)
    {
        if (ex) // If exponent is non-zero
        {
            if (ex == F.EXPMASK)   // infinity or NaN
            {
                if (*vi == 0x7F80_0000)  // positive infinity
                {
                    exp = int.max;
                }
                else if (*vi == 0xFF80_0000) // negative infinity
                    exp = int.min;
                else
                { // NaN
                    *vi |= 0x0040_0000;  // convert NaNS to NaNQ
                    exp = int.min;
                }
            }
            else
            {
                exp = (ex - F.EXPBIAS) >> 7;
                vu[F.EXPPOS_SHORT] = cast(ushort)((0x807F & vu[F.EXPPOS_SHORT]) | 0x3F00);
            }
        }
        else if (!(*vi & 0x7FFF_FFFF))
        {
            // vf is +-0.0
            exp = 0;
        }
        else
        {
            // subnormal
            vf *= F.RECIP_EPSILON;
            ex = vu[F.EXPPOS_SHORT] & F.EXPMASK;
            exp = ((ex - F.EXPBIAS) >> 7) - T.mant_dig + 1;
            vu[F.EXPPOS_SHORT] =
                cast(ushort)(((-1 - F.EXPMASK) & vu[F.EXPPOS_SHORT]) | 0x3F00);
        }
        return vf;
    }
    else // static if (F.realFormat == RealFormat.ibmExtended)
    {
        assert(0, "frexp not implemented");
    }
}

///
@safe unittest
{
    int exp;
    real mantissa = frexp(123.456L, exp);

    assert(isClose(mantissa * pow(2.0L, cast(real) exp), 123.456L));

    assert(frexp(-real.nan, exp) && exp == int.min);
    assert(frexp(real.nan, exp) && exp == int.min);
    assert(frexp(-real.infinity, exp) == -real.infinity && exp == int.min);
    assert(frexp(real.infinity, exp) == real.infinity && exp == int.max);
    assert(frexp(-0.0, exp) == -0.0 && exp == 0);
    assert(frexp(0.0, exp) == 0.0 && exp == 0);
}

@safe @nogc nothrow unittest
{
    int exp;
    real mantissa = frexp(123.456L, exp);

    // check if values are equal to 19 decimal digits of precision
    assert(equalsDigit(mantissa * pow(2.0L, cast(real) exp), 123.456L, 19));
}

@safe unittest
{
    import std.meta : AliasSeq;
    import std.typecons : tuple, Tuple;

    static foreach (T; AliasSeq!(real, double, float))
    {{
        Tuple!(T, T, int)[] vals =     // x,frexp,exp
            [
             tuple(T(0.0),  T( 0.0 ), 0),
             tuple(T(-0.0), T( -0.0), 0),
             tuple(T(1.0),  T( .5  ), 1),
             tuple(T(-1.0), T( -.5 ), 1),
             tuple(T(2.0),  T( .5  ), 2),
             tuple(T(float.min_normal/2.0f), T(.5), -126),
             tuple(T.infinity, T.infinity, int.max),
             tuple(-T.infinity, -T.infinity, int.min),
             tuple(T.nan, T.nan, int.min),
             tuple(-T.nan, -T.nan, int.min),

             // https://issues.dlang.org/show_bug.cgi?id=16026:
             tuple(3 * (T.min_normal * T.epsilon), T( .75), (T.min_exp - T.mant_dig) + 2)
             ];

        foreach (elem; vals)
        {
            T x = elem[0];
            T e = elem[1];
            int exp = elem[2];
            int eptr;
            T v = frexp(x, eptr);
            assert(isIdentical(e, v));
            assert(exp == eptr);

        }

        static if (floatTraits!(T).realFormat == RealFormat.ieeeExtended)
        {
            static T[3][] extendedvals = [ // x,frexp,exp
                [0x1.a5f1c2eb3fe4efp+73L,    0x1.A5F1C2EB3FE4EFp-1L,     74],    // normal
                [0x1.fa01712e8f0471ap-1064L, 0x1.fa01712e8f0471ap-1L, -1063],
                [T.min_normal,      .5, -16381],
                [T.min_normal/2.0L, .5, -16382]    // subnormal
            ];
            foreach (elem; extendedvals)
            {
                T x = elem[0];
                T e = elem[1];
                int exp = cast(int) elem[2];
                int eptr;
                T v = frexp(x, eptr);
                assert(isIdentical(e, v));
                assert(exp == eptr);

            }
        }
    }}

    // CTFE
    alias CtfeFrexpResult= Tuple!(real, int);
    static CtfeFrexpResult ctfeFrexp(T)(const T value)
    {
        int exp;
        auto significand = frexp(value, exp);
        return CtfeFrexpResult(significand, exp);
    }
    static foreach (T; AliasSeq!(real, double, float))
    {{
        enum Tuple!(T, T, int)[] vals =     // x,frexp,exp
            [
             tuple(T(0.0),  T( 0.0 ), 0),
             tuple(T(-0.0), T( -0.0), 0),
             tuple(T(1.0),  T( .5  ), 1),
             tuple(T(-1.0), T( -.5 ), 1),
             tuple(T(2.0),  T( .5  ), 2),
             tuple(T(float.min_normal/2.0f), T(.5), -126),
             tuple(T.infinity, T.infinity, int.max),
             tuple(-T.infinity, -T.infinity, int.min),
             tuple(T.nan, T.nan, int.min),
             tuple(-T.nan, -T.nan, int.min),

             // https://issues.dlang.org/show_bug.cgi?id=16026:
             tuple(3 * (T.min_normal * T.epsilon), T( .75), (T.min_exp - T.mant_dig) + 2)
             ];

        static foreach (elem; vals)
        {
            static assert(ctfeFrexp(elem[0]) is CtfeFrexpResult(elem[1], elem[2]));
        }

        static if (floatTraits!(T).realFormat == RealFormat.ieeeExtended)
        {
            enum T[3][] extendedvals = [ // x,frexp,exp
                [0x1.a5f1c2eb3fe4efp+73L,    0x1.A5F1C2EB3FE4EFp-1L,     74],    // normal
                [0x1.fa01712e8f0471ap-1064L, 0x1.fa01712e8f0471ap-1L, -1063],
                [T.min_normal,      .5, -16381],
                [T.min_normal/2.0L, .5, -16382]    // subnormal
            ];
            static foreach (elem; extendedvals)
            {
                static assert(ctfeFrexp(elem[0]) is CtfeFrexpResult(elem[1], cast(int) elem[2]));
            }
        }
    }}
}

@safe unittest
{
    import std.meta : AliasSeq;
    void foo() {
        static foreach (T; AliasSeq!(real, double, float))
        {{
            int exp;
            const T a = 1;
            immutable T b = 2;
            auto c = frexp(a, exp);
            auto d = frexp(b, exp);
        }}
    }
}

/******************************************
 * Extracts the exponent of x as a signed integral value.
 *
 * If x is not a special value, the result is the same as
 * $(D cast(int) logb(x)).
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                $(TH ilogb(x))     $(TH Range error?))
 *      $(TR $(TD 0)                 $(TD FP_ILOGB0)   $(TD yes))
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD int.max)     $(TD no))
 *      $(TR $(TD $(NAN))            $(TD FP_ILOGBNAN) $(TD no))
 *      )
 */
int ilogb(T)(const T x) @trusted pure nothrow @nogc
if (isFloatingPoint!T)
{
    import core.bitop : bsr;
    alias F = floatTraits!T;

    union floatBits
    {
        T rv;
        ushort[T.sizeof/2] vu;
        uint[T.sizeof/4] vui;
        static if (T.sizeof >= 8)
            ulong[T.sizeof/8] vul;
    }
    floatBits y = void;
    y.rv = x;

    int ex = y.vu[F.EXPPOS_SHORT] & F.EXPMASK;
    static if (F.realFormat == RealFormat.ieeeExtended ||
               F.realFormat == RealFormat.ieeeExtended53)
    {
        if (ex)
        {
            // If exponent is non-zero
            if (ex == F.EXPMASK) // infinity or NaN
            {
                if (y.vul[0] &  0x7FFF_FFFF_FFFF_FFFF)  // NaN
                    return FP_ILOGBNAN;
                else // +-infinity
                    return int.max;
            }
            else
            {
                return ex - F.EXPBIAS - 1;
            }
        }
        else if (!y.vul[0])
        {
            // vf is +-0.0
            return FP_ILOGB0;
        }
        else
        {
            // subnormal
            return ex - F.EXPBIAS - T.mant_dig + 1 + bsr(y.vul[0]);
        }
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        if (ex)    // If exponent is non-zero
        {
            if (ex == F.EXPMASK)
            {
                // infinity or NaN
                if (y.vul[MANTISSA_LSB] | ( y.vul[MANTISSA_MSB] & 0x0000_FFFF_FFFF_FFFF))  // NaN
                    return FP_ILOGBNAN;
                else // +- infinity
                    return int.max;
            }
            else
            {
                return ex - F.EXPBIAS - 1;
            }
        }
        else if ((y.vul[MANTISSA_LSB] | (y.vul[MANTISSA_MSB] & 0x0000_FFFF_FFFF_FFFF)) == 0)
        {
            // vf is +-0.0
            return FP_ILOGB0;
        }
        else
        {
            // subnormal
            const ulong msb = y.vul[MANTISSA_MSB] & 0x0000_FFFF_FFFF_FFFF;
            const ulong lsb = y.vul[MANTISSA_LSB];
            if (msb)
                return ex - F.EXPBIAS - T.mant_dig + 1 + bsr(msb) + 64;
            else
                return ex - F.EXPBIAS - T.mant_dig + 1 + bsr(lsb);
        }
    }
    else static if (F.realFormat == RealFormat.ieeeDouble)
    {
        if (ex) // If exponent is non-zero
        {
            if (ex == F.EXPMASK)   // infinity or NaN
            {
                if ((y.vul[0] & 0x7FFF_FFFF_FFFF_FFFF) == 0x7FF0_0000_0000_0000)  // +- infinity
                    return int.max;
                else // NaN
                    return FP_ILOGBNAN;
            }
            else
            {
                return ((ex - F.EXPBIAS) >> 4) - 1;
            }
        }
        else if (!(y.vul[0] & 0x7FFF_FFFF_FFFF_FFFF))
        {
            // vf is +-0.0
            return FP_ILOGB0;
        }
        else
        {
            // subnormal
            enum MANTISSAMASK_64 = ((cast(ulong) F.MANTISSAMASK_INT) << 32) | 0xFFFF_FFFF;
            return ((ex - F.EXPBIAS) >> 4) - T.mant_dig + 1 + bsr(y.vul[0] & MANTISSAMASK_64);
        }
    }
    else static if (F.realFormat == RealFormat.ieeeSingle)
    {
        if (ex) // If exponent is non-zero
        {
            if (ex == F.EXPMASK)   // infinity or NaN
            {
                if ((y.vui[0] & 0x7FFF_FFFF) == 0x7F80_0000)  // +- infinity
                    return int.max;
                else // NaN
                    return FP_ILOGBNAN;
            }
            else
            {
                return ((ex - F.EXPBIAS) >> 7) - 1;
            }
        }
        else if (!(y.vui[0] & 0x7FFF_FFFF))
        {
            // vf is +-0.0
            return FP_ILOGB0;
        }
        else
        {
            // subnormal
            const uint mantissa = y.vui[0] & F.MANTISSAMASK_INT;
            return ((ex - F.EXPBIAS) >> 7) - T.mant_dig + 1 + bsr(mantissa);
        }
    }
    else // static if (F.realFormat == RealFormat.ibmExtended)
    {
        assert(0, "ilogb not implemented");
    }
}
/// ditto
int ilogb(T)(const T x) @safe pure nothrow @nogc
if (isIntegral!T && isUnsigned!T)
{
    import core.bitop : bsr;
    if (x == 0)
        return FP_ILOGB0;
    else
    {
        static assert(T.sizeof <= ulong.sizeof, "integer size too large for the current ilogb implementation");
        return bsr(x);
    }
}
/// ditto
int ilogb(T)(const T x) @safe pure nothrow @nogc
if (isIntegral!T && isSigned!T)
{
    import std.traits : Unsigned;
    // Note: abs(x) can not be used because the return type is not Unsigned and
    //       the return value would be wrong for x == int.min
    Unsigned!T absx =  x >= 0 ? x : -x;
    return ilogb(absx);
}

///
@safe pure unittest
{
    assert(ilogb(1) == 0);
    assert(ilogb(3) == 1);
    assert(ilogb(3.0) == 1);
    assert(ilogb(100_000_000) == 26);

    assert(ilogb(0) == FP_ILOGB0);
    assert(ilogb(0.0) == FP_ILOGB0);
    assert(ilogb(double.nan) == FP_ILOGBNAN);
    assert(ilogb(double.infinity) == int.max);
}

/**
Special return values of $(LREF ilogb).
 */
alias FP_ILOGB0   = core.stdc.math.FP_ILOGB0;
/// ditto
alias FP_ILOGBNAN = core.stdc.math.FP_ILOGBNAN;

///
@safe pure unittest
{
    assert(ilogb(0) == FP_ILOGB0);
    assert(ilogb(0.0) == FP_ILOGB0);
    assert(ilogb(double.nan) == FP_ILOGBNAN);
}

@safe nothrow @nogc unittest
{
    import std.meta : AliasSeq;
    import std.typecons : Tuple;
    static foreach (F; AliasSeq!(float, double, real))
    {{
        alias T = Tuple!(F, int);
        T[13] vals =   // x, ilogb(x)
        [
            T(  F.nan     , FP_ILOGBNAN ),
            T( -F.nan     , FP_ILOGBNAN ),
            T(  F.infinity, int.max     ),
            T( -F.infinity, int.max     ),
            T(  0.0       , FP_ILOGB0   ),
            T( -0.0       , FP_ILOGB0   ),
            T(  2.0       , 1           ),
            T(  2.0001    , 1           ),
            T(  1.9999    , 0           ),
            T(  0.5       , -1          ),
            T(  123.123   , 6           ),
            T( -123.123   , 6           ),
            T(  0.123     , -4          ),
        ];

        foreach (elem; vals)
        {
            assert(ilogb(elem[0]) == elem[1]);
        }
    }}

    // min_normal and subnormals
    assert(ilogb(-float.min_normal) == -126);
    assert(ilogb(nextUp(-float.min_normal)) == -127);
    assert(ilogb(nextUp(-float(0.0))) == -149);
    assert(ilogb(-double.min_normal) == -1022);
    assert(ilogb(nextUp(-double.min_normal)) == -1023);
    assert(ilogb(nextUp(-double(0.0))) == -1074);
    static if (floatTraits!(real).realFormat == RealFormat.ieeeExtended)
    {
        assert(ilogb(-real.min_normal) == -16382);
        assert(ilogb(nextUp(-real.min_normal)) == -16383);
        assert(ilogb(nextUp(-real(0.0))) == -16445);
    }
    else static if (floatTraits!(real).realFormat == RealFormat.ieeeDouble)
    {
        assert(ilogb(-real.min_normal) == -1022);
        assert(ilogb(nextUp(-real.min_normal)) == -1023);
        assert(ilogb(nextUp(-real(0.0))) == -1074);
    }

    // test integer types
    assert(ilogb(0) == FP_ILOGB0);
    assert(ilogb(int.max) == 30);
    assert(ilogb(int.min) == 31);
    assert(ilogb(uint.max) == 31);
    assert(ilogb(long.max) == 62);
    assert(ilogb(long.min) == 63);
    assert(ilogb(ulong.max) == 63);
}

/*******************************************
 * Compute n * 2$(SUPERSCRIPT exp)
 * References: frexp
 */

pragma(inline, true)
real ldexp(real n, int exp)     @safe pure nothrow @nogc { return core.math.ldexp(n, exp); }
///ditto
pragma(inline, true)
double ldexp(double n, int exp) @safe pure nothrow @nogc { return core.math.ldexp(n, exp); }
///ditto
pragma(inline, true)
float ldexp(float n, int exp)   @safe pure nothrow @nogc { return core.math.ldexp(n, exp); }

///
@nogc @safe pure nothrow unittest
{
    import std.meta : AliasSeq;
    static foreach (T; AliasSeq!(float, double, real))
    {{
        T r;

        r = ldexp(3.0L, 3);
        assert(r == 24);

        r = ldexp(cast(T) 3.0, cast(int) 3);
        assert(r == 24);

        T n = 3.0;
        int exp = 3;
        r = ldexp(n, exp);
        assert(r == 24);
    }}
}

@safe pure nothrow @nogc unittest
{
    static if (floatTraits!(real).realFormat == RealFormat.ieeeExtended ||
               floatTraits!(real).realFormat == RealFormat.ieeeExtended53 ||
               floatTraits!(real).realFormat == RealFormat.ieeeQuadruple)
    {
        assert(ldexp(1.0L, -16384) == 0x1p-16384L);
        assert(ldexp(1.0L, -16382) == 0x1p-16382L);
        int x;
        real n = frexp(0x1p-16384L, x);
        assert(n == 0.5L);
        assert(x==-16383);
        assert(ldexp(n, x)==0x1p-16384L);
    }
    else static if (floatTraits!(real).realFormat == RealFormat.ieeeDouble)
    {
        assert(ldexp(1.0L, -1024) == 0x1p-1024L);
        assert(ldexp(1.0L, -1022) == 0x1p-1022L);
        int x;
        real n = frexp(0x1p-1024L, x);
        assert(n == 0.5L);
        assert(x==-1023);
        assert(ldexp(n, x)==0x1p-1024L);
    }
    else static assert(false, "Floating point type real not supported");
}

/* workaround https://issues.dlang.org/show_bug.cgi?id=14718
   float parsing depends on platform strtold
@safe pure nothrow @nogc unittest
{
    assert(ldexp(1.0, -1024) == 0x1p-1024);
    assert(ldexp(1.0, -1022) == 0x1p-1022);
    int x;
    double n = frexp(0x1p-1024, x);
    assert(n == 0.5);
    assert(x==-1023);
    assert(ldexp(n, x)==0x1p-1024);
}

@safe pure nothrow @nogc unittest
{
    assert(ldexp(1.0f, -128) == 0x1p-128f);
    assert(ldexp(1.0f, -126) == 0x1p-126f);
    int x;
    float n = frexp(0x1p-128f, x);
    assert(n == 0.5f);
    assert(x==-127);
    assert(ldexp(n, x)==0x1p-128f);
}
*/

@safe @nogc nothrow unittest
{
    static real[3][] vals =    // value,exp,ldexp
    [
    [    0,    0,    0],
    [    1,    0,    1],
    [    -1,    0,    -1],
    [    1,    1,    2],
    [    123,    10,    125952],
    [    real.max,    int.max,    real.infinity],
    [    real.max,    -int.max,    0],
    [    real.min_normal,    -int.max,    0],
    ];
    int i;

    for (i = 0; i < vals.length; i++)
    {
        real x = vals[i][0];
        int exp = cast(int) vals[i][1];
        real z = vals[i][2];
        real l = ldexp(x, exp);

        assert(equalsDigit(z, l, 7));
    }

    real function(real, int) pldexp = &ldexp;
    assert(pldexp != null);
}

private
{
    version (INLINE_YL2X) {} else
    {
        static if (floatTraits!real.realFormat == RealFormat.ieeeQuadruple)
        {
            // Coefficients for log(1 + x) = x - x**2/2 + x**3 P(x)/Q(x)
            static immutable real[13] logCoeffsP = [
                1.313572404063446165910279910527789794488E4L,
                7.771154681358524243729929227226708890930E4L,
                2.014652742082537582487669938141683759923E5L,
                3.007007295140399532324943111654767187848E5L,
                2.854829159639697837788887080758954924001E5L,
                1.797628303815655343403735250238293741397E5L,
                7.594356839258970405033155585486712125861E4L,
                2.128857716871515081352991964243375186031E4L,
                3.824952356185897735160588078446136783779E3L,
                4.114517881637811823002128927449878962058E2L,
                2.321125933898420063925789532045674660756E1L,
                4.998469661968096229986658302195402690910E-1L,
                1.538612243596254322971797716843006400388E-6L
            ];
            static immutable real[13] logCoeffsQ = [
                3.940717212190338497730839731583397586124E4L,
                2.626900195321832660448791748036714883242E5L,
                7.777690340007566932935753241556479363645E5L,
                1.347518538384329112529391120390701166528E6L,
                1.514882452993549494932585972882995548426E6L,
                1.158019977462989115839826904108208787040E6L,
                6.132189329546557743179177159925690841200E5L,
                2.248234257620569139969141618556349415120E5L,
                5.605842085972455027590989944010492125825E4L,
                9.147150349299596453976674231612674085381E3L,
                9.104928120962988414618126155557301584078E2L,
                4.839208193348159620282142911143429644326E1L,
                1.0
            ];

            // Coefficients for log(x) = z + z^3 P(z^2)/Q(z^2)
            // where z = 2(x-1)/(x+1)
            static immutable real[6] logCoeffsR = [
                1.418134209872192732479751274970992665513E5L,
                -8.977257995689735303686582344659576526998E4L,
                2.048819892795278657810231591630928516206E4L,
                -2.024301798136027039250415126250455056397E3L,
                8.057002716646055371965756206836056074715E1L,
                -8.828896441624934385266096344596648080902E-1L
            ];
            static immutable real[7] logCoeffsS = [
                1.701761051846631278975701529965589676574E6L,
                -1.332535117259762928288745111081235577029E6L,
                4.001557694070773974936904547424676279307E5L,
                -5.748542087379434595104154610899551484314E4L,
                3.998526750980007367835804959888064681098E3L,
                -1.186359407982897997337150403816839480438E2L,
                1.0
            ];
        }
        else
        {
            // Coefficients for log(1 + x) = x - x**2/2 + x**3 P(x)/Q(x)
            static immutable real[7] logCoeffsP = [
                2.0039553499201281259648E1L,
                5.7112963590585538103336E1L,
                6.0949667980987787057556E1L,
                2.9911919328553073277375E1L,
                6.5787325942061044846969E0L,
                4.9854102823193375972212E-1L,
                4.5270000862445199635215E-5L,
            ];
            static immutable real[7] logCoeffsQ = [
                6.0118660497603843919306E1L,
                2.1642788614495947685003E2L,
                3.0909872225312059774938E2L,
                2.2176239823732856465394E2L,
                8.3047565967967209469434E1L,
                1.5062909083469192043167E1L,
                1.0000000000000000000000E0L,
            ];

            // Coefficients for log(x) = z + z^3 P(z^2)/Q(z^2)
            // where z = 2(x-1)/(x+1)
            static immutable real[4] logCoeffsR = [
               -3.5717684488096787370998E1L,
                1.0777257190312272158094E1L,
               -7.1990767473014147232598E-1L,
                1.9757429581415468984296E-3L,
            ];
            static immutable real[4] logCoeffsS = [
               -4.2861221385716144629696E2L,
                1.9361891836232102174846E2L,
               -2.6201045551331104417768E1L,
                1.0000000000000000000000E0L,
            ];
        }
    }
}

/**************************************
 * Calculate the natural logarithm of x.
 *
 *    $(TABLE_SV
 *    $(TR $(TH x)            $(TH log(x))    $(TH divide by 0?) $(TH invalid?))
 *    $(TR $(TD $(PLUSMN)0.0) $(TD -$(INFIN)) $(TD yes)          $(TD no))
 *    $(TR $(TD $(LT)0.0)     $(TD $(NAN))    $(TD no)           $(TD yes))
 *    $(TR $(TD +$(INFIN))    $(TD +$(INFIN)) $(TD no)           $(TD no))
 *    )
 */
real log(real x) @safe pure nothrow @nogc
{
    version (INLINE_YL2X)
        return core.math.yl2x(x, LN2);
    else
    {
        // C1 + C2 = LN2.
        enum real C1 = 6.93145751953125E-1L;
        enum real C2 = 1.428606820309417232121458176568075500134E-6L;

        // Special cases.
        if (isNaN(x))
            return x;
        if (isInfinity(x) && !signbit(x))
            return x;
        if (x == 0.0)
            return -real.infinity;
        if (x < 0.0)
            return real.nan;

        // Separate mantissa from exponent.
        // Note, frexp is used so that denormal numbers will be handled properly.
        real y, z;
        int exp;

        x = frexp(x, exp);

        // Logarithm using log(x) = z + z^^3 R(z) / S(z),
        // where z = 2(x - 1)/(x + 1)
        if ((exp > 2) || (exp < -2))
        {
            if (x < SQRT1_2)
            {   // 2(2x - 1)/(2x + 1)
                exp -= 1;
                z = x - 0.5;
                y = 0.5 * z + 0.5;
            }
            else
            {   // 2(x - 1)/(x + 1)
                z = x - 0.5;
                z -= 0.5;
                y = 0.5 * x  + 0.5;
            }
            x = z / y;
            z = x * x;
            z = x * (z * poly(z, logCoeffsR) / poly(z, logCoeffsS));
            z += exp * C2;
            z += x;
            z += exp * C1;

            return z;
        }

        // Logarithm using log(1 + x) = x - .5x^^2 + x^^3 P(x) / Q(x)
        if (x < SQRT1_2)
        {
            exp -= 1;
            x = 2.0 * x - 1.0;
        }
        else
        {
            x = x - 1.0;
        }
        z = x * x;
        y = x * (z * poly(x, logCoeffsP) / poly(x, logCoeffsQ));
        y += exp * C2;
        z = y - 0.5 * z;

        // Note, the sum of above terms does not exceed x/4,
        // so it contributes at most about 1/4 lsb to the error.
        z += x;
        z += exp * C1;

        return z;
    }
}

///
@safe pure nothrow @nogc unittest
{
    assert(feqrel(log(E), 1) >= real.mant_dig - 1);
}

/**************************************
 * Calculate the base-10 logarithm of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)            $(TH log10(x))  $(TH divide by 0?) $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0) $(TD -$(INFIN)) $(TD yes)          $(TD no))
 *      $(TR $(TD $(LT)0.0)     $(TD $(NAN))    $(TD no)           $(TD yes))
 *      $(TR $(TD +$(INFIN))    $(TD +$(INFIN)) $(TD no)           $(TD no))
 *      )
 */
real log10(real x) @safe pure nothrow @nogc
{
    version (INLINE_YL2X)
        return core.math.yl2x(x, LOG2);
    else
    {
        // log10(2) split into two parts.
        enum real L102A =  0.3125L;
        enum real L102B = -1.14700043360188047862611052755069732318101185E-2L;

        // log10(e) split into two parts.
        enum real L10EA =  0.5L;
        enum real L10EB = -6.570551809674817234887108108339491770560299E-2L;

        // Special cases are the same as for log.
        if (isNaN(x))
            return x;
        if (isInfinity(x) && !signbit(x))
            return x;
        if (x == 0.0)
            return -real.infinity;
        if (x < 0.0)
            return real.nan;

        // Separate mantissa from exponent.
        // Note, frexp is used so that denormal numbers will be handled properly.
        real y, z;
        int exp;

        x = frexp(x, exp);

        // Logarithm using log(x) = z + z^^3 R(z) / S(z),
        // where z = 2(x - 1)/(x + 1)
        if ((exp > 2) || (exp < -2))
        {
            if (x < SQRT1_2)
            {   // 2(2x - 1)/(2x + 1)
                exp -= 1;
                z = x - 0.5;
                y = 0.5 * z + 0.5;
            }
            else
            {   // 2(x - 1)/(x + 1)
                z = x - 0.5;
                z -= 0.5;
                y = 0.5 * x  + 0.5;
            }
            x = z / y;
            z = x * x;
            y = x * (z * poly(z, logCoeffsR) / poly(z, logCoeffsS));
            goto Ldone;
        }

        // Logarithm using log(1 + x) = x - .5x^^2 + x^^3 P(x) / Q(x)
        if (x < SQRT1_2)
        {
            exp -= 1;
            x = 2.0 * x - 1.0;
        }
        else
            x = x - 1.0;

        z = x * x;
        y = x * (z * poly(x, logCoeffsP) / poly(x, logCoeffsQ));
        y = y - 0.5 * z;

        // Multiply log of fraction by log10(e) and base 2 exponent by log10(2).
        // This sequence of operations is critical and it may be horribly
        // defeated by some compiler optimizers.
    Ldone:
        z = y * L10EB;
        z += x * L10EB;
        z += exp * L102B;
        z += y * L10EA;
        z += x * L10EA;
        z += exp * L102A;

        return z;
    }
}

///
@safe pure nothrow @nogc unittest
{
    assert(fabs(log10(1000) - 3) < .000001);
}

/**
 * Calculates the natural logarithm of 1 + x.
 *
 * For very small x, log1p(x) will be more accurate than
 * log(1 + x).
 *
 *  $(TABLE_SV
 *  $(TR $(TH x)            $(TH log1p(x))     $(TH divide by 0?) $(TH invalid?))
 *  $(TR $(TD $(PLUSMN)0.0) $(TD $(PLUSMN)0.0) $(TD no)           $(TD no))
 *  $(TR $(TD -1.0)         $(TD -$(INFIN))    $(TD yes)          $(TD no))
 *  $(TR $(TD $(LT)-1.0)    $(TD -$(NAN))      $(TD no)           $(TD yes))
 *  $(TR $(TD +$(INFIN))    $(TD +$(INFIN))    $(TD no)           $(TD no))
 *  )
 */
real log1p(real x) @safe pure nothrow @nogc
{
    version (INLINE_YL2X)
    {
        // On x87, yl2xp1 is valid if and only if -0.5 <= lg(x) <= 0.5,
        //    ie if -0.29 <= x <= 0.414
        return (fabs(x) <= 0.25)  ? core.math.yl2xp1(x, LN2) : core.math.yl2x(x+1, LN2);
    }
    else
    {
        // Special cases.
        if (isNaN(x) || x == 0.0)
            return x;
        if (isInfinity(x) && !signbit(x))
            return x;
        if (x == -1.0)
            return -real.infinity;
        if (x < -1.0)
            return real.nan;

        return log(x + 1.0);
    }
}

///
@safe pure unittest
{
    assert(isIdentical(log1p(0.0), 0.0));
    assert(log1p(1.0).feqrel(0.69314) > 16);

    assert(log1p(-1.0) == -real.infinity);
    assert(isNaN(log1p(-2.0)));
    assert(log1p(real.nan) is real.nan);
    assert(log1p(-real.nan) is -real.nan);
    assert(log1p(real.infinity) == real.infinity);
}

/***************************************
 * Calculates the base-2 logarithm of x:
 * $(SUB log, 2)x
 *
 *  $(TABLE_SV
 *  $(TR $(TH x)            $(TH log2(x))   $(TH divide by 0?) $(TH invalid?))
 *  $(TR $(TD $(PLUSMN)0.0) $(TD -$(INFIN)) $(TD yes)          $(TD no) )
 *  $(TR $(TD $(LT)0.0)     $(TD $(NAN))    $(TD no)           $(TD yes) )
 *  $(TR $(TD +$(INFIN))    $(TD +$(INFIN)) $(TD no)           $(TD no) )
 *  )
 */
real log2(real x) @safe pure nothrow @nogc
{
    version (INLINE_YL2X)
        return core.math.yl2x(x, 1.0L);
    else
    {
        // Special cases are the same as for log.
        if (isNaN(x))
            return x;
        if (isInfinity(x) && !signbit(x))
            return x;
        if (x == 0.0)
            return -real.infinity;
        if (x < 0.0)
            return real.nan;

        // Separate mantissa from exponent.
        // Note, frexp is used so that denormal numbers will be handled properly.
        real y, z;
        int exp;

        x = frexp(x, exp);

        // Logarithm using log(x) = z + z^^3 R(z) / S(z),
        // where z = 2(x - 1)/(x + 1)
        if ((exp > 2) || (exp < -2))
        {
            if (x < SQRT1_2)
            {   // 2(2x - 1)/(2x + 1)
                exp -= 1;
                z = x - 0.5;
                y = 0.5 * z + 0.5;
            }
            else
            {   // 2(x - 1)/(x + 1)
                z = x - 0.5;
                z -= 0.5;
                y = 0.5 * x  + 0.5;
            }
            x = z / y;
            z = x * x;
            y = x * (z * poly(z, logCoeffsR) / poly(z, logCoeffsS));
            goto Ldone;
        }

        // Logarithm using log(1 + x) = x - .5x^^2 + x^^3 P(x) / Q(x)
        if (x < SQRT1_2)
        {
            exp -= 1;
            x = 2.0 * x - 1.0;
        }
        else
            x = x - 1.0;

        z = x * x;
        y = x * (z * poly(x, logCoeffsP) / poly(x, logCoeffsQ));
        y = y - 0.5 * z;

        // Multiply log of fraction by log10(e) and base 2 exponent by log10(2).
        // This sequence of operations is critical and it may be horribly
        // defeated by some compiler optimizers.
    Ldone:
        z = y * (LOG2E - 1.0);
        z += x * (LOG2E - 1.0);
        z += y;
        z += x;
        z += exp;

        return z;
    }
}

///
@safe unittest
{
    assert(isClose(log2(1024.0L), 10));
}

@safe @nogc nothrow unittest
{
    // check if values are equal to 19 decimal digits of precision
    assert(equalsDigit(log2(1024.0L), 10, 19));
}

/*****************************************
 * Extracts the exponent of x as a signed integral value.
 *
 * If x is subnormal, it is treated as if it were normalized.
 * For a positive, finite x:
 *
 * 1 $(LT)= $(I x) * FLT_RADIX$(SUPERSCRIPT -logb(x)) $(LT) FLT_RADIX
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH logb(x))   $(TH divide by 0?) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD +$(INFIN)) $(TD no))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD -$(INFIN)) $(TD yes) )
 *      )
 */
real logb(real x) @trusted nothrow @nogc
{
    version (InlineAsm_X87_MSVC)
    {
        version (X86_64)
        {
            asm pure nothrow @nogc
            {
                naked                       ;
                fld     real ptr [RCX]      ;
                fxtract                     ;
                fstp    ST(0)               ;
                ret                         ;
            }
        }
        else
        {
            asm pure nothrow @nogc
            {
                fld     x                   ;
                fxtract                     ;
                fstp    ST(0)               ;
            }
        }
    }
    else
        return core.stdc.math.logbl(x);
}

///
@safe @nogc nothrow unittest
{
    assert(logb(1.0) == 0);
    assert(logb(100.0) == 6);

    assert(logb(0.0) == -real.infinity);
    assert(logb(real.infinity) == real.infinity);
    assert(logb(-real.infinity) == real.infinity);
}

/*************************************
 * Efficiently calculates x * 2$(SUPERSCRIPT n).
 *
 * scalbn handles underflow and overflow in
 * the same fashion as the basic arithmetic operators.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH scalb(x)))
 *      $(TR $(TD $(PLUSMNINF))      $(TD $(PLUSMNINF)) )
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(PLUSMN)0.0) )
 *      )
 */
pragma(inline, true)
real scalbn(real x, int n) @safe pure nothrow @nogc { return _scalbn(x,n); }

/// ditto
pragma(inline, true)
double scalbn(double x, int n) @safe pure nothrow @nogc { return _scalbn(x,n); }

/// ditto
pragma(inline, true)
float scalbn(float x, int n) @safe pure nothrow @nogc { return _scalbn(x,n); }

///
@safe pure nothrow @nogc unittest
{
    assert(scalbn(0x1.2345678abcdefp0L, 999) == 0x1.2345678abcdefp999L);
    assert(scalbn(-real.infinity, 5) == -real.infinity);
    assert(scalbn(2.0,10) == 2048.0);
    assert(scalbn(2048.0f,-10) == 2.0f);
}

pragma(inline, true)
private F _scalbn(F)(F x, int n)
{
    if (__ctfe)
    {
        // Handle special cases.
        if (x == F(0.0) || isInfinity(x))
            return x;
    }
    return core.math.ldexp(x, n);
}

@safe pure nothrow @nogc unittest
{
    // CTFE-able test
    static assert(scalbn(0x1.2345678abcdefp0L, 999) == 0x1.2345678abcdefp999L);
    static assert(scalbn(-real.infinity, 5) == -real.infinity);
    // Test with large exponent delta n where the result is in bounds but 2.0L ^^ n is not.
    enum initialExponent = real.min_exp + 2, resultExponent = real.max_exp - 2;
    enum int n = resultExponent - initialExponent;
    enum real x = 0x1.2345678abcdefp0L * (2.0L ^^ initialExponent);
    enum staticResult = scalbn(x, n);
    static assert(staticResult == 0x1.2345678abcdefp0L * (2.0L ^^ resultExponent));
    assert(scalbn(x, n) == staticResult);
}

version (IeeeFlagsSupport)
{

/** IEEE exception status flags ('sticky bits')

 These flags indicate that an exceptional floating-point condition has occurred.
 They indicate that a NaN or an infinity has been generated, that a result
 is inexact, or that a signalling NaN has been encountered. If floating-point
 exceptions are enabled (unmasked), a hardware exception will be generated
 instead of setting these flags.
 */
struct IeeeFlags
{
nothrow @nogc:

private:
    // The x87 FPU status register is 16 bits.
    // The Pentium SSE2 status register is 32 bits.
    // The ARM and PowerPC FPSCR is a 32-bit register.
    // The SPARC FSR is a 32bit register (64 bits for SPARC 7 & 8, but high bits are uninteresting).
    // The RISC-V (32 & 64 bit) fcsr is 32-bit register.
    uint flags;

    version (CRuntime_Microsoft)
    {
        // Microsoft uses hardware-incompatible custom constants in fenv.h (core.stdc.fenv).
        // Applies to both x87 status word (16 bits) and SSE2 status word(32 bits).
        enum : int
        {
            INEXACT_MASK   = 0x20,
            UNDERFLOW_MASK = 0x10,
            OVERFLOW_MASK  = 0x08,
            DIVBYZERO_MASK = 0x04,
            INVALID_MASK   = 0x01,

            EXCEPTIONS_MASK = 0b11_1111
        }
        // Don't bother about subnormals, they are not supported on most CPUs.
        //  SUBNORMAL_MASK = 0x02;
    }
    else
    {
        enum : int
        {
            INEXACT_MASK    = core.stdc.fenv.FE_INEXACT,
            UNDERFLOW_MASK  = core.stdc.fenv.FE_UNDERFLOW,
            OVERFLOW_MASK   = core.stdc.fenv.FE_OVERFLOW,
            DIVBYZERO_MASK  = core.stdc.fenv.FE_DIVBYZERO,
            INVALID_MASK    = core.stdc.fenv.FE_INVALID,
            EXCEPTIONS_MASK = core.stdc.fenv.FE_ALL_EXCEPT,
        }
    }

    static uint getIeeeFlags() @trusted pure
    {
        version (InlineAsm_X86_Any)
        {
            ushort sw;
            asm pure nothrow @nogc { fstsw sw; }

            // OR the result with the SSE2 status register (MXCSR).
            if (haveSSE)
            {
                uint mxcsr;
                asm pure nothrow @nogc { stmxcsr mxcsr; }
                return (sw | mxcsr) & EXCEPTIONS_MASK;
            }
            else return sw & EXCEPTIONS_MASK;
        }
        else version (SPARC)
        {
           /*
               int retval;
               asm pure nothrow @nogc { st %fsr, retval; }
               return retval;
            */
           assert(0, "Not yet supported");
        }
        else version (ARM)
        {
            assert(false, "Not yet supported.");
        }
        else version (RISCV_Any)
        {
            mixin(`
            uint result = void;
            asm pure nothrow @nogc
            {
                "frflags %0" : "=r" (result);
            }
            return result;
            `);
        }
        else
            assert(0, "Not yet supported");
    }

    static void resetIeeeFlags() @trusted
    {
        version (InlineAsm_X86_Any)
        {
            asm nothrow @nogc
            {
                fnclex;
            }

            // Also clear exception flags in MXCSR, SSE's control register.
            if (haveSSE)
            {
                uint mxcsr;
                asm nothrow @nogc { stmxcsr mxcsr; }
                mxcsr &= ~EXCEPTIONS_MASK;
                asm nothrow @nogc { ldmxcsr mxcsr; }
            }
        }
        else version (RISCV_Any)
        {
            mixin(`
            uint newValues = 0x0;
            asm pure nothrow @nogc
            {
                "fsflags %0" : : "r" (newValues);
            }
            `);
        }
        else
        {
            /* SPARC:
              int tmpval;
              asm pure nothrow @nogc { st %fsr, tmpval; }
              tmpval &=0xFFFF_FC00;
              asm pure nothrow @nogc { ld tmpval, %fsr; }
            */
           assert(0, "Not yet supported");
        }
    }

public:
    /**
     * The result cannot be represented exactly, so rounding occurred.
     * Example: `x = sin(0.1);`
     */
    @property bool inexact() @safe const { return (flags & INEXACT_MASK) != 0; }

    /**
     * A zero was generated by underflow
     * Example: `x = real.min*real.epsilon/2;`
     */
    @property bool underflow() @safe const { return (flags & UNDERFLOW_MASK) != 0; }

    /**
     * An infinity was generated by overflow
     * Example: `x = real.max*2;`
     */
    @property bool overflow() @safe const { return (flags & OVERFLOW_MASK) != 0; }

    /**
     * An infinity was generated by division by zero
     * Example: `x = 3/0.0;`
     */
    @property bool divByZero() @safe const { return (flags & DIVBYZERO_MASK) != 0; }

    /**
     * A machine NaN was generated.
     * Example: `x = real.infinity * 0.0;`
     */
    @property bool invalid() @safe const { return (flags & INVALID_MASK) != 0; }
}

///
@safe unittest
{
    static void func() {
        int a = 10 * 10;
    }
    pragma(inline, false) static void blockopt(ref real x) {}
    real a = 3.5;
    // Set all the flags to zero
    resetIeeeFlags();
    assert(!ieeeFlags.divByZero);
    blockopt(a); // avoid constant propagation by the optimizer
    // Perform a division by zero.
    a /= 0.0L;
    assert(a == real.infinity);
    assert(ieeeFlags.divByZero);
    blockopt(a); // avoid constant propagation by the optimizer
    // Create a NaN
    a *= 0.0L;
    assert(ieeeFlags.invalid);
    assert(isNaN(a));

    // Check that calling func() has no effect on the
    // status flags.
    IeeeFlags f = ieeeFlags;
    func();
    assert(ieeeFlags == f);
}

@safe unittest
{
    import std.meta : AliasSeq;

    static struct Test
    {
        void delegate() @trusted action;
        bool function() @trusted ieeeCheck;
    }

    static foreach (T; AliasSeq!(float, double, real))
    {{
        T x; /* Needs to be here to trick -O. It would optimize away the
            calculations if x were local to the function literals. */
        auto tests = [
            Test(
                () { x = 1; x += 0.1L; },
                () => ieeeFlags.inexact
            ),
            Test(
                () { x = T.min_normal; x /= T.max; },
                () => ieeeFlags.underflow
            ),
            Test(
                () { x = T.max; x += T.max; },
                () => ieeeFlags.overflow
            ),
            Test(
                () { x = 1; x /= 0; },
                () => ieeeFlags.divByZero
            ),
            Test(
                () { x = 0; x /= 0; },
                () => ieeeFlags.invalid
            )
        ];
        foreach (test; tests)
        {
            resetIeeeFlags();
            assert(!test.ieeeCheck());
            test.action();
            assert(test.ieeeCheck());
        }
    }}
}

/// Set all of the floating-point status flags to false.
void resetIeeeFlags() @trusted nothrow @nogc
{
    IeeeFlags.resetIeeeFlags();
}

///
@safe unittest
{
    pragma(inline, false) static void blockopt(ref real x) {}
    resetIeeeFlags();
    real a = 3.5;
    blockopt(a); // avoid constant propagation by the optimizer
    a /= 0.0L;
    blockopt(a); // avoid constant propagation by the optimizer
    assert(a == real.infinity);
    assert(ieeeFlags.divByZero);

    resetIeeeFlags();
    assert(!ieeeFlags.divByZero);
}

/// Returns: snapshot of the current state of the floating-point status flags
@property IeeeFlags ieeeFlags() @trusted pure nothrow @nogc
{
   return IeeeFlags(IeeeFlags.getIeeeFlags());
}

///
@safe nothrow unittest
{
    pragma(inline, false) static void blockopt(ref real x) {}
    resetIeeeFlags();
    real a = 3.5;
    blockopt(a); // avoid constant propagation by the optimizer

    a /= 0.0L;
    assert(a == real.infinity);
    assert(ieeeFlags.divByZero);
    blockopt(a); // avoid constant propagation by the optimizer

    a *= 0.0L;
    assert(isNaN(a));
    assert(ieeeFlags.invalid);
}

} // IeeeFlagsSupport


version (FloatingPointControlSupport)
{

/** Control the Floating point hardware

  Change the IEEE754 floating-point rounding mode and the floating-point
  hardware exceptions.

  By default, the rounding mode is roundToNearest and all hardware exceptions
  are disabled. For most applications, debugging is easier if the $(I division
  by zero), $(I overflow), and $(I invalid operation) exceptions are enabled.
  These three are combined into a $(I severeExceptions) value for convenience.
  Note in particular that if $(I invalidException) is enabled, a hardware trap
  will be generated whenever an uninitialized floating-point variable is used.

  All changes are temporary. The previous state is restored at the
  end of the scope.


Example:
----
{
    FloatingPointControl fpctrl;

    // Enable hardware exceptions for division by zero, overflow to infinity,
    // invalid operations, and uninitialized floating-point variables.
    fpctrl.enableExceptions(FloatingPointControl.severeExceptions);

    // This will generate a hardware exception, if x is a
    // default-initialized floating point variable:
    real x; // Add `= 0` or even `= real.nan` to not throw the exception.
    real y = x * 3.0;

    // The exception is only thrown for default-uninitialized NaN-s.
    // NaN-s with other payload are valid:
    real z = y * real.nan; // ok

    // The set hardware exceptions and rounding modes will be disabled when
    // leaving this scope.
}
----

 */
struct FloatingPointControl
{
nothrow @nogc:

    alias RoundingMode = uint; ///

    version (StdDdoc)
    {
        enum : RoundingMode
        {
            /** IEEE rounding modes.
             * The default mode is roundToNearest.
             *
             *  roundingMask = A mask of all rounding modes.
             */
            roundToNearest,
            roundDown, /// ditto
            roundUp, /// ditto
            roundToZero, /// ditto
            roundingMask, /// ditto
        }
    }
    else version (CRuntime_Microsoft)
    {
        // Microsoft uses hardware-incompatible custom constants in fenv.h (core.stdc.fenv).
        enum : RoundingMode
        {
            roundToNearest = 0x0000,
            roundDown      = 0x0400,
            roundUp        = 0x0800,
            roundToZero    = 0x0C00,
            roundingMask   = roundToNearest | roundDown
                             | roundUp | roundToZero,
        }
    }
    else
    {
        enum : RoundingMode
        {
            roundToNearest = core.stdc.fenv.FE_TONEAREST,
            roundDown      = core.stdc.fenv.FE_DOWNWARD,
            roundUp        = core.stdc.fenv.FE_UPWARD,
            roundToZero    = core.stdc.fenv.FE_TOWARDZERO,
            roundingMask   = roundToNearest | roundDown
                             | roundUp | roundToZero,
        }
    }

    /***
     * Change the floating-point hardware rounding mode
     *
     * Changing the rounding mode in the middle of a function can interfere
     * with optimizations of floating point expressions, as the optimizer assumes
     * that the rounding mode does not change.
     * It is best to change the rounding mode only at the
     * beginning of the function, and keep it until the function returns.
     * It is also best to add the line:
     * ---
     * pragma(inline, false);
     * ---
     * as the first line of the function so it will not get inlined.
     * Params:
     *    newMode = the new rounding mode
     */
    @property void rounding(RoundingMode newMode) @trusted
    {
        initialize();
        setControlState((getControlState() & (-1 - roundingMask)) | (newMode & roundingMask));
    }

    /// Returns: the currently active rounding mode
    @property static RoundingMode rounding() @trusted pure
    {
        return cast(RoundingMode)(getControlState() & roundingMask);
    }

    alias ExceptionMask = uint; ///

    version (StdDdoc)
    {
        enum : ExceptionMask
        {
            /** IEEE hardware exceptions.
             *  By default, all exceptions are masked (disabled).
             *
             *  severeExceptions = The overflow, division by zero, and invalid
             *  exceptions.
             */
            subnormalException,
            inexactException, /// ditto
            underflowException, /// ditto
            overflowException, /// ditto
            divByZeroException, /// ditto
            invalidException, /// ditto
            severeExceptions, /// ditto
            allExceptions, /// ditto
        }
    }
    else version (ARM_Any)
    {
        enum : ExceptionMask
        {
            subnormalException    = 0x8000,
            inexactException      = 0x1000,
            underflowException    = 0x0800,
            overflowException     = 0x0400,
            divByZeroException    = 0x0200,
            invalidException      = 0x0100,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException | subnormalException,
        }
    }
    else version (PPC_Any)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x0008,
            divByZeroException    = 0x0010,
            underflowException    = 0x0020,
            overflowException     = 0x0040,
            invalidException      = 0x0080,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException,
        }
    }
    else version (RISCV_Any)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x01,
            divByZeroException    = 0x02,
            underflowException    = 0x04,
            overflowException     = 0x08,
            invalidException      = 0x10,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException,
        }
    }
    else version (HPPA)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x01,
            underflowException    = 0x02,
            overflowException     = 0x04,
            divByZeroException    = 0x08,
            invalidException      = 0x10,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException,
        }
    }
    else version (MIPS_Any)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x0080,
            divByZeroException    = 0x0400,
            overflowException     = 0x0200,
            underflowException    = 0x0100,
            invalidException      = 0x0800,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException,
        }
    }
    else version (SPARC_Any)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x0800000,
            divByZeroException    = 0x1000000,
            overflowException     = 0x4000000,
            underflowException    = 0x2000000,
            invalidException      = 0x8000000,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException,
        }
    }
    else version (IBMZ_Any)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x08000000,
            divByZeroException    = 0x40000000,
            overflowException     = 0x20000000,
            underflowException    = 0x10000000,
            invalidException      = 0x80000000,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException,
        }
    }
    else version (X86_Any)
    {
        enum : ExceptionMask
        {
            inexactException      = 0x20,
            underflowException    = 0x10,
            overflowException     = 0x08,
            divByZeroException    = 0x04,
            subnormalException    = 0x02,
            invalidException      = 0x01,
            severeExceptions   = overflowException | divByZeroException
                                 | invalidException,
            allExceptions      = severeExceptions | underflowException
                                 | inexactException | subnormalException,
        }
    }
    else
        static assert(false, "Not implemented for this architecture");

    version (ARM_Any)
    {
        static bool hasExceptionTraps_impl() @safe
        {
            auto oldState = getControlState();
            // If exceptions are not supported, we set the bit but read it back as zero
            // https://sourceware.org/ml/libc-ports/2012-06/msg00091.html
            setControlState(oldState | divByZeroException);
            immutable result = (getControlState() & allExceptions) != 0;
            setControlState(oldState);
            return result;
        }
    }

    /// Returns: true if the current FPU supports exception trapping
    @property static bool hasExceptionTraps() @safe pure
    {
        version (X86_Any)
            return true;
        else version (PPC_Any)
            return true;
        else version (MIPS_Any)
            return true;
        else version (ARM_Any)
        {
            // The hasExceptionTraps_impl function is basically pure,
            // as it restores all global state
            auto fptr = ( () @trusted => cast(bool function() @safe
                pure nothrow @nogc)&hasExceptionTraps_impl)();
            return fptr();
        }
        else
            assert(0, "Not yet supported");
    }

    /// Enable (unmask) specific hardware exceptions. Multiple exceptions may be ORed together.
    void enableExceptions(ExceptionMask exceptions) @trusted
    {
        assert(hasExceptionTraps);
        initialize();
        version (X86_Any)
            setControlState(getControlState() & ~(exceptions & allExceptions));
        else
            setControlState(getControlState() | (exceptions & allExceptions));
    }

    /// Disable (mask) specific hardware exceptions. Multiple exceptions may be ORed together.
    void disableExceptions(ExceptionMask exceptions) @trusted
    {
        assert(hasExceptionTraps);
        initialize();
        version (X86_Any)
            setControlState(getControlState() | (exceptions & allExceptions));
        else
            setControlState(getControlState() & ~(exceptions & allExceptions));
    }

    /// Returns: the exceptions which are currently enabled (unmasked)
    @property static ExceptionMask enabledExceptions() @trusted pure
    {
        assert(hasExceptionTraps);
        version (X86_Any)
            return (getControlState() & allExceptions) ^ allExceptions;
        else
            return (getControlState() & allExceptions);
    }

    ///  Clear all pending exceptions, then restore the original exception state and rounding mode.
    ~this() @trusted
    {
        clearExceptions();
        if (initialized)
            setControlState(savedState);
    }

private:
    ControlState savedState;

    bool initialized = false;

    version (ARM_Any)
    {
        alias ControlState = uint;
    }
    else version (HPPA)
    {
        alias ControlState = uint;
    }
    else version (PPC_Any)
    {
        alias ControlState = uint;
    }
    else version (RISCV_Any)
    {
        alias ControlState = uint;
    }
    else version (MIPS_Any)
    {
        alias ControlState = uint;
    }
    else version (SPARC_Any)
    {
        alias ControlState = ulong;
    }
    else version (IBMZ_Any)
    {
        alias ControlState = uint;
    }
    else version (X86_Any)
    {
        alias ControlState = ushort;
    }
    else
        static assert(false, "Not implemented for this architecture");

    void initialize() @safe
    {
        // BUG: This works around the absence of this() constructors.
        if (initialized) return;
        clearExceptions();
        savedState = getControlState();
        initialized = true;
    }

    // Clear all pending exceptions
    static void clearExceptions() @safe
    {
        version (IeeeFlagsSupport)
            resetIeeeFlags();
        else
            static assert(false, "Not implemented for this architecture");
    }

    // Read from the control register
    package(std.math) static ControlState getControlState() @trusted pure
    {
        version (D_InlineAsm_X86)
        {
            short cont;
            asm pure nothrow @nogc
            {
                xor EAX, EAX;
                fstcw cont;
            }
            return cont;
        }
        else version (D_InlineAsm_X86_64)
        {
            short cont;
            asm pure nothrow @nogc
            {
                xor RAX, RAX;
                fstcw cont;
            }
            return cont;
        }
        else version (RISCV_Any)
        {
            mixin(`
            ControlState cont;
            asm pure nothrow @nogc
            {
                "frcsr %0" : "=r" (cont);
            }
            return cont;
            `);
        }
        else
            assert(0, "Not yet supported");
    }

    // Set the control register
    package(std.math) static void setControlState(ControlState newState) @trusted
    {
        version (InlineAsm_X86_Any)
        {
            asm nothrow @nogc
            {
                fclex;
                fldcw newState;
            }

            // Also update MXCSR, SSE's control register.
            if (haveSSE)
            {
                uint mxcsr;
                asm nothrow @nogc { stmxcsr mxcsr; }

                /* In the FPU control register, rounding mode is in bits 10 and
                11. In MXCSR it's in bits 13 and 14. */
                mxcsr &= ~(roundingMask << 3);             // delete old rounding mode
                mxcsr |= (newState & roundingMask) << 3;   // write new rounding mode

                /* In the FPU control register, masks are bits 0 through 5.
                In MXCSR they're 7 through 12. */
                mxcsr &= ~(allExceptions << 7);            // delete old masks
                mxcsr |= (newState & allExceptions) << 7;  // write new exception masks

                asm nothrow @nogc { ldmxcsr mxcsr; }
            }
        }
        else version (RISCV_Any)
        {
            mixin(`
            asm pure nothrow @nogc
            {
                "fscsr %0" : : "r" (newState);
            }
            `);
        }
        else
            assert(0, "Not yet supported");
    }
}

///
@safe unittest
{
    FloatingPointControl fpctrl;

    fpctrl.rounding = FloatingPointControl.roundDown;
    assert(lrint(1.5) == 1.0);

    fpctrl.rounding = FloatingPointControl.roundUp;
    assert(lrint(1.4) == 2.0);

    fpctrl.rounding = FloatingPointControl.roundToNearest;
    assert(lrint(1.5) == 2.0);
}

@safe unittest
{
    void ensureDefaults()
    {
        assert(FloatingPointControl.rounding
               == FloatingPointControl.roundToNearest);
        if (FloatingPointControl.hasExceptionTraps)
            assert(FloatingPointControl.enabledExceptions == 0);
    }

    {
        FloatingPointControl ctrl;
    }
    ensureDefaults();

    {
        FloatingPointControl ctrl;
        ctrl.rounding = FloatingPointControl.roundDown;
        assert(FloatingPointControl.rounding == FloatingPointControl.roundDown);
    }
    ensureDefaults();

    if (FloatingPointControl.hasExceptionTraps)
    {
        FloatingPointControl ctrl;
        ctrl.enableExceptions(FloatingPointControl.divByZeroException
                              | FloatingPointControl.overflowException);
        assert(ctrl.enabledExceptions ==
               (FloatingPointControl.divByZeroException
                | FloatingPointControl.overflowException));

        ctrl.rounding = FloatingPointControl.roundUp;
        assert(FloatingPointControl.rounding == FloatingPointControl.roundUp);
    }
    ensureDefaults();
}

@safe unittest // rounding
{
    import std.meta : AliasSeq;

    static foreach (T; AliasSeq!(float, double, real))
    {{
        /* Be careful with changing the rounding mode, it interferes
         * with common subexpressions. Changing rounding modes should
         * be done with separate functions that are not inlined.
         */

        {
            static T addRound(T)(uint rm)
            {
                pragma(inline, false) static void blockopt(ref T x) {}
                pragma(inline, false);
                FloatingPointControl fpctrl;
                fpctrl.rounding = rm;
                T x = 1;
                blockopt(x); // avoid constant propagation by the optimizer
                x += 0.1L;
                return x;
            }

            T u = addRound!(T)(FloatingPointControl.roundUp);
            T d = addRound!(T)(FloatingPointControl.roundDown);
            T z = addRound!(T)(FloatingPointControl.roundToZero);

            assert(u > d);
            assert(z == d);
        }

        {
            static T subRound(T)(uint rm)
            {
                pragma(inline, false) static void blockopt(ref T x) {}
                pragma(inline, false);
                FloatingPointControl fpctrl;
                fpctrl.rounding = rm;
                T x = -1;
                blockopt(x); // avoid constant propagation by the optimizer
                x -= 0.1L;
                return x;
            }

            T u = subRound!(T)(FloatingPointControl.roundUp);
            T d = subRound!(T)(FloatingPointControl.roundDown);
            T z = subRound!(T)(FloatingPointControl.roundToZero);

            assert(u > d);
            assert(z == u);
        }
    }}
}

} // FloatingPointControlSupport


// Functions for NaN payloads
/*
 * A 'payload' can be stored in the significand of a $(NAN). One bit is required
 * to distinguish between a quiet and a signalling $(NAN). This leaves 22 bits
 * of payload for a float; 51 bits for a double; 62 bits for an 80-bit real;
 * and 111 bits for a 128-bit quad.
*/
/**
 * Create a quiet $(NAN), storing an integer inside the payload.
 *
 * For floats, the largest possible payload is 0x3F_FFFF.
 * For doubles, it is 0x3_FFFF_FFFF_FFFF.
 * For 80-bit or 128-bit reals, it is 0x3FFF_FFFF_FFFF_FFFF.
 */
real NaN(ulong payload) @trusted pure nothrow @nogc
{
    alias F = floatTraits!(real);
    static if (F.realFormat == RealFormat.ieeeExtended ||
               F.realFormat == RealFormat.ieeeExtended53)
    {
        // real80 (in x86 real format, the implied bit is actually
        // not implied but a real bit which is stored in the real)
        ulong v = 3; // implied bit = 1, quiet bit = 1
    }
    else
    {
        ulong v = 1; // no implied bit. quiet bit = 1
    }
    if (__ctfe)
    {
        v = 1; // We use a double in CTFE.
        assert(payload >>> 51 == 0,
            "Cannot set more than 51 bits of NaN payload in CTFE.");
    }


    ulong a = payload;

    // 22 Float bits
    ulong w = a & 0x3F_FFFF;
    a -= w;

    v <<=22;
    v |= w;
    a >>=22;

    // 29 Double bits
    v <<=29;
    w = a & 0xFFF_FFFF;
    v |= w;
    a -= w;
    a >>=29;

    if (__ctfe)
    {
        v |= 0x7FF0_0000_0000_0000;
        return *cast(double*) &v;
    }
    else static if (F.realFormat == RealFormat.ieeeDouble)
    {
        v |= 0x7FF0_0000_0000_0000;
        real x;
        * cast(ulong *)(&x) = v;
        return x;
    }
    else
    {
        v <<=11;
        a &= 0x7FF;
        v |= a;
        real x = real.nan;

        // Extended real bits
        static if (F.realFormat == RealFormat.ieeeQuadruple)
        {
            v <<= 1; // there's no implicit bit

            version (LittleEndian)
            {
                *cast(ulong*)(6+cast(ubyte*)(&x)) = v;
            }
            else
            {
                *cast(ulong*)(2+cast(ubyte*)(&x)) = v;
            }
        }
        else
        {
            *cast(ulong *)(&x) = v;
        }
        return x;
    }
}

///
@safe @nogc pure nothrow unittest
{
    real a = NaN(1_000_000);
    assert(isNaN(a));
    assert(getNaNPayload(a) == 1_000_000);
}

@system pure nothrow @nogc unittest // not @safe because taking address of local.
{
    static if (floatTraits!(real).realFormat == RealFormat.ieeeDouble)
    {
        auto x = NaN(1);
        auto xl = *cast(ulong*)&x;
        assert(xl & 0x8_0000_0000_0000UL); //non-signaling bit, bit 52
        assert((xl & 0x7FF0_0000_0000_0000UL) == 0x7FF0_0000_0000_0000UL); //all exp bits set
    }
}

/**
 * Extract an integral payload from a $(NAN).
 *
 * Returns:
 * the integer payload as a ulong.
 *
 * For floats, the largest possible payload is 0x3F_FFFF.
 * For doubles, it is 0x3_FFFF_FFFF_FFFF.
 * For 80-bit or 128-bit reals, it is 0x3FFF_FFFF_FFFF_FFFF.
 */
ulong getNaNPayload(real x) @trusted pure nothrow @nogc
{
    //  assert(isNaN(x));
    alias F = floatTraits!(real);
    ulong m = void;
    if (__ctfe)
    {
        double y = x;
        m = *cast(ulong*) &y;
        // Make it look like an 80-bit significand.
        // Skip exponent, and quiet bit
        m &= 0x0007_FFFF_FFFF_FFFF;
        m <<= 11;
    }
    else static if (F.realFormat == RealFormat.ieeeDouble)
    {
        m = *cast(ulong*)(&x);
        // Make it look like an 80-bit significand.
        // Skip exponent, and quiet bit
        m &= 0x0007_FFFF_FFFF_FFFF;
        m <<= 11;
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        version (LittleEndian)
        {
            m = *cast(ulong*)(6+cast(ubyte*)(&x));
        }
        else
        {
            m = *cast(ulong*)(2+cast(ubyte*)(&x));
        }

        m >>= 1; // there's no implicit bit
    }
    else
    {
        m = *cast(ulong*)(&x);
    }

    // ignore implicit bit and quiet bit

    const ulong f = m & 0x3FFF_FF00_0000_0000L;

    ulong w = f >>> 40;
            w |= (m & 0x00FF_FFFF_F800L) << (22 - 11);
            w |= (m & 0x7FF) << 51;
            return w;
}

///
@safe @nogc pure nothrow unittest
{
    real a = NaN(1_000_000);
    assert(isNaN(a));
    assert(getNaNPayload(a) == 1_000_000);
}

@safe @nogc pure nothrow unittest
{
    enum real a = NaN(1_000_000);
    static assert(isNaN(a));
    static assert(getNaNPayload(a) == 1_000_000);
    real b = NaN(1_000_000);
    assert(isIdentical(b, a));
    // The CTFE version of getNaNPayload relies on it being impossible
    // for a CTFE-constructed NaN to have more than 51 bits of payload.
    enum nanNaN = NaN(getNaNPayload(real.nan));
    assert(isIdentical(real.nan, nanNaN));
    static if (real.init != real.init)
    {
        enum initNaN = NaN(getNaNPayload(real.init));
        assert(isIdentical(real.init, initNaN));
    }
}

debug(UnitTest)
{
    @safe pure nothrow @nogc unittest
    {
        real nan4 = NaN(0x789_ABCD_EF12_3456);
        static if (floatTraits!(real).realFormat == RealFormat.ieeeExtended
                || floatTraits!(real).realFormat == RealFormat.ieeeQuadruple)
        {
            assert(getNaNPayload(nan4) == 0x789_ABCD_EF12_3456);
        }
        else
        {
            assert(getNaNPayload(nan4) == 0x1_ABCD_EF12_3456);
        }
        double nan5 = nan4;
        assert(getNaNPayload(nan5) == 0x1_ABCD_EF12_3456);
        float nan6 = nan4;
        assert(getNaNPayload(nan6) == 0x12_3456);
        nan4 = NaN(0xFABCD);
        assert(getNaNPayload(nan4) == 0xFABCD);
        nan6 = nan4;
        assert(getNaNPayload(nan6) == 0xFABCD);
        nan5 = NaN(0x100_0000_0000_3456);
        assert(getNaNPayload(nan5) == 0x0000_0000_3456);
    }
}

/**
 * Calculate the next largest floating point value after x.
 *
 * Return the least number greater than x that is representable as a real;
 * thus, it gives the next point on the IEEE number line.
 *
 *  $(TABLE_SV
 *    $(SVH x,            nextUp(x)   )
 *    $(SV  -$(INFIN),    -real.max   )
 *    $(SV  $(PLUSMN)0.0, real.min_normal*real.epsilon )
 *    $(SV  real.max,     $(INFIN) )
 *    $(SV  $(INFIN),     $(INFIN) )
 *    $(SV  $(NAN),       $(NAN)   )
 * )
 */
real nextUp(real x) @trusted pure nothrow @nogc
{
    alias F = floatTraits!(real);
    static if (F.realFormat != RealFormat.ieeeDouble)
    {
        if (__ctfe)
        {
            if (x == -real.infinity)
                return -real.max;
            if (!(x < real.infinity)) // Infinity or NaN.
                return x;
            real delta;
            // Start with a decent estimate of delta.
            if (x <= 0x1.ffffffffffffep+1023 && x >= -double.max)
            {
                const double d = cast(double) x;
                delta = (cast(real) nextUp(d) - cast(real) d) * 0x1p-11L;
                while (x + (delta * 0x1p-100L) > x)
                    delta *= 0x1p-100L;
            }
            else
            {
                delta = 0x1p960L;
                while (!(x + delta > x) && delta < real.max * 0x1p-100L)
                    delta *= 0x1p100L;
            }
            if (x + delta > x)
            {
                while (x + (delta / 2) > x)
                    delta /= 2;
            }
            else
            {
                do { delta += delta; } while (!(x + delta > x));
            }
            if (x < 0 && x + delta == 0)
                return -0.0L;
            return x + delta;
        }
    }
    static if (F.realFormat == RealFormat.ieeeDouble)
    {
        return nextUp(cast(double) x);
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        ushort e = F.EXPMASK & (cast(ushort *)&x)[F.EXPPOS_SHORT];
        if (e == F.EXPMASK)
        {
            // NaN or Infinity
            if (x == -real.infinity) return -real.max;
            return x; // +Inf and NaN are unchanged.
        }

        auto ps = cast(ulong *)&x;
        if (ps[MANTISSA_MSB] & 0x8000_0000_0000_0000)
        {
            // Negative number
            if (ps[MANTISSA_LSB] == 0 && ps[MANTISSA_MSB] == 0x8000_0000_0000_0000)
            {
                // it was negative zero, change to smallest subnormal
                ps[MANTISSA_LSB] = 1;
                ps[MANTISSA_MSB] = 0;
                return x;
            }
            if (ps[MANTISSA_LSB] == 0) --ps[MANTISSA_MSB];
            --ps[MANTISSA_LSB];
        }
        else
        {
            // Positive number
            ++ps[MANTISSA_LSB];
            if (ps[MANTISSA_LSB] == 0) ++ps[MANTISSA_MSB];
        }
        return x;
    }
    else static if (F.realFormat == RealFormat.ieeeExtended ||
                    F.realFormat == RealFormat.ieeeExtended53)
    {
        // For 80-bit reals, the "implied bit" is a nuisance...
        ushort *pe = cast(ushort *)&x;
        ulong  *ps = cast(ulong  *)&x;
        // EPSILON is 1 for 64-bit, and 2048 for 53-bit precision reals.
        enum ulong EPSILON = 2UL ^^ (64 - real.mant_dig);

        if ((pe[F.EXPPOS_SHORT] & F.EXPMASK) == F.EXPMASK)
        {
            // First, deal with NANs and infinity
            if (x == -real.infinity) return -real.max;
            return x; // +Inf and NaN are unchanged.
        }
        if (pe[F.EXPPOS_SHORT] & 0x8000)
        {
            // Negative number -- need to decrease the significand
            *ps -= EPSILON;
            // Need to mask with 0x7FFF... so subnormals are treated correctly.
            if ((*ps & 0x7FFF_FFFF_FFFF_FFFF) == 0x7FFF_FFFF_FFFF_FFFF)
            {
                if (pe[F.EXPPOS_SHORT] == 0x8000)   // it was negative zero
                {
                    *ps = 1;
                    pe[F.EXPPOS_SHORT] = 0; // smallest subnormal.
                    return x;
                }

                --pe[F.EXPPOS_SHORT];

                if (pe[F.EXPPOS_SHORT] == 0x8000)
                    return x; // it's become a subnormal, implied bit stays low.

                *ps = 0xFFFF_FFFF_FFFF_FFFF; // set the implied bit
                return x;
            }
            return x;
        }
        else
        {
            // Positive number -- need to increase the significand.
            // Works automatically for positive zero.
            *ps += EPSILON;
            if ((*ps & 0x7FFF_FFFF_FFFF_FFFF) == 0)
            {
                // change in exponent
                ++pe[F.EXPPOS_SHORT];
                *ps = 0x8000_0000_0000_0000; // set the high bit
            }
        }
        return x;
    }
    else // static if (F.realFormat == RealFormat.ibmExtended)
    {
        assert(0, "nextUp not implemented");
    }
}

/** ditto */
double nextUp(double x) @trusted pure nothrow @nogc
{
    ulong s = *cast(ulong *)&x;

    if ((s & 0x7FF0_0000_0000_0000) == 0x7FF0_0000_0000_0000)
    {
        // First, deal with NANs and infinity
        if (x == -x.infinity) return -x.max;
        return x; // +INF and NAN are unchanged.
    }
    if (s & 0x8000_0000_0000_0000)    // Negative number
    {
        if (s == 0x8000_0000_0000_0000) // it was negative zero
        {
            s = 0x0000_0000_0000_0001; // change to smallest subnormal
            return *cast(double*) &s;
        }
        --s;
    }
    else
    {   // Positive number
        ++s;
    }
    return *cast(double*) &s;
}

/** ditto */
float nextUp(float x) @trusted pure nothrow @nogc
{
    uint s = *cast(uint *)&x;

    if ((s & 0x7F80_0000) == 0x7F80_0000)
    {
        // First, deal with NANs and infinity
        if (x == -x.infinity) return -x.max;

        return x; // +INF and NAN are unchanged.
    }
    if (s & 0x8000_0000)   // Negative number
    {
        if (s == 0x8000_0000) // it was negative zero
        {
            s = 0x0000_0001; // change to smallest subnormal
            return *cast(float*) &s;
        }

        --s;
    }
    else
    {
        // Positive number
        ++s;
    }
    return *cast(float*) &s;
}

///
@safe @nogc pure nothrow unittest
{
    assert(nextUp(1.0 - 1.0e-6).feqrel(0.999999) > 16);
    assert(nextUp(1.0 - real.epsilon).feqrel(1.0) > 16);
}

/**
 * Calculate the next smallest floating point value before x.
 *
 * Return the greatest number less than x that is representable as a real;
 * thus, it gives the previous point on the IEEE number line.
 *
 *  $(TABLE_SV
 *    $(SVH x,            nextDown(x)   )
 *    $(SV  $(INFIN),     real.max  )
 *    $(SV  $(PLUSMN)0.0, -real.min_normal*real.epsilon )
 *    $(SV  -real.max,    -$(INFIN) )
 *    $(SV  -$(INFIN),    -$(INFIN) )
 *    $(SV  $(NAN),       $(NAN)    )
 * )
 */
real nextDown(real x) @safe pure nothrow @nogc
{
    return -nextUp(-x);
}

/** ditto */
double nextDown(double x) @safe pure nothrow @nogc
{
    return -nextUp(-x);
}

/** ditto */
float nextDown(float x) @safe pure nothrow @nogc
{
    return -nextUp(-x);
}

///
@safe pure nothrow @nogc unittest
{
    assert( nextDown(1.0 + real.epsilon) == 1.0);
}

@safe pure nothrow @nogc unittest
{
    static if (floatTraits!(real).realFormat == RealFormat.ieeeExtended ||
               floatTraits!(real).realFormat == RealFormat.ieeeDouble ||
               floatTraits!(real).realFormat == RealFormat.ieeeExtended53 ||
               floatTraits!(real).realFormat == RealFormat.ieeeQuadruple)
    {
        // Tests for reals
        assert(isIdentical(nextUp(NaN(0xABC)), NaN(0xABC)));
        //static assert(isIdentical(nextUp(NaN(0xABC)), NaN(0xABC)));
        // negative numbers
        assert( nextUp(-real.infinity) == -real.max );
        assert( nextUp(-1.0L-real.epsilon) == -1.0 );
        assert( nextUp(-2.0L) == -2.0 + real.epsilon);
        static assert( nextUp(-real.infinity) == -real.max );
        static assert( nextUp(-1.0L-real.epsilon) == -1.0 );
        static assert( nextUp(-2.0L) == -2.0 + real.epsilon);
        // subnormals and zero
        assert( nextUp(-real.min_normal) == -real.min_normal*(1-real.epsilon) );
        assert( nextUp(-real.min_normal*(1-real.epsilon)) == -real.min_normal*(1-2*real.epsilon) );
        assert( isIdentical(-0.0L, nextUp(-real.min_normal*real.epsilon)) );
        assert( nextUp(-0.0L) == real.min_normal*real.epsilon );
        assert( nextUp(0.0L) == real.min_normal*real.epsilon );
        assert( nextUp(real.min_normal*(1-real.epsilon)) == real.min_normal );
        assert( nextUp(real.min_normal) == real.min_normal*(1+real.epsilon) );
        static assert( nextUp(-real.min_normal) == -real.min_normal*(1-real.epsilon) );
        static assert( nextUp(-real.min_normal*(1-real.epsilon)) == -real.min_normal*(1-2*real.epsilon) );
        static assert( -0.0L is nextUp(-real.min_normal*real.epsilon) );
        static assert( nextUp(-0.0L) == real.min_normal*real.epsilon );
        static assert( nextUp(0.0L) == real.min_normal*real.epsilon );
        static assert( nextUp(real.min_normal*(1-real.epsilon)) == real.min_normal );
        static assert( nextUp(real.min_normal) == real.min_normal*(1+real.epsilon) );
        // positive numbers
        assert( nextUp(1.0L) == 1.0 + real.epsilon );
        assert( nextUp(2.0L-real.epsilon) == 2.0 );
        assert( nextUp(real.max) == real.infinity );
        assert( nextUp(real.infinity)==real.infinity );
        static assert( nextUp(1.0L) == 1.0 + real.epsilon );
        static assert( nextUp(2.0L-real.epsilon) == 2.0 );
        static assert( nextUp(real.max) == real.infinity );
        static assert( nextUp(real.infinity)==real.infinity );
        // ctfe near double.max boundary
        static assert(nextUp(nextDown(cast(real) double.max)) == cast(real) double.max);
    }

    double n = NaN(0xABC);
    assert(isIdentical(nextUp(n), n));
    // negative numbers
    assert( nextUp(-double.infinity) == -double.max );
    assert( nextUp(-1-double.epsilon) == -1.0 );
    assert( nextUp(-2.0) == -2.0 + double.epsilon);
    // subnormals and zero

    assert( nextUp(-double.min_normal) == -double.min_normal*(1-double.epsilon) );
    assert( nextUp(-double.min_normal*(1-double.epsilon)) == -double.min_normal*(1-2*double.epsilon) );
    assert( isIdentical(-0.0, nextUp(-double.min_normal*double.epsilon)) );
    assert( nextUp(0.0) == double.min_normal*double.epsilon );
    assert( nextUp(-0.0) == double.min_normal*double.epsilon );
    assert( nextUp(double.min_normal*(1-double.epsilon)) == double.min_normal );
    assert( nextUp(double.min_normal) == double.min_normal*(1+double.epsilon) );
    // positive numbers
    assert( nextUp(1.0) == 1.0 + double.epsilon );
    assert( nextUp(2.0-double.epsilon) == 2.0 );
    assert( nextUp(double.max) == double.infinity );

    float fn = NaN(0xABC);
    assert(isIdentical(nextUp(fn), fn));
    float f = -float.min_normal*(1-float.epsilon);
    float f1 = -float.min_normal;
    assert( nextUp(f1) ==  f);
    f = 1.0f+float.epsilon;
    f1 = 1.0f;
    assert( nextUp(f1) == f );
    f1 = -0.0f;
    assert( nextUp(f1) == float.min_normal*float.epsilon);
    assert( nextUp(float.infinity)==float.infinity );

    assert(nextDown(1.0L+real.epsilon)==1.0);
    assert(nextDown(1.0+double.epsilon)==1.0);
    f = 1.0f+float.epsilon;
    assert(nextDown(f)==1.0);
    assert(nextafter(1.0+real.epsilon, -real.infinity)==1.0);

    // CTFE

    enum double ctfe_n = NaN(0xABC);
    //static assert(isIdentical(nextUp(ctfe_n), ctfe_n)); // FIXME: https://issues.dlang.org/show_bug.cgi?id=20197
    static assert(nextUp(double.nan) is double.nan);
    // negative numbers
    static assert( nextUp(-double.infinity) == -double.max );
    static assert( nextUp(-1-double.epsilon) == -1.0 );
    static assert( nextUp(-2.0) == -2.0 + double.epsilon);
    // subnormals and zero

    static assert( nextUp(-double.min_normal) == -double.min_normal*(1-double.epsilon) );
    static assert( nextUp(-double.min_normal*(1-double.epsilon)) == -double.min_normal*(1-2*double.epsilon) );
    static assert( -0.0 is nextUp(-double.min_normal*double.epsilon) );
    static assert( nextUp(0.0) == double.min_normal*double.epsilon );
    static assert( nextUp(-0.0) == double.min_normal*double.epsilon );
    static assert( nextUp(double.min_normal*(1-double.epsilon)) == double.min_normal );
    static assert( nextUp(double.min_normal) == double.min_normal*(1+double.epsilon) );
    // positive numbers
    static assert( nextUp(1.0) == 1.0 + double.epsilon );
    static assert( nextUp(2.0-double.epsilon) == 2.0 );
    static assert( nextUp(double.max) == double.infinity );

    enum float ctfe_fn = NaN(0xABC);
    //static assert(isIdentical(nextUp(ctfe_fn), ctfe_fn)); // FIXME: https://issues.dlang.org/show_bug.cgi?id=20197
    static assert(nextUp(float.nan) is float.nan);
    static assert(nextUp(-float.min_normal) == -float.min_normal*(1-float.epsilon));
    static assert(nextUp(1.0f) == 1.0f+float.epsilon);
    static assert(nextUp(-0.0f) == float.min_normal*float.epsilon);
    static assert(nextUp(float.infinity)==float.infinity);
    static assert(nextDown(1.0L+real.epsilon)==1.0);
    static assert(nextDown(1.0+double.epsilon)==1.0);
    static assert(nextDown(1.0f+float.epsilon)==1.0);
    static assert(nextafter(1.0+real.epsilon, -real.infinity)==1.0);
}



/******************************************
 * Calculates the next representable value after x in the direction of y.
 *
 * If y > x, the result will be the next largest floating-point value;
 * if y < x, the result will be the next smallest value.
 * If x == y, the result is y.
 * If x or y is a NaN, the result is a NaN.
 *
 * Remarks:
 * This function is not generally very useful; it's almost always better to use
 * the faster functions nextUp() or nextDown() instead.
 *
 * The FE_INEXACT and FE_OVERFLOW exceptions will be raised if x is finite and
 * the function result is infinite. The FE_INEXACT and FE_UNDERFLOW
 * exceptions will be raised if the function value is subnormal, and x is
 * not equal to y.
 */
T nextafter(T)(const T x, const T y) @safe pure nothrow @nogc
{
    if (x == y || isNaN(y))
    {
        return y;
    }

    if (isNaN(x))
    {
        return x;
    }

    return ((y>x) ? nextUp(x) :  nextDown(x));
}

///
@safe pure nothrow @nogc unittest
{
    float a = 1;
    assert(is(typeof(nextafter(a, a)) == float));
    assert(nextafter(a, a.infinity) > a);
    assert(isNaN(nextafter(a, a.nan)));
    assert(isNaN(nextafter(a.nan, a)));

    double b = 2;
    assert(is(typeof(nextafter(b, b)) == double));
    assert(nextafter(b, b.infinity) > b);
    assert(isNaN(nextafter(b, b.nan)));
    assert(isNaN(nextafter(b.nan, b)));

    real c = 3;
    assert(is(typeof(nextafter(c, c)) == real));
    assert(nextafter(c, c.infinity) > c);
    assert(isNaN(nextafter(c, c.nan)));
    assert(isNaN(nextafter(c.nan, c)));
}

@safe pure nothrow @nogc unittest
{
    // CTFE
    enum float a = 1;
    static assert(is(typeof(nextafter(a, a)) == float));
    static assert(nextafter(a, a.infinity) > a);
    static assert(isNaN(nextafter(a, a.nan)));
    static assert(isNaN(nextafter(a.nan, a)));

    enum double b = 2;
    static assert(is(typeof(nextafter(b, b)) == double));
    static assert(nextafter(b, b.infinity) > b);
    static assert(isNaN(nextafter(b, b.nan)));
    static assert(isNaN(nextafter(b.nan, b)));

    enum real c = 3;
    static assert(is(typeof(nextafter(c, c)) == real));
    static assert(nextafter(c, c.infinity) > c);
    static assert(isNaN(nextafter(c, c.nan)));
    static assert(isNaN(nextafter(c.nan, c)));

    enum real negZero = nextafter(+0.0L, -0.0L);
    static assert(negZero == -0.0L);
    static assert(signbit(negZero));

    static assert(nextafter(c, c) == c);
}

//real nexttoward(real x, real y) { return core.stdc.math.nexttowardl(x, y); }

/**
 * Returns the positive difference between x and y.
 *
 * Equivalent to `fmax(x-y, 0)`.
 *
 * Returns:
 *      $(TABLE_SV
 *      $(TR $(TH x, y)       $(TH fdim(x, y)))
 *      $(TR $(TD x $(GT) y)  $(TD x - y))
 *      $(TR $(TD x $(LT)= y) $(TD +0.0))
 *      )
 */
real fdim(real x, real y) @safe pure nothrow @nogc
{
    return (x < y) ? +0.0 : x - y;
}

///
@safe pure nothrow @nogc unittest
{
    assert(fdim(2.0, 0.0) == 2.0);
    assert(fdim(-2.0, 0.0) == 0.0);
    assert(fdim(real.infinity, 2.0) == real.infinity);
    assert(isNaN(fdim(real.nan, 2.0)));
    assert(isNaN(fdim(2.0, real.nan)));
    assert(isNaN(fdim(real.nan, real.nan)));
}

/**
 * Returns the larger of `x` and `y`.
 *
 * If one of the arguments is a `NaN`, the other is returned.
 *
 * See_Also: $(REF max, std,algorithm,comparison) is faster because it does not perform the `isNaN` test.
 */
F fmax(F)(const F x, const F y) @safe pure nothrow @nogc
if (__traits(isFloating, F))
{
    // Do the more predictable test first. Generates 0 branches with ldc and 1 branch with gdc.
    // See https://godbolt.org/z/erxrW9
    if (isNaN(x)) return y;
    return y > x ? y : x;
}

///
@safe pure nothrow @nogc unittest
{
    import std.meta : AliasSeq;
    static foreach (F; AliasSeq!(float, double, real))
    {
        assert(fmax(F(0.0), F(2.0)) == 2.0);
        assert(fmax(F(-2.0), 0.0) == F(0.0));
        assert(fmax(F.infinity, F(2.0)) == F.infinity);
        assert(fmax(F.nan, F(2.0)) == F(2.0));
        assert(fmax(F(2.0), F.nan) == F(2.0));
    }
}

/**
 * Returns the smaller of `x` and `y`.
 *
 * If one of the arguments is a `NaN`, the other is returned.
 *
 * See_Also: $(REF min, std,algorithm,comparison) is faster because it does not perform the `isNaN` test.
 */
F fmin(F)(const F x, const F y) @safe pure nothrow @nogc
if (__traits(isFloating, F))
{
    // Do the more predictable test first. Generates 0 branches with ldc and 1 branch with gdc.
    // See https://godbolt.org/z/erxrW9
    if (isNaN(x)) return y;
    return y < x ? y : x;
}

///
@safe pure nothrow @nogc unittest
{
    import std.meta : AliasSeq;
    static foreach (F; AliasSeq!(float, double, real))
    {
        assert(fmin(F(0.0), F(2.0)) == 0.0);
        assert(fmin(F(-2.0), F(0.0)) == -2.0);
        assert(fmin(F.infinity, F(2.0)) == 2.0);
        assert(fmin(F.nan, F(2.0)) == 2.0);
        assert(fmin(F(2.0), F.nan) == 2.0);
    }
}

/**************************************
 * Returns (x * y) + z, rounding only once according to the
 * current rounding mode.
 *
 * BUGS: Not currently implemented - rounds twice.
 */
pragma(inline, true)
real fma(real x, real y, real z) @safe pure nothrow @nogc { return (x * y) + z; }

///
@safe pure nothrow @nogc unittest
{
    assert(fma(0.0, 2.0, 2.0) == 2.0);
    assert(fma(2.0, 2.0, 2.0) == 6.0);
    assert(fma(real.infinity, 2.0, 2.0) == real.infinity);
    assert(fma(real.nan, 2.0, 2.0) is real.nan);
    assert(fma(2.0, 2.0, real.nan) is real.nan);
}

/** Computes the value of a positive integer `x`, raised to the power `n`, modulo `m`.
 *
 *  Params:
 *      x = base
 *      n = exponent
 *      m = modulus
 *
 *  Returns:
 *      `x` to the power `n`, modulo `m`.
 *      The return type is the largest of `x`'s and `m`'s type.
 *
 * The function requires that all values have unsigned types.
 */
Unqual!(Largest!(F, H)) powmod(F, G, H)(F x, G n, H m)
if (isUnsigned!F && isUnsigned!G && isUnsigned!H)
{
    import std.meta : AliasSeq;

    alias T = Unqual!(Largest!(F, H));
    static if (T.sizeof <= 4)
    {
        alias DoubleT = AliasSeq!(void, ushort, uint, void, ulong)[T.sizeof];
    }

    static T mulmod(T a, T b, T c)
    {
        static if (T.sizeof == 8)
        {
            static T addmod(T a, T b, T c)
            {
                b = c - b;
                if (a >= b)
                    return a - b;
                else
                    return c - b + a;
            }

            T result = 0, tmp;

            b %= c;
            while (a > 0)
            {
                if (a & 1)
                    result = addmod(result, b, c);

                a >>= 1;
                b = addmod(b, b, c);
            }

            return result;
        }
        else
        {
            DoubleT result = cast(DoubleT) (cast(DoubleT) a * cast(DoubleT) b);
            return result % c;
        }
    }

    T base = x, result = 1, modulus = m;
    Unqual!G exponent = n;

    while (exponent > 0)
    {
        if (exponent & 1)
            result = mulmod(result, base, modulus);

        base = mulmod(base, base, modulus);
        exponent >>= 1;
    }

    return result;
}

///
@safe pure nothrow @nogc unittest
{
    assert(powmod(1U, 10U, 3U) == 1);
    assert(powmod(3U, 2U, 6U) == 3);
    assert(powmod(5U, 5U, 15U) == 5);
    assert(powmod(2U, 3U, 5U) == 3);
    assert(powmod(2U, 4U, 5U) == 1);
    assert(powmod(2U, 5U, 5U) == 2);
}

@safe pure nothrow @nogc unittest
{
    ulong a = 18446744073709551615u, b = 20u, c = 18446744073709551610u;
    assert(powmod(a, b, c) == 95367431640625u);
    a = 100; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 18223853583554725198u);
    a = 117; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 11493139548346411394u);
    a = 134; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 10979163786734356774u);
    a = 151; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 7023018419737782840u);
    a = 168; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 58082701842386811u);
    a = 185; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 17423478386299876798u);
    a = 202; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 5522733478579799075u);
    a = 219; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 15230218982491623487u);
    a = 236; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 5198328724976436000u);

    a = 0; b = 7919; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 0);
    a = 123; b = 0; c = 18446744073709551557u;
    assert(powmod(a, b, c) == 1);

    immutable ulong a1 = 253, b1 = 7919, c1 = 18446744073709551557u;
    assert(powmod(a1, b1, c1) == 3883707345459248860u);

    uint x = 100 ,y = 7919, z = 1844674407u;
    assert(powmod(x, y, z) == 1613100340u);
    x = 134; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 734956622u);
    x = 151; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 1738696945u);
    x = 168; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 1247580927u);
    x = 185; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 1293855176u);
    x = 202; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 1566963682u);
    x = 219; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 181227807u);
    x = 236; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 217988321u);
    x = 253; y = 7919; z = 1844674407u;
    assert(powmod(x, y, z) == 1588843243u);

    x = 0; y = 7919; z = 184467u;
    assert(powmod(x, y, z) == 0);
    x = 123; y = 0; z = 1844674u;
    assert(powmod(x, y, z) == 1);

    immutable ubyte x1 = 117;
    immutable uint y1 = 7919;
    immutable uint z1 = 1844674407u;
    auto res = powmod(x1, y1, z1);
    assert(is(typeof(res) == uint));
    assert(res == 9479781u);

    immutable ushort x2 = 123;
    immutable uint y2 = 203;
    immutable ubyte z2 = 113;
    auto res2 = powmod(x2, y2, z2);
    assert(is(typeof(res2) == ushort));
    assert(res2 == 42u);
}

/**************************************
 * To what precision is x equal to y?
 *
 * Returns: the number of mantissa bits which are equal in x and y.
 * eg, 0x1.F8p+60 and 0x1.F1p+60 are equal to 5 bits of precision.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)      $(TH y)          $(TH feqrel(x, y)))
 *      $(TR $(TD x)      $(TD x)          $(TD real.mant_dig))
 *      $(TR $(TD x)      $(TD $(GT)= 2*x) $(TD 0))
 *      $(TR $(TD x)      $(TD $(LT)= x/2) $(TD 0))
 *      $(TR $(TD $(NAN)) $(TD any)        $(TD 0))
 *      $(TR $(TD any)    $(TD $(NAN))     $(TD 0))
 *      )
 */
int feqrel(X)(const X x, const X y) @trusted pure nothrow @nogc
if (isFloatingPoint!(X))
{
    /* Public Domain. Author: Don Clugston, 18 Aug 2005.
     */
    alias F = floatTraits!(X);
    static if (F.realFormat == RealFormat.ieeeSingle
            || F.realFormat == RealFormat.ieeeDouble
            || F.realFormat == RealFormat.ieeeExtended
            || F.realFormat == RealFormat.ieeeExtended53
            || F.realFormat == RealFormat.ieeeQuadruple)
    {
        if (x == y)
            return X.mant_dig; // ensure diff != 0, cope with INF.

        Unqual!X diff = fabs(x - y);

        ushort *pa = cast(ushort *)(&x);
        ushort *pb = cast(ushort *)(&y);
        ushort *pd = cast(ushort *)(&diff);


        // The difference in abs(exponent) between x or y and abs(x-y)
        // is equal to the number of significand bits of x which are
        // equal to y. If negative, x and y have different exponents.
        // If positive, x and y are equal to 'bitsdiff' bits.
        // AND with 0x7FFF to form the absolute value.
        // To avoid out-by-1 errors, we subtract 1 so it rounds down
        // if the exponents were different. This means 'bitsdiff' is
        // always 1 lower than we want, except that if bitsdiff == 0,
        // they could have 0 or 1 bits in common.

        int bitsdiff = (((  (pa[F.EXPPOS_SHORT] & F.EXPMASK)
                          + (pb[F.EXPPOS_SHORT] & F.EXPMASK)
                          - (1 << F.EXPSHIFT)) >> 1)
                        - (pd[F.EXPPOS_SHORT] & F.EXPMASK)) >> F.EXPSHIFT;
        if ( (pd[F.EXPPOS_SHORT] & F.EXPMASK) == 0)
        {   // Difference is subnormal
            // For subnormals, we need to add the number of zeros that
            // lie at the start of diff's significand.
            // We do this by multiplying by 2^^real.mant_dig
            diff *= F.RECIP_EPSILON;
            return bitsdiff + X.mant_dig - ((pd[F.EXPPOS_SHORT] & F.EXPMASK) >> F.EXPSHIFT);
        }

        if (bitsdiff > 0)
            return bitsdiff + 1; // add the 1 we subtracted before

        // Avoid out-by-1 errors when factor is almost 2.
        if (bitsdiff == 0
            && ((pa[F.EXPPOS_SHORT] ^ pb[F.EXPPOS_SHORT]) & F.EXPMASK) == 0)
        {
            return 1;
        } else return 0;
    }
    else
    {
        static assert(false, "Not implemented for this architecture");
    }
}

///
@safe pure unittest
{
    assert(feqrel(2.0, 2.0) == 53);
    assert(feqrel(2.0f, 2.0f) == 24);
    assert(feqrel(2.0, double.nan) == 0);

    // Test that numbers are within n digits of each
    // other by testing if feqrel > n * log2(10)

    // five digits
    assert(feqrel(2.0, 2.00001) > 16);
    // ten digits
    assert(feqrel(2.0, 2.00000000001) > 33);
}

@safe pure nothrow @nogc unittest
{
    void testFeqrel(F)()
    {
       // Exact equality
       assert(feqrel(F.max, F.max) == F.mant_dig);
       assert(feqrel!(F)(0.0, 0.0) == F.mant_dig);
       assert(feqrel(F.infinity, F.infinity) == F.mant_dig);

       // a few bits away from exact equality
       F w=1;
       for (int i = 1; i < F.mant_dig - 1; ++i)
       {
          assert(feqrel!(F)(1.0 + w * F.epsilon, 1.0) == F.mant_dig-i);
          assert(feqrel!(F)(1.0 - w * F.epsilon, 1.0) == F.mant_dig-i);
          assert(feqrel!(F)(1.0, 1 + (w-1) * F.epsilon) == F.mant_dig - i + 1);
          w*=2;
       }

       assert(feqrel!(F)(1.5+F.epsilon, 1.5) == F.mant_dig-1);
       assert(feqrel!(F)(1.5-F.epsilon, 1.5) == F.mant_dig-1);
       assert(feqrel!(F)(1.5-F.epsilon, 1.5+F.epsilon) == F.mant_dig-2);


       // Numbers that are close
       assert(feqrel!(F)(0x1.Bp+84, 0x1.B8p+84) == 5);
       assert(feqrel!(F)(0x1.8p+10, 0x1.Cp+10) == 2);
       assert(feqrel!(F)(1.5 * (1 - F.epsilon), 1.0L) == 2);
       assert(feqrel!(F)(1.5, 1.0) == 1);
       assert(feqrel!(F)(2 * (1 - F.epsilon), 1.0L) == 1);

       // Factors of 2
       assert(feqrel(F.max, F.infinity) == 0);
       assert(feqrel!(F)(2 * (1 - F.epsilon), 1.0L) == 1);
       assert(feqrel!(F)(1.0, 2.0) == 0);
       assert(feqrel!(F)(4.0, 1.0) == 0);

       // Extreme inequality
       assert(feqrel(F.nan, F.nan) == 0);
       assert(feqrel!(F)(0.0L, -F.nan) == 0);
       assert(feqrel(F.nan, F.infinity) == 0);
       assert(feqrel(F.infinity, -F.infinity) == 0);
       assert(feqrel(F.max, -F.max) == 0);

       assert(feqrel(F.min_normal / 8, F.min_normal / 17) == 3);

       const F Const = 2;
       immutable F Immutable = 2;
       auto Compiles = feqrel(Const, Immutable);
    }

    assert(feqrel(7.1824L, 7.1824L) == real.mant_dig);

    testFeqrel!(real)();
    testFeqrel!(double)();
    testFeqrel!(float)();
}

/**
   Computes whether a values is approximately equal to a reference value,
   admitting a maximum relative difference, and a maximum absolute difference.

   Warning:
        This template is considered out-dated. It will be removed from
        Phobos in 2.106.0. Please use $(LREF isClose) instead.

   Params:
        value = Value to compare.
        reference = Reference value.
        maxRelDiff = Maximum allowable difference relative to `reference`.
        Setting to 0.0 disables this check. Defaults to `1e-2`.
        maxAbsDiff = Maximum absolute difference. This is mainly usefull
        for comparing values to zero. Setting to 0.0 disables this check.
        Defaults to `1e-5`.

   Returns:
       `true` if `value` is approximately equal to `reference` under
       either criterium. It is sufficient, when `value ` satisfies
       one of the two criteria.

       If one item is a range, and the other is a single value, then
       the result is the logical and-ing of calling `approxEqual` on
       each element of the ranged item against the single item. If
       both items are ranges, then `approxEqual` returns `true` if
       and only if the ranges have the same number of elements and if
       `approxEqual` evaluates to `true` for each pair of elements.

    See_Also:
        Use $(LREF feqrel) to get the number of equal bits in the mantissa.
 */
deprecated("approxEqual will be removed in 2.106.0. Please use isClose instead.")
bool approxEqual(T, U, V)(T value, U reference, V maxRelDiff = 1e-2, V maxAbsDiff = 1e-5)
{
    import std.range.primitives : empty, front, isInputRange, popFront;
    static if (isInputRange!T)
    {
        static if (isInputRange!U)
        {
            // Two ranges
            for (;; value.popFront(), reference.popFront())
            {
                if (value.empty) return reference.empty;
                if (reference.empty) return value.empty;
                if (!approxEqual(value.front, reference.front, maxRelDiff, maxAbsDiff))
                    return false;
            }
        }
        else static if (isIntegral!U)
        {
            // convert reference to real
            return approxEqual(value, real(reference), maxRelDiff, maxAbsDiff);
        }
        else
        {
            // value is range, reference is number
            for (; !value.empty; value.popFront())
            {
                if (!approxEqual(value.front, reference, maxRelDiff, maxAbsDiff))
                    return false;
            }
            return true;
        }
    }
    else
    {
        static if (isInputRange!U)
        {
            // value is number, reference is range
            for (; !reference.empty; reference.popFront())
            {
                if (!approxEqual(value, reference.front, maxRelDiff, maxAbsDiff))
                    return false;
            }
            return true;
        }
        else static if (isIntegral!T || isIntegral!U)
        {
            // convert both value and reference to real
            return approxEqual(real(value), real(reference), maxRelDiff, maxAbsDiff);
        }
        else
        {
            // two numbers
            //static assert(is(T : real) && is(U : real));
            if (reference == 0)
            {
                return fabs(value) <= maxAbsDiff;
            }
            static if (is(typeof(value.infinity)) && is(typeof(reference.infinity)))
            {
                if (value == value.infinity && reference == reference.infinity ||
                    value == -value.infinity && reference == -reference.infinity) return true;
            }
            return fabs((value - reference) / reference) <= maxRelDiff
                || maxAbsDiff != 0 && fabs(value - reference) <= maxAbsDiff;
        }
    }
}

deprecated @safe pure nothrow unittest
{
    assert(approxEqual(1.0, 1.0099));
    assert(!approxEqual(1.0, 1.011));
    assert(approxEqual(0.00001, 0.0));
    assert(!approxEqual(0.00002, 0.0));

    assert(approxEqual(3.0, [3, 3.01, 2.99])); // several reference values is strange
    assert(approxEqual([3, 3.01, 2.99], 3.0)); // better

    float[] arr1 = [ 1.0, 2.0, 3.0 ];
    double[] arr2 = [ 1.001, 1.999, 3 ];
    assert(approxEqual(arr1, arr2));
}

deprecated @safe pure nothrow unittest
{
    // relative comparison depends on reference, make sure proper
    // side is used when comparing range to single value. Based on
    // https://issues.dlang.org/show_bug.cgi?id=15763
    auto a = [2e-3 - 1e-5];
    auto b = 2e-3 + 1e-5;
    assert(a[0].approxEqual(b));
    assert(!b.approxEqual(a[0]));
    assert(a.approxEqual(b));
    assert(!b.approxEqual(a));
}

deprecated @safe pure nothrow @nogc unittest
{
    assert(!approxEqual(0.0,1e-15,1e-9,0.0));
    assert(approxEqual(0.0,1e-15,1e-9,1e-9));
    assert(!approxEqual(1.0,3.0,0.0,1.0));

    assert(approxEqual(1.00000000099,1.0,1e-9,0.0));
    assert(!approxEqual(1.0000000011,1.0,1e-9,0.0));
}

deprecated @safe pure nothrow @nogc unittest
{
    // maybe unintuitive behavior
    assert(approxEqual(1000.0,1010.0));
    assert(approxEqual(9_090_000_000.0,9_000_000_000.0));
    assert(approxEqual(0.0,1e30,1.0));
    assert(approxEqual(0.00001,1e-30));
    assert(!approxEqual(-1e-30,1e-30,1e-2,0.0));
}

deprecated @safe pure nothrow @nogc unittest
{
    int a = 10;
    assert(approxEqual(10, a));

    assert(!approxEqual(3, 0));
    assert(approxEqual(3, 3));
    assert(approxEqual(3.0, 3));
    assert(approxEqual(3, 3.0));

    assert(approxEqual(0.0,0.0));
    assert(approxEqual(-0.0,0.0));
    assert(approxEqual(0.0f,0.0));
}

deprecated @safe pure nothrow @nogc unittest
{
    real num = real.infinity;
    assert(num == real.infinity);
    assert(approxEqual(num, real.infinity));
    num = -real.infinity;
    assert(num == -real.infinity);
    assert(approxEqual(num, -real.infinity));

    assert(!approxEqual(1,real.nan));
    assert(!approxEqual(real.nan,real.max));
    assert(!approxEqual(real.nan,real.nan));
}

deprecated @safe pure nothrow unittest
{
    assert(!approxEqual([1.0,2.0,3.0],[1.0,2.0]));
    assert(!approxEqual([1.0,2.0],[1.0,2.0,3.0]));

    assert(approxEqual!(real[],real[])([],[]));
    assert(approxEqual(cast(real[])[],cast(real[])[]));
}


/**
   Computes whether two values are approximately equal, admitting a maximum
   relative difference, and a maximum absolute difference.

   Params:
        lhs = First item to compare.
        rhs = Second item to compare.
        maxRelDiff = Maximum allowable relative difference.
        Setting to 0.0 disables this check. Default depends on the type of
        `lhs` and `rhs`: It is approximately half the number of decimal digits of
        precision of the smaller type.
        maxAbsDiff = Maximum absolute difference. This is mainly usefull
        for comparing values to zero. Setting to 0.0 disables this check.
        Defaults to `0.0`.

   Returns:
       `true` if the two items are approximately equal under either criterium.
       It is sufficient, when `value ` satisfies one of the two criteria.

       If one item is a range, and the other is a single value, then
       the result is the logical and-ing of calling `isClose` on
       each element of the ranged item against the single item. If
       both items are ranges, then `isClose` returns `true` if
       and only if the ranges have the same number of elements and if
       `isClose` evaluates to `true` for each pair of elements.

    See_Also:
        Use $(LREF feqrel) to get the number of equal bits in the mantissa.
 */
bool isClose(T, U, V = CommonType!(FloatingPointBaseType!T,FloatingPointBaseType!U))
    (T lhs, U rhs, V maxRelDiff = CommonDefaultFor!(T,U), V maxAbsDiff = 0.0)
{
    import std.range.primitives : empty, front, isInputRange, popFront;
    import std.complex : Complex;
    static if (isInputRange!T)
    {
        static if (isInputRange!U)
        {
            // Two ranges
            for (;; lhs.popFront(), rhs.popFront())
            {
                if (lhs.empty) return rhs.empty;
                if (rhs.empty) return lhs.empty;
                if (!isClose(lhs.front, rhs.front, maxRelDiff, maxAbsDiff))
                    return false;
            }
        }
        else
        {
            // lhs is range, rhs is number
            for (; !lhs.empty; lhs.popFront())
            {
                if (!isClose(lhs.front, rhs, maxRelDiff, maxAbsDiff))
                    return false;
            }
            return true;
        }
    }
    else static if (isInputRange!U)
    {
        // lhs is number, rhs is range
        for (; !rhs.empty; rhs.popFront())
        {
            if (!isClose(lhs, rhs.front, maxRelDiff, maxAbsDiff))
                return false;
        }
        return true;
    }
    else static if (is(T TE == Complex!TE))
    {
        static if (is(U UE == Complex!UE))
        {
            // Two complex numbers
            return isClose(lhs.re, rhs.re, maxRelDiff, maxAbsDiff)
                && isClose(lhs.im, rhs.im, maxRelDiff, maxAbsDiff);
        }
        else
        {
            // lhs is complex, rhs is number
            return isClose(lhs.re, rhs, maxRelDiff, maxAbsDiff)
                && isClose(lhs.im, 0.0, maxRelDiff, maxAbsDiff);
        }
    }
    else static if (is(U UE == Complex!UE))
    {
        // lhs is number, rhs is complex
        return isClose(lhs, rhs.re, maxRelDiff, maxAbsDiff)
            && isClose(0.0, rhs.im, maxRelDiff, maxAbsDiff);
    }
    else
    {
        // two numbers
        if (lhs == rhs) return true;

        static if (is(typeof(lhs.infinity)) && is(typeof(rhs.infinity)))
        {
            if (lhs == lhs.infinity || rhs == rhs.infinity ||
                lhs == -lhs.infinity || rhs == -rhs.infinity) return false;
        }

        auto diff = abs(lhs - rhs);

        return diff <= maxRelDiff*abs(lhs)
            || diff <= maxRelDiff*abs(rhs)
            || diff <= maxAbsDiff;
    }
}

///
@safe pure nothrow @nogc unittest
{
    assert(isClose(1.0,0.999_999_999));
    assert(isClose(0.001, 0.000_999_999_999));
    assert(isClose(1_000_000_000.0,999_999_999.0));

    assert(isClose(17.123_456_789, 17.123_456_78));
    assert(!isClose(17.123_456_789, 17.123_45));

    // use explicit 3rd parameter for less (or more) accuracy
    assert(isClose(17.123_456_789, 17.123_45, 1e-6));
    assert(!isClose(17.123_456_789, 17.123_45, 1e-7));

    // use 4th parameter when comparing close to zero
    assert(!isClose(1e-100, 0.0));
    assert(isClose(1e-100, 0.0, 0.0, 1e-90));
    assert(!isClose(1e-10, -1e-10));
    assert(isClose(1e-10, -1e-10, 0.0, 1e-9));
    assert(!isClose(1e-300, 1e-298));
    assert(isClose(1e-300, 1e-298, 0.0, 1e-200));

    // different default limits for different floating point types
    assert(isClose(1.0f, 0.999_99f));
    assert(!isClose(1.0, 0.999_99));
    static if (real.sizeof > double.sizeof)
        assert(!isClose(1.0L, 0.999_999_999L));
}

///
@safe pure nothrow unittest
{
    assert(isClose([1.0, 2.0, 3.0], [0.999_999_999, 2.000_000_001, 3.0]));
    assert(!isClose([1.0, 2.0], [0.999_999_999, 2.000_000_001, 3.0]));
    assert(!isClose([1.0, 2.0, 3.0], [0.999_999_999, 2.000_000_001]));

    assert(isClose([2.0, 1.999_999_999, 2.000_000_001], 2.0));
    assert(isClose(2.0, [2.0, 1.999_999_999, 2.000_000_001]));
}

@safe pure nothrow unittest
{
    assert(!isClose([1.0, 2.0, 3.0], [0.999_999_999, 3.0, 3.0]));
    assert(!isClose([2.0, 1.999_999, 2.000_000_001], 2.0));
    assert(!isClose(2.0, [2.0, 1.999_999_999, 2.000_000_999]));
}

@safe pure nothrow @nogc unittest
{
    immutable a = 1.00001f;
    const b = 1.000019;
    assert(isClose(a,b));

    assert(isClose(1.00001f,1.000019f));
    assert(isClose(1.00001f,1.000019));
    assert(isClose(1.00001,1.000019f));
    assert(!isClose(1.00001,1.000019));

    real a1 = 1e-300L;
    real a2 = a1.nextUp;
    assert(isClose(a1,a2));
}

@safe pure nothrow unittest
{
    float[] arr1 = [ 1.0, 2.0, 3.0 ];
    double[] arr2 = [ 1.00001, 1.99999, 3 ];
    assert(isClose(arr1, arr2));
}

@safe pure nothrow @nogc unittest
{
    assert(!isClose(1000.0,1010.0));
    assert(!isClose(9_090_000_000.0,9_000_000_000.0));
    assert(isClose(0.0,1e30,1.0));
    assert(!isClose(0.00001,1e-30));
    assert(!isClose(-1e-30,1e-30,1e-2,0.0));
}

@safe pure nothrow @nogc unittest
{
    assert(!isClose(3, 0));
    assert(isClose(3, 3));
    assert(isClose(3.0, 3));
    assert(isClose(3, 3.0));

    assert(isClose(0.0,0.0));
    assert(isClose(-0.0,0.0));
    assert(isClose(0.0f,0.0));
}

@safe pure nothrow @nogc unittest
{
    real num = real.infinity;
    assert(num == real.infinity);
    assert(isClose(num, real.infinity));
    num = -real.infinity;
    assert(num == -real.infinity);
    assert(isClose(num, -real.infinity));

    assert(!isClose(1,real.nan));
    assert(!isClose(real.nan,real.max));
    assert(!isClose(real.nan,real.nan));
}

@safe pure nothrow @nogc unittest
{
    assert(isClose!(real[],real[],real)([],[]));
    assert(isClose(cast(real[])[],cast(real[])[]));
}

@safe pure nothrow @nogc unittest
{
    import std.conv : to;

    float f = 31.79f;
    double d = 31.79;
    double f2d = f.to!double;

    assert(isClose(f,f2d));
    assert(!isClose(d,f2d));
}

@safe pure nothrow @nogc unittest
{
    import std.conv : to;

    double d = 31.79;
    float f = d.to!float;
    double f2d = f.to!double;

    assert(isClose(f,f2d));
    assert(!isClose(d,f2d));
    assert(isClose(d,f2d,1e-4));
}

package(std.math) template CommonDefaultFor(T,U)
{
    import std.algorithm.comparison : min;

    alias baseT = FloatingPointBaseType!T;
    alias baseU = FloatingPointBaseType!U;

    enum CommonType!(baseT, baseU) CommonDefaultFor = 10.0L ^^ -((min(baseT.dig, baseU.dig) + 1) / 2 + 1);
}

private template FloatingPointBaseType(T)
{
    import std.range.primitives : ElementType;
    static if (isFloatingPoint!T)
    {
        alias FloatingPointBaseType = Unqual!T;
    }
    else static if (isFloatingPoint!(ElementType!(Unqual!T)))
    {
        alias FloatingPointBaseType = Unqual!(ElementType!(Unqual!T));
    }
    else
    {
        alias FloatingPointBaseType = real;
    }
}


@safe pure nothrow @nogc unittest
{
    float f = sqrt(2.0f);
    assert(fabs(f * f - 2.0f) < .00001);

    double d = sqrt(2.0);
    assert(fabs(d * d - 2.0) < .00001);

    real r = sqrt(2.0L);
    assert(fabs(r * r - 2.0) < .00001);
}

@safe pure nothrow @nogc unittest
{
    float f = fabs(-2.0f);
    assert(f == 2);

    double d = fabs(-2.0);
    assert(d == 2);

    real r = fabs(-2.0L);
    assert(r == 2);
}

@safe pure nothrow @nogc unittest
{
    float f = sin(-2.0f);
    assert(fabs(f - -0.909297f) < .00001);

    double d = sin(-2.0);
    assert(fabs(d - -0.909297f) < .00001);

    real r = sin(-2.0L);
    assert(fabs(r - -0.909297f) < .00001);
}

@safe pure nothrow @nogc unittest
{
    float f = cos(-2.0f);
    assert(fabs(f - -0.416147f) < .00001);

    double d = cos(-2.0);
    assert(fabs(d - -0.416147f) < .00001);

    real r = cos(-2.0L);
    assert(fabs(r - -0.416147f) < .00001);
}

@safe pure nothrow @nogc unittest
{
    float f = tan(-2.0f);
    assert(fabs(f - 2.18504f) < .00001);

    double d = tan(-2.0);
    assert(fabs(d - 2.18504f) < .00001);

    real r = tan(-2.0L);
    assert(fabs(r - 2.18504f) < .00001);

    // Verify correct behavior for large inputs
    assert(!isNaN(tan(0x1p63)));
    assert(!isNaN(tan(-0x1p63)));
    static if (real.mant_dig >= 64)
    {
        assert(!isNaN(tan(0x1p300L)));
        assert(!isNaN(tan(-0x1p300L)));
    }
}

/***********************************
 * Defines a total order on all floating-point numbers.
 *
 * The order is defined as follows:
 * $(UL
 *      $(LI All numbers in [-$(INFIN), +$(INFIN)] are ordered
 *          the same way as by built-in comparison, with the exception of
 *          -0.0, which is less than +0.0;)
 *      $(LI If the sign bit is set (that is, it's 'negative'), $(NAN) is less
 *          than any number; if the sign bit is not set (it is 'positive'),
 *          $(NAN) is greater than any number;)
 *      $(LI $(NAN)s of the same sign are ordered by the payload ('negative'
 *          ones - in reverse order).)
 * )
 *
 * Returns:
 *      negative value if `x` precedes `y` in the order specified above;
 *      0 if `x` and `y` are identical, and positive value otherwise.
 *
 * See_Also:
 *      $(MYREF isIdentical)
 * Standards: Conforms to IEEE 754-2008
 */
int cmp(T)(const(T) x, const(T) y) @nogc @trusted pure nothrow
if (isFloatingPoint!T)
{
    alias F = floatTraits!T;

    static if (F.realFormat == RealFormat.ieeeSingle
               || F.realFormat == RealFormat.ieeeDouble)
    {
        static if (T.sizeof == 4)
            alias UInt = uint;
        else
            alias UInt = ulong;

        union Repainter
        {
            T number;
            UInt bits;
        }

        enum msb = ~(UInt.max >>> 1);

        import std.typecons : Tuple;
        Tuple!(Repainter, Repainter) vars = void;
        vars[0].number = x;
        vars[1].number = y;

        foreach (ref var; vars)
            if (var.bits & msb)
                var.bits = ~var.bits;
            else
                var.bits |= msb;

        if (vars[0].bits < vars[1].bits)
            return -1;
        else if (vars[0].bits > vars[1].bits)
            return 1;
        else
            return 0;
    }
    else static if (F.realFormat == RealFormat.ieeeExtended53
                    || F.realFormat == RealFormat.ieeeExtended
                    || F.realFormat == RealFormat.ieeeQuadruple)
    {
        static if (F.realFormat == RealFormat.ieeeQuadruple)
            alias RemT = ulong;
        else
            alias RemT = ushort;

        struct Bits
        {
            ulong bulk;
            RemT rem;
        }

        union Repainter
        {
            T number;
            Bits bits;
            ubyte[T.sizeof] bytes;
        }

        import std.typecons : Tuple;
        Tuple!(Repainter, Repainter) vars = void;
        vars[0].number = x;
        vars[1].number = y;

        foreach (ref var; vars)
            if (var.bytes[F.SIGNPOS_BYTE] & 0x80)
            {
                var.bits.bulk = ~var.bits.bulk;
                var.bits.rem = cast(typeof(var.bits.rem))(-1 - var.bits.rem); // ~var.bits.rem
            }
            else
            {
                var.bytes[F.SIGNPOS_BYTE] |= 0x80;
            }

        version (LittleEndian)
        {
            if (vars[0].bits.rem < vars[1].bits.rem)
                return -1;
            else if (vars[0].bits.rem > vars[1].bits.rem)
                return 1;
            else if (vars[0].bits.bulk < vars[1].bits.bulk)
                return -1;
            else if (vars[0].bits.bulk > vars[1].bits.bulk)
                return 1;
            else
                return 0;
        }
        else
        {
            if (vars[0].bits.bulk < vars[1].bits.bulk)
                return -1;
            else if (vars[0].bits.bulk > vars[1].bits.bulk)
                return 1;
            else if (vars[0].bits.rem < vars[1].bits.rem)
                return -1;
            else if (vars[0].bits.rem > vars[1].bits.rem)
                return 1;
            else
                return 0;
        }
    }
    else
    {
        // IBM Extended doubledouble does not follow the general
        // sign-exponent-significand layout, so has to be handled generically

        const int xSign = signbit(x),
            ySign = signbit(y);

        if (xSign == 1 && ySign == 1)
            return cmp(-y, -x);
        else if (xSign == 1)
            return -1;
        else if (ySign == 1)
            return 1;
        else if (x < y)
            return -1;
        else if (x == y)
            return 0;
        else if (x > y)
            return 1;
        else if (isNaN(x) && !isNaN(y))
            return 1;
        else if (isNaN(y) && !isNaN(x))
            return -1;
        else if (getNaNPayload(x) < getNaNPayload(y))
            return -1;
        else if (getNaNPayload(x) > getNaNPayload(y))
            return 1;
        else
            return 0;
    }
}

/// Most numbers are ordered naturally.
@safe unittest
{
    assert(cmp(-double.infinity, -double.max) < 0);
    assert(cmp(-double.max, -100.0) < 0);
    assert(cmp(-100.0, -0.5) < 0);
    assert(cmp(-0.5, 0.0) < 0);
    assert(cmp(0.0, 0.5) < 0);
    assert(cmp(0.5, 100.0) < 0);
    assert(cmp(100.0, double.max) < 0);
    assert(cmp(double.max, double.infinity) < 0);

    assert(cmp(1.0, 1.0) == 0);
}

/// Positive and negative zeroes are distinct.
@safe unittest
{
    assert(cmp(-0.0, +0.0) < 0);
    assert(cmp(+0.0, -0.0) > 0);
}

/// Depending on the sign, $(NAN)s go to either end of the spectrum.
@safe unittest
{
    assert(cmp(-double.nan, -double.infinity) < 0);
    assert(cmp(double.infinity, double.nan) < 0);
    assert(cmp(-double.nan, double.nan) < 0);
}

/// $(NAN)s of the same sign are ordered by the payload.
@safe unittest
{
    assert(cmp(NaN(10), NaN(20)) < 0);
    assert(cmp(-NaN(20), -NaN(10)) < 0);
}

@safe unittest
{
    import std.meta : AliasSeq;
    static foreach (T; AliasSeq!(float, double, real))
    {{
        T[] values = [-cast(T) NaN(20), -cast(T) NaN(10), -T.nan, -T.infinity,
                      -T.max, -T.max / 2, T(-16.0), T(-1.0).nextDown,
                      T(-1.0), T(-1.0).nextUp,
                      T(-0.5), -T.min_normal, (-T.min_normal).nextUp,
                      -2 * T.min_normal * T.epsilon,
                      -T.min_normal * T.epsilon,
                      T(-0.0), T(0.0),
                      T.min_normal * T.epsilon,
                      2 * T.min_normal * T.epsilon,
                      T.min_normal.nextDown, T.min_normal, T(0.5),
                      T(1.0).nextDown, T(1.0),
                      T(1.0).nextUp, T(16.0), T.max / 2, T.max,
                      T.infinity, T.nan, cast(T) NaN(10), cast(T) NaN(20)];

        foreach (i, x; values)
        {
            foreach (y; values[i + 1 .. $])
            {
                assert(cmp(x, y) < 0);
                assert(cmp(y, x) > 0);
            }
            assert(cmp(x, x) == 0);
        }
    }}
}

package(std): // Not public yet
/* Return the value that lies halfway between x and y on the IEEE number line.
 *
 * Formally, the result is the arithmetic mean of the binary significands of x
 * and y, multiplied by the geometric mean of the binary exponents of x and y.
 * x and y must have the same sign, and must not be NaN.
 * Note: this function is useful for ensuring O(log n) behaviour in algorithms
 * involving a 'binary chop'.
 *
 * Special cases:
 * If x and y are within a factor of 2, (ie, feqrel(x, y) > 0), the return value
 * is the arithmetic mean (x + y) / 2.
 * If x and y are even powers of 2, the return value is the geometric mean,
 *   ieeeMean(x, y) = sqrt(x * y).
 *
 */
T ieeeMean(T)(const T x, const T y)  @trusted pure nothrow @nogc
in
{
    // both x and y must have the same sign, and must not be NaN.
    assert(signbit(x) == signbit(y));
    assert(x == x && y == y);
}
do
{
    // Runtime behaviour for contract violation:
    // If signs are opposite, or one is a NaN, return 0.
    if (!((x >= 0 && y >= 0) || (x <= 0 && y <= 0))) return 0.0;

    // The implementation is simple: cast x and y to integers,
    // average them (avoiding overflow), and cast the result back to a floating-point number.

    alias F = floatTraits!(T);
    T u;
    static if (F.realFormat == RealFormat.ieeeExtended ||
               F.realFormat == RealFormat.ieeeExtended53)
    {
        // There's slight additional complexity because they are actually
        // 79-bit reals...
        ushort *ue = cast(ushort *)&u;
        ulong *ul = cast(ulong *)&u;
        ushort *xe = cast(ushort *)&x;
        ulong *xl = cast(ulong *)&x;
        ushort *ye = cast(ushort *)&y;
        ulong *yl = cast(ulong *)&y;

        // Ignore the useless implicit bit. (Bonus: this prevents overflows)
        ulong m = ((*xl) & 0x7FFF_FFFF_FFFF_FFFFL) + ((*yl) & 0x7FFF_FFFF_FFFF_FFFFL);

        // @@@ BUG? @@@
        // Cast shouldn't be here
        ushort e = cast(ushort) ((xe[F.EXPPOS_SHORT] & F.EXPMASK)
                                 + (ye[F.EXPPOS_SHORT] & F.EXPMASK));
        if (m & 0x8000_0000_0000_0000L)
        {
            ++e;
            m &= 0x7FFF_FFFF_FFFF_FFFFL;
        }
        // Now do a multi-byte right shift
        const uint c = e & 1; // carry
        e >>= 1;
        m >>>= 1;
        if (c)
            m |= 0x4000_0000_0000_0000L; // shift carry into significand
        if (e)
            *ul = m | 0x8000_0000_0000_0000L; // set implicit bit...
        else
            *ul = m; // ... unless exponent is 0 (subnormal or zero).

        ue[4]= e | (xe[F.EXPPOS_SHORT]& 0x8000); // restore sign bit
    }
    else static if (F.realFormat == RealFormat.ieeeQuadruple)
    {
        // This would be trivial if 'ucent' were implemented...
        ulong *ul = cast(ulong *)&u;
        ulong *xl = cast(ulong *)&x;
        ulong *yl = cast(ulong *)&y;

        // Multi-byte add, then multi-byte right shift.
        import core.checkedint : addu;
        bool carry;
        ulong ml = addu(xl[MANTISSA_LSB], yl[MANTISSA_LSB], carry);

        ulong mh = carry + (xl[MANTISSA_MSB] & 0x7FFF_FFFF_FFFF_FFFFL) +
            (yl[MANTISSA_MSB] & 0x7FFF_FFFF_FFFF_FFFFL);

        ul[MANTISSA_MSB] = (mh >>> 1) | (xl[MANTISSA_MSB] & 0x8000_0000_0000_0000);
        ul[MANTISSA_LSB] = (ml >>> 1) | (mh & 1) << 63;
    }
    else static if (F.realFormat == RealFormat.ieeeDouble)
    {
        ulong *ul = cast(ulong *)&u;
        ulong *xl = cast(ulong *)&x;
        ulong *yl = cast(ulong *)&y;
        ulong m = (((*xl) & 0x7FFF_FFFF_FFFF_FFFFL)
                   + ((*yl) & 0x7FFF_FFFF_FFFF_FFFFL)) >>> 1;
        m |= ((*xl) & 0x8000_0000_0000_0000L);
        *ul = m;
    }
    else static if (F.realFormat == RealFormat.ieeeSingle)
    {
        uint *ul = cast(uint *)&u;
        uint *xl = cast(uint *)&x;
        uint *yl = cast(uint *)&y;
        uint m = (((*xl) & 0x7FFF_FFFF) + ((*yl) & 0x7FFF_FFFF)) >>> 1;
        m |= ((*xl) & 0x8000_0000);
        *ul = m;
    }
    else
    {
        assert(0, "Not implemented");
    }
    return u;
}

@safe pure nothrow @nogc unittest
{
    assert(ieeeMean(-0.0,-1e-20)<0);
    assert(ieeeMean(0.0,1e-20)>0);

    assert(ieeeMean(1.0L,4.0L)==2L);
    assert(ieeeMean(2.0*1.013,8.0*1.013)==4*1.013);
    assert(ieeeMean(-1.0L,-4.0L)==-2L);
    assert(ieeeMean(-1.0,-4.0)==-2);
    assert(ieeeMean(-1.0f,-4.0f)==-2f);
    assert(ieeeMean(-1.0,-2.0)==-1.5);
    assert(ieeeMean(-1*(1+8*real.epsilon),-2*(1+8*real.epsilon))
                 ==-1.5*(1+5*real.epsilon));
    assert(ieeeMean(0x1p60,0x1p-10)==0x1p25);

    static if (floatTraits!(real).realFormat == RealFormat.ieeeExtended)
    {
      assert(ieeeMean(1.0L,real.infinity)==0x1p8192L);
      assert(ieeeMean(0.0L,real.infinity)==1.5);
    }
    assert(ieeeMean(0.5*real.min_normal*(1-4*real.epsilon),0.5*real.min_normal)
           == 0.5*real.min_normal*(1-2*real.epsilon));
}


// The following IEEE 'real' formats are currently supported.
version (LittleEndian)
{
    static assert(real.mant_dig == 53 || real.mant_dig == 64
               || real.mant_dig == 113,
      "Only 64-bit, 80-bit, and 128-bit reals"~
      " are supported for LittleEndian CPUs");
}
else
{
    static assert(real.mant_dig == 53 || real.mant_dig == 113,
    "Only 64-bit and 128-bit reals are supported for BigEndian CPUs.");
}

// Underlying format exposed through floatTraits
enum RealFormat
{
    ieeeHalf,
    ieeeSingle,
    ieeeDouble,
    ieeeExtended,   // x87 80-bit real
    ieeeExtended53, // x87 real rounded to precision of double.
    ibmExtended,    // IBM 128-bit extended
    ieeeQuadruple,
}

// Constants used for extracting the components of the representation.
// They supplement the built-in floating point properties.
template floatTraits(T)
{
    // EXPMASK is a ushort mask to select the exponent portion (without sign)
    // EXPSHIFT is the number of bits the exponent is left-shifted by in its ushort
    // EXPBIAS is the exponent bias - 1 (exp == EXPBIAS yields ×2^-1).
    // EXPPOS_SHORT is the index of the exponent when represented as a ushort array.
    // SIGNPOS_BYTE is the index of the sign when represented as a ubyte array.
    // RECIP_EPSILON is the value such that (smallest_subnormal) * RECIP_EPSILON == T.min_normal
    enum Unqual!T RECIP_EPSILON = (1/T.epsilon);
    static if (T.mant_dig == 24)
    {
        // Single precision float
        enum ushort EXPMASK = 0x7F80;
        enum ushort EXPSHIFT = 7;
        enum ushort EXPBIAS = 0x3F00;
        enum uint EXPMASK_INT = 0x7F80_0000;
        enum uint MANTISSAMASK_INT = 0x007F_FFFF;
        enum realFormat = RealFormat.ieeeSingle;
        version (LittleEndian)
        {
            enum EXPPOS_SHORT = 1;
            enum SIGNPOS_BYTE = 3;
        }
        else
        {
            enum EXPPOS_SHORT = 0;
            enum SIGNPOS_BYTE = 0;
        }
    }
    else static if (T.mant_dig == 53)
    {
        static if (T.sizeof == 8)
        {
            // Double precision float, or real == double
            enum ushort EXPMASK = 0x7FF0;
            enum ushort EXPSHIFT = 4;
            enum ushort EXPBIAS = 0x3FE0;
            enum uint EXPMASK_INT = 0x7FF0_0000;
            enum uint MANTISSAMASK_INT = 0x000F_FFFF; // for the MSB only
            enum realFormat = RealFormat.ieeeDouble;
            version (LittleEndian)
            {
                enum EXPPOS_SHORT = 3;
                enum SIGNPOS_BYTE = 7;
            }
            else
            {
                enum EXPPOS_SHORT = 0;
                enum SIGNPOS_BYTE = 0;
            }
        }
        else static if (T.sizeof == 12)
        {
            // Intel extended real80 rounded to double
            enum ushort EXPMASK = 0x7FFF;
            enum ushort EXPSHIFT = 0;
            enum ushort EXPBIAS = 0x3FFE;
            enum realFormat = RealFormat.ieeeExtended53;
            version (LittleEndian)
            {
                enum EXPPOS_SHORT = 4;
                enum SIGNPOS_BYTE = 9;
            }
            else
            {
                enum EXPPOS_SHORT = 0;
                enum SIGNPOS_BYTE = 0;
            }
        }
        else
            static assert(false, "No traits support for " ~ T.stringof);
    }
    else static if (T.mant_dig == 64)
    {
        // Intel extended real80
        enum ushort EXPMASK = 0x7FFF;
        enum ushort EXPSHIFT = 0;
        enum ushort EXPBIAS = 0x3FFE;
        enum realFormat = RealFormat.ieeeExtended;
        version (LittleEndian)
        {
            enum EXPPOS_SHORT = 4;
            enum SIGNPOS_BYTE = 9;
        }
        else
        {
            enum EXPPOS_SHORT = 0;
            enum SIGNPOS_BYTE = 0;
        }
    }
    else static if (T.mant_dig == 113)
    {
        // Quadruple precision float
        enum ushort EXPMASK = 0x7FFF;
        enum ushort EXPSHIFT = 0;
        enum ushort EXPBIAS = 0x3FFE;
        enum realFormat = RealFormat.ieeeQuadruple;
        version (LittleEndian)
        {
            enum EXPPOS_SHORT = 7;
            enum SIGNPOS_BYTE = 15;
        }
        else
        {
            enum EXPPOS_SHORT = 0;
            enum SIGNPOS_BYTE = 0;
        }
    }
    else static if (T.mant_dig == 106)
    {
        // IBM Extended doubledouble
        enum ushort EXPMASK = 0x7FF0;
        enum ushort EXPSHIFT = 4;
        enum realFormat = RealFormat.ibmExtended;

        // For IBM doubledouble the larger magnitude double comes first.
        // It's really a double[2] and arrays don't index differently
        // between little and big-endian targets.
        enum DOUBLEPAIR_MSB = 0;
        enum DOUBLEPAIR_LSB = 1;

        // The exponent/sign byte is for most significant part.
        version (LittleEndian)
        {
            enum EXPPOS_SHORT = 3;
            enum SIGNPOS_BYTE = 7;
        }
        else
        {
            enum EXPPOS_SHORT = 0;
            enum SIGNPOS_BYTE = 0;
        }
    }
    else
        static assert(false, "No traits support for " ~ T.stringof);
}

// These apply to all floating-point types
version (LittleEndian)
{
    enum MANTISSA_LSB = 0;
    enum MANTISSA_MSB = 1;
}
else
{
    enum MANTISSA_LSB = 1;
    enum MANTISSA_MSB = 0;
}
