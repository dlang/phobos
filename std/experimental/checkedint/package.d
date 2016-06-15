/**
Checked integer arithmetic operations, functions, and types with improved handling of errors and corner cases compared
to the basic integral types.

$(B Note:) Normally this module should not be imported directly. Instead, import one of
$(MREF std,experimental,_checkedint, throws), $(MREF std,experimental,_checkedint, asserts), or
$(MREF std,experimental,_checkedint, noex), depending on which error signalling policy is needed. (See below.)

$(BIG $(B Problems solved by `checkedint`)) $(BR)
As in many other programming languages (C, C++, Java, etc.) D's basic integral types (such as `int` or `ulong`) are
surprisingly difficult to use correctly in the general case, due to variuos departures from the behaviour of ideal
mathematical integers:
$(UL
    $(LI Overflow silently wraps around: `assert(uint.max + 1 == 0);`)
    $(LI Mixed signed/unsigned comparisons often give the wrong result: `assert(-1 > 1u);`)
    $(LI Mixed signed/unsigned arithmetic operations can also give the wrong result.)
    $(LI Integer division by zero crashes the program with a mis-named and uncatchable `Floating Point Exception`
        (FPE).)
    $(LI `int.min / -1` and `int.min % -1` may also crash with an FPE, even though the latter should simply yield `0`.)
    $(LI If `x` is any integer value, and `y` is any negative integer value, `x ^^ y` will crash with an FPE.)
    $(LI No bounds checking is done when casting from one integer type to another.)
    $(LI The result of the bitshift operations (`<<`, `>>`, `>>>`) is formally undefined if the shift size is less
        than zero or greater than `(8 * N.sizeof) - 1`.)
)
The `checkedint` package offers solutions to all of these issues and more.

$(BIG $(B `SafeInt` versus `SmartInt`)) $(BR)
Two different approaches are available:
$(UL
    $(LI $(LREF SmartInt) and $(LREF smartOp) strive to actually give the mathematically correct answer whenever
        possible, rather than just signaling an error.)
    $(LI $(LREF SafeInt) and $(LREF safeOp) strive to match the behaviour of the basic integral types exactly,
        $(B except) that where the behaviour of the basic type is wrong, or very unintuitive, an error is signaled
        instead.)
)
There is no meaningful performance difference between `SafeInt` and `SmartInt`. For general use, choosing `SmartInt`
simplifies code and maximizes the range of inputs accepted.

`SafeInt` is intended mainly as a debugging tool, to help identify problems in code that must also work correctly with
the basic integral types. The $(LREF DebugInt) `template` `alias` makes it simple to use of `SafeInt` in debug builds,
and raw basic types in release builds.

$(TABLE
    $(TR $(TD)                $(TH `int` (basic type)) $(TH `SafeInt!int`)            $(TH `SmartInt!int`))
    $(TR $(TH `int.max + 1`)  $(TD `int.min`)          $(TD `raise(IntFlag.over)`)    $(TD `raise(IntFlag.over)`))
    $(TR $(TH `-1 > 1u`)      $(TD `true`)             $(TD compile-time error)       $(TD `false`))
    $(TR $(TH `-1 - 2u`)      $(TD `4294967293`)       $(TD compile-time error)       $(TD `-3`))
    $(TR $(TH `1 / 0`)        $(TD crash by FPE)       $(TD `raise(IntFlag.div0)`)    $(TD `raise(IntFlag.div0)`))
    $(TR $(TH `int.min % -1`) $(TD crash by FPE)       $(TD `raise(IntFlag.posOver)`) $(TD `0`))
    $(TR $(TH `-1 ^^ -7`)     $(TD crash by FPE)       $(TD `raise(IntFlag.undef)`)   $(TD `-1`))
    $(TR $(TH `cast(uint)-1`) $(TD `4294967295`)       $(TD compile-time error)       $(TD `raise(IntFlag.negOver)`))
    $(TR $(TH `-1 >> 100`)    $(TD undefined)          $(TD `raise(IntFlag.undef)`)   $(TD `-1`))
)

$(BIG $(B Error Signaling)) $(BR)
Some types of problem are signaled by a compile-time error, others at runtime. Runtime signaling is done through
$(MREF std,experimental,_checkedint, flags). Three different runtime signalling policies are available:
$(UL
    $(LI With `IntFlagPolicy.throws`, a `CheckedIntException` is thrown. These are normal exceptions; not FPEs. As
        such, they can be caught and include a stack trace.)
    $(LI With `IntFlagPolicy.asserts`, an assertion failure will be triggered. This policy is compatible with
        `pure nothrow @nogc` code, but will crash the program in the event of a runtime integer math error.)
    $(LI Alternatively, `IntFlagPolicy.noex` can be selected so that a thread-local flag is set when an operation fails.
        This allows `checkedint` to be used from `nothrow` and `@nogc` (but not `pure`) code without crashing the
        program, but requires the API user to manually insert checks of `IntFlags.local`.)
)
In normal code, there is no performance penalty for allowing `checkedint` to `throw`. Doing so is highly recommended
because this makes it easier to use correctly, and yields more precise error messages when something goes wrong.

$(BIG $(B Generic Code)) $(BR)
The $(MREF std,experimental,_checkedint, traits) module provides `checkedint`-aware versions of various numerical type
traits from `std.traits`, such as `Signed`, `isSigned` and `isIntegral`. This allows writing generic algorithms that
work with any of `SmartInt`, `SafeInt`, and the built-in numeric types such as `uint` and `long`.

Also of note is the $(LREF idx) function, which concisely and safely casts from any integral type (built-in, `SmartInt`, or
`SafeInt`) to either `size_t` or `ptrdiff_t` for easy array indexing.

$(BIG $(B Performance)) $(BR)
Replacing all basic integer types with `SmartInt` or `SafeInt` will slow down exectuion somewhat. How much depends on
many factors, but for most code following a few simple rules should keep the penalty low:
$(OL
    $(LI Build with $(LINK2 $(ROOT_DIR)dmd.html#switch-inline, $(B $(RED `-inline`))) and
        $(LINK2 $(ROOT_DIR)dmd.html#switch-O, $(B `-O`)) (DMD) or $(B `-O3`) (GDC and LDC). This by itself
        can improve the performance of `checkedint` by around $(B 1,000%).)
    $(LI With GDC or LDC, the performance hit in code that is bottlenecked by integer math will probably be between 30%
        and 100% on `x86_64`. The performance hit may be considerably larger with DMD, due to the weakness of the
        inliner.)
    $(LI `checkedint` can't slow down code where it's not used! For more speed, switch to
        $(LREF DebugInt) for the hottest code in the program (like inner loops) before giving up on `checkedint`
        entirely.)
)
The above guidelines should be more than sufficient for most programs. But, some micro-optimization are possible as
well, if needed:
$(UL
    $(LI Always use $(LREF smartOp.mulPow2), $(LREF smartOp.divPow2), and $(LREF smartOp.modPow2) whenever they can
        naturally express the intent - they're faster than a regular `/`, `%`, or `pow()`.)
    $(LI Unsigned types are a little bit faster than signed types, assuming negative values aren't needed.)
    $(LI Although they are perfectly safe with `checkedint`, mixed signed/unsigned operations are a little bit slower
        than same-signedness ones.)
    $(LI The assignment operators (`++` or `+=`, for example) should never be slower than the equivalent two operation
        sequence, and are sometimes a little bit faster.)
)

References: $(MREF core, _checkedint)

Copyright: Copyright Thomas Stuart Bockman 2015
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors: Thomas Stuart Bockman
Source:  $(PHOBOSSRC std/experimental/_checkedint/package.d)
**/
module std.experimental.checkedint;
import std.experimental.checkedint.flags;

import core.bitop, core.checkedint, std.algorithm, std.format, std.traits, std.typecons, std.meta;
static import std.math;

