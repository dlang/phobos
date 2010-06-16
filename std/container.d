// Written in the D programming language.

/**
Defines generic _containers.

Macros:
WIKI = Phobos/StdContainer

Copyright: Copyright 2010- Andrei Alexandrescu.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

 */
module std.container;

import core.stdc.stdlib, core.stdc.string, std.algorithm, std.contracts,
    std.conv, std.functional, std.range, std.traits, std.typecons,
    core.memory;
version(unittest) import std.stdio;

/**
$(D TotalContainer) is an unimplemented container that illustrates a
host of primitives that a container may define. It is to some extent
the bottom of the conceptual container hierarchy. A given container
most often will choose to only implement a subset of these primitives,
and define its own additional ones. Adhering to the standard primitive
names below allows generic code to work independently of containers.

Things to remember: any container must be a reference type, whether
implemented as a $(D class) or $(D struct). No primitive below
requires the container to escape addresses of elements, which means
that compliant containers can be defined to use reference counting or
other deterministic memory management techniques.

A container may choose to define additional specific operations. The
only requirement is that those operations bear different names than
the ones below, lest user code gets confused.

Complexity of operations should be interpreted as "at least as good
as". If an operation is required to have $(BIGOH n) complexity, it
could have anything lower than that, e.g. $(BIGOH log(n)). Unless
specified otherwise, $(D n) inside a $(BIGOH) expression stands for
the number of elements in the container.
 */
struct TotalContainer(Whatever)
{
/**
If the container has a notion of key-value mapping, $(D KeyType)
defines the type of the key of the container.
 */
    alias SomeType KeyType;

/**
If the container has a notion of multikey-value mapping, $(D
KeyTypes[k]), where $(D k) is a zero-based unsigned number, defines
the type of the $(D k)th key of the container.

A container may define both $(D KeyType) and $(D KeyTypes), e.g. in
the case it has the notion of primary/preferred key.
 */
    alias TypeTuple!(Key1, Key2) KeyTypes;

/**
If the container has a notion of key-value mapping, $(D ValueType)
defines the type of the value of the container. Typically, a map-style
container mapping values of type $(D K) to values of type $(D V)
defines $(D KeyType) to be $(D K), $(D ValueType) to be $(D V), and
$(D ElementType) to be $(D Tuple!(K, V)).
 */
    alias SomeType ValueType;

/**
Defines the container's primary range, which embodies one of the
archetypal ranges defined in $(XREFMODULE range).

Generally a container may define several types of ranges.
 */
    alias SomeType Range;

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
 */
    @property bool empty();

/**
Returns a duplicate of the container. The elements themselves are not
transitively duplicated.

Complexity: $(BIGOH n).
 */
    @property TotalContainer dup();

/**
Returns the number of elements in the container.

Complexity: $(BIGOH log(n)).
 */
    @property size_t length();

/**
Returns the maximum number of elements the container can store without
(a) allocating memory, (b) invalidating iterators upon insertion.

Complexity: $(BIGOH log(n)).
 */
    @property size_t capacity();

/**
Ensures sufficient capacity to accommodate $(D n) elements.

Postcondition: $(D capacity >= n)

Complexity: $(BIGOH log(e - capacity)) if $(D e > capacity), otherwise
$(BIGOH 1).
 */
    void reserve(size_t e);

/**
Returns a range that iterates over all elements of the container, in a
container-defined order. The container should choose the most
convenient and fast method of iteration for $(D opSlice()).

Complexity: $(BIGOH log(n))
 */
    Range opSlice();

/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Complexity: $(BIGOH log(n))
 */
    @property ElementType front();
    /// ditto
    @property ElementType back();

/**
Indexing operators yield or modify the value at a specified index.
 */
    ValueType opIndex(KeyType);
    /// ditto
    void opIndexAssign(KeyType);
    /// ditto
    void opIndexOpAssign(string op)(KeyType);

/**
$(D k in container) returns true if the given key is in the container.
 */
    bool opBinary(string op)(KeyType k) if (op == "in");

/**
Returns a range of all elements containing $(D k) (could be empty or a
singleton range).
 */
    Range equalRange(KeyType k);

/**
Returns a range of all elements with keys less than $(D k) (could be
empty or a singleton range). Only defined by containers that store
data sorted at all times.
 */
    Range lowerBound(KeyType k);

/**
Returns a range of all elements with keys larger than $(D k) (could be
empty or a singleton range).  Only defined by containers that store
data sorted at all times.
 */
    Range upperBound(KeyType k);

/**
Returns a new container that's the concatenation of $(D this) and its
argument. $(D opBinaryRight) is only defined if $(D Stuff) does not
define $(D opBinary).

Complexity: $(BIGOH n + m), where m is the number of elements in $(D
stuff)
 */
    TotalContainer opBinary(string op)(Stuff rhs) if (op == "~");

    /// ditto
    TotalContainer opBinaryRight(string op)(Stuff lhs) if (op == "~");

/**
Forwards to $(D insertAfter(this[], stuff)).
 */
    void opOpAssign(string op)(Stuff stuff) if (op == "~");

/**
Removes all contents from the container. The container decides how $(D
capacity) is affected.

Postcondition: $(D empty)

Complexity: $(BIGOH n)
 */
    void clear();

/**
Sets the number of elements in the container to $(D newSize). If $(D
newSize) is greater than $(D length), the added elements are added to
unspecified positions in the container and initialized with $(D
ElementType.init).

Complexity: $(BIGOH abs(n - newLength))

Postcondition: $(D length == newLength)
 */
    @property void length(size_t newLength);

/**
Inserts $(D stuff) in an unspecified position in the
container. Implementations should choose whichever insertion means is
the most advantageous for the container, but document the exact
behavior. $(D stuff) can be a value convertible to $(D ElementType) or
a range of objects convertible to $(D ElementType).

The $(D stable) version guarantees that ranges iterating over the
container are never invalidated. Client code that counts on
non-invalidating insertion should use $(D stableInsert). Such code would
not compile against containers that don't support it.

Returns: The number of elements added.

Complexity: $(BIGOH m * log(n)), where m is the number of elements in
$(D stuff)
 */
    size_t insert(Stuff stuff);
    ///ditto
    size_t stableInsert(Stuff stuff);

/**
Picks one value in an unspecified position in the container, removes
it from the container, and returns it. Implementations should pick the
value that's the most advantageous for the container, but document the
exact behavior. The stable version behaves the same, but guarantees that
ranges iterating over the container are never invalidated.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH log(n)).
 */
    ElementType removeAny();
    /// ditto
    ElementType stableRemoveAny();

/**
Inserts $(D value) to the front or back of the container. $(D stuff)
can be a value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH log(n)).
 */
    size_t insertFront(Stuff stuff);
    /// ditto
    size_t stableInsertFront(Stuff stuff);
    /// ditto
    size_t insertBack(Stuff stuff);
    /// ditto
    size_t stableInsertBack(T value);

/**
Removes the value at the front or back of the container. The stable
version behaves the same, but guarantees that ranges iterating over
the container are never invalidated. The optional parameter $(D
howMany) instructs removal of that many elements. If $(D howMany > n),
all elements are removed and no exception is thrown.

Precondition: $(D !empty)

Complexity: $(BIGOH log(n)).
 */
    void removeFront();
    /// ditto
    void stableRemoveFront();
    /// ditto
    void removeBack();
    /// ditto
    void stableRemoveBack();

/**
Removes $(D howMany) values at the front or back of the
container. Unlike the unparameterized versions above, these functions
do not throw if they could not remove $(D howMany) elements. Instead,
if $(D howMany > n), all elements are removed. The returned value is
the effective number of elements removed. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: The number of elements removed

Complexity: $(BIGOH howMany * log(n)).
 */
    size_t removeFront(size_t howMany);
    /// ditto
    size_t stableRemoveFront(size_t howMany);
    /// ditto
    size_t removeBack(size_t howMany);
    /// ditto
    size_t stableRemoveBack(size_t howMany);

/**
Removes all values corresponding to key $(D k).

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements with the same key.

Returns: The number of elements removed.
 */
    size_t removeKey(KeyType k);

/**
Inserts $(D stuff) before, after, or instead range $(D r), which must
be a valid range previously extracted from this container. $(D stuff)
can be a value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of values inserted.

Complexity: $(BIGOH n + m), where $(D m) is the length of $(D stuff)
 */
    size_t insertBefore(Range r, Stuff stuff);
    /// ditto
    size_t stableInsertBefore(Range r, Stuff stuff);
    /// ditto
    size_t insertAfter(Range r, Stuff stuff);
    /// ditto
    size_t stableInsertAfter(Range r, Stuff stuff);
    /// ditto
    size_t replace(Range r, Stuff stuff);
    /// ditto
    size_t stableReplace(Range r, Stuff stuff);

/**
Removes all elements belonging to $(D r), which must be a range
obtained originally from this container. The stable version behaves the
same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: A range spanning the remaining elements in the container that
initially were right after $(D r).

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements in $(D r)
 */
    Range remove(Range r);
    /// ditto
    Range stableRemove(Range r);

/**
Same as $(D remove) above, but has complexity relaxed to linear.

Returns: A range spanning the remaining elements in the container that
initially were right after $(D r).

Complexity: $(BIGOH n)
 */
    Range linearRemove(Range r);
    /// ditto
    Range stableLinearRemove(Range r);
}

