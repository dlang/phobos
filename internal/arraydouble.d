
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

/* Performance figures measured by Burton Radons
 */

alias double T;

extern (C):

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] + c[]
 */

T[] _arraySliceSliceAddSliceAssign_d(T[] a, T[] c, T[] b)
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

	// SSE2 version is 333% faster 
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
	for (int i = 0; i < a.length; i++)
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

    for (int i = 0; i < dim; i++)
    {	a[i] = i;
	b[i] = i + 7;
	c[i] = i * 2;
    }

    c[] = a[] + b[];

    for (int i = 0; i < dim; i++)
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

T[] _arraySliceSliceMinSliceAssign_d(T[] a, T[] c, T[] b)
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

	// SSE2 version is 324% faster 
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
	for (int i = 0; i < a.length; i++)
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

    for (int i = 0; i < c.length; i++)
    {
	assert(c[i] == a[i] - b[i]);
    }
  }
  {
    T[] a = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    T[] b = [4, 5, 6, 7, 8, 9, 10, 11, 12];
    T[9] c;

    c[] = a[] - b[];

    for (int i = 0; i < c.length; i++)
    {
	assert(c[i] == a[i] - b[i]);
    }
  }
  {
    const int dim = 35;
    T[dim] a;
    T[dim] b;
    T[dim] c;

    for (int i = 0; i < dim; i++)
    {	a[i] = i;
	b[i] = i + 7;
	c[i] = i * 2;
    }

    c[] = a[] - b[];

    for (int i = 0; i < dim; i++)
    {
	assert(c[i] == a[i] - b[i]);
    }
  }
}


/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] + value
 */

T[] _arraySliceExpAddSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpAddSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 305% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr;
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloop:
		add ESI, 64;
		movupd XMM0, [EAX];
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		addpd XMM0, XMM4;
		addpd XMM1, XMM4;
		addpd XMM2, XMM4;
		addpd XMM3, XMM4;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloop;

		mov aptr, ESI;
		mov bptr, EAX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ = *bptr++ + value;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] += value
 */

T[] _arrayExpSliceAddass_d(T[] a, T value)
{
    //printf("_arrayExpSliceAddass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 114% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    // align pointer
	    auto n = cast(T*)((cast(uint)aptr + 7) & ~7);
	    while (aptr < n)
		*aptr++ += value;
	    n = cast(T*)((cast(uint)aend) & ~7);
	    if (aptr < n)

	    // Aligned case
	    asm 
	    {
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloopa:
		movapd XMM0, [ESI]; 
		movapd XMM1, [ESI+16];
		movapd XMM2, [ESI+32];
		movapd XMM3, [ESI+48];
		add ESI, 64;
		addpd XMM0, XMM4;
		addpd XMM1, XMM4;
		addpd XMM2, XMM4;
		addpd XMM3, XMM4;
		movapd [ESI+ 0-64], XMM0;
		movapd [ESI+16-64], XMM1;
		movapd [ESI+32-64], XMM2;
		movapd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopa;

		mov aptr, ESI;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ += value;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] += b[]
 */

T[] _arraySliceSliceAddass_d(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceAddass_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 183% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov ECX, bptr; // right operand
		mov ESI, aptr; // destination operand
		mov EDI, n; // end comparison

		align 8;
	    startsseloopb:
		movupd XMM0, [ESI];
		movupd XMM1, [ESI+16];
		movupd XMM2, [ESI+32];
		movupd XMM3, [ESI+48];
		add ESI, 64;
		movupd XMM4, [ECX]; 
		movupd XMM5, [ECX+16];
		movupd XMM6, [ECX+32];
		movupd XMM7, [ECX+48];
		add ECX, 64;
		addpd XMM0, XMM4;
		addpd XMM1, XMM5;
		addpd XMM2, XMM6;
		addpd XMM3, XMM7;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, ECX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ += *bptr++;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] - value
 */

T[] _arraySliceExpMinSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMinSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 305% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr;
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloop:
		add ESI, 64;
		movupd XMM0, [EAX];
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		subpd XMM0, XMM4;
		subpd XMM1, XMM4;
		subpd XMM2, XMM4;
		subpd XMM3, XMM4;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloop;

		mov aptr, ESI;
		mov bptr, EAX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ = *bptr++ - value;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = value - b[]
 */

T[] _arrayExpSliceMinSliceAssign_d(T[] a, T[] b, T value)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arrayExpSliceMinSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 66% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr;
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloop:
		add ESI, 64;
		movapd XMM5, XMM4;
		movapd XMM6, XMM4;
		movupd XMM0, [EAX];
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		subpd XMM5, XMM0;
		subpd XMM6, XMM1;
		movupd [ESI+ 0-64], XMM5;
		movupd [ESI+16-64], XMM6;
		movapd XMM5, XMM4;
		movapd XMM6, XMM4;
		subpd XMM5, XMM2;
		subpd XMM6, XMM3;
		movupd [ESI+32-64], XMM5;
		movupd [ESI+48-64], XMM6;
		cmp ESI, EDI; 
		jb startsseloop;

		mov aptr, ESI;
		mov bptr, EAX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ = value - *bptr++;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] -= value
 */

