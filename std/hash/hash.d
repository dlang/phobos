/**
<script type="text/javascript">inhibitQuickIndex = 1</script>

$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW Template API) $(TD $(MYREF isDigest) $(MYREF digestType) $(MYREF hasPeek)
  $(MYREF ExampleDigest) $(MYREF _digest)
)
)
$(TR $(TDNW OOP API) $(TD $(MYREF Digest)
)
)
$(TR $(TDNW Helper functions) $(TD $(MYREF toHexString))
)
$(TR $(TDNW Implementation helpers) $(TD $(MYREF digestLength) $(MYREF asArray) $(MYREF WrapperDigest))
)
)

 * This module describes the digest APIs used in Phobos. All digests follow these APIs.
 * Additionally, this module contains useful helper methods which can be used with every _hash type.
 *
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
 * The OOP API is useful to change the _hash function and/or _hash backend at 'runtime'. The benefit here
 * is that switching e.g. Phobos MD5Digest and an OpenSSLMD5Digest implementation is ABI compatible.
 *
 * If just one specific _hash type and backend is needed, the template API is usually a good fit.
 * In this simplest case, the template API can even be used without templates: Just use the "$(B x)" structs
 * directly.
 *
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>
 * Authors:
 * Johannes Pfau
 *
 * Source:    $(PHOBOSSRC std/util/_hash/_hash.d)
 *
 * Macros:
 * MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>
 * MYREF2 = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$2">$1</a>&nbsp;</font>
 * MYREF3 = <a href="#$2">$(D $1)</a>
 * 
 * CTFE:
 * Hashes do not work in CTFE
 * 
 * Examples:
 * ---------
 * //Generating the hashes of a file using the template API
 * import std.hash.crc, std.hash.sha, std.hash.md;
 *
 * import std.stdio;
 *
 * void main(string[] args)
 * {
 *     MD5 md5;
 *     SHA1 sha1;
 *     CRC32 crc32;
 *
 *     md5.start();
 *     sha1.start();
 *     crc32.start();
 *
 *     foreach (arg; args[1 .. $])
 *     {
 *         digestFile(md5, arg);
 *         digestFile(sha1, arg);
 *         digestFile(crc32, arg);
 *     }
 * }
 *
 * // Digests a file and prints the result.
 * void digestFile(Hash)(ref Hash hash, string filename) if(isDigest!Hash)
 * {
 *     File file = File(filename);
 *     scope(exit) file.close();
 *
 *     //As digests implement OutputRange, we could use std.algorithm.copy
 *     //Let's do it manually for now
 *     foreach (buffer; file.byChunk(4096 * 1024))
 *         hash.put(buffer);
 *
 *     auto result = hash.finish();
 *     writefln("%s (%s) = %s", hash.stringof, filename, toHexString(result));
 * }
 * ---------
 *
 * ---------
 * //The same using the OOP API
 * import std.hash.crc, std.hash.sha, std.hash.md;
 *
 * import std.stdio;
 *
 * void main(string[] args)
 * {
 *     auto md5 = new MD5Digest();
 *     auto sha1 = new SHA1Digest();
 *     auto crc32 = new CRC32Digest();
 *
 *     foreach (arg; args[1 .. $])
 *     {
 *         digestFile(md5, arg);
 *         digestFile(sha1, arg);
 *         digestFile(crc32, arg);
 *     }
 * }
 *
 * // Digests a file and prints the result.
 * void digestFile(Digest hash, string filename)
 * {
 *     File file = File(filename);
 *     scope(exit) file.close();
 *
 *     //As digests implement OutputRange, we could use std.algorithm.copy
 *     //Let's do it manually for now
 *     foreach (buffer; file.byChunk(4096 * 1024))
 *         hash.put(buffer);
 *
 *     auto result = hash.finish();
 *     writefln("%s (%s) = %s", typeid(hash).toString(), filename, toHexString(result));
 * }
 * ---------
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
module std.hash.hash;

import std.exception, std.range, std.traits;

//verify example
unittest
{
    //Generating the hashes of a file using the template API
    import std.hash.crc, std.hash.sha, std.hash.md;

    import std.stdio;
    // Digests a file and prints the result.
    void digestFile(Hash)(ref Hash hash, string filename) if(isDigest!Hash)
    {
        File file = File(filename);
        scope(exit) file.close();

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

//verify example
unittest
{
    import std.hash.crc, std.hash.sha, std.hash.md;

    import std.stdio;

    // Digests a file and prints the result.
    void digestFile(Digest hash, string filename)
    {
        File file = File(filename);
        scope(exit) file.close();

        //As digests implement OutputRange, we could use std.algorithm.copy
        //Let's do it manually for now
        foreach (buffer; file.byChunk(4096 * 1024))
          hash.put(buffer);

        auto result = hash.finish();
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
version(unittest)
    version = ExampleDigest;

version(ExampleDigest)
{
    /**
     * This documents the general structure of a Digest in the template API.
     * All digest implementations should implement the following members and therefore pass
     * the $(LREF isDigest) test.
     *
     * Note:
     * A digest must be a struct (value type) to pass the $(LREF isDigest) test.
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
             * if the hash has already processed data.
             */
            @trusted void start()
            {

            }

            /**
             * A digest implementation must provide two finish functions:
             * The first variant returns the result on the stack and is a useful convenience function.
             * The second variant takes a $(B reference) to a buffer and updates the buffer in place.
             *
             * Note:
             * The actual type returned by finish (variant 1) and accepted as an input buffer (variant 2)
             * depends on the digest implementation.
             * $(D ubyte[16]) is just used as an example. It is guaranteed that the type returned by
             * variant 1 is the same as the type accepted by variant 2 and that the type is a
             * static array of ubytes.
             *
             * $(UL
             * $(LI Use $(LREF digestType) to obtain the actual return type.)
             * $(LI Use $(LREF digestLength) to obtain the length of the ubyte array.)
             * )
             */
            @trusted ubyte[16] finish()
            {
                return (ubyte[16]).init;
            }

            ///ditto
            @trusted void finish(ref ubyte[16] data)
            {

            }
    }
}

