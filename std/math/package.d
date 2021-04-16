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
$(TR $(TDNW $(SUBMODULE Exponentiation & Logarithms, exponential)) $(TD
    $(SUBREF exponential, pow)
    $(SUBREF exponential, exp)
    $(SUBREF exponential, exp2)
    $(SUBREF exponential, expm1)
    $(SUBREF exponential, ldexp)
    $(SUBREF exponential, frexp)
    $(SUBREF exponential, log)
    $(SUBREF exponential, log2)
    $(SUBREF exponential, log10)
    $(SUBREF exponential, logb)
    $(SUBREF exponential, ilogb)
    $(SUBREF exponential, log1p)
    $(SUBREF exponential, scalbn)
))
$(TR $(TDNW $(SUBMODULE Remainder, remainder)) $(TD
    $(SUBREF remainder, fmod)
    $(SUBREF remainder, modf)
    $(SUBREF remainder, remainder)
    $(SUBREF remainder, remquo)
))
$(TR $(TDNW $(SUBMODULE Floating-point operations, operations)) $(TD
    $(SUBREF operations, approxEqual)
    $(SUBREF operations, feqrel)
    $(SUBREF operations, fdim)
    $(SUBREF operations, fmax)
    $(SUBREF operations, fmin)
    $(SUBREF operations, fma)
    $(SUBREF operations, isClose)
    $(SUBREF operations, nextDown)
    $(SUBREF operations, nextUp)
    $(SUBREF operations, nextafter)
    $(SUBREF operations, NaN)
    $(SUBREF operations, getNaNPayload)
    $(SUBREF operations, cmp)
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
public import std.math.operations;
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
