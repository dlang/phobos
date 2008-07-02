
/***************************
 * D programming language http://www.digitalmars.com/d/
 * Runtime support for float array operations.
 * Based on code originally written by Burton Radons.
 * Placed in public domain.
 */

import std.cpuid;

bool disjoint(T)(T[] a, T[] b)
{
    return (a.ptr + a.length <= b.ptr || b.ptr + b.length <= a.ptr);
}

alias float T;

extern (C):

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] + c[]
 */

T[] _adAssAddFloat(T[] a, T[] c, T[] b)
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

	// SSE version is 834% faster 
	if (std.cpuid.sse() && b.length >= 16)
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
		movups XMM0, [EAX]; 
		movups XMM1, [EAX+16];
		movups XMM2, [EAX+32];
		movups XMM3, [EAX+48];
		add EAX, 64;
		movups XMM4, [ECX]; 
		movups XMM5, [ECX+16];
		movups XMM6, [ECX+32];
		movups XMM7, [ECX+48];
		add ESI, 64;
		addps XMM0, XMM4;
		addps XMM1, XMM5;
		addps XMM2, XMM6;
		addps XMM3, XMM7;
		add ECX, 64;
		movups [ESI+ 0-64], XMM0;
		movups [ESI+16-64], XMM1;
		movups [ESI+32-64], XMM2;
		movups [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, EAX;
		mov cptr, ECX;
	    }
	}
	else
	// 3DNow! version is only 13% faster 
	if (std.cpuid.amd3dnow() && b.length >= 8)
	{
	    n = aptr + (b.length & ~7);

	    asm
	    {
		mov ESI, aptr; // destination operand
		mov EDI, n;    // end comparison
		mov EAX, bptr; // left operand
		mov ECX, cptr; // right operand

		align 4;
	    start3dnow:
		movq MM0, [EAX];
		movq MM1, [EAX+8];
		movq MM2, [EAX+16];
		movq MM3, [EAX+24];
		pfadd MM0, [ECX];
		pfadd MM1, [ECX+8];
		pfadd MM2, [ECX+16];
		pfadd MM3, [ECX+24];
		movq [ESI], MM0;
		movq [ESI+8], MM1;
		movq [ESI+16], MM2;
		movq [ESI+24], MM3;
		add ECX, 32;
		add ESI, 32;
		add EAX, 32;
		cmp ESI, EDI;
		jb start3dnow;

		emms;
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
    printf("_adAssAddFloat unittest\n");

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

T[] _adAssMinFloat(T[] a, T[] c, T[] b)
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

	// SSE version is 834% faster 
	if (std.cpuid.sse() && b.length >= 16)
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
		movups XMM0, [EAX]; 
		movups XMM1, [EAX+16];
		movups XMM2, [EAX+32];
		movups XMM3, [EAX+48];
		add EAX, 64;
		movups XMM4, [ECX]; 
		movups XMM5, [ECX+16];
		movups XMM6, [ECX+32];
		movups XMM7, [ECX+48];
		add ESI, 64;
		subps XMM0, XMM4;
		subps XMM1, XMM5;
		subps XMM2, XMM6;
		subps XMM3, XMM7;
		add ECX, 64;
		movups [ESI+ 0-64], XMM0;
		movups [ESI+16-64], XMM1;
		movups [ESI+32-64], XMM2;
		movups [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, EAX;
		mov cptr, ECX;
	    }
	}
	else
	// 3DNow! version is only 13% faster 
	if (std.cpuid.amd3dnow() && b.length >= 8)
	{
	    n = aptr + (b.length & ~7);

	    asm
	    {
		mov ESI, aptr; // destination operand
		mov EDI, n;    // end comparison
		mov EAX, bptr; // left operand
		mov ECX, cptr; // right operand

		align 4;
	    start3dnow:
		movq MM0, [EAX];
		movq MM1, [EAX+8];
		movq MM2, [EAX+16];
		movq MM3, [EAX+24];
		pfsub MM0, [ECX];
		pfsub MM1, [ECX+8];
		pfsub MM2, [ECX+16];
		pfsub MM3, [ECX+24];
		movq [ESI], MM0;
		movq [ESI+8], MM1;
		movq [ESI+16], MM2;
		movq [ESI+24], MM3;
		add ECX, 32;
		add ESI, 32;
		add EAX, 32;
		cmp ESI, EDI;
		jb start3dnow;

		emms;
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
    printf("_adAssMinFloat unittest\n");

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

