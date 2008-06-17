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

Date: 2008.05.18

License: Public Domain


Macros:
    WIKI=Phobos/StdBigint
*/

module bigint;
import std.string       : format;
import std.stdio        : writef, writefln;
import std.algorithm    : min, max, swap;
import std.traits       : isIntegral;

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
        static if(BIG_ENDIAN) { auto a = [ cast(Digit)0, n ]; }
        else                  { auto a = [ cast(Digit)n, 0 ]; }
        Big b = bigInt(a);
        digits = b.digits;
    }

    ///
    void opAssign(long n)
    {
        static if(BIG_ENDIAN) { auto a = [ cast(Digit)(n>>32), cast(Digit)n ]; }
        else                  { auto a = [ cast(Digit)n, cast(Digit)(n>>32) ]; }
        Big b = bigInt(a);
        digits = b.digits;
    }

    ///
    void opAssign(ulong n)
    {
        static if(BIG_ENDIAN) { auto a = [ cast(Digit)0, cast(Digit)(n>>32), cast(Digit)n ]; }
        else                  { auto a = [ cast(Digit)n, cast(Digit)(n>>32), cast(Digit)0 ]; }
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
        mixin(setUp("x","*this"));
        r = peek(xp);
        xp = next(xp);
        if (xp != xe) r += cast(ulong)(peek(xp)) << 32;
    }

    ///
    void castTo(out string r) const
    {
        r = decimal(*this);
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
        return neg(*this);
    }

    ///
    BigInt opCom() const
    {
        return com(*this);
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
    BigInt opAdd(T)(T n) const
    {
        return opAdd(BigInt(n));
    }

    ///
    BigInt opAdd(T:int)(T n) const
    {
        return add(*this,cast(Digit)n);
    }

    ///
    BigInt opAdd(T:const(BigInt))(T n) const
    {
        return add(*this,n);
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
        return sub(*this,cast(Digit)n);
    }

    ///
    BigInt opSub(T:const(BigInt))(T n) const
    {
        return sub(*this,n);
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
        return and(*this,cast(Digit)n);
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
        return and(*this,n);
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
        return or(*this,cast(Digit)n);
    }

    ///
    BigInt opOr(T:const(BigInt))(T n) const
    {
        return or(*this,n);
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
        return xor(*this,cast(Digit)n);
    }

    ///
    BigInt opXor(T:const(BigInt))(T n) const
    {
        return xor(*this,n);
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
        Big r = *this;
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
        Big r = *this;
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
        int t = cmp(*this,n);
        return t == 0 ? 0 : (t > 0 ? 1 : -1);
    }

    ///
    int opCmp(T:const(BigInt))(T n) const
    {
        int t = cmp(*this,n);
        return t == 0 ? 0 : (t > 0 ? 1 : -1);
    }

    ///
    string toString() const
    {
        return decimal(*this);
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
        int t = cmp(*this,0);
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

version(BigEndian) { enum bool BIG_ENDIAN = true;  }
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
            r = (r << 4) + (c - 'A' + 10);
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
    if (b < 0) return "-" ~ decimal(-b);

    if (b < 10)
    {
        int n;
        b.castTo(n);
        char c = cast(char)(n + '0');
        return [ c ];
    }

    auto t = div(b,10);
    auto r = cast(string)(decimal(t.q) ~ [ cast(char)(t.r + '0') ]);
    return r;
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

Digit next(Digit d) { return d; }
FwdPtr next(FwdPtr p) { return p + 1; }
BwdPtr next(BwdPtr p) { return p - 1; }

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

WideDigit updateShr(WideDigit c) { return cast(SignedWideDigit)c >> 32; }

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
        c = updateShr(c);
    }

    mixin(runOnce(   "mulCore","updateShr","xs","y"));
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

            BigInt before = bigInt(_before);
            BigInt test = bigInt(_test);
            BigInt after = bigInt(_after);

            assert(after + test == before);
            assert(carry == 0);
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

unittest
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


/* Optimised asm multibyte arithmetic routines for X86 processors.
 * All operate on arrays of unsigned ints, stored lsb first.
 * Author: Don Clugston
 * Date: May 2008.
 *
 * License: Public Domain
 *
 * In simple terms, there are 3 modern x86 microarchitectures:
 * (a) the P6 family (Pentium Pro, PII, PIII, PM, Core), produced by Intel;
 * (b) the K6, Athlon, and AMD64 families, produced by AMD; and
 * (c) the Pentium 4, produced by Marketing.
 *
 * This code has been optimised for the Intel P6 family, except that it only
 * uses the basic instruction set (doesn't use MMX, SSE, SSE2)
 * Generally the code remains near-optimal for Core2, after translating
 * EAX-> RAX, etc, since all these CPUs use essentially the same pipeline.
 * Uses techniques described in Agner Fog's superb manuals available at
 * www.agner.org.
 * Not optimal for AMD64, which can do two memory loads per cycle (Intel
 * CPUs can only do one).
 */
private:
version(D_InlineAsm_X86) {
/* Duplicate string s, with n times, substituting index for '@'.
 *
 * Each instance of '@' in s is replaced by 0,1,...n-1. This is a helper
 * function for some of the asm routines.
 */
char [] indexedLoopUnroll(int n, invariant char [] s)
{
    char [] u;
    for (int i = 0; i<n; ++i) {
        char [] nstr= ((i>9 ? ""~ cast(char)('0'+i/10) : "") ~ cast(char)('0' + i%10)).dup;
        
        int last = 0;
        for (int j = 0; j<s.length; ++j) {
            if (s[j]=='@') {
                u ~= s[last..j] ~ nstr;
                last = j+1;
            }
        }
        if (last<s.length) u = u ~ s[last..$];
        
    }
    return u;    
}
unittest
{
assert(indexedLoopUnroll(3, "@*23;")=="0*23;1*23;2*23;");
}

// Multi-byte addition or subtraction
//    Dest[0..$] = src1[0..dest.length] + src2[0..dest.length] + carry (0 or 1).
// or Dest[0..$] = src1[0..dest.length] - src2[0..dest.length] - carry (0 or 1).
// Returns carry (0 or 1).
// Set op == '+' for addition, '-' for subtraction.
uint multibyteAddSub(char op)(uint[] dest, const (uint) *src1, const (uint) *src2, int carry)
{
    // Timing:
    // Pentium M: 2.25 (18 cycles/iteration when unrolled by 8).
    // * P6 family have a partial flags stall when reading the carry flag in
    // an ADC, SBB operation after an operation such as INC or DEC which
    // modifies some, but not all, flags. We avoid this by storing carry into
    // a resister (AL), and restoring it after the branch.
    // * Count UP to zero (from -len) to minimize loop overhead.

    enum { UNROLLFACTOR = 8 };
    enum { LASTPARAM = 4*4 } // 3* pushes + return address.
    asm {
        naked;
        push EDI;
        push EBX;
        push ESI;
        align 16; // This aligns L1 on a 16-byte boundary.
        mov ECX, [ESP + LASTPARAM + 2*4]; // dest.length;
        mov EDX, [ESP + LASTPARAM + 1*4]; // src1
        mov EDI, [ESP + LASTPARAM + 3*4]; // dest.ptr
             // Carry is automatically in EAX
        mov ESI, [ESP + LASTPARAM]; // src2;
        lea EDX, [EDX + 4*ECX]; // EDX = end of src1.
        lea EDI, [EDI + 4*ECX]; // EDI = end of dest.
        lea ESI, [ESI + 4*ECX]; // EBP = end of src2.        
        neg ECX;
        and ECX, 0xFFFF_FFF8;
        jz L2; // length <8
    L1:
        shr AL, 1; // get carry from the lsb of AL
    }
    mixin(" asm {"
    ~ indexedLoopUnroll( UNROLLFACTOR, "
        mov EAX, [@*4+EDX+ECX*4];
        "~ (op=='+'?"adc" : "sbb") ~ " EAX, [@*4+ESI+ECX*4];
        mov [@*4+EDI+ECX*4], EAX;
        ") ~ "}");
    asm {
        setc AL; // Save carry into the lsb of AL
        add ECX, UNROLLFACTOR;        
        jnz L1;
L2:
        mov ECX, [ESP + LASTPARAM + 2*4]; // dest.length;
        and ECX, 7;
        jz done; // divisible by 8 -- no residue
        neg ECX;
L3: // Do the residual 1..7 ints.
        shr AL, 1; // get carry from EAX
        mov EAX, [EDX+ECX*4];
    }
    static if (op=='+')
    {
        asm { adc EAX, [ESI+ECX*4]; }
    }
    else 
    {
        asm { sbb EAX, [ESI+ECX*4]; }
    }
    asm {
        mov [EDI+ECX*4], EAX;       
        setc AL; // save carry
        add ECX, 1;
        jnz L3;                
done:
        and EAX, 1; // make it O or 1.
        pop ESI;
        pop EBX;
        pop EDI;
        ret 4*4;
    } 
}

unittest
{
    uint [] a = new uint[20];
    uint [] b = new uint[20];
    uint [] c = new uint[20];
    for (int i=0; i<a.length; ++i)
    {
        if (i&1) a[i]=0x8000_0000 + i;
        else a[i]=i;
        b[i]= 0x8000_0003;
    }
    c[19]=0x3333_3333;
    uint carry = multibyteAddSub!('+')(c[0..18], a.ptr, b.ptr, 0);
    assert(carry==1);
    assert(c[0]==0x8000_0003);
    assert(c[1]==4);
    assert(c[19]==0x3333_3333); // check for overrun
}

// Dest[0..len] = src1[0..len] op src2[0..len]
// where op == '&' or '|' or '^'
uint multibyteLogical(char op)(uint [] dest, const (uint) *src1, const (uint) *src2)
{
    // PM: 2 cycles/operation. Limited by execution unit p2.
    // (AMD64 could reach 1.5 cycles/operation since it has TWO read ports.
    // On Core2, we could use SSE2 with 128-bit reads).
    enum { LASTPARAM = 3*4 } // 2* pushes + return address.
    asm {
        naked;
        push EDI;
        push ESI;
        mov EDI, [ESP + LASTPARAM + 4*2]; // dest
        mov ECX, [ESP + LASTPARAM + 4*1]; // dest.length;
        mov EDX, [ESP + LASTPARAM + 4*0]; // src1;
        mov ESI, EAX;                     // src2;
        lea EDI, [EDI + 4*ECX]; // EDI = end of dest.
        lea EDX, [EDX + 4*ECX]; // EDX = end of src1.
        lea ESI, [ESI + 4*ECX]; // ESI = end of src2.
        neg ECX;
L1:
        mov EAX, [EDX+ECX*4];
    }
    static if (op=='&') asm {        and EAX, [ESI+ECX*4]; }
    else   if (op=='|') asm {        or  EAX, [ESI+ECX*4]; }
    else   if (op=='^') asm {        xor EAX, [ESI+ECX*4]; }
    asm {
        mov [EDI + ECX *4], EAX;
        add ECX, 1;
        jl L1;
        pop ESI;
        pop EDI;
        ret 4*3;
    } 
}

unittest
{
    uint [] bb = [0x0F0F_0F0F, 0xF0F0_F0F0, 0x0F0F_0F0F, 0xF0F0_F0F0];
    for (int qqq=0; qqq<3; ++qqq) {
        uint [] aa = [0xF0FF_FFFF, 0x1222_2223, 0x4555_5556, 0x8999_999A, 0xBCCC_CCCD, 0xEEEE_EEEE];    
        switch(qqq) {
        case 0:
            multibyteLogical!('&')(aa[1..3], aa.ptr+1, bb.ptr);
            assert(aa[1]==0x0202_0203 && aa[2]==0x4050_5050 && aa[3]== 0x8999_999A);
            break;
        case 1:
            multibyteLogical!('|')(aa[1..2], aa.ptr+1, bb.ptr);
            assert(aa[1]==0x1F2F_2F2F && aa[2]==0x4555_5556 && aa[3]== 0x8999_999A);
            break;
        case 2:
            multibyteLogical!('^')(aa[1..2], aa.ptr+1, bb.ptr);
            assert(aa[1]==0x1D2D_2D2C && aa[2]==0x4555_5556 && aa[3]== 0x8999_999A);
            break;
        }
        assert(aa[0]==0xF0FF_FFFF);
    }
}
    
    // dest[0..$] = src[0..dest.length] << numbits
void multibyteShl(uint [] dest, const (uint) *src, uint numbits)
{
    // Timing: Optimal for P6 family.
    // 2.0 cycles/int on PPro..PM (limited by execution port p0)
    // Terrible performance on AMD64, which has 7 cycles for SHLD!!
    enum { LASTPARAM = 4*4 } // 3* pushes + return address.
    asm {
        naked;
        push ESI;
        push EDI;
        push EBX;
        mov EDI, [ESP + LASTPARAM + 4*2]; //dest.ptr;
        mov EBX, [ESP + LASTPARAM + 4*1]; //dest.length;
        mov ESI, [ESP + LASTPARAM + 4*0]; //src;
        mov ECX, EAX; // numbits;

        mov EAX, [-4+ESI + 4*EBX];
        cmp EBX, 1;
        jz L_last;
        mov EDX, [-4+ESI + 4*EBX];
        test EBX, 1;
        jz L_odd;
        sub EBX, 1;        
L_even:
        mov EDX, [-4+ ESI + 4*EBX];
        shld EAX, EDX, CL;
        mov [EDI+4*EBX], EAX;
L_odd:
        mov EAX, [-8+ESI + 4*EBX];
        shld EDX, EAX, CL;
        mov [-4+EDI + 4*EBX], EDX;        
        sub EBX, 2;
        jg L_even;
L_last:
        shl EAX, CL;
        mov [EDI], EAX;

        pop EBX;
        pop EDI;
        pop ESI;
        ret 3*4;
     }
}

// dest[0..len] = src[0..len] >> numbits
void multibyteShr(uint [] dest, const (uint) *src, uint numbits)
{
    // Timing: Optimal for P6 family.
    // 2.0 cycles/int on PPro..PM (limited by execution port p0)
    // Terrible performance on AMD64, which has 7 cycles for SHRD!!
    enum { LASTPARAM = 4*4 } // 3* pushes + return address.
    asm {
        naked;
        push ESI;
        push EDI;
        push EBX;
        mov EDI, [ESP + LASTPARAM + 4*2]; //dest.ptr;
        mov EBX, [ESP + LASTPARAM + 4*1]; //dest.length;
        mov ESI, [ESP + LASTPARAM + 4*0]; //src;
        mov ECX, EAX; // numbits;

        lea EDI, [EDI + 4*EBX]; // EDI = end of dest
        lea ESI, [ESI + 4*EBX]; // ESI = end of src
        neg EBX;                // count UP to zero.
        mov EAX, [ESI + 4*EBX];
        cmp EBX, -1;
        jz L_last;
        mov EDX, [ESI + 4*EBX];
        test EBX, 1;
        jz L_odd;
        add EBX, 1;        
L_even:
        mov EDX, [ ESI + 4*EBX];
        shrd EAX, EDX, CL;
        mov [-4 + EDI+4*EBX], EAX;
L_odd:
        mov EAX, [4 + ESI + 4*EBX];
        shrd EDX, EAX, CL;
        mov [EDI + 4*EBX], EDX;        
        add EBX, 2;
        jl L_even;
L_last:
        shr EAX, CL;
        mov [-4 + EDI], EAX;
        
        pop EBX;
        pop EDI;
        pop ESI;
        ret 3*4;
     }
}

unittest
{
    uint [] aa = [0x1222_2223, 0x4555_5556, 0x8999_999A, 0xBCCC_CCCD, 0xEEEE_EEEE];
    multibyteShr(aa[0..$-2], aa.ptr, 4);
	assert(aa[0]==0x6122_2222 && aa[1]==0xA455_5555 && aa[2]==0x0899_9999);
	assert(aa[3]==0xBCCC_CCCD);

    aa = [0x1222_2223, 0x4555_5556, 0x8999_999A, 0xBCCC_CCCD, 0xEEEE_EEEE];
    multibyteShr(aa[0..$-1], aa.ptr, 4);
	assert(aa[0] == 0x6122_2222 && aa[1]==0xA455_5555 
	    && aa[2]==0xD899_9999 && aa[3]==0x0BCC_CCCC);

    aa = [0xF0FF_FFFF, 0x1222_2223, 0x4555_5556, 0x8999_999A, 0xBCCC_CCCD, 0xEEEE_EEEE];
    multibyteShl(aa[1..4], aa.ptr+1, 4);
	assert(aa[0] == 0xF0FF_FFFF && aa[1] == 0x2222_2230 
	    && aa[2]==0x5555_5561 && aa[3]==0x9999_99A4 && aa[4]==0x0BCCC_CCCD);
}

// dest[0..$] = src[0..len] * multiplier + carry.
// Returns carry.
uint multibyteMul(uint[] dest, const (uint)* src, uint multiplier, uint carry)
{
    // Timing: definitely not optimal.
    // Pentium M: 5.0 cycles/operation, has 3 resource stalls/iteration
    // Fastest implementation found was 4.6 cycles/op, but not worth the complexity.

    enum { LASTPARAM = 4*4 } // 4* pushes + return address.
    // We'll use p2 (load unit) instead of the overworked p0 or p1 (ALU units)
    // when initializing variables to zero.
    version(D_PIC)
    {
        enum zero = 0; 
    }
    else
    {
        static invariant int zero = 0;
    }
    asm {
        naked;      
        push ESI;
        push EDI;
        push EBX;
        
        mov EDI, [ESP + LASTPARAM + 4*3]; // dest
        mov EBX, [ESP + LASTPARAM + 4*2]; // len
        mov ESI, [ESP + LASTPARAM + 4*1];  // src
        align 16;
        lea EDI, [EDI + 4*EBX]; // EDI = end of dest
        lea ESI, [ESI + 4*EBX]; // ESI = end of src
        mov ECX, EAX; // [carry]; -- last param is in EAX.
        neg EBX;                // count UP to zero.
        test EBX, 1;
        jnz L_odd;
        add EBX, 1;
 L1:
        mov EAX, [-4 + ESI + 4*EBX];
        mul int ptr [ESP+LASTPARAM]; //[multiplier];
        add EAX, ECX;
        mov ECX, zero;
        mov [-4+EDI + 4*EBX], EAX;
        adc ECX, EDX;
L_odd:        
        mov EAX, [ESI + 4*EBX];  // p2
        mul int ptr [ESP+LASTPARAM]; //[multiplier]; // p0*3, 
        add EAX, ECX;
        mov ECX, zero;
        adc ECX, EDX;
        mov [EDI + 4*EBX], EAX;
        add EBX, 2;
        jl L1;
        
        mov EAX, ECX; // get final carry

        pop EBX;
        pop EDI;
        pop ESI;
        ret 4*4;
     }
}

unittest
{
    uint [] aa = [0xF0FF_FFFF, 0x1222_2223, 0x4555_5556, 0x8999_999A, 0xBCCC_CCCD, 0xEEEE_EEEE];
    multibyteMul(aa.ptr[1..4], aa.ptr+1, 16, 0);
	assert(aa[0] == 0xF0FF_FFFF && aa[1] == 0x2222_2230 && aa[2]==0x5555_5561 && aa[3]==0x9999_99A4 && aa[4]==0x0BCCC_CCCD);
}

// dest[0..$] += src[0..dest.length] * multiplier + carry(0..FFFF_FFFF).
// Returns carry out of MSB (0..FFFF_FFFF).
uint multibyteMulAdd(uint [] dest, const uint* src, uint multiplier, uint carry)
{
    // Timing: This is the most time-critical bignum function.
    // Pentium M: 5.4 cycles/operation, still has 2 resource stalls + 1 load block/iteration
    
    // The bottlenecks in this code are extremely complicated. The MUL, ADD, and ADC
    // need 4 cycles on each of the ALUs units p0 and p1. So we use memory load 
    // (unit p2) for initializing registers to zero.
    // There are also dependencies between the instructions, and we run up against the
    // ROB-read limit (can only read 2 registers per cycle).
    // We also need the number of uops in the loop to be a multiple of 3.
    // The only available execution unit for this is p3 (memory write)
    
    // The main loop is pipelined and unrolled by 2, so entry to the loop is also complicated.
    
    version(D_PIC) {
        enum zero = 0; 
    } else {
        // use p2 (load unit) instead of the overworked p0 or p1 (ALU units)
        // when initializing registers to zero.
        static invariant int zero = 0;
        // use p3/p4 units 
        static int storagenop; // write-only
    }
    
    enum { LASTPARAM = 5*4 } // 4* pushes + return address.
    asm {
        naked;
        
        push ESI;
        push EDI;
        push EBX;
        push EBP;
        mov EDI, [ESP + LASTPARAM + 4*3]; // dest
        mov EBX, [ESP + LASTPARAM + 4*2]; // len
        align 16;
        nop;
        mov ESI, [ESP + LASTPARAM + 4*1];  // src
        lea EDI, [EDI + 4*EBX]; // EDI = end of dest
        lea ESI, [ESI + 4*EBX]; // ESI = end of src
        mov EBP, 0;
        mov ECX, EAX; // ECX = input carry.
        neg EBX;                // count UP to zero.
        mov EAX, [ESI+4*EBX];
        test EBX, 1;
        jnz L_enter_odd;
        // Entry point for even length
        add EBX, 1;
        mov EBP, ECX; // carry
        
        mul int ptr [ESP+LASTPARAM];
        mov ECX, 0;
 
        add EBP, EAX;
        mov EAX, [ESI+4*EBX];
        adc ECX, EDX;

        mul int ptr [ESP+LASTPARAM];

        add [-4+EDI+4*EBX], EBP;
        mov EBP, zero;
    
        adc ECX, EAX;
        mov EAX, [4+ESI+4*EBX];
    
        adc EBP, EDX;    
        add EBX, 2;
        jnl L_done;
        // Main loop
L1:
        mul int ptr [ESP+LASTPARAM];
        add [-8+EDI+4*EBX], ECX;
        mov ECX, zero;
 
        adc EBP, EAX;
        mov EAX, [ESI+4*EBX];
        
        adc ECX, EDX;
    }
    version(D_PIC) {} else {
    asm {
        mov storagenop, EDX; // make #uops in loop a multiple of 3
    }
    }
    asm {        
        mul int ptr [ESP+LASTPARAM];
        add [-4+EDI+4*EBX], EBP;
        mov EBP, zero;
    
        adc ECX, EAX;
        mov EAX, [4+ESI+4*EBX];
    
        adc EBP, EDX;    
        add EBX, 2;
        jl L1;
L_done:
        add [-8+EDI+4*EBX], ECX;
        mov EAX, EBP; // get final carry
        adc EAX, 0;
        pop EBP;
        pop EBX;
        pop EDI;
        pop ESI;
        ret 0x10;
        
L_enter_odd:
        mul int ptr [ESP+LASTPARAM];
        mov EBP, zero;   
        add ECX, EAX;
        mov EAX, [4+ESI+4*EBX];
    
        adc EBP, EDX;    
        add EBX, 2;
        jl L1;
        jmp L_done;

     }
}

unittest {
    
    uint [] aa = [0xF0FF_FFFF, 0x1222_2223, 0x4555_5556, 0x8999_999A, 0xBCCC_CCCD, 0xEEEE_EEEE];
    uint [] bb = [0x1234_1234, 0xF0F0_F0F0, 0x00C0_C0C0, 0xF0F0_F0F0, 0xC0C0_C0C0];
    multibyteMulAdd(bb[1..$-1], &aa[1], 16, 5);
	assert(bb[0] == 0x1234_1234 && bb[4] == 0xC0C0_C0C0);
    assert(bb[1] == 0x2222_2230 + 0xF0F0_F0F0+5 && bb[2] == 0x5555_5561+0x00C0_C0C0+1
	    && bb[3] == 0x9999_99A4+0xF0F0_F0F0 );
}

/*  dest[] /= divisor.
 * overflow is the initial remainder, and must be in the range 0..divisor-1.
 * divisor must not be a power of 2 (use right shift for that case;
 * A division by zero will occur if divisor is a power of 2).
 *
 * Based on public domain code by Eric Bainville. 
 * (http://www.bealto.com/) Used with permission.
 */
uint multibyteDiv(uint [] dest, uint divisor, uint overflow)
{
    // Timing: limited by a horrible dependency chain.
    // Pentium M: 18 cycles/op, 8 resource stalls/op.
    // EAX, EDX = scratch, used by MUL
    // EDI = dest
    // CL = shift
    // ESI = quotient
    // EBX = remainderhi
    // EBP = remainderlo
    // [ESP-4] = mask
    // [ESP] = kinv (2^64 /divisor)
    enum { LASTPARAM = 5*4 } // 4* pushes + return address.
    enum { LOCALS = 2*4} // MASK, KINV
    asm {
        naked;
        
        push ESI;
        push EDI;
        push EBX;
        push EBP;
        
        mov EDI, [ESP + LASTPARAM + 4*2]; // dest.ptr
        mov EBX, [ESP + LASTPARAM + 4*1]; // dest.length

        // Loop from msb to lsb
        lea     EDI, [EDI + 4*EBX];        
        mov EBP, EAX; // rem is the input remainder, in 0..divisor-1
        // Build the pseudo-inverse of divisor k: 2^64/k
        // First determine the shift in ecx to get the max number of bits in kinv
        xor     ECX, ECX;
        mov     EAX, [ESP + LASTPARAM]; //divisor;
        mov     EDX, 1;
kinv1:
        inc     ECX;
        ror     EDX, 1;
        shl     EAX, 1;
        jnc     kinv1;
        dec     ECX;
        // Here, ecx is a left shift moving the msb of k to bit 32
        
        mov     EAX, 1;
        shl     EAX, CL;
        dec     EAX;
        ror     EAX, CL ; //ecx bits at msb
        push    EAX;
        
        
        // Then divide 2^(32+cx) by divisor (edx already ok)
        xor     EAX, EAX;
        div     int ptr [ESP + LASTPARAM +  LOCALS-4*1]; //divisor;
        push    EAX; // kinv        
        // Here kinv has 64 bits

        align   16;
L2:
        // Get 32 bits of quotient approx, multiplying
        // most significant word of (rem*2^32+input)
        mov     EAX, [ESP+4]; //MASK;
        and     EAX, [EDI - 4];
        or      EAX, EBP;
        rol     EAX, CL;
        mov     EBX, EBP;
        mov     EBP, [EDI - 4];
        mul     int ptr [ESP]; //KINV;
                
        shl     EAX, 1;
        rcl     EDX, 1;
        
        // Multiply by k and subtract to get remainder
        // Subtraction must be done on two words
        mov     EAX, EDX;
        mov     ESI, EDX; // quot = high word
        mul     int ptr [ESP + LASTPARAM+LOCALS]; //divisor;
        sub     EBP, EAX;
        sbb     EBX, EDX;   
        jz      Lb;  // high word is 0, goto adjust on single word

        // Adjust quotient and remainder on two words
Ld:     inc     ESI;
        sub     EBP, [ESP + LASTPARAM+LOCALS]; //divisor;
        sbb     EBX, 0;
        jnz     Ld;
        
        // Adjust quotient and remainder on single word
Lb:     cmp     EBP, [ESP + LASTPARAM+LOCALS]; //divisor;
        jc      Lc; // rem in 0..divisor-1, OK        
        sub     EBP, [ESP + LASTPARAM+LOCALS]; //divisor;
        inc     ESI;
        jmp     Lb;
        
        // Store result
Lc:
        mov     [EDI - 4], ESI;
        lea     EDI, [EDI - 4];
        dec     int ptr [ESP + LASTPARAM + 4*1+LOCALS]; // len
        jnz	L2;
        
        pop EAX; // discard kinv
        pop EAX; // discard mask
        
        mov     EAX, EBP; // return final remainder
        pop     EBP;
        pop     EBX;
        pop     EDI;
        pop     ESI;        
        ret     3*4;
    }
}

unittest {
    uint [] aa = new uint[101];
    for (int i=0; i<aa.length; ++i) aa[i] = 0x8765_4321 * (i+3);
    uint overflow = multibyteMul(aa, aa.ptr, 0x8EFD_FCFB, 0x33FF_7461);
    uint r = multibyteDiv(aa, 0x8EFD_FCFB, overflow);
    for (int i=0; i<aa.length-1; ++i) assert(aa[i] == 0x8765_4321 * (i+3));
    assert(r==0x33FF_7461);

}


} // version(D_InlineAsm_X86)
