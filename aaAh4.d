//_ aaAh4.d
// Copyright (c) 2000-2001 by Digital Mars
// Written by Walter Bright

import c.stdio;
import c.stdlib;
import string;
import outofmemory;

// Implementation of associative array:
//	int aa[char[] key];

struct aaAh4
{
    aaAh4 *left;
    aaAh4 *right;
    uint hash;
    char[] key;
    int value;
}

extern (C):

/*************************************************
 * Invariant for aa.
 */

void _aaInvAh(aaAh4*[] aa)
{
    uint i;

    for (i = 0; i < aa.length; i++)
    {
	if (aa[i])
	    _aaInvAh_x(aa[i]);
    }
}

private int _aaCmpAh_x(aaAh4 *e1, aaAh4 *e2)
{   int c;

    c = e1.hash - e2.hash;
    if (c == 0)
    {
	c = e1.key.length - e2.key.length;
	if (c == 0)
	    c = memcmp((char *)e1.key, (char *)e2.key, e1.key.length);
    }
    return c;
}

private void _aaInvAh_x(aaAh4 *e)
{
    uint key_hash;
    aaAh4 *e1;
    aaAh4 *e2;

    key_hash = getHash(e.key);
    assert(key_hash == e.hash);

    while (1)
    {   int c;

	e1 = e.left;
	if (e1)
	{
	    _aaInvAh_x(e1);		// ordinary recursion
	    do
	    {
		c = _aaCmpAh_x(e1, e);
		assert(c < 0);
		e1 = e1.right;
	    } while (e1 != null);
	}

	e2 = e.right;
	if (e2)
	{
	    do
	    {
		c = _aaCmpAh_x(e, e2);
		assert(c < 0);
		e2 = e2.left;
	    } while (e2 != null);
	    e = e.right;		// tail recursion
	}
	else
	    break;
    }
}

/*************************************************
 */

uint getHash(char[] s)
{
    uint hash;
    uint len = s.length;
    char *str = s;

    hash = 0;
    while (1)
    {
	switch (len)
	{
	    case 0:
		return hash;

	    case 1:
		hash *= 9;
		hash += *(ubyte *)str;
		return hash;

	    case 2:
		hash *= 9;
		hash += *(ushort *)str;
		return hash;

	    case 3:
		hash *= 9;
		hash += (*(ushort *)str << 8) +
			((ubyte *)str)[2];
		return hash;

	    default:
		hash *= 9;
		hash += *(uint *)str;
		str += 4;
		len -= 4;
		break;
	}
    }
    return hash;
}

/****************************************************
 * Determine number of entries in associative array.
 */

int _aaLen(aaAh4*[] aa)
    in
    {
	//printf("_aaLen()+\n");
	_aaInvAh(aa);
    }
    out (result)
    {
	assert(result >= 0);
	//printf("_aaLen()-\n");
    }
    body
    {
	int len = 0;
	uint i;

	for (i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		len += _aaLen_x(aa[i]);
	}
	return len;
    }

private int _aaLen_x(aaAh4 *e)
{
    int len = 1;

    while (1)
    {
	if (e.right)
	    len += _aaLen_x(e.right);
	e = e.left;
	if (!e)
	    break;
	len++;
    }
    return len;
}

/*************************************************
 * Get pointer to value in associative array indexed by key[].
 * Add entry for key if it is not already there.
 */

int *_aaGetAh4(aaAh4*[] *aa, char[] key)
    in
    {
	assert(aa);
    }
    out (result)
    {
	assert(result);
	assert((*aa).length);
	assert(_aaInAh(*aa, key));
	assert(*aa);
    }
    body
    {
	uint key_hash;
	uint i;
	aaAh4 *e;
	aaAh4 **pe;

	if (!(*aa).length)
	{
	    alias aaAh4 *pa;

	    *aa = new pa[10];
	}

	key_hash = getHash(key);
	//printf("hash = %d\n", key_hash);
	i = key_hash % (*aa).length;
	pe = &(*aa)[i];
	while ((e = *pe) != null)
	{   int c;

	    c = key_hash - e->hash;
	    if (c == 0)
	    {
		c = key.length - e->key.length;
		if (c == 0)
		{
		    c = memcmp((char *)key, (char *)e.key, key.length);
		    if (c == 0)
		    {
			return &e->value;
		    }
		}
	    }

	    if (c < 0)
		pe = &e->left;
	    else
		pe = &e->right;
	}

	// Not found, create new elem
	//printf("create new one\n");
	e = (aaAh4 *) calloc(1, aaAh4.size);
	if (!e)
	    _d_OutOfMemory();
	e->key = key;
	e->hash = key_hash;
	*pe = e;
	return &e->value;
    }

/*************************************************
 * Determine if key is in aa.
 * Returns:
 *	0	not in aa
 *	!=0	in aa
 */

int _aaInAh(aaAh4*[] aa, char[] key)
    in
    {
    }
    out (result)
    {
	assert(result == 0 || result == 1);
    }
    body
    {
	uint key_hash;
	uint i;
	aaAh4 *e;

	if (aa.length)
	{
	    key_hash = getHash(key);
	    //printf("hash = %d\n", key_hash);
	    i = key_hash % aa.length;
	    e = aa[i];
	    while (e != null)
	    {   int c;

		c = key_hash - e->hash;
		if (c == 0)
		{
		    c = key.length - e->key.length;
		    if (c == 0)
		    {
			c = memcmp((char *)key, (char *)e.key, key.length);
			if (c == 0)
			    return 1;
		    }
		}

		if (c < 0)
		    e = e->left;
		else
		    e = e->right;
	    }
	}

	// Not found
	return 0;
    }

