// Written in the D programming language

/**
   Facilities for random number generation. The old-style functions
   $(D_PARAM rand_seed) and $(D_PARAM rand) will soon be deprecated as
   they rely on global state and as such are subjected to various
   thread-related issues.

   The new-style generator objects hold their own state so they are
   immune of threading issues. The generators feature a number of
   well-known and well-documented methods of generating random
   numbers. An overall fast and reliable means to generate random
   numbers is the $(D_PARAM Mt19937) generator, which derives its name
   from "$(LINK2 http://math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html,
   Mersenne Twister) with a period of 2 to the power of 19937". In
   memory-constrained situations,
   $(LINK2 http://en.wikipedia.org/wiki/Linear_congruential_generator,
   linear congruential) generators such as MinstdRand0 and MinstdRand
   might be useful. The standard library provides an alias $(D_PARAM
   Random) for whichever generator it finds the most fit for the
   target environment.
   
   Example:

----
Random gen;
// Generate a uniformly-distributed integer in the range [0, 15]
auto i = uniform!(int)(gen, 0, 15);
// Generate a uniformly-distributed real in the range [0, 100$(RPAREN)
auto r = uniform!(real)(gen, 0.0L, 100.0L);
----

In addition to random number generators, this module features
distributions, which skew a generator's output statistical
distribution in various ways. So far the uniform distribution for
integers and real numbers have been implemented.

Author:

Andrei Alexandrescu

Credits:

The entire random number library architecture is derived from the
excellent
$(LINK2 http://open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf,
C++0X) random number facility proposed by Jens Maurer and contrinuted
to by researchers at the Fermi laboratory.

Macros:

WIKI = Phobos/StdRandom
*/

// random.d
// www.digitalmars.com

module std.random;

import std.stdio, std.math, std.c.time, std.traits, std.contracts, std.conv,
    std.algorithm, std.process, std.date;

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

version (linux)
{
    private import std.c.linux.linux;
}

/**
   Linear Congruential generator.
*/

struct LinearCongruentialEngine(UIntType, UIntType a, UIntType c, UIntType m)
{
/// Alias for the generated type $(D_PARAM UIntType).
    alias UIntType ResultType;
    static invariant
    {
        /// Does this generator have a fixed range? ($(D_PARAM true)).
        bool hasFixedRange = true;
        /// Lowest generated value.
        ResultType min = ( c == 0 ? 1 : 0 );
        /// Highest generated value.
        ResultType max = m - 1;
/**
   The parameters of this distribution. The random number is $(D_PARAM x =
        (x * a + c) % m).
*/
        UIntType
            multiplier = a,
            ///ditto
            increment = c,
            ///ditto
            modulus = m;
    }
    
    static assert(isIntegral!(UIntType));
    static assert(m == 0 || a < m);
    static assert(m == 0 || c < m);
    static assert(m == 0 ||
                  (cast(ulong)a * (m-1) + c) % m == (c < a ? c - a + m : c - a));

/**
     Constructs a $(D_PARAM LinearCongruentialEngine) generator.
*/
    static LinearCongruentialEngine opCall(UIntType x0 = 1)
    {
        LinearCongruentialEngine result;
        result.seed(x0);
        return result;
    }

/**
   (Re)seeds the generator.
*/
    void seed(UIntType x0 = 1)
    {
        static if (c == 0)
        {
            enforce(x0, "Invalid (zero) seed for "
                    ~LinearCongruentialEngine.stringof);
        }
        _x = modulus ? (x0 % modulus) : x0;
    }

/**
   Returns the next number in the random sequence.
*/
    UIntType next()
    {
        static if (m) 
            _x = (cast(ulong) a * _x + c) % m;
        else
            _x = a * _x + c;
        return _x;
    }

/**
   Discards next $(D_PARAM n) samples.
*/
    void discard(ulong n)
    {
        while (n--) next;
    }

/**
   Compares against $(D_PARAM rhs) for equality.
*/
    bool opEquals(LinearCongruentialEngine rhs)
    {
        return _x == rhs._x;
    }
    
    private UIntType _x = 1;
};