/+pragma(inline, true)
{+/
// smart /////////////////////////////////////////////////
    /**
    Wrapper for any basic integral type `N` that uses the checked operations from `smartOp` and bounds checks
    assignments with $(LREF to).

    $(UL
        $(LI `policy` controls the error signalling policy (see $(MREF std,experimental,_checkedint, flags)).)
        $(LI `bitOps` may be set to `No.bitOps` if desired, to turn bitwise operations on this type into a
            compile-time error.)
    )
    **/
    struct SmartInt(N, IntFlagPolicy _policy, Flag!"bitOps" bitOps = Yes.bitOps)
        if (isIntegral!N && is(N == Unqual!N))
    {
        /// The error signalling policy used by this `SmartInt` type.
        enum IntFlagPolicy policy = _policy;

        static if (bitOps)
        {
            /**
            The basic integral value of this `SmartInt`. Accessing this directly may be useful for:
            $(UL
                $(LI Intentionally doing modular (unchecked) arithmetic, or)
                $(LI Interacting with APIs that are not `checkedint` aware.)
            )
            **/
            N bscal;
            ///
            unittest
            {
                import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

                SmartInt!uint n;
                static assert(is(typeof(n.bscal) == uint));

                n = 7;
                assert(n.bscal == 7);

                n.bscal -= 8;
                assert(n == uint.max);
            }

            /// Get a view of this `SmartInt` that allows bitwise operations.
            @property ref inout(SmartInt!(N, policy, Yes.bitOps)) bits() return inout pure @safe nothrow @nogc
            {
                return this;
            }
            ///
            unittest
            {
                import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

                SmartInt!(int, No.bitOps) n = 1;
                static assert(!__traits(compiles, n << 2));
                assert(n.bits << 2 == 4);
            }
        }
        else
        {
            @property ref inout(N) bscal() return inout pure @safe nothrow @nogc
            {
                return bits.bscal;
            }
            SmartInt!(N, policy, Yes.bitOps) bits;
        }

        /// The most negative possible value of this `SmartInt` type.
        enum SmartInt!(N, policy, bitOps) min = typeof(this)(trueMin!N);
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

            assert(SmartInt!(int).min == int.min);
            assert(SmartInt!(uint).min == uint.min);
        }

        /// The most positive possible value of this `SmartInt` type.
        enum SmartInt!(N, policy, bitOps) max = typeof(this)(trueMax!N);
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws;

            assert(SmartInt!(int).max == int.max);
            assert(SmartInt!(uint).max == uint.max);
        }

        // Construction, assignment, and casting /////////////////////////////////////////////////
        /**
        Assign the value of `that` to this `SmartInt` instance.

        $(LREF to) is used to verify `that >= N.min && that <= N.max`. If not, an `IntFlag` will be raised.
        **/
        this(M)(const M that) @safe
            if (isCheckedInt!M || isScalarType!M)
        {
            this.bscal = to!(N, policy)(that);
        }
        /// ditto
        ref typeof(this) opAssign(M)(const M that) return @safe
            if (isCheckedInt!M || isScalarType!M)
        {
            this.bscal = to!(N, policy)(that);
            return this;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : SmartInt; // use IntFlagPolicy.noex

            // Any basic scalar or checkedint *type* is accepted...
            SmartInt!int n = 0;
            n = cast(ulong)0;
            n = cast(dchar)0;
            n = cast(byte)0;
            n = cast(real)0;
            assert(!IntFlags.local);

            // ...but not any *value*.
            n = uint.max;
            n = long.min;
            n = real.nan;
            assert(IntFlags.local.clear() == (IntFlag.posOver | IntFlag.negOver | IntFlag.undef));
        }

        /**
        Convert this value to floating-point. This always succeeds, although some loss of precision may
        occur if M.sizeof <= N.sizeof.
        **/
        M opCast(M)() const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return cast(M)bscal;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

            SmartInt!int n = 92;
            auto f = cast(double)n;
            static assert(is(typeof(f) == double));
            assert(f == 92.0);
        }

        /// `this != 0`
        M opCast(M)() const pure @safe nothrow @nogc
            if (is(M == bool))
        {
            return bscal != 0;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

            SmartInt!int n = -315;
            assert( cast(bool)n);

            n = 0;
            assert(!cast(bool)n);
        }

        /**
        Convert this value to type `M` using $(LREF to) for bounds checking. An `IntFlag` will be raised if
        `M` cannot represent the current value of this `SmartInt`.
        **/
        M opCast(M)() const @safe
            if (isCheckedInt!M || isIntegral!M || isSomeChar!M)
        {
            return to!(M, policy)(bscal);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : SmartInt; // use IntFlagPolicy.noex

            SmartInt!ulong n = 52;
            auto a = cast(int)n;
            static assert(is(typeof(a) == int));
            assert(!IntFlags.local);
            assert(a == 52);

            auto m = SmartInt!long(-1).mulPow2(n);
            auto b = cast(wchar)m;
            static assert(is(typeof(b) == wchar));
            assert(IntFlags.local.clear() == IntFlag.negOver);
        }

        /**
        Convert this value to a type suitable for indexing an array:
        $(UL
            $(LI If `N` is signed, a `ptrdiff_t` is returned.)
            $(LI If `N` is unsigned, a `size_t` is returned.)
        )
        $(LREF to) is used for bounds checking.
        **/
        @property Select!(isSigned!N, ptrdiff_t, size_t) idx() const @safe
        {
            return to!(typeof(return), policy)(bscal);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

            char[3] arr = ['a', 'b', 'c'];
            SmartInt!long n = 1;

            // On 32-bit, `long` cannot be used directly for array indexing,
            static if (size_t.sizeof < long.sizeof)
                static assert(!__traits(compiles, arr[n]));
            // but idx can be used to concisely and safely cast to ptrdiff_t:
            assert(arr[n.idx] == 'b');

            // The conversion is bounds checked:
            static if (size_t.sizeof < long.sizeof)
            {
                n = long.min;
                try
                {
                    arr[n.idx] = '?';
                }
                catch (CheckedIntException e)
                {
                    assert(e.intFlags == IntFlag.negOver);
                }
            }
        }

        /// Get a simple hashcode for this value.
        size_t toHash() const pure @safe nothrow @nogc
        {
            static if (N.sizeof > size_t.sizeof)
            {
                static assert(N.sizeof == (2 * size_t.sizeof));
                return cast(size_t)bscal ^ cast(size_t)(bscal >>> 32);
            }
            else
                return cast(size_t)bscal;
        }

        /// Get a `string` representation of this value.
        string toString() const @safe
        {
            return to!(string, IntFlagPolicy.noex)(bscal);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : smartInt; // use IntFlagPolicy.throws
            assert(smartInt(-753).toString() == "-753");
        }
        /**
        Puts a `string` representation of this value into `w`. This overload will not allocate, unless
        `std.range.primitives.put(w, ...)` allocates.

        Params:
            w = An output range that will receive the `string`
            fmt = An optional format specifier
        */
        void toString(Writer, Char = char)(Writer w, FormatSpec!Char fmt = (FormatSpec!Char).init) const
        {
            formatValue(w, bscal, fmt);
        }

        // Comparison /////////////////////////////////////////////////
        /// Returns `true` if this value is mathematically precisely equal to `right`.
        bool opEquals(M)(const M right) const pure @safe nothrow @nogc
            if (isCheckedInt!M || isScalarType!M)
        {
            return smartOp!(policy).cmp!"=="(this.bscal, right.bscal);
        }
        /**
        Perform a mathematically correct comparison to `right`.

        Returns: $(UL
            $(LI `-1` if this value is less than `right`.)
            $(LI ` 0` if this value is precisely equal to `right`.)
            $(LI ` 1` if this value is greater than `right`.)
            $(LI `float.nan` if `right` is a floating-point `nan` value.)
        )
        **/
        auto opCmp(M)(const M right) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return
                (bscal <  right)? -1 :
                (bscal >  right)?  1 :
                (bscal == right)?  0 : float.nan;
        }
        /// ditto
        int opCmp(M)(const M right) const pure @safe nothrow @nogc
            if (isCheckedInt!M || isScalarType!M)
        {
            return smartOp!(policy).cmp(this.bscal, right.bscal);
        }

        // Unary /////////////////////////////////////////////////
        /// See $(LREF smartOp).
        typeof(this) opUnary(string op)() const pure @safe nothrow @nogc
            if (op == "~")
        {
            static assert(bitOps,
                "Bitwise operations are disabled.");

            return typeof(return)(smartOp!(policy).unary!op(bscal));
        }
        /// ditto
        SmartInt!(Signed!N, policy, bitOps) opUnary(string op)() const @safe
            if (op == "+" || op == "-")
        {
            return typeof(return)(smartOp!(policy).unary!op(bscal));
        }
        /// ditto
        ref typeof(this) opUnary(string op)() return
            if (op.among!("++", "--"))
        {
            smartOp!(policy).unary!op(bscal);
            return this;
        }

        /// ditto
        SmartInt!(Unsigned!N, policy, bitOps) abs() const pure @safe nothrow @nogc
        {
            return typeof(return)(smartOp!(policy).abs(bscal));
        }

        /// Count the number of set bits using $(REF _popcnt, core,bitop).
        SmartInt!(int, policy, bitOps) popcnt()() const pure @safe nothrow @nogc
        {
            static assert(bitOps, "Bitwise operations are disabled.");

            import core.bitop : stdPC = popcnt;
            return typeof(return)(stdPC(bscal));
        }

        /// See $(LREF smartOp).
        SmartInt!(ubyte, policy, bitOps) bsf()() const @safe
        {
            static assert(bitOps, "Bitwise operations are disabled.");

            return typeof(return)(smartOp!(policy).bsf(bscal));
        }
        /// ditto
        SmartInt!(ubyte, policy, bitOps) bsr()() const @safe
        {
            static assert(bitOps, "Bitwise operations are disabled. Consider using ilogb() instead?");

            return typeof(return)(smartOp!(policy).bsr(bscal));
        }

        /// ditto
        SmartInt!(ubyte, policy, bitOps) ilogb() const @safe
        {
            return typeof(return)(smartOp!(policy).ilogb(bscal));
        }

        // Binary /////////////////////////////////////////////////
        /// ditto
        auto opBinaryRight(string op, M)(const M left) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return smartOp!(policy).binary!op(left, bscal);
        }
        /// ditto
        auto opBinary(string op, M)(const M right) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return smartOp!(policy).binary!op(bscal, right);
        }
        /// ditto
        auto opBinaryRight(string op, M)(const M left) const @safe
            if (isSafeInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            enum mixBitOps = bitOps && hasBitOps!M;
            static assert(mixBitOps || !op.among!("<<", ">>", ">>>", "&", "|", "^"),
                "Bitwise operations are disabled. Consider using mulPow2(), divPow2(), or modPow2() instead?");

            const wret = smartOp!(mixPolicy).binary!op(left.bscal, this.bscal);
            return SmartInt!(typeof(wret), mixPolicy, mixBitOps)(wret);
        }
        /// ditto
        auto opBinary(string op, M)(const M right) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            enum mixBitOps = bitOps && hasBitOps!M;
            static assert(mixBitOps || !op.among!("<<", ">>", ">>>", "&", "|", "^"),
                "Bitwise operations are disabled. Consider using mulPow2(), divPow2(), or modPow2() instead?");

            const wret = smartOp!(mixPolicy).binary!op(this.bscal, right.bscal);
            return SmartInt!(typeof(wret), mixPolicy, mixBitOps)(wret);
        }
        /// ditto
        ref typeof(this) opOpAssign(string op, M)(const M right) return
            if (isCheckedInt!M || isFixedPoint!M)
        {
            static assert((bitOps && hasBitOps!M) || !op.among!("<<", ">>", ">>>", "&", "|", "^"),
                "Bitwise operations are disabled. Consider using mulPow2(), divPow2(), or modPow2() instead?");

            smartOp!(.max(policy, intFlagPolicyOf!M)).binary!(op ~ "=")(this.bscal, right.bscal);
            return this;
        }

        /// ditto
        auto mulPow2(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return smartOp!(policy).mulPow2(bscal, exp);
        }
        /// ditto
        auto mulPow2(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = smartOp!(mixPolicy).mulPow2(this.bscal, exp.bscal);
            return SmartInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }
        /// ditto
        auto divPow2(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return smartOp!(policy).divPow2(bscal, exp);
        }
        /// ditto
        auto divPow2(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = smartOp!(mixPolicy).divPow2(this.bscal, exp.bscal);
            return SmartInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }
        /// ditto
        auto modPow2(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return smartOp!(policy).modPow2(bscal, exp);
        }
        /// ditto
        auto modPow2(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = smartOp!(mixPolicy).modPow2(this.bscal, exp.bscal);
            return SmartInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }

        /// Raise `this` to the `exp` power using $(REF _pow, std,math).
        auto pow(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return std.math.pow(bscal, exp);
        }
        /// See $(LREF smartOp).
        auto pow(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = smartOp!(mixPolicy).pow(this.bscal, exp.bscal);
            return SmartInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }
    }
    /// ditto
    template SmartInt(N, IntFlagPolicy policy, Flag!"bitOps" bitOps = Yes.bitOps)
        if ((isIntegral!N && !is(N == Unqual!N)) || isCheckedInt!N)
    {
        alias SmartInt = SmartInt!(BasicScalar!N, policy, bitOps);
    }
    ///
    unittest
    {
        // Mixing standard signed and unsigned types is dangerous, but...
        int ba = -1;
        uint bb = 0;
        assert(ba > bb);

        auto bc = ba + bb;
        assert(is(typeof(bc) == uint));
        assert(bc == 4294967295u);

        // ...with SmartInt, mixed signed/unsigned operations "just work":
        import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

        SmartInt!int ma = -1;
        SmartInt!uint mb = 0;
        assert(ma < mb);

        auto mc = ma + mb;
        assert(is(typeof(mc) == SmartInt!int));
        assert(mc != 4294967295u);
        assert(mc == -1);
    }
    ///
    unittest
    {
        // When IntFlagPolicy.throws is used, failed SmartInt operations will throw a CheckedIntException.
        import std.experimental.checkedint.throws : SmartInt;

        SmartInt!uint ma = 1;
        SmartInt!uint mb = 0;

        bool overflow = false;
        try
        {
            SmartInt!uint mc = mb - ma;
            assert(false);
        }
        catch (CheckedIntException e)
        {
            assert(e.intFlags == IntFlag.negOver);
            overflow = true;
        }
        assert(overflow);

        bool div0 = false;
        try
        {
            // With standard integers, this would crash the program with an unrecoverable FPE...
            SmartInt!uint mc = ma / mb;
            assert(false);
        }
        catch (CheckedIntException e)
        {
            // ...but with SmartInt, it just throws a normal Exception.
            assert(e.intFlags == IntFlag.div0);
            div0 = true;
        }
        assert(div0);
    }
    ///
    unittest
    {
        // When IntFlagPolicy.noex is used, failed SmartInt operations set one or more bits in IntFlags.local.
        import std.experimental.checkedint.noex : SmartInt;

        SmartInt!uint ma = 1;
        SmartInt!uint mb = 0;
        SmartInt!uint mc;

        mc = mb - ma;
        assert(IntFlags.local == IntFlag.negOver);

        // With standard integers, this would crash the program with an unrecoverable FPE...
        mc = ma / mb;
        // ...but with SmartInt, it just sets a bit in IntFlags.local.
        assert(IntFlags.local & IntFlag.div0);

        // Each flag will remain set until cleared:
        assert(IntFlags.local.clear() == (IntFlag.negOver | IntFlag.div0));
        assert(!IntFlags.local);
    }

    private template SmartInt(N, IntFlagPolicy policy, bool bitOps)
        if (isIntegral!N)
    {
        alias SmartInt = SmartInt!(
            Unqual!N,
            policy,
            cast(Flag!"bitOps")bitOps);
    }

    /// Get the value of `num` as a `SmartInt!N`. The integral type `N` can be infered from the argument.
    SmartInt!(N, policy, bitOps) smartInt(IntFlagPolicy policy, Flag!"bitOps" bitOps = Yes.bitOps, N)(N num) @safe
        if (isIntegral!N || isCheckedInt!N)
    {
        return typeof(return)(num.bscal);
    }
    ///
    unittest
    {
        import std.experimental.checkedint.throws : smartInt, SmartInt; // use IntFlagPolicy.throws

        auto a = smartInt(55uL);
        static assert(is(typeof(a) == SmartInt!ulong));
        assert(a == 55);
    }

    /**
    Implements various integer math operations with error checking.

    `smartOp` strives to give the mathematically correct result, with integer-style rounding, for all inputs. Only
    if the correct result is undefined or not representable by the return type is an error signalled, using
    $(MREF std,experimental,_checkedint, flags).

    The error-signalling policy may be selected using the `policy` template parameter.
    **/
    template smartOp(IntFlagPolicy policy)
    {
        // NOTE: ddoc only scans the first branch of a static if
        static if (policy == IntFlagPolicy.none)
        {
            // No need to redundantly instantiate members which don't depend on `policy`.

            private void cmpTypeCheck(N, M)() pure @safe nothrow @nogc
            {
                static assert(isBoolean!N == isBoolean!M,
                    "The intent of a direct comparison of " ~
                    N.stringof ~ " with " ~ M.stringof ~
                    " is unclear. Add an explicit cast."
                );
            }

            /**
            Compare `left` and `right` using `op`.
            $(UL
                $(LI Unlike the standard integer comparison operator, this function correctly handles negative
                    values in signed/unsigned comparisons.)
                $(LI Like the standard operator, comparisons involving any floating-point `nan` value always return
                    `false`.)
            ) $(BR)
            Direct comparisons between boolean values and numeric ones are forbidden. Make the intent explicit:
            $(UL
                $(LI `numeric == cast(N)boolean`)
                $(LI `(numeric != 0) == boolean`)
            )
            **/
            bool cmp(string op, N, M)(const N left, const M right) pure @safe nothrow @nogc
                if (isScalarType!N && isScalarType!M)
            {
                cmpTypeCheck!(N, M)();

                static if (isSigned!N != isSigned!M)
                {
                    static if (isSigned!N)
                    {
                        if (left < 0)
                            return mixin("-1 " ~ op ~ " 0");
                    }
                    else
                    {
                        if (right < 0)
                            return mixin("0 " ~ op ~ " -1");
                    }
                }

                return mixin("left " ~ op ~ " right");
            }
            ///
            unittest
            {
                import std.experimental.checkedint.noex : smartOp; // smartOp.cmp() never throws

                assert(uint.max == -1);
                assert( smartOp.cmp!"!="(uint.max, -1));
                assert(-3156 > 300u);
                assert( smartOp.cmp!"<"(-3156, 300u));

                assert(!smartOp.cmp!"<"(1, real.nan));
                assert(!smartOp.cmp!"<"(real.nan, 1));
            }

            /**
            Defines a total order on all basic scalar values, using the same rules as $(REF _cmp, std,math).

            $(UL
                $(LI Mixed signed/unsigned comparisons return the mathematically correct result.)
                $(LI If neither `left` nor `right` is floating-point, this function is faster than
                    `std.math.cmp()`.)
                $(LI If either `left` or `right` $(I is) floating-point, this function forwards to
                    `std.math.cmp()`.)
            ) $(BR)
            Direct comparisons between boolean values and numeric ones are forbidden. Make the intent explicit:
            $(UL
                $(LI `numeric == cast(N)boolean`)
                $(LI `(numeric != 0) == boolean`)
            )
            **/
            int cmp(N, M)(const N left, const M right) pure @safe nothrow @nogc
                if (isScalarType!N && isScalarType!M)
            {
                cmpTypeCheck!(N, M)();

                static if (isFloatingPoint!N || isFloatingPoint!M)
                {
                    import std.math : stdCmp = cmp;
                    return stdCmp(left, right);
                }
                else
                {
                    static if (isSigned!N != isSigned!M)
                    {
                        static if (isSigned!N)
                        {
                            if (left < 0)
                                return -1;
                        }
                        else
                        {
                            if (right < 0)
                                return  1;
                        }
                    }

                    return (left < right)? -1 : (right < left);
                }
            }
            ///
            unittest
            {
                import std.experimental.checkedint.noex : smartOp; // smartOp.cmp() never throws

                assert(smartOp.cmp(325.0, 325u) == 0);
                assert(smartOp.cmp(uint.max, -1) == 1);
                assert(smartOp.cmp(-3156, 300u) == -1);
            }

            /// Get the absolute value of `num`. Because the return type is always unsigned, overflow is not possible.
            Unsigned!N abs(N)(const N num) pure @safe nothrow @nogc
                if (isIntegral!N)
            {
                static if (!isSigned!N)
                    return num;
                else
                    return cast(typeof(return))(num < 0?
                        -num : // -num doesn't need to be checked for overflow
                         num);
            }
            /// ditto
            IntFromChar!N abs(N)(const N num) pure @safe nothrow @nogc
                if (isSomeChar!N)
            {
                return num;
            }
            ///
            unittest
            {
                import std.experimental.checkedint.noex : smartOp; // smartOp.abs() never throws

                assert(smartOp.abs(int.min) == std.math.pow(2.0, 31));
                assert(smartOp.abs(-25) == 25u);
                assert(smartOp.abs(745u) == 745u);
            }

            private template Result(N, string op, M)
                if (isNumeric!N && isNumeric!M)
            {
            private:
                enum reqFloat = isFloatingPoint!N || isFloatingPoint!M;
                enum precN = precision!N, precM = precision!M;
                enum precStd = reqFloat? precision!float : precision!uint;
                enum smallSub = (op == "-") && precN < precision!int && precM < precision!int;

                enum reqSign = reqFloat ||
                    (op.among!("+", "-", "*" , "/") && (isSigned!N || isSigned!M || smallSub)) ||
                    (op.among!("%", "^^", "<<", ">>", ">>>") && isSigned!N) ||
                    (op.among!("&", "|", "^") && (isSigned!N && isSigned!M));

                enum reqPrec = reqFloat? max(precStd, precN, precM) :
                    op.among!("+", "-", "*")? max(precStd, precN, precM) - 1 :
                    op == "/"? (isSigned!M? max(precStd, precN) - 1 : precN) :
                    op == "%"? min(precision!N, precision!M) :
                    op == "^^"? max(precStd - 1, precN) :
                    op.among!("<<", ">>", ">>>")? precN :
                  /+op.among!("&", "|", "^")?+/ max(precN, precM);

            public:
                alias Result = Select!(reqFloat,
                    Select!(reqPrec <= double.mant_dig || double.mant_dig >= real.mant_dig,
                        Select!(reqPrec <= float.mant_dig, float, double),
                        real),
                    Select!(reqSign,
                        Select!(reqPrec <= 15,
                            Select!(reqPrec <= 7, byte, short),
                            Select!(reqPrec <= 31, int, long)),
                        Select!(reqPrec <= 16,
                            Select!(reqPrec <= 8, ubyte, ushort),
                            Select!(reqPrec <= 32, uint, ulong))));
            }
            private template Result(N, string op, M)
                if (isScalarType!N && isScalarType!M &&
                    (!isNumeric!N || !isNumeric!M))
            {
                alias Result = Result!(NumFromScal!N, op, NumFromScal!M);
            }
        }
        else
        {
            alias cmp = smartOp!(IntFlagPolicy.none).cmp;
            alias abs = smartOp!(IntFlagPolicy.none).abs;
            private alias Result = smartOp!(IntFlagPolicy.none).Result;
        }

        /**
        Perform the unary (single-argument) integer operation specified by `op`.

        Key differences from the standard unary operators:
        $(UL
            $(LI `-` and `+` always return a signed value.)
            $(LI `-` is checked for overflow, because `-int.min` is greater than `int.max`.)
            $(LI `++` and `--` are checked for overflow.)
        ) $(BR)
        Note that like the standard operators, `++` and `--` take the operand by `ref` and overwrite its value with
        the result.
        **/
        N unary(string op, N)(const N num) pure @safe nothrow @nogc
            if (isIntegral!N && op == "~")
        {
            return ~num;
        }
        /// ditto
        IntFromChar!N unary(string op, N)(const N num) pure @safe nothrow @nogc
            if (isSomeChar!N && op == "~")
        {
            return ~num;
        }
        /// ditto
        Signed!(Promoted!N) unary(string op, N)(const N num) @safe
            if (isFixedPoint!N && op.among!("-", "+"))
        {
            alias R = typeof(return);
            alias UR = Unsigned!R;

            static if (op == "-")
            {
                static if (isSigned!N)
                {
                    if (num < -trueMax!R)
                        IntFlag.posOver.raise!policy();
                }
                else
                {
                    if (num > cast(UR)trueMin!R)
                        IntFlag.negOver.raise!policy();
                }

                return -cast(R)num;
            }
            else
            {
                static if (!isSigned!N)
                {
                    if (num > trueMax!R)
                        IntFlag.posOver.raise!policy();
                }

                return num;
            }
        }
        /// ditto
        ref N unary(string op, N)(return ref N num) @safe
            if (isIntegral!N && op.among!("++", "--"))
        {
            static if (op == "++")
            {
                if (num >= trueMax!N)
                    IntFlag.posOver.raise!policy();

                return ++num;
            }
            else static if (op == "--")
            {
                if (num <= trueMin!N)
                    IntFlag.negOver.raise!policy();

                return --num;
            }
            else
                static assert(false);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            assert(smartOp.unary!"~"(0u) == uint.max);

            auto a = smartOp.unary!"-"(20uL);
            static assert(is(typeof(a) == long));
            assert(a == -20);

            auto b = smartOp.unary!"+"(uint.max);
            static assert(is(typeof(b) == int));
            assert(IntFlags.local.clear() == IntFlag.posOver);

            uint c = 1u;
            assert(smartOp.unary!"--"(c) == 0u);
            assert(c == 0u);
            smartOp.unary!"--"(c);
            assert(IntFlags.local.clear() == IntFlag.negOver);

            int d = 7;
            assert(smartOp.unary!"++"(d) == 8);
            assert(d == 8);
        }

        /// $(REF _bsf, core,bitop) without the undefined behaviour. `smartOp.bsf(0)` will raise `IntFlag.undef`.
        ubyte bsf(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            return cast(ubyte) bsfImpl!policy(num);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp;

            assert(smartOp.bsf(20) == 2);

            smartOp.bsf(0);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }

        /// $(REF _bsr, core,bitop) without the undefined behaviour. `smartOp.bsr(0)` will raise `IntFlag.undef`.
        ubyte bsr(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            return cast(ubyte) bsrImpl!policy(num);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp;

            assert(smartOp.bsr( 20) ==  4);
            assert(smartOp.bsr(-20) == 31);

            smartOp.bsr(0);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }

        /**
        Get the base 2 logarithm of `abs(num)`, rounded down to the nearest integer.

        `smartOp.ilogb(0)` will raise `IntFlag.undef`.
        **/
        ubyte ilogb(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            return cast(ubyte) bsrImpl!policy(abs(num));
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp;

            assert(smartOp.ilogb(20) == 4);
            assert(smartOp.ilogb(-20) == 4);

            smartOp.ilogb(0);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }

        private auto binaryImpl(string op, N, M)(const N left, const M right) @safe
            if (isIntegral!N && isIntegral!M)
        {
            enum wop = (op[$-1] == '=')? op[0 .. $-1] : op;
            alias
                UN = Unsigned!N,
                UM = Unsigned!M,
                 W = Result!(N, wop, M),
                 R = Select!(wop == op, W, N);

            static if (wop.among!("+", "-", "*"))
            {
                enum safePrec = (wop == "*")?
                    precision!N + precision!M :
                    max(precision!N, precision!M) + 1;
                enum safeR = precision!R >= safePrec;

                static if (safeR)
                    return mixin("cast(R)left " ~ wop ~ " cast(R)right");
                else
                {
                    enum safeW = precision!W >= safePrec;
                    enum matched = (isSigned!N == isSigned!M);
                    enum oX = staticIndexOf!(wop, "+", "-", "*") << 1;
                    alias cops = AliasSeq!(addu, adds, subu, subs, mulu, muls);

                    static if (safeW || matched || wop == "*")
                    {
                        bool over;
                        static if (safeW)
                            const wR = mixin("cast(W)left " ~ wop ~ " cast(W)right");
                        else
                        {
                            static if (matched)
                            {
                                alias cop = cops[oX + isSigned!W];
                                const wR = cop(left, right, over);
                            }
                            else
                            {
                                // integer multiplication is commutative
                                static if (isSigned!N)
                                    W sa = left, ub = right;
                                else
                                    W ub = left, sa = right;

                                static if (isSigned!R)
                                {
                                    W wR = muls(sa, ub, over);
                                    if (ub < 0)
                                        over = (sa != 0) && (ub != trueMin!W || sa != -1);
                                }
                                else
                                {
                                    over = (sa < 0) && (ub != 0);
                                    const wR = mulu(sa, ub, over);
                                }
                            }
                        }

                        alias WR = typeof(wR);
                        static if (isSigned!WR && trueMin!WR < trueMin!R)
                        {
                            if (wR < trueMin!R)
                                over = true;
                        }
                        static if (trueMax!WR > trueMax!R)
                        {
                            if (wR > trueMax!R)
                                over = true;
                        }
                    }
                    else
                    {
                        alias UW = Unsigned!W;
                        alias WR = Select!(isSigned!R, W, UW);
                        alias cop = cops[oX];

                        bool hiBit = false;
                        const wR = cast(WR) cop(cast(UW)left, cast(UW)right, hiBit);
                        const bool wSign = (Select!(isSigned!N, left, right) < 0) ^ hiBit;

                        static if (isSigned!WR)
                        {
                            static if (trueMax!WR > trueMax!R)
                            {
                                const over = (wR < 0)?
                                    !wSign || (wR < trueMin!R) :
                                     wSign || (wR > trueMax!R);
                            }
                            else
                                const over = (wR < 0) != wSign;
                        }
                        else
                        {
                            static if (trueMax!WR > trueMax!R)
                                const over = wSign || (wR > trueMax!R);
                            else
                                alias over = wSign;
                        }
                    }

                    if (over)
                        IntFlag.over.raise!policy();
                    return cast(R) wR;
                }
            }
            else static if (wop == "/")
            {
                static if (!isSigned!N && !isSigned!M)
                {
                    R ret = void;
                    if (right == 0)
                    {
                        IntFlag.div0.raise!policy();
                        ret = 0;
                    }
                    else
                        ret = cast(R)(left / right);

                    return ret;
                }
                else
                {
                    alias P = Select!(precision!N <= 32 && precision!M <= 32, uint, ulong);

                    IntFlag flag;
                    R ret = void;
                    if (right == 0)
                    {
                        flag = IntFlag.div0;
                        ret = 0;
                    }
                    else
                    {
                        static if (isSigned!N && isSigned!M)
                        {
                            if (left == trueMin!R && right == -1)
                            {
                                flag = IntFlag.posOver;
                                ret = 0;
                            }
                            else
                                ret = cast(R)(left / right);
                        }
                        else
                        {
                            alias UR = Unsigned!R;

                            P wL = void;
                            P wG = void;
                            static if (isSigned!N)
                            {
                                const negR = left < 0;
                                alias side = left;
                                alias wS = wL;
                                wG = cast(P)right;
                            }
                            else
                            {
                                const negR = right < 0;
                                wL = cast(P)left;
                                alias side = right;
                                alias wS = wG;
                            }

                            if (negR)
                            {
                                wS = -cast(P)side;
                                const P wR = wL / wG;

                                if (wR > cast(UR)trueMin!R)
                                    flag = IntFlag.negOver;
                                ret = -cast(R)wR;
                            }
                            else
                            {
                                wS =  cast(P)side;
                                const P wR = wL / wG;

                                if (wR > cast(UR)trueMax!R)
                                    flag = IntFlag.posOver;
                                ret =  cast(R)wR;
                            }
                        }
                    }

                    if (!flag.isNull)
                        flag.raise!policy();
                    return ret;
                }
            }
            else static if (wop == "%")
            {
                R ret = void;
                static if (isSigned!M)
                    const wG = cast(UM)((right < 0)? -right : right);
                else
                    const wG = right;

                if (wG <= trueMax!N)
                {
                    if (wG)
                        ret = cast(R)(left % cast(N)wG);
                    else
                    {
                        IntFlag.div0.raise!policy();
                        ret = 0;
                    }
                }
                else
                {
                    static if (isSigned!N)
                    {
                        ret = (wG != cast(UN)trueMin!N || left != trueMin!N)?
                            cast(R)left :
                            cast(R)0;
                    }
                    else
                        ret = cast(R)left;
                }

                return ret;
            }
            else static if (wop.among!("<<", ">>", ">>>"))
            {
                const negG = right < 0;
                const shR = (wop == "<<")?
                     negG :
                    !negG;

                R ret = void;
                static if (wop == ">>>")
                    const wL = cast(UN)left;
                else
                    alias wL = left;
                const absG = negG?
                    -cast(UM)right :
                     cast(UM)right;

                enum maxSh = precision!UN - 1;
                if (absG <= maxSh)
                {
                    const wG = cast(int)absG;
                    ret = cast(R)(shR?
                        wL >> wG :
                        wL << wG);
                }
                else
                {
                    ret = cast(R)((isSigned!N && (wop != ">>>") && shR)?
                        (wL >> maxSh) :
                        0);
                }

                return ret;
            }
            else static if (wop.among!("&", "|", "^"))
                return cast(R)mixin("left " ~ wop ~ " right");
            else
                static assert(false);
        }

        /**
        Perform the binary (two-argument) integer operation specified by `op`.

        Key differences from the standard binary operators:
        $(UL
            $(LI `+`, `-`, `*`, `/`, and `%` return a signed type if the result could be negative, unless $(B both)
                inputs are unsigned.)
            $(LI `+`, `-`, `*`, and `/` are checked for overflow.)
            $(LI `/` and `%` are checked for divide-by-zero, and will never generate an FPE.)
            $(LI `<<`, `>>`, and `>>>` are well-defined for all possible values of `right`. Large shifts return the
                same result as shifting by `1` `right` times in a row. (But, much faster because no actual loop is
                used.))
        ) $(BR)
        Note also:
        $(UL
            $(LI The shift operators are $(B not) checked for overflow and should not be used for
                multiplication, division, or exponentiation. Instead, use $(LREF smartOp.mulPow2) and
                $(LREF smartOp.divPow2), which internally use the bitshifts for speed, but check for overflow and
                correctly handle negative values.)
            $(LI Likewise, $(LREF smartOp.modPow2) should be used for remainders instead of `&`.)
            $(LI `^^` and `^^=` will remain disabled in favour of `pow` until DMD issues 15288 and 15412 are fixed.)
        ) $(BR)
        Like the standard equiavlents, the assignment operators (`+=`, `-=`, `*=`, etc.) take `left` by `ref` and will
        overwrite it with the result of the operation.
        **/
        auto binary(string op, N, M)(const N left, const M right) @safe
            if (isFixedPoint!N && isFixedPoint!M &&
                op.among!("+", "-", "*", "/", "%", "^^", "<<", ">>", ">>>", "&", "|", "^"))
        {
            static assert(op != "^^",
                "pow() should be used instead of operator ^^ because of issue 15288.");

            return binaryImpl!(op, NumFromScal!N, NumFromScal!M)(left, right);
        }
        /// ditto
        ref N binary(string op, N, M)(return ref N left, const M right) @safe
            if (isIntegral!N && isFixedPoint!M && (op[$ - 1] == '='))
        {
            static assert(op != "^^=",
                "pow() should be used instead of operator ^^= because of issue 15412.");

            left = binaryImpl!(op, NumFromScal!N, NumFromScal!M)(left, right);
            return left;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            ulong a = 18_446_744_073_709_551_615uL;
            long b =      -6_744_073_709_551_615L;
            auto c = smartOp.binary!"+"(a, b);
            static assert(isSigned!(typeof(c)));
            assert(IntFlags.local.clear() == IntFlag.posOver);

            assert(smartOp.binary!"+="(a, b) == 18_440_000_000_000_000_000uL);
            assert(a == 18_440_000_000_000_000_000uL);

            uint d = 25u;
            int e = 32;
            auto f = smartOp.binary!"-"(d, e);
            static assert(isSigned!(typeof(f)));
            assert(f == -7);

            smartOp.binary!"-="(d, e);
            assert(IntFlags.local.clear() == IntFlag.negOver);

            uint g = 1u << 31;
            int h = -1;
            auto i = smartOp.binary!"*"(g, h);
            static assert(isSigned!(typeof(i)));
            assert(i == int.min);

            smartOp.binary!"*="(g, h);
            assert(IntFlags.local.clear() == IntFlag.negOver);

            long j = long.min;
            ulong k = 1uL << 63;
            auto m = smartOp.binary!"/"(j, k);
            static assert(isSigned!(typeof(m)));
            assert(m == -1);

            smartOp.binary!"/="(j, -1);
            assert(IntFlags.local.clear() == IntFlag.posOver);

            ushort n = 20u;
            ulong p = ulong.max;
            auto q = smartOp.binary!"%"(n, p);
            static assert(is(typeof(q) == ushort));
            assert(q == 20u);

            smartOp.binary!"%="(n, 0);
            assert(IntFlags.local.clear() == IntFlag.div0);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            assert(smartOp.binary!"<<"(-0x80, -2) == -0x20);
            ubyte a = 0x3u;
            long b = long.max;
            auto c = smartOp.binary!"<<"(a, b);
            static assert(is(typeof(c) == ubyte));
            assert(c == 0u);

            assert(smartOp.binary!"<<="(a, 7) == 0x80u);
            assert(a == 0x80u);

            short d = -0xC;
            ubyte e = 5u;
            auto f = smartOp.binary!">>"(d, e);
            static assert(is(typeof(f) == short));
            assert(f == -0x1);

            assert(smartOp.binary!">>="(d, -8) == -0xC00);
            assert(d == -0xC00);

            int g = -0x80;
            ulong h = 2u;
            auto i = smartOp.binary!">>>"(g, h);
            static assert(is(typeof(i) == int));
            assert(i == 0x3FFF_FFE0);

            assert(smartOp.binary!">>>="(g, 32) == 0);
            assert(g == 0);

            ubyte j = 0x6Fu;
            short k = 0x4076;
            auto m = smartOp.binary!"&"(j, k);
            static assert(is(typeof(m) == ushort));
            assert(m == 0x66u);

            assert(smartOp.binary!"&="(j, k) == 0x66u);
            assert(j == 0x66u);

            byte n = 0x6F;
            ushort p = 0x4076u;
            auto q = smartOp.binary!"|"(n, p);
            static assert(is(typeof(q) == ushort));
            assert(q == 0x407Fu);

            assert(smartOp.binary!"|="(n, p) == 0x7F);
            assert(n == 0x7F);

            int r = 0x6F;
            int s = 0x4076;
            auto t = smartOp.binary!"^"(r, s);
            static assert(is(typeof(t) == int));
            assert(t == 0x4019);

            assert(smartOp.binary!"^="(r, s) == 0x4019);
            assert(r == 0x4019);

            assert(!IntFlags.local);
        }

        /**
        Equivalent to `left * pow(2, exp)`, but faster and works with a wider range of inputs. This is a safer
        alternative to `left << exp` that is still very fast.

        Note that (conceptually) rounding occurs $(I after) the `*`, meaning that `mulPow2(left, -exp)` is
        equivalent to `divPow2(left, exp)`.
        **/
        auto mulPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            return byPow2Impl!("*", NumFromScal!N, NumFromScal!M)(left, exp);
        }
        /// ditto
        auto mulPow2(N, M)(const N left, const M exp) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            return byPow2Impl!("*", policy, NumFromScal!N, NumFromScal!M)(left, exp);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            assert(smartOp.mulPow2(-23, 5) == -736);
            smartOp.mulPow2(10_000_000, 10);
            assert(IntFlags.local.clear() == IntFlag.posOver);

            assert(smartOp.mulPow2(65536, -8) == 256);
            assert(smartOp.mulPow2(-100, -100) == 0);
        }

        /**
        Equivalent to `left / pow(2, exp)`, but faster and works with a wider range of inputs. This is a safer
        alternative to `left >> exp` that is still very fast.

        Note that (conceptually) rounding occurs $(I after) the `/`, meaning that `divPow2(left, -exp)` is
        equivalent to `mulPow2(left, exp)`.
        **/
        auto divPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            return byPow2Impl!("/", NumFromScal!N, NumFromScal!M)(left, exp);
        }
        /// ditto
        auto divPow2(N, M)(const N left, const M exp) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            return byPow2Impl!("/", policy, NumFromScal!N, NumFromScal!M)(left, exp);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            assert(smartOp.divPow2(65536, 8) == 256);
            assert(smartOp.divPow2(-100, 100) == 0);
            assert(smartOp.divPow2(-23, -5) == -736);

            smartOp.divPow2(10_000_000, -10);
            assert(IntFlags.local.clear() == IntFlag.posOver);
        }

        /**
        Equivalent to `left % pow(2, exp)`, but faster and works with a wider range of inputs. This is a safer
        alternative to `left & ((1 << exp) - 1)` that is still very fast.
        **/
        auto modPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            return byPow2Impl!("%", NumFromScal!N, NumFromScal!M)(left, exp);
        }
        /// ditto
        auto modPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if (isFixedPoint!N && isFixedPoint!M)
        {
            return byPow2Impl!("%", IntFlagPolicy.noex, NumFromScal!N, NumFromScal!M)(left, exp);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            assert(smartOp.modPow2( 101,  1) ==  1);
            assert(smartOp.modPow2( 101,  3) ==  5);
            assert(smartOp.modPow2(-101,  3) == -5);

            assert(smartOp.modPow2(101, -2) ==  0);
            assert(smartOp.modPow2(101, 1_000) == 101);
        }

        /**
        Raise `base` to the `exp` power.

        Errors that may be signalled if neither input is floating-point:
        $(UL
            $(LI `IntFlag.posOver` or `IntFlag.negOver` if the absolute value of the result is too large to
                represent with the return type.)
            $(LI `IntFlag.div0` if `base == 0` and `exp < 0`.)
        )
        **/
        auto pow(N, M)(const N base, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            alias R = Result!(N, "^^", M);
            static assert(is(typeof(return) == R));
            return std.math.pow(cast(R)base, exp);
        }
        /// ditto
        auto pow(N, M)(const N base, const M exp) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            alias R = Result!(N, "^^", M);

            const po = powImpl!(R, Select!(isSigned!M, long, ulong))(base, exp);
            static assert(is(typeof(po.num) == const(R)));

            if (!po.flag.isNull)
                po.flag.raise!policy();
            return po.num;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : smartOp; // use IntFlagPolicy.noex

            assert(smartOp.pow(-10, 3) == -1_000);
            assert(smartOp.pow(16, 4uL) == 65536);
            assert(smartOp.pow(2, -1) == 0);

            smartOp.pow(-3, 27);
            assert(IntFlags.local.clear() == IntFlag.negOver);
            smartOp.pow(0, -5);
            assert(IntFlags.local.clear() == IntFlag.div0);
        }
    }
    private alias smartOp(bool throws) = smartOp!(cast(Flag!"throws")throws);

