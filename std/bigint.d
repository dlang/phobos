// Written in the D programming language.

/**
Provides a BigInt struct for multiprecision integer arithmetic.

The internal representation is binary, not decimal.

All relevant operators are overloaded.

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
----------------------------------------------------


Authors: Janice Caron

Date: 2008.05.13

License: Public Domain


Macros:
    WIKI=Phobos/StdBigint
*/

module std.bigint;
import std.algorithm;
import std.typecons;
import std.conv;

/+
void diag(int line = __LINE__, string file = __FILE__)
{
   writefln("%s(%d) executed.", file, line);
}
+/

private void validateDecimalString(string s)
{
    if (s.length != 0 && s[0] == '-')
    {
        s = s[1..$];
    }
    if (s.length == 0) throw new Exception("Parse error");
    foreach(char c;s)
    {
        if ((c < '0' || c > '9') && (c != '_'))
        {
            throw new Exception("Parse error");
        }
    }
}

private string removeUnderscores(string s)
{
    return cast(string)filter!("a!='_'")(s);
}

alias uint Digit; /// aliases to uint

private alias ulong DoubleDigit;
private alias invariant(Digit)[] Unsigned;
private alias Digit[] Buffer;

struct Signed
{
    bool neg = false;
    Unsigned s;
}

const Digit ZERO = 0;
const Digit ONE = ZERO + 1;
const DoubleDigit RADIX = 0x100000000;

unittest
{
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
}

// The top layer - the BigInt struct

/******************
 * Struct representing a multiprecision integer
 */
struct BigInt
{
    private Signed data;

    ///
    void opAssign(const BigInt n)
    {
        data = n.data;
    }

    ///
    void opAssign(int n)
    {
        if (n >= 0)
        {
            opAssign(cast(uint)n);
        }
        else
        {
            opAssign(cast(uint)-n);
            data.neg = true;
        }
    }

    ///
    void opAssign(uint n)
    {
        data.s = [n];
        data.neg = false;
    }

    ///
    void opAssign(long n)
    {
        if (n >= 0)
        {
            opAssign(cast(ulong)n);
        }
        else
        {
            opAssign(cast(ulong)-n);
            data.neg = true;
        }
    }

    ///
    void opAssign(ulong n)
    {
        uint hi = cast(uint)(n >> 32);
        uint lo = cast(uint)(n);
        if (hi == 0) opAssign(lo);
        else data.s = [hi,lo];
        data.neg = false;
    }

    ///
    void opAssign(string s)
    {
        data = fromString(s);
    }

    ///
    static BigInt opCall(T)(T n)
    {
        BigInt r;
        r.opAssign(n);
        return r;
    }

    // Convert TO other types

    ///
    void castTo(out BigInt r) const
    {
        r.data = data;
    }

    ///
    void castTo(out int r) const
    {
        ulong u;
        castTo(u);
        r = cast(int)u;
    }

    ///
    void castTo(out uint r) const
    {
        ulong u;
        castTo(u);
        r = cast(uint)u;
    }

    ///
    void castTo(out long r) const
    {
        ulong u;
        castTo(u);
        r = cast(long)u;
    }

    ///
    void castTo(out ulong r) const
    {
        if (data.s.length == 1)
        {
            r = data.s[0];
        }
        else
        {
            ulong hi = data.s[0];
            ulong lo = data.s[1];
            r = (hi << 32) + lo;
        }
        if (data.neg) r = cast(ulong)-r;
    }

    // Unary operator overloads

    ///
    BigInt opNeg()
    {
        BigInt n;
        n.data = neg(data);
        return n;
    }

    ///
    BigInt opCom()
    {
        BigInt n;
        n.data = subOne(neg(data));
        return n;
    }

    ///
    BigInt opPostInc()
    {
        BigInt n = *this;
        opAddAssign(1);
        return n;
    }

    ///
    BigInt opPostDec()
    {
        BigInt n = *this;
        opSubAssign(1);
        return n;
    }

    // Binary operator overloads

    ///
    BigInt opAdd(T)(T n)
    {
        return opAdd(BigInt(n));
    }

