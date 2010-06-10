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
 */
/*          Copyright Don Clugston 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module std.bigint;

private import std.internal.math.biguintcore;

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
        } else if (s[0]=='+') {
            s = s[1..$];
        }
        data = 0UL;
        auto q = 0X3;
        bool ok;
        assert(isZero());
        if (s.length>2 && (s[0..2]=="0x" || s[0..2]=="0X")) {
            ok = data.fromHexString(s[2..$]);
        } else {
            ok = data.fromDecimalString(s);
        }
        assert(ok);
        if (isZero()) neg = false;
        sign = neg;
    }

    ///
    this(T: long) (T x)
    {
        data = data.init; // Workaround for compiler bug
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
    BigInt opOpAssign(string op, T)(T y)  if ((op=="+" || op=="-" || op=="*" || op=="/" || op=="%" || op==">>" || op=="<<" || op=="^^") && is (T: long))
    {
        ulong u = cast(ulong)(y < 0 ? -y : y);

        static if (op=="+")
        {
            data = BigUint.addOrSubInt(data, u, sign!=(y<0), &sign);
        }
        else static if (op=="-")
        {
            data = BigUint.addOrSubInt(data, u, sign == (y<0), &sign);
        }
        else static if (op=="*")
        {
            if (y == 0) {
                sign = false;
                data = 0UL;
            } else {
                sign = (sign != (y<0));
                data = BigUint.mulInt(data, u);
            }
        }
        else static if (op=="/")
        {
            assert(y!=0, "Division by zero");
            static assert(!is(T==long) && !is(T==ulong));
            data = BigUint.divInt(data, cast(uint)u);
            sign = data.isZero()? false : sign ^ (y<0);
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
            if (y == 0) return this;
            else if ((y > 0) == (op=="<<")) {
                // Sign never changes during left shift
                data = data.opShl(u);
            } else {
                data = data.opShr(u);
                if (data.isZero()) sign = false;
            }
        }
        else static if (op=="^^")
        {
            sign = (y&1)? sign : false;
            data = BigUint.pow(data, u);
        }
        else static assert(0, "BigInt " ~ op[0..$-1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }

    // BigInt op= BigInt
    BigInt opOpAssign(string op, T)(T y)  if ((op=="+" || op=="-" || op=="*" || op=="/" || op=="%") && is (T: BigInt))
    {
        static if (op=="+")
        {
            data = BigUint.addOrSub(data, y.data, sign != y.sign, &sign);
        }
        else static if (op=="-")
        {
            data = BigUint.addOrSub(data, y.data, sign == y.sign, &sign);
        }
        else static if (op=="*")
        {
            data = BigUint.mul(data, y.data);
            sign = isZero() ? false : sign ^ y.sign;
        }
        else static if (op=="/")
        {
            if (!isZero()) {
                sign ^= y.sign;
                data = BigUint.div(data, y.data);
            }
        }
        else static if (op=="%"){
            if (!isZero()) {
                data = BigUint.mod(data, y.data);
            }
        }
        else static assert(0, "BigInt " ~ op[0..$-1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }

    // BigInt op BigInt
    BigInt opBinary(string op, T)(T y)  if ((op=="+" || op == "*" || op=="-" || op=="/" || op=="%") && is (T: BigInt))
    {
        BigInt r = this;
        return r.opOpAssign!(op)(y);
    }

    // BigInt op integer
    BigInt opBinary(string op, T)(T y)  if ((op=="+" || op == "*" || op=="-" || op=="/" || op==">>" || op=="<<" || op=="^^") && is (T: long))
    {
        BigInt r = this;
        return r.opOpAssign!(op)(y);
    }

    //
    int opBinary(string op, T:int)(T y) if (op=="%")
    {
        assert(y!=0);
        uint u = y < 0 ? -y : y;
        int rem = BigUint.modInt(data, u);
        // x%y always has the same sign as x.
        // This is not the same as mathematical mod.
        return sign ? -rem : rem;
    }

    // Commutative operators
    BigInt opBinaryRight(string op, T)(T y)  if ((op=="+" || op=="*") && !is(T: BigInt))
    {
        return opBinary!(op)(y);
    }

    //  integer op BigInt
    BigInt opBinaryRight(string op, T)(T y)  if ((op=="-") && is(T: long))
    {
        ulong u = cast(ulong)(y < 0 ? -y : y);
        BigInt r;
        static if (op=="-") {
            r.sign = sign;
            r.data = BigUint.addOrSubInt(data, u, sign == (y<0), &r.sign);
            r.negate();
        }
        return r;
    }

    BigInt opUnary(string op)()
    {
       static if (op=="-")
       {
            BigInt r = this;
            r.negate();
            return r;
        }
        else static if (op=="+")
           return this;
        else static if (op=="++")
        {
            data = BigUint.addOrSubInt(data, 1UL, false, &sign);
            return this;
        }
        else static if (op=="--")
        {
            data = BigUint.addOrSubInt(data, 1UL, true, &sign);
            return this;
        }
        else static assert(0, "Unary operation " ~ op ~ "BigInt is not supported");
    }

    ///
    bool opEquals(Tdummy=void)(ref const BigInt y) const {
       return sign == y.sign && y.data == data;
    }

    ///
    bool opEquals(T: int)(T y) const{
        if (sign!=(y<0)) return 0;
        return data.opEquals(cast(ulong)(y>=0?y:-y));
    }

    ///
    int opCmp(T:long)(T y) {
     //   if (y==0) return sign? -1: 1;
        if (sign!=(y<0)) return sign ? -1 : 1;
        int cmp = data.opCmp(cast(ulong)(y>=0? y: -y));
        return sign? -cmp: cmp;
    }
    ///
    int opCmp(T:BigInt)(T y) {
        if (sign!=y.sign) return sign ? -1 : 1;
        int cmp = data.opCmp(y.data);
        return sign? -cmp: cmp;
    }
    /// Returns the value of this BigInt as a long,
    /// or +- long.max if outside the representable range.
    long toLong() {
        return (sign ? -1 : 1)*
          (data.ulongLength() == 1  && (data.peekUlong(0) <= cast(ulong)(long.max)) ? cast(long)(data.peekUlong(0)): long.max);
    }
    /// Returns the value of this BigInt as an int,
    /// or +- long.max if outside the representable range.
    long toInt() {
        return (sign ? -1 : 1)*
          (data.uintLength() == 1  && (data.peekUint(0) <= cast(uint)(int.max)) ? cast(int)(data.peekUint(0)): int.max);
    }
    /// Number of significant uints which are used in storing this number.
    /// The absolute value of this BigInt is always < 2^(32*uintLength)
    int uintLength() { return data.uintLength(); }
    /// Number of significant ulongs which are used in storing this number.
    /// The absolute value of this BigInt is always < 2^(64*ulongLength)
    int ulongLength() { return data.ulongLength(); }

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
    void toString(void delegate(const (char)[]) sink, string formatString) const
    {
       if (isNegative()) sink("-");
       if (formatString.length>0 && formatString[$-1]=='x' || formatString[$-1]=='X') {
            char[] buff = data.toHexString(1, '_');
            sink(data.toHexString(0, '_'));
       } else {
            char [] buff = data.toDecimalString(0);
            sink(buff);
       }
    }
/+
private:
    /// Convert to a hexadecimal string, with an underscore every
    /// 8 characters.
    string toHex() {
        string buff = data.toHexString(1, '_');
        if (isNegative()) buff[0] = '-';
        else buff = buff[1..$];
        return buff;
    }
+/
private:
    void negate() { if (!data.isZero()) sign = !sign; }
    bool isZero() const { return data.isZero(); }
    bool isNegative() pure const { return sign; }
}

string toDecimalString(BigInt x)
{
    string outbuff="";
    void sink(const(char)[] s) { outbuff ~= s; }
    x.toString(&sink, "d");
    return outbuff;
}

string toHex(BigInt x)
{
    string outbuff="";
    void sink(const(char)[] s) { outbuff ~= s; }
    x.toString(&sink, "x");
    return outbuff;
}


debug(UnitTest)
{
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
    assert(BigInt(0x1234_5678_9ABC_5A5AL).toLong() == 0x1234_5678_9ABC_5A5AL);
    assert(BigInt(-0x1234_5678_9ABC_5A5AL).toLong() == -0x1234_5678_9ABC_5A5AL);
    assert(BigInt(0xF234_5678_9ABC_5A5AL).toLong() == long.max);
    assert(BigInt(-0x123456789ABCL).toInt() == -int.max);

}
}