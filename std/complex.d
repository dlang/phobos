// Written in the D programming language.

/** This module contains the $(LREF Complex) type, which is used to represent
    _complex numbers, along with related mathematical operations and functions.

    $(LREF Complex) will eventually $(LINK2 ../deprecate.html, replace)
    the built-in types $(D cfloat), $(D cdouble), $(D creal), $(D ifloat),
    $(D idouble), and $(D ireal).

    Authors:    Lars Tandle Kyllingstad, Don Clugston
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/_complex.d)
*/
module std.complex;


import std.exception, std.format, std.math, std.numeric, std.traits;
import std.string : format;

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

    /** Converts the complex number to a string representation.

    The second form of this function is usually not called directly;
    instead, it is used via $(XREF string,format), as shown in the examples
    below.  Supported format characters are 'e', 'f', 'g', 'a', and 's'.

    See the $(LINK2 std_format.html, std.format) and $(XREF string, format)
    documentation for more information.
    */
    string toString() const /* TODO: pure @safe nothrow */
    {
        import std.exception : assumeUnique;
        char[] buf;
        buf.reserve(100);
        auto fmt = FormatSpec!char("%s");
        toString((const(char)[] s) { buf ~= s; }, fmt);
        return assumeUnique(buf);
    }

    static if (is(T == double))
    {
        ///
        unittest
        {
            auto c = complex(1.2, 3.4);

            // Vanilla toString formatting:
            assert(c.toString() == "1.2+3.4i");

            // Formatting with std.string.format specs: the precision and width
            // specifiers apply to both the real and imaginary parts of the
            // complex number.
            import std.string : format;
            assert(format("%.2f", c)  == "1.20+3.40i");
            assert(format("%4.1f", c) == " 1.2+ 3.4i");
        }
    }

    /// ditto
    void toString(Char)(scope void delegate(const(Char)[]) sink,
                        FormatSpec!Char formatSpec) const
    {
        formatValue(sink, re, formatSpec);
        if (signbit(im) == 0) sink("+");
        formatValue(sink, im, formatSpec);
        sink("i");
    }

    /**
     * $(RED Deprecated.  This function will be removed in March 2014.
     * Please use $(XREF string,format) instead.)
     *
     * Converts the complex number to a string representation.
     *
     * If a $(D sink) delegate is specified, the string is passed to it
     * and this function returns $(D null).  Otherwise, this function
     * returns the string representation directly.

     * The output format is controlled via $(D formatSpec), which should consist
     * of a single POSIX format specifier, including the percent (%) character.
     * Note that complex numbers are floating point numbers, so the only
     * valid format characters are 'e', 'f', 'g', 'a', and 's', where 's'
     * gives the default behaviour. Positional parameters are not valid
     * in this context.
     *
     * See the $(LINK2 std_format.html, std.format) and $(XREF string, format)
     * documentation for more information.
     */
    deprecated("Please use std.string.format instead.")
    string toString(scope void delegate(const(char)[]) sink,
                    string formatSpec = "%s")
        const
    {
        if (sink == null)
        {
            import std.exception : assumeUnique;
            char[] buf;
            buf.reserve(100);
            formattedWrite((const(char)[] s) { buf ~= s; }, formatSpec, this);
            return assumeUnique(buf);
        }

        formattedWrite(sink, formatSpec, this);
        return null;
    }

