/*
 * License: $(LINK2 http://boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Ilya Yaroshenko
 * Source: $(PHOBOSSRC std/internal/math/_summation.d)
 */
module std.internal.math.summation;

import std.traits : 
    Unqual,
    isIterable,
    isMutable,
    isImplicitlyConvertible,
    ForeachType,
    isFloatingPoint;

private template isComplex(C)
{
    import std.complex : Complex;
    enum isComplex = is(C : Complex!F, F);
}

private F fabs(F)(F f) //+-0, +-NaN, +-inf  no matter
{
    if(__ctfe)
    {
        return f < 0 ? -f : f;
    }
    else
    {
        version(LDC) 
        {
            import ldc.intrinsics : llvm_fabs;
            return llvm_fabs(f);
        }
        else
        {
            import core.stdc.tgmath : fabs;
            return fabs(f);
        }
    }
}

/**
Naive summation algorithm. 
*/
F sumNaive(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0)
if(
    isMutable!F &&
    isIterable!Range && 
    isImplicitlyConvertible!(Unqual!(ForeachType!Range), F) 
)
{
    foreach(F x; r)
    {
        s += x;
    }
    return s;
}

/**
$(LUCKY Pairwise summation) algorithm. Range must be a finite sliceable range.
*/
F sumPairwise(Range, F = Unqual!(ForeachType!Range))(Range r)
if(
    isMutable!F &&
    isIterable!Range && 
    isImplicitlyConvertible!(Unqual!(ForeachType!Range), F)
)
{
    import std.range : hasLength, hasSlicing;
    static assert(hasLength!Range && hasSlicing!Range);
    switch (r.length)
    {
        case 0: return F(0);
        case 1: return cast(F)r[0];
        case 2: return cast(F)(r[0] + cast(F)r[1]);
        default: auto n = r.length/2; return cast(F)(sumPairwise!(Range, F)(r[0..n]) + sumPairwise!(Range, F)(r[n..$]));
    }
}

/**
$(LUCKY Kahan summation) algorithm.
*/
/**
---------------------
s := x[1]
c := 0
FOR k := 2 TO n DO
    y := x[k] - c
    t := s + y
    c := (t - s) - y
    s := t
END DO
---------------------
*/
F sumKahan(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0.0)
if(
    isMutable!F &&
    isIterable!Range && 
    isImplicitlyConvertible!(Unqual!(ForeachType!Range), F) 
)
{
    F c = 0.0;
    F y; // do not declare in the loop (algo can be used for matrixes and etc)
    F t; // ditto
    foreach(F x; r)
    {
        y = x - c;
        t = s + y;
        c = t - s;
        c -= y;
        s = t;
    }
    return s;    
}

/**
$(LUCKY Kahan-Babuška-Neumaier summation algorithm). $(D КBN) gives more accurate results then $(D Kahan).
*/
/**
---------------------
s := x[1]
c := 0
FOR i := 2 TO n DO
    t := s + x[i]
    IF ABS(s) >= ABS(x[i]) THEN
        c := c + ((s-t)+x[i])
    ELSE
        c := c + ((x[i]-t)+s)
    END IF
    s := t
END DO
s := s + c
---------------------
*/
F sumKBN(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0.0) 
if(
    isMutable!F &&
    isIterable!Range && 
    isImplicitlyConvertible!(Unqual!(ForeachType!Range), F) && 
    (isFloatingPoint!F || isComplex!F)
)
{
    F c = 0.0;
    static if(isFloatingPoint!F)
    {
        foreach(F x; r)
        {
            F t = s + x;
            if(s.fabs >= x.fabs)
                c += (s-t)+x;
            else
                c += (x-t)+s;
            s = t;
        }
    }
    else
    {
        foreach(F x; r)
        {
            F t = s + x;
            if(s.re.fabs < x.re.fabs)
            {
                auto t_re = s.re;
                s.re = x.re;
                x.re = t_re;
            }
            if(s.im.fabs < x.im.fabs)
            {
                auto t_im = s.im;
                s.im = x.im;
                x.im = t_im;
            }
            c += (s-t)+x;
            s = t;
        }
    }
    return s + c;
}

