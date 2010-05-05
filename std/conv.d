// Written in the D programming language.

/**
A one-stop shop for converting values from one type to another.

Copyright: Copyright Digital Mars 2007 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           Shin Fujishiro,
           Adam D. Ruppe

         Copyright Digital Mars 2007 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.conv;

import core.memory, core.stdc.errno, core.stdc.string, core.stdc.stdlib,
    std.array, std.contracts,
    std.ctype, std.math, std.range, std.stdio,
    std.string, std.traits, std.typecons, std.typetuple,
    std.utf;
import std.metastrings;

//debug=conv;           // uncomment to turn on debugging printf's

/* ************* Exceptions *************** */

/**
 * Thrown on conversion errors.
 */
class ConvError : Error
{
    this(string s)
    {
        super(s);
    }
    // static void raise(S, T)(S source)
    // {
    //     throw new ConvError(cast(string)
    //             ("Can't convert value `"~to!(string)(source)~"' of type "
    //                     ~S.stringof~" to type "~T.stringof));
    // }
}

private void conv_error(S, T)(S source)
{
    throw new ConvError(cast(string)
                        ("Can't convert value `"~to!(string)(source)~"' of type "
                         ~S.stringof~" to type "~T.stringof));
}

/**
 * Thrown on conversion overflow errors.
 */
class ConvOverflowError : ConvError
{
    this(string s)
    {
        super("Error: overflow " ~ s);
    }
    // @@@BUG@@@ Issue 3269
    // pure
    static void raise(string s)
    {
        throw new ConvOverflowError(s);
    }
}

private template implicitlyConverts(S, T)
{
    enum bool implicitlyConverts = T.sizeof >= S.sizeof
        && is(typeof({S s; T t = s;}()));
}

unittest
{
    assert(!implicitlyConverts!(const(char)[], string));
    assert(implicitlyConverts!(string, const(char)[]));
}

/**
String _to string conversion works for any two string types having
($(D char), $(D wchar), $(D dchar)) character widths and any
combination of qualifiers (mutable, $(D const), or $(D immutable)).

Example:
----
char[] a = "abc";
auto b = to!(immutable(dchar)[])(a);
assert(b == "abc"w);
----
 */
T to(T, S)(S s) if (!implicitlyConverts!(S, T) && isSomeString!(T)
        && isSomeString!(S))
{
    // string-to-string conversion
    static if (s[0].sizeof == T[0].sizeof) {
        // same width, only qualifier conversion
        enum tIsConst = is(T == const(char)[]) || is(T == const(wchar)[])
            || is(T == const(dchar)[]);
        enum tIsInvariant = is(T == immutable(char)[])
            || is(T == immutable(wchar)[]) || is(T == immutable(dchar)[]);
        static if (tIsConst) {
            return s;
        } else static if (tIsInvariant) {
            // conversion (mutable|const) -> immutable
            return s.idup;
        } else {
            // conversion (immutable|const) -> mutable
            return s.dup;
        }
    } else {
        // width conversion
        // we can cast because toUTFX always produces a fresh string
        static if (T[0].sizeof == 1) {
            return cast(T) toUTF8(s);
        } else static if (T[0].sizeof == 2) {
            return cast(T) toUTF16(s);
        } else {
            static assert(T[0].sizeof == 4);
            return cast(T) toUTF32(s);
        }
    }
}

unittest
{
    alias TypeTuple!(char, wchar, dchar) Chars;
    foreach (LhsC; Chars)
    {
        alias TypeTuple!(LhsC[], const(LhsC)[], immutable(LhsC)[]) LhStrings;
        foreach (Lhs; LhStrings)
        {
            foreach (RhsC; Chars)
            {
                alias TypeTuple!(RhsC[], const(RhsC)[], immutable(RhsC)[])
                    RhStrings;
                foreach (Rhs; RhStrings)
                {
                    Lhs s1 = to!(Lhs)("wyda");
                    Rhs s2 = to!(Rhs)(s1);
                    //writeln(Lhs.stringof, " -> ", Rhs.stringof);
                    assert(s1 == to!(Lhs)(s2));
                }
            }
        }
    }
}

/**
Converts array (other than strings) to string. The left bracket,
separator, and right bracket are configurable. Each element is
converted by calling $(D to!T).
 */
T to(T, S)(S s, in T leftBracket = "", in T separator = " ",
    in T rightBracket = "")
if (isSomeString!(T) && !isSomeString!(S) && isArray!(S))
{
    alias Unqual!(typeof(T.init[0])) Char;
    // array-to-string conversion
    static if (is(S == void[])
            || is(S == const(void)[]) || is(S == immutable(void)[])) {
        auto raw = cast(const(ubyte)[]) s;
        enforce(raw.length % Char.sizeof == 0, "Alignment mismatch"
                " in converting a " ~ S.stringof ~ " to a " ~ T.stringof);
        auto result = new Char[raw.length / Char.sizeof];
        memcpy(result.ptr, s.ptr, s.length);
        return cast(T) result;
    } else {
        Appender!(Char[]) result;
        result.put(leftBracket);
        foreach (i, e; s) {
            if (i) result.put(separator);
            result.put(to!T(e));
        }
        result.put(rightBracket);
        return cast(T) result.data;
    }
}

unittest
{
    long[] b = [ 1, 3, 5 ];
    auto s = to!string(b);
    //printf("%d, |%*s|\n", s.length, s.length, s.ptr);
    assert(to!string(b) == "1 3 5", s);
    double[2] a = [ 1.5, 2.5 ];
    //writeln(to!string(a));
    assert(to!string(a) == "1.5 2.5");
}

/**
Associative array to string conversion. The left bracket, key-value
separator, element separator, and right bracket are configurable.
Each element is printed by calling $(D to!T).
 */
T to(T, S)(S s, in T leftBracket = "[", in T keyval = ":",
        in T separator = ", ", in T rightBracket = "]")
if (isAssociativeArray!(S) && isSomeString!(T))
{
    alias Unqual!(typeof(T.init[0])) Char;
    Appender!(Char[]) result;
    // hash-to-string conversion
    result.put(leftBracket);
    bool first = true;
    foreach (k, v; s) {
        if (!first) result.put(separator);
        else first = false;
        result.put(to!(T)(k));
        result.put(keyval);
        result.put(to!(T)(v));
    }
    result.put(rightBracket);
    return cast(T) result.data;
}

/**
Object to string conversion calls $(D toString) against the object or
returns $(D nullstr) if the object is null.
 */
T to(T, S)(S s, in T nullstr = "null")
if (is(S : Object) && isSomeString!(T))
{
    if (!s) return nullstr;
    return to!(T)(s.toString);
}

unittest
{
    class A { override string toString() { return "an A"; } }
    A a;
    assert(to!string(a) == "null");
    a = new A;
    assert(to!string(a) == "an A");
}

/**
Struct to string conversion calls $(D toString) against the struct if
it is defined.
 */
T to(T, S)(S s)
if (is(S == struct) && isSomeString!(T) && is(typeof(&S.init.toString)))
{
    return to!T(s.toString);
}

unittest
{
    struct S { string toString() { return "wyda"; } }
    assert(to!string(S()) == "wyda");
}

/**
For structs that do not define $(D toString), the conversion to string
produces the list of fields.
 */
T to(T, S)(S s, in T left = S.stringof~"(", in T separator = ", ",
        in T right = ")")
if (is(S == struct) && isSomeString!(T) && !is(typeof(&S.init.toString)))
{
    Tuple!(FieldTypeTuple!(S)) * t = void;
    static if ((*t).sizeof == S.sizeof)
    {
        // ok, attempt to forge the tuple
        t = cast(typeof(t)) &s;
        alias Unqual!(typeof(T.init[0])) Char;
        Appender!(Char[]) app;
        app.put(left);
        foreach (i, e; t.field)
        {
            if (i > 0) app.put(to!(T)(separator));
            app.put(to!(T)(e));
        }
        app.put(right);
        return cast(T) app.data;
    }
    else
    {
        // struct with weird alignment
        return to!T(S.stringof);
    }
}

unittest
{
    struct S { int a = 42; float b = 43.5; }
    S s;
    assert(to!string(s) == "S(42, 43.5)");
}

/**
Enumerated types are converted to strings as their symbolic names.
 */
T to(T, S)(S s) if (is(S == enum) && isSomeString!(T)
        && !implicitlyConverts!(S, T))
{
    mixin (enumToStringImpl!(S).code);
}

// internal
private template enumToStringImpl(Enum)
{
    template generate(alias members)
    {
        static if (members.length)
        {
            enum m = members[0];
            enum code =
                "if (s == S." ~ m ~ ") return `" ~ m ~ "`;" ~
                generate!(members[1 .. $]).code;
        }
        else
        {
            enum code = "throw new ConvError(`"
                "There is no corresponding enum member name in " ~
                Enum.stringof ~ "`);";
        }
    }
    enum code = generate!([__traits(allMembers, Enum)]).code;
}

unittest
{
    enum E { a, b, c }
    assert(to! string(E.a) == "a"c);
    assert(to!wstring(E.b) == "b"w);
    assert(to!dstring(E.c) == "c"d);

    enum F : real { x = 1.414, y = 1.732, z = 2.236 }
    assert(to! string(F.x) == "x"c);
    assert(to!wstring(F.y) == "y"w);
    assert(to!dstring(F.z) == "z"d);

    try
    {
        to!string(cast(E) (E.max + 1));
        assert(0);
    }
    catch (ConvError e)
    {
    }
}

/**
A $(D typedef Type Symbol) is converted to string as $(D "Type(value)").
 */
T to(T, S)(S s, in T left = S.stringof~"(", in T right = ")")
if (is(S == typedef) && isSomeString!(T))
{
    static if (is(S Original == typedef)) {
        // typedef
        return left ~ to!(T)(cast(Original) s) ~ right;
    }
}

unittest
{
    typedef double Km;
    Km km = 42;
    assert(to!string(km) == "Km(42)");
}

unittest
{
    auto a = "abcx"w;
    const(void)[] b = a;
    assert(b.length == 8);
    auto c = to!(wchar[])(b);
    assert(c == "abcx");
}

