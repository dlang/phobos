// Written in the D programming language.
/**
<script type="text/javascript">inhibitQuickIndex = 1</script>

$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW Template API) $(TD $(MYREF SHA1)
)
)
$(TR $(TDNW OOP API) $(TD $(MYREF SHA1Digest))
)
$(TR $(TDNW Helpers) $(TD $(MYREF sha1Of))
)
)

 * Computes SHA1 hashes of arbitrary data. SHA1 hashes are 20 byte quantities
 * that are like a checksum or CRC, but are more robust.
 *
 * This module conforms to the APIs defined in $(D std.digest.digest). To understand the
 * differences between the template and the OOP API, see $(D std.digest.digest).
 *
 * This module publicly imports $(D std.digest.digest) and can be used as a stand-alone
 * module.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>
 *
 * CTFE:
 * Digests do not work in CTFE
 *
 * Authors:
 * The routines and algorithms are derived from the
 * $(I Secure Hash Signature Standard (SHS) (FIPS PUB 180-2)). $(BR )
 * Kai Nacke, Johannes Pfau
 *
 * References:
 * $(UL
 * $(LI $(LINK2 http://csrc.nist.gov/publications/fips/fips180-2/fips180-2withchangenotice.pdf, FIPS PUB180-2))
 * $(LI $(LINK2 http://software.intel.com/en-us/articles/improving-the-performance-of-the-secure-hash-algorithm-1/, Fast implementation of SHA1))
 * $(LI $(LINK2 http://en.wikipedia.org/wiki/Secure_Hash_Algorithm, Wikipedia article about SHA))
 * )
 *
 * Source: $(PHOBOSSRC std/digest/_sha.d)
 *
 * Macros:
 *      WIKI = Phobos/StdSha1
 *      MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>
 *
 * Examples:
 * ---------
 * //Template API
 * import std.digest.sha;
 *
 * ubyte[20] hash = sha1Of("abc");
 * assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");
 *
 * //Feeding data
 * ubyte[1024] data;
 * SHA1 sha;
 * sha.start();
 * sha.put(data[]);
 * sha.start(); //Start again
 * sha.put(data[]);
 * hash = sha.finish();
 * ---------
 *
 * ---------
 * //OOP API
 * import std.digest.sha;
 *
 * auto sha = new SHA1Digest();
 * ubyte[] hash = sha.digest("abc");
 * assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");
 *
 * //Feeding data
 * ubyte[1024] data;
 * sha.put(data[]);
 * sha.reset(); //Start again
 * sha.put(data[]);
 * hash = sha.finish();
 * ---------
 */

/*          Copyright Kai Nacke 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.digest.sha;

//verify example
unittest
{
    //Template API
    import std.digest.sha;

    ubyte[20] hash = sha1Of("abc");
    assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");

    //Feeding data
    ubyte[1024] data;
    SHA1 sha;
    sha.start();
    sha.put(data[]);
    sha.start(); //Start again
    sha.put(data[]);
    hash = sha.finish();
}

//verify example
unittest
{
    //OOP API
    import std.digest.sha;

    auto sha = new SHA1Digest();
    ubyte[] hash = sha.digest("abc");
    assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");

    //Feeding data
    ubyte[1024] data;
    sha.put(data[]);
    sha.reset(); //Start again
    sha.put(data[]);
    hash = sha.finish();
}

version(D_PIC)
{
    // Do not use (Bug9378).
}
else version(D_InlineAsm_X86)
{
    private version = USE_SSSE3;
}
else version(D_InlineAsm_X86_64)
{
    private version = USE_SSSE3;
}

import std.ascii : hexDigits;
import std.exception : assumeUnique;
import core.bitop : bswap;
version(USE_SSSE3) import core.cpuid : hasSSSE3Support = ssse3;
version(USE_SSSE3) import std.internal.digest.sha_SSSE3 : transformSSSE3;


version(unittest)
{
    import std.exception;
}


public import std.digest.digest;

/*
 * Helper methods for encoding the buffer.
 * Can be removed if the optimizer can inline the methods from std.bitmanip.
 */
private ubyte[8] nativeToBigEndian(ulong val) @trusted pure nothrow
{
    version(LittleEndian)
        immutable ulong res = (cast(ulong)  bswap(cast(uint) val)) << 32 | bswap(cast(uint) (val >> 32));
    else
        immutable ulong res = val;
    return *cast(ubyte[8]*) &res;
}

