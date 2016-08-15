/**

This module defines facilities for efficient checking of integral operations
against overflow, casting with loss of precision, unexpected change of sign,
etc. The checking (and possibly correction) can be done at operation level, for
example $(D opChecked!"+"(x, y, overflow)) adds two integrals `x` and `y` and
sets `overflow` to `true` if an overflow occurred. The flag (passed by
reference) is not touched if the operation succeeded, so the same flag can be
reused for a sequence of operations and tested at the end.

Issuing individual checked operations is flexible and efficient but often
tedious. The `Checked` facility offers encapsulated integral wrappers that do
all checking internally and have configurable behavior upon erroneous results.
For example, `Checked!int` is a type that behaves like `int` but issues an
`assert(0)` (i.e. throws an `Error` in debug mode or aborts execution in release
mode) whenever involved in an operation that produces the arithmetically wrong
result. For example $(D Checked!int(1_000_000) * 10_000) fails with `assert(0)`
because the operation overflows. Also, $(D Checked!int(-1) > uint(0)) fails with
`assert(0)` (even though the built-in comparison $(D int(-1) > uint(0)) is
surprisingly true due to language's conversion rules modeled  after C). Thus,
`Checked!int` is a virtually drop-in replacement for `int` useable in debug
builds, to be replaced by `int` if efficiency demands it.

`Checked`  has customizable behavior with the help of a second type parameter,
`Hook`. Depending on what methods `Hook` defines, core operations on the
underlying integral may be verified for overflow or completely redefined. If
`Hook` defines no method at all and carries no state, there is no change in
behavior, i.e. $(D Checked!(int, void)) is a wrapper around `int` that adds no
customization at all.

This module provides a few predefined hooks (below) that add useful behavior to
`Checked`:

$(UL

$(LI `Abort` fails every incorrect operation with a message to `stderr` followed
by a call to `abort()`. It is the default second parameter, i.e. `Checked!short`
is the same as $(D Checked!(short, Abort)).)

$(LI `ProperCompare` fixes the comparison operators `==`, `!=`, `<`, `<=`, `>`,
and `>=` to return correct results in all circumstances, at a slight cost in
    efficiency. For example, $(D Checked!(uint, ProperCompare)(1) > -1) is `true`,
which is not the case with the built-in comparison. Also, comparing numbers for
equality with floating-point numbers only passes if the integral can be
converted to the floating-point number precisely, so as to preserve transitivity
of equality.)

$(LI `WithNaN` reserves a special "Not a Number" value. )

)

These policies may be used alone, e.g. $(D Checked!(uint, WithNaN)) defines a
`uint`-like type that reaches a stable NaN state for all erroneous operations.
They may also be "stacked" on top of each other, owing to the property that a
checked integral emulates an actual integral, which means another checked
integral can be built on top of it. Some interesting combinations include:

$(UL

$(LI $(D Checked!(Checked!int, ProperCompare)) defines an `int` with fixed
comparison operators that will fail with `assert(0)` upon overflow. (Recall that
`Abort` is the default policy.) The order in which policies are combined is
important because the outermost policy (`ProperCompare` in this case) has the
first crack at intercepting an operator. The converse combination $(D
Checked!(Checked!(int, ProperCompare))) is meaningless because `Abort` will
intercept comparison and will fail without giving `ProperCompare` a chance to
intervene.)

$(LI $(D Checked!(Checked!(int, ProperCompare), WithNaN)) defines an `int`-like
type that supports a NaN value. For values that are not NaN, comparison works
properly. Again the composition order is important; $(D Checked!(Checked!(int,
WithNaN), ProperCompare)) does not have good semantics because `ProperCompare`
intercepts comparisons before the numbers involved are tested for NaN.)

)

*/
module std.experimental.checkedint;
import std.traits : isFloatingPoint, isIntegral, isNumeric, isUnsigned, Unqual;

///
unittest
{
    int[] addAndMerge(int[] a, int[] b, int offset)
    {
        // Aborts on overflow on size computation
        auto r = new int[(Checked!size_t(a.length) + b.length).representation];
        // Aborts on overflow on element computation
        foreach (i; 0 .. a.length)
            r[i] = (a[i] + Checked!int(offset)).representation;
        foreach (i; 0 .. b.length)
            r[i + a.length] = (b[i] + Checked!int(offset)).representation;
        return r;
    }
    assert(addAndMerge([1, 2, 3], [4, 5], -1) == [0, 1, 2, 3, 4]);
}