/* **************************************************************

The $(D_PARAM to) family of functions converts a value from type
$(D_PARAM Source) to type $(D_PARAM Target). The source type is
deduced and the target type must be specified, for example the
expression $(D_PARAM to!(int)(42.0)) converts the number 42 from
$(D_PARAM double) to $(D_PARAM int). The conversion is "safe", i.e.,
it checks for overflow; $(D_PARAM to!(int)(4.2e10)) would throw the
$(D_PARAM ConvOverflowError) exception. Overflow checks are only
inserted when necessary, e.g., $(D_PARAM to!(double)(42)) does not do
any checking because any int fits in a double.

Converting a value to its own type (useful mostly for generic code)
simply returns its argument.
Example:
-------------------------
int a = 42;
auto b = to!(int)(a); // b is int with value 42
auto c = to!(double)(3.14); // c is double with value 3.14
-------------------------
Converting among numeric types is a safe way to cast them around.
Conversions from floating-point types to integral types allow loss of
precision (the fractional part of a floating-point number). The
conversion is truncating towards zero, the same way a cast would
truncate. (To round a floating point value when casting to an
integral, use $(D_PARAM roundTo).)
Examples:
-------------------------
int a = 420;
auto b = to!(long)(a); // same as long b = a;
auto c = to!(byte)(a / 10); // fine, c = 42
auto d = to!(byte)(a); // throw ConvOverflowError
double e = 4.2e6;
auto f = to!(int)(e); // f == 4200000
e = -3.14;
auto g = to!(uint)(e); // fails: floating-to-integral negative overflow
e = 3.14;
auto h = to!(uint)(e); // h = 3
e = 3.99;
h = to!(uint)(a); // h = 3
e = -3.99;
f = to!(int)(a); // f = -3
-------------------------

Conversions from integral types to floating-point types always
succeed, but might lose accuracy. The largest integers with a
predecessor representable in floating-point format are 2^24-1 for
float, 2^53-1 for double, and 2^64-1 for $(D_PARAM real) (when
$(D_PARAM real) is 80-bit, e.g. on Intel machines).

Example:
-------------------------
int a = 16_777_215; // 2^24 - 1, largest proper integer representable as float
assert(to!(int)(to!(float)(a)) == a);
assert(to!(int)(to!(float)(-a)) == -a);
a += 2;
assert(to!(int)(to!(float)(a)) == a); // fails!
-------------------------

Conversions from string to numeric types differ from the C equivalents
$(D_PARAM atoi()) and $(D_PARAM atol()) by checking for overflow and
not allowing whitespace.

For conversion of strings to signed types, the grammar recognized is:
<pre>
$(I Integer): $(I Sign UnsignedInteger)
$(I UnsignedInteger)
$(I Sign):
    $(B +)
    $(B -)
</pre>
For conversion to unsigned types, the grammar recognized is:
<pre>
$(I UnsignedInteger):
    $(I DecimalDigit)
    $(I DecimalDigit) $(I UnsignedInteger)
</pre>

Converting an array to another array type works by converting each
element in turn. Associative arrays can be converted to associative
arrays as long as keys and values can in turn be converted.

Example:
-------------------------
int[] a = ([1, 2, 3]).dup;
auto b = to!(float[])(a);
assert(b == [1.0f, 2, 3]);
string str = "1 2 3 4 5 6";
auto numbers = to!(double[])(split(str));
assert(numbers == [1.0, 2, 3, 4, 5, 6]);
int[string] c;
c["a"] = 1;
c["b"] = 2;
auto d = to!(double[wstring])(c);
assert(d["a"w] == 1 && d["b"w] == 2);
-------------------------

Conversions operate transitively, meaning that they work on arrays and
associative arrays of any complexity:

-------------------------
int[string][double[int[]]] a;
...
auto b = to!(short[wstring][string[double[]]])(a);
-------------------------

This conversion works because $(D_PARAM to!(short)) applies to an
$(D_PARAM int), $(D_PARAM to!(wstring)) applies to a $(D_PARAM
string), $(D_PARAM to!(string)) applies to a $(D_PARAM double), and
$(D_PARAM to!(double[])) applies to an $(D_PARAM int[]). The
conversion might throw an exception because $(D_PARAM to!(short))
might fail the range check.

Macros: WIKI=Phobos/StdConv
 */

/**
If the source type is implicitly convertible to the target type, $(D
to) simply performs the implicit conversion.
 */
Target to(Target, Source)(Source value) if (implicitlyConverts!(Source, Target))
{
    return value;
}

unittest
{
    int a = 42;
    auto b = to!long(a);
    assert(a == b);
}

/**
Boolean values are printed as $(D "true") or $(D "false").
 */
T to(T, S)(S b) if (is(Unqual!S == bool) && isSomeString!(T))
{
    return to!T(b ? "true" : "false");
}

unittest
{
    bool b;
    assert(to!string(b) == "false");
    b = true;
    assert(to!string(b) == "true");
}


/**
When the source is a wide string, it is first converted to a narrow
string and then parsed.
 */
T to(T, S)(S value) if ((is(S : const(wchar)[]) || is(S : const(dchar)[]))
        && !isSomeString!(T))
{
    // todo: improve performance
    return parseString!(T)(toUTF8(value));
}

/**
When the source is a narrow string, normal text parsing occurs.
 */
T to(T, S)(S value) if (is(S : const(char)[]) && !isSomeString!(T))
{
    return parseString!(T)(value);
}

unittest
{
    foreach (Char; TypeTuple!(char, wchar, dchar))
    {
        auto a = to!(Char[])("123");
        assert(to!int(a) == 123);
        assert(to!double(a) == 123);
    }
}

/**
Object-to-object conversions throw exception when the source is
non-null and the target is null.
 */
T to(T, S)(S value) if (is(S : Object) && is(T : Object))
{
    auto result = cast(T) value;
    if (!result && value)
    {
        throw new ConvError("Cannot convert object of static type "
                ~S.classinfo.name~" and dynamic type "~value.classinfo.name
                ~" to type "~T.classinfo.name);
    }
    return result;
}

unittest
{
    // Testing object conversions
    class A {} class B : A {} class C : A {}
    A a1 = new A, a2 = new B, a3 = new C;
    assert(to!(B)(a2) is a2);
    assert(to!(C)(a3) is a3);
    try
    {
        to!(B)(a3);
        assert(false);
    }
    catch (ConvError e)
    {
        //writeln(e);
    }
}

/**
Object-_to-non-object conversions look for a method "to" of the source
object.

Example:
----
class Date
{
    T to(T)() if(is(T == long))
    {
        return timestamp;
    }
    ...
}

unittest
{
    auto d = new Date;
    auto ts = to!long(d); // same as d.to!long()
}
----
 */
T to(T, S)(S value) if (is(S : Object) && !is(T : Object) && !isSomeString!T
        && is(typeof(S.init.to!(T)()) : T))
{
    return value.to!T();
}

unittest
{
    class B { T to(T)() { return 43; } }
    auto b = new B;
    assert(to!int(b) == 43);
}

/**
Narrowing numeric-numeric conversions throw when the value does not
fit in the narrower type.
 */
T to(T, S)(S value)
if (!implicitlyConverts!(S, T)
        && std.traits.isNumeric!(S) && std.traits.isNumeric!(T))
{
    enum sSmallest = mostNegative!(S);
    enum tSmallest = mostNegative!(T);
    static if (sSmallest < 0) {
        // possible underflow converting from a signed
        static if (tSmallest == 0) {
            immutable good = value >= 0;
        } else {
            static assert(tSmallest < 0);
            immutable good = value >= tSmallest;
        }
        if (!good) ConvOverflowError.raise("Conversion negative overflow");
    }
    static if (S.max > T.max) {
        // possible overflow
        if (value > T.max) ConvOverflowError.raise("Conversion overflow");
    }
    return cast(T) value;
}

private T parseString(T)(const(char)[] v)
{
    scope(exit)
    {
        if (v.length)
        {
            conv_error!(const(char)[], T)(v);
        }
    }
    return parse!(T)(v);
}

/**
Array-to-array conversion (except when target is a string type)
converts each element in turn by using $(D to).
 */
T to(T, S)(S src) if (isArray!(S) && isArray!(T) && !isSomeString!(T)
        && !implicitlyConverts!(S, T))
{
    alias typeof(T.init[0]) E;
    auto result = new E[src.length];
    foreach (i, e; src) {
	/* Temporarily cast to mutable type, so we can get it initialized,
	 * this is ok because there are no other references to result[]
	 */
        cast()(result[i]) = to!(E)(e);
    }
    return result;
}

unittest
{
    // array to array conversions
    uint[] a = ([ 1u, 2, 3 ]).dup;
    auto b = to!(float[])(a);
    assert(b == [ 1.0f, 2, 3 ]);
    auto c = to!(string[])(b);
    assert(c[0] == "1" && c[1] == "2" && c[2] == "3");
    immutable(int)[3] d = [ 1, 2, 3 ];
    b = to!(float[])(d);
    assert(b == [ 1.0f, 2, 3 ]);
    uint[][] e = [ a, a ];
    auto f = to!(float[][])(e);
    assert(f[0] == b && f[1] == b);
}

/**
Associative array to associative array conversion converts each key
and each value in turn.
 */
T to(T : V2[K2], S : V1[K1], K1, V1, K2, V2)(S src)
//if (isAssociativeArray!(S) && isAssociativeArray!(T))
{
    T result;
    foreach (k1, v1; src)
    {
        result[to!(K2)(k1)] = to!(V2)(v1);
    }
    return result;
}

unittest {
    // hash to hash conversions
    int[string] a;
    a["0"] = 1;
    a["1"] = 2;
    auto b = to!(double[dstring])(a);
    assert(b["0"d] == 1 && b["1"d] == 2);
    // hash to string conversion
    assert(to!(string)(a) == "[0:1, 1:2]");
}

