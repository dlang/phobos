// Written in the D programming language.

/**
A one-stop shop for converting values from one type to another.

Copyright: Copyright Digital Mars 2007-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           Shin Fujishiro,
           Adam D. Ruppe,
           Kenji Hara

Source:    $(PHOBOSSRC std/_conv.d)
*/
module std.conv;

import core.stdc.math : ldexpl;
import core.stdc.string;
import std.algorithm, std.array, std.ascii, std.exception, std.math, std.range,
    std.string, std.traits, std.typecons, std.typetuple, std.uni,
    std.utf;
import std.metastrings;

//debug=conv;           // uncomment to turn on debugging printf's

/* ************* Exceptions *************** */

/**
 * Thrown on conversion errors.
 */
class ConvException : Exception
{
    this(string s, string fn = __FILE__, size_t ln = __LINE__)
    {
        super(s, fn, ln);
    }
}

deprecated alias ConvException ConvError;   /// ditto

private void convError(S, T)(S source, string fn = __FILE__, size_t ln = __LINE__)
{
    throw new ConvException(
        text("Can't convert value `", source,
             "' of type "~S.stringof~" to type "~T.stringof), fn, ln);
}

private void convError(S, T)(S source, int radix, string fn = __FILE__, size_t ln = __LINE__)
{
    throw new ConvException(
        text("Can't convert value `", source,
             "' of type "~S.stringof~" base ", radix, " to type "~T.stringof), fn, ln);
}

private void parseError(lazy string msg, string fn = __FILE__, size_t ln = __LINE__)
{
    throw new ConvException(text("Can't parse string: ", msg), fn, ln);
}

private void parseCheck(alias source)(dchar c, string fn = __FILE__, size_t ln = __LINE__)
{
    if (source.front != c)
        parseError(text("\"", c, "\" is missing"), fn, ln);
    source.popFront();
}

private
{
    template isImaginary(T)
    {
        enum bool isImaginary = staticIndexOf!(Unqual!(T),
                ifloat, idouble, ireal) >= 0;
    }
    template isComplex(T)
    {
        enum bool isComplex = staticIndexOf!(Unqual!(T),
                cfloat, cdouble, creal) >= 0;
    }
    template isNarrowInteger(T)
    {
        enum bool isNarrowInteger = staticIndexOf!(Unqual!(T),
                byte, ubyte, short, ushort) >= 0;
    }
}

/**
 * Thrown on conversion overflow errors.
 */
class ConvOverflowException : ConvException
{
    this(string s, string fn = __FILE__, size_t ln = __LINE__)
    {
        super(s, fn, ln);
    }
}

deprecated alias ConvOverflowException ConvOverflowError;   /// ditto

/* **************************************************************

The $(D_PARAM to) family of functions converts a value from type
$(D_PARAM Source) to type $(D_PARAM Target). The source type is
deduced and the target type must be specified, for example the
expression $(D_PARAM to!int(42.0)) converts the number 42 from
$(D_PARAM double) to $(D_PARAM int). The conversion is "safe", i.e.,
it checks for overflow; $(D_PARAM to!int(4.2e10)) would throw the
$(D_PARAM ConvOverflowException) exception. Overflow checks are only
inserted when necessary, e.g., $(D_PARAM to!double(42)) does not do
any checking because any int fits in a double.

Converting a value to its own type (useful mostly for generic code)
simply returns its argument.
Example:
-------------------------
int a = 42;
auto b = to!int(a); // b is int with value 42
auto c = to!double(3.14); // c is double with value 3.14
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
auto b = to!long(a); // same as long b = a;
auto c = to!byte(a / 10); // fine, c = 42
auto d = to!byte(a); // throw ConvOverflowException
double e = 4.2e6;
auto f = to!int(e); // f == 4200000
e = -3.14;
auto g = to!uint(e); // fails: floating-to-integral negative overflow
e = 3.14;
auto h = to!uint(e); // h = 3
e = 3.99;
h = to!uint(a); // h = 3
e = -3.99;
f = to!int(a); // f = -3
-------------------------

Conversions from integral types to floating-point types always
succeed, but might lose accuracy. The largest integers with a
predecessor representable in floating-point format are 2^24-1 for
float, 2^53-1 for double, and 2^64-1 for $(D_PARAM real) (when
$(D_PARAM real) is 80-bit, e.g. on Intel machines).

Example:
-------------------------
int a = 16_777_215; // 2^24 - 1, largest proper integer representable as float
assert(to!int(to!float(a)) == a);
assert(to!int(to!float(-a)) == -a);
a += 2;
assert(to!int(to!float(a)) == a); // fails!
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

This conversion works because $(D_PARAM to!short) applies to an
$(D_PARAM int), $(D_PARAM to!wstring) applies to a $(D_PARAM
string), $(D_PARAM to!string) applies to a $(D_PARAM double), and
$(D_PARAM to!(double[])) applies to an $(D_PARAM int[]). The
conversion might throw an exception because $(D_PARAM to!short)
might fail the range check.

Macros: WIKI=Phobos/StdConv
 */

/**
   Entry point that dispatches to the appropriate conversion
   primitive. Client code normally calls $(D _to!TargetType(value))
   (and not some variant of $(D toImpl)).
 */
template to(T)
{
    T to(A...)(A args)
    {
        return toImpl!T(args);
    }
}

/**
If the source type is implicitly convertible to the target type, $(D
to) simply performs the implicit conversion.
 */
T toImpl(T, S)(S value)
    if (isImplicitlyConvertible!(S, T))
{
    alias isUnsigned isUnsignedInt;

    // Conversion from integer to integer, and changing its sign
    static if (isUnsignedInt!S && isSignedInt!T && S.sizeof == T.sizeof)
    {   // unsigned to signed & same size
        enforce(value <= cast(S)T.max,
                new ConvOverflowException("Conversion positive overflow"));
    }
    else static if (isSignedInt!S && isUnsignedInt!T)
    {   // signed to unsigned
        enforce(0 <= value,
                new ConvOverflowException("Conversion negative overflow"));
    }

    return value;
}

private template isSignedInt(T)
{
    enum isSignedInt = isIntegral!T && isSigned!T;
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    int a = 42;
    auto b = to!long(a);
    assert(a == b);
}

// Tests for issue 6377
unittest
{
    // Conversion between same size
    foreach (S; TypeTuple!(byte, short, int, long))
    {
        alias Unsigned!S U;

        foreach (Sint; TypeTuple!(S, const(S), immutable(S)))
        foreach (Uint; TypeTuple!(U, const(U), immutable(U)))
        {
            // positive overflow
            Uint un = Uint.max;
            assertThrown!ConvOverflowException(to!Sint(un), text(
                Sint.stringof, ' ', Uint.stringof, ' ', un));

            // negative overflow
            Sint sn = -1;
            assertThrown!ConvOverflowException(to!Uint(sn), text(
                Sint.stringof, ' ', Uint.stringof, ' ', un));
        }
    }

    // Conversion between different size
    foreach (i, S1; TypeTuple!(byte, short, int, long))
    foreach (   S2; TypeTuple!(byte, short, int, long)[i+1..$])
    {
        alias Unsigned!S1 U1;
        alias Unsigned!S2 U2;

        static assert(U1.sizeof < S2.sizeof);

        // small unsigned to big signed
        foreach (Uint; TypeTuple!(U1, const(U1), immutable(U1)))
        foreach (Sint; TypeTuple!(S2, const(S2), immutable(S2)))
        {
            Uint un = Uint.max;
            assertNotThrown(to!Sint(un));
            assert(to!Sint(un) == un);
        }

        // big unsigned to small signed
        foreach (Uint; TypeTuple!(U2, const(U2), immutable(U2)))
        foreach (Sint; TypeTuple!(S1, const(S1), immutable(S1)))
        {
            Uint un = Uint.max;
            assertThrown(to!Sint(un));
        }

        static assert(S1.sizeof < U2.sizeof);

        // small signed to big unsigned
        foreach (Sint; TypeTuple!(S1, const(S1), immutable(S1)))
        foreach (Uint; TypeTuple!(U2, const(U2), immutable(U2)))
        {
            Sint sn = -1;
            assertThrown!ConvOverflowException(to!Uint(sn));
        }

        // big signed to small unsigned
        foreach (Sint; TypeTuple!(S2, const(S2), immutable(S2)))
        foreach (Uint; TypeTuple!(U1, const(U1), immutable(U1)))
        {
            Sint sn = -1;
            assertThrown!ConvOverflowException(to!Uint(sn));
        }
    }
}

/*
  Converting static arrays forwards to their dynamic counterparts.
 */
T toImpl(T, S)(ref S s)
    if (isStaticArray!S)
{
    return toImpl!(T, typeof(s[0])[])(s);
}

unittest
{
    char[4] test = ['a', 'b', 'c', 'd'];
    static assert(!isInputRange!(Unqual!(char[4])));
    assert(to!string(test) == test);
}

/**
$(RED Scheduled for deprecation in January 2012. Please define $(D opCast)
      for user-defined types instead of a $(D to) function.
      $(LREF to) will now use $(D opCast).)

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
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    auto d = new Date;
    auto ts = to!long(d); // same as d.to!long()
}
----
 */
T toImpl(T, S)(S value) if (is(S : Object) && !is(T : Object) && !isSomeString!T
        && is(typeof(S.init.to!T()) : T))
{
    return value.to!T();
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    class B
    {
        T to(T)() { return 43; }
    }
    auto b = new B;
    assert(to!int(b) == 43);
}

/**
When source type supports member template function opCast, is is used.
*/
T toImpl(T, S)(S value)
    if (is(typeof(S.init.opCast!T()) : T) &&
        !isSomeString!T)
{
    return value.opCast!T();
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    class B
    {
        T opCast(T)() { return 43; }
    }
    auto b = new B;
    assert(to!int(b) == 43);

    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    struct S
    {
        T opCast(T)() { return 43; }
    }
    auto s = S();
    assert(to!int(s) == 43);
}

/**
When target type supports 'converting construction', it is used.
$(UL $(LI If target type is struct, $(D T(src)) is used.)
     $(LI If target type is class, $(D new T(src)) is used.))
*/
T toImpl(T, S)(S src)
    if (!isImplicitlyConvertible!(S, T) &&
        is(T == struct) && is(typeof(T(src))))
{
    return T(src);
}

// Bugzilla 3961
unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__,
            " succeeded.");
    struct Int
    {
        int x;
    }
    Int i = to!Int(1);

    static struct Int2
    {
        int x;
        this(int x) { this.x = x; }
    }
    Int2 i2 = to!Int2(1);

    static struct Int3
    {
        int x;
        static Int3 opCall(int x)
        {
            Int3 i;
            i.x = x;
            return i;
        }
    }
    Int3 i3 = to!Int3(1);
}

// Bugzilla 6808
unittest
{
    static struct FakeBigInt
    {
        this(string s){}
    }

    string s = "101";
    auto i3 = to!FakeBigInt(s);
}

