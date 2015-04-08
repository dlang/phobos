// Written in the D programming language.

/**
Serialize data to $(D ubyte) arrays.

 * Macros:
 *      WIKI = Phobos/StdOutbuffer
 *
 * Copyright: Copyright Digital Mars 2000 - 2015.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_outbuffer.d)
 */
module std.outbuffer;

private
{
    import core.memory;
    import core.stdc.stdarg;
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import std.algorithm;
    import std.string;
}

/*********************************************
 * OutBuffer provides a way to build up an array of bytes out
 * of raw data. It is useful for things like preparing an
 * array of bytes to write out to a file.
 * OutBuffer's byte order is the format native to the computer.
 * To control the byte order (endianness), use a class derived
 * from OutBuffer.
 * OutBuffer's internal buffer is allocated with the GC.
 */

class OutBuffer
{
    ubyte[] data;
    size_t offset;

    invariant()
    {
        //printf("this = %p, offset = %x, data.length = %u\n", this, offset, data.length);
        assert(offset <= data.length);
    }

  pure nothrow @safe
  {
    this()
    {
        //printf("in OutBuffer constructor\n");
    }

    /*********************************
     * Convert to array of bytes.
     */

    ubyte[] toBytes() { return data[0 .. offset]; }

    /***********************************
     * Preallocate nbytes more to the size of the internal buffer.
     *
     * This is a
     * speed optimization, a good guess at the maximum size of the resulting
     * buffer will improve performance by eliminating reallocations and copying.
     */


    void reserve(size_t nbytes) @trusted
        in
        {
            assert(offset + nbytes >= offset);
        }
        out
        {
            assert(offset + nbytes <= data.length);
        }
        body
        {
            //c.stdio.printf("OutBuffer.reserve: length = %d, offset = %d, nbytes = %d\n", data.length, offset, nbytes);
            if (data.length < offset + nbytes)
            {
                data.length = (offset + nbytes) * 2;
                GC.clrAttr(data.ptr, GC.BlkAttr.NO_SCAN);
            }
        }

    /**********************************
     * put enables OutBuffer to be used as an OutputRange.
     */
    alias write put;

    /*************************************
     * Append data to the internal buffer.
     */

    void write(const(ubyte)[] bytes)
        {
            reserve(bytes.length);
            data[offset .. offset + bytes.length] = bytes[];
            offset += bytes.length;
        }

    void write(in wchar[] chars) @trusted
        {
        write(cast(ubyte[]) chars);
        }

    void write(const(dchar)[] chars) @trusted
        {
        write(cast(ubyte[]) chars);
        }

    void write(ubyte b)         /// ditto
        {
            reserve(ubyte.sizeof);
            this.data[offset] = b;
            offset += ubyte.sizeof;
        }

    void write(byte b) { write(cast(ubyte)b); }         /// ditto
    void write(char c) { write(cast(ubyte)c); }         /// ditto
    void write(dchar c) { write(cast(uint)c); }         /// ditto

    void write(ushort w) @trusted                /// ditto
    {
        reserve(ushort.sizeof);
        *cast(ushort *)&data[offset] = w;
        offset += ushort.sizeof;
    }

    void write(short s) { write(cast(ushort)s); }               /// ditto

    void write(wchar c) @trusted        /// ditto
    {
        reserve(wchar.sizeof);
        *cast(wchar *)&data[offset] = c;
        offset += wchar.sizeof;
    }

    void write(uint w) @trusted         /// ditto
    {
        reserve(uint.sizeof);
        *cast(uint *)&data[offset] = w;
        offset += uint.sizeof;
    }

    void write(int i) { write(cast(uint)i); }           /// ditto

    void write(ulong l) @trusted         /// ditto
    {
        reserve(ulong.sizeof);
        *cast(ulong *)&data[offset] = l;
        offset += ulong.sizeof;
    }

    void write(long l) { write(cast(ulong)l); }         /// ditto

    void write(float f) @trusted         /// ditto
    {
        reserve(float.sizeof);
        *cast(float *)&data[offset] = f;
        offset += float.sizeof;
    }

    void write(double f) @trusted               /// ditto
    {
        reserve(double.sizeof);
        *cast(double *)&data[offset] = f;
        offset += double.sizeof;
    }

    void write(real f) @trusted         /// ditto
    {
        reserve(real.sizeof);
        *cast(real *)&data[offset] = f;
        offset += real.sizeof;
    }

    void write(in char[] s) @trusted             /// ditto
    {
        write(cast(ubyte[])s);
    }

    void write(OutBuffer buf)           /// ditto
    {
        write(buf.toBytes());
    }

    /****************************************
     * Append nbytes of 0 to the internal buffer.
     */

    void fill0(size_t nbytes)
    {
        reserve(nbytes);
        data[offset .. offset + nbytes] = 0;
        offset += nbytes;
    }

    /**********************************
     * 0-fill to align on power of 2 boundary.
     */

    void alignSize(size_t alignsize)
    in
    {
        assert(alignsize && (alignsize & (alignsize - 1)) == 0);
    }
    out
    {
        assert((offset & (alignsize - 1)) == 0);
    }
    body
    {
        auto nbytes = offset & (alignsize - 1);
        if (nbytes)
            fill0(alignsize - nbytes);
    }

    /****************************************
     * Optimize common special case alignSize(2)
     */

    void align2()
    {
        if (offset & 1)
            write(cast(byte)0);
    }

    /****************************************
     * Optimize common special case alignSize(4)
     */

    void align4()
    {
        if (offset & 3)
        {   auto nbytes = (4 - offset) & 3;
            fill0(nbytes);
        }
    }

    /**************************************
     * Convert internal buffer to array of chars.
     */

    override string toString() const
    {
        //printf("OutBuffer.toString()\n");
        return cast(string) data[0 .. offset].idup;
    }
  }