unittest {
    // string tests
    alias TypeTuple!(char, wchar, dchar) AllChars;
    foreach (T; AllChars) {
        foreach (U; AllChars) {
            T[] s1 = to!(T[])("Hello, world!");
            auto s2 = to!(U[])(s1);
            assert(s1 == to!(T[])(s2));
            auto s3 = to!(const(U)[])(s1);
            assert(s1 == to!(T[])(s3));
            auto s4 = to!(immutable(U)[])(s1);
            assert(s1 == to!(T[])(s4));
        }
    }
}

private bool convFails(Source, Target, E)(Source src) {
    try {
        auto t = to!(Target)(src);
    } catch (E) {
        return true;
    }
    return false;
}

private void testIntegralToFloating(Integral, Floating)() {
    Integral a = 42;
    auto b = to!(Floating)(a);
    assert(a == b);
    assert(a == to!(Integral)(b));
}

private void testFloatingToIntegral(Floating, Integral)() {
    // convert some value
    Floating a = 4.2e1;
    auto b = to!(Integral)(a);
    assert(is(typeof(b) == Integral) && b == 42);
    // convert some negative value (if applicable)
    a = -4.2e1;
    static if (Integral.min < 0) {
        b = to!(Integral)(a);
        assert(is(typeof(b) == Integral) && b == -42);
    } else {
        // no go for unsigned types
        assert(convFails!(Floating, Integral, ConvOverflowError)(a));
    }
    // convert to the smallest integral value
    a = 0.0 + Integral.min;
    static if (Integral.min < 0) {
        a = -a; // -Integral.min not representable as an Integral
        assert(convFails!(Floating, Integral, ConvOverflowError)(a)
                || Floating.sizeof <= Integral.sizeof);
    }
    a = 0.0 + Integral.min;
    assert(to!(Integral)(a) == Integral.min);
    --a; // no more representable as an Integral
    assert(convFails!(Floating, Integral, ConvOverflowError)(a)
            || Floating.sizeof <= Integral.sizeof);
    a = 0.0 + Integral.max;
//   fwritefln(stderr, "%s a=%g, %s conv=%s", Floating.stringof, a,
//             Integral.stringof, to!(Integral)(a));
    assert(to!(Integral)(a) == Integral.max || Floating.sizeof <= Integral.sizeof);
    ++a; // no more representable as an Integral
    assert(convFails!(Floating, Integral, ConvOverflowError)(a)
            || Floating.sizeof <= Integral.sizeof);
    // convert a value with a fractional part
    a = 3.14;
    assert(to!(Integral)(a) == 3);
    a = 3.99;
    assert(to!(Integral)(a) == 3);
    static if (Integral.min < 0) {
        a = -3.14;
        assert(to!(Integral)(a) == -3);
        a = -3.99;
        assert(to!(Integral)(a) == -3);
    }
}

unittest {
    alias TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong)
    AllInts;
    alias TypeTuple!(float, double, real) AllFloats;
    alias TypeTuple!(AllInts, AllFloats) AllNumerics;
    // test with same type
    {
        foreach (T; AllNumerics) {
            T a = 42;
            auto b = to!(T)(a);
            assert(is(typeof(a) == typeof(b)) && a == b);
        }
    }
    // test that floating-point numbers convert properly to largest ints
    // see http://oregonstate.edu/~peterseb/mth351/docs/351s2001_fp80x87.html
    // look for "largest fp integer with a predecessor"
    {
        // float
        int a = 16_777_215; // 2^24 - 1
        assert(to!(int)(to!(float)(a)) == a);
        assert(to!(int)(to!(float)(-a)) == -a);
        // double
        long b = 9_007_199_254_740_991; // 2^53 - 1
        assert(to!(long)(to!(double)(b)) == b);
        assert(to!(long)(to!(double)(-b)) == -b);
        // real
        // @@@ BUG IN COMPILER @@@
//     ulong c = 18_446_744_073_709_551_615UL; // 2^64 - 1
//     assert(to!(ulong)(to!(real)(c)) == c);
//     assert(to!(ulong)(-to!(real)(c)) == c);
    }
    // test conversions floating => integral
    {
        // AllInts[0 .. $ - 1] should be AllInts
        // @@@ BUG IN COMPILER @@@
        foreach (Integral; AllInts[0 .. $ - 1]) {
            foreach (Floating; AllFloats) {
                testFloatingToIntegral!(Floating, Integral);
            }
        }
    }
    // test conversion integral => floating
    {
        foreach (Integral; AllInts[0 .. $ - 1]) {
            foreach (Floating; AllFloats) {
                testIntegralToFloating!(Integral, Floating);
            }
        }
    }
    // test parsing
    {
        foreach (T; AllNumerics) {
            // from type immutable(char)[2]
            auto a = to!(T)("42");
            assert(a == 42);
            // from type char[]
            char[] s1 = "42".dup;
            a = to!(T)(s1);
            assert(a == 42);
            // from type char[2]
            char[2] s2;
            s2[] = "42";
            a = to!(T)(s2);
            assert(a == 42);
            // from type immutable(wchar)[2]
            a = to!(T)("42"w);
            assert(a == 42);
        }
    }
    // test conversions to string
    {
        foreach (T; AllNumerics) {
            T a = 42;
            assert(to!(string)(a) == "42");
            //assert(to!(wstring)(a) == "42"w);
            //assert(to!(dstring)(a) == "42"d);
            // array test
//       T[] b = new T[2];
//       b[0] = 42;
//       b[1] = 33;
//       assert(to!(string)(b) == "[42,33]");
        }
    }
    // test array to string conversion
    foreach (T ; AllNumerics) {
        auto a = [to!(T)(1), 2, 3];
        assert(to!(string)(a) == "1 2 3");
    }
    // test enum to int conversion
    // enum Testing { Test1, Test2 };
    // Testing t;
    // auto a = to!(string)(t);
    // assert(a == "0");
}

/***************************************************************
 Rounded conversion from floating point to integral.

Example:
---------------
  assert(roundTo!(int)(3.14) == 3);
  assert(roundTo!(int)(3.49) == 3);
  assert(roundTo!(int)(3.5) == 4);
  assert(roundTo!(int)(3.999) == 4);
  assert(roundTo!(int)(-3.14) == -3);
  assert(roundTo!(int)(-3.49) == -3);
  assert(roundTo!(int)(-3.5) == -4);
  assert(roundTo!(int)(-3.999) == -4);
---------------
Rounded conversions do not work with non-integral target types.
 */

template roundTo(Target) {
    Target roundTo(Source)(Source value) {
        static assert(isFloatingPoint!Source);
        static assert(isIntegral!Target);
        return to!(Target)(value + (value < 0 ? -0.5 : 0.5));
    }
}

unittest {
    assert(roundTo!(int)(3.14) == 3);
    assert(roundTo!(int)(3.49) == 3);
    assert(roundTo!(int)(3.5) == 4);
    assert(roundTo!(int)(3.999) == 4);
    assert(roundTo!(int)(-3.14) == -3);
    assert(roundTo!(int)(-3.49) == -3);
    assert(roundTo!(int)(-3.5) == -4);
    assert(roundTo!(int)(-3.999) == -4);
    assert(roundTo!(const int)(to!(const double)(-3.999)) == -4);
}

/***************************************************************
 * The $(D_PARAM parse) family of functions works quite like the
 * $(D_PARAM to) family, except that (1) it only works with strings as
 * input, (2) takes the input string by reference and advances it to
 * the position following the conversion, and (3) does not throw if it
 * could not convert the entire string. It still throws if an overflow
 * occurred during conversion or if no character of the input string
 * was meaningfully converted.
 *
 * Example:
--------------
string test = "123 \t  76.14";
auto a = parse!(uint)(test);
assert(a == 123);
assert(test == " \t  76.14"); // parse bumps string
munch(test, " \t\n\r"); // skip ws
assert(test == "76.14");
auto b = parse!(double)(test);
assert(b == 76.14);
assert(test == "");
--------------
 */

Target parse(Target, Source)(ref Source s)
if (isSomeString!Source && isIntegral!Target)
{
    static if (Target.sizeof < int.sizeof)
    {
        // smaller types are handled like integers
        auto v = parse!(Select!(Target.min < 0, int, uint), Source)(s);
        auto result = cast(Target) v;
        if (result != v)
        {
            conv_error!(Source, Target)(s); 
        }
        return result;
    }
    else
    {
        // Larger than int types
        immutable length = s.length;
        if (!length)
            goto Lerr;

        static if (Target.min < 0)
            int sign = 0;
        else
            static const int sign = 0;
        Target v = 0;
        size_t i = 0;
        enum char maxLastDigit = Target.min < 0 ? '7' : '5';
        for (; i < length; i++)
        {
            immutable c = s[i];
            if (c >= '0' && c <= '9')
            {
                if (v >= Target.max/10 &&
                        (v != Target.max/10|| c + sign > maxLastDigit))
                    goto Loverflow;
                v = cast(Target) (v * 10 + (c - '0'));
            }
            else static if (Target.min < 0)
            {
                if (c == '-' && i == 0)
                {
                    if (length == 1)
                        goto Lerr;
                    sign = -1;
                }
                else if (c == '+' && i == 0)
                {
                    if (length == 1)
                        goto Lerr;
                }
                else
                    break;
            }
            else
                break;
        }
        if (i == 0) goto Lerr;
        s = s[i .. $];
        static if (Target.min < 0)
        {
            if (sign == -1)
            {
                v = -v;
            }
        }
        return v;
      Loverflow:
        ConvOverflowError.raise("Overflow in integral conversion");
      Lerr:
        conv_error!(Source, Target)(s);
        return 0;
    }
}

Target parse(Target, Source)(ref Source s)
if (isSomeString!Source && is(Target == enum))
{
    mixin(enumFromStringImpl!Target.code);
}

private template enumFromStringImpl(Enum)
{
    template generate(alias members)
    {
        static if (members.length)
        {
            enum m = members[0];
            enum code =
                "if (s.length >= `"~m~"`.length && s[0 .. `"~m~"`.length] == `"
                ~ m ~ "`) { s = s[`"~m~"`.length .. $]; return Target."
                ~ m ~ "; }" ~
                generate!(members[1 .. $]).code;
        }
        else
        {
            enum code = "throw new ConvError(`"
                "There is no corresponding enum member value in " ~
                Enum.stringof ~ "`);";
        }
    }
    enum code = generate!([__traits(allMembers, Enum)]).code;
}

