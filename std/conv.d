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

Macros:
WIKI = Phobos/StdConv

*/
module std.conv;

import core.stdc.string;
import std.algorithm, std.array, std.ascii, std.exception, std.range,
    std.string, std.traits, std.typecons, std.typetuple, std.uni,
    std.utf;
import std.format;

/* ************* Exceptions *************** */

/**
 * Thrown on conversion errors.
 */
class ConvException : Exception
{
    @safe pure nothrow
    this(string s, string fn = __FILE__, size_t ln = __LINE__)
    {
        super(s, fn, ln);
    }
}

private string convError_unexpected(S)(S source)
{
    return source.empty ? "end of input" : text("'", source.front, "'");
}

private auto convError(S, T)(S source, string fn = __FILE__, size_t ln = __LINE__)
{
    return new ConvException(
        text("Unexpected ", convError_unexpected(source),
             " when converting from type "~S.stringof~" to type "~T.stringof),
        fn, ln);
}

private auto convError(S, T)(S source, int radix, string fn = __FILE__, size_t ln = __LINE__)
{
    return new ConvException(
        text("Unexpected ", convError_unexpected(source),
             " when converting from type "~S.stringof~" base ", radix,
             " to type "~T.stringof),
        fn, ln);
}

@safe pure/* nothrow*/  // lazy parameter bug
private auto parseError(lazy string msg, string fn = __FILE__, size_t ln = __LINE__)
{
    return new ConvException(text("Can't parse string: ", msg), fn, ln);
}

private void parseCheck(alias source)(dchar c, string fn = __FILE__, size_t ln = __LINE__)
{
    if (source.empty)
        throw parseError(text("unexpected end of input when expecting", "\"", c, "\""));
    if (source.front != c)
        throw parseError(text("\"", c, "\" is missing"), fn, ln);
    source.popFront();
}

private
{
    template isImaginary(T)
    {
        enum bool isImaginary = staticIndexOf!(Unqual!T,
                ifloat, idouble, ireal) >= 0;
    }
    template isComplex(T)
    {
        enum bool isComplex = staticIndexOf!(Unqual!T,
                cfloat, cdouble, creal) >= 0;
    }
    template isNarrowInteger(T)
    {
        enum bool isNarrowInteger = staticIndexOf!(Unqual!T,
                byte, ubyte, short, ushort) >= 0;
    }

    T toStr(T, S)(S src)
        if (isSomeString!T)
    {
        import std.format : FormatSpec, formatValue;

        auto w = appender!T();
        FormatSpec!(ElementEncodingType!T) f;
        formatValue(w, src, f);
        return w.data;
    }

    template isExactSomeString(T)
    {
        enum isExactSomeString = isSomeString!T && !is(T == enum);
    }

    template isEnumStrToStr(S, T)
    {
        enum isEnumStrToStr = isImplicitlyConvertible!(S, T) &&
                              is(S == enum) && isExactSomeString!T;
    }
    template isNullToStr(S, T)
    {
        enum isNullToStr = isImplicitlyConvertible!(S, T) &&
                           (is(Unqual!S == typeof(null))) && isExactSomeString!T;
    }

    template isRawStaticArray(T, A...)
    {
        enum isRawStaticArray =
            A.length == 0 &&
            isStaticArray!T &&
            !is(T == class) &&
            !is(T == interface) &&
            !is(T == struct) &&
            !is(T == union);
    }
}

/**
 * Thrown on conversion overflow errors.
 */
class ConvOverflowException : ConvException
{
    @safe pure nothrow
    this(string s, string fn = __FILE__, size_t ln = __LINE__)
    {
        super(s, fn, ln);
    }
}

/**

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

 */

/**
   Entry point that dispatches to the appropriate conversion
   primitive. Client code normally calls $(D _to!TargetType(value))
   (and not some variant of $(D toImpl)).
 */
template to(T)
{
    T to(A...)(A args)
        if (!isRawStaticArray!A)
    {
        return toImpl!T(args);
    }

    // Fix issue 6175
    T to(S)(ref S arg)
        if (isRawStaticArray!S)
    {
        return toImpl!T(arg);
    }
}

// Tests for issue 6175
@safe pure nothrow unittest
{
    char[9] sarr = "blablabla";
    auto darr = to!(char[])(sarr);
    assert(sarr.ptr == darr.ptr);
    assert(sarr.length == darr.length);
}

// Tests for issue 7348
@safe pure /+nothrow+/ unittest
{
    assert(to!string(null) == "null");
    assert(text(null) == "null");
}

// Tests for issue 11390
@safe pure /+nothrow+/ unittest
{
    const(typeof(null)) ctn;
    immutable(typeof(null)) itn;
    assert(to!string(ctn) == "null");
    assert(to!string(itn) == "null");
}

// Tests for issue 8729: do NOT skip leading WS
@safe pure unittest
{
    foreach (T; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        assertThrown!ConvException(to!T(" 0"));
        assertThrown!ConvException(to!T(" 0", 8));
    }
    foreach (T; TypeTuple!(float, double, real))
    {
        assertThrown!ConvException(to!T(" 0"));
    }

    assertThrown!ConvException(to!bool(" true"));

    alias NullType = typeof(null);
    assertThrown!ConvException(to!NullType(" null"));

    alias ARR = int[];
    assertThrown!ConvException(to!ARR(" [1]"));

    alias AA = int[int];
    assertThrown!ConvException(to!AA(" [1:1]"));
}

/**
If the source type is implicitly convertible to the target type, $(D
to) simply performs the implicit conversion.
 */
T toImpl(T, S)(S value)
    if (isImplicitlyConvertible!(S, T) &&
        !isEnumStrToStr!(S, T) && !isNullToStr!(S, T))
{
    template isSignedInt(T)
    {
        enum isSignedInt = isIntegral!T && isSigned!T;
    }
    alias isUnsignedInt = isUnsigned;

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

@safe pure nothrow unittest
{
    enum E { a }  // Issue 9523 - Allow identity enum conversion
    auto e = to!E(E.a);
    assert(e == E.a);
}

@safe pure nothrow unittest
{
    int a = 42;
    auto b = to!long(a);
    assert(a == b);
}

// Tests for issue 6377
@safe pure unittest
{
    // Conversion between same size
    foreach (S; TypeTuple!(byte, short, int, long))
    {
        alias U = Unsigned!S;

        foreach (Sint; TypeTuple!(S, const S, immutable S))
        foreach (Uint; TypeTuple!(U, const U, immutable U))
        {
            // positive overflow
            Uint un = Uint.max;
            assertThrown!ConvOverflowException(to!Sint(un),
                text(Sint.stringof, ' ', Uint.stringof, ' ', un));

            // negative overflow
            Sint sn = -1;
            assertThrown!ConvOverflowException(to!Uint(sn),
                text(Sint.stringof, ' ', Uint.stringof, ' ', un));
        }
    }

    // Conversion between different size
    foreach (i, S1; TypeTuple!(byte, short, int, long))
    foreach (   S2; TypeTuple!(byte, short, int, long)[i+1..$])
    {
        alias U1 = Unsigned!S1;
        alias U2 = Unsigned!S2;

        static assert(U1.sizeof < S2.sizeof);

        // small unsigned to big signed
        foreach (Uint; TypeTuple!(U1, const U1, immutable U1))
        foreach (Sint; TypeTuple!(S2, const S2, immutable S2))
        {
            Uint un = Uint.max;
            assertNotThrown(to!Sint(un));
            assert(to!Sint(un) == un);
        }

        // big unsigned to small signed
        foreach (Uint; TypeTuple!(U2, const U2, immutable U2))
        foreach (Sint; TypeTuple!(S1, const S1, immutable S1))
        {
            Uint un = Uint.max;
            assertThrown(to!Sint(un));
        }

        static assert(S1.sizeof < U2.sizeof);

        // small signed to big unsigned
        foreach (Sint; TypeTuple!(S1, const S1, immutable S1))
        foreach (Uint; TypeTuple!(U2, const U2, immutable U2))
        {
            Sint sn = -1;
            assertThrown!ConvOverflowException(to!Uint(sn));
        }

        // big signed to small unsigned
        foreach (Sint; TypeTuple!(S2, const S2, immutable S2))
        foreach (Uint; TypeTuple!(U1, const U1, immutable U1))
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
    if (isRawStaticArray!S)
{
    return toImpl!(T, typeof(s[0])[])(s);
}

@safe pure nothrow unittest
{
    char[4] test = ['a', 'b', 'c', 'd'];
    static assert(!isInputRange!(Unqual!(char[4])));
    assert(to!string(test) == test);
}

/**
When source type supports member template function opCast, is is used.
*/
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        is(typeof(S.init.opCast!T()) : T) &&
        !isExactSomeString!T &&
        !is(typeof(T(value))))
{
    return value.opCast!T();
}

@safe pure unittest
{
    static struct Test
    {
        struct T
        {
            this(S s) @safe pure { }
        }
        struct S
        {
            T opCast(U)() @safe pure { assert(false); }
        }
    }
    to!(Test.T)(Test.S());

    // make sure std.conv.to is doing the same thing as initialization
    Test.S s;
    Test.T t = s;
}

@safe pure unittest
{
    class B
    {
        T opCast(T)() { return 43; }
    }
    auto b = new B;
    assert(to!int(b) == 43);

    struct S
    {
        T opCast(T)() { return 43; }
    }
    auto s = S();
    assert(to!int(s) == 43);
}

/**
When target type supports 'converting construction', it is used.
$(UL $(LI If target type is struct, $(D T(value)) is used.)
     $(LI If target type is class, $(D new T(value)) is used.))
*/
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        is(T == struct) && is(typeof(T(value))))
{
    return T(value);
}

// Bugzilla 3961
@safe pure unittest
{
    struct Int
    {
        int x;
    }
    Int i = to!Int(1);

    static struct Int2
    {
        int x;
        this(int x) @safe pure { this.x = x; }
    }
    Int2 i2 = to!Int2(1);

    static struct Int3
    {
        int x;
        static Int3 opCall(int x) @safe pure
        {
            Int3 i;
            i.x = x;
            return i;
        }
    }
    Int3 i3 = to!Int3(1);
}

// Bugzilla 6808
@safe pure unittest
{
    static struct FakeBigInt
    {
        this(string s) @safe pure {}
    }

    string s = "101";
    auto i3 = to!FakeBigInt(s);
}

/// ditto
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        is(T == class) && is(typeof(new T(value))))
{
    return new T(value);
}

