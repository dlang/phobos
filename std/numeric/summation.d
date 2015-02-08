/++
 + License: $(LINK2 http://boost.org/LICENSE_1_0.txt, Boost License 1.0).
 + Authors: Ilya Yaroshenko
 + Source: $(PHOBOSSRC std/internal/math/_summation.d)
 +/
module std.numeric.summation;

import std.traits;
import std.typecons;
import std.range.primitives;
import std.math : isNaN, isFinite, isInfinity, signbit;

/++
Summation algorithms for ranges of floating point numbers or $(D Complex).
+/
enum Summation
{
    /++
    Fast summation algorithm. 
    +/
    Fast,

    /++
    Naive algorithm.
    +/
    Naive,

    /++
    $(LUCKY Pairwise summation) algorithm. Range must be a finite sliceable range.
    +/
    Pairwise,
   
    /++
    $(LUCKY Kahan summation) algorithm.
    +/
    Kahan,
   
    /++
    $(LUCKY Kahan-Babuška-Neumaier summation algorithm). $(D КBN) gives more accurate results then $(D Kahan).
    +/
    KBN,
   
    /++
    $(LUCKY Generalized Kahan-Babuška summation algorithm), order 2. $(D КB2) gives more accurate results then $(D Kahan) and $(D КBN).
    +/
    KB2,
   
    /++
    Precise summation algorithm.
    Returns the value of the sum, rounded to the nearest representable
    floating-point number using the $(LUCKY round-half-to-even rule).
    +/
    Precise,
}

/++
Computes sum of range.
+/
template fsum(F, Summation summation = Summation.Precise)
    if (isFloatingPoint!F && isMutable!F)
{
    alias sum = Algo!summation;

    F fsum(Range)(Range r)
        if (isInputRange!Range)
    {
        return sum!(Range, typeof(return))(r);
    }

    F fsum(F, Range)(F seed, Range r)
        if (isInputRange!Range)
    {
        return sum!(Range, F)(r, seed);
    }

    //F fsum(Range)(Range r, F seed)
    //    if (
    //        isInputRange!Range && 
    //        isImplicitlyConvertible!(Unqual!(ForeachType!Range), F) &&
    //        !isInfinite!Range &&
    //        (
    //            summation != Summation.Pairwise || 
    //            hasLength!Range && hasSlicing!Range
    //        )
    //    )
}

    //static assert(
    //    __traits(compiles, 
    //    {
    //        F a = 0.0, b, c; 
    //        c = a + b; 
    //        c = a - b;
    //        static if (summation != Summation.Pairwise)
    //        {
    //            a += b;
    //            a -= b;
    //        }
    //    }), summation.stringof ~ " isn't implemented for " ~ F.stringof);

///ditto
template fsum(Summation summation = Summation.Precise)
{
    alias sum = Algo!summation;

    Unqual!(ForeachType!Range) fsum(Range)(Range r)
        if (isInputRange!Range)
    {
        return sum!(Range, typeof(return))(r);
    }

    F fsum(F, Range)(F seed, Range r)
        if (isInputRange!Range)
    {
        return sum!(F, Range)(r, seed);
    }
}

///
unittest 
{
    import std.math, std.algorithm, std.range;
    auto ar = 1000
        .iota
        .map!(n => 1.7.pow(n+1) - 1.7.pow(n))
        .chain([-(1.7.pow(1000))]);

    //Summation.Precise is default
    assert(ar.fsum  ==  -1.0);
    assert(ar.retro.fsum  ==  -1.0);
}

///
unittest {
    import std.algorithm;
    auto ar = [1, 1e100, 1, -1e100].map!(a => a*10000);
    const r = 20000;
    assert(r != ar.fsum!(Summation.Naive));
    assert(r != ar.fsum!(Summation.Pairwise));
    assert(r != ar.fsum!(Summation.Kahan));
    assert(r == ar.fsum!(Summation.KBN));
    assert(r == ar.fsum!(Summation.KB2));
    assert(r == ar.fsum); //Summation.Precise
}

/++
$(D Fast), $(D Pairwise) and $(D Kahan) algorithms can be used for summation user defined types.
+/
unittest 
{
    static struct Quaternion(F) 
        if (isFloatingPoint!F)
    {
        F[3] array;

        /// + and - operator overloading
        Quaternion opBinary(string op)(auto ref Quaternion rhs) const
            if (op == "+" || op == "-")
        {
            Quaternion ret = void;
            foreach (i, ref e; ret.array)
                mixin("e = array[i] "~op~" rhs.array[i];");
            return ret;
        }

        /// += and -= operator overloading
        Quaternion opOpAssign(string op)(auto ref Quaternion rhs)
            if (op == "+" || op == "-")
        {
            Quaternion ret = void;
            foreach (i, ref e; array)
                mixin("e "~op~"= rhs.array[i];");
            return this;
        }

        ///constructor with single FP argument
        this(F f) 
        {
            array[] = f;
        }
    }

    Quaternion!double q, p, r;
    q.array = [0, 1, 2];
    p.array = [3, 4, 5];
    r.array = [3, 5, 7];

    assert(r == [p, q].fsum!(Summation.Fast));
    assert(r == [p, q].fsum!(Summation.Pairwise));
    assert(r == [p, q].fsum!(Summation.Kahan));
}


/++
All summation algorithms available for complex numbers.
+/
unittest 
{
    import std.complex;
    Complex!double[] ar = [complex(1.0, 2), complex(2, 3), complex(3, 4), complex(4, 5)];
    Complex!double r = complex(10, 14);
    assert(r == ar.fsum);
}


/++
Handler for full precise summation with $(D put) primitive.
The current implementation re-establish special
value semantics across iterations (i.e. handling -inf + inf).

References: $(LINK2 http://www.cs.cmu.edu/afs/cs/project/quake/public/papers/robust-arithmetic.ps,
"Adaptive Precision Floating-Point Arithmetic and Fast Robust Geometric Predicates", Jonathan Richard Shewchuk)
+/
/+
Precise summation function as msum() by Raymond Hettinger in
<http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/393090>,
enhanced with the exact partials sum and roundoff from Mark
Dickinson's post at <http://bugs.python.org/file10357/msum4.py>.
See those links for more details, proofs and other references.
IEEE 754R floating point semantics are assumed.
+/
struct Summator(F)
    if (isFloatingPoint!F && isMutable!F)
{
    import std.internal.scopebuffer;

private:
    enum F M = (cast(F)(2)) ^^ (F.max_exp - 1);
    F[32] scopeBufferArray = void;
    ScopeBuffer!F partials;        
    //sum for NaN and infinity.
    F s;
    //Overflow Degree. Count of 2^^F.max_exp minus count of -(2^^F.max_exp)
    sizediff_t o; 


    /++
    Compute the sum of a list of nonoverlapping floats.
    On input, partials is a list of nonzero, nonspecial,
    nonoverlapping floats, strictly increasing in magnitude, but
    possibly not all having the same sign.
    On output, the sum of partials gives the error in the returned
    result, which is correctly rounded (using the round-half-to-even
    rule).
    Two floating point values x and y are non-overlapping if the least significant nonzero
    bit of x is more significant than the most significant nonzero bit of y, or vice-versa.
    +/
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
            if (_break)
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
        if (l)
        {
        //Make half-even rounding work across multiple partials.
        //Needed so that sum([1e-16, 1, 1e16]) will round-up the last
        //digit to two instead of down to zero (the 1e-16 makes the 1
        //slightly closer to two). Can guarantee commutativity.
            if (z && !signbit(l * z))
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
        if (o == 0)
            return 0;
        if (partials.length && (o == -1 || o == 1)  && signbit(o * partials[$-1]))
        {
            // problem case: decide whether result is representable
            F x = o * M;
            F y = partials[$-1] / 2;
            F h = x + y;
            F l = (y - (h - x)) * 2;
            y = h * 2;
            if (!.isInfinity(y) || partials.length > 1 && !signbit(l * partials[$-2]) && (h + l) - h == l)
                return 0;
        }
        return F.infinity * o;
    }

public:

    ///
    this(F x)
    {
        partials = scopeBuffer(scopeBufferArray);
        s = 0;
        o = 0;
        if (x) put(x);
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
        if (scopeBufferArray.ptr !is a.ptr)
        {
            partials = scopeBuffer(scopeBufferArray);
            partials.put(a);
        }
    }

    ///Adds $(D x) to internal partial sums.
    void put(F x)
    {
        if (.isFinite(x))
        {
            size_t i;
            foreach (y; partials[])
            {
                F h = x + y;
                if (.isInfinity(h))
                {
                    if (fabs(x) < fabs(y))
                    {
                        F t = x; x = y; y = t;
                    }
                    //h == -F.infinity
                    if (signbit(h)) 
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
                if (l)
                {
                    partials[i++] = l;
                }
                x = h;
            }
            partials.length = i;
            if (x)
            {
                partials.put(x);
            }
        }
        else
        {
            s += x;
        }
    }

    /++
    Adds $(D x) to the internal partial sums.
    +/
    void unsafePut(F x)
    in {
        assert(.isFinite(x));
    }
    body {
        size_t i;
        foreach (y; partials[])
        {
            F h = x + y;
            debug(numeric) assert(.isFinite(h));
            F l = fabs(x) < fabs(y) ? x - (h - y) : y - (h - x);
            debug(numeric) assert(.isFinite(l));
            if (l)
            {
                partials[i++] = l;
            }
            x = h;
        }
        partials.length = i;
        if (x)
        {
            partials.put(x);
        }
    }

    /++
    Returns the value of the sum, rounded to the nearest representable 
    floating-point number using the round-half-to-even rule.
    +/
    F sum() const
    {
        debug(numeric)
        {
            foreach (y; partials[])
            {
                assert(y);
                assert(y.isFinite);
            }
            //TODO: Add Non-Overlapping check to std.math
            import std.algorithm : isSorted, map;
            assert(partials[].map!(a => fabs(a)).isSorted);
        }

        if (s)
            return s;
        auto parts = partials[];
        F y = 0;
        //pick last
        if (parts.length)
        {
            y = parts[$-1];
            parts = parts[0..$-1];
        }
        if (o)
        {
            immutable F of = o;
            if (y && (o == -1 || o == 1)  && signbit(of * y))
            {
                // problem case: decide whether result is representable
                y /= 2;
                F x = of * M;
                immutable F h = x + y;
                F l = (y - (h - x)) * 2;
                y = h * 2;
                if (y.isInfinity)
                {
                    // overflow, except in edge case...
                    x = h + l;
                    y = parts.length && x - h == l && !signbit(l*parts[$-1]) ? 
                        x * 2 : 
                        F.infinity * of;
                    parts = null;
                }
                else if (l)
                {
                    bool _break;
                    y = partialsReducePred(y, l, parts.length ? parts[$-1] : 0, _break);
                    if (_break)
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

    version(none)
    F partialsSum() const 
    {
        debug(numeric) partialsDebug;
        auto parts = partials[];
        F y = 0;
        //pick last
        if (parts.length)
        {
            y = parts[$-1];
            parts = parts[0..$-1];
        }
        return partialsReduce(y, parts);
    }

    ///Returns $(D Summator) with extended internal partial sums.
    T opCast(T : Summator!P, P)() 
        if (
            isMutable!T &&
            P.max_exp >= F.max_exp &&
            P.mant_dig >= F.mant_dig
        )
    {
        static if (is(P == F))
            return this;
        else
        {
            typeof(return) ret = void;
            ret.s = s;
            ret.o = o;
            ret.partials = scopeBuffer(ret.scopeBufferArray);
            foreach (p; partials[])
            {
                ret.partials.put(p);
            }
            enum exp_diff = P.max_exp / F.max_exp;
            static if (exp_diff)
            {
                if (ret.o)
                {
                    immutable f = ret.o / exp_diff;
                    immutable t = cast(int)(ret.o % exp_diff);
                    ret.o = f;
                    ret.put((P(2) ^^ F.max_exp) * t);
                }
            }
            return ret;
        }
    }

    ///
    unittest
    {
        import std.math;
        float  M = 2.0f ^^ (float.max_exp-1);
        double N = 2.0  ^^ (float.max_exp-1);
        auto s = Summator!float(0); //float summator
        s += M;
        s += M;
        auto e = cast(Summator!double) s;

        assert(M+M == s.sum);
        assert(M+M ==  float.infinity);
        assert(N+N == e.sum);
        assert(N+N != double.infinity);
    }

    /++
    $(D cast(F)) operator overlaoding. Returns $(D cast(T)sum()).
    See also: $(D cast)
    +/
    T opCast(T)() if (is(Unqual!T == F))
    {
        return sum();
    }

    ///The assignment operator $(D =) overlaoding.
    void opAssign(F rhs)
    {
        partials.length = 0;
        s = 0;
        o = 0;
        if (rhs) put(rhs);
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
        foreach (f; rhs.partials[])
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
        foreach (f; rhs.partials[])
            put(-f);
    }
    ///
    unittest {
        import std.math, std.algorithm, std.range;
        auto r1 = iota(  1, 501 ).map!(a => (-1.0).pow(a)/a);
        auto r2 = iota(501, 1001).map!(a => (-1.0).pow(a)/a);
        Summator!double s1 = 0.0, s2 = 0.0;
        foreach (e; r1) s1 += e; 
        foreach (e; r2) s2 -= e; 
        s1 -= s2;
        assert(s1.sum == -0.69264743055982025);
    }

    ///Returns $(D true) if current sum is a NaN.
    bool isNaN() const
    {
        return .isNaN(s);
    }

    ///Returns $(D true) if current sum is finite (not infinite or NaN).
    bool isFinite() const
    {
        if (s)
            return false;
        return !overflow;
    }

    ///Returns $(D true) if current sum is ±∞.
    bool isInfinity() const
    {
        return .isInfinity(s) || overflow();
    }
}

unittest 
{
    import std.range;
    import std.algorithm;
    import std.math;

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
    foreach (test; tests)
    {
        foreach (t; test[0]) summator.put(t);
        auto r = test[1];
        assert(summator.isNaN() == r.isNaN());
        assert(summator.isFinite() == r.isFinite());
        assert(summator.isInfinity() == r.isInfinity());
        auto s = summator.sum;
        assert(s == r || s.isNaN && r.isNaN);
        summator = 0;
    }
}


private:

//template isComplex(C)
//{
//    import std.complex : Complex;
//    enum isComplex = is(C : Complex!F, F);
//}

// FIXME (perfomance issue): fabs in std.math avaliable only for for real.
F fabs(F)(F f) //+-0, +-NaN, +-inf doesn't matter
{
    if (__ctfe)
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

//if (
//    isInputRange!Range && 
//    isImplicitlyConvertible!(Unqual!(ForeachType!Range), F) &&
//    !isInfinite!Range &&
//    (
//        summation != Summation.Pairwise || 
//        hasLength!Range && hasSlicing!Range
//    )
//)

/++
Naive summation algorithm. 
+/
F sumNaive(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0)
{
    foreach (x; r)
    {
        s += x;
    }
    return s;
}

///TODO
alias sumFast = sumNaive;

/++
$(LUCKY Pairwise summation) algorithm. Range must be a finite sliceable range.
+/

F sumPairwise(Range, F = Unqual!(ForeachType!Range))(Range r)
    if (hasLength!Range && hasSlicing!Range)
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

F sumPairwise(Range, F = Unqual!(ForeachType!Range))(Range r, F seed)
{
    return sumPairwise!Range(r) + seed;
}


/++
$(LUCKY Kahan summation) algorithm.
+/
/++
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
+/
F sumKahan(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0)
{
    F c = 0.0;
    F y; // do not declare in the loop (algo can be used for matrixes and etc)
    F t; // ditto
    foreach (F x; r)
    {
        y = x - c;
        t = s + y;
        c = t - s;
        c -= y;
        s = t;
    }
    return s;    
}


/++
$(LUCKY Kahan-Babuška-Neumaier summation algorithm). 
$(D КBN) gives more accurate results then $(D Kahan).
+/
/++
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
+/
F sumKBN(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0) 
{
    F c = 0.0;
    static if (isFloatingPoint!F)
    {
        foreach (F x; r)
        {
            F t = s + x;
            if (fabs(s) >= fabs(x))
                c += (s-t)+x;
            else
                c += (x-t)+s;
            s = t;
        }
    }
    else
    {
        foreach (F x; r)
        {
            F t = s + x;
            if (fabs(s.re) < fabs(x.re))
            {
                auto t_re = s.re;
                s.re = x.re;
                x.re = t_re;
            }
            if (fabs(s.im) < fabs(x.im))
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


/++
$(LUCKY Generalized Kahan-Babuška summation algorithm), order 2. 
$(D КB2) gives more accurate results then $(D Kahan) and $(D КBN).
+/
/++
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
+/
F sumKB2(Range, F = Unqual!(ForeachType!Range))(Range r, F s = 0) 
{
    F cs = 0.0;
    F ccs = 0.0;
    static if (isFloatingPoint!F)
    {
        foreach (F x; r)
        {
            F t = s + x;
            F c = void;
            if (fabs(s) >= fabs(x))
                c = (s-t)+x;
            else
                c = (x-t)+s;
            s = t;
            t = cs + c;
            if (fabs(cs) >= fabs(c))
                ccs += (cs-t)+c;
            else
                ccs += (c-t)+cs;
            cs = t;
        }
    }
    else
    {
        foreach (F x; r)
        {
            F t = s + x;
            if (fabs(s.re) < fabs(x.re))
            {
                auto t_re = s.re;
                s.re = x.re;
                x.re = t_re;
            }
            if (fabs(s.im) < fabs(x.im))
            {
                auto t_im = s.im;
                s.im = x.im;
                x.im = t_im;
            }
            F c = (s-t)+x;
            s = t;
            if (fabs(cs.re) < fabs(c.re))
            {
                auto t_re = cs.re;
                cs.re = c.re;
                c.re = t_re;
            }
            if (fabs(cs.im) < fabs(c.im))
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
    foreach (I; TypeTuple!(byte, uint, long))
    {
        I[] ar = [1, 2, 3, 4];
        I r = 10;
        assert(r == ar.sumFast());
        assert(r == ar.sumPairwise());
    }
}

unittest 
{
    import std.typetuple;
    foreach (F; TypeTuple!(float, double, real))
    {
        F[] ar = [1, 2, 3, 4];
        F r = 10;
        assert(r == ar.sumFast());
        assert(r == ar.sumPairwise());
        assert(r == ar.sumKahan());
        assert(r == ar.sumKBN());
        assert(r == ar.sumKB2());
    }
}

unittest 
{
    import std.complex;
    Complex!double[] ar = [complex(1.0, 2), complex(2, 3), complex(3, 4), complex(4, 5)];
    Complex!double r = complex(10, 14);
    assert(r == ar.sumFast());
    assert(r == ar.sumPairwise());
    assert(r == ar.sumKahan());
    assert(r == ar.sumKBN());
    assert(r == ar.sumKB2());
}

//@@@BUG@@@: DMD 2.066 Segmentation fault (core dumped)
version(none)
unittest 
{
    import core.simd;
    static if (__traits(compiles, double2.init + double2.init))
    {
        double2[] ar = [double2([1.0, 2]), double2([2, 3]), double2([3, 4]), double2([4, 6])];
        assert(ar.sumFast().array == double2([10, 14]).array);
        assert(ar.sumPairwise().array == double2([10, 14]).array);
        assert(ar.sumKahan().array == double2([10, 14]).array);
    }
}

unittest 
{
    import std.algorithm : map;
    auto ar = [1, 1e100, 1, -1e100].map!(a => a*10000);
    double r = 20000;
    assert(r != ar.sumFast());
    //assert(r != ar.sumNaive()); //undefined
    assert(r != ar.sumPairwise());
    assert(r != ar.sumKahan());
    assert(r == ar.sumKBN());
    assert(r == ar.sumKB2());
}

/++
Precise summation.
+/
F sumPrecise(Range, F = Unqual!(ForeachType!Range))(Range r, F seed = 0) 
{
    static if (isFloatingPoint!F)
    {
        auto sum = Summator!F(seed);
        foreach (e; r)
        {
            sum.put(e);
        }
        return sum.sum;
    }
    else
    {
        alias T = typeof(F.init.re);
        static if (isForwardRange!Range)
        {
            auto s = r.save;
            auto sum = Summator!T(seed.re);
            foreach (e; r)
            {
                sum.put(e.re);
            }
            T sumRe = sum.sum;
            sum = seed.im;
            foreach (e; s)
            {
                sum.put(e.im);
            }
            return F(sumRe, sum.sum);
        }
        else
        {
            auto sumRe = Summator!T(seed.re);
            auto sumIm = Summator!T(seed.im);
            foreach (e; r)
            {
                sumRe.put(e.re);
                sumIm.put(e.im);
            }
            return F(sumRe.sum, sumIm.sum);
        }
    }
}

template Algo(Summation summation)
{
    
    static if (summation == Summation.Fast)
        alias Algo = sumFast;
    else 
    static if (summation == Summation.Naive)
        alias Algo = sumNaive;
    else 
    static if (summation == Summation.Pairwise)
        alias Algo = sumPairwise;
    else 
    static if (summation == Summation.Kahan)
        alias Algo = sumKahan;
    else 
    static if (summation == Summation.KBN)
        alias Algo = sumKBN;
    else 
    static if (summation == Summation.KB2)
        alias Algo = sumKB2;
    else 
    static if (summation == Summation.Precise)
        alias Algo = sumPrecise;
    else 
    static assert(0);

}