unittest
{
    enum E { a, b, c }
    assert(to!E("a"c) == E.a);
    assert(to!E("b"w) == E.b);
    assert(to!E("c"d) == E.c);

    enum F : real { x = 1.414, y = 1.732, z = 2.236 }
    assert(to!F("x"c) == F.x);
    assert(to!F("y"w) == F.y);
    assert(to!F("z"d) == F.z);

    try
    {
        to!E("d");
        assert(0);
    }
    catch (ConvError e)
    {
    }
}

Target parse(Target, Source)(ref Source s)
    if (!isSomeString!Source && isSomeChar!(ElementType!Source)
        && isIntegral!Target)
{
    char[] accum;
    foreach (c; s)
    {
        writeln(c);
        if ("0123456789-+".indexOf(c) < 0)
        {
            static if (is(typeof(s.unget(c)))) s.unget(c);
            break;
        }
        accum ~= c;
    }
    return parse!Target(accum);
}

Target parse(Target, Source)(ref Source s)
if (!isSomeString!Source && isFloatingPoint!Target)
{
    static assert(0);
}

Target parse(Target, Source)(ref Source s)
if (isSomeString!Source && isFloatingPoint!Target)
{
    // issue 1589
    //version (Windows)
    {
        if (icmp(s, "nan") == 0)
        {
            s = s[3 .. $];
            return Target.nan;
        }
    }

    auto t = s;
    if (t.startsWith('+', '-')) t.popFront();
    munch(t, "0-9"); // integral part
    if (t.startsWith('.'))
    {
        t.popFront(); // decimal point
        munch(t, "0-9"); // fractionary part
    }
    if (t.startsWith('E', 'e'))
    {
        t.popFront();
        if (t.startsWith('+', '-')) t.popFront();
        munch(t, "0-9"); // exponent
    }
    auto len = s.length - t.length;
    char sz[80] = void;
    enforce(len < sz.length);
    foreach (i; 0 .. len) sz[i] = s[i];
    sz[len] = 0;  
    
//     //writefln("toFloat('%s')", s);
//     auto sz = toStringz(to!(const char[])(s));
//     if (std.ctype.isspace(*sz))
//         goto Lerr;

//     // BUG: should set __locale_decpoint to "." for DMC

    setErrno(0);
    char* endptr;
    static if (is(Target == float))
        auto f = strtof(sz.ptr, &endptr);
    else static if (is(Target == double))
        auto f = strtod(sz.ptr, &endptr);
    else static if (is(Target == real))
        auto f = strtold(sz.ptr, &endptr);
    else
        static assert(false);
    if (getErrno() == ERANGE)
        goto Lerr;
    assert(endptr);
    if (endptr == sz.ptr)
    {
        // no progress
        goto Lerr;
    }
    s = s[endptr - sz.ptr .. $];
    return f;
  Lerr:
    conv_error!(Source, Target)(s);
    assert(0);
}

// Target parse(Target, Source)(ref Source s)
// if (isSomeString!Source && isSomeString!Target)
// {
    
// }

unittest
{
    string s = "123";
    auto a = parse!int(s);
}

// Parsing typedefs forwards to their host types
Target parse(Target, Source)(ref Source s)
if (isSomeString!Source && is(Target == typedef))
{
    static if (is(Target T == typedef))
        return cast(Target) parse!T(s);
    else
        static assert(0);
}

// Customizable integral parse

// private N parseIntegral(S, N)(ref S s)
// {
//     static if (N.sizeof < int.sizeof)
//     {
//         // smaller types are handled like integers
//         static if (N.min < 0) // signed small integer
//             alias int N1;
//         else
//             alias uint N1;
//         auto v = parseIntegral!(S, N1)(s);
//         auto result = cast(N) v;
//         if (result != v) 
//         {
//             ConvError.raise!(S, N)(s); 
//         }
//         return result;
//     }
//     else
//     {
//         // Larger than int types
//         immutable length = s.length;
//         if (!length)
//             goto Lerr;

//         static if (N.min < 0)
//             int sign = 0;
//         else
//             enum sign = 0;
//         N v = 0;
//         size_t i = 0;
//         enum char maxLastDigit = N.min < 0 ? '7' : '5';
//         for (; i < length; i++)
//         {
//             auto c = s[i];
//             if (c >= '0' && c <= '9')
//             {
//                 if (v < N.max/10 || (v == N.max/10 && c + sign <= maxLastDigit))
//                     v = cast(N) (v * 10 + (c - '0'));
//                 else
//                     goto Loverflow;
//             }
//             else static if (N.min < 0)
//             {
//                 if (c == '-' && i == 0)
//                 {
//                     sign = -1;
//                     if (length == 1)
//                         goto Lerr;
//                 }
//                 else if (c == '+' && i == 0)
//                 {
//                     if (length == 1)
//                         goto Lerr;
//                 } else
//                       break;
//             }
//             else
//                 break;
//         }
//         if (i == 0) goto Lerr;
//         s = s[i .. $];
//         static if (N.min < 0)
//         {
//             if (sign == -1)
//             {
//                 v = -v;
//             }
//         }
//         return v;
//       Loverflow:
//         assert(false);
//         //ConvOverflowError.raise(to!string(s));
//       Lerr:
//         ConvError.raise!(S, N)(s);
//         return 0;
//     }
// }

/*
 */

