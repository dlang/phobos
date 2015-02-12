/**
 * This module describes the digest APIs used in Phobos. All digests follow these APIs.
 * Additionally, this module contains useful helper methods which can be used with every _digest type.
 *
$(SCRIPT inhibitQuickIndex = 1;)

$(DIVC quickindex,
$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW Template API) $(TD $(MYREF isDigest) $(MYREF DigestType) $(MYREF hasPeek)
  $(MYREF ExampleDigest) $(MYREF _digest) $(MYREF hexDigest) $(MYREF makeDigest)
)
)
$(TR $(TDNW OOP API) $(TD $(MYREF Digest)
)
)
$(TR $(TDNW Helper functions) $(TD $(MYREF toHexString))
)
$(TR $(TDNW Implementation helpers) $(TD $(MYREF digestLength) $(MYREF WrapperDigest))
)
)
)

 * APIs:
 * There are two APIs for digests: The template API and the OOP API. The template API uses structs
 * and template helpers like $(LREF isDigest). The OOP API implements digests as classes inheriting
 * the $(LREF Digest) interface. All digests are named so that the template API struct is called "$(B x)"
 * and the OOP API class is called "$(B x)Digest". For example we have $(D MD5) <--> $(D MD5Digest),
 * $(D CRC32) <--> $(D CRC32Digest), etc.
 *
 * The template API is slightly more efficient. It does not have to allocate memory dynamically,
 * all memory is allocated on the stack. The OOP API has to allocate in the finish method if no
 * buffer was provided. If you provide a buffer to the OOP APIs finish function, it doesn't allocate,
 * but the $(LREF Digest) classes still have to be created using $(D new) which allocates them using the GC.
 *
 * The OOP API is useful to change the _digest function and/or _digest backend at 'runtime'. The benefit here
 * is that switching e.g. Phobos MD5Digest and an OpenSSLMD5Digest implementation is ABI compatible.
 *
 * If just one specific _digest type and backend is needed, the template API is usually a good fit.
 * In this simplest case, the template API can even be used without templates: Just use the "$(B x)" structs
 * directly.
 *
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 * Johannes Pfau
 *
 * Source:    $(PHOBOSSRC std/_digest/_digest.d)
 *
 * Macros:
 * MYREF2 = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$2">$1</a>&nbsp;</font>
 * MYREF3 = <a href="#$2">$(D $1)</a>
 *
 * CTFE:
 * Digests do not work in CTFE
 *
 * TODO:
 * Digesting single bits (as opposed to bytes) is not implemented. This will be done as another
 * template constraint helper (hasBitDigesting!T) and an additional interface (BitDigest)
 */
