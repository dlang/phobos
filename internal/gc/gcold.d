/**
 * Part of the D programming language runtime library.
 */

/*
 *  Copyright (C) 2004-2007 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
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


/* Obsolete storage allocation functions, kept for link compatibility with
 * older library binaries.
 */

module std.gcold;

//debug = PRINTF;

import gc;

extern (C)
ulong _d_newarrayi(size_t length, size_t size, ...)
{
    void *p;
    ulong result;

    //debug(PRINTF) printf("_d_newarrayi(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	//void* q = cast(void*)(&size + 1);	// pointer to initializer
	va_list q;
	va_start!(size_t)(q, size);		// q is pointer to ... initializer
	p = _gc.malloc(length * size + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	if (size == 1)
	    memset(p, *cast(ubyte*)q, length);
	else if (size == int.sizeof)
	{
	    int init = *cast(int*)q;
	    for (uint u = 0; u < length; u++)
	    {
		(cast(int*)p)[u] = init;
	    }
	}
	else
	{
	    for (uint u = 0; u < length; u++)
	    {
		memcpy(p + u * size, q, size);
	    }
	}
	va_end(q);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

extern (C)
ulong _d_newarrayii(size_t length, size_t size, size_t isize ...)
{
    void *p;
    ulong result;

    //debug(PRINTF) printf("_d_newarrayii(length = %d, size = %d, isize = %d)\n", length, size, isize);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	//void* q = cast(void*)(&size + 1);	// pointer to initializer
	va_list q;
	va_start!(size_t)(q, isize);		// q is pointer to ... initializer
	size *= length;
	p = _gc.malloc(size * isize + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	if (isize == 1)
	    memset(p, *cast(ubyte*)q, size);
	else if (isize == int.sizeof)
	{
	    int init = *cast(int*)q;
	    for (uint u = 0; u < size; u++)
	    {
		(cast(int*)p)[u] = init;
	    }
	}
	else
	{
	    for (uint u = 0; u < size; u++)
	    {
		memcpy(p + u * isize, q, isize);
	    }
	}
	va_end(q);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

extern (C)
ulong _d_newm(size_t size, int ndims, ...)
{
    ulong result;

    //debug(PRINTF)
	//printf("_d_newm(size = %d, ndims = %d)\n", size, ndims);
    if (size == 0 || ndims == 0)
	result = 0;
    else
    {	va_list q;
	va_start!(int)(q, ndims);

	void[] foo(size_t* pdim, int ndims)
	{
	    size_t dim = *pdim;
	    void[] p;

	    if (ndims == 1)
	    {	p = _gc.malloc(dim * size + 1)[0 .. dim];
		memset(p.ptr, 0, dim * size + 1);
	    }
	    else
	    {
		p = _gc.malloc(dim * (void[]).sizeof + 1)[0 .. dim];
		for (int i = 0; i < dim; i++)
		{
		    (cast(void[]*)p.ptr)[i] = foo(pdim + 1, ndims - 1);
		}
	    }
	    return p;
	}

	size_t* pdim = cast(size_t *)q;
	result = cast(ulong)foo(pdim, ndims);
	//printf("result = %llx\n", result);

	version (none)
	{
	    for (int i = 0; i < ndims; i++)
	    {
		printf("index %d: %d\n", i, va_arg!(int)(q));
	    }
	}
	va_end(q);
    }
    return result;
}

extern (C)
ulong _d_newarraymi(size_t size, int ndims, ...)
{
    ulong result;

    //debug(PRINTF)
	//printf("_d_newarraymi(size = %d, ndims = %d)\n", size, ndims);
    if (size == 0 || ndims == 0)
	result = 0;
    else
    {	void* pinit;		// pointer to initializer
	va_list q;
	va_start!(int)(q, ndims);

	void[] foo(size_t* pdim, int ndims)
	{
	    size_t dim = *pdim;
	    void[] p;

	    if (ndims == 1)
	    {	p = _gc.malloc(dim * size + 1)[0 .. dim];
		if (size == 1)
		    memset(p.ptr, *cast(ubyte*)pinit, dim);
		else
		{
		    for (size_t u = 0; u < dim; u++)
		    {
			memcpy(p.ptr + u * size, pinit, size);
		    }
		}
	    }
	    else
	    {
		p = _gc.malloc(dim * (void[]).sizeof + 1)[0 .. dim];
		for (int i = 0; i < dim; i++)
		{
		    (cast(void[]*)p.ptr)[i] = foo(pdim + 1, ndims - 1);
		}
	    }
	    return p;
	}

	size_t* pdim = cast(size_t *)q;
	pinit = pdim + ndims;
	result = cast(ulong)foo(pdim, ndims);
	//printf("result = %llx\n", result);

	version (none)
	{
	    for (int i = 0; i < ndims; i++)
	    {
		printf("index %d: %d\n", i, va_arg!(int)(q));
		printf("init = %d\n", va_arg!(int)(q));
	    }
	}
	va_end(q);
    }
    return result;
}

/******************************************
 * Allocate a new array of length elements, each of size size.
 * Initialize to 0.
 */

extern (C)
ulong _d_new(size_t length, size_t size)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_new(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	p = _gc.malloc(length * size + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	memset(p, 0, length * size);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

extern (C)
byte[] _d_arraysetlength(size_t newlength, size_t sizeelem, Array *p)
in
{
    assert(sizeelem);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;

    debug(PRINTF)
    {
	printf("_d_arraysetlength(p = %p, sizeelem = %d, newlength = %d)\n", p, sizeelem, newlength);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    if (newlength)
    {
	version (D_InlineAsm_X86)
	{
	    size_t newsize = void;

	    asm
	    {
		mov	EAX,newlength	;
		mul	EAX,sizeelem	;
		mov	newsize,EAX	;
		jc	Loverflow	;
	    }
	}
	else
	{
	    size_t newsize = sizeelem * newlength;

	    if (newsize / newlength != sizeelem)
		goto Loverflow;
	}
	//printf("newsize = %x, newlength = %x\n", newsize, newlength);

	if (p.data)
	{
	    newdata = p.data;
	    if (newlength > p.length)
	    {
		size_t size = p.length * sizeelem;
		size_t cap = _gc.capacity(p.data);

		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize + 1, 1);
	}
    }
    else
    {
	newdata = p.data;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];

Loverflow:
    _d_OutOfMemory();
}

/**
 * Resize arrays for non-zero initializers.
 * (obsolete, replaced by _d_arraysetlength3)
 */
extern (C)
byte[] _d_arraysetlength2(size_t newlength, size_t sizeelem, Array *p, ...)
in
{
    assert(sizeelem);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;

    debug(PRINTF)
    {
	printf("_d_arraysetlength2(p = %p, sizeelem = %d, newlength = %d)\n", p, sizeelem, newlength);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    if (newlength)
    {
	version (D_InlineAsm_X86)
	{
	    size_t newsize = void;

	    asm
	    {
		mov	EAX,newlength	;
		mul	EAX,sizeelem	;
		mov	newsize,EAX	;
		jc	Loverflow	;
	    }
	}
	else
	{
	    size_t newsize = sizeelem * newlength;

	    if (newsize / newlength != sizeelem)
		goto Loverflow;
	}
	//printf("newsize = %x, newlength = %x\n", newsize, newlength);

	size_t size = p.length * sizeelem;
	if (p.data)
	{
	    newdata = p.data;
	    if (newlength > p.length)
	    {
		size_t cap = _gc.capacity(p.data);

		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.malloc(newsize + 1);
	}

	va_list q;
	va_start!(Array *)(q, p);	// q is pointer to initializer

	if (newsize > size)
	{
	    if (sizeelem == 1)
	    {
		//printf("newdata = %p, size = %d, newsize = %d, *q = %d\n", newdata, size, newsize, *cast(byte*)q);
		newdata[size .. newsize] = *(cast(byte*)q);
	    }
	    else
	    {
		for (size_t u = size; u < newsize; u += sizeelem)
		{
		    memcpy(newdata + u, q, sizeelem);
		}
	    }
	}
    }
    else
    {
	newdata = p.data;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];

Loverflow:
    _d_OutOfMemory();
}


version (none)
{
ulong _d_newbitarray(size_t length, bit value)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_newbitarray(length = %d, value = %d)\n", length, value);
    if (length == 0)
	result = 0;
    else
    {	size_t size = (length + 8) >> 3;	// number of bytes
	ubyte fill = value ? 0xFF : 0;

	p = _gc.malloc(size);
	debug(PRINTF) printf(" p = %p\n", p);
	memset(p, fill, size);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}
}

/***************************
 * Resize bit[] arrays.
 */

version (none)
{
extern (C)
bit[] _d_arraysetlengthb(size_t newlength, Array *p)
{
    byte* newdata;
    size_t newsize;

    debug (PRINTF)
	printf("p = %p, newlength = %d\n", p, newlength);

    assert(!p.length || p.data);
    if (newlength)
    {
	newsize = ((newlength + 31) >> 5) * 4;	// # bytes rounded up to uint
	if (p.length)
	{   size_t size = ((p.length + 31) >> 5) * 4;

	    newdata = p.data;
	    if (newsize > size)
	    {
		size_t cap = _gc.capacity(p.data);
		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize + 1, 1);
	}
    }
    else
    {
	newdata = null;
    }

    p.data = newdata;
    p.length = newlength;
    return (cast(bit *)newdata)[0 .. newlength];
}
}

version (none)
{
extern (C)
long _d_arrayappendb(Array *px, bit[] y)
{

    size_t cap = _gc.capacity(px.data);
    size_t length = px.length;
    size_t newlength = length + y.length;
    size_t newsize = (newlength + 7) / 8;
    if (newsize > cap)
    {	void* newdata;

	//newdata = _gc.malloc(newlength * size);
	newdata = _gc.malloc(newCapacity(newsize, 1) + 1);
	memcpy(newdata, px.data, (length + 7) / 8);
	px.data = cast(byte*)newdata;
    }
    px.length = newlength;
    if ((length & 7) == 0)
	// byte aligned, straightforward copy
	memcpy(px.data + length / 8, y, (y.length + 7) / 8);
    else
    {	bit* x = cast(bit*)px.data;

	for (size_t u = 0; u < y.length; u++)
	{
	    x[length + u] = y[u];
	}
    }
    return *cast(long*)px;
}
}

version (none)
{
extern (C)
bit[] _d_arrayappendcb(inout bit[] x, bit b)
{
    if (x.length & 7)
    {
	*cast(size_t *)&x = x.length + 1;
    }
    else
    {
	x.length = x.length + 1;
    }
    x[x.length - 1] = b;
    return x;
}
}

/**
 * Resize arrays for non-zero initializers.
 *	p		pointer to array lvalue to be updated
 *	newlength	new .length property of array
 *	sizeelem	size of each element of array
 *	initsize	size of initializer
 *	...		initializer
 */
extern (C)
byte[] _d_arraysetlength3(size_t newlength, size_t sizeelem, Array *p,
	size_t initsize, ...)
in
{
    assert(sizeelem);
    assert(initsize);
    assert(initsize <= sizeelem);
    assert((sizeelem / initsize) * initsize == sizeelem);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;

    debug(PRINTF)
    {
	printf("_d_arraysetlength3(p = %p, sizeelem = %d, newlength = %d, initsize = %d)\n", p, sizeelem, newlength, initsize);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    if (newlength)
    {
	version (D_InlineAsm_X86)
	{
	    size_t newsize = void;

	    asm
	    {
		mov	EAX,newlength	;
		mul	EAX,sizeelem	;
		mov	newsize,EAX	;
		jc	Loverflow	;
	    }
	}
	else
	{
	    size_t newsize = sizeelem * newlength;

	    if (newsize / newlength != sizeelem)
		goto Loverflow;
	}
	//printf("newsize = %x, newlength = %x\n", newsize, newlength);

	size_t size = p.length * sizeelem;
	if (p.data)
	{
	    newdata = p.data;
	    if (newlength > p.length)
	    {
		size_t cap = _gc.capacity(p.data);

		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.malloc(newsize + 1);
	}

	va_list q;
	va_start!(size_t)(q, initsize);	// q is pointer to initializer

	if (newsize > size)
	{
	    if (initsize == 1)
	    {
		//printf("newdata = %p, size = %d, newsize = %d, *q = %d\n", newdata, size, newsize, *cast(byte*)q);
		newdata[size .. newsize] = *(cast(byte*)q);
	    }
	    else
	    {
		for (size_t u = size; u < newsize; u += initsize)
		{
		    memcpy(newdata + u, q, initsize);
		}
	    }
	}
    }
    else
    {
	newdata = p.data;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];

Loverflow:
    _d_OutOfMemory();
}


extern (C)
long _d_arrayappend(Array *px, byte[] y, size_t size)
{

    size_t cap = _gc.capacity(px.data);
    size_t length = px.length;
    size_t newlength = length + y.length;
    if (newlength * size > cap)
    {   byte* newdata;

	newdata = cast(byte *)_gc.malloc(newCapacity(newlength, size) + 1);
	memcpy(newdata, px.data, length * size);
	px.data = newdata;
    }
    px.length = newlength;
    memcpy(px.data + length * size, y.ptr, y.length * size);
    return *cast(long*)px;
}


extern (C)
byte[] _d_arrayappendc(inout byte[] x, in size_t size, ...)
{
    size_t cap = _gc.capacity(x.ptr);
    size_t length = x.length;
    size_t newlength = length + 1;

    assert(cap == 0 || length * size <= cap);

    //printf("_d_arrayappendc(size = %d, ptr = %p, length = %d, cap = %d)\n", size, x.ptr, x.length, cap);

    if (newlength * size >= cap)
    {   byte* newdata;

	//printf("_d_arrayappendc(size = %d, newlength = %d, cap = %d)\n", size, newlength, cap);
	cap = newCapacity(newlength, size);
	assert(cap >= newlength * size);
	newdata = cast(byte *)_gc.malloc(cap + 1);
	memcpy(newdata, x.ptr, length * size);
	(cast(void **)(&x))[1] = newdata;
    }
    byte *argp = cast(byte *)(&size + 1);

    *cast(size_t *)&x = newlength;
    (cast(byte *)x)[length * size .. newlength * size] = argp[0 .. size];
    assert((cast(size_t)x.ptr & 15) == 0);
    assert(_gc.capacity(x.ptr) > x.length * size);
    return x;
}


extern (C)
byte[] _d_arraycat(byte[] x, byte[] y, size_t size)
out (result)
{
    //printf("_d_arraycat(%d,%p ~ %d,%p size = %d => %d,%p)\n", x.length, x.ptr, y.length, y.ptr, size, result.length, result.ptr);
    assert(result.length == x.length + y.length);
    for (size_t i = 0; i < x.length * size; i++)
	assert((cast(byte*)result)[i] == (cast(byte*)x)[i]);
    for (size_t i = 0; i < y.length * size; i++)
	assert((cast(byte*)result)[x.length * size + i] == (cast(byte*)y)[i]);

    size_t cap = _gc.capacity(result.ptr);
    assert(!cap || cap > result.length * size);
}
body
{
    version (none)
    {
	/* Cannot use this optimization because:
	 *  char[] a, b;
	 *  char c = 'a';
	 *	b = a ~ c;
	 *	c = 'b';
	 * will change the contents of b.
	 */
	if (!y.length)
	    return x;
	if (!x.length)
	    return y;
    }

    size_t xlen = x.length * size;
    size_t ylen = y.length * size;
    size_t len = xlen + ylen;
    if (!len)
	return null;

    byte* p = cast(byte*)_gc.malloc(len + 1);
    memcpy(p, x.ptr, xlen);
    memcpy(p + xlen, y.ptr, ylen);
    p[len] = 0;

    return p[0 .. x.length + y.length];
}


extern (C)
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

version (none)
{
extern (C)
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
}

version (none)
{
extern (C)
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

extern (C)
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

extern (C)
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
}

extern (C)
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

/**********************************
 * Support for array.dup property.
 */

extern (C) long _adDup(Array2 a, int szelem)
    out (result)
    {
	assert(memcmp((*cast(Array2*)&result).ptr, a.ptr, a.length * szelem) == 0);
    }
    body
    {
	Array2 r;

	auto size = a.length * szelem;
	r.ptr = cast(void *) new byte[size];
	r.length = a.length;
	memcpy(r.ptr, a.ptr, size);
	return *cast(long*)(&r);
    }

unittest
{
    int[] a;
    int[] b;
    int i;

    debug(adi) printf("array.dup.unittest\n");

    a = new int[3];
    a[0] = 1; a[1] = 2; a[2] = 3;
    b = a.dup;
    assert(b.length == 3);
    for (i = 0; i < 3; i++)
	assert(b[i] == i + 1);
}

/**********************************
 * Support for array.dup property for bit[].
 */

version (none)
{
extern (C) long _adDupBit(Array a)
    out (result)
    {
	assert(memcmp((*cast(Array*)(&result)).ptr, a.ptr, (a.length + 7) / 8) == 0);
    }
    body
    {
	Array r;

	auto size = (a.length + 31) / 32;
	r.ptr = cast(void *) new uint[size];
	r.length = a.length;
	memcpy(r.ptr, a.ptr, size * uint.sizeof);
	return *cast(long*)(&r);
    }

unittest
{
    bit[] a;
    bit[] b;
    int i;

    debug(adi) printf("array.dupBit[].unittest\n");

    a = new bit[3];
    a[0] = 1; a[1] = 0; a[2] = 1;
    b = a.dup;
    assert(b.length == 3);
    for (i = 0; i < 3; i++)
    {	debug(adi) printf("b[%d] = %d\n", i, b[i]);
	assert(b[i] == (((i ^ 1) & 1) ? true : false));
    }
}
}