/**
 * Use this to check if a type is a digest. See $(LREF ExampleDigest) to see what
 * a type must provide to pass this check.
 *
 * Note:
 * This is very useful as a template constraint (see examples)
 *
 * Examples:
 * ---------
 * static assert(isDigest!ExampleDigest);
 * ---------
 *
 * ---------
 * void myFunction(T)() if(isDigest!T)
 * {
 *     T dig;
 *     dig.start();
 *     auto result = dig.finish();
 * }
 * ---------
 *
 * BUGS:
 * $(UL
 * $(LI Does not yet verify that put takes scope parameters.)
 * $(LI Should check that finish() returns a ubyte[num] array)
 * )
 */
template isDigest(T)
{
    enum bool isDigest = isOutputRange!(T, const(ubyte)[]) && isOutputRange!(T, ubyte) &&
        is(T == struct) &&
        is(typeof(
        {
            T dig = void; //Can define
            dig.put(cast(ubyte)0, cast(ubyte)0); //varags
            dig.start(); //has start
            auto value = dig.finish(); //has finish
            typeof(value) buf;
            dig.finish(buf);
        }));
}

//verify example
unittest
{
    assert(isDigest!ExampleDigest);
}
//verify example
unittest
{
    void myFunction(T)() if(isDigest!T)
    {
        T dig;
        dig.start();
        auto result = dig.finish();
    }
    myFunction!ExampleDigest();
}

/**
 * Use this template to get the type which is returned by a digest's $(LREF finish) method.
 *
 * Examples:
 * --------
 * assert(is(digestType!(ExampleDigest) == ubyte[16]));
 * --------
 *
 * --------
 * ExampleDigest dig;
 * dig.start();
 * digestType!ExampleDigest buf;
 * dig.finish(buf);
 * --------
 */
template digestType(T)
{
    static if(isDigest!T)
    {
        alias ReturnType!(typeof(
            {
                T dig = void;
                return dig.finish();
            })) digestType;
    }
    else
        static assert(false, T.stringof ~ " is not a digest! (fails isDigest!T)");
}

//verify example
unittest
{
    assert(is(digestType!(ExampleDigest) == ubyte[16]));
}
//verify example
unittest
{
    ExampleDigest dig;
    dig.start();
    digestType!ExampleDigest buf;
    dig.finish(buf);
}

/**
 * Used to check if a digest supports the $(D peek) method.
 * Peek has exactly the same function signatures as finish, but it doesn't reset
 * the hash's internal state.
 *
 * Note:
 * $(UL
 * $(LI This is very useful as a template constraint (see examples))
 * $(LI This also checks if T passes $(LREF isDigest))
 * )
 *
 * Examples:
 * ---------
 * import std.hash.crc;
 * assert(!hasPeek!(ExampleDigest));
 * assert(hasPeek!CRC32);
 * ---------
 *
 * ---------
 * void myFunction(T)() if(hasPeek!T)
 * {
 *     T dig;
 *     dig.start();
 *     auto result = dig.peek();
 *     dig.peek(result); //use provided buffer
 * }
 * ---------
 */
template hasPeek(T)
{
    enum bool hasPeek = isDigest!T &&
        is(typeof(
        {
            T dig = void; //Can define
            digestType!T val = dig.peek();
            dig.peek(val);
        }));
}

