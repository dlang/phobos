//_ aaA.d

/**
 * Part of the D programming language runtime library.
 * Implementation of associative arrays.
 */

/*
 *  Copyright (C) 2000-2010 by Digital Mars, http://www.digitalmars.com
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


//import std.stdio;
import std.c.stdarg;
import std.c.stdio;
import std.c.stdlib;
import std.c.string;
import std.string;
import std.gc;

import std.outofmemory;

// Auto-rehash and pre-allocate - Dave Fladebo

static size_t[] prime_list = [
               97UL,            389UL,
            1_543UL,          6_151UL,
           24_593UL,         98_317UL,
          393_241UL,      1_572_869UL,
        6_291_469UL,     25_165_843UL,
      100_663_319UL,    402_653_189UL,
    1_610_612_741UL,  4_294_967_291UL,
//    8_589_934_513UL, 17_179_869_143UL
];

/* This is the type of the return value for dynamic arrays.
 * It should be a type that is returned in registers.
 * Although DMD will return types of Array in registers,
 * gcc will not, so we instead use a 'long'.
 */
alias long ArrayRet_t;

struct Array
{
    size_t length;
    void* ptr;
}

struct aaA
{
    aaA *left;
    aaA *right;
    hash_t hash;
    version (X86_64)
        size_t padto16;         // don't always need it, but have to change API to fix it
    /* key   */
    /* value */
}

struct BB
{
    aaA*[] b;
    size_t nodes;       // total number of aaA nodes
}

/* This is the type actually seen by the programmer, although
 * it is completely opaque.
 */

struct AA
{
    BB* a;
}

/**********************************
 * Align to next pointer boundary, so that
 * GC won't be faced with misaligned pointers
 * in value.
 */

size_t aligntsize(size_t tsize)
{
    version (X86_64)
        // Size of key needed to align value on 16 bytes
        return (tsize + 15) & ~(15);
    else
        return (tsize + size_t.sizeof - 1) & ~(size_t.sizeof - 1);
}

extern (C):

/*************************************************
 * Invariant for aa.
 */

/+
void _aaInvAh(aaA*[] aa)
{
    for (size_t i = 0; i < aa.length; i++)
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
    hash_t key_hash;
    aaA *e1;
    aaA *e2;

    key_hash = getHash(e.key);
    assert(key_hash == e.hash);

    while (1)
    {   int c;

        e1 = e.left;
        if (e1)
        {
            _aaInvAh_x(e1);             // ordinary recursion
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
            e = e.right;                // tail recursion
        }
        else
            break;
    }
}
+/

/****************************************************
 * Determine number of entries in associative array.
 */

size_t _aaLen(AA aa)
    in
    {
        //printf("_aaLen()+\n");
        //_aaInv(aa);
    }
    out (result)
    {
        size_t len = 0;

        void _aaLen_x(aaA* ex)
        {
            auto e = ex;
            len++;

            while (1)
            {
                if (e.right)
                    _aaLen_x(e.right);
                e = e.left;
                if (!e)
                    break;
                len++;
            }
        }

        if (aa.a)
        {
            foreach (e; aa.a.b)
            {
                if (e)
                    _aaLen_x(e);
            }
        }
        assert(len == result);

        //printf("_aaLen()-\n");
    }
    body
    {
        return aa.a ? aa.a.nodes : 0;
    }


/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there.
 */

/* Retained for binary backwards compatibility
 */
void* _aaGet(AA* aa, TypeInfo keyti, size_t valuesize, ...)
{
    return _aaGetX(aa, keyti, valuesize, cast(void *)(&valuesize + 1));
}

void* _aaGetX(AA* aa, TypeInfo keyti, size_t valuesize, void* pkey)
    in
    {
        assert(aa);
    }
    out (result)
    {
        assert(result);
        assert(aa.a);
        assert(aa.a.b.length);
        //assert(_aaInAh(*aa.a, key));
    }
    body
    {
        //printf("aaGet()\n");
        size_t i;
        aaA* e;
        auto keysize = aligntsize(keyti.tsize());
        //printf("keysize = %d\n", keysize);

        if (!aa.a)
            aa.a = new BB();

        if (!aa.a.b.length)
        {
            alias aaA *pa;
            auto len = prime_list[0];

            aa.a.b = new pa[len];
        }

        auto key_hash = keyti.getHash(pkey);
        //printf("hash = %d\n", key_hash);
        i = key_hash % aa.a.b.length;
        auto pe = &aa.a.b[i];
        while ((e = *pe) !is null)
        {
            if (key_hash == e.hash)
            {
                auto c = keyti.compare(pkey, e + 1);
                if (c == 0)
                    goto Lret;
                pe = (c < 0) ? &e.left : &e.right;
            }
            else
                pe = (key_hash < e.hash) ? &e.left : &e.right;
        }

        // Not found, create new elem
        //printf("create new one\n");
        std.gc.disable();
        e = cast(aaA *) cast(void*) new void[aaA.sizeof + keysize + valuesize];
        std.gc.enable();
        memcpy(e + 1, pkey, keysize);
        e.hash = key_hash;
        *pe = e;

        auto nodes = ++aa.a.nodes;
        //printf("length = %d, nodes = %d\n", (*aa.a).length, nodes);
        if (nodes > aa.a.b.length * 4)
        {
            _aaRehash(aa,keyti);
        }

    Lret:
        return cast(void *)(e + 1) + keysize;
    }