/// ditto
T toImpl(T, S)(S src)
    if (!isImplicitlyConvertible!(S, T) &&
        is(T : Object) && is(typeof(new T(src))))
{
    return new T(src);
}

unittest
{
    static struct S
    {
        int x;
    }
    static class C
    {
        int x;
        this(int x) { this.x = x; }
    }

    static class B
    {
        int value;
        this(S src) { value = src.x; }
        this(C src) { value = src.x; }
    }

    S s = S(1);
    auto b1 = to!B(s);  // == new B(s)
    assert(b1.value == 1);

    C c = new C(2);
    auto b2 = to!B(c);  // == new B(c)
    assert(b2.value == 2);

    auto c2 = to!C(3);   // == new C(3)
    assert(c2.x == 3);
}

version (unittest)
{
    class A
    {
        this(B b) {}
    }
    class B : A
    {
        this() { super(this); }
    }
}
unittest
{
    B b = new B();
    A a = to!A(b);      // == cast(A)b
                        // (do not run construction conversion like new A(b))
    assert(b is a);

    static class C : Object
    {
        this() {}
        this(Object o) {}
    }

    Object oc = new C();
    C a2 = to!C(oc);    // == new C(a)
                        // Construction conversion overrides down-casting conversion
    assert(a2 != a);    //
}

/**
Object-to-object conversions by dynamic casting throw exception when the source is
non-null and the target is null.
 */
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        (is(S == class) || is(S == interface)) && !is(typeof(value.opCast!T()) : T) &&
        (is(T == class) || is(T == interface)) && !is(typeof(new T(value))))
{
    static if (is(T == immutable))
    {
            // immutable <- immutable
            enum isModConvertible = is(S == immutable);
    }
    else static if (is(T == const))
    {
        static if (is(T == shared))
        {
            // shared const <- shared
            // shared const <- shared const
            // shared const <- immutable
            enum isModConvertible = is(S == shared) || is(S == immutable);
        }
        else
        {
            // const <- mutable
            // const <- immutable
            enum isModConvertible = !is(S == shared);
        }
    }
    else
    {
        static if (is(T == shared))
        {
            // shared <- shared mutable
            enum isModConvertible = is(S == shared) && !is(S == const);
        }
        else
        {
            // (mutable) <- (mutable)
            enum isModConvertible = is(Unqual!S == S);
        }
    }
    static assert(isModConvertible, "Bad modifier conversion: "~S.stringof~" to "~T.stringof);

    auto result = cast(T) value;
    if (!result && value)
    {
        throw new ConvException("Cannot convert object of static type "
                ~S.classinfo.name~" and dynamic type "~value.classinfo.name
                ~" to type "~T.classinfo.name);
    }
    return result;
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    // Testing object conversions
    class A {}
    class B : A {}
    class C : A {}
    A a1 = new A, a2 = new B, a3 = new C;
    assert(to!B(a2) is a2);
    assert(to!C(a3) is a3);
    assertThrown!ConvException(to!B(a3));
}

// Unittest for 6288
version (unittest)
{
    private template Identity(T)        { alias              T   Identity; }
    private template toConst(T)         { alias        const(T)  toConst; }
    private template toShared(T)        { alias       shared(T)  toShared; }
    private template toSharedConst(T)   { alias shared(const(T)) toSharedConst; }
    private template toImmutable(T)     { alias    immutable(T)  toImmutable; }
    private template AddModifier(int n) if (0 <= n && n < 5)
    {
             static if (n == 0) alias Identity       AddModifier;
        else static if (n == 1) alias toConst        AddModifier;
        else static if (n == 2) alias toShared       AddModifier;
        else static if (n == 3) alias toSharedConst  AddModifier;
        else static if (n == 4) alias toImmutable    AddModifier;
    }
}
unittest
{
    interface I {}
    interface J {}

    class A {}
    class B : A {}
    class C : B, I, J {}
    class D : I {}

    foreach (m1; TypeTuple!(0,1,2,3,4)) // enumerate modifiers
    foreach (m2; TypeTuple!(0,1,2,3,4)) // ditto
    {
        alias AddModifier!m1 srcmod;
        alias AddModifier!m2 tgtmod;
        //pragma(msg, srcmod!Object, " -> ", tgtmod!Object, ", convertible = ",
        //            isImplicitlyConvertible!(srcmod!Object, tgtmod!Object));

        // Compile time convertible equals to modifier convertible.
        static if (isImplicitlyConvertible!(srcmod!Object, tgtmod!Object))
        {
            // Test runtime conversions: class to class, class to interface,
            // interface to class, and interface to interface

            // Check that the runtime conversion to succeed
            srcmod!A ac = new srcmod!C();
            srcmod!I ic = new srcmod!C();
            assert(to!(tgtmod!C)(ac) !is null); // A(c) to C
            assert(to!(tgtmod!I)(ac) !is null); // A(c) to I
            assert(to!(tgtmod!C)(ic) !is null); // I(c) to C
            assert(to!(tgtmod!J)(ic) !is null); // I(c) to J

            // Check that the runtime conversion fails
            srcmod!A ab = new srcmod!B();
            srcmod!I id = new srcmod!D();
            assertThrown(to!(tgtmod!C)(ab));    // A(b) to C
            assertThrown(to!(tgtmod!I)(ab));    // A(b) to I
            assertThrown(to!(tgtmod!C)(id));    // I(d) to C
            assertThrown(to!(tgtmod!J)(id));    // I(d) to J
        }
        else
        {
            // Check that the conversion is rejected statically
            static assert(!is(typeof(to!(tgtmod!C)(srcmod!A.init))));   // A to C
            static assert(!is(typeof(to!(tgtmod!I)(srcmod!A.init))));   // A to I
            static assert(!is(typeof(to!(tgtmod!C)(srcmod!I.init))));   // I to C
            static assert(!is(typeof(to!(tgtmod!J)(srcmod!I.init))));   // I to J
        }
    }
}