// debug /////////////////////////////////////////////////
    /**
    `template` `alias` that evaluates to `SafeInt!(N, policy, bitOps)` in debug mode, and `N` in release mode. This
    way, `SafeInt!N` is used to debug integer logic while testing, but the basic `N` is used in release mode for
    maximum speed and the smallest binaries.

    While this may be very helpful for debugging algorithms, note that `DebugInt` is $(B not) a substitute
    for input validation in release mode. Unrecoverable FPEs or silent data-corrupting overflow can still occur in
    release mode in algorithms that are faulty, or missing the appropriate manual bounds checks.

    If performance is the only motivation for using `DebugInt` rather than $(LREF SmartInt), consider limiting
    `DebugInt` to only the hotest code paths - inner loops and the like. For most programs, this should provide
    nearly the same performance boost as using it everywhere, with far less loss of safety.
    **/
    template DebugInt(N, IntFlagPolicy policy, Flag!"bitOps" bitOps = Yes.bitOps)
        if (isIntegral!N || isCheckedInt!N)
    {
        version (Debug)
            alias DebugInt = SafeInt!(N, policy, bitOps);
        else
            alias DebugInt = Unqual!(BasicScalar!N);
    }

// safe /////////////////////////////////////////////////
    /**
    Wrapper for any basic integral type `N` that uses the checked operations from `safeOp` and rejects attempts to
    directly assign values that cannot be proven to be within the range representable by `N`. ($(LREF to) can be
    used to safely assign values of incompatible types, with runtime bounds checking.)

    `SafeInt` is designed to be as interchangeable with `N` as possible, without compromising safety. The
    $(LREF DebugInt) `template` allows a variable to use `SafeInt` in debug mode to find bugs, and `N` directly in
    release mode for greater speed and a smaller binary.

    Outside of generic code that needs to work with both `SafeInt!N` and `N`, it is generally preferable to use
    $(LREF SmartInt) instead. It generates far fewer error messages: mostly it "just works".

    $(UL
        $(LI `policy` controls the error signalling policy (see $(MREF std,experimental,_checkedint, flags)).)
        $(LI `bitOps` may be set to `No.bitOps` if desired, to turn bitwise operations on this type into a compile-time
            error.)
    )
    **/
    struct SafeInt(N, IntFlagPolicy _policy, Flag!"bitOps" bitOps = Yes.bitOps)
        if (isIntegral!N && is(N == Unqual!N))
    {
        /// The error signalling policy used by this `SafeInt` type.
        enum IntFlagPolicy policy = _policy;

        static if (bitOps)
        {
            /**
            The basic integral value of this `SafeInt`. Accessing this directly may be useful for:
            $(UL
                $(LI Intentionally doing modular (unchecked) arithmetic, or)
                $(LI Interacting with APIs that are not `checkedint` aware.)
            )
            **/
            N bscal;
            ///
            unittest
            {
                import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws

                SafeInt!uint n;
                static assert(is(typeof(n.bscal) == uint));

                n = 7u;
                assert(n.bscal == 7u);

                n.bscal -= 8u;
                assert(n == uint.max);
            }

            /// Get a view of this `SafeInt` that allows bitwise operations.
            @property ref inout(SafeInt!(N, policy, Yes.bitOps)) bits() return inout pure @safe nothrow @nogc
            {
                return this;
            }
            ///
            unittest
            {
                import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws

                SafeInt!(int, No.bitOps) n = 1;
                static assert(!__traits(compiles, n << 2));
                assert(n.bits << 2 == 4);
            }
        }
        else
        {
            @property ref inout(N) bscal() return inout pure @safe nothrow @nogc
            {
                return bits.bscal;
            }
            SafeInt!(N, policy, Yes.bitOps) bits;
        }

        /// The most negative possible value of this `SafeInt` type.
        enum SafeInt!(N, policy, bitOps) min = typeof(this)(trueMin!N);
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws

            assert(SafeInt!(int).min == int.min);
            assert(SafeInt!(uint).min == uint.min);
        }

        /// The most positive possible value of this `SafeInt` type.
        enum SafeInt!(N, policy, bitOps) max = typeof(this)(trueMax!N);
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws;

            assert(SafeInt!(int).max == int.max);
            assert(SafeInt!(uint).max == uint.max);
        }

        // Construction, assignment, and casting /////////////////////////////////////////////////
        private void checkImplicit(M)() const @safe
            if (isCheckedInt!M || isScalarType!M)
        {
            alias MB = BasicScalar!M;
            static assert(trueMin!MB >= cast(real)N.min && MB.max <= cast(real)N.max,
                "SafeInt does not support implicit conversions from " ~
                MB.stringof ~ " to " ~ N.stringof ~
                ", because they are unsafe when unchecked. Use the explicit checkedint.to()."
            );
        }

        /**
        Assign the value of `that` to this `SafeInt` instance.

        Trying to assign a value that cannot be proven at compile time to be representable by `N` is an error. Use
        $(LREF to) to safely convert `that` with runtime bounds checking, instead.
        **/
        this(M)(const M that) pure @safe nothrow @nogc
            if (isCheckedInt!M || isScalarType!M)
        {
            checkImplicit!M();
            this.bscal = that.bscal;
        }
        /// ditto
        ref typeof(this) opAssign(M)(const M that) return pure @safe nothrow @nogc
            if (isCheckedInt!M || isScalarType!M)
        {
            checkImplicit!M();
            this.bscal = that.bscal;
            return this;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : SafeInt, to; // use IntFlagPolicy.noex

            // Only types that for which N can represent all values are accepted directly:
            SafeInt!int n = int.max;
            n = byte.max;
            n = wchar.max;

            // Values of a type that could be `< N.min` or `> N.max` are rejected at compile time:
            static assert(!__traits(compiles, n = long.max));
            static assert(!__traits(compiles, n = uint.max));
            static assert(!__traits(compiles, n = real.max));

            // Instead, use checkedint.to(), which does runtime bounds checking:
            n = to!int(315L);
            assert(n == 315);

            n = to!int(long.max);
            assert(IntFlags.local.clear() == IntFlag.posOver);
        }

        /**
        Convert this value to floating-point. This always succeeds, although some loss of precision may
        occur if M.sizeof <= N.sizeof.
        **/
        M opCast(M)() const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return cast(M)bscal;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws

            SafeInt!int n = 92;
            auto f = cast(double)n;
            static assert(is(typeof(f) == double));
            assert(f == 92.0);
        }

        /// `this != 0`
        M opCast(M)() const pure @safe nothrow @nogc
            if (is(M == bool))
        {
            return bscal != 0;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws

            SafeInt!int n = -315;
            assert( cast(bool)n);

            n = 0;
            assert(!cast(bool)n);
        }

        /**
        Convert this value to type `M` using $(LREF to) for bounds checking. An `IntFlag` will be raised if
        `M` cannot represent the current value of this `SafeInt`.
        **/
        M opCast(M)() const @safe
            if (isCheckedInt!M || isIntegral!M || isSomeChar!M)
        {
            return to!(M, policy)(bscal);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : SafeInt; // use IntFlagPolicy.noex

            SafeInt!ulong n = 52uL;
            auto a = cast(int)n;
            static assert(is(typeof(a) == int));
            assert(!IntFlags.local);
            assert(a == 52);

            auto m = SafeInt!long(-1).mulPow2(n);
            auto b = cast(wchar)m;
            static assert(is(typeof(b) == wchar));
            assert(IntFlags.local.clear() == IntFlag.negOver);
        }

        /**
        Convert this value to a type suitable for indexing an array:
        $(UL
            $(LI If `N` is signed, a `ptrdiff_t` is returned.)
            $(LI If `N` is unsigned, a `size_t` is returned.)
        )
        $(LREF to) is used for bounds checking.
        **/
        @property Select!(isSigned!N, ptrdiff_t, size_t) idx() const @safe
        {
            return to!(typeof(return), policy)(bscal);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SafeInt; // use IntFlagPolicy.throws

            char[3] arr = ['a', 'b', 'c'];
            SafeInt!long n = 1;

            // On 32-bit, `long` cannot be used directly for array indexing,
            static if (size_t.sizeof < long.sizeof)
                static assert(!__traits(compiles, arr[n]));
            // but idx can be used to concisely and safely cast to ptrdiff_t:
            assert(arr[n.idx] == 'b');

            // The conversion is bounds checked:
            static if (size_t.sizeof < long.sizeof)
            {
                n = long.min;
                try
                {
                    arr[n.idx] = '?';
                }
                catch (CheckedIntException e)
                {
                    assert(e.intFlags == IntFlag.negOver);
                }
            }
        }

        /// Get a simple hashcode for this value.
        size_t toHash() const pure @safe nothrow @nogc
        {
            static if (N.sizeof > size_t.sizeof)
            {
                static assert(N.sizeof == (2 * size_t.sizeof));
                return cast(size_t)bscal ^ cast(size_t)(bscal >>> 32);
            }
            else
                return cast(size_t)bscal;
        }

        /// Get a `string` representation of this value.
        string toString() const @safe
        {
            return to!(string, IntFlagPolicy.noex)(bscal);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : safeInt; // use IntFlagPolicy.throws
            assert(safeInt(-753).toString() == "-753");
        }
        /**
        Puts a `string` representation of this value into `w`. This overload will not allocate, unless
        `std.range.primitives.put(w, ...)` allocates.

        Params:
            w = An output range that will receive the `string`
            fmt = An optional format specifier
        */
        void toString(Writer, Char = char)(Writer w, FormatSpec!Char fmt = (FormatSpec!Char).init) const
        {
            formatValue(w, bscal, fmt);
        }

        // Comparison /////////////////////////////////////////////////
        /// See $(LREF safeOp).
        bool opEquals(M)(const M right) const pure @safe nothrow @nogc
            if (isSafeInt!M || isScalarType!M)
        {
            return safeOp!(policy).cmp!"=="(this.bscal, right.bscal);
        }

        /**
        Perform a floating-point comparison to `right`.

        Returns: $(UL
            $(LI `-1` if this value is less than `right`.)
            $(LI ` 0` if this value is equal to `right`.)
            $(LI ` 1` if this value is greater than `right`.)
            $(LI `float.nan` if `right` is a floating-point `nan` value.))
        **/
        auto opCmp(M)(const M right) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return
                (left <  right)? -1 :
                (left >  right)?  1 :
                (left == right)?  0 : float.nan;
        }
        /// See $(LREF safeOp).
        int opCmp(M)(const M right) const pure @safe nothrow @nogc
            if (isSafeInt!M || isFixedPoint!M)
        {
            return
                safeOp!(policy).cmp!"<"(this.bscal, right.bscal)? -1 :
                safeOp!(policy).cmp!">"(this.bscal, right.bscal);
        }

        // Unary /////////////////////////////////////////////////
        /// ditto
        typeof(this) opUnary(string op)() const @safe
            if (op.among!("-", "+", "~"))
        {
            static assert(bitOps || (op != "~"),
                "Bitwise operations are disabled.");

            return typeof(return)(safeOp!(policy).unary!op(bscal));
        }
        /// ditto
        ref typeof(this) opUnary(string op)() return @safe
            if (op.among!("++", "--"))
        {
            safeOp!(policy).unary!op(bscal);
            return this;
        }

        /// ditto
        typeof(this) abs() const @safe
        {
            return typeof(return)(safeOp!(policy).abs(bscal));
        }

        /// Count the number of set bits using $(REF _popcnt, core,bitop).
        SafeInt!(int, policy, bitOps) popcnt()() const pure @safe nothrow @nogc
        {
            static assert(bitOps, "Bitwise operations are disabled.");

            import core.bitop : stdPC = popcnt;
            return typeof(return)(stdPC(bscal));
        }

        /// See $(LREF safeOp).
        SafeInt!(int, policy, bitOps) bsf()() const @safe
        {
            static assert(bitOps, "Bitwise operations are disabled.");

            return typeof(return)(safeOp!(policy).bsf(bscal));
        }
        /// ditto
        SafeInt!(int, policy, bitOps) bsr()() const @safe
        {
            static assert(bitOps, "Bitwise operations are disabled. Consider using ilogb() instead?");

            return typeof(return)(safeOp!(policy).bsr(bscal));
        }

        /// ditto
        SafeInt!(int, policy, bitOps) ilogb() const @safe
        {
            return typeof(return)(safeOp!(policy).ilogb(bscal));
        }

        // Binary /////////////////////////////////////////////////
        /// Perform a floating-point math operation.
        M opBinaryRight(string op, M)(const M left) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return mixin("left " ~ op ~ " bscal");
        }
        /// ditto
        M opBinary(string op, M)(const M right) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return mixin("bscal " ~ op ~ " right");
        }
        /// See $(LREF safeOp).
        SafeInt!(OpType!(M, op, N), policy, bitOps) opBinaryRight(string op, M)(const M left) const @safe
            if (isFixedPoint!M)
        {
            static assert(bitOps || !op.among!("<<", ">>", ">>>", "&", "|", "^"),
                "Bitwise operations are disabled. Consider using mulPow2(), divPow2(), or modPow2() instead?");

            return typeof(return)(safeOp!(policy).binary!op(left, bscal));
        }
        /// ditto
        SafeInt!(OpType!(N, op, BasicScalar!M), .max(policy, intFlagPolicyOf!M), bitOps && hasBitOps!M) opBinary(string op, M)(const M right) const @safe
            if (isSafeInt!M || isFixedPoint!M)
        {
            static assert(bitOps && hasBitOps!M || !op.among!("<<", ">>", ">>>", "&", "|", "^"),
                "Bitwise operations are disabled. Consider using mulPow2(), divPow2(), or modPow2() instead?");

            return typeof(return)(safeOp!(.max(policy, intFlagPolicyOf!M)).binary!op(this.bscal, right.bscal));
        }
        /// ditto
        ref typeof(this) opOpAssign(string op, M)(const M right) return @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            static assert((bitOps && hasBitOps!M) || !op.among!("<<", ">>", ">>>", "&", "|", "^"),
                "Bitwise operations are disabled. Consider using mulPow2(), divPow2(), or modPow2() instead?");
            checkImplicit!(OpType!(N, op, BasicScalar!M))();

            safeOp!(.max(policy, intFlagPolicyOf!M)).binary!(op ~ "=")(this.bscal, right.bscal);
            return this;
        }

        /// ditto
        auto mulPow2(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return safeOp!(policy).mulPow2(bscal, exp);
        }
        /// ditto
        auto mulPow2(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = safeOp!(mixPolicy).mulPow2(this.bscal, exp.bscal);
            return SafeInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }
        /// ditto
        auto divPow2(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return safeOp!(policy).divPow2(bscal, exp);
        }
        /// ditto
        auto divPow2(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = safeOp!(mixPolicy).divPow2(this.bscal, exp.bscal);
            return SafeInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }
        /// ditto
        auto modPow2(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return safeOp!(policy).modPow2(bscal, exp);
        }
        /// ditto
        auto modPow2(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            enum mixPolicy = .max(policy, intFlagPolicyOf!M);
            const wret = safeOp!(mixPolicy).modPow2(this.bscal, exp.bscal);
            return SafeInt!(typeof(wret), mixPolicy, bitOps && hasBitOps!M)(wret);
        }

        /// Raise `this` to the `exp` power using $(REF _pow, std,math).
        M pow(M)(const M exp) const pure @safe nothrow @nogc
            if (isFloatingPoint!M)
        {
            return std.math.pow(bscal, exp);
        }
        /// See $(LREF safeOp).
        SafeInt!(CallType!(std.math.pow, N, BasicScalar!M), .max(policy, intFlagPolicyOf!M), bitOps && hasBitOps!M)
            pow(M)(const M exp) const @safe
            if (isCheckedInt!M || isFixedPoint!M)
        {
            return typeof(return)(safeOp!(.max(policy, intFlagPolicyOf!M)).pow(this.bscal, exp.bscal));
        }
    }
    /// ditto
    template SafeInt(N, IntFlagPolicy policy, Flag!"bitOps" bitOps = Yes.bitOps)
        if ((isIntegral!N && !is(N == Unqual!N)) || isCheckedInt!N)
    {
        alias SafeInt = SafeInt!(BasicScalar!N, policy, bitOps);
    }
    ///
    unittest
    {
        // Mixing standard signed and unsigned types is dangerous...
        int ba = -1;
        uint bb = 0;
        assert(ba > bb);

        auto bc = ba + bb;
        assert(is(typeof(bc) == uint));
        assert(bc == 4294967295u);

        // ...that's why SafeInt doesn't allow it.
        import std.experimental.checkedint.throws : SafeInt, to; // use IntFlagPolicy.throws

        SafeInt!int sa = -1;
        SafeInt!uint sb = 0u;
        static assert(!__traits(compiles, sa < sb));
        static assert(!__traits(compiles, sa + sb));

        // Instead, use checkedint.to() to safely convert to a common type...
        auto sbi = to!(SafeInt!int)(sb);
        assert(sa < sbi);
        auto sc = sa + sbi;
        assert(sc == -1);
        // (...or just switch to SmartInt.)
    }
    ///
    unittest
    {
        // When IntFlagPolicy.throws is set, SafeInt operations that fail at runtime will throw a CheckedIntException.
        import std.experimental.checkedint.throws : SafeInt;

        SafeInt!uint sa = 1u;
        SafeInt!uint sb = 0u;

        bool overflow = false;
        try
        {
            SafeInt!uint sc = sb - sa;
            assert(false);
        }
        catch (CheckedIntException e)
        {
            assert(e.intFlags == IntFlag.negOver);
            overflow = true;
        }
        assert(overflow);

        bool div0 = false;
        try
        {
            // With standard integers, this would crash the program with an unrecoverable FPE...
            SafeInt!uint sc = sa / sb;
            assert(false);
        }
        catch (CheckedIntException e)
        {
            // ...but with SafeInt, it just throws a normal Exception.
            assert(e.intFlags == IntFlag.div0);
            div0 = true;
        }
        assert(div0);
    }
    ///
    unittest
    {
        // When IntFlagPolicy.noex is set, SafeInt operations that fail at runtime set one or more bits in IntFlags.local.
        import std.experimental.checkedint.noex : SafeInt;

        SafeInt!uint sa = 1u;
        SafeInt!uint sb = 0u;
        SafeInt!uint sc;

        sc = sb - sa;
        assert(IntFlags.local == IntFlag.negOver);

        // With standard integers, this would crash the program with an unrecoverable FPE...
        sc = sa / sb;
        // ...but with SmartInt, it just sets a bit in IntFlags.local.
        assert(IntFlags.local & IntFlag.div0);

        // Each flag will remain set until cleared:
        assert(IntFlags.local.clear() == (IntFlag.negOver | IntFlag.div0));
        assert(!IntFlags.local);
    }

    private template SafeInt(N, IntFlagPolicy policy, bool bitOps)
        if (isIntegral!N)
    {
        alias SafeInt = SafeInt!(
            Unqual!N,
            policy,
            cast(Flag!"bitOps")bitOps);
    }

    /// Get the value of `num` as a `SafeInt!N`. The integral type `N` can be infered from the argument.
    SafeInt!(N, policy, bitOps) safeInt(IntFlagPolicy policy, Flag!"bitOps" bitOps = Yes.bitOps, N)(N num) @safe
        if (isIntegral!N || isCheckedInt!N)
    {
        return typeof(return)(num.bscal);
    }
    ///
    unittest
    {
        import std.experimental.checkedint.throws : safeInt, SafeInt; // use IntFlagPolicy.throws

        auto a = safeInt(55uL);
        static assert(is(typeof(a) == SafeInt!ulong));
        assert(a == 55u);
    }

    /**
    Implements various integer math operations with error checking.

    `safeOp` strives to mimic the standard integer math operations in every way, except:
    $(UL
        $(LI If the operation is generally untrustworthy - for example, signed/unsigned comparisons - a compile-time error
            is generated. The message will usually suggest a workaround.)
        $(LI At runtime, if the result is mathematically incorrect an appropriate `IntFlag` will be raised.)
    )
    The runtime error-signalling policy may be selected using the `policy` template parameter.
    **/
    template safeOp(IntFlagPolicy policy)
    {
        // NOTE: ddoc only scans the first branch of a static if
        static if (policy == IntFlagPolicy.none)
        {
        // No need to redundantly instantiate members which don't depend on `policy`.

            private void cmpTypeCheck(N, M)() pure @safe nothrow @nogc
            {
                static assert(isBoolean!N == isBoolean!M,
                    "The intent of a direct comparison of " ~
                    N.stringof ~ " with " ~ M.stringof ~
                    " is unclear. Add an explicit cast."
                );

                alias OT = OpType!(N, "+", M);
                static assert(isFloatingPoint!OT || isSigned!OT || !(isSigned!N || isSigned!M),
                    "The standard signed/unsigned comparisons of " ~ N.stringof ~ " to " ~ M.stringof ~
                    " are unsafe. Use an explicit cast, or switch to smartOp/SmartInt."
                );
            }

            /**
            Compare `left` and `right` using `op`.

            Unsafe signed/unsigned comparisons will trigger a compile-time error. Possible solutions include:
            $(UL
                $(LI Should the inputs really have different signedness? Changing the type of one to match the other is the simplest
                    solution.)
                $(LI Consider using `smartOp.cmp()`, instead, as it can safely do signed/unsigned comparisons.)
                $(LI Alternately, $(LREF to) can be used to safely convert the type of one input, with runtime bounds
                    checking.)
            ) $(BR)
            Direct comparisons between boolean values and numeric ones are also forbidden. Make the intent explicit:
            $(UL
                $(LI `numeric == cast(N)boolean`)
                $(LI `(numeric != 0) == boolean`)
            )
            **/
            bool cmp(string op, N, M)(const N left, const M right) pure @safe nothrow @nogc
                if (isScalarType!N && isScalarType!M)
            {
                cmpTypeCheck!(N, M)();
                return mixin("left " ~ op ~ " right");
            }
            ///
            unittest
            {
                import std.experimental.checkedint.noex : safeOp; // safeOp.cmp() never throws

                assert(safeOp.cmp!"=="(int.max, 0x7FFF_FFFF));
                assert(safeOp.cmp!"!="(uint.min, 5u));
                assert(safeOp.cmp!"<="(int.min, 0));

                static assert(!__traits(compiles, safeOp.cmp!"=="(uint.max, -1)));
                static assert(!__traits(compiles, safeOp.cmp!">"(-1, 1u)));
            }
        }
        else
            alias cmp = safeOp!(IntFlagPolicy.none).cmp;

        /**
        Perform the unary (single-argument) integer operation specified by `op`.

        Trying to negate `-` an unsigned value will generate a compile-time error, because mathematically, the result should
        always be negative (except for -0), but the unsigned return type cannot represent this.

        `++` and `--` are checked for overflow at runtime, and will raise `IntFlag.posOver` or `IntFlag.negOver` if needed.
        **/
        N unary(string op, N)(const N num) @safe
            if ((isIntegral!N) && op.among!("-", "+", "~"))
        {
            static assert(isSigned!N || op != "-",
                "The standard unary - operation for " ~ N.stringof ~
                " is unsafe. Use an explicit cast to a signed type, or switch to smartOp/SmartInt."
            );

            static if (op == "-")
            {
                static if (is(N == int) || is(N == long))
                {
                    bool over = false;
                    const N ret = negs(num, over);
                }
                else
                {
                    const over = (num <= trueMin!N);
                    const N ret = -num;
                }

                if (over)
                    IntFlag.posOver.raise!policy();

                return ret;
            }
            else
                return mixin(op ~ "num");
        }
        /// ditto
        ref N unary(string op, N)(return ref N num) @safe
            if ((isIntegral!N) && op.among!("++", "--"))
        {
            static if (op == "++")
            {
                if (num >= trueMax!N)
                    IntFlag.posOver.raise!policy();
            }
            else static if (op == "--")
            {
                if (num <= trueMin!N)
                    IntFlag.negOver.raise!policy();
            }

            return mixin(op ~ "num");
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.unary!"~"(0u) == uint.max);

            assert(safeOp.unary!"-"(20L) == -20L);
            static assert(!__traits(compiles, safeOp.unary!"-"(20uL)));
            safeOp.unary!"-"(long.min);
            assert(IntFlags.local.clear() == IntFlag.posOver);

            auto a = safeOp.unary!"+"(uint.max);
            static assert(is(typeof(a) == uint));
            assert(a == uint.max);

            uint b = 1u;
            assert(safeOp.unary!"--"(b) == 0u);
            assert(b == 0u);
            safeOp.unary!"--"(b);
            assert(IntFlags.local.clear() == IntFlag.negOver);

            int c = 7;
            assert(safeOp.unary!"++"(c) == 8);
            assert(c == 8);
        }

        /**
        Get the absolute value of `num`.

        `IntFlag.posOver` is raised if `N` is signed and `num == N.min`.
        **/
        N abs(N)(const N num) @safe
            if (isIntegral!N || isBoolean!N)
        {
            static if (isSigned!N)
            {
                if (num < 0)
                    return unary!"-"(num);
            }
            return num;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.abs(-25) == 25);
            assert(safeOp.abs(745u) == 745u);

            safeOp.abs(int.min);
            assert(IntFlags.local.clear() == IntFlag.posOver);
        }

        /// $(REF _bsf, core,bitop) without the undefined behaviour. `safeOp.bsf(0)` will raise `IntFlag.undef`.
        int bsf(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            return bsfImpl!policy(num);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.bsf(20) == 2);

            safeOp.bsf(0);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }

        /// $(REF _bsr, core,bitop) without the undefined behaviour. `safeOp.bsr(0)` will raise `IntFlag.undef`.
        int bsr(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            return bsrImpl!policy(num);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.bsr( 20) ==  4);
            assert(safeOp.bsr(-20) == 31);

            safeOp.bsr(0);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }

        /**
        Get the base 2 logarithm of `abs(num)`, rounded down to the nearest integer.

        `safeOp.ilogb(0)` will raise `IntFlag.undef`.
        **/
        int ilogb(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            static if (isSigned!N)
                const absN = cast(Unsigned!N) (num < 0? -num : num);
            else
                alias absN = num;

            return bsrImpl!policy(absN);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.ilogb( 20) == 4);
            assert(safeOp.ilogb(-20) == 4);

            safeOp.ilogb(0);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }

        private auto binaryImpl(string op, N, M)(const N left, const M right) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            enum wop = (op[$-1] == '=')? op[0 .. $-1] : op;
            alias P = OpType!(N, wop, M);
            alias R = Select!(wop == op, P, N);

            static if (wop.among!("+", "-", "*"))
            {
                enum isPromSafe = !(isSigned!N || isSigned!M) || (isSigned!P && isSigned!R);
                enum needCOp = (wop == "*")?
                    (precision!N + precision!M) > precision!P :
                    (max(precision!N, precision!M) + 1) > precision!P;

                bool over = false;
                static if (needCOp)
                {
                    enum cx = (staticIndexOf!(wop, "+", "-", "*") << 1) + isSigned!P;
                    alias cop = AliasSeq!(addu, adds, subu, subs, mulu, muls)[cx];

                    const pR = cop(cast(P)left, cast(P)right, over);
                }
                else
                    const pR = mixin("left " ~ wop ~ " right");

                static if (isSigned!P && trueMin!P < trueMin!R)
                {
                    if (pR < trueMin!R)
                        over = true;
                }
                static if (trueMax!P > trueMax!R)
                {
                    if (pR > trueMax!R)
                        over = true;
                }

                if (over)
                    IntFlag.over.raise!policy();
                return cast(R)pR;
            }
            else static if (wop.among!("/", "%"))
            {
                enum isPromSafe = !(isSigned!N || isSigned!M) ||
                    (isSigned!P && (wop == "%"? (isSigned!R || !isSigned!N) : isSigned!R));

                const div0 = (right == 0);
                static if (isSigned!N && isSigned!M)
                    const posOver = (left == trueMin!R) && (right == -1);
                else
                    enum posOver = false;

                R ret = void;
                if (div0 || posOver)
                {
                    (posOver? IntFlag.posOver : IntFlag.div0).raise!policy();
                    ret = 0; // Prevent unrecoverable FPE
                }
                else
                    ret = cast(R)mixin("left " ~ wop ~ " right");

                return ret;
            }
            else static if (wop.among!("<<", ">>", ">>>"))
            {
                enum isPromSafe = !isSigned!N || isSigned!R || (op == ">>>");

                enum invalidSh = ~cast(M)(8 * P.sizeof - 1);
                if (right & invalidSh)
                    IntFlag.undef.raise!policy();

                return cast(R) mixin("cast(P)left " ~ wop ~ " right");
            }
            else static if (wop.among!("&", "|", "^"))
            {
                enum isPromSafe = true;

                return cast(R)mixin("left " ~ wop ~ " right");
            }
            else
                static assert(false);

            static assert(isPromSafe,
                "The standard " ~ N.stringof ~ " " ~ op ~ " " ~ M.stringof ~
                " operation is unsafe, due to a signed/unsigned mismatch. " ~
                "Use an explicit cast, or switch to smartOp/SmartInt."
            );
        }

        /**
        Perform the binary (two-argument) integer operation specified by `op`.
        $(UL
            $(LI Unsafe signed/unsigned operations will generate a compile-time error.)
            $(LI `+`, `-`, `*`, `/`, and `%` are checked for overflow at runtime.)
            $(LI `/` and `%` are also checked for divide-by-zero.)
            $(LI `<<`, `>>`, and `>>>` are checked to verify that `right >= 0` and `right < (8 * typeof(left).sizeof)`.
                Otherwise, `IntFlag.undef` is raised.)
        ) $(BR)
        Note also:
        $(UL
            $(LI The shift operators are $(B not) checked for overflow and should not be used for multiplication,
                division, or exponentiation. Instead, use $(LREF safeOp.mulPow2) and $(LREF safeOp.divPow2), which
                internally use the bitshifts for speed, but check for overflow and correctly handle negative values.)
            $(LI Likewise, $(LREF safeOp.modPow2) should be used for remainders instead of `&`.)
            $(LI `^^` and `^^=` will remain disabled in favour of `pow` until DMD issues 15288 and 15412 are fixed.)
        ) $(BR)
        Like the standard equiavlents, the assignment operators (`+=`, `-=`, `*=`, etc.) take `left` by `ref` and will overwrite
        it with the result of the operation.
        **/
        OpType!(N, op, M) binary(string op, N, M)(const N left, const M right) @safe
            if (isFixedPoint!N && isFixedPoint!M &&
                op.among!("+", "-", "*", "/", "%", "^^", "<<", ">>", ">>>", "&", "|", "^"))
        {
            static assert(op != "^^",
                "pow() should be used instead of operator ^^ because of issue 15288.");

            return binaryImpl!op(left, right);
        }
        /// ditto
        ref N binary(string op, N, M)(return ref N left, const M right) @safe
            if (isIntegral!N && isFixedPoint!M && (op[$ - 1] == '='))
        {
            static assert(op != "^^=",
                "pow() should be used instead of operator ^^= because of issue 15412.");

            left = binaryImpl!op(left, right);
            return left;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.binary!"+"(17, -5) == 12);
            static assert(!__traits(compiles, safeOp.binary!"+"(-1, 1u)));

            ulong a = 18_446_744_073_709_551_615uL;
            safeOp.binary!"+="(a, 1u);
            assert(IntFlags.local.clear() == IntFlag.posOver);

            assert(safeOp.binary!"-"(17u, 5u) == 12u);
            safeOp.binary!"-"(5u, 17u);
            assert(IntFlags.local.clear() == IntFlag.negOver);

            ulong b = 123_456_789_987_654_321uL;
            static assert(!__traits(compiles, safeOp.binary!"-="(b, 987_654_321)));
            assert(safeOp.binary!"-="(b, 987_654_321u) == 123_456_789_000_000_000uL);
            assert(b == 123_456_789_000_000_000uL);

            assert(safeOp.binary!"*"(-1 << 30, 2) == int.min);
            safeOp.binary!"*"(1 << 30, 2);
            assert(IntFlags.local.clear() == IntFlag.negOver);

            uint c = 1u << 18;
            assert(safeOp.binary!"*="(c, 1u << 4) == 1u << 22);
            assert(c == 1u << 22);

            assert(safeOp.binary!"/"(22, 11) == 2);
            assert(!__traits(compiles, safeOp.binary!"/"(-22, 11u)));
            safeOp.binary!"/"(0, 0);
            assert(IntFlags.local.clear() == IntFlag.div0);

            long j = long.min;
            safeOp.binary!"/="(j, -1);
            assert(IntFlags.local.clear() == IntFlag.posOver);

            assert(safeOp.binary!"%"(20u, 7u) == 6u);
            static assert(!__traits(compiles, safeOp.binary!"%"(20u, -7)));
            safeOp.binary!"%"(20u, 0u);
            assert(IntFlags.local.clear() == IntFlag.div0);

            short n = 75;
            assert(safeOp.binary!"%="(n, -10) == 5);
            assert(n == 5);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.binary!"<<"(-0x80,  2) == -0x200);
            safeOp.binary!"<<"(-0x80, -2);
            assert(IntFlags.local.clear() == IntFlag.undef);

            ubyte a = 0x3u;
            safeOp.binary!"<<="(a, 7);
            assert(a == 0x80u);

            assert(safeOp.binary!">>"(-0xC, 5u) == -0x1);
            safeOp.binary!">>"(-0xC, long.max);
            assert(IntFlags.local.clear() == IntFlag.undef);

            short b = 0x700;
            assert(safeOp.binary!">>="(b, 8) == 0x7);
            assert(b == 0x7);

            assert(safeOp.binary!">>>"(-0x80, 2u) == 0x3FFF_FFE0);
            safeOp.binary!">>>"(-0x80, 32);
            assert(IntFlags.local.clear() == IntFlag.undef);

            int c = 0xFE_DCBA;
            assert(safeOp.binary!">>>="(c, 12) == 0xFED);
            assert(c == 0xFED);

            assert(safeOp.binary!"&"(0x6Fu, 0x4076)  == 0x66u);

            ubyte d = 0x6Fu;
            assert(safeOp.binary!"&="(d, 0x4076) == 0x66u);
            assert(d == 0x66u);

            assert(safeOp.binary!"|"(0x6F, 0x4076u) == 0x407Fu);

            byte e = 0x6F;
            assert(safeOp.binary!"|="(e, 0x4076u) == 0x7F);
            assert(e == 0x7F);

            assert(safeOp.binary!"^"(0x6F, 0x4076) == 0x4019);

            int f = 0x6F;
            assert(safeOp.binary!"^="(f, 0x4076) == 0x4019);
            assert(f == 0x4019);

            assert(!IntFlags.local);
        }

        /**
        Equivalent to `left * pow(2, exp)`, but faster and works with a wider range of inputs. This is a safer alternative to
        `left << exp` that is still very fast.

        Note that (conceptually) rounding occurs $(I after) the `*`, meaning that `mulPow2(left, -exp)` is equivalent to
        `divPow2(left, exp)`.
        **/
        auto mulPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            return byPow2Impl!("*", NumFromScal!N, NumFromScal!M)(left, exp);
        }
        /// ditto
        auto mulPow2(N, M)(const N left, const M exp) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            return byPow2Impl!("*", policy, NumFromScal!N, NumFromScal!M)(left, exp);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.mulPow2(-23, 5) == -736);
            safeOp.mulPow2(10_000_000, 10);
            assert(IntFlags.local.clear() == IntFlag.posOver);

            assert(safeOp.mulPow2(65536, -8) == 256);
            assert(safeOp.mulPow2(-100, -100) == 0);
        }

        /**
        Equivalent to `left / pow(2, exp)`, but faster and works with a wider range of inputs. This is a safer alternative to
        `left >> exp` that is still very fast.

        Note that (conceptually) rounding occurs $(I after) the `/`, meaning that `divPow2(left, -exp)` is equivalent to
        `mulPow2(left, exp)`.
        **/
        auto divPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            return byPow2Impl!("/", NumFromScal!N, NumFromScal!M)(left, exp);
        }
        /// ditto
        auto divPow2(N, M)(const N left, const M exp) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            return byPow2Impl!("/", policy, NumFromScal!N, NumFromScal!M)(left, exp);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.divPow2(65536, 8) == 256);
            assert(safeOp.divPow2(-100, 100) == 0);
            assert(safeOp.divPow2(-23, -5) == -736);

            safeOp.divPow2(10_000_000, -10);
            assert(IntFlags.local.clear() == IntFlag.posOver);
        }

        /**
        Equivalent to `left % pow(2, exp)`, but faster and works with a wider range of inputs. This is a safer alternative to
        `left & ((1 << exp) - 1)` that is still very fast.
        **/
        auto modPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if ((isFloatingPoint!N && isScalarType!M) || (isScalarType!N && isFloatingPoint!M))
        {
            return byPow2Impl!("%", NumFromScal!N, NumFromScal!M)(left, exp);
        }
        /// ditto
        auto modPow2(N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if (isFixedPoint!N && isFixedPoint!M)
        {
            return byPow2Impl!("%", IntFlagPolicy.noex, NumFromScal!N, NumFromScal!M)(left, exp);
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.modPow2( 101,  1) ==  1);
            assert(safeOp.modPow2( 101,  3) ==  5);
            assert(safeOp.modPow2(-101,  3) == -5);

            assert(safeOp.modPow2(101, -2) ==  0);
            assert(safeOp.modPow2(101, 1_000) == 101);
        }

        /**
        Raise `base` to the `exp` power.

        Errors that may be signalled if neither input is floating-point:
        $(UL
            $(LI `IntFlag.posOver` or `IntFlag.negOver` if the absolute value of the result is too large to
                represent with the return type.)
            $(LI `exp < 0`, `IntFlag.undef` is raised because $(REF _pow, std,math) would trigger an FPE given the
                same input.)
        )
        **/
        CallType!(std.math.pow, N, M) pow(N, M)(const N base, const M exp) @safe
            if (isFixedPoint!N && isFixedPoint!M)
        {
            alias R = typeof(return);
            static assert(!isSigned!N || isSigned!R,
                "std.math.pow(" ~ N.stringof ~ ", " ~ M.stringof ~
                ") is unsafe, due to a signed/unsigned mismatch. Use an explicit cast, or switch to smartOp/SmartInt."
            );

            auto po = powImpl!(R, Select!(isSigned!M, long, ulong))(base, exp);
            static assert(is(typeof(po.num) == R));
            if (exp < 0)
                po.flag = IntFlag.undef;

            if (!po.flag.isNull)
                po.flag.raise!policy();
            return po.num;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : safeOp; // use IntFlagPolicy.noex

            assert(safeOp.pow(-10, 3) == -1_000);
            static assert(!__traits(compiles, safeOp.pow(16, 4uL)));
            safeOp.pow(2, -1);
            assert(IntFlags.local.clear() == IntFlag.undef);

            safeOp.pow(-3, 27);
            assert(IntFlags.local.clear() == IntFlag.negOver);
            safeOp.pow(0, -5);
            assert(IntFlags.local.clear() == IntFlag.undef);
        }
    }
    private alias safeOp(bool throws) = safeOp!(cast(Flag!"throws")throws);

