/**
This module provides a $(D BinaryHeap) adaptor that makes a binary heap out of
any user-provided random-access range.

This module is a submodule of $(LINK2 std_container_package.html, std.container).

Source: $(PHOBOSSRC std/container/_binaryheap.d)
Macros:
WIKI = Phobos/StdContainer
TEXTWITHCOMMAS = $0

Copyright: Red-black tree code copyright (C) 2008- by Steven Schveighoffer. Other code
copyright 2010- Andrei Alexandrescu. All rights reserved by the respective holders.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Steven Schveighoffer, $(WEB erdani.com, Andrei Alexandrescu)
*/
module std.container.binaryheap;

import std.range.primitives;
import std.traits;

public import std.container.util;

// BinaryHeap
/**
Implements a $(WEB en.wikipedia.org/wiki/Binary_heap, binary heap)
container on top of a given random-access range type (usually $(D
T[])) or a random-access container type (usually $(D Array!T)). The
documentation of $(D BinaryHeap) will refer to the underlying range or
container as the $(I store) of the heap.

The binary heap induces structure over the underlying store such that
accessing the largest element (by using the $(D front) property) is a
$(BIGOH 1) operation and extracting it (by using the $(D
removeFront()) method) is done fast in $(BIGOH log n) time.

If $(D less) is the less-than operator, which is the default option,
then $(D BinaryHeap) defines a so-called max-heap that optimizes
extraction of the $(I largest) elements. To define a min-heap,
instantiate BinaryHeap with $(D "a > b") as its predicate.

Simply extracting elements from a $(D BinaryHeap) container is
tantamount to lazily fetching elements of $(D Store) in descending
order. Extracting elements from the $(D BinaryHeap) to completion
leaves the underlying store sorted in ascending order but, again,
yields elements in descending order.

If $(D Store) is a range, the $(D BinaryHeap) cannot grow beyond the
size of that range. If $(D Store) is a container that supports $(D
insertBack), the $(D BinaryHeap) may grow by adding elements to the
container.
     */