/**
Checked integral type wraps an integral `T` and customizes its behavior with the
help of a `Hook` type. The type wrapped must be one of the predefined integrals
(unqualified), or another instance of `Checked`.
*/
struct Checked(T, Hook = Abort)
if (isIntegral!T && is(T == Unqual!T) || is(T == Checked!(U, H), U, H))
{
    import std.algorithm.comparison : among;
    import std.traits : hasMember;
    import std.experimental.allocator.common : stateSize;

    /**
    The type of the integral subject to checking.
    */
    alias Representation = T;

    // state {
    static if (hasMember!(Hook, "defaultValue"))
        private T payload = Hook.defaultValue!T;
    else
        private T payload;
    /**
    `hook` is a member variable if it has state, or an alias for `Hook`
    otherwise.
    */
    static if (stateSize!Hook > 0) Hook hook;
    else alias hook = Hook;
    // } state

    // representation
    /**
    Returns a copy of the underlying value.
    */
    auto representation() inout { return payload; }
    ///
    unittest
    {
        auto x = Checked!ubyte(ubyte(42));
        static assert(is(typeof(x.representation()) == ubyte));
        assert(x.representation == 42);
    }

    /**
    Defines the minimum and maximum allowed.
    */
    static if (hasMember!(Hook, "min"))
        enum min = Checked!(T, Hook)(Hook.min!T);
    else
        enum min = Checked(T.min);
    /// ditto
    static if (hasMember!(Hook, "max"))
        enum max = Checked(Hook.max!T);
    else
        enum max = Checked(T.max);
    ///
    unittest
    {
        assert(Checked!short.min == -32768);
        assert(Checked!(short, WithNaN).min == -32767);
        assert(Checked!(uint, WithNaN).max == uint.max - 1);
    }

    /**
    Constructor taking a value properly convertible to the underlying type. `U`
    may be either an integral that can be converted to `T` without a loss, or
    another `Checked` instance whose representation may be in turn converted to
    `T` without a loss.
    */
    this(U)(U rhs)
    if (valueConvertible!(U, T) ||
        !isIntegral!T && is(typeof(T(rhs))) ||
        is(U == Checked!(V, W), V, W) &&
            is(typeof(Checked(rhs.representation))))
    {
        static if (isIntegral!U)
            payload = rhs;
        else
            payload = rhs.payload;
    }

    /**
    Assignment operator. Has the same constraints as the constructor.
    */
    void opAssign(U)(U rhs) if (is(typeof(Checked(rhs))))
    {
        static if (isIntegral!U)
            payload = rhs;
        else
            payload = rhs.payload;
    }

    // opCast
    /**
    Casting operator to integral, `bool`, or floating point type. If `Hook`
    defines `hookOpCast`, the call immediately returns
    `hook.hookOpCast!U(representation)`. Otherwise, casting to `bool` yields $(D
    representation != 0) and casting to another integral that can represent all
    values of `T` returns `representation` promoted to `U`.

    If a cast to a floating-point type is requested and `Hook` defines
    `onBadCast`, the cast is verified by ensuring $(D representation == cast(T)
    U(representation)). If that is not `true`,
    `hook.onBadCast!U(representation)` is returned.

    If a cast to an integral type is requested and `Hook` defines `onBadCast`,
    the cast is verified by ensuring `representation` and $(D cast(U)
    representation) are the same arithmetic number. (Note that `int(-1)` and
    `uint(1)` are different values arithmetically although they have the same
    bitwise representation and compare equal by language rules.) If the numbers
    are not arithmetically equal, `hook.onBadCast!U(representation)` is
    returned.

    */
    U opCast(U)()
    if (isIntegral!U || isFloatingPoint!U || is(U == bool))
    {
        static if (hasMember!(Hook, "hookOpCast"))
        {
            return hook.hookOpCast!U(payload);
        }
        else static if (is(U == bool))
        {
            return payload != 0;
        }
        else static if (valueConvertible!(T, U))
        {
            return payload;
        }
        // may lose bits or precision
        else static if (!hasMember!(Hook, "onBadCast"))
        {
            return cast(U) payload;
        }
        else
        {
            if (isUnsigned!T || !isUnsigned!U ||
                    T.sizeof > U.sizeof || payload >= 0)
            {
                auto result = cast(U) payload;
                // If signedness is different, we need additional checks
                if (result == payload &&
                        (!isUnsigned!T || isUnsigned!U || result >= 0))
                    return result;
            }
            return hook.onBadCast!U(payload);
        }
    }
    ///
    unittest
    {
        assert(cast(uint) Checked!int(42) == 42);
        assert(cast(uint) Checked!(int, WithNaN)(-42) == uint.max);
    }

    // opEquals
    /**
    Compares `this` against `rhs` for equality. If `Hook` defines
    `hookOpEquals`, the function forwards to $(D
    hook.hookOpEquals(representation, rhs)). Otherwise, the result of the
    built-in operation $(D representation == rhs) is returned.

    If `U` is an instance of `Checked`
    */
    bool opEquals(U)(U rhs)
    if (isIntegral!U || isFloatingPoint!U || is(U == bool) ||
        is(U == Checked!(V, W), V, W) && is(typeof(this == rhs.payload)))
    {
        static if (is(U == Checked!(V, W), V, W))
        {
            alias R = typeof(payload + rhs.payload);
            static if (is(Hook == W))
            {
                // Use the lhs hook if there
                return this == rhs.payload;
            }
            else static if (valueConvertible!(T, R) && valueConvertible!(V, R))
            {
                return payload == rhs.payload;
            }
            else static if (hasMember!(Hook, "hookOpEquals"))
            {
                return hook.hookOpEquals(payload, rhs.payload);
            }
            else static if (hasMember!(W, "hookOpEquals"))
            {
                return rhs.hook.hookOpEquals(rhs.payload, payload);
            }
            else
            {
                return payload == rhs.payload;
            }
        }
        else static if (hasMember!(Hook, "hookOpEquals"))
            return hook.hookOpEquals(payload, rhs);
        else static if (isIntegral!U || isFloatingPoint!U || is(U == bool))
            return payload == rhs;
    }

    // opCmp
    /**
    */
    auto opCmp(U)(const U rhs) //const pure @safe nothrow @nogc
    if (isIntegral!U || isFloatingPoint!U || is(U == bool))
    {
        static if (hasMember!(Hook, "hookOpCmp"))
        {
            return hook.hookOpCmp(payload, rhs);
        }
        else static if (valueConvertible!(T, U) || valueConvertible!(U, T))
        {
            return payload < rhs ? -1 : payload > rhs;
        }
        else static if (isFloatingPoint!U)
        {
            U lhs = payload;
            return lhs < rhs ? U(-1.0)
                : lhs > rhs ? U(1.0)
                : lhs == rhs ? U(0.0) : U.init;
        }
        else
        {
            return payload < rhs ? -1 : payload > rhs;
        }
    }

    /// ditto
    auto opCmp(U, Hook1)(Checked!(U, Hook1) rhs)
    {
        alias R = typeof(payload + rhs.payload);
        static if (valueConvertible!(T, R) && valueConvertible!(U, R))
        {
            return payload < rhs.payload ? -1 : payload > rhs.payload;
        }
        else static if (is(Hook == Hook1))
        {
            // Use the lhs hook
            return this.opCmp(rhs.payload);
        }
        else static if (hasMember!(Hook, "hookOpCmp"))
        {
            return hook.hookOpCmp(payload, rhs);
        }
        else static if (hasMember!(Hook1, "hookOpCmp"))
        {
            return rhs.hook.hookOpCmp(rhs.payload, this);
        }
        else
        {
            return payload < rhs.payload ? -1 : payload > rhs.payload;
        }
    }

    // opUnary
    /**
    */
    auto opUnary(string op)()
    if (op == "+" || op == "-" || op == "~")
    {
        static if (op == "+")
            return Checked(this); // "+" is not hookable
        else static if (hasMember!(Hook, "hookOpUnary"))
        {
            auto r = hook.hookOpUnary!op(payload);
            return Checked!(typeof(r), Hook)(r);
        }
        else static if (isIntegral!T && !isUnsigned!T && op == "-" &&
                hasMember!(Hook, "onOverflow"))
        {
            import core.checkedint;
            static assert(is(typeof(-payload) == typeof(payload)));
            bool overflow;
            auto r = negs(payload, overflow);
            if (overflow) r = hook.onOverflow!op(payload);
            return Checked(r);
        }
        else
            return Checked(mixin(op ~ "payload"));
    }

    /// ditto
    ref Checked opUnary(string op)() return
    if (op == "++" || op == "--")
    {
        static if (hasMember!(Hook, "hookOpUnary"))
            hook.hookOpUnary!op(payload);
        else static if (hasMember!(Hook, "onOverflow"))
        {
            static if (op == "++")
            {
                if (payload == max.payload)
                    payload = hook.onOverflow!"++"(payload);
                else
                    ++payload;
            }
            else
            {
                if (payload == min.payload)
                    payload = hook.onOverflow!"--"(payload);
                else
                    --payload;
            }
        }
        else
            mixin(op ~ "payload;");
        return this;
    }

    // opBinary
    /**
    */
    auto opBinary(string op, Rhs)(const Rhs rhs)
    if (isIntegral!Rhs || isFloatingPoint!Rhs || is(Rhs == bool))
    {
        alias R = typeof(payload + rhs);
        static assert(is(typeof(mixin("payload" ~ op ~ "rhs")) == R));
        static if (isIntegral!R) alias Result = Checked!(R, Hook);
        else alias Result = R;

        static if (hasMember!(Hook, "hookOpBinary"))
        {
            auto r = hook.hookOpBinary!op(payload, rhs);
            return Checked!(typeof(r), Hook)(r);
        }
        else static if (is(Rhs == bool))
        {
            return mixin("this" ~ op ~ "ubyte(rhs)");
        }
        else static if (isFloatingPoint!Rhs)
        {
            return mixin("payload" ~ op ~ "rhs");
        }
        else static if (hasMember!(Hook, "onOverflow"))
        {
            bool overflow;
            auto r = opChecked!op(payload, rhs, overflow);
            if (overflow) r = hook.onOverflow!op(payload, rhs);
            return Result(r);
        }
        else
        {
            // Default is built-in behavior
            return Result(mixin("payload" ~ op ~ "rhs"));
        }
    }

    /// ditto
    auto opBinary(string op, U, Hook1)(Checked!(U, Hook1) rhs)
    {
        alias R = typeof(representation + rhs.payload);
        static if (valueConvertible!(T, R) && valueConvertible!(U, R) ||
            is(Hook == Hook1))
        {
            // Delegate to lhs
            return mixin("this" ~ op ~ "rhs.payload");
        }
        else static if (hasMember!(Hook, "hookOpBinary"))
        {
            return hook.hookOpBinary!op(payload, rhs);
        }
        else static if (hasMember!(Hook1, "hookOpBinary"))
        {
            // Delegate to rhs
            return mixin("this.payload" ~ op ~ "rhs");
        }
        else static if (hasMember!(Hook, "onOverflow") &&
            !hasMember!(Hook1, "onOverflow"))
        {
            // Delegate to lhs
            return mixin("this" ~ op ~ "rhs.payload");
        }
        else static if (hasMember!(Hook1, "onOverflow") &&
            !hasMember!(Hook, "onOverflow"))
        {
            // Delegate to rhs
            return mixin("this.payload" ~ op ~ "rhs");
        }
        else
        {
            static assert(0, "Conflict between lhs and rhs hooks," ~
                " use .representation on one side to disambiguate.");
        }
    }

    // opBinaryRight
    /**
    */
    auto opBinaryRight(string op, Lhs)(const Lhs lhs)
    if (isIntegral!Lhs || isFloatingPoint!Lhs || is(Lhs == bool))
    {
        static if (hasMember!(Hook, "hookOpBinaryRight"))
        {
            auto r = hook.hookOpBinaryRight!op(lhs, payload);
            return Checked!(typeof(r), Hook)(r);
        }
        else static if (hasMember!(Hook, "hookOpBinary"))
        {
            auto r = hook.hookOpBinary!op(lhs, payload);
            return Checked!(typeof(r), Hook)(r);
        }
        else static if (is(Lhs == bool))
        {
            return mixin("ubyte(lhs)" ~ op ~ "this");
        }
        else static if (isFloatingPoint!Lhs)
        {
            return mixin("lhs" ~ op ~ "payload");
        }
        else static if (hasMember!(Hook, "onOverflow"))
        {
            bool overflow;
            auto r = opChecked!op(lhs, T(payload), overflow);
            if (overflow) r = hook.onOverflow!op(42);
            return Checked!(typeof(r), Hook)(r);
        }
        else
        {
            // Default is built-in behavior
            auto r = mixin("lhs" ~ op ~ "T(payload)");
            return Checked!(typeof(r), Hook)(r);
        }
    }

    // opOpAssign
    /**
    */
    ref Checked opOpAssign(string op, Rhs)(const Rhs rhs)
    if (isIntegral!Rhs || isFloatingPoint!Rhs || is(Rhs == bool))
    {
        static assert(is(typeof(mixin("payload" ~ op ~ "=rhs")) == T));

        static if (hasMember!(Hook, "hookOpOpAssign"))
        {
            hook.hookOpOpAssign!op(payload, rhs);
        }
        else
        {
            alias R = typeof(payload + rhs);
            auto r = mixin("this" ~ op ~ "rhs").payload;

            static if (valueConvertible!(R, T) ||
                !hasMember!(Hook, "onBadOpOpAssign") ||
                op.among(">>", ">>>"))
            {
                // No need to check these
                payload = cast(T) r;
            }
            else
            {
                static if (isUnsigned!T && !isUnsigned!R)
                {
                    // Example: ushort += int
                    import std.conv : unsigned;
                    const bad = unsigned(r) > max.payload;
                }
                else
                    // Some narrowing is afoot
                    static if (R.min < min.payload)
                        // Example: int += long
                        const bad = r > max.payload || r < min.payload;
                    else
                        // Example: uint += ulong
                        const bad = r > max.payload;
                if (bad)
                    payload = hook.onBadOpOpAssign!op(payload, Rhs(rhs));
                else
                    payload = cast(T) r;
            }
        }
        return this;
    }
}