/*          Copyright Johannes Pfau 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.digest.digest;

import std.traits;
import std.typetuple : allSatisfy;
public import std.ascii : LetterCase;


///
unittest
{
    import std.digest.crc;

    //Simple example
    char[8] hexHash = hexDigest!CRC32("The quick brown fox jumps over the lazy dog");
    assert(hexHash == "39A34F41");

    //Simple example, using the API manually
    CRC32 context = makeDigest!CRC32();
    context.put(cast(ubyte[])"The quick brown fox jumps over the lazy dog");
    ubyte[4] hash = context.finish();
    assert(toHexString(hash) == "39A34F41");
}

///
unittest
{
    //Generating the hashes of a file, idiomatic D way
    import std.digest.crc, std.digest.sha, std.digest.md;
    import std.stdio;

    // Digests a file and prints the result.
    void digestFile(Hash)(string filename) if(isDigest!Hash)
    {
        auto file = File(filename);
        auto result = digest!Hash(file.byChunk(4096 * 1024));
        writefln("%s (%s) = %s", Hash.stringof, filename, toHexString(result));
    }

    void main(string[] args)
    {
        foreach (name; args[1 .. $])
        {
            digestFile!MD5(name);
            digestFile!SHA1(name);
            digestFile!CRC32(name);
        }
    }
}
///
unittest
{
    //Generating the hashes of a file using the template API
    import std.digest.crc, std.digest.sha, std.digest.md;
    import std.stdio;
    // Digests a file and prints the result.
    void digestFile(Hash)(ref Hash hash, string filename) if(isDigest!Hash)
    {
        File file = File(filename);

        //As digests imlement OutputRange, we could use std.algorithm.copy
        //Let's do it manually for now
        foreach (buffer; file.byChunk(4096 * 1024))
            hash.put(buffer);

        auto result = hash.finish();
        writefln("%s (%s) = %s", Hash.stringof, filename, toHexString(result));
    }

    void uMain(string[] args)
    {
        MD5 md5;
        SHA1 sha1;
        CRC32 crc32;

        md5.start();
        sha1.start();
        crc32.start();

        foreach (arg; args[1 .. $])
        {
            digestFile(md5, arg);
            digestFile(sha1, arg);
            digestFile(crc32, arg);
        }
    }
}

///
unittest
{
    import std.digest.crc, std.digest.sha, std.digest.md;
    import std.stdio;

    // Digests a file and prints the result.
    void digestFile(Digest hash, string filename)
    {
        File file = File(filename);

        //As digests implement OutputRange, we could use std.algorithm.copy
        //Let's do it manually for now
        foreach (buffer; file.byChunk(4096 * 1024))
          hash.put(buffer);

        ubyte[] result = hash.finish();
        writefln("%s (%s) = %s", typeid(hash).toString(), filename, toHexString(result));
    }

    void umain(string[] args)
    {
        auto md5 = new MD5Digest();
        auto sha1 = new SHA1Digest();
        auto crc32 = new CRC32Digest();

        foreach (arg; args[1 .. $])
        {
          digestFile(md5, arg);
          digestFile(sha1, arg);
          digestFile(crc32, arg);
        }
    }
}

version(StdDdoc)
    version = ExampleDigest;

version(ExampleDigest)
{
    /**
     * This documents the general structure of a Digest in the template API.
     * All digest implementations should implement the following members and therefore pass
     * the $(LREF isDigest) test.
     *
     * Note:
     * $(UL
     * $(LI A digest must be a struct (value type) to pass the $(LREF isDigest) test.)
     * $(LI A digest passing the $(LREF isDigest) test is always an $(D OutputRange))
     * )
     */
    struct ExampleDigest
    {
        public:
            /**
             * Use this to feed the digest with data.
             * Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and
             * $(D const(ubyte)[]).
             * The following usages of $(D put) must work for any type which passes $(LREF isDigest):
             * Examples:
             * ----
             * ExampleDigest dig;
             * dig.put(cast(ubyte)0); //single ubyte
             * dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
             * ubyte[10] buf;
             * dig.put(buf); //buffer
             * ----
             */
            @trusted void put(scope const(ubyte)[] data...)
            {

            }

            /**
             * This function is used to (re)initialize the digest.
             * It must be called before using the digest and it also works as a 'reset' function
             * if the digest has already processed data.
             */
            @trusted void start()
            {

            }

            /**
             * The finish function returns the final hash sum and resets the Digest.
             *
             * Note:
             * The actual type returned by finish depends on the digest implementation.
             * $(D ubyte[16]) is just used as an example. It is guaranteed that the type is a
             * static array of ubytes.
             *
             * $(UL
             * $(LI Use $(LREF DigestType) to obtain the actual return type.)
             * $(LI Use $(LREF digestLength) to obtain the length of the ubyte array.)
             * )
             */
            @trusted ubyte[16] finish()
            {
                return (ubyte[16]).init;
            }
    }
}

///
unittest
{
    //Using the OutputRange feature
    import std.algorithm : copy;
    import std.range : repeat;
    import std.digest.md;

    auto oneMillionRange = repeat!ubyte(cast(ubyte)'a', 1000000);
    auto ctx = makeDigest!MD5();
    copy(oneMillionRange, &ctx); //Note: You must pass a pointer to copy!
    assert(ctx.finish().toHexString() == "7707D6AE4E027C70EEA2A935C2296F21");
}