/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Returns null if it is not already there.
 */

void* _aaGetRvalue(AA aa, TypeInfo keyti, size_t valuesize, ...)
{
    return _aaGetRvalueX(aa, keyti, valuesize, cast(void *)(&valuesize + 1));
}

void* _aaGetRvalueX(AA aa, TypeInfo keyti, size_t valuesize, void *pkey)
    {
        //printf("_aaGetRvalue(valuesize = %u)\n", valuesize);
        if (!aa.a)
            return null;

        auto keysize = aligntsize(keyti.tsize());
        auto len = aa.a.b.length;

        if (len)
        {
            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            size_t i = key_hash % len;
            auto e = aa.a.b[i];
            while (e !is null)
            {
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
                    if (c == 0)
                        return cast(void *)(e + 1) + keysize;
                    e = (c < 0) ? e.left : e.right;
                }
                else
                    e = (key_hash < e.hash) ? e.left : e.right;
            }
        }
        return null;    // not found, caller will throw exception
    }


/*************************************************
 * Determine if key is in aa.
 * Returns:
 *      null    not in aa
 *      !=null  in aa, return pointer to value
 */

void* _aaIn(AA aa, TypeInfo keyti, ...)
{
    return _aaInX(aa, keyti, cast(void *)(&keyti + 1));
}

void* _aaInX(AA aa, TypeInfo keyti, void* pkey)
    in
    {
    }
    out (result)
    {
        //assert(result == 0 || result == 1);
    }
    body
    {
        if (aa.a)
        {
            //printf("_aaIn(), .length = %d, .ptr = %x\n", aa.a.length, cast(uint)aa.a.ptr);
            auto len = aa.a.b.length;

            if (len)
            {
                auto key_hash = keyti.getHash(pkey);
                //printf("hash = %d\n", key_hash);
                size_t i = key_hash % len;
                auto e = aa.a.b[i];
                while (e !is null)
                {
                    if (key_hash == e.hash)
                    {
                        auto c = keyti.compare(pkey, e + 1);
                        if (c == 0)
                            return cast(void *)(e + 1) + aligntsize(keyti.tsize());
                        e = (c < 0) ? e.left : e.right;
                    }
                    else
                        e = (key_hash < e.hash) ? e.left : e.right;
                }
            }
        }

        // Not found
        return null;
    }


/*************************************************
 * Delete key entry in aa[].
 * If key is not in aa[], do nothing.
 */

void _aaDel(AA aa, TypeInfo keyti, ...)
{
    return _aaDelX(aa, keyti, cast(void *)(&keyti + 1));
}

void _aaDelX(AA aa, TypeInfo keyti, void* pkey)
    {
        aaA* e;

        if (aa.a && aa.a.b.length)
        {
            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            size_t i = key_hash % aa.a.b.length;
            auto pe = &aa.a.b[i];
            while ((e = *pe) !is null)  // null means not found
            {
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
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

                        aa.a.nodes--;

                        // Should notify GC that e can be free'd now
                        delete e;
                        break;
                    }
                    pe = (c < 0) ? &e.left : &e.right;
                }
                else
                    pe = (key_hash < e.hash) ? &e.left : &e.right;
            }
        }
    }


/********************************************
 * Produce array of values from aa.
 */

ArrayRet_t _aaValues(AA aa, size_t keysize, size_t valuesize)
    in
    {
        assert(keysize == aligntsize(keysize));
    }
    body
    {
        size_t resi;
        Array a;

        void _aaValues_x(aaA* e)
        {
            do
            {
                memcpy(a.ptr + resi * valuesize,
                       cast(byte*)e + aaA.sizeof + keysize,
                       valuesize);
                resi++;
                if (e.left)
                {   if (!e.right)
                    {   e = e.left;
                        continue;
                    }
                    _aaValues_x(e.left);
                }
                e = e.right;
            } while (e !is null);
        }

        if (aa.a)
        {
            a.length = _aaLen(aa);
            a.ptr = (new void[a.length * valuesize]).ptr;
            resi = 0;
            foreach (e; aa.a.b)
            {
                if (e)
                    _aaValues_x(e);
            }
            assert(resi == a.length);
        }
        return *cast(ArrayRet_t*)(&a);
    }