// representation
unittest
{
    assert(Checked!(ubyte, void)(ubyte(22)).representation == 22);
}

// Abort
/**
Force all overflows to fail with `assert(0)`.
*/
struct Abort
{
    private static void abort(string msg)
    {
        import std.stdio : stderr;
        stderr.writeln(msg);
        import core.stdc.stdlib : abort;
        abort();
    }
static:
    Dst onBadCast(Dst, Src)(Src src)
    {
        abort("Bad cast");
        assert(0);
    }
    Lhs onBadOpOpAssign(string x, Lhs, Rhs)(Lhs, Rhs)
    {
        abort("Bad opAssign");
        assert(0);
    }
    bool onBadOpEquals(Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        abort("Bad comparison for equality");
        assert(0);
    }
    bool onBadOpCmp(Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        abort("Bad comparison for ordering");
        assert(0);
    }
    typeof(~Lhs()) onOverflow(string op, Lhs)(Lhs lhs)
    {
        abort("Overflow on unary \"" ~ op ~ "\"");
        assert(0);
    }
    typeof(Lhs() + Rhs()) onOverflow(string op, Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        abort("Overflow on binary \"" ~ op ~ "\"");
        assert(0);
    }
}

unittest
{
    Checked!(int, Abort) x;
    x = 42;
    short x1 = cast(short) x;
    //x += long(int.max);
}

