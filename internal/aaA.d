//_ aaA.d
// Copyright (c) 2000-2003 by Digital Mars
// Written by Walter Bright

import std.c.stdio;
import std.c.stdlib;
import std.string;
import std.outofmemory;

// Implementation of associative array

struct Array
{
    int length;
    void* ptr;
}

struct aaA
{
    aaA *left;
    aaA *right;
    uint hash;
    /* key   */
    /* value */
}


extern (C):

/*************************************************
 * Invariant for aa.
 */

/+
void _aaInvAh(aaA*[] aa)
{
    uint i;

    for (i = 0; i < aa.length; i++)
    {
	if (aa[i])
	    _aaInvAh_x(aa[i]);
    }
}

private int _aaCmpAh_x(aaA *e1, aaA *e2)
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

private void _aaInvAh_x(aaA *e)
{
    uint key_hash;
    aaA *e1;
    aaA *e2;

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
+/

/****************************************************
 * Determine number of entries in associative array.
 */

int _aaLen(aaA*[] aa)
    in
    {
	//printf("_aaLen()+\n");
	//_aaInv(aa);
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

private int _aaLen_x(aaA *e)
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
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there.
 */

void *_aaGet(aaA*[] *aa, TypeInfo keyti, int valuesize, ...)
    in
    {
	assert(aa);
    }
    out (result)
    {
	assert(result);
	assert((*aa).length);
	//assert(_aaInAh(*aa, key));
	assert(*aa);
    }
    body
    {
	void *pkey = cast(void *)(&valuesize + 1);
	uint key_hash;
	uint i;
	aaA *e;
	aaA **pe;
	int keysize = keyti.tsize();

	if (!(*aa).length)
	{
	    alias aaA *pa;

	    *aa = new pa[10];
	}

	key_hash = keyti.getHash(pkey);
	//printf("hash = %d\n", key_hash);
	i = key_hash % (*aa).length;
	pe = &(*aa)[i];
	while ((e = *pe) != null)
	{   int c;

	    c = key_hash - e.hash;
	    if (c == 0)
	    {
		c = keyti.compare(pkey, e + 1);
		if (c == 0)
		    goto Lret;
	    }

	    if (c < 0)
		pe = &e.left;
	    else
		pe = &e.right;
	}

	// Not found, create new elem
	//printf("create new one\n");
	e = cast(aaA *) cast(void*) new byte[aaA.size + keysize + valuesize];
	memcpy(e + 1, pkey, keysize);
	e.hash = key_hash;
	*pe = e;
    Lret:
	return cast(void *)(e + 1) + keysize;
    }

/*************************************************
 * Determine if key is in aa.
 * Returns:
 *	0	not in aa
 *	!=0	in aa
 */

int _aaIn(aaA*[] aa, TypeInfo keyti, ...)
    in
    {
    }
    out (result)
    {
	assert(result == 0 || result == 1);
    }
    body
    {
	void *pkey = cast(void *)(&keyti + 1);
	uint key_hash;
	uint i;
	aaA *e;

	if (aa.length)
	{
	    key_hash = keyti.getHash(pkey);
	    //printf("hash = %d\n", key_hash);
	    i = key_hash % aa.length;
	    e = aa[i];
	    while (e != null)
	    {   int c;

		c = key_hash - e.hash;
		if (c == 0)
		{
		    c = keyti.compare(pkey, e + 1);
		    if (c == 0)
			return 1;
		}

		if (c < 0)
		    e = e.left;
		else
		    e = e.right;
	    }
	}

	// Not found
	return 0;
    }

/*************************************************
 * Delete key entry in aa[].
 * If key is not in aa[], do nothing.
 */

void _aaDel(aaA*[] aa, TypeInfo keyti, ...)
    {
	void *pkey = cast(void *)(&keyti + 1);
	uint key_hash;
	uint i;
	aaA *e;
	aaA **pe;

	if (aa.length)
	{
	    key_hash = keyti.getHash(pkey);
	    //printf("hash = %d\n", key_hash);
	    i = key_hash % aa.length;
	    pe = &aa[i];
	    while ((e = *pe) != null)	// null means not found
	    {   int c;

		c = key_hash - e.hash;
		if (c == 0)
		{
		    c = keyti.compare(pkey, e + 1);
		    if (c == 0)
		    {
			if (!e.left && !e.right)
			{
			    *pe = null;
			}
			else if (e.left && !e.right)
			{
			    *pe = e.left;
			     e.left = null;
			}
			else if (!e.left && e.right)
			{
			    *pe = e.right;
			     e.right = null;
			}
			else
			{
			    *pe = e.left;
			    e.left = null;
			    do
				pe = &(*pe).right;
			    while (*pe);
			    *pe = e.right;
			    e.right = null;
			}

			// Should notify GC that e can be free'd now
			break;
		    }
		}

		if (c < 0)
		    pe = &e.left;
		else
		    pe = &e.right;
	    }
	}
    }


/********************************************
 * Produce array of v byte values from aa.
 */

Array _aaValues(aaA*[] aa, uint k, uint v)
    {
	uint resi;
	Array a;

	a.length = _aaLen(aa);
	a.ptr = new byte[a.length * v];
	resi = 0;
	for (uint i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		_aaValues_x(aa[i], a.ptr, resi, k, v);
	}
	assert(resi == a.length);
	return a;
    }

void _aaValues_x(aaA *e, void *ptr, inout uint resi, uint k, uint v)
    {
	do
	{
	    memcpy(ptr + resi * v, cast(byte*)e + aaA.size + k, v);
	    resi++;
	    if (e.left)
		_aaValues_x(e.left, ptr, resi, k, v);
	    e = e.right;
	} while (e != null);
    }

/********************************************
 * Rehash an array.
 */

aaA*[] _aaRehash(aaA*[]* paa, TypeInfo keyti)
    in
    {
	//_aaInvAh(paa);
    }
    out (result)
    {
	//_aaInvAh(result);
    }
    body
    {
	int len;
	aaA*[] aa;
	aaA*[] newaa;
	int i;

	aa = *paa;
	len = _aaLen(aa);
	if (len < 1)
	    len = 1;
	newaa = new aaA*[len];

	for (i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		_aaRehash_x(newaa, aa[i], keyti);
	}

	*paa = newaa;
	return newaa;
    }

private void _aaRehash_x(aaA*[] newaa, aaA *olde, TypeInfo keyti)
{
    aaA *left;
    aaA *right;

    while (1)
    {
	left = olde.left;
	right = olde.right;
	olde.left = null;
	olde.right = null;

	uint key_hash;
	uint i;
	aaA *e;
	aaA **pe;

	//printf("rehash %p\n", olde);
	key_hash = olde.hash;
	i = key_hash % newaa.length;
	pe = &newaa[i];
	while ((e = *pe) != null)
	{   int c;

	    //printf("\te = %p, e.left = %p, e.right = %p\n", e, e.left, e.right);
	    assert(e.left != e);
	    assert(e.right != e);
	    c = key_hash - e.hash;
	    if (c == 0)
		c = keyti.compare(olde + 1, e + 1);
	    if (c < 0)
		pe = &e.left;
	    else if (c > 0)
		pe = &e.right;
	    else
		assert(0);
	}
	*pe = olde;

	if (right)
	{
	    _aaRehash_x(newaa, right, keyti);
	}
	if (!left)
	    break;
	olde = left;
    }
}


/********************************************
 * Produce array of N byte keys from aa.
 */

Array _aaKeys(aaA*[] aa, uint n)
    {
	uint len;
	byte[] res;
	uint i;
	uint resi;

	len = _aaLen(aa);
	res = new byte[len * n];
	resi = 0;
	for (i = 0; i < aa.length; i++)
	{
	    if (aa[i])
		_aaKeys_x(aa[i], res, resi, n);
	}
	assert(resi == len);

	Array a;
	a.length = len;
	a.ptr = res;
	return a;
    }

private
void _aaKeys_x(aaA *e, byte[] res, inout uint resi, uint n)
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
	    memcpy(&res[resi * n], cast(byte*)(e + 1), n);
	    resi++;
	    if (e.left)
		_aaKeys_x(e.left, res, resi, n);
	    e = e.right;
	} while (e != null);
    }