/**
   Define $(D_PARAM LinearCongruentialEngine) generators with "good"
   parameters.

   Example:

   ----
   // seed with a constant
   auto rnd0 = MinstdRand0(1);
   auto n = rnd0.next; // same for each run
   // Seed with an unpredictable value
   rnd0.seed(unpredictableSeed);
   n = rnd0.next; // different across runs
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
    auto rnd0 = MinstdRand0(1);
    foreach (e; checking0)
    {
        assert(rnd0.next == e);
    }
    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd0.seed;
    rnd0.discard(9999);
    assert(rnd0.next == 1043618065);

    // Test MinstdRand
    auto checking = [48271UL,182605794,1291394886,1914720637,2078669041,
                     407355683];
    auto rnd = MinstdRand(1);
    foreach (e; checking)
    {
        assert(rnd.next == e);
    }

    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd.seed;
    rnd.discard(9999);
    assert(rnd.next == 399268537);
}

/**
   The $(LINK2 http://math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html,
   Mersenne Twister generator).
*/
struct MersenneTwisterEngine(
    UIntType, size_t w, size_t n, size_t m, size_t r,
    UIntType a, size_t u, size_t s,
    UIntType b, size_t t,
    UIntType c, size_t l)
{
/// Result type (an alias for $(D_PARAM UIntType)).
    alias UIntType ResultType;

/**
   Parameter for the generator.
*/
    static invariant
    {
        size_t wordSize = w;
        size_t stateSize = n;
        size_t shiftSize = m;
        size_t maskBits = r;
        UIntType xorMask = a;
        UIntType temperingU = u;
        size_t temperingS = s;
        UIntType temperingB = b;
        size_t temperingT = t;
        UIntType temperingC = c;
        size_t temperingL = l;
    }

    /// Smallest generated value (0).
    static invariant UIntType min = 0;
    /// Largest generated value.
    static invariant UIntType max =
        w == UIntType.sizeof * 8 ? UIntType.max : (1u << w) - 1;
    /// The default seed value.
    static invariant UIntType defaultSeed = 5489u;

    static assert(1 <= m && m <= n);
    static assert(0 <= r && 0 <= u && 0 <= s && 0 <= t && 0 <= l);
    static assert(r <= w && u <= w && s <= w && t <= w && l <= w);
    static assert(0 <= a && 0 <= b && 0 <= c);
    static assert(a <= max && b <= max && c <= max);

/**
   Constructs a MersenneTwisterEngine object
*/
    static MersenneTwisterEngine opCall(ResultType value)
    {
        MersenneTwisterEngine result;
        result.seed(value);
        return result;
    }
    
/**
   Constructs a MersenneTwisterEngine object
*/
    void seed(ResultType value = defaultSeed)
    {
        static if (w == ResultType.sizeof * 8)
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
                (1812433253UL * (mt[mti-1] ^ (mt[mti-1] >> (w - 2))) + mti); 
            /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
            /* In the previous versions, MSBs of the seed affect   */
            /* only MSBs of the array mt[].                        */
            /* 2002/01/09 modified by Makoto Matsumoto             */
            mt[mti] &= ResultType.max;
            /* for >32 bit machines */
        }
    }

/**
   Returns the next random value.
*/
    uint next()
    {
        static invariant ResultType
            upperMask = ~((cast(ResultType) 1u <<
                           (ResultType.sizeof * 8 - (w - r))) - 1),
            lowerMask = (cast(ResultType) 1u << r) - 1;

        ulong y = void;
        static invariant ResultType mag01[2] = [0x0UL, a];

        if (mti >= n)
        {
            /* generate N words at one time */
            if (mti == n + 1)   /* if init_genrand() has not been called, */
                seed(5489UL); /* a default initial seed is used */
            
            int kk = 0;            
            for (; kk < n - m; ++kk)
            {
                y = (mt[kk] & upperMask)|(mt[kk + 1] & lowerMask);
                mt[kk] = mt[kk + m] ^ (y >> 1) ^ mag01[y & 0x1UL];
            }
            for (; kk < n - 1; ++kk)
            {
                y = (mt[kk] & upperMask)|(mt[kk + 1] & lowerMask);
                mt[kk] = mt[kk + (m -n)] ^ (y >> 1) ^ mag01[y & 0x1UL];
            }
            y = (mt[n -1] & upperMask)|(mt[0] & lowerMask);
            mt[n - 1] = mt[m - 1] ^ (y >> 1) ^ mag01[y & 0x1UL];
            
            mti = 0;
        }
        
        y = mt[mti++];
        
        /* Tempering */
        y ^= (y >> temperingU);
        y ^= (y << temperingS) & temperingB;
        y ^= (y << temperingT) & temperingC;
        y ^= (y >> temperingL);
        
        return y;
    }

/**
   Discards next $(D_PARAM n) samples.
*/
    void discard(ulong n)
    {
        while (n--) next;
    }

    private ResultType mt[n];
    private size_t mti = n + 1; /* means mt is not initialized */
}