// ProperCompare
/**

Implements a hook that provides arithmetically correct comparisons for equality
and ordering. Comparing an object of type $(D Checked!(X, ProperCompare))
against another integral (for equality or ordering) ensures that no surprising
conversions from signed to unsigned integral occur before the comparison. Using
$(D Checked!(X, ProperCompare)) on either side of a comparison for equality
against a floating-point number makes sure the integral can be properly
converted to the floating point type, thus making sure equality is transitive.

*/
struct ProperCompare
{
    /**
    Hook for `==` and `!=` that ensures comparison against integral values has
    the behavior expected by the usual arithmetic rules. The built-in semantics
    yield surprising behavior when comparing signed values against unsigned
    values for equality, for example $(D uint.max == -1) or $(D -1_294_967_296 ==
    3_000_000_000u). The call $(D hookOpEquals(x, y)) returns `true` if and only
    if `x` and `y` represent the same arithmetic number.

    If one of the numbers is an integral and the other is a floating-point
    number, $(D hookOpEquals(x, y)) returns `true` if and only if the integral
    can be converted exactly (without approximation) to the floating-point
    number. This is in order to preserve transitivity of equality: if $(D
    hookOpEquals(x, y)) and $(D hookOpEquals(y, z)) then $(D hookOpEquals(y,
    z)), in case `x`, `y`, and `z` are a mix of integral and floating-point
    numbers.
    */
    static bool hookOpEquals(L, R)(L lhs, R rhs)
    {
        alias C = typeof(lhs + rhs);
        static if (isFloatingPoint!C)
        {
            static if (!isFloatingPoint!L)
            {
                return hookOpEquals(rhs, lhs);
            }
            else static if (!isFloatingPoint!R)
            {
                static assert(isFloatingPoint!L && !isFloatingPoint!R);
                auto rhs1 = C(rhs);
                return lhs == rhs1 && cast(R) rhs1 == rhs;
            }
            else
                return lhs == rhs;
        }
        else static if (valueConvertible!(L, C) && valueConvertible!(R, C))
        {
            // Values are converted to R before comparison, cool.
            return lhs == rhs;
        }
        else
        {
            static assert(isUnsigned!C);
            static assert(isUnsigned!L != isUnsigned!R);
            if (lhs != rhs) return false;
            // R(lhs) and R(rhs) have the same bit pattern, yet may be
            // different due to signedness change.
            static if (!isUnsigned!R)
            {
                if (rhs >= 0)
                    return true;
            }
            else
            {
                if (lhs >= 0)
                    return true;
            }
            return false;
        }
    }

    /**
    Hook for `<`, `<=`, `>`, and `>=` that ensures comparison against integral
    values has the behavior expected by the usual arithmetic rules. The built-in
    semantics yield surprising behavior when comparing signed values against
    unsigned values, for example $(D 0u < -1). The call $(D hookOpCmp(x, y))
    returns `-1` if and only if `x` is smaller than `y` in abstract arithmetic
    sense.

    If one of the numbers is an integral and the other is a floating-point
    number, $(D hookOpEquals(x, y)) returns a floating-point number that is `-1`
    if `x < y`, `0` if `x == y`, `1` if `x > y`, and `NaN` if the floating-point
    number is `NaN`.
    */
    static auto hookOpCmp(L, R)(L lhs, R rhs)
    {
        alias C = typeof(lhs + rhs);
        static if (isFloatingPoint!C)
        {
            return lhs < rhs
                ? C(-1)
                : lhs > rhs ? C(1) : lhs == rhs ? C(0) : C.init;
        }
        else
        {
            static if (!valueConvertible!(L, C) || !valueConvertible!(R, C))
            {
                static assert(isUnsigned!C);
                static assert(isUnsigned!L != isUnsigned!R);
                if (!isUnsigned!L && lhs < 0)
                    return -1;
                if (!isUnsigned!R && rhs < 0)
                    return 1;
            }
            return lhs < rhs ? -1 : lhs > rhs;
        }
    }
}

///
unittest
{
    alias opEqualsProper = ProperCompare.hookOpEquals;
    assert(opEqualsProper(42, 42));
    assert(opEqualsProper(42u, 42));
    assert(opEqualsProper(42, 42u));
    assert(-1 == 4294967295u);
    assert(!opEqualsProper(-1, 4294967295u));
    assert(!opEqualsProper(uint(-1), -1));
    assert(!opEqualsProper(uint(-1), -1.0));
    assert(3_000_000_000U == -1_294_967_296);
    assert(!opEqualsProper(3_000_000_000U, -1_294_967_296));
}

unittest
{
    alias opCmpProper = ProperCompare.hookOpCmp;
    assert(opCmpProper(42, 42) == 0);
    assert(opCmpProper(42u, 42) == 0);
    assert(opCmpProper(42, 42u) == 0);
    assert(opCmpProper(-1, uint(-1)) < 0);
    assert(opCmpProper(uint(-1), -1) > 0);
    assert(opCmpProper(-1.0, -1) == 0);
}

unittest
{
    auto x1 = Checked!(uint, ProperCompare)(42u);
    assert(x1.representation < -1);
    assert(x1 > -1);
}

