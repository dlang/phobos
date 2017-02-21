/**
This module contains summation algorithms.

Project:
    $(LINK2 http://mir.dlang.io, Mir)

License: $(LINK2 http://boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Ilya Yaroshenko

Copyright: Copyright © 2015-, Ilya Yaroshenko
*/
module std.experimental.numeric.sum;

///
unittest
{
    import std.algorithm.iteration: map;
    auto ar = [1, 1e100, 1, -1e100].map!(a => a*10_000);
    const r = 20_000;
    assert(r == ar.sum!(Summation.kbn));
    assert(r == ar.sum!(Summation.kb2));
    assert(r == ar.sum!(Summation.precise));
}

///
unittest
{
    import std.algorithm.iteration: map;
    import std.math, std.range;
    auto ar = 1000
        .iota
        .map!(n => 1.7L.pow(n+1) - 1.7L.pow(n))
        .array
        ;
    real d = 1.7L.pow(1000);
    assert(sum!(Summation.precise)(ar.chain([-d])) == -1);
    assert(sum!(Summation.precise)(ar.retro, -d) == -1);
}

/++
$(D Naive), $(D Pairwise) and $(D Kahan) algorithms can be used for user defined types.
+/
unittest
{
    static struct Quaternion(F)
        if (isFloatingPoint!F)
    {
        F[4] rijk;

        /// + and - operator overloading
        Quaternion opBinary(string op)(auto ref const Quaternion rhs) const
            if (op == "+" || op == "-")
        {
            Quaternion ret = void;
            foreach (i, ref e; ret.rijk)
                mixin("e = rijk[i] "~op~" rhs.rijk[i];");
            return ret;
        }

        /// += and -= operator overloading
        Quaternion opOpAssign(string op)(auto ref const Quaternion rhs)
            if (op == "+" || op == "-")
        {
            foreach (i, ref e; rijk)
                mixin("e "~op~"= rhs.rijk[i];");
            return this;
        }

        ///constructor with single FP argument
        this(F f)
        {
            rijk[] = f;
        }

        ///assigment with single FP argument
        void opAssign(F f)
        {
            rijk[] = f;
        }
    }

    Quaternion!double q, p, r;
    q.rijk = [0, 1, 2, 4];
    p.rijk = [3, 4, 5, 9];
    r.rijk = [3, 5, 7, 13];

    assert(r == [p, q].sum!(Summation.naive));
    assert(r == [p, q].sum!(Summation.pairwise));
    assert(r == [p, q].sum!(Summation.kahan));
}

/++
All summation algorithms available for complex numbers.
+/
unittest
{
    cdouble[] ar = [1.0 + 2i, 2 + 3i, 3 + 4i, 4 + 5i];
    cdouble r = 10 + 14i;
    assert(r == ar.sum!(Summation.fast));
    assert(r == ar.sum!(Summation.naive));
    assert(r == ar.sum!(Summation.pairwise));
    assert(r == ar.sum!(Summation.kahan));
    assert(r == ar.sum!(Summation.kbn));
    assert(r == ar.sum!(Summation.kb2));
    assert(r == ar.sum!(Summation.precise));
}

///
@safe pure nothrow unittest
{
    import std.range: repeat, iota;

    //simple integral summation
    assert(sum([ 1, 2, 3, 4]) == 10);

    //with initial value
    assert(sum([ 1, 2, 3, 4], 5) == 15);

    //with integral promotion
    assert(sum([false, true, true, false, true]) == 3);
    assert(sum(ubyte.max.repeat(100)) == 25_500);

    //The result may overflow
    assert(uint.max.repeat(3).sum()           ==  4_294_967_293U );
    //But a seed can be used to change the summation primitive
    assert(uint.max.repeat(3).sum(ulong.init) == 12_884_901_885UL);

    //Floating point summation
    assert(sum([1.0, 2.0, 3.0, 4.0]) == 10);

    //Type overriding
    static assert(is(typeof(sum!double([1F, 2F, 3F, 4F])) == double));
    static assert(is(typeof(sum!double([1F, 2F, 3F, 4F], 5F)) == double));
    assert(sum([1F, 2, 3, 4]) == 10);
    assert(sum([1F, 2, 3, 4], 5F) == 15);

    //Force pair-wise floating point summation on large integers
    import std.math : approxEqual;
    assert(iota(uint.max / 2, uint.max / 2 + 4096).sum(0.0)
               .approxEqual((uint.max / 2) * 4096.0 + 4096^^2 / 2));
}

/// Precise summation
nothrow @nogc unittest
{
    import std.range: iota;
    import std.algorithm.iteration: map;
    import core.stdc.tgmath: pow;
    assert(iota(1000).map!(n => 1.7L.pow(real(n)+1) - 1.7L.pow(real(n)))
                     .sum!(Summation.precise) == -1 + 1.7L.pow(1000.0L));
}

/// Precise summation with output range
nothrow @nogc unittest
{
    import std.range: iota;
    import std.algorithm.iteration: map;
    import std.math;
    auto r = iota(1000).map!(n => 1.7L.pow(n+1) - 1.7L.pow(n));
    Summator!(real, Summation.precise) s = 0.0;
    s.put(r);
    s -= 1.7L.pow(1000);
    assert(s.sum() == -1);
}

/// Precise summation with output range
nothrow @nogc unittest
{
    import std.math;
    float  M = 2.0f ^^ (float.max_exp-1);
    double N = 2.0  ^^ (float.max_exp-1);
    auto s = Summator!(float, Summation.precise)(0);
    s += M;
    s += M;
    assert(float.infinity == s.sum()); //infinity
    auto e = cast(Summator!(double, Summation.precise)) s;
    assert(isFinite(e.sum()));
    assert(N+N == e.sum()); //finite number
}