/**
 * Use this to check if a type is a digest. See $(LREF ExampleDigest) to see what
 * a type must provide to pass this check.
 *
 * Note:
 * This is very useful as a template constraint (see examples)
 *
 * BUGS:
 * $(UL
 * $(LI Does not yet verify that put takes scope parameters.)
 * $(LI Should check that finish() returns a ubyte[num] array)
 * )
 */
template isDigest(T)
{
    import std.range : isOutputRange;
    enum bool isDigest = isOutputRange!(T, const(ubyte)[]) && isOutputRange!(T, ubyte) &&
        is(T == struct) &&
        is(typeof(
        {
            T dig = void; //Can define
            dig.put(cast(ubyte)0, cast(ubyte)0); //varags
            dig.start(); //has start
            auto value = dig.finish(); //has finish
        }));
}

///
unittest
{
    import std.digest.crc;
    static assert(isDigest!CRC32);
}
///
unittest
{
    import std.digest.crc;
    void myFunction(T)() if(isDigest!T)
    {
        T dig;
        dig.start();
        auto result = dig.finish();
    }
    myFunction!CRC32();
}

/**
 * Use this template to get the type which is returned by a digest's $(LREF finish) method.
 */
template DigestType(T)
{
    static if(isDigest!T)
    {
        alias DigestType =
            ReturnType!(typeof(
            {
                T dig = void;
                return dig.finish();
            }));
    }
    else
        static assert(false, T.stringof ~ " is not a digest! (fails isDigest!T)");
}

///
unittest
{
    import std.digest.crc;
    assert(is(DigestType!(CRC32) == ubyte[4]));
}
///
unittest
{
    import std.digest.crc;
    CRC32 dig;
    dig.start();
    DigestType!CRC32 result = dig.finish();
}

/**
 * Used to check if a digest supports the $(D peek) method.
 * Peek has exactly the same function signatures as finish, but it doesn't reset
 * the digest's internal state.
 *
 * Note:
 * $(UL
 * $(LI This is very useful as a template constraint (see examples))
 * $(LI This also checks if T passes $(LREF isDigest))
 * )
 */
template hasPeek(T)
{
    enum bool hasPeek = isDigest!T &&
        is(typeof(
        {
            T dig = void; //Can define
            DigestType!T val = dig.peek();
        }));
}

///
unittest
{
    import std.digest.crc, std.digest.md;
    assert(!hasPeek!(MD5));
    assert(hasPeek!CRC32);
}
///
unittest
{
    import std.digest.crc;
    void myFunction(T)() if(hasPeek!T)
    {
        T dig;
        dig.start();
        auto result = dig.peek();
    }
    myFunction!CRC32();
}

private template isDigestibleRange(Range)
{
    import std.digest.md;
    import std.range : isInputRange, ElementType;
    enum bool isDigestibleRange = isInputRange!Range && is(typeof(
          {
          MD5 ha; //Could use any conformant hash
          ElementType!Range val;
          ha.put(val);
          }));
}

/**
 * This is a convenience function to calculate a hash using the template API.
 * Every digest passing the $(LREF isDigest) test can be used with this function.
 *
 * Params:
 *  range= an $(D InputRange) with $(D ElementType) $(D ubyte), $(D ubyte[]) or $(D ubyte[num])
 */
DigestType!Hash digest(Hash, Range)(auto ref Range range) if(!isArray!Range
    && isDigestibleRange!Range)
{
    import std.algorithm : copy;
    Hash hash;
    hash.start();
    copy(range, &hash);
    return hash.finish();
}

///
unittest
{
    import std.digest.md;
    import std.range : repeat;
    auto testRange = repeat!ubyte(cast(ubyte)'a', 100);
    auto md5 = digest!MD5(testRange);
}

