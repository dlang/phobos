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

Macros:
    WIKI=Phobos/StdBigint

Copyright: Copyright Janice Caron 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   Janice Caron

         Copyright Janice Caron 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.bigint;

import std.string       : format;
import std.stdio        : writef, writefln;
import std.algorithm    : min, max, swap, reverse;
import std.traits       : isIntegral;
import std.contracts    : assumeUnique;

alias uint Digit; /// alias for uint

/******************
 * Struct representing a multiprecision integer
 */
struct BigInt
{
    Digits digits = [ cast(Digit)0 ];

    static const BigInt ZERO = { [ cast(Digit)0 ] };
    static const BigInt ONE = { [ cast(Digit)1 ] };

    ///
    void opAssign(const BigInt n)
    {
        digits = n.digits;
    }

    ///
    void opAssign(int n)
    {
        digits = cast(Digits)( [ cast(Digit)n ] );
    }

    ///
    void opAssign(uint n)
    {
        static if(BIG_ENDIAN) { Digits a = [ cast(Digit)0, n ]; }
        else                  { Digits a = [ cast(Digit)n, 0 ]; }
        Big b = bigInt(a);
        digits = b.digits;
    }

    ///
    void opAssign(long n)
    {
        static if(BIG_ENDIAN) { Digits a = [ cast(Digit)(n>>32), cast(Digit)n ]; }
        else                  { Digits a = [ cast(Digit)n, cast(Digit)(n>>32) ]; }
        Big b = bigInt(a);
        digits = b.digits;
    }

    ///
    void opAssign(ulong n)
    {
        static if(BIG_ENDIAN) { Digits a = [ cast(Digit)0, cast(Digit)(n>>32), cast(Digit)n ]; }
        else                  { Digits a = [ cast(Digit)n, cast(Digit)(n>>32), cast(Digit)0 ]; }
        Big b = bigInt(a);
        digits = b.digits;
    }

    ///
    void opAssign(string s)
    {
        Big b = fromString(s);
        digits = b.digits;
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
        r.digits = digits;
    }

    ///
    void castTo(out int r) const
    {
        r = cast(int)tail(digits,1u)[0];
    }

    ///
    void castTo(out uint r) const
    {
        r = cast(uint)tail(digits,1u)[0];
    }

    ///
    void castTo(out long r) const
    {
        ulong t;
        castTo(t);
        r = cast(long)t;
    }

    ///
    void castTo(out ulong r) const
    {
        mixin(setUp("x","this"));
        r = peek(xp);
        xp = next(xp);
        if (xp != xe) r += cast(ulong)(peek(xp)) << 32;
    }

    ///
    void castTo(out string r) const
    {
        r = decimal(this);
    }

    // Unary operator overloads

    ///
    BigInt opPos() const
    {
        BigInt r;
        r.digits = digits;
        return r;
    }

    ///
    BigInt opNeg() const
    {
        return neg(this);
    }

    ///
    BigInt opCom() const
    {
        return com(this);
    }

    ///
    BigInt opPostInc()
    {
        BigInt n = this;
        opAddAssign(1);
        return n;
    }

    ///
    BigInt opPostDec()
    {
        BigInt n = this;
        opSubAssign(1);
        return n;
    }

    // Binary operator overloads

    ///
    BigInt opAdd(T)(T n) const
    {
        return opAdd(BigInt(n));
    }

    ///
    BigInt opAdd(T:int)(T n) const
    {
        return add(this,cast(Digit)n);
    }

    ///
    BigInt opAdd(T:const(BigInt))(T n) const
    {
        return add(this,n);
    }

    ///
    void opAddAssign(T)(T n)
    {
        auto r = opAdd(n);
        digits = r.digits;
    }

    ///
    BigInt opSub(T)(T n) const
    {
        return opSub(BigInt(n));
    }

    ///
    BigInt opSub(T:int)(T n) const
    {
        return sub(this,cast(Digit)n);
    }

    ///
    BigInt opSub(T:const(BigInt))(T n) const
    {
        return sub(this,n);
    }

    ///
    void opSubAssign(T)(T n)
    {
        auto r = opSub(n);
        digits = r.digits;
    }

    ///
    BigInt opMul(T)(T n) const
    {
        return opMul(BigInt(n));
    }

    ///
    BigInt opMul(T:int)(T n) const
    {
        if (cast(int)n == int.min) return opMul(BigInt(n));
        int xs = sgn;
        if (xs == 0 || n == 0) return BigInt.ZERO;
        int ys = n > 0 ? 1 : -1;
        auto x = abs;
        auto y = n > 0 ? n : -n;
        auto r = mul(x,y);
        return (xs == ys) ? r : -r;
    }

    ///
    BigInt opMul(T:const(BigInt))(T n) const
    {
        int xs = sgn;
        int ys = n.sgn;
        if (xs == 0 || ys == 0) return BigInt.ZERO;
        auto x = abs;
        auto y = n.abs;
        auto r = mul(x,y);
        return (xs == ys) ? r : -r;
    }

    ///
    void opMulAssign(T)(T n)
    {
        auto r = opMul(n);
        digits = r.digits;
    }

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

    ///
    BigInt opDiv(T)(T n) const
    {
        return opDiv(BigInt(n));
    }

    ///
    BigInt opDiv(T:int)(T n) const
    {
        if (n == 0) throw new Exception("Divide by zero");
        if (cast(int)n == int.min) return opDiv(BigInt(n));
        int xs = sgn;
        int ys = n > 0 ? 1 : -1;
        if (xs == 0) return BigInt.ZERO;
        auto x = abs;
        auto y = n > 0 ? n : -n;
        auto r = div(x,y);
        return (xs == ys) ? r.q : -r.q;
    }

    ///
    BigInt opDiv(T:const(BigInt))(T n) const
    {
        int xs = sgn;
        int ys = n.sgn;
        if (ys == 0) throw new Exception("Divide by zero");
        if (xs == 0) return BigInt.ZERO;
        auto x = abs;
        auto y = n.abs;
        auto r = div(x,y);
        return (xs == ys) ? r.q : -r.q;
    }

    ///
    void opDivAssign(T)(T n)
    {
        auto r = opDiv(n);
        digits = r.digits;
    }

    ///
    BigInt opMod(T)(T n) const
    {
        return opMod(BigInt(n));
    }

    ///
    int opMod(T:int)(T n) const
    {
        if (n == 0) throw new Exception("Divide by zero");
        int xs = sgn;
        if (xs == 0) return n;
        auto x = abs;
        auto y = n > 0 ? n : -n;
        auto r = div(x,y);
        return (xs == 1) ? r.r : -r.r;
    }

    ///
    BigInt opMod(T:const(BigInt))(T n) const
    {
        int xs = sgn;
        int ys = n.sgn;
        if (ys == 0) throw new Exception("Divide by zero");
        if (xs == 0) return n;
        auto x = abs;
        auto y = n.abs;
        auto r = div(x,y);
        assert(r.r.abs < n.abs);
        return (xs == 1) ? r.r : -r.r;
    }

    ///
    void opModAssign(T:int)(T n)
    {
        auto r = opMod(BigInt(n));
        digits = r.digits;
    }

    ///
    void opModAssign(T)(T n)
    {
        auto r = opMod(n);
        digits = r.digits;
    }

    ///
    BigInt opAnd(T)(T n) const
    {
        return opAnd(BigInt(n));
    }

    ///
    BigInt opAnd(T:int)(T n) const
    {
        return and(this,cast(Digit)n);
    }

    ///
    uint opAnd(T:uint)(T n) const
    {
        uint t;
        castTo(t);
        return t & n;
    }

