/**
 * Part of the D programming language runtime library.
 */

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module arraycat;

import object;
import std.string;
import std.c.string;
import std.c.stdio;
import std.c.stdarg;

extern (C):

byte[] _d_arraycatn(uint size, uint n, ...)
{   byte[] a;
    uint length;
    byte[]* p;
    uint i;
    byte[] b;

    p = cast(byte[]*)(&n + 1);

    for (i = 0; i < n; i++)
    {
	b = *p++;
	length += b.length;
    }
    if (!length)
	return null;

    a = new byte[length * size];
    p = cast(byte[]*)(&n + 1);

    uint j = 0;
    for (i = 0; i < n; i++)
    {
	b = *p++;
	if (b.length)
	{
	    memcpy(&a[j], b.ptr, b.length * size);
	    j += b.length * size;
	}
    }

    *cast(int *)&a = length;	// jam length
    //a.length = length;
    return a;
}

bit[] _d_arraycatb(bit[] x, bit[] y)
{   bit[] a;
    uint a_length;
    uint x_bytes;

    //printf("_d_arraycatb(x.ptr = %p, x.length = %d, y.ptr = %p, y.length = %d)\n", x.ptr, x.length, y.ptr, y.length);
    if (!x.length)
	return y;
    if (!y.length)
	return x;

    a_length = x.length + y.length;
    a = new bit[a_length];
    x_bytes = (x.length + 7) >> 3;
    memcpy(a.ptr, x.ptr, x_bytes);
    if ((x.length & 7) == 0)
	memcpy(cast(void*)a.ptr + x_bytes, y.ptr, (y.length + 7) >> 3);
    else
    {	uint x_length = x.length;
	uint y_length = y.length;
	for (uint i = 0; i < y_length; i++)
	    a[x_length + i] = y[i];
    }
    return a;
}

byte[] _d_arraycopy(uint size, byte[] from, byte[] to)
{
    //printf("f = %p,%d, t = %p,%d, size = %d\n", (void*)from, from.length, (void*)to, to.length, size);

    if (to.length != from.length)
    {
	//throw new Error(std.string.format("lengths don't match for array copy, %s = %s", to.length, from.length));
	throw new Error("lengths don't match for array copy," ~
		toString(to.length) ~ " = " ~ toString(from.length));
    }
    else if (cast(byte *)to + to.length * size <= cast(byte *)from ||
	cast(byte *)from + from.length * size <= cast(byte *)to)
    {
	memcpy(cast(byte *)to, cast(byte *)from, to.length * size);
    }
    else
    {
	throw new Error("overlapping array copy");
    }
    return to;
}

bit[] _d_arraycopybit(bit[] from, bit[] to)
{
    //printf("f = %p,%d, t = %p,%d\n", (void*)from, from.length, (void*)to, to.length);
    uint nbytes;

    if (to.length != from.length)
    {
	throw new Error("lengths don't match for array copy");
    }
    else
    {
	nbytes = (to.length + 7) / 8;
	if (cast(void *)to + nbytes <= cast(void *)from ||
	    cast(void *)from + nbytes <= cast(void *)to)
	{
	    nbytes = to.length / 8;
	    if (nbytes)
		memcpy(cast(void *)to, cast(void *)from, nbytes);

	    if (to.length & 7)
	    {
		/* Copy trailing bits.
		 */
		static ubyte[8] masks = [0,1,3,7,0x0F,0x1F,0x3F,0x7F];
		ubyte mask = masks[to.length & 7];
		(cast(ubyte*)to)[nbytes] &= ~mask;
		(cast(ubyte*)to)[nbytes] |= (cast(ubyte*)from)[nbytes] & mask;
	    }
	}
	else
	{
	    throw new Error("overlapping array copy");
	}
    }
    return to;
}

bit[] _d_arraysetbit(bit[] ba, uint lwr, uint upr, bit value)
in
{
    //printf("_d_arraysetbit(ba.length = %d, lwr = %u, upr = %u, value = %d)\n", ba.length, lwr, upr, value);
    assert(lwr <= upr);
    assert(upr <= ba.length);
}
body
{
    // Inefficient; lots of room for improvement here
    for (uint i = lwr; i < upr; i++)
	ba[i] = value;

    return ba;
}

bit[] _d_arraysetbit2(bit[] ba, bit value)
{
    //printf("_d_arraysetbit2(ba.ptr = %p, ba.length = %d, value = %d)\n", ba.ptr, ba.length, value);
    size_t len = ba.length;
    uint val = -cast(int)value;
    memset(ba.ptr, val, len >> 3);
    for (uint i = len & ~7; i < len; i++)
	ba[i] = value;
    //printf("-_d_arraysetbit2(ba.ptr = %p, ba.length = %d, value = %d)\n", ba.ptr, ba.length, ba[0]);
    return ba;
}

void* _d_arrayliteral(size_t size, size_t length, ...)
{
    byte[] result;

    //printf("_d_arrayliteral(size = %d, length = %d)\n", size, length);
    if (length == 0 || size == 0)
	result = null;
    else
    {
	result = new byte[length * size];
	*cast(size_t *)&result = length;	// jam length

	va_list q;
	va_start!(size_t)(q, length);

	size_t stacksize = (size + int.sizeof - 1) & ~(int.sizeof - 1);

	if (stacksize == size)
	{
	    memcpy(result.ptr, q, length * size);
	}
	else
	{
	    for (size_t i = 0; i < length; i++)
	    {
		memcpy(result.ptr + i * size, q, size);
		q += stacksize;
	    }
	}

	va_end(q);
    }
    return result.ptr;
}