/**
Stringnize conversion from all types is supported.
$(UL
  $(LI String _to string conversion works for any two string types having
       ($(D char), $(D wchar), $(D dchar)) character widths and any
       combination of qualifiers (mutable, $(D const), or $(D immutable)).)
  $(LI Converts array (other than strings) to string. The left bracket,
       separator, and right bracket are configurable. Each element is
       converted by calling $(D to!T).)
  $(LI Associative array to string conversion. The left bracket, key-value
       separator, element separator, and right bracket are configurable.
       Each element is printed by calling $(D to!T).)
  $(LI Object to string conversion calls $(D toString) against the object or
       returns $(D nullstr) if the object is null.)
  $(LI Struct to string conversion calls $(D toString) against the struct if
       it is defined.)
  $(LI For structs that do not define $(D toString), the conversion to string
       produces the list of fields.)
  $(LI Enumerated types are converted to strings as their symbolic names.)
  $(LI A $(D typedef Type Symbol) is converted to string as $(D "Type(value)").)
  $(LI Boolean values are printed as $(D "true") or $(D "false").)
  $(LI $(D char), $(D wchar), $(D dchar) to a string type.)
  $(LI Unsigned or signed integers to strings.
       $(DL $(DT [special case])
            $(DD Convert inttegral value to string in $(D_PARAM radix) radix.
            radix must be a value from 2 to 36.
            value is treated as a signed value only if radix is 10.
            The characters A through Z are used to represent values 10 through 36.)))
  $(LI All floating point types to all string types.)
  $(LI Pointer to string conversions prints the pointer as a $(D size_t) value.
       If pointer is $(D char*), treat it as C-style strings.))
*/
T toImpl(T, S)(S s)
    if (!isImplicitlyConvertible!(S, T) &&
        isInputRange!(Unqual!S) && isSomeChar!(ElementType!S) &&
        isSomeString!T)
{
    static if (isSomeString!S)
    {
        // string-to-string conversion
        static if (s[0].sizeof == T[0].sizeof)
        {
            // same width, only qualifier conversion
            enum tIsConst = is(T == const(char)[]) || is(T == const(wchar)[])
                || is(T == const(dchar)[]);
            enum tIsInvariant = is(T == immutable(char)[])
                || is(T == immutable(wchar)[]) || is(T == immutable(dchar)[]);
            static if (tIsConst)
            {
                return s;
            }
            else static if (tIsInvariant)
            {
                // conversion (mutable|const) -> immutable
                return s.idup;
            }
            else
            {
                // conversion (immutable|const) -> mutable
                return s.dup;
            }
        }
        else
        {
            // width conversion
            // we can cast because toUTFX always produces a fresh string
            static if (T[0].sizeof == 1)
            {
                return cast(T) toUTF8(s);
            }
            else static if (T[0].sizeof == 2)
            {
                return cast(T) toUTF16(s);
            }
            else
            {
                static assert(T[0].sizeof == 4);
                return cast(T) toUTF32(s);
            }
        }
    }
    else
    {
        Appender!T result;
        result.put(s);
        return result.data;
    }
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
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
                    Lhs s1 = to!Lhs("wyda");
                    Rhs s2 = to!Rhs(s1);
                    //writeln(Lhs.stringof, " -> ", Rhs.stringof);
                    assert(s1 == to!Lhs(s2));
                }
            }
        }
    }
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    // string tests
    alias TypeTuple!(char, wchar, dchar) AllChars;
    foreach (T; AllChars)
    {
        foreach (U; AllChars)
        {
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

/// ditto
T toImpl(T, S)(S s, in T leftBracket = "[", in T separator = ", ", in T rightBracket = "]")
    if (!isSomeChar!(ElementType!S) && (isInputRange!S || isInputRange!(Unqual!S)) &&
        isSomeString!T)
{
    static if (!isInputRange!S)
    {
        alias toImpl!(T, Unqual!S) ti;
        return ti(s, leftBracket, separator, rightBracket);
    }
    else
    {
        alias Unqual!(typeof(T.init[0])) Char;
        // array-to-string conversion
        auto result = appender!(Char[])();
        result.put(leftBracket);
        bool first = true;
        for (; !s.empty; s.popFront())
        {
            if (!first)
            {
                result.put(separator);
            }
            else
            {
                first = false;
            }
            result.put(to!T(s.front));
        }
        result.put(rightBracket);
        return cast(T) result.data;
    }
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    long[] b = [ 1, 3, 5 ];
    auto s = to!string(b);
//printf("%d, |%*s|\n", s.length, s.length, s.ptr);
    assert(to!string(b) == "[1, 3, 5]", s);
    double[2] a = [ 1.5, 2.5 ];
//writeln(to!string(a));
    assert(to!string(a) == "[1.5, 2.5]");
}

// Converting arrays of void
T toImpl(T, S)(ref S s, in T leftBracket = "[", in T separator = " ", in T rightBracket = "]")
    if ((is(S == void[]) || is(S == const(void)[]) || is(S == immutable(void)[])) &&
        isSomeString!T)
{
    alias Unqual!(typeof(T.init[0])) Char;
    auto raw = cast(const(ubyte)[]) s;
    enforce(raw.length % Char.sizeof == 0,
            new ConvException("Alignment mismatch in converting a "
                    ~ S.stringof ~ " to a "
                    ~ T.stringof));
    auto result = new Char[raw.length / Char.sizeof];
    memcpy(result.ptr, s.ptr, s.length);
    return cast(T) result;
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    auto a = "abcx"w;
    const(void)[] b = a;
    assert(b.length == 8);
    auto c = to!(wchar[])(b);
    assert(c == "abcx");
}

/// ditto
T toImpl(T, S)(S s, in T leftBracket = "[", in T keyval = ":", in T separator = ", ", in T rightBracket = "]")
    if (isAssociativeArray!S &&
        isSomeString!T)
{
    alias Unqual!(typeof(T.init[0])) Char;
    auto result = appender!(Char[])();
// hash-to-string conversion
    result.put(leftBracket);
    bool first = true;
    foreach (k, v; s)
    {
        if (!first)
            result.put(separator);
        else first = false;
        result.put(to!T(k));
        result.put(keyval);
        result.put(to!T(v));
    }
    result.put(rightBracket);
    return cast(T) result.data;
}

/// ditto
T toImpl(T, S)(S s, in T nullstr = "null")
    if (is(S : Object) &&
        isSomeString!T)
{
    if (!s)
        return nullstr;
    return to!T(s.toString);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    class A
    {
        override string toString() { return "an A"; }
    }
    A a;
    assert(to!string(a) == "null");
    a = new A;
    assert(to!string(a) == "an A");
}

/// ditto
T toImpl(T, S)(S s)
    if (is(S == struct) && is(typeof(&S.init.toString)) &&
        isSomeString!T)
{
    return to!T(s.toString);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    struct S
    {
        string toString() { return "wyda"; }
    }
    assert(to!string(S()) == "wyda");
}

/// ditto
T toImpl(T, S)(S s, in T left = S.stringof~"(", in T separator = ", ", in T right = ")")
    if (is(S == struct) && !is(typeof(&S.init.toString)) && !isInputRange!S &&
        isSomeString!T)
{
    Tuple!(FieldTypeTuple!S) * t = void;
    static if ((*t).sizeof == S.sizeof)
    {
        // ok, attempt to forge the tuple
        t = cast(typeof(t)) &s;
        alias Unqual!(typeof(T.init[0])) Char;
        auto app = appender!(Char[])();
        app.put(left);
        foreach (i, e; t.field)
        {
            if (i > 0)
                app.put(to!T(separator));
            app.put(to!T(e));
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
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    struct S
    {
        int a = 42;
        float b = 43.5;
    }
    S s;
    assert(to!string(s) == "S(42, 43.5)");
}

/// ditto
T toImpl(T, S)(S s)
    if (!isImplicitlyConvertible!(S, T) &&
        is(S == enum) &&
        isSomeString!T)
{
    foreach (i, e; EnumMembers!S)
    {
        if (s == e)
            return __traits(allMembers, S)[i];
    }

    // val is not a member of T, output cast(T)rawValue instead.
    static assert(!is(OriginalType!S == S));
    return to!T("cast(" ~ S.stringof ~ ")") ~ to!T(cast(OriginalType!S)s);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    enum E { a, b, c }
    assert(to! string(E.a) == "a"c);
    assert(to!wstring(E.b) == "b"w);
    assert(to!dstring(E.c) == "c"d);

    enum F : real { x = 1.414, y = 1.732, z = 2.236 }
    assert(to! string(F.x) == "x"c);
    assert(to!wstring(F.y) == "y"w);
    assert(to!dstring(F.z) == "z"d);

    // Test an value not corresponding to an enum member.
    auto o = cast(E)5;
    assert(to! string(o) == "cast(E)5"c);
    assert(to!wstring(o) == "cast(E)5"w);
    assert(to!dstring(o) == "cast(E)5"d);
}

/// ditto
T toImpl(T, S)(S s, in T left = S.stringof~"(", in T right = ")")
    if (is(S == typedef) &&
        isSomeString!T)
{
    static if (is(S Original == typedef))
    {
        // typedef
        return left ~ to!T(cast(Original) s) ~ right;
    }
}

version(none) unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    typedef double Km;
    Km km = 42;
    assert(to!string(km) == "Km(42)");
}

/// ditto
T toImpl(T, S)(S b)
    if (is(Unqual!S == bool) &&
        isSomeString!T)
{
    return to!T(b ? "true" : "false");
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    bool b;
    assert(to!string(b) == "false");
    b = true;
    assert(to!string(b) == "true");
}

/// ditto
T toImpl(T, S)(S c)
    if (isSomeChar!(Unqual!S) &&
        isSomeString!T)
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

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    alias TypeTuple!(
        char, wchar, dchar,
        const(char), const(wchar), const(dchar),
        immutable(char), immutable(wchar), immutable(dchar)) AllChars;
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

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    debug(conv) printf("string.to!string(char).unittest\n");

    string s = "foo";
    string s2;
    foreach (char c; s)
    {
        s2 ~= to!string(c);
    }
    //printf("%.*s", s2);
    assert(s2 == "foo");
}

/// ditto
T toImpl(T, S)(S input)
    if (isIntegral!S && isUnsigned!S &&
        isSomeString!T)
{
    static if (S.sizeof < uint.sizeof)
    {
        // Small unsigned integers to strings.
        return to!T(cast(uint) input);
    }
    else
    {
        // Unsigned integers (uint and ulong) to string.
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
        {
            result = new Char[maxlength];
        }
        else
        {
            result = uninitializedArray!(Char[])(maxlength);
        }

        uint ndigits = 0;
        do
        {
            auto div = value / 10;
            auto rem = value % 10;
            const c = cast(Char) (rem + '0');
            value = div;
            ++ndigits;
            result[$ - ndigits] = c;
        }
        while (value);
        return cast(T) result[$ - ndigits .. $];
    }
}

unittest
{
    foreach (Int; TypeTuple!(ubyte, ushort, uint, ulong))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("string.to!string(%.*s).unittest\n", Int.stringof.length, Int.stringof.ptr);

        assert(to!string(to!Int(0)) == "0");
        assert(to!string(to!Int(9)) == "9");
        assert(to!string(to!Int(123)) == "123");
    }
}

/// ditto
T toImpl(T, S)(S value)
    if (isIntegral!S && isSigned!S &&
        isSomeString!T)
{
    static if (S.sizeof < int.sizeof)
    {
        // Small signed integers to strings.
        return to!T(cast(int) value);
    }
    else
    {
        // Signed values ($(D int) and $(D long)).
        if (value >= 0)
            return to!T(cast(Unsigned!S) value);
        alias Unqual!(typeof(T.init[0])) Char;

        // Cache read-only data only for const and immutable; mutable
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
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    assert(wtext(int.max) == "2147483647"w);
    assert(wtext(int.min) == "-2147483648"w);
    assert(to!string(0L) == "0");
}

unittest
{
    foreach (Int; TypeTuple!(byte, short, int, long))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("string.to!string(%.*s).unittest\n", Int.stringof.length, Int.stringof.ptr);

        assert(to!string(to!Int(0)) == "0");
        assert(to!string(to!Int(9)) == "9");
        assert(to!string(to!Int(123)) == "123");
        assert(to!string(to!Int(-0)) == "0");
        assert(to!string(to!Int(-9)) == "-9");
        assert(to!string(to!Int(-123)) == "-123");
        assert(to!string(to!(const Int)(6)) == "6");
    }
}

/// ditto
T toImpl(T, S)(S value, uint radix)
    if (isIntegral!(Unqual!S) &&
        isSomeString!T)
in
{
    assert(radix >= 2 && radix <= 36);
}
body
{
    static if (!is(Unqual!S == ulong))
    {
        enforce(radix >= 2 && radix <= 36, new ConvException("Radix error"));
        if (radix == 10)
            return to!string(value);     // handle signed cases only for radix 10
        return to!string(cast(ulong) value, radix);
    }
    else
    {
        char[value.sizeof * 8] buffer;
        uint i = buffer.length;

        if (value < radix && value < hexDigits.length)
            return hexDigits[cast(size_t)value .. cast(size_t)value + 1];

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
}

unittest
{
    foreach (Int; TypeTuple!(uint, ulong))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("string.to!string(%.*s, uint).unittest\n", Int.stringof.length, Int.stringof.ptr);

        assert(to!string(to!Int(16), 16) == "10");
        assert(to!string(to!Int(15), 2u) == "1111");
        assert(to!string(to!Int(1), 2u) == "1");
        assert(to!string(to!Int(0x1234AF), 16u) == "1234AF");
    }

    foreach (Int; TypeTuple!(int, long))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("string.to!string(%.*s, uint).unittest\n", Int.stringof.length, Int.stringof.ptr);

        assert(to!string(to!Int(-10), 10u) == "-10");
    }
}

/// ditto
T toImpl(T, S)(S value)
    if ((isFloatingPoint!S || isImaginary!S || isComplex!S) &&
        isSomeString!T)
{
    import core.stdc.stdio;// : sprintf;

    /// $(D float) to all string types.
    static if (is(Unqual!S == float))
    {
        return to!T(cast(double) value);
    }

    /// $(D double) to all string types.
    static if (is(Unqual!S == double))
    {
        //alias Unqual!(ElementType!T) Char;
        char[20] buffer;
        int len = sprintf(buffer.ptr, "%g", value);
        return to!T(buffer[0 .. len].dup);
    }

    /// $(D real) to all string types.
    static if (is(Unqual!S == real))
    {
        char[20] buffer;
        int len = sprintf(buffer.ptr, "%Lg", value);
        return to!T(buffer[0 .. len].dup);
    }

    /// $(D ifloat) to all string types.
    static if (is(Unqual!S == ifloat))
    {
        return to!T(cast(idouble) value);
    }

    /// $(D idouble) to all string types.
    static if (is(Unqual!S == idouble))
    {
        char[21] buffer;
        int len = sprintf(buffer.ptr, "%gi", value);
        return to!T(buffer[0 .. len].dup);
    }

    /// $(D ireal) to all string types.
    static if (is(Unqual!S == ireal))
    {
        char[21] buffer;
        int len = sprintf(buffer.ptr, "%Lgi", value);
        //assert(len < buffer.length); // written bytes is len + 1
        return to!T(buffer[0 .. len].dup);
    }

    /// $(D cfloat) to all string types.
    static if (is(Unqual!S == cfloat))
    {
        return to!string(cast(cdouble) value);
    }

    /// $(D cdouble) to all string types.
    static if (is(Unqual!S == cdouble))
    {
        char[20 + 1 + 20 + 1] buffer;

        int len = sprintf(buffer.ptr, "%g+%gi", value.re, value.im);
        return to!T(buffer[0 .. len]);
    }

    /// $(D creal) to all string types.
    static if (is(Unqual!S == creal))
    {
        char[20 + 1 + 20 + 1] buffer;
        int len = sprintf(buffer.ptr, "%Lg+%Lgi", value.re, value.im);
        return to!T(buffer[0 .. len].dup);
    }
}