// WithNaN
/**
*/
struct WithNaN
{
static:
    enum defaultValue(T) = T.min == 0 ? T.max : T.min;
    enum max(T) = cast(T) (T.min == 0 ? T.max - 1 : T.max);
    enum min(T) = cast(T) (T.min == 0 ? T(0) : T.min + 1);
    Lhs hookOpCast(Lhs, Rhs)(Rhs rhs)
    {
        static if (is(Lhs == bool))
        {
            return rhs != defaultValue!Rhs && rhs != 0;
        }
        else static if (valueConvertible!(Rhs, Lhs))
        {
            return rhs != defaultValue!Rhs ? Lhs(rhs) : defaultValue!Lhs;
        }
        else
        {
            if (isUnsigned!Rhs || !isUnsigned!Lhs ||
                    Rhs.sizeof > Lhs.sizeof || rhs >= 0)
            {
                auto result = cast(Lhs) rhs;
                // If signedness is different, we need additional checks
                if (result == rhs &&
                        (!isUnsigned!Rhs || isUnsigned!Lhs || result >= 0))
                    return result;
            }
            return defaultValue!Lhs;
        }
    }
    Lhs onBadOpOpAssign(string x, Lhs, Rhs)(Lhs, Rhs)
    {
        return defaultValue!Lhs;
    }
    bool hookOpEquals(Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        return lhs != defaultValue!Lhs && lhs == rhs;
    }
    double hookOpCmp(Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        if (lhs == defaultValue!Lhs) return double.init;
        return lhs < rhs
            ? -1.0
            : lhs > rhs ? 1.0 : lhs == rhs ? 0.0 : double.init;
    }
    auto hookOpUnary(string x, T)(ref T v)
    {
        static if (x == "-" || x == "~")
        {
            return v != defaultValue!T ? mixin(x ~ "v") : v;
        }
        else static if (x == "++")
        {
            static if (defaultValue!T == T.min)
            {
                if (v != defaultValue!T)
                {
                    if (v == T.max) v = defaultValue!T;
                    else ++v;
                }
            }
            else
            {
                static assert(defaultValue!T == T.max);
                if (v != defaultValue!T) ++v;
            }
        }
        else static if (x == "-")
        {
            if (v != defaultValue!T) --v;
        }
    }
    auto hookOpBinary(string x, L, R)(L lhs, R rhs)
    {
        alias Result = typeof(lhs + rhs);
        if (lhs != defaultValue!L)
        {
            bool error;
            auto result = opChecked!x(lhs, rhs, error);
            if (!error) return result;
        }
        return defaultValue!Result;
    }
    auto hookOpBinaryRight(string x, L, R)(L lhs, R rhs)
    {
        alias Result = typeof(lhs + rhs);
        if (rhs != defaultValue!R)
        {
            bool error;
            auto result = opChecked!x(lhs, rhs, error);
            if (!error) return result;
        }
        return defaultValue!Result;
    }
    void hookOpOpAssign(string x, L, R)(ref L lhs, R rhs)
    {
        if (lhs == defaultValue!L)
            return;
        bool error;
        auto temp = opChecked!x(lhs, rhs, error);
        lhs = error
            ? defaultValue!L
            : hookOpCast!L(temp);
    }
}

///
unittest
{
    auto x1 = Checked!(int, WithNaN)();
    assert(x1.representation == int.min);
    assert(x1 != x1);
    assert(!(x1 < x1));
    assert(!(x1 > x1));
    assert(!(x1 == x1));
    ++x1;
    assert(x1.representation == int.min);
    --x1;
    assert(x1.representation == int.min);
    x1 = 42;
    assert(x1 == x1);
    assert(x1 <= x1);
    assert(x1 >= x1);
    static assert(x1.min == int.min + 1);
    x1 += long(int.max);
}

unittest
{
    alias Smart(T) = Checked!(Checked!(T, ProperCompare), WithNaN);
    Smart!int x1;
    assert(x1 != x1);
    x1 = -1;
    assert(x1 < 1u);
    auto x2 = Smart!int(42);
}

/*
Yields `true` if `T1` is "value convertible" (using terminology from C) to
`T2`, where the two are integral types. That is, all of values in `T1` are
also in `T2`. For example `int` is value convertible to `long` but not to
`uint` or `ulong`.
*/
/*
private enum valueConvertible(T1, T2) = isIntegral!T1 && isIntegral!T2 &&
    is(T1 : T2) && (
        isUnsigned!T1 == isUnsigned!T2 || // same signedness
        !isUnsigned!T2 && T2.sizeof > T1.sizeof // safely convertible
    );
*/
template valueConvertible(T1, T2)
{
    static if (!isIntegral!T1 || !isIntegral!T2)
    {
        enum bool valueConvertible = false;
    }
    else
    {
        enum bool valueConvertible = is(T1 : T2) && (
            isUnsigned!T1 == isUnsigned!T2 || // same signedness
            !isUnsigned!T2 && T2.sizeof > T1.sizeof // safely convertible
        );
    }
}

/**

Defines binary operations with overflow checking for any two integral types.
The result type obeys the language rules (even when they may be
counterintuitive), and `overflow` is set if an overflow occurs (including
inadvertent change of signedness, e.g. `-1` is converted to `uint`).
Conceptually the behavior is:

$(OL $(LI Perform the operation in infinite precision)
$(LI If the infinite-precision result fits in the result type, return it and
do not touch `overflow`)
$(LI Otherwise, set `overflow` to `true` and return an unspecified value)
)

The implementation exploits properties of types and operations to minimize
additional work.

*/
typeof(L() + R()) opChecked(string x, L, R)(const L lhs, const R rhs,
    ref bool error)
if (isIntegral!L && isIntegral!R)
{
    alias Result = typeof(lhs + rhs);
    import core.checkedint;
    import std.algorithm.comparison : among;
    static if (x.among("<<", ">>", ">>>"))
    {
        // Handle shift separately from all others. The test below covers
        // negative rhs as well.
        import std.conv : unsigned;
        if (unsigned(rhs) > 8 * Result.sizeof) goto fail;
        return mixin("lhs" ~ x ~ "rhs");
    }
    else static if (x.among("&", "|", "^"))
    {
        // Nothing to check
        return mixin("lhs" ~ x ~ "rhs");
    }
    else static if (x == "^^")
    {
        // Exponentiation is weird, handle separately
        return pow(lhs, rhs, error);
    }
    else static if (valueConvertible!(L, Result) &&
            valueConvertible!(R, Result))
    {
        static if (L.sizeof < Result.sizeof && R.sizeof < Result.sizeof &&
            x.among("+", "-", "*"))
        {
            // No checks - both are value converted and result is in range
            return mixin("lhs" ~ x ~ "rhs");
        }
        else static if (x == "+")
        {
            static if (isUnsigned!Result) alias impl = addu;
            else alias impl = adds;
            return impl(Result(lhs), Result(rhs), error);
        }
        else static if (x == "-")
        {
            static if (isUnsigned!Result) alias impl = subu;
            else alias impl = subs;
            return impl(Result(lhs), Result(rhs), error);
        }
        else static if (x == "*")
        {
            static if (!isUnsigned!L && !isUnsigned!R &&
                is(L == Result))
            {
                if (lhs == Result.min && rhs == -1) goto fail;
            }
            static if (isUnsigned!Result) alias impl = mulu;
            else alias impl = muls;
            return impl(Result(lhs), Result(rhs), error);
        }
        else static if (x == "/" || x == "%")
        {
            static if (!isUnsigned!L && !isUnsigned!R &&
                is(L == Result) && op == "/")
            {
                if (lhs == Result.min && rhs == -1) goto fail;
            }
            if (rhs == 0) goto fail;
            return mixin("lhs" ~ x ~ "rhs");
        }
        else static assert(0, x);
    }
    else // Mixed signs
    {
        static assert(isUnsigned!Result);
        static assert(isUnsigned!L != isUnsigned!R);
        static if (x == "+")
        {
            static if (!isUnsigned!L)
            {
                if (lhs < 0)
                    return subu(Result(rhs), Result(-lhs), error);
            }
            else static if (!isUnsigned!R)
            {
                if (rhs < 0)
                    return subu(Result(lhs), Result(-rhs), error);
            }
            return addu(Result(lhs), Result(rhs), error);
        }
        else static if (x == "-")
        {
            static if (!isUnsigned!L)
            {
                if (lhs < 0) goto fail;
            }
            else static if (!isUnsigned!R)
            {
                if (rhs < 0)
                    return addu(Result(lhs), Result(-rhs), error);
            }
            return subu(Result(lhs), Result(rhs), error);
        }
        else static if (x == "*")
        {
            static if (!isUnsigned!L)
            {
                if (lhs < 0) goto fail;
            }
            else static if (!isUnsigned!R)
            {
                if (rhs < 0) goto fail;
            }
            return mulu(Result(lhs), Result(rhs), error);
        }
        else static if (x == "/" || x == "%")
        {
            static if (!isUnsigned!L)
            {
                if (lhs < 0 || rhs == 0) goto fail;
            }
            else static if (!isUnsigned!R)
            {
                if (rhs <= 0) goto fail;
            }
            return mixin("Result(lhs)" ~ x ~ "Result(rhs)");
        }
        else static assert(0, x);
    }
    debug assert(false);
fail:
    error = true;
    return 0;
}

