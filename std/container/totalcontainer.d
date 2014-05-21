module std.container.totalcontainer;

import std.typetuple;
public import std.container.util;


/* The following documentation and type $(D TotalContainer) are
intended for developers only.

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
struct TotalContainer(T)
{
/**
If the container has a notion of key-value mapping, $(D KeyType)
defines the type of the key of the container.
 */
    alias KeyType = T;

/**
If the container has a notion of multikey-value mapping, $(D
KeyTypes[k]), where $(D k) is a zero-based unsigned number, defines
the type of the $(D k)th key of the container.

A container may define both $(D KeyType) and $(D KeyTypes), e.g. in
the case it has the notion of primary/preferred key.
 */
    alias KeyTypes = TypeTuple!T;

/**
If the container has a notion of key-value mapping, $(D ValueType)
defines the type of the value of the container. Typically, a map-style
container mapping values of type $(D K) to values of type $(D V)
defines $(D KeyType) to be $(D K) and $(D ValueType) to be $(D V).
 */
    alias ValueType = T;

/**
Defines the container's primary range, which embodies one of the
ranges defined in $(XREFMODULE range).

Generally a container may define several types of ranges.
 */
    struct Range
    {
        /++
        Range primitives.
        +/
        @property bool empty()
        {
            assert(0);
        }
        /// Ditto
        @property ref T front() //ref return optional
        {
            assert(0);
        }
        /// Ditto
        @property void front(T value) //Only when front does not return by ref
        {
            assert(0);
        }
        /// Ditto
        T moveFront()
        {
            assert(0);
        }
        /// Ditto
        void popFront()
        {
            assert(0);
        }
        /// Ditto
        @property ref T back() //ref return optional
        {
            assert(0);
        }
        /// Ditto
        @property void back(T value) //Only when front does not return by ref
        {
            assert(0);
        }
        /// Ditto
        T moveBack()
        {
            assert(0);
        }
        /// Ditto
        void popBack()
        {
            assert(0);
        }
        /// Ditto
        T opIndex(size_t i) //ref return optional
        {
            assert(0);
        }
        /// Ditto
        void opIndexAssign(size_t i, T value) //Only when front does not return by ref
        {
            assert(0);
        }
        /// Ditto
        T opIndexUnary(string op)(size_t i) //Only when front does not return by ref
        {
            assert(0);
        }
        /// Ditto
        void opIndexOpAssign(string op)(size_t i, T value) //Only when front does not return by ref
        {
            assert(0);
        }
        /// Ditto
        T moveAt(size_t i)
        {
            assert(0);
        }
        /// Ditto
        @property size_t length()
        {
            assert(0);
        }
    }

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
 */
    @property bool empty()
    {
        assert(0);
    }

/**
Returns a duplicate of the container. The elements themselves are not
transitively duplicated.

Complexity: $(BIGOH n).
 */
    @property TotalContainer dup()
    {
        assert(0);
    }

/**
Returns the number of elements in the container.

Complexity: $(BIGOH log(n)).
*/
    @property size_t length()
    {
        assert(0);
    }

/**
Returns the maximum number of elements the container can store without
(a) allocating memory, (b) invalidating iterators upon insertion.

Complexity: $(BIGOH log(n)).
 */
    @property size_t capacity()
    {
        assert(0);
    }

/**
Ensures sufficient capacity to accommodate $(D n) elements.

Postcondition: $(D capacity >= n)

Complexity: $(BIGOH log(e - capacity)) if $(D e > capacity), otherwise
$(BIGOH 1).
 */
    void reserve(size_t e)
    {
        assert(0);
    }

/**
Returns a range that iterates over all elements of the container, in a
container-defined order. The container should choose the most
convenient and fast method of iteration for $(D opSlice()).

Complexity: $(BIGOH log(n))
 */
    Range opSlice()
    {
        assert(0);
    }

    /**
       Returns a range that iterates the container between two
       specified positions.

       Complexity: $(BIGOH log(n))
     */
    Range opSlice(size_t a, size_t b)
    {
        assert(0);
    }

/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Complexity: $(BIGOH log(n))
 */
    @property ref T front() //ref return optional
    {
        assert(0);
    }
    /// Ditto
    @property void front(T value) //Only when front does not return by ref
    {
        assert(0);
    }
    /// Ditto
    T moveFront()
    {
        assert(0);
    }
    /// Ditto
    @property ref T back() //ref return optional
    {
        assert(0);
    }
    /// Ditto
    @property void back(T value) //Only when front does not return by ref
    {
        assert(0);
    }
    /// Ditto
    T moveBack()
    {
        assert(0);
    }

/**
Indexing operators yield or modify the value at a specified index.
 */
    ref T opIndex(KeyType) //ref return optional
    {
        assert(0);
    }
    /// ditto
    void opIndexAssign(KeyType i, T value) //Only when front does not return by ref
    {
        assert(0);
    }
    /// ditto
    T opIndexUnary(string op)(KeyType i) //Only when front does not return by ref
    {
        assert(0);
    }
    /// ditto
    void opIndexOpAssign(string op)(KeyType i, T value) //Only when front does not return by ref
    {
        assert(0);
    }
    /// ditto
    T moveAt(KeyType i)
    {
        assert(0);
    }

/**
$(D k in container) returns true if the given key is in the container.
 */
    bool opBinaryRight(string op)(KeyType k) if (op == "in")
    {
        assert(0);
    }

/**
Returns a range of all elements containing $(D k) (could be empty or a
singleton range).
 */
    Range equalRange(KeyType k)
    {
        assert(0);
    }