private ubyte[4] nativeToBigEndian(uint val) @trusted pure nothrow
{
    version(LittleEndian)
        immutable uint res = bswap(val);
    else
        immutable uint res = val;
    return *cast(ubyte[4]*) &res;
}

private uint bigEndianToNative(ubyte[4] val) @trusted pure nothrow
{
    version(LittleEndian)
        return bswap(*cast(uint*) &val);
    else
        return *cast(uint*) &val;
}

//rotateLeft rotates x left n bits
private nothrow pure uint rotateLeft(uint x, uint n)
{
    // With recently added optimization to DMD (commit 32ea0206 at 07/28/11), this is translated to rol.
    // No assembler required.
    return (x << n) | (x >> (32-n));
}

/**
 * Template API SHA1 implementation.
 * See $(D std.digest.digest) for differences between template and OOP API.
 *
 * Examples:
 * --------
 * //Simple example, hashing a string using sha1Of helper function
 * ubyte[20] hash = sha1Of("abc");
 * //Let's get a hash string
 * assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");
 * --------
 *
 * --------
 * //Using the basic API
 * SHA1 hash;
 * hash.start();
 * ubyte[1024] data;
 * //Initialize data here...
 * hash.put(data);
 * ubyte[20] result = hash.finish();
 * --------
 *
 * --------
 * //Let's use the template features:
 * //Note: When passing a SHA1 to a function, it must be passed by referece!
 * void doSomething(T)(ref T hash) if(isDigest!T)
 * {
 *     hash.put(cast(ubyte)0);
 * }
 * SHA1 sha;
 * sha.start();
 * doSomething(sha);
 * assert(toHexString(sha.finish()) == "5BA93C9DB0CFF93F52B521D7420E43F6EDA2784F");
 * --------
 */
struct SHA1
{
    version(USE_SSSE3)
    {
        private __gshared immutable nothrow pure void function(uint[5]* state, const(ubyte[64])* block) transform;

        shared static this()
        {
            transform = hasSSSE3Support() ? &transformSSSE3 : &transformX86;
        }
    }
    else
    {
        alias transformX86 transform;
    }

    private:
        uint state[5] =                                   /* state (ABCDE) */
        /* magic initialization constants */
        [0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0];

        ulong count;        /* number of bits, modulo 2^64 */
        ubyte[64] buffer;   /* input buffer */

        enum ubyte[64] padding =
        [
          0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ];

        /*
         * Ch, Parity and Maj are basic SHA1 functions.
         */
        static pure nothrow
        {
            uint Ch(uint x, uint y, uint z) { return z ^ (x & (y ^ z)); }
            uint Parity(uint x, uint y, uint z) { return x ^ y ^ z; }
            uint Maj(uint x, uint y, uint z) { return (x & y) | (z & (x ^ y)); }
        }

        /*
         * SHA1 basic transformation. Transforms state based on block.
         */
        static nothrow pure void T_0_15(int i, const(ubyte[64])* input, ref uint[16] W, uint A, ref uint B, uint C, uint D,
            uint E, ref uint T)
        {
            uint Wi = W[i] = bigEndianToNative(*cast(ubyte[4]*)&((*input)[i*4]));
            T = Ch(B, C, D) + E + rotateLeft(A, 5) + Wi + 0x5a827999;
            B = rotateLeft(B, 30);
        }

