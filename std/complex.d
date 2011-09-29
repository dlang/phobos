// Written in the D programming language.

/** Module that will replace the built-in types $(D cfloat), $(D cdouble),
    $(D creal), $(D ifloat), $(D idouble), and $(D ireal).

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/_complex.d)
*/
module std.complex;


import std.format;
import std.math;
import std.numeric;
import std.traits;




/** Helper function that returns a _complex number with the specified
    real and imaginary parts.

    If neither $(D re) nor $(D im) are floating-point numbers, this
    function returns a $(D Complex!double).  Otherwise, the return type
    is deduced using $(D std.traits.CommonType!(R, I)).

    Examples:
    ---
    auto c = complex(2.0);
    static assert (is(typeof(c) == Complex!double));
    assert (c.re == 2.0);
    assert (c.im == 0.0);

    auto w = complex(2);
    static assert (is(typeof(w) == Complex!double));
    assert (w == c);

    auto z = complex(1, 3.14L);
    static assert (is(typeof(z) == Complex!real));
    assert (z.re == 1.0L);
    assert (z.im == 3.14L);
    ---
*/
auto complex(T)(T re)  @safe pure nothrow  if (is(T : double))
{
    static if (isFloatingPoint!T)
        return Complex!T(re, 0);
    else
        return Complex!double(re, 0);
}

/// ditto
auto complex(R, I)(R re, I im)  @safe pure nothrow
    if (is(R : double) && is(I : double))
{
    static if (isFloatingPoint!R || isFloatingPoint!I)
        return Complex!(CommonType!(R, I))(re, im);
    else
        return Complex!double(re, im);
}


unittest
{
    auto a = complex(1.0);
    static assert (is(typeof(a) == Complex!double));
    assert (a.re == 1.0);
    assert (a.im == 0.0);

    auto b = complex(2.0L);
    static assert (is(typeof(b) == Complex!real));
    assert (b.re == 2.0L);
    assert (b.im == 0.0L);

    auto c = complex(1.0, 2.0);
    static assert (is(typeof(c) == Complex!double));
    assert (c.re == 1.0);
    assert (c.im == 2.0);

    auto d = complex(3.0, 4.0L);
    static assert (is(typeof(d) == Complex!real));
    assert (d.re == 3.0);
    assert (d.im == 4.0L);

    auto e = complex(1);
    static assert (is(typeof(e) == Complex!double));
    assert (e.re == 1);
    assert (e.im == 0);

    auto f = complex(1L, 2);
    static assert (is(typeof(f) == Complex!double));
    assert (f.re == 1L);
    assert (f.im == 2);

    auto g = complex(3, 4.0L);
    static assert (is(typeof(g) == Complex!real));
    assert (g.re == 3);
    assert (g.im == 4.0L);
}




/** A complex number parametrised by a type $(D T), which must be either
    $(D float), $(D double) or $(D real).
*/
struct Complex(T)  if (isFloatingPoint!T)
{
    /** The real part of the number. */
    T re;

