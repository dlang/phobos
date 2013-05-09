// Written in the D programming language.

/* md5.d - RSA Data Security, Inc., MD5 message-digest algorithm
 * Derived from the RSA Data Security, Inc. MD5 Message-Digest Algorithm.
 */

/**
 * $(RED Scheduled for deprecation. Please use std.digest.md instead.)
 *
 * Computes MD5 digests of arbitrary data. MD5 digests are 16 byte quantities that are like a checksum or crc, but are more robust.
 *
 * There are two ways to do this. The first does it all in one function call to
 * sum(). The second is for when the data is buffered.
 *
 * Bugs:
 * MD5 digests have been demonstrated to not be unique.
 *
 * Author:
 * The routines and algorithms are derived from the
 * $(I RSA Data Security, Inc. MD5 Message-Digest Algorithm).
 *
 * References:
 *      $(LINK2 http://en.wikipedia.org/wiki/Md5, Wikipedia on MD5)
 *
 * Source: $(PHOBOSSRC std/_md5.d)
 *
 * Macros:
 *      WIKI = Phobos/StdMd5
 */

/++++++++++++++++++++++++++++++++
 Example:

--------------------
// This code is derived from the
// RSA Data Security, Inc. MD5 Message-Digest Algorithm.

import std.md5;
import std.stdio;

void main(string[] args)
{
    foreach (arg; args)
        mdFile(arg);
}

/// Digests a file and prints the result.
void mdFile(string filename)
{
    ubyte[16] digest;

    MD5_CTX context;
    context.start();
    foreach (buffer; File(filename).byChunk(64 * 1024))
        context.update(buffer);
    context.finish(digest);
    writefln("MD5 (%s) = %s", filename, digestToString(digest));
}
--------------------
 +/

/* Copyright (C) 1991-2, RSA Data Security, Inc. Created 1991. All
rights reserved.

License to copy and use this software is granted provided that it
is identified as the "RSA Data Security, Inc. MD5 Message-Digest
Algorithm" in all material mentioning or referencing this software
or this function.

License is also granted to make and use derivative works provided
that such works are identified as "derived from the RSA Data
Security, Inc. MD5 Message-Digest Algorithm" in all material
mentioning or referencing the derived work.

RSA Data Security, Inc. makes no representations concerning either
the merchantability of this software or the suitability of this
software for any particular purpose. It is provided "as is"
without express or implied warranty of any kind.
These notices must be retained in any copies of any part of this
documentation and/or software.
 */

module std.md5;

pragma(msg, "std.md5 is scheduled for deprecation. Please use "
    "std.digest.md instead");

//debug=md5;            // uncomment to turn on debugging printf's

import std.ascii;
import std.bitmanip;
import std.string;
import std.exception;
debug(md5) import std.c.stdio : printf;

/***************************************
 * Computes MD5 digest of several arrays of data.
 */

void sum(ref ubyte[16] digest, in void[][] data...)
{
    MD5_CTX context;
    context.start();
    foreach (datum; data)
    {
        context.update(datum);
    }
    context.finish(digest);
}

// /******************
//  * Prints a message digest in hexadecimal to stdout.
//  */
// void printDigest(const ubyte digest[16])
// {
//     foreach (ubyte u; digest)
//         printf("%02x", u);
// }

/****************************************
 * Converts MD5 digest to a string.
 */