/**
$(LUCKY Generalized Kahan-Babuška summation algorithm), order 2. $(D КB2) gives more accurate results then $(D Kahan) and $(D КBN).
*/
/**
---------------------
s := 0 ; cs := 0 ; ccs := 0
FOR j := 1 TO n DO
    t := s + x[i]
    IF ABS(s) >= ABS(x[i]) THEN
        c := (s-t) + x[i]
    ELSE
        c := (x[i]-t) + s
    END IF
    s := t
    t := cs + c
    IF ABS(cs) >= ABS(c) THEN
        cc := (cs-t) + c
    ELSE
        cc := (c-t) + cs
    END IF
    cs := t
    ccs := ccs + cc
END FOR
RETURN s+cs+ccs
---------------------
*/
F sumKB2(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0.0) 
if(
    isMutable!F &&
    isIterable!Range && 
    isImplicitlyConvertible!(Unqual!(ForeachType!Range), F) && 
    (isFloatingPoint!F || isComplex!F)
)
{
    F cs = 0.0;
    F ccs = 0.0;
    static if(isFloatingPoint!F)
    {
        foreach(F x; r)
        {
            F t = s + x;
            F c = void;
            if(s.fabs >= x.fabs)
                c = (s-t)+x;
            else
                c = (x-t)+s;
            s = t;
            t = cs + c;
            if(cs.fabs >= c.fabs)
                ccs += (cs-t)+c;
            else
                ccs += (c-t)+cs;
            cs = t;
        }
    }
    else
    {
        foreach(F x; r)
        {
            F t = s + x;
            if(s.re.fabs < x.re.fabs)
            {
                auto t_re = s.re;
                s.re = x.re;
                x.re = t_re;
            }
            if(s.im.fabs < x.im.fabs)
            {
                auto t_im = s.im;
                s.im = x.im;
                x.im = t_im;
            }
            F c = (s-t)+x;
            s = t;
            if(cs.re.fabs < c.re.fabs)
            {
                auto t_re = cs.re;
                cs.re = c.re;
                c.re = t_re;
            }
            if(cs.im.fabs < c.im.fabs)
            {
                auto t_im = cs.im;
                cs.im = c.im;
                c.im = t_im;
            }
            ccs += (cs-t)+c;
            cs = t;
        }
    }
    return s+cs+ccs; // no rounding in between
}

unittest 
{
    import std.typetuple;
    foreach(I; TypeTuple!(byte, uint, long))
    {
        I[] ar = [1, 2, 3, 4];
        I r = 10;
        assert(r == ar.sumNaive);
        assert(r == ar.sumPairwise);
    }
}

unittest 
{
    import std.typetuple;
    foreach(F; TypeTuple!(float, double, real))
    {
        F[] ar = [1, 2, 3, 4];
        F r = 10;
        assert(r == ar.sumNaive);
        assert(r == ar.sumPairwise);
        assert(r == ar.sumKahan);
        assert(r == ar.sumKBN);
        assert(r == ar.sumKB2);
    }
}

unittest 
{
    import std.complex;
    Complex!double[] ar = [complex(1.0, 2), complex(2, 3), complex(3, 4), complex(4, 5)];
    Complex!double r = complex(10, 14);
    assert(r == ar.sumNaive);
    assert(r == ar.sumPairwise);
    assert(r == ar.sumKahan);
    assert(r == ar.sumKBN);
    assert(r == ar.sumKB2);
}

//BUG: DMD 2.066 Segmentation fault (core dumped)
//unittest 
//{
//    import core.simd;
//    static if(__traits(compiles, double2.init + double2.init))
//    {
//        double2[] ar = [double2([1.0, 2]), double2([2, 3]), double2([3, 4]), double2([4, 6])];
//        assert(ar.sumNaive.array == double2([10, 14]).array);
//        assert(ar.sumPairwise.array == double2([10, 14]).array);
//        assert(ar.sumKahan.array == double2([10, 14]).array);
//    }
//}