    /** The imaginary part of the number. */
    T im;


@safe pure nothrow  // The following functions depend only on std.math.
{

    /** Calculate the absolute value (or modulus) of the number. */
    @property T abs() const
    {
        return hypot(re, im);
    }


    /** Calculate the argument (or phase) of the number. */
    @property T arg() const
    {
        return atan2(im, re);
    }


    /** Return the complex conjugate of the number. */
    @property Complex conj() const
    {
        return Complex(re, -im);
    }




    // ASSIGNMENT OPERATORS

    // TODO: Make operators return by ref when DMD bug 2460 is fixed.


    // this = complex
    ref Complex opAssign(R : T)(Complex!R z)
    {
        re = z.re;
        im = z.im;
        return this;
    }


    // this = numeric
    ref Complex opAssign(R : T)(R r)
    {
        re = r;
        im = 0;
        return this;
    }




    // COMPARISON OPERATORS


    // this == complex
    bool opEquals(R : T)(Complex!R z) const
    {
        return re == z.re && im == z.im;
    }


    // this == numeric
    bool opEquals(R : T)(R r) const
    {
        return re == r && im == 0;
    }



    // UNARY OPERATORS


    // +complex
    Complex opUnary(string op)() const
        if (op == "+")
    {
        return this;
    }


    // -complex
    Complex opUnary(string op)() const
        if (op == "-")
    {
        return Complex(-re, -im);
    }



    // BINARY OPERATORS


    // complex op complex
    Complex!(CommonType!(T,R)) opBinary(string op, R)(Complex!R z) const
    {
        alias typeof(return) C;
        auto w = C(this.re, this.im);
        return w.opOpAssign!(op)(z);
    }


    // complex op numeric
    Complex!(CommonType!(T,R)) opBinary(string op, R)(R r) const
        if (isNumeric!R)
    {
        alias typeof(return) C;
        auto w = C(this.re, this.im);
        return w.opOpAssign!(op)(r);
    }


    // numeric + complex,  numeric * complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(R r) const
        if ((op == "+" || op == "*") && (isNumeric!R))
    {
        return opBinary!(op)(r);
    }


    // numeric - complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(R r) const
        if (op == "-" && isNumeric!R)
    {
        return Complex(r - re, -im);
    }


    // numeric / complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(R r) const
        if (op == "/" && isNumeric!R)
    {
        typeof(return) w;
        alias FPTemporary!(typeof(w.re)) Tmp;

        if (fabs(re) < fabs(im))
        {
            Tmp ratio = re/im;
            Tmp rdivd = r/(re*ratio + im);

            w.re = rdivd*ratio;
            w.im = -rdivd;
        }
        else
        {
            Tmp ratio = im/re;
            Tmp rdivd = r/(re + im*ratio);

            w.re = rdivd;
            w.im = -rdivd*ratio;
        }

        return w;
    }



    // OPASSIGN OPERATORS


    // complex += complex,  complex -= complex
    ref Complex opOpAssign(string op, C)(C z)
        if ((op == "+" || op == "-") && is(C R == Complex!R))
    {
        mixin ("re "~op~"= z.re;");
        mixin ("im "~op~"= z.im;");
        return this;
    }


    // complex *= complex
    ref Complex opOpAssign(string op, C)(C z)
        if (op == "*" && is(C R == Complex!R))
    {
        auto temp = re*z.re - im*z.im;
        im = im*z.re + re*z.im;
        re = temp;
        return this;
    }


    // complex /= complex
    ref Complex opOpAssign(string op, C)(C z)
        if (op == "/" && is(C R == Complex!R))
    {
        if (fabs(z.re) < fabs(z.im))
        {
            FPTemporary!T ratio = z.re/z.im;
            FPTemporary!T denom = z.re*ratio + z.im;

            auto temp = (re*ratio + im)/denom;
            im = (im*ratio - re)/denom;
            re = temp;
        }
        else
        {
            FPTemporary!T ratio = z.im/z.re;
            FPTemporary!T denom = z.re + z.im*ratio;

            auto temp = (re + im*ratio)/denom;
            im = (im - re*ratio)/denom;
            re = temp;
        }
        return this;
    }


    // complex ^^= complex
    ref Complex opOpAssign(string op, C)(C z)
        if (op == "^^" && is(C R == Complex!R))
    {
        FPTemporary!T r = abs;
        FPTemporary!T t = arg;
        FPTemporary!T ab = r^^z.re * exp(-t*z.im);
        FPTemporary!T ar = t*z.re + log(r)*z.im;

        re = ab*std.math.cos(ar);
        im = ab*std.math.sin(ar);
        return this;
    }


    // complex += numeric,  complex -= numeric
    ref Complex opOpAssign(string op, U : T)(U a)
        if (op == "+" || op == "-")
    {
        mixin ("re "~op~"= a;");
        return this;
    }


    // complex *= numeric,  complex /= numeric
    ref Complex opOpAssign(string op, U : T)(U a)
        if (op == "*" || op == "/")
    {
        mixin ("re "~op~"= a;");
        mixin ("im "~op~"= a;");
        return this;
    }


    // complex ^^= real
    ref Complex opOpAssign(string op, R)(R r)
        if (op == "^^" && isFloatingPoint!R)
    {
        FPTemporary!T ab = abs^^r;
        FPTemporary!T ar = arg*r;
        re = ab*std.math.cos(ar);
        im = ab*std.math.sin(ar);
        return this;
    }


    // complex ^^= int
    ref Complex opOpAssign(string op, U)(U i)
        if (op == "^^" && isIntegral!U)
    {
        switch (i)
        {
        case 0:
            re = 1.0;
            im = 0.0;
            break;
        case 1:
            // identity; do nothing
            break;
        case 2:
            this *= this;
            break;
        case 3:
            auto z = this;
            this *= z;
            this *= z;
            break;
        default:
            this ^^= cast(real) i;
        }
        return this;
    }

} // @safe pure nothrow



