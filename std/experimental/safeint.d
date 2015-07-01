/** This $(D module) holds functions to safely compare integers of different
sizes and signeness without any unwanted implicit casts.

Additionally, this $(D module) implements a $(D SafeInt!T) type.
This type has an explicit $(D nan) value, checks binary operation for over-
and underflows, checks division by zero, and checks if values to assign can be
represented by $(D T) where $(D T) is any integer type.
*/
module std.experimental.safeint;

import std.traits : isFloatingPoint, isIntegral, isUnsigned, isNumeric,
    isSigned, Unqual;
import std.typetuple : TypeTuple;

//version(none)
int main()
{
    import std.stdio : writeln, writefln;
    import std.datetime : StopWatch;
    StopWatch sw2;
    sw2.start();
    auto i = prim!(int)();
    sw2.stop();
    writefln("%12s %10d %5d msecs", "int", i, sw2.peek().msecs);

    StopWatch sw;
    sw.start();
    auto i3 = prim!(SafeIntFast!int)();
    sw.stop();
    writefln("%12s %10d %5d msecs", "SafeIntFast", i3, sw.peek().msecs);

    StopWatch sw3;
    sw3.start();
    auto i2 = prim!(SafeIntSmall!int)();
    sw3.stop();
    writefln("%12s %10d %5d msecs", "SafeIntSmall", i3, sw3.peek().msecs);

	assert(i == i3);
	assert(i2 == i3);
	assert(i2 == i);

	return (i + i2 + i3) % 127;
}

@safe:

/** Compares two integer of arbitrary type for equality.

This function makes sure no implicit value propagation falsifies the result of
the comparison.

Params:
    t = an integer value
    s = an integer value

Returns: $(D true) if the value of $(D t) is equal to the value of $(D s),
    false otherwise.
*/
bool equal(T, S)(in T t, in S s) @nogc nothrow pure
        if (isIntegral!T && isIntegral!S)
{
    return impl!("a == b", false, false)(t, s);
}

///
unittest
{
    assert(-1 == uint.max); // this should be false
    assert(!equal(-1, uint.max));
}

/** Compares two integer of arbitrary type for no-equality.

This function makes sure no implicit value propagation falsifies the result of
the comparison.

Params:
    t = an integer value
    s = an integer value

Returns: $(D true) if the value of $(D t) is not equal to the value of $(D s),
    false otherwise.
*/
bool notEqual(T, S)(in T t, in S s) @nogc nothrow pure
        if (isIntegral!T && isIntegral!S)
{
    return impl!("a != b", true, true)(t, s);
}

///
unittest
{
    assert(notEqual(-1, uint.max));
}

/** Checks if the value of the first parameter is smaller than
the value of the second parameter.

This function makes sure no implicit value propagation falsifies the result of
the comparison.

Params:
    t = an integer value
    s = an integer value

Returns: $(D true) if the value of $(D t) is smaller than the value of $(D s),
    false otherwise.
*/
bool less(T, S)(in T t, in S s) @nogc nothrow pure
        if (isIntegral!T && isIntegral!S)
{
    return impl!("a < b", true, false)(t, s);
}

///
unittest
{
    assert(less(-1, uint.max));
}

/** Checks if the value of the first parameter is less or equal
to the value of the second parameter.

This function makes sure no implicit value propagation falsifies the result of
the comparison.

Params:
    t = an integer value
    s = an integer value

Returns: $(D true) if the value of $(D t) is smaller or equal than the value
    of $(D s), false otherwise.
*/
bool lessEqual(T, S)(in T t, in S s) @nogc nothrow pure
        if (isIntegral!T && isIntegral!S)
{
    return impl!("a <= b", true, false)(t, s);
}

///
unittest
{
    assert(lessEqual( 0, uint.max));
    assert(lessEqual(-1, ulong.max));
}

/** Checks if the value of the first parameter is greater than
the value of the second parameter.

This function makes sure no implicit value propagation falsifies the result of
the comparison.

Params:
    t = an integer value
    s = an integer value

Returns: $(D true) if the value of $(D t) is greater than the value of $(D s),
    false otherwise.
*/
bool greater(T, S)(in T t, in S s) @nogc nothrow pure
        if (isIntegral!T && isIntegral!S)
{
    return impl!("a > b", false, true)(t, s);
}

