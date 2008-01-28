// Written in the D programming language.

/**
This module is a port of a growing fragment of the $(D_PARAM
algorithm) header in Alexander Stepanov's
$(LINK2 http://www.sgi.com/tech/stl/,Standard Template Library).

Macros:
WIKI = Phobos/StdAlgorithm

Author:
Andrei Alexandrescu
*/

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Andrei Alexandrescu, www.erdani.org
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

module std.algorithm;
private import std.stdio;
private import std.math;
private import std.random;
private import std.date;
private import std.functional;

/* The iterator-related part below is undocumented and might
 * change in future releases. Do NOT rely on it.
*/

template IteratorType(T : U[], U)
{
    alias U* IteratorType;
}

template ElementType(T : U[], U)
{
    alias U ElementType;
}

IteratorType!(T[]) begin(T)(T[] range)
{
    return range.ptr;
}

ElementType!(T[]) front(T)(T[] range)
{
    assert(range.length);
    return *range.ptr;
}

bool isEmpty(T)(T[] range)
{
    return !range.length;
}

IteratorType!(T[]) end(T)(T[] range)
{
    return range.ptr + range.length;
}

void next(T)(ref T[] range)
{
    range = range.ptr[1 .. range.length];;
}

IteratorType!(R) adjacentFind(R, E)(R range)
{
    if (range.isEmpty()) return range.end();
    auto result = range.begin();
    range.next();
    if (range.isEmpty()) return range.end();
    for (; !range.isEmpty(); range.next())
    {
        auto next = range.begin();
        if (*result == *next) return result;
        result = next;
    }
    return range.end();
}

IteratorType!(Range) find(Range, E)(Range haystack, E needle)
{
    ElementType!(Range) e;
    for (; !isEmpty(haystack); next(haystack))
    {
        if (front(haystack) == needle) break;
    }
    return begin(haystack);
}

unittest
{
    int[] a = ([ 1, 2, 3 ]).dup;
    assert(find(a, 5) == a.ptr + a.length);
    assert(find(a, 2) == &a[1]);
}

/**
   Swaps $(D_PARAM lhs) and $(D_PARAM rhs).
*/
void swap(T)(ref T lhs, ref T rhs)
{
    auto t = lhs;
    lhs = rhs;
    rhs = t;
}

/**
Implements C.A.R. Hoare's
$(LINK2 http://en.wikipedia.org/wiki/Selection_algorithm#Partition-based_general_selection_algorithm,
partition) algorithm. Specifically, reorders the range [$(D_PARAM
left), $(D_PARAM right)$(RPAREN) such that everything strictly smaller
(according to the predicate $(D_PARAM compare)) than $(D_PARAM *mid)
is to the left of the returned pointer, and everything else is at the
right of the returned pointer.

Precondition:

$(D_PARAM left == mid && mid == right
||
left <= mid && mid < right).

Returns:

If $(D_PARAM left == right), returns $(D_PARAM left). Otherwise,
return a value $(D_PARAM p) such that the following three conditions
are simultaneously true:
$(OL
$(LI $(D_PARAM *p == *mid))
$(LI $(D_PARAM compare(*p1, *p)) for all $(D_PARAM p1) in [$(D_PARAM
left), $(D_PARAM p)$(RPAREN))
$(LI $(D_PARAM !compare(*p2, *p)) for all $(D_PARAM p2) in [$(D_PARAM p),
$(D_PARAM right)$(RPAREN)))

Example:

----
auto a = [3, 3, 2].dup;
p = partition!(less)(a.ptr, a.ptr, a.ptr + a.length);
assert(p == a.ptr + 1 && a == [2, 3, 3]);
----
*/
template partition(alias compare)
{
    ///
    T partition(T)(T left, T mid, T right)
    {
        if (left == right) return left;
        assert(left <= mid && mid < right);
        auto pivot = *mid;
        --right;
        swap(*mid, *right);  // Move pivot to end
        auto result = left;
        for (auto i = left; i != right; ++i) {
            if (!compare(*i, pivot)) continue;
            swap(*result, *i);
            ++result;
        }
        swap(*right, *result);  // Move pivot to its final place
        assert(*result == pivot);
        return result;
    }
}

unittest
{
    int[] a = null;
    auto p = partition!(less)(a.ptr, a.ptr, a.ptr + a.length);
    assert(p is null);

    a = [2].dup;
    p = partition!(less)(a.ptr, a.ptr, a.ptr + a.length);
    assert(p == a.ptr);

    a = [2, 2].dup;
    p = partition!(less)(a.ptr, a.ptr, a.ptr + a.length);
    assert(p == a.ptr);

    p = partition!(less)(a.ptr, a.ptr + 1, a.ptr + a.length);
    assert(p == a.ptr);

    a = [3, 3, 2].dup;
    p = partition!(less)(a.ptr, a.ptr, a.ptr + a.length);
    assert(p == a.ptr + 1);
}

