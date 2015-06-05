// Written in the D programming language.

/**
Facilities for random number generation.

The new-style generator objects hold their own state so they are
immune of threading issues. The generators feature a number of
well-known and well-documented methods of generating random
numbers. An overall fast and reliable means to generate random numbers
is the $(D_PARAM Mt19937) generator, which derives its name from
"$(LUCKY Mersenne Twister) with a period of 2 to the power of
19937". In memory-constrained situations, $(LUCKY linear congruential)
generators such as $(D MinstdRand0) and $(D MinstdRand) might be
useful. The standard library provides an alias $(D_PARAM Random) for
whichever generator it considers the most fit for the target
environment.

Example:

----
// Generate a uniformly-distributed integer in the range [0, 14]
auto i = uniform(0, 15);
// Generate a uniformly-distributed real in the range [0, 100$(RPAREN)
// using a specific random generator
Random gen;
auto r = uniform(0.0L, 100.0L, gen);
----

In addition to random number generators, this module features
distributions, which skew a generator's output statistical
distribution in various ways. So far the uniform distribution for
integers and real numbers have been implemented.

Upgrading:
        $(WEB digitalmars.com/d/1.0/phobos/std_random.html#rand Phobos D1 $(D rand())) can
        be replaced with $(D uniform!uint()).

Source:    $(PHOBOSSRC std/_random.d)

Macros:

WIKI = Phobos/StdRandom


Copyright: Copyright Andrei Alexandrescu 2008 - 2009, Joseph Rushton Wakeling 2012.
License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
           Masahiro Nakagawa (Xorshift random generator)
           $(WEB braingam.es, Joseph Rushton Wakeling) (Algorithm D for random sampling)
Credits:   The entire random number library architecture is derived from the
           excellent $(WEB open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf, C++0X)
           random number facility proposed by Jens Maurer and contributed to by
           researchers at the Fermi laboratory (excluding Xorshift).
*/
/*
         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.random;

public import std.random.device;
public import std.random.engine;
public import std.random.traits;

import std.range.primitives;
import std.traits;

// Segments of the code in this file Copyright (c) 1997 by Rick Booth
// From "Inner Loops" by Rick Booth, Addison-Wesley


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
    return uniform!(boundaries, T1, T2, Random)(a, b, rndGen);
}

@safe unittest
{
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
            text("std.random.uniform(): invalid bounding interval ",
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
                text("std.random.uniform(): invalid left bound ", a));
        ResultType lower = cast(ResultType) (a + 1);
    }
    else
    {
        ResultType lower = a;
    }

    static if (boundaries[1] == ']')
    {
        enforce(lower <= b,
                text("std.random.uniform(): invalid bounding interval ",
                        boundaries[0], a, ", ", b, boundaries[1]));
        /* Cannot use this next optimization with dchar, as dchar
         * only partially uses its full bit range
         */
        static if (!is(ResultType == dchar))
        {
            if (b == ResultType.max && lower == ResultType.min)
            {
                // Special case - all bits are occupied
                return std.random.uniform!ResultType(rng);
            }
        }
        auto upperDist = unsigned(b - lower) + 1u;
    }
    else
    {
        enforce(lower < b,
                text("std.random.uniform(): invalid bounding interval ",
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
    return members[std.random.uniform(0, members.length, urng)];
}

/// Ditto
auto uniform(E)()
if (is(E == enum))
{
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
 *     rng = (optional) random number generator to use;
 *           if not specified, defaults to $(D rndGen)
 *
 * Returns:
 *     Floating-point random variate of type $(D T) drawn from the _uniform
 *     distribution across the half-open interval [0, 1$(RPAREN).
 *
 */
T uniform01(T = double)()
    if (isFloatingPoint!T)
{
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

/**
Shuffles elements of $(D r) using $(D gen) as a shuffler. $(D r) must be
a random-access range with length.  If no RNG is specified, $(D rndGen)
will be used.

Params:
    r = random-access range whose elements are to be shuffled
    gen = (optional) random number generator to use; if not
          specified, defaults to $(D rndGen)
 */

void randomShuffle(Range, RandomGen)(Range r, ref RandomGen gen)
    if(isRandomAccessRange!Range && isUniformRNG!RandomGen)
{
    return partialShuffle!(Range, RandomGen)(r, r.length, gen);
}

/// ditto
void randomShuffle(Range)(Range r)
    if(isRandomAccessRange!Range)
{
    return randomShuffle(r, rndGen);
}

unittest
{
    import std.algorithm;
    import std.random.device : unpredictableSeed;
    foreach(RandomGen; PseudoRngTypes)
    {
        // Also tests partialShuffle indirectly.
        auto a = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        auto b = a.dup;
        auto gen = RandomGen(unpredictableSeed);
        randomShuffle(a, gen);
        sort(a);
        assert(a == b);
        randomShuffle(a);
        sort(a);
        assert(a == b);
    }
}

/**
Partially shuffles the elements of $(D r) such that upon returning $(D r[0..n])
is a random subset of $(D r) and is randomly ordered.  $(D r[n..r.length])
will contain the elements not in $(D r[0..n]).  These will be in an undefined
order, but will not be random in the sense that their order after
$(D partialShuffle) returns will not be independent of their order before
$(D partialShuffle) was called.

$(D r) must be a random-access range with length.  $(D n) must be less than
or equal to $(D r.length).  If no RNG is specified, $(D rndGen) will be used.

Params:
    r = random-access range whose elements are to be shuffled
    n = number of elements of $(D r) to shuffle (counting from the beginning);
        must be less than $(D r.length)
    gen = (optional) random number generator to use; if not
          specified, defaults to $(D rndGen)
*/
void partialShuffle(Range, RandomGen)(Range r, in size_t n, ref RandomGen gen)
    if(isRandomAccessRange!Range && isUniformRNG!RandomGen)
{
    import std.exception : enforce;
    import std.algorithm : swapAt;
    enforce(n <= r.length, "n must be <= r.length for partialShuffle.");
    foreach (i; 0 .. n)
    {
        swapAt(r, i, uniform(i, r.length, gen));
    }
}

/// ditto
void partialShuffle(Range)(Range r, in size_t n)
    if(isRandomAccessRange!Range)
{
    return partialShuffle(r, n, rndGen);
}

unittest
{
    import std.algorithm;
    foreach(RandomGen; PseudoRngTypes)
    {
        auto a = [0, 1, 1, 2, 3];
        auto b = a.dup;

        // Pick a fixed seed so that the outcome of the statistical
        // test below is deterministic.
        auto gen = RandomGen(12345);

        // NUM times, pick LEN elements from the array at random.
        immutable int LEN = 2;
        immutable int NUM = 750;
        int[][] chk;
        foreach(step; 0..NUM)
        {
            partialShuffle(a, LEN, gen);
            chk ~= a[0..LEN].dup;
        }

        // Check that each possible a[0..LEN] was produced at least once.
        // For a perfectly random RandomGen, the probability that each
        // particular combination failed to appear would be at most
        // 0.95 ^^ NUM which is approximately 1,962e-17.
        // As long as hardware failure (e.g. bit flip) probability
        // is higher, we are fine with this unittest.
        sort(chk);
        assert(equal(uniq(chk), [       [0,1], [0,2], [0,3],
                                 [1,0], [1,1], [1,2], [1,3],
                                 [2,0], [2,1],        [2,3],
                                 [3,0], [3,1], [3,2],      ]));

        // Check that all the elements are still there.
        sort(a);
        assert(equal(a, b));
    }
}

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
    auto rnd = Random(unpredictableSeed);
    auto i = dice(rnd, 0.0, 100.0);
    assert(i == 1);
    i = dice(rnd, 100.0, 0.0);
    assert(i == 0);

    i = dice(100U, 0U);
    assert(i == 0);
}

/**
Covers a given range $(D r) in a random manner, i.e. goes through each
element of $(D r) once and only once, just in a random order. $(D r)
must be a random-access range with length.

If no random number generator is passed to $(D randomCover), the
thread-global RNG rndGen will be used internally.

Params:
    r = random-access range to cover
    rng = (optional) random number generator to use;
          if not specified, defaults to $(D rndGen)

Returns:
    Range whose elements consist of the elements of $(D r),
    in random order.  Will be a forward range if both $(D r) and
    $(D rng) are forward ranges, an input range otherwise.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
foreach (e; randomCover(a))
{
    writeln(e);
}
----

$(B WARNING:) If an alternative RNG is desired, it is essential for this
to be a $(I new) RNG seeded in an unpredictable manner. Passing it a RNG
used elsewhere in the program will result in unintended correlations,
due to the current implementation of RNGs as value types.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
foreach (e; randomCover(a, Random(unpredictableSeed)))  // correct!
{
    writeln(e);
}

foreach (e; randomCover(a, rndGen))  // DANGEROUS!! rndGen gets copied by value
{
    writeln(e);
}

foreach (e; randomCover(a, rndGen))  // ... so this second random cover
{                                    // will output the same sequence as
    writeln(e);                      // the previous one.
}
----

These issues will be resolved in a second-generation std.random that
re-implements random number generators as reference types.
 */
struct RandomCover(Range, UniformRNG = void)
    if (isRandomAccessRange!Range && (isUniformRNG!UniformRNG || is(UniformRNG == void)))
{
    private Range _input;
    private bool[] _chosen;
    private size_t _current;
    private size_t _alreadyChosen = 0;

    static if (is(UniformRNG == void))
    {
        this(Range input)
        {
            _input = input;
            _chosen.length = _input.length;
            if (_chosen.length == 0)
            {
                _alreadyChosen = 1;
            }
        }
    }
    else
    {
        private UniformRNG _rng;

        this(Range input, ref UniformRNG rng)
        {
            _input = input;
            _rng = rng;
            _chosen.length = _input.length;
            if (_chosen.length == 0)
            {
                _alreadyChosen = 1;
            }
        }

        this(Range input, UniformRNG rng)
        {
            this(input, rng);
        }
    }

    static if (hasLength!Range)
    {
        @property size_t length()
        {
            if (_alreadyChosen == 0)
            {
                return _input.length;
            }
            else
            {
                return (1 + _input.length) - _alreadyChosen;
            }
        }
    }

    @property auto ref front()
    {
        if (_alreadyChosen == 0)
        {
            popFront();
        }
        return _input[_current];
    }

    void popFront()
    {
        if (_alreadyChosen >= _input.length)
        {
            // No more elements
            ++_alreadyChosen; // means we're done
            return;
        }
        size_t k = _input.length - _alreadyChosen;
        size_t i;
        foreach (e; _input)
        {
            if (_chosen[i]) { ++i; continue; }
            // Roll a dice with k faces
            static if (is(UniformRNG == void))
            {
                auto chooseMe = uniform(0, k) == 0;
            }
            else
            {
                auto chooseMe = uniform(0, k, _rng) == 0;
            }
            assert(k > 1 || chooseMe);
            if (chooseMe)
            {
                _chosen[i] = true;
                _current = i;
                ++_alreadyChosen;
                return;
            }
            --k;
            ++i;
        }
    }

    static if (isForwardRange!UniformRNG)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret._input = _input.save;
            ret._rng = _rng.save;
            return ret;
        }
    }

    @property bool empty() { return _alreadyChosen > _input.length; }
}

/// Ditto
auto randomCover(Range, UniformRNG)(Range r, auto ref UniformRNG rng)
    if (isRandomAccessRange!Range && isUniformRNG!UniformRNG)
{
    return RandomCover!(Range, UniformRNG)(r, rng);
}

/// Ditto
auto randomCover(Range)(Range r)
    if (isRandomAccessRange!Range)
{
    return RandomCover!(Range, void)(r);
}

unittest
{
    import std.algorithm;
    import std.conv;
    import std.random.device : unpredictableSeed;
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
    foreach (UniformRNG; std.typetuple.TypeTuple!(void, PseudoRngTypes))
    {
        static if (is(UniformRNG == void))
        {
            auto rc = randomCover(a);
            static assert(isInputRange!(typeof(rc)));
            static assert(!isForwardRange!(typeof(rc)));
        }
        else
        {
            auto rng = UniformRNG(unpredictableSeed);
            auto rc = randomCover(a, rng);
            static assert(isForwardRange!(typeof(rc)));
            // check for constructor passed a value-type RNG
            auto rc2 = RandomCover!(int[], UniformRNG)(a, UniformRNG(unpredictableSeed));
            static assert(isForwardRange!(typeof(rc2)));
        }

        int[] b = new int[9];
        uint i;
        foreach (e; rc)
        {
            //writeln(e);
            b[i++] = e;
        }
        sort(b);
        assert(a == b, text(b));
    }
}

unittest
{
    // Bugzilla 12589
    int[] r = [];
    auto rc = randomCover(r);
    assert(rc.length == 0);
    assert(rc.empty);
}

// RandomSample
/**
Selects a random subsample out of $(D r), containing exactly $(D n)
elements. The order of elements is the same as in the original
range. The total length of $(D r) must be known. If $(D total) is
passed in, the total number of sample is considered to be $(D
total). Otherwise, $(D RandomSample) uses $(D r.length).

Params:
    r = range to sample from
    n = number of elements to include in the sample;
        must be less than or equal to the total number
        of elements in $(D r) and/or the parameter
        $(D total) (if provided)
    total = (semi-optional) number of elements of $(D r)
            from which to select the sample (counting from
            the beginning); must be less than or equal to
            the total number of elements in $(D r) itself.
            May be omitted if $(D r) has the $(D .length)
            property and the sample is to be drawn from
            all elements of $(D r).
    rng = (optional) random number generator to use;
          if not specified, defaults to $(D rndGen)

Returns:
    Range whose elements consist of a randomly selected subset of
    the elements of $(D r), in the same order as these elements
    appear in $(D r) itself.  Will be a forward range if both $(D r)
    and $(D rng) are forward ranges, an input range otherwise.

$(D RandomSample) implements Jeffrey Scott Vitter's Algorithm D
(see Vitter $(WEB dx.doi.org/10.1145/358105.893, 1984), $(WEB
dx.doi.org/10.1145/23002.23003, 1987)), which selects a sample
of size $(D n) in O(n) steps and requiring O(n) random variates,
regardless of the size of the data being sampled.  The exception
to this is if traversing k elements on the input range is itself
an O(k) operation (e.g. when sampling lines from an input file),
in which case the sampling calculation will inevitably be of
O(total).

RandomSample will throw an exception if $(D total) is verifiably
less than the total number of elements available in the input,
or if $(D n > total).

If no random number generator is passed to $(D randomSample), the
thread-global RNG rndGen will be used internally.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
// Print 5 random elements picked off from a
foreach (e; randomSample(a, 5))
{
    writeln(e);
}
----

$(B WARNING:) If an alternative RNG is desired, it is essential for this
to be a $(I new) RNG seeded in an unpredictable manner. Passing it a RNG
used elsewhere in the program will result in unintended correlations,
due to the current implementation of RNGs as value types.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
foreach (e; randomSample(a, 5, Random(unpredictableSeed)))  // correct!
{
    writeln(e);
}

foreach (e; randomSample(a, 5, rndGen))  // DANGEROUS!! rndGen gets
{                                        // copied by value
    writeln(e);
}

foreach (e; randomSample(a, 5, rndGen))  // ... so this second random
{                                        // sample will select the same
    writeln(e);                          // values as the previous one.
}
----

These issues will be resolved in a second-generation std.random that
re-implements random number generators as reference types.
*/
struct RandomSample(Range, UniformRNG = void)
    if (isInputRange!Range && (isUniformRNG!UniformRNG || is(UniformRNG == void)))
{
    private size_t _available, _toSelect;
    private enum ushort _alphaInverse = 13; // Vitter's recommended value.
    private double _Vprime;
    private Range _input;
    private size_t _index;
    private enum Skip { None, A, D }
    private Skip _skip = Skip.None;

    // If we're using the default thread-local random number generator then
    // we shouldn't store a copy of it here.  UniformRNG == void is a sentinel
    // for this.  If we're using a user-specified generator then we have no
    // choice but to store a copy.
    static if (is(UniformRNG == void))
    {
        static if (hasLength!Range)
        {
            this(Range input, size_t howMany)
            {
                _input = input;
                initialize(howMany, input.length);
            }
        }

        this(Range input, size_t howMany, size_t total)
        {
            _input = input;
            initialize(howMany, total);
        }
    }
    else
    {
        UniformRNG _rng;

        static if (hasLength!Range)
        {
            this(Range input, size_t howMany, ref UniformRNG rng)
            {
                _rng = rng;
                _input = input;
                initialize(howMany, input.length);
            }

            this(Range input, size_t howMany, UniformRNG rng)
            {
                this(input, howMany, rng);
            }
        }

        this(Range input, size_t howMany, size_t total, ref UniformRNG rng)
        {
            _rng = rng;
            _input = input;
            initialize(howMany, total);
        }

        this(Range input, size_t howMany, size_t total, UniformRNG rng)
        {
            this(input, howMany, total, rng);
        }
    }

    private void initialize(size_t howMany, size_t total)
    {
        import std.exception : enforce;
        import std.conv : text;
        _available = total;
        _toSelect = howMany;
        enforce(_toSelect <= _available,
                text("RandomSample: cannot sample ", _toSelect,
                     " items when only ", _available, " are available"));
        static if (hasLength!Range)
        {
            enforce(_available <= _input.length,
                    text("RandomSample: specified ", _available,
                         " items as available when input contains only ",
                         _input.length));
        }
    }

    private void initializeFront()
    {
        assert(_skip == Skip.None);
        // We can save ourselves a random variate by checking right
        // at the beginning if we should use Algorithm A.
        if ((_alphaInverse * _toSelect) > _available)
        {
            _skip = Skip.A;
        }
        else
        {
            _skip = Skip.D;
            _Vprime = newVprime(_toSelect);
        }
        prime();
    }

/**
   Range primitives.
*/
    @property bool empty() const
    {
        return _toSelect == 0;
    }

    @property auto ref front()
    {
        assert(!empty);
        // The first sample point must be determined here to avoid
        // having it always correspond to the first element of the
        // input.  The rest of the sample points are determined each
        // time we call popFront().
        if (_skip == Skip.None)
        {
            initializeFront();
        }
        return _input.front;
    }

/// Ditto
    void popFront()
    {
        // First we need to check if the sample has
        // been initialized in the first place.
        if (_skip == Skip.None)
        {
            initializeFront();
        }

        _input.popFront();
        --_available;
        --_toSelect;
        ++_index;
        prime();
    }

/// Ditto
    static if (isForwardRange!Range && isForwardRange!UniformRNG)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret._input = _input.save;
            ret._rng = _rng.save;
            return ret;
        }
    }

/// Ditto
    @property size_t length()
    {
        return _toSelect;
    }

/**
Returns the index of the visited record.
 */
    @property size_t index()
    {
        if (_skip == Skip.None)
        {
            initializeFront();
        }
        return _index;
    }

    private size_t skip()
    {
        assert(_skip != Skip.None);

        // Step D1: if the number of points still to select is greater
        // than a certain proportion of the remaining data points, i.e.
        // if n >= alpha * N where alpha = 1/13, we carry out the
        // sampling with Algorithm A.
        if (_skip == Skip.A)
        {
            return skipA();
        }
        else if ((_alphaInverse * _toSelect) > _available)
        {
            // We shouldn't get here unless the current selected
            // algorithm is D.
            assert(_skip == Skip.D);
            _skip = Skip.A;
            return skipA();
        }
        else
        {
            assert(_skip == Skip.D);
            return skipD();
        }
    }

/*
Vitter's Algorithm A, used when the ratio of needed sample values
to remaining data values is sufficiently large.
*/
    private size_t skipA()
    {
        size_t s;
        double v, quot, top;

        if (_toSelect==1)
        {
            static if (is(UniformRNG == void))
            {
                s = uniform(0, _available);
            }
            else
            {
                s = uniform(0, _available, _rng);
            }
        }
        else
        {
            v = 0;
            top = _available - _toSelect;
            quot = top / _available;

            static if (is(UniformRNG == void))
            {
                v = uniform!"()"(0.0, 1.0);
            }
            else
            {
                v = uniform!"()"(0.0, 1.0, _rng);
            }

            while (quot > v)
            {
                ++s;
                quot *= (top - s) / (_available - s);
            }
        }

        return s;
    }

/*
Randomly reset the value of _Vprime.
*/
    private double newVprime(size_t remaining)
    {
        static if (is(UniformRNG == void))
        {
            double r = uniform!"()"(0.0, 1.0);
        }
        else
        {
            double r = uniform!"()"(0.0, 1.0, _rng);
        }

        return r ^^ (1.0 / remaining);
    }

/*
Vitter's Algorithm D.  For an extensive description of the algorithm
and its rationale, see:

  * Vitter, J.S. (1984), "Faster methods for random sampling",
    Commun. ACM 27(7): 703--718

  * Vitter, J.S. (1987) "An efficient algorithm for sequential random
    sampling", ACM Trans. Math. Softw. 13(1): 58-67.

Variable names are chosen to match those in Vitter's paper.
*/
    private size_t skipD()
    {
        import std.math : isNaN, trunc;
        // Confirm that the check in Step D1 is valid and we
        // haven't been sent here by mistake
        assert((_alphaInverse * _toSelect) <= _available);

        // Now it's safe to use the standard Algorithm D mechanism.
        if (_toSelect > 1)
        {
            size_t s;
            size_t qu1 = 1 + _available - _toSelect;
            double x, y1;

            assert(!_Vprime.isNaN());

            while (true)
            {
                // Step D2: set values of x and u.
                while(1)
                {
                    x = _available * (1-_Vprime);
                    s = cast(size_t) trunc(x);
                    if (s < qu1)
                        break;
                    _Vprime = newVprime(_toSelect);
                }

                static if (is(UniformRNG == void))
                {
                    double u = uniform!"()"(0.0, 1.0);
                }
                else
                {
                    double u = uniform!"()"(0.0, 1.0, _rng);
                }

                y1 = (u * (cast(double) _available) / qu1) ^^ (1.0/(_toSelect - 1));

                _Vprime = y1 * ((-x/_available)+1.0) * ( qu1/( (cast(double) qu1) - s ) );

                // Step D3: if _Vprime <= 1.0 our work is done and we return S.
                // Otherwise ...
                if (_Vprime > 1.0)
                {
                    size_t top = _available - 1, limit;
                    double y2 = 1.0, bottom;

                    if (_toSelect > (s+1))
                    {
                        bottom = _available - _toSelect;
                        limit = _available - s;
                    }
                    else
                    {
                        bottom = _available - (s+1);
                        limit = qu1;
                    }

                    foreach (size_t t; limit .. _available)
                    {
                        y2 *= top/bottom;
                        top--;
                        bottom--;
                    }

                    // Step D4: decide whether or not to accept the current value of S.
                    if (_available/(_available-x) < y1 * (y2 ^^ (1.0/(_toSelect-1))))
                    {
                        // If it's not acceptable, we generate a new value of _Vprime
                        // and go back to the start of the for (;;) loop.
                        _Vprime = newVprime(_toSelect);
                    }
                    else
                    {
                        // If it's acceptable we generate a new value of _Vprime
                        // based on the remaining number of sample points needed,
                        // and return S.
                        _Vprime = newVprime(_toSelect-1);
                        return s;
                    }
                }
                else
                {
                    // Return if condition D3 satisfied.
                    return s;
                }
            }
        }
        else
        {
            // If only one sample point remains to be taken ...
            return cast(size_t) trunc(_available * _Vprime);
        }
    }

    private void prime()
    {
        if (empty)
        {
            return;
        }
        assert(_available && _available >= _toSelect);
        immutable size_t s = skip();
        assert(s + _toSelect <= _available);
        static if (hasLength!Range)
        {
            assert(s + _toSelect <= _input.length);
        }
        assert(!_input.empty);
        _input.popFrontExactly(s);
        _index += s;
        _available -= s;
        assert(_available > 0);
    }
}