@safe pure nothrow:

    this(R : T)(Complex!R z)
    {
        re = z.re;
        im = z.im;
    }

    this(Rx : T, Ry : T)(Rx x, Ry y)
    {
        re = x;
        im = y;
    }

    this(R : T)(R r)
    {
        re = r;
        im = 0;
    }

    // ASSIGNMENT OPERATORS

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
        alias C = typeof(return);
        auto w = C(this.re, this.im);
        return w.opOpAssign!(op)(z);
    }

    // complex op imaginary
    Complex!(CommonType!(T, R)) opBinary(string op, R)(Imaginary!R rhs) const
    {
        alias C = typeof(return);
        auto w = C(this.re, this.im);
        return w.opOpAssign!(op)(rhs);
    }

    // complex op numeric
    Complex!(CommonType!(T,R)) opBinary(string op, R)(R r) const
        if (isNumeric!R)
    {
        alias C = typeof(return);
        auto w = C(this.re, this.im);
        return w.opOpAssign!(op)(r);
    }

    // imaginary + complex, imaginary * complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(Imaginary!R lhs) const
        if (op == "+" || op == "*")
    {
        return opBinary!(op)(lhs);
    }

    // imaginary - complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(Imaginary!R lhs) const
        if (op == "-")
    {
        return typeof(return)(-re, lhs.im - im);
    }

    // imaginary / complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(Imaginary!R lhs) const
        if (op == "/")
    {
        typeof(return) w = void;
        alias FPTemporary!(typeof(w.re)) Tmp;

        if (fabs(re) < fabs(im))
        {
            Tmp ratio = re / im;
            Tmp idivd = lhs.im / ((re * ratio) + im);
            w.re = idivd;
            w.im = idivd * ratio;
        }
        else
        {
            Tmp ratio = im / re;
            Tmp denom = re + im * ratio;
            Tmp idivd = lhs.im / (re + (im * ratio));
            w.re = idivd * ratio;
            w.im = idivd;
        }

        return w;
    }

    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(Imaginary!R lhs) const
        if (op == "^^")
    {
        FPTemporary!(CommonType!(T, R)) ab = void, ar = void;
        if (lhs.im >= 0)
        {
            // r = lhs.im
            // theta = PI / 2
            ab = (lhs.im ^^ this.re) * std.math.exp(-PI_2 * this.im);
            ar = (PI_2 * this.re) + (std.math.log(lhs.im) * this.im);
        }
        else
        {
            // r = -lhs.im
            // theta = -PI / 2
            ab = ((-lhs.im) ^^ this.re) * std.math.exp(PI_2 * this.im);
            ar = (-PI_2 * this.re) + (std.math.log(-lhs.im) * this.im);
        }
        return typeof(return)(ab * std.math.cos(ar), ab * std.math.sin(ar));
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
        return typeof(return)(r - re, -im);
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

    // numeric ^^ complex
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(R lhs) const
        if (op == "^^" && isNumeric!R)
    {
        FPTemporary!(CommonType!(T, R)) ab = void, ar = void;

        if (lhs >= 0)
        {
            // r = lhs
            // theta = 0
            ab = lhs ^^ this.re;
            ar = log(lhs) * this.im;
        }
        else
        {
            // r = -lhs
            // theta = PI
            ab = (-lhs) ^^ this.re * exp(-PI * this.im);
            ar = PI * this.re + log(-lhs) * this.im;
        }

        return typeof(return)(ab * std.math.cos(ar), ab * std.math.sin(ar));
    }

    // OP-ASSIGN OPERATORS

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
        FPTemporary!T r = abs(this);
        FPTemporary!T t = arg(this);
        FPTemporary!T ab = r^^z.re * exp(-t*z.im);
        FPTemporary!T ar = t*z.re + log(r)*z.im;

        re = ab*std.math.cos(ar);
        im = ab*std.math.sin(ar);
        return this;
    }

    // complex += imaginary, complex -= imaginary
    ref Complex opOpAssign(string op, I)(I z)
    if ((op == "+" || op == "-") && is(I R == Imaginary!R))
    {
        mixin ("this.im "~op~"= z.im;");
        return this;
    }

    // complex *= imaginary
    ref Complex opOpAssign(string op, I)(I z)
        if (op == "*" && is(I R == Imaginary!R))
    {
        auto temp = -im * z.im;
        im = re * z.im;
        re = temp;
        return this;
    }

    // complex /= imaginary
    ref Complex opOpAssign(string op, I)(I z)
    if (op == "/" && is(I R == Imaginary!R))
    {
        auto temp = im / z.im;
        im = -re / z.im;
        re = temp;
        return this;
    }

    // complex ^^= imaginary
    ref Complex opOpAssign(string op, I)(I z)
        if (op == "^^" && is(I R == Imaginary!R))
    {
        FPTemporary!T r = abs(this);
        FPTemporary!T t = arg(this);
        FPTemporary!T ab = exp(-t * z.im);
        FPTemporary!T ar = log(r) * z.im;

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
        FPTemporary!T ab = abs(this)^^r;
        FPTemporary!T ar = arg(this)*r;
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
}