///
unittest
{
    assert(greater(ulong.max, long.min));
}

/** Checks if the value of the first parameter is greater or equal
to the value of the second parameter.

This function makes sure no implicit value propagation falsifies the result of
the comparison.

Params:
    t = an integer value
    s = an integer value

Returns: $(D true) if the value of $(D t) is greater or equal than the value
    of $(D s), false otherwise.
*/
bool greaterEqual(T, S)(in T t, in S s) @nogc nothrow pure
        if (isIntegral!T && isIntegral!S)
{
    return impl!("a >= b", false, true)(t, s);
}

///
unittest
{
    assert(greaterEqual(ulong.max, long.min));
}

private bool impl(string op, bool A, bool B, T, S)(in T t, in S s)
        @nogc nothrow pure if (isIntegral!T && isIntegral!S)
{
    import std.functional : binaryFun;

    alias func = binaryFun!op;

    static if ((isUnsigned!T && isUnsigned!S) || (isSigned!T && isSigned!S))
    {
        return func(t, s);
    }
    else static if (isSigned!T && isUnsigned!S)
    {
        return t < 0 ? A : func(t, s);
    }
    else static if (isUnsigned!T && isSigned!S)
    {
        return s < 0 ? B : func(t, s);
    }
    else
    {
        static if (isSigned!T)
        {
            string Ts = "signed!T";
        }
        else
        {
            string Ts = "unSigned!T";
        }
        static if (isSigned!S)
        {
            string Ss = "signed!S";
        }
        else
        {
            string Ss = "unSigned!S";
        }
        static assert(false, T.stringof ~ " " ~ S.stringof ~ " " ~ Ts ~ " " ~ Ss);
    }
}

private alias TTest =
    TypeTuple!(byte, short, int, long, ubyte, ushort, uint, ulong);

pure @safe unittest
{
    import std.conv : to;

    foreach (T; TypeTuple!(byte, short, int, long))
    {
        foreach (S; TypeTuple!(ubyte, ushort, uint, ulong))
        {
            assert(equal(to!T(1), to!T(1)));
            assert(equal(to!S(1), to!S(1)));
            assert(equal(to!T(1), to!S(1)));
            assert(!equal(to!T(-1), to!S(1)));
            assert(!notEqual(to!T(1), to!T(1)));
            assert(!notEqual(to!S(1), to!S(1)));
            assert(!notEqual(to!T(1), to!S(1)));
            assert(notEqual(to!T(-1), to!S(1)));
            assert(notEqual(to!T(0), to!S(1)));
            assert(!notEqual(to!T(0), to!S(0)));

            assert(!less(to!T(1), to!T(1)));
            assert(!less(to!S(1), to!S(1)));
            assert(!less(to!T(1), to!S(1)));
            assert(less(to!T(-1), to!S(1)));
            assert(!less(to!T(1), to!S(0)));

            assert(lessEqual(to!T(1), to!T(1)));
            assert(lessEqual(to!S(1), to!S(1)));
            assert(lessEqual(to!T(1), to!S(1)));
            assert(lessEqual(to!T(-1), to!S(1)));
            assert(!lessEqual(to!T(1), to!S(0)));

            assert(!greater(to!T(1), to!T(1)));
            assert(greater(to!T(2), to!T(1)));
            assert(!greater(to!S(1), to!S(1)));
            assert(greater(to!S(2), to!S(1)));
            assert(!greater(to!T(1), to!S(1)));
            assert(!greater(to!T(-1), to!S(1)));

            assert(greaterEqual(to!T(1), to!T(1)));
            assert(greaterEqual(to!T(2), to!T(1)));
            assert(!greaterEqual(to!S(1), to!S(2)));
            assert(!greaterEqual(to!T(-1), to!S(1)));
        }
    }
}

private auto divFunc(T)(T v1, T v2, ref bool overflow)
        if(isIntegral!T)
{
    if (v2 == 0)
    {
        overflow = true;
        return 0;
    }
    else
    {
        overflow = false;
        return v1 / v2;
    }
}

private alias divu = divFunc;
private alias divs = divFunc;