/**********************************************
 * 'apply' for associative arrays - to support foreach
 */

// dg is D, but _aaApply() is C
extern (D) typedef int delegate(void *) dg_t;

int _aaApply(aaA*[] aa, int keysize, dg_t dg)
{   int result;

    //printf("_aaApply(aa = x%llx, keysize = %d, dg = x%llx)\n", aa, keysize, dg);

    int treewalker(aaA* e)
    {	int result;

	do
	{
	    //printf("treewalker(e = %p, dg = x%llx)\n", e, dg);
	    result = dg(cast(void *)(e + 1) + keysize);
	    if (result)
		break;
	    if (e.right)
	    {	result = treewalker(e.right);
		if (result)
		    break;
	    }
	    e = e.left;
	} while (e);

	return result;
    }

    for (uint i = 0; i < aa.length; i++)
    {
	if (aa[i])
	{
	    result = treewalker(aa[i]);
	    if (result)
		break;
	}
    }
    return result;
}

// dg is D, but _aaApply2() is C
extern (D) typedef int delegate(void *, void *) dg2_t;

int _aaApply2(aaA*[] aa, int keysize, dg2_t dg)
{   int result;

    //printf("_aaApply(aa = x%llx, keysize = %d, dg = x%llx)\n", aa, keysize, dg);

    int treewalker(aaA* e)
    {	int result;

	do
	{
	    //printf("treewalker(e = %p, dg = x%llx)\n", e, dg);
	    result = dg(cast(void *)(e + 1), cast(void *)(e + 1) + keysize);
	    if (result)
		break;
	    if (e.right)
	    {	result = treewalker(e.right);
		if (result)
		    break;
	    }
	    e = e.left;
	} while (e);

	return result;
    }

    for (uint i = 0; i < aa.length; i++)
    {
	if (aa[i])
	{
	    result = treewalker(aa[i]);
	    if (result)
		break;
	}
    }
    return result;
}

