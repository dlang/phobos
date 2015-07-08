// Written in the D programming language

/**
 * Implements algorithms for generating random numbers drawn from
 * different probability distributions.
 *
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Source:    $(PHOBOSSRC std/random/_distribution.d)
 */
module std.random.distribution;

import std.random.traits;
import std.range.primitives;
import std.traits;

/**
Rolls a dice with relative probabilities stored in $(D
proportions). Returns the index in $(D proportions) that was chosen.

Params:
    rnd = (optional) random number generator to use; if not
          specified, defaults to $(D rndGen)
    proportions = forward range or list of individual values
                  whose elements correspond to the probabilities
                  with which to choose the corresponding index
                  value

Returns:
    Random variate drawn from the index values
    [0, ... $(D proportions.length) - 1], with the probability
    of getting an individual index value $(D i) being proportional to
    $(D proportions[i]).

Example:

----
auto x = dice(0.5, 0.5);   // x is 0 or 1 in equal proportions
auto y = dice(50, 50);     // y is 0 or 1 in equal proportions
auto z = dice(70, 20, 10); // z is 0 70% of the time, 1 20% of the time,
                           // and 2 10% of the time
----
*/
size_t dice(Rng, Num)(ref Rng rnd, Num[] proportions...)
if (isNumeric!Num && isForwardRange!Rng)
{
    return diceImpl(rnd, proportions);
}

/// Ditto
size_t dice(R, Range)(ref R rnd, Range proportions)
if (isForwardRange!Range && isNumeric!(ElementType!Range) && !isArray!Range)
{
    return diceImpl(rnd, proportions);
}

/// Ditto
size_t dice(Range)(Range proportions)
if (isForwardRange!Range && isNumeric!(ElementType!Range) && !isArray!Range)
{
    return diceImpl(rndGen, proportions);
}

/// Ditto
size_t dice(Num)(Num[] proportions...)
if (isNumeric!Num)
{
    import std.random.engine : rndGen;
    return diceImpl(rndGen, proportions);
}

private size_t diceImpl(Rng, Range)(ref Rng rng, Range proportions)
    if (isForwardRange!Range && isNumeric!(ElementType!Range) && isForwardRange!Rng)
in
{
    import std.algorithm : all;
    assert(proportions.save.all!"a >= 0");
}
body
{
    import std.exception : enforce;
    import std.algorithm : reduce;
    double sum = reduce!"a + b"(0.0, proportions.save);
    enforce(sum > 0, "Proportions in a dice cannot sum to zero");
    immutable point = uniform(0.0, sum, rng);
    assert(point < sum);
    auto mass = 0.0;

    size_t i = 0;
    foreach (e; proportions)
    {
        mass += e;
        if (point < mass) return i;
        i++;
    }
    // this point should not be reached
    assert(false);
}

unittest
{
    import std.random.device : unpredictableSeed;
    import std.random.engine : Random;
    auto rnd = Random(unpredictableSeed);
    auto i = dice(rnd, 0.0, 100.0);
    assert(i == 1);
    i = dice(rnd, 100.0, 0.0);
    assert(i == 0);

    i = dice(100U, 0U);
    assert(i == 0);
}

/**
Generates a number between $(D a) and $(D b). The $(D boundaries)
parameter controls the shape of the interval (open vs. closed on
either side). Valid values for $(D boundaries) are $(D "[]"), $(D
"$(LPAREN)]"), $(D "[$(RPAREN)"), and $(D "()"). The default interval
is closed to the left and open to the right. The version that does not
take $(D urng) uses the default generator $(D rndGen).

Params:
    a = lower bound of the _uniform distribution
    b = upper bound of the _uniform distribution
    urng = (optional) random number generator to use;
           if not specified, defaults to $(D rndGen)

Returns:
    A single random variate drawn from the _uniform distribution
    between $(D a) and $(D b), whose type is the common type of
    these parameters

Example:

----
auto gen = Random(unpredictableSeed);
// Generate an integer in [0, 1023]
auto a = uniform(0, 1024, gen);
// Generate a float in [0, 1$(RPAREN)
auto a = uniform(0.0f, 1.0f, gen);
----
 */
auto uniform(string boundaries = "[)", T1, T2)
(T1 a, T2 b)  if (!is(CommonType!(T1, T2) == void))
{
    import std.random.engine : Random, rndGen;
    return uniform!(boundaries, T1, T2, Random)(a, b, rndGen);
}