/// ditto
T toImpl(T, S)(S value)
    if (isPointer!S && (!is(typeof(*S.init)) || !isSomeChar!(typeof(*S.init))) &&
        isSomeString!T)
{
    return to!T(cast(size_t) value, 16u);
}

/// ditto
T toImpl(T, S)(S s)
    if (isPointer!S && is(S : const(char)*) &&
        isSomeString!T)
{
    return s ? cast(T) s[0 .. strlen(s)].dup : cast(string)null;
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    debug(conv) printf("string.to!string(char*).unittest\n");

    assert(to!string(cast(char*) null) == "");
    assert(to!string("foo\0".ptr) == "foo");
}


/**
Narrowing numeric-numeric conversions throw when the value does not
fit in the narrower type.
 */
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        (isNumeric!S || isSomeChar!S) &&
        (isNumeric!T || isSomeChar!T))
{
    enum sSmallest = mostNegative!S;
    enum tSmallest = mostNegative!T;
    static if (sSmallest < 0)
    {
        // possible underflow converting from a signed
        static if (tSmallest == 0)
        {
            immutable good = value >= 0;
        }
        else
        {
            static assert(tSmallest < 0);
            immutable good = value >= tSmallest;
        }
        if (!good)
            throw new ConvOverflowException("Conversion negative overflow");
    }
    static if (S.max > T.max)
    {
        // possible overflow
        if (value > T.max)
            throw new ConvOverflowException("Conversion positive overflow");
    }
    return cast(T) value;
}

unittest
{
    dchar a = ' ';
    assert(to!char(a) == ' ');
    a = 300;
    assert(collectException(to!char(a)));

    dchar from0 = 'A';
    char to0 = to!char(from0);

    wchar from1 = 'A';
    char to1 = to!char(from1);

    char from2 = 'A';
    char to2 = to!char(from2);

    char from3 = 'A';
    wchar to3 = to!wchar(from3);

    char from4 = 'A';
    dchar to4 = to!dchar(from4);
}

/**
Array-to-array conversion (except when target is a string type)
converts each element in turn by using $(D to).
 */
T toImpl(T, S)(S src)
    if (!isImplicitlyConvertible!(S, T) &&
        !isSomeString!S && isDynamicArray!S &&
        !isSomeString!T && isArray!T)
{
    alias typeof(T.init[0]) E;
    auto result = new E[src.length];
    foreach (i, e; src)
    {
        /* Temporarily cast to mutable type, so we can get it initialized,
         * this is ok because there are no other references to result[]
         */
        cast()(result[i]) = to!E(e);
    }
    return result;
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
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
T toImpl(T, S)(S src)
    if (isAssociativeArray!S &&
        isAssociativeArray!T)
{
    alias typeof(T.keys[0]) K2;
    alias typeof(T.values[0]) V2;
    T result;
    foreach (k1, v1; src)
    {
        result[to!K2(k1)] = to!V2(v1);
    }
    return result;
}

unittest
{
    //hash to hash conversions
    int[string] a;
    a["0"] = 1;
    a["1"] = 2;
    auto b = to!(double[dstring])(a);
    assert(b["0"d] == 1 && b["1"d] == 2);
    //hash to string conversion
    assert(to!string(a) == "[0:1, 1:2]");
}

private void testIntegralToFloating(Integral, Floating)()
{
    Integral a = 42;
    auto b = to!Floating(a);
    assert(a == b);
    assert(a == to!Integral(b));
}

private void testFloatingToIntegral(Floating, Integral)()
{
    bool convFails(Source, Target, E)(Source src)
    {
        try
            auto t = to!Target(src);
        catch (E)
            return true;
        return false;
    }

    // convert some value
    Floating a = 4.2e1;
    auto b = to!Integral(a);
    assert(is(typeof(b) == Integral) && b == 42);
    // convert some negative value (if applicable)
    a = -4.2e1;
    static if (Integral.min < 0)
    {
        b = to!Integral(a);
        assert(is(typeof(b) == Integral) && b == -42);
    }
    else
    {
        // no go for unsigned types
        assert(convFails!(Floating, Integral, ConvOverflowException)(a));
    }
    // convert to the smallest integral value
    a = 0.0 + Integral.min;
    static if (Integral.min < 0)
    {
        a = -a; // -Integral.min not representable as an Integral
        assert(convFails!(Floating, Integral, ConvOverflowException)(a)
                || Floating.sizeof <= Integral.sizeof);
    }
    a = 0.0 + Integral.min;
    assert(to!Integral(a) == Integral.min);
    --a; // no more representable as an Integral
    assert(convFails!(Floating, Integral, ConvOverflowException)(a)
            || Floating.sizeof <= Integral.sizeof);
    a = 0.0 + Integral.max;
//   fwritefln(stderr, "%s a=%g, %s conv=%s", Floating.stringof, a,
//             Integral.stringof, to!Integral(a));
    assert(to!Integral(a) == Integral.max || Floating.sizeof <= Integral.sizeof);
    ++a; // no more representable as an Integral
    assert(convFails!(Floating, Integral, ConvOverflowException)(a)
            || Floating.sizeof <= Integral.sizeof);
    // convert a value with a fractional part
    a = 3.14;
    assert(to!Integral(a) == 3);
    a = 3.99;
    assert(to!Integral(a) == 3);
    static if (Integral.min < 0)
    {
        a = -3.14;
        assert(to!Integral(a) == -3);
        a = -3.99;
        assert(to!Integral(a) == -3);
    }
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");

    alias TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong)
    AllInts;
    alias TypeTuple!(float, double, real) AllFloats;
    alias TypeTuple!(AllInts, AllFloats) AllNumerics;
    // test with same type
    {
        foreach (T; AllNumerics)
        {
            T a = 42;
            auto b = to!T(a);
            assert(is(typeof(a) == typeof(b)) && a == b);
        }
    }
    // test that floating-point numbers convert properly to largest ints
    // see http://oregonstate.edu/~peterseb/mth351/docs/351s2001_fp80x87.html
    // look for "largest fp integer with a predecessor"
    {
        // float
        int a = 16_777_215; // 2^24 - 1
        assert(to!int(to!float(a)) == a);
        assert(to!int(to!float(-a)) == -a);
        // double
        long b = 9_007_199_254_740_991; // 2^53 - 1
        assert(to!long(to!double(b)) == b);
        assert(to!long(to!double(-b)) == -b);
        // real
        // @@@ BUG IN COMPILER @@@
//     ulong c = 18_446_744_073_709_551_615UL; // 2^64 - 1
//     assert(to!ulong(to!real(c)) == c);
//     assert(to!ulong(-to!real(c)) == c);
    }
    // test conversions floating => integral
    {
        // AllInts[0 .. $ - 1] should be AllInts
        // @@@ BUG IN COMPILER @@@
        foreach (Integral; AllInts[0 .. $ - 1])
        {
            foreach (Floating; AllFloats)
            {
                testFloatingToIntegral!(Floating, Integral);
            }
        }
    }
    // test conversion integral => floating
    {
        foreach (Integral; AllInts[0 .. $ - 1])
        {
            foreach (Floating; AllFloats)
            {
                testIntegralToFloating!(Integral, Floating);
            }
        }
    }
    // test parsing
    {
        foreach (T; AllNumerics)
        {
            // from type immutable(char)[2]
            auto a = to!T("42");
            assert(a == 42);
            // from type char[]
            char[] s1 = "42".dup;
            a = to!T(s1);
            assert(a == 42);
            // from type char[2]
            char[2] s2;
            s2[] = "42";
            a = to!T(s2);
            assert(a == 42);
            // from type immutable(wchar)[2]
            a = to!T("42"w);
            assert(a == 42);
        }
    }
    // test conversions to string
    {
        foreach (T; AllNumerics)
        {
            T a = 42;
            assert(to!string(a) == "42");
            //assert(to!wstring(a) == "42"w);
            //assert(to!dstring(a) == "42"d);
            // array test
//       T[] b = new T[2];
//       b[0] = 42;
//       b[1] = 33;
//       assert(to!string(b) == "[42,33]");
        }
    }
    // test array to string conversion
    foreach (T ; AllNumerics)
    {
        auto a = [to!T(1), 2, 3];
        assert(to!string(a) == "[1, 2, 3]");
    }
    // test enum to int conversion
    // enum Testing { Test1, Test2 };
    // Testing t;
    // auto a = to!string(t);
    // assert(a == "0");
}


/**
String to non-string conversion runs parsing.
$(UL
  $(LI When the source is a wide string, it is first converted to a narrow
       string and then parsed.)
  $(LI When the source is a narrow string, normal text parsing occurs.))
*/
T toImpl(T, S)(S value)
    if (isDynamicArray!S && isSomeString!S &&
        !isSomeString!T && is(typeof({ ElementEncodingType!S[] v = value; parse!T(v); })))
{
    alias ElementEncodingType!S[] SV;
    static if (is(SV == S))
        alias value v;
    else
        SV v = value;   // e.g. convert const(char[]) to const(char)[]

    scope(exit)
    {
        if (v.length)
        {
            convError!(SV, T)(v);
        }
    }
    return parse!T(v);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    foreach (Char; TypeTuple!(char, wchar, dchar))
    {
        auto a = to!(Char[])("123");
        assert(to!int(a) == 123);
        assert(to!double(a) == 123);
    }
}

/***************************************************************
 Rounded conversion from floating point to integral.

Example:
---------------
assert(roundTo!int(3.14) == 3);
assert(roundTo!int(3.49) == 3);
assert(roundTo!int(3.5) == 4);
assert(roundTo!int(3.999) == 4);
assert(roundTo!int(-3.14) == -3);
assert(roundTo!int(-3.49) == -3);
assert(roundTo!int(-3.5) == -4);
assert(roundTo!int(-3.999) == -4);
---------------
Rounded conversions do not work with non-integral target types.
 */