// conv /////////////////////////////////////////////////
    /**
    A wrapper for $(REF _to, std,conv) which uses $(MREF std,experimental,_checkedint, flags) for error signaling when converting between any combination
    of basic scalar types and `checkedint` types. With an appropriate `policy`, this allows $(LREF _to) to be used
    for numeric conversions in `pure nothrow` code, unlike `std.conv.to()`.

    Conversions involving any other type are simply forwarded to `std.conv.to()`, with no runtime overhead.
    **/
    template to(T, IntFlagPolicy policy)
    {
        private enum useFlags(S) = (isCheckedInt!T || isScalarType!T) && (isCheckedInt!S || isScalarType!S);
        private enum reqAttrs =
            ((policy == IntFlagPolicy.noex || policy == IntFlagPolicy.asserts)? " nothrow" : "") ~
            ((policy == IntFlagPolicy.asserts || policy == IntFlagPolicy.throws)? " pure" : "");

        T to(S)(const S value) @safe
            if (useFlags!S)
        {
            static if (isCheckedInt!T || isCheckedInt!S)
                return T(.to!(BasicScalar!T, policy)(value.bscal));
            else
            {
                static if (policy != IntFlagPolicy.none && !isFloatingPoint!T)
                {
                    static if (isFloatingPoint!S)
                    {
                        if (value >= trueMin!T)
                        {
                            if (value > trueMax!T)
                                IntFlag.posOver.raise!policy();
                        }
                        else
                            (std.math.isNaN(value)? IntFlag.undef : IntFlag.negOver).raise!policy();
                    }
                    else
                    {
                        static if (cast(long)trueMin!S < cast(long)trueMin!T)
                        {
                            if (value < cast(S)trueMin!T)
                                IntFlag.negOver.raise!policy();
                        }
                        static if (cast(ulong)trueMax!S > cast(ulong)trueMax!T)
                        {
                            if (value > cast(S)trueMax!T)
                                IntFlag.posOver.raise!policy();
                        }
                    }
                }
                return cast(T)value;
            }
        }

        mixin(`
        T to(S)(S value)` ~ reqAttrs ~ `
            if (!useFlags!S)
        {
            import std.conv : impl = to;
            return impl!T(value);
        }`);
    }
    ///
    unittest
    {
        // Conversions involving only basic scalars or checkedint types use IntFlags for error signalling.
        import std.experimental.checkedint.noex : smartInt, SmartInt, smartOp, to; // use IntFlagPolicy.noex

        assert(to!int(smartInt(-421751L)) == -421751);
        assert(to!(SmartInt!ubyte)(100) == 100u);

        assert(is(typeof(to!int(50u)) == int));
        assert(to!int(50u) == 50);
        assert(!IntFlags.local);

        // If IntFlagPolicy.noex is set, failed conversions return garbage, but...
        assert(smartOp.cmp!"!="(to!int(uint.max), uint.max));
        // ...IntFlags.local can be checked to see if anything went wrong.
        assert(IntFlags.local.clear() == IntFlag.posOver);
    }
    ///
    unittest
    {
        // Everything else forwards to std.conv.to().
        assert(to!(string, IntFlagPolicy.throws)(55) == "55");
        assert(to!(real, IntFlagPolicy.throws)("3.141519e0") == 3.141519L);

        // Setting IntFlagPolicy.noex or .asserts will block std.conv.to(), unless the instantiation is nothrow.
        // Setting IntFlagPolicy.asserts or .throws will block std.conv.to(), unless the instantiation is pure.
        static assert(!__traits(compiles, to!(real, IntFlagPolicy.noex)("3.141519e0")));
    }

    @property {
        /**
        Get a view or copy of `num` as a basic scalar.

        Useful in generic code that handles both basic types, and `checkedint` types.
        **/
        ref inout(N) bscal(N)(return ref inout(N) num) @safe
            if (isScalarType!N)
        {
            return num;
        }
        /// ditto
        ref inout(N) bscal(N)(return ref inout(N) num) @safe
            if (isCheckedInt!N)
        {
            return num.bscal;
        }
        /// ditto
        N bscal(N)(const N num) @safe
            if (isScalarType!N)
        {
            return num;
        }
        /// ditto
        BasicScalar!N bscal(N)(const N num) @safe
            if (isCheckedInt!N)
        {
            return num.bscal;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : smartInt, SmartInt; // use IntFlagPolicy.throws

            assert(is(typeof(bscal(2u)) == uint));
            assert(is(typeof(bscal(SmartInt!int(2))) == int));

            assert(bscal(-3153) == -3153);
            assert(bscal(smartInt(75_000)) == 75_000);
        }

        /**
        Get a view or copy of `num` that supports bitwise operations.

        Useful in generic code that handles both basic types and `checkedint` types.
        ***/
        ref inout(N) bits(N)(return ref inout(N) num) @safe
            if (isFixedPoint!N)
        {
            return num;
        }
        /// ditto
        N bits(N)(const N num) @safe
            if (isFixedPoint!N)
        {
            return num;
        }
        /// ditto
        ref inout(SmartInt!(BasicScalar!N, N.policy, Yes.bitOps)) bits(N)(return ref inout(N) num) @safe
            if (isSmartInt!N)
        {
            return num.bits;
        }
        /// ditto
        SmartInt!(BasicScalar!N, N.policy, Yes.bitOps) bits(N)(const N num) @safe
            if (isSmartInt!N)
        {
            return num.bits;
        }
        /// ditto
        ref inout(SafeInt!(BasicScalar!N, N.policy, Yes.bitOps)) bits(N)(return ref inout(N) num) @safe
            if (isSafeInt!N)
        {
            return num.bits;
        }
        /// ditto
        SafeInt!(BasicScalar!N, N.policy, Yes.bitOps) bits(N)(const N num) @safe
            if (isSafeInt!N)
        {
            return num.bits;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.throws : SmartInt; // use IntFlagPolicy.throws

            assert(is(typeof(bits(5)) == int));

            SmartInt!(int, No.bitOps) noBits = 5;
            assert(is(typeof(bits(noBits)) == SmartInt!(int, Yes.bitOps)));

            static assert(!__traits(compiles, noBits << 2));
            assert((bits(noBits) << 2) == 20);
        }

        /**
        Cast `num` to a basic type suitable for indexing an array.

        For signed types, `ptrdiff_t` is returned. For unsigned types, `size_t` is returned.
        **/
        Select!(isSigned!N, ptrdiff_t, size_t) idx(IntFlagPolicy policy, N)(const N num) @safe
            if (isScalarType!N || isCheckedInt!N)
        {
            return to!(typeof(return), policy)(num.bscal);
        }
        /// ditto
        Select!(isSigned!(BasicScalar!N), ptrdiff_t, size_t) idx(N)(const N num) @safe
            if (isCheckedInt!N)
        {
            return num.idx;
        }
        ///
        unittest
        {
            import std.experimental.checkedint.noex : idx, SmartInt, safeInt; // use IntFlagPolicy.noex

            assert(is(typeof(idx(cast(long)1)) == ptrdiff_t));
            assert(is(typeof(idx(cast(ubyte)1)) == size_t));
            assert(is(typeof(idx(SmartInt!ulong(1))) == size_t));

            assert(idx(17uL) == 17);
            assert(idx(-3) == -3);
            assert(idx(safeInt(cast(byte)100)) == 100);

            static if (size_t.sizeof == 4)
            {
                idx(ulong.max);
                assert(IntFlags.local.clear() == IntFlag.posOver);

                idx(long.min);
                assert(IntFlags.local.clear() == IntFlag.negOver);
            }
        }
    }