string digestToString(in ubyte[16] digest)
{
    auto result = new char[32];
    int i;

    foreach (ubyte u; digest)
    {
        result[i] = std.ascii.hexDigits[u >> 4];
        result[i + 1] = std.ascii.hexDigits[u & 15];
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
    MD5_CTX ctx;
    ctx.start();
    foreach (datum; data) {
        ctx.update(datum);
    }
    ubyte[16] digest;
    ctx.finish(digest);
    return digestToString(digest);
}

version(unittest) import std.stdio;
unittest
{
    string a = "Mary has ", b = "a little lamb";
    int[] c = [ 1, 2, 3, 4, 5 ];
    string d = getDigestString(a, b, c);
    version(LittleEndian)
        assert(d == "F36625A66B2A8D9F47270C00C8BEFD2F", d);
    else
        assert(d == "2656D2008FF10DAE4B0783E6E0171655", d);
}

/**
 * Holds context of MD5 computation.
 *
 * Used when data to be digested is buffered.
 */
struct MD5_CTX
{
    uint state[4] =                                   /* state (ABCD) */
    /* magic initialization constants */
    [0x67452301,0xefcdab89,0x98badcfe,0x10325476];

    ulong count;        /* number of bits, modulo 2^64 */
    ubyte buffer[64];   /* input buffer */

    static ubyte[64] PADDING =
    [
      0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ];

    /* F, G, H and I are basic MD5 functions.
     */
    private static
    {
        uint F(uint x, uint y, uint z) { return (x & y) | (~x & z); }
        uint G(uint x, uint y, uint z) { return (x & z) | (y & ~z); }
        uint H(uint x, uint y, uint z) { return x ^ y ^ z; }
        uint I(uint x, uint y, uint z) { return y ^ (x | ~z); }
    }

    /* ROTATE_LEFT rotates x left n bits.
     */
    static uint ROTATE_LEFT(uint x, uint n)
    {
        // With recently added optimization to DMD (commit 32ea0206 at 07/28/11), this is translated to rol.
        // No assembler required.
        return (x << n) | (x >> (32-n));
    }

    /* FF, GG, HH, and II transformations for rounds 1, 2, 3, and 4.
     * Rotation is separate from addition to prevent recomputation.
     */
    static void FF(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += F (b, c, d) + x + ac;
        a = ROTATE_LEFT (a, s);
        a += b;
    }

    static void GG(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += G (b, c, d) + x + ac;
        a = ROTATE_LEFT (a, s);
        a += b;
    }

    static void HH(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += H (b, c, d) + x + ac;
        a = ROTATE_LEFT (a, s);
        a += b;
    }

    static void II(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += I (b, c, d) + x + ac;
        a = ROTATE_LEFT (a, s);
        a += b;
    }

    /**
     * MD5 initialization. Begins an MD5 operation, writing a new context.
     */
    void start()
    {
        this = MD5_CTX.init;
    }

    /** MD5 block update operation. Continues an MD5 message-digest
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
            transform (buffer.ptr);

            for (i = partLen; i + 63 < inputLen; i += 64)
               transform ((cast(ubyte[])input)[i .. i + 64].ptr);

            index = 0;
      }
      else
            i = 0;

      /* Buffer remaining input */
      if (inputLen - i)
            std.c.string.memcpy(&buffer[index], &input[i], inputLen-i);
    }

    /** MD5 finalization. Ends an MD5 message-digest operation, writing the
     * the message to digest and zeroing the context.
     */
    void finish(ref ubyte[16] digest)         /* message digest */
    {
      ubyte bits[8] = void;
      uint index, padLen;

      /* Save number of bits */
      bits[0 .. 8] = nativeToLittleEndian(count)[];

      /* Pad out to 56 mod 64. */
      index = (cast(uint)count >> 3) & (64 - 1);
      padLen = (index < 56) ? (56 - index) : (120 - index);
      update (PADDING[0 .. padLen]);

      /* Append length (before padding) */
      update (bits);

      /* Store state in digest */
      digest[0 .. 4]   = nativeToLittleEndian(state[0])[];
      digest[4 .. 8]   = nativeToLittleEndian(state[1])[];
      digest[8 .. 12]  = nativeToLittleEndian(state[2])[];
      digest[12 .. 16] = nativeToLittleEndian(state[3])[];

      /* Zeroize sensitive information. */
      std.c.string.memset (&this, 0, MD5_CTX.sizeof);
    }

    /* MD5 basic transformation. Transforms state based on block.
     */

    /* Constants for MD5Transform routine. */
    enum
    {
        S11 = 7,
        S12 = 12,
        S13 = 17,
        S14 = 22,
        S21 = 5,
        S22 = 9,
        S23 = 14,
        S24 = 20,
        S31 = 4,
        S32 = 11,
        S33 = 16,
        S34 = 23,
        S41 = 6,
        S42 = 10,
        S43 = 15,
        S44 = 21,
    }

    private void transform (const ubyte* /*[64]*/ block)
    {
      uint a = state[0],
           b = state[1],
           c = state[2],
           d = state[3];
      uint[16] x = void;

      version(BigEndian)
      {
          for(size_t i = 0; i < 16; i++)
          {
              x[i] = littleEndianToNative!uint(*cast(ubyte[4]*)&block[i*4]);
          }
      }
      else
      {
          (cast(ubyte*)x.ptr)[0 .. 64] = block[0 .. 64];
      }

      /* Round 1 */
      FF (a, b, c, d, x[ 0], S11, 0xd76aa478); /* 1 */
      FF (d, a, b, c, x[ 1], S12, 0xe8c7b756); /* 2 */
      FF (c, d, a, b, x[ 2], S13, 0x242070db); /* 3 */
      FF (b, c, d, a, x[ 3], S14, 0xc1bdceee); /* 4 */
      FF (a, b, c, d, x[ 4], S11, 0xf57c0faf); /* 5 */
      FF (d, a, b, c, x[ 5], S12, 0x4787c62a); /* 6 */
      FF (c, d, a, b, x[ 6], S13, 0xa8304613); /* 7 */
      FF (b, c, d, a, x[ 7], S14, 0xfd469501); /* 8 */
      FF (a, b, c, d, x[ 8], S11, 0x698098d8); /* 9 */
      FF (d, a, b, c, x[ 9], S12, 0x8b44f7af); /* 10 */
      FF (c, d, a, b, x[10], S13, 0xffff5bb1); /* 11 */
      FF (b, c, d, a, x[11], S14, 0x895cd7be); /* 12 */
      FF (a, b, c, d, x[12], S11, 0x6b901122); /* 13 */
      FF (d, a, b, c, x[13], S12, 0xfd987193); /* 14 */
      FF (c, d, a, b, x[14], S13, 0xa679438e); /* 15 */
      FF (b, c, d, a, x[15], S14, 0x49b40821); /* 16 */

     /* Round 2 */
      GG (a, b, c, d, x[ 1], S21, 0xf61e2562); /* 17 */
      GG (d, a, b, c, x[ 6], S22, 0xc040b340); /* 18 */
      GG (c, d, a, b, x[11], S23, 0x265e5a51); /* 19 */
      GG (b, c, d, a, x[ 0], S24, 0xe9b6c7aa); /* 20 */
      GG (a, b, c, d, x[ 5], S21, 0xd62f105d); /* 21 */
      GG (d, a, b, c, x[10], S22,  0x2441453); /* 22 */
      GG (c, d, a, b, x[15], S23, 0xd8a1e681); /* 23 */
      GG (b, c, d, a, x[ 4], S24, 0xe7d3fbc8); /* 24 */
      GG (a, b, c, d, x[ 9], S21, 0x21e1cde6); /* 25 */
      GG (d, a, b, c, x[14], S22, 0xc33707d6); /* 26 */
      GG (c, d, a, b, x[ 3], S23, 0xf4d50d87); /* 27 */
      GG (b, c, d, a, x[ 8], S24, 0x455a14ed); /* 28 */
      GG (a, b, c, d, x[13], S21, 0xa9e3e905); /* 29 */
      GG (d, a, b, c, x[ 2], S22, 0xfcefa3f8); /* 30 */
      GG (c, d, a, b, x[ 7], S23, 0x676f02d9); /* 31 */
      GG (b, c, d, a, x[12], S24, 0x8d2a4c8a); /* 32 */

      /* Round 3 */
      HH (a, b, c, d, x[ 5], S31, 0xfffa3942); /* 33 */
      HH (d, a, b, c, x[ 8], S32, 0x8771f681); /* 34 */
      HH (c, d, a, b, x[11], S33, 0x6d9d6122); /* 35 */
      HH (b, c, d, a, x[14], S34, 0xfde5380c); /* 36 */
      HH (a, b, c, d, x[ 1], S31, 0xa4beea44); /* 37 */
      HH (d, a, b, c, x[ 4], S32, 0x4bdecfa9); /* 38 */
      HH (c, d, a, b, x[ 7], S33, 0xf6bb4b60); /* 39 */
      HH (b, c, d, a, x[10], S34, 0xbebfbc70); /* 40 */
      HH (a, b, c, d, x[13], S31, 0x289b7ec6); /* 41 */
      HH (d, a, b, c, x[ 0], S32, 0xeaa127fa); /* 42 */
      HH (c, d, a, b, x[ 3], S33, 0xd4ef3085); /* 43 */
      HH (b, c, d, a, x[ 6], S34,  0x4881d05); /* 44 */
      HH (a, b, c, d, x[ 9], S31, 0xd9d4d039); /* 45 */
      HH (d, a, b, c, x[12], S32, 0xe6db99e5); /* 46 */
      HH (c, d, a, b, x[15], S33, 0x1fa27cf8); /* 47 */
      HH (b, c, d, a, x[ 2], S34, 0xc4ac5665); /* 48 */

      /* Round 4 */
      II (a, b, c, d, x[ 0], S41, 0xf4292244); /* 49 */
      II (d, a, b, c, x[ 7], S42, 0x432aff97); /* 50 */
      II (c, d, a, b, x[14], S43, 0xab9423a7); /* 51 */
      II (b, c, d, a, x[ 5], S44, 0xfc93a039); /* 52 */
      II (a, b, c, d, x[12], S41, 0x655b59c3); /* 53 */
      II (d, a, b, c, x[ 3], S42, 0x8f0ccc92); /* 54 */
      II (c, d, a, b, x[10], S43, 0xffeff47d); /* 55 */
      II (b, c, d, a, x[ 1], S44, 0x85845dd1); /* 56 */
      II (a, b, c, d, x[ 8], S41, 0x6fa87e4f); /* 57 */
      II (d, a, b, c, x[15], S42, 0xfe2ce6e0); /* 58 */
      II (c, d, a, b, x[ 6], S43, 0xa3014314); /* 59 */
      II (b, c, d, a, x[13], S44, 0x4e0811a1); /* 60 */
      II (a, b, c, d, x[ 4], S41, 0xf7537e82); /* 61 */
      II (d, a, b, c, x[11], S42, 0xbd3af235); /* 62 */
      II (c, d, a, b, x[ 2], S43, 0x2ad7d2bb); /* 63 */
      II (b, c, d, a, x[ 9], S44, 0xeb86d391); /* 64 */

      state[0] += a;
      state[1] += b;
      state[2] += c;
      state[3] += d;

      /* Zeroize sensitive information. */
      x[] = 0;
    }
}

