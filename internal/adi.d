//_ adi.d
// Copyright (c) 2000-2003 by Digital Mars
// All Rights Reserved
// www.digitalmars.com
// Written by Walter Bright

// Dynamic array property support routines

//debug=adi;		// uncomment to turn on debugging printf's

import std.c.stdio;
import std.c.stdlib;
import std.string;
import std.outofmemory;


struct Array
{
    int length;
    void *ptr;
}


/**********************************************
 * Support for array.reverse property.
 */

extern (C) Array _adReverse(Array a, int szelem)
    out (result)
    {
	assert(result === a);
    }
    body
    {
	if (a.length >= 2)
	{
	    byte *tmp;
	    byte[16] buffer;

	    void* lo = a.ptr;
	    void* hi = a.ptr + (a.length - 1) * szelem;

	    tmp = buffer;
	    if (szelem > 16)
	    {
		//version (Win32)
		    tmp = (byte*) alloca(szelem);
		//else
		    //tmp = new byte[szelem];
	    }

	    for (; lo < hi; lo += szelem, hi -= szelem)
	    {
		memcpy(tmp, lo,  szelem);
		memcpy(lo,  hi,  szelem);
		memcpy(hi,  tmp, szelem);
	    }

	    version (Win32)
	    {
	    }
	    else
	    {
		//if (szelem > 16)
		    // BUG: bad code is generate for delete pointer, tries
		    // to call delclass.
		    //delete tmp;
	    }
	}
	return a;
    }

unittest
{
    debug(adi) printf("array.reverse.unittest\n");

    int[] a = new int[5];
    int[] b;
    int i;

    for (i = 0; i < 5; i++)
	a[i] = i;
    b = a.reverse;
    assert(b === a);
    for (i = 0; i < 5; i++)
	assert(a[i] == 4 - i);

    struct X20
    {	// More than 16 bytes in size
	int a;
	int b, c, d, e;
    }

    X20[] c = new X20[5];
    X20[] d;

    for (i = 0; i < 5; i++)
    {	c[i].a = i;
	c[i].e = 10;
    }
    d = c.reverse;
    assert(d === c);
    for (i = 0; i < 5; i++)
    {
	assert(c[i].a == 4 - i);
	assert(c[i].e == 10);
    }
}

/**********************************************
 * Support for array.reverse property for bit[].
 */

extern (C) bit[] _adReverseBit(bit[] a)
    out (result)
    {
	assert(result === a);
    }
    body
    {
	if (a.length >= 2)
	{
	    bit t;
	    int lo, hi;

	    lo = 0;
	    hi = a.length - 1;
	    for (; lo < hi; lo++, hi--)
	    {
		t = a[lo];
		a[lo] = a[hi];
		a[hi] = t;
	    }
	}
	return a;
    }

unittest
{
    debug(adi) printf("array.reverse_Bit[].unittest\n");

    bit[] b;
    b = new bit[5];
    static bit[5] data = [1,0,1,1,0];
    int i;

    b[] = data[];
    b.reverse;
    for (i = 0; i < 5; i++)
    {
	assert(b[i] == data[4 - i]);
    }
}


/**********************************
 * Support for array.dup property.
 */