    /** Convert the complex number to a string representation.

        If a $(D sink) delegate is specified, the string is passed to it
        and this function returns $(D null).  Otherwise, this function
        returns the string representation directly.

        The output format is controlled via $(D formatSpec), which should consist
        of a single POSIX format specifier, including the percent (%) character.
        Note that complex numbers are floating point numbers, so the only
        valid format characters are 'e', 'f', 'g', 'a', and 's', where 's'
        gives the default behaviour. Positional parameters are not valid
        in this context.

        See the $(LINK2 std_format.html, std.format documentation) for
        more information.
    */
    string toString
        (scope void delegate(const(char)[]) sink = null, string formatSpec = "%s")
        const
    {
        if (sink == null)
        {
            char[] buf;
            buf.reserve(100);
            toString((const(char)[] s) { buf ~= s; }, formatSpec);
            return cast(string) buf;
        }

        formattedWrite(sink, formatSpec, re);
        if (signbit(im) == 0)  sink("+");
        formattedWrite(sink, formatSpec, im);
        sink("i");
        return null;
    }
}


unittest
{
    enum EPS = double.epsilon;

    // Check abs() and arg()
    auto c1 = Complex!double(1.0, 1.0);
    assert (approxEqual(c1.abs, std.math.sqrt(2.0), EPS));
    assert (approxEqual(c1.arg, PI_4, EPS));

    auto c1c = c1.conj;
    assert (c1c.re == 1.0 && c1c.im == -1.0);


    // Check unary operations.
    auto c2 = Complex!double(0.5, 2.0);

    assert (c2 == +c2);

    assert ((-c2).re == -(c2.re));
    assert ((-c2).im == -(c2.im));
    assert (c2 == -(-c2));


    // Check complex-complex operations.
    auto cpc = c1 + c2;
    assert (cpc.re == c1.re + c2.re);
    assert (cpc.im == c1.im + c2.im);

    auto cmc = c1 - c2;
    assert (cmc.re == c1.re - c2.re);
    assert (cmc.im == c1.im - c2.im);

    auto ctc = c1 * c2;
    assert (approxEqual(ctc.abs, c1.abs*c2.abs, EPS));
    assert (approxEqual(ctc.arg, c1.arg+c2.arg, EPS));

    auto cdc = c1 / c2;
    assert (approxEqual(cdc.abs, c1.abs/c2.abs, EPS));
    assert (approxEqual(cdc.arg, c1.arg-c2.arg, EPS));

    auto cec = c1^^c2;
    assert (approxEqual(cec.re, 0.11524131979943839881, EPS));
    assert (approxEqual(cec.im, 0.21870790452746026696, EPS));


    // Check complex-real operations.
    double a = 123.456;

    auto cpr = c1 + a;
    assert (cpr.re == c1.re + a);
    assert (cpr.im == c1.im);

    auto cmr = c1 - a;
    assert (cmr.re == c1.re - a);
    assert (cmr.im == c1.im);

    auto ctr = c1 * a;
    assert (ctr.re == c1.re*a);
    assert (ctr.im == c1.im*a);

    auto cdr = c1 / a;
    assert (approxEqual(cdr.abs, c1.abs/a, EPS));
    assert (approxEqual(cdr.arg, c1.arg, EPS));

    auto rpc = a + c1;
    assert (rpc == cpr);

    auto rmc = a - c1;
    assert (rmc.re == a-c1.re);
    assert (rmc.im == -c1.im);

    auto rtc = a * c1;
    assert (rtc == ctr);

    auto rdc = a / c1;
    assert (approxEqual(rdc.abs, a/c1.abs, EPS));
    assert (approxEqual(rdc.arg, -c1.arg, EPS));

    auto cer = c1^^3.0;
    assert (approxEqual(cer.abs, c1.abs^^3, EPS));
    assert (approxEqual(cer.arg, c1.arg*3, EPS));


    // Check Complex-int operations.
    foreach (i; 0..6)
    {
        auto cei = c1^^i;
        assert (approxEqual(cei.abs, c1.abs^^i, EPS));
        // Use cos() here to deal with arguments that go outside
        // the (-pi,pi] interval (only an issue for i>3).
        assert (approxEqual(std.math.cos(cei.arg), std.math.cos(c1.arg*i), EPS));
    }


    // Check operations between different complex types.
    auto cf = Complex!float(1.0, 1.0);
    auto cr = Complex!real(1.0, 1.0);
    auto c1pcf = c1 + cf;
    auto c1pcr = c1 + cr;
    static assert (is(typeof(c1pcf) == Complex!double));
    static assert (is(typeof(c1pcr) == Complex!real));
    assert (c1pcf.re == c1pcr.re);
    assert (c1pcf.im == c1pcr.im);
}