/**
   A $(D_PARAM MersenneTwisterEngine) instantiated with the parameters
   of the original engine
   $(LINK2 http://math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html,MT19937),
   generating uniformly-distributed 32-bit numbers with a period of 2
   to the power of 19937. Recommended for random number generation
   unless memory is severely restricted, in which case a $(D_PARAM
   LinearCongruentialEngine) would be the generator of choice.

   Example:

   ----
   // seed with a constant
   Mt19937 gen;
   auto n = gen.next; // same for each run
   // Seed with an unpredictable value
   gen.seed(unpredictableSeed);
   n = gen.next; // different across runs
   ----
 */
alias MersenneTwisterEngine!(uint, 32, 624, 397, 31, 0x9908b0df, 11, 7,
                             0x9d2c5680, 15, 0xefc60000, 18)
    Mt19937;

unittest
{
    Mt19937 gen;
    gen.discard(9999);
    assert(gen.next == 4123659995);
}

/**
   The "default", "favorite", "suggested" random number generator on
   the current platform. It is a typedef for one of the
   previously-defined generators. You may want to use it if (1) you
   need to generate some nice random numbers, and (2) you don't care
   for the minutiae of the method being used.
 */

typedef Mt19937 Random;

/**
   A "good" seed for initializing random number engines. Initializing
   with $(D_PARAM unpredictableSeed) makes engines generate different
   random number sequences every run.

   Example:

----
auto rnd = Random(unpredictableSeed);
auto n = rnd.next;
...
----   
*/

ulong unpredictableSeed()
{
    return cast(ulong) (getpid ^ getUTCtime);
}

/**
   Generates uniformly-distributed numbers within a range using an
   external generator. The $(D_PARAM leftLim) and $(D_PARAM rightLim)
   parameters control the shape of the interval (open vs. closed on
   either side). The default interval is [a, b$(RPAREN).

   Example:

----
auto a = new double[20];
Random gen;
auto rndIndex = UniformDistribution!(uint)(0, a.length);
auto rndValue = UniformDistribution!(double)(0, 1);
// Get a random index into the array
auto i = rndIndex.next(gen);
// Get a random probability, i.e., a real number in [0, 1$(RPAREN)
auto p = rndValue.next(gen);
// Assign that value to that array element
a[i] = p;
auto digits = UniformDistribution!(char, '[', ']')('0', '9');
auto percentages = UniformDistribution!(double, '$(LPAREN)', ']')(0.0, 100.0);
// Get a digit in ['0', '9']
auto digit = digits.next(gen); 
// Get a number in $(LPAREN)0.0, 100.0]
auto p = percentages.next(gen);
----
 */
struct UniformDistribution(NumberType, char leftLim = '[', char rightLim = ')')
{
    static assert((leftLim == '[' || leftLim == '(')
                  && (rightLim == ']' || rightLim == ')'));

    alias NumberType InputType;
    alias NumberType ResultType;
/**
   Constructs a $(D_PARAM UniformDistribution) able to generate
   numbers in the interval [$(D_PARAM min), $(D_PARAM max)) if
   $(D_PARAM closedRight) is $(D_PARAM false).
*/
    static UniformDistribution opCall(NumberType a, NumberType b)
    {
        UniformDistribution result;
        static if (leftLim == '(')
            result._a = nextLarger(a);
        else
            result._a = a;
        static if (rightLim == ')')
            result._b = nextSmaller(b);
        else
            result._b = b;
        enforce(result._a <= result._b,
                "Invalid distribution range: " ~ leftLim ~ to!(string)(a)
                ~ ", " ~ to!(string)(b) ~ rightLim);
        return result;
    }
/**
   Returns the smallest random value generated.
*/
    ResultType a() { return leftLim == '[' ? _a : nextSmaller(_a); }

/**
   Returns the largest random value generated.
*/ 
    ResultType b() { return rightLim == ']' ? _b : nextLarger(_b); }

/**
   Does nothing (provided for conformity with other distributions).
*/
    void reset()
    {
    }

/**
   Returns a random number using $(D_PARAM
   UniformRandomNumberGenerator) as back-end.
*/
    ResultType next(UniformRandomNumberGenerator)
        (ref UniformRandomNumberGenerator urng)
    {
        static if (isIntegral!(NumberType))
        {
            auto myRange = _b - _a;
            if (!myRange) return _a;
            assert(urng.max - urng.min >= myRange,
                   "UniformIntGenerator.next not implemented for large ranges");
            unsigned!(typeof((urng.max - urng.min + 1) / (myRange + 1)))
                bucketSize = 1 + (urng.max - urng.min - myRange) / (myRange + 1);
            assert(bucketSize, to!(string)(myRange));
            ResultType r = void;
            do
            {
                r = (urng.next - urng.min) / bucketSize;
            }
            while (r > myRange);
            return _a + r;
        }
        else
        {
            return _a + (_b - _a) * cast(NumberType) (urng.next - urng.min)
                / (urng.max - urng.min);
        }
    }
    
private:    
    NumberType _a = 0, _b = NumberType.max;