struct BinaryHeap(Store, alias less = "a < b")
if (isRandomAccessRange!(Store) || isRandomAccessRange!(typeof(Store.init[])))
{
    import std.functional : binaryFun;
    import std.exception : enforce;
    import std.algorithm : move, min;
    import std.typecons : RefCounted, RefCountedAutoInitialize;

// Really weird @@BUG@@: if you comment out the "private:" label below,
// std.algorithm can't unittest anymore
//private:

    // The payload includes the support store and the effective length
    private static struct Data
    {
        Store _store;
        size_t _length;
    }
    private RefCounted!(Data, RefCountedAutoInitialize.no) _payload;
    // Comparison predicate
    private alias comp = binaryFun!(less);
    // Convenience accessors
    private @property ref Store _store()
    {
        assert(_payload.refCountedStore.isInitialized);
        return _payload._store;
    }
    private @property ref size_t _length()
    {
        assert(_payload.refCountedStore.isInitialized);
        return _payload._length;
    }

    // Asserts that the heap property is respected.
    private void assertValid()
    {
        debug
        {
            import std.conv : to;
            if (!_payload.refCountedStore.isInitialized) return;
            if (_length < 2) return;
            for (size_t n = _length - 1; n >= 1; --n)
            {
                auto parentIdx = (n - 1) / 2;
                assert(!comp(_store[parentIdx], _store[n]), to!string(n));
            }
        }
    }

    // Assuming the element at index i perturbs the heap property in
    // store r, percolates it down the heap such that the heap
    // property is restored.
    private void percolateDown(Store r, size_t i, size_t length)
    {
        for (;;)
        {
            auto left = i * 2 + 1, right = left + 1;
            if (right == length)
            {
                if (comp(r[i], r[left])) swap(r, i, left);
                return;
            }
            if (right > length) return;
            assert(left < length && right < length);
            auto largest = comp(r[i], r[left])
                ? (comp(r[left], r[right]) ? right : left)
                : (comp(r[i], r[right]) ? right : i);
            if (largest == i) return;
            swap(r, i, largest);
            i = largest;
        }
    }

    // @@@BUG@@@: add private here, std.algorithm doesn't unittest anymore
    /*private*/ void pop(Store store)
    {
        assert(!store.empty, "Cannot pop an empty store.");
        if (store.length == 1) return;
        auto t1 = moveFront(store[]);
        auto t2 = moveBack(store[]);
        store.front = move(t2);
        store.back = move(t1);
        percolateDown(store, 0, store.length - 1);
    }

    /*private*/ static void swap(Store _store, size_t i, size_t j)
    {
        static if (is(typeof(swap(_store[i], _store[j]))))
        {
            swap(_store[i], _store[j]);
        }
        else static if (is(typeof(_store.moveAt(i))))
        {
            auto t1 = _store.moveAt(i);
            auto t2 = _store.moveAt(j);
            _store[i] = move(t2);
            _store[j] = move(t1);
        }
        else // assume it's a container and access its range with []
        {
            auto t1 = _store[].moveAt(i);
            auto t2 = _store[].moveAt(j);
            _store[i] = move(t2);
            _store[j] = move(t1);
        }
    }

public:

    /**
       Converts the store $(D s) into a heap. If $(D initialSize) is
       specified, only the first $(D initialSize) elements in $(D s)
       are transformed into a heap, after which the heap can grow up
       to $(D r.length) (if $(D Store) is a range) or indefinitely (if
       $(D Store) is a container with $(D insertBack)). Performs
       $(BIGOH min(r.length, initialSize)) evaluations of $(D less).
     */
    this(Store s, size_t initialSize = size_t.max)
    {
        acquire(s, initialSize);
    }

/**
Takes ownership of a store. After this, manipulating $(D s) may make
the heap work incorrectly.
     */
    void acquire(Store s, size_t initialSize = size_t.max)
    {
        _payload.refCountedStore.ensureInitialized();
        _store = move(s);
        _length = min(_store.length, initialSize);
        if (_length < 2) return;
        for (auto i = (_length - 2) / 2; ; )
        {
            this.percolateDown(_store, i, _length);
            if (i-- == 0) break;
        }
        assertValid();
    }

/**
Takes ownership of a store assuming it already was organized as a
heap.
     */
    void assume(Store s, size_t initialSize = size_t.max)
    {
        _payload.refCountedStore.ensureInitialized();
        _store = s;
        _length = min(_store.length, initialSize);
        assertValid();
    }

/**
Clears the heap. Returns the portion of the store from $(D 0) up to
$(D length), which satisfies the $(LUCKY heap property).
     */
    auto release()
    {
        if (!_payload.refCountedStore.isInitialized)
        {
            return typeof(_store[0 .. _length]).init;
        }
        assertValid();
        auto result = _store[0 .. _length];
        _payload = _payload.init;
        return result;
    }

/**
Returns $(D true) if the heap is _empty, $(D false) otherwise.
     */
    @property bool empty()
    {
        return !length;
    }

/**
Returns a duplicate of the heap. The underlying store must also
support a $(D dup) method.
     */
    @property BinaryHeap dup()
    {
        BinaryHeap result;
        if (!_payload.refCountedStore.isInitialized) return result;
        result.assume(_store.dup, length);
        return result;
    }

/**
Returns the _length of the heap.
     */
    @property size_t length()
    {
        return _payload.refCountedStore.isInitialized ? _length : 0;
    }

/**
Returns the _capacity of the heap, which is the length of the
underlying store (if the store is a range) or the _capacity of the
underlying store (if the store is a container).
     */
    @property size_t capacity()
    {
        if (!_payload.refCountedStore.isInitialized) return 0;
        static if (is(typeof(_store.capacity) : size_t))
        {
            return _store.capacity;
        }
        else
        {
            return _store.length;
        }
    }

/**
Returns a copy of the _front of the heap, which is the largest element
according to $(D less).
     */
    @property ElementType!Store front()
    {
        enforce(!empty, "Cannot call front on an empty heap.");
        return _store.front;
    }

/**
Clears the heap by detaching it from the underlying store.
     */
    void clear()
    {
        _payload = _payload.init;
    }

/**
Inserts $(D value) into the store. If the underlying store is a range
and $(D length == capacity), throws an exception.
     */
    size_t insert(ElementType!Store value)
    {
        static if (is(typeof(_store.insertBack(value))))
        {
            _payload.refCountedStore.ensureInitialized();
            if (length == _store.length)
            {
                // reallocate
                _store.insertBack(value);
            }
            else
            {
                // no reallocation
                _store[_length] = value;
            }
        }
        else
        {
            // can't grow
            enforce(length < _store.length,
                    "Cannot grow a heap created over a range");
            _store[_length] = value;
        }

        // sink down the element
        for (size_t n = _length; n; )
        {
            auto parentIdx = (n - 1) / 2;
            if (!comp(_store[parentIdx], _store[n])) break; // done!
            // must swap and continue
            swap(_store, parentIdx, n);
            n = parentIdx;
        }
        ++_length;
        debug(BinaryHeap) assertValid();
        return 1;
    }

/**
Removes the largest element from the heap.
     */
    void removeFront()
    {
        enforce(!empty, "Cannot call removeFront on an empty heap.");
        if (_length > 1)
        {
            auto t1 = moveFront(_store[]);
            auto t2 = moveAt(_store[], _length - 1);
            _store.front = move(t2);
            _store[_length - 1] = move(t1);
        }
        --_length;
        percolateDown(_store, 0, _length);
    }

    /// ditto
    alias popFront = removeFront;

/**
Removes the largest element from the heap and returns a copy of
it. The element still resides in the heap's store. For performance
reasons you may want to use $(D removeFront) with heaps of objects
that are expensive to copy.
     */
    ElementType!Store removeAny()
    {
        removeFront();
        return _store[_length];
    }

/**
Replaces the largest element in the store with $(D value).
     */
    void replaceFront(ElementType!Store value)
    {
        // must replace the top
        assert(!empty, "Cannot call replaceFront on an empty heap.");
        _store.front = value;
        percolateDown(_store, 0, _length);
        debug(BinaryHeap) assertValid();
    }

/**
If the heap has room to grow, inserts $(D value) into the store and
returns $(D true). Otherwise, if $(D less(value, front)), calls $(D
replaceFront(value)) and returns again $(D true). Otherwise, leaves
the heap unaffected and returns $(D false). This method is useful in
scenarios where the smallest $(D k) elements of a set of candidates
must be collected.
     */
    bool conditionalInsert(ElementType!Store value)
    {
        _payload.refCountedStore.ensureInitialized();
        if (_length < _store.length)
        {
            insert(value);
            return true;
        }
        // must replace the top
        assert(!_store.empty, "Cannot replace front of an empty heap.");
        if (!comp(value, _store.front)) return false; // value >= largest
        _store.front = value;
        percolateDown(_store, 0, _length);
        debug(BinaryHeap) assertValid();
        return true;
    }
}