///
unittest
{
    bool overflow;
    assert(opChecked!"+"(short(1), short(1), overflow) == 2 && !overflow);
    assert(opChecked!"+"(1, 1, overflow) == 2 && !overflow);
    assert(opChecked!"+"(1, 1u, overflow) == 2 && !overflow);
    assert(opChecked!"+"(-1, 1u, overflow) == 0 && !overflow);
    assert(opChecked!"+"(1u, -1, overflow) == 0 && !overflow);
}

///
unittest
{
    bool overflow;
    assert(opChecked!"-"(1, 1, overflow) == 0 && !overflow);
    assert(opChecked!"-"(1, 1u, overflow) == 0 && !overflow);
    assert(opChecked!"-"(1u, -1, overflow) == 2 && !overflow);
    assert(opChecked!"-"(-1, 1u, overflow) == 0 && overflow);
}

unittest
{
    bool overflow;
    assert(opChecked!"*"(2, 3, overflow) == 6 && !overflow);
    assert(opChecked!"*"(2, 3u, overflow) == 6 && !overflow);
    assert(opChecked!"*"(1u, -1, overflow) == 0 && overflow);
    //assert(mul(-1, 1u, overflow) == uint.max - 1 && overflow);
}

unittest
{
    bool overflow;
    assert(opChecked!"/"(6, 3, overflow) == 2 && !overflow);
    assert(opChecked!"/"(6, 3, overflow) == 2 && !overflow);
    assert(opChecked!"/"(6u, 3, overflow) == 2 && !overflow);
    assert(opChecked!"/"(6, 3u, overflow) == 2 && !overflow);
    assert(opChecked!"/"(11, 0, overflow) == 0 && overflow);
    overflow = false;
    assert(opChecked!"/"(6u, 0, overflow) == 0 && overflow);
    overflow = false;
    assert(opChecked!"/"(-6, 2u, overflow) == 0 && overflow);
    overflow = false;
    assert(opChecked!"/"(-6, 0u, overflow) == 0 && overflow);
}

/**
*/
private pure @safe nothrow @nogc
auto pow(L, R)(const L lhs, const R rhs, ref bool overflow)
if (isIntegral!L && isIntegral!R)
{
    if (rhs <= 1)
    {
        if (rhs == 0) return 1;
        static if (!isUnsigned!R)
            return rhs == 1
                ? lhs
                : (rhs == -1 && (lhs == 1 || lhs == -1)) ? lhs : 0;
        else
            return lhs;
    }

    typeof(lhs ^^ rhs) b = void;
    static if (!isUnsigned!L && isUnsigned!(typeof(b)))
    {
        // Need to worry about mixed-sign stuff
        if (lhs < 0)
        {
            if (rhs & 1)
            {
                if (lhs < 0) overflow = true;
                return 0;
            }
            b = -lhs;
        }
        else
        {
            b = lhs;
        }
    }
    else
    {
        b = lhs;
    }
    if (b == 1) return 1;
    if (b == -1) return (rhs & 1) ? -1 : 1;
    if (rhs > 63)
    {
        overflow = true;
        return 0;
    }

    assert((b > 1 || b < -1) && rhs > 1);
    return powImpl(b, cast(uint) rhs, overflow);
}

// Inspiration: http://www.stepanovpapers.com/PAM.pdf
pure @safe nothrow @nogc
private T powImpl(T)(T b, uint e, ref bool overflow)
if (isIntegral!T && T.sizeof >= 4)
{
    assert(e > 1);

    import core.checkedint : muls, mulu;
    static if (isUnsigned!T) alias mul = mulu;
    else alias mul = muls;

    T r = b;
    --e;
    // Loop invariant: r * (b ^^ e) is the actual result
    for (;; e /= 2)
    {
        if (e % 2)
        {
            r = mul(r, b, overflow);
            if (e == 1) break;
        }
        b = mul(b, b, overflow);
    }
    return r;
}

unittest
{
    static void testPow(T)(T x, uint e)
    {
        bool overflow;
        assert(opChecked!"^^"(T(0), 0, overflow) == 1);
        assert(opChecked!"^^"(-2, T(0), overflow) == 1);
        assert(opChecked!"^^"(-2, T(1), overflow) == -2);
        assert(opChecked!"^^"(-1, -1, overflow) == -1);
        assert(opChecked!"^^"(-2, 1, overflow) == -2);
        assert(opChecked!"^^"(-2, -1, overflow) == 0);
        assert(opChecked!"^^"(-2, 4u, overflow) == 16);
        assert(!overflow);
        assert(opChecked!"^^"(-2, 3u, overflow) == 0);
        assert(overflow);
        overflow = false;
        assert(opChecked!"^^"(3, 64u, overflow) == 0);
        assert(overflow);
        overflow = false;
        foreach (uint i; 0 .. e)
        {
            assert(opChecked!"^^"(x, i, overflow) == x ^^ i);
            assert(!overflow);
        }
        assert(opChecked!"^^"(x, e, overflow) == x ^^ e);
        assert(overflow);
    }

    testPow!int(3, 21);
    testPow!uint(3, 21);
    testPow!long(3, 40);
    testPow!ulong(3, 41);
}

