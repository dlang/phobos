// Written in the D programming language.

/**
 * Computes SHA1 digests of arbitrary data. SHA1 digests are 20 byte quantities
 * that are like a checksum or crc, but are more robust.
 *
 * There are two ways to do this. The first does it all in one function call to
 * sum(). The second is for when the data is buffered.
 *
 * Bugs:
 * SHA1 digests have been demonstrated to not be unique.
 *
 * Author:
 * The routines and algorithms are derived from the
 * $(I Secure Hash Signature Standard (SHS) (FIPS PUB 180-2)).
 *
 * References:
 *      $(LINK2 http://csrc.nist.gov/publications/fips/fips180-2/fips180-2withchangenotice.pdf, FIPS PUB180-2)
 *      $(LINK2 http://software.intel.com/en-us/articles/improving-the-performance-of-the-secure-hash-algorithm-1/, Fast implementation of SHA1)
 *
 * Source: $(PHOBOSSRC std/digest/_sha1.d)
 *
 * Macros:
 *      WIKI = Phobos/StdSha1
 */

/++++++++++++++++++++++++++++++++
 Example:

--------------------
import std.crypt.sha1;

private import std.exception;
private import std.stdio;
private import std.string;

void main(string[] args)
{
    foreach (arg; args[1 .. $])
        SHA1File(arg);
}

/* Digests a file and prints the result. */
void SHA1File(string filename)
{
    File file = File(filename);
    scope(exit) file.close();
    ubyte digest[20];

    SHA1_CTX context;
    context.start();
    foreach (buffer; file.byChunk(4096 * 1024))
        context.update(buffer);
    context.finish(digest);
    writefln("SHA1 (%s) = %s", filename, digestToString(digest));
}
--------------------
 +/

module std.crypt.sha1;

//debug=sha1;            // uncomment to turn on debugging printf's

version(SHA1_WITHOUT_SSSE3)
{
}
else
{
    version(D_InlineAsm_X86)
    {
        version = USE_SSSE3;
    }
    else version(D_InlineAsm_X86_64)
    {
        version = USE_SSSE3;
    }
}

import std.ascii : hexDigits;
import std.c.string : memcpy, memset;
import std.exception : assumeUnique;
import core.bitop : bswap;
version(USE_SSSE3) import core.cpuid : hasSSSE3Support = ssse3;
version(USE_SSSE3) import std.internal.crypt.sha1_SSSE3 : transformSSSE3;
import std.stdio;

/***************************************
 * Computes SHA1 digest of several arrays of data.
 */

void sum(ref ubyte[20] digest, in void[][] data...)
{
    SHA1_CTX context;
    context.start();
    foreach (datum; data)
    {
        context.update(datum);
    }
    context.finish(digest);
}

/****************************************
 * Converts SHA1 digest to a string.
 */

string digestToString(in ubyte[20] digest)
{
    auto result = new char[40];
    int i;

    foreach (ubyte u; digest)
    {
        result[i] = hexDigits[u >> 4];
        result[i + 1] = hexDigits[u & 15];
        i += 2;
    }
    return assumeUnique(result);
}

/**
   Gets the digest of all $(D data) items passed in.

Example:

----
string a = "Mary has ", b = "a little lamb";
int[] c = [ 1, 2, 3, 4, 5 ];
string d = getDigestString(a, b, c);
----
*/
string getDigestString(in void[][] data...)
{
    ubyte[20] digest = void;
    sum(digest, data);
    return digestToString(digest);
}

unittest
{
    string a = "Mary has ", b = "a little lamb";
    int[] c = [ 1, 2, 3, 4, 5 ];
    string d = getDigestString(a, b, c);
    assert(d == "CDBB611D00AC2387B642D3D7BDF4C3B342237110", d);
}

/**
 * Holds context of SHA1 computation.
 *
 * Used when data to be digested is buffered.
 */
struct SHA1_CTX
{
    version(USE_SSSE3)
    {
        private static void function(uint* state, ubyte* block) transform;

        static this()
        {
            if (hasSSSE3Support())
            {
                transform = &transformSSSE3;
            }
            else
            {
                transform = &transformX86;
            }
        }
    }
    else
    {
        alias transformX86 transform;
    }