/+}+/

// traits /////////////////////////////////////////////////

/// Evaluates to `true` if `T` is an instance of $(LREF SafeInt).
enum isSafeInt(T) = isInstanceOf!(SafeInt, T);
///
unittest
{
    import std.experimental.checkedint.throws : SmartInt, SafeInt; // use IntFlagPolicy.throws

    assert( isSafeInt!(SafeInt!int));

    assert(!isSafeInt!int);
    assert(!isSafeInt!(SmartInt!int));
}

/// Evaluates to `true` if `T` is an instance of $(LREF SmartInt).
enum isSmartInt(T) = isInstanceOf!(SmartInt, T);
///
unittest
{
    import std.experimental.checkedint.throws : SmartInt, SafeInt; // use IntFlagPolicy.throws

    assert( isSmartInt!(SmartInt!int));

    assert(!isSmartInt!int);
    assert(!isSmartInt!(SafeInt!int));
}

/// Evaluates to `true` if `T` is an instance of $(LREF SafeInt) or $(LREF SmartInt).
enum isCheckedInt(T) = isSafeInt!T || isSmartInt!T;
///
unittest
{
    import std.experimental.checkedint.throws : SmartInt, SafeInt; // use IntFlagPolicy.throws

    assert( isCheckedInt!(SafeInt!int));
    assert( isCheckedInt!(SmartInt!int));

    assert(!isCheckedInt!int);
}

