/** Arbitrary-precision ('bignum') arithmetic
 *
 * Performance is optimized for numbers below ~1000 decimal digits.
 * For X86 machines, highly optimised assembly routines are used.
 *
 * The following algorithms are currently implemented:
 * $(UL
 * $(LI Karatsuba multiplication)
 * $(LI Squaring is optimized independently of multiplication)
 * $(LI Divide-and-conquer division)
 * $(LI Binary exponentiation)
 * )
 *
 * For very large numbers, consider using the $(WEB gmplib.org, GMP library) instead.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Don Clugston
 * Source: $(PHOBOSSRC std/_bigint.d)
 */
/*          Copyright Don Clugston 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module std.bigint;

private import std.internal.math.biguintcore;
private import std.format : FormatSpec, FormatException;

/** A struct representing an arbitrary precision integer
 *
 * All arithmetic operations are supported, except
 * unsigned shift right (>>>). Logical operations are not currently supported.
 *
 * BigInt implements value semantics using copy-on-write. This means that
 * assignment is cheap, but operations such as x++ will cause heap
 * allocation. (But note that for most bigint operations, heap allocation is
 * inevitable anyway).

 Example:
----------------------------------------------------
        BigInt a = "9588669891916142";
        BigInt b = "7452469135154800";
        auto c = a * b;
        assert(c == "71459266416693160362545788781600");
        auto d = b * a;
        assert(d == "71459266416693160362545788781600");
        assert(d == c);
        d = c * "794628672112";
        assert(d == "56783581982794522489042432639320434378739200");
        auto e = c + d;
        assert(e == "56783581982865981755459125799682980167520800");
        auto f = d + c;
        assert(f == e);
        auto g = f - c;
        assert(g == d);
        g = f - d;
        assert(g == c);
        e = 12345678;
        g = c + e;
        auto h = g / b;
        auto i = g % b;
        assert(h == a);
        assert(i == e);
        BigInt j = "-0x9A56_57f4_7B83_AB78";
        j ^^= 11;
----------------------------------------------------
 *
 */
struct BigInt
{
private:
        BigUint data;     // BigInt adds signed arithmetic to BigUint.
        bool sign = false;
public:
    /// Construct a BigInt from a decimal or hexadecimal string.
    /// The number must be in the form of a D decimal or hex literal:
    /// It may have a leading + or - sign; followed by "0x" if hexadecimal.
    /// Underscores are permitted.
    /// BUG: Should throw a IllegalArgumentException/ConvError if invalid character found
    this(T:string)(T s)
    {
        bool neg = false;
        if (s[0] == '-') {
            neg = true;
            s = s[1..$];
        } else if (s[0] == '+') {
            s = s[1..$];
        }
        data = 0UL;
        auto q = 0X3;
        bool ok;
        assert(isZero());
        if (s.length > 2 && (s[0..2] == "0x" || s[0..2] == "0X"))
        {
            ok = data.fromHexString(s[2..$]);
        } else {
            ok = data.fromDecimalString(s);
        }
        assert(ok);
        if (isZero())
            neg = false;
        sign = neg;
    }

    ///
    this(T: long) (T x)
    {
        data = data.init; // @@@: Workaround for compiler bug
        opAssign(x);
    }

    ///
    void opAssign(T: long)(T x)
    {
        data = cast(ulong)((x < 0) ? -x : x);
        sign = (x < 0);
    }

    ///
    void opAssign(T:BigInt)(T x)
    {
        data = x.data;
        sign = x.sign;
    }

