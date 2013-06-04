// Written in the D programming language.

/**
    Components that can compress and expand ranges.

    Description:
        Compression is useful for storage and transmission data formats.
        This compresses using a variant of the
        $(LINK2 https://en.wikipedia.org/wiki/LZ77_and_LZ78, LZ77) compression algorithm.
        compress() and expand() are meant to be a matched set. Users should
        not depend on the particular data format.

    Example:
    This program takes a filename as an argument, compresses it,
    expands it, and verifies that the result matches the original
    contents.
    ---
    int main(string args[])
    {
        import std.stdio;
        import std.algorithm;
        import std.file;
        import std.compression.lz77;

        string filename;
        if (args.length < 2)
        {
            printf("need filename argument\n");
            return 1;
        }
        else
            filename = args[1];

        ubyte[] si = cast(ubyte[])std.file.read(filename);

        // Compress
        auto di = new ubyte[maxCompressedSize(si.length)];
        auto result = si.compress().copy(di);

        di = di[0..$ - result.length];

        writefln("Compression done, srclen = %s compressed = %s",
            si.length, di.length);

        // Decompress
        ubyte[] si2 = new ubyte[si.length];
        result = di.expand().copy(si2);
        assert(result.length == 0);

        writefln("Decompression done, dilen = %s decompressed = %s",
            di.length, si2.length);

        if (si != si2)
        {
            writeln("Buffers don't match");
            assert(0);
        }

        return 0;
    }
    ---

    References: https://en.wikipedia.org/wiki/LZ77_and_LZ78

    Macros:
        WIKI = Phobos/StdCompress

    Copyright: Copyright Digital Mars 2013.
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(WEB digitalmars.com, Walter Bright)
    Source:    $(PHOBOSSRC std/compression/_lz77.d)
   */

module std.compression.lz77;

import std.range;

//import core.stdc.stdio : printf;

private struct CircularBuffer(U: T[dim], T, size_t dim)
{
    void put(T e)
    {
        assert(length != dim);
        size_t i = first + length;
        if (i >= dim)
            i -= dim;
        buf[i] = e;
        length += 1;
    }

    @property T front()
    {
        assert(length);
        return buf[first];
    }

    void popFront()
    {
        assert(length);
        first += 1;
        if (first == dim)
            first = 0;
        --length;
    }

    @property bool full()
    {
        return length == dim;
    }

    @property bool empty()
    {
        return length == 0;
    }

    T opIndex(size_t i)
    {
        assert(i < length);
        i += first;
        if (i >= dim)
            i -= dim;
        return buf[i];
    }

    size_t length;

  private:
    size_t first;
    T[dim] buf = void;
}

unittest
{
    CircularBuffer!(ubyte[3]) buf;
    assert(buf.empty);
    assert(buf.length == 0);
    assert(!buf.full);

    buf.put(7);
    assert(!buf.empty);
    assert(buf.length == 1);
    assert(!buf.full);
    assert(buf[0] == 7);

    buf.put(8);
    buf.put(9);
    assert(!buf.empty);
    assert(buf.length == 3);
    assert(buf.full);

    assert(buf.front == 7);
    buf.popFront();
    buf.put(10);
    assert(!buf.empty);
    assert(buf.length == 3);
    assert(buf.full);
    assert(buf[0] == 8);
    assert(buf[1] == 9);
    assert(buf[2] == 10);
}

/* *********************************************************************** */

private
{
    enum matchLenMax = 0x80;
    enum offsetMax = 0x8000/4;
}

/*********************************
 * Compute the max size of a buffer needed to hold the compressed result.
 * Parameters:
 *      length  number of bytes of uncompressed data
 * Returns:
 *      max size of compressed buffer
 */
size_t maxCompressedSize(size_t length)
{
    return length + (length >> 3) + 3;
}

/************************************
 * Exception thrown on errors in compression functions,
 * likely caused by corrupted data.
 */

class CompressException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

/*******************************************************
 * Component that returns a Range that will compress src using LZ77 compression.
 *
 * Description:
 *      Compresses input of arbitrarily large size.
 *
 *      compress() does not allocate memory, although it uses a little over 8Kb
 *      of stack if src is not an array.
 *
 * Parameters:
 *      src     An InputRange of ubytes.
 *              If it is an array, it will go faster and will
 *              use much less stack.
 * Returns:
 *      InputRange
 */