/**
Returns an initialized container. This function is mainly for
eliminating construction differences between $(D class) containers and
$(D struct) containers.
 */
Container make(Container, T...)(T arguments) if (is(Container == struct))
{
    static if (T.length == 0)
        static assert(false, "You must pass at least one argument");
    else
        return Container(arguments);
}

/// ditto
Container make(Container, T...)(T arguments) if (is(Container == class))
{
    return new Container(arguments);
}

/**
Implements a simple and fast singly-linked list.
 */
struct SList(T)
{
    private struct Node
    {
        T _payload;
        Node * _next;
        this(T a, Node* b) { _payload = a; _next = b; }
    }
    private Node * _root;

    private static Node * findLastNode(Node * n)
    {
        assert(n);
        auto ahead = n._next;
        while (ahead)
        {
            n = ahead;
            ahead = n._next;
        }
        return n;
    }

    private static Node * findLastNode(Node * n, size_t limit)
    {
        assert(n && limit);
        auto ahead = n._next;
        while (ahead)
        {
            if (!--limit) break;
            n = ahead;
            ahead = n._next;
        }
        return n;
    }

    private static Node * findNode(Node * n, Node * findMe)
    {
        assert(n);
        auto ahead = n._next;
        while (ahead != findMe)
        {
            n = ahead;
            enforce(n);
            ahead = n._next;
        }
        return n;
    }

/**
Constructor taking a number of nodes
 */
    this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
    {
        insertFront(values);
    }

/**
Constructor taking an input range
 */
    this(Stuff)(Stuff stuff)
    if (isInputRange!Stuff
            && isImplicitlyConvertible!(ElementType!Stuff, T)
            && !is(Stuff == T[]))
    {
        insertFront(stuff);
    }

/**
Comparison for equality.

Complexity: $(BIGOH min(n, n1)) where $(D n1) is the number of
elements in $(D rhs).
 */
    bool opEquals(ref const SList rhs) const
    {
        const(Node) * n1 = _root, n2 = rhs._root;

        for (;; n1 = n1._next, n2 = n2._next)
        {
            if (!n1) return !n2;
            if (!n2 || n1._payload != n2._payload) return false;
        }
    }

/**
Defines the container's primary range, which embodies a forward range.
 */
    struct Range
    {
        private Node * _head;
        private this(Node * p) { _head = p; }
        /// Forward range primitives.
        bool empty() const { return !_head; }
        /// ditto
        @property T front() { return _head._payload; }
        /// ditto
        @property void front(T value)
        {
            enforce(_head);
            _head._payload = value;
        }
        /// ditto
        void popFront()
        {
            enforce(_head);
            _head = _head._next;
        }

        T moveFront()
        {
            enforce(_head);
            return move(_head._payload);
        }
    }

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
 */
    @property bool empty() const
    {
        return _root is null;
    }

/**
Duplicates the container. The elements themselves are not transitively
duplicated.

Complexity: $(BIGOH n).
 */
    @property SList dup()
    {
        return SList(this[]);
    }

/**
Returns a range that iterates over all elements of the container, in
forward order.

Complexity: $(BIGOH 1)
 */
    Range opSlice()
    {
        return Range(_root);
    }

/**
Forward to $(D opSlice().front).

Complexity: $(BIGOH 1)
 */
    @property T front()
    {
        enforce(_root);
        return _root._payload;
    }

/**
Forward to $(D opSlice().front(value)).

Complexity: $(BIGOH 1)
 */
    @property void front(T value)
    {
        enforce(_root);
        _root._payload = value;
    }

    unittest
    {
        auto s = SList!int(1, 2, 3);
        s.front = 42;
        assert(s == SList!int(42, 2, 3));
    }

/**
Returns a new $(D SList) that's the concatenation of $(D this) and its
argument. $(D opBinaryRight) is only defined if $(D Stuff) does not
define $(D opBinary).
 */
    SList opBinary(string op, Stuff)(Stuff rhs)
    if (op == "~" && is(typeof(SList(rhs))))
    {
        auto toAdd = SList(rhs);
        static if (is(Stuff == SList))
        {
            toAdd = toAdd.dup;
        }
        if (empty) return toAdd;
        // TODO: optimize
        auto result = dup;
        auto n = findLastNode(result._root);
        n._next = toAdd._root;
        return result;
    }

/**
Removes all contents from the $(D SList).

Postcondition: $(D empty)

Complexity: $(BIGOH 1)
 */
    void clear()
    {
        _root = null;
    }

/**
Inserts $(D stuff) to the front of the container. $(D stuff) can be a
value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH log(n))
 */
    size_t insertFront(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        size_t result;
        Node * n, newRoot;
        foreach (item; stuff)
        {
            auto newNode = new Node(item, null);
            (newRoot ? n._next : newRoot) = newNode;
            n = newNode;
            ++result;
        }
        if (!n) return 0;
        // Last node points to the old root
        n._next = _root;
        _root = newRoot;
        return result;
    }

