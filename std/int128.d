// Written in the D programming language
/**
 * Implements a signed 128 bit integer type.
 *
    Author:     Walter Bright
    Copyright:  Copyright (c) 2022, D Language Foundation
    License:    $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/int128.d)
 */
module std.int128;

private import core.int128;


/***********************************
 * 128 bit signed integer type.
 */

public struct Int128
{
  @safe pure nothrow @nogc
  {
    Cent data;          /// core.int128.Cent

    /****************
     * Construct an `Int128` from a `long` value.
     * The upper 64 bits are formed by sign extension.
     * Params:
     *  lo = signed lower 64 bits
     */
    this(long lo)
    {
        data.lo = lo;
        data.hi = lo < 0 ? ~0L : 0;
    }

    /****************
     * Construct an `Int128` from a `ulong` value.
     * The upper 64 bits are set to zero.
     * Params:
     *  lo = unsigned lower 64 bits
     */
    this(ulong lo)
    {
        data.lo = lo;
        data.hi = 0;
    }

    /****************
     * Construct an `Int128` from a `long` value.
     * Params:
     *  hi = upper 64 bits
     *  lo = lower 64 bits
     */
    this(long hi, long lo)
    {
        data.hi = hi;
        data.lo = lo;
    }

    /********************
     * Construct an `Int128` from a `Cent`.
     * Params:
     *  data = Cent data
     */
    this(Cent data)
    {
        this.data = data;
    }

    /********************
     * Returns: hash value for Int128
     */
    size_t toHash() const
    {
        return cast(size_t)((data.lo & 0xFFFF_FFFF) + (data.hi & 0xFFFF_FFFF) + (data.lo >> 32) + (data.hi >> 32));
    }

    /************************
     * Compare for equality
     * Params: lo = signed value to compare with
     * Returns: true if Int128 equals value
     */
    bool opEquals(long lo) const
    {
        return data.lo == lo && data.hi == (lo >> 63);
    }

    /************************
     * Compare for equality
     * Params: lo = unsigned value to compare with
     * Returns: true if Int128 equals value
     */
    bool opEquals(ulong lo) const
    {
        return data.hi == 0 && data.lo == lo;
    }

    /************************
     * Compare for equality
     * Params: op2 = value to compare with
     * Returns: true if Int128 equals value
     */
    bool opEquals(Int128 op2) const
    {
        return data.hi == op2.data.hi && data.lo == op2.data.lo;
    }

    /** Support unary arithmentic operator +
     * Params: op = "+"
     * Returns: lvalue of result
     */
    Int128 opUnary(string op)() const
        if (op == "+")
    {
        return this;
    }

    /** Support unary arithmentic operator - ~
     * Params: op = "-", "~"
     * Returns: lvalue of result
     */
    Int128 opUnary(string op)() const
        if (op == "-" || op == "~")
    {
        static if (op == "-")
            return Int128(neg(this.data));
        else static if (op == "~")
            return Int128(com(this.data));
    }

    /** Support unary arithmentic operator ++ --
     * Params: op = "++", "--"
     * Returns: lvalue of result
     */
    Int128 opUnary(string op)()
        if (op == "++" || op == "--")
    {
        static if (op == "++")
            this.data = inc(this.data);
        else static if (op == "--")
            this.data = dec(this.data);
        else
            static assert(0, op);
        return this;
    }

    /** Support casting to a bool
     * Params: T = bool
     * Returns: boolean result
     */
    bool opCast(T : bool)() const
    {
        return tst(this.data);
    }

    /** Support binary arithmetic operators + - * / % & | ^ << >> >>>
     * Params:
     *   op = one of the arithmetic binary operators
     *   op2 = second operand
     * Returns: value after the operation is applied
     */
    Int128 opBinary(string op)(Int128 op2) const
        if (op == "+" || op == "-" ||
            op == "*" || op == "/" || op == "%" ||
            op == "&" || op == "|" || op == "^")
    {
        static if (op == "+")
            return Int128(add(this.data, op2.data));
        else static if (op == "-")
            return Int128(sub(this.data, op2.data));
        else static if (op == "*")
            return Int128(mul(this.data, op2.data));
        else static if (op == "/")
            return Int128(div(this.data, op2.data));
        else static if (op == "%")
        {
            Cent modulus;
            divmod(this.data, op2.data, modulus);
            return Int128(modulus);
        }
        else static if (op == "&")
            return Int128(and(this.data, op2.data));
        else static if (op == "|")
            return Int128(or(this.data, op2.data));
        else static if (op == "^")
            return Int128(xor(this.data, op2.data));
        else
            static assert(0, "wrong op value");
    }

    /// ditto
    Int128 opBinary(string op)(long op2) const
        if (op == "+" || op == "-" ||
            op == "*" || op == "/" || op == "%" ||
            op == "&" || op == "|" || op == "^")
    {
        return mixin("this " ~ op ~ " Int128(0, op2)");
    }

    /// ditto
    Int128 opBinaryRight(string op)(long op2) const
        if (op == "+" || op == "-" ||
            op == "*" || op == "/" || op == "%" ||
            op == "&" || op == "|" || op == "^")
    {
        mixin("return Int128(0, op2) " ~ op ~ " this;");
    }

    /// ditto
    Int128 opBinary(string op)(long op2) const
        if (op == "<<")
    {
        return Int128(shl(this.data, cast(uint) op2));
    }

    /// ditto
    Int128 opBinary(string op)(long op2) const
        if (op == ">>")
    {
        return Int128(sar(this.data, cast(uint) op2));
    }

    /// ditto
    Int128 opBinary(string op)(long op2) const
        if (op == ">>>")
    {
        return Int128(shr(this.data, cast(uint) op2));
    }

    /** arithmetic assignment operators += -= *= /= %= &= |= ^= <<= >>= >>>=
     * Params: op = one of +, -, etc.
     *   op2 = second operand
     * Returns: lvalue of updated left operand
     */
    ref Int128 opOpAssign(string op)(Int128 op2)
        if (op == "+" || op == "-" ||
            op == "*" || op == "/" || op == "%" ||
            op == "&" || op == "|" || op == "^" ||
            op == "<<" || op == ">>" || op == ">>>")
    {
        mixin("this = this " ~ op ~ " op2;");
        return this;
    }

    /// ditto
    ref Int128 opOpAssign(string op)(long op2)
        if (op == "+" || op == "-" ||
            op == "*" || op == "/" || op == "%" ||
            op == "&" || op == "|" || op == "^" ||
            op == "<<" || op == ">>" || op == ">>>")
    {
        mixin("this = this " ~ op ~ " op2;");
        return this;
    }

    /** support signed arithmentic comparison operators < <= > >=
     * Params: op2 = right hand operand
     * Returns: -1 for less than, 0 for equals, 1 for greater than
     */
    int opCmp(Int128 op2) const
    {
        return this == op2 ? 0 : gt(this.data, op2.data) * 2 - 1;
    }

    /** support signed arithmentic comparison operators < <= > >=
     * Params: op2 = right hand operand
     * Returns: -1 for less than, 0 for equals, 1 for greater than
     */
    int opCmp(long op2) const
    {
        return opCmp(Int128(0, op2));
    }
  } // @safe pure nothrow @nogc