/**
Evaluates to `true` if either:
$(UL
    $(LI `isScalarType!T`, or)
    $(LI `isCheckedInt!T`)
)
$(B And) bitwise operators such as `<<` and `~` are available for `T`.
**/
template hasBitOps(T)
{
    static if (isCheckedInt!T)
        enum hasBitOps = TemplateArgsOf!T[2];
    else
        enum hasBitOps = isFixedPoint!T;
}
///
unittest
{
    import std.experimental.checkedint.throws : SmartInt, SafeInt; // use IntFlagPolicy.throws

    assert( hasBitOps!(SafeInt!(int, Yes.bitOps)));
    assert( hasBitOps!(SmartInt!(int, Yes.bitOps)));
    assert( hasBitOps!int);
    assert( hasBitOps!bool);
    assert( hasBitOps!dchar);

    assert(!hasBitOps!(SafeInt!(int, No.bitOps)));
    assert(!hasBitOps!(SmartInt!(int, No.bitOps)));
    assert(!hasBitOps!float);
}

/**
Aliases to the basic scalar type associated with `T`, assuming either:
$(UL
    $(LI `isScalarType!T`, or)
    $(LI `isCheckedInt!T`)
)
Otherwise, `BasicScalar` aliases to `void`.
**/
template BasicScalar(T)
{
    static if (isScalarType!T)
        alias BasicScalar = Unqual!T;
    else static if (isCheckedInt!T)
        alias BasicScalar = TemplateArgsOf!T[0];
    else
        alias BasicScalar = void;
}
///
unittest
{
    import std.experimental.checkedint.throws : SmartInt, SafeInt; // use IntFlagPolicy.throws

    assert(is(BasicScalar!(SafeInt!int) == int));
    assert(is(BasicScalar!(SmartInt!ushort) == ushort));

    assert(is(BasicScalar!int == int));
    assert(is(BasicScalar!(const shared real) == real));
}