@safe unittest
{
    import std.random.engine: MinstdRand0;
    MinstdRand0 gen;
    foreach (i; 0 .. 20)
    {
        auto x = uniform(0.0, 15.0, gen);
        assert(0 <= x && x < 15);
    }
    foreach (i; 0 .. 20)
    {
        auto x = uniform!"[]"('a', 'z', gen);
        assert('a' <= x && x <= 'z');
    }

    foreach (i; 0 .. 20)
    {
        auto x = uniform('a', 'z', gen);
        assert('a' <= x && x < 'z');
    }

    foreach(i; 0 .. 20)
    {
        immutable ubyte a = 0;
            immutable ubyte b = 15;
        auto x = uniform(a, b, gen);
            assert(a <= x && x < b);
    }
}

// Implementation of uniform for floating-point types
/// ditto
auto uniform(string boundaries = "[)",
        T1, T2, UniformRandomNumberGenerator)
(T1 a, T2 b, ref UniformRandomNumberGenerator urng)
if (isFloatingPoint!(CommonType!(T1, T2)) && isUniformRNG!UniformRandomNumberGenerator)
{
    import std.exception : enforce;
    import std.conv : text;
    alias NumberType = Unqual!(CommonType!(T1, T2));
    static if (boundaries[0] == '(')
    {
        import std.math : nextafter;
        NumberType _a = nextafter(cast(NumberType) a, NumberType.infinity);
    }
    else
    {
        NumberType _a = a;
    }
    static if (boundaries[1] == ')')
    {
        import std.math : nextafter;
        NumberType _b = nextafter(cast(NumberType) b, -NumberType.infinity);
    }
    else
    {
        NumberType _b = b;
    }
    enforce(_a <= _b,
            text("std.random.distribution.uniform(): invalid bounding interval ",
                    boundaries[0], a, ", ", b, boundaries[1]));
    NumberType result =
        _a + (_b - _a) * cast(NumberType) (urng.front - urng.min)
        / (urng.max - urng.min);
    urng.popFront();
    return result;
}

// Implementation of uniform for integral types
/+ Description of algorithm and suggestion of correctness:

The modulus operator maps an integer to a small, finite space. For instance, `x
% 3` will map whatever x is into the range [0 .. 3). 0 maps to 0, 1 maps to 1, 2
maps to 2, 3 maps to 0, and so on infinitely. As long as the integer is
uniformly chosen from the infinite space of all non-negative integers then `x %
3` will uniformly fall into that range.

(Non-negative is important in this case because some definitions of modulus,
namely the one used in computers generally, map negative numbers differently to
(-3 .. 0]. `uniform` does not use negative number modulus, thus we can safely
ignore that fact.)

The issue with computers is that integers have a finite space they must fit in,
and our uniformly chosen random number is picked in that finite space. So, that
method is not sufficient. You can look at it as the integer space being divided
into "buckets" and every bucket after the first bucket maps directly into that
first bucket. `[0, 1, 2]`, `[3, 4, 5]`, ... When integers are finite, then the
last bucket has the chance to be "incomplete": `[uint.max - 3, uint.max - 2,
uint.max - 1]`, `[uint.max]` ... (the last bucket only has 1!). The issue here
is that _every_ bucket maps _completely_ to the first bucket except for that
last one. The last one doesn't have corresponding mappings to 1 or 2, in this
case, which makes it unfair.

So, the answer is to simply "reroll" if you're in that last bucket, since it's
the only unfair one. Eventually you'll roll into a fair bucket. Simply, instead
of the meaning of the last bucket being "maps to `[0]`", it changes to "maps to
`[0, 1, 2]`", which is precisely what we want.

To generalize, `upperDist` represents the size of our buckets (and, thus, the
exclusive upper bound for our desired uniform number). `rnum` is a uniformly
random number picked from the space of integers that a computer can hold (we'll
say `UpperType` represents that type).

We'll first try to do the mapping into the first bucket by doing `offset = rnum
% upperDist`. We can figure out the position of the front of the bucket we're in
by `bucketFront = rnum - offset`.

If we start at `UpperType.max` and walk backwards `upperDist - 1` spaces, then
the space we land on is the last acceptable position where a full bucket can
fit:

```
   bucketFront     UpperType.max
      v                 v
[..., 0, 1, 2, ..., upperDist - 1]
      ^~~ upperDist - 1 ~~^
```

If the bucket starts any later, then it must have lost at least one number and
at least that number won't be represented fairly.

```
                bucketFront     UpperType.max
                     v                v
[..., upperDist - 1, 0, 1, 2, ..., upperDist - 2]
          ^~~~~~~~ upperDist - 1 ~~~~~~~^