extern (C) Array _adDup(Array a, int szelem)
    out (result)
    {
	assert(memcmp(result.ptr, a.ptr, a.length * szelem) == 0);
    }
    body
    {
	Array r;
	int size;

	size = a.length * szelem;
	r.ptr = (void *) new byte[size];
	r.length = a.length;
	memcpy(r.ptr, a.ptr, size);
	return r;
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

extern (C) Array _adDupBit(Array a)
    out (result)
    {
	assert(memcmp(result.ptr, a.ptr, (a.length + 7) / 8) == 0);
    }
    body
    {
	Array r;
	int size;

	size = (a.length + 31) / 32;
	r.ptr = (void *) new uint[size];
	r.length = a.length;
	memcpy(r.ptr, a.ptr, size);
	return r;
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


/***************************************
 * Support for array equality test.
 */

extern (C) int _adEq(Array a1, Array a2, TypeInfo ti)
{
    if (a1.length != a2.length)
	return 0;		// not equal
    int sz = ti.tsize();
    //printf("sz = %d\n", sz);
    void *p1 = a1.ptr;
    void *p2 = a2.ptr;
    for (int i = 0; i < a1.length; i++)
    {
	if (!ti.equals(p1 + i * sz, p2 + i * sz))
	    return 0;		// not equal
    }
    return 1;			// equal
}

unittest
{
    debug(adi) printf("array.Eq unittest\n");

    char[] a = "hello";

    assert(a != "hel");
    assert(a != "helloo");
    assert(a != "betty");
    assert(a == "hello");
    assert(a != "hxxxx");
}

/***************************************
 * Support for array equality test for bit arrays.
 */

extern (C) int _adEqBit(Array a1, Array a2)
{   int i;

    if (a1.length != a2.length)
	return 0;		// not equal
    byte *p1 = cast(byte*)a1.ptr;
    byte *p2 = cast(byte*)a2.ptr;
    uint n = a1.length / 8;
    for (i = 0; i < n; i++)
    {
	if (p1[i] != p2[i])
	    return 0;		// not equal
    }

    ubyte mask;

    n = a1.length & 7;
    mask = (1 << n) - 1;
    //printf("i = %d, n = %d, mask = %x, %x, %x\n", i, n, mask, p1[i], p2[i]);
    return (mask == 0) || (p1[i] & mask) == (p2[i] & mask);
}

unittest
{
    debug(adi) printf("array.EqBit unittest\n");

    static bit[] a = [1,0,1,0,1];
    static bit[] b = [1,0,1];
    static bit[] c = [1,0,1,0,1,0,1];
    static bit[] d = [1,0,1,1,1];
    static bit[] e = [1,0,1,0,1];

    assert(a != b);
    assert(a != c);
    assert(a != d);
    assert(a == e);
}

/***************************************
 * Support for array compare test.
 */

extern (C) int _adCmp(Array a1, Array a2, TypeInfo ti)
{
    int len;

    //printf("adCmp()\n");
    len = a1.length;
    if (a2.length < len)
	len = a2.length;
    int sz = ti.tsize();
    void *p1 = a1.ptr;
    void *p2 = a2.ptr;
    for (int i = 0; i < len; i++)
    {
	int c;

	c = ti.compare(p1 + i * sz, p2 + i * sz);
	if (c)
	    return c;
    }
    return cast(int)a1.length - cast(int)a2.length;
}

unittest
{
    debug(adi) printf("array.Cmp unittest\n");

    char[] a = "hello";

    assert(a >  "hel");
    assert(a >= "hel");
    assert(a <  "helloo");
    assert(a <= "helloo");
    assert(a >  "betty");
    assert(a >= "betty");
    assert(a == "hello");
    assert(a <= "hello");
    assert(a >= "hello");
}

/***************************************
 * Support for array compare test.
 */

extern (C) int _adCmpChar(Array a1, Array a2)
{
version (X86)
{
    asm
    {	naked			;

        push    EDI		;
        push    ESI		;

        mov    ESI,a1+4[4+ESP]	;
        mov    EDI,a2+4[4+ESP]	;

        mov    ECX,a1[4+ESP]	;
        mov    EDX,a2[4+ESP]	;

	cmp	ECX,EDX		;
	jb	GotLength	;

	mov	ECX,EDX		;

GotLength:
        cmp    ECX,4		;
        jb    DoBytes		;

        // Do alignment if neither is dword aligned
        test    ESI,3		;
        jz    Aligned		;

        test	EDI,3		;
        jz    Aligned		;
DoAlign:
        mov    AL,[ESI]		; //align ESI to dword bounds
        mov    DL,[EDI]		;

        cmp    AL,DL		;
        jnz    Unequal		;

        inc    ESI		;
        inc    EDI		;

        test    ESI,3		;

        lea    ECX,[ECX-1]	;
        jnz    DoAlign		;
Aligned:
        mov    EAX,ECX		;

	// do multiple of 4 bytes at a time

        shr    ECX,2		;
        jz    TryOdd		;

        repe			;
	cmpsd			;

        jnz    UnequalQuad	;

TryOdd:
        mov    ECX,EAX		;
DoBytes:
	// if still equal and not end of string, do up to 3 bytes slightly
	// slower.

        and    ECX,3		;
        jz    Equal		;

        repe			;
	cmpsb			;

        jnz    Unequal		;
Equal:
        mov    EAX,a1[4+ESP]	;
        mov    EDX,a2[4+ESP]	;

        sub    EAX,EDX		;
        pop    ESI		;

        pop    EDI		;
        ret			;

UnequalQuad:
        mov    EDX,[EDI-4]	;
        mov    EAX,[ESI-4]	;

        cmp    AL,DL		;
        jnz    Unequal		;

        cmp    AH,DH		;
        jnz    Unequal		;

        shr    EAX,16		;

        shr    EDX,16		;

        cmp    AL,DL		;
        jnz    Unequal		;

        cmp    AH,DH		;
Unequal:
        sbb    EAX,EAX		;
        pop    ESI		;

        or     EAX,1		;
        pop    EDI		;

        ret			;
    }
}
else
{
    int len;
    int c;

    //printf("adCmpChar()\n");
    len = a1.length;
    if (a2.length < len)
	len = a2.length;
    c = string.memcmp((char *)a1.ptr, (char *)a2.ptr, len);
    if (!c)
	c = cast(int)a1.length - cast(int)a2.length;
    return c;
}
}

unittest
{
    debug(adi) printf("array.CmpChar unittest\n");

    char[] a = "hello";

    assert(a >  "hel");
    assert(a >= "hel");
    assert(a <  "helloo");
    assert(a <= "helloo");
    assert(a >  "betty");
    assert(a >= "betty");
    assert(a == "hello");
    assert(a <= "hello");
    assert(a >= "hello");
}

/***************************************
 * Support for array compare test.
 */

extern (C) int _adCmpBit(Array a1, Array a2)
{
    int len;
    uint i;

    len = a1.length;
    if (a2.length < len)
	len = a2.length;
    ubyte *p1 = cast(ubyte*)a1.ptr;
    ubyte *p2 = cast(ubyte*)a2.ptr;
    uint n = len / 8;
    for (i = 0; i < n; i++)
    {
	if (p1[i] != p2[i])
	    break;		// not equal
    }
    for (uint j = i * 8; j < len; j++)
    {	ubyte mask = 1 << j;
	int c;

	c = (int)(p1[i] & mask) - (int)(p2[i] & mask);
	if (c)
	    return c;
    }
    return cast(int)a1.length - cast(int)a2.length;
}

unittest
{
    debug(adi) printf("array.CmpBit unittest\n");

    static bit[] a = [1,0,1,0,1];
    static bit[] b = [1,0,1];
    static bit[] c = [1,0,1,0,1,0,1];
    static bit[] d = [1,0,1,1,1];
    static bit[] e = [1,0,1,0,1];

    assert(a >  b);
    assert(a >= b);
    assert(a <  c);
    assert(a <= c);
    assert(a <  d);
    assert(a <= d);
    assert(a == e);
    assert(a <= e);
    assert(a >= e);
}