auto compress(R)(R src) if (isInputRange!R && is(ElementType!R : ubyte))
{
    enum bool arrayLike = isRandomAccessRange!R && hasLength!R;

    static struct Range
    {
      private:
        R src;

        static if (!arrayLike)
            /* Need to create a sliding window buffer, since we
             * cannot look back in src[]
             */
            CircularBuffer!(ubyte[offsetMax + 1 + matchLenMax]) buf;

        ubyte[32] dst;  // temp buffer for output
        size_t dis;     // index in dst[] of next ubyte to be emitted
        size_t dip;     // where bits is to go in dst[]
        size_t di = 1;  // current position in dst[]

        size_t si = 0;  // current index into buf[] or src[]
        uint bitsLeft = 8; // space left in bits
        uint bits;      // encoded matchlen and offset

        bool done = false;

      public:

        this(R src) { this.src = src; }

        void popFront()
        {
            //printf("dst.popFront()\n");
            dis = (dis + 1) & 0x1F;
        }

        @property ubyte front()
        {
            //printf("dst.front()\n");
            //printf("%02x\n", dst[dis]);
            return dst[dis];
        }

        @property bool empty()
        {
            //printf("dst.empty()\n");
            if (dis != dip)
                return false;

            if (done)
                return true;

            void putBit(uint c)
            {
                bits = (bits << 1) + c;
                if (--bitsLeft == 0)
                {
                    dst[dip] = cast(ubyte)bits;
                    dip = di;
                    di = (di + 1) & 0x1F;
                    assert(di != dis);
                    bitsLeft = 8;
                }
            }

            while (1)
            {
                if (dis != dip)
                    return false;

                static if (arrayLike)
                {
                    if (si == src.length)
                        break;
                    size_t mlmax = matchLenMax;
                    if (mlmax > src.length - si)
                        mlmax = src.length - si;
                }
                else
                {
                    while (!buf.full && !src.empty)
                    {
                        buf.put(src.front);
                        src.popFront();
                    }
                    if (si == buf.length)
                        break;

                    size_t mlmax = matchLenMax;
                    if (mlmax > buf.length - si)
                        mlmax = buf.length - si;
                }

                int offsetmax = cast(int)((si > offsetMax) ? -offsetMax : -si);

                /* Look for best match, and compute matchlen and offset
                 */
                uint matchlen = 0;
                uint offset;
                for (int i = -1; i >= offsetmax; i--)
                {
                    static if (arrayLike)
                    {
                        if (src[si + i] != src[si])
                            continue;
                    }
                    else
                    {
                        if (buf[si + i] != buf[si])
                            continue;
                    }

                    // Compute longest match
                    uint j;
                    for (j = 1; j < mlmax; j++)
                    {
                        static if (arrayLike)
                        {
                            if (src[si + i + j] != src[si + j])
                                break;
                        }
                        else
                        {
                            if (buf[si + i + j] != buf[si + j])
                                break;
                        }
                    }
                    if (j > matchlen)
                    {
                        matchlen = j;
                        offset = -i - 1;
                    }
                }

                //if (matchlen > 1)
                    //printf("offset = x%x, matchlen = x%x\n", offset, matchlen);

                void advanceSrc()
                {
                    static if (arrayLike)
                        ++si;
                    else
                    {
                        if (si < offsetMax)
                            ++si;
                        else
                            buf.popFront();
                    }
                }

                switch (matchlen)
                {
                    case 0:
                    case 1:
                    Lbyte:
                        putBit(1);
                        static if (arrayLike)
                            dst[di] = src[si];
                        else
                            dst[di] = buf[si];
                        di = (di + 1) & 0x1F;
                        advanceSrc();
                        continue;

                    case 2:             // 000
                        if (offset >= 256)
                            goto Lbyte;
                        putBit(0);
                        putBit(0);
                        putBit(0);
                        dst[di] = cast(ubyte)offset;
                        di = (di + 1) & 0x1F;
                        advanceSrc();
                        advanceSrc();
                        continue;

                    case 3:             // 001
                        putBit(0);
                        putBit(0);
                        putBit(1);
                        break;

                    case 4:             // 0100
                    case 5:             // 0101
                        putBit(0);
                        putBit(1);
                        putBit(0);
                        putBit(matchlen & 1);
                        break;

                    case 6:             // 01100
                    case 7:             // 01101
                        putBit(0);
                        putBit(1);
                        putBit(1);
                        putBit(0);
                        putBit(matchlen & 1);
                        break;

                    case 8:             // 0111000
                    case 9:             // 0111001
                    case 10:            // 0111010
                    case 11:            // 0111011
                        putBit(0);
                        putBit(1);
                        putBit(1);
                        putBit(1);
                        putBit(0);
                        putBit((matchlen >> 1) & 1);
                        putBit(matchlen & 1);
                        break;

                    case 12: .. case 19:  // 011110XXX
                        putBit(0);
                        putBit(1);
                        putBit(1);
                        putBit(1);
                        putBit(1);
                        putBit(0);
                        putBit(((matchlen - 12) >> 2) & 1);
                        putBit((matchlen >> 1) & 1);
                        putBit(matchlen & 1);
                        break;

                    default:            // 011111
                        assert(matchlen <= 0x80);
                        putBit(0);
                        putBit(1);
                        putBit(1);
                        putBit(1);
                        putBit(1);
                        putBit(1);
                        dst[di] = cast(ubyte)matchlen;
                        di = (di + 1) & 0x1F;
                        break;
                }
                if (offset < 0x100)             // 00
                {
                    putBit(0);
                    putBit(0);
                }
                else if (offset < 0x200)        // 010
                {
                    putBit(0);
                    putBit(1);
                    putBit(0);
                }
                else if (offset < 0x400)        // 011X
                {
                    putBit(0);
                    putBit(1);
                    putBit(1);
                    putBit((offset >> 8) & 1);
                }
                else if (offset < 0x800)        // 100XX
                {
                    putBit(1);
                    putBit(0);
                    putBit(0);
                    putBit((offset >> 9) & 1);
                    putBit((offset >> 8) & 1);
                }
                else if (offset < 0x1000)       // 101XXX
                {
                    putBit(1);
                    putBit(0);
                    putBit(1);
                    putBit((offset >> 10) & 1);
                    putBit((offset >> 9) & 1);
                    putBit((offset >> 8) & 1);
                }
                else if (offset < 0x2000)       // 110XXXX
                {
                    putBit(1);
                    putBit(1);
                    putBit(0);
                    putBit((offset >> 11) & 1);
                    putBit((offset >> 10) & 1);
                    putBit((offset >> 9) & 1);
                    putBit((offset >> 8) & 1);
                }
                else if (offset < 0x3000)       // 1110XXXX
                {
                    putBit(1);
                    putBit(1);
                    putBit(1);
                    putBit(0);
                    putBit((offset >> 11) & 1);
                    putBit((offset >> 10) & 1);
                    putBit((offset >> 9) & 1);
                    putBit((offset >> 8) & 1);
                }
                else if (offset < 0x4000)       // 11110XXXX
                {
                    putBit(1);
                    putBit(1);
                    putBit(1);
                    putBit(1);
                    putBit(0);
                    putBit((offset >> 11) & 1);
                    putBit((offset >> 10) & 1);
                    putBit((offset >> 9) & 1);
                    putBit((offset >> 8) & 1);
                }
                else if (offset < 0x8000)       // 11111XXXXXX
                {
                    putBit(1);
                    putBit(1);
                    putBit(1);
                    putBit(1);
                    putBit(1);
                    putBit((offset >> 13) & 1);
                    putBit((offset >> 12) & 1);
                    putBit((offset >> 11) & 1);
                    putBit((offset >> 10) & 1);
                    putBit((offset >> 9) & 1);
                    putBit((offset >> 8) & 1);
                }
                else
                {
                    assert(0);
                }
                dst[di] = offset & 0xFF;
                di = (di + 1) & 0x1F;
                static if (arrayLike)
                    si += matchlen;
                else
                {
                    foreach (i; 0 .. matchlen)
                    {
                        advanceSrc();
                    }
                }

                if (dis != dip)
                    return false;
            }

            // Put end marker, 011111 0x82
            putBit(0);
            putBit(1);
            putBit(1);
            putBit(1);
            putBit(1);
            putBit(1);

            bits <<= bitsLeft;
            dst[dip] = cast(ubyte)bits;

            dst[di] = 0x82;
            di = (di + 1) & 0x1F;
            dip = di;
            done = true;
            return false;
        }
    }

    return Range(src);
}