```

Hence, our condition to reroll is
`bucketFront > (UpperType.max - (upperDist - 1))`
+/
auto uniform(string boundaries = "[)", T1, T2, RandomGen)
(T1 a, T2 b, ref RandomGen rng)
if ((isIntegral!(CommonType!(T1, T2)) || isSomeChar!(CommonType!(T1, T2))) &&
     isUniformRNG!RandomGen)
{
    import std.exception : enforce;
    import std.conv : text, unsigned;
    alias ResultType = Unqual!(CommonType!(T1, T2));
    static if (boundaries[0] == '(')
    {
        enforce(a < ResultType.max,
                text("std.random.distribution.uniform(): invalid left bound ", a));
        ResultType lower = cast(ResultType) (a + 1);
    }
    else
    {
        ResultType lower = a;
    }

    static if (boundaries[1] == ']')
    {
        enforce(lower <= b,
                text("std.random.distribution.uniform(): invalid bounding interval ",
                        boundaries[0], a, ", ", b, boundaries[1]));
        /* Cannot use this next optimization with dchar, as dchar
         * only partially uses its full bit range
         */
        static if (!is(ResultType == dchar))
        {
            if (b == ResultType.max && lower == ResultType.min)
            {
                // Special case - all bits are occupied
                return std.random.distribution.uniform!ResultType(rng);
            }
        }
        auto upperDist = unsigned(b - lower) + 1u;
    }
    else
    {
        enforce(lower < b,
                text("std.random.distribution.uniform(): invalid bounding interval ",
                        boundaries[0], a, ", ", b, boundaries[1]));
        auto upperDist = unsigned(b - lower);
    }

    assert(upperDist != 0);

    alias UpperType = typeof(upperDist);
    static assert(UpperType.min == 0);

    UpperType offset, rnum, bucketFront;
    do
    {
        rnum = uniform!UpperType(rng);
        offset = rnum % upperDist;
        bucketFront = rnum - offset;
    } // while we're in an unfair bucket...
    while (bucketFront > (UpperType.max - (upperDist - 1)));

    return cast(ResultType)(lower + offset);
}

@safe unittest
{
    import std.conv : to;
    import std.random.device : unpredictableSeed;
    import std.random.engine : Mt19937, Xorshift;
    auto gen = Mt19937(unpredictableSeed);
    static assert(isForwardRange!(typeof(gen)));

    auto a = uniform(0, 1024, gen);
    assert(0 <= a && a <= 1024);
    auto b = uniform(0.0f, 1.0f, gen);
    assert(0 <= b && b < 1, to!string(b));
    auto c = uniform(0.0, 1.0);
    assert(0 <= c && c < 1);

    foreach (T; std.typetuple.TypeTuple!(char, wchar, dchar, byte, ubyte, short, ushort,
                          int, uint, long, ulong, float, double, real))
    {
        T lo = 0, hi = 100;

        // Try tests with each of the possible bounds
        {
            T init = uniform(lo, hi);
            size_t i = 50;
            while (--i && uniform(lo, hi) == init) {}
            assert(i > 0);
        }
        {
            T init = uniform!"[)"(lo, hi);
            size_t i = 50;
            while (--i && uniform(lo, hi) == init) {}
            assert(i > 0);
        }
        {
            T init = uniform!"(]"(lo, hi);
            size_t i = 50;
            while (--i && uniform(lo, hi) == init) {}
            assert(i > 0);
        }
        {
            T init = uniform!"()"(lo, hi);
            size_t i = 50;
            while (--i && uniform(lo, hi) == init) {}
            assert(i > 0);
        }
        {
            T init = uniform!"[]"(lo, hi);
            size_t i = 50;
            while (--i && uniform(lo, hi) == init) {}
            assert(i > 0);
        }

        /* Test case with closed boundaries covering whole range
         * of integral type
         */
        static if (isIntegral!T || isSomeChar!T)
        {
            foreach (immutable _; 0 .. 100)
            {
                auto u = uniform!"[]"(T.min, T.max);
                static assert(is(typeof(u) == T));
                assert(T.min <= u, "Lower bound violation for uniform!\"[]\" with " ~ T.stringof);
                assert(u <= T.max, "Upper bound violation for uniform!\"[]\" with " ~ T.stringof);
            }
        }
    }

    auto reproRng = Xorshift(239842);

    foreach (T; std.typetuple.TypeTuple!(char, wchar, dchar, byte, ubyte, short,
                          ushort, int, uint, long, ulong))
    {
        T lo = T.min + 10, hi = T.max - 10;
        T init = uniform(lo, hi, reproRng);
        size_t i = 50;
        while (--i && uniform(lo, hi, reproRng) == init) {}
        assert(i > 0);
    }

    {
        bool sawLB = false, sawUB = false;
        foreach (i; 0 .. 50)
        {
            auto x = uniform!"[]"('a', 'd', reproRng);
            if (x == 'a') sawLB = true;
            if (x == 'd') sawUB = true;
            assert('a' <= x && x <= 'd');
        }
        assert(sawLB && sawUB);
    }

    {
        bool sawLB = false, sawUB = false;
        foreach (i; 0 .. 50)
        {
            auto x = uniform('a', 'd', reproRng);
            if (x == 'a') sawLB = true;
            if (x == 'c') sawUB = true;
            assert('a' <= x && x < 'd');
        }
        assert(sawLB && sawUB);
    }

    {
        bool sawLB = false, sawUB = false;
        foreach (i; 0 .. 50)
        {
            immutable int lo = -2, hi = 2;
            auto x = uniform!"()"(lo, hi, reproRng);
            if (x == (lo+1)) sawLB = true;
            if (x == (hi-1)) sawUB = true;
            assert(lo < x && x < hi);
        }
        assert(sawLB && sawUB);
    }

    {
        bool sawLB = false, sawUB = false;
        foreach (i; 0 .. 50)
        {
            immutable ubyte lo = 0, hi = 5;
            auto x = uniform(lo, hi, reproRng);
            if (x == lo) sawLB = true;
            if (x == (hi-1)) sawUB = true;
            assert(lo <= x && x < hi);
        }
        assert(sawLB && sawUB);
    }

    {
        foreach (i; 0 .. 30)
        {
            assert(i == uniform(i, i+1, reproRng));
        }
    }
}

/**
Generates a uniformly-distributed number in the range $(D [T.min,
T.max]) for any integral or character type $(D T). If no random
number generator is passed, uses the default $(D rndGen).

Params:
    urng = (optional) random number generator to use;
           if not specified, defaults to $(D rndGen)

Returns:
    Random variate drawn from the _uniform distribution across all
    possible values of the integral or character type $(D T).
 */
auto uniform(T, UniformRandomNumberGenerator)
(ref UniformRandomNumberGenerator urng)
if (!is(T == enum) && (isIntegral!T || isSomeChar!T) && isUniformRNG!UniformRandomNumberGenerator)
{
    /* dchar does not use its full bit range, so we must
     * revert to the uniform with specified bounds
     */
    static if (is(T == dchar))
    {
        return uniform!"[]"(T.min, T.max);
    }
    else
    {
        auto r = urng.front;
        urng.popFront();
        static if (T.sizeof <= r.sizeof)
        {
            return cast(T) r;
        }
        else
        {
            static assert(T.sizeof == 8 && r.sizeof == 4);
            T r1 = urng.front | (cast(T)r << 32);
            urng.popFront();
            return r1;
        }
    }
}

/// Ditto
auto uniform(T)()
if (!is(T == enum) && (isIntegral!T || isSomeChar!T))
{
    import std.random.engine : rndGen;
    return uniform!T(rndGen);
}

@safe unittest
{
    foreach(T; std.typetuple.TypeTuple!(char, wchar, dchar, byte, ubyte, short, ushort,
                          int, uint, long, ulong))
    {
        T init = uniform!T();
        size_t i = 50;
        while (--i && uniform!T() == init) {}
        assert(i > 0);

        foreach (immutable _; 0 .. 100)
        {
            auto u = uniform!T();
            static assert(is(typeof(u) == T));
            assert(T.min <= u, "Lower bound violation for uniform!" ~ T.stringof);
            assert(u <= T.max, "Upper bound violation for uniform!" ~ T.stringof);
        }
    }
}

/**
Returns a uniformly selected member of enum $(D E). If no random number
generator is passed, uses the default $(D rndGen).

Params:
    urng = (optional) random number generator to use;
           if not specified, defaults to $(D rndGen)

Returns:
    Random variate drawn with equal probability from any
    of the possible values of the enum $(D E).
 */
auto uniform(E, UniformRandomNumberGenerator)
(ref UniformRandomNumberGenerator urng)
if (is(E == enum) && isUniformRNG!UniformRandomNumberGenerator)
{
    static immutable E[EnumMembers!E.length] members = [EnumMembers!E];
    return members[std.random.distribution.uniform(0, members.length, urng)];
}

/// Ditto
auto uniform(E)()
if (is(E == enum))
{
    import std.random.engine : rndGen;
    return uniform!E(rndGen);
}

///
@safe unittest
{
    enum Fruit { apple, mango, pear }
    auto randFruit = uniform!Fruit();
}

@safe unittest
{
    import std.random.engine : rndGen;
    enum Fruit { Apple = 12, Mango = 29, Pear = 72 }
    foreach (_; 0 .. 100)
    {
        foreach(f; [uniform!Fruit(), rndGen.uniform!Fruit()])
        {
            assert(f == Fruit.Apple || f == Fruit.Mango || f == Fruit.Pear);
        }
    }
}

/**
 * Generates a uniformly-distributed floating point number of type
 * $(D T) in the range [0, 1$(RPAREN).  If no random number generator is
 * specified, the default RNG $(D rndGen) will be used as the source
 * of randomness.
 *
 * $(D uniform01) offers a faster generation of random variates than
 * the equivalent $(D uniform!"[$(RPAREN)"(0.0, 1.0)) and so may be preferred
 * for some applications.
 *
 * Params:
 *     urng = (optional) random number generator to use;
 *            if not specified, defaults to $(D rndGen)
 *
 * Returns:
 *     Floating-point random variate of type $(D T) drawn from the _uniform
 *     distribution across the half-open interval [0, 1$(RPAREN).
 *
 */
T uniform01(T = double)()
    if (isFloatingPoint!T)
{
    import std.random.engine : rndGen;
    return uniform01!T(rndGen);
}

/// ditto
T uniform01(T = double, UniformRNG)(ref UniformRNG rng)
    if (isFloatingPoint!T && isUniformRNG!UniformRNG)
out (result)
{
    assert(0 <= result);
    assert(result < 1);
}
body
{
    alias R = typeof(rng.front);
    static if (isIntegral!R)
    {
        enum T factor = 1 / (T(1) + rng.max - rng.min);
    }
    else static if (isFloatingPoint!R)
    {
        enum T factor = 1 / (rng.max - rng.min);
    }
    else
    {
        static assert(false);
    }

    while (true)
    {
        immutable T u = (rng.front - rng.min) * factor;
        rng.popFront();

        import core.stdc.limits : CHAR_BIT;  // CHAR_BIT is always 8
        static if (isIntegral!R && T.mant_dig >= (CHAR_BIT * R.sizeof))
        {
            /* If RNG variates are integral and T has enough precision to hold
             * R without loss, we're guaranteed by the definition of factor
             * that precisely u < 1.
             */
            return u;
        }
        else
        {
            /* Otherwise we have to check whether u is beyond the assumed range
             * because of the loss of precision, or for another reason, a
             * floating-point RNG can return a variate that is exactly equal to
             * its maximum.
             */
            if (u < 1)
            {
                return u;
            }
        }
    }

    // Shouldn't ever get here.
    assert(false);
}

@safe unittest
{
    import std.random.device : unpredictableSeed;
    import std.random.engine : PseudoRngTypes;
    import std.typetuple;
    foreach (UniformRNG; PseudoRngTypes)
    {

        foreach (T; std.typetuple.TypeTuple!(float, double, real))
        (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
            UniformRNG rng = UniformRNG(unpredictableSeed);

            auto a = uniform01();
            assert(is(typeof(a) == double));
            assert(0 <= a && a < 1);

            auto b = uniform01(rng);
            assert(is(typeof(a) == double));
            assert(0 <= b && b < 1);

            auto c = uniform01!T();
            assert(is(typeof(c) == T));
            assert(0 <= c && c < 1);

            auto d = uniform01!T(rng);
            assert(is(typeof(d) == T));
            assert(0 <= d && d < 1);

            T init = uniform01!T(rng);
            size_t i = 50;
            while (--i && uniform01!T(rng) == init) {}
            assert(i > 0);
            assert(i < 50);
        }();
    }
}

/**
Generates a uniform probability distribution of size $(D n), i.e., an
array of size $(D n) of positive numbers of type $(D F) that sum to
$(D 1). If $(D useThis) is provided, it is used as storage.
 */
F[] uniformDistribution(F = double)(size_t n, F[] useThis = null)
    if(isFloatingPoint!F)
{
    import std.numeric : normalize;
    useThis.length = n;
    foreach (ref e; useThis)
    {
        e = uniform(0.0, 1);
    }
    normalize(useThis);
    return useThis;
}

@safe unittest
{
    import std.math;
    import std.algorithm;
    static assert(is(CommonType!(double, int) == double));
    auto a = uniformDistribution(5);
    assert(a.length == 5);
    assert(approxEqual(reduce!"a + b"(a), 1));
    a = uniformDistribution(10, a);
    assert(a.length == 10);
    assert(approxEqual(reduce!"a + b"(a), 1));
}