/// Ditto
auto randomSample(Range)(Range r, size_t n, size_t total)
    if (isInputRange!Range)
{
    return RandomSample!(Range, void)(r, n, total);
}

/// Ditto
auto randomSample(Range)(Range r, size_t n)
    if (isInputRange!Range && hasLength!Range)
{
    return RandomSample!(Range, void)(r, n, r.length);
}

/// Ditto
auto randomSample(Range, UniformRNG)(Range r, size_t n, size_t total, auto ref UniformRNG rng)
    if (isInputRange!Range && isUniformRNG!UniformRNG)
{
    return RandomSample!(Range, UniformRNG)(r, n, total, rng);
}

/// Ditto
auto randomSample(Range, UniformRNG)(Range r, size_t n, auto ref UniformRNG rng)
    if (isInputRange!Range && hasLength!Range && isUniformRNG!UniformRNG)
{
    return RandomSample!(Range, UniformRNG)(r, n, r.length, rng);
}

unittest
{
    import std.exception;
    import std.range;
    import std.conv : text;
    import std.random.device : unpredictableSeed;
    // For test purposes, an infinite input range
    struct TestInputRange
    {
        private auto r = recurrence!"a[n-1] + 1"(0);
        bool empty() @property const pure nothrow { return r.empty; }
        auto front() @property pure nothrow { return r.front; }
        void popFront() pure nothrow { r.popFront(); }
    }
    static assert(isInputRange!TestInputRange);
    static assert(!isForwardRange!TestInputRange);

    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];

    foreach (UniformRNG; PseudoRngTypes)
    {
        auto rng = UniformRNG(unpredictableSeed);
        /* First test the most general case: randomSample of input range, with and
         * without a specified random number generator.
         */
        static assert(isInputRange!(typeof(randomSample(TestInputRange(), 5, 10))));
        static assert(isInputRange!(typeof(randomSample(TestInputRange(), 5, 10, rng))));
        static assert(!isForwardRange!(typeof(randomSample(TestInputRange(), 5, 10))));
        static assert(!isForwardRange!(typeof(randomSample(TestInputRange(), 5, 10, rng))));
        // test case with range initialized by direct call to struct
        {
            auto sample =
                RandomSample!(TestInputRange, UniformRNG)
                             (TestInputRange(), 5, 10, UniformRNG(unpredictableSeed));
            static assert(isInputRange!(typeof(sample)));
            static assert(!isForwardRange!(typeof(sample)));
        }

        /* Now test the case of an input range with length.  We ignore the cases
         * already covered by the previous tests.
         */
        static assert(isInputRange!(typeof(randomSample(TestInputRange().takeExactly(10), 5))));
        static assert(isInputRange!(typeof(randomSample(TestInputRange().takeExactly(10), 5, rng))));
        static assert(!isForwardRange!(typeof(randomSample(TestInputRange().takeExactly(10), 5))));
        static assert(!isForwardRange!(typeof(randomSample(TestInputRange().takeExactly(10), 5, rng))));
        // test case with range initialized by direct call to struct
        {
            auto sample =
                RandomSample!(typeof(TestInputRange().takeExactly(10)), UniformRNG)
                             (TestInputRange().takeExactly(10), 5, 10, UniformRNG(unpredictableSeed));
            static assert(isInputRange!(typeof(sample)));
            static assert(!isForwardRange!(typeof(sample)));
        }

        // Now test the case of providing a forward range as input.
        static assert(!isForwardRange!(typeof(randomSample(a, 5))));
        static if (isForwardRange!UniformRNG)
        {
            static assert(isForwardRange!(typeof(randomSample(a, 5, rng))));
            // ... and test with range initialized directly
            {
                auto sample =
                    RandomSample!(int[], UniformRNG)
                                 (a, 5, UniformRNG(unpredictableSeed));
                static assert(isForwardRange!(typeof(sample)));
            }
        }
        else
        {
            static assert(isInputRange!(typeof(randomSample(a, 5, rng))));
            static assert(!isForwardRange!(typeof(randomSample(a, 5, rng))));
            // ... and test with range initialized directly
            {
                auto sample =
                    RandomSample!(int[], UniformRNG)
                                 (a, 5, UniformRNG(unpredictableSeed));
                static assert(isInputRange!(typeof(sample)));
                static assert(!isForwardRange!(typeof(sample)));
            }
        }

        /* Check that randomSample will throw an error if we claim more
         * items are available than there actually are, or if we try to
         * sample more items than are available. */
        assert(collectExceptionMsg(randomSample(a, 5, 15)) == "RandomSample: specified 15 items as available when input contains only 10");
        assert(collectExceptionMsg(randomSample(a, 15)) == "RandomSample: cannot sample 15 items when only 10 are available");
        assert(collectExceptionMsg(randomSample(a, 9, 8)) == "RandomSample: cannot sample 9 items when only 8 are available");
        assert(collectExceptionMsg(randomSample(TestInputRange(), 12, 11)) == "RandomSample: cannot sample 12 items when only 11 are available");

        /* Check that sampling algorithm never accidentally overruns the end of
         * the input range.  If input is an InputRange without .length, this
         * relies on the user specifying the total number of available items
         * correctly.
         */
        {
            uint i = 0;
            foreach (e; randomSample(a, a.length))
            {
                assert(e == i);
                ++i;
            }
            assert(i == a.length);

            i = 0;
            foreach (e; randomSample(TestInputRange(), 17, 17))
            {
                assert(e == i);
                ++i;
            }
            assert(i == 17);
        }


        // Check length properties of random samples.
        assert(randomSample(a, 5).length == 5);
        assert(randomSample(a, 5, 10).length == 5);
        assert(randomSample(a, 5, rng).length == 5);
        assert(randomSample(a, 5, 10, rng).length == 5);
        assert(randomSample(TestInputRange(), 5, 10).length == 5);
        assert(randomSample(TestInputRange(), 5, 10, rng).length == 5);

        // ... and emptiness!
        assert(randomSample(a, 0).empty);
        assert(randomSample(a, 0, 5).empty);
        assert(randomSample(a, 0, rng).empty);
        assert(randomSample(a, 0, 5, rng).empty);
        assert(randomSample(TestInputRange(), 0, 10).empty);
        assert(randomSample(TestInputRange(), 0, 10, rng).empty);

        /* Test that the (lazy) evaluation of random samples works correctly.
         *
         * We cover 2 different cases: a sample where the ratio of sample points
         * to total points is greater than the threshold for using Algorithm, and
         * one where the ratio is small enough (< 1/13) for Algorithm D to be used.
         *
         * For each, we also cover the case with and without a specified RNG.
         */
        {
            // Small sample/source ratio, no specified RNG.
            uint i = 0;
            foreach (e; randomSample(randomCover(a), 5))
            {
                ++i;
            }
            assert(i == 5);

            // Small sample/source ratio, specified RNG.
            i = 0;
            foreach (e; randomSample(randomCover(a), 5, rng))
            {
                ++i;
            }
            assert(i == 5);

            // Large sample/source ratio, no specified RNG.
            i = 0;
            foreach (e; randomSample(TestInputRange(), 123, 123_456))
            {
                ++i;
            }
            assert(i == 123);

            // Large sample/source ratio, specified RNG.
            i = 0;
            foreach (e; randomSample(TestInputRange(), 123, 123_456, rng))
            {
                ++i;
            }
            assert(i == 123);

            /* Sample/source ratio large enough to start with Algorithm D,
             * small enough to switch to Algorithm A.
             */
            i = 0;
            foreach (e; randomSample(TestInputRange(), 10, 131))
            {
                ++i;
            }
            assert(i == 10);
        }

        // Test that the .index property works correctly
        {
            auto sample1 = randomSample(TestInputRange(), 654, 654_321);
            for (; !sample1.empty; sample1.popFront())
            {
                assert(sample1.front == sample1.index);
            }

            auto sample2 = randomSample(TestInputRange(), 654, 654_321, rng);
            for (; !sample2.empty; sample2.popFront())
            {
                assert(sample2.front == sample2.index);
            }

            /* Check that it also works if .index is called before .front.
             * See: http://d.puremagic.com/issues/show_bug.cgi?id=10322
             */
            auto sample3 = randomSample(TestInputRange(), 654, 654_321);
            for (; !sample3.empty; sample3.popFront())
            {
                assert(sample3.index == sample3.front);
            }

            auto sample4 = randomSample(TestInputRange(), 654, 654_321, rng);
            for (; !sample4.empty; sample4.popFront())
            {
                assert(sample4.index == sample4.front);
            }
        }

        /* Test behaviour if .popFront() is called before sample is read.
         * This is a rough-and-ready check that the statistical properties
         * are in the ballpark -- not a proper validation of statistical
         * quality!  This incidentally also checks for reference-type
         * initialization bugs, as the foreach() loop will operate on a
         * copy of the popFronted (and hence initialized) sample.
         */
        {
            size_t count0, count1, count99;
            foreach(_; 0 .. 100_000)
            {
                auto sample = randomSample(iota(100), 5);
                sample.popFront();
                foreach(s; sample)
                {
                    if (s == 0)
                    {
                        ++count0;
                    }
                    else if (s == 1)
                    {
                        ++count1;
                    }
                    else if (s == 99)
                    {
                        ++count99;
                    }
                }
            }
            /* Statistical assumptions here: this is a sequential sampling process
             * so (i) 0 can only be the first sample point, so _can't_ be in the
             * remainder of the sample after .popFront() is called. (ii) By similar
             * token, 1 can only be in the remainder if it's the 2nd point of the
             * whole sample, and hence if 0 was the first; probability of 0 being
             * first and 1 second is 5/100 * 4/99 (thank you, Algorithm S:-) and
             * so the mean count of 1 should be about 202.  Finally, 99 can only
             * be the _last_ sample point to be picked, so its probability of
             * inclusion should be independent of the .popFront() and it should
             * occur with frequency 5/100, hence its count should be about 5000.
             * Unfortunately we have to set quite a high tolerance because with
             * sample size small enough for unittests to run in reasonable time,
             * the variance can be quite high.
             */
            assert(count0 == 0);
            assert(count1 < 300, text("1: ", count1, " > 300."));
            assert(4_700 < count99, text("99: ", count99, " < 4700."));
            assert(count99 < 5_300, text("99: ", count99, " > 5300."));
        }

        /* Odd corner-cases: RandomSample has 2 constructors that are not called
         * by the randomSample() helper functions, but that can be used if the
         * constructor is called directly.  These cover the case of the user
         * specifying input but not input length.
         */
        {
            auto input1 = TestInputRange().takeExactly(456_789);
            static assert(hasLength!(typeof(input1)));
            auto sample1 = RandomSample!(typeof(input1), void)(input1, 789);
            static assert(isInputRange!(typeof(sample1)));
            static assert(!isForwardRange!(typeof(sample1)));
            assert(sample1.length == 789);
            assert(sample1._available == 456_789);
            uint i = 0;
            for (; !sample1.empty; sample1.popFront())
            {
                assert(sample1.front == sample1.index);
                ++i;
            }
            assert(i == 789);

            auto input2 = TestInputRange().takeExactly(456_789);
            static assert(hasLength!(typeof(input2)));
            auto sample2 = RandomSample!(typeof(input2), typeof(rng))(input2, 789, rng);
            static assert(isInputRange!(typeof(sample2)));
            static assert(!isForwardRange!(typeof(sample2)));
            assert(sample2.length == 789);
            assert(sample2._available == 456_789);
            i = 0;
            for (; !sample2.empty; sample2.popFront())
            {
                assert(sample2.front == sample2.index);
                ++i;
            }
            assert(i == 789);
        }

        /* Test that the save property works where input is a forward range,
         * and RandomSample is using a (forward range) random number generator
         * that is not rndGen.
         */
        static if (isForwardRange!UniformRNG)
        {
            auto sample1 = randomSample(a, 5, rng);
            auto sample2 = sample1.save;
            assert(sample1.array() == sample2.array());
        }

        // Bugzilla 8314
        {
            auto sample(RandomGen)(uint seed) { return randomSample(a, 1, RandomGen(seed)).front; }

            // Start from 1 because not all RNGs accept 0 as seed.
            immutable fst = sample!UniformRNG(1);
            uint n = 1;
            while (sample!UniformRNG(++n) == fst && n < n.max) {}
            assert(n < n.max);
        }
    }
}
