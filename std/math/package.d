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
