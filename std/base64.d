// Written in the D programming language.

/**
 * Encoding / Decoding Base64 format.
 *
 * Implemented according to $(WEB tools.ietf.org/html/rfc4648,
 * RFC 4648 - The Base16, Base32, and Base64 Data Encodings).
 *
 * Example:
 * -----
 * ubyte[] data = [0x14, 0xfb, 0x9c, 0x03, 0xd9, 0x7e];
 * Base64.encode(data);        //-> "FPucA9l+"
 * Base64.decode("FPucA9l+");  //-> [0x14, 0xfb, 0x9c, 0x03, 0xd9, 0x7e]
 * -----
 *
 * Support Range interface using Encoder / Decoder.
 *
 * Example:
 * -----
 * // Create MIME Base64 with CRLF, per line 76.
 * foreach (encoded; Base64.encoder(f.byChunk(57))) {
 *     mime64.put(encoded);
 *     mime64.put("\r\n");
 * }
 * -----
 *
 * Copyright: Masahiro Nakagawa 2010-.
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Masahiro Nakagawa, Daniel Murphy (Single value Encoder and Decoder)
 * Source:    $(PHOBOSSRC std/_base64.d)
 */
module std.base64;

import std.exception;  // enforce
import std.range;      // isInputRange, isOutputRange, isForwardRange, ElementType, hasLength
import std.traits;     // isArray

version(unittest) import std.algorithm, std.conv, std.file, std.stdio;


/**
 * The Base64
 */
alias Base64Impl!('+', '/') Base64;


/**
 * The "URL and Filename safe" Base64
 */
alias Base64Impl!('-', '_') Base64URL;


/**
 * Core implementation for Base64 format.
 *
 * Example:
 * -----
 * alias Base64Impl!('+', '/')                   Base64;    // The Base64 format(Already defined).
 * alias Base64Impl!('!', '=', Base64.NoPadding) Base64Re;  // non-standard Base64 format for Regular expression
 * -----
 *
 * NOTE:
 *  encoded-string doesn't have padding character if set Padding parameter to NoPadding.
 */
