/**
Cyclic Redundancy Check (32-bit) implementation.

$(SCRIPT inhibitQuickIndex = 1;)

$(DIVC quickindex,
$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW Template API) $(TD $(MYREF CRC32)
)
)
$(TR $(TDNW OOP API) $(TD $(MYREF CRC32Digest))
)
$(TR $(TDNW Helpers) $(TD $(MYREF crcHexString) $(MYREF crc32Of))
)
)
)

 *
 * This module conforms to the APIs defined in $(D std.digest.digest). To understand the
 * differences between the template and the OOP API, see $(D std.digest.digest).
 *
 * This module publicly imports $(D std.digest.digest) and can be used as a stand-alone
 * module.
 *
 * Note:
 * CRCs are usually printed with the MSB first. When using
 * $(REF toHexString, std,digest,digest) the result will be in an unexpected
 * order. Use $(REF toHexString, std,digest,digest)'s optional order parameter
 * to specify decreasing order for the correct result. The $(LREF crcHexString)
 * alias can also be used for this purpose.
 *
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Authors:   Pavel "EvilOne" Minayev, Alex Rønne Petersen, Johannes Pfau
 *
 * References:
 *      $(LINK2 http://en.wikipedia.org/wiki/Cyclic_redundancy_check, Wikipedia on CRC)
 *
 * Source: $(PHOBOSSRC std/digest/_crc.d)
 *
 * Standards:
 * Implements the 'common' IEEE CRC32 variant
 * (LSB-first order, Initial value uint.max, complement result)
 *
 * CTFE:
 * Digests do not work in CTFE
 */
/*
 * Copyright (c) 2001 - 2002
 * Pavel "EvilOne" Minayev
 * Copyright (c) 2012
 * Alex Rønne Petersen
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.digest.crc;

public import std.digest.digest;

version(unittest)
    import std.exception;


///
@safe unittest
{
    //Template API
    import std.digest.crc;

    ubyte[4] hash = crc32Of("The quick brown fox jumps over the lazy dog");
    assert(crcHexString(hash) == "414FA339");

    //Feeding data
    ubyte[1024] data;
    CRC32 crc;
    crc.put(data[]);
    crc.start(); //Start again
    crc.put(data[]);
    hash = crc.finish();
}

///
@safe unittest
{
    //OOP API
    import std.digest.crc;

    auto crc = new CRC32Digest();
    ubyte[] hash = crc.digest("The quick brown fox jumps over the lazy dog");
    assert(crcHexString(hash) == "414FA339"); //352441c2

    //Feeding data
    ubyte[1024] data;
    crc.put(data[]);
    crc.reset(); //Start again
    crc.put(data[]);
    hash = crc.finish();
}

private uint[256][8] genTables(uint polynomial)
{
    uint[256][8] res = void;

    foreach (i; 0 .. 0x100)
    {
        uint crc = i;
        foreach (_; 0 .. 8)
            crc = (crc >> 1) ^ (-int(crc & 1) & polynomial);
        res[0][i] = crc;
    }

    foreach (i; 0 .. 0x100)
    {
        res[1][i] = (res[0][i] >> 8) ^ res[0][res[0][i] & 0xFF];
        res[2][i] = (res[1][i] >> 8) ^ res[0][res[1][i] & 0xFF];
        res[3][i] = (res[2][i] >> 8) ^ res[0][res[2][i] & 0xFF];

        res[4][i] = (res[3][i] >> 8) ^ res[0][res[3][i] & 0xFF];
        res[5][i] = (res[4][i] >> 8) ^ res[0][res[4][i] & 0xFF];
        res[6][i] = (res[5][i] >> 8) ^ res[0][res[5][i] & 0xFF];
        res[7][i] = (res[6][i] >> 8) ^ res[0][res[6][i] & 0xFF];
    }
    return res;
}

private static immutable uint[256][8] crc32Tables = genTables(0xEDB88320);

@system unittest
{
    auto tables = genTables(0xEDB88320);
    assert(tables[0][0] == 0x00000000 && tables[0][$ - 1] == 0x2d02ef8d && tables[7][$ - 1] == 0x264b06e6);
}

/**
 * Template API CRC32 implementation.
 * See $(D std.digest.digest) for differences between template and OOP API.
 */
struct CRC32
{
    private:
        // magic initialization constants
        uint _state = uint.max;