unittest
{
    enum EPS = double.epsilon;
    auto c1 = complex(1.0, 1.0);

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
    assert (approxEqual(abs(ctc), abs(c1)*abs(c2), EPS));
    assert (approxEqual(arg(ctc), arg(c1)+arg(c2), EPS));

    auto cdc = c1 / c2;
    assert (approxEqual(abs(cdc), abs(c1)/abs(c2), EPS));
    assert (approxEqual(arg(cdc), arg(c1)-arg(c2), EPS));

    auto cec = c1^^c2;
    assert (approxEqual(cec.re, 0.11524131979943839881, EPS));
    assert (approxEqual(cec.im, 0.21870790452746026696, EPS));

    // Check complex-imaginary operations
    auto i1 = imaginary(2.0);
    auto cpi = c1 + i1;
    assert(cpi.re == c1.re);
    assert(cpi.im == c1.im + i1.im);

    auto cmi = c1 - i1;
    assert(cmi.re == c1.re);
    assert(cmi.im == c1.im - i1.im);

    auto cti = c1 * i1;
    assert(approxEqual(abs(cti), abs(c1) * std.math.abs(i1.im), EPS));
    // need to support both abs and arg for imaginaries

    auto cdi = c1 / i1;
    assert(approxEqual(abs(cdi), abs(c1) / std.math.abs(i1.im), EPS));
    // again, need second unittest here

    auto cei1 = c1 ^^ i1;
    auto cei2 = c1 ^^ complex(0.0, i1.im);
    assert(approxEqual(cei1.re, cei2.re, EPS));
    assert(approxEqual(cei1.im, cei2.im, EPS));

    auto ipc = i1 + c1;
    assert(ipc == cpi);

    auto imc = i1 - c1;
    assert(imc == -cmi);

    auto itc = i1 * c1;
    assert(itc == cti);

    auto idc = i1 / c1;
    assert(idc == 1.0 / cdi);

    auto iec1a = i1 ^^ c1;
    auto iec1b = complex(0.0, i1.im) ^^ c1;
    assert(iec1a == iec1b);

    auto iec2a = (-i1) ^^ c1;
    auto iec2b = complex(0.0, -i1.im) ^^ c1;
    assert(approxEqual(iec2a.re, iec2b.re, EPS));
    assert(approxEqual(iec2a.im, iec2b.im, EPS));

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
    assert (approxEqual(abs(cdr), abs(c1)/a, EPS));
    assert (approxEqual(arg(cdr), arg(c1), EPS));

    auto cer = c1^^3.0;
    assert (approxEqual(abs(cer), abs(c1)^^3, EPS));
    assert (approxEqual(arg(cer), arg(c1)*3, EPS));

    auto rpc = a + c1;
    assert (rpc == cpr);

    auto rmc = a - c1;
    assert (rmc.re == a-c1.re);
    assert (rmc.im == -c1.im);

    auto rtc = a * c1;
    assert (rtc == ctr);

    auto rdc = a / c1;
    assert (approxEqual(abs(rdc), a/abs(c1), EPS));
    assert (approxEqual(arg(rdc), -arg(c1), EPS));

    auto rec1a = 1.0 ^^ c1;
    assert(rec1a.re == 1.0);
    assert(rec1a.im == 0.0);

    auto rec2a = 1.0 ^^ c2;
    assert(rec2a.re == 1.0);
    assert(rec2a.im == 0.0);

    auto rec1b = (-1.0) ^^ c1;
    assert(approxEqual(abs(rec1b), std.math.exp(-PI * c1.im), EPS));
    auto arg1b = arg(rec1b);
    /* The argument _should_ be PI, but floating-point rounding error
     * means that in fact the imaginary part is very slightly negative.
     */
    assert(approxEqual(arg1b, PI, EPS) || approxEqual(arg1b, -PI, EPS));

    auto rec2b = (-1.0) ^^ c2;
    assert(approxEqual(abs(rec2b), std.math.exp(-2 * PI), EPS));
    assert(approxEqual(arg(rec2b), PI_2, EPS));

    auto rec3a = 0.79 ^^ complex(6.8, 5.7);
    auto rec3b = complex(0.79, 0.0) ^^ complex(6.8, 5.7);
    assert(approxEqual(rec3a.re, rec3b.re, EPS));
    assert(approxEqual(rec3a.im, rec3b.im, EPS));

    auto rec4a = (-0.79) ^^ complex(6.8, 5.7);
    auto rec4b = complex(-0.79, 0.0) ^^ complex(6.8, 5.7);
    assert(approxEqual(rec4a.re, rec4b.re, EPS));
    assert(approxEqual(rec4a.im, rec4b.im, EPS));

    auto rer = a ^^ complex(2.0, 0.0);
    auto rcheck = a ^^ 2.0;
    static assert(is(typeof(rcheck) == double));
    assert(feqrel(rer.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer.re, rcheck));
    assert(rer.im == 0.0);

    auto rer2 = (-a) ^^ complex(2.0, 0.0);
    rcheck = (-a) ^^ 2.0;
    assert(feqrel(rer2.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer2.re, rcheck));
    assert(approxEqual(rer2.im, 0.0, EPS));

    auto rer3 = (-a) ^^ complex(-2.0, 0.0);
    rcheck = (-a) ^^ (-2.0);
    assert(feqrel(rer3.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer3.re, rcheck));
    assert(approxEqual(rer3.im, 0.0, EPS));

    auto rer4 = a ^^ complex(-2.0, 0.0);
    rcheck = a ^^ (-2.0);
    assert(feqrel(rer4.re, rcheck) == double.mant_dig);
    assert(isIdentical(rer4.re, rcheck));
    assert(rer4.im == 0.0);

    // Check Complex-int operations.
    foreach (i; 0..6)
    {
        auto cei = c1^^i;
        assert (approxEqual(abs(cei), abs(c1)^^i, EPS));
        // Use cos() here to deal with arguments that go outside
        // the (-pi,pi] interval (only an issue for i>3).
        assert (approxEqual(std.math.cos(arg(cei)), std.math.cos(arg(c1)*i), EPS));
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
    // Initialization
    Complex!double a = 1;
    assert (a.re == 1 && a.im == 0);
    Complex!double b = 1.0;
    assert (b.re == 1.0 && b.im == 0);
    Complex!double c = Complex!real(1.0, 2);
    assert (c.re == 1.0 && c.im == 2);
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
    auto z2 = conj(z1);
    char[] s2;
    z2.toString((const(char)[] c) { s2 ~= c; }, "%.8e");
    assert (s2 == "1.23456789e-01-1.23456789e-01i");
    assert (s2 == z2.toString(null, "%.8e"));
}


/*  Makes Complex!(Complex!T) fold to Complex!T.

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


/** Calculates the absolute value (or modulus) of a complex number. */
T abs(T)(Complex!T z) @safe pure nothrow
{
    return hypot(z.re, z.im);
}

unittest
{
    assert (abs(complex(1.0)) == 1.0);
    assert (abs(complex(0.0, 1.0)) == 1.0);
    assert (abs(complex(1.0L, -2.0L)) == std.math.sqrt(5.0L));
}


/** Calculates the argument (or phase) of a complex number. */
real arg(T)(Complex!T z) @safe pure nothrow
{
    return atan2(z.im, z.re);
}

unittest
{
    assert (arg(complex(1.0)) == 0.0);
    assert (arg(complex(0.0L, 1.0L)) == PI_2);
    assert (arg(complex(1.0L, 1.0L)) == PI_4);
}


/** Returns the complex conjugate of a complex number. */
Complex!T conj(T)(Complex!T z) @safe pure nothrow
{
    return Complex!T(z.re, -z.im);
}

unittest
{
    assert (conj(complex(1.0)) == complex(1.0));
    assert (conj(complex(1.0, 2.0)) == complex(1.0, -2.0));
}


/** Constructs a complex number given its absolute value and argument. */
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


/** Calculates cos(y) + i sin(y).

    Note:
    $(D expi) is included here for convenience and for easy migration of code
    that uses $(XREF math,_expi).  Unlike $(XREF math,_expi), which uses the
    x87 $(I fsincos) instruction when possible, this function is no faster
    than calculating cos(y) and sin(y) separately.
*/
Complex!real expi(real y)  @trusted pure nothrow
{
    return Complex!real(std.math.cos(y), std.math.sin(y));
}

unittest
{
    assert(expi(1.3e5L) == complex(std.math.cos(1.3e5L), std.math.sin(1.3e5L)));
    assert(expi(0.0L) == 1.0L);
    auto z1 = expi(1.234);
    auto z2 = std.math.expi(1.234);
    assert(z1.re == z2.re && z1.im == z2.im);
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

// Issue 10881: support %f formatting of complex numbers
unittest
{
    auto x = complex(1.2, 3.4);
    assert(format("%.2f", x) == "1.20+3.40i");

    auto y = complex(1.2, -3.4);
    assert(format("%.2f", y) == "1.20-3.40i");
}

unittest
{
    // Test wide string formatting
    wstring wformat(T)(string format, Complex!T c)
    {
        import std.array : appender;
        auto w = appender!wstring();
        auto n = formattedWrite(w, format, c);
        return w.data;
    }

    auto x = complex(1.2, 3.4);
    assert(wformat("%.2f", x) == "1.20+3.40i"w);
}

unittest
{
    // Test ease of use (vanilla toString() should be supported)
    assert(complex(1.2, 3.4).toString() == "1.2+3.4i");
}

/**
 * Helper function that returns an _imaginary number with the specified
 * magnitude.
 *
 * If $(D T) is a floating-point type, this function returns a type of
 * $(D Imaginary!T), otherwise it returns an $(D Imaginary!double).
 *
 * Examples:
 * ---
 * auto i1 = imaginary(2.0);
 * static assert (is(typeof(i1) == Imaginary!double));
 * assert (i1.im == 2.0);
 *
 * auto i2 = imaginary(2);
 * static assert (is(typeof(i2) == Imaginary!double));
 * assert (i2 == i1);
 *
 * auto i3 = imaginary(3.14L);
 * static assert (is(typeof(i3) == Imaginary!real));
 * assert (i3.im == 3.14L);
 * ---
 */
auto imaginary(T)(T im)
{
    static if (isFloatingPoint!T)
    {
        return Imaginary!T(im);
    }
    else
    {
        return Imaginary!double(im);
    }
}

/**
 * An imaginary number parameterized by a floating-point type $(D T).
 */
struct Imaginary(T)
    if (isFloatingPoint!T)
{
    /**
     * The imaginary part of the number.  This can be written to directly
     * if it's useful to do so.
     */
    T im;

    /**
     * Converts the imaginary number to a string representation.
     *
     * The second form of this function is usually not called directly;
     * instead, it is used via $(XREF string,format), as shown in the examples
     * below.  Supported format characters are 'e', 'f', 'g', 'a', and 's'.
     *
     * See the $(LINK2 std_format.html, std.format) and $(XREF string, format)
     * documentation for more information.
     */
    string toString()
    {
        import std.exception : assumeUnique;
        char[] buf;
        buf.reserve(100);
        auto fmt = FormatSpec!char("%s");
        toString((const(char)[] s) { buf ~= s; }, fmt);
        return assumeUnique(buf);
    }

    /// ditto
    void toString(Char)(scope void delegate(const(Char)[]) sink,
                        FormatSpec!Char formatSpec) const
    {
        formatValue(sink, im, formatSpec);
        if (im != 0) sink("i");
    }

    static if (is(T == double))
    {
        ///
        unittest
        {
            auto im = Imaginary!double(3.4);
            assert(im.toString() == "3.4i");

            import std.string : format;
            assert(format("%.2f", im) == "3.40i");
            assert(format("%4.1f", im) == " 3.4i");

            im.im = 0.0;
            assert(im.toString() == "0");
            assert(format("%.2f", im) == "0.00");
            assert(format("%4.1f", im) == " 0.0");
        }
    }

    this(R : T)(Imaginary!R that) @safe nothrow pure
    {
        this.im = that.im;
    }

    this(R : T)(Complex!R z)
    {
        if (z.re != 0)
        {
            throw new Exception(format("Cannot initialize %s with complex number %s whose real part is non-zero",
                                       typeof(this).stringof, z));
        }
        else
        {
            this.im = z.im;
        }
    }

    this(R : T)(R y) @safe nothrow pure
    {
        this.im = y;
    }

    // ------ Assignment operators ------------------------

    // this = imaginary
    ref Imaginary opAssign(R : T)(Imaginary!R that) @safe nothrow pure
    {
        this.im = that.im;
        return this;
    }

    // this = complex (must have real part == 0)
    ref Imaginary opAssign(R : T)(Complex!R z)
    {
        if (z.re != 0)
        {
            /* Question: leave this.im alone here, or set it to nan
             * to reflect failed assignment?
             */
            throw new Exception(format("Cannot assign complex number %s with non-zero real part to %s",
                                       z, typeof(this).stringof));
        }
        else
        {
            this.im = z.im;
        }

        return this;
    }

  @safe nothrow pure:
    /* No numeric opAssign because built-in numerical types
     * lie on the real axis, not the imaginary one ... :-)
     *
     * We could include support for built-in complex and
     * imaginary types, but as Complex doesn't, it seems
     * superfluous.
     */

    // ------ Comparison operators ------------------------

    bool opEquals(R : T)(Imaginary!R that)
    {
        return this.im == that.im;
    }

    bool opEquals(R : T)(Complex!R z)
    {
        return z.re == 0 && this.im == z.im;
    }

    bool opEquals(R : T)(R re)
    {
        /* Since numerical types lie on the real axis,
         * they are only equal to imaginary types if
         * both are 0.
         */
        return re == 0 && this.im == 0;
    }

    // ------ Unary operators -----------------------------

    Imaginary opUnary(string op)() const
        if (op == "+")
    {
        return this;
    }

    Imaginary opUnary(string op)() const
        if (op == "-")
    {
        return Imaginary(-im);
    }

    // ------ Binary operators ----------------------------

    // imaginary + imaginary, imaginary - imaginary
    Imaginary!(CommonType!(T, R)) opBinary(string op, R)(Imaginary!R rhs) const
        if (op == "+" || op == "-")
    {
        return typeof(return)(mixin("this.im " ~ op ~ " rhs.im"));
    }

    // imaginary * imaginary
    CommonType!(T, R) opBinary(string op, R)(Imaginary!R rhs) const
        if (op == "*")
    {
        return -this.im * rhs.im;
    }

    // imaginary / imaginary
    CommonType!(T, R) opBinary(string op, R)(Imaginary!R rhs) const
        if (op == "/")
    {
        return this.im / rhs.im;
    }

    // imaginary ^^ imaginary
    Complex!(CommonType!(T, R)) opBinary(string op, R)(Imaginary!R rhs) const
        if (op == "^^")
    {
        FPTemporary!T r = abs(this);
        FPTemporary!T t = arg(this);
        FPTemporary!T ab = exp(-t * rhs.im);
        FPTemporary!T ar = log(r) * rhs.im;

        return typeof(return)(ab * std.math.cos(ar), ab * std.math.sin(ar));
    }

    // imaginary + numeric, imaginary - numeric
    Complex!(CommonType!(T, R)) opBinary(string op, R)(R rhs) const
        if (isNumeric!R && (op == "+" || op == "-"))
    {
        return typeof(return)(mixin(op ~ "rhs"), this.im);
    }

    // imaginary * numeric
    Imaginary!(CommonType!(T, R)) opBinary(string op, R)(R rhs) const
        if (isNumeric!R && op == "*")
    {
        return typeof(return)(this.im * rhs);
    }

    // imaginary / numeric
    Imaginary!(CommonType!(T, R)) opBinary(string op, R)(R rhs) const
        if (isNumeric!R && op == "/")
    {
        return typeof(return)(this.im / rhs);
    }

    // imaginary ^^ numeric
    Complex!(CommonType!(T, R)) opBinary(string op, R)(R rhs) const
        if (isNumeric!R && op == "^^")
    {
        FPTemporary!T r = abs(this);
        FPTemporary!T t = arg(this);
        FPTemporary!T ab = r ^^ rhs;
        FPTemporary!T ar = rhs * t;

        return typeof(return)(ab * std.math.cos(ar), ab * std.math.sin(ar));
    }

    // numeric + imaginary, numeric - imaginary
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(R lhs) const
        if (isNumeric!R && (op == "+" || op == "-"))
    {
        return typeof(return)(lhs, mixin(op ~ "this.im"));
    }

    // numeric * imaginary
    Imaginary!(CommonType!(T, R)) opBinaryRight(string op, R)(R lhs) const
        if (isNumeric!R && op == "*")
    {
        return opBinary!(op, R)(lhs);
    }

    // numeric / imaginary
    Imaginary!(CommonType!(T, R)) opBinaryRight(string op, R)(R lhs) const
        if (isNumeric!R && op == "/")
    {
        return typeof(return)((-lhs) / this.im);
    }

    // numeric ^^ imaginary
    Complex!(CommonType!(T, R)) opBinaryRight(string op, R)(R lhs) const
        if (isNumeric!R && op == "^^")
    {
        alias F = FPTemporary!(CommonType!(T, R));

        if (lhs >= 0)
        {
            // r = lhs
            // theta = 0
            //  ==> ab = 1.0
            F ar = log(lhs) * this.im;
            return typeof(return)(std.math.cos(ar), std.math.sin(ar));
        }
        else
        {
            // r = -lhs
            // theta = PI
            //  ==> ar = 0.0
            F ab = std.math.exp(-PI * this.im);
            F ar = this.im * std.math.log(-lhs);
            return typeof(return)(ab * std.math.cos(ar), ab * std.math.sin(ar));
        }
    }
}

unittest
{
    // initialization
    auto i1 = imaginary(5.9);
    auto i2 = imaginary(complex(0.0, 3.7));
    auto i3 = imaginary(i1);
    assertThrown(imaginary(complex(1.1, 4.2)));

    // Check comparison operations
    assert(i1 != i2);
    assert(i1 == i3);
    assert(is(typeof(i1) == typeof(i3)));
    assert(i1 == complex(0.0, i1.im));
    assert(i1 != complex(0.1, i1.im));
    assert(imaginary(0) == 0);
    assert(imaginary(0) != 0.3);
    assert(imaginary(0.3) != 0);
    assert(imaginary(0.3) != 0.3);

    // Check assignment
    i3 = imaginary(i1.im + i2.im);
    assert(i3.im == i1.im + i2.im);
    i3 = complex(0.0, 3 * i1.im);
    assert(i3.im == 3 * i1.im);
    assertThrown(i3 = complex(1.3, 4 * i2.im));
    assert(i3.im == 3 * i1.im); // unchanged, but perhaps should be nan?

    // Check unary operations
    assert(i1 == +i1);
    assert((-i1).im == -(i1.im));
    assert(i1 == -(-i1));

    // Check imaginary-imaginary operations
    auto ipi = i1 + i2;
    assert(ipi.im == i1.im + i2.im);

    auto imi = i1 - i2;
    assert(imi.im == i1.im - i2.im);

    auto iti = i1 * i2;
    assert(isFloatingPoint!(typeof(iti)));
    assert(iti == -i1.im * i2.im);

    auto idi = i1 / i2;   // Amin?
    assert(isFloatingPoint!(typeof(idi)));
    assert(idi == i1.im / i2.im);

    auto iei = imaginary(1.0) ^^ imaginary(1.0);  // i ^^ i
    assert(is(typeof(iei) == Complex!double));
    assert(approxEqual(iei.re, exp(-PI_2)));
    assert(iei.im == 0);

    auto iei1 = i1 ^^ i2;
    auto iei2 = complex(0.0, i1.im) ^^ complex(0.0, i2.im);
    assert(is(typeof(iei1) == typeof(iei2)));
    assert(approxEqual(iei1.re, iei2.re));
    assert(approxEqual(iei1.im, iei2.im));

    // Check imaginary-numerical operations
    real r1 = 3.5;

    // imaginary op numeric
    auto ipr = i1 + r1;    // patents ahoy!
    assert(is(typeof(ipr) == Complex!real));
    assert(ipr.re == r1);
    assert(ipr.im == i1.im);

    auto imr = i1 - r1;
    assert(is(typeof(imr) == Complex!real));
    assert(imr.re == -r1);
    assert(imr.im == i1.im);

    auto itr = i1 * r1;
    assert(is(typeof(itr) == Imaginary!real));
    assert(itr.im == i1.im * r1);

    auto idr = i1 / r1;
    assert(is(typeof(idr) == Imaginary!real));
    assert(idr.im == i1.im / r1);

    auto ier1 = i1 ^^ r1;
    auto ier2 = complex(0.0, i1.im) ^^ r1;
    assert(is(typeof(ier1) == typeof(ier2)));
    assert(approxEqual(ier1.re, ier2.re));
    assert(approxEqual(ier1.im, ier2.im));

    // numeric op imaginary
    auto rpi = r1 + i1;
    assert(is(typeof(rpi) == Complex!real));
    assert(rpi.re == r1);
    assert(rpi.im == i1.im);
    assert(rpi == ipr);

    auto rmi = r1 - i1;
    assert(is(typeof(rmi) == Complex!real));
    assert(rmi.re == r1);
    assert(rmi.im == -i1.im);
    assert(rmi == -imr);

    auto rti = r1 * i1;
    assert(is(typeof(rti) == Imaginary!real));
    assert(rti.im == i1.im * r1);
    assert(rti == itr);

    auto rdi = r1 / i1;  // do YOU have a healthy diet?
    assert(is(typeof(rdi) == Imaginary!real));
    assert(rdi.im == -r1 / i1.im);
    assert(rdi == 1.0L / idr);
    assert(rdi.im == -1.0 / idr.im);

    auto rei1a = r1 ^^ i1;
    auto rei1b = complex(r1, 0.0) ^^ i1;
    assert(rei1a == rei1b);

    auto rei2a = (-r1) ^^ i1;
    auto rei2b = complex(-r1, 0.0) ^^ i1;
    assert(rei2a == rei2b);
}

/** Calculates the absolute value (or modulus) of an imaginary number. */
T abs(T)(Imaginary!T im) @safe pure nothrow
{
    return std.math.abs(im.im);
}

unittest
{
    assert (abs(imaginary(1.0)) == 1.0);
    assert (abs(imaginary(-2.0L)) == 2.0L);
}


/** Calculates the argument (or phase) of an imaginary number. */
real arg(T)(Imaginary!T im) @safe pure nothrow
{
    if (im.im > 0)
    {
        return PI_2;
    }
    else if (im.im < 0)
    {
        return -PI_2;
    }
    else
    {
        assert(im.im == 0);
        return 0;
    }
}

unittest
{
    assert(arg(imaginary(0.0)) == 0.0);
    assert(arg(imaginary(1.0)) == PI_2);
    assert(arg(imaginary(-0.1)) == -PI_2);
    assert(approxEqual(arg(imaginary(3.5)), arg(complex(0.0, 3.5))));
    assert(approxEqual(arg(imaginary(-7.2)), arg(complex(0.0, -7.2))));
}