    /// ditto
    size_t insertFront(Stuff)(Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        auto newRoot = new Node(stuff, _root);
        _root = newRoot;
        return 1;
    }

/// ditto
    alias insertFront insert;

/// ditto
    alias insert stableInsert;

    /// ditto
    alias insertFront stableInsertFront;

/**
Picks one value from the front of the container, removes it from the
container, and returns it.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH 1).
 */
    T removeAny()
    {
        enforce(!empty);
        auto result = move(_root._payload);
        _root = _root._next;
        return result;
    }
    /// ditto
    alias removeAny stableRemoveAny;

/**
Removes the value at the front of the container. The stable version
behaves the same, but guarantees that ranges iterating over the
container are never invalidated.

Precondition: $(D !empty)

Complexity: $(BIGOH 1).
 */
    void removeFront()
    {
        enforce(_root);
        _root = _root._next;
    }

    /// ditto
    alias removeFront stableRemoveFront;

/**
Removes $(D howMany) values at the front or back of the
container. Unlike the unparameterized versions above, these functions
do not throw if they could not remove $(D howMany) elements. Instead,
if $(D howMany > n), all elements are removed. The returned value is
the effective number of elements removed. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: The number of elements removed

Complexity: $(BIGOH howMany * log(n)).
 */
    size_t removeFront(size_t howMany)
    {
        size_t result;
        while (_root && result < howMany)
        {
            _root = _root._next;
            ++result;
        }
        return result;
    }

    /// ditto
    alias removeFront stableRemoveFront;

/**
Inserts $(D stuff) after range $(D r), which must be a range
previously extracted from this container. Given that all ranges for a
list end at the end of the list, this function essentially appends to
the list and uses $(D r) as a potentially fast way to reach the last
node in the list. (Ideally $(D r) is positioned near or at the last
element of the list.)

$(D stuff) can be a value convertible to $(D ElementType) or a range
of objects convertible to $(D ElementType). The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: The number of values inserted.

Complexity: $(BIGOH k + m), where $(D k) is the number of elements in
$(D r) and $(D m) is the length of $(D stuff).
 */

    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        if (!_root)
        {
            enforce(!r._head);
            return insertFront(stuff);
        }
        enforce(r._head);
        auto n = findLastNode(_root);
        SList tmp;
        auto result = tmp.insertFront(stuff);
        n._next = tmp._root;
        return result;
    }

/**
Similar to $(D insertAfter) above, but accepts a range bounded in
count. This is important for ensuring fast insertions in the middle of
the list.  For fast insertions after a specified position $(D r), use
$(D insertAfter(take(r, 1), stuff)). The complexity of that operation
only depends on the number of elements in $(D stuff).

Precondition: $(D r.original.empty || r.maxLength > 0)

Returns: The number of values inserted.

Complexity: $(BIGOH k + m), where $(D k) is the number of elements in
$(D r) and $(D m) is the length of $(D stuff).
 */
    size_t insertAfter(Stuff)(Take!Range r, Stuff stuff)
    {
        auto orig = r.original;
        if (!orig._head)
        {
            // Inserting after a null range counts as insertion to the
            // front
            return insertFront(stuff);
        }
        enforce(!r.empty);
        // Find the last valid element in the range
        foreach (i; 1 .. r.maxLength)
        {
            if (!orig._head._next) break;
            orig.popFront();
        }
        // insert here
        SList tmp;
        tmp._root = orig._head._next;
        auto result = tmp.insertFront(stuff);
        orig._head._next = tmp._root;
        return result;
    }

/// ditto
    alias insertAfter stableInsertAfter;

/**
Removes a range from the list in linear time.

Returns: An empty range.

Complexity: $(BIGOH n)
 */
    Range linearRemove(Range r)
    {
        if (!_root)
        {
            enforce(!r._head);
            return this[];
        }
        auto n = findNode(_root, r._head);
        n._next = null;
        return Range(null);
    }

/**
Removes a $(D Take!Range) from the list in linear time.

Returns: A range comprehending the elements after the removed range.

Complexity: $(BIGOH n)
 */
    Range linearRemove(Take!Range r)
    {
        auto orig = r.original;
        // We have something to remove here
        if (orig._head == _root)
        {
            // remove straight from the head of the list
            for (; !orig.empty; orig.popFront())
            {
                removeFront();
            }
            return this[];
        }
        if (!r.maxLength)
        {
            // Nothing to remove, return the range itself
            return orig;
        }
        // Remove from somewhere in the middle of the list
        enforce(_root);
        auto n1 = findNode(_root, orig._head);
        auto n2 = findLastNode(orig._head, r.maxLength);
        n1._next = n2._next;
        return Range(n1._next);
    }

/// ditto
    alias linearRemove stableLinearRemove;
}

unittest
{
    auto s = make!(SList!int)(1, 2, 3);
    auto n = s.findLastNode(s._root);
    assert(n && n._payload == 3);
}

unittest
{
    auto s = SList!int(1, 2, 5, 10);
    assert(walkLength(s[]) == 4);
}

unittest
{
    auto src = take([0, 1, 2, 3], 3);
    auto s = SList!int(src);
    assert(s == SList!int(0, 1, 2));
}

unittest
{
    auto a = SList!int(1, 2, 3);
    auto b = SList!int(4, 5, 6);
    // @@@BUG@@@ in compiler
    //auto c = a ~ b;
    auto d = [ 4, 5, 6 ];
    auto e = a ~ d;
    assert(e == SList!int(1, 2, 3, 4, 5, 6));
}

unittest
{
    auto a = SList!int(1, 2, 3);
    auto c = a ~ 4;
    assert(c == SList!int(1, 2, 3, 4));
}

unittest
{
    auto s = SList!int(1, 2, 3, 4);
    s.insertFront([ 42, 43 ]);
    assert(s == SList!int(42, 43, 1, 2, 3, 4));
}

unittest
{
    auto s = SList!int(1, 2, 3);
    assert(s.removeAny() == 1);
    assert(s == SList!int(2, 3));
    assert(s.stableRemoveAny() == 2);
    assert(s == SList!int(3));
}

unittest
{
    auto s = SList!int(1, 2, 3);
    s.removeFront();
    assert(equal(s[], [2, 3]));
    s.stableRemoveFront();
    assert(equal(s[], [3]));
}

unittest
{
    auto s = SList!int(1, 2, 3, 4, 5, 6, 7);
    assert(s.removeFront(3) == 3);
    assert(s == SList!int(4, 5, 6, 7));
}

unittest
{
    auto a = SList!int(1, 2, 3);
    auto b = SList!int(1, 2, 3);
    assert(a.insertAfter(a[], b[]) == 3);
}

unittest
{
    auto s = SList!int(1, 2, 3, 4);
    auto r = take(s[], 2);
    assert(s.insertAfter(r, 5) == 1);
    assert(s == SList!int(1, 2, 5, 3, 4));
}

unittest
{
    auto s = SList!int(1, 2, 3, 4, 5);
    auto r = s[];
    popFrontN(r, 3);
    auto r1 = s.linearRemove(r);
    assert(s == SList!int(1, 2, 3));
    assert(r1.empty);
}