    public:
        /**
         * Use this to feed the digest with data.
         * Also implements the $(REF isOutputRange, std,range,primitives)
         * interface for $(D ubyte) and $(D const(ubyte)[]).
         */
        void put(scope const(ubyte)[] data...) @trusted pure nothrow @nogc
        {
            uint crc = _state;
            // process eight bytes at once
            while (data.length >= 8)
            {
                // Use byte-wise reads to support architectures without HW support
                // for unaligned reads. This can be optimized by compilers to a single
                // 32-bit read if unaligned reads are supported.
                // DMD is not able to do this optimization though, so explicitly
                // do unaligned reads for DMD's architectures.
                version (X86)
                    enum hasLittleEndianUnalignedReads = true;
                else version (X86_64)
                    enum hasLittleEndianUnalignedReads = true;
                else
                    enum hasLittleEndianUnalignedReads = false; // leave decision to optimizer
                static if (hasLittleEndianUnalignedReads)
                {
                    uint one = (cast(uint*) data.ptr)[0] ^ crc;
                    uint two = (cast(uint*) data.ptr)[1];
                }
                else
                {
                    uint one = (data.ptr[3] << 24 | data.ptr[2] << 16 | data.ptr[1] << 8 | data.ptr[0]) ^ crc;
                    uint two = (data.ptr[7] << 24 | data.ptr[6] << 16 | data.ptr[5] << 8 | data.ptr[4]);
                }

                crc =
                    crc32Tables[0][two >> 24] ^
                    crc32Tables[1][(two >> 16) & 0xFF] ^
                    crc32Tables[2][(two >>  8) & 0xFF] ^
                    crc32Tables[3][two & 0xFF] ^
                    crc32Tables[4][one >> 24] ^
                    crc32Tables[5][(one >> 16) & 0xFF] ^
                    crc32Tables[6][(one >>  8) & 0xFF] ^
                    crc32Tables[7][one & 0xFF];

                data = data[8 .. $];
            }
            // remaining 1 to 7 bytes
            foreach (d; data)
                crc = (crc >> 8) ^ crc32Tables[0][(crc & 0xFF) ^ d];
            _state = crc;
        }
        ///
        @safe unittest
        {
            CRC32 dig;
            dig.put(cast(ubyte) 0); //single ubyte
            dig.put(cast(ubyte) 0, cast(ubyte) 0); //variadic
            ubyte[10] buf;
            dig.put(buf); //buffer
        }

        /**
         * Used to initialize the CRC32 digest.
         *
         * Note:
         * For this CRC32 Digest implementation calling start after default construction
         * is not necessary. Calling start is only necessary to reset the Digest.
         *
         * Generic code which deals with different Digest types should always call start though.
         */
        void start() @safe pure nothrow @nogc
        {
            this = CRC32.init;
        }
        ///
        @safe unittest
        {
            CRC32 digest;
            //digest.start(); //Not necessary
            digest.put(0);
        }

        /**
         * Returns the finished CRC32 hash. This also calls $(LREF start) to
         * reset the internal state.
         */
        ubyte[4] finish() @safe pure nothrow @nogc
        {
            auto tmp = peek();
            start();
            return tmp;
        }
        ///
        @safe unittest
        {
            //Simple example
            CRC32 hash;
            hash.put(cast(ubyte) 0);
            ubyte[4] result = hash.finish();
        }

        /**
         * Works like $(D finish) but does not reset the internal state, so it's possible
         * to continue putting data into this CRC32 after a call to peek.
         */
        ubyte[4] peek() const @safe pure nothrow @nogc
        {
            import std.bitmanip : nativeToLittleEndian;
            //Complement, LSB first / Little Endian, see http://rosettacode.org/wiki/CRC-32
            return nativeToLittleEndian(~_state);
        }
}

///
@safe unittest
{
    //Simple example, hashing a string using crc32Of helper function
    ubyte[4] hash = crc32Of("abc");
    //Let's get a hash string
    assert(crcHexString(hash) == "352441C2");
}

///
@safe unittest
{
    //Using the basic API
    CRC32 hash;
    ubyte[1024] data;
    //Initialize data here...
    hash.put(data);
    ubyte[4] result = hash.finish();
}

///
@safe unittest
{
    //Let's use the template features:
    //Note: When passing a CRC32 to a function, it must be passed by reference!
    void doSomething(T)(ref T hash)
    if (isDigest!T)
    {
      hash.put(cast(ubyte) 0);
    }
    CRC32 crc;
    crc.start();
    doSomething(crc);
    assert(crcHexString(crc.finish()) == "D202EF8D");
}

@safe unittest
{
    assert(isDigest!CRC32);
}

@system unittest
{
    ubyte[4] digest;

    CRC32 crc;
    crc.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    assert(crc.peek() == cast(ubyte[]) x"bd50274c");
    crc.start();
    crc.put(cast(ubyte[])"");
    assert(crc.finish() == cast(ubyte[]) x"00000000");

    digest = crc32Of("");
    assert(digest == cast(ubyte[]) x"00000000");

    //Test vector from http://rosettacode.org/wiki/CRC-32
    assert(crcHexString(crc32Of("The quick brown fox jumps over the lazy dog")) == "414FA339");

    digest = crc32Of("a");
    assert(digest == cast(ubyte[]) x"43beb7e8");

    digest = crc32Of("abc");
    assert(digest == cast(ubyte[]) x"c2412435");

    digest = crc32Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    assert(digest == cast(ubyte[]) x"5f3f1a17");

    digest = crc32Of("message digest");
    assert(digest == cast(ubyte[]) x"7f9d1520");

    digest = crc32Of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    assert(digest == cast(ubyte[]) x"d2e6c21f");

    digest = crc32Of("1234567890123456789012345678901234567890"~
                    "1234567890123456789012345678901234567890");
    assert(digest == cast(ubyte[]) x"724aa97c");

    assert(crcHexString(cast(ubyte[4]) x"c3fcd3d7") == "D7D3FCC3");
}