/// Example from "Introduction to Algorithms" Cormen et al, p 146
unittest
{
    import std.algorithm : equal;
    int[] a = [ 4, 1, 3, 2, 16, 9, 10, 14, 8, 7 ];
    auto h = heapify(a);
    // largest element
    assert(h.front == 16);
    // a has the heap property
    assert(equal(a, [ 16, 14, 10, 8, 7, 9, 3, 2, 4, 1 ]));
}

/// $(D BinaryHeap) implements the standard input range interface, allowing
/// lazy iteration of the underlying range in descending order.
unittest
{
    import std.algorithm : equal;
    import std.range : take;
    int[] a = [4, 1, 3, 2, 16, 9, 10, 14, 8, 7];
    auto top5 = heapify(a).take(5);
    assert(top5.equal([16, 14, 10, 9, 8]));
}

/**
Convenience function that returns a $(D BinaryHeap!Store) object
initialized with $(D s) and $(D initialSize).
 */
BinaryHeap!(Store, less) heapify(alias less = "a < b", Store)(Store s,
        size_t initialSize = size_t.max)
{
    return BinaryHeap!(Store, less)(s, initialSize);
}

unittest
{
    import std.conv : to;
    {
        // example from "Introduction to Algorithms" Cormen et al., p 146
        int[] a = [ 4, 1, 3, 2, 16, 9, 10, 14, 8, 7 ];
        auto h = heapify(a);
        h = heapify!"a < b"(a);
        assert(h.front == 16);
        assert(a == [ 16, 14, 10, 8, 7, 9, 3, 2, 4, 1 ]);
        auto witness = [ 16, 14, 10, 9, 8, 7, 4, 3, 2, 1 ];
        for (; !h.empty; h.removeFront(), witness.popFront())
        {
            assert(!witness.empty);
            assert(witness.front == h.front);
        }
        assert(witness.empty);
    }
    {
        int[] a = [ 4, 1, 3, 2, 16, 9, 10, 14, 8, 7 ];
        int[] b = new int[a.length];
        BinaryHeap!(int[]) h = BinaryHeap!(int[])(b, 0);
        foreach (e; a)
        {
            h.insert(e);
        }
        assert(b == [ 16, 14, 10, 8, 7, 3, 9, 1, 4, 2 ], to!string(b));
    }
}

unittest
{
    // Test range interface.
    import std.algorithm : equal;
    int[] a = [4, 1, 3, 2, 16, 9, 10, 14, 8, 7];
    auto h = heapify(a);
    static assert(isInputRange!(typeof(h)));
    assert(h.equal([16, 14, 10, 9, 8, 7, 4, 3, 2, 1]));
}