unittest
{
    auto s = SList!int(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    auto r = s[];
    popFrontN(r, 3);
    auto r1 = take(r, 4);
    assert(equal(r1, [4, 5, 6, 7]));
    auto r2 = s.linearRemove(r1);
    assert(s == SList!int(1, 2, 3, 8, 9, 10));
    assert(equal(r2, [8, 9, 10]));
}


unittest
{
    auto lst = SList!int(1, 5, 42, 9);
    assert(!lst.empty);
    assert(lst.front == 1);
    assert(walkLength(lst[]) == 4);

    auto lst2 = lst ~ [ 1, 2, 3 ];
    assert(walkLength(lst2[]) == 7);

    auto lst3 = lst ~ [ 7 ];
    assert(walkLength(lst3[]) == 5);
}

unittest
{
    auto s = make!(SList!int)(1, 2, 3);
}

version (none)
{
/**
_Array type with straightforward implementation building on $(D T[]).
 */
struct Array(T)
{
    private struct Data
    {
        size_t _capacity;
        T[] _payload;
        this(size_t c, T[] p) { _capacity = c; _payload = p; }
    }
    private Data * _data;

    this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
    {
        _data = new Data(values.length, new T[values.length]);
        foreach (i, e; values)
        {
            _data._payload[i] = e;
        }
    }

/**
Comparison for equality.
 */
    bool opEquals(ref const Array rhs) const
    {
        if (empty) return rhs.empty;
        if (rhs.empty) return false;
        return _data._payload == rhs._data._payload;
    }

/**
Defines the container's primary range, which is a random-access range.
 */
    alias T[] Range;

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
 */
    @property bool empty() const
    {
        return !_data || _data._payload.empty;
    }

/**
Duplicates the container. The elements themselves are not transitively
duplicated.

Complexity: $(BIGOH n).
 */
    @property Array dup()
    {
        if (!_data) return this;
        Array result;
        result._data = new Data(_data._capacity, _data._payload.dup);
        return result;
    }

/**
Returns the number of elements in the container.

Complexity: $(BIGOH 1).
 */
    @property size_t length() const
    {
        return _data ? _data._payload.length : 0;
    }

/**
Returns the maximum number of elements the container can store without
   (a) allocating memory, (b) invalidating iterators upon insertion.

Complexity: $(BIGOH 1)
 */
    @property size_t capacity()
    {
        return _data ? _data._capacity : 0;
    }

/**
Ensures sufficient capacity to accommodate $(D e) elements.

Postcondition: $(D capacity >= e)

Complexity: $(BIGOH 1)
 */
    void reserve(size_t e)
    {
        if (!_data)
        {
            auto newPayload = (cast(T*) core.memory.GC.malloc(
                        e * T.sizeof))[0 .. 0];
            _data = new Data(e, newPayload);
        }
        else
        {
            if (e <= _data._capacity) return;
            auto newPayload = (cast(T*) core.memory.GC.realloc(
                        _data._payload.ptr,
                        e * T.sizeof))[0 .. _data._payload.length];
            _data._payload = newPayload;
            _data._capacity = e;
        }
    }

/**
Returns a range that iterates over elements of the container, in
forward order.

Complexity: $(BIGOH 1)
 */
    Range opSlice()
    {
        return _data ? _data._payload : null;
    }

/**
Returns a range that iterates over elements of the container from
index $(D a) up to (excluding) index $(D b).

Precondition: $(D a <= b && b <= length)

Complexity: $(BIGOH 1)
 */
    Range opSlice(size_t a, size_t b)
    {
        enforce(a <= b && b <= length);
        return _data ? _data._payload[a .. b] : (enforce(b == 0), (T[]).init);
    }

/**
@@@BUG@@@ This doesn't work yet
 */
    size_t opDollar() const
    {
        return length;
    }

/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Precondition: $(D !empty)

Complexity: $(BIGOH 1)
 */
    @property T front()
    {
        enforce(!empty);
        return *_data._payload.ptr;
    }

/// ditto
    @property void front(T value)
    {
        enforce(!empty);
        *_data._payload.ptr = value;
    }

/// ditto
    @property T back()
    {
        enforce(!empty);
        return _data._payload[$ - 1];
    }

/// ditto
    @property void back(T value)
    {
        enforce(!empty);
        _data._payload[$ - 1] = value;
    }

/**
Indexing operators yield or modify the value at a specified index.

Precondition: $(D i < length)

Complexity: $(BIGOH 1)
 */
    T opIndex(size_t i)
    {
        enforce(_data);
        return _data._payload[i];
    }

    /// ditto
    void opIndexAssign(T value, size_t i)
    {
        enforce(_data);
        _data._payload[i] = value;
    }

/// ditto
    void opIndexOpAssign(string op)(T value, size_t i)
    {
        mixin("_data._payload[i] "~op~"= value;");
    }

/**
Returns a new container that's the concatenation of $(D this) and its
argument. $(D opBinaryRight) is only defined if $(D Stuff) does not
define $(D opBinary).

Complexity: $(BIGOH n + m), where m is the number of elements in $(D
stuff)
 */
    Array opBinary(string op, Stuff)(Stuff stuff) if (op == "~")
    {
        // TODO: optimize
        auto result = Array(this[]);
        result ~= stuff;
        return result;
    }

/**
Forwards to $(D insertBack(stuff)).
 */
    void opOpAssign(string op, Stuff)(Stuff stuff) if (op == "~")
    {
        static if (is(typeof(stuff[])))
        {
            insertBack(stuff[]);
        }
        else
        {
            insertBack(stuff);
        }
    }

/**
Removes all contents from the container. The container decides how $(D
capacity) is affected.

Postcondition: $(D empty)

Complexity: $(BIGOH n)
 */
    void clear()
    {
        _data = null;
    }

/**
Sets the number of elements in the container to $(D newSize). If $(D
newSize) is greater than $(D length), the added elements are added to
unspecified positions in the container and initialized with $(D
ElementType.init).

Complexity: $(BIGOH abs(n - newLength))

Postcondition: $(D length == newLength)
 */
    @property void length(size_t newLength)
    {
        if (!_data)
        {
            _data = new Data(newLength, new T[newLength]);
        }
        else
        {
            _data._payload.length = newLength;
            if (newLength > capacity)
            {
                _data._capacity = newLength;
            }
        }
    }

/**
Picks one value in an unspecified position in the container, removes
it from the container, and returns it. Implementations should pick the
value that's the most advantageous for the container, but document the
exact behavior. The stable version behaves the same, but guarantees
that ranges iterating over the container are never invalidated.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH log(n)).
 */
    T removeAny()
    {
        auto result = back;
        removeBack();
        return result;
    }
    /// ditto
    alias removeAny stableRemoveAny;

/**
Inserts $(D value) to the front or back of the container. $(D stuff)
can be a value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements in $(D stuff)
 */
    size_t insertBack(Stuff)(Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        if (capacity == length)
        {
            reserve(1 + capacity * 3 / 2);
        }
        _data._payload = _data._payload.ptr[0 .. _data._payload.length + 1];
        _data._payload[$ - 1] = stuff;
        return 1;
    }

/// ditto
    size_t insertBack(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        size_t result;
        foreach (item; stuff)
        {
            insertBack(item);
            ++result;
        }
        return result;
    }
/// ditto
    alias insertBack insert;

/**
Removes the value at the back of the container. The stable version
behaves the same, but guarantees that ranges iterating over the
container are never invalidated.

Precondition: $(D !empty)

Complexity: $(BIGOH log(n)).
 */
    void removeBack()
    {
        enforce(!empty);
        _data._payload = _data._payload[0 .. $ - 1];
    }
/// ditto
    alias removeBack stableRemoveBack;

/**
Removes $(D howMany) values at the front or back of the
container. Unlike the unparameterized versions above, these functions
do not throw if they could not remove $(D howMany) elements. Instead,
if $(D howMany > n), all elements are removed. The returned value is
the effective number of elements removed. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: The number of elements removed

Complexity: $(BIGOH howMany).
 */
    size_t removeBack(size_t howMany)
    {
        if (howMany > length) howMany = length;
        _data._payload = _data._payload[0 .. $ - howMany];
        return howMany;
    }
    /// ditto
    alias removeBack stableRemoveBack;

/**
Inserts $(D stuff) before, after, or instead range $(D r), which must
be a valid range previously extracted from this container. $(D stuff)
can be a value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of values inserted.

Complexity: $(BIGOH n + m), where $(D m) is the length of $(D stuff)
 */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    {
        // TODO: optimize
        enforce(_data);
        immutable offset = r.ptr - _data._payload.ptr;
        enforce(offset <= length);
        auto result = insertBack(stuff);
        bringToFront(this[offset .. length - result],
                this[length - result .. length]);
        return result;
    }

    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        // TODO: optimize
        enforce(_data);
        immutable offset = r.ptr + r.length - _data._payload.ptr;
        enforce(offset <= length);
        auto result = insertBack(stuff);
        bringToFront(this[offset .. length - result],
                this[length - result .. length]);
        return result;
    }

/// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        enforce(_data);
        immutable offset = r.ptr - _data._payload.ptr;
        enforce(offset <= length);
        size_t result;
        for (; !stuff.empty; stuff.popFront())
        {
            if (r.empty)
            {
                // append the rest
                return result + insertBack(stuff);
            }
            r.front = stuff.front;
            r.popFront();
            ++result;
        }
        // Remove remaining stuff in r
        remove(r);
        return result;
    }

/// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        if (r.empty)
        {
            insertBefore(r, stuff);
        }
        else
        {
            r.front = stuff;
            r.popFront();
            remove(r);
        }
        return 1;
    }

