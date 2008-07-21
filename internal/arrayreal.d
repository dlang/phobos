
/***************************
 * D programming language http://www.digitalmars.com/d/
 * Runtime support for double array operations.
 * Placed in public domain.
 */

import std.cpuid;

bool disjoint(T)(T[] a, T[] b)
{
    return (a.ptr + a.length <= b.ptr || b.ptr + b.length <= a.ptr);
}

alias real T;

extern (C):

/* ======================================================================== */

/***********************
 * Computes:
 *	a[] = b[] + c[]
 */

T[] _arraySliceSliceAddSliceAssign_r(T[] a, T[] c, T[] b)
in
{
	assert(a.length == b.length && b.length == c.length);
	assert(disjoint(a, b));
	assert(disjoint(a, c));
	assert(disjoint(b, c));
}
body
{
    for (int i = 0; i < a.length; i++)
	a[i] = b[i] + c[i];
    return a;
}


unittest
{
    printf("_adAssAddReal unittest\n");

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

T[] _arraySliceSliceMinSliceAssign_r(T[] a, T[] c, T[] b)
in
{
	assert(a.length == b.length && b.length == c.length);
	assert(disjoint(a, b));
	assert(disjoint(a, c));
	assert(disjoint(b, c));
}
body
{
    for (int i = 0; i < a.length; i++)
	a[i] = b[i] - c[i];
    return a;
}


unittest
{
    printf("_adAssMinReal unittest\n");

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