version(unittest) private struct CountOverflows
{
    uint calls;
    auto onOverflow(string op, Lhs)(Lhs lhs)
    {
        ++calls;
        return mixin(op ~ "lhs");
    }
    auto onOverflow(string op, Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        ++calls;
        return mixin("lhs" ~ op ~ "rhs");
    }
    Lhs onBadOpOpAssign(string op, Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        ++calls;
        return mixin("lhs" ~ op ~ "=rhs");
    }
}

version(unittest) private struct CountOpBinary
{
    uint calls;
    auto hookOpBinary(string op, Lhs, Rhs)(Lhs lhs, Rhs rhs)
    {
        ++calls;
        return mixin("lhs" ~ op ~ "rhs");
    }
}

// opBinary
@nogc nothrow pure @safe unittest
{
    auto x = Checked!(int, void)(42), y = Checked!(int, void)(142);
    assert(x + y == 184);
    assert(x + 100 == 142);
    assert(y - x == 100);
    assert(200 - x == 158);
    assert(y * x == 142 * 42);
    assert(x / 1 == 42);
    assert(x % 20 == 2);

    auto x1 = Checked!(int, CountOverflows)(42);
    assert(x1 + 0 == 42);
    assert(x1 + false == 42);
    assert(is(typeof(x1 + 0.5) == double));
    assert(x1 + 0.5 == 42.5);
    assert(x1.hook.calls == 0);
    assert(x1 + int.max == int.max + 42);
    assert(x1.hook.calls == 1);
    assert(x1 * 2 == 84);
    assert(x1.hook.calls == 1);
    assert(x1 / 2 == 21);
    assert(x1.hook.calls == 1);
    assert(x1 % 20 == 2);
    assert(x1.hook.calls == 1);
    assert(x1 << 2 == 42 << 2);
    assert(x1.hook.calls == 1);
    assert(x1 << 42 == x1.representation << x1.representation);
    assert(x1.hook.calls == 2);

    auto x2 = Checked!(int, CountOpBinary)(42);
    assert(x2 + 1 == 43);
    assert(x2.hook.calls == 1);

    auto x3 = Checked!(uint, CountOverflows)(42u);
    assert(x3 + 1 == 43);
    assert(x3.hook.calls == 0);
    assert(x3 - 1 == 41);
    assert(x3.hook.calls == 0);
    assert(x3 + (-42) == 0);
    assert(x3.hook.calls == 0);
    assert(x3 - (-42) == 84);
    assert(x3.hook.calls == 0);
    assert(x3 * 2 == 84);
    assert(x3.hook.calls == 0);
    assert(x3 * -2 == -84);
    assert(x3.hook.calls == 1);
    assert(x3 / 2 == 21);
    assert(x3.hook.calls == 1);
    assert(x3 / -2 == 0);
    assert(x3.hook.calls == 2);
    assert(x3 ^^ 2 == 42 * 42);
    assert(x3.hook.calls == 2);

    auto x4 = Checked!(int, CountOverflows)(42);
    assert(x4 + 1 == 43);
    assert(x4.hook.calls == 0);
    assert(x4 + 1u == 43);
    assert(x4.hook.calls == 0);
    assert(x4 - 1 == 41);
    assert(x4.hook.calls == 0);
    assert(x4 * 2 == 84);
    assert(x4.hook.calls == 0);
    x4 = -2;
    assert(x4 + 2u == 0);
    assert(x4.hook.calls == 0);
    assert(x4 * 2u == -4);
    assert(x4.hook.calls == 1);

    auto x5 = Checked!(int, CountOverflows)(3);
    assert(x5 ^^ 0 == 1);
    assert(x5 ^^ 1 == 3);
    assert(x5 ^^ 2 == 9);
    assert(x5 ^^ 3 == 27);
    assert(x5 ^^ 4 == 81);
    assert(x5 ^^ 5 == 81 * 3);
    assert(x5 ^^ 6 == 81 * 9);
}

// opBinaryRight
@nogc nothrow pure @safe unittest
{
    auto x1 = Checked!(int, CountOverflows)(42);
    assert(1 + x1 == 43);
    assert(true + x1 == 43);
    assert(0.5 + x1 == 42.5);
    auto x2 = Checked!(int, void)(42);
    assert(x1 + x2 == 84);
    assert(x2 + x1   == 84);
}

// opOpAssign
unittest
{
    auto x1 = Checked!(int, CountOverflows)(3);
    assert((x1 += 2) == 5);
    x1 *= 2_000_000_000L;
    assert(x1.hook.calls == 1);

    auto x2 = Checked!(ushort, CountOverflows)(ushort(3));
    assert((x2 += 2) == 5);
    assert(x2.hook.calls == 0);
    assert((x2 += ushort.max) == cast(ushort) (ushort(5) + ushort.max));
    assert(x2.hook.calls == 1);

    auto x3 = Checked!(uint, CountOverflows)(3u);
    x3 *= ulong(2_000_000_000);
    assert(x3.hook.calls == 1);
}

// opAssign
unittest
{
    Checked!(int, void) x;
    x = 42;
    assert(x.representation == 42);
    x = x;
    assert(x.representation == 42);
    x = short(43);
    assert(x.representation == 43);
    x = ushort(44);
    assert(x.representation == 44);
}

unittest
{
    static assert(!is(typeof(Checked!(short, void)(ushort(42)))));
    static assert(!is(typeof(Checked!(int, void)(long(42)))));
    static assert(!is(typeof(Checked!(int, void)(ulong(42)))));
    assert(Checked!(short, void)(short(42)).representation == 42);
    assert(Checked!(int, void)(ushort(42)).representation == 42);
}