/*************************************************
 * Delete key entry in aa[].
 * If key is not in aa[], do nothing.
 */

void _aaDelAh(aaAh4*[] aa, char[] key)
    in
    {
	assert(aa);
    }
    out
    {
	assert(!_aaInAh(aa, key));
	assert(aa);
    }
    body
    {
	uint key_hash;
	uint i;
	aaAh4 *e;
	aaAh4 **pe;

	if (aa.length)
	{
	    key_hash = getHash(key);
	    //printf("hash = %d\n", key_hash);
	    i = key_hash % aa.length;
	    pe = &aa[i];
	    while ((e = *pe) != null)	// null means not found
	    {   int c;

		c = key_hash - e->hash;
		if (c == 0)
		{
		    c = key.length - e->key.length;
		    if (c == 0)
		    {
			c = memcmp((char *)key, (char *)e.key, key.length);
			if (c == 0)
			{
			    if (!e->left && !e->right)
			    {
				*pe = null;
			    }
			    else if (e->left && !e->right)
			    {
				*pe = e->left;
				 e->left = null;
			    }
			    else if (!e->left && e->right)
			    {
				*pe = e->right;
				 e->right = null;
			    }
			    else
			    {
				*pe = e->left;
				e->left = null;
				do
				    pe = &(*pe)->right;
				while (*pe);
				*pe = e->right;
				e->right = null;
			    }
			    e.key = null;	// enable GC to collect key[]

			    // Should notify GC that e can be free'd now
			    break;
			}
		    }
		}

		if (c < 0)
		    pe = &e->left;
		else
		    pe = &e->right;
	    }
	}
    }

/********************************************
 * Produce array of 8 byte keys from aa.
 */

char[][] _aaKeys8(aaAh4*[] aa)
    in
    {
    }
    out (result)
    {
    }
    body
    {
	int len;
	char[][] res;
	uint i;
	uint resi;

	len = _aaLen(aa);
	res = new char[len][];
	resi = 0;
	for (i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		_aaKeys8_x(aa[i], res, resi);
	}
	assert(resi == res.length);
	return res;
    }

void _aaKeys8_x(aaAh4 *e, char[][] res, inout uint resi)
    in
    {
	assert(e);
	assert(resi < res.length);
    }
    out
    {
	assert(resi <= res.length);
    }
    body
    {
	do
	{
	    res[resi++] = e.key;
	    if (e.left)
		_aaKeys8_x(e.left, res, resi);
	    e = e.right;
	} while (e != null);
    }

/********************************************
 * Produce array of 4 byte values from aa.
 */

int[] _aaValues8_4(aaAh4*[] aa)
    in
    {
    }
    out (result)
    {
    }
    body
    {
	int len;
	int[] res;
	uint i;
	uint resi;

	len = _aaLen(aa);
	res = new int[len];
	resi = 0;
	for (i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		_aaValues8_4_x(aa[i], res, resi);
	}
	assert(resi == res.length);
	return res;
    }

void _aaValues8_4_x(aaAh4 *e, int[] res, inout uint resi)
    in
    {
	assert(e);
	assert(resi < res.length);
    }
    out
    {
	assert(resi <= res.length);
    }
    body
    {
	do
	{
	    res[resi++] = e.value;
	    if (e.left)
		_aaValues8_4_x(e.left, res, resi);
	    e = e.right;
	} while (e != null);
    }

/********************************************
 * Rehash an array.
 */

aaAh4*[] _aaRehashAh(aaAh4*[] paa)
    in
    {
	_aaInvAh(paa);
    }
    out (result)
    {
	_aaInvAh(result);
    }
    body
    {
	int len;
	aaAh4*[] aa;
	aaAh4*[] newaa;
	int i;

	aa = paa;
	len = _aaLen(aa);
	if (len < 1)
	    len = 1;
	newaa = new aaAh4*[len];

	for (i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		_aaRehashAh_x(newaa, aa[i]);
	}

	return newaa;
    }

void _aaRehashAh_x(aaAh4*[] aa, aaAh4 *olde)
{
    aaAh4 *left;
    aaAh4 *right;

    while (1)
    {
	left = olde.left;
	right = olde.right;
	olde.left = null;
	olde.right = null;
	_aaRehashAh_ins(aa, olde);
	if (right)
	{
	    _aaRehashAh_x(aa, right);
	}
	if (!left)
	    break;
	olde = left;
    }
}

void _aaRehashAh_ins(aaAh4*[] aa, aaAh4 *olde)
{
    uint key_hash;
    uint i;
    aaAh4 *e;
    aaAh4 **pe;

    //printf("insert('%s')\n", (char *)olde.key);
    i = olde.hash % aa.length;
    pe = &aa[i];
    while ((e = *pe) != null)
    {   int c;

	c = _aaCmpAh_x(olde, e);
	if (c < 0)
	    pe = &e.left;
	else if (c > 0)
	    pe = &e.right;
	else
	    assert(0);
    }

    *pe = olde;
}

