
/***************************
 * D programming language http://www.digitalmars.com/d/
 * Runtime support for double array operations.
 * Based on code originally written by Burton Radons.
 * Placed in public domain.
 */

import std.cpuid;

bool disjoint(T)(T[] a, T[] b)
{
    return (a.ptr + a.length <= b.ptr || b.ptr + b.length <= a.ptr);
}

alias double T;

extern (C):

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] + c[]
 */

T[] _adAssAddDouble(T[] a, T[] c, T[] b)
in
{
	assert(a.length == b.length && b.length == c.length);
	assert(disjoint(a, b));
	assert(disjoint(a, c));
	assert(disjoint(b, c));
}
body
{
    version (D_InlineAsm_X86)
    {
        auto aptr = a.ptr;
	auto aend = aptr + a.length;
	auto bptr = b.ptr;
	auto cptr = c.ptr;
	T* n;

	// SSE version is 333% faster 
	if (std.cpuid.sse2() && b.length >= 16)
	{
	    n = aptr + (b.length & ~15);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr; // left operand
		mov ECX, cptr; // right operand
		mov ESI, aptr; // destination operand
		mov EDI, n;    // end comparison

		align 8;
	    startsseloopb:
		movupd XMM0, [EAX]; 
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		movupd XMM4, [ECX]; 
		movupd XMM5, [ECX+16];
		movupd XMM6, [ECX+32];
		movupd XMM7, [ECX+48];
		add ESI, 64;
		addpd XMM0, XMM4;
		addpd XMM1, XMM5;
		addpd XMM2, XMM6;
		addpd XMM3, XMM7;
		add ECX, 64;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, EAX;
		mov cptr, ECX;
	    }
	}

	// Handle remainder
        while (aptr < aend)
            *aptr++ = *bptr++ + *cptr++;
    }
    else
    {
	foreach (i; 0 .. a.length)
	    a[i] = b[i] + c[i];
    }
    return a;
}


unittest
{
    printf("_adAssAddDouble unittest\n");

  {
    T[] a = [1, 2, 3];
    T[] b = [4, 5, 6];
    T[3] c;

    c[] = a[] + b[];
    assert(c[0] == 5);
    assert(c[1] == 7);
    assert(c[2] == 9);
  }
  {
    T[] a = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    T[] b = [4, 5, 6, 7, 8, 9, 10, 11, 12];
    T[9] c;

    c[] = a[] + b[];
    assert(c[0] == 5);
    assert(c[1] == 7);
    assert(c[2] == 9);
    assert(c[3] == 11);
    assert(c[4] == 13);
    assert(c[5] == 15);
    assert(c[6] == 17);
    assert(c[7] == 19);
    assert(c[8] == 21);
  }
  {
    const int dim = 35;
    T[dim] a;
    T[dim] b;
    T[dim] c;

    foreach (i; 0 .. dim)
    {	a[i] = i;
	b[i] = i + 7;
	c[i] = i * 2;
    }

    c[] = a[] + b[];

    foreach (i; 0 .. dim)
    {
	assert(c[i] == a[i] + b[i]);
    }
  }
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] - c[]
 */

T[] _adAssMinDouble(T[] a, T[] c, T[] b)
in
{
	assert(a.length == b.length && b.length == c.length);
	assert(disjoint(a, b));
	assert(disjoint(a, c));
	assert(disjoint(b, c));
}
body
{
    version (D_InlineAsm_X86)
    {
        auto aptr = a.ptr;
	auto aend = aptr + a.length;
	auto bptr = b.ptr;
	auto cptr = c.ptr;
	T* n;

	// SSE version is 324% faster 
	if (std.cpuid.sse2() && b.length >= 8)
	{
	    n = aptr + (b.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr; // left operand
		mov ECX, cptr; // right operand
		mov ESI, aptr; // destination operand
		mov EDI, n;    // end comparison

		align 8;
	    startsseloopb:
		movupd XMM0, [EAX]; 
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		movupd XMM4, [ECX]; 
		movupd XMM5, [ECX+16];
		movupd XMM6, [ECX+32];
		movupd XMM7, [ECX+48];
		add ESI, 64;
		subpd XMM0, XMM4;
		subpd XMM1, XMM5;
		subpd XMM2, XMM6;
		subpd XMM3, XMM7;
		add ECX, 64;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, EAX;
		mov cptr, ECX;
	    }
	}

	// Handle remainder
        while (aptr < aend)
            *aptr++ = *bptr++ - *cptr++;
    }
    else
    {
	foreach (i; 0 .. a.length)
	    a[i] = b[i] - c[i];
    }
    return a;
}


unittest
{
    printf("_adAssMinDouble unittest\n");

  {
    T[] a = [1, 2, 3];
    T[] b = [4, 5, 6];
    T[3] c;

    c[] = a[] - b[];

    foreach (i; 0 .. c.length)
    {
	assert(c[i] == a[i] - b[i]);
    }
  }
  {
    T[] a = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    T[] b = [4, 5, 6, 7, 8, 9, 10, 11, 12];
    T[9] c;

    c[] = a[] - b[];

    foreach (i; 0 .. c.length)
    {
	assert(c[i] == a[i] - b[i]);
    }
  }
  {
    const int dim = 35;
    T[dim] a;
    T[dim] b;
    T[dim] c;

    foreach (i; 0 .. dim)
    {	a[i] = i;
	b[i] = i + 7;
	c[i] = i * 2;
    }

    c[] = a[] - b[];

    foreach (i; 0 .. dim)
    {
	assert(c[i] == a[i] - b[i]);
    }
  }
}