/**
   Reorders the range [$(D_PARAM b), $(D_PARAM e)$(RPAREN) such that
   $(D_PARAM nth) points to the element that would fall there if the
   range were fully sorted. Effectively, it finds the nth smallest
   (according to $(D_PARAM compare)) element in the range [$(D_PARAM b),
   $(D_PARAM e)$(RPAREN).
   
Example:

----
auto v = ([ 25, 7, 9, 2, 0, 5, 21 ]).dup;
auto n = 4;
nthElement!(less)(v.ptr, v.ptr + n, v.ptr + v.length);
assert(v[n] == 9);
----
*/
template nthElement(alias compare)
{
    ///
    void nthElement(T)(T b, T nth, T e)
    {
        assert(b <= nth && nth < e);
        for (;;) {
            auto pivot = b + (e - b) / 2;
            pivot = partition!(compare)(b, pivot, e);
            if (pivot == nth) return;
            if (pivot < nth) b = pivot + 1;
            else e = pivot;
        }
    }
}

unittest
{
    scope(failure) writeln(stderr, "Failure testing algorithm");
    auto v = ([ 25, 7, 9, 2, 0, 5, 21 ]).dup;
    auto n = 4;
    nthElement!(less)(v.ptr, v.ptr + n, v.ptr + v.length);
    assert(v[n] == 9);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 3;
    nthElement!(less)(v.ptr, v.ptr + n, v.ptr + v.length);
    assert(v[n] == 3);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 1;
    nthElement!(less)(v.ptr, v.ptr + n, v.ptr + v.length);
    assert(v[n] == 2);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = v.length - 1;
    nthElement!(less)(v.ptr, v.ptr + n, v.ptr + v.length);
    assert(v[n] == 7);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 0;
    nthElement!(less)(v.ptr, v.ptr + n, v.ptr + v.length);
    assert(v[n] == 1);
}

/**
  Reverses $(D_PARAM range) in-place.
*/
void reverse(T)(T range)
{
    auto len = range.length;
    const limit = len / 2;
    --len;
    for (uint i = 0; i != limit; ++i)
    {
        auto t = range[i];
        range[i] = range[len - i];
        range[len - i] = t;
    }
}

unittest
{
    int[] range = null;
    reverse(range);
    range = [ 1 ].dup;
    reverse(range);
    assert(range == [1]);
    range = [1, 2].dup;
    reverse(range);
    assert(range == [2, 1]);
    range = [1, 2, 3].dup;
    reverse(range);
    assert(range == [3, 2, 1]);
}

/**
Sorts a random-access range according to predicate $(D_PARAM comp),
which must be a function name.

Example:

----
int[] array = ([ 1, 2, 3, 4 ]).dup;
sort!(greater)(array);
assert(array == [ 4, 3, 2, 1 ]);
bool myComp(int x, int y) { return x < y; }
sort!(myComp)(array);
assert(array == [ 1, 2, 3, 4 ]);
----
*/

template sort(alias comp)
{
    void sort(Range)(Range r)
    {
        static if (is(typeof(comp(*begin(r), *end(r))) == bool))
        {
            sortImpl!(comp)(begin(r), end(r));
            assert(isSorted!(comp)(r));
        }
        else
        {
            static assert(false, typeof(&comp).stringof);
        }
    }
}

/**
   Sorts a random-access range according to predicate $(D_PARAM comp),
   expressed as a string. The string can use the names "a" and "b" for
   the two elements being compared.

   Example:

----
int[] array = ([ 1, 2, 3, 4 ]).dup;
sort!("a > b")(array);
assert(array == [ 4, 3, 2, 1 ]);
----
*/

template sort(string comp)
{
    void sort(Range)(Range r)
    {
        alias typeof(*begin(r)) ElementType;
        static ElementType a, b;
        alias typeof(mixin(comp)) ResultType;
        static ResultType compFn(ElementType a, ElementType b)
        {
            return mixin(comp);
        }
        .sort!(compFn)(r);
    }
}

unittest
{
    // sort using delegate
    int a[] = new int[100];
    auto rnd = Random(getUTCtime);
    foreach (ref e; a) {
        e = uniform!(int)(rnd, -100, 100);
    }
    
    int i = 0;
    bool greater2(int a, int b) { return a + i > b + i; }
    bool delegate(int, int) greater = &greater2;
    sort!(greater)(a);
    assert(isSorted!(greater)(a));

    // sort using string
    sort!("a < b")(a);
    assert(isSorted!(less)(a));

    // sort using function; all elements equal
    foreach (ref e; a) {
        e = 5;
    }
    sort!(less)(a);
    assert(isSorted!(less)(a));

    // sort using ternary predicate
    //sort!("b - a")(a);
    //assert(isSorted!(less)(a));
}

/*private*/ template getPivot(alias compare)
{
    Iter getPivot(Iter)(Iter b, Iter e)
    {
        auto r = b + (e - b) / 2;
        return r;
    }
}

/*private*/ template sortImpl(alias comp)
{
    void sortImpl(Iter)(Iter b, Iter e)
    {
        while (e - b > 1)
        {
            auto m = partition!(comp)(b, getPivot!(comp)(b, e), e);
            assert(b <= m && m < e);
            .sortImpl!(comp)(b, m);
            b = ++m;
        }
    }
}

/**
   Checks whether a random-access range is sorted according to the
   comparison operation $(D_PARAM comp).

   Example:

----
int[] arr = ([4, 3, 2, 1]).dup;
assert(!isSorted!(less)(arr));
sort!(less)(arr);
assert(isSorted!(less)(arr));
----
*/

template isSorted(alias comp)
{
    bool isSorted(Range)(Range r)
    {
        auto b = begin(r), e = end(r);
        if (e - b <= 1) return true;
        auto next = b + 1;
        for (; next < e; ++b, ++next) {
            if (comp(*next, *b)) return false;
        }
        return true;
    }
}