    ///
    BigInt opAdd(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = add(data,n.data);
        return r;
    }

    ///
    void opAddAssign(T)(T n)
    {
        auto r = opAdd(n);
        data = r.data;
    }

    ///
    BigInt opSub(T)(T n)
    {
        return opSub(BigInt(n));
    }

    ///
    BigInt opSub(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = sub(data,n.data);
        return r;
    }

    ///
    void opSubAssign(T)(T n)
    {
        auto r = opSub(n);
        data = r.data;
    }

    ///
    BigInt opMul(T)(T n)
    {
        return opMul(BigInt(n));
    }

    ///
    BigInt opMul(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = mul(data,n.data);
        return r;
    }

    ///
    void opMulAssign(T)(T n)
    {
        auto r = opMul(n);
        data = r.data;
    }

    ///
    BigInt opDiv(T)(T n)
    {
        return opDiv(BigInt(n));
    }

    ///
    BigInt opDiv(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = divmod(data,n.data)._0;
        return r;
    }

    ///
    void opDivAssign(T)(T n)
    {
        auto r = opDiv(n);
        data = r.data;
    }

    /// n may not be negative
    BigInt opAnd(T)(T n)
    {
        return opAnd(BigInt(n));
    }

    /// n may not be negative
    Digit opAnd(T:Digit)(T n)
    {
        Digit d = lsd(data.s);
        if (data.neg) d = -d;
        return d & d;
    }

    /// n may not be negative
    BigInt opAnd(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = and(data,n.data);
        return r;
    }

    /// n may not be negative
    void opAndAssign(T:Digit)(T n)
    {
        Digit r = opAnd(n);
        data.length = 1;
        data.s[0] = r;
    }

    /// n may not be negative
    void opAndAssign(T)(T n)
    {
        auto r = opAnd(n);
        data = r.data;
    }

    /// n may not be negative
    BigInt opOr(T)(T n)
    {
        return opOr(BigInt(n));
    }

    /// n may not be negative
    BigInt opOr(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = or(data,n.data);
        return r;
    }

    /// n may not be negative
    void opOrAssign(T)(T n)
    {
        auto r = opOr(n);
        data = r.data;
    }

    /// n may not be negative
    BigInt opXor(T)(T n)
    {
        return opXor(BigInt(n));
    }

    /// n may not be negative
    BigInt opXor(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = xor(data,n.data);
        return r;
    }

    /// n may not be negative
    void opXorAssign(T)(T n)
    {
        auto r = opXor(n);
        data = r.data;
    }

    ///
    BigInt opMod(T)(T n)
    {
        return opMod(BigInt(n));
    }

    ///
    BigInt opMod(T:const(BigInt))(T n)
    {
        BigInt r;
        r.data = divmod(data,n.data)._1;
        return r;
    }

    ///
    void opModAssign(T)(T n)
    {
        auto r = opMod(n);
        data = r.data;
    }

    ///
    BigInt opShl(uint n)
    {
        BigInt r;
        r.data = shl(data,n);
        return r;
    }

    ///
    void opShlAssign(uint n)
    {
        auto r = opShl(n);
        data = r.data;
    }

    ///
    BigInt opShr(uint n)
    {
        BigInt r;
        r.data = shr(data,n);
        return r;
    }

    ///
    void opShrAssign(uint n)
    {
        auto r = opShr(n);
        data = r.data;
    }

    ///
    BigInt opUShr(uint n)
    {
        BigInt r;
        r.data = ushr(data,n);
        return r;
    }

    ///
    void opUShrAssign(uint n)
    {
        auto r = opUShr(n);
        data = r.data;
    }

    ///
    int opEquals(T)(T n)
    {
        return opEquals(BigInt(n));
    }

    ///
    int opEquals(T:const(BigInt))(T n)
    {
        return cmp(data,n.data) == 0;
    }

    ///
    int opCmp(T)(T n)
    {
        return opCmp(BigInt(n));
    }

    ///
    int opCmp(T:const(BigInt))(T n)
    {
        return cmp(data,n.data);
    }

    ///
    string toString() const
    {
        return toString_(data);
    }