    uint state[5] =                                   /* state (ABCDE) */
    /* magic initialization constants */
    [0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0];

    ulong count;        /* number of bits, modulo 2^64 */
    ubyte buffer[64];   /* input buffer */

    static ubyte[64] PADDING =
    [
      0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ];

    /* Ch, Parity and Maj are basic SHA1 functions.
     */
    private static pure nothrow
    {
        uint Ch(uint x, uint y, uint z) { return z ^ (x & (y ^ z)); }
        uint Parity(uint x, uint y, uint z) { return x ^ y ^ z; }
        uint Maj(uint x, uint y, uint z) { return (x & y) | (z & (x ^ y)); }
    }

    /* ROTATE_LEFT rotates x left n bits.
     */
    private static pure nothrow uint ROTATE_LEFT(uint x, uint n)
    {
        // With recently added optimization to DMD (commit 32ea0206 at 07/28/11), this is translated to rol.
        // No assembler required.
        return (x << n) | (x >> (uint.sizeof*8-n));
    }

    /**
     * SHA1 initialization. Begins an SHA1 operation, writing a new context.
     */
    void start()
    {
        this = SHA1_CTX.init;
    }

    /** SHA1 block update operation. Continues an SHA1 message-digest
      operation, processing another message block, and updating the
      context.
     */
    void update(const void[] input)
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
            std.c.string.memcpy(&buffer[index], input.ptr, partLen);
            transform (state.ptr, buffer.ptr);

            for (i = partLen; i + 63 < inputLen; i += 64)
               transform (state.ptr, (cast(ubyte[])input)[i .. i + 64].ptr);