/********************************************
 * Rehash an array.
 */

void* _aaRehash(AA* paa, TypeInfo keyti)
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
        BB newb;

        void _aaRehash_x(aaA* olde)
        {
            while (1)
            {
                auto left = olde.left;
                auto right = olde.right;
                olde.left = null;
                olde.right = null;

                aaA* e;

                //printf("rehash %p\n", olde);
                auto key_hash = olde.hash;
                size_t i = key_hash % newb.b.length;
                auto pe = &newb.b[i];
                while ((e = *pe) !is null)
                {
                    //printf("\te = %p, e.left = %p, e.right = %p\n", e, e.left, e.right);
                    assert(e.left != e);
                    assert(e.right != e);
                    if (key_hash == e.hash)
                    {
                        auto c = keyti.compare(olde + 1, e + 1);
                        assert(c != 0);
                        pe = (c < 0) ? &e.left : &e.right;
                    }
                    else
                        pe = (key_hash < e.hash) ? &e.left : &e.right;
                }
                *pe = olde;

                if (right)
                {
                    if (!left)
                    {   olde = right;
                        continue;
                    }
                    _aaRehash_x(right);
                }
                if (!left)
                    break;
                olde = left;
            }
        }

        //printf("Rehash\n");
        if (paa.a)
        {
            auto aa = paa.a;
            auto len = _aaLen(*paa);
            if (len)
            {   size_t i;

                for (i = 0; i < prime_list.length - 1; i++)
                {
                    if (len <= prime_list[i])
                        break;
                }
                //printf("rehash %d x%x\n", len, len);
                len = prime_list[i];
                newb.b = new aaA*[len];

                foreach (e; aa.b)
                {
                    if (e)
                        _aaRehash_x(e);
                }
                delete aa.b;

                newb.nodes = aa.nodes;
            }

            *paa.a = newb;
            _aaBalance(paa);
        }
        return (*paa).a;
    }

/********************************************
 * Balance an array.
 */

void _aaBalance(AA* paa)
{
    //printf("_aaBalance()\n");
    if (paa.a)
    {
        aaA*[16] tmp;
        aaA*[] array = tmp;

        auto aa = paa.a;
        foreach (j, e; aa.b)
        {
            /* Temporarily store contents of bucket in array[]
             */
            size_t k = 0;

            void addToArray(aaA* e)
            {
                while (e)
                {   addToArray(e.left);
                    if (k == array.length)
                        array.length = array.length * 2;
                    array[k++] = e;
                    e = e.right;
                }
            }

            addToArray(e);

            /* The contents of the bucket are now sorted into array[].
             * Rebuild the tree.
             */

            void buildTree(aaA** p, size_t x1, size_t x2)
            {
                if (x1 >= x2)
                    *p = null;
                else
                {   auto mid = (x1 + x2) >> 1;
                    *p = array[mid];
                    buildTree(&(*p).left, x1, mid);
                    buildTree(&(*p).right, mid + 1, x2);
                }
            }

            auto p = &aa.b[j];
            buildTree(p, 0, k);
        }
    }
}

/********************************************
 * Produce array of N byte keys from aa.
 */

ArrayRet_t _aaKeys(AA aa, size_t keysize)
    {
        byte[] res;
        size_t resi;

        void _aaKeys_x(aaA* e)
        {
            do
            {
                memcpy(&res[resi * keysize], cast(byte*)(e + 1), keysize);
                resi++;
                if (e.left)
                {   if (!e.right)
                    {   e = e.left;
                        continue;
                    }
                    _aaKeys_x(e.left);
                }
                e = e.right;
            } while (e !is null);
        }

        auto len = _aaLen(aa);
        if (!len)
            return 0;
        res = cast(byte[])new void[len * keysize];
        resi = 0;
        foreach (e; aa.a.b)
        {
            if (e)
                _aaKeys_x(e);
        }
        assert(resi == len);

        Array a;
        a.length = len;
        a.ptr = res.ptr;
        return *cast(ArrayRet_t*)(&a);
    }


/**********************************************
 * 'apply' for associative arrays - to support foreach
 */

// dg is D, but _aaApply() is C
extern (D) typedef int delegate(void *) dg_t;