    ///
    BigInt opAnd(T:const(BigInt))(T n) const
    {
        return and(this,n);
    }

    ///
    void opAndAssign(T:uint)(T n)
    {
        auto r = opAnd(BigInt(n));
        digits = r.digits;
    }

    ///
    void opAndAssign(T)(T n)
    {
        auto r = opAnd(n);
        digits = r.digits;
    }

    ///
    BigInt opOr(T)(T n) const
    {
        return opOr(BigInt(n));
    }

    ///
    BigInt opOr(T:int)(T n) const
    {
        return or(this,cast(Digit)n);
    }

    ///
    BigInt opOr(T:const(BigInt))(T n) const
    {
        return or(this,n);
    }

    ///
    void opOrAssign(T)(T n)
    {
        auto r = opOr(n);
        digits = r.digits;
    }

    ///
    BigInt opXor(T)(T n) const
    {
        return opXor(BigInt(n));
    }

    ///
    BigInt opXor(T:int)(T n) const
    {
        return xor(this,cast(Digit)n);
    }

    ///
    BigInt opXor(T:const(BigInt))(T n) const
    {
        return xor(this,n);
    }

    ///
    void opXorAssign(T)(T n)
    {
        auto r = opXor(n);
        digits = r.digits;
    }

    ///
    BigInt opShl(uint n) const
    {
        uint hi = n >> 5;
        uint lo = n & 0x1F;
        Big r = this;
        if (lo != 0) r = shl(r,lo);
        if (hi != 0) r = shlDigits(r,hi);
        return r;
    }

    ///
    void opShlAssign(uint n)
    {
        auto r = opShl(n);
        digits = r.digits;
    }

    ///
    BigInt opShr(uint n) const
    {
        uint hi = n >> 5;
        uint lo = n & 0x1F;
        Big r = this;
        if (lo != 0) r = shr(r,lo).q;
        if (hi != 0) r = shrDigits(r,hi);
        return r;
    }

    ///
    void opShrAssign(uint n)
    {
        auto r = opShr(n);
        digits = r.digits;
    }
    
    ///
    BigInt opUShr(T)(T n) const
    {
        if (sgn >= 0) return opShr(n);
        else throw new Exception(">>> cannot be applied to negative numbers");
    }
    
    ///
    void opUShrAssign(T)(T n)
    {
        if (sgn >= 0) opShrAssign(n);
        else throw new Exception(">>>= cannot be applied to negative numbers");
    }

    ///
    int opEquals(T)(T n) const
    {
        return opEquals(BigInt(n));
    }

    ///
    int opEquals(T:int)(T n) const
    {
        return digits.length == 1 && digits[0] == n;
    }

    ///
    int opEquals(T:const(BigInt))(T n) const
    {
        return digits == n.digits;
    }

    ///
    int opCmp(T)(T n) const
    {
        return opCmp(BigInt(n));
    }

    ///
    int opCmp(T:int)(T n) const
    {
        int t = cmp(this,n);
        return t == 0 ? 0 : (t > 0 ? 1 : -1);
    }

    ///
    int opCmp(T:const(BigInt))(T n) const
    {
        int t = cmp(this,n);
        return t == 0 ? 0 : (t > 0 ? 1 : -1);
    }

    ///
    string toString() const
    {
        return decimal(this);
    }

    ///
    hash_t toHash() const
    {
        hash_t h = 0;
        foreach(Digit d;digits) { h += d; }
        return h;
    }

    private int sgn() const
    {
        int t = cmp(this,0);
        return t == 0 ? 0 : (t > 0 ? 1 : -1);
    }

    private BigInt abs() const
    {
        return sgn >= 0 ? opPos : opNeg;
    }
}

// ----------- EVERYTHING PRIVATE BEYOND THIS POINT -----------
private:

// Aliases and Typedefs

alias BigInt                Big;
alias invariant(Digit)[]    Digits;
typedef Digit[]             DownArray;
typedef Digit*              DownPtr;
alias int                   SignedDigit;
alias long                  SignedWideDigit;
alias Digit                 Unused;
typedef Digit[]             UpArray;
typedef Digit*              UpPtr;
alias ulong                 WideDigit;

struct Big_Digit { Big q; Digit r; }
struct Big_Big{ Big q; Big r; }

// Endianness

// The constant BIG_ENDIAN determines the ordering of digits within arrays.
// If BIG_ENDIAN is true, then bigints are stored most significant digit first.
// If BIG_ENDIAN is true, then bigints are stored most significant digit last.

// Note that this does not necessarily have to be the same as the endianness
// of the platform architecture.

// Setting BIG_ENDIAN opposite to platform endianness allows unittests
// to run in reverse endianness. (And they still pass).

version(BigEndian) { enum bool BIG_ENDIAN = true; }
else               { enum bool BIG_ENDIAN = false; }

// String conversion

void parseError()
{
    throw new Exception("Parse Error");
}