/**
 * This overload of the digest function handles arrays.
 *
 * Params:
 *  data= one or more arrays of any type
 */
DigestType!Hash digest(Hash, T...)(scope const T data) if(allSatisfy!(isArray, typeof(data)))
{
    Hash hash;
    hash.start();
    foreach(datum; data)
        hash.put(cast(const(ubyte[]))datum);
    return hash.finish();
}

///
unittest
{
    import std.digest.md, std.digest.sha, std.digest.crc;
    auto md5   = digest!MD5(  "The quick brown fox jumps over the lazy dog");
    auto sha1  = digest!SHA1( "The quick brown fox jumps over the lazy dog");
    auto crc32 = digest!CRC32("The quick brown fox jumps over the lazy dog");
    assert(toHexString(crc32) == "39A34F41");
}

///
unittest
{
    import std.digest.crc;
    auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
    assert(toHexString(crc32) == "39A34F41");
}

/**
 * This is a convenience function similar to $(LREF digest), but it returns the string
 * representation of the hash. Every digest passing the $(LREF isDigest) test can be used with this
 * function.
 *
 * Params:
 *  order= the order in which the bytes are processed (see $(LREF toHexString))
 *  range= an $(D InputRange) with $(D ElementType) $(D ubyte), $(D ubyte[]) or $(D ubyte[num])
 */
char[digestLength!(Hash)*2] hexDigest(Hash, Order order = Order.increasing, Range)(ref Range range)
    if(!isArray!Range && isDigestibleRange!Range)
{
    return toHexString!order(digest!Hash(range));
}

///
unittest
{
    import std.digest.md;
    import std.range : repeat;
    auto testRange = repeat!ubyte(cast(ubyte)'a', 100);
    assert(hexDigest!MD5(testRange) == "36A92CC94A9E0FA21F625F8BFB007ADF");
}

/**
 * This overload of the hexDigest function handles arrays.
 *
 * Params:
 *  order= the order in which the bytes are processed (see $(LREF toHexString))
 *  data= one or more arrays of any type
 */
char[digestLength!(Hash)*2] hexDigest(Hash, Order order = Order.increasing, T...)(scope const T data)
    if(allSatisfy!(isArray, typeof(data)))
{
    return toHexString!order(digest!Hash(data));
}

///
unittest
{
    import std.digest.crc;
    assert(hexDigest!(CRC32, Order.decreasing)("The quick brown fox jumps over the lazy dog") == "414FA339");
}
///
unittest
{
    import std.digest.crc;
    assert(hexDigest!(CRC32, Order.decreasing)("The quick ", "brown ", "fox jumps over the lazy dog") == "414FA339");
}

/**
 * This is a convenience function which returns an initialized digest, so it's not necessary to call
 * start manually.
 */
Hash makeDigest(Hash)()
{
    Hash hash;
    hash.start();
    return hash;
}

///
unittest
{
    import std.digest.md;
    auto md5 = makeDigest!MD5();
    md5.put(0);
    assert(toHexString(md5.finish()) == "93B885ADFE0DA089CDF634904FD59F71");
}

/*+*************************** End of template part, welcome to OOP land **************************/

/**
 * This describes the OOP API. To understand when to use the template API and when to use the OOP API,
 * see the module documentation at the top of this page.
 *
 * The Digest interface is the base interface which is implemented by all digests.
 *
 * Note:
 * A Digest implementation is always an $(D OutputRange)
 */
interface Digest
{
    public:
        /**
         * Use this to feed the digest with data.
         * Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and
         * $(D const(ubyte)[]).
         *
         * Examples:
         * ----
         * void test(Digest dig)
         * {
         *     dig.put(cast(ubyte)0); //single ubyte
         *     dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
         *     ubyte[10] buf;
         *     dig.put(buf); //buffer
         * }
         * ----
         */
        @trusted nothrow void put(scope const(ubyte)[] data...);