unittest
{
    debug(conv) printf("conv.to!int.unittest\n");

    int i;

    i = to!int("0");
    assert(i == 0);

    i = to!int("+0");
    assert(i == 0);

    i = to!int("-0");
    assert(i == 0);

    i = to!int("6");
    assert(i == 6);

    i = to!int("+23");
    assert(i == 23);

    i = to!int("-468");
    assert(i == -468);

    i = to!int("2147483647");
    assert(i == 0x7FFFFFFF);

    i = to!int("-2147483648");
    assert(i == 0x80000000);

    immutable string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "xx",
        "123h",
        "2147483648",
        "-2147483649",
        "5656566565",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!int(errors[j]);
            //printf("i = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}


/*
Tests for to!uint 
 */
unittest
{
    debug(conv) printf("conv.to!uint.unittest\n");

    uint i;

    i = to!uint("0");
    assert(i == 0);

    i = to!uint("6");
    assert(i == 6);

    i = to!uint("23");
    assert(i == 23);

    i = to!uint("468");
    assert(i == 468);

    i = to!uint("2147483647");
    assert(i == 0x7FFFFFFF);

    i = to!uint("4294967295");
    assert(i == 0xFFFFFFFF);

    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "+5",
        "-78",
        "xx",
        "123h",
        "4294967296",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!uint(errors[j]);
            //printf("i = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}

/*
Tests for to!long
 */

unittest
{
    debug(conv) printf("conv.to!long.unittest\n");

    long i;

    i = to!long("0");
    assert(i == 0);

    i = to!long("+0");
    assert(i == 0);

    i = to!long("-0");
    assert(i == 0);

    i = to!long("6");
    assert(i == 6);

    i = to!long("+23");
    assert(i == 23);

    i = to!long("-468");
    assert(i == -468);

    i = to!long("2147483647");
    assert(i == 0x7FFFFFFF);

    i = to!long("-2147483648");
    assert(i == -0x80000000L);

    i = to!long("9223372036854775807");
    assert(i == 0x7FFFFFFFFFFFFFFF);

    i = to!long("-9223372036854775808");
    assert(i == 0x8000000000000000);

    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "xx",
        "123h",
        "9223372036854775808",
        "-9223372036854775809",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!long(errors[j]);
            //printf("l = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}


/*
Tests for to!ulong
 */

unittest
{
    debug(conv) printf("conv.to!ulong.unittest\n");

    ulong i;

    i = to!ulong("0");
    assert(i == 0);

    i = to!ulong("6");
    assert(i == 6);

    i = to!ulong("23");
    assert(i == 23);

    i = to!ulong("468");
    assert(i == 468);

    i = to!ulong("2147483647");
    assert(i == 0x7FFFFFFF);

    i = to!ulong("4294967295");
    assert(i == 0xFFFFFFFF);

    i = to!ulong("9223372036854775807");
    assert(i == 0x7FFFFFFFFFFFFFFF);

    i = to!ulong("18446744073709551615");
    assert(i == 0xFFFFFFFFFFFFFFFF);


    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "+5",
        "-78",
        "xx",
        "123h",
        "18446744073709551616",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!ulong(errors[j]);
            //printf("i = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}

/*
Tests for toShort
 */

unittest
{
    debug(conv) printf("conv.to!short.unittest\n");

    short i;

    i = to!short("0");
    assert(i == 0);

    i = to!short("+0");
    assert(i == 0);

    i = to!short("-0");
    assert(i == 0);

    i = to!short("6");
    assert(i == 6);

    i = to!short("+23");
    assert(i == 23);

    i = to!short("-468");
    assert(i == -468);

    i = to!short("32767");
    assert(i == 0x7FFF);

    i = to!short("-32768");
    assert(i == cast(short)0x8000);

    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "xx",
        "123h",
        "32768",
        "-32769",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!short(errors[j]);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}


/*
Tests for to!ushort
 */

unittest
{
    debug(conv) printf("conv.to!ushort.unittest\n");

    ushort i;

    i = to!ushort("0");
    assert(i == 0);

    i = to!ushort("6");
    assert(i == 6);

    i = to!ushort("23");
    assert(i == 23);

    i = to!ushort("468");
    assert(i == 468);

    i = to!ushort("32767");
    assert(i == 0x7FFF);

    i = to!ushort("65535");
    assert(i == 0xFFFF);

    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "+5",
        "-78",
        "xx",
        "123h",
        "65536",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!ushort(errors[j]);
            debug(conv) printf("i = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}


/*******************************************************
Tests for to!byte
 */

unittest
{
    debug(conv) printf("conv.to!byte.unittest\n");

    byte i;

    i = to!byte("0");
    assert(i == 0);

    i = to!byte("+0");
    assert(i == 0);

    i = to!byte("-0");
    assert(i == 0);

    i = to!byte("6");
    assert(i == 6);

    i = to!byte("+23");
    assert(i == 23);

    i = to!byte("-68");
    assert(i == -68);

    i = to!byte("127");
    assert(i == 0x7F);

    i = to!byte("-128");
    assert(i == cast(byte)0x80);

    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "xx",
        "123h",
        "128",
        "-129",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!byte(errors[j]);
            debug(conv) printf("i = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}


/*
Tests for to!ubyte
 */

unittest
{
    debug(conv) printf("conv.to!ubyte.unittest\n");

    ubyte i;

    i = to!ubyte("0");
    assert(i == 0);

    i = to!ubyte("6");
    assert(i == 6);

    i = to!ubyte("23");
    assert(i == 23);

    i = to!ubyte("68");
    assert(i == 68);

    i = to!ubyte("127");
    assert(i == 0x7F);

    i = to!ubyte("255");
    assert(i == 0xFF);

    static string[] errors =
    [
        "",
        "-",
        "+",
        "-+",
        " ",
        " 0",
        "0 ",
        "- 0",
        "1-",
        "+5",
        "-78",
        "xx",
        "123h",
        "256",
    ];

    for (int j = 0; j < errors.length; j++)
    {
        i = 47;
        try
        {
            i = to!ubyte(errors[j]);
            debug(conv) printf("i = %d\n", i);
        }
        catch (Error e)
        {
            debug(conv) e.print();
            i = 3;
        }
        assert(i == 3);
    }
}

// @@@ BUG IN COMPILER
// lvalue of type immutable(T)[] should be implicitly convertible to
// ref const(T)[].
// F parseFloating(S : S[], F)(ref S[] s)
// {
//     //writefln("toFloat('%s')", s);
//     auto sz = toStringz(to!(const char[])(s));
//     if (std.ctype.isspace(*sz))
//      goto Lerr;

//     // issue 1589
//     version (Windows)
//     {
//         if (icmp(s, "nan") == 0)
//         {
//             s = s[3 .. $];
//             return F.nan;
//         }
//     }

//     // BUG: should set __locale_decpoint to "." for DMC

//     setErrno(0);
//     char* endptr;
//     static if (is(F == float))
//         auto f = strtof(sz, &endptr);
//     else static if (is(F == double))
//         auto f = strtod(sz, &endptr);
//     else static if (is(F == real))
//         auto f = strtold(sz, &endptr);
//     else
//         static assert(false);
//     if (getErrno() == ERANGE)
//         goto Lerr;
//     assert(endptr);
//     if (endptr == sz)
//     {
//         // no progress
//         goto Lerr;
//     }
//     s = s[endptr - sz .. $];
//     return f;
//   Lerr:
//     ConvError.raise!(S[], F)(s);
//     assert(0);
// }

unittest
{
    debug( conv ) writefln( "conv.to!float.unittest" );
    float f;

    f = to!float( "nAn" );
    assert(isnan(f));
    f = to!float( "123" );
    assert( f == 123f );
    f = to!float( "+123" );
    assert( f == +123f );
    f = to!float( "-123" );
    assert( f == -123f );
    f = to!float( "123e+2" );
    assert( f == 123e+2f );

    f = to!float( "123e-2" );
    assert( f == 123e-2f );
    f = to!float( "123." );
    assert( f == 123.f );
    f = to!float( ".456" );
    assert( f == .456f );

    // min and max
    f = to!float("1.17549e-38");
    assert(feq(cast(real)f, cast(real)1.17549e-38));
    assert(feq(cast(real)f, cast(real)float.min_normal));
    f = to!float("3.40282e+38");
    assert(to!string(f) == to!string(3.40282e+38));

    // nan
    f = to!float("nan");
    assert(to!string(f) == to!string(float.nan));

    bool ok = false;
    try
    {
        to!float("\x00");
    }
    catch (ConvError e)
    {
        ok = true;
    }
    assert(ok);
}

/*
Tests for to!double
 */

unittest
{
    debug( conv ) writefln( "conv.to!double.unittest" );
    double d;

    d = to!double( "123" );
    assert( d == 123 );
    d = to!double( "+123" );
    assert( d == +123 );
    d = to!double( "-123" );
    assert( d == -123 );
    d = to!double( "123e2" );
    assert( d == 123e2);
    d = to!double( "123e-2" );
    assert( d == 123e-2 );
    d = to!double( "123." );
    assert( d == 123. );
    d = to!double( ".456" );
    assert( d == .456 );
    d = to!double( "1.23456E+2" );
    assert( d == 1.23456E+2 );

    // min and max
    d = to!double("2.22507e-308");
    assert(feq(cast(real)d, cast(real)2.22508e-308));
    assert(feq(cast(real)d, cast(real)double.min_normal));
    d = to!double("1.79769e+308");
    assert(to!string(d) == to!string(1.79769e+308));
    assert(to!string(d) == to!string(double.max));

    // nan
    d = to!double("nan");
    assert(to!string(d) == to!string(double.nan));
    //assert(cast(real)d == cast(real)double.nan);

    bool ok = false;
    try
    {
        to!double("\x00");
    }
    catch (ConvError e)
    {
        ok = true;
    }
    assert(ok);
}

/*
Tests for to!real
 */
unittest
{
    debug(conv) writefln("conv.to!real.unittest");
    real r;

    r = to!real("123");
    assert(r == 123L);
    r = to!real("+123");
    assert(r == 123L);
    r = to!real("-123");
    assert(r == -123L);
    r = to!real("123e2");
    assert(feq(r, 123e2L));
    r = to!real("123e-2");
    assert(feq(r, 1.23L));
    r = to!real("123.");
    assert(r == 123L);
    r = to!real(".456");
    assert(r == .456L);

    r = to!real("1.23456e+2");
    assert(feq(r,  1.23456e+2L));
    r = to!real(to!string(real.max / 2L));
    assert(to!string(r) == to!string(real.max / 2L));

    // min and max
    r = to!real(to!string(real.min_normal));
    assert(to!string(r) == to!string(real.min_normal));
    r = to!real(to!string(real.max));
    assert(to!string(r) == to!string(real.max));

    // nan
    r = to!real("nan");
    assert(to!string(r) == to!string(real.nan));
    //assert(r == real.nan);

    r = to!real(to!string(real.nan));
    assert(to!string(r) == to!string(real.nan));
    //assert(r == real.nan);

    bool ok = false;
    try
    {
        to!real("\x00");
    }
    catch (ConvError e)
    {
        ok = true;
    }
    assert(ok);
}

version (none)
{   /* These are removed for the moment because of concern about
     * what to do about the 'i' suffix. Should it be there?
     * Should it not? What about 'nan', should it be 'nani'?
     * 'infinity' or 'infinityi'?
     * Should it match what to!string(ifloat) does with the 'i' suffix?
     */

/*******************************************************
 * ditto
 */

    ifloat toIfloat(in string s)
    {
        return toFloat(s) * 1.0i;
    }

    unittest
    {
        debug(conv) writefln("conv.toIfloat.unittest");
        ifloat ift;

        ift = toIfloat(to!string(123.45));
        assert(to!string(ift) == to!string(123.45i));

        ift = toIfloat(to!string(456.77i));
        assert(to!string(ift) == to!string(456.77i));

        // min and max
        ift = toIfloat(to!string(ifloat.min_normal));
        assert(to!string(ift) == to!string(ifloat.min_normal) );
        assert(feq(cast(ireal)ift, cast(ireal)ifloat.min_normal));

        ift = toIfloat(to!string(ifloat.max));
        assert(to!string(ift) == to!string(ifloat.max));
        assert(feq(cast(ireal)ift, cast(ireal)ifloat.max));

        // nan
        ift = toIfloat("nani");
        assert(cast(real)ift == cast(real)ifloat.nan);

        ift = toIfloat(to!string(ifloat.nan));
        assert(to!string(ift) == to!string(ifloat.nan));
        assert(feq(cast(ireal)ift, cast(ireal)ifloat.nan));
    }

/*******************************************************
 * ditto
 */

    idouble toIdouble(in string s)
    {
        return toDouble(s) * 1.0i;
    }

    unittest
    {
        debug(conv) writefln("conv.toIdouble.unittest");
        idouble id;

        id = toIdouble(to!string("123.45"));
        assert(id == 123.45i);

        id = toIdouble(to!string("123.45e+302i"));
        assert(id == 123.45e+302i);

        // min and max
        id = toIdouble(to!string(idouble.min_normal));
        assert(to!string( id ) == to!string(idouble.min_normal));
        assert(feq(cast(ireal)id.re, cast(ireal)idouble.min_normal.re));
        assert(feq(cast(ireal)id.im, cast(ireal)idouble.min_normal.im));

        id = toIdouble(to!string(idouble.max));
        assert(to!string(id) == to!string(idouble.max));
        assert(feq(cast(ireal)id.re, cast(ireal)idouble.max.re));
        assert(feq(cast(ireal)id.im, cast(ireal)idouble.max.im));

        // nan
        id = toIdouble("nani");
        assert(cast(real)id == cast(real)idouble.nan);

        id = toIdouble(to!string(idouble.nan));
        assert(to!string(id) == to!string(idouble.nan));
    }

/*******************************************************
 * ditto
 */

    ireal toIreal(in string s)
    {
        return toReal(s) * 1.0i;
    }

    unittest
    {
        debug(conv) writefln("conv.toIreal.unittest");
        ireal ir;

        ir = toIreal(to!string("123.45"));
        assert(feq(cast(real)ir.re, cast(real)123.45i)); 

        ir = toIreal(to!string("123.45e+82i"));
        assert(to!string(ir) == to!string(123.45e+82i));
        //assert(ir == 123.45e+82i);

        // min and max
        ir = toIreal(to!string(ireal.min));
        assert(to!string(ir) == to!string(ireal.min_normal));
        assert(feq(cast(real)ir.re, cast(real)ireal.min_normal.re));
        assert(feq(cast(real)ir.im, cast(real)ireal.min_normal.im));

        ir = toIreal(to!string(ireal.max));
        assert(to!string(ir) == to!string(ireal.max));
        assert(feq(cast(real)ir.re, cast(real)ireal.max.re));
        //assert(feq(cast(real)ir.im, cast(real)ireal.max.im));

        // nan
        ir = toIreal("nani");
        assert(cast(real)ir == cast(real)ireal.nan);

        ir = toIreal(to!string(ireal.nan));
        assert(to!string(ir) == to!string(ireal.nan));
    }


/*******************************************************
 * ditto
 */
    cfloat toCfloat(in string s)
    {
        string s1;
        string s2;
        real   r1;
        real   r2;
        cfloat cf;
        bool    b = 0;
        char*  endptr;

        if (!s.length)
            goto Lerr;

        b = getComplexStrings(s, s1, s2);

        if (!b)
            goto Lerr;

        // atof(s1);
        endptr = &s1[s1.length - 1];
        r1 = strtold(s1, &endptr); 

        // atof(s2);
        endptr = &s2[s2.length - 1];
        r2 = strtold(s2, &endptr); 

        cf = cast(cfloat)(r1 + (r2 * 1.0i));

        //writefln( "toCfloat() r1=%g, r2=%g, cf=%g, max=%g", 
        //           r1, r2, cf, cfloat.max);
        // Currently disabled due to a posted bug where a 
        // complex float greater-than compare to .max compares 
        // incorrectly.
        //if (cf > cfloat.max)
        //    goto Loverflow;

        return cf;

      Loverflow:
        conv_overflow(s);

      Lerr:
        conv_error(s);
        return cast(cfloat)0.0e-0+0i;
    }

    unittest
    {
        debug(conv) writefln("conv.toCfloat.unittest");
        cfloat cf;

        cf = toCfloat(to!string("1.2345e-5+0i"));
        assert(to!string(cf) == to!string(1.2345e-5+0i));
        assert(feq(cf, 1.2345e-5+0i));

        // min and max
        cf = toCfloat(to!string(cfloat.min));
        assert(to!string(cf) == to!string(cfloat.min));

        cf = toCfloat(to!string(cfloat.max));
        assert(to!string(cf) == to!string(cfloat.max));

        // nan ( nan+nani )
        cf = toCfloat("nani");
        //writefln("toCfloat() cf=%g, cf=\"%s\", nan=%s", 
        //         cf, to!string(cf), to!string(cfloat.nan));
        assert(to!string(cf) == to!string(cfloat.nan));

        cf = toCdouble("nan+nani");
        assert(to!string(cf) == to!string(cfloat.nan));

        cf = toCfloat(to!string(cfloat.nan));
        assert(to!string(cf) == to!string(cfloat.nan));
        assert(feq(cast(creal)cf, cast(creal)cfloat.nan));
    }

/*******************************************************
 * ditto
 */
    cdouble toCdouble(in string s)
    {
        string  s1;
        string  s2;
        real    r1;
        real    r2;
        cdouble cd;
        bool     b = 0;
        char*   endptr;

        if (!s.length)
            goto Lerr;

        b = getComplexStrings(s, s1, s2);

        if (!b)
            goto Lerr;

        // atof(s1);
        endptr = &s1[s1.length - 1];
        r1 = strtold(s1, &endptr); 

        // atof(s2);
        endptr = &s2[s2.length - 1];
        r2 = strtold(s2, &endptr); //atof(s2);

        cd = cast(cdouble)(r1 + (r2 * 1.0i));

        //Disabled, waiting on a bug fix.
        //if (cd > cdouble.max)  //same problem the toCfloat() having
        //    goto Loverflow;

        return cd;

      Loverflow:
        conv_overflow(s);

      Lerr:
        conv_error(s);
        return cast(cdouble)0.0e-0+0i;
    }

    unittest
    {
        debug(conv) writefln("conv.toCdouble.unittest");
        cdouble cd;

        cd = toCdouble(to!string("1.2345e-5+0i"));
        assert(to!string( cd ) == to!string(1.2345e-5+0i));
        assert(feq(cd, 1.2345e-5+0i));

        // min and max
        cd = toCdouble(to!string(cdouble.min));
        assert(to!string(cd) == to!string(cdouble.min));
        assert(feq(cast(creal)cd, cast(creal)cdouble.min));

        cd = toCdouble(to!string(cdouble.max));
        assert(to!string( cd ) == to!string(cdouble.max));
        assert(feq(cast(creal)cd, cast(creal)cdouble.max));

        // nan ( nan+nani )
        cd = toCdouble("nani");
        assert(to!string(cd) == to!string(cdouble.nan));

        cd = toCdouble("nan+nani");
        assert(to!string(cd) == to!string(cdouble.nan));

        cd = toCdouble(to!string(cdouble.nan));
        assert(to!string(cd) == to!string(cdouble.nan));
        assert(feq(cast(creal)cd, cast(creal)cdouble.nan));
    }

/*******************************************************
 * ditto
 */
    creal toCreal(in string s)
    {
        string s1;
        string s2;
        real   r1;
        real   r2;
        creal  cr;
        bool    b = 0;
        char*  endptr;

        if (!s.length)
            goto Lerr;

        b = getComplexStrings(s, s1, s2);

        if (!b)
            goto Lerr;

        // atof(s1);
        endptr = &s1[s1.length - 1];
        r1 = strtold(s1, &endptr); 

        // atof(s2);
        endptr = &s2[s2.length - 1];
        r2 = strtold(s2, &endptr); //atof(s2);

        //writefln("toCreal() r1=%g, r2=%g, s1=\"%s\", s2=\"%s\", nan=%g", 
        //          r1, r2, s1, s2, creal.nan);

        if (s1 =="nan" && s2 == "nani")
            cr = creal.nan;
        else if (r2 != 0.0)
            cr = cast(creal)(r1 + (r2 * 1.0i));
        else
            cr = cast(creal)(r1 + 0.0i);    
    
        return cr;

      Lerr:
        conv_error(s);
        return cast(creal)0.0e-0+0i;
    }

    unittest
    {
        debug(conv) writefln("conv.toCreal.unittest");
        creal cr;

        cr = toCreal(to!string("1.2345e-5+0i"));
        assert(to!string(cr) == to!string(1.2345e-5+0i));
        assert(feq(cr, 1.2345e-5+0i));

        cr = toCreal(to!string("0.0e-0+0i"));
        assert(to!string(cr) == to!string(0.0e-0+0i));
        assert(cr == 0.0e-0+0i);
        assert(feq(cr, 0.0e-0+0i));

        cr = toCreal("123");
        assert(cr == 123);

        cr = toCreal("+5");
        assert(cr == 5);

        cr = toCreal("-78");
        assert(cr == -78);

        // min and max
        cr = toCreal(to!string(creal.min));
        assert(to!string(cr) == to!string(creal.min));
        assert(feq(cr, creal.min));

        cr = toCreal(to!string(creal.max));
        assert(to!string(cr) == to!string(creal.max));
        assert(feq(cr, creal.max));

        // nan ( nan+nani )
        cr = toCreal("nani");
        assert(to!string(cr) == to!string(creal.nan));

        cr = toCreal("nan+nani");
        assert(to!string(cr) == to!string(creal.nan));

        cr = toCreal(to!string(cdouble.nan));
        assert(to!string(cr) == to!string(creal.nan));
        assert(feq(cr, creal.nan));
    }

}

/* **************************************************************
 * Splits a complex float (cfloat, cdouble, and creal) into two workable strings.
 * Grammar:
 * ['+'|'-'] string floating-point digit {digit}
 */
private bool getComplexStrings(in string s, out string s1, out string s2)
{
    int len = s.length;

    if (!len)
        goto Lerr;

    // When "nan" or "nani" just return them.
    if (s == "nan" || s == "nani" || s == "nan+nani")
    {
        s1 = "nan";
        s2 = "nani";
        return 1;
    }

    // Split the original string out into two strings.
    for (int i = 1; i < len; i++)
        if ((s[i - 1] != 'e' && s[i - 1] != 'E') && s[i] == '+')
        {
            //s1 = s[0..i]; should work, doesn't
            s1 = s[0..i];
            if (i + 1 < len - 1)
                s2 = s[i + 1..len - 1];
            else
                s2 = "0e+0i";

            break;
        }

    // Handle the case when there's only a single value
    // to work with, and set the other string to zero.
    if (!s1.length)
    {
        s1 = s;
        s2 = "0e+0i";
    }

    //writefln( "getComplexStrings() s=\"%s\", s1=\"%s\", s2=\"%s\", len=%d",
    //           s, s1, s2, len );

    return 1;

  Lerr:
    // Display the original string in the error message.
    throw new ConvError("getComplexStrings() \"" ~ s ~ "\"" ~ " s1=\""
            ~ s1 ~ "\"" ~ " s2=\"" ~ s2 ~ "\"");
}

// feq() functions now used only in unittesting

/* ***************************************
 * Main function to compare reals with given precision
 */
private bool feq(in real rx, in real ry, in real precision)
{
    if (rx == ry)
        return 1;

    if (isnan(rx))
        return cast(bool)isnan(ry);

    if (isnan(ry))
        return 0;

    return cast(bool)(fabs(rx - ry) <= precision);
}

/* ***************************************
 * (Note: Copied here from std.math's mfeq() function for unittesting)
 * Simple function to compare two floating point values
 * to a specified precision.
 * Returns:
 *  1   match
 *  0   nomatch
 */
private bool feq(in real r1, in real r2)
{
    if (r1 == r2)
        return 1;

    if (isnan(r1))
        return cast(bool)isnan(r2);

    if (isnan(r2))
        return 0;

    return cast(bool)(feq(r1, r2, 0.000001L));
}

/* ***************************************
 * compare ireals with given precision
 */
private bool feq(in ireal r1, in ireal r2)
{
    real rx = cast(real)r1;
    real ry = cast(real)r2;

    if (rx == ry)
        return 1;

    if (isnan(rx))
        return cast(bool)isnan(ry);

    if (isnan(ry))
        return 0;

    return feq(rx, ry, 0.000001L);
}

/* ***************************************
 * compare creals with given precision
 */
private bool feq(in creal r1, in creal r2)
{
    real r1a = fabs(cast(real)r1.re - cast(real)r2.re);
    real r2b = fabs(cast(real)r1.im - cast(real)r2.im);

    if ((cast(real)r1.re == cast(real)r2.re) &&
            (cast(real)r1.im == cast(real)r2.im))
        return 1;

    if (isnan(r1a))
        return cast(bool)isnan(r2b);

    if (isnan(r2b))
        return 0;

    return feq(r1a, r2b, 0.000001L);
}

/// Small unsigned integers to strings.
T to(T, S)(S value) if (isIntegral!S && S.min == 0
        && S.sizeof < uint.sizeof && isSomeString!T)
{
    return to!T(cast(uint) value);
}

/// Small signed integers to strings.
T to(T, S)(S value) if (isIntegral!S && S.min < 0
        && S.sizeof < int.sizeof && isSomeString!T)
{
    return to!T(cast(int) value);
}

/// Unsigned integers (uint and ulong) to string.
T to(T, S)(S input)
if (std.typetuple.staticIndexOf!(Unqual!S, uint, ulong) >= 0 && isSomeString!T)
{
    Unqual!S value = input;
    alias Unqual!(typeof(T.init[0])) Char;
    static if (is(typeof(T.init[0]) == const) ||
            is(typeof(T.init[0]) == immutable))
    {
        if (value < 10)
        {
            static immutable Char[10] digits = "0123456789";
            // Avoid storage allocation for simple stuff
            return digits[cast(size_t) value .. cast(size_t) value + 1];
        }
    }

    static if (S.sizeof == uint.sizeof)
        enum maxlength = S.sizeof * 3;
    else
        auto maxlength = (value > uint.max ? S.sizeof : uint.sizeof) * 3;
 
    Char[] result;
    if (__ctfe)
        result = new Char[maxlength];
    else 
        result = cast(Char[])
            GC.malloc(Char.sizeof * maxlength, GC.BlkAttr.NO_SCAN)
            [0 .. Char.sizeof * maxlength];

    uint ndigits = 0;
    do
    {
        const c = cast(Char) ((value % 10) + '0');
        value /= 10;
        ndigits++;
        result[$ - ndigits] = c;
    }
    while (value);
    return cast(T) result[$ - ndigits .. $];
}

unittest
{
    assert(wtext(int.max) == "2147483647"w);
    assert(wtext(int.min) == "-2147483648"w);
    assert(to!string(0L) == "0");
}

/// $(D char), $(D wchar), $(D dchar) to a string type.
T to(T, S)(S c) if (staticIndexOf!(Unqual!S, char, wchar, dchar) >= 0
        && isSomeString!(T))
{
    alias typeof(T.init[0]) Char;
    static if (Char.sizeof >= S.sizeof)
    {
        return [ c ];
    }
    else
    {
        Unqual!Char[] result;
        encode(result, c);
        return cast(T) result;
    }
}

version(unittest) private alias TypeTuple!(
    char, wchar, dchar,
    const(char), const(wchar), const(dchar),
    immutable(char), immutable(wchar), immutable(dchar))
                      AllChars;

unittest
{
    foreach (Char1; AllChars)
    {
        foreach (Char2; AllChars)
        {
            Char1 c = 'a';
            assert(to!(Char2[])(c)[0] == c);
        }
        uint x = 4;
        assert(to!(Char1[])(x) == "4");
    }
}

/// Signed values ($(D int) and $(D long)).
T to(T, S)(S value)
if (staticIndexOf!(Unqual!S, int, long) >= 0 && isSomeString!T)
{
    if (value >= 0)
        return to!T(cast(Unsigned!(S)) value);
    alias Unqual!(typeof(T.init[0])) Char;

    // Cache read-only data only for const and immutable - mutable
    // data is supposed to use allocation in all cases
    static if (is(ElementType!T == const) || is(ElementType!T == immutable))
    {
        if (value > -10)
        {
            static immutable Char[20] data =
                "00-1-2-3-4-5-6-7-8-9";
            immutable i = cast(size_t) -value * 2;
            return data[i .. i + 2];
        }
    }

    Char[1 + S.sizeof * 3] buffer;

    auto u = -cast(Unqual!(Unsigned!S)) value;
    uint ndigits = 1;
    while (u)
    {
        immutable c = cast(char)((u % 10) + '0');
        u /= 10;
        buffer[$ - ndigits] = c;
        ++ndigits;
    }
    assert(ndigits <= buffer.length);
    buffer[$ - ndigits] = '-';
    return cast(T) buffer[buffer.length - ndigits .. buffer.length].dup;
}

unittest
{
    string r;
    int i;

    r = to!string(0L);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9L);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123L);
    i = cmp(r, "123");
    assert(i == 0);

    r = to!string(-0L);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(-9L);
    i = cmp(r, "-9");
    assert(i == 0);

    r = to!string(-123L);
    i = cmp(r, "-123");
    assert(i == 0);

    const h  = 6;
    string s = to!string(h);
    assert(s == "6");
}

/// C-style strings
T to(T, S)(S s) if (is(S : const(char)*) && isSomeString!(T))
{
    return s ? cast(T) s[0 .. strlen(s)].dup : cast(string)null;
}

/// $(D float) to all string types.
T to(T, S)(S f) if (is(Unqual!S == float) && isSomeString!(T))
{
    return to!T(cast(double) f);
}

/// $(D double) to all string types.
T to(T, S)(S d) if (is(Unqual!S == double) && isSomeString!(T))
{
    //alias Unqual!(ElementType!T) Char;
    char[20] buffer;
    int len = sprintf(buffer.ptr, "%g", d);
    return to!T(buffer[0 .. len].dup);
}

/// $(D real) to all string types.
T to(T, S)(S r) if (is(Unqual!S == real) && isSomeString!(T))
{
    char[20] buffer;
    int len = sprintf(buffer.ptr, "%Lg", r);
    return to!T(buffer[0 .. len].dup);
}

/// $(D ifloat) to all string types.
T to(T, S)(S f) if (is(Unqual!S == ifloat) && isSomeString!(T))
{
    return to!T(cast(idouble) f);
}

/// $(D idouble) to all string types.
T to(T, S)(S d) if (is(Unqual!S == idouble) && isSomeString!(T))
{
    char[21] buffer;
    int len = sprintf(buffer.ptr, "%gi", d);
    return to!T(buffer[0 .. len].dup);
}

/// $(D ireal) to all string types.
T to(T, S)(S r) if (is(Unqual!S == ireal) && isSomeString!(T))
{
    char[21] buffer;
    int len = sprintf(buffer.ptr, "%Lgi", r);
    //assert(len < buffer.length); // written bytes is len + 1
    return to!T(buffer[0 .. len].dup);
}

/// $(D cfloat) to all string types.
T to(T, S)(S f) if (is(Unqual!S == cfloat) && isSomeString!(T))
{
    return to!string(cast(cdouble) f);
}

/// $(D cdouble) to all string types.
T to(T, S)(S d) if (is(Unqual!S == cdouble) && isSomeString!(T))
{
    char[20 + 1 + 20 + 1] buffer;

    int len = sprintf(buffer.ptr, "%g+%gi", d.re, d.im);
    return to!T(buffer[0 .. len]);
}

/// $(D creal) to all string types.
T to(T, S)(S r) if (is(Unqual!S == creal) && isSomeString!(T))
{
    char[20 + 1 + 20 + 1] buffer;
    int len = sprintf(buffer.ptr, "%Lg+%Lgi", r.re, r.im);
    return to!T(buffer[0 .. len].dup);
}

/******************************************
 * Convert value to string in _radix radix.
 *
 * radix must be a value from 2 to 36.
 * value is treated as a signed value only if radix is 10.
 * The characters A through Z are used to represent values 10 through 36.
 */
T to(T, S)(S value, uint radix)
if (isIntegral!(Unqual!S) && !is(Unqual!S == ulong) && isSomeString!(T))
in
{
    assert(radix >= 2 && radix <= 36);
}
body
{
    if (radix == 10)
        return to!string(value);     // handle signed cases only for radix 10
    return to!string(cast(ulong) value, radix);
}

/// ditto
T to(T, S)(S value, uint radix)
if (is(Unqual!S == ulong) && isSomeString!(T))
in
{
    assert(radix >= 2 && radix <= 36);
}
body
{
    char[value.sizeof * 8] buffer;
    uint i = buffer.length;
    
    if (value < radix && value < hexdigits.length)
        return hexdigits[cast(size_t)value .. cast(size_t)value + 1];
    
    do
    {
        ubyte c;
        c = cast(ubyte)(value % radix);
        value = value / radix;
        i--;
        buffer[i] = cast(char)((c < 10) ? c + '0' : c + 'A' - 10);
    } while (value);
    return to!T(buffer[i .. $].dup);
}

unittest
{
    size_t x = 16;
    assert(to!string(x, 16) == "10");
}

unittest
{
    debug(string) printf("string.toString(ulong, uint).unittest\n");

    string r;
    int i;

    r = to!string(-10L, 10u);
    assert(r == "-10");

    r = to!string(15L, 2u);
    //writefln("r = '%s'", r);
    assert(r == "1111");

    r = to!string(1L, 2u);
    //writefln("r = '%s'", r);
    assert(r == "1");

    r = to!string(0x1234AFL, 16u);
    //writefln("r = '%s'", r);
    assert(r == "1234AF");
}

unittest
{
    debug(string) printf("string.toString(char).unittest\n");

    string s = "foo";
    string s2;
    foreach (char c; s)
    {
        s2 ~= to!string(c);
    }
    //printf("%.*s", s2);
    assert(s2 == "foo");
}

unittest
{
    debug(string) printf("string.toString(uint).unittest\n");

    string r;
    int i;

    r = to!string(0u);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9u);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123u);
    i = cmp(r, "123");
    assert(i == 0);
}

unittest
{
    debug(string) printf("string.toString(ulong).unittest\n");

    string r;
    int i;

    r = to!string(0uL);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9uL);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123uL);
    i = cmp(r, "123");
    assert(i == 0);
}

unittest
{
    debug(string) printf("string.toString(int).unittest\n");

    string r;
    int i;

    r = to!string(0);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123);
    i = cmp(r, "123");
    assert(i == 0);

    r = to!string(-0);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(-9);
    i = cmp(r, "-9");
    assert(i == 0);

    r = to!string(-123);
    i = cmp(r, "-123");
    assert(i == 0);
}

unittest
{
    debug(string) printf("string.toString(long).unittest\n");

    string r;
    int i;

    r = to!string(0L);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9L);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123L);
    i = cmp(r, "123");
    assert(i == 0);

    r = to!string(-0L);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(-9L);
    i = cmp(r, "-9");
    assert(i == 0);

    r = to!string(-123L);
    i = cmp(r, "-123");
    assert(i == 0);
}