        static nothrow pure void T_16_19(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E, ref uint T)
        {
            W[i&15] = rotateLeft(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
            T = Ch(B, C, D) + E + rotateLeft(A, 5) + W[i&15] + 0x5a827999;
            B = rotateLeft(B, 30);
        }

        static nothrow pure void T_20_39(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E,
            ref uint T)
        {
            W[i&15] = rotateLeft(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
            T = Parity(B, C, D) + E + rotateLeft(A, 5) + W[i&15] + 0x6ed9eba1;
            B = rotateLeft(B, 30);
        }

        static nothrow pure void T_40_59(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E,
            ref uint T)
        {
            W[i&15] = rotateLeft(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
            T = Maj(B, C, D) + E + rotateLeft(A, 5) + W[i&15] + 0x8f1bbcdc;
            B = rotateLeft(B, 30);
        }

        static nothrow pure void T_60_79(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E,
            ref uint T)
        {
            W[i&15] = rotateLeft(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
            T = Parity(B, C, D) + E + rotateLeft(A, 5) + W[i&15] + 0xca62c1d6;
            B = rotateLeft(B, 30);
        }

        private static nothrow pure void transformX86(uint[5]* state, const(ubyte[64])* block)
        {
            uint A, B, C, D, E, T;
            uint[16] W = void;

            A = (*state)[0];
            B = (*state)[1];
            C = (*state)[2];
            D = (*state)[3];
            E = (*state)[4];

            T_0_15 ( 0, block, W, A, B, C, D, E, T);
            T_0_15 ( 1, block, W, T, A, B, C, D, E);
            T_0_15 ( 2, block, W, E, T, A, B, C, D);
            T_0_15 ( 3, block, W, D, E, T, A, B, C);
            T_0_15 ( 4, block, W, C, D, E, T, A, B);
            T_0_15 ( 5, block, W, B, C, D, E, T, A);
            T_0_15 ( 6, block, W, A, B, C, D, E, T);
            T_0_15 ( 7, block, W, T, A, B, C, D, E);
            T_0_15 ( 8, block, W, E, T, A, B, C, D);
            T_0_15 ( 9, block, W, D, E, T, A, B, C);
            T_0_15 (10, block, W, C, D, E, T, A, B);
            T_0_15 (11, block, W, B, C, D, E, T, A);
            T_0_15 (12, block, W, A, B, C, D, E, T);
            T_0_15 (13, block, W, T, A, B, C, D, E);
            T_0_15 (14, block, W, E, T, A, B, C, D);
            T_0_15 (15, block, W, D, E, T, A, B, C);
            T_16_19(16, W, C, D, E, T, A, B);
            T_16_19(17, W, B, C, D, E, T, A);
            T_16_19(18, W, A, B, C, D, E, T);
            T_16_19(19, W, T, A, B, C, D, E);
            T_20_39(20, W, E, T, A, B, C, D);
            T_20_39(21, W, D, E, T, A, B, C);
            T_20_39(22, W, C, D, E, T, A, B);
            T_20_39(23, W, B, C, D, E, T, A);
            T_20_39(24, W, A, B, C, D, E, T);
            T_20_39(25, W, T, A, B, C, D, E);
            T_20_39(26, W, E, T, A, B, C, D);
            T_20_39(27, W, D, E, T, A, B, C);
            T_20_39(28, W, C, D, E, T, A, B);
            T_20_39(29, W, B, C, D, E, T, A);
            T_20_39(30, W, A, B, C, D, E, T);
            T_20_39(31, W, T, A, B, C, D, E);
            T_20_39(32, W, E, T, A, B, C, D);
            T_20_39(33, W, D, E, T, A, B, C);
            T_20_39(34, W, C, D, E, T, A, B);
            T_20_39(35, W, B, C, D, E, T, A);
            T_20_39(36, W, A, B, C, D, E, T);
            T_20_39(37, W, T, A, B, C, D, E);
            T_20_39(38, W, E, T, A, B, C, D);
            T_20_39(39, W, D, E, T, A, B, C);
            T_40_59(40, W, C, D, E, T, A, B);
            T_40_59(41, W, B, C, D, E, T, A);
            T_40_59(42, W, A, B, C, D, E, T);
            T_40_59(43, W, T, A, B, C, D, E);
            T_40_59(44, W, E, T, A, B, C, D);
            T_40_59(45, W, D, E, T, A, B, C);
            T_40_59(46, W, C, D, E, T, A, B);
            T_40_59(47, W, B, C, D, E, T, A);
            T_40_59(48, W, A, B, C, D, E, T);
            T_40_59(49, W, T, A, B, C, D, E);
            T_40_59(50, W, E, T, A, B, C, D);
            T_40_59(51, W, D, E, T, A, B, C);
            T_40_59(52, W, C, D, E, T, A, B);
            T_40_59(53, W, B, C, D, E, T, A);
            T_40_59(54, W, A, B, C, D, E, T);
            T_40_59(55, W, T, A, B, C, D, E);
            T_40_59(56, W, E, T, A, B, C, D);
            T_40_59(57, W, D, E, T, A, B, C);
            T_40_59(58, W, C, D, E, T, A, B);
            T_40_59(59, W, B, C, D, E, T, A);
            T_60_79(60, W, A, B, C, D, E, T);
            T_60_79(61, W, T, A, B, C, D, E);
            T_60_79(62, W, E, T, A, B, C, D);
            T_60_79(63, W, D, E, T, A, B, C);
            T_60_79(64, W, C, D, E, T, A, B);
            T_60_79(65, W, B, C, D, E, T, A);
            T_60_79(66, W, A, B, C, D, E, T);
            T_60_79(67, W, T, A, B, C, D, E);
            T_60_79(68, W, E, T, A, B, C, D);
            T_60_79(69, W, D, E, T, A, B, C);
            T_60_79(70, W, C, D, E, T, A, B);
            T_60_79(71, W, B, C, D, E, T, A);
            T_60_79(72, W, A, B, C, D, E, T);
            T_60_79(73, W, T, A, B, C, D, E);
            T_60_79(74, W, E, T, A, B, C, D);
            T_60_79(75, W, D, E, T, A, B, C);
            T_60_79(76, W, C, D, E, T, A, B);
            T_60_79(77, W, B, C, D, E, T, A);
            T_60_79(78, W, A, B, C, D, E, T);
            T_60_79(79, W, T, A, B, C, D, E);

            (*state)[0] += E;
            (*state)[1] += T;
            (*state)[2] += A;
            (*state)[3] += B;
            (*state)[4] += C;

            /* Zeroize sensitive information. */
            W[] = 0;
        }

    public:
        /**
         * SHA1 initialization. Begins a SHA1 operation.
         *
         * Note:
         * For this SHA1 Digest implementation calling start after default construction
         * is not necessary. Calling start is only necessary to reset the Digest.
         *
         * Generic code which deals with different Digest types should always call start though.
         *
         * Examples:
         * --------
         * SHA1 digest;
         * //digest.start(); //Not necessary
         * digest.put(0);
         * --------
         */
        @trusted nothrow pure void start()
        {
            this = SHA1.init;
        }

        /**
         * Use this to feed the digest with data.
         * Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and
         * $(D const(ubyte)[]).
         *
         * Examples:
         * ----
         * SHA1 dig;
         * dig.put(cast(ubyte)0); //single ubyte
         * dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
         * ubyte[10] buf;
         * dig.put(buf); //buffer
         * ----
         */
        @trusted nothrow pure void put(scope const(ubyte)[] input...)
        {
            uint i, index, partLen;
            auto inputLen = input.length;

            /* Compute number of bytes mod 64 */
            index = (cast(uint)count >> 3) & (64 - 1);

            /* Update number of bits */
            count += inputLen * 8;

            partLen = 64 - index;

            /* Transform as many times as possible. */
            if (inputLen >= partLen)
            {
                (&buffer[index])[0 .. partLen] = input.ptr[0 .. partLen];
                transform (&state, &buffer);

                for (i = partLen; i + 63 < inputLen; i += 64)
                   transform(&state, cast(ubyte[64]*)(input.ptr + i));

                index = 0;
            }
            else
                i = 0;

            /* Buffer remaining input */
            if (inputLen - i)
                (&buffer[index])[0 .. inputLen-i] = (&input[i])[0 .. inputLen-i];
        }

        /**
         * Returns the finished SHA1 hash. This also calls $(LREF start) to
         * reset the internal state.
         *
         * Examples:
         * --------
         * //Simple example
         * SHA1 hash;
         * hash.start();
         * hash.put(cast(ubyte)0);
         * ubyte[20] result = hash.finish();
         * --------
         */
        @trusted nothrow pure ubyte[20] finish()
        {
            ubyte[20] data = void;
            uint index, padLen;

            /* Save number of bits */
            ubyte bits[8] = nativeToBigEndian(count);

            /* Pad out to 56 mod 64. */
            index = (cast(uint)count >> 3) & (64 - 1);
            padLen = (index < 56) ? (56 - index) : (120 - index);
            put(padding[0 .. padLen]);

            /* Append length (before padding) */
            put(bits);

            /* Store state in digest */
            for (auto i = 0; i < 5; i++)
                data[i*4..(i+1)*4] = nativeToBigEndian(state[i])[];

            /* Zeroize sensitive information. */
            start();
            return data;
        }
}

//verify example
unittest
{
    //Simple example, hashing a string using sha1Of helper function
    ubyte[20] hash = sha1Of("abc");
    //Let's get a hash string
    assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");
}

//verify example
unittest
{
    //Using the basic API
    SHA1 hash;
    hash.start();
    ubyte[1024] data;
    //Initialize data here...
    hash.put(data);
    ubyte[20] result = hash.finish();
}

//verify example
unittest
{
    //Let's use the template features:
    //Note: When passing a SHA1 to a function, it must be passed by referece!
    void doSomething(T)(ref T hash) if(isDigest!T)
    {
      hash.put(cast(ubyte)0);
    }
    SHA1 sha;
    sha.start();
    doSomething(sha);
    assert(toHexString(sha.finish()) == "5BA93C9DB0CFF93F52B521D7420E43F6EDA2784F");
}

//verify example
unittest
{
    SHA1 dig;
    dig.put(cast(ubyte)0); //single ubyte
    dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
    ubyte[10] buf;
    dig.put(buf); //buffer
}

//verify example
unittest
{
    //Simple example
    SHA1 hash;
    hash.start();
    hash.put(cast(ubyte)0);
    ubyte[20] result = hash.finish();
}

unittest
{
    assert(isDigest!SHA1);
}

unittest
{
    import std.range;

    ubyte[20] digest;

    SHA1 sha;
    sha.put(cast(ubyte[])"abcdef");
    sha.start();
    sha.put(cast(ubyte[])"");
    assert(sha.finish() == cast(ubyte[])x"da39a3ee5e6b4b0d3255bfef95601890afd80709");

    digest = sha1Of("");
    assert(digest == cast(ubyte[])x"da39a3ee5e6b4b0d3255bfef95601890afd80709");

    digest = sha1Of("a");
    assert(digest == cast(ubyte[])x"86f7e437faa5a7fce15d1ddcb9eaeaea377667b8");

    digest = sha1Of("abc");
    assert(digest == cast(ubyte[])x"a9993e364706816aba3e25717850c26c9cd0d89d");

    digest = sha1Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    assert(digest == cast(ubyte[])x"84983e441c3bd26ebaae4aa1f95129e5e54670f1");

    digest = sha1Of("message digest");
    assert(digest == cast(ubyte[])x"c12252ceda8be8994d5fa0290a47231c1d16aae3");

    digest = sha1Of("abcdefghijklmnopqrstuvwxyz");
    assert(digest == cast(ubyte[])x"32d10c7b8cf96570ca04ce37f2a19d84240d3a89");

    digest = sha1Of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    assert(digest == cast(ubyte[])x"761c457bf73b14d27e9e9265c46f4b4dda11f940");

    digest = sha1Of("1234567890123456789012345678901234567890"
                    "1234567890123456789012345678901234567890");
    assert(digest == cast(ubyte[])x"50abf5706a150990a08b2c5ea40fa0e585554732");

    ubyte[] onemilliona = new ubyte[1000000];
    onemilliona[] = 'a';
    digest = sha1Of(onemilliona);
    assert(digest == cast(ubyte[])x"34aa973cd4c4daa4f61eeb2bdbad27316534016f");

    auto oneMillionRange = repeat!ubyte(cast(ubyte)'a', 1000000);
    digest = sha1Of(oneMillionRange);
    assert(digest == cast(ubyte[])x"34aa973cd4c4daa4f61eeb2bdbad27316534016f");

    assert(toHexString(cast(ubyte[20])x"a9993e364706816aba3e25717850c26c9cd0d89d")
        == "A9993E364706816ABA3E25717850C26C9CD0D89D");
}

/**
 * This is a convenience alias for $(XREF digest.digest, digest) using the
 * SHA1 implementation.
 *
 * Examples:
 * ---------
 * ubyte[20] hash = sha1Of("abc");
 * assert(hash == digest!SHA1("abc")); //This is the same as above
 * ---------
 */
//simple alias doesn't work here, hope this gets inlined...
auto sha1Of(T...)(T data)
{
    return digest!(SHA1, T)(data);
}

//verify example
unittest
{
    ubyte[20] hash = sha1Of("abc");
    assert(hash == digest!SHA1("abc"));
}

unittest
{
    string a = "Mary has ", b = "a little lamb";
    int[] c = [ 1, 2, 3, 4, 5 ];
    string d = toHexString(sha1Of(a, b, c));
    version(LittleEndian)
        assert(d == "CDBB611D00AC2387B642D3D7BDF4C3B342237110", d);
    else
        assert(d == "A0F1196C7A379C09390476D9CA4AA11B71FD11C8", d);
}

/**
 * OOP API SHA1 implementation.
 * See $(D std.digest.digest) for differences between template and OOP API.
 *
 * This is an alias for $(XREF digest.digest, WrapperDigest)!SHA1, see
 * $(XREF digest.digest, WrapperDigest) for more information.
 *
 * Examples:
 * --------
 * //Simple example, hashing a string using Digest.digest helper function
 * auto sha = new SHA1Digest();
 * ubyte[] hash = sha.digest("abc");
 * //Let's get a hash string
 * assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");
 * --------
 *
 * --------
 * //Let's use the OOP features:
 * void test(Digest dig)
 * {
 *     dig.put(cast(ubyte)0);
 * }
 * auto sha = new SHA1Digest();
 * test(sha);
 *
 * //Let's use a custom buffer:
 * ubyte[20] buf;
 * ubyte[] result = sha.finish(buf[]);
 * assert(toHexString(result) == "5BA93C9DB0CFF93F52B521D7420E43F6EDA2784F");
 * --------
 */
alias WrapperDigest!SHA1 SHA1Digest;

//verify example
unittest
{
    //Simple example, hashing a string using Digest.digest helper function
    auto sha = new SHA1Digest();
    ubyte[] hash = sha.digest("abc");
    //Let's get a hash string
    assert(toHexString(hash) == "A9993E364706816ABA3E25717850C26C9CD0D89D");
}

//verify example
unittest
{
    //Let's use the OOP features:
    void test(Digest dig)
    {
      dig.put(cast(ubyte)0);
    }
    auto sha = new SHA1Digest();
    test(sha);

    //Let's use a custom buffer:
    ubyte[20] buf;
    ubyte[] result = sha.finish(buf[]);
    assert(toHexString(result) == "5BA93C9DB0CFF93F52B521D7420E43F6EDA2784F");
}

unittest
{
    auto sha = new SHA1Digest();

    sha.put(cast(ubyte[])"abcdef");
    sha.reset();
    sha.put(cast(ubyte[])"");
    assert(sha.finish() == cast(ubyte[])x"da39a3ee5e6b4b0d3255bfef95601890afd80709");

    sha.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    ubyte[22] result;
    auto result2 = sha.finish(result[]);
    assert(result[0 .. 20] == result2 && result2 == cast(ubyte[])x"32d10c7b8cf96570ca04ce37f2a19d84240d3a89");

    debug
        assertThrown!Error(sha.finish(result[0 .. 15]));

    assert(sha.length == 20);

    assert(sha.digest("") == cast(ubyte[])x"da39a3ee5e6b4b0d3255bfef95601890afd80709");

    assert(sha.digest("a") == cast(ubyte[])x"86f7e437faa5a7fce15d1ddcb9eaeaea377667b8");

    assert(sha.digest("abc") == cast(ubyte[])x"a9993e364706816aba3e25717850c26c9cd0d89d");

    assert(sha.digest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
           == cast(ubyte[])x"84983e441c3bd26ebaae4aa1f95129e5e54670f1");

    assert(sha.digest("message digest") == cast(ubyte[])x"c12252ceda8be8994d5fa0290a47231c1d16aae3");

    assert(sha.digest("abcdefghijklmnopqrstuvwxyz")
           == cast(ubyte[])x"32d10c7b8cf96570ca04ce37f2a19d84240d3a89");

    assert(sha.digest("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
           == cast(ubyte[])x"761c457bf73b14d27e9e9265c46f4b4dda11f940");

    assert(sha.digest("1234567890123456789012345678901234567890",
                                   "1234567890123456789012345678901234567890")
           == cast(ubyte[])x"50abf5706a150990a08b2c5ea40fa0e585554732");

    ubyte[] onemilliona = new ubyte[1000000];
    onemilliona[] = 'a';
    assert(sha.digest(onemilliona) == cast(ubyte[])x"34aa973cd4c4daa4f61eeb2bdbad27316534016f");
}