template Base64Impl(char Map62th, char Map63th, char Padding = '=')
{
    enum NoPadding = '\0';  /// represents no-padding encoding


    // Verify Base64 characters
    static assert(Map62th < 'A' || Map62th > 'Z', "Character '" ~ Map62th ~ "' cannot be used twice");
    static assert(Map63th < 'A' || Map63th > 'Z', "Character '" ~ Map63th ~ "' cannot be used twice");
    static assert(Padding < 'A' || Padding > 'Z', "Character '" ~ Padding ~ "' cannot be used twice");
    static assert(Map62th < 'a' || Map62th > 'z', "Character '" ~ Map62th ~ "' cannot be used twice");
    static assert(Map63th < 'a' || Map63th > 'z', "Character '" ~ Map63th ~ "' cannot be used twice");
    static assert(Padding < 'a' || Padding > 'z', "Character '" ~ Padding ~ "' cannot be used twice");
    static assert(Map62th < '0' || Map62th > '9', "Character '" ~ Map62th ~ "' cannot be used twice");
    static assert(Map63th < '0' || Map63th > '9', "Character '" ~ Map63th ~ "' cannot be used twice");
    static assert(Padding < '0' || Padding > '9', "Character '" ~ Padding ~ "' cannot be used twice");
    static assert(Map62th != Map63th, "Character '" ~ Map63th ~ "' cannot be used twice");
    static assert(Map62th != Padding, "Character '" ~ Padding ~ "' cannot be used twice");
    static assert(Map63th != Padding, "Character '" ~ Padding ~ "' cannot be used twice");
    static assert(Map62th != NoPadding, "'\\0' is not a valid Base64character");
    static assert(Map63th != NoPadding, "'\\0' is not a valid Base64character");


    /* Encode functions */


    private immutable EncodeMap = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ~ Map62th ~ Map63th;


    /**
     * Calculates the minimum length for encoding.
     *
     * Params:
     *  sourceLength = the length of source array.
     *
     * Returns:
     *  the calculated length using $(D_PARAM sourceLength).
     */
    @safe
    pure nothrow size_t encodeLength(in size_t sourceLength)
    {
        static if (Padding == NoPadding)
            return (sourceLength / 3) * 4 + (sourceLength % 3 == 0 ? 0 : sourceLength % 3 == 1 ? 2 : 3);
        else
            return (sourceLength / 3 + (sourceLength % 3 ? 1 : 0)) * 4;
    }


    // ubyte[] to char[]


    /**
     * Encodes $(D_PARAM source) into $(D_PARAM buffer).
     *
     * Params:
     *  source = an $(D InputRange) to encode.
     *  range  = a buffer to store encoded result.
     *
     * Returns:
     *  the encoded string that slices buffer.
     */
    @trusted
    pure char[] encode(R1, R2)(in R1 source, R2 buffer) if (isArray!R1 && is(ElementType!R1 : ubyte) &&
                                                            is(R2 == char[]))
    in
    {
        assert(buffer.length >= encodeLength(source.length), "Insufficient buffer for encoding");
    }
    out(result)
    {
        assert(result.length == encodeLength(source.length), "The length of result is different from Base64");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return [];

        immutable blocks = srcLen / 3;
        immutable remain = srcLen % 3;
        auto      bufptr = buffer.ptr;
        auto      srcptr = source.ptr;

        foreach (Unused; 0..blocks) {
            immutable val = srcptr[0] << 16 | srcptr[1] << 8 | srcptr[2];
            *bufptr++ = EncodeMap[val >> 18       ];
            *bufptr++ = EncodeMap[val >> 12 & 0x3f];
            *bufptr++ = EncodeMap[val >>  6 & 0x3f];
            *bufptr++ = EncodeMap[val       & 0x3f];
            srcptr += 3;
        }

        if (remain) {
            immutable val = srcptr[0] << 16 | (remain == 2 ? srcptr[1] << 8 : 0);
            *bufptr++ = EncodeMap[val >> 18       ];
            *bufptr++ = EncodeMap[val >> 12 & 0x3f];

            final switch (remain) {
            case 2:
                *bufptr++ = EncodeMap[val >> 6 & 0x3f];
                static if (Padding != NoPadding)
                    *bufptr++ = Padding;
                break;
            case 1:
                static if (Padding != NoPadding) {
                    *bufptr++ = Padding;
                    *bufptr++ = Padding;
                }
                break;
            }
        }

        // encode method can't assume buffer length. So, slice needed.
        return buffer[0..bufptr - buffer.ptr];
    }


    // InputRange to char[]


    /**
     * ditto
     */
    char[] encode(R1, R2)(R1 source, R2 buffer) if (!isArray!R1 && isInputRange!R1 &&
                                                    is(ElementType!R1 : ubyte) && hasLength!R1 &&
                                                    is(R2 == char[]))
    in
    {
        assert(buffer.length >= encodeLength(source.length), "Insufficient buffer for encoding");
    }
    out(result)
    {
        // @@@BUG@@@ D's DbC can't caputre an argument of function and store the result of precondition.
        //assert(result.length == encodeLength(source.length), "The length of result is different from Base64");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return [];

        immutable blocks = srcLen / 3;
        immutable remain = srcLen % 3;
        auto      bufptr = buffer.ptr;

        foreach (Unused; 0..blocks) {
            immutable v1 = source.front; source.popFront();
            immutable v2 = source.front; source.popFront();
            immutable v3 = source.front; source.popFront();
            immutable val = v1 << 16 | v2 << 8 | v3;
            *bufptr++ = EncodeMap[val >> 18       ];
            *bufptr++ = EncodeMap[val >> 12 & 0x3f];
            *bufptr++ = EncodeMap[val >>  6 & 0x3f];
            *bufptr++ = EncodeMap[val       & 0x3f];
        }

        if (remain) {
            size_t val = source.front << 16;
            if (remain == 2) {
                source.popFront();
                val |= source.front << 8;
            }

            *bufptr++ = EncodeMap[val >> 18       ];
            *bufptr++ = EncodeMap[val >> 12 & 0x3f];

            final switch (remain) {
            case 2:
                *bufptr++ = EncodeMap[val >> 6 & 0x3f];
                static if (Padding != NoPadding)
                    *bufptr++ = Padding;
                break;
            case 1:
                static if (Padding != NoPadding) {
                    *bufptr++ = Padding;
                    *bufptr++ = Padding;
                }
                break;
            }
        }

        // @@@BUG@@@ Workaround for DbC problem. See comment on 'out'.
        version (unittest) assert(bufptr - buffer.ptr == encodeLength(srcLen), "The length of result is different from Base64");

        // encode method can't assume buffer length. So, slice needed.
        return buffer[0..bufptr - buffer.ptr];
    }


    // ubyte[] to OutputRange


    /**
     * Encodes $(D_PARAM source) into $(D_PARAM range).
     *
     * Params:
     *  source = an $(D InputRange) to encode.
     *  range  = an $(D OutputRange) to put encoded result.
     *
     * Returns:
     *  the number of calling put.
     */
    size_t encode(R1, R2)(in R1 source, R2 range) if (isArray!R1 && is(ElementType!R1 : ubyte) &&
                                                      !is(R2 == char[]))
    out(result)
    {
        assert(result == encodeLength(source.length), "The number of put is different from the length of Base64");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return 0;

        immutable blocks = srcLen / 3;
        immutable remain = srcLen % 3;
        auto      srcptr = source.ptr;
        size_t    pcount;

        foreach (Unused; 0..blocks) {
            immutable val = srcptr[0] << 16 | srcptr[1] << 8 | srcptr[2];
            put(range, EncodeMap[val >> 18       ]);
            put(range, EncodeMap[val >> 12 & 0x3f]);
            put(range, EncodeMap[val >>  6 & 0x3f]);
            put(range, EncodeMap[val       & 0x3f]);
            srcptr += 3;
            pcount += 4;
        }

        if (remain) {
            immutable val = srcptr[0] << 16 | (remain == 2 ? srcptr[1] << 8 : 0);
            put(range, EncodeMap[val >> 18       ]);
            put(range, EncodeMap[val >> 12 & 0x3f]);
            pcount += 2;

            final switch (remain) {
            case 2:
                put(range, EncodeMap[val >> 6 & 0x3f]);
                pcount++;

                static if (Padding != NoPadding) {
                    put(range, Padding);
                    pcount++;
                }
                break;
            case 1:
                static if (Padding != NoPadding) {
                    put(range, Padding);
                    put(range, Padding);
                    pcount += 2;
                }
                break;
            }
        }

        return pcount;
    }


    // InputRange to OutputRange


    /**
     * ditto
     */
    size_t encode(R1, R2)(R1 source, R2 range) if (!isArray!R1 && isInputRange!R1 &&
                                                   is(ElementType!R1 : ubyte) && hasLength!R1 &&
                                                   !is(R2 == char[]) && isOutputRange!(R2, char))
    out(result)
    {
        // @@@BUG@@@ Workaround for DbC problem.
        //assert(result == encodeLength(source.length), "The number of put is different from the length of Base64");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return 0;

        immutable blocks = srcLen / 3;
        immutable remain = srcLen % 3;
        size_t    pcount;

        foreach (Unused; 0..blocks) {
            immutable v1 = source.front; source.popFront();
            immutable v2 = source.front; source.popFront();
            immutable v3 = source.front; source.popFront();
            immutable val = v1 << 16 | v2 << 8 | v3;
            put(range, EncodeMap[val >> 18       ]);
            put(range, EncodeMap[val >> 12 & 0x3f]);
            put(range, EncodeMap[val >>  6 & 0x3f]);
            put(range, EncodeMap[val       & 0x3f]);
            pcount += 4;
        }

        if (remain) {
            size_t val = source.front << 16;
            if (remain == 2) {
                source.popFront();
                val |= source.front << 8;
            }

            put(range, EncodeMap[val >> 18       ]);
            put(range, EncodeMap[val >> 12 & 0x3f]);
            pcount += 2;

            final switch (remain) {
            case 2:
                put(range, EncodeMap[val >> 6 & 0x3f]);
                pcount++;

                static if (Padding != NoPadding) {
                    put(range, Padding);
                    pcount++;
                }
                break;
            case 1:
                static if (Padding != NoPadding) {
                    put(range, Padding);
                    put(range, Padding);
                    pcount += 2;
                }
                break;
            }
        }

        // @@@BUG@@@ Workaround for DbC problem.
        version (unittest) assert(pcount == encodeLength(srcLen), "The number of put is different from the length of Base64");

        return pcount;
    }


    /**
     * Encodes $(D_PARAM source) to new buffer.
     *
     * Shortcut to encode(source, buffer) function.
     */
    @safe
    pure char[] encode(Range)(Range source) if (isArray!Range && is(ElementType!Range : ubyte))
    {
        return encode(source, new char[encodeLength(source.length)]);
    }


    /**
     * ditto
     */
    char[] encode(Range)(Range source) if (!isArray!Range && isInputRange!Range &&
                                           is(ElementType!Range : ubyte) && hasLength!Range)
    {
        return encode(source, new char[encodeLength(source.length)]);
    }


    /**
     * Range that encodes chunk data at a time.
     */
    struct Encoder(Range) if (isInputRange!Range && (is(ElementType!Range : const(ubyte)[]) ||
                                                     is(ElementType!Range : const(char)[])))
    {
      private:
        Range  range_;
        char[] buffer_, encoded_;


      public:
        this(Range range)
        {
            range_ = range;
            doEncoding();
        }


        /**
         * Range primitive operation that checks iteration state.
         *
         * Returns:
         *  true if there are no more elements to be iterated.
         */
        @property @trusted
        bool empty() const
        {
            return range_.empty;
        }


        /**
         * Range primitive operation that returns the currently iterated element.
         *
         * Returns:
         *  the encoded string.
         */
        @property @safe
        nothrow char[] front()
        {
            return encoded_;
        }


        /**
         * Range primitive operation that advances the range to its next element.
         *
         * Throws:
         *  an Exception when you try to call popFront on empty range.
         */
        void popFront()
        {
            enforce(!empty, "Cannot call popFront on Encoder with no data remaining");

            range_.popFront();

            /*
             * This check is very ugly. I think this is a Range's flaw.
             * I very strongly want the Range guideline for unified implementation.
             *
             * In this case, Encoder becomes a beautiful implementation if 'front' performs Base64 encoding.
             */
            if (!empty)
                doEncoding();
        }


        static if (isForwardRange!Range) {
            /**
             * Captures a Range state. 
             *
             * Returns:
             *  a copy of $(D this).
             */
            @property
            typeof(this) save()
            {
                typeof(return) encoder;

                encoder.range_   = range_.save;
                encoder.buffer_  = buffer_.dup;
                encoder.encoded_ = encoder.buffer_[0..encoded_.length];

                return encoder;
            }
        }


      private:
        void doEncoding()
        {
            auto data = cast(const(ubyte)[])range_.front;
            auto size = encodeLength(data.length);
            if (size > buffer_.length)
                buffer_.length = size;

            encoded_ = encode(data, buffer_);
        }
    }


    /**
     * Range that encodes single character at a time.
     */
    struct Encoder(Range) if (isInputRange!Range && is(ElementType!Range : ubyte))
    {
      private:
        Range range_;
        ubyte first;
        int   pos, padding;


      public:
        this(Range range)
        {
            range_ = range;
            static if (isForwardRange!Range)
                range_ = range_.save;

            if (range_.empty)
                pos = -1;
            else
                popFront();
        }
        

        /**
         * Range primitive operation that checks iteration state.
         *
         * Returns:
         *  true if there are no more elements to be iterated.
         */
        @property @safe
        nothrow bool empty() const
        {
            static if (Padding == NoPadding)
                return pos < 0;
            else
                return pos < 0 && !padding;
        }


        /**
         * Range primitive operation that returns the currently iterated element.
         *
         * Returns:
         *  the encoded character.
         */
        @property @safe
        nothrow ubyte front()
        {
            return first;
        }


        /**
         * Range primitive operation that advances the range to its next element.
         *
         * Throws:
         *  an Exception when you try to call popFront on empty range.
         */
        void popFront()
        {
            enforce(!empty, "Cannot call popFront on Encoder with no data remaining");

            static if (Padding != NoPadding)
                if (padding) {
                    first = Padding;
                    pos   = -1;
                    padding--;
                    return;
                }

            if (range_.empty) {
                pos = -1;
                return;
            }
                        
            final switch (pos) {
            case 0:
                first = EncodeMap[range_.front >> 2];
                break;
            case 1:
                immutable t = (range_.front & 0b11) << 4;
                range_.popFront();

                if (range_.empty) {
                    first   = EncodeMap[t];
                    padding = 3;
                } else {
                    first = EncodeMap[t | (range_.front >> 4)];
                }
                break;
            case 2:
                immutable t = (range_.front & 0b1111) << 2;
                range_.popFront();

                if (range_.empty) {
                    first   = EncodeMap[t];
                    padding = 2;
                } else {
                    first = EncodeMap[t | (range_.front >> 6)];
                }
                break;
            case 3:
                first = EncodeMap[range_.front & 0b111111];
                range_.popFront();
                break;
            }
            
            ++pos %= 4;            
        }


        static if (isForwardRange!Range) {
            /**
             * Captures a Range state. 
             *
             * Returns:
             *  a copy of $(D this).
             */
            @property
            typeof(this) save()
            {
                auto encoder = this;
                encoder.range_ = encoder.range_.save;
                return encoder;
            }
        }
    }


    /**
     * Iterates through an $(D InputRange) at a time by using $(D Encoder).
     *
     * Default $(D Encoder) encodes chunk data.
     *
     * Example:
     * -----
     * foreach (encoded; Base64.encoder(f.byLine())) {
     *     ... use encoded line ...
     * }
     * -----
     *
     * In addition, You can use $(D Encoder) that returns encoded single character.
     * This $(D Encoder) performs Range-based and lazy encoding.
     *
     * Example:
     * -----
     * // The ElementType of data is not aggregation type
     * foreach (encoded; Base64.encoder(data)) {
     *     ... use encoded character ...
     * }
     * -----
     *
     * Params:
     *  range = an $(D InputRange) to iterate.
     *
     * Returns:
     *  a $(D Encoder) object instantiated and initialized according to the arguments.
     */
    Encoder!(Range) encoder(Range)(Range range) if (isInputRange!Range)
    {
        return typeof(return)(range);
    }


    /* Decode functions */


    private immutable int[char.max + 1] DecodeMap = [
        'A':0b000000, 'B':0b000001, 'C':0b000010, 'D':0b000011, 'E':0b000100,
        'F':0b000101, 'G':0b000110, 'H':0b000111, 'I':0b001000, 'J':0b001001,
        'K':0b001010, 'L':0b001011, 'M':0b001100, 'N':0b001101, 'O':0b001110,
        'P':0b001111, 'Q':0b010000, 'R':0b010001, 'S':0b010010, 'T':0b010011,
        'U':0b010100, 'V':0b010101, 'W':0b010110, 'X':0b010111, 'Y':0b011000,
        'Z':0b011001, 'a':0b011010, 'b':0b011011, 'c':0b011100, 'd':0b011101,
        'e':0b011110, 'f':0b011111, 'g':0b100000, 'h':0b100001, 'i':0b100010,
        'j':0b100011, 'k':0b100100, 'l':0b100101, 'm':0b100110, 'n':0b100111,
        'o':0b101000, 'p':0b101001, 'q':0b101010, 'r':0b101011, 's':0b101100,
        't':0b101101, 'u':0b101110, 'v':0b101111, 'w':0b110000, 'x':0b110001,
        'y':0b110010, 'z':0b110011, '0':0b110100, '1':0b110101, '2':0b110110,
        '3':0b110111, '4':0b111000, '5':0b111001, '6':0b111010, '7':0b111011,
        '8':0b111100, '9':0b111101, Map62th:0b111110, Map63th:0b111111, Padding:-1
    ];


    /**
     * Calculates the minimum length for decoding.
     *
     * Params:
     *  sourceLength = the length of source array.
     *
     * Returns:
     *  calculated length using $(D_PARAM sourceLength).
     */
    @safe
    pure nothrow size_t decodeLength(in size_t sourceLength)
    in
    {
        static if (Padding == NoPadding)
            assert(sourceLength % 4 != 1, "Invalid no-padding Base64 format");
        else
            assert(sourceLength % 4 == 0, "Invalid Base64 format");
    }
    body
    {
        static if (Padding == NoPadding)
            return (sourceLength / 4) * 3 + (sourceLength % 4 == 0 ? 0 : sourceLength % 4 == 2 ? 1 : 2);
        else
            return (sourceLength / 4) * 3;
    }


    // char[] to ubyte[]


    /**
     * Decodes $(D_PARAM source) into $(D_PARAM buffer).
     *
     * Params:
     *  source = an $(D InputRange) to decode.
     *  buffer = a buffer to store decoded result.
     *
     * Returns:
     *  the decoded string that slices buffer.
     *
     * Throws:
     *  an Exception if $(D_PARAM source) has character outside base-alphabet.
     */
    @trusted
    pure ubyte[] decode(R1, R2)(in R1 source, R2 buffer) if (isArray!R1 && is(ElementType!R1 : dchar) &&
                                                             is(R2 == ubyte[]) && isOutputRange!(R2, ubyte))
    in
    {
        assert(buffer.length >= decodeLength(source.length), "Insufficient buffer for decoding");
    }
    out(result)
    {
        immutable expect = decodeLength(source.length) - (source.length == 0       ? 0 :
                                                          source[$ - 2] == Padding ? 2 :
                                                          source[$ - 1] == Padding ? 1 : 0);
        assert(result.length == expect, "The length of result is different from the expected length");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return [];

        immutable blocks = srcLen / 4;
        auto      srcptr = source.ptr;
        auto      bufptr = buffer.ptr;

        foreach (Unused; 0..blocks) {
            immutable v1 = decodeChar(*srcptr++);
            immutable v2 = decodeChar(*srcptr++);

            *bufptr++ = cast(ubyte)(v1 << 2 | v2 >> 4);

            immutable v3 = decodeChar(*srcptr++);
            if (v3 == -1)
                break;

            *bufptr++ = cast(ubyte)((v2 << 4 | v3 >> 2) & 0xff);

            immutable v4 = decodeChar(*srcptr++);
            if (v4 == -1)
                break;

            *bufptr++ = cast(ubyte)((v3 << 6 | v4) & 0xff);
        }

        static if (Padding == NoPadding) {
            immutable remain = srcLen % 4;

            if (remain) {
                immutable v1 = decodeChar(*srcptr++);
                immutable v2 = decodeChar(*srcptr++);

                *bufptr++ = cast(ubyte)(v1 << 2 | v2 >> 4);

                if (remain == 3)
                    *bufptr++ = cast(ubyte)((v2 << 4 | decodeChar(*srcptr++) >> 2) & 0xff);
            }
        }

        return buffer[0..bufptr - buffer.ptr];
    }


    // InputRange to ubyte[]


    /**
     * ditto
     */
    ubyte[] decode(R1, R2)(R1 source, R2 buffer) if (!isArray!R1 && isInputRange!R1 &&
                                                     is(ElementType!R1 : dchar) && hasLength!R1 &&
                                                     is(R2 == ubyte[]) && isOutputRange!(R2, ubyte))
    in
    {
        assert(buffer.length >= decodeLength(source.length), "Insufficient buffer for decoding");
    }
    out(result)
    {
        // @@@BUG@@@ Workaround for DbC problem.
        //immutable expect = decodeLength(source.length) - 2;
        //assert(result.length >= expect, "The length of result is smaller than expected length");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return [];

        immutable blocks = srcLen / 4;
        auto      bufptr = buffer.ptr;

        foreach (Unused; 0..blocks) {
            immutable v1 = decodeChar(source.front); source.popFront();
            immutable v2 = decodeChar(source.front); source.popFront();

            *bufptr++ = cast(ubyte)(v1 << 2 | v2 >> 4);

            immutable v3 = decodeChar(source.front);
            if (v3 == -1)
                break;

            *bufptr++ = cast(ubyte)((v2 << 4 | v3 >> 2) & 0xff);
            source.popFront();

            immutable v4 = decodeChar(source.front);
            if (v4 == -1)
                break;

            *bufptr++ = cast(ubyte)((v3 << 6 | v4) & 0xff);
            source.popFront();
        }

        static if (Padding == NoPadding) {
            immutable remain = srcLen % 4;

            if (remain) {
                immutable v1 = decodeChar(source.front); source.popFront();
                immutable v2 = decodeChar(source.front);

                *bufptr++ = cast(ubyte)(v1 << 2 | v2 >> 4);

                if (remain == 3) {
                    source.popFront();
                    *bufptr++ = cast(ubyte)((v2 << 4 | decodeChar(source.front) >> 2) & 0xff);
                }
            }
        }

        // @@@BUG@@@ Workaround for DbC problem.
        version (unittest) assert((bufptr - buffer.ptr) >= (decodeLength(srcLen) - 2), "The length of result is smaller than expected length");

        return buffer[0..bufptr - buffer.ptr];
    }


    // char[] to OutputRange


    /**
     * Decodes $(D_PARAM source) into $(D_PARAM range).
     *
     * Params:
     *  source = an $(D InputRange) to decode.
     *  range  = an $(D OutputRange) to put decoded result
     *
     * Returns:
     *  the number of calling put.
     *
     * Throws:
     *  an Exception if $(D_PARAM source) has character outside base-alphabet.
     */
    size_t decode(R1, R2)(in R1 source, R2 range) if (isArray!R1 && is(ElementType!R1 : dchar) &&
                                                      !is(R2 == ubyte[]) && isOutputRange!(R2, ubyte))
    out(result)
    {
        immutable expect = decodeLength(source.length) - (source.length == 0       ? 0 :
                                                          source[$ - 2] == Padding ? 2 :
                                                          source[$ - 1] == Padding ? 1 : 0);
        assert(result == expect, "The result of decode is different from the expected");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return 0;

        immutable blocks = srcLen / 4;
        auto      srcptr = source.ptr;
        size_t    pcount;

        foreach (Unused; 0..blocks) {
            immutable v1 = decodeChar(*srcptr++);
            immutable v2 = decodeChar(*srcptr++);

            put(range, cast(ubyte)(v1 << 2 | v2 >> 4));
            pcount++;

            immutable v3 = decodeChar(*srcptr++);
            if (v3 == -1)
                break;

            put(range, cast(ubyte)((v2 << 4 | v3 >> 2) & 0xff));
            pcount++;

            immutable v4 = decodeChar(*srcptr++);
            if (v4 == -1)
                break;

            put(range, cast(ubyte)((v3 << 6 | v4) & 0xff));
            pcount++;
        }

        static if (Padding == NoPadding) {
            immutable remain = srcLen % 4;

            if (remain) {
                immutable v1 = decodeChar(*srcptr++);
                immutable v2 = decodeChar(*srcptr++);

                put(range, cast(ubyte)(v1 << 2 | v2 >> 4));
                pcount++;

                if (remain == 3) {
                    put(range, cast(ubyte)((v2 << 4 | decodeChar(*srcptr++) >> 2) & 0xff));
                    pcount++;
                }
            }
        }

        return pcount;
    }


    // InputRange to OutputRange


    /**
     * ditto
     */
    size_t decode(R1, R2)(R1 source, R2 range) if (!isArray!R1 && isInputRange!R1 &&
                                                   is(ElementType!R1 : dchar) && hasLength!R1 &&
                                                   !is(R2 == ubyte[]) && isOutputRange!(R2, ubyte))
    out(result)
    {
        // @@@BUG@@@ Workaround for DbC problem.
        //immutable expect = decodeLength(source.length) - 2;
        //assert(result >= expect, "The length of result is smaller than expected length");
    }
    body
    {
        immutable srcLen = source.length;
        if (srcLen == 0)
            return 0;

        immutable blocks = srcLen / 4;
        size_t    pcount;

        foreach (Unused; 0..blocks) {
            immutable v1 = decodeChar(source.front); source.popFront();
            immutable v2 = decodeChar(source.front); source.popFront();

            put(range, cast(ubyte)(v1 << 2 | v2 >> 4));
            pcount++;

            immutable v3 = decodeChar(source.front);
            if (v3 == -1)
                break;

            put(range, cast(ubyte)((v2 << 4 | v3 >> 2) & 0xff));
            source.popFront();
            pcount++;

            immutable v4 = decodeChar(source.front);
            if (v4 == -1)
                break;

            put(range, cast(ubyte)((v3 << 6 | v4) & 0xff));
            source.popFront();
            pcount++;
        }

        static if (Padding == NoPadding) {
            immutable remain = srcLen % 4;

            if (remain) {
                immutable v1 = decodeChar(source.front); source.popFront();
                immutable v2 = decodeChar(source.front);

                put(range, cast(ubyte)(v1 << 2 | v2 >> 4));
                pcount++;

                if (remain == 3) {
                    source.popFront();
                    put(range, cast(ubyte)((v2 << 4 | decodeChar(source.front) >> 2) & 0xff));
                    pcount++;
                }
            }
        }

        // @@@BUG@@@ Workaround for DbC problem.
        version (unittest) assert(pcount >= (decodeLength(srcLen) - 2), "The length of result is smaller than expected length");

        return pcount;
    }


    /**
     * Decodes $(D_PARAM source) into new buffer.
     *
     * Shortcut to decode(source, buffer) function.
     */
    @safe
    pure ubyte[] decode(Range)(Range source) if (isArray!Range && is(ElementType!Range : dchar))
    {
        return decode(source, new ubyte[decodeLength(source.length)]);
    }


    /**
     * ditto
     */
    ubyte[] decode(Range)(Range source) if (!isArray!Range && isInputRange!Range &&
                                            is(ElementType!Range : dchar) && hasLength!Range)
    {
        return decode(source, new ubyte[decodeLength(source.length)]);
    }


    /**
     * Range that decodes chunk data at a time.
     */
    struct Decoder(Range) if (isInputRange!Range && (is(ElementType!Range : const(char)[]) ||
                                                     is(ElementType!Range : const(ubyte)[])))
    {
      private:
        Range   range_;
        ubyte[] buffer_, decoded_;


      public:
        this(Range range)
        {
            range_ = range;
            doDecoding();
        }


        /**
         * Range primitive operation that checks iteration state.
         *
         * Returns:
         *  true if there are no more elements to be iterated.
         */
        @property @trusted
        bool empty() const
        {
            return range_.empty;
        }


        /**
         * Range primitive operation that returns the currently iterated element.
         *
         * Returns:
         *  the decoded result.
         */
        @property @safe
        nothrow ubyte[] front()
        {
            return decoded_;
        }


        /**
         * Range primitive operation that advances the range to its next element.
         *
         * Throws:
         *  an Exception when you try to call popFront on empty range.
         */
        void popFront()
        {
            enforce(!empty, "Cannot call popFront on Decoder with no data remaining.");

            range_.popFront();

            /*
             * I mentioned Encoder's popFront.
             */
            if (!empty)
                doDecoding();
        }


        static if (isForwardRange!Range) {
            /**
             * Captures a Range state. 
             *
             * Returns:
             *  a copy of $(D this).
             */
            @property
            typeof(this) save()
            {
                typeof(return) decoder;

                decoder.range_   = range_.save;
                decoder.buffer_  = buffer_.dup;
                decoder.decoded_ = decoder.buffer_[0..decoded_.length];

                return decoder;
            }
        }


      private:
        void doDecoding()
        {
            auto data = cast(const(char)[])range_.front;

            static if (Padding == NoPadding) {
                while (data.length % 4 == 1) {
                    range_.popFront();
                    data ~= cast(const(char)[])range_.front;
                }
            } else {
                while (data.length % 4 != 0) {
                    range_.popFront();
                    data ~= cast(const(char)[])range_.front;
                }
            }

            auto size = decodeLength(data.length);
            if (size > buffer_.length)
                buffer_.length = size;

            decoded_ = decode(data, buffer_);
        }
    }


    /**
     * Range that decodes single character at a time.
     */
    struct Decoder(Range) if (isInputRange!Range && is(ElementType!Range : char))
    {
      private:
        Range range_;
        ubyte first;
        int   pos;


      public:
        this(Range range)
        {
            range_ = range;
            static if (isForwardRange!Range)
                range_ = range_.save;

            static if (Padding != NoPadding && hasLength!Range)
                enforce(range_.length % 4 == 0);

            if (range_.empty)
                pos = -1;
            else
                popFront();
        }
        

        /**
         * Range primitive operation that checks iteration state.
         *
         * Returns:
         *  true if there are no more elements to be iterated.
         */
        @property @safe
        nothrow bool empty() const
        {
            return pos < 0;
        }


        /**
         * Range primitive operation that returns the currently iterated element.
         *
         * Returns:
         *  the decoded result.
         */
        @property @safe
        nothrow ubyte front()
        {
            return first;
        }


        /**
         * Range primitive operation that advances the range to its next element.
         *
         * Throws:
         *  an Exception when you try to call popFront on empty range.
         */
        void popFront()
        {
            enforce(!empty, "Cannot call popFront on Decoder with no data remaining");

            static if (Padding == NoPadding) {
                bool endCondition()
                { 
                    return range_.empty;
                }
            } else {
                bool endCondition()
                {
                    enforce(!range_.empty, "Missing padding");
                    return range_.front == Padding;
                }
            }

            if (range_.empty || range_.front == Padding) {
                pos = -1;
                return;
            }

            final switch (pos) {
            case 0:
                enforce(!endCondition(), "Premature end of data found");

                immutable t = DecodeMap[range_.front] << 2;
                range_.popFront();

                enforce(!endCondition(), "Premature end of data found");
                first = cast(ubyte)(t | (DecodeMap[range_.front] >> 4));
                break;
            case 1:
                immutable t = (DecodeMap[range_.front] & 0b1111) << 4;
                range_.popFront();

                if (endCondition()) {
                    pos = -1;
                    return;
                } else {
                    first = cast(ubyte)(t | (DecodeMap[range_.front] >> 2));
                }
                break;
            case 2:
                immutable t = (DecodeMap[range_.front] & 0b11) << 6;
                range_.popFront();

                if (endCondition()) {
                    pos = -1;
                    return;
                } else {
                    first = cast(ubyte)(t | DecodeMap[range_.front]);
                }

                range_.popFront();
                break;
            }

            ++pos %= 3;
        }


        static if (isForwardRange!Range) {
            /**
             * Captures a Range state. 
             *
             * Returns:
             *  a copy of $(D this).
             */
            @property
            typeof(this) save()
            {
                auto decoder = this;
                decoder.range_ = decoder.range_.save;
                return decoder;
            }
        }
    }


    /**
     * Iterates through an $(D InputRange) at a time by using $(D Decoder).
     *
     * Default $(D Decoder) decodes chunk data.
     *
     * Example:
     * -----
     * foreach (decoded; Base64.decoder(f.byLine())) {
     *     ... use decoded line ...
     * }
     * -----
     *
     * In addition, You can use $(D Decoder) that returns decoded single character.
     * This $(D Decoder) performs Range-based and lazy decoding.
     *
     * Example:
     * -----
     * auto encoded = Base64.encoder(cast(ubyte[])"0123456789");
     * foreach (n; map!q{a - '0'}(Base64.decoder(encoded))) {
     *     ... do something with n ...
     * }
     * -----
     *
     * NOTE:
     *  If you use $(D ByChunk), chunk-size should be the multiple of 4.
     *  $(D Decoder) can't judge a encode-boundary.
     *
     * Params:
     *  range = an $(D InputRange) to iterate.
     *
     * Returns:
     *  a $(D Decoder) object instantiated and initialized according to the arguments.
     */
    Decoder!(Range) decoder(Range)(Range range) if (isInputRange!Range)
    {
        return typeof(return)(range);
    }


  private:
    @safe
    pure int decodeChar()(char chr)
    {
        immutable val = DecodeMap[chr];

        // enforce can't be a pure function, so I use trivial check.
        if (val == 0 && chr != 'A')
            throw new Exception("Invalid character: " ~ chr);

        return val;
    }


    @safe
    pure int decodeChar()(dchar chr)
    {
        // See above comment.
        if (chr > 0x7f)
            throw new Exception("Base64-encoded character must be a single byte");

        return decodeChar(cast(char)chr);
    }
}