/**
Removes all elements belonging to $(D r), which must be a range
obtained originally from this container. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: A range spanning the remaining elements in the container that
initially were right after $(D r).

Complexity: $(BIGOH n - m), where $(D m) is the number of elements in
$(D r)
 */
    Range linearRemove(Range r)
    {
        enforce(_data);
        immutable offset1 = r.ptr - _data._payload.ptr;
        immutable offset2 = offset1 + r.length;
        enforce(offset1 <= offset2 && offset2 <= length);
        immutable tailLength = length - offset2;
        // Use copy here, not a[] = b[] because the ranges may overlap
        copy(this[offset2 .. length], this[offset1 .. offset1 + tailLength]);
        length = offset1 + tailLength;
        return this[length - tailLength .. length];
    }

    /// ditto
    alias remove stableLinearRemove;

}

unittest
{
    Array!int a;
    assert(a.empty);
}

unittest
{
    auto a = Array!int(1, 2, 3);
    auto b = a.dup;
    assert(b == Array!int(1, 2, 3));
    b.front = 42;
    assert(b == Array!int(42, 2, 3));
    assert(a == Array!int(1, 2, 3));
}

unittest
{
    auto a = Array!int(1, 2, 3);
    assert(a.length == 3);
}

unittest
{
    Array!int a;
    a.reserve(1000);
    assert(a.length == 0);
    assert(a.empty);
    assert(a.capacity >= 1000);
    auto p = a._data._payload.ptr;
    foreach (i; 0 .. 1000)
    {
        a.insertBack(i);
    }
    assert(p == a._data._payload.ptr);
}

unittest
{
    auto a = Array!int(1, 2, 3);
    a[1] *= 42;
    assert(a[1] == 84);
}

unittest
{
    auto a = Array!int(1, 2, 3);
    auto b = Array!int(11, 12, 13);
    assert(a ~ b == Array!int(1, 2, 3, 11, 12, 13));
    assert(a ~ b[] == Array!int(1, 2, 3, 11, 12, 13));
}

unittest
{
    auto a = Array!int(1, 2, 3);
    auto b = Array!int(11, 12, 13);
    a ~= b;
    assert(a == Array!int(1, 2, 3, 11, 12, 13));
}

unittest
{
    auto a = Array!int(1, 2, 3, 4);
    assert(a.removeAny() == 4);
    assert(a == Array!int(1, 2, 3));
}

unittest
{
    auto a = Array!int(1, 2, 3, 4, 5);
    auto r = a[2 .. a.length];
    assert(a.insertBefore(r, 42) == 1);
    assert(a == Array!int(1, 2, 42, 3, 4, 5));
    r = a[2 .. 2];
    assert(a.insertBefore(r, [8, 9]) == 2);
    assert(a == Array!int(1, 2, 8, 9, 42, 3, 4, 5));
}

unittest
{
    auto a = Array!int(0, 1, 2, 3, 4, 5, 6, 7, 8);
    a.linearRemove(a[4 .. 6]);
    assert(a == Array!int(0, 1, 2, 3, 6, 7, 8));
}
}

/**
Array type with deterministic control of memory. The memory allocated
for the array is reclaimed as soon as possible; there is no reliance
on the garbage collector.
 */
struct Array(T)
{
    private struct Data
    {
        uint _refCount = 1;
        size_t _capacity;
        T[] _payload;
        this(T[] p) { _capacity = p.length; _payload = p; }
    }
    private Data * _data;

    this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
    {
	auto p = malloc(T.sizeof * values.length);
	if (T.sizeof >= size_t.sizeof && p)
	    GC.addRange(p, T.sizeof * values.length);
        _data = emplace!Data(
            malloc(Data.sizeof)[0 .. Data.sizeof],
            (cast(T*) p)[0 .. values.length]);
        assert(_data._refCount == 1);
        foreach (i, e; values)
        {
            emplace!T((cast(void*) &_data._payload[i])[0 .. T.sizeof], e);
            assert(_data._payload[i] == e);
        }
    }

    this(this)
    {
        if (_data)
        {
            ++_data._refCount;
        }
    }

    ~this()
    {
        if (!_data) return;
        if (_data._refCount > 1)
        {
            --_data._refCount;
            return;
        }
        assert(_data._refCount == 1);
        --_data._refCount;
        foreach (ref e; _data._payload) .clear(e);
	if (T.sizeof >= size_t.sizeof)
	    GC.removeRange(_data._payload.ptr);
        free(_data._payload.ptr);
        free(_data);
        _data = null;
    }