        /**
         * Resets the internal state of the digest.
         * Note:
         * $(LREF finish) calls this internally, so it's not necessary to call
         * $(D reset) manually after a call to $(LREF finish).
         */
        @trusted nothrow void reset();

        /**
         * This is the length in bytes of the hash value which is returned by $(LREF finish).
         * It's also the required size of a buffer passed to $(LREF finish).
         */
        @trusted nothrow @property size_t length() const;

        /**
         * The finish function returns the hash value. It takes an optional buffer to copy the data
         * into. If a buffer is passed, it must be at least $(LREF length) bytes big.
         */
        @trusted nothrow ubyte[] finish();
        ///ditto
        nothrow ubyte[] finish(scope ubyte[] buf);
        //@@@BUG@@@ http://d.puremagic.com/issues/show_bug.cgi?id=6549
        /*in
        {
            assert(buf.length >= this.length);
        }*/

        /**
         * This is a convenience function to calculate the hash of a value using the OOP API.
         */
        final @trusted nothrow ubyte[] digest(scope const(void[])[] data...)
        {
            this.reset();
            foreach(datum; data)
                this.put(cast(ubyte[])datum);
            return this.finish();
        }
}

///
unittest
{
    //Using the OutputRange feature
    import std.algorithm : copy;
    import std.range : repeat;
    import std.digest.md;

    auto oneMillionRange = repeat!ubyte(cast(ubyte)'a', 1000000);
    auto ctx = new MD5Digest();
    copy(oneMillionRange, ctx);
    assert(ctx.finish().toHexString() == "7707D6AE4E027C70EEA2A935C2296F21");
}

///
unittest
{
    import std.digest.md, std.digest.sha, std.digest.crc;
    ubyte[] md5   = (new MD5Digest()).digest("The quick brown fox jumps over the lazy dog");
    ubyte[] sha1  = (new SHA1Digest()).digest("The quick brown fox jumps over the lazy dog");
    ubyte[] crc32 = (new CRC32Digest()).digest("The quick brown fox jumps over the lazy dog");
    assert(crcHexString(crc32) == "414FA339");
}

///
unittest
{
    import std.digest.crc;
    ubyte[] crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
    assert(crcHexString(crc32) == "414FA339");
}

unittest
{
    import std.range : isOutputRange;
    assert(!isDigest!(Digest));
    assert(isOutputRange!(Digest, ubyte));
}

///
unittest
{
    void test(Digest dig)
    {
        dig.put(cast(ubyte)0); //single ubyte
        dig.put(cast(ubyte)0, cast(ubyte)0); //variadic
        ubyte[10] buf;
        dig.put(buf); //buffer
    }
}

/*+*************************** End of OOP part, helper functions follow ***************************/

/**
 * See $(LREF toHexString)
 */
enum Order : bool
{
    increasing, ///
    decreasing ///
}


/**
 * Used to convert a hash value (a static or dynamic array of ubytes) to a string.
 * Can be used with the OOP and with the template API.
 *
 * The additional order parameter can be used to specify the order of the input data.
 * By default the data is processed in increasing order, starting at index 0. To process it in the
 * opposite order, pass Order.decreasing as a parameter.
 *
 * The additional letterCase parameter can be used to specify the case of the output data.
 * By default the output is in upper case. To change it to the lower case
 * pass LetterCase.lower as a parameter.
 */
char[num*2] toHexString(Order order = Order.increasing, size_t num, LetterCase letterCase = LetterCase.upper)
(in ubyte[num] digest)
{
    static if (letterCase == LetterCase.upper)
    {
        import std.ascii : hexDigits = hexDigits;
    }
    else
    {
        import std.ascii : hexDigits = lowerHexDigits;
    }


    char[num*2] result;
    size_t i;

    static if(order == Order.increasing)
    {
        foreach(u; digest)
        {
            result[i++] = hexDigits[u >> 4];
            result[i++] = hexDigits[u & 15];
        }
    }
    else
    {
        size_t j = num - 1;
        while(i < num*2)
        {
            result[i++] = hexDigits[digest[j] >> 4];
            result[i++] = hexDigits[digest[j] & 15];
            j--;
        }
    }
    return result;
}