Big fromString(string s)
{
    if (s.length == 0) parseError();
    if (s[0] == '-')
    {
        return -fromString(s[1..$]);
    }
    if (s.length > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
    {
        return fromHex(s[2..$]);
    }
    return fromDecimal(s);
}

Big fromDecimal(string s)
{
    bool invalid = true;
    Big r = Big.ZERO;
    foreach(char c;s)
    {
        if (c == '_') continue;
        if (c < '0' || c > '9') parseError();
        invalid = false;
        //r = 10 * r + (c - '0');
        r *= 10;
        r += (c - '0');
    }
    if (invalid) parseError();
    return r;
}

Big fromHex(string s)
{
    bool invalid = true;
    Big r = Big.ZERO;
    foreach(char c;s)
    {
        switch(c)
        {
        case '_':
            continue;

        case '0','1','2','3','4','5','6','7','8','9':
            r = (r << 4) + (c - '0');
            invalid = false;
            break;

        case 'A','B','C','D','E','F':
            r = (r << 4) + (c - 'A' + 10);
            invalid = false;
            break;

        case 'a','b','c','d','e','f':
            r = (r << 4) + (c - 'a' + 10);
            invalid = false;
            break;

        default:
            parseError();
        }
    }
    if (invalid) parseError();
    return r;
}

string decimal(Big b)
{
    if (b == 0) return "0";
    if (b < 0) return "-" ~ decimal(-b);
    
    char[] result;
    while (b != Big.ZERO) {
        auto t = div(b, 10);
        b = t.q;
        result ~= cast(char)(t.r + '0');
    }
    reverse(cast(ubyte[]) result);
    return assumeUnique(result);
}

// Shrinking

Big bigInt(DownArray a)
{
    if (a.length == 0) return Big.ZERO;

    Big r;

    if (a.length == 1)
    {
        r.digits = cast(Digits)a;
    }
    else
    {
        auto xp = begin(a);
        auto xe = end(a);
        auto d1 = peek(xp);
        xp = next(xp);
        auto s = signOf(d1);
        while (xp != xe)
        {
            if (d1 != s) break;
            auto d2 = peek(xp);
            if (signOf(d2) != s) break;
            xp = next(xp);
            d1 = d2;
        }
        r.digits = freezeRange(xp, xe);
    }
    return r;
}

static if(BIG_ENDIAN)
{
    alias UpArray       BwdArray;
    alias UpPtr         BwdPtr;
    alias DownArray     FwdArray;
    alias DownPtr       FwdPtr;

    Digit[] join(Digit[] t, Digit[] u) { return t ~ u; }
    T head(T)(T t,size_t n) { return cast(T)(t[0..n]); }
    T tail(T)(T t,size_t n) { return cast(T)(t[$-n..$]); }
}
else
{
    alias DownArray     BwdArray;
    alias DownPtr       BwdPtr;
    alias UpArray       FwdArray;
    alias UpPtr         FwdPtr;

    Digit[] join(Digit[] t, Digit[] u) { return u ~ t; }
    T head(T)(T t,size_t n) { return cast(T)(t[$-n..$]); }
    T tail(T)(T t,size_t n) { return cast(T)(t[0..n]); }
}

// Really simple functions

FwdPtr advance(FwdPtr p,size_t n) { return p + n; }
BwdPtr advance(BwdPtr p,size_t n) { return p - n; }

Digit begin(Digit a) { return a; }
FwdPtr begin(FwdArray a) { return cast(FwdPtr)(a.ptr); }
BwdPtr begin(BwdArray a) { return cast(BwdPtr)(a.ptr + a.length - 1); }

Big bigInt(Digit a) { Digit[] t; t.length = 1; t[0] = a; return bigInt(cast(DownArray)t); }
Big bigInt(Digits a) { return bigInt(cast(DownArray)a); }
Big bigInt(Digit[] a) { return bigInt(cast(DownArray)a); }
Big bigInt(UpArray a) { return bigInt(cast(DownArray)a); }

Digit downArray(Digit a) { return a; }
DownArray downArray(Digit[] a) { return cast(DownArray)a; }
DownArray downArray(Big a) { return cast(DownArray)(a.digits); }

Digit end(Digit a) { return a; }
FwdPtr end(FwdArray a) { return cast(FwdPtr)(a.ptr + a.length); }
BwdPtr end(BwdArray a) { return cast(BwdPtr)(a.ptr + - 1); }

Digit first(Digit a) { return a; }
Digit first(FwdArray a) { return a[0]; }
Digit first(BwdArray a) { return a[$-1]; }

Digits freezeRange(FwdPtr p, FwdPtr q) { return cast(Digits)((p-1)[0..(q-p+1)]); }
Digits freezeRange(BwdPtr p, BwdPtr q) { return cast(Digits)((q+1)[0..(p-q+1)]); }

Digit last(Digit a) { return a; }
Digit last(FwdArray a) { return a[$-1]; }
Digit last(BwdArray a) { return a[0]; }

Digit lsd(Digit a) { return a; }
Digit lsd(DownArray a) { return last(a); }
Digit lsd(UpArray a) { return first(a); }

Digit msd(Digit a) { return a; }
Digit msd(DownArray a) { return first(a); }
Digit msd(UpArray a) { return last(a); }

size_t lengthOf(Digit a) { return 1; }
size_t lengthOf(Big a) { return a.digits.length; }
size_t lengthOf(DownArray a) { return a.length; }
size_t lengthOf(UpArray a) { return a.length; }

Digit next(ulong d) { return cast(Digit)d; }
Digit next(Digit d) { return d; }
FwdPtr next(FwdPtr p) { return p + 1; }
BwdPtr next(BwdPtr p) { return p - 1; }

Digit peek(ulong d) { return cast(Digit)d; }
Digit peek(Digit d) { return d; }
Digit peek(Digit* p) { return *p; }

void poke(DownPtr p,Digit d) { *p = d; }
void poke(DownPtr p,WideDigit d) { *p = cast(Digit)d; }
void poke(DownPtr p,SignedWideDigit d) { *p = cast(Digit)d; }
void poke(UpPtr p,Digit d) { *p = d; }
void poke(UpPtr p,WideDigit d) { *p = cast(Digit)d; }
void poke(UpPtr p,SignedWideDigit d) { *p = cast(Digit)d; }

Big shrink(Big a) { return bigInt(cast(DownArray)(a.digits)); }

FwdArray slice(FwdPtr ptr, size_t len) { return cast(FwdArray)(ptr[0..len]); }
BwdArray slice(BwdPtr ptr, size_t len) { return cast(BwdArray)((ptr-len+1)[0..len]); }

Digit signOf(SignedDigit d) { return d < 0 ? -1 : 0; }

Digit upArray(Digit a) { return a; }
UpArray upArray(Digit[] a) { return cast(UpArray)a; }
UpArray upArray(in Big a) { return cast(UpArray)(a.digits); }

// Core functions

WideDigit addCore(Digit x,Digit y,WideDigit c) { return (c + x) + y; }

Digit andCore(Digit x,Digit y,Digit c) { return x & y; }

WideDigit divCore(Digit x,Digit y,WideDigit c)
{
    c <<= 32;
    c += x;
    WideDigit r = c % y;
    c /= y;
    c += r << 32;
    return c;
}

WideDigit shlCore(Digit x,Digit y,WideDigit c) { return c + (cast(WideDigit)x << y); }

WideDigit shrCore(Digit x,Digit y,WideDigit c) { return c + (x >> y) + (cast(WideDigit)x << (64-y)); }

WideDigit mulCore(Digit x,Digit y,WideDigit c) { return c + (cast(WideDigit)x * y); }

WideDigit subCore(Digit x,Digit y,WideDigit c) { return (c + x) - y; }

Digit orCore(Digit x,Digit y,Digit c) { return x | y; }

Digit xorCore(Digit x,Digit y,Digit c) { return x ^ y; }

// Update functions

Digit updateDigit(Digit c) { return c; }

WideDigit updateShr(WideDigit c) { return cast(WideDigit)(cast(SignedWideDigit)c >> 32); }

WideDigit updateUShr(WideDigit c) { return c >> 32; }

// Helper functions

int cmp(DownPtr xp, DownPtr xe, DownPtr yp)
{
    while (xp != xe)
    {
        auto xd = peek(xp);
        auto yd = peek(yp);
        if (xd < yd) return -1;
        if (xd > yd) return 1;
        xp = next(xp);
        yp = next(yp);
    }
    return 0;
}

void mulInner(Big a, UpPtr rp, WideDigit y)
{
    WideDigit c;
    mixin(setUp("x","a"));

    while (xp != xe)
    {
        c += y * peek(xp) + peek(rp);
        poke(rp,c);
        xp = next(xp);
        rp = next(rp);
        c = updateUShr(c);
    }

    mixin(runOnce(   "mulCore","updateUShr","xs","y"));
}

void divInner(DownPtr xp, DownPtr cachePtr, size_t len)
{
    Digit result;

    debug // sanity checking
    {
        DownArray _divisor = slice(cachePtr,32*len);
        _divisor = tail(_divisor,len);
    }

    DownPtr rp = xp;
    xp = next(xp);
    DownPtr xe = advance(xp,len);

    debug // sanity checking
    {
        DownArray _remainder = slice(xp,len);  // will be modified in-place
        DownArray _original = cast(DownArray)_remainder.dup;  // but we'll keep this one
    }

    for (Digit mask=0x80000000; mask!=0; mask>>=1)
    {
        int t = cmp(xp,xe,cachePtr);
        if (t >= 0)
        {
            debug // sanity checking
            {
                DownArray _after = slice(xp,len);   // will be modified in-place
                DownArray _before = cast(DownArray)_after.dup;     // but we'll keep this one
                DownArray _test = slice(cachePtr,len);
            }

            result += mask;
            Digit carry = subInPlace(xp,cachePtr,len);
            debug
            {
                BigInt before = bigInt(_before);
                BigInt test = bigInt(_test);
                BigInt after = bigInt(_after);

                assert(after + test == before);
                assert(carry == 0);
            }
        }
        cachePtr = advance(cachePtr,len);
    }

    debug // sanity checking
    {
        // in theory, quotient * _divisor + _remainder == _original
        BigInt quotient = result;
        BigInt divisor = bigInt(_divisor);
        BigInt remainder = bigInt(_remainder);
        BigInt original = bigInt(_original);

        assert(quotient * divisor + remainder == original);
    }

    poke(rp,result);
}

Digit subInPlace(DownPtr downPtrX, DownPtr downPtrY, size_t len)
{
    UpPtr xp = cast(UpPtr)(advance(downPtrX,len-1));
    UpPtr yp = cast(UpPtr)(advance(downPtrY,len-1));
    UpPtr xe = advance(xp,len);

    SignedWideDigit c;

    while (xp != xe)
    {
        c += peek(xp);
        c -= peek(yp);
        poke(xp,c);
        c >>= 32;
        xp = next(xp);
        yp = next(yp);
    }

    return cast(Digit)c;
}

DownPtr makeDivCache(DownArray y)
{
    // Pad with a leading zero
    auto paddedY = cast(UpArray)(join([Digit.init],y));

    auto upCache = cast(UpArray)new Digit[32 * paddedY.length];
    auto rp = begin(upCache);

    // Fill upCache by successively leftshifting x by one bit
    for (int i=0; i<32; ++i)
    {
        auto xp = begin(paddedY);
        auto xe = end(paddedY);

        WideDigit c;

        // Shift lefy by one bit
        while (xp != xe)
        {
            Digit xd = peek(xp);
            poke(rp,xd);
            c += xd;
            c += xd;
            poke(xp,c);
            c >>= 32;
            xp = next(xp);
            rp = next(rp);
        }
    }

    auto downCache = cast(DownArray)upCache;

    static if(false) // make true to display cache
    {
        for (int j=0; j<32; ++j)
        {
            writefln("bit %02d: ",31-j,hex(downCache[paddedY.length*j..paddedY.length*(j+1)]));
        }
    }

    return begin(downCache);
}

// Mixins

string runOnce(string core, string updater, string xp, string yp)
{
    return
    "{
        auto xd = peek("~xp~");
        auto yd = peek("~yp~");
        c = "~core~"(xd,yd,c);
        poke(rp,c);
        "~xp~" = next("~xp~");
        "~yp~" = next("~yp~");
        rp = next(rp);
        c = "~updater~"(c);
    }";
}