/**
Returns a range of all elements with keys less than $(D k) (could be
empty or a singleton range). Only defined by containers that store
data sorted at all times.
 */
    Range lowerBound(KeyType k)
    {
        assert(0);
    }

/**
Returns a range of all elements with keys larger than $(D k) (could be
empty or a singleton range).  Only defined by containers that store
data sorted at all times.
 */
    Range upperBound(KeyType k)
    {
        assert(0);
    }

/**
Returns a new container that's the concatenation of $(D this) and its
argument. $(D opBinaryRight) is only defined if $(D Stuff) does not
define $(D opBinary).

Complexity: $(BIGOH n + m), where m is the number of elements in $(D
stuff)
 */
    TotalContainer opBinary(string op)(Stuff rhs) if (op == "~")
    {
        assert(0);
    }

    /// ditto
    TotalContainer opBinaryRight(string op)(Stuff lhs) if (op == "~")
    {
        assert(0);
    }

/**
Forwards to $(D insertAfter(this[], stuff)).
 */
    void opOpAssign(string op)(Stuff stuff) if (op == "~")
    {
        assert(0);
    }

/**
Removes all contents from the container. The container decides how $(D
capacity) is affected.

Postcondition: $(D empty)

Complexity: $(BIGOH n)
 */
    void clear()
    {
        assert(0);
    }

/**
Sets the number of elements in the container to $(D newSize). If $(D
newSize) is greater than $(D length), the added elements are added to
unspecified positions in the container and initialized with $(D
.init).

Complexity: $(BIGOH abs(n - newLength))

Postcondition: $(D _length == newLength)
 */
    @property void length(size_t newLength)
    {
        assert(0);
    }

/**
Inserts $(D stuff) in an unspecified position in the
container. Implementations should choose whichever insertion means is
the most advantageous for the container, but document the exact
behavior. $(D stuff) can be a value convertible to the element type of
the container, or a range of values convertible to it.

The $(D stable) version guarantees that ranges iterating over the
container are never invalidated. Client code that counts on
non-invalidating insertion should use $(D stableInsert). Such code would
not compile against containers that don't support it.

Returns: The number of elements added.

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements in $(D stuff)
 */
    size_t insert(Stuff)(Stuff stuff)
    {
        assert(0);
    }
    ///ditto
    size_t stableInsert(Stuff)(Stuff stuff)
    {
        assert(0);
    }

/**
Same as $(D insert(stuff)) and $(D stableInsert(stuff)) respectively,
but relax the complexity constraint to linear.
 */
    size_t linearInsert(Stuff)(Stuff stuff)
    {
        assert(0);
    }
    ///ditto
    size_t stableLinearInsert(Stuff)(Stuff stuff)
    {
        assert(0);
    }

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
    T removeAny()
    {
        assert(0);
    }
    /// ditto
    T stableRemoveAny()
    {
        assert(0);
    }

/**
Inserts $(D value) to the front or back of the container. $(D stuff)
can be a value convertible to the container's element type or a range
of values convertible to it. The stable version behaves the same, but
guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH log(n)).
 */
    size_t insertFront(Stuff)(Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t stableInsertFront(Stuff)(Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t insertBack(Stuff)(Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t stableInsertBack(T value)
    {
        assert(0);
    }

/**
Removes the value at the front or back of the container. The stable
version behaves the same, but guarantees that ranges iterating over
the container are never invalidated. The optional parameter $(D
howMany) instructs removal of that many elements. If $(D howMany > n),
all elements are removed and no exception is thrown.

Precondition: $(D !empty)

Complexity: $(BIGOH log(n)).
 */
    void removeFront()
    {
        assert(0);
    }
    /// ditto
    void stableRemoveFront()
    {
        assert(0);
    }
    /// ditto
    void removeBack()
    {
        assert(0);
    }
    /// ditto
    void stableRemoveBack()
    {
        assert(0);
    }

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
        assert(0);
    }
    /// ditto
    size_t stableRemoveFront(size_t howMany)
    {
        assert(0);
    }
    /// ditto
    size_t removeBack(size_t howMany)
    {
        assert(0);
    }
    /// ditto
    size_t stableRemoveBack(size_t howMany)
    {
        assert(0);
    }

/**
Removes all values corresponding to key $(D k).

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements with the same key.

Returns: The number of elements removed.
 */
    size_t removeKey(KeyType k)
    {
        assert(0);
    }

/**
Inserts $(D stuff) before, after, or instead range $(D r), which must
be a valid range previously extracted from this container. $(D stuff)
can be a value convertible to the container's element type or a range
of objects convertible to it. The stable version behaves the same, but
guarantees that ranges iterating over the container are never
invalidated.

Returns: The number of values inserted.

Complexity: $(BIGOH n + m), where $(D m) is the length of $(D stuff)
 */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t stableInsertBefore(Stuff)(Range r, Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t stableInsertAfter(Stuff)(Range r, Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    {
        assert(0);
    }
    /// ditto
    size_t stableReplace(Stuff)(Range r, Stuff stuff)
    {
        assert(0);
    }

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
    Range remove(Range r)
    {
        assert(0);
    }
    /// ditto
    Range stableRemove(Range r)
    {
        assert(0);
    }

/**
Same as $(D remove) above, but has complexity relaxed to linear.

Returns: A range spanning the remaining elements in the container that
initially were right after $(D r).

Complexity: $(BIGOH n)
 */
    Range linearRemove(Range r)
    {
        assert(0);
    }
    /// ditto
    Range stableLinearRemove(Range r)
    {
        assert(0);
    }
}

unittest {
    TotalContainer!int test;
}