unittest
{
    debug(md5) printf("std.md5.unittest\n");

    ubyte[16] digest;

    sum (digest, "");
    assert(digest == cast(ubyte[])x"d41d8cd98f00b204e9800998ecf8427e");

    sum (digest, "a");
    assert(digest == cast(ubyte[])x"0cc175b9c0f1b6a831c399e269772661");

    sum (digest, "abc");
    assert(digest == cast(ubyte[])x"900150983cd24fb0d6963f7d28e17f72");

    sum (digest, "message digest");
    assert(digest == cast(ubyte[])x"f96b697d7cb7938d525a2f31aaf161d0");

    sum (digest, "abcdefghijklmnopqrstuvwxyz");
    assert(digest == cast(ubyte[])x"c3fcd3d76192e4007dfb496cca67e13b");

    sum (digest, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    assert(digest == cast(ubyte[])x"d174ab98d277d9f5a5611c2c9f419d9f");

    sum (digest,
        "1234567890123456789012345678901234567890"
        "1234567890123456789012345678901234567890");
    assert(digest == cast(ubyte[])x"57edf4a22be3c955ac49da2e2107b67a");

    assert(digestToString(cast(ubyte[16])x"c3fcd3d76192e4007dfb496cca67e13b")
        == "C3FCD3D76192E4007DFB496CCA67E13B");
}
