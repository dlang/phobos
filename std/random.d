// Written in the D programming language.

/**
Facilities for random number generation. The old-style functions
$(D_PARAM rand_seed) and $(D_PARAM rand) will soon be deprecated as
they rely on global state and as such are subjected to various
thread-related issues.

The new-style generator objects hold their own state so they are
immune of threading issues. The generators feature a number of
well-known and well-documented methods of generating random
numbers. An overall fast and reliable means to generate random numbers
is the $(D_PARAM Mt19937) generator, which derives its name from
"$(WEB math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html, Mersenne
Twister) with a period of 2 to the power of 19937". In
memory-constrained situations, $(LUCKY linear congruential) generators
such as $(D MinstdRand0) and $(D MinstdRand) might be useful. The
standard library provides an alias $(D_PARAM Random) for whichever
generator it considers the most fit for the target environment.

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

Macros:

WIKI = Phobos/StdRandom


Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
Credits:   The entire random number library architecture is derived from the
           excellent $(WEB open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf, C++0X)
           random number facility proposed by Jens Maurer and contributed to by
           researchers at the Fermi laboratory.

         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.random;

import std.algorithm, std.c.time, std.contracts, std.conv, std.date, std.math,
    std.numeric, std.process, std.range, std.stdio, std.traits, core.thread;

// Segments of the code in this file Copyright (c) 1997 by Rick Booth
// From "Inner Loops" by Rick Booth, Addison-Wesley

// Work derived from:

/*
   A C-program for MT19937, with initialization improved 2002/1/26.
   Coded by Takuji Nishimura and Makoto Matsumoto.

   Before using, initialize the state by using init_genrand(seed)
   or init_by_array(init_key, key_length).

   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

     1. Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.

     2. Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

     3. The names of its contributors may not be used to endorse or promote
        products derived from this software without specific prior written
        permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


   Any feedback is very welcome.
   http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
   email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)
*/

version (Win32)
{
    extern(Windows) int QueryPerformanceCounter(ulong *count);
}

version (Posix)
{
    private import core.sys.posix.sys.time;
}

/**
Linear Congruential generator.
 */
struct LinearCongruentialEngine(UIntType, UIntType a, UIntType c, UIntType m)
{
    /// Does this generator have a fixed range? ($(D_PARAM true)).
    enum bool hasFixedRange = true;
    /// Lowest generated value ($(D 1) if $(D c == 0), $(D 0) otherwise).
    enum UIntType min = ( c == 0 ? 1 : 0 );
    /// Highest generated value ($(D modulus - 1)).
    enum UIntType max = m - 1;
/**
The parameters of this distribution. The random number is $(D_PARAM x
= (x * multipler + increment) % modulus).
 */
    enum UIntType multiplier = a;
    ///ditto
    enum UIntType increment = c;
    ///ditto
    enum UIntType modulus = m;

    static assert(isIntegral!(UIntType));
    static assert(m == 0 || a < m);
    static assert(m == 0 || c < m);
    static assert(m == 0 ||
            (cast(ulong)a * (m-1) + c) % m == (c < a ? c - a + m : c - a));