/*************************************
 * Component to expand compressed result of LZ77 Compress.
 *
 * Description:
 *      Does not allocate memory. The expand operation is quite a bit
 *      faster than the corresponding compress.
 * Parameters:
 *      src     An InputRange over data generated by compress.
 * Returns:
 *      An InputRange which provides the expanded data.
 */


auto expand(R)(R src) if (isInputRange!R && is(ElementType!R : ubyte))
{
    enum bool arrayLike = isRandomAccessRange!R && hasLength!R;

    static struct Range
    {
      private:
        R src;
        size_t di = 0;
        enum Prime = 9;         // magic value to prime the pump
        uint bitsLeft = Prime;
        uint bits;

        static if (arrayLike)
            size_t si = 0;

        CircularBuffer!(ubyte[offsetMax + 1 + matchLenMax]) dst;

      public:
        this(R src) { this.src = src; }

        @property ubyte front()
        {
            return dst.front;
        }

        void popFront()
        {
            dst.popFront();
        }

        @property bool empty()
        {
            if (dst.length > offsetMax)
                return false;

            uint count = 0;
            uint off;
            uint offh;

            while (dst.length <= offsetMax)
            {
                // If no more input
                static if (arrayLike)
                {
                    if (si == src.length)
                        break;
                }
                else
                {
                    if (src.empty)
                        break;
                }

                if (bitsLeft == Prime)                  // prime the pump
                {
                    bits = get();
                    bitsLeft = 8;
                }

                if (getBit())
                {
                    dst.put(get());                     // straight byte
                    continue;
                }

                // 0
                if (!getBit() ||                       // 00
                    (++count, !getBit()) ||            // 010
                    (++count, !getBit()))              // 0110
                {
                    count++;            // count = 1,2,3
                    count += count + getBit(); // count = 2-7
                    //printf("count = %d\n", count);
                    if (count == 2)     // 000
                    {   off = 0;
                        goto BACK_COPY;
                    }
                }
                else
                {
                    //0111
                    if (!getBit())                     //01110XX is 8-11
                    {
                        count = getBit();
                        count = (count << 1) | getBit();
                        count += 8;
                    }
                    //01111
                    else if (!getBit())                //11110XXX is 12-19
                    {
                        count = getBit();
                        count = (count << 1) | getBit();
                        count = (count << 1) | getBit();
                        count += 12;
                    }
                    else
                    {
                        //011111
                        count = get();
                        //printf("count = %02x, si = %04x\n", count, si - *psi);
                        if (count >= 0x81)
                        {
                            if (count != 0x81)
                            {
                                // Reached the end of the source
                                static if (arrayLike)
                                {   if (si != src.length)
                                        throw new CompressException("compressed data is corrupt");
                                }
                                else
                                {   if (!src.empty)
                                        throw new CompressException("compressed data is corrupt");
                                }
                                break;
                            }
                            count = 0;
                            continue;
                        }
                    }
                }

                // Get high byte of offset

                if (getBit())
                {
                    // 1
                    if (!getBit())
                    {
                        // 10
                        offh = 0x402;
                        if (getBit())                // 100XX is 4-7
                        {
                            // 101XXX is 8-0xF
                            offh = 0x803;
                        }
                    }
                    else
                    {
                        // 11
                        offh = 0x1004;
                        if (getBit())                // 110XXXX is 0x10-0x1F
                        {
                            // 111
                            offh = 0x2004;
                            if (getBit())            // 1110XXXX is 0x20-0x2F
                            {
                                // 1111
                                offh = 0x3004;       // 11110XXXX is 0x30-0x3F
                                if (getBit())
                                    offh = 0x4006;   // 11111XXXXXX is 0x40-0x7F
                            }
                        }
                    }
                }
                //0
                else if (getBit())
                {
                    //01
                    off = 0x100;
                    if (!getBit())
                        goto BACK_COPY;         // 010 is 1
                    //011X  is 2 or 3
                    offh = 0x201;
                }
                else
                {
                    //00 is 0
                    off = 0;
                    goto BACK_COPY;
                }
                off = 0;
                do
                {
                    off = (off << 1) | (getBit() << 8);
                } while ((--offh & 0xFF) != 0);
                off += offh & 0xFF00;


            BACK_COPY:
                off |= get();           // bottom 8 bits of offset
                if (off + 1 > dst.length)
                    throw new CompressException("corrupt compressed data");
                for (; count; count--)
                {
                    dst.put(dst[dst.length - (off + 1)]);
                }
            }
            return dst.empty;
        }

      private:

        /* Get next bit from src[]
         */
        bool getBit()
        {
            bool c = (bits & 0x80) != 0;
            bits <<= 1;
            if (--bitsLeft == 0)
            {
                bitsLeft = 8;
                bits = get();
            }
            return c;
        }

        /* Get next ubyte from src[]
         */
        ubyte get()
        {
            static if (arrayLike)
                return src[si++];
            else
            {
                assert(!src.empty);
                auto c = src.front;
                src.popFront();
                return c;
            }
        }
    }

    return Range(src);
}