            index = 0;
        }
        else
            i = 0;

        /* Buffer remaining input */
        if (inputLen - i)
            memcpy(&buffer[index], &input[i], inputLen-i);
    }

    /** SHA1 finalization. Ends an SHA1 message-digest operation, writing the
     * the message to digest and zeroing the context.
     */
    void finish(ref ubyte[20] digest)         /* message digest */
    {
        uint index, padLen;

        /* Save number of bits */
        ubyte bits[8] = nativeToBigEndian(count);

        /* Pad out to 56 mod 64. */
        index = (cast(uint)count >> 3) & (64 - 1);
        padLen = (index < 56) ? (56 - index) : (120 - index);
        update (PADDING[0 .. padLen]);

        /* Append length (before padding) */
        update (bits);

        /* Store state in digest */
        for (auto i = 0; i < 5; i++)
            digest[i*4..(i+1)*4] = nativeToBigEndian(state[i]);

        /* Zeroize sensitive information. */
        memset (&this, 0, SHA1_CTX.sizeof);
    }

    /* SHA1 basic transformation. Transforms state based on block.
     */
    private static void T_0_15(int i, ubyte* input, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E, ref uint T)
    {
        uint Wi = W[i] = bigEndianToNative(*cast(ubyte[4]*)&input[i*4]);
        T = Ch(B, C, D) + E + ROTATE_LEFT(A, 5) + Wi + 0x5a827999;
        B = ROTATE_LEFT(B, 30);
    }

    private static void T_16_19(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E, ref uint T)
    {
        W[i&15] = ROTATE_LEFT(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
        T = Ch(B, C, D) + E + ROTATE_LEFT(A, 5) + W[i&15] + 0x5a827999;
        B = ROTATE_LEFT(B, 30);
    }

    private static void T_20_39(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E, ref uint T)
    {
        W[i&15] = ROTATE_LEFT(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
        T = Parity(B, C, D) + E + ROTATE_LEFT(A, 5) + W[i&15] + 0x6ed9eba1;
        B = ROTATE_LEFT(B, 30);
    }

    private static void T_40_59(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E, ref uint T)
    {
        W[i&15] = ROTATE_LEFT(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
        T = Maj(B, C, D) + E + ROTATE_LEFT(A, 5) + W[i&15] + 0x8f1bbcdc;
        B = ROTATE_LEFT(B, 30);
    }

    private static void T_60_79(int i, ref uint[16] W, uint A, ref uint B, uint C, uint D, uint E, ref uint T)
    {
        W[i&15] = ROTATE_LEFT(W[(i-3)&15] ^ W[(i-8)&15] ^ W[(i-14)&15] ^ W[(i-16)&15], 1);
        T = Parity(B, C, D) + E + ROTATE_LEFT(A, 5) + W[i&15] + 0xca62c1d6;
        B = ROTATE_LEFT(B, 30);
    }

    private static void transformX86(uint* state, ubyte* /*[64]*/ block)
    {
        uint A, B, C, D, E, T;
        uint[16] W = void;

        A = state[0];
        B = state[1];
        C = state[2];
        D = state[3];
        E = state[4];

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

        state[0] += E;
        state[1] += T;
        state[2] += A;
        state[3] += B;
        state[4] += C;

        /* Zeroize sensitive information. */
        W[] = 0;
    }

    /* Helper methods for encoding the buffer.
     * Can be removed if the optimizer can inline the methods from std.bitmanip.
     */
    private static ubyte[8] nativeToBigEndian(ulong val) @trusted pure nothrow
    {
        version(LittleEndian)
            immutable ulong res = (cast(ulong)  bswap(cast(uint) val)) << 32 | bswap(cast(uint) (val >> 32));
        else
            immutable ulong res = val;
        return *cast(ubyte[8]*) &res;
    }

    private static ubyte[4] nativeToBigEndian(uint val) @trusted pure nothrow
    {
        version(LittleEndian)
            immutable uint res = bswap(val);
        else
            immutable uint res = val;
        return *cast(ubyte[4]*) &res;
    }

    private static uint bigEndianToNative(ubyte[4] val) @trusted pure nothrow
    {
        version(LittleEndian)
            return bswap(*cast(uint*) &val);
        else
            return *cast(uint*) &val;
    }
}

unittest
{
    import std.stdio;
    import std.conv;
    debug(sha1) writefln("std.sha1.unittest");

    ubyte[20] digest;

    sum (digest, "");
    assert(digest == cast(ubyte[])x"da39a3ee5e6b4b0d3255bfef95601890afd80709", digestToString(digest));

    sum (digest, "a");
    assert(digest == cast(ubyte[])x"86f7e437faa5a7fce15d1ddcb9eaeaea377667b8", digestToString(digest));

    sum (digest, "abc");
    assert(digest == cast(ubyte[])x"a9993e364706816aba3e25717850c26c9cd0d89d", digestToString(digest));

    sum (digest, "message digest");
    assert(digest == cast(ubyte[])x"c12252ceda8be8994d5fa0290a47231c1d16aae3", digestToString(digest));

    sum (digest, "abcdefghijklmnopqrstuvwxyz");
    assert(digest == cast(ubyte[])x"32d10c7b8cf96570ca04ce37f2a19d84240d3a89", digestToString(digest));

    sum (digest, "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    assert(digest == cast(ubyte[])x"84983e441c3bd26ebaae4aa1f95129e5e54670f1", digestToString(digest));

    sum (digest, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    assert(digest == cast(ubyte[])x"761c457bf73b14d27e9e9265c46f4b4dda11f940", digestToString(digest));

    sum (digest,
        "1234567890123456789012345678901234567890"
        "1234567890123456789012345678901234567890");
    assert(digest == cast(ubyte[])x"50abf5706a150990a08b2c5ea40fa0e585554732", digestToString(digest));

    ubyte[] onemilliona = new ubyte[1000000];
    onemilliona[] = 'a';
    sum (digest, onemilliona);
    assert(digest == cast(ubyte[])x"34aa973cd4c4daa4f61eeb2bdbad27316534016f", digestToString(digest));

    assert(digestToString(cast(ubyte[20])x"a9993e364706816aba3e25717850c26c9cd0d89d")
        == "A9993E364706816ABA3E25717850C26C9CD0D89D");
}