// maybe add these to std.traits? ///////////////////////////
private
{
    enum isFixedPoint(T) = isIntegral!T || isSomeChar!T || isBoolean!T;

    template IntFromChar(N)
        if (isSomeChar!N)
    {
        static if (N.sizeof == char.sizeof)
            alias IntFromChar = ubyte;
        else
        static if (N.sizeof == wchar.sizeof)
            alias IntFromChar = ushort;
        else
        static if (N.sizeof == dchar.sizeof)
            alias IntFromChar = uint;
        else
            static assert(false);
    }
    template IntFromChar(N)
        if (isIntegral!N)
    {
        alias IntFromChar = Unqual!N;
    }
    template Promoted(N)
        if (isScalarType!N)
    {
        alias Promoted = CopyTypeQualifiers!(N, typeof(N.init + N.init));
    }

    alias CallType(alias callable, ArgTypes...) = typeof(function()
        {
            import std.typecons : Tuple;
            return callable(Tuple!(ArgTypes)().expand);
        }());
    alias OpType(string op, T) = typeof(function()
        {
            T t;
            return mixin(op ~ "t");
        }());
    alias OpType(T, string op, V) = typeof(function()
        {
            T t;
            V v = 1; // Prevent "divide by zero" errors at CTFE
            return mixin("t " ~ op ~ " v");
        }());

    template precision(N)
        if (isScalarType!N)
    {
        import core.bitop : bsr;
        static if (isFloatingPoint!N)
            enum int precision = N.mant_dig;
        else static if (isSomeChar!N)
            enum int precision = N.sizeof * 8; // dchar may hold values greater than dchar.max
        else
            enum int precision = bsr(N.max) + 1;
    }
}