@safe pure unittest
{
    static struct S
    {
        int x;
    }
    static class C
    {
        int x;
        this(int x) @safe pure { this.x = x; }
    }

    static class B
    {
        int value;
        this(S src) @safe pure { value = src.x; }
        this(C src) @safe pure { value = src.x; }
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

@safe pure unittest
{
    struct S
    {
        class A
        {
            this(B b) @safe pure {}
        }
        class B : A
        {
            this() @safe pure { super(this); }
        }
    }

    S.B b = new S.B();
    S.A a = to!(S.A)(b);      // == cast(S.A)b
                              // (do not run construction conversion like new S.A(b))
    assert(b is a);

    static class C : Object
    {
        this() @safe pure {}
        this(Object o) @safe pure {}
    }

    Object oc = new C();
    C a2 = to!C(oc);    // == new C(a)
                        // Construction conversion overrides down-casting conversion
    assert(a2 !is a);   //
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

    auto result = ()@trusted{ return cast(T) value; }();
    if (!result && value)
    {
        throw new ConvException("Cannot convert object of static type "
                ~S.classinfo.name~" and dynamic type "~value.classinfo.name
                ~" to type "~T.classinfo.name);
    }
    return result;
}

@safe pure unittest
{
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
@safe pure unittest
{
    alias Identity(T)      =              T;
    alias toConst(T)       =        const T;
    alias toShared(T)      =       shared T;
    alias toSharedConst(T) = shared const T;
    alias toImmutable(T)   =    immutable T;
    template AddModifier(int n) if (0 <= n && n < 5)
    {
             static if (n == 0) alias AddModifier = Identity;
        else static if (n == 1) alias AddModifier = toConst;
        else static if (n == 2) alias AddModifier = toShared;
        else static if (n == 3) alias AddModifier = toSharedConst;
        else static if (n == 4) alias AddModifier = toImmutable;
    }

    interface I {}
    interface J {}

    class A {}
    class B : A {}
    class C : B, I, J {}
    class D : I {}

    foreach (m1; TypeTuple!(0,1,2,3,4)) // enumerate modifiers
    foreach (m2; TypeTuple!(0,1,2,3,4)) // ditto
    {
        alias srcmod = AddModifier!m1;
        alias tgtmod = AddModifier!m2;
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
Stringize conversion from all types is supported.
$(UL
  $(LI String _to string conversion works for any two string types having
       ($(D char), $(D wchar), $(D dchar)) character widths and any
       combination of qualifiers (mutable, $(D const), or $(D immutable)).)
  $(LI Converts array (other than strings) to string.
       Each element is converted by calling $(D to!T).)
  $(LI Associative array to string conversion.
       Each element is printed by calling $(D to!T).)
  $(LI Object to string conversion calls $(D toString) against the object or
       returns $(D "null") if the object is null.)
  $(LI Struct to string conversion calls $(D toString) against the struct if
       it is defined.)
  $(LI For structs that do not define $(D toString), the conversion to string
       produces the list of fields.)
  $(LI Enumerated types are converted to strings as their symbolic names.)
  $(LI Boolean values are printed as $(D "true") or $(D "false").)
  $(LI $(D char), $(D wchar), $(D dchar) to a string type.)
  $(LI Unsigned or signed integers to strings.
       $(DL $(DT [special case])
            $(DD Convert integral value to string in $(D_PARAM radix) radix.
            radix must be a value from 2 to 36.
            value is treated as a signed value only if radix is 10.
            The characters A through Z are used to represent values 10 through 36
            and their case is determined by the $(D_PARAM letterCase) parameter.)))
  $(LI All floating point types to all string types.)
  $(LI Pointer to string conversions prints the pointer as a $(D size_t) value.
       If pointer is $(D char*), treat it as C-style strings.
       In that case, this function is $(D @system).))
*/
T toImpl(T, S)(S value)
    if (!(isImplicitlyConvertible!(S, T) &&
          !isEnumStrToStr!(S, T) && !isNullToStr!(S, T)) &&
        isExactSomeString!T)
{
    static if (isExactSomeString!S && value[0].sizeof == ElementEncodingType!T.sizeof)
    {
        // string-to-string with incompatible qualifier conversion
        static if (is(ElementEncodingType!T == immutable))
        {
            // conversion (mutable|const) -> immutable
            return value.idup;
        }
        else
        {
            // conversion (immutable|const) -> mutable
            return value.dup;
        }
    }
    else static if (isExactSomeString!S)
    {
        // other string-to-string
        //Use Appender directly instead of toStr, which also uses a formatedWrite
        auto w = appender!T();
        w.put(value);
        return w.data;
    }
    else static if (isIntegral!S && !is(S == enum))
    {
        // other integral-to-string conversions with default radix
        return toImpl!(T, S)(value, 10);
    }
    else static if (is(S == void[]) || is(S == const(void)[]) || is(S == immutable(void)[]))
    {
        // Converting void array to string
        alias Char = Unqual!(ElementEncodingType!T);
        auto raw = cast(const(ubyte)[]) value;
        enforce(raw.length % Char.sizeof == 0,
                new ConvException("Alignment mismatch in converting a "
                        ~ S.stringof ~ " to a "
                        ~ T.stringof));
        auto result = new Char[raw.length / Char.sizeof];
        ()@trusted{ memcpy(result.ptr, value.ptr, value.length); }();
        return cast(T) result;
    }
    else static if (isPointer!S && is(S : const(char)*))
    {
        // It is unsafe because we cannot guarantee that the pointer is null terminated.
        return value ? cast(T) value[0 .. strlen(value)].dup : cast(string)null;
    }
    else static if (isSomeString!T && is(S == enum))
    {
        static if (isSwitchable!(OriginalType!S) && EnumMembers!S.length <= 50)
        {
            switch(value)
            {
                foreach (member; NoDuplicates!(EnumMembers!S))
                {
                    case member:
                        return to!T(enumRep!(immutable(T), S, member));
                }
                default:
            }
        }
        else
        {
            foreach (member; EnumMembers!S)
            {
                if (value == member)
                    return to!T(enumRep!(immutable(T), S, member));
            }
        }

        import std.format : FormatSpec, formatValue;

        //Default case, delegate to format
        //Note: we don't call toStr directly, to avoid duplicate work.
        auto app = appender!T();
        app.put("cast(");
        app.put(S.stringof);
        app.put(')');
        FormatSpec!char f;
        formatValue(app, cast(OriginalType!S)value, f);
        return app.data;
    }
    else
    {
        // other non-string values runs formatting
        return toStr!T(value);
    }
}

/*
    Check whether type $(D T) can be used in a switch statement.
    This is useful for compile-time generation of switch case statements.
*/
private template isSwitchable(E)
{
    enum bool isSwitchable = is(typeof({
        switch (E.init) { default: }
    }));
}

//
unittest
{
    static assert(isSwitchable!int);
    static assert(!isSwitchable!double);
    static assert(!isSwitchable!real);
}

//Static representation of the index I of the enum S,
//In representation T.
//T must be an immutable string (avoids un-necessary initializations).
private template enumRep(T, S, S value)
if (is (T == immutable) && isExactSomeString!T && is(S == enum))
{
    static T enumRep = toStr!T(value);
}

@safe pure unittest
{
    void dg()
    {
        // string to string conversion
        alias Chars = TypeTuple!(char, wchar, dchar);
        foreach (LhsC; Chars)
        {
            alias LhStrings = TypeTuple!(LhsC[], const(LhsC)[], immutable(LhsC)[]);
            foreach (Lhs; LhStrings)
            {
                foreach (RhsC; Chars)
                {
                    alias RhStrings = TypeTuple!(RhsC[], const(RhsC)[], immutable(RhsC)[]);
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

        foreach (T; Chars)
        {
            foreach (U; Chars)
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
    dg();
    assertCTFEable!dg;
}

@safe pure unittest
{
    // Conversion reinterpreting void array to string
    auto a = "abcx"w;
    const(void)[] b = a;
    assert(b.length == 8);

    auto c = to!(wchar[])(b);
    assert(c == "abcx");
}

@system pure nothrow unittest
{
    // char* to string conversion
    assert(to!string(cast(char*) null) == "");
    assert(to!string("foo\0".ptr) == "foo");
}

@safe pure /+nothrow+/ unittest
{
    // Conversion representing bool value with string
    bool b;
    assert(to!string(b) == "false");
    b = true;
    assert(to!string(b) == "true");
}

@safe pure unittest
{
    // Conversion representing character value with string
    alias AllChars =
        TypeTuple!( char, const( char), immutable( char),
                   wchar, const(wchar), immutable(wchar),
                   dchar, const(dchar), immutable(dchar));
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

    string s = "foo";
    string s2;
    foreach (char c; s)
    {
        s2 ~= to!string(c);
    }
    //printf("%.*s", s2);
    assert(s2 == "foo");
}

@safe pure nothrow unittest
{
    // Conversion representing integer values with string

    foreach (Int; TypeTuple!(ubyte, ushort, uint, ulong))
    {
        assert(to!string(Int(0)) == "0");
        assert(to!string(Int(9)) == "9");
        assert(to!string(Int(123)) == "123");
    }

    foreach (Int; TypeTuple!(byte, short, int, long))
    {
        assert(to!string(Int(0)) == "0");
        assert(to!string(Int(9)) == "9");
        assert(to!string(Int(123)) == "123");
        assert(to!string(Int(-0)) == "0");
        assert(to!string(Int(-9)) == "-9");
        assert(to!string(Int(-123)) == "-123");
        assert(to!string(const(Int)(6)) == "6");
    }

    assert(wtext(int.max) == "2147483647"w);
    assert(wtext(int.min) == "-2147483648"w);
    assert(to!string(0L) == "0");

    assertCTFEable!(
    {
        assert(to!string(1uL << 62) == "4611686018427387904");
        assert(to!string(0x100000000) == "4294967296");
        assert(to!string(-138L) == "-138");
    });
}

@safe pure /+nothrow+/ unittest
{
    // Conversion representing dynamic/static array with string
    long[] b = [ 1, 3, 5 ];
    auto s = to!string(b);
    assert(to!string(b) == "[1, 3, 5]", s);
}
/*@safe pure */unittest // sprintf issue
{
    double[2] a = [ 1.5, 2.5 ];
    assert(to!string(a) == "[1.5, 2.5]");
}

/*@safe pure */unittest
{
    // Conversion representing associative array with string
    int[string] a = ["0":1, "1":2];
    assert(to!string(a) == `["0":1, "1":2]`);
}

unittest
{
    // Conversion representing class object with string
    class A
    {
        override string toString() const { return "an A"; }
    }
    A a;
    assert(to!string(a) == "null");
    a = new A;
    assert(to!string(a) == "an A");

    // Bug 7660
    class C { override string toString() const { return "C"; } }
    struct S { C c; alias c this; }
    S s; s.c = new C();
    assert(to!string(s) == "C");
}

unittest
{
    // Conversion representing struct object with string
    struct S1
    {
        string toString() { return "wyda"; }
    }
    assert(to!string(S1()) == "wyda");

    struct S2
    {
        int a = 42;
        float b = 43.5;
    }
    S2 s2;
    assert(to!string(s2) == "S2(42, 43.5)");

    // Test for issue 8080
    struct S8080
    {
        short[4] data;
        alias data this;
        string toString() { return "<S>"; }
    }
    S8080 s8080;
    assert(to!string(s8080) == "<S>");
}

/+nothrow+/ unittest
{
    // Conversion representing enum value with string
    enum EB : bool { a = true }
    enum EU : uint { a = 0, b = 1, c = 2 }  // base type is unsigned
    enum EI : int { a = -1, b = 0, c = 1 }  // base type is signed (bug 7909)
    enum EF : real { a = 1.414, b = 1.732, c = 2.236 }
    enum EC : char { a = 'x', b = 'y' }
    enum ES : string { a = "aaa", b = "bbb" }

    foreach (E; TypeTuple!(EB, EU, EI, EF, EC, ES))
    {
        assert(to! string(E.a) == "a"c);
        assert(to!wstring(E.a) == "a"w);
        assert(to!dstring(E.a) == "a"d);
    }

    // Test an value not corresponding to an enum member.
    auto o = cast(EU)5;
    assert(to! string(o) == "cast(EU)5"c);
    assert(to!wstring(o) == "cast(EU)5"w);
    assert(to!dstring(o) == "cast(EU)5"d);
}

unittest
{
    enum E
    {
        foo,
        doo = foo, // check duplicate switch statements
        bar,
    }

    //Test regression 12494
    assert(to!string(E.foo) == "foo");
    assert(to!string(E.doo) == "foo");
    assert(to!string(E.bar) == "bar");

    foreach (S; TypeTuple!(string, wstring, dstring, const(char[]), const(wchar[]), const(dchar[])))
    {
        auto s1 = to!S(E.foo);
        auto s2 = to!S(E.foo);
        assert(s1 == s2);
        // ensure we don't allocate when it's unnecessary
        assert(s1 is s2);
    }

    foreach (S; TypeTuple!(char[], wchar[], dchar[]))
    {
        auto s1 = to!S(E.foo);
        auto s2 = to!S(E.foo);
        assert(s1 == s2);
        // ensure each mutable array is unique
        assert(s1 !is s2);
    }
}

/// ditto
@trusted pure T toImpl(T, S)(S value, uint radix, LetterCase letterCase = LetterCase.upper)
    if (isIntegral!S &&
        isExactSomeString!T)
in
{
    assert(radix >= 2 && radix <= 36);
}
body
{
    alias EEType = Unqual!(ElementEncodingType!T);

    T toStringRadixConvert(size_t bufLen, uint radix = 0, bool neg = false)(uint runtimeRadix = 0)
    {
        static if (neg)
            ulong div = void, mValue = unsigned(-value);
        else
            Unsigned!(Unqual!S) div = void, mValue = unsigned(value);

        size_t index = bufLen;
        EEType[bufLen] buffer = void;
        char baseChar = letterCase == LetterCase.lower ? 'a' : 'A';
        char mod = void;

        do
        {
            static if (radix == 0)
            {
                div = cast(S)(mValue / runtimeRadix );
                mod = cast(ubyte)(mValue % runtimeRadix);
                mod += mod < 10 ? '0' : baseChar - 10;
            }
            else static if (radix > 10)
            {
                div = cast(S)(mValue / radix );
                mod = cast(ubyte)(mValue % radix);
                mod += mod < 10 ? '0' : baseChar - 10;
            }
            else
            {
                div = cast(S)(mValue / radix);
                mod = mValue % radix + '0';
            }
            buffer[--index] = cast(char)mod;
            mValue = div;
        } while (mValue);

        static if (neg)
        {
            buffer[--index] = '-';
        }
        return cast(T)buffer[index .. $].dup;
    }

    switch(radix)
    {
        case 10:
            if (value < 0)
                return toStringRadixConvert!(S.sizeof * 3 + 1, 10, true)();
            else
                return toStringRadixConvert!(S.sizeof * 3, 10)();
        case 16:
            return toStringRadixConvert!(S.sizeof * 2, 16)();
        case 2:
            return toStringRadixConvert!(S.sizeof * 8, 2)();
        case 8:
            return toStringRadixConvert!(S.sizeof * 3, 8)();
        default:
           return toStringRadixConvert!(S.sizeof * 6)(radix);
    }
}

@safe pure nothrow unittest
{
    foreach (Int; TypeTuple!(uint, ulong))
    {
        assert(to!string(Int(16), 16) == "10");
        assert(to!string(Int(15), 2u) == "1111");
        assert(to!string(Int(1), 2u) == "1");
        assert(to!string(Int(0x1234AF), 16u) == "1234AF");
        assert(to!string(Int(0x1234BCD), 16u, LetterCase.upper) == "1234BCD");
        assert(to!string(Int(0x1234AF), 16u, LetterCase.lower) == "1234af");
    }

    foreach (Int; TypeTuple!(int, long))
    {
        assert(to!string(Int(-10), 10u) == "-10");
    }

    assert(to!string(byte(-10), 16) == "F6");
    assert(to!string(long.min) == "-9223372036854775808");
    assert(to!string(long.max) == "9223372036854775807");
}


/**
Narrowing numeric-numeric conversions throw when the value does not
fit in the narrower type.
 */
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        (isNumeric!S || isSomeChar!S || isBoolean!S) &&
        (isNumeric!T || isSomeChar!T || isBoolean!T) && !is(T == enum))
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
    return (ref value)@trusted{ return cast(T) value; }(value);
}

@safe pure unittest
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

unittest
{
    // Narrowing conversions from enum -> integral should be allowed, but they
    // should throw at runtime if the enum value doesn't fit in the target
    // type.
    enum E1 : ulong { A = 1, B = 1UL<<48, C = 0 }
    assert(to!int(E1.A) == 1);
    assert(to!bool(E1.A) == true);
    assertThrown!ConvOverflowException(to!int(E1.B)); // E1.B overflows int
    assertThrown!ConvOverflowException(to!bool(E1.B)); // E1.B overflows bool
    assert(to!bool(E1.C) == false);

    enum E2 : long { A = -1L<<48, B = -1<<31, C = 1<<31 }
    assertThrown!ConvOverflowException(to!int(E2.A)); // E2.A overflows int
    assertThrown!ConvOverflowException(to!uint(E2.B)); // E2.B overflows uint
    assert(to!int(E2.B) == -1<<31); // but does not overflow int
    assert(to!int(E2.C) == 1<<31);  // E2.C does not overflow int

    enum E3 : int { A = -1, B = 1, C = 255, D = 0 }
    assertThrown!ConvOverflowException(to!ubyte(E3.A));
    assertThrown!ConvOverflowException(to!bool(E3.A));
    assert(to!byte(E3.A) == -1);
    assert(to!byte(E3.B) == 1);
    assert(to!ubyte(E3.C) == 255);
    assert(to!bool(E3.B) == true);
    assertThrown!ConvOverflowException(to!byte(E3.C));
    assertThrown!ConvOverflowException(to!bool(E3.C));
    assert(to!bool(E3.D) == false);

}

/**
Array-to-array conversion (except when target is a string type)
converts each element in turn by using $(D to).
 */
T toImpl(T, S)(S value)
    if (!isImplicitlyConvertible!(S, T) &&
        !isSomeString!S && isDynamicArray!S &&
        !isExactSomeString!T && isArray!T)
{
    alias E = typeof(T.init[0]);

    static if (isStaticArray!T)
    {
        auto res = to!(E[])(value);
        enforceEx!ConvException(T.length == res.length,
            format("Length mismatch when converting to static array: %s vs %s", T.length, res.length));
        return res[0 .. T.length];
    }
    else
    {
        auto w = appender!(E[])();
        w.reserve(value.length);
        foreach (i, ref e; value)
        {
            w.put(to!E(e));
        }
        return w.data;
    }
}

@safe pure unittest
{
    // array to array conversions
    uint[] a = ([ 1u, 2, 3 ]).dup;
    auto b = to!(float[])(a);
    assert(b == [ 1.0f, 2, 3 ]);

    //auto c = to!(string[])(b);
    //assert(c[0] == "1" && c[1] == "2" && c[2] == "3");

    immutable(int)[3] d = [ 1, 2, 3 ];
    b = to!(float[])(d);
    assert(b == [ 1.0f, 2, 3 ]);

    uint[][] e = [ a, a ];
    auto f = to!(float[][])(e);
    assert(f[0] == b && f[1] == b);

    // Test for bug 8264
    struct Wrap
    {
        string wrap;
        alias wrap this;
    }
    Wrap[] warr = to!(Wrap[])(["foo", "bar"]);  // should work

    // Issue 12633
    import std.conv : to;
    const s2 = ["10", "20"];

    immutable int[2] a3 = s2.to!(int[2]);
    assert(a3 == [10, 20]);

    // verify length mismatches are caught
    immutable s4 = [1, 2, 3, 4];
    foreach (i; [1, 4])
    {
        auto ex = collectException(s4[0 .. i].to!(int[2]));
            assert(ex && ex.msg == "Length mismatch when converting to static array: 2 vs " ~ [cast(char)(i + '0')],
                ex ? ex.msg : "Exception was not thrown!");
    }
}
/*@safe pure */unittest
{
    auto b = [ 1.0f, 2, 3 ];

    auto c = to!(string[])(b);
    assert(c[0] == "1" && c[1] == "2" && c[2] == "3");
}

/**
Associative array to associative array conversion converts each key
and each value in turn.
 */
T toImpl(T, S)(S value)
    if (isAssociativeArray!S &&
        isAssociativeArray!T && !is(T == enum))
{
    /* This code is potentially unsafe.
     */
    alias K2 = KeyType!T;
    alias V2 = ValueType!T;

    // While we are "building" the AA, we need to unqualify its values, and only re-qualify at the end
    Unqual!V2[K2] result;

    foreach (k1, v1; value)
    {
        // Cast values temporarily to Unqual!V2 to store them to result variable
        result[to!K2(k1)] = cast(Unqual!V2) to!V2(v1);
    }
    // Cast back to original type
    return cast(T)result;
}

@safe /*pure */unittest
{
    // hash to hash conversions
    int[string] a;
    a["0"] = 1;
    a["1"] = 2;
    auto b = to!(double[dstring])(a);
    assert(b["0"d] == 1 && b["1"d] == 2);
}
@safe /*pure */unittest // Bugzilla 8705, from doc
{
    int[string][double[int[]]] a;
    auto b = to!(short[wstring][string[double[]]])(a);
    a = [null:["hello":int.max]];
    assertThrown!ConvOverflowException(to!(short[wstring][string[double[]]])(a));
}
unittest // Extra cases for AA with qualifiers conversion
{
    int[][int[]] a;// = [[], []];
    auto b = to!(immutable(short[])[immutable short[]])(a);

    double[dstring][int[long[]]] c;
    auto d = to!(immutable(short[immutable wstring])[immutable string[double[]]])(c);
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

@safe pure unittest
{
    alias AllInts = TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong);
    alias AllFloats = TypeTuple!(float, double, real);
    alias AllNumerics = TypeTuple!(AllInts, AllFloats);
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
                testFloatingToIntegral!(Floating, Integral)();
            }
        }
    }
    // test conversion integral => floating
    {
        foreach (Integral; AllInts[0 .. $ - 1])
        {
            foreach (Floating; AllFloats)
            {
                testIntegralToFloating!(Integral, Floating)();
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
}
/*@safe pure */unittest
{
    alias AllInts = TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong);
    alias AllFloats = TypeTuple!(float, double, real);
    alias AllNumerics = TypeTuple!(AllInts, AllFloats);
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
    if ( isExactSomeString!S && isDynamicArray!S &&
        !isExactSomeString!T && is(typeof(parse!T(value))))
{
    scope(success)
    {
        if (value.length)
        {
            throw convError!(S, T)(value);
        }
    }
    return parse!T(value);
}

/// ditto
T toImpl(T, S)(S value, uint radix)
    if ( isExactSomeString!S && isDynamicArray!S &&
        !isExactSomeString!T && is(typeof(parse!T(value, radix))))
{
    scope(success)
    {
        if (value.length)
        {
            throw convError!(S, T)(value);
        }
    }
    return parse!T(value, radix);
}

@safe pure unittest
{
    // Issue 6668 - ensure no collaterals thrown
    try { to!uint("-1"); }
    catch (ConvException e) { assert(e.next is null); }
}

@safe pure unittest
{
    foreach (Str; TypeTuple!(string, wstring, dstring))
    {
        Str a = "123";
        assert(to!int(a) == 123);
        assert(to!double(a) == 123);
    }

    // 6255
    auto n = to!int("FF", 16);
    assert(n == 255);
}

/**
Convert a value that is implicitly convertible to the enum base type
into an Enum value. If the value does not match any enum member values
a ConvException is thrown.
Enums with floating-point or string base types are not supported.
*/
T toImpl(T, S)(S value)
    if (is(T == enum) && !is(S == enum)
        && is(typeof(value == OriginalType!T.init))
        && !isFloatingPoint!(OriginalType!T) && !isSomeString!(OriginalType!T))
{
    foreach (Member; EnumMembers!T)
    {
        if (Member == value)
            return Member;
    }

    throw new ConvException(format("Value (%s) does not match any member value of enum '%s'", value, T.stringof));
}

@safe pure unittest
{
    enum En8143 : int { A = 10, B = 20, C = 30, D = 20 }
    enum En8143[][] m3 = to!(En8143[][])([[10, 30], [30, 10]]);
    static assert(m3 == [[En8143.A, En8143.C], [En8143.C, En8143.A]]);

    En8143 en1 = to!En8143(10);
    assert(en1 == En8143.A);
    assertThrown!ConvException(to!En8143(5));   // matches none
    En8143[][] m1 = to!(En8143[][])([[10, 30], [30, 10]]);
    assert(m1 == [[En8143.A, En8143.C], [En8143.C, En8143.A]]);
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
        import std.math : trunc;

        static assert(isFloatingPoint!Source);
        static assert(isIntegral!Target);
        return to!Target(trunc(value + (value < 0 ? -0.5L : 0.5L)));
    }
}

unittest
{
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
 * $(D_PARAM to) family, except that (1) it only works with character ranges
 * as input, (2) takes the input by reference and advances it to
 * the position following the conversion, and (3) does not throw if it
 * could not convert the entire input. It still throws if an overflow
 * occurred during conversion or if no character of the input
 * was meaningfully converted.
 *
 * Example:
 * --------------
 * string test = "123 \t  76.14";
 * auto a = parse!uint(test);
 * assert(a == 123);
 * assert(test == " \t  76.14"); // parse bumps string
 * munch(test, " \t\n\r"); // skip ws
 * assert(test == "76.14");
 * auto b = parse!double(test);
 * assert(b == 76.14);
 * assert(test == "");
 * --------------
 */

Target parse(Target, Source)(ref Source s)
    if (isInputRange!Source &&
        !isExactSomeString!Source &&
        isSomeChar!(ElementType!Source) &&
        is(Unqual!Target == bool))
{
    if (!s.empty)
    {
        auto c1 = std.ascii.toLower(s.front);
        bool result = (c1 == 't');
        if (result || c1 == 'f')
        {
            s.popFront();
            foreach (c; result ? "rue" : "alse")
            {
                if (s.empty || std.ascii.toLower(s.front) != c)
                    goto Lerr;
                s.popFront();
            }
            return result;
        }
    }
Lerr:
    throw parseError("bool should be case-insensitive 'true' or 'false'");
}

unittest
{
    struct InputString
    {
        string _s;
        @property auto front() { return _s.front; }
        @property bool empty() { return _s.empty; }
        void popFront() { _s.popFront(); }
    }

    auto s = InputString("trueFALSETrueFalsetRUEfALSE");
    assert(parse!bool(s) == true);
    assert(s.equal("FALSETrueFalsetRUEfALSE"));
    assert(parse!bool(s) == false);
    assert(s.equal("TrueFalsetRUEfALSE"));
    assert(parse!bool(s) == true);
    assert(s.equal("FalsetRUEfALSE"));
    assert(parse!bool(s) == false);
    assert(s.equal("tRUEfALSE"));
    assert(parse!bool(s) == true);
    assert(s.equal("fALSE"));
    assert(parse!bool(s) == false);
    assert(s.empty);

    foreach (ss; ["tfalse", "ftrue", "t", "f", "tru", "fals", ""])
    {
        s = InputString(ss);
        assertThrown!ConvException(parse!bool(s));
    }
}

Target parse(Target, Source)(ref Source s)
    if (isSomeChar!(ElementType!Source) &&
        isIntegral!Target && !is(Target == enum))
{
    static if (Target.sizeof < int.sizeof)
    {
        // smaller types are handled like integers
        auto v = .parse!(Select!(Target.min < 0, int, uint))(s);
        auto result = ()@trusted{ return cast(Target) v; }();
        if (result == v)
            return result;
        throw new ConvOverflowException("Overflow in integral conversion");
    }
    else
    {
        // Larger than int types

        static if (Target.min < 0)
            bool sign = 0;
        else
            enum bool sign = 0;

        enum char maxLastDigit = Target.min < 0 ? 7 : 5;
        Unqual!(typeof(s.front)) c;

        if (s.empty)
            goto Lerr;

        c = s.front;
        s.popFront();
        static if (Target.min < 0)
        {
            switch (c)
            {
                case '-':
                    sign = true;
                    goto case '+';
                case '+':
                    if (s.empty)
                        goto Lerr;
                    c = s.front;
                    s.popFront();
                    break;

                default:
                    break;
            }
        }
        c -= '0';
        if (c <= 9)
        {
            Target v = cast(Target)c;
            while (!s.empty)
            {
                c = s.front - '0';
                if (c > 9)
                    break;

                if (v < Target.max/10 ||
                    (v == Target.max/10 && c <= maxLastDigit + sign))
                {
                    v = cast(Target) (v * 10 + c);
                    s.popFront();
                }
                else
                    throw new ConvOverflowException("Overflow in integral conversion");
            }

            if (sign)
                v = -v;
            return v;
        }
Lerr:
        throw convError!(Source, Target)(s);
    }
}

@safe pure unittest
{
    string s = "123";
    auto a = parse!int(s);
}

@safe pure unittest
{
    foreach (Int; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
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

@safe pure unittest
{
    // parsing error check
    foreach (Int; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
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
                "-+1",
                "--1",
                "+-1",
                "++1",
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

@safe pure unittest
{
    assertCTFEable!({ string s =  "1234abc"; assert(parse! int(s) ==  1234 && s == "abc"); });
    assertCTFEable!({ string s = "-1234abc"; assert(parse! int(s) == -1234 && s == "abc"); });
    assertCTFEable!({ string s =  "1234abc"; assert(parse!uint(s) ==  1234 && s == "abc"); });
}

/// ditto
Target parse(Target, Source)(ref Source s, uint radix)
    if (isSomeChar!(ElementType!Source) &&
        isIntegral!Target && !is(Target == enum))
in
{
    assert(radix >= 2 && radix <= 36);
}
body
{
    if (radix == 10)
        return parse!Target(s);

    immutable uint beyond = (radix < 10 ? '0' : 'a'-10) + radix;

    Target v = 0;
    size_t atStart = true;

    for (; !s.empty; s.popFront())
    {
        uint c = s.front;
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
        atStart = false;
    }
    if (atStart)
        goto Lerr;
    return v;

Loverflow:
    throw new ConvOverflowException("Overflow in integral conversion");
Lerr:
    throw convError!(Source, Target)(s, radix);
}

@safe pure unittest
{
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

@safe pure unittest // bugzilla 7302
{
    auto r = cycle("2A!");
    auto u = parse!uint(r, 16);
    assert(u == 42);
    assert(r.front == '!');
}

Target parse(Target, Source)(ref Source s)
    if (isExactSomeString!Source &&
        is(Target == enum))
{
    Target result;
    size_t longest_match = 0;

    foreach (i, e; EnumMembers!Target)
    {
        auto ident = __traits(allMembers, Target)[i];
        if (longest_match < ident.length && s.startsWith(ident))
        {
            result = e;
            longest_match = ident.length ;
        }
    }

    if (longest_match > 0)
    {
        s = s[longest_match .. $];
        return result ;
    }

    throw new ConvException(
        Target.stringof ~ " does not have a member named '"
        ~ to!string(s) ~ "'");
}

unittest
{
    enum EB : bool { a = true, b = false, c = a }
    enum EU { a, b, c }
    enum EI { a = -1, b = 0, c = 1 }
    enum EF : real { a = 1.414, b = 1.732, c = 2.236 }
    enum EC : char { a = 'a', b = 'b', c = 'c' }
    enum ES : string { a = "aaa", b = "bbb", c = "ccc" }

    foreach (E; TypeTuple!(EB, EU, EI, EF, EC, ES))
    {
        assert(to!E("a"c) == E.a);
        assert(to!E("b"w) == E.b);
        assert(to!E("c"d) == E.c);

        assertThrown!ConvException(to!E("d"));
    }
}

@safe pure unittest // bugzilla 4744
{
    enum A { member1, member11, member111 }
    assert(to!A("member1"  ) == A.member1  );
    assert(to!A("member11" ) == A.member11 );
    assert(to!A("member111") == A.member111);
    auto s = "member1111";
    assert(parse!A(s) == A.member111 && s == "1");
}

Target parse(Target, Source)(ref Source p)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) && !is(Source == enum) &&
        isFloatingPoint!Target && !is(Target == enum))
{
    static import core.stdc.math/* : HUGE_VAL*/;

    static immutable real[14] negtab =
        [ 1e-4096L,1e-2048L,1e-1024L,1e-512L,1e-256L,1e-128L,1e-64L,1e-32L,
                1e-16L,1e-8L,1e-4L,1e-2L,1e-1L,1.0L ];
    static immutable real[13] postab =
        [ 1e+4096L,1e+2048L,1e+1024L,1e+512L,1e+256L,1e+128L,1e+64L,1e+32L,
                1e+16L,1e+8L,1e+4L,1e+2L,1e+1L ];
    // static immutable string infinity = "infinity";
    // static immutable string nans = "nans";

    ConvException bailOut()(string msg = null, string fn = __FILE__, size_t ln = __LINE__)
    {
        if (!msg)
            msg = "Floating point conversion error";
        return new ConvException(text(msg, " for input \"", p, "\"."), fn, ln);
    }

    enforce(!p.empty, bailOut());

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
        if (std.ascii.toLower(p.front) == 'n')
        {
            p.popFront();
            enforce(!p.empty, bailOut());
            if (std.ascii.toLower(p.front) == 'f')
            {
                // 'inf'
                p.popFront();
                return sign ? -Target.infinity : Target.infinity;
            }
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
            return (sign) ? -0.0 : 0.0;
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
            {
                p.popFront();
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
            {
                msdec = 0x8000000000000000L;
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
            {
                case '-':    sexp++;
                             goto case;
                case '+':    p.popFront(); enforce(!p.empty,
                                new ConvException("Error converting input"~
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
        enforce(ndigits, new ConvException("Error converting input"~
                        " to floating point"));

        static if (real.mant_dig == 64)
        {
            if (msdec)
            {
                int e2 = 0x3FFF + 63;

                // left justify mantissa
                while (msdec >= 0)
                {
                    msdec <<= 1;
                    e2--;
                }

                // Stuff mantissa directly into real
                ()@trusted{ *cast(long*)&ldval = msdec; }();
                ()@trusted{ (cast(ushort*)&ldval)[4] = cast(ushort) e2; }();

                import std.math : ldexp;

                // Exponent is power of 2, not power of 10
                ldval = ldexp(ldval,exp);
            }
        }
        else static if (real.mant_dig == 53)
        {
            if (msdec)
            {
                //Exponent bias + 52:
                //After shifting 52 times left, exp must be 1
                int e2 = 0x3FF + 52;

                // right justify mantissa
                // first 11 bits must be zero, rest is implied bit + mantissa
                // shift one time less, do rounding, shift again
                while ((msdec & 0xFFC0_0000_0000_0000) != 0)
                {
                    msdec  = ((cast(ulong)msdec) >> 1);
                    e2++;
                }

                //Have to shift one more time
                //and do rounding
                if((msdec & 0xFFE0_0000_0000_0000) != 0)
                {
                    auto roundUp = (msdec & 0x1);

                    msdec  = ((cast(ulong)msdec) >> 1);
                    e2++;
                    if(roundUp)
                    {
                        msdec += 1;
                        //If mantissa was 0b1111... and we added +1
                        //the mantissa should be 0b10000 (think of implicit bit)
                        //and the exponent increased
                        if((msdec & 0x0020_0000_0000_0000) != 0)
                        {
                            msdec = 0x0010_0000_0000_0000;
                            e2++;
                        }
                    }
                }


                // left justify mantissa
                // bit 11 must be 1
                while ((msdec & 0x0010_0000_0000_0000) == 0)
                {
                    msdec <<= 1;
                    e2--;
                }

                // Stuff mantissa directly into double
                // (first including implicit bit)
                ()@trusted{ *cast(long *)&ldval = msdec; }();
                //Store exponent, now overwriting implicit bit
                ()@trusted{ *cast(long *)&ldval &= 0x000F_FFFF_FFFF_FFFF; }();
                ()@trusted{ *cast(long *)&ldval |= ((e2 & 0xFFFUL) << 52); }();

                import std.math : ldexp;

                // Exponent is power of 2, not power of 10
                ldval = ldexp(ldval,exp);
            }
        }
        else
            static assert(false, "Floating point format of real type not supported");

        goto L6;
    }
    else // not hex
    {
        if (std.ascii.toUpper(p.front) == 'N' && !startsWithZero)
        {
            // nan
            p.popFront();
            enforce(!p.empty && std.ascii.toUpper(p.front) == 'A',
                   new ConvException("error converting input to floating point"));
            p.popFront();
            enforce(!p.empty && std.ascii.toUpper(p.front) == 'N',
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
                {
                    lsdec = lsdec * 10 + (i - '0');
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
        {
            case '-':    sexp++;
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
    import std.math : isnan, fabs;

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
        assert(to!Float("123") == Literal!Float(123));
        assert(to!Float("+123") == Literal!Float(+123));
        assert(to!Float("-123") == Literal!Float(-123));
        assert(to!Float("123e2") == Literal!Float(123e2));
        assert(to!Float("123e+2") == Literal!Float(123e+2));
        assert(to!Float("123e-2") == Literal!Float(123e-2));
        assert(to!Float("123.") == Literal!Float(123.0));
        assert(to!Float(".375") == Literal!Float(.375));

        assert(to!Float("1.23375E+2") == Literal!Float(1.23375E+2));

        assert(to!Float("0") is 0.0);
        assert(to!Float("-0") is -0.0);

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

//Tests for the double implementation
unittest
{
    import core.stdc.stdlib, std.math;
    static if(real.mant_dig == 53)
    {
        //Should be parsed exactly: 53 bit mantissa
        string s = "0x1A_BCDE_F012_3456p10";
        auto x = parse!real(s);
        assert(x == 0x1A_BCDE_F012_3456p10L);
        //1 bit is implicit
        assert(((*cast(ulong*)&x) & 0x000F_FFFF_FFFF_FFFF) == 0xA_BCDE_F012_3456);
        assert(strtod("0x1ABCDEF0123456p10", null) == x);

        //Should be parsed exactly: 10 bit mantissa
        s = "0x3FFp10";
        x = parse!real(s);
        assert(x == 0x03FFp10);
        //1 bit is implicit
        assert(((*cast(ulong*)&x) & 0x000F_FFFF_FFFF_FFFF) == 0x000F_F800_0000_0000);
        assert(strtod("0x3FFp10", null) == x);

        //60 bit mantissa, round up
        s = "0xFFF_FFFF_FFFF_FFFFp10";
        x = parse!real(s);
        assert(approxEqual(x, 0xFFF_FFFF_FFFF_FFFFp10));
        //1 bit is implicit
        assert(((*cast(ulong*)&x) & 0x000F_FFFF_FFFF_FFFF) == 0x0000_0000_0000_0000);
        assert(strtod("0xFFFFFFFFFFFFFFFp10", null) == x);

        //60 bit mantissa, round down
        s = "0xFFF_FFFF_FFFF_FF90p10";
        x = parse!real(s);
        assert(approxEqual(x, 0xFFF_FFFF_FFFF_FF90p10));
        //1 bit is implicit
        assert(((*cast(ulong*)&x) & 0x000F_FFFF_FFFF_FFFF) == 0x000F_FFFF_FFFF_FFFF);
        assert(strtod("0xFFFFFFFFFFFFF90p10", null) == x);

        //61 bit mantissa, round up 2
        s = "0x1F0F_FFFF_FFFF_FFFFp10";
        x = parse!real(s);
        assert(approxEqual(x, 0x1F0F_FFFF_FFFF_FFFFp10));
        //1 bit is implicit
        assert(((*cast(ulong*)&x) & 0x000F_FFFF_FFFF_FFFF) == 0x000F_1000_0000_0000);
        assert(strtod("0x1F0FFFFFFFFFFFFFp10", null) == x);

        //61 bit mantissa, round down 2
        s = "0x1F0F_FFFF_FFFF_FF10p10";
        x = parse!real(s);
        assert(approxEqual(x, 0x1F0F_FFFF_FFFF_FF10p10));
        //1 bit is implicit
        assert(((*cast(ulong*)&x) & 0x000F_FFFF_FFFF_FFFF) == 0x000F_0FFF_FFFF_FFFF);
        assert(strtod("0x1F0FFFFFFFFFFF10p10", null) == x);

        //Huge exponent
        s = "0x1F_FFFF_FFFF_FFFFp900";
        x = parse!real(s);
        assert(strtod("0x1FFFFFFFFFFFFFp900", null) == x);

        //exponent too big -> converror
        s = "";
        assertThrown!ConvException(x = parse!real(s));
        assert(strtod("0x1FFFFFFFFFFFFFp1024", null) == real.infinity);

        //-exponent too big -> 0
        s = "0x1FFFFFFFFFFFFFp-2000";
        x = parse!real(s);
        assert(x == 0);
        assert(strtod("0x1FFFFFFFFFFFFFp-2000", null) == x);
    }
}

unittest
{
    import core.stdc.errno;
    import core.stdc.stdlib;

    errno = 0;  // In case it was set by another unittest in a different module.
    struct longdouble
    {
        static if(real.mant_dig == 64)
        {
            ushort value[5];
        }
        else static if(real.mant_dig == 53)
        {
            ushort value[4];
        }
        else
            static assert(false, "Not implemented");
    }

    real ld;
    longdouble x;
    real ld1;
    longdouble x1;
    int i;

    static if(real.mant_dig == 64)
        enum s = "0x1.FFFFFFFFFFFFFFFEp-16382";
    else static if(real.mant_dig == 53)
        enum s = "0x1.FFFFFFFFFFFFFFFEp-1000";
    else
        static assert(false, "Floating point format for real not supported");

    auto s2 = s.idup;
    ld = parse!real(s2);
    assert(s2.empty);
    x = *cast(longdouble *)&ld;
    version (Win64)
        ld1 = 0x1.FFFFFFFFFFFFFFFEp-16382L; // strtold currently mapped to strtod
    else
        ld1 = strtold(s.ptr, null);
    x1 = *cast(longdouble *)&ld1;
    assert(x1 == x && ld1 == ld);

    // for (i = 4; i >= 0; i--)
    // {
    //     printf("%04x ", x.value[i]);
    // }
    // printf("\n");
    assert(!errno);

    s2 = "1.0e5";
    ld = parse!real(s2);
    assert(s2.empty);
    x = *cast(longdouble *)&ld;
    ld1 = strtold("1.0e5", null);
    x1 = *cast(longdouble *)&ld1;

    // for (i = 4; i >= 0; i--)
    // {
    //     printf("%04x ", x.value[i]);
    // }
    // printf("\n");
}

@safe pure unittest
{
    // Bugzilla 4959
    {
        auto s = "0 ";
        auto x = parse!double(s);
        assert(s == " ");
        assert(x == 0.0);
    }

    // Bugzilla 3369
    assert(to!float("inf") == float.infinity);
    assert(to!float("-inf") == -float.infinity);

    // Bugzilla 6160
    assert(6_5.536e3L == to!real("6_5.536e3"));                     // 2^16
    assert(0x1000_000_000_p10 == to!real("0x1000_000_000_p10"));    // 7.03687e+13

    // Bugzilla 6258
    assertThrown!ConvException(to!real("-"));
    assertThrown!ConvException(to!real("in"));

    // Bugzilla 7055
    assertThrown!ConvException(to!float("INF2"));

    //extra stress testing
    auto ssOK    = ["1.", "1.1.1", "1.e5", "2e1e", "2a", "2e1_1",
                    "inf", "-inf", "infa", "-infa", "inf2e2", "-inf2e2"];
    auto ssKO    = ["", " ", "2e", "2e+", "2e-", "2ee", "2e++1", "2e--1", "2e_1", "+inf"];
    foreach (s; ssOK)
        parse!double(s);
    foreach (s; ssKO)
        assertThrown!ConvException(parse!double(s));
}

/**
Parsing one character off a string returns the character and bumps the
string up one position.
 */
Target parse(Target, Source)(ref Source s)
    if (isExactSomeString!Source &&
        staticIndexOf!(Unqual!Target, dchar, Unqual!(ElementEncodingType!Source)) >= 0)
{
    if (s.empty)
        throw convError!(Source, Target)(s);
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

@safe pure unittest
{
    foreach (Str; TypeTuple!(string, wstring, dstring))
    {
        foreach (Char; TypeTuple!(char, wchar, dchar))
        {
            static if (is(Unqual!Char == dchar) ||
                       Char.sizeof == ElementEncodingType!Str.sizeof)
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
        isSomeChar!Target && Target.sizeof >= ElementType!Source.sizeof && !is(Target == enum))
{
    if (s.empty)
        throw convError!(Source, Target)(s);
    Target result = s.front;
    s.popFront();
    return result;
}

// string to bool conversions
Target parse(Target, Source)(ref Source s)
    if (isExactSomeString!Source &&
        is(Unqual!Target == bool))
{
    if (s.length >= 4 && icmp(s[0 .. 4], "true") == 0)
    {
        s = s[4 .. $];
        return true;
    }
    if (s.length >= 5 && icmp(s[0 .. 5], "false") == 0)
    {
        s = s[5 .. $];
        return false;
    }
    throw parseError("bool should be case-insensitive 'true' or 'false'");
}

/*
    Tests for to!bool and parse!bool
*/
@safe pure unittest
{
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

// string to null literal conversions
Target parse(Target, Source)(ref Source s)
    if (isExactSomeString!Source &&
        is(Unqual!Target == typeof(null)))
{
    if (s.length >= 4 && icmp(s[0 .. 4], "null") == 0)
    {
        s = s[4 .. $];
        return null;
    }
    throw parseError("null should be case-insensitive 'null'");
}

@safe pure unittest
{
    alias NullType = typeof(null);
    auto s1 = "null";
    assert(parse!NullType(s1) is null);
    assert(s1 == "");

    auto s2 = "NUll"d;
    assert(parse!NullType(s2) is null);
    assert(s2 == "");

    auto m = "maybe";
    assertThrown!ConvException(parse!NullType(m));
    assert(m == "maybe");  // m shouldn't change on failure

    auto s = "NULL";
    assert(parse!(const NullType)(s) is null);
}

//Used internally by parse Array/AA, to remove ascii whites
package void skipWS(R)(ref R r)
{
    static if (isSomeString!R)
    {
        //Implementation inspired from stripLeft.
        foreach (i, dchar c; r)
        {
            if (!std.ascii.isWhite(c))
            {
                r = r[i .. $];
                return;
            }
        }
        r = r[0 .. 0]; //Empty string with correct type.
        return;
    }
    else
    {
        for (; !r.empty && std.ascii.isWhite(r.front); r.popFront())
        {}
    }
}

/**
 * Parses an array from a string given the left bracket (default $(D
 * '[')), right bracket (default $(D ']')), and element separator (by
 * default $(D ',')).
 */
Target parse(Target, Source)(ref Source s, dchar lbracket = '[', dchar rbracket = ']', dchar comma = ',')
    if (isExactSomeString!Source &&
        isDynamicArray!Target && !is(Target == enum))
{
    Target result;

    parseCheck!s(lbracket);
    skipWS(s);
    if (s.empty)
        throw convError!(Source, Target)(s);
    if (s.front == rbracket)
    {
        s.popFront();
        return result;
    }
    for (;; s.popFront(), skipWS(s))
    {
        result ~= parseElement!(ElementType!Target)(s);
        skipWS(s);
        if (s.empty)
            throw convError!(Source, Target)(s);
        if (s.front != comma)
            break;
    }
    parseCheck!s(rbracket);

    return result;
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

@safe pure unittest
{
    auto s1 = `[['h', 'e', 'l', 'l', 'o'], "world"]`;
    auto a1 = parse!(string[])(s1);
    assert(a1 == ["hello", "world"]);

    auto s2 = `["aaa", "bbb", "ccc"]`;
    auto a2 = parse!(string[])(s2);
    assert(a2 == ["aaa", "bbb", "ccc"]);
}

@safe pure unittest
{
    //Check proper failure
    auto s = "[ 1 , 2 , 3 ]";
    foreach (i ; 0..s.length-1)
    {
        auto ss = s[0 .. i];
        assertThrown!ConvException(parse!(int[])(ss));
    }
    int[] arr = parse!(int[])(s);
}

@safe pure unittest
{
    //Checks parsing of strings with escaped characters
    string s1 = `[
        "Contains a\0null!",
        "tab\there",
        "line\nbreak",
        "backslash \\ slash / question \?",
        "number \x35 five",
        "unicode \u65E5 sun",
        "very long \U000065E5 sun"
    ]`;

    //Note: escaped characters purposefully replaced and isolated to guarantee
    //there are no typos in the escape syntax
    string[] s2 = [
        "Contains a" ~ '\0' ~ "null!",
        "tab" ~ '\t' ~ "here",
        "line" ~ '\n' ~ "break",
        "backslash " ~ '\\' ~ " slash / question ?",
        "number 5 five",
        "unicode 日 sun",
        "very long 日 sun"
    ];
    assert(s2 == parse!(string[])(s1));
    assert(s1.empty);
}

/// ditto
Target parse(Target, Source)(ref Source s, dchar lbracket = '[', dchar rbracket = ']', dchar comma = ',')
    if (isExactSomeString!Source &&
        isStaticArray!Target && !is(Target == enum))
{
    static if (hasIndirections!Target)
        Target result = Target.init[0].init;
    else
        Target result = void;

    parseCheck!s(lbracket);
    skipWS(s);
    if (s.empty)
        throw convError!(Source, Target)(s);
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
        if (s.empty)
            throw convError!(Source, Target)(s);
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
    throw parseError(text("Too many elements in input, ", result.length, " elements expected."));

Lfewerr:
    throw parseError(text("Too few elements in input, ", result.length, " elements expected."));
}

@safe pure unittest
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
    if (isExactSomeString!Source &&
        isAssociativeArray!Target && !is(Target == enum))
{
    alias KeyType = typeof(Target.init.keys[0]);
    alias ValType = typeof(Target.init.values[0]);

    Target result;

    parseCheck!s(lbracket);
    skipWS(s);
    if (s.empty)
        throw convError!(Source, Target)(s);
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
        auto val = parseElement!ValType(s);
        skipWS(s);
        result[key] = val;
        if (s.empty)
            throw convError!(Source, Target)(s);
        if (s.front != comma)
            break;
    }
    parseCheck!s(rbracket);

    return result;
}

@safe pure unittest
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

@safe pure unittest
{
    //Check proper failure
    auto s = "[1:10, 2:20, 3:30]";
    foreach (i ; 0 .. s.length-1)
    {
        auto ss = s[0 .. i];
        assertThrown!ConvException(parse!(int[int])(ss));
    }
    int[int] aa = parse!(int[int])(s);
}

private dchar parseEscape(Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source))
{
    parseCheck!s('\\');
    if (s.empty)
        throw parseError("Unterminated escape sequence");

    dchar getHexDigit()(ref Source s_ = s)  // workaround
    {
        if (s_.empty)
            throw parseError("Unterminated escape sequence");
        s_.popFront();
        if (s_.empty)
            throw parseError("Unterminated escape sequence");
        dchar c = s_.front;
        if (!isHexDigit(c))
            throw parseError("Hex digit is missing");
        return std.ascii.isAlpha(c) ? ((c & ~0x20) - ('A' - 10)) : c - '0';
    }

    dchar result;

    switch (s.front)
    {
        case '"':   result = '\"';  break;
        case '\'':  result = '\'';  break;
        case '0':   result = '\0';  break;
        case '?':   result = '\?';  break;
        case '\\':  result = '\\';  break;
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
            throw parseError("Unknown escape character " ~ to!string(s.front));
    }
    if (s.empty)
        throw parseError("Unterminated escape sequence");

    s.popFront();

    return result;
}

@safe pure unittest
{
    string[] s1 = [
        `\"`, `\'`, `\?`, `\\`, `\a`, `\b`, `\f`, `\n`, `\r`, `\t`, `\v`, //Normal escapes
        //`\141`, //@@@9621@@@ Octal escapes.
        `\x61`,
        `\u65E5`, `\U00012456`
        //`\&amp;`, `\&quot;`, //@@@9621@@@ Named Character Entities.
    ];

    const(dchar)[] s2 = [
        '\"', '\'', '\?', '\\', '\a', '\b', '\f', '\n', '\r', '\t', '\v', //Normal escapes
        //'\141', //@@@9621@@@ Octal escapes.
        '\x61',
        '\u65E5', '\U00012456'
        //'\&amp;', '\&quot;', //@@@9621@@@ Named Character Entities.
    ];

    foreach (i ; 0 .. s1.length)
    {
        assert(s2[i] == parseEscape(s1[i]));
        assert(s1[i].empty);
    }
}

@safe pure unittest
{
    string[] ss = [
        `hello!`,  //Not an escape
        `\`,       //Premature termination
        `\/`,      //Not an escape
        `\gggg`,   //Not an escape
        `\xzz`,    //Not an hex
        `\x0`,     //Premature hex end
        `\XB9`,    //Not legal hex syntax
        `\u!!`,    //Not a unicode hex
        `\777`,    //Octal is larger than a byte //Note: Throws, but simply because octals are unsupported
        `\u123`,   //Premature hex end
        `\U123123` //Premature hex end
    ];
    foreach (s ; ss)
        assertThrown!ConvException(parseEscape(s));
}

// Undocumented
Target parseElement(Target, Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) && !is(Source == enum) &&
        isExactSomeString!Target)
{
    auto result = appender!Target();

    // parse array of chars
    if (s.empty)
        throw convError!(Source, Target)(s);
    if (s.front == '[')
        return parse!Target(s);

    parseCheck!s('\"');
    if (s.empty)
        throw convError!(Source, Target)(s);
    if (s.front == '\"')
    {
        s.popFront();
        return result.data;
    }
    while (true)
    {
        if (s.empty)
            throw parseError("Unterminated quoted string");
        switch (s.front)
        {
            case '\"':
                s.popFront();
                return result.data;
            case '\\':
                result.put(parseEscape(s));
                break;
            default:
                result.put(s.front);
                s.popFront();
                break;
        }
    }
    assert(0);
}

// ditto
Target parseElement(Target, Source)(ref Source s)
    if (isInputRange!Source && isSomeChar!(ElementType!Source) && !is(Source == enum) &&
        isSomeChar!Target && !is(Target == enum))
{
    Target c;

    parseCheck!s('\'');
    if (s.empty)
        throw convError!(Source, Target)(s);
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
 * Convenience functions for converting any number and types of
 * arguments into _text (the three character widths).
 */
string text(T...)(T args) { return textImpl!string(args); }
///ditto
wstring wtext(T...)(T args) { return textImpl!wstring(args); }
///ditto
dstring dtext(T...)(T args) { return textImpl!dstring(args); }

private S textImpl(S, U...)(U args)
{
    static if (U.length == 0)
    {
        return null;
    }
    else
    {
        auto result = to!S(args[0]);
        foreach (arg; args[1 .. $])
            result ~= to!S(arg);
        return result;
    }
}
///
unittest
{
    assert( text(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"c);
    assert(wtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"w);
    assert(dtext(42, ' ', 1.5, ": xyz") == "42 1.5: xyz"d);
}
unittest
{
    assert(text() is null);
    assert(wtext() is null);
    assert(dtext() is null);
}


/***************************************************************
The $(D octal) facility is intended as an experimental facility to
replace _octal literals starting with $(D '0'), which many find
confusing. Using $(D octal!177) or $(D octal!"177") instead of $(D
0177) as an _octal literal makes code clearer and the intent more
visible. If use of this facility becomes predominant, a future
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
@property int octal(string num)()
    if((octalFitsInInt!(num) && !literalIsLong!(num)) && !literalIsUnsigned!(num))
{
    return octal!(int, num);
}

/// Ditto
@property long octal(string num)()
    if((!octalFitsInInt!(num) || literalIsLong!(num)) && !literalIsUnsigned!(num))
{
    return octal!(long, num);
}

/// Ditto
@property uint octal(string num)()
    if((octalFitsInInt!(num) && !literalIsLong!(num)) && literalIsUnsigned!(num))
{
    return octal!(int, num);
}

/// Ditto
@property ulong octal(string num)()
    if((!octalFitsInInt!(num) || literalIsLong!(num)) && literalIsUnsigned!(num))
{
    return octal!(long, num);
}

/// Ditto
template octal(alias s)
    if (isIntegral!(typeof(s)))
{
    enum auto octal = octal!(typeof(s), to!string(s));
}

/*
    Takes a string, num, which is an octal literal, and returns its
    value, in the type T specified.

    So:

    int a = octal!(int, "10");

    assert(a == 8);
*/
@property T octal(T, string num)()
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

/+
emplaceRef is a package function for phobos internal use. It works like
emplace, but takes its argument by ref (as opposed to "by pointer").

This makes it easier to use, easier to be safe, and faster in a non-inline
build.

Furthermore, emplaceRef takes a type paremeter, which specifies the type we
want to build. This helps to build qualified objects on mutable buffer,
without breaking the type system with unsafe casts.
+/
package template emplaceRef(T)
{
    alias UT = Unqual!T;

    ref UT emplaceRef()(ref UT chunk)
    {
        static assert (is(typeof({static T i;})),
            format("Cannot emplace a %1$s because %1$s.this() is annotated with @disable.", T.stringof));

        return emplaceInitializer(chunk);
    }

    static if (!is(T == struct))
    ref UT emplaceRef(Arg)(ref UT chunk, auto ref Arg arg)
    {
        static assert(is(typeof({T t = arg;})),
            format("%s cannot be emplaced from a %s.", T.stringof, Arg.stringof));

        static if (isStaticArray!T)
        {
            alias UArg = Unqual!Arg;
            alias E = ElementEncodingType!(typeof(T.init[]));
            alias UE = Unqual!E;
            enum N = T.length;

            static if (is(Arg : T))
            {
                //Matching static array
                static if (!hasElaborateAssign!UT && isAssignable!(UT, Arg))
                    chunk = arg;
                else static if (is(UArg == UT))
                {
                    memcpy(&chunk, &arg, T.sizeof);
                    static if (hasElaborateCopyConstructor!T)
                        typeid(T).postblit(cast(void*)&chunk);
                }
                else
                    .emplaceRef!T(chunk, cast(T)arg);
            }
            else static if (is(Arg : E[]))
            {
                //Matching dynamic array
                static if (!hasElaborateAssign!UT && is(typeof(chunk[] = arg[])))
                    chunk[] = arg[];
                else static if (is(Unqual!(ElementEncodingType!Arg) == UE))
                {
                    assert(N == chunk.length, "Array length missmatch in emplace");
                    memcpy(cast(void*)&chunk, arg.ptr, T.sizeof);
                    static if (hasElaborateCopyConstructor!T)
                        typeid(T).postblit(cast(void*)&chunk);
                }
                else
                    .emplaceRef!T(chunk, cast(E[])arg);
            }
            else static if (is(Arg : E))
            {
                //Case matching single element to array.
                static if (!hasElaborateAssign!UT && is(typeof(chunk[] = arg)))
                    chunk[] = arg;
                else static if (is(UArg == Unqual!E))
                {
                    //Note: We copy everything, and then postblit just once.
                    //This is as exception safe as what druntime can provide us.
                    foreach(i; 0 .. N)
                        memcpy(cast(void*)&(chunk[i]), &arg, E.sizeof);
                    static if (hasElaborateCopyConstructor!T)
                        typeid(T).postblit(cast(void*)&chunk);
                }
                else
                    //Alias this. Coerce.
                    .emplaceRef!T(chunk, cast(E)arg);
            }
            else static if (is(typeof(.emplaceRef!E(chunk[0], arg))))
            {
                //Final case for everything else:
                //Types that don't match (int to uint[2])
                //Recursion for multidimensions
                static if (!hasElaborateAssign!UT && is(typeof(chunk[] = arg)))
                    chunk[] = arg;
                else
                    foreach(i; 0 .. N)
                        .emplaceRef!E(chunk[i], arg);
            }
            else
                static assert(0, format("Sorry, this implementation doesn't know how to emplace a %s with a %s", T.stringof, Arg.stringof));

            return chunk;
        }
        else
        {
            chunk = arg;
            return chunk;
        }
    }
    // ditto
    static if (is(T == struct))
    ref UT emplaceRef(Args...)(ref UT chunk, auto ref Args args)
    {
        static if (Args.length == 1 && is(Args[0] : T) &&
            is (typeof({T t = args[0];})) //Check for legal postblit
            )
        {
            static if (is(Unqual!T == Unqual!(Args[0])))
            {
                //Types match exactly: we postblit
                static if (!hasElaborateAssign!UT && isAssignable!(UT, T))
                    chunk = args[0];
                else
                {
                    memcpy(&chunk, &args[0], T.sizeof);
                    static if (hasElaborateCopyConstructor!T)
                        typeid(T).postblit(&chunk);
                }
            }
            else
                //Alias this. Coerce to type T.
                .emplaceRef!T(chunk, cast(T)args[0]);
        }
        else static if (is(typeof(chunk.__ctor(args))))
        {
            // T defines a genuine constructor accepting args
            // Go the classic route: write .init first, then call ctor
            emplaceInitializer(chunk);
            chunk.__ctor(args);
        }
        else static if (is(typeof(T.opCall(args))))
        {
            //Can be built calling opCall
            emplaceOpCaller(chunk, args); //emplaceOpCaller is deprecated
        }
        else static if (is(typeof(T(args))))
        {
            // Struct without constructor that has one matching field for
            // each argument. Individually emplace each field
            emplaceInitializer(chunk);
            foreach (i, ref field; chunk.tupleof[0 .. Args.length])
            {
                alias Field = typeof(field);
                alias UField = Unqual!Field;
                static if (is(Field == UField))
                    .emplaceRef!Field(field, args[i]);
                else
                    .emplaceRef!Field(*cast(Unqual!Field*)&field, args[i]);
            }
        }
        else
        {
            //We can't emplace. Try to diagnose a disabled postblit.
            static assert(!(Args.length == 1 && is(Args[0] : T)),
                format("Cannot emplace a %1$s because %1$s.this(this) is annotated with @disable.", T.stringof));

            //We can't emplace.
            static assert(false,
                format("%s cannot be emplaced from %s.", T.stringof, Args[].stringof));
        }

        return chunk;
    }
}
//emplace helper functions
private ref T emplaceInitializer(T)(ref T chunk) @trusted pure nothrow
{
    static if (!hasElaborateAssign!T && isAssignable!T)
        chunk = T.init;
    else
    {
        static immutable T init = T.init;
        memcpy(&chunk, &init, T.sizeof);
    }
    return chunk;
}
private deprecated("Using static opCall for emplace is deprecated. Plase use emplace(chunk, T(args)) instead.")
ref T emplaceOpCaller(T, Args...)(ref T chunk, auto ref Args args)
{
    static assert (is(typeof({T t = T.opCall(args);})),
        format("%s.opCall does not return adequate data for construction.", T.stringof));
    return emplaceRef!T(chunk, chunk.opCall(args));
}


// emplace
/**
Given a pointer $(D chunk) to uninitialized memory (but already typed
as $(D T)), constructs an object of non-$(D class) type $(D T) at that
address.

Returns: A pointer to the newly constructed object (which is the same
as $(D chunk)).
 */
T* emplace(T)(T* chunk) @safe pure nothrow
{
    emplaceRef!T(*chunk);
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
T* emplace(T, Args...)(T* chunk, auto ref Args args)
if (!is(T == struct) && Args.length == 1)
{
    emplaceRef!T(*chunk, args);
    return chunk;
}
/// ditto
T* emplace(T, Args...)(T* chunk, auto ref Args args)
if (is(T == struct))
{
    emplaceRef!T(*chunk, args);
    return chunk;
}

version(unittest) private struct __conv_EmplaceTest
{
    int i = 3;
    this(int i)
    {
        assert(this.i == 3 && i == 5);
        this.i = i;
    }
    this(int i, ref int j)
    {
        assert(i == 5 && j == 6);
        this.i = i;
        ++j;
    }

@disable:
    this();
    this(this);
    void opAssign();
}

version(unittest) private class __conv_EmplaceTestClass
{
    int i = 3;
    this(int i)
    {
        assert(this.i == 3 && i == 5);
        this.i = i;
    }
    this(int i, ref int j)
    {
        assert(i == 5 && j == 6);
        this.i = i;
        ++j;
    }
}

unittest
{
    struct S { @disable this(); }
    S s = void;
    static assert(!__traits(compiles, emplace(&s)));
    static assert( __traits(compiles, emplace(&s, S.init)));
}

unittest
{
    interface I {}
    class K : I {}

    K k = void;
    emplace(&k);
    assert(k is null);

    I i = void;
    emplace(&i);
    assert(i is null);
}

unittest
{
    static struct S {int i = 5;}
    S[2] s2 = void;
    emplace(&s2);
    assert(s2[0].i == 5 && s2[1].i == 5);
}

unittest
{
    struct S1
    {}

    struct S2
    {
        void opAssign(S2);
    }

    S1 s1 = void;
    S2 s2 = void;
    S1[2] as1 = void;
    S2[2] as2 = void;
    emplace(&s1);
    emplace(&s2);
    emplace(&as1);
    emplace(&as2);
}

unittest
{
    static struct S1
    {
        this(this) @disable;
    }
    static struct S2
    {
        this() @disable;
    }
    S1[2] ss1 = void;
    S2[2] ss2 = void;
    static assert( __traits(compiles, emplace(&ss1)));
    static assert(!__traits(compiles, emplace(&ss2)));
    S1 s1 = S1.init;
    S2 s2 = S2.init;
    static assert(!__traits(compiles, emplace(&ss1, s1)));
    static assert( __traits(compiles, emplace(&ss2, s2)));
}

unittest
{
    struct S
    {
        immutable int i;
    }
    S s = void;
    S[2] ss1 = void;
    S[2] ss2 = void;
    emplace(&s, 5);
    emplace(&ss1, s);
    emplace(&ss2, ss1);
}

//Start testing emplace-args here

unittest
{
    int a;
    int b = 42;
    assert(*emplace!int(&a, b) == 42);
}

unittest
{
    interface I {}
    class K : I {}

    K k = null, k2 = new K;
    assert(k !is k2);
    emplace!K(&k, k2);
    assert(k is k2);

    I i = null;
    assert(i !is k);
    emplace!I(&i, k);
    assert(i is k);
}

unittest
{
    static struct S
    {
        int i = 5;
        void opAssign(S){assert(0);}
    }
    S[2] sa = void;
    S[2] sb;
    emplace(&sa, sb);
    assert(sa[0].i == 5 && sa[1].i == 5);
}

//Start testing emplace-struct here

// Test constructor branch
unittest
{
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
    __conv_EmplaceTest k = void;
    emplace(&k, 5);
    assert(k.i == 5);
}

unittest
{
    int var = 6;
    __conv_EmplaceTest k = void;
    emplace(&k, 5, var);
    assert(k.i == 5);
    assert(var == 7);
}

// Test matching fields branch
unittest
{
    struct S { uint n; }
    S s;
    emplace!S(&s, 2U);
    assert(s.n == 2);
}

unittest
{
    struct S { int a, b; this(int){} }
    S s;
    static assert(!__traits(compiles, emplace!S(&s, 2, 3)));
}

unittest
{
    struct S { int a, b = 7; }
    S s1 = void, s2 = void;

    emplace!S(&s1, 2);
    assert(s1.a == 2 && s1.b == 7);

    emplace!S(&s2, 2, 3);
    assert(s2.a == 2 && s2.b == 3);
}

//opAssign
unittest
{
    static struct S
    {
        int i = 5;
        void opAssign(int){assert(0);}
        void opAssign(S){assert(0);}
    }
    S sa1 = void;
    S sa2 = void;
    S sb1 = S(1);
    emplace(&sa1, sb1);
    emplace(&sa2, 2);
    assert(sa1.i == 1);
    assert(sa2.i == 2);
}

//postblit precedence
unittest
{
    //Works, but breaks in "-w -O" because of @@@9332@@@.
    //Uncomment test when 9332 is fixed.
    static struct S
    {
        int i;

        this(S other){assert(false);}
        this(int i){this.i = i;}
        this(this){}
    }
    S a = void;
    assert(is(typeof({S b = a;})));    //Postblit
    assert(is(typeof({S b = S(a);}))); //Constructor
    auto b = S(5);
    emplace(&a, b);
    assert(a.i == 5);

    static struct S2
    {
        int* p;
        this(const S2){};
    }
    static assert(!is(immutable S2 : S2));
    S2 s2 = void;
    immutable is2 = (immutable S2).init;
    emplace(&s2, is2);
}

//nested structs and postblit
unittest
{
    static struct S
    {
        int* p;
        this(int i){p = [i].ptr;}
        this(this)
        {
            if (p)
                p = [*p].ptr;
        }
    }
    static struct SS
    {
        S s;
        void opAssign(const SS)
        {
            assert(0);
        }
    }
    SS ssa = void;
    SS ssb = SS(S(5));
    emplace(&ssa, ssb);
    assert(*ssa.s.p == 5);
    assert(ssa.s.p != ssb.s.p);
}

//disabled postblit
unittest
{
    static struct S1
    {
        int i;
        @disable this(this);
    }
    S1 s1 = void;
    static assert( __traits(compiles, emplace(&s1, 1)));
    static assert(!__traits(compiles, emplace(&s1, S1.init)));

    static struct S2
    {
        int i;
        @disable this(this);
        this(ref S2){}
    }
    S2 s2 = void;
    static assert(!__traits(compiles, emplace(&s2, 1)));
    static assert( __traits(compiles, emplace(&s2, S2.init)));

    static struct SS1
    {
        S1 s;
    }
    SS1 ss1 = void;
    static assert( __traits(compiles, emplace(&ss1)));
    static assert(!__traits(compiles, emplace(&ss1, SS1.init)));

    static struct SS2
    {
        S2 s;
    }
    SS2 ss2 = void;
    static assert( __traits(compiles, emplace(&ss2)));
    static assert(!__traits(compiles, emplace(&ss2, SS2.init)));


    // SS1 sss1 = s1;      //This doesn't compile
    // SS1 sss1 = SS1(s1); //This doesn't compile
    // So emplace shouldn't compile either
    static assert(!__traits(compiles, emplace(&sss1, s1)));
    static assert(!__traits(compiles, emplace(&sss2, s2)));
}

//Imutability
unittest
{
    //Castable immutability
    {
        static struct S1
        {
            int i;
        }
        static assert(is( immutable(S1) : S1));
        S1 sa = void;
        auto sb = immutable(S1)(5);
        emplace(&sa, sb);
        assert(sa.i == 5);
    }
    //Un-castable immutability
    {
        static struct S2
        {
            int* p;
        }
        static assert(!is(immutable(S2) : S2));
        S2 sa = void;
        auto sb = immutable(S2)(null);
        assert(!__traits(compiles, emplace(&sa, sb)));
    }
}

unittest
{
    static struct S
    {
        immutable int i;
        immutable(int)* j;
    }
    S s = void;
    emplace(&s, 1, null);
    emplace(&s, 2, &s.i);
    assert(s is S(2, &s.i));
}

//Context pointer
unittest
{
    int i = 0;
    {
        struct S1
        {
            void foo(){++i;}
        }
        S1 sa = void;
        S1 sb;
        emplace(&sa, sb);
        sa.foo();
        assert(i == 1);
    }
    {
        struct S2
        {
            void foo(){++i;}
            this(this){}
        }
        S2 sa = void;
        S2 sb;
        emplace(&sa, sb);
        sa.foo();
        assert(i == 2);
    }

    ////NOTE: THESE WILL COMPILE
    ////But will not correctly emplace the context pointer
    ////The problem lies with voldemort, and not emplace.
    //{
    //    struct S3
    //    {
    //        int k;
    //        void foo(){++i;}
    //    }
    //}
    //S3 s3 = void;
    //emplace(&s3);    //S3.init has no context pointer information
    //emplace(&s3, 1); //No way to obtain context pointer once inside emplace
}

//Alias this
unittest
{
    static struct S
    {
        int i;
    }
    //By Ref
    {
        static struct SS1
        {
            int j;
            S s;
            alias s this;
        }
        S s = void;
        SS1 ss = SS1(1, S(2));
        emplace(&s, ss);
        assert(s.i == 2);
    }
    //By Value
    {
        static struct SS2
        {
            int j;
            S s;
            S foo() @property{return s;}
            alias foo this;
        }
        S s = void;
        SS2 ss = SS2(1, S(2));
        emplace(&s, ss);
        assert(s.i == 2);
    }
}
version(unittest)
{
    //Ambiguity
    struct __std_conv_S
    {
        int i;
        this(__std_conv_SS ss)         {assert(0);}
        static opCall(__std_conv_SS ss)
        {
            __std_conv_S s; s.i = ss.j;
            return s;
        }
    }
    struct __std_conv_SS
    {
        int j;
        __std_conv_S s;
        ref __std_conv_S foo() @property {s.i = j; return s;}
        alias foo this;
    }
    static assert(is(__std_conv_SS : __std_conv_S));
    unittest
    {
        __std_conv_S s = void;
        __std_conv_SS ss = __std_conv_SS(1);

        __std_conv_S sTest1 = ss; //this calls "SS alias this" (and not "S.this(SS)")
        emplace(&s, ss); //"alias this" should take precedence in emplace over "opCall"
        assert(s.i == 1);
    }
}

//Nested classes
unittest
{
    class A{}
    static struct S
    {
        A a;
    }
    S s1 = void;
    S s2 = S(new A);
    emplace(&s1, s2);
    assert(s1.a is s2.a);
}

//safety & nothrow & CTFE
unittest
{
    //emplace should be safe for anything with no elaborate opassign
    static struct S1
    {
        int i;
    }
    static struct S2
    {
        int i;
        this(int j)@safe nothrow{i = j;}
    }

    int i;
    S1 s1 = void;
    S2 s2 = void;

    auto pi = &i;
    auto ps1 = &s1;
    auto ps2 = &s2;

    void foo() @safe nothrow
    {
        emplace(pi);
        emplace(pi, 5);
        emplace(ps1);
        emplace(ps1, 5);
        emplace(ps1, S1.init);
        emplace(ps2);
        emplace(ps2, 5);
        emplace(ps2, S2.init);
    }

    T bar(T)() @property
    {
        T t/+ = void+/; //CTFE void illegal
        emplace(&t, 5);
        return t;
    }
    enum a = bar!int;
    enum b = bar!S1;
    enum c = bar!S2;
}


unittest
{
    struct S
    {
        int[2] get(){return [1, 2];}
        alias get this;
    }
    struct SS
    {
        int[2] ii;
    }
    struct ISS
    {
        int[2] ii;
    }
    S s;
    SS ss = void;
    ISS iss = void;
    emplace(&ss, s);
    emplace(&iss, s);
    assert(ss.ii == [1, 2]);
    assert(iss.ii == [1, 2]);
}

//disable opAssign
unittest
{
    static struct S
    {
        @disable void opAssign(S);
    }
    S s;
    emplace(&s, S.init);
}

//opCall
unittest
{
    int i;
    //Without constructor
    {
        static struct S1
        {
            int i;
            static S1 opCall(int*){assert(0);}
        }
        S1 s = void;
        static assert(!__traits(compiles, emplace(&s,  1)));
        static assert( __traits(compiles, emplace(&s, &i))); //(works, but deprected)
    }
    //With constructor
    {
        static struct S2
        {
            int i = 0;
            static S2 opCall(int*){assert(0);}
            static S2 opCall(int){assert(0);}
            this(int i){this.i = i;}
        }
        S2 s = void;
        static assert( __traits(compiles, emplace(&s, 1)));  //(works, but deprected)
        static assert( __traits(compiles, emplace(&s, &i))); //(works, but deprected)
        emplace(&s,  1);
        assert(s.i == 1);
    }
    //With postblit ambiguity
    {
        static struct S3
        {
            int i = 0;
            static S3 opCall(ref S3){assert(0);}
        }
        S3 s = void;
        static assert( __traits(compiles, emplace(&s, S3.init)));
    }
}

unittest //@@@9559@@@
{
    alias I = Nullable!int;
    auto ints = [0, 1, 2].map!(i => i & 1 ? I.init : I(i))();
    auto asArray = std.array.array(ints);
}

unittest //http://forum.dlang.org/thread/nxbdgtdlmwscocbiypjs@forum.dlang.org
{
    import std.array : array;
    import std.datetime : SysTime, UTC;
    import std.math : isNaN;

    static struct A
    {
        double i;
    }

    static struct B
    {
        invariant()
        {
            if(j == 0)
                assert(a.i.isNaN, "why is 'j' zero?? and i is not NaN?");
            else
                assert(!a.i.isNaN);
        }
        SysTime when; // comment this line avoid the breakage
        int j;
        A a;
    }

    B b1 = B.init;
    assert(&b1); // verify that default eyes invariants are ok;

    auto b2 = B(SysTime(0, UTC()), 1, A(1));
    assert(&b2);
    auto b3 = B(SysTime(0, UTC()), 1, A(1));
    assert(&b3);

    auto arr = [b2, b3];

    assert(arr[0].j == 1);
    assert(arr[1].j == 1);
    auto a2 = arr.array(); // << bang, invariant is raised, also if b2 and b3 are good
}

//static arrays
unittest
{
    static struct S
    {
        int[2] ii;
    }
    static struct IS
    {
        immutable int[2] ii;
    }
    int[2] ii;
    S  s   = void;
    IS ims = void;
    ubyte ub = 2;
    emplace(&s, ub);
    emplace(&s, ii);
    emplace(&ims, ub);
    emplace(&ims, ii);
    uint[2] uu;
    static assert(!__traits(compiles, {S ss = S(uu);}));
    static assert(!__traits(compiles, emplace(&s, uu)));
}

unittest
{
    int[2]  sii;
    int[2]  sii2;
    uint[2] uii;
    uint[2] uii2;
    emplace(&sii, 1);
    emplace(&sii, 1U);
    emplace(&uii, 1);
    emplace(&uii, 1U);
    emplace(&sii, sii2);
    //emplace(&sii, uii2); //Sorry, this implementation doesn't know how to...
    //emplace(&uii, sii2); //Sorry, this implementation doesn't know how to...
    emplace(&uii, uii2);
    emplace(&sii, sii2[]);
    //emplace(&sii, uii2[]); //Sorry, this implementation doesn't know how to...
    //emplace(&uii, sii2[]); //Sorry, this implementation doesn't know how to...
    emplace(&uii, uii2[]);
}

unittest
{
    bool allowDestruction = false;
    struct S
    {
        int i;
        this(this){}
        ~this(){assert(allowDestruction);}
    }
    S s = S(1);
    S[2] ss1 = void;
    S[2] ss2 = void;
    S[2] ss3 = void;
    emplace(&ss1, s);
    emplace(&ss2, ss1);
    emplace(&ss3, ss2[]);
    assert(ss1[1] == s);
    assert(ss2[1] == s);
    assert(ss3[1] == s);
    allowDestruction = true;
}

unittest
{
    //Checks postblit, construction, and context pointer
    int count = 0;
    struct S
    {
        this(this)
        {
            ++count;
        }
        ~this()
        {
            --count;
        }
    }

    S s;
    {
        S[4] ss = void;
        emplace(&ss, s);
        assert(count == 4);
    }
    assert(count == 0);
}

unittest
{
    struct S
    {
        int i;
    }
    S s;
    S[2][2][2] sss = void;
    emplace(&sss, s);
}

unittest //Constness
{
    import std.stdio;

    int a = void;
    emplaceRef!(const int)(a, 5);

    immutable i = 5;
    const(int)* p = void;
    emplaceRef!(const int*)(p, &i);

    struct S
    {
        int* p;
    }
    alias IS = immutable(S);
    S s = void;
    emplaceRef!IS(s, IS());
    S[2] ss = void;
    emplaceRef!(IS[2])(ss, IS());

    IS[2] iss = IS.init;
    emplaceRef!(IS[2])(ss, iss);
    emplaceRef!(IS[2])(ss, iss[]);
}

private void testEmplaceChunk(void[] chunk, size_t typeSize, size_t typeAlignment, string typeName)
{
    enforceEx!ConvException(chunk.length >= typeSize,
        format("emplace: Chunk size too small: %s < %s size = %s",
        chunk.length, typeName, typeSize));
    enforceEx!ConvException((cast(size_t) chunk.ptr) % typeAlignment == 0,
        format("emplace: Misaligned memory block (0x%X): it must be %s-byte aligned for type %s",
        chunk.ptr, typeAlignment, typeName));
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
T emplace(T, Args...)(void[] chunk, auto ref Args args)
    if (is(T == class))
{
    enum classSize = __traits(classInstanceSize, T);
    testEmplaceChunk(chunk, classSize, classInstanceAlignment!T, T.stringof);
    auto result = cast(T) chunk.ptr;

    // Initialize the object in its pre-ctor state
    (cast(byte[]) chunk)[0 .. classSize] = typeid(T).init[];

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

unittest
{
    int var = 6;
    auto k = emplace!__conv_EmplaceTestClass(new void[__traits(classInstanceSize, __conv_EmplaceTestClass)], 5, var);
    assert(k.i == 5);
    assert(var == 7);
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
T* emplace(T, Args...)(void[] chunk, auto ref Args args)
    if (!is(T == class))
{
    testEmplaceChunk(chunk, T.sizeof, T.alignof, T.stringof);
    return emplace(cast(T*) chunk.ptr, args);
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
    int var = 6;
    auto k = emplace!__conv_EmplaceTest(new void[__conv_EmplaceTest.sizeof], 5, var);
    assert(k.i == 5);
    assert(var == 7);
}

unittest
{
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
    void[] buf;

    static byte[__traits(classInstanceSize, A)] sbuf;
    buf = sbuf[];
    auto a = emplace!A(buf, 55);
    assert(a.x == 55 && a.y == 55);

    // emplace in bigger buffer
    buf = new byte[](__traits(classInstanceSize, A) + 10);
    a = emplace!A(buf, 55);
    assert(a.x == 55 && a.y == 55);

    // need ctor args
    static assert(!is(typeof(emplace!A(buf))));
}

unittest
{
    // Check fix for http://d.puremagic.com/issues/show_bug.cgi?id=2971
    assert(equal(map!(to!int)(["42", "34", "345"]), [42, 34, 345]));
}

// Undocumented for the time being
void toTextRange(T, W)(T value, W writer)
    if (isIntegral!T && isOutputRange!(W, char))
{
    char[value.sizeof * 4] buffer = void;
    uint i = cast(uint) (buffer.length - 1);

    bool negative = value < 0;
    Unqual!(Unsigned!T) v = negative ? -value : value;

    while (v >= 10)
    {
        auto c = cast(uint) (v % 10);
        v /= 10;
        buffer[i--] = cast(char) (c + '0');
    }

    buffer[i] = cast(char) (v + '0'); //hexDigits[cast(uint) v];
    if (negative)
        buffer[--i] = '-';
    put(writer, buffer[i .. $]);
}

unittest
{
    auto result = appender!(char[])();
    toTextRange(-1, result);
    assert(result.data == "-1");
}


/**
    Returns the corresponding unsigned value for $(D x) (e.g. if $(D x) has type
    $(D int), it returns $(D cast(uint) x)). The advantage compared to the cast
    is that you do not need to rewrite the cast if $(D x) later changes type
    (e.g from $(D int) to $(D long)).

    Note that the result is always mutable even if the original type was const
    or immutable. In order to retain the constness, use $(XREF traits, Unsigned).
 */
auto unsigned(T)(T x) if (isIntegral!T)
{
    return cast(Unqual!(Unsigned!T))x;
}

///
unittest
{
    uint s = 42;
    auto u1 = unsigned(s); //not qualified
    Unsigned!(typeof(s)) u2 = unsigned(s); //same qualification
    immutable u3 = unsigned(s); //totally qualified
}

unittest
{
    foreach(T; TypeTuple!(byte, ubyte))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == ubyte));
        static assert(is(typeof(unsigned(cast(const T)1)) == ubyte));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == ubyte));
    }

    foreach(T; TypeTuple!(short, ushort))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == ushort));
        static assert(is(typeof(unsigned(cast(const T)1)) == ushort));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == ushort));
    }

    foreach(T; TypeTuple!(int, uint))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == uint));
        static assert(is(typeof(unsigned(cast(const T)1)) == uint));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == uint));
    }

    foreach(T; TypeTuple!(long, ulong))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == ulong));
        static assert(is(typeof(unsigned(cast(const T)1)) == ulong));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == ulong));
    }
}

auto unsigned(T)(T x) if (isSomeChar!T)
{
    // All characters are unsigned
    static assert(T.min == 0);
    return cast(Unqual!T) x;
}

unittest
{
    foreach(T; TypeTuple!(char, wchar, dchar))
    {
        static assert(is(typeof(unsigned(cast(T)'A')) == T));
        static assert(is(typeof(unsigned(cast(const T)'A')) == T));
        static assert(is(typeof(unsigned(cast(immutable T)'A')) == T));
    }
}


/**
    Returns the corresponding signed value for $(D x) (e.g. if $(D x) has type
    $(D uint), it returns $(D cast(int) x)). The advantage compared to the cast
    is that you do not need to rewrite the cast if $(D x) later changes type
    (e.g from $(D uint) to $(D ulong)).

    Note that the result is always mutable even if the original type was const
    or immutable. In order to retain the constness, use $(XREF traits, Signed).
 */
auto signed(T)(T x) if (isIntegral!T)
{
    return cast(Unqual!(Signed!T))x;
}

///
unittest
{
    uint u = 42;
    auto s1 = unsigned(u); //not qualified
    Unsigned!(typeof(u)) s2 = unsigned(u); //same qualification
    immutable s3 = unsigned(u); //totally qualified
}

unittest
{
    foreach(T; TypeTuple!(byte, ubyte))
    {
        static assert(is(typeof(signed(cast(T)1)) == byte));
        static assert(is(typeof(signed(cast(const T)1)) == byte));
        static assert(is(typeof(signed(cast(immutable T)1)) == byte));
    }

    foreach(T; TypeTuple!(short, ushort))
    {
        static assert(is(typeof(signed(cast(T)1)) == short));
        static assert(is(typeof(signed(cast(const T)1)) == short));
        static assert(is(typeof(signed(cast(immutable T)1)) == short));
    }

    foreach(T; TypeTuple!(int, uint))
    {
        static assert(is(typeof(signed(cast(T)1)) == int));
        static assert(is(typeof(signed(cast(const T)1)) == int));
        static assert(is(typeof(signed(cast(immutable T)1)) == int));
    }

    foreach(T; TypeTuple!(long, ulong))
    {
        static assert(is(typeof(signed(cast(T)1)) == long));
        static assert(is(typeof(signed(cast(const T)1)) == long));
        static assert(is(typeof(signed(cast(immutable T)1)) == long));
    }
}

unittest
{
    // issue 10874
    enum Test { a = 0 }
    ulong l = 0;
    auto t = l.to!Test;
}