int _aaApply(AA aa, size_t keysize, dg_t dg)
in
{
    assert(aligntsize(keysize) == keysize);
}
body
{   int result;

    //printf("_aaApply(aa = x%llx, keysize = %d, dg = x%llx)\n", aa.a, keysize, dg);

    int treewalker(aaA* e)
    {   int result;

        do
        {
            //printf("treewalker(e = %p, dg = x%llx)\n", e, dg);
            result = dg(cast(void *)(e + 1) + keysize);
            if (result)
                break;
            if (e.right)
            {   if (!e.left)
                {
                    e = e.right;
                    continue;
                }
                result = treewalker(e.right);
                if (result)
                    break;
            }
            e = e.left;
        } while (e);

        return result;
    }

    if (aa.a)
    {
        foreach (e; aa.a.b)
        {
            if (e)
            {
                result = treewalker(e);
                if (result)
                    break;
            }
        }
    }
    return result;
}

// dg is D, but _aaApply2() is C
extern (D) typedef int delegate(void *, void *) dg2_t;

int _aaApply2(AA aa, size_t keysize, dg2_t dg)
in
{
    assert(aligntsize(keysize) == keysize);
}
body
{   int result;

    //printf("_aaApply(aa = x%llx, keysize = %d, dg = x%llx)\n", aa.a, keysize, dg);

    int treewalker(aaA* e)
    {   int result;

        do
        {
            //printf("treewalker(e = %p, dg = x%llx)\n", e, dg);
            result = dg(cast(void *)(e + 1), cast(void *)(e + 1) + keysize);
            if (result)
                break;
            if (e.right)
            {   if (!e.left)
                {
                    e = e.right;
                    continue;
                }
                result = treewalker(e.right);
                if (result)
                    break;
            }
            e = e.left;
        } while (e);

        return result;
    }

    if (aa.a)
    {
        foreach (e; aa.a.b)
        {
            if (e)
            {
                result = treewalker(e);
                if (result)
                    break;
            }
        }
    }
    return result;
}


/***********************************
 * Construct an associative array of type ti from
 * length pairs of key/value pairs.
 */

extern (C)
BB* _d_assocarrayliteralT(TypeInfo_AssociativeArray ti, size_t length, ...)
{
    auto valuesize = ti.next.tsize();           // value size
    auto keyti = ti.key;
    auto keysize = keyti.tsize();               // key size
    BB* result;

    //printf("_d_assocarrayliteralT(keysize = %d, valuesize = %d, length = %d)\n", keysize, valuesize, length);
    //printf("tivalue = %.*s\n", ti.next.classinfo.name);
    if (length == 0 || valuesize == 0 || keysize == 0)
    {
        ;
    }
    else
    {
        va_list q;
        version (X86_64) va_start(q, __va_argsave); else va_start(q, length);

        result = new BB();
        size_t i;

        for (i = 0; i < prime_list.length - 1; i++)
        {
            if (length <= prime_list[i])
                break;
        }
        auto len = prime_list[i];
        result.b = new aaA*[len];

        size_t keystacksize   = (keysize   + size_t.sizeof - 1) & ~(size_t.sizeof - 1);
        size_t valuestacksize = (valuesize + size_t.sizeof - 1) & ~(size_t.sizeof - 1);

        size_t keytsize = aligntsize(keysize);

        aaA* ne;
        for (size_t j = 0; j < length; j++)
        {
            if (!ne)
                ne = cast(aaA *) cast(void*) new void[aaA.sizeof + keytsize + valuesize];
            void* pkey = ne + 1;
            va_arg(q, keyti, pkey);
            //q += keystacksize;
            aaA* e;

            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            i = key_hash % len;
            auto pe = &result.b[i];
            while (1)
            {
                e = *pe;
                if (!e)
                {
                    // Not found, create new elem
                    //printf("create new one\n");
                    //e = cast(aaA *) cast(void*) new void[aaA.sizeof + keytsize + valuesize];
                    //memcpy(e + 1, pkey, keysize);
                    e = ne;
                    e.hash = key_hash;
                    *pe = e;
                    ne = null;
                    result.nodes++;
                    break;
                }
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
                    if (c == 0)
                        break;
                    pe = (c < 0) ? &e.left : &e.right;
                }
                else
                    pe = (key_hash < e.hash) ? &e.left : &e.right;
            }
            //memcpy(cast(void *)(e + 1) + keytsize, q, valuesize);
            //q += valuestacksize;
            va_arg(q, ti.next, cast(void *)(e + 1) + keytsize);
        }
        if (ne)
            delete ne;
        va_end(q);
    }
    return result;
}