T[] _arrayExpSliceMinass_d(T[] a, T value)
{
    //printf("_arrayExpSliceMinass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 115% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    // align pointer
	    auto n = cast(T*)((cast(uint)aptr + 7) & ~7);
	    while (aptr < n)
		*aptr++ -= value;
	    n = cast(T*)((cast(uint)aend) & ~7);
	    if (aptr < n)

	    // Aligned case
	    asm 
	    {
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloopa:
		movapd XMM0, [ESI]; 
		movapd XMM1, [ESI+16];
		movapd XMM2, [ESI+32];
		movapd XMM3, [ESI+48];
		add ESI, 64;
		subpd XMM0, XMM4;
		subpd XMM1, XMM4;
		subpd XMM2, XMM4;
		subpd XMM3, XMM4;
		movapd [ESI+ 0-64], XMM0;
		movapd [ESI+16-64], XMM1;
		movapd [ESI+32-64], XMM2;
		movapd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopa;

		mov aptr, ESI;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ -= value;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] -= b[]
 */

T[] _arraySliceSliceMinass_d(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMinass_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 183% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov ECX, bptr; // right operand
		mov ESI, aptr; // destination operand
		mov EDI, n; // end comparison

		align 8;
	    startsseloopb:
		movupd XMM0, [ESI]; 
		movupd XMM1, [ESI+16];
		movupd XMM2, [ESI+32];
		movupd XMM3, [ESI+48];
		add ESI, 64;
		movupd XMM4, [ECX]; 
		movupd XMM5, [ECX+16];
		movupd XMM6, [ECX+32];
		movupd XMM7, [ECX+48];
		add ECX, 64;
		subpd XMM0, XMM4;
		subpd XMM1, XMM5;
		subpd XMM2, XMM6;
		subpd XMM3, XMM7;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, ECX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ -= *bptr++;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] * value
 */

T[] _arraySliceExpMulSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMulSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 304% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr;
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloop:
		add ESI, 64;
		movupd XMM0, [EAX];
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		mulpd XMM0, XMM4;
		mulpd XMM1, XMM4;
		mulpd XMM2, XMM4;
		mulpd XMM3, XMM4;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloop;

		mov aptr, ESI;
		mov bptr, EAX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ = *bptr++ * value;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] * c[]
 */

T[] _arraySliceSliceMulSliceAssign_d(T[] a, T[] c, T[] b)
in
{
	assert(a.length == b.length && b.length == c.length);
	assert(disjoint(a, b));
	assert(disjoint(a, c));
	assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceMulSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 329% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr; // left operand
		mov ECX, cptr; // right operand
		mov ESI, aptr; // destination operand
		mov EDI, n; // end comparison

		align 8;
	    startsseloopb:
		movupd XMM0, [EAX];
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add ESI, 64;
		movupd XMM4, [ECX]; 
		movupd XMM5, [ECX+16];
		movupd XMM6, [ECX+32];
		movupd XMM7, [ECX+48];
		add EAX, 64;
		mulpd XMM0, XMM4;
		mulpd XMM1, XMM5;
		mulpd XMM2, XMM6;
		mulpd XMM3, XMM7;
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
    }

    while (aptr < aend)
	*aptr++ = *bptr++ * *cptr++;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] *= value
 */