string runTo(string dest, string core, string updater, string xp, string yp)
{
    string s = runOnce(core,updater,xp,yp);
    return
    "
        static if(isIntegral!(typeof("~dest~"))) {"~s~"}
        else
        {
            while("~dest[0..1]~"p!="~dest~") {"~s~"}
        }
    ";
}

string setDown(string x,string a)
{
    return
    "
        auto "~x~" = downArray("~a~");
        auto "~x~"p = begin("~x~");
        auto "~x~"e = end("~x~");
        auto "~x~"s = signOf(msd("~x~"));
    ";
}

string setUp(string x,string a)
{
    return
    "
        auto "~x~" = upArray("~a~");
        auto "~x~"p = begin("~x~");
        auto "~x~"e = end("~x~");
        auto "~x~"s = signOf(msd("~x~"));
    ";
}

// BigInt functions

Big neg(Big b)
{
    auto r = upArray(new Digit[lengthOf(b) + 1]);
    auto rp = begin(r);

    SignedDigit a;
    WideDigit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runOnce(   "subCore","updateShr","xp","yp"));
    mixin(runTo("ye","subCore","updateShr","xs","yp"));
    mixin(runOnce(   "subCore","updateShr","xs","ys"));

    return bigInt(r);
}

Big com(Big a)
{
    auto r = upArray(new Digit[lengthOf(a)]);
    auto rp = begin(r);

    Digit c;

    mixin(setUp("x","a"));
    Digit ys = uint.max;

    mixin(runTo("xe","xorCore","updateDigit","xp","ys"));

    return bigInt(r);
}

Big add(Other)(Big a,Other b)
{
    static if(is(Other==BigInt)) if (lengthOf(a) < lengthOf(b))
    {
    swap(a,b);
    }
    auto r = upArray(new Digit[max(lengthOf(a),lengthOf(b)) + 1]);
    auto rp = begin(r);

    WideDigit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runTo("ye","addCore","updateShr","xp","yp"));
    mixin(runTo("xe","addCore","updateShr","xp","ys"));
    mixin(runOnce(   "addCore","updateShr","xs","ys"));

    return bigInt(r);
}

Big sub(Big a,Big b)
{
    auto r = upArray(new Digit[max(lengthOf(a),lengthOf(b)) + 1]);
    auto rp = begin(r);
    auto re = advance(rp,min(lengthOf(a),lengthOf(b)));

    WideDigit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runTo("re","subCore","updateShr","xp","yp"));
    if (lengthOf(x) >= lengthOf(y))
    {
        mixin(runTo("xe","subCore","updateShr","xp","ys"));
    }
    else
    {
        mixin(runTo("ye","subCore","updateShr","xs","yp"));
    }
    mixin(runOnce("subCore","updateShr","xs","ys"));

    return bigInt(r);
}

Big sub(Big a, Digit b)
{
    auto r = upArray(new Digit[lengthOf(a) + 1]);
    auto rp = begin(r);

    WideDigit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runOnce(   "subCore","updateShr","xp","yp"));
    mixin(runTo("xe","subCore","updateShr","xp","ys"));
    mixin(runOnce(   "subCore","updateShr","xs","ys"));

    return bigInt(r);
}

Big mul(Big a, Big b) // a and b must be positive
{
    auto r = upArray(new Digit[lengthOf(a) + lengthOf(b)]);
    auto rp = begin(r);

    mixin(setUp("y","b"));
    while (yp != ye)
    {
        mulInner(a,rp,peek(yp));
        yp = next(yp);
        rp = next(rp);
    }

    return bigInt(r);
}

Big mul(Big a, Digit b) // a and b must be positive
{
    auto r = upArray(new Digit[lengthOf(a) + 1]);
    auto rp = begin(r);

    WideDigit c;

    mixin(setUp("x","a"));

    mixin(runTo("xe","mulCore","updateShr","xp","b"));
    poke(rp,c);

    return bigInt(r);
}

Big_Big div(Big a, Big b) // a and b must be positive
{
    auto lenX = lengthOf(a);
    auto lenY = lengthOf(b) + 1;

    auto r = cast(DownArray)join(new Digit[lenY], cast(Digit[])a.digits);
    auto rp = begin(r);
    auto re = advance(rp,lenX);

    auto y = downArray(b);
    auto cache = makeDivCache(y);

    while (rp != re)
    {
        divInner(rp, cache, lenY);
        rp = next(rp);
    }

    Big quotient  = bigInt(cast(DownArray)(head(r,lenX)));
    Big remainder = bigInt(cast(DownArray)(tail(r,lenY)));

    return Big_Big(quotient,remainder);
}

Big_Digit div(Big a, Digit b) // a and b must be positive
{
    auto r = downArray(new Digit[lengthOf(a)]);
    auto rp = begin(r);

    WideDigit c;

    mixin(setDown("x","a"));

    mixin(runTo("xe","divCore","updateUShr","xp","b"));

    return Big_Digit(bigInt(r),cast(Digit)c);
}

Big and(Other)(Big a, Other b)
{
    static if(is(Other==BigInt)) if (lengthOf(a) < lengthOf(b)) { swap(a,b); }
    auto r = upArray(new Digit[max(lengthOf(a),lengthOf(b))]);
    auto rp = begin(r);

    Digit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runTo("ye","andCore","updateDigit","xp","yp"));
    mixin(runTo("xe","andCore","updateDigit","xp","ys"));

    return bigInt(r);
}