    /**
     * Formats `Int128` with either `%d`, `%x`, `%X`, or `%s` (same as `%d`).
     *
     * Params:
     *   sink = $(REF_ALTTEXT Output range, isOutputRange, std, range, primitives)
     *   to write to.
     *   fmt = A $(REF FormatSpec, std,format) which controls how the number
     *   is displayed.
     *
     * Throws:
     *       $(REF FormatException, std,format) if the format specifier is
     *       not one of 'd', 'x', 'X', 's'.
     *
     * See_Also: $(REF formatValue, std,format)
     */
    void toString(Writer, FormatSpec)(scope ref Writer sink, scope const ref FormatSpec fmt) const
    {
        import std.range.primitives : put;
        import std.format : FormatException, Fmt = FormatSpec;

        static if (is(FormatSpec == Fmt!Char, Char))
        {
            // Puts "Char" into scope if the pattern matches.
        }
        static assert(is(Char),
            "Expecting `FormatSpec` to be instantiation of `std.format.FormatSpec`");

        Char[39] buf = void;
        size_t bufStart = void;
        Char signChar = 0;
        if (fmt.spec == 'd' || fmt.spec == 's')
        {
            const bool isNeg = 0 > cast(long) this.data.hi;
            Cent val = isNeg ? neg(this.data) : this.data;
            immutable Cent radix = { lo: 10, hi: 0 };
            Cent modulus;
            bufStart = buf.length;
            do
            {
                uint x = void;
                if (ugt(radix, val))
                {
                    x = cast(uint) val.lo;
                    val = Cent(0, 0);
                }
                else
                {
                    val = udivmod(val, radix, modulus);
                    x = cast(uint) modulus.lo;
                }
                buf[--bufStart] = cast(Char) ('0' + x);
            } while (tst(val));
            if (isNeg)
                signChar = '-';
            else if (fmt.flPlus)
                signChar = '+';
            else if (fmt.flSpace)
                signChar = ' ';
        }
        else if (fmt.spec == 'x' || fmt.spec == 'X')
        {
            immutable hexDigits = fmt.spec == 'X' ? "0123456789ABCDEF" : "0123456789abcdef";
            ulong a = data.lo;
            bufStart = buf.length - 1;
            size_t penPos = buf.length - 1;
            do
            {
                if ((buf[penPos] = hexDigits[0xF & cast(uint) a]) != '0')
                    bufStart = penPos;
                a >>>= 4;
            } while (--penPos >= buf.length - 16);
            a = data.hi;
            do
            {
                if ((buf[penPos] = hexDigits[0xF & cast(uint) a]) != '0')
                    bufStart = penPos;
                a >>>= 4;
            } while (--penPos >= buf.length - 32);
        }
        else
        {
            throw new FormatException("Format specifier not understood: %" ~ fmt.spec);
        }

        const minw = (buf.length - bufStart) + int(signChar != 0);
        const maxw = minw < fmt.width ? fmt.width : minw;
        const difw = maxw - minw;

        static void putRepeatedChars(Char c)(scope ref Writer sink, size_t n)
        {
            static immutable Char[8] array = [c, c, c, c, c, c, c, c];
            foreach (_; 0 .. n / 8)
                put(sink, array[0 .. 8]);
            if (n & 7)
                put(sink, array[0 .. n & 7]);
        }

        if (!fmt.flDash && !fmt.flZero && difw)
            putRepeatedChars!' '(sink, difw);

        if (signChar)
        {
            Char[1] signCharBuf = signChar;
            put(sink, signCharBuf[0 .. 1]);
        }

        if (!fmt.flDash && fmt.flZero && difw)
            putRepeatedChars!'0'(sink, difw);

        put(sink, buf[bufStart .. $]);

        if (fmt.flDash && difw)
            putRepeatedChars!' '(sink, difw);
    }

