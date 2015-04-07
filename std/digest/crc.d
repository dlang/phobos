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
 * CRCs are usually printed with the MSB first. When using $(XREF digest.digest, toHexString) the result
 * will be in an unexpected order. Use $(XREF digest.digest, toHexString)s optional order parameter
 * to specify decreasing order for the correct result. The $(LREF crcHexString) alias can also
 * be used for this purpose.
 *
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Authors:   Pavel "EvilOne" Minayev, Alex Rønne Petersen, Johannes Pfau
 *
 * References:
 *      $(LINK2 http://en.wikipedia.org/wiki/Cyclic_redundancy_check, Wikipedia on CRC)
 *
 * Source: $(PHOBOSSRC std/digest/_crc.d)
 *
 * Macros:
 * WIKI = Phobos/StdUtilDigestCRC32
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
unittest
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
unittest
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

private immutable uint[256] crc32_table =
[
    0x00000000,0x77073096,0xee0e612c,0x990951ba,0x076dc419,0x706af48f,0xe963a535,
    0x9e6495a3,0x0edb8832,0x79dcb8a4,0xe0d5e91e,0x97d2d988,0x09b64c2b,0x7eb17cbd,
    0xe7b82d07,0x90bf1d91,0x1db71064,0x6ab020f2,0xf3b97148,0x84be41de,0x1adad47d,
    0x6ddde4eb,0xf4d4b551,0x83d385c7,0x136c9856,0x646ba8c0,0xfd62f97a,0x8a65c9ec,
    0x14015c4f,0x63066cd9,0xfa0f3d63,0x8d080df5,0x3b6e20c8,0x4c69105e,0xd56041e4,
    0xa2677172,0x3c03e4d1,0x4b04d447,0xd20d85fd,0xa50ab56b,0x35b5a8fa,0x42b2986c,
    0xdbbbc9d6,0xacbcf940,0x32d86ce3,0x45df5c75,0xdcd60dcf,0xabd13d59,0x26d930ac,
    0x51de003a,0xc8d75180,0xbfd06116,0x21b4f4b5,0x56b3c423,0xcfba9599,0xb8bda50f,
    0x2802b89e,0x5f058808,0xc60cd9b2,0xb10be924,0x2f6f7c87,0x58684c11,0xc1611dab,
    0xb6662d3d,0x76dc4190,0x01db7106,0x98d220bc,0xefd5102a,0x71b18589,0x06b6b51f,
    0x9fbfe4a5,0xe8b8d433,0x7807c9a2,0x0f00f934,0x9609a88e,0xe10e9818,0x7f6a0dbb,
    0x086d3d2d,0x91646c97,0xe6635c01,0x6b6b51f4,0x1c6c6162,0x856530d8,0xf262004e,
    0x6c0695ed,0x1b01a57b,0x8208f4c1,0xf50fc457,0x65b0d9c6,0x12b7e950,0x8bbeb8ea,
    0xfcb9887c,0x62dd1ddf,0x15da2d49,0x8cd37cf3,0xfbd44c65,0x4db26158,0x3ab551ce,
    0xa3bc0074,0xd4bb30e2,0x4adfa541,0x3dd895d7,0xa4d1c46d,0xd3d6f4fb,0x4369e96a,
    0x346ed9fc,0xad678846,0xda60b8d0,0x44042d73,0x33031de5,0xaa0a4c5f,0xdd0d7cc9,
    0x5005713c,0x270241aa,0xbe0b1010,0xc90c2086,0x5768b525,0x206f85b3,0xb966d409,
    0xce61e49f,0x5edef90e,0x29d9c998,0xb0d09822,0xc7d7a8b4,0x59b33d17,0x2eb40d81,
    0xb7bd5c3b,0xc0ba6cad,0xedb88320,0x9abfb3b6,0x03b6e20c,0x74b1d29a,0xead54739,
    0x9dd277af,0x04db2615,0x73dc1683,0xe3630b12,0x94643b84,0x0d6d6a3e,0x7a6a5aa8,
    0xe40ecf0b,0x9309ff9d,0x0a00ae27,0x7d079eb1,0xf00f9344,0x8708a3d2,0x1e01f268,
    0x6906c2fe,0xf762575d,0x806567cb,0x196c3671,0x6e6b06e7,0xfed41b76,0x89d32be0,
    0x10da7a5a,0x67dd4acc,0xf9b9df6f,0x8ebeeff9,0x17b7be43,0x60b08ed5,0xd6d6a3e8,
    0xa1d1937e,0x38d8c2c4,0x4fdff252,0xd1bb67f1,0xa6bc5767,0x3fb506dd,0x48b2364b,
    0xd80d2bda,0xaf0a1b4c,0x36034af6,0x41047a60,0xdf60efc3,0xa867df55,0x316e8eef,
    0x4669be79,0xcb61b38c,0xbc66831a,0x256fd2a0,0x5268e236,0xcc0c7795,0xbb0b4703,
    0x220216b9,0x5505262f,0xc5ba3bbe,0xb2bd0b28,0x2bb45a92,0x5cb36a04,0xc2d7ffa7,
    0xb5d0cf31,0x2cd99e8b,0x5bdeae1d,0x9b64c2b0,0xec63f226,0x756aa39c,0x026d930a,
    0x9c0906a9,0xeb0e363f,0x72076785,0x05005713,0x95bf4a82,0xe2b87a14,0x7bb12bae,
    0x0cb61b38,0x92d28e9b,0xe5d5be0d,0x7cdcefb7,0x0bdbdf21,0x86d3d2d4,0xf1d4e242,
    0x68ddb3f8,0x1fda836e,0x81be16cd,0xf6b9265b,0x6fb077e1,0x18b74777,0x88085ae6,
    0xff0f6a70,0x66063bca,0x11010b5c,0x8f659eff,0xf862ae69,0x616bffd3,0x166ccf45,
    0xa00ae278,0xd70dd2ee,0x4e048354,0x3903b3c2,0xa7672661,0xd06016f7,0x4969474d,
    0x3e6e77db,0xaed16a4a,0xd9d65adc,0x40df0b66,0x37d83bf0,0xa9bcae53,0xdebb9ec5,
    0x47b2cf7f,0x30b5ffe9,0xbdbdf21c,0xcabac28a,0x53b39330,0x24b4a3a6,0xbad03605,
    0xcdd70693,0x54de5729,0x23d967bf,0xb3667a2e,0xc4614ab8,0x5d681b02,0x2a6f2b94,
    0xb40bbe37,0xc30c8ea1,0x5a05df1b,0x2d02ef8d
];

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
         * Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and
         * $(D const(ubyte)[]).
         */
        void put(scope const(ubyte)[] data...) @trusted pure nothrow @nogc
        {
            foreach (val; data)
                _state = (_state >> 8) ^ crc32_table[cast(ubyte)_state ^ val];
        }
        ///
        unittest
        {
            CRC32 dig;
            dig.put(cast(ubyte)0); //single ubyte
            dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
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
        unittest
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
        unittest
        {
            //Simple example
            CRC32 hash;
            hash.put(cast(ubyte)0);
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
unittest
{
    //Simple example, hashing a string using crc32Of helper function
    ubyte[4] hash = crc32Of("abc");
    //Let's get a hash string
    assert(crcHexString(hash) == "352441C2");
}

///
unittest
{
    //Using the basic API
    CRC32 hash;
    ubyte[1024] data;
    //Initialize data here...
    hash.put(data);
    ubyte[4] result = hash.finish();
}

///
unittest
{
    //Let's use the template features:
    //Note: When passing a CRC32 to a function, it must be passed by reference!
    void doSomething(T)(ref T hash) if(isDigest!T)
    {
      hash.put(cast(ubyte)0);
    }
    CRC32 crc;
    crc.start();
    doSomething(crc);
    assert(crcHexString(crc.finish()) == "D202EF8D");
}

unittest
{
    assert(isDigest!CRC32);
}

unittest
{
    ubyte[4] digest;

    CRC32 crc;
    crc.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    assert(crc.peek() == cast(ubyte[])x"bd50274c");
    crc.start();
    crc.put(cast(ubyte[])"");
    assert(crc.finish() == cast(ubyte[])x"00000000");

    digest = crc32Of("");
    assert(digest == cast(ubyte[])x"00000000");

    //Test vector from http://rosettacode.org/wiki/CRC-32
    assert(crcHexString(crc32Of("The quick brown fox jumps over the lazy dog")) == "414FA339");

    digest = crc32Of("a");
    assert(digest == cast(ubyte[])x"43beb7e8");

    digest = crc32Of("abc");
    assert(digest == cast(ubyte[])x"c2412435");

    digest = crc32Of("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    assert(digest == cast(ubyte[])x"5f3f1a17");

    digest = crc32Of("message digest");
    assert(digest == cast(ubyte[])x"7f9d1520");

    digest = crc32Of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    assert(digest == cast(ubyte[])x"d2e6c21f");

    digest = crc32Of("1234567890123456789012345678901234567890"~
                    "1234567890123456789012345678901234567890");
    assert(digest == cast(ubyte[])x"724aa97c");

    assert(crcHexString(cast(ubyte[4])x"c3fcd3d7") == "D7D3FCC3");
}

/**
 * This is a convenience alias for $(XREF digest.digest, digest) using the
 * CRC32 implementation.
 */
//simple alias doesn't work here, hope this gets inlined...
auto crc32Of(T...)(T data)
{
    return digest!(CRC32, T)(data);
}

/**
 * This is a convenience alias for $(XREF digest.digest, toHexString) producing the usual
 * CRC32 string output.
 */
public alias crcHexString = toHexString!(Order.decreasing);
///ditto
public alias crcHexString = toHexString!(Order.decreasing, 16);

///
unittest
{
    ubyte[4] hash = crc32Of("abc");
    assert(hash == digest!CRC32("abc")); //This is the same as above
}

/**
 * OOP API CRC32 implementation.
 * See $(D std.digest.digest) for differences between template and OOP API.
 *
 * This is an alias for $(XREF digest.digest, WrapperDigest)!CRC32, see
 * $(XREF digest.digest, WrapperDigest) for more information.
 */
alias CRC32Digest = WrapperDigest!CRC32;

///
unittest
{
    //Simple example, hashing a string using Digest.digest helper function
    auto crc = new CRC32Digest();
    ubyte[] hash = crc.digest("abc");
    //Let's get a hash string
    assert(crcHexString(hash) == "352441C2");
}

///
unittest
{
     //Let's use the OOP features:
    void test(Digest dig)
    {
      dig.put(cast(ubyte)0);
    }
    auto crc = new CRC32Digest();
    test(crc);

    //Let's use a custom buffer:
    ubyte[4] buf;
    ubyte[] result = crc.finish(buf[]);
    assert(crcHexString(result) == "D202EF8D");
}

///
unittest
{
    //Simple example
    auto hash = new CRC32Digest();
    hash.put(cast(ubyte)0);
    ubyte[] result = hash.finish();
}

///
unittest
{
    //using a supplied buffer
    ubyte[4] buf;
    auto hash = new CRC32Digest();
    hash.put(cast(ubyte)0);
    ubyte[] result = hash.finish(buf[]);
    //The result is now in result (and in buf. If you pass a buffer which is bigger than
    //necessary, result will have the correct length, but buf will still have it's original
    //length)
}

unittest
{
    import std.range;

    auto crc = new CRC32Digest();

    crc.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    assert(crc.peek() == cast(ubyte[])x"bd50274c");
    crc.reset();
    crc.put(cast(ubyte[])"");
    assert(crc.finish() == cast(ubyte[])x"00000000");

    crc.put(cast(ubyte[])"abcdefghijklmnopqrstuvwxyz");
    ubyte[20] result;
    auto result2 = crc.finish(result[]);
    assert(result[0 .. 4] == result2 && result2 == cast(ubyte[])x"bd50274c");

    debug
        assertThrown!Error(crc.finish(result[0 .. 3]));

    assert(crc.length == 4);

    assert(crc.digest("") == cast(ubyte[])x"00000000");

    assert(crc.digest("a") == cast(ubyte[])x"43beb7e8");

    assert(crc.digest("abc") == cast(ubyte[])x"c2412435");

    assert(crc.digest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
           == cast(ubyte[])x"5f3f1a17");

    assert(crc.digest("message digest") == cast(ubyte[])x"7f9d1520");

    assert(crc.digest("abcdefghijklmnopqrstuvwxyz")
           == cast(ubyte[])x"bd50274c");

    assert(crc.digest("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
           == cast(ubyte[])x"d2e6c21f");

    assert(crc.digest("1234567890123456789012345678901234567890",
                                   "1234567890123456789012345678901234567890")
           == cast(ubyte[])x"724aa97c");

    ubyte[] onemilliona = new ubyte[1000000];
    onemilliona[] = 'a';
    auto digest = crc32Of(onemilliona);
    assert(digest == cast(ubyte[])x"BCBF25DC");

    auto oneMillionRange = repeat!ubyte(cast(ubyte)'a', 1000000);
    digest = crc32Of(oneMillionRange);
    assert(digest == cast(ubyte[])x"BCBF25DC");
}
