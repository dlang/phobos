/**
<script type="text/javascript">inhibitQuickIndex = 1</script>

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

 * Cyclic Redundancy Check (32-bit) implementation.
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
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>
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
 * MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>
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

import std.bitmanip;

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

private immutable uint[256] crc32_table = ()
{
    static uint crc32TableValue(uint c) pure
    {
        foreach (k; 0 .. 8)
            c = (c & 1) ? 0xedb88320L ^ (c >> 1) : c >> 1;
        return c;
    }

    uint[256] result;
    foreach(uint i, ref r; result)
        r = crc32TableValue(i);
    return result;
}();

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
        @trusted pure nothrow void put(scope const(ubyte)[] data...)
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
        @trusted pure nothrow void start()
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
        @trusted pure nothrow ubyte[4] finish()
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
        @trusted pure nothrow ubyte[4] peek() const
        {
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