private auto modFunc(T)(T v1, T v2, ref bool overflow)
        if(isIntegral!T)
{
	if (v2 == 0) 
	{
		overflow = true;
		return 0;
	}
	else
	{
		overflow = false;
    	return v1 % v2;
	}
}

private alias modu = modFunc;
private alias mods = modFunc;

private pure auto getValue(T)(T t)
{
    static if (isIntegral!T)
        return t;
    else
        return t.store.value;
}

/* Checks if the value of $(D s) can be stored by a variable of
type $(D T).

Params:
    s = the value to check

Returns:
    $(D true) if the value can be stored, false otherwise.
*/
bool canConvertTo(T, S)(in S s) nothrow @nogc pure
        if (isIntegral!(Unqual!T) && isIntegral!(SafeIntType!S))
{
    return (less(getValue(s), T.min) || greater(getValue(s), T.max)) ? false : true;
}

///
pure unittest
{
    assert(canConvertTo!int(1337));
    assert(canConvertTo!uint(1337));
    assert(canConvertTo!int(-1337));
    assert(!canConvertTo!uint(-1337));
    assert(!canConvertTo!byte(1337));
    assert(!canConvertTo!ubyte(1337));
    assert(!canConvertTo!byte(-1337));
    assert(!canConvertTo!ubyte(-1337));
}

pure unittest
{
    foreach (T; TTest)
    {
        foreach (S; TTest)
        {
            auto s = SafeInt!S(0);
            assert(!s.isNaN);
            assert(canConvertTo!T(s));
        }
    }
}

/** Returns the integer type used by a $(D SafeInt) to store the
value.

If an integer type is passed this type will be returned.
*/
template SafeIntType(T)
{
    static if (isIntegral!T)
        alias SafeIntType = T;
    else
        alias SafeIntType = typeof(T.store.value);
}

///
pure unittest
{
    static assert(is(SafeIntType!(SafeInt!int) == int));
    static assert(is(SafeIntType!int == int));
}

/** Checks if the passed type is a $(D SafeInt).

Returns:
    $(D true) if the passed type $(D T) is an $(D SafeInt), false
    overwise.
*/
template isSafeInt(T)
{
    //pragma(msg, typeof(T));
    static if (is(T : SafeIntImpl!(S), S...))
        enum isSafeInt = true;
    else
        enum isSafeInt = false;
}

///
pure unittest
{
    //static assert( isSafeInt!(SafeIntInline!int));
    //static assert( isSafeInt!(SafeIntExplicit!int));
    static assert( isSafeInt!(SafeInt!int));
    static assert(!isSafeInt!int);
}

pure unittest
{
    static assert(!isSafeInt!int);
    foreach (T; TTest)
    {
        alias ST = SafeInt!T;
        static assert(isSafeInt!ST);
    }
}

struct SafeIntInline(T)
{
    T value = nan;

    alias value this;

    static if (isUnsigned!T)
    {
        /// The minimal value storable by this SafeInt.
        enum min = 0u;
        /// The maximal value storable by this SafeInt.
        enum max = T.max - 1;
        // The NaN value defined by this SafeInt.
        enum nan = T.max;
    }
    else
    {
        /// The minimal value storable by this SafeInt.
        enum min = T.min + 1;
        /// The maximal value storable by this SafeInt.
        enum max = T.max;
        // The NaN value defined by this SafeInt.
        enum nan = T.min;
    }

    bool isNaN() const
    {
        return this.value == nan;
    }

    void setNaN() {
        this.value = this.nan;
    }

    void unsetNaN() {
        this.value = 0;
    }
}

struct SafeIntExplicit(T)
{
    T value;
    bool nan = true;

    alias value this;

    static if (isUnsigned!T)
    {
        /// The minimal value storable by this SafeInt.
        enum min = 0u;
        /// The maximal value storable by this SafeInt.
        enum max = T.max;
    }
    else
    {
        /// The minimal value storable by this SafeInt.
        enum min = T.min;
        /// The maximal value storable by this SafeInt.
        enum max = T.max;
    }

    bool isNaN() const
    {
        return this.nan;
    }

    void setNaN()
    {
        this.nan = true;
    }

    void unsetNaN() {
        this.nan = false;
    }
}