Big or(Other)(Big a, Other b)
{
    static if(is(Other==BigInt)) if (lengthOf(a) < lengthOf(b)) { swap(a,b); }
    auto r = upArray(new Digit[max(lengthOf(a),lengthOf(b))]);
    auto rp = begin(r);

    Digit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runTo("ye","orCore","updateDigit","xp","yp"));
    mixin(runTo("xe","orCore","updateDigit","xp","ys"));

    return bigInt(r);
}

Big xor(Other)(Big a, Other b)
{
    static if(is(Other==BigInt)) if (lengthOf(a) < lengthOf(b)) { swap(a,b); }
    auto r = upArray(new Digit[max(lengthOf(a),lengthOf(b))]);
    auto rp = begin(r);

    Digit c;

    mixin(setUp("x","a"));
    mixin(setUp("y","b"));

    mixin(runTo("ye","xorCore","updateDigit","xp","yp"));
    mixin(runTo("xe","xorCore","updateDigit","xp","ys"));

    return bigInt(r);
}

Big shl(Big a, Digit b)
{
    auto r = upArray(new Digit[lengthOf(a) + 1]);
    auto rp = begin(r);

    WideDigit c;

    mixin(setUp("x","a"));

    mixin(runTo("xe","shlCore","updateShr","xp","b"));
    poke(rp,c);

    return bigInt(r);
}

Big shlDigits(Big a, uint n)
{
    Big b;
    b.digits = cast(Digits)join(a.digits.dup, new Digit[n]);
    return b;
}

Big_Digit shr(Big a, Digit b)
{
    auto r = downArray(new Digit[lengthOf(a)]);
    auto rp = begin(r);

    mixin(setDown("x","a"));

    WideDigit c = (signOf(msd(x)) << (32-b)) & uint.max;

    mixin(runTo("xe","shrCore","updateUShr","xp","b"));

    return Big_Digit(bigInt(r),cast(Digit)(c >> (32-b)));
}

Big shrDigits(Big a, uint n)
{
    if (lengthOf(a) < n)
    {
        return bigInt(signOf(msd(downArray(a))));
    }
    Big b;
    b.digits = cast(Digits)head(a.digits, a.digits.length-n);
    return b;
}

int cmp(Big a, Big b) // assumes a and b are both shrunk
{
    mixin(setDown("x","a"));
    mixin(setDown("y","b"));

    if (xs != ys) return xs - ys;

    if (lengthOf(x) > lengthOf(y)) return cast(SignedDigit)xs < 0 ? -1 : 1;
    if (lengthOf(x) < lengthOf(y)) return cast(SignedDigit)ys < 0 ? 1 : -1;

    return cmp(xp,xe,yp);
}

int cmp(Big a, Digit b) // assumes a is shrunk
{
    mixin(setDown("x","a"));
    Digit ys = signOf(b);

    if (xs != ys) return xs - ys;

    if (lengthOf(x) > 1) return cast(SignedDigit)xs < 0 ? -1 : 1;

    return peek(xp) - b;
}

// Debugging functions

Big makeBig(Digits array...)
{
    Big r;
    static if(BIG_ENDIAN)
    {
        r.digits = array;
    }
    else
    {
        r.digits = cast(Digits)(array.dup.reverse);
    }
    return r;
}

string hex(Big x)
{
    return "\r" ~ hex(x.digits);
}

string hex(in Digit[] x)
{
    string r;
    static if(BIG_ENDIAN)
    {
        auto array = x;
    }
    else
    {
        auto array = x.dup.reverse;
    }
    for (int i=array.length; i<4; ++i)
    {
        r ~= "----------, ";
    }
    foreach(d;array)
    {
        r ~= format("0x%08X, ",d);
    }
    return r;
}