unittest
{
    debug(string) printf("string.to!string(ulong, uint).unittest\n");

    string r;
    int i;

    r = to!string(-10L, 10u);
    assert(r == "-10");

    r = to!string(15L, 2u);
    //writefln("r = '%s'", r);
    assert(r == "1111");

    r = to!string(1L, 2u);
    //writefln("r = '%s'", r);
    assert(r == "1");

    r = to!string(0x1234AFL, 16u);
    //writefln("r = '%s'", r);
    assert(r == "1234AF");
}

unittest
{
    debug(string) printf("string.to!string(char*).unittest\n");

    string r;
    int i;

    r = to!string(cast(char*) null);
    i = cmp(r, "");
    assert(i == 0);

    r = to!string("foo\0".ptr);
    i = cmp(r, "foo");
    assert(i == 0);
}

unittest
{
    string s = "foo";
    string s2;
    foreach (char c; s)
    {
        s2 ~= to!string(c);
    }
    //printf("%.*s", s2);
    assert(s2 == "foo");
}

unittest
{
    string r;
    int i;

    r = to!string(0uL);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9uL);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123uL);
    i = cmp(r, "123");
    assert(i == 0);
}

unittest
{
    string r;
    int i;

    r = to!string(0u);
    i = cmp(r, "0");
    assert(i == 0);

    r = to!string(9u);
    i = cmp(r, "9");
    assert(i == 0);

    r = to!string(123u);
    i = cmp(r, "123");
    assert(i == 0);
}