/** $(B SafeInt) implements a safe integer type.

Safe in the sense that:
$(UL
    $(LI over and underflows are not ignored)
    $(LI no unchecked implicit casts are performed)
    $(LI assigned values are checked if they fit into the value range of the
        underlaying type)
    $(LI default initialization to NaN)
    $(LI no bitwise operations are implemented.)
)

Every SafeInt must be specialized with one integer type.
The integer type also defines the NaN value.
For unsigned integer $(D U) the NaN value is $(D U.max).
For signed integer $(D S) the NaN value is $(D U.min).

This limits the value ranges of $(D SafeInt!U) where $(D U) is an unsigned
integer to $(D SafeInt!U >= 0 && SafeInt!U < U.max).
This limits the value ranges of $(D SafeInt!S) where $(D S) is an signed
integer to $(D SafeInt!S > S.min && SafeInt!S < S.max).
*/
nothrow @nogc struct SafeIntImpl(T,Store = SafeIntInline!T) if (isIntegral!T)
{
    import core.checkedint;

    alias Signed = isSigned!T;

    Store!T store;

    /** Whenever a operation is not defined by the SafeInt struct this alias
    converts the SafeInt to the underlaying integer.
    */
    alias store this;

    /** The constructor for SafeInt.

    The passed value must either be an basic numeric or another SafeInt value.
    The value of the passed parameter must fit into the value range defined by
    the template specialization of the SafeInt.

    Params:
        v = the value to construct the SafeInt from.
    */
    this(V)(in V v) pure if (isNumeric!V || isSafeInt!V)
    {
        this.safeAssign(v);
    }

    enum min = Store.min;
    enum max = Store.max;

    private void safeAssign(V)(in V v) pure
    {
        static if (isFloatingPoint!V)
        {
            if (v >= this.min && v <= this.max)
            {
                this.store.unsetNaN();
                this.store.value = cast(T) v;
            }
            else
            {
                this.store.setNaN();
            }
        }
        else
        {
            alias VT = SafeIntType!V;

            static if (is(typeof(this) == V))
            {
                // If this and v have the exact same value type, no runtime
                // checks are required at all.
                this.store.unsetNaN();
                this.store.value = getValue(v);
            }
            else
            {
                static if (isSafeInt!V)
                {
                    if (v.isNaN)
                    {
                        this.store.setNaN();
                        return;
                    }
                }

                auto vVal = getValue(v);
                static if (Signed && isSigned!(typeof(vVal)) &&
                        typeof(vVal).sizeof > T.sizeof)
                {
                    if (less(vVal, this.min) || greater(vVal, this.max))
                    {
                        this.store.setNaN();
                        return;
                    }
                }
                else static if (Signed && !isSigned!(typeof(vVal)) &&
                        typeof(vVal).sizeof >= T.sizeof)
                {
                    if(greater(vVal, this.max))
                    {
                        this.store.setNaN();
                        return;
                    }
                }
                else static if (!Signed && !isSigned!(typeof(vVal)) &&
                        typeof(vVal).sizeof > T.sizeof)
                {
                    if(greater(vVal, this.max))
                    {
                        this.store.setNaN();
                        return;
                    }
                }
                else static if (!Signed && isSigned!(typeof(vVal)))
                {
                    if (less(vVal, this.min) || greater(vVal, this.max))
                    {
                        this.store.setNaN();
                        return;
                    }
                }

                this.store.unsetNaN();
                this.store.value = cast(T)vVal;
            }
        }
    }

    /** Check if this SafeInts value is NaN.

    Returns:
        true is value is NaN, false otherwise.
    */
    @property bool isNaN() const pure
    {
        return this.store.isNaN();
    }

    private static auto getValue(V)(V vIn) pure
    {
        static if (isSafeInt!V)
        {
            return vIn.store.value;
        }
        else
        {
            return vIn;
        }
    }

    /** This implements $(D +=, -=, %=, /=, *=) for this SafeInt.

    Returns:
        a copy of this SafeInt.
    */
    typeof(this) opOpAssign(string op, V)(V vIn) pure
    {
        enum call = "this = this " ~ op ~ " vIn;";
        mixin(call);
        return this;
    }

    /** This implements $(D +, -, %, /, *) for this SafeInt.

    If the result of the operation can not be stored by the SafeInt!T,
    the resulting value is nan.

    Returns:
        a new SafeInt!T with the result of the operation.
    */
    Unqual!(typeof(this)) opBinary(string op, V)(V vIn) const pure
    {
        auto v = getValue(vIn);

        static if (typeof(v).sizeof > 4 || typeof(this.store.value).sizeof > 4)
        {
            alias SignedType = long;
            alias UnsignedType = ulong;
        }
        else
        {
            alias SignedType = int;
            alias UnsignedType = uint;
        }

        bool overflow = false;
        bool wasNaN = true;

        if (this.isNaN)
        {
            auto tmp = Unqual!(typeof(this))();
            tmp.store.setNaN();
            return tmp;
        }
        static if (isSafeInt!V)
        {
            if(vIn.isNaN)
            {
                auto tmp = Unqual!(typeof(this))();
                tmp.store.setNaN();
                return tmp;
            }
        }

        static if (op == "+")
        {
            enum opStrS = "adds";
            enum opStrU = "addu";
        }
        else static if (op == "-")
        {
            enum opStrS = "subs";
            enum opStrU = "subu";
        }
        else static if (op == "*")
        {
            enum opStrS = "muls";
            enum opStrU = "mulu";
        }
        else static if (op == "/")
        {
            enum opStrS = "divs";
            enum opStrU = "divu";
        }
        else static if (op == "%")
        {
            enum opStrS = "mods";
            enum opStrU = "modu";
        }
        else
        {
            static assert(false, "Only \"+,-,*,/,%\" operations are supported, "
                ~ "to use bitwise operaton, please convert to an buildin "
                ~ "integer.");
        }

        static if (Signed && isSigned!(typeof(v)))
        {
            mixin("auto ret = " ~ opStrS ~ "(this.store.value, v, overflow);");
            wasNaN = false;
        }
        else static if (!Signed && isUnsigned!(typeof(v)))
        {
            mixin("auto ret = " ~ opStrU ~ "(this.store.value, v, overflow);");
            wasNaN = false;
        }

        static if (Signed && isUnsigned!(typeof(v)))
        {
            T ret;
            if (canConvertTo!SignedType(v))
            {
                mixin("ret = cast(T)" ~ opStrS ~
                    "(this.store.value, cast(T)v, overflow);");
                wasNaN = false;
            }
            else if (canConvertTo!UnsignedType(this.store.value))
            {
                mixin("auto tmp = " ~ opStrU ~
                    "(cast(typeof(v))this.store.value, v, overflow);");
                if (canConvertTo!T(tmp))
                {
                    ret = cast(T) tmp;
                    wasNaN = false;
                }
            }
        }

        static if (!Signed && isSigned!(typeof(v)))
        {
            T ret;
            if (canConvertTo!UnsignedType(v))
            {
                mixin("ret = cast(T)" ~ opStrU ~
                    "(this.store.value, cast(T)v, overflow);");
                wasNaN = false;
            }
            else if (canConvertTo!SignedType(this.store.value))
            {
                mixin("auto tmp = " ~ opStrS ~
                    "(cast(typeof(v))this.store.value, v, overflow);");
                if (canConvertTo!(SafeIntType!T)(tmp))
                {
                    ret = cast(T) tmp;
                    wasNaN = false;
                }
            }
        }

        Unqual!(typeof(this)) retu;


        if (overflow)
        {
            retu.store.setNaN();
        }
        else if(wasNaN)
        {
            retu.store.setNaN();
        }
        else
        {
            return Unqual!(typeof(this))(ret);
        }

        return retu;
    }

    /** Implements the assignment operation for the SafeInt type.

    Every numeric value and every SafeInt can be assigned.
    If the passed value can not be stored by the SafeInt, the value of the
    SafeInt will be set to NaN.

    Params:
        vIn = the value to assign

    Returns:
        a copy of this SafeInt.
    */
    typeof(this) opAssign(V)(V vIn) pure if (isNumeric!T || isSafeInt!V)
    {
        this.safeAssign(vIn);
        return this;
    }

    /** Implements the equality comparison function for the SafeInt type.

    Params:
        vIn = the value to compare the SafeInt with

    Returns:
        $(D true) if the passed value is equal to the value stored in the
        SafeInt, false otherwise.
    */
    bool opEquals(V)(auto ref V vIn) const pure
    {
        static if (isFloatingPoint!V)
        {
            return this.store.value == vIn;
        }
        else
        {
            if(this.isNaN) {
                return false;
            }

            static if(isSafeInt!V)
            {
                if(vIn.isNaN)
                {
                    return false;
                }
            }

            auto v = getValue(vIn);

            return equal(this.store.value, v);
        }
    }

    /** Implements the comparison function for the SafeInt type.

    Params:
        vIn = the value to compare the SafeInt with

    Returns:
        -1 if the SafeInt is less than $(D vIn), 1 if the SafeInt is greater
        than $(D vIn), 0 otherwise.
    */
    int opCmp(V)(auto ref V vIn) const pure
    {
        static if (isFloatingPoint!V)
        {
            return this.store.value < vIn ? -1 : this.store.value > vIn ?
                   1 : 0;
        }
        else
        {
            auto v = getValue(vIn);

            return less(this.store.value, v) ? -1 : equal(this.store.value, v) ?
                   0 : 1;
        }
    }

    import std.format : FormatSpec;

    void toString(scope void delegate(const(char)[]) @system sink,
            FormatSpec!char fmt) const @trusted
    {
        import std.format : formatValue;

        if (this.store.isNaN())
        {
            sink("nan");
        }
        else
        {
            formatValue(sink, this.store.value, fmt);
        }
    }
}