    void opAssign(Array another)
    {
        swap(this, another);
    }

/**
Comparison for equality.
 */
    bool opEquals(ref const Array rhs) const
    {
        if (empty) return rhs.empty;
        if (rhs.empty) return false;
        return _data._payload == rhs._data._payload;
    }

/**
Defines the container's primary range, which is a random-access range.
 */
    struct Range
    {
        private Data * _data;
        private size_t _a, _b;

        private this(Data * data, size_t a, size_t b)
        {
            _data = data;
            if (!_data)
            {
                assert(a == 0 && b == 0);
                return;
            }
            ++_data._refCount;
            _a = a;
            _b = b;
        }

        this(this)
        {
            if (_data)
            {
                ++_data._refCount;
            }
        }

        ~this()
        {
            if (!_data) return;
            if (_data._refCount > 1)
            {
                --_data._refCount;
                return;
            }
            assert(_data._refCount == 1);
            foreach (ref e; _data._payload) .clear(e);
            free(_data._payload.ptr);
            free(_data);
            _data = null;
            _a = _b = 0;
        }

        void opAssign(Range another)
        {
            swap(this, another);
        }

        @property bool empty() const
        {
            return !_data || _a == _b || _data._payload.length <= _a;
        }

        @property Range save()
        {
            return this;
        }

        @property T front()
        {
            enforce(_data && _a < _data._payload.length);
            return _data._payload[_a];
        }

        void popFront()
        {
            enforce(!empty);
            ++_a;
        }

        void put(T e)
        {
            enforce(!empty);
            _data._payload[_a] = e;
            popFront();
        }

        T moveFront()
        {
            enforce(_data && _a < _data._payload.length);
            return move(_data._payload[_a]);
        }

        T moveBack()
        {
            enforce(_data && _b <= _data._payload.length);
            return move(_data._payload[_b - 1]);
        }

        T moveAt(size_t i)
        {
            enforce(_data && _a + i < _b && _b <= _data._payload.length);
            return move(_data._payload[_a + i]);
        }

        T opIndex(size_t i)
        {
            enforce(_data && _a + i < _b && _b <= _data._payload.length);
            return _data._payload.ptr[_a + i];
        }

        void opIndexAssign(T value, size_t i)
        {
            enforce(_data && _a + i < _b && _b <= _data._payload.length);
            swap(_data._payload.ptr[_a + i], value);
        }

        void opIndexOpAssign(string op)(T value, size_t i)
        {
            enforce(_data && _a + i < _b && _b <= _data._payload.length);
            mixin("_data._payload.ptr[_a + i] "~op~"= value;");
        }
    }

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
 */
    @property bool empty() const
    {
        return !_data || _data._payload.empty;
    }

/**
Duplicates the container. The elements themselves are not transitively
duplicated.

Complexity: $(BIGOH n).
 */
    @property Array dup()
    {
        if (!_data) return this;
        return Array(_data._payload);
    }

/**
Returns the number of elements in the container.

Complexity: $(BIGOH 1).
 */
    @property size_t length() const
    {
        return _data ? _data._payload.length : 0;
    }

/**
Returns the maximum number of elements the container can store without
   (a) allocating memory, (b) invalidating iterators upon insertion.

Complexity: $(BIGOH 1)
 */
    @property size_t capacity()
    {
        return _data ? _data._capacity : 0;
    }

/**
Ensures sufficient capacity to accommodate $(D e) elements.

Postcondition: $(D capacity >= e)

Complexity: $(BIGOH 1)
 */
    void reserve(size_t elements)
    {
        if (!_data)
        {
	    auto p = malloc(elements * T.sizeof);
	    if (T.sizeof >= size_t.sizeof && p)	// should use hasPointers instead
		GC.addRange(p, T.sizeof * elements);
            _data = emplace!Data(malloc(Data.sizeof)[0 .. Data.sizeof],
                    (cast(T*) p)[0 .. 0]);
            _data._capacity = elements;
        }
        else
        {
            if (elements <= _data._capacity) return;

	    auto sz = elements * T.sizeof;
	    if (T.sizeof >= size_t.sizeof)	// should use hasPointers instead
	    {
		/* Because of the transactional nature of this relative to the
		 * garbage collector, ensure no threading bugs by using malloc/copy/free
		 * rather than realloc.
		 */
		auto newPayload = (cast(T*) malloc(sz))[0 .. _data._payload.length];
		newPayload || assert(false);
		newPayload[] = _data._payload[];	// copy old data over to new array
		// Zero out unused capacity to prevent gc from seeing false pointers
		memset(newPayload.ptr + _data._payload.length,
		       0,
		       (elements - _data._payload.length) * T.sizeof);
		GC.addRange(newPayload.ptr, sz);
		GC.removeRange(_data._payload.ptr);
		free(_data._payload.ptr);
		_data._payload = newPayload;
	    }
	    else
	    {
		/* These can't have pointers, so no need to zero unused region
		 */
		auto newPayload = (cast(T*) realloc(_data._payload.ptr, sz))
			[0 .. _data._payload.length];
		newPayload || assert(false);
		_data._payload = newPayload;
	    }
            _data._capacity = elements;
        }
    }

/**
Returns a range that iterates over elements of the container, in
forward order.

Complexity: $(BIGOH 1)
 */
    Range opSlice()
    {
        return Range(_data, 0, length);
    }

/**
Returns a range that iterates over elements of the container from
index $(D a) up to (excluding) index $(D b).

Precondition: $(D a <= b && b <= length)

Complexity: $(BIGOH 1)
 */
    Range opSlice(size_t a, size_t b)
    {
        enforce(a <= b && b <= length);
        return Range(_data, a, b);
    }

/**
@@@BUG@@@ This doesn't work yet
 */
    size_t opDollar() const
    {
        return length;
    }

/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Precondition: $(D !empty)

Complexity: $(BIGOH 1)
 */
    @property T front()
    {
        enforce(!empty);
        return *_data._payload.ptr;
    }

/// ditto
    @property void front(T value)
    {
        enforce(!empty);
        *_data._payload.ptr = value;
    }

/// ditto
    @property T back()
    {
        enforce(!empty);
        return _data._payload[$ - 1];
    }

/// ditto
    @property void back(T value)
    {
        enforce(!empty);
        _data._payload[$ - 1] = value;
    }

/**
Indexing operators yield or modify the value at a specified index.

Precondition: $(D i < length)

Complexity: $(BIGOH 1)
 */
    T opIndex(size_t i)
    {
        enforce(_data);
        return _data._payload[i];
    }