// opCast
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(cast(float) Checked!(int, void)(42)) == float));
    assert(cast(float) Checked!(int, void)(42) == 42);

    assert(is(typeof(cast(long) Checked!(int, void)(42)) == long));
    assert(cast(long) Checked!(int, void)(42) == 42);
    static assert(is(typeof(cast(long) Checked!(uint, void)(42u)) == long));
    assert(cast(long) Checked!(uint, void)(42u) == 42);

    auto x = Checked!(int, void)(42);
    if (x) {} else assert(0);
    x = 0;
    if (x) assert(0);

    static struct Hook1
    {
        uint calls;
        Dst hookOpCast(Dst, Src)(Src value)
        {
            ++calls;
            return 42;
        }
    }
    auto y = Checked!(long, Hook1)(long.max);
    assert(cast(int) y == 42);
    assert(cast(uint) y == 42);
    assert(y.hook.calls == 2);

    static struct Hook2
    {
        uint calls;
        Dst onBadCast(Dst, Src)(Src value)
        {
            ++calls;
            return 42;
        }
    }
    auto x1 = Checked!(uint, Hook2)(100u);
    assert(cast(ushort) x1 == 100);
    assert(cast(short) x1 == 100);
    assert(cast(float) x1 == 100);
    assert(cast(double) x1 == 100);
    assert(cast(real) x1 == 100);
    assert(x1.hook.calls == 0);
    assert(cast(int) x1 == 100);
    assert(x1.hook.calls == 0);
    x1 = uint.max;
    assert(cast(int) x1 == 42);
    assert(x1.hook.calls == 1);

    auto x2 = Checked!(int, Hook2)(-100);
    assert(cast(short) x2 == -100);
    assert(cast(ushort) x2 == 42);
    assert(cast(uint) x2 == 42);
    assert(cast(ulong) x2 == 42);
    assert(x2.hook.calls == 3);
}

// opEquals
@nogc nothrow pure @safe unittest
{
    assert(Checked!(int, void)(42) == 42L);
    assert(42UL == Checked!(int, void)(42));

    static struct Hook1
    {
        uint calls;
        bool hookOpEquals(Lhs, Rhs)(const Lhs lhs, const Rhs rhs)
        {
            ++calls;
            return lhs != rhs;
        }
    }
    auto x1 = Checked!(int, Hook1)(100);
    assert(x1 != Checked!(long, Hook1)(100));
    assert(x1.hook.calls == 1);
    assert(x1 != 100u);
    assert(x1.hook.calls == 2);

    static struct Hook2
    {
        uint calls;
        bool hookOpEquals(Lhs, Rhs)(Lhs lhs, Rhs rhs)
        {
            ++calls;
            return false;
        }
    }
    auto x2 = Checked!(int, Hook2)(-100);
    assert(x2 != -100);
    assert(x2.hook.calls == 1);
    assert(x2 != cast(uint) -100);
    assert(x2.hook.calls == 2);
    x2 = 100;
    assert(x2 != cast(uint) 100);
    assert(x2.hook.calls == 3);
    x2 = -100;

    auto x3 = Checked!(uint, Hook2)(100u);
    assert(x3 != 100);
    x3 = uint.max;
    assert(x3 != -1);

    assert(x2 != x3);
}

// opCmp
@nogc nothrow pure @safe unittest
{
    Checked!(int, void) x;
    assert(x <= x);
    assert(x < 45);
    assert(x < 45u);
    assert(x > -45);
    assert(x < 44.2);
    assert(x > -44.2);
    assert(!(x < double.init));
    assert(!(x > double.init));
    assert(!(x <= double.init));
    assert(!(x >= double.init));

    static struct Hook1
    {
        uint calls;
        int hookOpCmp(Lhs, Rhs)(Lhs lhs, Rhs rhs)
        {
            ++calls;
            return 0;
        }
    }
    auto x1 = Checked!(int, Hook1)(42);
    assert(!(x1 < 43u));
    assert(!(43u < x1));
    assert(x1.hook.calls == 2);

    static struct Hook2
    {
        uint calls;
        int hookOpCmp(Lhs, Rhs)(Lhs lhs, Rhs rhs)
        {
            ++calls;
            return ProperCompare.hookOpCmp(lhs, rhs);
        }
    }
    auto x2 = Checked!(int, Hook2)(-42);
    assert(x2 < 43u);
    assert(43u > x2);
    assert(x2.hook.calls == 2);
    x2 = 42;
    assert(x2 > 41u);

    auto x3 = Checked!(uint, Hook2)(42u);
    assert(x3 > 41);
    assert(x3 > -41);
}

// opUnary
@nogc nothrow pure @safe unittest
{
    auto x = Checked!(int, void)(42);
    assert(x == +x);
    static assert(is(typeof(-x) == typeof(x)));
    assert(-x == Checked!(int, void)(-42));
    static assert(is(typeof(~x) == typeof(x)));
    assert(~x == Checked!(int, void)(~42));
    assert(++x == 43);
    assert(--x == 42);

    static struct Hook1
    {
        uint calls;
        auto hookOpUnary(string op, T)(T value) if (op == "-")
        {
            ++calls;
            return T(42);
        }
        auto hookOpUnary(string op, T)(T value) if (op == "~")
        {
            ++calls;
            return T(43);
        }
    }
    auto x1 = Checked!(int, Hook1)(100);
    assert(is(typeof(-x1) == typeof(x1)));
    assert(-x1 == Checked!(int, Hook1)(42));
    assert(is(typeof(~x1) == typeof(x1)));
    assert(~x1 == Checked!(int, Hook1)(43));
    assert(x1.hook.calls == 2);

    static struct Hook2
    {
        uint calls;
        auto hookOpUnary(string op, T)(ref T value) if (op == "++")
        {
            ++calls;
            --value;
        }
        auto hookOpUnary(string op, T)(ref T value) if (op == "--")
        {
            ++calls;
            ++value;
        }
    }
    auto x2 = Checked!(int, Hook2)(100);
    assert(++x2 == 99);
    assert(x2 == 99);
    assert(--x2 == 100);
    assert(x2 == 100);

    auto x3 = Checked!(int, CountOverflows)(int.max - 1);
    assert(++x3 == int.max);
    assert(x3.hook.calls == 0);
    assert(++x3 == int.min);
    assert(x3.hook.calls == 1);
    assert(-x3 == int.min);
    assert(x3.hook.calls == 2);

    x3 = int.min + 1;
    assert(--x3 == int.min);
    assert(x3.hook.calls == 2);
    assert(--x3 == int.max);
    assert(x3.hook.calls == 3);
}

//
@nogc nothrow pure @safe unittest
{
    Checked!(int, void) x;
    assert(x == x);
    assert(x == +x);
    assert(x == -x);
    ++x;
    assert(x == 1);
    x++;
    assert(x == 2);

    x = 42;
    assert(x == 42);
    short _short = 43;
    x = _short;
    assert(x == _short);
    ushort _ushort = 44;
    x = _ushort;
    assert(x == _ushort);
    assert(x == 44.0);
    assert(x != 44.1);
    assert(x < 45);
    assert(x < 44.2);
    assert(x > -45);
    assert(x > -44.2);

    assert(cast(long) x == 44);
    assert(cast(short) x == 44);

    Checked!(uint, void) y;
    assert(y <= y);
    assert(y == 0);
    assert(y < x);
    x = -1;
    assert(x > y);
}