unittest
{
    // Assignments and comparisons
    Complex!double z;

    z = 1;
    assert (z == 1);
    assert (z.re == 1.0  &&  z.im == 0.0);

    z = 2.0;
    assert (z == 2.0);
    assert (z.re == 2.0  &&  z.im == 0.0);

    z = 1.0L;
    assert (z == 1.0L);
    assert (z.re == 1.0  &&  z.im == 0.0);


    auto w = Complex!real(1.0, 1.0);
    z = w;
    assert (z == w);
    assert (z.re == 1.0  &&  z.im == 1.0);

    auto c = Complex!float(2.0, 2.0);
    z = c;
    assert (z == c);
    assert (z.re == 2.0  &&  z.im == 2.0);
}

unittest
{
    // Convert to string.

    // Using default format specifier
    auto z1 = Complex!real(0.123456789, 0.123456789);
    char[] s1;
    z1.toString((const(char)[] c) { s1 ~= c; });
    assert (s1 == "0.123457+0.123457i");
    assert (s1 == z1.toString());

    // Using custom format specifier
    auto z2 = z1.conj;
    char[] s2;
    z2.toString((const(char)[] c) { s2 ~= c; }, "%.8e");
    assert (s2 == "1.23456789e-01-1.23456789e-01i");
    assert (s2 == z2.toString(null, "%.8e"));
}




/*  Fold Complex!(Complex!T) to Complex!T.

    The rationale for this is that just like the real line is a
    subspace of the complex plane, the complex plane is a subspace
    of itself.  Example of usage:
    ---
    Complex!T addI(T)(T x)
    {
        return x + Complex!T(0.0, 1.0);
    }
    ---
    The above will work if T is both real and complex.
*/
template Complex(T) if (is(T R == Complex!R))
{
    alias T Complex;
}

unittest
{
    static assert (is(Complex!(Complex!real) == Complex!real));

    Complex!T addI(T)(T x)
    {
        return x + Complex!T(0.0, 1.0);
    }

    auto z1 = addI(1.0);
    assert (z1.re == 1.0 && z1.im == 1.0);

    enum one = Complex!double(1.0, 0.0);
    auto z2 = addI(one);
    assert (z1 == z2);
}




/** Construct a complex number given its absolute value and argument. */
Complex!(CommonType!(T, U)) fromPolar(T, U)(T modulus, U argument)
    @safe pure nothrow
{
    return Complex!(CommonType!(T,U))
        (modulus*std.math.cos(argument), modulus*std.math.sin(argument));
}

unittest
{
    auto z = fromPolar(std.math.sqrt(2.0), PI_4);
    assert (approxEqual(z.re, 1.0L, real.epsilon));
    assert (approxEqual(z.im, 1.0L, real.epsilon));
}




/** Trigonometric functions. */
Complex!T sin(T)(Complex!T z)  @safe pure nothrow
{
    auto cs = expi(z.re);
    auto csh = coshisinh(z.im);
    return typeof(return)(cs.im * csh.re, cs.re * csh.im);
}

unittest
{
  assert(sin(complex(0.0)) == 0.0);
  assert(sin(complex(2.0L, 0)) == std.math.sin(2.0L));
}


/// ditto
Complex!T cos(T)(Complex!T z)  @safe pure nothrow
{
    auto cs = expi(z.re);
    auto csh = coshisinh(z.im);
    return typeof(return)(cs.re * csh.re, - cs.im * csh.im);
}

unittest{
    assert(cos(complex(0.0)) == 1.0);
    assert(cos(complex(1.3L)) == std.math.cos(1.3L));
    assert(cos(complex(0, 5.2L)) == cosh(5.2L));
}


/** Square root. */
Complex!T sqrt(T)(Complex!T z)  @safe pure nothrow
{
    typeof(return) c;
    real x,y,w,r;

    if (z == 0)
    {
        c = typeof(return)(0, 0);
    }
    else
    {
        real z_re = z.re;
        real z_im = z.im;

        x = fabs(z_re);
        y = fabs(z_im);
        if (x >= y)
        {
            r = y / x;
            w = std.math.sqrt(x)
                * std.math.sqrt(0.5 * (1 + std.math.sqrt(1 + r * r)));
        }
        else
        {
            r = x / y;
            w = std.math.sqrt(y)
                * std.math.sqrt(0.5 * (r + std.math.sqrt(1 + r * r)));
        }

        if (z_re >= 0)
        {
            c = typeof(return)(w, z_im / (w + w));
        }
        else
        {
            if (z_im < 0)
                w = -w;
            c = typeof(return)(z_im / (w + w), w);
        }
    }
    return c;
}

unittest
{
    assert (sqrt(complex(0.0)) == 0.0);
    assert (sqrt(complex(1.0L, 0)) == std.math.sqrt(1.0L));
    assert (sqrt(complex(-1.0L, 0)) == complex(0, 1.0L));
}