///ditto
auto toHexString(LetterCase letterCase, Order order = Order.increasing, size_t num)(in ubyte[num] digest)
{
    return toHexString!(order, num, letterCase)(digest);
}

///ditto
string toHexString(Order order = Order.increasing, LetterCase letterCase = LetterCase.upper)
(in ubyte[] digest)
{
    static if (letterCase == LetterCase.upper)
    {
        import std.ascii : hexDigits = hexDigits;
    }
    else
    {
        import std.ascii : hexDigits = lowerHexDigits;
    }

    auto result = new char[digest.length*2];
    size_t i;

    static if(order == Order.increasing)
    {
        foreach(u; digest)
        {
            result[i++] = hexDigits[u >> 4];
            result[i++] = hexDigits[u & 15];
        }
    }
    else
    {
        import std.range : retro;
        foreach(u; retro(digest))
        {
            result[i++] = hexDigits[u >> 4];
            result[i++] = hexDigits[u & 15];
        }
    }
    import std.exception : assumeUnique;
    return assumeUnique(result);
}

///ditto
auto toHexString(LetterCase letterCase, Order order = Order.increasing)(in ubyte[] digest)
{
    return toHexString!(order, letterCase)(digest);
}

//For more example unittests, see Digest.digest, digest

///
unittest
{
    import std.digest.crc;
    //Test with template API:
    auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
    //Lower case variant:
    assert(toHexString!(LetterCase.lower)(crc32) == "39a34f41");
    //Usually CRCs are printed in this order, though:
    assert(toHexString!(Order.decreasing)(crc32) == "414FA339");
    assert(toHexString!(LetterCase.lower, Order.decreasing)(crc32) == "414fa339");
}

///
unittest
{
    import std.digest.crc;
    // With OOP API
    auto crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
    //Usually CRCs are printed in this order, though:
    assert(toHexString!(Order.decreasing)(crc32) == "414FA339");
}

unittest
{
    ubyte[16] data;
    assert(toHexString(data) == "00000000000000000000000000000000");

    assert(toHexString(cast(ubyte[4])[42, 43, 44, 45]) == "2A2B2C2D");
    assert(toHexString(cast(ubyte[])[42, 43, 44, 45]) == "2A2B2C2D");
    assert(toHexString!(Order.decreasing)(cast(ubyte[4])[42, 43, 44, 45]) == "2D2C2B2A");
    assert(toHexString!(Order.decreasing, LetterCase.lower)(cast(ubyte[4])[42, 43, 44, 45]) == "2d2c2b2a");
    assert(toHexString!(Order.decreasing)(cast(ubyte[])[42, 43, 44, 45]) == "2D2C2B2A");
}

/*+*********************** End of public helper part, private helpers follow ***********************/

/*
 * Used to convert from a ubyte[] slice to a ref ubyte[N].
 * This helper is used internally in the WrapperDigest template to wrap the template API's
 * finish function.
 */
ref T[N] asArray(size_t N, T)(ref T[] source, string errorMsg = "")
{
     assert(source.length >= N, errorMsg);
     return *cast(T[N]*)source.ptr;
}

/**
 * This helper is used internally in the WrapperDigest template, but it might be
 * useful for other purposes as well. It returns the length (in bytes) of the hash value
 * produced by T.
 */
template digestLength(T) if(isDigest!T)
{
    enum size_t digestLength = (ReturnType!(T.finish)).length;
}

/**
 * Wraps a template API hash struct into a Digest interface.
 * Modules providing digest implementations will usually provide
 * an alias for this template (e.g. MD5Digest, SHA1Digest, ...).
 */