    // Check for maximum range
    private static ulong gcd(ulong a, ulong b) {
        while (b) {
            auto t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    private static ulong primeFactorsOnly(ulong n) {
        ulong result = 1;
        ulong iter = 2;
        for (; n >= iter * iter; iter += 2 - (iter == 2)) {
            if (n % iter) continue;
            result *= iter;
            do {
                n /= iter;
            } while (n % iter == 0);
        }
        return result * n;
    }

    unittest {
        static assert(primeFactorsOnly(100) == 10);
        //writeln(primeFactorsOnly(11));
        static assert(primeFactorsOnly(11) == 11);
        static assert(primeFactorsOnly(7 * 7 * 7 * 11 * 15 * 11) == 7 * 11 * 15);
        static assert(primeFactorsOnly(129 * 2) == 129 * 2);
        // enum x = primeFactorsOnly(7 * 7 * 7 * 11 * 15);
        // static assert(x == 7 * 11 * 15);
    }

    private static bool properLinearCongruentialParameters(ulong m,
            ulong a, ulong c) {
        if (m == 0)
        {
            static if (is(UIntType == uint))
            {
                // Assume m is uint.max + 1
                m = (1uL << 32);
            }
            else
            {
                return false;
            }
        }
        // Bounds checking
        if (a == 0 || a >= m || c >= m) return false;
        // c and m are relatively prime
        if (c > 0 && gcd(c, m) != 1) return false;
        // a - 1 is divisible by all prime factors of m
        if ((a - 1) % primeFactorsOnly(m)) return false;
        // if a - 1 is multiple of 4, then m is a  multiple of 4 too.
        if ((a - 1) % 4 == 0 && m % 4) return false;
        // Passed all tests
        return true;
    }

    // check here
    static assert(c == 0 || properLinearCongruentialParameters(m, a, c),
            "Incorrect instantiation of LinearCongruentialEngine");

/**
Constructs a $(D_PARAM LinearCongruentialEngine) generator seeded with
$(D x0).
 */
    this(UIntType x0)
    {
        seed(x0);
    }

/**
   (Re)seeds the generator.
*/
    void seed(UIntType x0 = 1)
    {
        static if (c == 0)
        {
            enforce(x0, "Invalid (zero) seed for "
                    ~ LinearCongruentialEngine.stringof);
        }
        _x = modulus ? (x0 % modulus) : x0;
        popFront;
    }

/**
   Advances the random sequence.
*/
    void popFront()
    {
        static if (m)
        {
            static if (is(UIntType == uint) && m == uint.max)
            {
                immutable ulong
                    x = (cast(ulong) a * _x + c),
                    v = x >> 32,
                    w = x & uint.max;
                immutable y = cast(uint)(v + w);
                _x = (y < v || y == uint.max) ? (y + 1) : y;
            }
            else static if (is(UIntType == uint) && m == int.max)
            {
                immutable ulong
                    x = (cast(ulong) a * _x + c),
                    v = x >> 31,
                    w = x & int.max;
                immutable uint y = cast(uint)(v + w);
                _x = (y >= int.max) ? (y - int.max) : y;
            }
            else
            {
                _x = cast(UIntType) ((cast(ulong) a * _x + c) % m);
            }
        }
        else
        {
            _x = a * _x + c;
        }
    }

/**
   Returns the current number in the random sequence.
*/
    UIntType front()
    {
        return _x;
    }
    
/**
Always $(D false) (random generators are infinite ranges).
 */
    enum bool empty = false;

/**
   Compares against $(D_PARAM rhs) for equality.
 */
    bool opEquals(ref const LinearCongruentialEngine rhs) const
    {
        return _x == rhs._x;
    }

    private UIntType _x = m ? (a + c) % m : (a + c);
}

/**
Define $(D_PARAM LinearCongruentialEngine) generators with well-chosen
parameters. $(D MinstdRand0) implements Park and Miller's "minimal
standard" $(WEB
wikipedia.org/wiki/Park%E2%80%93Miller_random_number_generator,
generator) that uses 16807 for the multiplier. $(D MinstdRand)
implements a variant that has slightly better spectral behavior by
using the multiplier 48271. Both generators are rather simplistic.

Example:

----
// seed with a constant
auto rnd0 = MinstdRand0(1);
auto n = rnd0.front; // same for each run
// Seed with an unpredictable value
rnd0.seed(unpredictableSeed);
n = rnd0.front; // different across runs
----
 */
alias LinearCongruentialEngine!(uint, 16807, 0, 2147483647) MinstdRand0;
/// ditto
alias LinearCongruentialEngine!(uint, 48271, 0, 2147483647) MinstdRand;

unittest
{
    // The correct numbers are taken from The Database of Integer Sequences
    // http://www.research.att.com/~njas/sequences/eisBTfry00128.txt
    auto checking0 = [
        16807UL,282475249,1622650073,984943658,1144108930,470211272,
        101027544,1457850878,1458777923,2007237709,823564440,1115438165,
        1784484492,74243042,114807987,1137522503,1441282327,16531729,
        823378840,143542612 ];
    //auto rnd0 = MinstdRand0(1);
    MinstdRand0 rnd0;
    foreach (e; checking0)
    {
        assert(rnd0.front == e);
        rnd0.popFront;
    }
    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd0.seed;
    popFrontN(rnd0, 9999);
    assert(rnd0.front == 1043618065);

    // Test MinstdRand
    auto checking = [48271UL,182605794,1291394886,1914720637,2078669041,
                     407355683];
    //auto rnd = MinstdRand(1);
    MinstdRand rnd;
    foreach (e; checking)
    {
        assert(rnd.front == e);
        rnd.popFront;
    }

    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd.seed;
    popFrontN(rnd, 9999);
    assert(rnd.front == 399268537);
}

/**
The $(WEB math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html, Mersenne
Twister) generator.
 */
struct MersenneTwisterEngine(
    UIntType, size_t w, size_t n, size_t m, size_t r,
    UIntType a, size_t u, size_t s,
    UIntType b, size_t t,
    UIntType c, size_t l)
{
/**
Parameter for the generator.
*/
    enum size_t wordSize = w;
    enum size_t stateSize = n;
    enum size_t shiftSize = m;
    enum size_t maskBits = r;
    enum UIntType xorMask = a;
    enum UIntType temperingU = u;
    enum size_t temperingS = s;
    enum UIntType temperingB = b;
    enum size_t temperingT = t;
    enum UIntType temperingC = c;
    enum size_t temperingL = l;

    /// Smallest generated value (0).
    enum UIntType min = 0;
    /// Largest generated value.
    enum UIntType max =
        w == UIntType.sizeof * 8 ? UIntType.max : (1u << w) - 1;
    /// The default seed value.
    enum UIntType defaultSeed = 5489u;

    static assert(1 <= m && m <= n);
    static assert(0 <= r && 0 <= u && 0 <= s && 0 <= t && 0 <= l);
    static assert(r <= w && u <= w && s <= w && t <= w && l <= w);
    static assert(0 <= a && 0 <= b && 0 <= c);
    static assert(a <= max && b <= max && c <= max);

/**
   Constructs a MersenneTwisterEngine object.
*/
    this(UIntType value)
    {
        seed(value);
    }

/**
   Seeds a MersenneTwisterEngine object.
*/
    void seed(UIntType value = defaultSeed)
    {
        static if (w == UIntType.sizeof * 8)
        {
            mt[0] = value;
        }
        else
        {
            static assert(max + 1 > 0);
            mt[0] = value % (max + 1);
        }
        for (mti = 1; mti < n; ++mti) {
            mt[mti] =
                cast(UIntType)
                (1812433253UL * (mt[mti-1] ^ (mt[mti-1] >> (w - 2))) + mti);
            /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
            /* In the previous versions, MSBs of the seed affect   */
            /* only MSBs of the array mt[].                        */
            /* 2002/01/09 modified by Makoto Matsumoto             */
            //mt[mti] &= ResultType.max;
            /* for >32 bit machines */
        }
        popFront;
    }

/**
   Advances the generator.
*/
    void popFront()
    {
        if (mti == size_t.max) seed();
        enum UIntType
            upperMask = ~((cast(UIntType) 1u <<
                           (UIntType.sizeof * 8 - (w - r))) - 1),
            lowerMask = (cast(UIntType) 1u << r) - 1;
        static invariant UIntType mag01[2] = [0x0UL, a];

        ulong y = void;

        if (mti >= n)
        {
            /* generate N words at one time */

            int kk = 0;
            const limit1 = n - m;
            for (; kk < limit1; ++kk)
            {
                y = (mt[kk] & upperMask)|(mt[kk + 1] & lowerMask);
                mt[kk] = cast(UIntType) (mt[kk + m] ^ (y >> 1)
                        ^ mag01[cast(UIntType) y & 0x1U]);
            }
            const limit2 = n - 1;
            for (; kk < limit2; ++kk)
            {
                y = (mt[kk] & upperMask)|(mt[kk + 1] & lowerMask);
                mt[kk] = cast(UIntType) (mt[kk + (m -n)] ^ (y >> 1)
                                         ^ mag01[cast(UIntType) y & 0x1U]);
            }
            y = (mt[n -1] & upperMask)|(mt[0] & lowerMask);
            mt[n - 1] = cast(UIntType) (mt[m - 1] ^ (y >> 1)
                                        ^ mag01[cast(UIntType) y & 0x1U]);

            mti = 0;
        }

        y = mt[mti++];

        /* Tempering */
        y ^= (y >> temperingU);
        y ^= (y << temperingS) & temperingB;
        y ^= (y << temperingT) & temperingC;
        y ^= (y >> temperingL);

        _y = cast(UIntType) y;
    }

/**
   Returns the current random value.
 */
    UIntType front()
    {
        if (mti == size_t.max) seed();
        return _y;
    }

/**
Always $(D false).
 */
    enum bool empty = false;

    private UIntType mt[n];
    private size_t mti = size_t.max; /* means mt is not initialized */
    UIntType _y = UIntType.max;
}

/**
A $(D MersenneTwisterEngine) instantiated with the parameters of the
original engine $(WEB math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html,
MT19937), generating uniformly-distributed 32-bit numbers with a
period of 2 to the power of 19937. Recommended for random number
generation unless memory is severely restricted, in which case a $(D
LinearCongruentialEngine) would be the generator of choice.

Example:

----
// seed with a constant
Mt19937 gen;
auto n = gen.front; // same for each run
// Seed with an unpredictable value
gen.seed(unpredictableSeed);
n = gen.front; // different across runs
----
 */
alias MersenneTwisterEngine!(uint, 32, 624, 397, 31, 0x9908b0df, 11, 7,
                             0x9d2c5680, 15, 0xefc60000, 18)
    Mt19937;

unittest
{
    Mt19937 gen;
    popFrontN(gen, 9999);
    assert(gen.front == 4123659995);
}

unittest
{
    uint a, b;
    {
        Mt19937 gen;
        a = gen.front;
    }
    {
        Mt19937 gen;
        gen.popFront;
        //popFrontN(gen, 1);  // skip 1 element
        b = gen.front;
    }
    assert(a != b);
}

/**
A "good" seed for initializing random number engines. Initializing
with $(D_PARAM unpredictableSeed) makes engines generate different
random number sequences every run.

Example:

----
auto rnd = Random(unpredictableSeed);
auto n = rnd.front;
...
----
*/

uint unpredictableSeed()
{
    static bool seeded;
    static MinstdRand0 rand;
    if (!seeded) {
        uint threadID = cast(uint) cast(void*) Thread.getThis();
        rand.seed((getpid + threadID) ^ cast(uint) getUTCtime);
        seeded = true;
    }
    rand.popFront;
    return cast(uint) (getUTCtime ^ rand.front);
}

unittest
{
    // not much to test here
    auto a = unpredictableSeed;
    static assert(is(typeof(a) == uint));
}

/**
The "default", "favorite", "suggested" random number generator type on
the current platform. It is an alias for one of the previously-defined
generators. You may want to use it if (1) you need to generate some
nice random numbers, and (2) you don't care for the minutiae of the
method being used.
 */

alias Mt19937 Random;

/**
Global random number generator used by various functions in this
module whenever no generator is specified. It is allocated per-thread
and initialized to an unpredictable value for each thread.
 */
ref Random rndGen()
{
    static Random result;
    static bool initialized;
    if (!initialized)
    {
        result = Random(unpredictableSeed);
        initialized = true;
    }
    return result;
}

/**
Generates a number between $(D a) and $(D b). The $(D boundaries)
parameter controls the shape of the interval (open vs. closed on
either side). Valid values for $(D boundaries) are $(D "[]"), $(D
"$(LPAREN)]"), $(D "[$(RPAREN)"), and $(D "()"). The default interval
is closed to the left and open to the right.

Example:

----
Random gen(unpredictableSeed);
// Generate an integer in [0, 1023]
auto a = uniform(0, 1024, gen);
// Generate a float in [0, 1$(RPAREN)
auto a = uniform(0.0f, 1.0f, gen);
----
 */
version(ddoc)
    CommonType!(T1, T2) uniform(string boundaries = "[$(RPAREN)",
            T1, T2, UniformRandomNumberGenerator)
        (T1 a, T2 b, ref UniformRandomNumberGenerator urng);
else
    CommonType!(T1, T2) uniform(string boundaries = "[)",
            T1, T2, UniformRandomNumberGenerator)
(T1 a, T2 b, ref UniformRandomNumberGenerator urng)
if (is(CommonType!(T1, UniformRandomNumberGenerator) == void) &&
        !is(CommonType!(T1, T2) == void))
{
    alias Unqual!(CommonType!(T1, T2)) NumberType;
    NumberType _a, _b;
    static if (boundaries[0] == '(')
        static if (isIntegral!(NumberType) || is(Unqual!NumberType : dchar))
            _a = a + 1;
        else
            _a = nextafter(a, a.infinity);
    else
        _a = a;
    static if (boundaries[1] == ')')
        static if (isIntegral!(NumberType) || is(Unqual!NumberType : dchar))
        {
            static if (_b.min == 0)
            {
                if (b == 0)
                {
                    // writeln("Invalid distribution range: "
                    //         ~ boundaries[0] ~ to!(string)(a)
                    //         ~ ", " ~ to!(string)(b) ~ boundaries[1]);
                    ++b;
                }
            }
            _b = b - 1;
        }
        else
        {
            static assert(isFloatingPoint!NumberType);
            _b = nextafter(to!NumberType(b), -_b.infinity);
        }
    else
        _b = b;
    enforce(_a <= _b,
            text("Invalid distribution range: ", boundaries[0], a,
                    ", ", b, boundaries[1]));
    static if (isIntegral!(NumberType) || is(Unqual!NumberType : dchar))
    {
        auto myRange = _b - _a;
        if (!myRange) return _a;
        assert(urng.max - urng.min >= myRange,
                "UniformIntGenerator.popFront not implemented"
                " for large ranges");
        Unsigned!(typeof((urng.max - urng.min + 1) / (myRange + 1)))
            bucketSize = 1 + (urng.max - urng.min - myRange) / (myRange + 1);
        //assert(bucketSize, to!(string)(myRange));
        NumberType r;
        do
        {
            r = cast(NumberType) ((urng.front - urng.min) / bucketSize);
            urng.popFront;
        }
        while (r > myRange);
        return cast(typeof(return)) (_a + r);
    }
    else
    {
        static assert(isFloatingPoint!NumberType);
        auto result = _a + (_b - _a) * cast(NumberType) (urng.front - urng.min)
            / (urng.max - urng.min);
        urng.popFront;
        return result;
    }
}

/**
As above, but uses the default generator $(D rndGen).
 */
version(ddoc)
    CommonType!(T1, T2) uniform(string boundaries = "[$(RPAREN)", T1, T2)
        (T1 a, T2 b)  if (!is(CommonType!(T1, T2) == void));
else
CommonType!(T1, T2) uniform(string boundaries = "[)", T1, T2)
(T1 a, T2 b)  if (is(CommonType!(T1, T2)))
{
    return uniform!(boundaries, T1, T2, Random)(a, b, rndGen);
}

unittest
{
    MinstdRand0 gen;
    foreach (i; 0 .. 20)
    {
        auto x = uniform(0., 15., gen);
        assert(0 <= x && x < 15);
        //writeln(x);
    }
    foreach (i; 0 .. 20)
    {
        auto x = uniform!"[]"('a', 'z', gen);
        assert('a' <= x && x <= 'z');
        //writeln(x);
    }
}

unittest
{
    auto gen = Mt19937(unpredictableSeed);
    auto a = uniform(0, 1024, gen);
    assert(0 <= a && a <= 1024);
    auto b = uniform(0.0f, 1.0f, gen);
    assert(0 <= b && b < 1, to!string(b));
    auto c = uniform(0.0, 1.0);
    assert(0 <= c && c < 1);
}

/**
Generates a uniform probability distribution of size $(D n), i.e., an
array of size $(D n) of positive numbers of type $(D F) that sum to
$(D 1). If $(D useThis) is provided, it is used as storage.
 */
F[] uniformDistribution(F = double)(size_t n, F[] useThis = null)
{
    useThis.length = n;
    foreach (ref e; useThis)
    {
        e = uniform(0.0, 1);
    }
    normalize(useThis);
    return useThis;
}

unittest
{
    static assert(is(CommonType!(double, int) == double));
    auto a = uniformDistribution(5);
    enforce(a.length == 5);
    enforce(approxEqual(reduce!"a + b"(a), 1));
    a = uniformDistribution(10, a);
    enforce(a.length == 10);
    enforce(approxEqual(reduce!"a + b"(a), 1));
}

/**
Shuffles elements of $(D r) using $(D r) as a shuffler. $(D r) must be
a random-access range with length.
 */

void randomShuffle(Range, RandomGen = Random)(Range r,
        ref RandomGen gen = rndGen)
{
    foreach (i; 0 .. r.length)
    {
        swap(r[i], r[i + uniform(0, r.length - i, gen)]);
    }
}

unittest
{
    auto a = ([ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]).dup;
    auto b = a.dup;
    Mt19937 gen;
    randomShuffle(a, gen);
    assert(a.sort == b.sort);
    randomShuffle(a);
    assert(a.sort == b.sort);
}

/**
Rolls a dice with relative probabilities stored in $(D
proportions). Returns the index in $(D proportions) that was chosen.

Example:

----
auto x = dice(0.5, 0.5);   // x is 0 or 1 in equal proportions
auto y = dice(50, 50);     // y is 0 or 1 in equal proportions
auto z = dice(70, 20, 10); // z is 0 70% of the time, 1 30% of the time,
                           // and 2 10% of the time
----
*/

size_t dice(R)(ref R rnd, double[] proportions...) {
    invariant sum = reduce!("(assert(b >= 0), a + b)")(0.0, proportions);
    enforce(sum > 0, "Proportions in a dice cannot sum to zero");
    invariant point = uniform(0.0, sum, rnd);
    assert(point < sum);
    auto mass = 0.0;
    foreach (i, e; proportions) {
        mass += e;
        if (point < mass) return i;
    }
    // this point should not be reached
    assert(false);
}

unittest {
    auto rnd = Random(unpredictableSeed);
    auto i = dice(rnd, 0.0, 100.0);
    assert(i == 1);
    i = dice(rnd, 100.0, 0.0);
    assert(i == 0);
}

/**
Covers a given range $(D r) in a random manner, i.e. goes through each
element of $(D r) once and only once, just in a random order. $(D r)
must be a random-access range with length.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
auto rnd = Random(unpredictableSeed);
foreach (e; randomCover(a, rnd))
{
    writeln(e);
}
----
 */
struct RandomCover(Range, Random)
{
    private Range _input;
    private Random _rnd;
    private bool[] _chosen;
    private uint _current;
    private uint _alreadyChosen;

    this(Range input, Random rnd)
    {
        _input = input;
        _rnd = rnd;
        _chosen.length = _input.length;
        popFront;
    }

    static if (hasLength!Range)
        size_t length()
        {
            return (1 + _input.length) - _alreadyChosen;
        }

    ref ElementType!(Range) front()
    {
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
        uint k = _input.length - _alreadyChosen;
        uint i;
        foreach (e; _input)
        {
            if (_chosen[i]) { ++i; continue; }
            // Roll a dice with k faces
            auto chooseMe = uniform(0, k, _rnd) == 0;
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
        assert(false);
    }

    bool empty() { return _alreadyChosen > _input.length; }
}

/// Ditto
RandomCover!(Range, Random) randomCover(Range, Random)(Range r, Random rnd)
{
    return typeof(return)(r, rnd);
}

unittest
{
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
    auto rnd = Random(unpredictableSeed);
    RandomCover!(int[], Random) rc = randomCover(a, rnd);
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

// RandomSample
/**
Selects a random subsample out of $(D r), containing exactly $(D n)
elements. The order of elements is the same as in the original
range. The total length of $(D r) must be known. If $(D total) is
passed in, the total number of sample is considered to be $(D
total). Otherwise, $(D RandomSample) uses $(D r.length).

If the number of elements is not exactly $(D total), $(D
RandomSample) throws an exception. This is because $(D total) is
essential to computing the probability of selecting elements in the
range.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
// Print 5 random elements picked off from r
foreach (e; randomSample(n, 5))
{
    writeln(e);
}
----
 */
struct RandomSample(R)
{
    private size_t _available, _toSelect;
    private R _input;
    private size_t _index;
    private enum bool byRef = is(typeof(&(R.init.front())));

/**
Constructor.
*/
    static if (hasLength!R)
        this(R input, size_t howMany)
        {
            this(input, howMany, input.length);
        }

/// Ditto
    this(R input, size_t howMany, size_t total)
    {
        _input = input;
        _available = total;
        _toSelect = howMany;
        enforce(_toSelect <= _available);
        // we should skip some elements initially so we don't always
        // start with the first
        prime;
    }

/**
   Range primitives.
*/
    bool empty() const
    {
        return _toSelect == 0;
    }

    mixin((byRef ? "ref " : "")~
            q{ElementType!R front()
                {
                    assert(!empty);
                    return _input.front;
                }});

/// Ditto
    void popFront()
    {
        _input.popFront;
        --_available;
        --_toSelect;
        ++_index;
        prime;
    }

/// Ditto
    size_t length()
    {
        return _toSelect;
    }

/**
Returns the index of the visited record.
 */
    size_t index()
    {
        return _index;
    }

    private void prime()
    {
        if (empty) return;
        assert(_available && _available >= _toSelect);
        for (;;)
        {
            auto r = uniform(0, _available);
            if (r < _toSelect)
            {
                // chosen!
                return;
            }
            // not chosen, retry
            assert(!_input.empty);
            _input.popFront;
            ++_index;
            --_available;
            assert(_available > 0);
        }
    }
}

/// Ditto
RandomSample!R randomSample(R)(R r, size_t n, size_t total)
{
    return typeof(return)(r, n, total);
}

/// Ditto
RandomSample!R randomSample(R)(R r, size_t n) //if (hasLength!R) // @@@BUG@@@
{
    return typeof(return)(r, n, r.length);
}

unittest
{
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
    //int[] a = [ 0, 1, 2 ];
    assert(randomSample(a, 5).length == 5);
    uint i;
    foreach (e; randomSample(randomCover(a, rndGen), 5))
    {
        ++i;
        //writeln(e);
    }
    assert(i == 5);
}

//__EOF__
/* ===================== Random ========================= */

// seed and index are deliberately thread local

private uint seed;              // starting seed
private uint index;             // ith random number

/**
The random number generator is seeded at program startup with a random
value.  This ensures that each program generates a different sequence
of random numbers. To generate a repeatable sequence, use $(D
rand_seed()) to start the sequence. seed and index start it, and each
successive value increments index.  This means that the $(I n)th
random number of the sequence can be directly generated by passing
index + $(I n) to $(D rand_seed()).

Note: This is more random, but slower, than C's $(D rand()) function.
To use C's $(D rand()) instead, import $(D std.c.stdlib).

BUGS: Shares a global single state, not multithreaded.  SCHEDULED FOR
DEPRECATION.

*/

void rand_seed(uint seed, uint index)
{
    .seed = seed;
    .index = index;
}

/**
Get the popFront random number in sequence.
BUGS: Shares a global single state, not multithreaded.
SCHEDULED FOR DEPRECATION.
*/

deprecated uint rand()
{
    static uint xormix1[20] =
    [
                0xbaa96887, 0x1e17d32c, 0x03bcdc3c, 0x0f33d1b2,
                0x76a6491d, 0xc570d85d, 0xe382b1e3, 0x78db4362,
                0x7439a9d4, 0x9cea8ac5, 0x89537c5c, 0x2588f55d,
                0x415b5e1d, 0x216e3d95, 0x85c662e7, 0x5e8ab368,
                0x3ea5cc8c, 0xd26a0f74, 0xf3a9222b, 0x48aad7e4
    ];

    static uint xormix2[20] =
    [
                0x4b0f3b58, 0xe874f0c3, 0x6955c5a6, 0x55a7ca46,
                0x4d9a9d86, 0xfe28a195, 0xb1ca7865, 0x6b235751,
                0x9a997a61, 0xaa6e95c8, 0xaaa98ee1, 0x5af9154c,
                0xfc8e2263, 0x390f5e8c, 0x58ffd802, 0xac0a5eba,
                0xac4874f6, 0xa9df0913, 0x86be4c74, 0xed2c123b
    ];

    uint hiword, loword, hihold, temp, itmpl, itmph, i;

    loword = seed;
    hiword = index++;
    for (i = 0; i < 4; i++)             // loop limit can be 2..20, we choose 4
    {
        hihold  = hiword;                           // save hiword for later
        temp    = hihold ^  xormix1[i];             // mix up bits of hiword
        itmpl   = temp   &  0xffff;                 // decompose to hi & lo
        itmph   = temp   >> 16;                     // 16-bit words
        temp    = itmpl * itmpl + ~(itmph * itmph); // do a multiplicative mix
        temp    = (temp >> 16) | (temp << 16);      // swap hi and lo halves
        hiword  = loword ^ ((temp ^ xormix2[i]) + itmpl * itmph); //loword mix
        loword  = hihold;                           // old hiword is loword
    }
    return hiword;
}

shared static this()
{
    ulong s;

    version(Win32)
    {
        QueryPerformanceCounter(&s);
    }
    version(Posix)
    {
        // time.h
        // sys/time.h

        timeval tv;
        if (gettimeofday(&tv, null))
        {   // Some error happened - try time() instead
            s = core.sys.posix.sys.time.time(null);
        }
        else
        {
            s = cast(ulong)((cast(long)tv.tv_sec << 32) + tv.tv_usec);
        }
    }
    //rand_seed(cast(uint) s, cast(uint)(s >> 32));
}


unittest
{
    static uint results[10] =
    [
        0x8c0188cb,
        0xb161200c,
        0xfc904ac5,
        0x2702e049,
        0x9705a923,
        0x1c139d89,
        0x346b6d1f,
        0xf8c33e32,
        0xdb9fef76,
        0xa97fcb3f
    ];
    int i;
    uint seedsave = seed;
    uint indexsave = index;

    rand_seed(1234, 5678);
    for (i = 0; i < 10; i++)
    {   uint r = rand();
        //printf("0x%x,\n", rand());
        assert(r == results[i]);
    }

    seed = seedsave;
    index = indexsave;
}