//verify example
unittest
{
    import std.hash.crc;
    assert(!hasPeek!(ExampleDigest));
    assert(hasPeek!CRC32);
}
//verify example
unittest
{
    import std.hash.crc;
    void myFunction(T)() if(hasPeek!T)
    {
        T dig;
        dig.start();
        auto result = dig.peek();
        dig.peek(result); //use provided buffer
    }
    myFunction!CRC32();
}

/**
 * This is a convenience function to calculate the hash of a value using the template API.
 * Every hash passing the $(LREF isDigest) test can be used with this function.
 *
 * Examples:
 * ---------
 * import std.hash.md, std.hash.sha, std.hash.crc;
 * auto md5   = digest!MD5(  "The quick brown fox jumps over the lazy dog");
 * auto sha1  = digest!SHA1( "The quick brown fox jumps over the lazy dog");
 * auto crc32 = digest!CRC32("The quick brown fox jumps over the lazy dog");
 * assert(toHexString(crc32) == "414FA339");
 * ---------
 *
 * ---------
 * //It's also possible to pass multiple values to this function:
 * import std.hash.crc;;
 * auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
 * assert(toHexString(crc32) == "414FA339");
 * ---------
 */
digestType!Hash digest(Hash)(scope const(void[])[] data...) if(isDigest!Hash)
{
    Hash hash;
    hash.start();
    foreach(datum; data)
        hash.put(cast(const(ubyte[]))datum);
    return hash.finish();
}

//verify example
unittest
{
    import std.hash.md, std.hash.sha, std.hash.crc;
    auto md5   = digest!MD5(  "The quick brown fox jumps over the lazy dog");
    auto sha1  = digest!SHA1( "The quick brown fox jumps over the lazy dog");
    auto crc32 = digest!CRC32("The quick brown fox jumps over the lazy dog");
    assert(toHexString(crc32) == "39A34F41");
}

//verify example
unittest
{
    import std.hash.crc;
    auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
    assert(toHexString(crc32) == "39A34F41");
}

/*+*************************** End of template part, welcome to OOP land **************************/

/**
 * The rest of the documentation now describes the OOP API. To understand when to use the template
 * API and when to use the OOP API, see the module documentation at the top of this page.
 *
 * The Digest interface is the base interface which is implemented by all digests.
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
         * into. If a buffer is passed, it must have a length at least $(LREF length) bytes.
         */
        @trusted nothrow ubyte[] finish();
        ///ditto
        nothrow ubyte[] finish(scope ubyte[] buf);
        //http://d.puremagic.com/issues/show_bug.cgi?id=6549
        /*in
        {
            assert(buf.length >= this.length);
        }*/

        /**
         * This is a convenience function to calculate the hash of a value using the OOP API.
         *
         * Examples:
         * ---------
         * import std.hash.md, std.hash.sha, std.hash.crc;
         * auto md5   = (new MD5Digest()).digest("The quick brown fox jumps over the lazy dog");
         * auto sha1  = (new SHA1Digest()).digest("The quick brown fox jumps over the lazy dog");
         * auto crc32 = (new CRC32Digest()).digest("The quick brown fox jumps over the lazy dog");
         * assert(crcHexString(crc32) == "414FA339");
         * ---------
         *
         * ---------
         * //It's also possible to pass multiple values to this function:
         * import std.hash.crc;;
         * auto crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
         * assert(crcHexString(crc32) == "414FA339");
         * ---------
         */
        final @trusted nothrow ubyte[] digest(scope const(void[])[] data...)
        {
            this.reset();
            foreach(datum; data)
                this.put(cast(ubyte[])datum);
            return this.finish();
        }
}

//verify example
unittest
{
    import std.hash.md, std.hash.sha, std.hash.crc;
    auto md5   = (new MD5Digest()).digest("The quick brown fox jumps over the lazy dog");
    auto sha1  = (new SHA1Digest()).digest("The quick brown fox jumps over the lazy dog");
    auto crc32 = (new CRC32Digest()).digest("The quick brown fox jumps over the lazy dog");
    assert(crcHexString(crc32) == "414FA339");
}

//verify example
unittest
{
    import std.hash.crc;
    auto crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
    assert(crcHexString(crc32) == "414FA339");
}

unittest
{
    assert(!isDigest!(Digest));
}

//verify example
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
 * Examples:
 * --------
 * //With template API:
 * auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
 * assert(toHexString(crc32) == "39A34F41");
 * --------
 *
 * --------
 * //Usually CRCs are printed in this order, though:
 * auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
 * assert(toHexString!(Order.decreasing)(crc32) == "414FA339");
 * --------
 *
 * --------
 * //With OOP API:
 * auto crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
 * assert(toHexString(crc32) == "39A34F41");
 * --------
 *
 * --------
 * //Usually CRCs are printed in this order, though:
 * auto crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
 * assert(toHexString!(Order.decreasing)(crc32) == "414FA339");
 * --------
 */