    /**
        `toString` is rarely directly invoked; the usual way of using it is via
        $(REF format, std, format):
     */
    @safe unittest
    {
        import std.format : format;

        assert(format("%s", Int128.max) == "170141183460469231731687303715884105727");
        assert(format("%s", Int128.min) == "-170141183460469231731687303715884105728");
        assert(format("%x", Int128.max) == "7fffffffffffffffffffffffffffffff");
        assert(format("%X", Int128.max) == "7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
        assert(format("%032X", Int128(123L)) == "0000000000000000000000000000007B");
        assert(format("%+ 40d", Int128(123L)) == "                                    +123");
        assert(format("%+-40d", Int128(123L)) == "+123                                    ");
    }

    /// Also can format as `wchar` or `dchar`.
    @safe unittest
    {
        import std.conv : to;

        assert(to!wstring(Int128.max) == "170141183460469231731687303715884105727"w);
        assert(to!dstring(Int128.max) == "170141183460469231731687303715884105727"d);
    }

    enum min = Int128(long.min, 0);             /// minimum value
    enum max = Int128(long.max, ulong.max);     /// maximum value
}

/********************************************* Tests ************************************/

version (unittest)
{
import core.stdc.stdio;

@trusted void print(Int128 c)
{
    printf("%lld, %lld\n", c.data.hi, c.data.lo);
}

@trusted void printx(Int128 c)
{
    printf("%llx, %llx\n", c.data.hi, c.data.lo);
}
}

/// Int128 tests
@safe pure nothrow @nogc
unittest
{
    Int128 c = Int128(5, 6);
    assert(c == c);
    assert(c == +c);
    assert(c == - -c);
    assert(~c == Int128(~5, ~6));
    ++c;
    assert(c == Int128(5, 7));
    assert(--c == Int128(5, 6));
    assert(!!c);
    assert(!Int128());

    assert(c + Int128(10, 20) == Int128(15, 26));
    assert(c - Int128(1, 2)   == Int128(4, 4));
    assert(c * Int128(100, 2) == Int128(610, 12));
    assert(c / Int128(3, 2)   == Int128(0, 1));
    assert(c % Int128(3, 2)   == Int128(2, 4));
    assert((c & Int128(3, 2)) == Int128(1, 2));
    assert((c | Int128(3, 2)) == Int128(7, 6));
    assert((c ^ Int128(3, 2)) == Int128(6, 4));

    assert(c + 15   == Int128(5, 21));
    assert(c - 15   == Int128(4, -9));
    assert(c * 15   == Int128(75, 90));
    assert(c / 15   == Int128(0, 6148914691236517205));
    assert(c % 15   == Int128(0, 11));
    assert((c & 15) == Int128(0, 6));
    assert((c | 15) == Int128(5, 15));
    assert((c ^ 15) == Int128(5, 9));

    assert(15 + c   == Int128(5, 21));
    assert(15 - c   == Int128(-5, 9));
    assert(15 * c   == Int128(75, 90));
    assert(15 / c   == Int128(0, 0));
    assert(15 % c   == Int128(0, 15));
    assert((15 & c) == Int128(0, 6));
    assert((15 | c) == Int128(5, 15));
    assert((15 ^ c) == Int128(5, 9));

    assert(c << 1 == Int128(10, 12));
    assert(-c >> 1 == Int128(-3, 9223372036854775805));
    assert(-c >>> 1 == Int128(9223372036854775805, 9223372036854775805));

    assert((c += 1) == Int128(5, 7));
    assert((c -= 1) == Int128(5, 6));
    assert((c += Int128(0, 1)) == Int128(5, 7));
    assert((c -= Int128(0, 1)) == Int128(5, 6));
    assert((c *= 2) == Int128(10, 12));
    assert((c /= 2) == Int128(5, 6));
    assert((c %= 2) == Int128());
    c += Int128(5, 6);
    assert((c *= Int128(10, 20)) == Int128(160, 120));
    assert((c /= Int128(10, 20)) == Int128(0, 15));
    c += Int128(72, 0);
    assert((c %= Int128(10, 20)) == Int128(1, -125));
    assert((c &= Int128(3, 20)) == Int128(1, 0));
    assert((c |= Int128(8, 2)) == Int128(9, 2));
    assert((c ^= Int128(8, 2)) == Int128(1, 0));
    c |= Int128(10, 5);
    assert((c <<= 1) == Int128(11 * 2, 5 * 2));
    assert((c >>>= 1) == Int128(11, 5));
    c = Int128(long.min, long.min);
    assert((c >>= 1) == Int128(long.min >> 1, cast(ulong) long.min >> 1));

    assert(-Int128.min == Int128.min);
    assert(Int128.max + 1 == Int128.min);

    c = Int128(5, 6);
    assert(c < Int128(6, 5));
    assert(c > 10);

    c = Int128(-1UL);
    assert(c == -1UL);
    c = Int128(-1L);
    assert(c == -1L);
}