    static NumberType nextLarger(NumberType x)
    {
        static if (isIntegral!(NumberType))
            return x + 1;
        else
            return nextafter(x, x.infinity);
    }

    static NumberType nextSmaller(NumberType x)
    {
        static if (isIntegral!(NumberType))
            return x - 1;
        else
            return nextafter(x, -x.infinity);
    }
}

unittest
{
    MinstdRand0 gen;
    auto rnd1 = UniformDistribution!(int)(0, 15);
    foreach (i; 0 .. 20)
    {
        auto x = rnd1.next(gen);
        assert(0 <= x && x <= 15);
        //writeln(x);
    }
}

unittest
{
    MinstdRand0 gen;
    foreach (i; 0 .. 20)
    {
        auto x = uniform!(double)(gen, 0., 15.);
        assert(0 <= x && x <= 15);
        //writeln(x);
    }
}

/**
   Convenience function that generates a number in an interval by
   forwarding to $(D_PARAM UniformDistribution!(T, leftLim,
   rightLim)(a, b).next).
   
   Example:

----
Random gen(unpredictableSeed);
// Generate an integer in [0, 1024]
auto a = uniform!(int)(gen, 0, 1024);
// Generate a float in [0, 1$(RPAREN)
auto a = uniform!(float)(gen, 0.0f, 1.0f);
----
*/

template uniform(T, char leftLim = '[', char rightLim = ')')
{
    T uniform(UniformRandomNumberGenerator)
        (ref UniformRandomNumberGenerator gen, T a, T b)
    {
        auto dist = UniformDistribution!(T, leftLim, rightLim)(a, b);
        return dist.next(gen);
    }
}

unittest
{
    auto gen = Mt19937(unpredictableSeed);
    auto a = uniform!(int)(gen, 0, 1024);
    assert(0 <= a && a <= 1024);
    auto b = uniform!(float)(gen, 0.0f, 1.0f);
    assert(0 <= b && b < 1, to!(string)(b));
}

/**
   Shuffles elements of $(D_PARAM array) using $(D_PARAM r) as a
   shuffler.
*/

void randomShuffle(T, SomeRandomGen)(T[] array, ref SomeRandomGen r)
{
    foreach (i; 0 .. array.length)
    {
        // generate a random number i .. n
	auto which = i + uniform!(size_t)(r, 0u, array.length - i);
        swap(array[i], array[which]);
    }
}

unittest
{
    auto a = ([ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]).dup;
    auto b = a.dup;
    Mt19937 gen;
    randomShuffle(a, gen);
    //assert(a == expectedA);
    assert(a.sort == b.sort);
}

/* ===================== Random ========================= */

// BUG: not multithreaded

private uint seed;		// starting seed
private uint index;		// ith random number

/**
 * The random number generator is seeded at program startup with a random value.
 This ensures that each program generates a different sequence of random
 numbers. To generate a repeatable sequence, use rand_seed() to start the
 sequence. seed and index start it, and each successive value increments index.
 This means that the $(I n)th random number of the sequence can be directly
 generated
 by passing index + $(I n) to rand_seed().

 Note: This is more random, but slower, than C's rand() function.
 To use C's rand() instead, import std.c.stdlib.
 
 BUGS: Shares a global single state, not multithreaded.
 SCHEDULED FOR DEPRECATION.
*/

void rand_seed(uint seed, uint index)
{
     .seed = seed;
     .index = index;
}

/**
 * Get the next random number in sequence.
 * BUGS: Shares a global single state, not multithreaded.
 * SCHEDULED FOR DEPRECATION.
 */

uint rand()
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
    for (i = 0; i < 4; i++)		// loop limit can be 2..20, we choose 4
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

static this()
{
    ulong s;

    version(Win32)
    {
	QueryPerformanceCounter(&s);
    }
    version(linux)
    {
	// time.h
	// sys/time.h

	timeval tv;

	if (gettimeofday(&tv, null))
	{   // Some error happened - try time() instead
	    s = std.c.linux.linux.time(null);
	}
	else
	{
	    s = cast(ulong)((cast(long)tv.tv_sec << 32) + tv.tv_usec);
	}
    }
    rand_seed(cast(uint) s, cast(uint)(s >> 32));
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
    {	uint r = rand();
	//printf("0x%x,\n", rand());
	assert(r == results[i]);
    }

    seed = seedsave;
    index = indexsave;
}