    /*****************************************
     * Append output of C's vprintf() to internal buffer.
     */

    void vprintf(string format, va_list args) @trusted nothrow
    {
        char[128] buffer;
        int count;

        // Can't use `tempCString()` here as it will result in compilation error:
        // "cannot mix core.std.stdlib.alloca() and exception handling".
        auto f = toStringz(format);
        auto p = buffer.ptr;
        auto psize = buffer.length;
        for (;;)
        {
            version(Windows)
            {
                count = _vsnprintf(p,psize,f,args);
                if (count != -1)
                    break;
                psize *= 2;
                p = cast(char *) alloca(psize); // buffer too small, try again with larger size
            }
            else version(Posix)
            {
                count = vsnprintf(p,psize,f,args);
                if (count == -1)
                    psize *= 2;
                else if (count >= psize)
                    psize = count + 1;
                else
                    break;
                /+
                if (p != buffer)
                    c.stdlib.free(p);
                p = (char *) c.stdlib.malloc(psize);    // buffer too small, try again with larger size
                +/
                p = cast(char *) alloca(psize); // buffer too small, try again with larger size
            }
            else
            {
                static assert(0);
            }
        }
        write(cast(ubyte[]) p[0 .. count]);
        /+
        version (Posix)
        {
            if (p != buffer)
                c.stdlib.free(p);
        }
        +/
    }

    /*****************************************
     * Append output of C's printf() to internal buffer.
     */

    void printf(string format, ...) @trusted
    {
        va_list ap;
        va_start(ap, format);
        vprintf(format, ap);
        va_end(ap);
    }

    /**
     * Formats and writes its arguments in text format to the OutBuffer.
     *
     * Params:
     *  fmt = format string as described in $(XREF format, formattedWrite)
     *  args = arguments to be formatted
     *
     * See_Also:
     *  $(XREF stdio, writef);
     *  $(XREF format, formattedWrite);
     */
    void writef(Char, A...)(in Char[] fmt, A args)
    {
        import std.format : formattedWrite;
        formattedWrite(this, fmt, args);
    }

    ///
    unittest
    {
        OutBuffer b = new OutBuffer();
        b.writef("a%sb", 16);
        assert(b.toString() == "a16b");
    }

    /**
     * Formats and writes its arguments in text format to the OutBuffer,
     * followed by a newline.
     *
     * Params:
     *  fmt = format string as described in $(XREF format, formattedWrite)
     *  args = arguments to be formatted
     *
     * See_Also:
     *  $(XREF stdio, writefln);
     *  $(XREF format, formattedWrite);
     */
    void writefln(Char, A...)(in Char[] fmt, A args)
    {
        import std.format : formattedWrite;
        formattedWrite(this, fmt, args);
        put('\n');
    }

    ///
    unittest
    {
        OutBuffer b = new OutBuffer();
        b.writefln("a%sb", 16);
        assert(b.toString() == "a16b\n");
    }

    /*****************************************
     * At offset index into buffer, create nbytes of space by shifting upwards
     * all data past index.
     */

    void spread(size_t index, size_t nbytes) pure nothrow @safe
        in
        {
            assert(index <= offset);
        }
        body
        {
            reserve(nbytes);

            // This is an overlapping copy - should use memmove()
            for (size_t i = offset; i > index; )
            {
                --i;
                data[i + nbytes] = data[i];
            }
            offset += nbytes;
        }
}

unittest
{
    //printf("Starting OutBuffer test\n");

    OutBuffer buf = new OutBuffer();

    //printf("buf = %p\n", buf);
    //printf("buf.offset = %x\n", buf.offset);
    assert(buf.offset == 0);
    buf.write("hello"[]);
    buf.write(cast(byte)0x20);
    buf.write("world"[]);
    buf.printf(" %d", 6);
    //auto s = buf.toString();
    //printf("buf = '%.*s'\n", s.length, s.ptr);
    assert(cmp(buf.toString(), "hello world 6") == 0);
}

unittest
{
    import std.range;
    static assert(isOutputRange!(OutBuffer, char));

    import std.algorithm;
  {
    OutBuffer buf = new OutBuffer();
    "hello".copy(buf);
    assert(buf.toBytes() == "hello");
  }
  {
    OutBuffer buf = new OutBuffer();
    "hello"w.copy(buf);
    assert(buf.toBytes() == "h\x00e\x00l\x00l\x00o\x00");
  }
  {
    OutBuffer buf = new OutBuffer();
    "hello"d.copy(buf);
    assert(buf.toBytes() == "h\x00\x00\x00e\x00\x00\x00l\x00\x00\x00l\x00\x00\x00o\x00\x00\x00");
  }
}