    ///
    hash_t toHash() const
    {
        hash_t h = 0;
        foreach(Digit d;data.s) { h += d; }
        return h;
    }
}

private:

Signed fromString(string s)
{
    Signed r;
    validateDecimalString(s);
    s = removeUnderscores(s);
    if (s.length != 0 && s[0] == '-')
    {
        r.neg = true;
        s = s[1..$];
    }

    r.s = [0];
    foreach(char c;s)
    {
        r.s = mul(r.s,[10]);
        r.s = add(r.s,[c-'0']);
    }

    return r;
}

// -----------------------------------------------------------
// The middle layer.
// This layer consists of functions which accept Signed input.

string toString_(Signed s)
{
    string r = toString_(s.s);
    return s.neg ? '-' ~ r : r;
}

int isZero(Signed s)
{
    return s.s == [ZERO];
}

int sign(Signed s)
{
    if (s.neg) return -1;
    if (isZero(s)) return 0;
    return 1;
}

Unsigned abs(Signed s)
{
    return s.s;
}

Signed neg(Signed s)
{
    if (!isZero(s)) s.neg = !s.neg;
    return s;
}

Signed addOne(Signed s)
{
    return add(s,toSigned([ONE]));
}

Signed subOne(Signed s)
{
    return sub(s,toSigned([ONE]));
}

Signed add(Signed s, Signed t)
{
    int ss = sign(s);
    int st = sign(t);
    if (ss == 0) return t;
    if (st == 0) return s;
    auto as = abs(s);
    auto at = abs(t);
    if (ss > 0)
    {
        return (st > 0) ? toSigned(add(as,at)) : sub(as,at);
    }
    else
    {
        return (st > 0) ?  sub(at,as) : neg(toSigned(add(as,at)));
    }
}

Signed sub(Signed s, Signed t)
{
    return add(s,neg(t));
}

Signed mul(Signed s, Signed t)
{
    int ss = sign(s);
    int st = sign(t);
    if (ss == 0 || st == 0) return toSigned([ZERO]);
    auto as = abs(s);
    auto at = abs(t);
    return toSigned(mul(as,at),ss!=st);
}

struct SignedPair // workaround for bug in Tuple!
{
    Signed _0;
    Signed _1;
}

SignedPair divmod(Signed s, Signed t)
{
    /*
        Here's how the signs work
         7 /  3 = 2
         7 %  3 = 1
         7 / -3 = -2
         7 % -3 = 1
        -7 /  3 = -2
        -7 %  3 = -1
        -7 / -3 = 2
        -7 % -3 = -1
    */

    SignedPair r;
    auto qr = divmod(abs(s),abs(t));
    r._0.neg = s.neg != t.neg;
    r._0.s = qr._0;
    r._1.neg = s.neg;
    r._1.s = qr._1;
    return r;
}

Signed and(Signed s, Signed t)
{
    int ss = sign(s);
    int st = sign(t);
    if (ss == 0) return s;
    if (st == 0) return t;
    assert(ss > 0);
    assert(st > 0);
    auto as = abs(s);
    auto at = abs(t);
    return toSigned(and(as,at));
}

Signed or(Signed s, Signed t)
{
    int ss = sign(s);
    int st = sign(t);
    if (ss == 0) return s;
    if (st == 0) return t;
    assert(ss > 0);
    assert(st > 0);
    auto as = abs(s);
    auto at = abs(t);
    return toSigned(or(as,at));
}

Signed xor(Signed s, Signed t)
{
    int ss = sign(s);
    int st = sign(t);
    if (ss == 0) return s;
    if (st == 0) return t;
    assert(ss > 0);
    assert(st > 0);
    auto as = abs(s);
    auto at = abs(t);
    return toSigned(xor(as,at));
}

Signed shl(Signed s, uint n)
{
    s.s = (s.neg) ? addOne(shl(subOne(s.s), n)) : shl(s.s, n);
    return s;
}

Signed shr(Signed s, uint n)
{
    s.s = (s.neg) ? addOne(shr(subOne(s.s), n)) : shr(s.s, n);
    return s;
}

