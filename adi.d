//_ ad.d   Wed Dec 20 2000
// Copyright (c) 2000 by Digital Mars
// Written by Walter Bright

import stdio;
import stdlib;
import string;
import outofmemory;

extern (C):

int _comparei(void *e1, void *e2)
{
    return *(int *)e1 - *(int *)e2;
}

int[] _adsorti(int[] *pa)
    in
    {
	assert(pa);
    }
    out (result)
    {
	assert(result == *pa);
	if (result.length)
	    for (int i = 0; i < result.length - 1; i++)
	    {
		assert(result[i] <= result[i + 1]);
	    }
    }
    body
    {
	qsort((*pa), (*pa).length, int.size, &_comparei);
	return *pa;
    }

int[] _adreversei(int[] *pa)
    in
    {
	assert(pa);
    }
    out (result)
    {
	assert(result == *pa);
    }
    body
    {
	int[] a = *pa;

	if (a.length >= 2)
	{
	    int *lo = &a[0];
	    int *hi = &a[a.length - 1];

	    for (; lo < hi; lo++, hi--)
	    {
		int tmp;

		tmp = *lo;
		*lo = *hi;
		*hi = tmp;
	    }
	}
	return a;
    }