string toHexString(Order order = Order.increasing, size_t num)(in ubyte[num] digest)
{
    auto result = new char[num*2];
    size_t i;

    static if(order == Order.increasing)
    {
        foreach(u; digest)
        {
            result[i++] = std.ascii.hexDigits[u >> 4];
            result[i++] = std.ascii.hexDigits[u & 15];
        }
    }
    else
    {
        size_t j = num - 1;
        while(i < num*2)
        {
            result[i++] = std.ascii.hexDigits[digest[j] >> 4];
            result[i++] = std.ascii.hexDigits[digest[j] & 15];
            j--;
        }
    }
    return assumeUnique(result);
}

///ditto
string toHexString(Order order = Order.increasing)(in ubyte[] digest)
{
    auto result = new char[digest.length*2];
    size_t i;

    static if(order == Order.increasing)
    {
        foreach(u; digest)
        {
            result[i++] = std.ascii.hexDigits[u >> 4];
            result[i++] = std.ascii.hexDigits[u & 15];
        }
    }
    else
    {
        foreach(u; retro(digest))
        {
            result[i++] = std.ascii.hexDigits[u >> 4];
            result[i++] = std.ascii.hexDigits[u & 15];
        }
    }
    return assumeUnique(result);
}

//For more example unittests, see Digest.digest, digest

//verify example
unittest
{
    import std.hash.crc;
    //Usually CRCs are printed in this order, though:
    auto crc32 = digest!CRC32("The quick ", "brown ", "fox jumps over the lazy dog");
    assert(toHexString!(Order.decreasing)(crc32) == "414FA339");
}

//verify example
unittest
{
    import std.hash.crc;
    //Usually CRCs are printed in this order, though:
    auto crc32 = (new CRC32Digest()).digest("The quick ", "brown ", "fox jumps over the lazy dog");
    assert(toHexString!(Order.decreasing)(crc32) == "414FA339");
}

unittest
{
    ubyte[16] data;
    assert(toHexString(data) == "00000000000000000000000000000000");

    assert(toHexString(cast(ubyte[4])[42, 43, 44, 45]) == "2A2B2C2D");
    assert(toHexString(cast(ubyte[])[42, 43, 44, 45]) == "2A2B2C2D");
    assert(toHexString!(Order.decreasing)(cast(ubyte[4])[42, 43, 44, 45]) == "2D2C2B2A");
    assert(toHexString!(Order.decreasing)(cast(ubyte[])[42, 43, 44, 45]) == "2D2C2B2A");
}

/*+*********************** End of public helper part, private helpers follow ***********************/

/**
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
 * Modules providing hash implementations will usually provide
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
         * //Simple example
         * import std.hash.md;
         * auto hash = new WrapperDigest!MD5();
         * hash.put(cast(ubyte)0);
         * auto result = hash.finish();
         * --------
         *
         * --------
         * //using a supplied buffer
         * import std.hash.md;
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
            enum string msg = "Buffer needs to be at least " ~ digestLength!(T).stringof ~ " bytes "
                "big, check " ~ typeof(this).stringof ~ ".length!";
            _digest.finish(asArray!(digestLength!T)(buf, msg));
            return buf[0 .. digestLength!T];
        }

        ///ditto
        @trusted nothrow ubyte[] finish()
        {
            enum len = digestLength!T;
            auto buf = new ubyte[len];
            _digest.finish(asArray!(digestLength!T)(buf));
            return buf;
        }
        
        version(StdDdoc)
        {
            /**
             * Works like $(D finish) but does not reset the internal state, so it's possible
             * to continue putting data into this CRC32 after a call to peek.
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
                enum string msg = "Buffer needs to be at least " ~ digestLength!(T).stringof ~ " bytes "
                    "big, check " ~ typeof(this).stringof ~ ".length!";
                _digest.peek(asArray!(digestLength!T)(buf, msg));
                return buf[0 .. digestLength!T];
            }
            
            @trusted ubyte[] peek() const
            {
                enum len = digestLength!T;
                auto buf = new ubyte[len];
                _digest.peek(asArray!(digestLength!T)(buf));
                return buf;
            }
        }
}

//verify example
unittest
{
    import std.hash.md;
    //Simple example
    auto hash = new WrapperDigest!MD5();
    hash.put(cast(ubyte)0);
    auto result = hash.finish();
}

//verify example
unittest
{
    import std.hash.md;
    ubyte[16] buf;
    auto hash = new WrapperDigest!MD5();
    hash.put(cast(ubyte)0);
    auto result = hash.finish(buf[]);
    //The result is now in result (and in buf). If you pass a buffer which is bigger than
    //necessary, result will have the correct length, but buf will still have it's original
    //length
}