Signed ushr(Signed s, uint n)
{
    s.neg = false;
    s.s = shr(s.s, n);
    return s;
}

int cmp(Signed s, Signed t)
{
    if (s.neg)
    {
        return (t.neg) ? -cmp(s.s,t.s) : -1;
    }
    else
    {
        return (t.neg) ? 1 : cmp(s.s,t.s);
    }
}

// -----------------------------------------------------------------
// The lowest layer (apart from Digits).
// This layer consists of functions which accept only Unsigned input
// (but may on occasion return a Signed result

string toString_(Unsigned s)
{
    if (isZero(s)) return "0";
    char[] r;
    while (!isZero(s))
    {
        auto qr = divmod(s,10);
        s = qr._0;
        char c = qr._1 + '0';
        r ~= c;
    }
    return cast(string)(r.reverse);
}

/+
string toHexString(T)(T s)
{
    string r;
    for(int i=s.length; i<8; ++i)
    {
        r ~= "-------- ";
    }
    foreach(Digit d;s)
    {
        r ~= format("%08X ",d);
    }
    return r;
}
+/

Signed toSigned(Unsigned s, bool neg=false)
{
    Signed r;
    r.neg = neg;
    r.s = s;
    return r;
}

T shrink(T)(T s)
{
    while(s.length > 1 && s[0] == ZERO)
    {
        s = s[1..$];
    }
    return s;
}

bool isZero(Unsigned s)
{
    return s == [ZERO];
}

bool isEven(Unsigned s)
{
    static assert((RADIX & 1) == 0);
    Digit c = s[$-1];
    return (c & 1) == (ZERO & 1);
}

Digit lsd(Unsigned s) // Least Significant Digit
{
    return s[$-1];
}

Digit msd(Unsigned s) // Most Significant Digit
{
    return s[0];
}

Unsigned shrDigit(Unsigned s)
{
    s = s[0..$-1];
    if (s.length == 0) return [ZERO];
    return s;
}

Unsigned shlDigit(Unsigned s)
{
    return isZero(s) ? s : ZERO ~ s;
}

Unsigned addOne(Unsigned s)
{
    Buffer r = new Digit[s.length+1];
    Digit c = 0;
    r[$-1] = add(s[$-1],ONE,c);
    for (int i=1; i<s.length; ++i)
    {
        r[$-i-1] = add(s[$-i-1],ZERO,c);
    }
    r[0] = c + '0';
    return cast(Unsigned)shrink(r);
}

Unsigned subOne(Unsigned s)
{
    Buffer r = new Digit[s.length+1];
    Digit c = 0;
    r[$-1] = sub(s[$-1],ONE,c);
    for (int i=1; i<s.length; ++i)
    {
        r[$-i-1] = sub(s[$-i-1],ZERO,c);
    }
    r[0] = c + '0';
    return cast(Unsigned)shrink(r);
}

Unsigned add(Unsigned s, Unsigned t)
{
    if (s.length < t.length) swap(s,t);
    Buffer r = new Digit[s.length+1];
    int i;
    Digit c = 0;
    for (i=0; i<t.length; ++i)
    {
        r[$-i-1] = add(s[$-i-1],t[$-i-1],c);
    }
    for (; i<s.length; ++i)
    {
        r[$-i-1] = add(s[$-i-1],ZERO,c);
    }
    r[0] = c + ZERO;
    return cast(Unsigned)shrink(r);
}

Signed sub(Unsigned s, Unsigned t)
{
    int n = cmp(s,t);
    if (n == 0) return toSigned([ZERO]);
    if (n < 0) swap(s,t);
    Buffer r = new Digit[s.length+1];
    int i;
    Digit c = 0;
    for (i=0; i<t.length; ++i)
    {
        r[$-i-1] = sub(s[$-i-1],t[$-i-1],c);
    }
    for (; i<s.length; ++i)
    {
        r[$-i-1] = sub(s[$-i-1],ZERO,c);
    }
    r[0] = c + ZERO;
    auto a = cast(Unsigned)shrink(r);
    return toSigned(a, n < 0);
}

Unsigned usub(Unsigned s, Unsigned t)
{
    return sub(s,t).s;
}