template roundTo(Target)
{
    Target roundTo(Source)(Source value)
    {
        static assert(isFloatingPoint!Source);
        static assert(isIntegral!Target);
        return to!Target(trunc(value + (value < 0 ? -0.5L : 0.5L)));
    }
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    assert(roundTo!int(3.14) == 3);
    assert(roundTo!int(3.49) == 3);
    assert(roundTo!int(3.5) == 4);
    assert(roundTo!int(3.999) == 4);
    assert(roundTo!int(-3.14) == -3);
    assert(roundTo!int(-3.49) == -3);
    assert(roundTo!int(-3.5) == -4);
    assert(roundTo!int(-3.999) == -4);
    assert(roundTo!(const int)(to!(const double)(-3.999)) == -4);

    // boundary values
    foreach (Int; TypeTuple!(byte, ubyte, short, ushort, int, uint))
    {
        assert(roundTo!Int(Int.min - 0.4L) == Int.min);
        assert(roundTo!Int(Int.max + 0.4L) == Int.max);
        assertThrown!ConvOverflowException(roundTo!Int(Int.min - 0.5L));
        assertThrown!ConvOverflowException(roundTo!Int(Int.max + 0.5L));
    }
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
auto a = parse!uint(test);
assert(a == 123);
assert(test == " \t  76.14"); // parse bumps string
munch(test, " \t\n\r"); // skip ws
assert(test == "76.14");
auto b = parse!double(test);
assert(b == 76.14);
assert(test == "");
--------------
 */

Target parse(Target, Source)(ref Source s)
    if (isSomeChar!(ElementType!Source) &&
        isIntegral!Target)
{
    static if (Target.sizeof < int.sizeof)
    {
        // smaller types are handled like integers
        auto v = .parse!(Select!(Target.min < 0, int, uint))(s);
        auto result = cast(Target) v;
        if (result != v)
            goto Loverflow;
        return result;
    }
    else
    {
        // Larger than int types
        // immutable length = s.length;
        // if (!length)
        //     goto Lerr;
        if (s.empty)
            goto Lerr;

        static if (Target.min < 0)
            int sign = 0;
        else
            static const int sign = 0;
        Target v = 0;
        size_t i = 0;
        enum char maxLastDigit = Target.min < 0 ? '7' : '5';
        //for (; i < length; i++)
        for (; !s.empty; ++i)
        {
            //immutable c = s[i];
            immutable c = s.front;
            if (c >= '0' && c <= '9')
            {
                if (v >= Target.max/10 &&
                        (v != Target.max/10|| c + sign > maxLastDigit))
                    goto Loverflow;
                v = cast(Target) (v * 10 + (c - '0'));
                s.popFront();
            }
            else static if (Target.min < 0)
            {
                if (c == '-' && i == 0)
                {
                    s.popFront();
                    if (s.empty)
                        goto Lerr;
                    sign = -1;
                }
                else if (c == '+' && i == 0)
                {
                    s.popFront();
                    if (s.empty)
                        goto Lerr;
                }
                else
                    break;
            }
            else
                break;
        }
        if (i == 0)
            goto Lerr;
        //s = s[i .. $];
        static if (Target.min < 0)
        {
            if (sign == -1)
            {
                v = -v;
            }
        }
        return v;
    }

Loverflow:
    throw new ConvOverflowException("Overflow in integral conversion");
Lerr:
    convError!(Source, Target)(s);
    assert(0);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    string s = "123";
    auto a = parse!int(s);
}

unittest
{
    foreach (Int; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("conv.to!%.*s.unittest\n", Int.stringof.length, Int.stringof.ptr);

        {
                assert(to!Int("0") == 0);

            static if (isSigned!Int)
            {
                assert(to!Int("+0") == 0);
                assert(to!Int("-0") == 0);
            }
        }

        static if (Int.sizeof >= byte.sizeof)
        {
                assert(to!Int("6") == 6);
                assert(to!Int("23") == 23);
                assert(to!Int("68") == 68);
                assert(to!Int("127") == 0x7F);

            static if (isUnsigned!Int)
            {
                assert(to!Int("255") == 0xFF);
            }
            static if (isSigned!Int)
            {
                assert(to!Int("+6") == 6);
                assert(to!Int("+23") == 23);
                assert(to!Int("+68") == 68);
                assert(to!Int("+127") == 0x7F);

                assert(to!Int("-6") == -6);
                assert(to!Int("-23") == -23);
                assert(to!Int("-68") == -68);
                assert(to!Int("-128") == -128);
            }
        }

        static if (Int.sizeof >= short.sizeof)
        {
                assert(to!Int("468") == 468);
                assert(to!Int("32767") == 0x7FFF);

            static if (isUnsigned!Int)
            {
                assert(to!Int("65535") == 0xFFFF);
            }
            static if (isSigned!Int)
            {
                assert(to!Int("+468") == 468);
                assert(to!Int("+32767") == 0x7FFF);

                assert(to!Int("-468") == -468);
                assert(to!Int("-32768") == -32768);
            }
        }

        static if (Int.sizeof >= int.sizeof)
        {
                assert(to!Int("2147483647") == 0x7FFFFFFF);

            static if (isUnsigned!Int)
            {
                assert(to!Int("4294967295") == 0xFFFFFFFF);
            }

            static if (isSigned!Int)
            {
                assert(to!Int("+2147483647") == 0x7FFFFFFF);

                assert(to!Int("-2147483648") == -2147483648);
            }
        }

        static if (Int.sizeof >= long.sizeof)
        {
                assert(to!Int("9223372036854775807") == 0x7FFFFFFFFFFFFFFF);

            static if (isUnsigned!Int)
            {
                assert(to!Int("18446744073709551615") == 0xFFFFFFFFFFFFFFFF);
            }

            static if (isSigned!Int)
            {
                assert(to!Int("+9223372036854775807") == 0x7FFFFFFFFFFFFFFF);

                assert(to!Int("-9223372036854775808") == 0x8000000000000000);
            }
        }
    }
}

unittest
{
    // parsing error check
    foreach (Int; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("conv.to!%.*s.unittest (error)\n", Int.stringof.length, Int.stringof.ptr);

        {
            immutable string[] errors1 =
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
            ];
            foreach (j, s; errors1)
                assertThrown!ConvException(to!Int(s));
        }

        // parse!SomeUnsigned cannot parse head sign.
        static if (isUnsigned!Int)
        {
            immutable string[] errors2 =
            [
                "+5",
                "-78",
            ];
            foreach (j, s; errors2)
                assertThrown!ConvException(to!Int(s));
        }
    }

    // positive overflow check
    foreach (i, Int; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("conv.to!%.*s.unittest (pos overflow)\n", Int.stringof.length, Int.stringof.ptr);

        immutable string[] errors =
        [
            "128",                  // > byte.max
            "256",                  // > ubyte.max
            "32768",                // > short.max
            "65536",                // > ushort.max
            "2147483648",           // > int.max
            "4294967296",           // > uint.max
            "9223372036854775808",  // > long.max
            "18446744073709551616", // > ulong.max
        ];
        foreach (j, s; errors[i..$])
            assertThrown!ConvOverflowException(to!Int(s));
    }

    // negative overflow check
    foreach (i, Int; TypeTuple!(byte, short, int, long))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("conv.to!%.*s.unittest (neg overflow)\n", Int.stringof.length, Int.stringof.ptr);

        immutable string[] errors =
        [
            "-129",                 // < byte.min
            "-32769",               // < short.min
            "-2147483649",          // < int.min
            "-9223372036854775809", // < long.min
        ];
        foreach (j, s; errors[i..$])
            assertThrown!ConvOverflowException(to!Int(s));
    }
}

/// ditto
Target parse(Target, Source)(ref Source s, uint radix)
    if (isSomeString!Source &&
        isIntegral!Target)
in
{
    assert(radix >= 2 && radix <= 36);
}
body
{
    if (radix == 10)
        return parse!Target(s);

    immutable length = s.length;
    immutable uint beyond = (radix < 10 ? '0' : 'a'-10) + radix;

    Target v = 0;
    size_t i = 0;
    for (; i < length; ++i)
    {
        uint c = s[i];
        if (c < '0')
            break;
        if (radix < 10)
        {
            if (c >= beyond)
                break;
        }
        else
        {
            if (c > '9')
            {
                c |= 0x20;//poorman's tolower
                if (c < 'a' || c >= beyond)
                    break;
                c -= 'a'-10-'0';
            }
        }
        auto blah = cast(Target) (v * radix + c - '0');
        if (blah < v)
            goto Loverflow;
        v = blah;
    }
    if (!i)
        goto Lerr;
    assert(i <= s.length);
    s = s[i .. $];
    return v;

Loverflow:
    throw new ConvOverflowException("Overflow in integral conversion");
Lerr:
    convError!(Source, Target)(s, radix);
    assert(0);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    // @@@BUG@@@ the size of China
        // foreach (i; 2..37)
        // {
        //      assert(parse!int("0",i) == 0);
        //      assert(parse!int("1",i) == 1);
        //      assert(parse!byte("10",i) == i);
        // }
        foreach (i; 2..37)
        {
            string s = "0";
                assert(parse!int(s,i) == 0);
            s = "1";
                assert(parse!int(s,i) == 1);
            s = "10";
                assert(parse!byte(s,i) == i);
        }
    // Same @@@BUG@@@ as above
        //assert(parse!int("0011001101101", 2) == 0b0011001101101);
        // assert(parse!int("765",8) == 0765);
        // assert(parse!int("fCDe",16) == 0xfcde);
    auto s = "0011001101101";
        assert(parse!int(s, 2) == 0b0011001101101);
    s = "765";
        assert(parse!int(s, 8) == octal!765);
    s = "fCDe";
        assert(parse!int(s, 16) == 0xfcde);

    // 6609
    s = "-42";
    assert(parse!int(s, 10) == -42);
}

Target parse(Target, Source)(ref Source s)
    if (isSomeString!Source &&
        is(Target == enum))
{
    // TODO: BUG4744
    foreach (i, e; EnumMembers!Target)
    {
        auto ident = __traits(allMembers, Target)[i];
        if (s.skipOver(ident))
            return e;
    }
    throw new ConvException(
        Target.stringof ~ " does not have a member named '"
        ~ to!string(s) ~ "'");
}

//@@@BUG4737@@@: typeid doesn't work for scoped enum with initializer
version(unittest)
{
    private enum F : real { x = 1.414, y = 1.732, z = 2.236 }
}
unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    enum E { a, b, c }
    assert(to!E("a"c) == E.a);
    assert(to!E("b"w) == E.b);
    assert(to!E("c"d) == E.c);

    assert(to!F("x"c) == F.x);
    assert(to!F("y"w) == F.y);
    assert(to!F("z"d) == F.z);

    assertThrown!ConvException(to!E("d"));
}

version (none)  // TODO: BUG4744
unittest
{
    enum A { member1, member11, member111 }
    assert(to!A("member1"  ) == A.member1  );
    assert(to!A("member11" ) == A.member11 );
    assert(to!A("member111") == A.member111);
    auto s = "member1111";
    assert(parse!A(s) == A.member111 && s == "1");
}