    /// ditto
    void opIndexAssign(T value, size_t i)
    {
        enforce(_data);
        _data._payload[i] = value;
    }

/// ditto
    void opIndexOpAssign(string op)(T value, size_t i)
    {
        mixin("_data._payload[i] "~op~"= value;");
    }

/**
Returns a new container that's the concatenation of $(D this) and its
argument. $(D opBinaryRight) is only defined if $(D Stuff) does not
define $(D opBinary).

Complexity: $(BIGOH n + m), where m is the number of elements in $(D
stuff)
 */
    Array opBinary(string op, Stuff)(Stuff stuff) if (op == "~")
    {
        // TODO: optimize
        Array result;
        result ~= this[];
        result ~= stuff;
        return result;
    }

/**
Forwards to $(D insertBack(stuff)).
 */
    void opOpAssign(string op, Stuff)(Stuff stuff) if (op == "~")
    {
        static if (is(typeof(stuff[])))
        {
            insertBack(stuff[]);
        }
        else
        {
            insertBack(stuff);
        }
    }

/**
Removes all contents from the container. The container decides how $(D
capacity) is affected.

Postcondition: $(D empty)

Complexity: $(BIGOH n)
 */
    void clear()
    {
        _data = null;
    }

/**
Sets the number of elements in the container to $(D newSize). If $(D
newSize) is greater than $(D length), the added elements are added to
unspecified positions in the container and initialized with $(D
ElementType.init).

Complexity: $(BIGOH abs(n - newLength))

Postcondition: $(D length == newLength)
 */
    @property void length(size_t newLength)
    {
        size_t startEmplace = void;
        if (!_data)
        {
            _data = emplace!Data(malloc(Data.sizeof)[0 .. Data.sizeof],
                    (cast(T*) malloc(T.sizeof * newLength))[0 .. newLength]);
            startEmplace = 0;
        }
        else
        {
            if (length >= newLength)
            {
                // shorten
                _data._payload = _data._payload.ptr[0 .. newLength];
                return;
            }
            else
            {
                // enlarge
                startEmplace = length;
                _data._payload = (cast(T*) realloc(_data._payload.ptr,
                                T.sizeof * newLength))[0 .. newLength];
            }
        }
        foreach (ref e; _data._payload[startEmplace .. $])
        {
            static init = T.init;
            memcpy(&e, &init, T.sizeof);
        }
    }

/**
Picks one value in an unspecified position in the container, removes
it from the container, and returns it. Implementations should pick the
value that's the most advantageous for the container, but document the
exact behavior. The stable version behaves the same, but guarantees
that ranges iterating over the container are never invalidated.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH log(n)).
 */
    T removeAny()
    {
        auto result = back;
        removeBack();
        return result;
    }
    /// ditto
    alias removeAny stableRemoveAny;

/**
Inserts $(D value) to the front or back of the container. $(D stuff)
can be a value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements in $(D stuff)
 */
    size_t insertBack(Stuff)(Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        if (capacity == length)
        {
            reserve(1 + capacity * 3 / 2);
            assert(capacity > length);
        }
        assert(_data);
        emplace!T((cast(void*) (_data._payload.ptr + _data._payload.length))
                [0 .. T.sizeof],
                stuff);
        _data._payload = _data._payload.ptr[0 .. _data._payload.length + 1];
        return 1;
    }

/// ditto
    size_t insertBack(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        size_t result;
        foreach (item; stuff)
        {
            insertBack(item);
            ++result;
        }
        return result;
    }
/// ditto
    alias insertBack insert;

/**
Removes the value at the back of the container. The stable version
behaves the same, but guarantees that ranges iterating over the
container are never invalidated.

Precondition: $(D !empty)

Complexity: $(BIGOH log(n)).
 */
    void removeBack()
    {
        enforce(!empty);
        _data._payload = _data._payload[0 .. $ - 1];
    }
/// ditto
    alias removeBack stableRemoveBack;

/**
Removes $(D howMany) values at the front or back of the
container. Unlike the unparameterized versions above, these functions
do not throw if they could not remove $(D howMany) elements. Instead,
if $(D howMany > n), all elements are removed. The returned value is
the effective number of elements removed. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: The number of elements removed

Complexity: $(BIGOH howMany).
 */
    size_t removeBack(size_t howMany)
    {
        if (howMany > length) howMany = length;
        _data._payload = _data._payload[0 .. $ - howMany];
        return howMany;
    }
    /// ditto
    alias removeBack stableRemoveBack;

/**
Inserts $(D stuff) before, after, or instead range $(D r), which must
be a valid range previously extracted from this container. $(D stuff)
can be a value convertible to $(D ElementType) or a range of objects
convertible to $(D ElementType). The stable version behaves the same,
but guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of values inserted.

Complexity: $(BIGOH n + m), where $(D m) is the length of $(D stuff)
 */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        enforce(r._data == _data && r._a < length);
        reserve(length + 1);
        assert(_data);
        // Move elements over by one slot
        memmove(_data._payload.ptr + r._a + 1,
                _data._payload.ptr + r._a,
                T.sizeof * (length - r._a));
        emplace!T((cast(void*) (_data._payload.ptr + r._a))[0 .. T.sizeof],
                stuff);
        _data._payload = _data._payload.ptr[0 .. _data._payload.length + 1];
        return 1;
    }

/// ditto
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        enforce(r._data == _data && r._a < length);
        static if (isForwardRange!Stuff)
        {
            // Can find the length in advance
            auto extra = walkLength(stuff);
            if (!extra) return 0;
            reserve(length + extra);
            assert(_data);
            // Move elements over by extra slots
            memmove(_data._payload.ptr + r._a + extra,
                    _data._payload.ptr + r._a,
                    T.sizeof * (length - r._a));
            foreach (p; _data._payload.ptr + r._a ..
                    _data._payload.ptr + r._a + extra)
            {
                emplace!T((cast(void*) p)[0 .. T.sizeof], stuff.front);
                stuff.popFront();
            }
            _data._payload =
                _data._payload.ptr[0 .. _data._payload.length + extra];
            return extra;
        }
        else
        {
            enforce(_data);
            immutable offset = r._a;
            enforce(offset <= length);
            auto result = insertBack(stuff);
            bringToFront(this[offset .. length - result],
                    this[length - result .. length]);
            return result;
        }
    }

    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        // TODO: optimize
        enforce(_data);
        immutable offset = r.ptr + r.length - _data._payload.ptr;
        enforce(offset <= length);
        auto result = insertBack(stuff);
        bringToFront(this[offset .. length - result],
                this[length - result .. length]);
        return result;
    }

/// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        enforce(_data);
        immutable offset = r.ptr - _data._payload.ptr;
        enforce(offset <= length);
        size_t result;
        for (; !stuff.empty; stuff.popFront())
        {
            if (r.empty)
            {
                // append the rest
                return result + insertBack(stuff);
            }
            r.front = stuff.front;
            r.popFront();
            ++result;
        }
        // Remove remaining stuff in r
        remove(r);
        return result;
    }

/// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        if (r.empty)
        {
            insertBefore(r, stuff);
        }
        else
        {
            r.front = stuff;
            r.popFront();
            remove(r);
        }
        return 1;
    }

/**
Removes all elements belonging to $(D r), which must be a range
obtained originally from this container. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Returns: A range spanning the remaining elements in the container that
initially were right after $(D r).

Complexity: $(BIGOH n - m), where $(D m) is the number of elements in
$(D r)
 */
    Range linearRemove(Range r)
    {
        enforce(_data);
        enforce(r._a <= r._b && r._b <= length);
        immutable offset1 = r._a;
        immutable offset2 = r._b;
        immutable tailLength = length - offset2;
        // Use copy here, not a[] = b[] because the ranges may overlap
        copy(this[offset2 .. length], this[offset1 .. offset1 + tailLength]);
        length = offset1 + tailLength;
        return this[length - tailLength .. length];
    }

    /// ditto
    alias remove stableLinearRemove;

}