T[] _arrayExpSliceMulass_d(T[] a, T value)
{
    //printf("_arrayExpSliceMulass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 109% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    // align pointer
	    auto n = cast(T*)((cast(uint)aptr + 7) & ~7);
	    while (aptr < n)
		*aptr++ *= value;
	    n = cast(T*)((cast(uint)aend) & ~7);
	    if (aptr < n)

	    // Aligned case
	    asm 
	    {
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, value;
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloopa:
		movapd XMM0, [ESI]; 
		movapd XMM1, [ESI+16];
		movapd XMM2, [ESI+32];
		movapd XMM3, [ESI+48];
		add ESI, 64;
		mulpd XMM0, XMM4;
		mulpd XMM1, XMM4;
		mulpd XMM2, XMM4;
		mulpd XMM3, XMM4;
		movapd [ESI+ 0-64], XMM0;
		movapd [ESI+16-64], XMM1;
		movapd [ESI+32-64], XMM2;
		movapd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopa;

		mov aptr, ESI;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ *= value;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] *= b[]
 */

T[] _arraySliceSliceMulass_d(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMulass_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 205% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov ECX, bptr; // right operand
		mov ESI, aptr; // destination operand
		mov EDI, n; // end comparison

		align 8;
	    startsseloopb:
		movupd XMM0, [ESI];
		movupd XMM1, [ESI+16];
		movupd XMM2, [ESI+32];
		movupd XMM3, [ESI+48];
		add ESI, 64;
		movupd XMM4, [ECX]; 
		movupd XMM5, [ECX+16];
		movupd XMM6, [ECX+32];
		movupd XMM7, [ECX+48];
		add ECX, 64;
		mulpd XMM0, XMM4;
		mulpd XMM1, XMM5;
		mulpd XMM2, XMM6;
		mulpd XMM3, XMM7;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopb;

		mov aptr, ESI;
		mov bptr, ECX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ *= *bptr++;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] / value
 */

T[] _arraySliceExpDivSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpDivSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    /* Multiplying by the reciprocal is faster, but does
     * not produce as accurate an answer.
     */
    T recip = cast(T)1 / value;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 299% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov EAX, bptr;
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, recip;
		//movsd XMM4, value
		//rcpsd XMM4, XMM4
		shufps XMM4, XMM4, 0;

		align 8;
	    startsseloop:
		add ESI, 64;
		movupd XMM0, [EAX];
		movupd XMM1, [EAX+16];
		movupd XMM2, [EAX+32];
		movupd XMM3, [EAX+48];
		add EAX, 64;
		mulpd XMM0, XMM4;
		mulpd XMM1, XMM4;
		mulpd XMM2, XMM4;
		mulpd XMM3, XMM4;
		//divpd XMM0, XMM4;
		//divpd XMM1, XMM4;
		//divpd XMM2, XMM4;
		//divpd XMM3, XMM4;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloop;

		mov aptr, ESI;
		mov bptr, EAX;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ = *bptr++ * recip;

    return a;
}

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] /= value
 */

T[] _arrayExpSliceDivass_d(T[] a, T value)
{
    //printf("_arrayExpSliceDivass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    /* Multiplying by the reciprocal is faster, but does
     * not produce as accurate an answer.
     */
    T recip = cast(T)1 / value;

    version (D_InlineAsm_X86)
    {
	// SSE2 version is 65% faster 
	if (std.cpuid.sse2() && a.length >= 8)
	{
	    auto n = aptr + (a.length & ~7);

	    // Unaligned case
	    asm 
	    {
		mov ESI, aptr;
		mov EDI, n;
		movsd XMM4, recip;
		//movsd XMM4, value
		//rcpsd XMM4, XMM4
		shufpd XMM4, XMM4, 0;

		align 8;
	    startsseloopa:
		movupd XMM0, [ESI]; 
		movupd XMM1, [ESI+16];
		movupd XMM2, [ESI+32];
		movupd XMM3, [ESI+48];
		add ESI, 64;
		mulpd XMM0, XMM4;
		mulpd XMM1, XMM4;
		mulpd XMM2, XMM4;
		mulpd XMM3, XMM4;
		//divpd XMM0, XMM4;
		//divpd XMM1, XMM4;
		//divpd XMM2, XMM4;
		//divpd XMM3, XMM4;
		movupd [ESI+ 0-64], XMM0;
		movupd [ESI+16-64], XMM1;
		movupd [ESI+32-64], XMM2;
		movupd [ESI+48-64], XMM3;
		cmp ESI, EDI; 
		jb startsseloopa;

		mov aptr, ESI;
	    }
	}
    }

    while (aptr < aend)
	*aptr++ *= recip;

    return a;
}