/**
 * This is a convenience alias for $(REF digest, std,digest,digest) using the
 * CRC32 implementation.
 *
 * Params:
 *      data = $(D InputRange) of $(D ElementType) implicitly convertible to
 *             $(D ubyte), $(D ubyte[]) or $(D ubyte[num]) or one or more arrays
 *             of any type.
 *
 * Returns:
 *      CRC32 of data
 */
//simple alias doesn't work here, hope this gets inlined...
ubyte[4] crc32Of(T...)(T data)
{
    return digest!(CRC32, T)(data);
}

///
@system unittest
{
    ubyte[] data = [4,5,7,25];
    assert(data.crc32Of == [167, 180, 199, 131]);

    import std.utf : byChar;
    assert("hello"d.byChar.crc32Of == [134, 166, 16, 54]);

    ubyte[4] hash = "abc".crc32Of();
    assert(hash == digest!CRC32("ab", "c"));

    import std.range : iota;
    enum ubyte S = 5, F = 66;
    assert(iota(S, F).crc32Of == [59, 140, 234, 154]);
}

/**
 * This is a convenience alias for $(REF toHexString, std,digest,digest)
 * producing the usual CRC32 string output.
 */
public alias crcHexString = toHexString!(Order.decreasing);
///ditto
public alias crcHexString = toHexString!(Order.decreasing, 16);


/**
 * OOP API CRC32 implementation.
 * See $(D std.digest.digest) for differences between template and OOP API.
 *
 * This is an alias for $(D $(REF WrapperDigest, std,digest,digest)!CRC32), see
 * there for more information.
 */
alias CRC32Digest = WrapperDigest!CRC32;

///
@safe unittest
{
    //Simple example, hashing a string using Digest.digest helper function
    auto crc = new CRC32Digest();
    ubyte[] hash = crc.digest("abc");
    //Let's get a hash string
    assert(crcHexString(hash) == "352441C2");
}

///
@system unittest
{
     //Let's use the OOP features:
    void test(Digest dig)
    {
      dig.put(cast(ubyte) 0);
    }
    auto crc = new CRC32Digest();
    test(crc);

    //Let's use a custom buffer:
    ubyte[4] buf;
    ubyte[] result = crc.finish(buf[]);
    assert(crcHexString(result) == "D202EF8D");
}

///
@safe unittest
{
    //Simple example
    auto hash = new CRC32Digest();
    hash.put(cast(ubyte) 0);
    ubyte[] result = hash.finish();
}

///
@system unittest
{
    //using a supplied buffer
    ubyte[4] buf;
    auto hash = new CRC32Digest();
    hash.put(cast(ubyte) 0);
    ubyte[] result = hash.finish(buf[]);
    //The result is now in result (and in buf. If you pass a buffer which is bigger than
    //necessary, result will have the correct length, but buf will still have it's original
    //length)
}

@system unittest
{
    import std.range;

    auto crc = new CRC32Digest();

    crc.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    assert(crc.peek() == cast(ubyte[]) x"bd50274c");
    crc.reset();
    crc.put(cast(ubyte[])"");
    assert(crc.finish() == cast(ubyte[]) x"00000000");

    crc.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    ubyte[20] result;
    auto result2 = crc.finish(result[]);
    assert(result[0 .. 4] == result2 && result2 == cast(ubyte[]) x"bd50274c");

    debug
        assertThrown!Error(crc.finish(result[0 .. 3]));

    assert(crc.length == 4);

    assert(crc.digest("") == cast(ubyte[]) x"00000000");

    assert(crc.digest("a") == cast(ubyte[]) x"43beb7e8");

    assert(crc.digest("abc") == cast(ubyte[]) x"c2412435");

    assert(crc.digest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
           == cast(ubyte[]) x"5f3f1a17");

    assert(crc.digest("message digest") == cast(ubyte[]) x"7f9d1520");

    assert(crc.digest("abcdefghijklmnopqrstuvwxyz")
           == cast(ubyte[]) x"bd50274c");

    assert(crc.digest("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
           == cast(ubyte[]) x"d2e6c21f");

    assert(crc.digest("1234567890123456789012345678901234567890",
                                   "1234567890123456789012345678901234567890")
           == cast(ubyte[]) x"724aa97c");

    ubyte[] onemilliona = new ubyte[1000000];
    onemilliona[] = 'a';
    auto digest = crc32Of(onemilliona);
    assert(digest == cast(ubyte[]) x"BCBF25DC");

    auto oneMillionRange = repeat!ubyte(cast(ubyte)'a', 1000000);
    digest = crc32Of(oneMillionRange);
    assert(digest == cast(ubyte[]) x"BCBF25DC");
}