class CachingMultiplier
{
    Unsigned[Unsigned] map;
    Unsigned n;

    this(Unsigned s)
    {
        n = s;
        map[[ONE]] = s;
    }

    Unsigned mul(Unsigned t)
    {
        auto p = t in map;
        if (p != null) return *p;

        auto a = shr(t,1);
        auto u = mul(a);
        auto v = u;
        if (!isEven(t))
        {
            v = add(v,n);
            map[addOne(a)] = v;
        }
        auto r = add(u,v);
        map[t] = r;
        return r;
    }
}

Unsigned mul(Unsigned s, Unsigned t)
{
    void acc(Buffer r, Digit k)
    {
        DoubleDigit c = 0;
        for (int i=0; i<t.length; ++i)
        {
            r[$-i-1] = addMul(r[$-i-1],t[$-i-1],k,c);
        }
        r[0] = cast(Digit)(c + ZERO);
    }

    Buffer r = new Digit[s.length + t.length];
    r[] = ZERO;
    for (int i=0; i<s.length; ++i)
    {
        acc(r[$-i-t.length-1..$-i],s[$-i-1]-ZERO);
    }
    return cast(Unsigned)shrink(r);
}

struct UnsignedPair // workaround for bug in Tuple!
{
    Unsigned _0;
    Unsigned _1;
}

UnsignedPair divmod(Unsigned s, Unsigned t)
{
    int testResult = cmp(s,t);
    if (testResult == 0) return UnsignedPair([ONE],[ZERO]);
    if (testResult < 0) return UnsignedPair([ZERO],s);

    Unsigned remainder;
    Unsigned lowerBound = usub(s,t);
    alias s upperBound;
    auto multiplier = new CachingMultiplier(t);

    int test(Unsigned quotient)
    {
        auto product = multiplier.mul(quotient);
        testResult = cmp(product,lowerBound);
        if (testResult <= 0) return -1;
        testResult = cmp(product,upperBound);
        if (testResult > 0) return 1;
        remainder = usub(product,s);
        return 0;
    }

    int tailLength = t.length - 1;
    auto numerator = s[0..$-tailLength];
    auto denominator = msd(t) - ZERO;

    // quotient cannot be less than numerator/(denominator+1)
    Unsigned minQuotient = (denominator == RADIX - 1)
        ? shrDigit(numerator)
        : divmod(numerator,denominator+1)._0;
    if (test(minQuotient) == 0) return UnsignedPair(minQuotient,remainder);

    // quotient cannot be greater than (numberator+1)/denominator
    Unsigned maxQuotient = divmod(addOne(numerator),denominator)._0;
    if (test(maxQuotient) == 0) return UnsignedPair(maxQuotient,remainder);

    // Simple binary search
    while(true)
    {
        Unsigned quotient = shr(add(minQuotient,maxQuotient),1);
        assert(quotient != minQuotient);
        assert(quotient != maxQuotient);

        testResult = test(quotient);
        if (testResult == 0) return UnsignedPair(quotient,remainder);
        if (testResult < 0)
            minQuotient = quotient;
        else
            maxQuotient = quotient;
    }
    assert(false);
}

Tuple!(Unsigned,Digit) divmod(Unsigned s, Digit t)
{
    Buffer r = new Digit[s.length];
    DoubleDigit c = 0;
    for (int i=0; i<s.length; ++i)
    {
        c = c * RADIX + s[i] - ZERO;
        DoubleDigit u = c / t;
        r[i] = cast(Digit)(u + ZERO);
        c -= u * t;
    }
    return tuple(cast(Unsigned)shrink(r),cast(Digit)c);
}

Unsigned and(Unsigned s, Unsigned t)
{
    if (s.length < t.length) swap(s,t);
    Buffer r = new Digit[t.length];
    int i;
    for (i=0; i<t.length; ++i)
    {
        r[$-i-1] = s[$-i-1] & t[$-i-1];
    }
    return cast(Unsigned)shrink(r);
}

