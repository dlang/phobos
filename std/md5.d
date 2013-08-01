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

alias ubyte md5_byte_t; /* 8-bit byte */
alias uint md5_word_t; /* 32-bit word */

/* Define the state of the MD5 Algorithm. */
struct md5_state_t
{
    md5_word_t count[2];    /* message length in bits, lsw first */
    md5_word_t abcd[4];     /* digest buffer */
    md5_byte_t buf[64];     /* accumulate block */
};

/* Initialize the algorithm. */
extern (C) void md5_init(md5_state_t *pms);

/* Append a string to the message. */
extern (C) void md5_append(md5_state_t *pms, const md5_byte_t *data, uint nbytes);

/* Finish the message and return the digest. */
extern (C) void md5_finish(md5_state_t *pms, ref md5_byte_t[16] digest);

struct MD5_CTX
{
    /**
     * MD5 initialization. Begins an MD5 operation, writing a new context.
     */
    void start()
    {
        std.md5.md5_init(&state);
    }

    /** MD5 block update operation. Continues an MD5 message-digest
      operation, processing another message block, and updating the
      context.
     */
    void update(const void[] input)
    {
        std.md5.md5_append(&state, cast(ubyte*)input.ptr, cast(uint)input.length);
    }

    /** MD5 finalization. Ends an MD5 message-digest operation, writing the
     * the message to digest and zeroing the context.
     */
    void finish(ref ubyte[16] digest)         /* message digest */
    {
        std.md5.md5_finish(&state, digest);
    }

    md5_state_t state;
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