/**
Pointer to string conversions prints the pointer as a $(D size_t) value.
 */
T to(T, S)(S value)
if (isPointer!S && !isSomeChar!(typeof(*S.init)) && isSomeString!T)
{
    return to!T(cast(size_t) value, 16u);
}

private S textImpl(S, U...)(U args)
{
    S result;
    foreach (i, arg; args)
    {
        result ~= to!S(args[i]);
    }
    return result;
}

/**
   Convenience functions for converting any number and types of
   arguments into _text (the three character widths).

   Example:
   ----
   assert(text(42, ' ', 1.5, ": xyz") == "42 1.5: xyz");
   assert(wtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"w);
   assert(dtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"d);
   ----
*/
string text(T...)(T args) { return textImpl!(string, T)(args); }
///ditto
wstring wtext(T...)(T args) { return textImpl!(wstring, T)(args); }
///ditto
dstring dtext(T...)(T args) { return textImpl!(dstring, T)(args); }

unittest
{
    assert(text(42, ' ', 1.5, ": xyz") == "42 1.5: xyz");
    assert(wtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"w);
    assert(dtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"d);
}

unittest
{
    typedef uint Testing;
    auto s = "123";
    auto t = parse!Testing(s);
    assert(t == cast(Testing) 123);
}

//------------------------------------------------------------------------------
// octal
//------------------------------------------------------------------------------
/*
Take a look at int.max and int.max+1 in octal and the logic for this
function follows directly.
 */
template octalFitsInInt(string octalNum) {
	// note it is important to strip the literal of all
	// non-numbers. kill the suffix and underscores lest they mess up
	// the number of digits here that we depend on.
    enum bool octalFitsInInt = strippedOctalLiteral(octalNum).length < 11 ||
        strippedOctalLiteral(octalNum).length == 11 &&
        strippedOctalLiteral(octalNum)[0] == '1';
}

string strippedOctalLiteral(string original) {
	string stripped;
	foreach (c; original)
		if (c >= '0' && c <= '7')
			stripped ~= c;
	return stripped;
}

template literalIsLong(string num) {
	static if (num.length > 1)
        // can be xxL or xxLu according to spec
		enum literalIsLong = (num[$-1] == 'L' || num[$-2] == 'L');
	else
		enum literalIsLong = false;
}

template literalIsUnsigned(string num) {
	static if (num.length > 1)
        // can be xxL or xxLu according to spec
		enum literalIsUnsigned = (num[$-1] == 'u' || num[$-2] == 'u')
            // both cases are allowed too
            || (num[$-1] == 'U' || num[$-2] == 'U'); 
	else
        enum literalIsUnsigned = false;
}

/**
The $(D octal) facility is intended as an experimental facility to
replace _octal literals starting with $(D '0'), which many find
confusing. Using $(D octal!177) or $(D octal!"177") instead of $(D
0177) as an _octal literal makes code clearer and the intent more
visible. If use of this facility becomes preponderent, a future
version of the language may deem old-style _octal literals deprecated.

The rules for strings are the usual for literals: If it can fit in an
$(D int), it is an $(D int). Otherwise, it is a $(D long). But, if the
user specifically asks for a $(D long) with the $(D L) suffix, always
give the $(D long). Give an unsigned iff it is asked for with the $(D
U) or $(D u) suffix. _Octals created from integers preserve the type
of the passed-in integral.

Example:
----
// same as 0177
auto x = octal!177;
// octal is a compile-time device
enum y = octal!160;
// Create an unsigned octal
auto z = octal!"1_000_000u";
----
 */
int octal(string num)()
if((octalFitsInInt!(num) && !literalIsLong!(num)) && !literalIsUnsigned!(num)) {
	return octal!(int, num);
}

/// Ditto
long octal(string num)()
if((!octalFitsInInt!(num) || literalIsLong!(num)) && !literalIsUnsigned!(num)) {
	return octal!(long, num);
}

/// Ditto
uint octal(string num)()
if((octalFitsInInt!(num) && !literalIsLong!(num)) && literalIsUnsigned!(num)) {
	return octal!(int, num);
}

/// Ditto
ulong octal(string num)()
if((!octalFitsInInt!(num) || literalIsLong!(num)) && literalIsUnsigned!(num)) {
	return octal!(long, num);
}

/*
Returns if the given string is a correctly formatted octal literal.

The format is specified in lex.html. The leading zero is allowed, but
not required.
 */
bool isOctalLiteralString(string num) {
	if (num.length == 0)
		return false;
    
	// Must start with a number. To avoid confusion, literals that
    // start with a '0' are not allowed
    if (num[0] == '0' && num.length > 1)
        return false;
	if (num[0] < '0' || num[0] > '7')
		return false;
	
	foreach (i, c; num) {
		if ((c < '0' || c > '7') && c != '_') // not a legal character
			if (i < num.length - 2)
				return false;
			else { // gotta check for those suffixes
				if (c != 'U' && c != 'u' && c != 'L')
					return false;
				if (i != num.length - 1) {
                    // if we're not the last one, the next one must
                    // also be a suffix to be valid
					char c2 = num[$-1];
					if (c2 != 'U' && c2 != 'u' && c2 != 'L')
						return false; // spam at the end of the string
					if (c2 == c)
						return false; // repeats are disallowed
				}
			}
	}

	return true;
}

/*
	Returns true if the given compile time string is an octal literal.
*/
template isOctalLiteral(string num) {
	enum bool isOctalLiteral = isOctalLiteralString(num);
}

/*
	Takes a string, num, which is an octal literal, and returns its
	value, in the type T specified.

	So:

	int a = octal!(int, "10");

	assert(a == 8);
*/
T octal(T, string num)() {
    static assert(isOctalLiteral!num, num ~ " is not a valid octal literal");

    ulong pow = 1;
    T value = 0;

    for (int pos = num.length - 1; pos >= 0; pos--) {
        char s = num[pos];
	if (s < '0' || s > '7') // we only care about digits; skip the rest
        // safe to skip - this is checked out in the assert so these
        // are just suffixes
		continue; 
	
	value += pow * (s - '0');
	pow *= 8;
  }

  return value;
}

/// Ditto
template octal(alias s) if (isIntegral!(typeof(s))) {
	enum auto octal = octal!(typeof(s), toStringNow!(s));
}

unittest
{
	// ensure that you get the right types, even with embedded underscores
	auto w = octal!"100_000_000_000";
	static assert(!is(typeof(w) == int));
	auto w2 = octal!"1_000_000_000";
	static assert(is(typeof(w2) == int));

    static assert(octal!"45" == 37);
    static assert(octal!"0" == 0);
    static assert(octal!"7" == 7);
    static assert(octal!"10" == 8);
    static assert(octal!"666" == 438);

    static assert(octal!45 == 37);
    static assert(octal!0 == 0);
    static assert(octal!7 == 7);
    static assert(octal!10 == 8);
    static assert(octal!666 == 438);

    static assert(octal!"66_6" == 438);

    static assert(octal!2520046213 == 356535435);
    static assert(octal!"2520046213" == 356535435);

    static assert(octal!17777777777 == int.max);

    static assert(!__traits(compiles, octal!823));

    // for some reason, this line fails, though if you try it in code,
    // it indeed doesn't compile... weird.

    // static assert(!__traits(compiles, octal!"823"));

    static assert(!__traits(compiles, octal!"_823"));
    static assert(!__traits(compiles, octal!"spam"));
    static assert(!__traits(compiles, octal!"77%"));

    int a;
    long b;

    // biggest value that should fit in an it
    static assert(__traits(compiles,  a = octal!"17777777777"));
    // should not fit in the int
    static assert(!__traits(compiles, a = octal!"20000000000"));
    // ... but should fit in a long
    static assert(__traits(compiles, b = octal!"20000000000")); 
    
    static assert(!__traits(compiles, a = octal!"1L"));

    // this should pass, but it doesn't, since the int converter
    // doesn't pass along its suffix to helper templates

    //static assert(!__traits(compiles, a = octal!1L));

    static assert(__traits(compiles, b = octal!"1L"));
    static assert(__traits(compiles, b = octal!1L));
}
