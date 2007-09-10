// outbuffer.d
// Written by Walter Bright
// Copyright (c) 2001 Digital Mars
// All Rights Reserved
// www.digitalmars.com

// OutBuffer provides a way to build up an array of bytes out
// of raw data. It is useful for things like preparing an
// array of bytes to write out to a file.
// OutBuffer's byte order is the format native to the computer.
// To control the byte order (endianness), use a class derived
// from OutBuffer.
// To convert an array of bytes back into raw data, use InBuffer.

import c.stdio;
import string;
import c.stdlib;

class OutBuffer
{
    ubyte data[];
    uint offset;

    invariant
    {
	//printf("this = %p, offset = %x, data.length = %u\n", this, offset, data.length);
	assert(offset <= data.length);
    }

    this()
    {
	//printf("in OutBuffer constructor\n");
    }

    /*********************************
     * Convert to array of bytes.
     */

    ubyte[] toBytes() { return data[0 .. offset]; }

    void reserve(uint nbytes)
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
	    }
	}

    void write(ubyte[] bytes)
	{
	    reserve(bytes.length);
	    data[offset .. offset + bytes.length] = bytes;
	    offset += bytes.length;
	}

    void write(ubyte b)
	{
	    reserve(ubyte.size);
	    this.data[offset] = b;
	    offset += ubyte.size;
	}

    void write(byte b) { write(cast(ubyte)b); }
    void write(char c) { write(cast(ubyte)c); }

    void write(ushort w)
    {
	reserve(ushort.size);
	*(ushort *)&data[offset] = w;
	offset += ushort.size;
    }

    void write(short s) { write(cast(ushort)s); }

    void write(wchar c)
    {
	reserve(wchar.size);
	*(wchar *)&data[offset] = c;
	offset += wchar.size;
    }

    void write(uint w)
    {
	reserve(uint.size);
	*(uint *)&data[offset] = w;
	offset += uint.size;
    }

    void write(int i) { write(cast(uint)i); }

    void write(ulong l)
    {
	reserve(ulong.size);
	*(ulong *)&data[offset] = l;
	offset += ulong.size;
    }

    void write(long l) { write(cast(ulong)l); }

    void write(float f)
    {
	reserve(float.size);
	*(float *)&data[offset] = f;
	offset += float.size;
    }

    void write(double f)
    {
	reserve(double.size);
	*(double *)&data[offset] = f;
	offset += double.size;
    }

    void write(real f)
    {
	reserve(real.size);
	*(real *)&data[offset] = f;
	offset += real.size;
    }

    void write(char[] s)
    {
	write(cast(ubyte[])s);
    }

    void write(OutBuffer buf)
    {
	write(buf.toBytes());
    }

    void fill0(uint nbytes)
    {
	reserve(nbytes);
	data[offset .. offset + nbytes] = 0;
	offset += nbytes;
    }

    /**********************************
     * 0-fill to align on power of 2 boundary.
     */

    void alignSize(uint alignsize)
    in
    {
	assert(alignsize && (alignsize & (alignsize - 1)) == 0);
    }
    out
    {
	assert((offset & (alignsize - 1)) == 0);
    }
    body
    {   uint nbytes;

	nbytes = offset & (alignsize - 1);
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
	{   uint nbytes = (4 - offset) & 3;
	    fill0(nbytes);
	}
    }

    char[] toString()
    {
	//printf("OutBuffer.toString()\n");
	return (char[])data[0 .. offset];
    }

    /*****************************************
     * vprintf() into buffer.
     */

    void vprintf(char[] format, va_list args)
    {
	char[128] buffer;
	char* p;
	char* f;
	uint psize;
	int count;

	f = toStringz(format);
	p = buffer;
	psize = buffer.length;
	for (;;)
	{
	    version(Win32)
	    {
		count = _vsnprintf(p,psize,f,args);
		if (count != -1)
		    break;
		psize *= 2;
	    }
	    version(linux)
	    {
		count = vsnprintf(p,psize,f,args);
		if (count == -1)
		    psize *= 2;
		else if (count >= psize)
		    psize = count + 1;
		else
		    break;
	    }
	    p = (char *) alloca(psize);	// buffer too small, try again with larger size
	}
	write(p[0 .. count]);
    }

    /*****************************************
     * printf() into buffer.
     */

    void printf(char[] format, ...)
    {
	va_list ap;
	ap = cast(va_list)&format;
	ap += format.size;
	vprintf(format, ap);
    }

    /*****************************************
     */

    void spread(uint index, uint nbytes)
	in
	{
	    assert(index <= offset);
	}
	body
	{
	    reserve(nbytes);

	    // This is an overlapping copy - should use memmove()
	    for (uint i = offset; i > index; )
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
    buf.write("hello");
    buf.write(cast(byte)0x20);
    buf.write("world");
    buf.printf(" %d", 6);
    //printf("buf = '%.*s'\n", buf.toString());
    assert(cmp(buf.toString(), "hello world 6") == 0);
}