class WrapperDigest(T) if(isDigest!T) : Digest
{
    protected:
        T _digest;

    public final:
        /**
         * Initializes the digest.
         */
        this()
        {
            _digest.start();
        }

        /**
         * Use this to feed the digest with data.
         * Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and
         * $(D const(ubyte)[]).
         */
        @trusted nothrow void put(scope const(ubyte)[] data...)
        {
            _digest.put(data);
        }

        /**
         * Resets the internal state of the digest.
         * Note:
         * $(LREF finish) calls this internally, so it's not necessary to call
         * $(D reset) manually after a call to $(LREF finish).
         */
        @trusted nothrow void reset()
        {
            _digest.start();
        }

        /**
         * This is the length in bytes of the hash value which is returned by $(LREF finish).
         * It's also the required size of a buffer passed to $(LREF finish).
         */
        @trusted nothrow @property size_t length() const pure
        {
            return digestLength!T;
        }

        /**
         * The finish function returns the hash value. It takes an optional buffer to copy the data
         * into. If a buffer is passed, it must have a length at least $(LREF length) bytes.
         *
         * Examples:
         * --------
         *
         * import std.digest.md;
         * ubyte[16] buf;
         * auto hash = new WrapperDigest!MD5();
         * hash.put(cast(ubyte)0);
         * auto result = hash.finish(buf[]);
         * //The result is now in result (and in buf). If you pass a buffer which is bigger than
         * //necessary, result will have the correct length, but buf will still have it's original
         * //length
         * --------
         */
        nothrow ubyte[] finish(scope ubyte[] buf)
        in
        {
            assert(buf.length >= this.length);
        }
        body
        {
            enum string msg = "Buffer needs to be at least " ~ digestLength!(T).stringof ~ " bytes " ~
                "big, check " ~ typeof(this).stringof ~ ".length!";
            asArray!(digestLength!T)(buf, msg) = _digest.finish();
            return buf[0 .. digestLength!T];
        }

        ///ditto
        @trusted nothrow ubyte[] finish()
        {
            enum len = digestLength!T;
            auto buf = new ubyte[len];
            asArray!(digestLength!T)(buf) = _digest.finish();
            return buf;
        }

        version(StdDdoc)
        {
            /**
             * Works like $(D finish) but does not reset the internal state, so it's possible
             * to continue putting data into this WrapperDigest after a call to peek.
             *
             * These functions are only available if $(D hasPeek!T) is true.
             */
            @trusted ubyte[] peek(scope ubyte[] buf) const;
            ///ditto
            @trusted ubyte[] peek() const;
        }
        else static if(hasPeek!T)
        {
            @trusted ubyte[] peek(scope ubyte[] buf) const
            in
            {
                assert(buf.length >= this.length);
            }
            body
            {
                enum string msg = "Buffer needs to be at least " ~ digestLength!(T).stringof ~ " bytes " ~
                    "big, check " ~ typeof(this).stringof ~ ".length!";
                asArray!(digestLength!T)(buf, msg) = _digest.peek();
                return buf[0 .. digestLength!T];
            }

            @trusted ubyte[] peek() const
            {
                enum len = digestLength!T;
                auto buf = new ubyte[len];
                asArray!(digestLength!T)(buf) = _digest.peek();
                return buf;
            }
        }
}

///
unittest
{
    import std.digest.md;
    //Simple example
    auto hash = new WrapperDigest!MD5();
    hash.put(cast(ubyte)0);
    auto result = hash.finish();
}

///
unittest
{
    //using a supplied buffer
    import std.digest.md;
    ubyte[16] buf;
    auto hash = new WrapperDigest!MD5();
    hash.put(cast(ubyte)0);
    auto result = hash.finish(buf[]);
    //The result is now in result (and in buf). If you pass a buffer which is bigger than
    //necessary, result will have the correct length, but buf will still have it's original
    //length
}