    // BigInt op= integer
    BigInt opOpAssign(string op, T)(T y)
        if ((op=="+" || op=="-" || op=="*" || op=="/" || op=="%"
          || op==">>" || op=="<<" || op=="^^") && is (T: long))
    {
        ulong u = cast(ulong)(y < 0 ? -y : y);

        static if (op=="+")
        {
            data = BigUint.addOrSubInt(data, u, sign != (y<0), sign);
        }
        else static if (op=="-")
        {
            data = BigUint.addOrSubInt(data, u, sign == (y<0), sign);
        }
        else static if (op=="*")
        {
            if (y == 0) {
                sign = false;
                data = 0UL;
            } else {
                sign = ( sign != (y<0) );
                data = BigUint.mulInt(data, u);
            }
        }
        else static if (op=="/")
        {
            assert(y!=0, "Division by zero");
            static assert(!is(T == long) && !is(T == ulong));
            data = BigUint.divInt(data, cast(uint)u);
            sign = data.isZero() ? false : sign ^ (y < 0);
        }
        else static if (op=="%")
        {
            assert(y!=0, "Division by zero");
            static assert(!is(T==long) && !is(T==ulong));
            data = cast(ulong)BigUint.modInt(data, cast(uint)u);
            // x%y always has the same sign as x.
            // This is not the same as mathematical mod.
        }
        else static if (op==">>" || op=="<<")
        {
            // Do a left shift if y>0 and <<, or
            // if y<0 and >>; else do a right shift.
            if (y == 0)
                return this;
            else if ((y > 0) == (op=="<<"))
            {
                // Sign never changes during left shift
                data = data.opShl(u);
            } else
            {
                data = data.opShr(u);
                if (data.isZero())
                    sign = false;
            }
        }
        else static if (op=="^^")
        {
            sign = (y & 1) ? sign : false;
            data = BigUint.pow(data, u);
        }
        else static assert(0, "BigInt " ~ op[0..$-1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }

    // BigInt op= BigInt
    BigInt opOpAssign(string op, T)(T y)
        if ((op=="+" || op== "-" || op=="*" || op=="/" || op=="%")
            && is (T: BigInt))
    {
        static if (op == "+")
        {
            data = BigUint.addOrSub(data, y.data, sign != y.sign, &sign);
        }
        else static if (op == "-")
        {
            data = BigUint.addOrSub(data, y.data, sign == y.sign, &sign);
        }
        else static if (op == "*")
        {
            data = BigUint.mul(data, y.data);
            sign = isZero() ? false : sign ^ y.sign;
        }
        else static if (op == "/")
        {
            y.checkDivByZero();
            if (!isZero())
            {
                sign ^= y.sign;
                data = BigUint.div(data, y.data);
            }
        }
        else static if (op == "%")
        {
            y.checkDivByZero();
            if (!isZero())
            {
                data = BigUint.mod(data, y.data);
                // x%y always has the same sign as x.
                if (isZero())
                    sign = false;
            }
        }
        else static assert(0, "BigInt " ~ op[0..$-1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }

    // BigInt op BigInt
    BigInt opBinary(string op, T)(T y)
        if ((op=="+" || op == "*" || op=="-" || op=="/" || op=="%") && is (T: BigInt))
    {
        BigInt r = this;
        return r.opOpAssign!(op)(y);
    }

    // BigInt op integer
    BigInt opBinary(string op, T)(T y)
        if ((op=="+" || op == "*" || op=="-" || op=="/"
            || op==">>" || op=="<<" || op=="^^") && is (T: long))
    {
        BigInt r = this;
        return r.opOpAssign!(op)(y);
    }

    //
    int opBinary(string op, T : int)(T y)
        if (op == "%")
    {
        assert(y!=0);
        uint u = y < 0 ? -y : y;
        int rem = BigUint.modInt(data, u);
        // x%y always has the same sign as x.
        // This is not the same as mathematical mod.
        return sign ? -rem : rem;
    }

    // Commutative operators
    BigInt opBinaryRight(string op, T)(T y)
        if ((op=="+" || op=="*") && !is(T: BigInt))
    {
        return opBinary!(op)(y);
    }

    //  BigInt = integer op BigInt
    BigInt opBinaryRight(string op, T)(T y)
        if (op == "-" && is(T: long))
    {
        ulong u = cast(ulong)(y < 0 ? -y : y);
        BigInt r;
        static if (op == "-")
        {
            r.sign = sign;
            r.data = BigUint.addOrSubInt(data, u, sign == (y<0), r.sign);
            r.negate();
        }
        return r;
    }

    //  integer = integer op BigInt
    T opBinaryRight(string op, T)(T x)
        if ((op=="%" || op=="/") && is(T: long))
    {
        static if (op == "%")
        {
            checkDivByZero();
            // x%y always has the same sign as x.
            if (data.ulongLength() > 1)
                return x;
            ulong u = x < 0 ? -x : x;
            ulong rem = u % data.peekUlong(0);
            // x%y always has the same sign as x.
            return cast(T)((x<0) ? -rem : rem);
        }
        else static if (op == "/")
        {
            checkDivByZero();
            if (data.ulongLength() > 1)
                return 0;
            return cast(T)(x / data.peekUlong(0));
        }
    }
    // const unary operations
    BigInt opUnary(string op)() /*const*/ if (op=="+" || op=="-")
    {
       static if (op=="-")
       {
            BigInt r = this;
            r.negate();
            return r;
        }
        else static if (op=="+")
           return this;
    }

    // non-const unary operations
    BigInt opUnary(string op)() if (op=="++" || op=="--")
    {
        static if (op=="++")
        {
            data = BigUint.addOrSubInt(data, 1UL, false, sign);
            return this;
        }
        else static if (op=="--")
        {
            data = BigUint.addOrSubInt(data, 1UL, true, sign);
            return this;
        }
    }

    ///
    bool opEquals(Tdummy=void)(ref const BigInt y) const
    {
       return sign == y.sign && y.data == data;
    }

    ///
    bool opEquals(T: int)(T y) const
    {
        if (sign != (y<0))
            return 0;
        return data.opEquals(cast(ulong)( y>=0 ? y : -y));
    }

    ///
    int opCmp(T:long)(T y)
    {
        if (sign != (y<0) )
            return sign ? -1 : 1;
        int cmp = data.opCmp(cast(ulong)(y >= 0 ? y : -y));
        return sign? -cmp: cmp;
    }
    ///
    int opCmp(T:BigInt)(T y)
    {
        if (sign!=y.sign)
            return sign ? -1 : 1;
        int cmp = data.opCmp(y.data);
        return sign? -cmp: cmp;
    }
    /// Returns the value of this BigInt as a long,
    /// or +- long.max if outside the representable range.
    long toLong() pure const
    {
        return (sign ? -1 : 1) *
          (data.ulongLength() == 1  && (data.peekUlong(0) <= cast(ulong)(long.max))
          ? cast(long)(data.peekUlong(0))
          : long.max);
    }
    /// Returns the value of this BigInt as an int,
    /// or +- int.max if outside the representable range.
    long toInt() pure const
    {
        return (sign ? -1 : 1) *
          (data.uintLength() == 1  && (data.peekUint(0) <= cast(uint)(int.max))
          ? cast(int)(data.peekUint(0))
          : int.max);
    }
    /// Number of significant uints which are used in storing this number.
    /// The absolute value of this BigInt is always < 2^^(32*uintLength)
    @property size_t uintLength() pure const
    {
        return data.uintLength();
    }
    /// Number of significant ulongs which are used in storing this number.
    /// The absolute value of this BigInt is always < 2^^(64*ulongLength)
    @property size_t ulongLength() pure const
    {
        return data.ulongLength();
    }

    /** Convert the BigInt to string, passing it to 'sink'.
     *
     * $(TABLE  The output format is controlled via formatString:
     * $(TR $(TD "d") $(TD  Decimal))
     * $(TR $(TD "x") $(TD  Hexadecimal, lower case))
     * $(TR $(TD "X") $(TD  Hexadecimal, upper case))
     * $(TR $(TD "s") $(TD  Default formatting (same as "d") ))
     * $(TR $(TD null) $(TD Default formatting (same as "d") ))
     * )
     */
    void toString(scope void delegate(const (char)[]) sink, string formatString) const
    {
        auto f = FormatSpec!char(formatString);
        f.writeUpToNextSpec(sink);
        toString(sink, f);
    }
    void toString(scope void delegate(const(char)[]) sink, ref FormatSpec!char f) const
    {
        auto hex = (f.spec == 'x' || f.spec == 'X');
        if (!(f.spec == 's' || f.spec == 'd' || hex))
            throw new FormatException("Format specifier not understood: %" ~ f.spec);

        char[] buff =
            hex ? data.toHexString(0, '_', 0, f.flZero ? '0' : ' ')
                : data.toDecimalString(0);
        assert(buff.length > 0);

        char signChar = isNegative() ? '-' : 0;
        auto minw = buff.length + (signChar ? 1 : 0);

        if (!hex && !signChar && (f.width == 0 || minw < f.width))
        {
            if (f.flPlus)
                signChar = '+', ++minw;
            else if (f.flSpace)
                signChar = ' ', ++minw;
        }

        auto maxw = minw < f.width ? f.width : minw;
        auto difw = maxw - minw;

        if (!f.flDash && !f.flZero)
            foreach (i; 0 .. difw)
                sink(" ");

        if (signChar)
            sink((&signChar)[0..1]);

        if (!f.flDash && f.flZero)
            foreach (i; 0 .. difw)
                sink("0");

        sink(buff);

        if (f.flDash)
            foreach (i; 0 .. difw)
                sink(" ");
    }
/+
private:
    /// Convert to a hexadecimal string, with an underscore every
    /// 8 characters.
    string toHex()
    {
        string buff = data.toHexString(1, '_');
        if (isNegative())
            buff[0] = '-';
        else
            buff = buff[1..$];
        return buff;
    }
+/
private:
    void negate()
    {
        if (!data.isZero())
            sign = !sign;
    }
    bool isZero() pure const
    {
        return data.isZero();
    }
    bool isNegative() pure const
    {
        return sign;
    }
    // Generate a runtime error if division by zero occurs
    void checkDivByZero() pure const
    {
        assert(!isZero(), "BigInt division by zero");
        if (isZero())
           auto x = 1/toInt(); // generate a div by zero error
    }
}

string toDecimalString(BigInt x)
{
    string outbuff="";
    void sink(const(char)[] s) { outbuff ~= s; }
    x.toString(&sink, "%d");
    return outbuff;
}

string toHex(BigInt x)
{
    string outbuff="";
    void sink(const(char)[] s) { outbuff ~= s; }
    x.toString(&sink, "%x");
    return outbuff;
}

unittest {
    // Radix conversion
    assert( toDecimalString(BigInt("-1_234_567_890_123_456_789"))
        == "-1234567890123456789");
    assert( toHex(BigInt("0x1234567890123456789")) == "123_45678901_23456789");
    assert( toHex(BigInt("0x00000000000000000000000000000000000A234567890123456789"))
        == "A23_45678901_23456789");
    assert( toHex(BigInt("0x000_00_000000_000_000_000000000000_000000_")) == "0");

    assert(BigInt(-0x12345678).toInt() == -0x12345678);
    assert(BigInt(-0x12345678).toLong() == -0x12345678);
    assert(BigInt(0x1234_5678_9ABC_5A5AL).ulongLength == 1);
    assert(BigInt(0x1234_5678_9ABC_5A5AL).toLong() == 0x1234_5678_9ABC_5A5AL);
    assert(BigInt(-0x1234_5678_9ABC_5A5AL).toLong() == -0x1234_5678_9ABC_5A5AL);
    assert(BigInt(0xF234_5678_9ABC_5A5AL).toLong() == long.max);
    assert(BigInt(-0x123456789ABCL).toInt() == -int.max);
    assert((BigInt(-2) + BigInt(1)) == BigInt(-1));
    BigInt a = ulong.max - 5;
    auto b = -long.max % a;
    assert( b == -long.max % (ulong.max - 5));
    b = long.max / a;
    assert( b == long.max /(ulong.max - 5));
    assert(BigInt(1) - 1 == 0);
    assert((-4) % BigInt(5) == -4); // bug 5928
    assert(BigInt(-4) % BigInt(5) == -4);
}

unittest // Recursive division, bug 5568
{
    enum Z = 4843;
    BigInt m = (BigInt(1) << (Z*8) ) - 1;
    m -= (BigInt(1) << (Z*6)) - 1;
    BigInt oldm = m;

    BigInt a = (BigInt(1) << (Z*4) )-1;
    BigInt b = m % a;
    m /= a;
    m *= a;
    assert( m + b == oldm);

    m = (BigInt(1) << (4846 + 4843) ) - 1;
    a = (BigInt(1) << 4846 ) - 1;
    b = (BigInt(1) << (4846*2 + 4843)) - 1;
    BigInt c = (BigInt(1) << (4846*2 + 4843*2)) - 1;
    BigInt w =  c - b + a;
    assert(w % m == 0);

    // Bug 6819. ^^
    BigInt z1 = BigInt(10)^^64;
    BigInt w1 = BigInt(10)^^128;
    assert(z1^^2 == w1);
    BigInt z2 = BigInt(1)<<64;
    BigInt w2 = BigInt(1)<<128;
    assert(z2^^2 == w2);
}

unittest
{
    import std.array;
    import std.format;

    immutable string[][] table = [
    /*  fmt,        +10     -10 */
        ["%d",      "10",   "-10"],
        ["%+d",     "+10",  "-10"],
        ["%-d",     "10",   "-10"],
        ["%+-d",    "+10",  "-10"],

        ["%4d",     "  10", " -10"],
        ["%+4d",    " +10", " -10"],
        ["%-4d",    "10  ", "-10 "],
        ["%+-4d",   "+10 ", "-10 "],

        ["%04d",    "0010", "-010"],
        ["%+04d",   "+010", "-010"],
        ["%-04d",   "10  ", "-10 "],
        ["%+-04d",  "+10 ", "-10 "],

        ["% 04d",   " 010", "-010"],
        ["%+ 04d",  "+010", "-010"],
        ["%- 04d",  " 10 ", "-10 "],
        ["%+- 04d", "+10 ", "-10 "],
    ];

    auto w1 = appender!(char[])();
    auto w2 = appender!(char[])();

    foreach (entry; table)
    {
        immutable fmt = entry[0];

        formattedWrite(w1, fmt, BigInt(10));
        formattedWrite(w2, fmt, 10);
        assert(w1.data == w2.data);
        assert(w1.data == entry[1]);
        w1.clear();
        w2.clear();

        formattedWrite(w1, fmt, BigInt(-10));
        formattedWrite(w2, fmt, -10);
        assert(w1.data == w2.data);
        assert(w1.data == entry[2]);
        w1.clear();
        w2.clear();
    }
}

unittest
{
    import std.array;
    import std.format;

    immutable string[][] table = [
    /*  fmt,        +10     -10 */
        ["%X",      "A",    "-A"],
        ["%+X",     "A",    "-A"],
        ["%-X",     "A",    "-A"],
        ["%+-X",    "A",    "-A"],

        ["%4X",     "   A", "  -A"],
        ["%+4X",    "   A", "  -A"],
        ["%-4X",    "A   ", "-A  "],
        ["%+-4X",   "A   ", "-A  "],

        ["%04X",    "000A", "-00A"],
        ["%+04X",   "000A", "-00A"],
        ["%-04X",   "A   ", "-A  "],
        ["%+-04X",  "A   ", "-A  "],

        ["% 04X",   "000A", "-00A"],
        ["%+ 04X",  "000A", "-00A"],
        ["%- 04X",  "A   ", "-A  "],
        ["%+- 04X", "A   ", "-A  "],
    ];

    auto w1 = appender!(char[])();
    auto w2 = appender!(char[])();

    foreach (entry; table)
    {
        immutable fmt = entry[0];

        formattedWrite(w1, fmt, BigInt(10));
        formattedWrite(w2, fmt, 10);
        assert(w1.data == w2.data);     // Equal only positive BigInt
        assert(w1.data == entry[1]);
        w1.clear();
        w2.clear();

        formattedWrite(w1, fmt, BigInt(-10));
        //formattedWrite(w2, fmt, -10);
        //assert(w1.data == w2.data);
        assert(w1.data == entry[2]);
        w1.clear();
        //w2.clear();
    }
}

// 6448
unittest
{
    import std.array;
    import std.format;

    auto w1 = appender!string();
    auto w2 = appender!string();

    int x = 100;
    formattedWrite(w1, "%010d", x);
    BigInt bx = x;
    formattedWrite(w2, "%010d", bx);
    assert(w1.data == w2.data);
}