Target parse(Target, Source)(ref Source p)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) &&
        isFloatingPoint!Target)
{
    static immutable real negtab[14] =
        [ 1e-4096L,1e-2048L,1e-1024L,1e-512L,1e-256L,1e-128L,1e-64L,1e-32L,
                1e-16L,1e-8L,1e-4L,1e-2L,1e-1L,1.0L ];
    static immutable real postab[13] =
        [ 1e+4096L,1e+2048L,1e+1024L,1e+512L,1e+256L,1e+128L,1e+64L,1e+32L,
                1e+16L,1e+8L,1e+4L,1e+2L,1e+1L ];
    // static immutable string infinity = "infinity";
    // static immutable string nans = "nans";

    ConvException bailOut(string fn = __FILE__, size_t ln = __LINE__)
        (string msg = null)
    {
        if (!msg)
            msg = "Floating point conversion error";
        return new ConvException(text(msg, " for input \"", p, "\"."), fn, ln);
    }

    for (;;)
    {
        enforce(!p.empty, bailOut());
        if (!std.uni.isWhite(p.front))
            break;
        p.popFront();
    }
    char sign = 0;                       /* indicating +                 */
    switch (p.front)
    {
    case '-':
        sign++;
        p.popFront();
        enforce(!p.empty, bailOut());
        if (std.ascii.toLower(p.front) == 'i')
            goto case 'i';
        enforce(!p.empty, bailOut());
        break;
    case '+':
        p.popFront();
        enforce(!p.empty, bailOut());
        break;
    case 'i': case 'I':
        p.popFront();
        enforce(!p.empty, bailOut());
        if (std.ascii.toLower(p.front) == 'n' &&
                (p.popFront(), enforce(!p.empty, bailOut()), std.ascii.toLower(p.front) == 'f') &&
                (p.popFront(), p.empty))
        {
            // 'inf'
            return sign ? -Target.infinity : Target.infinity;
        }
        goto default;
    default: {}
    }

    bool isHex = false;
    bool startsWithZero = p.front == '0';
    if(startsWithZero)
    {
        p.popFront();
        if(p.empty)
        {
            return (sign) ? -0 : 0;
        }

        isHex = p.front == 'x' || p.front == 'X';
    }

    real ldval = 0.0;
    char dot = 0;                        /* if decimal point has been seen */
    int exp = 0;
    long msdec = 0, lsdec = 0;
    ulong msscale = 1;

    if (isHex)
    {
        int guard = 0;
        int anydigits = 0;
        uint ndigits = 0;

        p.popFront();
        while (!p.empty)
        {
            int i = p.front;
            while (isHexDigit(i))
            {
                anydigits = 1;
                i = std.ascii.isAlpha(i) ? ((i & ~0x20) - ('A' - 10)) : i - '0';
                if (ndigits < 16)
                {
                    msdec = msdec * 16 + i;
                    if (msdec)
                        ndigits++;
                }
                else if (ndigits == 16)
                {
                    while (msdec >= 0)
                    {
                        exp--;
                        msdec <<= 1;
                        i <<= 1;
                        if (i & 0x10)
                            msdec |= 1;
                    }
                    guard = i << 4;
                    ndigits++;
                    exp += 4;
                }
                else
                {
                    guard |= i;
                    exp += 4;
                }
                exp -= dot;
                p.popFront();
                if (p.empty)
                    break;
                i = p.front;
                if (i == '_')
                {
                    p.popFront();
                    if (p.empty)
                        break;
                    i = p.front;
                }
            }
            if (i == '.' && !dot)
            {       p.popFront();
                dot = 4;
            }
            else
                break;
        }

        // Round up if (guard && (sticky || odd))
        if (guard & 0x80 && (guard & 0x7F || msdec & 1))
        {
            msdec++;
            if (msdec == 0)                 // overflow
            {   msdec = 0x8000000000000000L;
                exp++;
            }
        }

        enforce(anydigits, bailOut());
        enforce(!p.empty && (p.front == 'p' || p.front == 'P'),
                bailOut("Floating point parsing: exponent is required"));
        char sexp;
        int e;

        sexp = 0;
        p.popFront();
        if (!p.empty)
        {
            switch (p.front)
            {   case '-':    sexp++;
                             goto case;
                case '+':    p.popFront(); enforce(!p.empty,
                                new ConvException("Error converting input"
                                " to floating point"));
                             break;
                default: {}
            }
        }
        ndigits = 0;
        e = 0;
        while (!p.empty && isDigit(p.front))
        {
            if (e < 0x7FFFFFFF / 10 - 10) // prevent integer overflow
            {
                e = e * 10 + p.front - '0';
            }
            p.popFront();
            ndigits = 1;
        }
        exp += (sexp) ? -e : e;
        enforce(ndigits, new ConvException("Error converting input"
                        " to floating point"));

        if (msdec)
        {
            int e2 = 0x3FFF + 63;

            // left justify mantissa
            while (msdec >= 0)
            {   msdec <<= 1;
                e2--;
            }

            // Stuff mantissa directly into real
            *cast(long *)&ldval = msdec;
            (cast(ushort *)&ldval)[4] = cast(ushort) e2;

            // Exponent is power of 2, not power of 10
            ldval = ldexpl(ldval,exp);
        }
        goto L6;
    }
    else // not hex
    {
        if (std.ascii.toUpper(p.front) == 'N' && !startsWithZero)
        {
            // nan
            enforce((p.popFront(), !p.empty && std.ascii.toUpper(p.front) == 'A')
                    && (p.popFront(), !p.empty && std.ascii.toUpper(p.front) == 'N'),
                   new ConvException("error converting input to floating point"));
            // skip past the last 'n'
            p.popFront();
            return typeof(return).nan;
        }

        bool sawDigits = startsWithZero;

        while (!p.empty)
        {
            int i = p.front;
            while (isDigit(i))
            {
                sawDigits = true;        /* must have at least 1 digit   */
                if (msdec < (0x7FFFFFFFFFFFL-10)/10)
                    msdec = msdec * 10 + (i - '0');
                else if (msscale < (0xFFFFFFFF-10)/10)
                {   lsdec = lsdec * 10 + (i - '0');
                    msscale *= 10;
                }
                else
                {
                    exp++;
                }
                exp -= dot;
                p.popFront();
                if (p.empty)
                    break;
                i = p.front;
                if (i == '_')
                {
                    p.popFront();
                    if (p.empty)
                        break;
                    i = p.front;
                }
            }
            if (i == '.' && !dot)
            {
                p.popFront();
                dot++;
            }
            else
            {
                break;
            }
        }
        enforce(sawDigits, new ConvException("no digits seen"));
    }
    if (!p.empty && (p.front == 'e' || p.front == 'E'))
    {
        char sexp;
        int e;

        sexp = 0;
        p.popFront();
        enforce(!p.empty, new ConvException("Unexpected end of input"));
        switch (p.front)
        {   case '-':    sexp++;
                         goto case;
            case '+':    p.popFront();
                         break;
            default: {}
        }
        bool sawDigits = 0;
        e = 0;
        while (!p.empty && isDigit(p.front))
        {
            if (e < 0x7FFFFFFF / 10 - 10)   // prevent integer overflow
            {
                e = e * 10 + p.front - '0';
            }
            p.popFront();
            sawDigits = 1;
        }
        exp += (sexp) ? -e : e;
        enforce(sawDigits, new ConvException("No digits seen."));
    }

    ldval = msdec;
    if (msscale != 1)               /* if stuff was accumulated in lsdec */
        ldval = ldval * msscale + lsdec;
    if (ldval)
    {
        uint u = 0;
        int pow = 4096;

        while (exp > 0)
        {
            while (exp >= pow)
            {
                ldval *= postab[u];
                exp -= pow;
            }
            pow >>= 1;
            u++;
        }
        while (exp < 0)
        {
            while (exp <= -pow)
            {
                ldval *= negtab[u];
                enforce(ldval != 0, new ConvException("Range error"));
                exp += pow;
            }
            pow >>= 1;
            u++;
        }
    }
  L6: // if overflow occurred
    enforce(ldval != core.stdc.math.HUGE_VAL, new ConvException("Range error"));

  L1:
    return (sign) ? -ldval : ldval;
}

unittest
{
    // Compare reals with given precision
    bool feq(in real rx, in real ry, in real precision = 0.000001L)
    {
        if (rx == ry)
            return 1;

        if (isnan(rx))
            return cast(bool)isnan(ry);

        if (isnan(ry))
            return 0;

        return cast(bool)(fabs(rx - ry) <= precision);
    }

    // Make given typed literal
    F Literal(F)(F f)
    {
        return f;
    }

    foreach (Float; TypeTuple!(float, double, real))
    {
        debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
        debug(conv) printf("conv.to!%.*s.unittest\n", Float.stringof.length, Float.stringof.ptr);

        assert(to!Float("123") == Literal!Float(123));
        assert(to!Float("+123") == Literal!Float(+123));
        assert(to!Float("-123") == Literal!Float(-123));
        assert(to!Float("123e2") == Literal!Float(123e2));
        assert(to!Float("123e+2") == Literal!Float(123e+2));
        assert(to!Float("123e-2") == Literal!Float(123e-2));
        assert(to!Float("123.") == Literal!Float(123.));
        assert(to!Float(".456") == Literal!Float(.456));

        assert(to!Float("1.23456E+2") == Literal!Float(1.23456E+2));

        assert(to!Float("0") == 0.0);
        assert(to!Float("-0") == -0.0);

        assert(isnan(to!Float("nan")));

        assertThrown!ConvException(to!Float("\x00"));
    }

    // min and max
    float f = to!float("1.17549e-38");
    assert(feq(cast(real)f, cast(real)1.17549e-38));
    assert(feq(cast(real)f, cast(real)float.min_normal));
    f = to!float("3.40282e+38");
    assert(to!string(f) == to!string(3.40282e+38));

    // min and max
    double d = to!double("2.22508e-308");
    assert(feq(cast(real)d, cast(real)2.22508e-308));
    assert(feq(cast(real)d, cast(real)double.min_normal));
    d = to!double("1.79769e+308");
    assert(to!string(d) == to!string(1.79769e+308));
    assert(to!string(d) == to!string(double.max));

    assert(to!string(to!real(to!string(real.max / 2L))) == to!string(real.max / 2L));

    // min and max
    real r = to!real(to!string(real.min_normal));
    assert(to!string(r) == to!string(real.min_normal));
    r = to!real(to!string(real.max));
    assert(to!string(r) == to!string(real.max));
}

unittest
{
    import core.stdc.errno;
    import core.stdc.stdlib;

    errno = 0;  // In case it was set by another unittest in a different module.
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    struct longdouble
    {
        ushort value[5];
    }

    real ld;
    longdouble x;
    real ld1;
    longdouble x1;
    int i;

    string s = "0x1.FFFFFFFFFFFFFFFEp-16382";
    ld = parse!real(s);
    assert(s.empty);
    x = *cast(longdouble *)&ld;
    ld1 = strtold("0x1.FFFFFFFFFFFFFFFEp-16382", null);
    x1 = *cast(longdouble *)&ld1;
    assert(x1 == x && ld1 == ld);

    // for (i = 4; i >= 0; i--)
    // {
    //     printf("%04x ", x.value[i]);
    // }
    // printf("\n");
    assert(!errno);

    s = "1.0e5";
    ld = parse!real(s);
    assert(s.empty);
    x = *cast(longdouble *)&ld;
    ld1 = strtold("1.0e5", null);
    x1 = *cast(longdouble *)&ld1;

    // for (i = 4; i >= 0; i--)
    // {
    //     printf("%04x ", x.value[i]);
    // }
    // printf("\n");
}

// Unittest for bug 4959
unittest
{
    auto s = "0 ";
    auto x = parse!double(s);
    assert(s == " ");
    assert(x == 0.0);
}

// Unittest for bug 3369
unittest
{
    assert(to!float("inf") == float.infinity);
    assert(to!float("-inf") == -float.infinity);
}

// Unittest for bug 6160
unittest
{
    assert(1000_000_000e50L == to!real("1000_000_000_e50"));        // 1e59
    assert(0x1000_000_000_p10 == to!real("0x1000_000_000_p10"));    // 7.03687e+13
}