Unsigned or(Unsigned s, Unsigned t)
{
    if (s.length < t.length) swap(s,t);
    Buffer r = new Digit[s.length];
    int i;
    for (i=0; i<t.length; ++i)
    {
        r[$-i-1] = s[$-i-1] | t[$-i-1];
    }
    for (; i<s.length; ++i)
    {
        r[$-i-1] = s[$-i-1];
    }
    return cast(Unsigned)shrink(r);
}

Unsigned xor(Unsigned s, Unsigned t)
{
    if (s.length < t.length) swap(s,t);
    Buffer r = new Digit[s.length];
    int i;
    for (i=0; i<t.length; ++i)
    {
        r[$-i-1] = s[$-i-1] ^ t[$-i-1];
    }
    for (; i<s.length; ++i)
    {
        r[$-i-1] = s[$-i-1];
    }
    return cast(Unsigned)shrink(r);
}

Unsigned shl(Unsigned s, uint n)
in
{
    assert((1L<<n) < RADIX);
}
body
{
    Buffer r = new Digit[s.length+1];
    DoubleDigit c;
    Digit d = 0;
    for (int i=0; i<s.length; ++i)
    {
        c = ((s[$-i-1] - ZERO) << n) + d;
        r[$-i-1] = cast(Digit)((c % RADIX) + ZERO);
        d = c / RADIX;
    }
    c = (c << n) | d;
    r[0] = cast(Digit)(c + 0);
    return cast(Unsigned)shrink(r);
}

Unsigned shr(Unsigned s, uint n)
in
{
    assert((1L<<n) < RADIX);
}
body
{
    uint mask = (1 << n) - 1;
    Buffer r = new Digit[s.length];
    DoubleDigit c = 0;
    for (int i=0; i<s.length; ++i)
    {
        c = c * RADIX + s[i] - ZERO;
        DoubleDigit u = c >>> n;
        r[i] = cast(Digit)(u + ZERO);
        c &= mask;
    }
    return cast(Unsigned)shrink(r);
}

int cmp(Unsigned s, Unsigned t)
{
    s = shrink(s);
    t = shrink(t);
    if (s.length < t.length) return -1;
    if (s.length > t.length) return 1;
    for (int i=0; i<s.length; ++i)
    {
        if (s[i] < t[i]) return -1;
        if (s[i] > t[i]) return 1;
    }
    return 0;
}

// ---------------------------------------------------------------
// The very, very lowest level. These function deal only in Digits

Digit add(Digit a, Digit b, ref Digit c)
in
{
    assert(isValidDigit(a));
    assert(isValidDigit(b));
    assert(isValidCarry(c));
}
out (r)
{
    assert(isValidDigit(r));
}
body
{
    DoubleDigit r = ((cast(DoubleDigit)(a-ZERO) + (b-ZERO)) + c);
    if (r >= RADIX)
    {
        r -= RADIX;
        c = 1;
    }
    else
    {
        c = 0;
    }
    return cast(Digit)(r + ZERO);
}

Digit addMul(Digit a, Digit b, Digit k, ref DoubleDigit c)
in
{
    assert(isValidDigit(a));
    assert(isValidDigit(b));
    assert(isValidCarry(k));
}
out (r)
{
    assert(isValidDigit(r));
}
body
{
    DoubleDigit r = ((cast(DoubleDigit)(b - ZERO) * k) + (a - ZERO)) + c;
    c = (r / RADIX);
    r = (r % RADIX);
    return cast(Digit)r + ZERO;
}

Digit sub(Digit a, Digit b, ref Digit c)
in
{
    assert(isValidDigit(a));
    assert(isValidDigit(b));
    assert(isValidCarry(c));
}
out (r)
{
    assert(isValidDigit(r));
}
body
{
    DoubleDigit r = ((cast(DoubleDigit)(a-ZERO) - (b-ZERO)) - c);
    if (r >= RADIX)
    {
        r += RADIX;
        c = 1;
    }
    else
    {
        c = 0;
    }
    return cast(Digit)(r + ZERO);
}

bool isValidDigit(T)(T x)
{
    if (x < ZERO) return false;
    return isValidCarry(x - ZERO);
}

bool isValidCarry(T)(T x)
{
    return (x >= 0 && x < RADIX);
}