unittest 
{
    import std.algorithm : map;
    auto ar = [1, 1e100, 1, -1e100].map!(a => a*10000);
    double r = 20000;
    assert(r != ar.sumNaive);
    assert(r != ar.sumPairwise);
    assert(r != ar.sumKahan);
    assert(r == ar.sumKBN);
    assert(r == ar.sumKB2);
}

/**
Handler for full precise summation with $(D put) primitive.
The current implementation re-establish special
value semantics across iterations (i.e. handling -inf + inf).
*/
/*
Precise summation function as msum() by Raymond Hettinger in
<http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/393090>,
enhanced with the exact partials sum and roundoff from Mark
Dickinson's post at <http://bugs.python.org/file10357/msum4.py>.
See those links for more details, proofs and other references.

Note: IEEE 754R floating point semantics are assumed.
*/
struct Summator(F, bool CTFEable = false) 
if(isFloatingPoint!F && is(Unqual!F == F))
{
    import std.internal.scopebuffer;
    static if(CTFEable) import std.conv;
private:
    enum F M = (cast(F)(2)) ^^ (F.max_exp - 1);

    static if(CTFEable)
    {
        static assert(0, "CTFEable Summator not implemented.");
    }
    else
    {
        F[32] scopeBufferArray = void;
        ScopeBuffer!F partials;        
    }

    //sum for NaN and infinity.
    F s;
    //Overflow Degree. Count of 2^^F.max_exp minus count of -(2^^F.max_exp)
    sizediff_t o; 

    debug(numeric) 
    void partialsDebug() const
    {
        foreach(y; partials[])
        {
            assert(y);
            assert(y.isFinite);
        }
        //TODO: Add NonOverlaping check to std.math
        import std.algorithm : isSorted, map;
        assert(partials[].map!fabs.isSorted);
    }

    /**
    Compute the sum of a list of nonoverlapping floats.
    On input, partials is a list of nonzero, nonspecial,
    nonoverlapping floats, strictly increasing in magnitude, but
    possibly not all having the same sign.
    On output, the sum of partials gives the error in the returned
    result, which is correctly rounded (using the round-half-to-even
    rule).
    Two floating point values x and y are non-overlapping if the least significant nonzero
    bit of x is more significant than the most significant nonzero bit of y, or vice-versa.
    */
    static F partialsReduce(F s, in F[] partials)
    in
    {
        debug(numeric) assert(!partials.length || s.isFinite);
    }
    body
    {
        bool _break = void;
        foreach_reverse(i, y; partials) 
        {
            s = partialsReducePred(s, y, i ? partials[i-1] : 0, _break);
            if(_break)
                break;
            debug(numeric) assert(s.isFinite);
        }
        return s;
    }

    static F partialsReducePred(F s, F y, F z, out bool _break)
    out(result)
    {
        debug(numeric) assert(result.isFinite);
    }
    body
    {
        F x = s;
        s = x + y;
        F l = y - (s - x);
        debug(numeric)
        {
            assert(x.isFinite);
            assert(y.isFinite);
            assert(s.isFinite);
            assert(fabs(y) < fabs(x));
        }
        if(l)
        {
        //Make half-even rounding work across multiple partials.
        //Needed so that sum([1e-16, 1, 1e16]) will round-up the last
        //digit to two instead of down to zero (the 1e-16 makes the 1
        //slightly closer to two). Can guarantee commutativity.
            if(z && !signbit(l * z))
            {
                l *= 2;
                x = s + l;
                if (l == x - s)
                    s = x;
            }
            _break = true;
        }
        return s;
    }

    //Returns corresponding infinity if is overflow and 0 otherwise.
    F overflow() const
    {
        if(o == 0)
            return 0;
        if(partials.length && (o == -1 || o == 1)  && signbit(o * partials[$-1]))
        {
            // problem case: decide whether result is representable
            F x = o * M;
            F y = partials[$-1] / 2;
            F h = x + y;
            F l = (y - (h - x)) * 2;
            y = h * 2;
            if(!y.isInfinity || partials.length > 1 && !signbit(l * partials[$-2]) && (h + l) - h == l)
                return 0;
        }
        return F.infinity * o;
    }

public:

    ///
    this(F f)
    {
        partials = scopeBuffer(scopeBufferArray);
        s = 0;
        o = 0;
        if(f) put(f);
    }

    ///
    @disable this();

    // free ScopeBuffer
    ~this()
    {
        partials.free;
    }

    // copy ScopeBuffer if necessary
    this(this)
    {
        auto a = partials[];
        if(scopeBufferArray.ptr !is a.ptr)
        {
            partials = scopeBuffer(scopeBufferArray);
            partials.put(a);
        }
    }

    ///Adds $(D x) to internal partial sums.
    void put(F x)
    {
        if(x.isFinite)
        {
            size_t i;
            foreach(y; partials[])
            {
                F h = x + y;
                if(h.isInfinity)
                {
                    if(fabs(x) < fabs(y))
                    {
                        F t = x; x = y; y = t;
                    }
                    //h == -F.infinity
                    if(h.signbit) 
                    {
                        x += M;
                        x += M;
                        o--;
                    }
                    //h == +F.infinity
                    else 
                    {
                        x -= M;
                        x -= M;
                        o++;
                    }
                    debug(numeric) assert(x.isFinite);
                    h = x + y;
                }
                debug(numeric) assert(h.isFinite);
                F l = fabs(x) < fabs(y) ? x - (h - y) : y - (h - x);
                debug(numeric) assert(l.isFinite);
                if(l)
                {
                    partials[i++] = l;
                }
                x = h;
            }
            partials.length = i;
            if(x)
            {
                partials.put(x);
            }
        }
        else
        {
            s += x;
        }
    }

    /**
    Adds $(D x) to internal partial sums.

    */
    void unsafePut(F x)
    {
        size_t i;
        foreach(y; partials[])
        {
            F h = x + y;
            debug(numeric) assert(h.isFinite);
            F l = fabs(x) < fabs(y) ? x - (h - y) : y - (h - x);
            debug(numeric) assert(l.isFinite);
            if(l)
            {
                partials[i++] = l;
            }
            x = h;
        }
        partials.length = i;
        if(x)
        {
            partials.put(x);
        }
    }

    /**
    Returns the value of the sum, rounded to the nearest representable 
    floating-point number using the round-half-to-even rule.
    */
    F sum() const 
    {
        debug(numeric) partialsDebug;
        
        if(s)
            return s;
        auto parts = partials[];
        F y = 0;
        //pick last
        if(parts.length)
        {
            y = parts[$-1];
            parts = parts[0..$-1];
        }
        if(o)
        {
            immutable F of = o;
            if(y && (o == -1 || o == 1)  && signbit(of * y))
            {
                // problem case: decide whether result is representable
                y /= 2;
                F x = of * M;
                immutable F h = x + y;
                F l = (y - (h - x)) * 2;
                y = h * 2;
                if(y.isInfinity)
                {
                    // overflow, except in edge case...
                    x = h + l;
                    y = parts.length && x - h == l && !signbit(l*parts[$-1]) ? 
                        x * 2 : 
                        F.infinity * of;
                    parts = null;
                }
                else if(l)
                {
                    bool _break;
                    y = partialsReducePred(y, l, parts.length ? parts[$-1] : 0, _break);
                    if(_break)
                        parts = null;
                }
            }
            else
            {
                y = F.infinity * of;
                parts = null;
            }
        }
        return partialsReduce(y, parts);
    }

    /**
    */
    F partialsSum() const 
    {
        debug(numeric) partialsDebug;
        auto parts = partials[];
        F y = 0;
        //pick last
        if(parts.length)
        {
            y = parts[$-1];
            parts = parts[0..$-1];
        }
        return partialsReduce(y, parts);
    }

    ///
    @property F nonFinitySum() const
    {
        return s;
    }

    ///
    @property sizediff_t overflowDegree() const
    {
        return o;
    }

    ///
    void resetNonPartials()
    {
        s = 0;
        o = 0;
    }

    ///Returns $(D Summator) with extended internal partial sums.
    Summator!(Unqual!E) extendTo(E)() if(
        isFloatingPoint!E && 
        E.max_exp >= F.max_exp &&
        E.mant_dig >= F.mant_dig
        )
    {
        static if(is(Unqual!E == F))
            return this;
        else
        {
            typeof(return) ret = void;
            ret.s = s;
            ret.o = o;
            ret.partials = scopeBuffer(ret.scopeBufferArray);
            foreach(p; partials[])
            {
                ret.partials.put(p);
            }
            enum exp_diff = E.max_exp - F.max_exp;
            static if(exp_diff)
            {
                if(ret.o)
                {
                    //enum shift = 2u ^^ exp_diff;
                    immutable f = ret.o >> exp_diff;
                    immutable t = cast(int)(ret.o - (f << exp_diff));
                    ret.o = f;
                    ret.put(E(2) ^^ t);
                }
            }
        }
    }

    ///
    unittest
    {
        import std.math;
        float  M = 2.0f ^^ (float.max_exp-1);
        double N = 2.0  ^^ (float.max_exp-1);
        auto s = Summator(0.0f); //float summator
        s += M;
        s += M;
        auto e = s.extendTo!double;

        assert(M+M == s.sum);
        assert(M+M ==  float.infinity);

        assert(N+N == e.sum);
        assert(N+N != double.infinity);
    }

    /**
    $(D cast(F)) operator overlaoding. Returns $(D cast(T)sum()).
    See also: $(D extendTo)
    */
    T opCast(T)() if(Unqual!T == F)
    {
        return sum();
    }

    ///The assignment operator $(D =) overlaoding.
    void opAssign(F rhs)
    {
        partials.length = 0;
        s = 0;
        o = 0;
        if(rhs) put(rhs);
    }

    /// += and -= operator overlaoding.
    void opOpAssign(string op : "+")(F f)
    {
        put(f);
    }

    ///ditto
    void opOpAssign(string op : "+")(ref const Summator rhs)
    {
        s += rhs.s;
        o += rhs.o;
        foreach(f; rhs.partials[])
            put(f);
    }

    ///ditto
    void opOpAssign(string op : "-")(F f)
    {
        put(-f);
    }

    ///ditto
    void opOpAssign(string op : "-")(ref const Summator rhs)
    {
        s -= rhs.s;
        o -= rhs.o;
        foreach(f; rhs.partials[])
            put(-f);
    }

    ///
    unittest {
        import std.math, std.algorithm, std.range;
        auto r1 = iota(  1, 501 ).map!(a => (-1.0)^^a/a);
        auto r2 = iota(501, 1001).map!(a => (-1.0)^^a/a);
        Summator!double s1 = 0.69264743055982025, s2 = 0;
        foreach(e; r1) s1 += e; 
        foreach(e; r2) s2 -= e; 
        s1 -= s2;
        assert(s1.sum == 0);
    }

    ///Returns $(D true) if current sum is a NaN.
    bool isNaN() const
    {
        if(s.isNaN)
            return true;
        if(s)
            return (s + overflow).isNaN;
        return false;
    }

    ///Returns $(D true) if current sum is finite (not infinite or NaN).
    bool isFinite() const
    {
        if(s)
            return false;
        return !overflow;
    }

    ///Returns $(D true) if current sum is ±∞.
    bool isInfinity() const
    {
        if(s.isNaN)
            return false;
        return (s + overflow).isInfinity;
    }
}