extern (C)
BB* _d_assocarrayliteralTX(TypeInfo_AssociativeArray ti, void[] keys, void[] values)
{
    auto valueti = ti.next;
    auto valuesize = valueti.tsize();           // value size
    auto keyti = ti.key;
    auto keysize = keyti.tsize();               // key size
    auto length = keys.length;
    BB* result;

    //printf("_d_assocarrayliteralT(keysize = %d, valuesize = %d, length = %d)\n", keysize, valuesize, length);
    //printf("tivalue = %.*s\n", ti.next.classinfo.name);
    assert(length == values.length);
    if (length == 0 || valuesize == 0 || keysize == 0)
    {
        ;
    }
    else
    {
        result = new BB();

        size_t i;
        for (i = 0; i < prime_list.length - 1; i++)
        {
            if (length <= prime_list[i])
                break;
        }
        auto len = prime_list[i];
        result.b = new aaA*[len];

        size_t keytsize = aligntsize(keysize);

        for (size_t j = 0; j < length; j++)
        {   auto pkey = keys.ptr + j * keysize;
            auto pvalue = values.ptr + j * valuesize;
            aaA* e;

            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            i = key_hash % len;
            auto pe = &result.b[i];
            while (1)
            {
                e = *pe;
                if (!e)
                {
                    // Not found, create new elem
                    //printf("create new one\n");
                    e = cast(aaA *) cast(void*) new void[aaA.sizeof + keytsize + valuesize];
                    memcpy(e + 1, pkey, keysize);
                    e.hash = key_hash;
                    *pe = e;
                    result.nodes++;
                    break;
                }
                if (key_hash == e.hash)
                {
                    auto c = keyti.compare(pkey, e + 1);
                    if (c == 0)
                        break;
                    pe = (c < 0) ? &e.left : &e.right;
                }
                else
                    pe = (key_hash < e.hash) ? &e.left : &e.right;
            }
            memcpy(cast(void *)(e + 1) + keytsize, pvalue, valuesize);
        }
    }
    return result;
}


/***********************************
 * Compare AA contents for equality.
 * Returns:
 *      1       equal
 *      0       not equal
 */
int _aaEqual(TypeInfo_AssociativeArray ti, AA e1, AA e2)
{
    //printf("_aaEqual()\n");
    //printf("keyti = %.*s\n", ti.key.classinfo.name);
    //printf("valueti = %.*s\n", ti.next.classinfo.name);

    if (e1.a is e2.a)
        return 1;

    size_t len = _aaLen(e1);
    if (len != _aaLen(e2))
        return 0;

    /* Algorithm: Visit each key/value pair in e1. If that key doesn't exist
     * in e2, or if the value in e1 doesn't match the one in e2, the arrays
     * are not equal, and exit early.
     * After all pairs are checked, the arrays must be equal.
     */

    auto keyti = ti.key;
    auto valueti = ti.next;
    auto keysize = aligntsize(keyti.tsize());
    auto len2 = e2.a.b.length;

    int _aaKeys_x(aaA* e)
    {
        do
        {
            auto pkey = cast(void*)(e + 1);
            auto pvalue = pkey + keysize;
            //printf("key = %d, value = %g\n", *cast(int*)pkey, *cast(double*)pvalue);

            // We have key/value for e1. See if they exist in e2

            auto key_hash = keyti.getHash(pkey);
            //printf("hash = %d\n", key_hash);
            auto i = key_hash % len2;
            auto f = e2.a.b[i];
            while (1)
            {
                //printf("f is %p\n", f);
                if (f is null)
                    return 0;                   // key not found, so AA's are not equal
                if (key_hash == f.hash)
                {
                    //printf("hash equals\n");
                    auto c = keyti.compare(pkey, f + 1);
                    if (c == 0)
                    {   // Found key in e2. Compare values
                        //printf("key equals\n");
                        auto pvalue2 = cast(void *)(f + 1) + keysize;
                        if (valueti.equals(pvalue, pvalue2))
                        {
                            //printf("value equals\n");
                            break;
                        }
                        else
                            return 0;           // values don't match, so AA's are not equal
                    }
                    f = (c < 0) ? f.left : f.right;
                }
                else
                    f = (key_hash < f.hash) ? f.left : f.right;
            }

            // Look at next entry in e1
            if (e.left)
            {   if (!e.right)
                {   e = e.left;
                    continue;
                }
                if (_aaKeys_x(e.left) == 0)
                    return 0;
            }
            e = e.right;
        } while (e !is null);
        return 1;                       // this subtree matches
    }

    foreach (e; e1.a.b)
    {
        if (e)
        {   if (_aaKeys_x(e) == 0)
                return 0;
        }
    }

    return 1;           // equal
}

