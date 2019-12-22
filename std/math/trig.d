// Written in the D programming language.

/**
 *  Contains trigonometric mathematical functions.
 *
$(SCRIPT inhibitQuickIndex = 1;)
$(DIVC quickindex,
$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions))
$(TR $(TDNW Trigonometry) $(TD
    $(MYREF sin)
))
)
)
 *  Macros:
 *      TABLE_SV = <table border="1" cellpadding="4" cellspacing="0">
 *              <caption>Special Values</caption>
 *              $0</table>
 *      TH3 = $(TR $(TH $1) $(TH $2) $(TH $3))
 *      TD3 = $(TR $(TD $1) $(TD $2) $(TD $3))
 *      NAN = $(RED NAN)
 *      THETA = &theta;
 *      PLUSMN = &plusmn;
 *      PLUSMNINF = &plusmn;&infin;
 *
 *  Copyright: Copyright The D Language Foundation 2000 - 2011.
 *  License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *  Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
 *             Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
 *  Source: $(PHOBOSSRC std/math/trig.d)
 */
module std.math.trig;

static import core.math;

/***********************************
 * Returns $(HTTP en.wikipedia.org/wiki/Sine, sine) of x. x is in $(HTTP en.wikipedia.org/wiki/Radian, radians).
 *
 *      $(TABLE_SV
 *      $(TH3 x           ,  sin(x)      ,  invalid?)
 *      $(TD3 $(NAN)      ,  $(NAN)      ,  yes     )
 *      $(TD3 $(PLUSMN)0.0,  $(PLUSMN)0.0,  no      )
 *      $(TD3 $(PLUSMNINF),  $(NAN)      ,  yes     )
 *      )
 *
 * Params:
 *      x = angle in radians (not degrees)
 * Returns:
 *      sine of x
 * See_Also:
 *      $(MYREF cos), $(MYREF tan), $(MYREF asin)
 * Bugs:
 *      Results are undefined if |x| >= $(POWER 2,64).
 */

real sin(real x) @safe pure nothrow @nogc { pragma(inline, true); return core.math.sin(x); }
//FIXME
///ditto
double sin(double x) @safe pure nothrow @nogc { return sin(cast(real) x); }
//FIXME
///ditto
float sin(float x) @safe pure nothrow @nogc { return sin(cast(real) x); }

///
@safe unittest
{
    import std.math : sin, PI;
    import std.stdio : writefln;

    void someFunc()
    {
      real x = 30.0;
      auto result = sin(x * (PI / 180)); // convert degrees to radians
      writefln("The sine of %s degrees is %s", x, result);
    }
}

@safe unittest
{
    real function(real) psin = &sin;
    assert(psin != null);
}

/*
 *  Returns sine for complex and imaginary arguments.
 *
 *  sin(z) = sin(z.re)*cosh(z.im) + cos(z.re)*sinh(z.im)i
 *
 * If both sin($(THETA)) and cos($(THETA)) are required,
 * it is most efficient to use expi($(THETA)).
 */
deprecated("Use std.complex.sin")
auto sin(creal z) @safe pure nothrow @nogc
{
    import std.math : expi, coshisinh;
    const creal cs = expi(z.re);
    const creal csh = coshisinh(z.im);
    return cs.im * csh.re + cs.re * csh.im * 1i;
}

/* ditto */
deprecated("Use std.complex.sin")
auto sin(ireal y) @safe pure nothrow @nogc
{
    import std.math : cosh;
    return cosh(y.im)*1i;
}

deprecated
@safe pure nothrow @nogc unittest
{
  assert(sin(0.0+0.0i) == 0.0);
  assert(sin(2.0+0.0i) == sin(2.0L) );
}