unittest
{
    alias Base64Impl!('!', '=', Base64.NoPadding) Base64Re;

    // Test vectors from RPC 4648
    ubyte[][string] tv = [
         ""      :cast(ubyte[])"",
         "f"     :cast(ubyte[])"f",
         "fo"    :cast(ubyte[])"fo",
         "foo"   :cast(ubyte[])"foo",
         "foob"  :cast(ubyte[])"foob",
         "fooba" :cast(ubyte[])"fooba",
         "foobar":cast(ubyte[])"foobar"
    ];

    { // Base64
        // encode
        assert(Base64.encodeLength(tv[""].length)       == 0);
        assert(Base64.encodeLength(tv["f"].length)      == 4);
        assert(Base64.encodeLength(tv["fo"].length)     == 4);
        assert(Base64.encodeLength(tv["foo"].length)    == 4);
        assert(Base64.encodeLength(tv["foob"].length)   == 8);
        assert(Base64.encodeLength(tv["fooba"].length)  == 8);
        assert(Base64.encodeLength(tv["foobar"].length) == 8);
       
        assert(Base64.encode(tv[""])       == "");
        assert(Base64.encode(tv["f"])      == "Zg==");
        assert(Base64.encode(tv["fo"])     == "Zm8=");
        assert(Base64.encode(tv["foo"])    == "Zm9v");
        assert(Base64.encode(tv["foob"])   == "Zm9vYg==");
        assert(Base64.encode(tv["fooba"])  == "Zm9vYmE=");
        assert(Base64.encode(tv["foobar"]) == "Zm9vYmFy");

        // decode
        assert(Base64.decodeLength(Base64.encode(tv[""]).length)       == 0);
        assert(Base64.decodeLength(Base64.encode(tv["f"]).length)      == 3);
        assert(Base64.decodeLength(Base64.encode(tv["fo"]).length)     == 3);
        assert(Base64.decodeLength(Base64.encode(tv["foo"]).length)    == 3);
        assert(Base64.decodeLength(Base64.encode(tv["foob"]).length)   == 6);
        assert(Base64.decodeLength(Base64.encode(tv["fooba"]).length)  == 6);
        assert(Base64.decodeLength(Base64.encode(tv["foobar"]).length) == 6);

        assert(Base64.decode(Base64.encode(tv[""]))       == tv[""]);
        assert(Base64.decode(Base64.encode(tv["f"]))      == tv["f"]);
        assert(Base64.decode(Base64.encode(tv["fo"]))     == tv["fo"]);
        assert(Base64.decode(Base64.encode(tv["foo"]))    == tv["foo"]);
        assert(Base64.decode(Base64.encode(tv["foob"]))   == tv["foob"]);
        assert(Base64.decode(Base64.encode(tv["fooba"]))  == tv["fooba"]);
        assert(Base64.decode(Base64.encode(tv["foobar"])) == tv["foobar"]);

        try {
            Base64.decode("ab|c");
            assert(false);
        } catch (Exception e) {}
    }

    { // No padding
        // encode
        assert(Base64Re.encodeLength(tv[""].length)       == 0);
        assert(Base64Re.encodeLength(tv["f"].length)      == 2);
        assert(Base64Re.encodeLength(tv["fo"].length)     == 3);
        assert(Base64Re.encodeLength(tv["foo"].length)    == 4);
        assert(Base64Re.encodeLength(tv["foob"].length)   == 6);
        assert(Base64Re.encodeLength(tv["fooba"].length)  == 7);
        assert(Base64Re.encodeLength(tv["foobar"].length) == 8);
       
        assert(Base64Re.encode(tv[""])       == "");
        assert(Base64Re.encode(tv["f"])      == "Zg");
        assert(Base64Re.encode(tv["fo"])     == "Zm8");
        assert(Base64Re.encode(tv["foo"])    == "Zm9v");
        assert(Base64Re.encode(tv["foob"])   == "Zm9vYg");
        assert(Base64Re.encode(tv["fooba"])  == "Zm9vYmE");
        assert(Base64Re.encode(tv["foobar"]) == "Zm9vYmFy");

        // decode
        assert(Base64Re.decodeLength(Base64Re.encode(tv[""]).length)       == 0);
        assert(Base64Re.decodeLength(Base64Re.encode(tv["f"]).length)      == 1);
        assert(Base64Re.decodeLength(Base64Re.encode(tv["fo"]).length)     == 2);
        assert(Base64Re.decodeLength(Base64Re.encode(tv["foo"]).length)    == 3);
        assert(Base64Re.decodeLength(Base64Re.encode(tv["foob"]).length)   == 4);
        assert(Base64Re.decodeLength(Base64Re.encode(tv["fooba"]).length)  == 5);
        assert(Base64Re.decodeLength(Base64Re.encode(tv["foobar"]).length) == 6);

        assert(Base64Re.decode(Base64Re.encode(tv[""]))       == tv[""]);
        assert(Base64Re.decode(Base64Re.encode(tv["f"]))      == tv["f"]);
        assert(Base64Re.decode(Base64Re.encode(tv["fo"]))     == tv["fo"]);
        assert(Base64Re.decode(Base64Re.encode(tv["foo"]))    == tv["foo"]);
        assert(Base64Re.decode(Base64Re.encode(tv["foob"]))   == tv["foob"]);
        assert(Base64Re.decode(Base64Re.encode(tv["fooba"]))  == tv["fooba"]);
        assert(Base64Re.decode(Base64Re.encode(tv["foobar"])) == tv["foobar"]);
    }

    { // with OutputRange
        auto a = Appender!(char[])([]);
        auto b = Appender!(ubyte[])([]);

        assert(Base64.encode(tv[""], a) == 0);
        assert(Base64.decode(a.data, b) == 0);
        assert(tv[""] == b.data); a.clear(); b.clear();

        assert(Base64.encode(tv["f"], a) == 4);
        assert(Base64.decode(a.data,  b) == 1);
        assert(tv["f"] == b.data); a.clear(); b.clear();

        assert(Base64.encode(tv["fo"], a) == 4);
        assert(Base64.decode(a.data,   b) == 2);
        assert(tv["fo"] == b.data); a.clear(); b.clear();

        assert(Base64.encode(tv["foo"], a) == 4);
        assert(Base64.decode(a.data,    b) == 3);
        assert(tv["foo"] == b.data); a.clear(); b.clear();

        assert(Base64.encode(tv["foob"], a) == 8);
        assert(Base64.decode(a.data,     b) == 4);
        assert(tv["foob"] == b.data); a.clear(); b.clear();

        assert(Base64.encode(tv["fooba"], a) == 8);
        assert(Base64.decode(a.data, b)      == 5);
        assert(tv["fooba"] == b.data); a.clear(); b.clear();

        assert(Base64.encode(tv["foobar"], a) == 8);
        assert(Base64.decode(a.data, b)       == 6);
        assert(tv["foobar"] == b.data); a.clear(); b.clear();
    }

    { // with InputRange
        // InputRange to ubyte[] or char[]
        auto encoded = Base64.encode(map!(to!(ubyte))(["20", "251", "156", "3", "217", "126"]));
        assert(encoded == "FPucA9l+");
        assert(Base64.decode(map!q{a}(encoded)) == [0x14, 0xfb, 0x9c, 0x03, 0xd9, 0x7e]);

        // InputRange to OutputRange
        auto a = Appender!(char[])([]);
        auto b = Appender!(ubyte[])([]);
        assert(Base64.encode(map!(to!(ubyte))(["20", "251", "156", "3", "217", "126"]), a) == 8);
        assert(a.data == "FPucA9l+");
        assert(Base64.decode(map!q{a}(a.data), b) == 6);
        assert(b.data == [0x14, 0xfb, 0x9c, 0x03, 0xd9, 0x7e]);
    }

    { // Encoder and Decoder
        {
            std.file.write("testingEncoder", "\nf\nfo\nfoo\nfoob\nfooba\nfoobar");

            auto witness = ["", "Zg==", "Zm8=", "Zm9v", "Zm9vYg==", "Zm9vYmE=", "Zm9vYmFy"];
            auto f = File("testingEncoder");
            scope(exit)
            {
                f.close;
                assert(!f.isOpen);
                std.file.remove("testingEncoder");
            }

            size_t i;
            foreach (encoded; Base64.encoder(f.byLine()))
                assert(encoded == witness[i++]);

            assert(i == witness.length);
        }

        {
            std.file.write("testingDecoder", "\nZg==\nZm8=\nZm9v\nZm9vYg==\nZm9vYmE=\nZm9vYmFy");

            auto witness = tv.keys.sort;
            auto f = File("testingDecoder");
            scope(exit)
            {
                f.close;
                assert(!f.isOpen);
                std.file.remove("testingDecoder");
            }

            size_t i;
            foreach (decoded; Base64.decoder(f.byLine()))
                assert(decoded == witness[i++]);

            assert(i == witness.length);
        }

        { // ForwardRange
            {
                auto encoder = Base64.encoder(tv.values.sort);
                auto witness = ["", "Zg==", "Zm8=", "Zm9v", "Zm9vYg==", "Zm9vYmE=", "Zm9vYmFy"];
                size_t i;

                assert(encoder.front == witness[i++]); encoder.popFront();
                assert(encoder.front == witness[i++]); encoder.popFront();
                assert(encoder.front == witness[i++]); encoder.popFront();

                foreach (encoded; encoder.save)
                    assert(encoded == witness[i++]);
            }

            {
                auto decoder = Base64.decoder(["", "Zg==", "Zm8=", "Zm9v", "Zm9vYg==", "Zm9vYmE=", "Zm9vYmFy"]);
                auto witness = tv.values.sort;
                size_t i;

                assert(decoder.front == witness[i++]); decoder.popFront();
                assert(decoder.front == witness[i++]); decoder.popFront();
                assert(decoder.front == witness[i++]); decoder.popFront();

                foreach (decoded; decoder.save)
                    assert(decoded == witness[i++]);
            }
        }
    }

    { // Encoder and Decoder for single character encoding and decoding
        alias Base64Impl!('+', '/', Base64.NoPadding) Base64NoPadding;

        auto tests = [
            ""       : ["", "", "", ""],
            "f"      : ["Zg==", "Zg==", "Zg", "Zg"],
            "fo"     : ["Zm8=", "Zm8=", "Zm8", "Zm8"],
            "foo"    : ["Zm9v", "Zm9v", "Zm9v", "Zm9v"],
            "foob"   : ["Zm9vYg==", "Zm9vYg==", "Zm9vYg", "Zm9vYg"],
            "fooba"  : ["Zm9vYmE=", "Zm9vYmE=", "Zm9vYmE", "Zm9vYmE"],
            "foobar" : ["Zm9vYmFy", "Zm9vYmFy", "Zm9vYmFy", "Zm9vYmFy"],
        ];

        foreach (u, e; tests) {
            assert(equal(Base64.encoder(cast(ubyte[])u), e[0]));
            assert(equal(Base64.decoder(Base64.encoder(cast(ubyte[])u)), u));

            assert(equal(Base64URL.encoder(cast(ubyte[])u), e[1]));
            assert(equal(Base64URL.decoder(Base64URL.encoder(cast(ubyte[])u)), u));

            assert(equal(Base64NoPadding.encoder(cast(ubyte[])u), e[2]));
            assert(equal(Base64NoPadding.decoder(Base64NoPadding.encoder(cast(ubyte[])u)), u));

            assert(equal(Base64Re.encoder(cast(ubyte[])u), e[3]));
            assert(equal(Base64Re.decoder(Base64Re.encoder(cast(ubyte[])u)), u));
        }
    }
}