unittest 
{
    Summator!double summator = 0;
    
    enum double M = (cast(double)2) ^^ (double.max_exp - 1);
    Tuple!(double[], double)[] tests = [
        tuple(new double[0], 0.0),
        tuple([0.0], 0.0),
        tuple([1e100, 1.0, -1e100, 1e-100, 1e50, -1.0, -1e50], 1e-100),
        tuple([1e308, 1e308, -1e308], 1e308),
        tuple([-1e308, 1e308, 1e308], 1e308),
        tuple([1e308, -1e308, 1e308], 1e308),
        tuple([M, M, -2.0^^1000], 1.7976930277114552e+308),
        tuple([M, M, M, M, -M, -M, -M], 8.9884656743115795e+307),
        tuple([2.0^^53, -0.5, -2.0^^-54], 2.0^^53-1.0),
        tuple([2.0^^53, 1.0, 2.0^^-100], 2.0^^53+2.0),
        tuple([2.0^^53+10.0, 1.0, 2.0^^-100], 2.0^^53+12.0),
        tuple([2.0^^53-4.0, 0.5, 2.0^^-54], 2.0^^53-3.0),
        tuple([M-2.0^^970, -1.0, M], 1.7976931348623157e+308),
        
        tuple([double.max, double.max*2.^^-54], double.max),
        tuple([double.max, double.max*2.^^-53], double.infinity),

        tuple(iota(1, 1001).map!(a => 1.0/a).array , 7.4854708605503451),
        tuple(iota(1, 1001).map!(a => (-1.0)^^a/a).array, -0.69264743055982025), //0.693147180559945309417232121458176568075500134360255254120680...
        tuple(iota(1000).map!(a => 1.7.pow(a+1) - 1.7.pow(a)).chain([-(1.7.pow(1000))]).array , -1.0),
        
        tuple(iota(1, 1001).map!(a => 1.0/a).retro.array , 7.4854708605503451),
        tuple(iota(1, 1001).map!(a => (-1.0)^^a/a).retro.array, -0.69264743055982025),
        tuple(iota(1000).map!(a => 1.7.pow(a+1) - 1.7.pow(a)).chain([-(1.7.pow(1000))]).retro.array , -1.0),


        tuple([double.infinity, -double.infinity, double.nan], double.nan),
        tuple([double.nan, double.infinity, -double.infinity], double.nan),
        tuple([double.infinity, double.nan, double.infinity], double.nan),
        tuple([double.infinity, double.infinity], double.infinity),
        tuple([double.infinity, -double.infinity], double.nan),
        tuple([-double.infinity, 1e308, 1e308, -double.infinity], -double.infinity),

        tuple([M-2.0^^970, 0.0, M], double.infinity),
        tuple([M-2.0^^970, 1.0, M], double.infinity),
        tuple([M, M], double.infinity),
        tuple([M, M, -1.0], double.infinity),
        tuple([M, M, M, M, -M, -M], double.infinity),
        tuple([M, M, M, M, -M, M], double.infinity),
        tuple([-M, -M, -M, -M], -double.infinity),
        tuple([M, M, -2.^^971], double.max),
        tuple([M, M, -2.^^970], double.infinity),
        tuple([-2.^^970, M, M, -2.^^-1074], double.max),
        tuple([M, M, -2.^^970, 2.^^-1074], double.infinity),
        tuple([-M, 2.^^971, -M], -double.max),
        tuple([-M, -M, 2.^^970], -double.infinity),
        tuple([-M, -M, 2.^^970, 2.^^-1074], -double.max),
        tuple([-2.^^-1074, -M, -M, 2.^^970], -double.infinity),
        tuple([2.^^930, -2.^^980, M, M, M, -M], 1.7976931348622137e+308),
        tuple([M, M, -1e307], 1.6976931348623159e+308),
        tuple([1e16, 1., 1e-16], 10000000000000002.0),
    ];
    foreach(test; tests)
    {
        foreach(t; test[0]) summator.put(t);
        auto r = test[1];
        assert(summator.isNaN == r.isNaN);
        assert(summator.isFinite == r.isFinite);
        assert(summator.isInfinity == r.isInfinity);
        auto s = summator.sum;
        assert(s == r || s.isNaN && r.isNaN);
        summator = 0;
    }
}