@safe @nogc pure nothrow unittest
{
    foreach(S; TypeTuple!(SafeIntSmall!uint, SafeIntFast!uint))
    {
        S s0 = -1;
        assert(s0.isNaN);

        S s0_1 = s0 + 4;
        assert(s0_1.isNaN);
        auto s1 = S(1);
        assert(!s1.isNaN);
        S s2 = s1 + 1;
        assert(!s2.isNaN);
        assert(s2 == 2);

        S s2_1 = s0 = s2;
        assert(!s2.isNaN);
        assert(s2 == SafeInt!byte(2));
        assert(s2 < SafeInt!byte(3));
        assert(s2 > SafeInt!byte(1));
        assert(s2 > 1.0);

        s2 += 1;
        assert(s2 == 3);

        auto s3 = S(2);
        auto s4 = s1 + s3;
        assert(!s4.isNaN);
        assert(s4 == 3);

        assert(SafeInt!int(0) == 0.0);
    }
}

unittest
{
    auto s = SafeIntSmall!int(1);
    SafeIntFast!int f = s;
    assert(f == 1);
}

alias SafeIntFast(T) = SafeIntImpl!(T, SafeIntExplicit!T);
alias SafeIntSmall(T) = SafeIntImpl!(T, SafeIntInline!T);
alias SafeInt(T) = SafeIntSmall!(T);