string dump(string name)
{
    return
    "{  writef(\"(%d) "~name~" = \",__LINE__);
        static if(is(typeof("~name~") == Digit)) writefln(\"Digit %08X\","~name~");
        else static if(is(typeof("~name~") == WideDigit)) writefln(\"WideDigit %016X\","~name~");
        else static if(is(typeof("~name~") == SignedDigit)) writefln(\"SignedDigit %08X\","~name~");
        else static if(is(typeof("~name~") == SignedWideDigit)) writefln(\"SignedWideDigit %016X\","~name~");
        else writefln(typeof("~name~").stringof,\" \","~name~");
    }";
}

void diag(int line = __LINE__, string file = __FILE__)
{
   writefln("%s(%d) executed.", file, line);
}

// Unittests

debug unittest
{
    // This block of unittests demonstrates that we can shrink arrays correctly
    {
        auto a = makeBig( 0x00000000 );
        auto r = shrink(a);
        assert(r.digits == a.digits, hex(r));
            }{
        auto a = makeBig( 0xFFFFFFFF );
        auto r = shrink(a);
        assert(r.digits == a.digits, hex(r));
            }{
        auto a = makeBig( 0x44444444 );
        auto r = shrink(a);
        assert(r.digits == a.digits, hex(r));
            }{
        auto a = makeBig( 0xCCCCCCCC );
        auto r = shrink(a);
        assert(r.digits == a.digits, hex(r));
            }{
        auto a = makeBig( 0x00000000, 0x00000000, 0x44444444, 0x44444444 );
        auto b = makeBig(                         0x44444444, 0x44444444 );
        auto r = shrink(a);
        assert(r.digits == b.digits, hex(r));
            }{
        auto a = makeBig( 0x00000000, 0x00000000, 0xCCCCCCCC, 0xCCCCCCCC );
        auto b = makeBig(             0x00000000, 0xCCCCCCCC, 0xCCCCCCCC );
        auto r = shrink(a);
        assert(r.digits == b.digits, hex(r));
            }{
        auto a = makeBig( 0xFFFFFFFF, 0xFFFFFFFF, 0x44444444, 0x44444444 );
        auto b = makeBig(             0xFFFFFFFF, 0x44444444, 0x44444444 );
        auto r = shrink(a);
        assert(r.digits == b.digits, hex(r));
    }
    // This block of unittests demonstrates that neg(Big) works
    {
        auto x = makeBig( 0x66666666, 0x66666660 );
        auto z = makeBig( 0x99999999, 0x999999A0 );
        auto r = neg(x);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig(             0x80000000, 0x00000000 );
        auto z = makeBig( 0x00000000, 0x80000000, 0x00000000 );
        auto r = neg(x);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x00000000, 0x80000000, 0x00000000 );
        auto z = makeBig(             0x80000000, 0x00000000 );
        auto r = neg(x);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that com(Big) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto z = makeBig( 0xFEDCBA98, 0x76543210 );
        auto r = com(x);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that add(Big,Big) works
    {
        auto x = makeBig(             0x66666666, 0x66666660 );
        auto y = makeBig(             0x77777777, 0x77777770 );
        auto z = makeBig( 0x00000000, 0xDDDDDDDD, 0xDDDDDDD0 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig(             0x99999999, 0x99999990 );
        auto y = makeBig(             0xAAAAAAAA, 0xAAAAAAA0 );
        auto z = makeBig( 0xFFFFFFFF, 0x44444444, 0x44444430 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0xEEEEEEEE, 0xEEEEEEE0 );
        auto y = makeBig( 0x66666666, 0x66666660 );
        auto z = makeBig( 0x55555555, 0x55555540 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x99999999, 0x99999990 );
        auto y = makeBig( 0x66666666, 0x66666660 );
        auto z = makeBig(             0xFFFFFFF0 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that add(Big,int) works
    {
        auto x = makeBig( 0x66666666, 0x66666660 );
        auto y =                      0x77777770  ;
        auto z = makeBig( 0x66666666, 0xDDDDDDD0 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x99999999, 0x99999990 );
        auto y =                      0xAAAAAAA0  ;
        auto z = makeBig( 0x99999999, 0x44444430 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0xEEEEEEEE, 0xEEEEEEE0 );
        auto y =                      0x66666660  ;
        auto z = makeBig( 0xEEEEEEEF, 0x55555540 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x99999999, 0x99999990 );
        auto y =                      0x66666660 ;
        auto z = makeBig( 0x99999999, 0xFFFFFFF0 );
        auto r = add(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that sub(Big,Big) works
    {
        auto x = makeBig( 0x22222222, 0x22222222, 0x22222222 );
        auto y = makeBig(             0x11111111, 0x11111111 );
        auto z = makeBig( 0x22222222, 0x11111111, 0x11111111 );
        auto r = sub(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig(             0x22222222, 0x22222222 );
        auto y = makeBig( 0x11111111, 0x11111111, 0x11111111 );
        auto z = makeBig( 0xEEEEEEEF, 0x11111111, 0x11111111 );
        auto r = sub(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that sub(Big,int) works
    {
        auto x = makeBig( 0x22222222, 0x22222222 );
        auto y =                      0x11111111  ;
        auto z = makeBig( 0x22222222, 0x11111111 );
        auto r = sub(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x22222222, 0x22222222 );
        auto y =                      0x80000000  ;
        auto z = makeBig( 0x22222222, 0xA2222222 );
        auto r = sub(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that mul(Big,Big) works
    {
        auto x = makeBig(                         0x01111111, 0x11111111 );
        auto y = makeBig(                         0x01111111, 0x11111111 );
        auto z = makeBig( 0x00012345, 0x6789ABCD, 0xEFEDCBA9, 0x87654321 );
        auto r = mul(x,y);
        assert(r.digits == z.digits, hex(r));
         // Bugzilla 2987
        BigInt a = "871782912000";
        BigInt b = "760005445655199744000000";
        assert(a * a == b);
    }

    // This block of unittests demonstrates that mul(Big,uint) works
    {
        auto x = makeBig(             0x11111111, 0x11111111 );
        auto y =                                  0x11111111  ;
        auto z = makeBig( 0x01234567, 0x88888888, 0x87654321 );
        auto r = mul(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that div(Big,Big) works
    {
        auto x = makeBig( 0x00000014 );
        auto y = makeBig( 0x00000007 );
        auto z = makeBig( 0x00000002 );
        auto w = makeBig( 0x00000006 );
        auto t = div(x,y);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r.digits == w.digits, hex(t.r));
            }{
        auto x = makeBig( 0x00012345, 0x6789ABCD, 0xEFEDCBA9, 0x87654321 );
        auto y = makeBig(                         0x01111111, 0x11111111 );
        auto z = makeBig(                         0x01111111, 0x11111111 );
        auto w = makeBig(                                     0x00000000 );
        auto t = div(x,y);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r.digits == w.digits, hex(t.r));
            }{
        auto x = makeBig( 0x00012345, 0x6789ABCD, 0xEFEDCBA9, 0x98765432 );
        auto y = makeBig(                         0x01111111, 0x11111111 );
        auto z = makeBig(                         0x01111111, 0x11111111 );
        auto w = makeBig(                                     0x11111111 );
        auto t = div(x,y);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r.digits == w.digits, hex(t.r));
    }

    // This block of unittests demonstrates that div(Big,uint) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y =                      0x01234567  ;
        auto z = makeBig( 0x00000001, 0x00000079 );
        auto t = div(x,y);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r == 0x00000040, format("remainder = %08X",t.r));
            }{
        auto x = makeBig( 0x00000000, 0xAB54A98C, 0xEB1F0AD2 );
        auto y =                                  0x0000000A  ;
        auto z = makeBig(             0x112210F4, 0x7DE98115 );
        auto t = div(x,y);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r == 0x00000000, format("remainder = %08X",t.r));
    }

    // This block of unittests demonstrates that and(Big,Big) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig( 0X33333333, 0X33333333 );
        auto z = makeBig( 0x01230123, 0x01230123 );
        auto r = and(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig(             0X33333333 );
        auto z = makeBig(             0x01230123 );
        auto r = and(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig(             0XCCCCCCCC );
        auto z = makeBig( 0x01234567, 0x8888CCCC );
        auto r = and(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that and(Big,int) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y =                      0X33333333  ;
        auto z = makeBig(             0x01230123 );
        auto r = and(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y =                      0XCCCCCCCC  ;
        auto z = makeBig( 0x01234567, 0x8888CCCC );
        auto r = and(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that or(Big,Big) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig( 0X33333333, 0X33333333 );
        auto z = makeBig( 0x33337777, 0xBBBBFFFF );
        auto r = or(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig(             0X33333333 );
        auto z = makeBig( 0x01234567, 0xBBBBFFFF );
        auto r = or(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig(             0XCCCCCCCC );
        auto z = makeBig(             0xCDEFCDEF );
        auto r = or(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that or(Big,int) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y =                      0X33333333  ;
        auto z = makeBig( 0x01234567, 0xBBBBFFFF );
        auto r = or(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y =                      0XCCCCCCCC  ;
        auto z = makeBig(             0xCDEFCDEF );
        auto r = or(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that xor(Big,int) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig( 0X33333333, 0X33333333 );
        auto z = makeBig( 0x32107654, 0xBA98FEDC );
        auto r = xor(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig(             0X33333333 );
        auto z = makeBig( 0x01234567, 0xBA98FEDC );
        auto r = xor(x,y);
        assert(r.digits == z.digits, hex(r));
            }{
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y = makeBig(             0XCCCCCCCC );
        auto z = makeBig( 0xFEDCBA98, 0x45670123 );
        auto r = xor(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that xor(Big,int) works
    {
        auto x = makeBig( 0x01234567, 0x89ABCDEF );
        auto y =                      0X33333333  ;
        auto z = makeBig( 0x01234567, 0xBA98FEDC );
        auto r = xor(x,y);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that shl(Big,uint) works
    {
        Big x = makeBig(             0x01234567, 0x89ABCDEF );
        Big z = makeBig( 0x00000123, 0x456789AB, 0xCDEF0000 );
        Big r = shl(x,16);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that shlDigits(Big,uint) works
    {
        Big x = makeBig(                         0x01234567, 0x89ABCDEF );
        Big z = makeBig( 0x01234567, 0x89ABCDEF, 0x00000000, 0x00000000 );
        Big r = shlDigits(x,2);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that shr(Big,uint) works
    {
        Big x = makeBig( 0x00000123, 0x456789AB, 0xCDEF4444 );
        Big z = makeBig(             0x12345678, 0x9ABCDEF4 );
        auto t = shr(x,12);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r == 0x00000444, format("remainder = %08X",t.r));
            }{
        auto x = makeBig( 0x80000000, 0x00000000 );
        auto z = makeBig( 0xFFFF8000, 0x00000000 );
        auto t = shr(x,16);
        assert(t.q.digits == z.digits, hex(t.q));
        assert(t.r == 0x00000000, format("remainder = %08X",t.r));
    }

    // This block of unittests demonstrates that shrDigits(Big,uint) works
    {
        Big x = makeBig( 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 );
        Big z = makeBig(                         0x01234567, 0x89ABCDEF );
        Big r = shrDigits(x,2);
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that cmp(Big,Big) works
    {
        Big x = makeBig( 0x11111111, 0x11111111, 0x11111111 );
        Big y = makeBig(             0x11111111, 0x11111111 );
        assert(cmp(x,y) > 0);
            }{
        Big x = makeBig(             0x11111111, 0x11111111 );
        Big y = makeBig( 0x11111111, 0x11111111, 0x11111111 );
        assert(cmp(x,y) < 0);
            }{
        Big x = makeBig( 0xEEEEEEEE, 0xEEEEEEEE, 0xEEEEEEEE );
        Big y = makeBig(             0xEEEEEEEE, 0xEEEEEEEE );
        assert(cmp(x,y) < 0);
            }{
        Big x = makeBig(             0xEEEEEEEE, 0xEEEEEEEE );
        Big y = makeBig( 0xEEEEEEEE, 0xEEEEEEEE, 0xEEEEEEEE );
        assert(cmp(x,y) > 0);
            }{
        Big x = makeBig( 0x33333333, 0x22222222, 0xEEEEEEEE );
        Big y = makeBig( 0x33333333, 0x11111111, 0xEEEEEEEE );
        assert(cmp(x,y) > 0);
            }{
        Big x = makeBig( 0x33333333, 0x11111111, 0xEEEEEEEE );
        Big y = makeBig( 0x33333333, 0x22222222, 0xEEEEEEEE );
        assert(cmp(x,y) < 0);
            }{
        Big x = makeBig( 0x33333333, 0x11111111, 0xEEEEEEEE );
        Big y = makeBig( 0xEEEEEEEE, 0x22222222, 0xEEEEEEEE );
        assert(cmp(x,y) > 0);
            }{
        Big x = makeBig( 0x01234567, 0x88888888, 0x76543210 );
        Big y = makeBig( 0x01234567, 0x88888888, 0x76543210 );
        assert(cmp(x,y) == 0);
    }

    // This block of unittests demonstrates that cmp(Big,uint) works
    {
        Big x = makeBig( 0x11111111, 0x11111111, 0x11111111 );
        Digit y =                                0x11111111  ;
        assert(cmp(x,y) > 0);
            }{
        Big x = makeBig( 0xEEEEEEEE, 0xEEEEEEEE, 0xEEEEEEEE );
        Digit y =                                0xEEEEEEEE ;
        assert(cmp(x,y) < 0);
            }{
        Big x = makeBig( 0x22222222 );
        Digit y =        0x11111111  ;
        assert(cmp(x,y) > 0);
            }{
        Big x = makeBig( 0x11111111 );
        Digit y =        0x22222222  ;
        assert(cmp(x,y) < 0);
            }{
        Big x = makeBig( 0x76543210 );
        Digit y =        0x76543210  ;
        assert(cmp(x,y) == 0);
    }

    // This block of unittests demonstrates that fromString(string) works
    {
        Big r = fromString("123");
        Big z = makeBig( 0x0000007B );
        assert(r.digits == z.digits, hex(r));
            }{
        Big r = fromString("12_345_678_901_234_567_890");
        Big z = makeBig( 0x00000000, 0xAB54A98C, 0xEB1F0AD2 );
        assert(r.digits == z.digits, hex(r));
            }{
        Big r = fromString("-12_345_678_901_234_567_890");
        Big z = makeBig( 0xFFFFFFFF, 0x54AB5673, 0x14E0F52E );
        assert(r.digits == z.digits, hex(r));
            }{
        Big r = fromString("0x0123_4567_89AB_CDEF");
        Big z = makeBig( 0x01234567, 0x89ABCDEF );
        assert(r.digits == z.digits, hex(r));
            }{
        Big r = fromString("-0x0123_4567_89AB_CDEF");
        Big z = makeBig( 0xFEDCBA98, 0x76543211 );
        assert(r.digits == z.digits, hex(r));
    }

    // This block of unittests demonstrates that decimal(Big) works
    {
        Big x = makeBig( 0x0000007B );
        string r = decimal(x);
        assert(r == "123", r);
            }{
        Big x = makeBig( 0x00000000, 0xAB54A98C, 0xEB1F0AD2 );
        string r = decimal(x);
        assert(r == "12345678901234567890", r);
            }{
        Big x = makeBig( 0xFFFFFFFF, 0x54AB5673, 0x14E0F52E );
        string r = decimal(x);
        assert(r == "-12345678901234567890", r);
            }{
        Big x = makeBig( 0x01234567, 0x89ABCDEF );
        string r = decimal(x);
        assert(r == "81985529216486895", r);
            }{
        Big x = makeBig( 0xFEDCBA98, 0x76543211 );
        string r = decimal(x);
        assert(r == "-81985529216486895", r);
    }

    // This block of unittests demonstrates that opAssign works
    {
        Big z = makeBig( 0x00000064 );
        Big r;
        r.opAssign(z);
        assert(z.digits == r.digits, hex(r));
            //
        r.opAssign( cast(int)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r.opAssign( cast(uint)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r.opAssign( cast(long)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r.opAssign( cast(ulong)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r.opAssign( "100" );
        assert(z.digits == r.digits, hex(r));
            }{
        Big r;
        r.opAssign( cast(long)0xFEDCBA9876543210 );
        Big z = makeBig( 0xFEDCBA98, 0x76543210 );
        assert(z.digits == r.digits, hex(r));
            }{
        Big r;
        r.opAssign( cast(ulong)0xFEDCBA9876543210 );
        Big z = makeBig( 0x00000000, 0xFEDCBA98, 0x76543210 );
        assert(z.digits == r.digits, hex(r));
        
    }

    // This block of unittests demonstrates that static opCall works
    {
        Big z = makeBig( 0x00000064 );
        Big r = BigInt(z);
        assert(z.digits == r.digits, hex(r));
            //
        r = BigInt( cast(int)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r = BigInt( cast(uint)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r = BigInt( cast(long)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r = BigInt( cast(ulong)100 );
        assert(z.digits == r.digits, hex(r));
            //
        r = BigInt( "100" );
        assert(z.digits == r.digits, hex(r));
            }{
        Big r = BigInt( cast(long)0xFEDCBA9876543210 );
        Big z = makeBig( 0xFEDCBA98, 0x76543210 );
        assert(z.digits == r.digits, hex(r));
            }{
        Big r = BigInt( cast(ulong)0xFEDCBA9876543210 );
        Big z = makeBig( 0x00000000, 0xFEDCBA98, 0x76543210 );
        assert(z.digits == r.digits, hex(r));
    }

    // This block of unittests demonstrates that castTo works
    {
        BigInt z = makeBig( 0x00000000, 0x89ABCDEF, 0x89ABCDEF );
        BigInt r;
        z.castTo(r);
        assert(z.digits == r.digits, hex(r));
            //
        int i;
        z.castTo(i);
        assert(i == -1985229329);
            //
        uint j;
        z.castTo(j);
        assert(j == 2309737967);
            //
        long k;
        z.castTo(k);
        assert(k == -8526495040805286417);
            //
        ulong l;
        z.castTo(l);
        assert(l == 9920249032904265199u);
            //
        string s;
        z.castTo(s);
        assert(s == "9920249032904265199");
    }
    
    // This block of unittests demonstrates that opEquals and opCmp work
    {
        BigInt x = makeBig( 0x00000000, 0x89ABCDEF, 0x89ABCDEF );
        assert(x  > BigInt("9920249032904265198"));
        assert(x == BigInt("9920249032904265199"));
        assert(x  < BigInt("9920249032904265200"));
            //
        assert(x.opEquals(BigInt("9920249032904265199")));
        assert(x.opCmp(BigInt("9920249032904265199") == 0));
            //
        BigInt y = 42;
        assert(y  > 41);
        assert(y == 42);
        assert(y  < 43);
    }

    // This block of unittests demonstrates that opNeg works
    {
        BigInt x = "100000000000000";
        BigInt y = "-100000000000000";
        assert(x == -y);
        assert(-x == y);
        assert(x == -(-x));
    }

    // This block of unittests demonstrates that opPos works
    {
        BigInt x = "100000000000000";
        assert(x == +x);
    }

    // This block of unittests demonstrates that opCom works
    {
        BigInt x = "100000000000000";
        BigInt y = "-100000000000001";
        assert(x == ~y);
        assert(~x == y);
        assert(x == ~(~x));
    }

    // This block of unittests demonstrates that opPostInc and opPostDec work
    {
        BigInt x = "100000000000000";
        BigInt y = x++;
        assert(y == BigInt("100000000000000"));
        assert(x == BigInt("100000000000001"));
            }{
        BigInt x = "100000000000000";
        BigInt y = x--;
        assert(y == BigInt("100000000000000"));
        assert(x == BigInt( "99999999999999"));
    }

    // This block of unittests demonstrates that opAdd works
    {
        BigInt x = "100000000000000";
        BigInt y = x + 42;
        assert(y == BigInt("100000000000042"));
        BigInt z = x + x;
        assert(z == BigInt("200000000000000"));
            }{
        BigInt x = "100000000000000";
        BigInt y = x + -42;
        assert(y == BigInt("99999999999958"));
        BigInt z = x + -(x + x);
        assert(z == BigInt("-100000000000000"));
            }{
        BigInt x = "100000000000000";
        x += 42;
        assert(x == BigInt("100000000000042"));
    }

    // This block of unittests demonstrates that opSub works
    {
        BigInt x = "100000000000000";
        BigInt y = x - 42;
        assert(y == BigInt("99999999999958"));
        BigInt z = x - x;
        assert(z == BigInt.init);
            }{
        BigInt x = "100000000000000";
        BigInt y = x - -42;
        assert(y == BigInt("100000000000042"));
        BigInt z = x - -(x + x);
        assert(z == BigInt("300000000000000"));
            }{
        BigInt x = "100000000000000";
        x -= 42;
        assert(x == BigInt("99999999999958"));
    }

    // This block of unittests demonstrates that opMul works
    {
        BigInt a = "9588669891916142";
        BigInt b = "7452469135154800";
        auto c = a * b;
        assert(c == "71459266416693160362545788781600");
            }{
        BigInt a = "-9588669891916142";
        BigInt b = "7452469135154800";
        auto c = a * b;
        assert(c == "-71459266416693160362545788781600");
            }{
        BigInt a = "9588669891916142";
        BigInt b = "-7452469135154800";
        auto c = a * b;
        assert(c == "-71459266416693160362545788781600");
            }{
        BigInt a = "-9588669891916142";
        BigInt b = "-7452469135154800";
        auto c = a * b;
        assert(c == "71459266416693160362545788781600");
            }{
        BigInt a = "10000000000000000000";
        a *= -4;
        assert(a == "-40000000000000000000");
    }

    // This block of unittests demonstrates that opDiv works
    {
        BigInt a = "10000000000000000";
        BigInt b = "7";
        auto c = a / b;
        assert(c == "1428571428571428");
            }{
        BigInt a = "-10000000000000000";
        BigInt b = "7";
        auto c = a / b;
        assert(c == "-1428571428571428");
            }{
        BigInt a = "10000000000000000";
        BigInt b = "-7";
        auto c = a / b;
        assert(c == "-1428571428571428");
            }{
        BigInt a = "-10000000000000000";
        BigInt b = "-7";
        auto c = a / b;
        assert(c == "1428571428571428");
            }{
        BigInt a = "10000000000000000";
        a /= -7;
        assert(a == "-1428571428571428");
    }

    // This block of unittests demonstrates that opMod works
    {
        BigInt a = "10000000000000000";
        BigInt b = "7";
        auto c = a % b;
        assert(c == 4);
            }{
        BigInt a = "-10000000000000000";
        BigInt b = "7";
        auto c = a % b;
        assert(c == -4);
            }{
        BigInt a = "10000000000000000";
        BigInt b = "-7";
        auto c = a % b;
        assert(c == 4);
            }{
        BigInt a = "-10000000000000000";
        BigInt b = "-7";
        auto c = a % b;
        assert(c == -4);
            }{
        BigInt a = "10000000000000000";
        a %= -7;
        assert(a == 4);
            }{
        BigInt a = "10000000000000000";
        a %= BigInt("0x80000000");
            }{
        BigInt a = "10000000000000000";
        int i = 0x80000000;
        a %= i;
    }

    // This block of unittests demonstrates that opAnd works
    {
        BigInt x = "0xCCCCCCCC";
        auto y = x & 0xAAAAAAAA;
        assert(y == 0x88888888);
        static assert(is(typeof(y) == uint));
            }{
        BigInt x = "0xCCCCCCCC";
        x &= 0xAAAAAAAA;
        assert(x == 0x88888888);
    }

    // This block of unittests demonstrates that opOr works
    {
        BigInt x = "0xCCCCCCCC";
        auto y = x | 0xAAAAAAAA;
        assert(y == 0xEEEEEEEE);
            }{
        BigInt x = "0xCCCCCCCC";
        x |= 0xAAAAAAAA;
        assert(x == 0xEEEEEEEE);
    }

    // This block of unittests demonstrates that opXor works
    {
        BigInt x = "0xCCCCCCCC";
        auto y = x ^ 0xAAAAAAAA;
        assert(y == 0x66666666);
            }{
        BigInt x = "0xCCCCCCCC";
        x ^= 0xAAAAAAAA;
        assert(x == 0x66666666);
    }

    // This block of unittests demonstrates that opShl works
    {
        BigInt x = "0x1234567";
        BigInt y = x << 80;
        assert(y == BigInt("0x123456700000000000000000000"));
            }{
        BigInt x = "0x1234567";
        x <<= 80;
        assert(x == BigInt("0x123456700000000000000000000"));
    }

    // This block of unittests demonstrates that opShr works
    {
        BigInt x = "0x1234567FFFFFFFFFFFFFFFFFFFF";
        BigInt y = x >> 80;
        assert(y == BigInt("0x1234567"));
            }{
        BigInt x = "0x1234567FFFFFFFFFFFFFFFFFFFF";
        x >>= 80;
        assert(x == BigInt("0x1234567"));
    }

    // This block of unittests demonstrates that toString works
    {
        string s = "128649024696729866742487649";
        BigInt x = s;
        string t = x.toString;
        assert(t == s);
    }

    // This block of unittests demonstrates that sgn and abs work
    {
        BigInt x = 1000;
        assert(x.sgn == 1);
        assert(x.abs == 1000);
            }{
        BigInt x = -1000;
        assert(x.sgn == -1);
        assert(x.abs == 1000);
            }{
        BigInt x = 0;
        assert(x.sgn == 0);
        assert(x.abs == 0);
    }

    // Silly ad hoc test
    {
        BigInt a = "9588669891916142";
        BigInt b = "7452469135154800";
        auto c = a * b;                                             // c = a.b
        assert(c == "71459266416693160362545788781600");
        auto d = b * a;                                             // d = a.b
        assert(d == "71459266416693160362545788781600");
        assert(d == c);
        d = c * "794628672112";                                     // d = 794628672112.a.b
        assert(d == "56783581982794522489042432639320434378739200");
        auto e = c + d;                                             // e = 794628672113.a.b
        assert(e == "56783581982865981755459125799682980167520800");
        auto f = d + c;                                             // f = 794628672113.a.b
        assert(f == e);
        auto g = f - c;                                             // g = 794628672112.a.b
        assert(g == d);
        g = f - d;                                                  // g = a.b
        assert(g == c);
        e = 12345678;                                               // e = 12345678
        g = c + e;                                                  // g = a.b + e
        auto h = g / b;                                             // h = a
        auto i = g % b;                                             // i = e
        assert(h == a);
        assert(i == e);
    }

}