// internal /////////////////////////////////////////////////
private
{
    enum N trueMin(N) = mostNegative!N;
    template trueMax(N)
        if (isScalarType!N)
    {
        static if (is(Unqual!N == dchar))
            enum N trueMax = ~cast(N)0;
        else
            enum N trueMax = N.max;
    }

    template NumFromScal(N)
        if (isScalarType!N)
    {
        static if (isNumeric!N)
            alias NumFromScal = N;
        else static if (isSomeChar!N)
            alias NumFromScal = IntFromChar!N;
        else //if (isBoolean!N)
            alias NumFromScal = ubyte;
    }

    /+pragma(inline, true)
    {+/
        int bsfImpl(IntFlagPolicy policy, N)(const N num) @safe
            if (isFixedPoint!N)
        {
            static if (isSigned!N)
                return bsfImpl!(policy, Unsigned!N)(num);
            else
            {
                static assert(N.sizeof <= ulong.sizeof);

                int ret = void;
                if (num == 0)
                {
                    IntFlag.undef.raise!policy();
                    ret = int.min;
                }
                else
                    ret = bsf(num);

                return ret;
            }
        }
        int bsrImpl(IntFlagPolicy policy, N)(const N num) @safe
            if (isFixedPoint!N)
        {
            static if (isSigned!N)
                return bsrImpl!(policy, Unsigned!N)(num);
            else
            {
                static assert(N.sizeof <= ulong.sizeof);

                int ret = void;
                if (num == 0)
                {
                    IntFlag.undef.raise!policy();
                    ret = int.min;
                }
                else
                    ret = bsr(num);

                return ret;
            }
        }

        auto byPow2Impl(string op, N, M)(const N left, const M exp) pure @safe nothrow @nogc
            if (op.among!("*", "/", "%") && ((isFloatingPoint!N && isNumeric!M) || (isNumeric!N && isFloatingPoint!M)))
        {
            import std.math : exp2, isFinite, frexp, ldexp;

            enum wantPrec = max(precision!N, precision!M);
            alias R =
                Select!(wantPrec <= precision!float, float,
                Select!(wantPrec <= precision!double, double, real));

            static if (isFloatingPoint!M)
            {
                R ret = void;

                static if (op.among!("*", "/"))
                {
                    if (left == 0 && exp.isFinite)
                        ret = 0;
                    else
                    {
                        R wexp = cast(R)exp;
                        static if (op == "/")
                            wexp = -wexp;

                        ret = cast(R)left * exp2(wexp);
                    }
                }
                else
                {
                    const p2 = exp2(cast(R)exp);
                    ret =
                        p2.isFinite? cast(R)left % p2 :
                        (p2 > 0)? cast(R)left :
                        (p2 < 0)? cast(R)0 :
                        R.nan;
                }

                return ret;
            }
            else
            {
                static if (op.among!("*", "/"))
                {
                    int wexp =
                        (exp > int.max)? int.max :
                        (cast(long)exp < -int.max)? -int.max : cast(int)exp;
                    static if (op == "/")
                        wexp = -wexp;

                    return ldexp(cast(R)left, wexp);
                }
                else
                {
                    int expL;
                    real mantL = frexp(left, expL);

                    static if (!isSigned!M)
                        const retL = expL <= exp;
                    else
                        const retL = (expL < 0) || (expL <= exp);

                    R ret = void;
                    if (retL)
                        ret = left;
                    else
                    {
                        const expDiff = expL - exp;
                        ret = (expDiff > N.mant_dig)?
                            cast(R)0 :
                            left - ldexp(floor(ldexp(mantissa, expDiff)), expL - expDiff);
                    }

                    return ret;
                }
            }
        }
        auto byPow2Impl(string op, IntFlagPolicy policy, N, M)(const N left, const M exp) @safe
            if (op.among!("*", "/", "%") && isIntegral!N && isIntegral!M)
        {
            alias R = Select!(op.among!("*", "/") != 0, Promoted!N, N);
            enum Unsigned!M maxSh = 8 * N.sizeof - 1;

            R ret = void;
            static if (op.among!("*", "/"))
            {
                const rc = cast(R)left;
                const negE = exp < 0;
                const absE = cast(Unsigned!M)(negE?
                    -exp :
                     exp);
                const bigSh = (absE > maxSh);

                R back = void;
                if ((op == "*")? negE : !negE)
                {
                    if (bigSh)
                        ret = 0;
                    else
                    {
                        // ">>" rounds as floor(), but we want trunc() like "/"
                        ret = (rc < 0)?
                            -(-rc >>> absE) :
                            rc >>> absE;
                    }
                }
                else
                {
                    if (bigSh)
                    {
                        ret = 0;
                        back = 0;
                    }
                    else
                    {
                        ret  = rc  << absE;
                        back = ret >> absE;
                    }

                    if (back != rc)
                        IntFlag.over.raise!policy();
                }
            }
            else
            {
                if (exp & ~maxSh)
                    ret = (exp < 0)? 0 : left;
                else
                {
                    const mask = ~(~cast(N)0 << exp);
                    ret = cast(R)(left < 0?
                        -(-left & mask) :
                         left & mask);
                }
            }

            return ret;
        }
    /+}+/

    struct PowOut(B)
    {
        B num;
        IntFlag flag;
    }

    // Minimize template bloat by using a common pow() implementation
    pragma(inline, false)
    PowOut!B powImpl(B, E)(const B base, const E exp) @safe
        if ((is(B == int) || is(B == uint) || is(B == long) || is(B == ulong)) &&
            (is(E == long) || is(E == ulong)))
    {
        PowOut!B ret;

        static if (isSigned!B)
        {
            alias cmul = muls;
            const smallB = (1 >= base && base >= -1);
        }
        else
        {
            alias cmul = mulu;
            const smallB = (base <= 1);
        }

        if (smallB)
        {
            if (base == 0)
            {
                static if (isSigned!E)
                {
                    if (exp < 0)
                        ret.flag = IntFlag.div0;
                }

                ret.num = (exp == 0);
            }
            else
                ret.num = (exp & 0x1)? base : 1;

            return ret;
        }
        if (exp <= 0)
        {
            ret.num = (exp == 0);
            return ret;
        }

        ret.num = 1;
        if (exp <= precision!B)
        {
            B b = base;
            int e = cast(int)exp;
            if (e & 0x1)
                ret.num = b;
            e >>>= 1;

            bool over = false;
            while (e != 0)
            {
                b = cmul(b, b, over);
                if (e & 0x1)
                    ret.num = cmul(ret.num, b, over);

                e >>>= 1;
            }

            if (!over)
                return ret;
        }

        ret.flag = (base < 0 && (exp & 0x1))?
            IntFlag.negOver :
            IntFlag.posOver;
        return ret;
    }
}