// Unittest for bug 6258
unittest
{
    assertThrown!ConvException(to!real("-"));
    assertThrown!ConvException(to!real("in"));
}

/**
Parsing one character off a string returns the character and bumps the
string up one position.
 */
Target parse(Target, Source)(ref Source s)
    if (isSomeString!Source &&
        staticIndexOf!(Unqual!Target, dchar, Unqual!(typeof(Source.init[0]))) >= 0)
{
    static if (is(Unqual!Target == dchar))
    {
        Target result = s.front;
        s.popFront();
        return result;
    }
    else
    {
        // Special case: okay so parse a Char off a Char[]
        Target result = s[0];
        s = s[1 .. $];
        return result;
    }
}

unittest
{
    foreach (Str; TypeTuple!(string, wstring, dstring))
    {
        foreach (Char; TypeTuple!(char, wchar, dchar))
        {
            static if (is(Unqual!Char == dchar) ||
                       Char.sizeof == Str.init[0].sizeof)
            {
                Str s = "aaa";
                assert(parse!Char(s) == 'a');
                assert(s == "aa");
            }
        }
    }
}

Target parse(Target, Source)(ref Source s)
    if (!isSomeString!Source && isInputRange!Source && isSomeChar!(ElementType!Source) &&
        isSomeChar!Target && Target.sizeof >= ElementType!Source.sizeof)
{
    Target result = s.front;
    s.popFront();
    return result;
}

// string to bool conversions
Target parse(Target, Source)(ref Source s)
    if (isSomeString!Source &&
        is(Unqual!Target == bool))
{
    if (s.length >= 4 && icmp(s[0 .. 4], "true")==0)
    {
        s = s[4 .. $];
        return true;
    }
    if (s.length >= 5 && icmp(s[0 .. 5], "false")==0)
    {
        s = s[5 .. $];
        return false;
    }
    parseError("bool should be case-insensive 'true' or 'false'");
    assert(0);
}

/*
    Tests for to!bool and parse!bool
*/
unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    debug(conv) printf("conv.to!bool.unittest\n");

    assert (to!bool("TruE") == true);
    assert (to!bool("faLse"d) == false);
    assertThrown!ConvException(to!bool("maybe"));

    auto t = "TrueType";
    assert (parse!bool(t) == true);
    assert (t == "Type");

    auto f = "False killer whale"d;
    assert (parse!bool(f) == false);
    assert (f == " killer whale"d);

    auto m = "maybe";
    assertThrown!ConvException(parse!bool(m));
    assert (m == "maybe");  // m shouldn't change on failure

    auto s = "true";
    auto b = parse!(const(bool))(s);
    assert(b == true);
}

// Parsing typedefs forwards to their host types
Target parse(Target, Source)(ref Source s)
    if (isSomeString!Source &&
        is(Target == typedef))
{
    static if (is(Target T == typedef))
        return cast(Target) parse!T(s);
    else
        static assert(0);
}

private void skipWS(R)(ref R r)
{
    skipAll(r, ' ', '\n', '\t', '\r');
}

/**
 * Parses an array from a string given the left bracket (default $(D
 * '[')), right bracket (default $(D ']')), and element seprator (by
 * default $(D ',')).
 */
Target parse(Target, Source)(ref Source s, dchar lbracket = '[', dchar rbracket = ']', dchar comma = ',')
    if (isSomeString!Source &&
        isDynamicArray!Target)
{
    Target result;

    parseCheck!s(lbracket);
    skipWS(s);
    if (s.front == rbracket)
    {
        s.popFront();
        return result;
    }
    for (;; s.popFront(), skipWS(s))
    {
        result ~= parseElement!(ElementType!Target)(s);
        skipWS(s);
        if (s.front != comma)
            break;
    }
    parseCheck!s(rbracket);

    return result;
}

version(none) unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    typedef uint Testing;
    auto s = "123";
    auto t = parse!Testing(s);
    assert(t == cast(Testing) 123);
}

unittest
{
    int[] a = [1, 2, 3, 4, 5];
    auto s = to!string(a);
    assert(to!(int[])(s) == a);
}

unittest
{
    int[][] a = [ [1, 2] , [3], [4, 5] ];
    auto s = to!string(a);
    assert(to!(int[][])(s) == a);
}

unittest
{
    int[][][] ia = [ [[1,2],[3,4],[5]] , [[6],[],[7,8,9]] , [[]] ];

    char[] s = to!(char[])(ia);
    int[][][] ia2;

    ia2 = to!(typeof(ia2))(s);
    assert( ia == ia2);
}

unittest
{
    auto s1 = `[['h', 'e', 'l', 'l', 'o'], "world"]`;
    auto a1 = parse!(string[])(s1);
    assert(a1 == ["hello", "world"]);

    auto s2 = `["aaa", "bbb", "ccc"]`;
    auto a2 = parse!(string[])(s2);
    assert(a2 == ["aaa", "bbb", "ccc"]);
}

/// ditto
Target parse(Target, Source)(ref Source s, dchar lbracket = '[', dchar rbracket = ']', dchar comma = ',')
    if (isSomeString!Source &&
        isStaticArray!Target)
{
    Target result = void;

    parseCheck!s(lbracket);
    skipWS(s);
    if (s.front == rbracket)
    {
        static if (result.length != 0)
            goto Lmanyerr;
        else
        {
            s.popFront();
            return result;
        }
    }
    for (size_t i = 0; ; s.popFront(), skipWS(s))
    {
        if (i == result.length)
            goto Lmanyerr;
        result[i++] = parseElement!(ElementType!Target)(s);
        skipWS(s);
        if (s.front != comma)
        {
            if (i != result.length)
                goto Lfewerr;
            break;
        }
    }
    parseCheck!s(rbracket);

    return result;

Lmanyerr:
    parseError(text("Too many elements in input, ", result.length, " elements expected."));
    assert(0);

Lfewerr:
    parseError(text("Too few elements in input, ", result.length, " elements expected."));
    assert(0);
}

unittest
{
    auto s1 = "[1,2,3,4]";
    auto sa1 = parse!(int[4])(s1);
    assert(sa1 == [1,2,3,4]);

    auto s2 = "[[1],[2,3],[4]]";
    auto sa2 = parse!(int[][3])(s2);
    assert(sa2 == [[1],[2,3],[4]]);

    auto s3 = "[1,2,3]";
    assertThrown!ConvException(parse!(int[4])(s3));

    auto s4 = "[1,2,3,4,5]";
    assertThrown!ConvException(parse!(int[4])(s4));
}

/**
 * Parses an associative array from a string given the left bracket (default $(D
 * '[')), right bracket (default $(D ']')), key-value separator (default $(D
 * ':')), and element seprator (by default $(D ',')).
 */
Target parse(Target, Source)(ref Source s, dchar lbracket = '[', dchar rbracket = ']', dchar keyval = ':', dchar comma = ',')
    if (isSomeString!Source &&
        isAssociativeArray!Target)
{
    alias typeof(Target.keys[0]) KeyType;
    alias typeof(Target.values[0]) ValueType;

    Target result;

    parseCheck!s(lbracket);
    skipWS(s);
    if (s.front == rbracket)
    {
        s.popFront();
        return result;
    }
    for (;; s.popFront(), skipWS(s))
    {
        auto key = parseElement!KeyType(s);
        skipWS(s);
        parseCheck!s(keyval);
        skipWS(s);
        auto val = parseElement!ValueType(s);
        skipWS(s);
        result[key] = val;
        if (s.front != comma) break;
    }
    parseCheck!s(rbracket);

    return result;
}

unittest
{
    auto s1 = "[1:10, 2:20, 3:30]";
    auto aa1 = parse!(int[int])(s1);
    assert(aa1 == [1:10, 2:20, 3:30]);

    auto s2 = `["aaa":10, "bbb":20, "ccc":30]`;
    auto aa2 = parse!(int[string])(s2);
    assert(aa2 == ["aaa":10, "bbb":20, "ccc":30]);

    auto s3 = `["aaa":[1], "bbb":[2,3], "ccc":[4,5,6]]`;
    auto aa3 = parse!(int[][string])(s3);
    assert(aa3 == ["aaa":[1], "bbb":[2,3], "ccc":[4,5,6]]);
}

private dchar parseEscape(Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source))
{
    parseCheck!s('\\');

    dchar getHexDigit()
    {
        s.popFront();
        if (s.empty)
            parseError("Unterminated escape sequence");
        dchar c = s.front;
        if (!isHexDigit(c))
            parseError("Hex digit is missing");
        return std.ascii.isAlpha(c) ? ((c & ~0x20) - ('A' - 10)) : c - '0';
    }

    dchar result;

    switch (s.front)
    {
        case 'a':   result = '\a';  break;
        case 'b':   result = '\b';  break;
        case 'f':   result = '\f';  break;
        case 'n':   result = '\n';  break;
        case 'r':   result = '\r';  break;
        case 't':   result = '\t';  break;
        case 'v':   result = '\v';  break;
        case 'x':
            result  = getHexDigit() << 4;
            result |= getHexDigit();
            break;
        case 'u':
            result  = getHexDigit() << 12;
            result |= getHexDigit() << 8;
            result |= getHexDigit() << 4;
            result |= getHexDigit();
            break;
        case 'U':
            result  = getHexDigit() << 28;
            result |= getHexDigit() << 24;
            result |= getHexDigit() << 20;
            result |= getHexDigit() << 16;
            result |= getHexDigit() << 12;
            result |= getHexDigit() << 8;
            result |= getHexDigit() << 4;
            result |= getHexDigit();
            break;
        default:
            parseError("Unknown escape character " ~ to!string(s.front));
            break;
    }

    s.popFront();

    return result;
}

// Undocumented
Target parseElement(Target, Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) &&
        isSomeString!Target)
{
    auto result = appender!Target();

    // parse array of chars
    if (s.front == '[')
        return parse!Target(s);

    parseCheck!s('\"');
    if (s.front == '\"')
    {
        s.popFront();
        return result.data;
    }
    while (true)
    {
        if (s.empty)
            parseError("Unterminated quoted string");
        switch (s.front)
        {
            case '\"':
                s.popFront();
                return result.data;
            case '\\':
                result.put(parseEscape(s));
                break;
            default:
                result.put(s.front());
                s.popFront();
                break;
        }
    }
    assert(0);
}

// ditto
Target parseElement(Target, Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) &&
        isSomeChar!Target)
{
    Target c;

    parseCheck!s('\'');
    if (s.front != '\\')
    {
        c = s.front;
        s.popFront();
    }
    else
        c = parseEscape(s);
    parseCheck!s('\'');

    return c;
}

// ditto
Target parseElement(Target, Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) &&
        !isSomeString!Target && !isSomeChar!Target)
{
    return parse!Target(s);
}