/* =========================================================== */


version (unittest)
{
    import core.stdc.stdio;

    // Roll our own to avoid importing std.algorithm which pulls in everything
    ubyte[] copy(R)(R src, ubyte[] dst)
    {
        size_t i = 0;
        while (!src.empty)
        {
            dst[i++] = src.front;
            src.popFront();
        }
        return dst[i .. dst.length];
    }

    // Convert array to InputRange in order to test Range code paths
    struct Adapter
    {
        this(ubyte[] r) { this.r = r; }

        @property bool empty() { return r.length == 0; }

        @property ubyte front() { return r[0]; }

        void popFront() { r = r[1 .. $]; }

        @property size_t length() { return r.length; }

      private:

        ubyte[] r;
    }
}

void test()
{
    ubyte[] src;
    src.compress();
    src.expand();
}

unittest
{
    void testArray(ubyte[] src)
    {
        auto di = new ubyte[maxCompressedSize(src.length)];
        auto result = src.compress().copy(di);
        di = di[0 .. $ - result.length];
        ubyte[] src2 = new ubyte[src.length];
        result = di.expand().copy(src2);
        if (src != src2)
        {
            printf("Buffers don't match\n");
            assert(0);
        }
    }

    void testRange(ubyte[] src1, ref Adapter src)
    {
        auto di = new ubyte[maxCompressedSize(src.length)];
        auto result = src.compress().copy(di);
        di = di[0 .. $ - result.length];
        ubyte[] src2 = new ubyte[src.length];
        result = di.expand().copy(src2);
        if (src1 != src2)
        {
            printf("Buffers don't match\n");
            assert(0);
        }
    }

    foreach (i; 0 .. 20)
    {
        ubyte[] src = new ubyte[i];
        testArray(src);
        auto a = Adapter(src);
        testRange(src, a);
    }

    static string gettysburg =
    "Four score and seven years ago our fathers brought forth on this continent a new nation,
    conceived in liberty, and dedicated to the proposition that all men are created equal.

    Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived
    and so dedicated, can long endure. We are met on a great battlefield of that war. We have come
    to dedicate a portion of that field, as a final resting place for those who here gave their
    lives that that nation might live. It is altogether fitting and proper that we should do this.

    But, in a larger sense, we can not dedicate, we can not consecrate, we can not hallow this
    ground. The brave men, living and dead, who struggled here, have consecrated it, far above our
    poor power to add or detract. The world will little note, nor long remember what we say here,
    but it can never forget what they did here. It is for us the living, rather, to be dedicated
    here to the unfinished work which they who fought here have thus far so nobly advanced. It is
    rather for us to be here dedicated to the great task remaining before us-that from these honored
    dead we take increased devotion to that cause for which they gave the last full measure of
    devotion-that we here highly resolve that these dead shall not have died in vain-that this
    nation, under God, shall have a new birth of freedom-and that government of the people, by the
    people, for the people, shall not perish from the earth.";

    testArray(cast(ubyte[])gettysburg);

    ubyte[] p = new ubyte[0x100000];
    size_t s;
    while (s < p.length)
    {
        if (s + gettysburg.length > p.length)
            break;
        p[s .. s+gettysburg.length] = (cast(ubyte[])gettysburg)[];
        s += gettysburg.length;

        foreach (i; 0 .. s)
        {
            if (s + i >= p.length)
                break;
            p[s + i] = cast(ubyte)((s + i) / 10);
        }
        s += s;
    }

    testArray(p);
}