unittest
{
    Array!int a;
    assert(a.empty);
}

unittest
{
    auto a = Array!int(1, 2, 3);
    auto b = a.dup;
    assert(b == Array!int(1, 2, 3));
    b.front = 42;
    assert(b == Array!int(42, 2, 3));
    assert(a == Array!int(1, 2, 3));
}

unittest
{
    auto a = Array!int(1, 2, 3);
    assert(a.length == 3);
}

unittest
{
    Array!int a;
    a.reserve(1000);
    assert(a.length == 0);
    assert(a.empty);
    assert(a.capacity >= 1000);
    auto p = a._data._payload.ptr;
    foreach (i; 0 .. 1000)
    {
        a.insertBack(i);
    }
    assert(p == a._data._payload.ptr);
}

unittest
{
    auto a = Array!int(1, 2, 3);
    a[1] *= 42;
    assert(a[1] == 84);
}

unittest
{
    auto a = Array!int(1, 2, 3);
    auto b = Array!int(11, 12, 13);
    assert(a ~ b == Array!int(1, 2, 3, 11, 12, 13));
    assert(a ~ b[] == Array!int(1, 2, 3, 11, 12, 13));
}

unittest
{
    auto a = Array!int(1, 2, 3);
    auto b = Array!int(11, 12, 13);
    a ~= b;
    assert(a == Array!int(1, 2, 3, 11, 12, 13));
}

unittest
{
    auto a = Array!int(1, 2, 3, 4);
    assert(a.removeAny() == 4);
    assert(a == Array!int(1, 2, 3));
}

unittest
{
    auto a = Array!int(1, 2, 3, 4, 5);
    auto r = a[2 .. a.length];
    assert(a.insertBefore(r, 42) == 1);
    assert(a == Array!int(1, 2, 42, 3, 4, 5));
    r = a[2 .. 2];
    assert(a.insertBefore(r, [8, 9]) == 2);
    assert(a == Array!int(1, 2, 8, 9, 42, 3, 4, 5));
}

unittest
{
    auto a = Array!int(0, 1, 2, 3, 4, 5, 6, 7, 8);
    a.linearRemove(a[4 .. 6]);
    auto b = Array!int(0, 1, 2, 3, 6, 7, 8);
    assert(a == Array!int(0, 1, 2, 3, 6, 7, 8));
}

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

Example:
----
// Example from "Introduction to Algorithms" Cormen et al, p 146
int[] a = [ 4, 1, 3, 2, 16, 9, 10, 14, 8, 7 ];
auto h = heapify(a);
// largest element
assert(h.front == 16);
// a has the heap property
assert(equal(a, [ 16, 14, 10, 9, 8, 7, 4, 3, 2, 1 ]));
----
 */
struct BinaryHeap(Store, alias less = "a < b")
if (isRandomAccessRange!(Store) || isRandomAccessRange!(typeof(Store.init[])))
{
// Really weird @@BUG@@: if you comment out the "private:" label below,
// std.algorithm can't unittest anymore
//private:

    // The payload includes the support store and the effective length
    private RefCounted!(Tuple!(Store, "_store", size_t, "_length"),
                       RefCountedAutoInitialize.no) _payload;
    // Comparison predicate
    private alias binaryFun!(less) comp;
    // Convenience accessors
    private @property ref Store _store()
    {
        assert(_payload.refCountedIsInitialized);
        return _payload._store;
    }
    private @property ref size_t _length()
    {
        assert(_payload.refCountedIsInitialized);
        return _payload._length;
    }

    // Asserts that the heap property is respected.
    private void assertValid()
    {
        debug
        {
            if (!_payload.refCountedIsInitialized) return;
            if (_length < 2) return;
            for (size_t n = _length - 1; n >= 1; --n)
            {
                auto parentIdx = (n - 1) / 2;
                assert(!comp(_store[parentIdx], _store[n]), text(n));
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
        assert(!store.empty);
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
specified, only the first $(D initialSize) elements in $(D s) are
transformed into a heap, after which the heap can grow up to $(D
r.length) (if $(D Store) is a range) or indefinitely (if $(D Store) is
a container with $(D insertBack)). Performs $(BIGOH min(r.length,
initialSize)) evaluations of $(D less).
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
        _payload.refCountedEnsureInitialized();
        _store() = move(s);
        _length() = min(_store.length, initialSize);
        if (_length < 2) return;
        for (auto i = (_length - 2) / 2; ; )
        {
            this.percolateDown(_store, i, _length);
            if (i-- == 0) break;
        }
        assertValid;
    }

/**
Takes ownership of a store assuming it already was organized as a
heap.
 */
    void assume(Store s, size_t initialSize = size_t.max)
    {
        _payload.refCountedEnsureInitialized();
        _store() = s;
        _length() = min(_store.length, initialSize);
        assertValid;
    }

/**
Clears the heap. Returns the portion of the store from $(D 0) up to
$(D length), which satisfies the $(LUCKY heap property).
 */
    auto release()
    {
        if (!_payload.refCountedIsInitialized)
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
        if (!_payload.refCountedIsInitialized) return result;
        result.assume(_store.dup, length);
        return result;
    }

/**
Returns the _length of the heap.
 */
    @property size_t length()
    {
        return _payload.refCountedIsInitialized ? _length : 0;
    }

/**
Returns the _capacity of the heap, which is the length of the
underlying store (if the store is a range) or the _capacity of the
underlying store (if the store is a container).
 */
    @property size_t capacity()
    {
        if (!_payload.refCountedIsInitialized) return 0;
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
        enforce(!empty);
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
        static if (is(_store.insertBack(value)))
        {
            _payload.refCountedEnsureInitialized();
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
        assertValid();
        return 1;
    }

/**
Removes the largest element from the heap.
 */
    void removeFront()
    {
        enforce(!empty);
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
        assert(!empty);
        _store.front = value;
        percolateDown(_store, 0, _length);
        assertValid;
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
        _payload.refCountedEnsureInitialized();
        if (_length < _store.length)
        {
            insert(value);
            return true;
        }
        // must replace the top
        assert(!_store.empty);
        if (!comp(value, _store.front)) return false; // value >= largest
        _store.front = value;
        percolateDown(_store, 0, _length);
        assertValid;
        return true;
    }
}

/**
Convenience function that returns a $(D BinaryHeap!Store) object
initialized with $(D s) and $(D initialSize).
 */
BinaryHeap!Store heapify(Store)(Store s, size_t initialSize = size_t.max)
{
    return BinaryHeap!Store(s, initialSize);
}

unittest
{
    {
        // example from "Introduction to Algorithms" Cormen et al., p 146
        int[] a = [ 4, 1, 3, 2, 16, 9, 10, 14, 8, 7 ];
        auto h = heapify(a);
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
        assert(b == [ 16, 14, 10, 8, 7, 3, 9, 1, 4, 2 ], text(b));
    }
}