/// Moving mean
unittest
{
    import std.range;
    import std.experimental.numeric.sum;

    class MovingAverage
    {
        Summator!(double, Summation.precise) summator;
        double[] circularBuffer;
        size_t frontIndex;

        double avg() @property const
        {
            return summator.sum() / circularBuffer.length;
        }

        this(double[] buffer)
        {
            assert(!buffer.empty);
            circularBuffer = buffer;
            summator = 0;
            summator.put(buffer);
        }

        ///operation without rounding
        void put(double x)
        {
            import std.algorithm.mutation : swap;
            summator += x;
            swap(circularBuffer[frontIndex++], x);
            summator -= x;
            frontIndex %= circularBuffer.length;
        }
    }

    /// ma always keeps precise average of last 1000 elements
    auto ma = new MovingAverage(iota(0.0, 1000.0).array);
    assert(ma.avg == (1000 * 999 / 2) / 1000.0);
    /// move by 10 elements
    put(ma, iota(1000.0, 1010.0));
    assert(ma.avg == (1010 * 1009 / 2 - 10 * 9 / 2) / 1000.0);
}

version(X86)
    version = X86_Any;
version(X86_64)
    version = X86_Any;

/++
SIMD Vectors
Bugs: ICE 1662 (dmd only)
+/
version(LDC)
version(X86_Any)
unittest
{
    import core.simd;
    double2 a = 1, b = 2, c = 3, d = 6;
    with(Summation)
    {
        foreach (algo; AliasSeq!(naive, fast, pairwise, kahan))
        {
            assert([a, b, c].sum!algo.array == d.array);
            assert([a, b].sum!algo(c).array == d.array);
        }
    }
}

import std.traits;
import std.typecons;
import std.range.primitives;
import std.meta: AliasSeq;
import std.math: isInfinity, isFinite, isNaN, signbit;

private template isComplex(C)
{
    enum bool isComplex
     = is(Unqual!C == creal)
    || is(Unqual!C == cdouble)
    || is(Unqual!C == cfloat);
}

private template chainSeq(size_t n)
{
    static if (n)
        alias chainSeq = AliasSeq!(n, chainSeq!(n / 2));
    else
        alias chainSeq = AliasSeq!();
}

private alias Iota(size_t j) = Iota!(0, j);

private template Iota(size_t i, size_t j)
{
    static assert(i <= j, "Iota: i should be less than or equal to j");
    static if (i == j)
        alias Iota = AliasSeq!();
    else
        alias Iota = AliasSeq!(i, Iota!(i + 1, j));
}

/++
Summation algorithms.
+/
enum Summation
{
    /++
    Performs $(D pairwise) summation for floating point based types and $(D fast) summation for integral based types.
    +/
    appropriate,

    /++
    $(WEB en.wikipedia.org/wiki/Pairwise_summation, Pairwise summation) algorithm.
    +/
    pairwise,

    /++
    Precise summation algorithm.
    The value of the sum is rounded to the nearest representable
    floating-point number using the $(LUCKY round-half-to-even rule).
    The result can differ from the exact value on $(D X86), $(D nextDown(proir) <= result &&  result <= nextUp(proir)).
    The current implementation re-establish special value semantics across iterations (i.e. handling -inf + inf).

    References: $(LINK2 http://www.cs.cmu.edu/afs/cs/project/quake/public/papers/robust-arithmetic.ps,
        "Adaptive Precision Floating-Point Arithmetic and Fast Robust Geometric Predicates", Jonathan Richard Shewchuk),
        $(LINK2 http://bugs.python.org/file10357/msum4.py, Mark Dickinson's post at bugs.python.org).
    +/

    /+
    Precise summation function as msum() by Raymond Hettinger in
    <http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/393090>,
    enhanced with the exact partials sum and roundoff from Mark
    Dickinson's post at <http://bugs.python.org/file10357/msum4.py>.
    See those links for more details, proofs and other references.
    IEEE 754R floating point semantics are assumed.
    +/
    precise,

    /++
    $(WEB en.wikipedia.org/wiki/Kahan_summation, Kahan summation) algorithm.
    +/
    /+
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
    kahan,

    /++
    $(LUCKY Kahan-Babuška-Neumaier summation algorithm). $(D KBN) gives more accurate results then $(D Kahan).
    +/
    /+
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
    kbn,

    /++
    $(LUCKY Generalized Kahan-Babuška summation algorithm), order 2. $(D KB2) gives more accurate results then $(D Kahan) and $(D KBN).
    +/
    /+
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
    kb2,

    /++
    Naive algorithm (one by one).
    +/
    naive,

    /++
    SIMD optimized summation algorithm.
    +/
    fast,
}

/++
Output range for summation.
+/
struct Summator(T, Summation summation)
    if (isMutable!T)
{
    version (LDC)
        import ldc.intrinsics: fabs = llvm_fabs;
    else
        import std.math: fabs;
    static if (is(T == class) || is(T == interface) || hasElaborateAssign!T)
        static assert (summation == Summation.naive,
            "Classes, interfaces, and structures with "
            ~ "elaborate constructor support only naive summation.");

    static if (summation == Summation.fast)
    {
        version (LDC)
        {
            import ldc.attributes: fastmath;
            alias attr = fastmath;
        }
        else
        {
            alias attr = AliasSeq!();
        }
    }
    else
    {
        alias attr = AliasSeq!();
    }

    @attr:

    static if (summation != Summation.pairwise)
        @disable this();

    static if (summation == Summation.pairwise)
        private enum bool fastPairwise =
            is(F == float) ||
            is(F == double) ||
            is(F == cfloat) ||
            is(F == cdouble) ||
            is(F : __vector(W[N]), W, size_t N);
            //false;

    alias F = T;

    static if (summation == Summation.precise)
    {
        import std.internal.scopebuffer;

    private:
        enum F M = (cast(F)(2)) ^^ (T.max_exp - 1);
        F[16] scopeBufferArray = void;
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
            foreach_reverse (i, y; partials)
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
            F d = s - x;
            F l = y - d;
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
                    F t = x - s;
                    if (l == t)
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
                F d = h - x;
                F l = (y - d) * 2;
                y = h * 2;
                d = h + l;
                F t = d - h;
                version(X86)
                {
                    if (!.isInfinity(cast(T)y) || !.isInfinity(sum()))
                        return 0;
                }
                else
                {
                    if (!.isInfinity(cast(T)y) ||
                        ((partials.length > 1 && !signbit(l * partials[$-2])) && t == l))
                        return 0;
                }
            }
            return F.infinity * o;
        }
    }
    else
    static if (summation == Summation.kb2)
    {
        F s = void;
        F cs = void;
        F ccs = void;
    }
    else
    static if (summation == Summation.kbn)
    {
        F s = void;
        F c = void;
    }
    else
    static if (summation == Summation.kahan)
    {
        F s = void;
        F c = void;
        F y = void; // do not declare in the loop/put (algo can be used for matrixes and etc)
        F t = void; // ditto
    }
    else
    static if (summation == Summation.pairwise)
    {
        package size_t counter;
        size_t index;
        static if (fastPairwise)
        {
            enum registersCount= 16;
            F[size_t.sizeof * 8] partials = void;
        }
        else
        {
            F[size_t.sizeof * 8] partials = void;
        }
    }
    else
    static if (summation == Summation.naive)
    {
        F s = void;
    }
    else
    static if (summation == Summation.fast)
    {
        F s = void;
    }
    else
    static assert(0, "Unsupported summation type for std.numeric.Summator.");