/***************************************************************
   Convenience functions for converting any number and types of
   arguments into _text (the three character widths).

   Example:
----
assert(text(42, ' ', 1.5, ": xyz") == "42 1.5: xyz");
assert(wtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"w);
assert(dtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"d);
----
*/
string text(T...)(T args)
{
    return textImpl!string(args);
}
///ditto
wstring wtext(T...)(T args)
{
    return textImpl!wstring(args);
}
///ditto
dstring dtext(T...)(T args)
{
    return textImpl!dstring(args);
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

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    assert(text(42, ' ', 1.5, ": xyz") == "42 1.5: xyz");
    assert(wtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"w);
    assert(dtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"d);
}

/***************************************************************
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
    if((octalFitsInInt!(num) && !literalIsLong!(num)) && !literalIsUnsigned!(num))
{
    return octal!(int, num);
}

/// Ditto
long octal(string num)()
    if((!octalFitsInInt!(num) || literalIsLong!(num)) && !literalIsUnsigned!(num))
{
    return octal!(long, num);
}

/// Ditto
uint octal(string num)()
    if((octalFitsInInt!(num) && !literalIsLong!(num)) && literalIsUnsigned!(num))
{
    return octal!(int, num);
}

/// Ditto
ulong octal(string num)()
    if((!octalFitsInInt!(num) || literalIsLong!(num)) && literalIsUnsigned!(num))
{
    return octal!(long, num);
}

/// Ditto
template octal(alias s)
    if (isIntegral!(typeof(s)))
{
    enum auto octal = octal!(typeof(s), toStringNow!(s));
}

/*
    Takes a string, num, which is an octal literal, and returns its
    value, in the type T specified.

    So:

    int a = octal!(int, "10");

    assert(a == 8);
*/
T octal(T, string num)()
    if (isOctalLiteral!num)
{
    ulong pow = 1;
    T value = 0;

    for (int pos = num.length - 1; pos >= 0; pos--)
    {
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

/*
Take a look at int.max and int.max+1 in octal and the logic for this
function follows directly.
 */
template octalFitsInInt(string octalNum)
{
    // note it is important to strip the literal of all
    // non-numbers. kill the suffix and underscores lest they mess up
    // the number of digits here that we depend on.
    enum bool octalFitsInInt = strippedOctalLiteral(octalNum).length < 11 ||
        strippedOctalLiteral(octalNum).length == 11 &&
        strippedOctalLiteral(octalNum)[0] == '1';
}

string strippedOctalLiteral(string original)
{
    string stripped = "";
    foreach (c; original)
        if (c >= '0' && c <= '7')
            stripped ~= c;
    return stripped;
}

template literalIsLong(string num)
{
    static if (num.length > 1)
    // can be xxL or xxLu according to spec
        enum literalIsLong = (num[$-1] == 'L' || num[$-2] == 'L');
    else
        enum literalIsLong = false;
}

template literalIsUnsigned(string num)
{
    static if (num.length > 1)
    // can be xxU or xxUL according to spec
        enum literalIsUnsigned = (num[$-1] == 'u' || num[$-2] == 'u')
            // both cases are allowed too
            || (num[$-1] == 'U' || num[$-2] == 'U');
    else
        enum literalIsUnsigned = false;
}

/*
Returns if the given string is a correctly formatted octal literal.

The format is specified in lex.html. The leading zero is allowed, but
not required.
 */
bool isOctalLiteralString(string num)
{
    if (num.length == 0)
        return false;

    // Must start with a number. To avoid confusion, literals that
    // start with a '0' are not allowed
    if (num[0] == '0' && num.length > 1)
        return false;
    if (num[0] < '0' || num[0] > '7')
        return false;

    foreach (i, c; num)
    {
        if ((c < '0' || c > '7') && c != '_') // not a legal character
        {
            if (i < num.length - 2)
                    return false;
            else   // gotta check for those suffixes
            {
                if (c != 'U' && c != 'u' && c != 'L')
                        return false;
                if (i != num.length - 1)
                {
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
    }

    return true;
}

/*
    Returns true if the given compile time string is an octal literal.
*/
template isOctalLiteral(string num)
{
    enum bool isOctalLiteral = isOctalLiteralString(num);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__,
            " succeeded.");
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

    static assert(!__traits(compiles, octal!"823"));

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

// emplace
/**
Given a pointer $(D chunk) to uninitialized memory (but already typed
as $(D T)), constructs an object of non-$(D class) type $(D T) at that
address.

This function can be $(D @trusted) if the corresponding constructor of
$(D T) is $(D @safe).

Returns: A pointer to the newly constructed object (which is the same
as $(D chunk)).
 */
T* emplace(T)(T* chunk)
    if (!is(T == class))
{
    auto result = cast(typeof(return)) chunk;
    static T i;
    memcpy(result, &i, T.sizeof);
    return result;
}
///ditto
T* emplace(T)(T* chunk)
    if (is(T == class))
{
    *chunk = null;
    return chunk;
}


/**
Given a pointer $(D chunk) to uninitialized memory (but already typed
as a non-class type $(D T)), constructs an object of type $(D T) at
that address from arguments $(D args).

This function can be $(D @trusted) if the corresponding constructor of
$(D T) is $(D @safe).

Returns: A pointer to the newly constructed object (which is the same
as $(D chunk)).
 */
T* emplace(T, Args...)(T* chunk, Args args)
    if (!is(T == struct) && Args.length == 1)
{
    *chunk = args[0];
    return chunk;
}

// Specialization for struct
T* emplace(T, Args...)(T* chunk, Args args)
    if (is(T == struct))
{
    auto result = cast(typeof(return)) chunk;

    void initialize()
    {
        static T i;
        memcpy(chunk, &i, T.sizeof);
    }

    static if (is(typeof(result.__ctor(args))))
    {
        // T defines a genuine constructor accepting args
        // Go the classic route: write .init first, then call ctor
        initialize();
        result.__ctor(args);
    }
    else static if (is(typeof(T(args))))
    {
        // Struct without constructor that has one matching field for
        // each argument
        *result = T(args);
    }
    else //static if (Args.length == 1 && is(Args[0] : T))
    {
        static assert(Args.length == 1);
        //static assert(0, T.stringof ~ " " ~ Args.stringof);
        // initialize();
        *result = args[0];
    }
    return result;
}

/**
Given a raw memory area $(D chunk), constructs an object of $(D class)
type $(D T) at that address. The constructor is passed the arguments
$(D Args). The $(D chunk) must be as least as large as $(D T) needs
and should have an alignment multiple of $(D T)'s alignment. (The size
of a $(D class) instance is obtained by using $(D
__traits(classInstanceSize, T))).

This function can be $(D @trusted) if the corresponding constructor of
$(D T) is $(D @safe).

Returns: A pointer to the newly constructed object.
 */
T emplace(T, Args...)(void[] chunk, Args args) if (is(T == class))
{
    enforce(chunk.length >= __traits(classInstanceSize, T),
           new ConvException("emplace: chunk size too small"));
    auto a = cast(size_t) chunk.ptr;
    enforce(a % T.alignof == 0, text(a, " vs. ", T.alignof));
    auto result = cast(typeof(return)) chunk.ptr;

    // Initialize the object in its pre-ctor state
    (cast(byte[]) chunk)[] = typeid(T).init[];

    // Call the ctor if any
    static if (is(typeof(result.__ctor(args))))
    {
        // T defines a genuine constructor accepting args
        // Go the classic route: write .init first, then call ctor
        result.__ctor(args);
    }
    else
    {
        static assert(args.length == 0 && !is(typeof(&T.__ctor)),
                "Don't know how to initialize an object of type "
                ~ T.stringof ~ " with arguments " ~ Args.stringof);
    }
    return result;
}

/**
Given a raw memory area $(D chunk), constructs an object of non-$(D
class) type $(D T) at that address. The constructor is passed the
arguments $(D args), if any. The $(D chunk) must be as least as large
as $(D T) needs and should have an alignment multiple of $(D T)'s
alignment.

This function can be $(D @trusted) if the corresponding constructor of
$(D T) is $(D @safe).

Returns: A pointer to the newly constructed object.
 */
T* emplace(T, Args...)(void[] chunk, Args args)
    if (!is(T == class))
{
    enforce(chunk.length >= T.sizeof,
           new ConvException("emplace: chunk size too small"));
    auto a = cast(size_t) chunk.ptr;
    enforce(a % T.alignof == 0, text(a, " vs. ", T.alignof));
    auto result = cast(typeof(return)) chunk.ptr;
    return emplace(result, args);
}

unittest
{
    struct S
    {
        int a, b;
    }
    auto p = new void[S.sizeof];
    S s;
    s.a = 42;
    s.b = 43;
    auto s1 = emplace!S(p, s);
    assert(s1.a == 42 && s1.b == 43);
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__,
            " succeeded.");
    int a;
    int b = 42;
    assert(*emplace!int(&a, b) == 42);

    struct S
    {
        double x = 5, y = 6;
        this(int a, int b)
        {
            assert(x == 5 && y == 6);
            x = a;
            y = b;
        }
    }

    auto s1 = new void[S.sizeof];
    auto s2 = S(42, 43);
    assert(*emplace!S(cast(S*) s1.ptr, s2) == s2);
    assert(*emplace!S(cast(S*) s1, 44, 45) == S(44, 45));
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    class A
    {
        int x = 5;
        int y = 42;
        this(int z)
        {
            assert(x == 5 && y == 42);
            x = y = z;
        }
    }
    static byte[__traits(classInstanceSize, A)] buf;
    auto a = emplace!A(cast(void[]) buf, 55);
    assert(a.x == 55 && a.y == 55);
    static assert(!is(typeof(emplace!A(cast(void[]) buf))));
}

unittest
{
    debug(conv) scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " succeeded.");
    // Check fix for http://d.puremagic.com/issues/show_bug.cgi?id=2971
    assert(equal(map!(to!int)(["42", "34", "345"]), [42, 34, 345]));
}

unittest
{
    struct Foo
    {
        uint num;
    }

    Foo foo;
    emplace!Foo(&foo, 2U);
    assert(foo.num == 2);
}

unittest
{
    interface I {}
    class K : I {}

    K k = void;
    emplace!K(&k);
    assert(k is null);
    K k2 = new K;
    assert(k2 !is null);
    emplace!K(&k, k2);
    assert(k is k2);

    I i = void;
    emplace!I(&i);
    assert(i is null);
    emplace!I(&i, k);
    assert(i is k);
}

// Undocumented for the time being
void toTextRange(T, W)(T value, W writer)
    if (isIntegral!T && isOutputRange!(W, char))
{
    Unqual!(Unsigned!T) v = void;
    if (value < 0)
    {
        put(writer, '-');
        v = -value;
    }
    else
    {
        v = value;
    }

    if (v < 10 && v < hexDigits.length)
    {
        put(writer, hexDigits[cast(size_t) v]);
        return;
    }

    char[v.sizeof * 4] buffer = void;
    auto i = buffer.length;

    do
    {
        auto c = cast(ubyte) (v % 10);
        v = v / 10;
        i--;
        buffer[i] = cast(char) (c + '0');
    } while (v);

    put(writer, buffer[i .. $]);
}