@safe:

nothrow @nogc pure unittest
{
    foreach (T; TTest)
    {
        auto s1 = SafeInt!T(127);
        assert(s1 == 127);
        assert(!s1.isNaN);
        auto s1_2 = s1 + 1;

        SafeInt!T s2;
        assert(s2.isNaN);
    }
}

nothrow @nogc pure unittest
{
    auto s = SafeInt!byte(1337u);
    assert(s.isNaN);

    auto u = SafeInt!ubyte(1337u);
    assert(u.isNaN);
}

nothrow pure @nogc unittest
{
    auto s1 = SafeInt!byte();
    assert(s1.isNaN);

    SafeInt!int s2 = s1;
    assert(s2.isNaN);

    auto s3 = SafeInt!int(1) + s1;
    assert(s3.isNaN);

    auto s4 = SafeInt!int(s1);
    assert(s4.isNaN);
}

unittest
{
    SafeInt!int a = 1;
    static assert(!__traits(compiles, (a | 1)));
}

unittest
{
    import std.format : format;

    auto f = format("%d", SafeInt!int(1));
    assert(f == "1");

    f = format("%5d", SafeInt!int(1));
    assert(f == "    1");

    f = format("%d", SafeInt!int());
    assert(f == "nan");
}

nothrow @nogc pure:

unittest
{
    auto s1 = SafeInt!ubyte(1);

    auto r = s1 + SafeInt!ubyte(2);
    assert(r == 3);
    auto r1 = s1 + 2;
    assert(r1 == 3);
}

unittest
{
    foreach (T; TTest)
    {
        auto s1 = SafeInt!T(1);
        auto s2 = SafeInt!T(1);
        auto s3 = SafeInt!T(5);
        auto s4 = SafeInt!T(2);

        auto sp = s1 + s2;
        auto sm = s1 - s2;
        auto sx = s1 * s2;
        auto sd = s1 / s2;
        auto sdn = s1 / 0;
        auto sdn2 = s1 / SafeInt!int(0);
        auto smo = s3 % s4;

        static assert(is(typeof(sp) == SafeInt!T));
        static assert(is(typeof(sm) == SafeInt!T));
        static assert(is(typeof(sx) == SafeInt!T));
        static assert(is(typeof(sd) == SafeInt!T));
        static assert(is(typeof(smo) == SafeInt!T));
        static assert(is(typeof(sdn) == SafeInt!T));
        static assert(is(typeof(sdn2) == SafeInt!T));

        assert(sp == 2);
        assert(sm == 0);
        assert(sx == 1);
        assert(sd == 1);
        assert(smo == 1);
        assert(sdn.isNaN);
        assert(sdn2.isNaN);
    }
}

unittest
{
    foreach (T; TTest)
    {
        foreach (S; TTest)
        {
            auto s0 = SafeInt!T(0);
            auto s1 = SafeInt!T(1);
            auto s2 = SafeInt!S(1);
            auto s3 = SafeInt!S(2);

            assert(s1 == 1);
            assert(s1 == s2);
            assert(s1 < s3);
            assert(s1 < 2);
            assert(s1 < s3);
            assert(s1 < 2);
            assert(s1 > 0);
            assert(s1 > s0);
        }
    }
}

unittest
{
    auto s1 = SafeInt!int(1);
    auto s2 = SafeInt!int(1);

    auto sd = s1 / s2;
}

unittest
{
    import std.conv : to;

    foreach (T; TTest)
    {
        SafeInt!T minT = SafeInt!(T).min;
        SafeInt!T maxT = SafeInt!(T).max;
        SafeInt!T zeroT = 0;

        static if (isUnsigned!T)
        {
            assert(minT == 0);
            assert(maxT == T.max - 1);
            assert(zeroT == 0);

            zeroT -= 1;
            assert(zeroT.isNaN);
        }
        else
        {
            assert(minT == T.min + 1);
            assert(maxT == T.max);
            assert(zeroT == 0);
        }

        minT -= 1;
        assert(minT.isNaN);

        maxT += 1;
        assert(maxT.isNaN);

    }
}

unittest
{
    foreach (T; TTest)
    {
        foreach (S; TypeTuple!(byte, short, int, long))
        {
            auto s0 = SafeInt!T(2);
            auto s1 = s0 + cast(S)-1;
        }
    }
}

unittest
{
    SafeInt!int safe;
    int raw = 0;
    safe = raw;
}

private T prim(T)()
{
    enum upTo = 200_000_000;
    T ret = 5;
    T[1000] buf;
    buf[0] = 2;
    buf[1] = 3;
    T bufIdx = 2;

    con: for(T i = 3; i < upTo; i+=2)
    {
        for(size_t j = 0; j < bufIdx; ++j)
        {
            if (i % buf[j] == 0)
            {
                continue con;
            }
        }

        for(T j = buf[bufIdx-1]; j < i; ++j)
        {
            auto t = i % j;
            if (t == 0)
            {
                continue con;
            }
        }

        if (bufIdx < buf.length)
        {
            buf[bufIdx++] = i;
        }

		// Collatz sequence
		T cnt = 0;
		while(i != 0 && cnt < 2_100_000_000) 
		{
			if (i % 2 == 0)
				i /= 2;
			else
				i = i * 3 + 1;

			++cnt;
		}

		// Digit Sum
		T sum = cnt + i;
		T sumElem = 0;
		while(sum > 0)
		{
			sumElem += sum % 10;
			sum /= 10;
		}

        ret += i - sumElem;
    }

    return ret;
}