public:

    ///
    this(T n)
    {
        static if (summation == Summation.precise)
        {
            partials = scopeBuffer(scopeBufferArray);
            s = 0.0;
            o = 0;
            if (n) put(n);
        }
        else
        static if (summation == Summation.kb2)
        {
            s = n;
            static if (isComplex!T)
            {
                cs = 0 + 0fi;
                ccs = 0 + 0fi;
            }
            else
            {
                cs = 0.0;
                ccs = 0.0;
            }
        }
        else
        static if (summation == Summation.kbn)
        {
            s = n;
            static if (isComplex!T)
                c = 0 + 0fi;
            else
                c = 0.0;
        }
        else
        static if (summation == Summation.kahan)
        {
            s = n;
            static if (isComplex!T)
                c = 0 + 0fi;
            else
                c = 0.0;
        }
        else
        static if (summation == Summation.pairwise)
        {
            counter = index = 1;
            partials[0] = n;
        }
        else
        static if (summation == Summation.naive)
        {
            s = n;
        }
        else
        static if (summation == Summation.fast)
        {
            s = n;
        }
        else
        static assert(0);
    }

    // free ScopeBuffer
    static if (summation == Summation.precise)
    ~this()
    {
        partials.free;
    }

    // copy ScopeBuffer if necessary
    static if (summation == Summation.precise)
    this(this)
    {
        auto a = partials[];
        if (scopeBufferArray.ptr !is a.ptr)
        {
            partials = scopeBuffer(scopeBufferArray);
            partials.put(a);
        }
    }

    ///Adds $(D n) to the internal partial sums.
    void put(N)(N n)
        if (__traits(compiles, {T a = n; a = n; a += n;}))
    {
        static if (isCompesatorAlgorithm!summation)
            F x = n;
        static if (summation == Summation.precise)
        {
            if (.isFinite(x))
            {
                size_t i;
                foreach (y; partials[])
                {
                    F h = x + y;
                    if (.isInfinity(cast(T)h))
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
                    F l;
                    if (fabs(x) < fabs(y))
                    {
                        F t = h - y;
                        l = x - t;
                    }
                    else
                    {
                        F t = h - x;
                        l = y - t;
                    }
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
        else
        static if (summation == Summation.kb2)
        {
            static if (isFloatingPoint!F)
            {
                F t = s + x;
                F c = void;
                if (fabs(s) >= fabs(x))
                {
                    F d = s - t;
                    c = d + x;
                }
                else
                {
                    F d = x - t;
                    c = d + s;
                }
                s = t;
                t = cs + c;
                if (fabs(cs) >= fabs(c))
                {
                    F d = cs - t;
                    d += c;
                    ccs += d;
                }
                else
                {
                    F d = c - t;
                    d += cs;
                    ccs += d;
                }
                cs = t;
            }
            else
            {
                F t = s + x;
                if (fabs(s.re) < fabs(x.re))
                {
                    auto s_re = s.re;
                    auto x_re = x.re;
                    s = x_re + s.im * 1fi;
                    x = s_re + x.im * 1fi;
                }
                if (fabs(s.im) < fabs(x.im))
                {
                    auto s_im = s.im;
                    auto x_im = x.im;
                    s = s.re + x_im * 1fi;
                    x = x.re + s_im * 1fi;
                }
                F c = (s-t)+x;
                s = t;
                if (fabs(cs.re) < fabs(c.re))
                {
                    auto c_re = c.re;
                    auto cs_re = cs.re;
                    c = cs_re + c.im * 1fi;
                    cs = c_re + cs.im * 1fi;
                }
                if (fabs(cs.im) < fabs(c.im))
                {
                    auto c_im = c.im;
                    auto cs_im = cs.im;
                    c = c.re + cs_im * 1fi;
                    cs = cs.re + c_im * 1fi;
                }
                F d = cs - t;
                d += c;
                ccs += d;
                cs = t;
            }
        }
        else
        static if (summation == Summation.kbn)
        {
            static if (isFloatingPoint!F)
            {
                F t = s + x;
                if (fabs(s) >= fabs(x))
                {
                    F d = s - t;
                    d += x;
                    c += d;
                }
                else
                {
                    F d = x - t;
                    d += s;
                    c += d;
                }
                s = t;
            }
            else
            {
                F t = s + x;
                if (fabs(s.re) < fabs(x.re))
                {
                    auto s_re = s.re;
                    auto x_re = x.re;
                    s = x_re + s.im * 1fi;
                    x = s_re + x.im * 1fi;
                }
                if (fabs(s.im) < fabs(x.im))
                {
                    auto s_im = s.im;
                    auto x_im = x.im;
                    s = s.re + x_im * 1fi;
                    x = x.re + s_im * 1fi;
                }
                F d = s - t;
                d += x;
                c += d;
                s = t;
            }
        }
        else
        static if (summation == Summation.kahan)
        {
            y = x - c;
            t = s + y;
            c = t - s;
            c -= y;
            s = t;
        }
        else
        static if (summation == Summation.pairwise)
        {
            import core.bitop : bsf;
            ++counter;
            partials[index] = n;
            foreach (_; 0 .. bsf(counter))
            {
                immutable newIndex = index - 1;
                partials[newIndex] += partials[index];
                index = newIndex;
            }
            ++index;
        }
        else
        static if (summation == Summation.naive)
        {
            s += n;
        }
        else
        static if (summation == Summation.fast)
        {
            s += n;
        }
        else
        static assert(0);
    }

    ///ditto
    void put(Range)(Range r)
        if (isInputRange!Range)
    {
        static if (summation == Summation.pairwise)
        {
            static if (fastPairwise && isRandomAccessRange!Range && hasLength!Range && hasSlicing!Range)
            {
                F[registersCount] v = void;
                foreach (i, n; chainSeq!registersCount)
                {
                    if (r.length >= n * 2) do
                    {
                        foreach (j; Iota!n)
                            v[j] = cast(F) r[j];
                        foreach (j; Iota!n)
                            v[j] += cast(F) r[n + j];
                        foreach (m; chainSeq!(n / 2))
                            foreach (j; Iota!m)
                                v[j] += v[m + j];
                        put(v[0]);
                        r.popFrontExactly(n * 2);
                    }
                    while (!i && r.length >= n * 2);
                }
                if (r.length)
                {
                    put(cast(F) r[0]);
                    r.popFront;
                }
                assert(r.empty);
            }
            else
            {
                for (; !r.empty; r.popFront)
                    put(r.front);
            }
        }
        else
        static if (summation == Summation.precise)
        {
            for (; !r.empty; r.popFront)
                put(r.front);
        }
        else
        static if (summation == Summation.kb2)
        {
            for (; !r.empty; r.popFront)
                put(r.front);
        }
        else
        static if (summation == Summation.kbn)
        {
            for (; !r.empty; r.popFront)
                put(r.front);
        }
        else
        static if (summation == Summation.kahan)
        {
            for (; !r.empty; r.popFront)
                put(r.front);
        }
        else        static if (summation == Summation.naive)
        {
            for (; !r.empty; r.popFront)
                s += r.front;
        }
        else
        static if (summation == Summation.fast)
        {
            for (; !r.empty; r.popFront)
                s += r.front;
        }
        else
        static assert(0);
    }

    /++
    Adds $(D x) to the internal partial sums.
    This operation doesn't re-establish special
    value semantics across iterations (i.e. handling -inf + inf).
    Preconditions: $(D isFinite(x)).
    +/
    version(none)
    static if (summation == Summation.precise)
    package void unsafePut(F x)
    in {
        assert(.isFinite(x));
    }
    body {
        size_t i;
        foreach (y; partials[])
        {
            F h = x + y;
            debug(numeric) assert(.isFinite(h));
            F l;
            if (fabs(x) < fabs(y))
            {
                F t = h - y;
                l = x - t;
            }
            else
            {
                F t = h - x;
                l = y - t;
            }
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

    ///Returns the value of the sum.
    T sum() const
    {
        /++
        Returns the value of the sum, rounded to the nearest representable
        floating-point number using the round-half-to-even rule.
        The result can differ from the exact value on $(D X86), $(D nextDown(proir) <= result &&  result <= nextUp(proir)).
        +/
        static if (summation == Summation.precise)
        {
            debug(sum)
            {
                foreach (y; partials[])
                {
                    assert(y);
                    assert(y.isFinite);
                }
                //TODO: Add Non-Overlapping check to std.math
                import std.algorithm.sorting: isSorted;
                import std.algorithm.iteration: map;
                assert(partials[].map!(a => fabs(a)).isSorted);
            }

            if (s)
                return s;
            auto parts = partials[];
            F y = 0.0;
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
                    F t = h - x;
                    F l = (y - t) * 2;
                    y = h * 2;
                    if (.isInfinity(cast(T)y))
                    {
                        // overflow, except in edge case...
                        x = h + l;
                        t = x - h;
                        y = parts.length && t == l && !signbit(l*parts[$-1]) ?
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
        else
        static if (summation == Summation.kb2)
        {
            import std.conv: to;
            return to!T(s + (cs + ccs));
        }
        else
        static if (summation == Summation.kbn)
        {
            import std.conv: to;
            return to!T(s + c);
        }
        else
        static if (summation == Summation.kahan)
        {
            import std.conv: to;
            return to!T(s);
        }
        else
        static if (summation == Summation.pairwise)
        {
            F s = summationInitValue!T;
            assert((counter == 0) == (index == 0));
            foreach_reverse (ref e; partials[0 .. index])
            {
                static if (is(F : __vector(W[N]), W, size_t N))
                    s += cast(Unqual!F) e; //DMD bug workaround
                else
                    s += e;
            }
            return s;
        }
        else
        static if (summation == Summation.naive)
        {
            return s;
        }
        else
        static if (summation == Summation.fast)
        {
            return s;
        }
        else
         static assert(0);
    }

    version(none)
    static if (summation == Summation.precise)
    F partialsSum() const
    {
        debug(numeric) partialsDebug;
        auto parts = partials[];
        F y = 0.0;
        //pick last
        if (parts.length)
        {
            y = parts[$-1];
            parts = parts[0..$-1];
        }
        return partialsReduce(y, parts);
    }

    ///Returns $(D Summator) with extended internal partial sums.
    C opCast(C : Summator!(P, _summation), P, Summation _summation)() const
        if (
            _summation == summation &&
            isMutable!C &&
            P.max_exp >= T.max_exp &&
            P.mant_dig >= T.mant_dig
        )
    {
        static if (is(P == T))
                return this;
        else
        static if (summation == Summation.precise)
        {
            typeof(return) ret = void;
            ret.s = s;
            ret.o = o;
            ret.partials = scopeBuffer(ret.scopeBufferArray);
            foreach (p; partials[])
            {
                ret.partials.put(p);
            }
            enum exp_diff = P.max_exp / T.max_exp;
            static if (exp_diff)
            {
                if (ret.o)
                {
                    immutable f = ret.o / exp_diff;
                    immutable t = cast(int)(ret.o % exp_diff);
                    ret.o = f;
                    ret.put((P(2) ^^ T.max_exp) * t);
                }
            }
            return ret;
        }
        else
        static if (summation == Summation.kb2)
        {
            typeof(return) ret = void;
            ret.s = s;
            ret.cs = cs;
            ret.ccs = ccs;
            return ret;
        }
        else
        static if (summation == Summation.kbn)
        {
            typeof(return) ret = void;
            ret.s = s;
            ret.c = c;
            return ret;
        }
        else
        static if (summation == Summation.kahan)
        {
            typeof(return) ret = void;
            ret.s = s;
            ret.c = c;
            return ret;
        }
        else
        static if (summation == Summation.pairwise)
        {
            typeof(return) ret = void;
            ret.counter = counter;
            ret.index = index;
            foreach (i; 0 .. index)
                ret.partials[i] = partials[i];
            return ret;
        }
        else
        static if (summation == Summation.naive)
        {
            typeof(return) ret = void;
            ret.s = s;
            return ret;
        }
        else
        static if (summation == Summation.fast)
        {
            typeof(return) ret = void;
            ret.s = s;
            return ret;
        }
        else
        static assert(0);
    }

    /++
    $(D cast(C)) operator overloading. Returns $(D cast(C)sum()).
    See also: $(D cast)
    +/
    C opCast(C)() const if (is(Unqual!C == T))
    {
        return cast(C)sum();
    }

    ///Operator overloading.
    // opAssign should initialize partials.
    void opAssign(T rhs)
    {
        static if (summation == Summation.precise)
        {
            partials.free;
            partials = scopeBuffer(scopeBufferArray);
            s = 0.0;
            o = 0;
            if (rhs) put(rhs);
        }
        else
        static if (summation == Summation.kb2)
        {
            s = rhs;
            static if (isComplex!T)
            {
                cs = 0 + 0fi;
                ccs = 0 + 0fi;
            }
            else
            {
                cs = 0.0;
                ccs = 0.0;
            }
        }
        else
        static if (summation == Summation.kbn)
        {
            s = rhs;
            static if (isComplex!T)
                c = 0 + 0fi;
            else
                c = 0.0;
        }
        else
        static if (summation == Summation.kahan)
        {
            s = rhs;
            static if (isComplex!T)
                c = 0 + 0fi;
            else
                c = 0.0;
        }
        else
        static if (summation == Summation.pairwise)
        {
            counter = 1;
            index = 1;
            partials[0] = rhs;
        }
        else
        static if (summation == Summation.naive)
        {
            s = rhs;
        }
        else
        static if (summation == Summation.fast)
        {
            s = rhs;
        }
        else
        static assert(0);
    }

    ///ditto
    void opOpAssign(string op : "+")(T rhs)
    {
        put(rhs);
    }

    ///ditto
    void opOpAssign(string op : "+")(ref const Summator rhs)
    {
        static if (summation == Summation.precise)
        {
            s += rhs.s;
            o += rhs.o;
            foreach (f; rhs.partials[])
                put(f);
        }
        else
        static if (summation == Summation.kb2)
        {
            put(rhs.ccs);
            put(rhs.cs);
            put(rhs.s);
        }
        else
        static if (summation == Summation.kbn)
        {
            put(rhs.c);
            put(rhs.s);
        }
        else
        static if (summation == Summation.kahan)
        {
            put(rhs.s);
        }
        else
        static if (summation == Summation.pairwise)
        {
            foreach_reverse (e; rhs.partials[0 .. rhs.index])
                put(e);
            counter -= rhs.index;
            counter += rhs.counter;
        }
        else
        static if (summation == Summation.naive)
        {
            put(rhs.s);
        }
        else
        static if (summation == Summation.fast)
        {
            put(rhs.s);
        }
        else
        static assert(0);
    }

    ///ditto
    void opOpAssign(string op : "-")(T rhs)
    {
        static if (summation == Summation.precise)
        {
            put(-rhs);
        }
        else
        static if (summation == Summation.kb2)
        {
            put(-rhs);
        }
        else
        static if (summation == Summation.kbn)
        {
            put(-rhs);
        }
        else
        static if (summation == Summation.kahan)
        {
            y = 0.0;
            y -= rhs;
            y -= c;
            t = s + y;
            c = t - s;
            c -= y;
            s = t;
        }
        else
        static if (summation == Summation.pairwise)
        {
            put(-rhs);
        }
        else
        static if (summation == Summation.naive)
        {
            s -= rhs;
        }
        else
        static if (summation == Summation.fast)
        {
            s -= rhs;
        }
        else
        static assert(0);
    }

    ///ditto
    void opOpAssign(string op : "-")(ref const Summator rhs)
    {
        static if (summation == Summation.precise)
        {
            s -= rhs.s;
            o -= rhs.o;
            foreach (f; rhs.partials[])
                put(-f);
        }
        else
        static if (summation == Summation.kb2)
        {
            put(-rhs.ccs);
            put(-rhs.cs);
            put(-rhs.s);
        }
        else
        static if (summation == Summation.kbn)
        {
            put(-rhs.c);
            put(-rhs.s);
        }
        else
        static if (summation == Summation.kahan)
        {
            this -= rhs.s;
        }
        else
        static if (summation == Summation.pairwise)
        {
            foreach_reverse (e; rhs.partials[0 .. rhs.index])
                put(-e);
            counter -= rhs.index;
            counter += rhs.counter;
        }
        else
        static if (summation == Summation.naive)
        {
            s -= rhs.s;
        }
        else
        static if (summation == Summation.fast)
        {
            s -= rhs.s;
        }
        else
        static assert(0);
    }

    ///
    @nogc nothrow unittest
    {
        import std.math, std.range;
        import std.algorithm.iteration: map;
        auto r1 = iota(500).map!(a => 1.7L.pow(a+1) - 1.7L.pow(a));
        auto r2 = iota(500, 1000).map!(a => 1.7L.pow(a+1) - 1.7L.pow(a));
        Summator!(real, Summation.precise) s1 = 0, s2 = 0.0;
        foreach (e; r1) s1 += e;
        foreach (e; r2) s2 -= e;
        s1 -= s2;
        s1 -= 1.7L.pow(1000);
        assert(s1.sum() == -1);
    }

    @nogc nothrow unittest
    {
        import std.typetuple;
        with(Summation)
        foreach (summation; TypeTuple!(kahan, kbn, kb2, precise, pairwise))
        foreach (T; TypeTuple!(float, double, real))
        {
            Summator!(T, summation) sum = 1;
            sum += 3;
            assert(sum.sum == 4);
            sum -= 10;
            assert(sum.sum == -6);
            Summator!(T, summation) sum2 = 3;
            sum -= sum2;
            assert(sum.sum == -9);
            sum2 = 100;
            sum += 100;
            assert(sum.sum == 91);
            auto sum3 = cast(Summator!(real, summation))sum;
            assert(sum3.sum == 91);
            sum = sum2;
        }
    }

    @nogc nothrow unittest
    {
        import std.typetuple;
        import std.math: approxEqual;
        with(Summation)
        foreach (summation; TypeTuple!(naive, fast))
        foreach (T; TypeTuple!(float, double, real))
        {
            Summator!(T, summation) sum = 1;
            sum += 3.5;
            assert(sum.sum.approxEqual(4.5));
            sum = 2;
            assert(sum.sum == 2);
            sum -= 4;
            assert(sum.sum.approxEqual(-2));
        }
    }

    static if (summation == Summation.precise)
    {
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
    else static if (isFloatingPoint!F)
    {
        ///Returns $(D true) if current sum is a NaN.
        bool isNaN() const
        {
            return .isNaN(sum());
        }

        ///Returns $(D true) if current sum is finite (not infinite or NaN).
        bool isFinite() const
        {
            return cast(bool).isFinite(sum());
        }

        ///Returns $(D true) if current sum is ±∞.
        bool isInfinity() const
        {
            return .isInfinity(sum());
        }
    }
    else
    {
        //User defined types
    }
}

unittest
{
    import std.algorithm.iteration: map;
    import std.range: iota, retro;
    import std.array: array;

    Summator!(double, Summation.precise) summator = 0.0;

    enum double M = (cast(double)2) ^^ (double.max_exp - 1);
    Tuple!(double[], double)[] tests = [
        tuple(new double[0], 0.0),
        tuple([0.0], 0.0),
        tuple([1e100, 1.0, -1e100, 1e-100, 1e50, -1, -1e50], 1e-100),
        tuple([1e308, 1e308, -1e308], 1e308),
        tuple([-1e308, 1e308, 1e308], 1e308),
        tuple([1e308, -1e308, 1e308], 1e308),
        tuple([M, M, -2.0^^1000], 1.7976930277114552e+308),
        tuple([M, M, M, M, -M, -M, -M], 8.9884656743115795e+307),
        tuple([2.0^^53, -0.5, -2.0^^-54], 2.0^^53-1.0),
        tuple([2.0^^53, 1.0, 2.0^^-100], 2.0^^53+2.0),
        tuple([2.0^^53+10.0, 1.0, 2.0^^-100], 2.0^^53+12.0),
        tuple([2.0^^53-4.0, 0.5, 2.0^^-54], 2.0^^53-3.0),
        tuple([M-2.0^^970, -1, M], 1.7976931348623157e+308),
        tuple([double.max, double.max*2.^^-54], double.max),
        tuple([double.max, double.max*2.^^-53], double.infinity),
        tuple(iota(1, 1001).map!(a => 1.0/a).array , 7.4854708605503451),
        tuple(iota(1, 1001).map!(a => (-1.0)^^a/a).array, -0.69264743055982025), //0.693147180559945309417232121458176568075500134360255254120680...
        tuple(iota(1, 1001).map!(a => 1.0/a).retro.array , 7.4854708605503451),
        tuple(iota(1, 1001).map!(a => (-1.0)^^a/a).retro.array, -0.69264743055982025),
        tuple([double.infinity, -double.infinity, double.nan], double.nan),
        tuple([double.nan, double.infinity, -double.infinity], double.nan),
        tuple([double.infinity, double.nan, double.infinity], double.nan),
        tuple([double.infinity, double.infinity], double.infinity),
        tuple([double.infinity, -double.infinity], double.nan),
        tuple([-double.infinity, 1e308, 1e308, -double.infinity], -double.infinity),
        tuple([M-2.0^^970, 0.0, M], double.infinity),
        tuple([M-2.0^^970, 1.0, M], double.infinity),
        tuple([M, M], double.infinity),
        tuple([M, M, -1], double.infinity),
        tuple([M, M, M, M, -M, -M], double.infinity),
        tuple([M, M, M, M, -M, M], double.infinity),
        tuple([-M, -M, -M, -M], -double.infinity),
        tuple([M, M, -2.^^971], double.max),
        tuple([M, M, -2.^^970], double.infinity),
        tuple([-2.^^970, M, M, -0X0.0000000000001P-0 * 2.^^-1022], double.max),
        tuple([M, M, -2.^^970, 0X0.0000000000001P-0 * 2.^^-1022], double.infinity),
        tuple([-M, 2.^^971, -M], -double.max),
        tuple([-M, -M, 2.^^970], -double.infinity),
        tuple([-M, -M, 2.^^970, 0X0.0000000000001P-0 * 2.^^-1022], -double.max),
        tuple([-0X0.0000000000001P-0 * 2.^^-1022, -M, -M, 2.^^970], -double.infinity),
        tuple([2.^^930, -2.^^980, M, M, M, -M], 1.7976931348622137e+308),
        tuple([M, M, -1e307], 1.6976931348623159e+308),
        tuple([1e16, 1., 1e-16], 10_000_000_000_000_002.0),
    ];
    foreach (i, test; tests)
    {
        summator = 0.0;
        foreach (t; test[0]) summator.put(t);
        auto r = test[1];
        auto s = summator.sum;
        assert(summator.isNaN() == r.isNaN());
        assert(summator.isFinite() == r.isFinite());
        assert(summator.isInfinity() == r.isInfinity());
        assert(s == r || s.isNaN && r.isNaN);
    }
}

/**
Sums elements of $(D r), which must be a finite
$(XREF_PACK_NAMED range,primitives,isInputRange,input range). Although
conceptually $(D sum(r)) is equivalent to $(LREF reduce)!((a, b) => a +
b)(0, r), $(D sum) uses specialized algorithms to maximize accuracy.

A seed may be passed to $(D sum). Not only will this seed be used as an initial
value, but its type will be used if it is not specified.

Note that these specialized summing algorithms execute more primitive operations
than vanilla summation. Therefore, if in certain cases maximum speed is required
at expense of precision, one can use $(XREF, numeric_summation, Summation.fast).

Returns:
    The sum of all the elements in the range r.

See_Also: $(XREFMODULE, numeric_summation) contains detailed documentation and examples about available summation algorithms.
 */
template sum(F, Summation summation = Summation.appropriate)
    if (isFloatingPoint!F && isMutable!F)
{
    template sum(Range)
    {
        F sum(Range r)
        {
            return SummationAlgo!(summation, Range, F)(r);
        }

        F sum(Range r, F seed)
        {
            return SummationAlgo!(summation, Range, F)(r, seed);
        }
    }
}

///ditto
template sum(Summation summation = Summation.appropriate)
{
    auto sum(Range)(Range r)
    {
        return SummationAlgo!(summation, Range, sumType!Range)(r);
    }

    F sum(Range, F)(Range r, F seed)
    {
        return SummationAlgo!(summation, Range, F)(r, seed);
    }
}


@safe pure nothrow unittest
{
    static assert(is(typeof(sum([cast( byte)1])) ==  int));
    static assert(is(typeof(sum([cast(ubyte)1])) ==  int));
    static assert(is(typeof(sum([  1,   2,   3,   4])) ==  int));
    static assert(is(typeof(sum([ 1U,  2U,  3U,  4U])) == uint));
    static assert(is(typeof(sum([ 1L,  2L,  3L,  4L])) ==  long));
    static assert(is(typeof(sum([1UL, 2UL, 3UL, 4UL])) == ulong));

    int[] empty;
    assert(sum(empty) == 0);
    assert(sum([42]) == 42);
    assert(sum([42, 43]) == 42 + 43);
    assert(sum([42, 43, 44]) == 42 + 43 + 44);
    assert(sum([42, 43, 44, 45]) == 42 + 43 + 44 + 45);
}

@safe pure nothrow unittest
{
    static assert(is(typeof(sum([1.0, 2.0, 3.0, 4.0])) == double));
    static assert(is(typeof(sum!double([ 1F,  2F,  3F,  4F])) == double));
    const(float[]) a = [1F, 2F, 3F, 4F];
    static assert(is(typeof(sum!double(a)) == double));
    const(float)[] b = [1F, 2F, 3F, 4F];
    static assert(is(typeof(sum!double(a)) == double));

    double[] empty;
    assert(sum(empty) == 0);
    assert(sum([42.]) == 42);
    assert(sum([42., 43.]) == 42 + 43);
    assert(sum([42., 43., 44.]) == 42 + 43 + 44);
    assert(sum([42., 43., 44., 45.5]) == 42 + 43 + 44 + 45.5);
}

@safe pure nothrow unittest
{
    import std.container;
    static assert(is(typeof(sum!double(SList!float()[])) == double));
    static assert(is(typeof(sum(SList!double()[])) == double));
    static assert(is(typeof(sum(SList!real()[])) == real));

    assert(sum(SList!double()[]) == 0);
    assert(sum(SList!double(1)[]) == 1);
    assert(sum(SList!double(1, 2)[]) == 1 + 2);
    assert(sum(SList!double(1, 2, 3)[]) == 1 + 2 + 3);
    assert(sum(SList!double(1, 2, 3, 4)[]) == 10);
}

@safe pure nothrow unittest // 12434
{
    import std.algorithm.iteration: map;
    immutable a = [10, 20];
    auto s1 = sum(a);             // Error
    auto s2 = a.map!(x => x).sum; // Error
}

unittest
{
    import std.bigint;
    import std.range;

    immutable BigInt[] a = BigInt("1_000_000_000_000_000_000").repeat(10).array();
    immutable ulong[]  b = (ulong.max/2).repeat(10).array();
    auto sa = a.sum();
    auto sb = b.sum(BigInt(0)); //reduce ulongs into bigint
    assert(sa == BigInt("10_000_000_000_000_000_000"));
    assert(sb == (BigInt(ulong.max/2) * 10));
}

unittest
{
    import std.typetuple;
    with(Summation)
    foreach (F; TypeTuple!(float, double, real))
    {
        F[] ar = [1, 2, 3, 4];
        F r = 10;
        assert(r == ar.sum!fast());
        assert(r == ar.sum!pairwise());
        assert(r == ar.sum!kahan());
        assert(r == ar.sum!kbn());
        assert(r == ar.sum!kb2());
    }
}

version(LDC)
version(X86_Any)
unittest
{
    import core.simd;
    static if (__traits(compiles, double2.init + double2.init))
    {

        alias S = Summation;
        alias sums = AliasSeq!(S.kahan, S.pairwise, S.naive, S.fast);

        double2[] ar = [double2([1.0, 2]), double2([2, 3]), double2([3, 4]), double2([4, 6])];
        double2 c = double2([10, 15]);

        foreach (sumType; sums)
        {
            double2 s = ar.sum!(sumType);
            assert(s.array == c.array);
        }
    }
}

version(LDC)
version(X86_Any)
unittest
{
    import core.simd;
    import std.range: iota;
    import std.array: array;


    alias S = Summation;
    alias sums = AliasSeq!(S.kahan, S.pairwise, S.naive, S.fast, S.precise,
                           S.kbn, S.kb2);

    double[] ns = [9.0, 101.0];

    foreach (n; ns)
    {
        foreach (sumType; sums)
        {
            double[] ar = iota(n).array;
            double c = n * (n - 1) / 2; // gauss for n=100
            double s = ar.sum!(sumType);
            assert(s == c);
        }
    }
}

/++
Precise summation.
+/
private F sumPrecise(Range, F)(Range r, F seed = summationInitValue!F)
    if (isFloatingPoint!F || isComplex!F)
{
    static if (isFloatingPoint!F)
    {
        auto sum = Summator!(F, Summation.precise)(seed);
        for (; !r.empty; r.popFront)
        {
            sum.put(r.front);
        }
        return sum.sum;
    }
    else
    {
        alias T = typeof(F.init.re);
        auto sumRe = Summator!(T, Summation.precise)(seed.re);
        auto sumIm = Summator!(T, Summation.precise)(seed.im);
        for (; !r.empty; r.popFront)
        {
            auto e = r.front;
            sumRe.put(e.re);
            sumIm.put(e.im);
        }
        return sumRe.sum + sumIm.sum * 1fi;
    }
}

private template SummationAlgo(Summation summation, Range, F)
{
    static if (summation == Summation.precise)
        alias SummationAlgo = sumPrecise!(Range, F);
    else
    static if (summation == Summation.appropriate)
    {
        static if (isSummable!(Range, F))
            alias SummationAlgo = SummationAlgo!(Summation.pairwise, Range, F);
        else
        static if (is(F == class) || is(F == struct) || is(F == interface))
            alias SummationAlgo = SummationAlgo!(Summation.naive, Range, F);
        else
            alias SummationAlgo = SummationAlgo!(Summation.fast, Range, F);
    }
    else
    {
        F SummationAlgo(Range r)
        {
            static if (__traits(compiles, {Summator!(F, summation) sum;}))
                Summator!(F, summation) sum;
            else
                auto sum = Summator!(F, summation)(summationInitValue!F);
            sum.put(r);
            return sum.sum;
        }

        F SummationAlgo(Range r, F s)
        {
            auto sum = Summator!(F, summation)(s);
            sum.put(r);
            return sum.sum;
        }
    }
}

private T summationInitValue(T)()
{
    static if (__traits(compiles, {T a = 0.0;}))
    {
        T a = 0.0;
        return a;
    }
    else
    static if (__traits(compiles, {T a = 0;}))
    {
        T a = 0;
        return a;
    }
    else
    static if (__traits(compiles, {T a = 0 + 0fi;}))
    {
        T a = 0 + 0fi;
        return a;
    }
    else
    {
        return T.init;
    }
}

private template sumType(Range)
{
    alias T = Unqual!(ElementType!Range);
    alias sumType = typeof(T.init + T.init);
}

package:

template isSummable(F)
{
    enum bool isSummable =
        __traits(compiles,
        {
            F a = 0.1, b, c;
            b = 2.3;
            c = a + b;
            c = a - b;
            a += b;
            a -= b;
        });
}

template isSummable(Range, F)
{
    enum bool isSummable =
        isInputRange!Range &&
        isImplicitlyConvertible!(Unqual!(ElementType!Range), F) &&
        !isInfinite!Range &&
        isSummable!F;
}

unittest
{
    import std.range: iota;
    static assert(isSummable!(typeof(iota(ulong.init, ulong.init, ulong.init)), double));
}

private enum bool isCompesatorAlgorithm(Summation summation) =
    summation == Summation.precise
 || summation == Summation.kb2
 || summation == Summation.kbn
 || summation == Summation.kahan;
