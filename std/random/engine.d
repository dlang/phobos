// Written in the D programming language

/**
 * Implements algorithms for uniform pseudo-random number generation.
 * More specifically, the algorithms implemented here provide sources
 * of uniformly-distributed pseudo-random bits.
 *
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Source:    $(PHOBOSSRC std/random/_engine.d)
 */
module std.random.engine;

import std.traits;

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

version(unittest)
{
    static import std.typetuple;
    package alias PseudoRngTypes =
        std.typetuple.TypeTuple!(MinstdRand0, MinstdRand, Mt19937, Xorshift32, Xorshift64,
                                 Xorshift96, Xorshift128, Xorshift160, Xorshift192);
}

/**
Linear Congruential generator.
 */
struct LinearCongruentialEngine(UIntType, UIntType a, UIntType c, UIntType m)
    if(isUnsigned!UIntType)
{
    ///Mark this as a Rng
    enum bool isUniformRandom = true;
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
    private static ulong gcd(ulong a, ulong b) @safe pure nothrow
    {
        while (b)
        {
            auto t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    private static ulong primeFactorsOnly(ulong n) @safe pure nothrow
    {
        ulong result = 1;
        ulong iter = 2;
        for (; n >= iter * iter; iter += 2 - (iter == 2))
        {
            if (n % iter) continue;
            result *= iter;
            do
            {
                n /= iter;
            } while (n % iter == 0);
        }
        return result * n;
    }

    @safe pure nothrow unittest
    {
        static assert(primeFactorsOnly(100) == 10);
        //writeln(primeFactorsOnly(11));
        static assert(primeFactorsOnly(11) == 11);
        static assert(primeFactorsOnly(7 * 7 * 7 * 11 * 15 * 11) == 7 * 11 * 15);
        static assert(primeFactorsOnly(129 * 2) == 129 * 2);
        // enum x = primeFactorsOnly(7 * 7 * 7 * 11 * 15);
        // static assert(x == 7 * 11 * 15);
    }

    private static bool properLinearCongruentialParameters(ulong m,
            ulong a, ulong c) @safe pure nothrow
    {
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
    this(UIntType x0) @safe pure
    {
        seed(x0);
    }

/**
   (Re)seeds the generator.
*/
    void seed(UIntType x0 = 1) @safe pure
    {
        static if (c == 0)
        {
            import std.exception : enforce;
            enforce(x0, "Invalid (zero) seed for "
                    ~ LinearCongruentialEngine.stringof);
        }
        _x = modulus ? (x0 % modulus) : x0;
        popFront();
    }

/**
   Advances the random sequence.
*/
    void popFront() @safe pure nothrow
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
    @property UIntType front() const @safe pure nothrow
    {
        return _x;
    }

///
    @property typeof(this) save() @safe pure nothrow
    {
        return this;
    }

/**
Always $(D false) (random generators are infinite ranges).
 */
    enum bool empty = false;

/**
   Compares against $(D_PARAM rhs) for equality.
 */
    bool opEquals(ref const LinearCongruentialEngine rhs) const @safe pure nothrow
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
alias MinstdRand0 = LinearCongruentialEngine!(uint, 16807, 0, 2147483647);
/// ditto
alias MinstdRand = LinearCongruentialEngine!(uint, 48271, 0, 2147483647);

unittest
{
    import std.random.device : unpredictableSeed;
    import std.random.traits;
    import std.range;
    static assert(isForwardRange!MinstdRand);
    static assert(isUniformRNG!MinstdRand);
    static assert(isUniformRNG!MinstdRand0);
    static assert(isUniformRNG!(MinstdRand, uint));
    static assert(isUniformRNG!(MinstdRand0, uint));
    static assert(isSeedable!MinstdRand);
    static assert(isSeedable!MinstdRand0);
    static assert(isSeedable!(MinstdRand, uint));
    static assert(isSeedable!(MinstdRand0, uint));

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
        rnd0.popFront();
    }
    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd0.seed();
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
        rnd.popFront();
    }

    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd.seed();
    popFrontN(rnd, 9999);
    assert(rnd.front == 399268537);

    // Check .save works
    foreach (Type; std.typetuple.TypeTuple!(MinstdRand0, MinstdRand))
    {
        auto rnd1 = Type(unpredictableSeed);
        auto rnd2 = rnd1.save;
        assert(rnd1 == rnd2);
        // Enable next test when RNGs are reference types
        version(none) { assert(rnd1 !is rnd2); }
        assert(rnd1.take(100).array() == rnd2.take(100).array());
    }
}

/**
The $(LUCKY Mersenne Twister) generator.
 */
struct MersenneTwisterEngine(UIntType, size_t w, size_t n, size_t m, size_t r,
                             UIntType a, size_t u, size_t s,
                             UIntType b, size_t t,
                             UIntType c, size_t l)
    if(isUnsigned!UIntType)
{
    import std.range.primitives;

    static assert(0 < w && w <= UIntType.sizeof * 8);
    static assert(1 <= m && m <= n);
    static assert(0 <= r && 0 <= u && 0 <= s && 0 <= t && 0 <= l);
    static assert(r <= w && u <= w && s <= w && t <= w && l <= w);
    static assert(0 <= a && 0 <= b && 0 <= c);

    ///Mark this as a Rng
    enum bool isUniformRandom = true;

/**
Parameters for the generator.
*/
    enum size_t   wordSize   = w;
    enum size_t   stateSize  = n; /// ditto
    enum size_t   shiftSize  = m; /// ditto
    enum size_t   maskBits   = r; /// ditto
    enum UIntType xorMask    = a; /// ditto
    enum UIntType temperingU = u; /// ditto
    enum size_t   temperingS = s; /// ditto
    enum UIntType temperingB = b; /// ditto
    enum size_t   temperingT = t; /// ditto
    enum UIntType temperingC = c; /// ditto
    enum size_t   temperingL = l; /// ditto

    /// Smallest generated value (0).
    enum UIntType min = 0;
    /// Largest generated value.
    enum UIntType max = UIntType.max >> (UIntType.sizeof * 8u - w);
    static assert(a <= max && b <= max && c <= max);
    /// The default seed value.
    enum UIntType defaultSeed = 5489u;

/**
   Constructs a MersenneTwisterEngine object.
*/
    this(UIntType value) @safe pure nothrow
    {
        seed(value);
    }

/**
   Seeds a MersenneTwisterEngine object.
   Note:
   This seed function gives 2^32 starting points. To allow the RNG to be started in any one of its
   internal states use the seed overload taking an InputRange.
*/
    void seed()(UIntType value = defaultSeed) @safe pure nothrow
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
        for (mti = 1; mti < n; ++mti)
        {
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
        popFront();
    }

/**
   Seeds a MersenneTwisterEngine object using an InputRange.

   Throws:
   $(D Exception) if the InputRange didn't provide enough elements to seed the generator.
   The number of elements required is the 'n' template parameter of the MersenneTwisterEngine struct.

   Examples:
   ----------------
   Mt19937 gen;
   gen.seed(map!((a) => unpredictableSeed)(repeat(0)));
   ----------------
 */
    void seed(T)(T range) if(isInputRange!T && is(Unqual!(ElementType!T) == UIntType))
    {
        size_t j;
        for(j = 0; j < n && !range.empty; ++j, range.popFront())
        {
            mt[j] = range.front;
        }

        mti = n;
        if(range.empty && j < n)
        {
            import std.format : format;
            throw new Exception(format("MersenneTwisterEngine.seed: Input range didn't provide enough"~
                " elements: Need %s elemnets.", n));
        }

        popFront();
    }

/**
   Advances the generator.
*/
    void popFront() @safe pure nothrow
    {
        if (mti == size_t.max) seed();
        enum UIntType
            upperMask = ~((cast(UIntType) 1u <<
                           (UIntType.sizeof * 8 - (w - r))) - 1),
            lowerMask = (cast(UIntType) 1u << r) - 1;
        static immutable UIntType[2] mag01 = [0x0UL, a];

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
    @property UIntType front() @safe pure nothrow
    {
        if (mti == size_t.max) seed();
        return _y;
    }

///
    @property typeof(this) save() @safe pure nothrow
    {
        return this;
    }

/**
Always $(D false).
 */
    enum bool empty = false;

    private UIntType[n] mt;
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
alias Mt19937 = MersenneTwisterEngine!(uint, 32, 624, 397, 31,
                                       0x9908b0df, 11, 7,
                                       0x9d2c5680, 15,
                                       0xefc60000, 18);

nothrow unittest
{
    import std.algorithm;
    import std.random.device : unpredictableSeed;
    import std.random.traits;
    import std.range;
    static assert(isUniformRNG!Mt19937);
    static assert(isUniformRNG!(Mt19937, uint));
    static assert(isSeedable!Mt19937);
    static assert(isSeedable!(Mt19937, uint));
    static assert(isSeedable!(Mt19937, typeof(map!((a) => unpredictableSeed)(repeat(0)))));
    Mt19937 gen;
    popFrontN(gen, 9999);
    assert(gen.front == 4123659995);
}

unittest
{
    import std.exception;
    import std.random.device : unpredictableSeed;
    import std.range;
    import std.algorithm;

    Mt19937 gen;

    assertThrown(gen.seed(map!((a) => unpredictableSeed)(repeat(0, 623))));

    gen.seed(map!((a) => unpredictableSeed)(repeat(0, 624)));
    //infinite Range
    gen.seed(map!((a) => unpredictableSeed)(repeat(0)));
}

@safe pure nothrow unittest
{
    uint a, b;
    {
        Mt19937 gen;
        a = gen.front;
    }
    {
        Mt19937 gen;
        gen.popFront();
        //popFrontN(gen, 1);  // skip 1 element
        b = gen.front;
    }
    assert(a != b);
}

unittest
{
    import std.random.device : unpredictableSeed;
    import std.range;
    // Check .save works
    foreach(Type; std.typetuple.TypeTuple!(Mt19937))
    {
        auto gen1 = Type(unpredictableSeed);
        auto gen2 = gen1.save;
        assert(gen1 == gen2);  // Danger, Will Robinson -- no opEquals for MT
        // Enable next test when RNGs are reference types
        version(none) { assert(gen1 !is gen2); }
        assert(gen1.take(100).array() == gen2.take(100).array());
    }
}

@safe pure nothrow unittest //11690
{
    alias MT(UIntType, uint w) = MersenneTwisterEngine!(UIntType, w, 624, 397, 31,
                                                        0x9908b0df, 11, 7,
                                                        0x9d2c5680, 15,
                                                        0xefc60000, 18);

    foreach (R; std.typetuple.TypeTuple!(MT!(uint, 32), MT!(ulong, 32), MT!(ulong, 48), MT!(ulong, 64)))
        auto a = R();
}


/**
 * Xorshift generator using 32bit algorithm.
 *
 * Implemented according to $(WEB www.jstatsoft.org/v08/i14/paper, Xorshift RNGs).
 *
 * $(BOOKTABLE $(TEXTWITHCOMMAS Supporting bits are below, $(D bits) means second parameter of XorshiftEngine.),
 *  $(TR $(TH bits) $(TH period))
 *  $(TR $(TD 32)   $(TD 2^32 - 1))
 *  $(TR $(TD 64)   $(TD 2^64 - 1))
 *  $(TR $(TD 96)   $(TD 2^96 - 1))
 *  $(TR $(TD 128)  $(TD 2^128 - 1))
 *  $(TR $(TD 160)  $(TD 2^160 - 1))
 *  $(TR $(TD 192)  $(TD 2^192 - 2^32))
 * )
 */
struct XorshiftEngine(UIntType, UIntType bits, UIntType a, UIntType b, UIntType c)
    if(isUnsigned!UIntType)
{
    static assert(bits == 32 || bits == 64 || bits == 96 || bits == 128 || bits == 160 || bits == 192,
                  "Xorshift supports only 32, 64, 96, 128, 160 and 192 bit versions. "
                  ~ to!string(bits) ~ " is not supported.");

  public:
    ///Mark this as a Rng
    enum bool isUniformRandom = true;
    /// Always $(D false) (random generators are infinite ranges).
    enum empty = false;
    /// Smallest generated value.
    enum UIntType min = 0;
    /// Largest generated value.
    enum UIntType max = UIntType.max;


  private:
    enum size = bits / 32;

    static if (bits == 32)
        UIntType[size] seeds_ = [2463534242];
    else static if (bits == 64)
        UIntType[size] seeds_ = [123456789, 362436069];
    else static if (bits == 96)
        UIntType[size] seeds_ = [123456789, 362436069, 521288629];
    else static if (bits == 128)
        UIntType[size] seeds_ = [123456789, 362436069, 521288629, 88675123];
    else static if (bits == 160)
        UIntType[size] seeds_ = [123456789, 362436069, 521288629, 88675123, 5783321];
    else static if (bits == 192)
    {
        UIntType[size] seeds_ = [123456789, 362436069, 521288629, 88675123, 5783321, 6615241];
        UIntType       value_;
    }
    else
    {
        static assert(false, "Phobos Error: Xorshift has no instantiation rule for "
                             ~ to!string(bits) ~ " bits.");
    }


  public:
    /**
     * Constructs a $(D XorshiftEngine) generator seeded with $(D_PARAM x0).
     */
    @safe
    nothrow this(UIntType x0) pure
    {
        seed(x0);
    }


    /**
     * (Re)seeds the generator.
     */
    @safe
    nothrow void seed(UIntType x0) pure
    {
        // Initialization routine from MersenneTwisterEngine.
        foreach (i, e; seeds_)
            seeds_[i] = x0 = cast(UIntType)(1812433253U * (x0 ^ (x0 >> 30)) + i + 1);

        // All seeds must not be 0.
        sanitizeSeeds(seeds_);

        popFront();
    }


    /**
     * Returns the current number in the random sequence.
     */
    @property @safe
    nothrow UIntType front() const pure
    {
        static if (bits == 192)
            return value_;
        else
            return seeds_[size - 1];
    }


    /**
     * Advances the random sequence.
     */
    @safe
    nothrow void popFront() pure
    {
        UIntType temp;

        static if (bits == 32)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            temp      = temp ^ (temp >> b);
            seeds_[0] = temp ^ (temp << c);
        }
        else static if (bits == 64)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[1] ^ (seeds_[1] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 96)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[2] ^ (seeds_[2] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 128)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[3];
            seeds_[3] = seeds_[3] ^ (seeds_[3] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 160)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[3];
            seeds_[3] = seeds_[4];
            seeds_[4] = seeds_[4] ^ (seeds_[4] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 192)
        {
            temp      = seeds_[0] ^ (seeds_[0] >> a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[3];
            seeds_[3] = seeds_[4];
            seeds_[4] = seeds_[4] ^ (seeds_[4] << c) ^ temp ^ (temp << b);
            value_    = seeds_[4] + (seeds_[5] += 362437);
        }
        else
        {
            static assert(false, "Phobos Error: Xorshift has no popFront() update for "
                                 ~ to!string(bits) ~ " bits.");
        }
    }


    /**
     * Captures a range state.
     */
    @property @safe
    nothrow typeof(this) save() pure
    {
        return this;
    }


    /**
     * Compares against $(D_PARAM rhs) for equality.
     */
    @safe
    nothrow bool opEquals(ref const XorshiftEngine rhs) const pure
    {
        return seeds_ == rhs.seeds_;
    }


  private:
    @safe
    static nothrow void sanitizeSeeds(ref UIntType[size] seeds) pure
    {
        for (uint i; i < seeds.length; i++)
        {
            if (seeds[i] == 0)
                seeds[i] = i + 1;
        }
    }


    @safe pure nothrow unittest
    {
        static if (size  ==  4)  // Other bits too
        {
            UIntType[size] seeds = [1, 0, 0, 4];

            sanitizeSeeds(seeds);

            assert(seeds == [1, 2, 3, 4]);
        }
    }
}


/**
 * Define $(D XorshiftEngine) generators with well-chosen parameters. See each bits examples of "Xorshift RNGs".
 * $(D Xorshift) is a Xorshift128's alias because 128bits implementation is mostly used.
 *
 * Example:
 * -----
 * // Seed with a constant
 * auto rnd = Xorshift(1);
 * auto num = rnd.front;  // same for each run
 *
 * // Seed with an unpredictable value
 * rnd.seed(unpredictableSeed());
 * num = rnd.front; // different across runs
 * -----
 */
alias Xorshift32  = XorshiftEngine!(uint, 32,  13, 17, 15) ;
alias Xorshift64  = XorshiftEngine!(uint, 64,  10, 13, 10); /// ditto
alias Xorshift96  = XorshiftEngine!(uint, 96,  10, 5,  26); /// ditto
alias Xorshift128 = XorshiftEngine!(uint, 128, 11, 8,  19); /// ditto
alias Xorshift160 = XorshiftEngine!(uint, 160, 2,  1,  4);  /// ditto
alias Xorshift192 = XorshiftEngine!(uint, 192, 2,  1,  4);  /// ditto
alias Xorshift    = Xorshift128;                            /// ditto


unittest
{
    import std.random.device : unpredictableSeed;
    import std.random.traits;
    import std.range;
    static assert(isForwardRange!Xorshift);
    static assert(isUniformRNG!Xorshift);
    static assert(isUniformRNG!(Xorshift, uint));
    static assert(isSeedable!Xorshift);
    static assert(isSeedable!(Xorshift, uint));

    // Result from reference implementation.
    auto checking = [
        [2463534242UL, 901999875, 3371835698, 2675058524, 1053936272, 3811264849, 472493137, 3856898176, 2131710969, 2312157505],
        [362436069UL, 2113136921, 19051112, 3010520417, 951284840, 1213972223, 3173832558, 2611145638, 2515869689, 2245824891],
        [521288629UL, 1950277231, 185954712, 1582725458, 3580567609, 2303633688, 2394948066, 4108622809, 1116800180, 3357585673],
        [88675123UL, 3701687786, 458299110, 2500872618, 3633119408, 516391518, 2377269574, 2599949379, 717229868, 137866584],
        [5783321UL, 393427209, 1947109840, 565829276, 1006220149, 971147905, 1436324242, 2800460115, 1484058076, 3823330032],
        [0UL, 246875399, 3690007200, 1264581005, 3906711041, 1866187943, 2481925219, 2464530826, 1604040631, 3653403911]
    ];

    alias XorshiftTypes = std.typetuple.TypeTuple!(Xorshift32, Xorshift64, Xorshift96, Xorshift128, Xorshift160, Xorshift192);

    foreach (I, Type; XorshiftTypes)
    {
        Type rnd;

        foreach (e; checking[I])
        {
            assert(rnd.front == e);
            rnd.popFront();
        }
    }

    // Check .save works
    foreach (Type; XorshiftTypes)
    {
        auto rnd1 = Type(unpredictableSeed);
        auto rnd2 = rnd1.save;
        assert(rnd1 == rnd2);
        // Enable next test when RNGs are reference types
        version(none) { assert(rnd1 !is rnd2); }
        assert(rnd1.take(100).array() == rnd2.take(100).array());
    }
}


/* A complete list of all pseudo-random number generators implemented in
 * std.random.  This can be used to confirm that a given function or
 * object is compatible with all the pseudo-random number generators
 * available.  It is enabled only in unittest mode.
 *
 * Example:
 *
 * ----
 * foreach(Rng; PseudoRngTypes)
 * {
 *     static assert(isUniformRng!Rng);
 *     auto rng = Rng(unpredictableSeed);
 *     foo(rng);
 * }
 * ----
 */

unittest
{
    import std.random.traits;
    foreach(Rng; PseudoRngTypes)
    {
        static assert(isUniformRNG!Rng);
    }
}


/**
The "default", "favorite", "suggested" random number generator type on
the current platform. It is an alias for one of the previously-defined
generators. You may want to use it if (1) you need to generate some
nice random numbers, and (2) you don't care for the minutiae of the
method being used.
 */

alias Random = Mt19937;

unittest
{
    import std.random.traits;
    static assert(isUniformRNG!Random);
    static assert(isUniformRNG!(Random, uint));
    static assert(isSeedable!Random);
    static assert(isSeedable!(Random, uint));
}

/**
Global random number generator used by various functions in this
module whenever no generator is specified. It is allocated per-thread
and initialized to an unpredictable value for each thread.

Returns:
A singleton instance of the default random number generator
 */
@property ref Random rndGen() @safe
{
    import std.algorithm : map;
    import std.random.device : unpredictableSeed;
    import std.random.traits;
    import std.range : repeat;

    static Random result;
    static bool initialized;
    if (!initialized)
    {
        static if(isSeedable!(Random, typeof(map!((a) => unpredictableSeed)(repeat(0)))))
            result.seed(map!((a) => unpredictableSeed)(repeat(0)));
        else
            result = Random(unpredictableSeed);
        initialized = true;
    }
    return result;
}
