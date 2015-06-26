/**
This module provides an $(D Array) type with deterministic memory usage not
reliant on the GC, as an alternative to the built-in arrays.

This module is a submodule of $(LINK2 std_container.html, std.container).

Source: $(PHOBOSSRC std/container/_array.d)
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
module std.container.array;

import std.range.primitives;
import std.traits;
import core.exception : RangeError;
import std.algorithm : move;

public import std.container.util;

private struct RangeT(A)
{
    /* Workaround for Issue 13629 at https://issues.dlang.org/show_bug.cgi?id=13629
       See also: http://forum.dlang.org/thread/vbmwhzvawhnkoxrhbnyb@forum.dlang.org?page=1
    */
    private A[1] _outer_;
    private @property ref inout(A) _outer() inout { return _outer_[0]; }

    private size_t _a, _b;

    /* E is different from T when A is more restrictively qualified than T:
       immutable(Array!int) => T == int, E = immutable(int) */
    alias E = typeof(_outer_[0]._data._payload[0]);

    private this(ref A data, size_t a, size_t b)
    {
        _outer_ = data;
        _a = a;
        _b = b;
    }

    @property RangeT save()
    {
        return this;
    }

    @property bool empty() @safe pure nothrow const
    {
        return _a >= _b;
    }

    @property size_t length() @safe pure nothrow const
    {
        return _b - _a;
    }
    alias opDollar = length;

    @property ref inout(E) front() inout
    {
        version (assert) if (empty) throw new RangeError();
        return _outer[_a];
    }
    @property ref inout(E) back() inout
    {
        version (assert) if (empty) throw new RangeError();
        return _outer[_b - 1];
    }

    void popFront() @safe pure nothrow
    {
        version (assert) if (empty) throw new RangeError();
        ++_a;
    }

    void popBack() @safe pure nothrow
    {
        version (assert) if (empty) throw new RangeError();
        --_b;
    }

    static if (isMutable!A)
    {
        E moveFront()
        {
            version (assert) if (empty || _a >= _outer.length) throw new RangeError();
            return move(_outer._data._payload[_a]);
        }

        E moveBack()
        {
            version (assert) if (empty || _b  > _outer.length) throw new RangeError();
            return move(_outer._data._payload[_b - 1]);
        }

        E moveAt(size_t i)
        {
            version (assert) if (_a + i >= _b || _a + i >= _outer.length) throw new RangeError();
            return move(_outer._data._payload[_a + i]);
        }
    }

    ref inout(E) opIndex(size_t i) inout
    {
        version (assert) if (_a + i >= _b) throw new RangeError();
        return _outer[_a + i];
    }

    RangeT opSlice()
    {
        return typeof(return)(_outer, _a, _b);
    }

    RangeT opSlice(size_t i, size_t j)
    {
        version (assert) if (i > j || _a + j > _b) throw new RangeError();
        return typeof(return)(_outer, _a + i, _a + j);
    }

    RangeT!(const(A)) opSlice() const
    {
        return typeof(return)(_outer, _a, _b);
    }

    RangeT!(const(A)) opSlice(size_t i, size_t j) const
    {
        version (assert) if (i > j || _a + j > _b) throw new RangeError();
        return typeof(return)(_outer, _a + i, _a + j);
    }

    static if (isMutable!A)
    {
        void opSliceAssign(E value)
        {
            version (assert) if (_b > _outer.length) throw new RangeError();
            _outer[_a .. _b] = value;
        }

        void opSliceAssign(E value, size_t i, size_t j)
        {
            version (assert) if (_a + j > _b) throw new RangeError();
            _outer[_a + i .. _a + j] = value;
        }

        void opSliceUnary(string op)()
        if (op == "++" || op == "--")
        {
            version (assert) if (_b > _outer.length) throw new RangeError();
            mixin(op~"_outer[_a .. _b];");
        }

        void opSliceUnary(string op)(size_t i, size_t j)
        if (op == "++" || op == "--")
        {
            version (assert) if (_a + j > _b) throw new RangeError();
            mixin(op~"_outer[_a + i .. _a + j];");
        }

        void opSliceOpAssign(string op)(E value)
        {
            version (assert) if (_b > _outer.length) throw new RangeError();
            mixin("_outer[_a .. _b] "~op~"= value;");
        }

        void opSliceOpAssign(string op)(E value, size_t i, size_t j)
        {
            version (assert) if (_a + j > _b) throw new RangeError();
            mixin("_outer[_a + i .. _a + j] "~op~"= value;");
        }
    }
}

/**
Array type with deterministic control of memory. The memory allocated
for the array is reclaimed as soon as possible; there is no reliance
on the garbage collector. $(D Array) uses $(D malloc) and $(D free)
for managing its own memory.

This means that pointers to elements of an $(D Array) will become
dangling as soon as the element is removed from the $(D Array). On the other hand
the memory allocated by an $(D Array) will be scanned by the GC and
GC managed objects referenced from an $(D Array) will be kept alive.

Note:

When using $(D Array) with range-based functions like those in $(D std.algorithm),
$(D Array) must be sliced to get a range (for example, use $(D array[].map!)
instead of $(D array.map!)). The container itself is not a range.
 */
struct Array(T)
if (!is(Unqual!T == bool))
{
    import core.stdc.stdlib;
    import core.stdc.string;

    import core.memory;

    import std.algorithm : initializeAll, copy;
    import std.exception : enforce;
    import std.typecons : RefCounted, RefCountedAutoInitialize;

    // This structure is not copyable.
    private struct Payload
    {
        size_t _capacity;
        T[] _payload;

        // Convenience constructor
        this(T[] p) { _capacity = p.length; _payload = p; }

        // Destructor releases array memory
        ~this()
        {
            //Warning: destroy will also destroy class instances.
            //The hasElaborateDestructor protects us here.
            static if (hasElaborateDestructor!T)
                foreach (ref e; _payload)
                    .destroy(e);

            static if (hasIndirections!T)
                GC.removeRange(_payload.ptr);

            free(_payload.ptr);
        }

        this(this)
        {
            assert(0);
        }

        void opAssign(Payload rhs)
        {
            assert(false);
        }

        // Duplicate data
        // @property Payload dup()
        // {
        //     Payload result;
        //     result._payload = _payload.dup;
        //     // Conservatively assume initial capacity == length
        //     result._capacity = result._payload.length;
        //     return result;
        // }

        // length
        @property size_t length() const
        {
            return _payload.length;
        }

        // length
        @property void length(size_t newLength)
        {
            if (length >= newLength)
            {
                // shorten
                static if (hasElaborateDestructor!T)
                    foreach (ref e; _payload.ptr[newLength .. _payload.length])
                        .destroy(e);

                _payload = _payload.ptr[0 .. newLength];
                return;
            }
            // enlarge
            auto startEmplace = length;
            _payload = (cast(T*) realloc(_payload.ptr,
                            T.sizeof * newLength))[0 .. newLength];
            initializeAll(_payload.ptr[startEmplace .. length]);
        }

        // capacity
        @property size_t capacity() const
        {
            return _capacity;
        }

        // reserve
        void reserve(size_t elements)
        {
            if (elements <= capacity) return;
            immutable sz = elements * T.sizeof;
            static if (hasIndirections!T)       // should use hasPointers instead
            {
                /* Because of the transactional nature of this
                 * relative to the garbage collector, ensure no
                 * threading bugs by using malloc/copy/free rather
                 * than realloc.
                 */
                immutable oldLength = length;
                auto newPayload =
                    enforce(cast(T*) malloc(sz))[0 .. oldLength];
                // copy old data over to new array
                memcpy(newPayload.ptr, _payload.ptr, T.sizeof * oldLength);
                // Zero out unused capacity to prevent gc from seeing
                // false pointers
                memset(newPayload.ptr + oldLength,
                        0,
                        (elements - oldLength) * T.sizeof);
                GC.addRange(newPayload.ptr, sz);
                GC.removeRange(_payload.ptr);
                free(_payload.ptr);
                _payload = newPayload;
            }
            else
            {
                /* These can't have pointers, so no need to zero
                 * unused region
                 */
                auto newPayload =
                    enforce(cast(T*) realloc(_payload.ptr, sz))[0 .. length];
                _payload = newPayload;
            }
            _capacity = elements;
        }

        // Insert one item
        size_t insertBack(Stuff)(Stuff stuff)
        if (isImplicitlyConvertible!(Stuff, T))
        {
            import std.conv : emplace;
            if (_capacity == length)
            {
                reserve(1 + capacity * 3 / 2);
            }
            assert(capacity > length && _payload.ptr);
            emplace(_payload.ptr + _payload.length, stuff);
            _payload = _payload.ptr[0 .. _payload.length + 1];
            return 1;
        }

        /// Insert a range of items
        size_t insertBack(Stuff)(Stuff stuff)
        if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
        {
            static if (hasLength!Stuff)
            {
                immutable oldLength = length;
                reserve(oldLength + stuff.length);
            }
            size_t result;
            foreach (item; stuff)
            {
                insertBack(item);
                ++result;
            }
            static if (hasLength!Stuff)
            {
                assert(length == oldLength + stuff.length);
            }
            return result;
        }
    }
    private alias Data = RefCounted!(Payload, RefCountedAutoInitialize.no);
    private Data _data;

/**
Constructor taking a number of items
     */
    this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
    {
        import std.conv : emplace;
        auto p = cast(T*) malloc(T.sizeof * values.length);
        static if (hasIndirections!T)
        {
            if (p)
                GC.addRange(p, T.sizeof * values.length);
        }

        foreach (i, e; values)
        {
            emplace(p + i, e);
            assert(p[i] == e);
        }
        _data = Data(p[0 .. values.length]);
    }

/**
Constructor taking an input range
     */
    this(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T) && !is(Stuff == T[]))
    {
        insertBack(stuff);
    }


/**
Comparison for equality.
     */
    bool opEquals(const Array rhs) const
    {
        return opEquals(rhs);
    }

    /// ditto
    bool opEquals(ref const Array rhs) const
    {
        if (empty) return rhs.empty;
        if (rhs.empty) return false;
        return _data._payload == rhs._data._payload;
    }

/**
   Defines the container's primary range, which is a random-access range.

   ConstRange is a variant with const elements.
   ImmutableRange is a variant with immutable elements.
*/
    alias Range = RangeT!Array;
    alias ConstRange = RangeT!(const Array); /// ditto
    alias ImmutableRange = RangeT!(immutable Array); /// ditto

/**
Duplicates the container. The elements themselves are not transitively
duplicated.

Complexity: $(BIGOH n).
     */
    @property Array dup()
    {
        if (!_data.refCountedStore.isInitialized) return this;
        return Array(_data._payload);
    }

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
     */
    @property bool empty() const
    {
        return !_data.refCountedStore.isInitialized || _data._payload.empty;
    }

/**
Returns the number of elements in the container.

Complexity: $(BIGOH 1).
     */
    @property size_t length() const
    {
        return _data.refCountedStore.isInitialized ? _data._payload.length : 0;
    }

    /// ditto
    size_t opDollar() const
    {
        return length;
    }

/**
Returns the maximum number of elements the container can store without
   (a) allocating memory, (b) invalidating iterators upon insertion.

Complexity: $(BIGOH 1)
     */
    @property size_t capacity()
    {
        return _data.refCountedStore.isInitialized ? _data._capacity : 0;
    }

/**
Ensures sufficient capacity to accommodate $(D e) elements.

Postcondition: $(D capacity >= e)

Complexity: $(BIGOH 1)
     */
    void reserve(size_t elements)
    {
        if (!_data.refCountedStore.isInitialized)
        {
            if (!elements) return;
            immutable sz = elements * T.sizeof;
            auto p = enforce(malloc(sz));
            static if (hasIndirections!T)
            {
                GC.addRange(p, sz);
            }
            _data = Data(cast(T[]) p[0 .. 0]);
            _data._capacity = elements;
        }
        else
        {
            _data.reserve(elements);
        }
    }

/**
Returns a range that iterates over elements of the container, in
forward order.

Complexity: $(BIGOH 1)
     */
    Range opSlice()
    {
        return typeof(return)(this, 0, length);
    }
    ConstRange opSlice() const
    {
        return typeof(return)(this, 0, length);
    }
    ImmutableRange opSlice() immutable
    {
        return typeof(return)(this, 0, length);
    }

/**
Returns a range that iterates over elements of the container from
index $(D a) up to (excluding) index $(D b).

Precondition: $(D a <= b && b <= length)

Complexity: $(BIGOH 1)
*/
    Range opSlice(size_t i, size_t j)
    {
        version (assert) if (i > j || j > length) throw new RangeError();
        return typeof(return)(this, i, j);
    }
    ConstRange opSlice(size_t i, size_t j) const
    {
        version (assert) if (i > j || j > length) throw new RangeError();
        return typeof(return)(this, i, j);
    }
    ImmutableRange opSlice(size_t i, size_t j) immutable
    {
        version (assert) if (i > j || j > length) throw new RangeError();
        return typeof(return)(this, i, j);
    }

/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Precondition: $(D !empty)

Complexity: $(BIGOH 1)
     */
    @property ref inout(T) front() inout
    {
        version (assert) if (!_data.refCountedStore.isInitialized) throw new RangeError();
        return _data._payload[0];
    }

    /// ditto
    @property ref inout(T) back() inout
    {
        version (assert) if (!_data.refCountedStore.isInitialized) throw new RangeError();
        return _data._payload[$ - 1];
    }

/**
Indexing operators yield or modify the value at a specified index.

Precondition: $(D i < length)

Complexity: $(BIGOH 1)
     */
    ref inout(T) opIndex(size_t i) inout
    {
        version (assert) if (!_data.refCountedStore.isInitialized) throw new RangeError();
        return _data._payload[i];
    }

/**
Slicing operations execute an operation on an entire slice.

Precondition: $(D i < j && j < length)

Complexity: $(BIGOH slice.length)
     */
    void opSliceAssign(T value)
    {
        if (!_data.refCountedStore.isInitialized) return;
        _data._payload[] = value;
    }

    /// ditto
    void opSliceAssign(T value, size_t i, size_t j)
    {
        auto slice = _data.refCountedStore.isInitialized ?
            _data._payload :
            T[].init;
        slice[i .. j] = value;
    }

    /// ditto
    void opSliceUnary(string op)()
        if (op == "++" || op == "--")
    {
        if (!_data.refCountedStore.isInitialized) return;
        mixin(op~"_data._payload[];");
    }

    /// ditto
    void opSliceUnary(string op)(size_t i, size_t j)
        if (op == "++" || op == "--")
    {
        auto slice = _data.refCountedStore.isInitialized ? _data._payload : T[].init;
        mixin(op~"slice[i .. j];");
    }

    /// ditto
    void opSliceOpAssign(string op)(T value)
    {
        if (!_data.refCountedStore.isInitialized) return;
        mixin("_data._payload[] "~op~"= value;");
    }

    /// ditto
    void opSliceOpAssign(string op)(T value, size_t i, size_t j)
    {
        auto slice = _data.refCountedStore.isInitialized ? _data._payload : T[].init;
        mixin("slice[i .. j] "~op~"= value;");
    }

/**
Returns a new container that's the concatenation of $(D this) and its
argument. $(D opBinaryRight) is only defined if $(D Stuff) does not
define $(D opBinary).

Complexity: $(BIGOH n + m), where m is the number of elements in $(D
stuff)
     */
    Array opBinary(string op, Stuff)(Stuff stuff)
        if (op == "~")
    {
        // TODO: optimize
        Array result;
        // @@@BUG@@ result ~= this[] doesn't work
        auto r = this[];
        result ~= r;
        assert(result.length == length);
        result ~= stuff[];
        return result;
    }

/**
Forwards to $(D insertBack(stuff)).
     */
    void opOpAssign(string op, Stuff)(Stuff stuff)
        if (op == "~")
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
        _data = Data.init;
    }

/**
Sets the number of elements in the container to $(D newSize). If $(D
newSize) is greater than $(D length), the added elements are added to
unspecified positions in the container and initialized with $(D
T.init).

Complexity: $(BIGOH abs(n - newLength))

Postcondition: $(D length == newLength)
     */
    @property void length(size_t newLength)
    {
        _data.refCountedStore.ensureInitialized();
        _data.length = newLength;
    }

/**
Picks one value in an unspecified position in the container, removes
it from the container, and returns it. The stable version behaves the same,
but guarantees that ranges iterating over the container are never invalidated.

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
    alias stableRemoveAny = removeAny;

/**
Inserts $(D value) to the front or back of the container. $(D stuff)
can be a value convertible to $(D T) or a range of objects convertible
to $(D T). The stable version behaves the same, but guarantees that
ranges iterating over the container are never invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements in $(D stuff)
     */
    size_t insertBack(Stuff)(Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T) ||
            isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        _data.refCountedStore.ensureInitialized();
        return _data.insertBack(stuff);
    }
    /// ditto
    alias insert = insertBack;

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
        static if (hasElaborateDestructor!T)
            .destroy(_data._payload[$ - 1]);

        _data._payload = _data._payload[0 .. $ - 1];
    }
    /// ditto
    alias stableRemoveBack = removeBack;

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
        static if (hasElaborateDestructor!T)
            foreach (ref e; _data._payload[$ - howMany .. $])
                .destroy(e);

        _data._payload = _data._payload[0 .. $ - howMany];
        return howMany;
    }
    /// ditto
    alias stableRemoveBack = removeBack;

/**
Inserts $(D stuff) before, after, or instead range $(D r), which must
be a valid range previously extracted from this container. $(D stuff)
can be a value convertible to $(D T) or a range of objects convertible
to $(D T). The stable version behaves the same, but guarantees that
ranges iterating over the container are never invalidated.

Returns: The number of values inserted.

Complexity: $(BIGOH n + m), where $(D m) is the length of $(D stuff)
     */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        import std.conv : emplace;
        enforce(r._outer._data is _data && r._a <= length);
        reserve(length + 1);
        assert(_data.refCountedStore.isInitialized);
        // Move elements over by one slot
        memmove(_data._payload.ptr + r._a + 1,
                _data._payload.ptr + r._a,
                T.sizeof * (length - r._a));
        emplace(_data._payload.ptr + r._a, stuff);
        _data._payload = _data._payload.ptr[0 .. _data._payload.length + 1];
        return 1;
    }

    /// ditto
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        import std.conv : emplace;
        enforce(r._outer._data is _data && r._a <= length);
        static if (isForwardRange!Stuff)
        {
            // Can find the length in advance
            auto extra = walkLength(stuff);
            if (!extra) return 0;
            reserve(length + extra);
            assert(_data.refCountedStore.isInitialized);
            // Move elements over by extra slots
            memmove(_data._payload.ptr + r._a + extra,
                    _data._payload.ptr + r._a,
                    T.sizeof * (length - r._a));
            foreach (p; _data._payload.ptr + r._a ..
                    _data._payload.ptr + r._a + extra)
            {
                emplace(p, stuff.front);
                stuff.popFront();
            }
            _data._payload =
                _data._payload.ptr[0 .. _data._payload.length + extra];
            return extra;
        }
        else
        {
            import std.algorithm : bringToFront;
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
        import std.algorithm : bringToFront;
        enforce(r._outer._data is _data);
        // TODO: optimize
        immutable offset = r._b;
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
        enforce(r._outer._data is _data);
        size_t result;
        for (; !stuff.empty; stuff.popFront())
        {
            if (r.empty)
            {
                // insert the rest
                return result + insertBefore(r, stuff);
            }
            r.front = stuff.front;
            r.popFront();
            ++result;
        }
        // Remove remaining stuff in r
        linearRemove(r);
        return result;
    }

    /// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        enforce(r._outer._data is _data);
        if (r.empty)
        {
            insertBefore(r, stuff);
        }
        else
        {
            r.front = stuff;
            r.popFront();
            linearRemove(r);
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
        enforce(r._outer._data is _data);
        enforce(_data.refCountedStore.isInitialized);
        enforce(r._a <= r._b && r._b <= length);
        immutable offset1 = r._a;
        immutable offset2 = r._b;
        immutable tailLength = length - offset2;
        // Use copy here, not a[] = b[] because the ranges may overlap
        copy(this[offset2 .. length], this[offset1 .. offset1 + tailLength]);
        length = offset1 + tailLength;
        return this[length - tailLength .. length];
    }
}

unittest
{
    Array!int a;
    assert(a.empty);
}

unittest
{
    Array!int a = Array!int(1, 2, 3);
    //a._data._refCountedDebug = true;
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
    const Array!int a = [1, 2];

    assert(a[0] == 1);
    assert(a.front == 1);
    assert(a.back == 2);

    static assert(!__traits(compiles, { a[0] = 1; }));
    static assert(!__traits(compiles, { a.front = 1; }));
    static assert(!__traits(compiles, { a.back = 1; }));

    auto r = a[];
    size_t i;
    foreach (e; r)
    {
        assert(e == i + 1);
        i++;
    }
}

unittest
{
    // REG https://issues.dlang.org/show_bug.cgi?id=13621
    import std.container : Array, BinaryHeap;
    alias Heap = BinaryHeap!(Array!int);
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
    auto c = a ~ b;
    //foreach (e; c) writeln(e);
    assert(c == Array!int(1, 2, 3, 11, 12, 13));
    //assert(a ~ b[] == Array!int(1, 2, 3, 11, 12, 13));
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

// Give the Range object some testing.
unittest
{
    import std.algorithm : equal;
    import std.range : retro;
    auto a = Array!int(0, 1, 2, 3, 4, 5, 6)[];
    auto b = Array!int(6, 5, 4, 3, 2, 1, 0)[];
    alias A = typeof(a);

    static assert(isRandomAccessRange!A);
    static assert(hasSlicing!A);
    static assert(hasAssignableElements!A);
    static assert(hasMobileElements!A);

    assert(equal(retro(b), a));
    assert(a.length == 7);
    assert(equal(a[1..4], [1, 2, 3]));
}
// Test issue 5920
unittest
{
    struct structBug5920
    {
        int order;
        uint* pDestructionMask;
        ~this()
        {
            if (pDestructionMask)
                *pDestructionMask += 1 << order;
        }
    }

    alias S = structBug5920;
    uint dMask;

    auto arr = Array!S(cast(S[])[]);
    foreach (i; 0..8)
        arr.insertBack(S(i, &dMask));
    // don't check dMask now as S may be copied multiple times (it's ok?)
    {
        assert(arr.length == 8);
        dMask = 0;
        arr.length = 6;
        assert(arr.length == 6);    // make sure shrinking calls the d'tor
        assert(dMask == 0b1100_0000);
        arr.removeBack();
        assert(arr.length == 5);    // make sure removeBack() calls the d'tor
        assert(dMask == 0b1110_0000);
        arr.removeBack(3);
        assert(arr.length == 2);    // ditto
        assert(dMask == 0b1111_1100);
        arr.clear();
        assert(arr.length == 0);    // make sure clear() calls the d'tor
        assert(dMask == 0b1111_1111);
    }
    assert(dMask == 0b1111_1111);   // make sure the d'tor is called once only.
}
// Test issue 5792 (mainly just to check if this piece of code is compilable)
unittest
{
    auto a = Array!(int[])([[1,2],[3,4]]);
    a.reserve(4);
    assert(a.capacity >= 4);
    assert(a.length == 2);
    assert(a[0] == [1,2]);
    assert(a[1] == [3,4]);
    a.reserve(16);
    assert(a.capacity >= 16);
    assert(a.length == 2);
    assert(a[0] == [1,2]);
    assert(a[1] == [3,4]);
}

// test replace!Stuff with range Stuff
unittest
{
    import std.algorithm : equal;
    auto a = Array!int([1, 42, 5]);
    a.replace(a[1 .. 2], [2, 3, 4]);
    assert(equal(a[], [1, 2, 3, 4, 5]));
}

// test insertBefore and replace with empty Arrays
unittest
{
    import std.algorithm : equal;
    auto a = Array!int();
    a.insertBefore(a[], 1);
    assert(equal(a[], [1]));
}
unittest
{
    import std.algorithm : equal;
    auto a = Array!int();
    a.insertBefore(a[], [1, 2]);
    assert(equal(a[], [1, 2]));
}
unittest
{
    import std.algorithm : equal;
    auto a = Array!int();
    a.replace(a[], [1, 2]);
    assert(equal(a[], [1, 2]));
}
unittest
{
    import std.algorithm : equal;
    auto a = Array!int();
    a.replace(a[], 1);
    assert(equal(a[], [1]));
}
// make sure that Array instances refuse ranges that don't belong to them
unittest
{
    import std.exception;
    Array!int a = [1, 2, 3];
    auto r = a.dup[];
    assertThrown(a.insertBefore(r, 42));
    assertThrown(a.insertBefore(r, [42]));
    assertThrown(a.insertAfter(r, 42));
    assertThrown(a.replace(r, 42));
    assertThrown(a.replace(r, [42]));
    assertThrown(a.linearRemove(r));
}
unittest
{
    auto a = Array!int([1, 1]);
    a[1]  = 0; //Check Array.opIndexAssign
    assert(a[1] == 0);
    a[1] += 1; //Check Array.opIndexOpAssign
    assert(a[1] == 1);

    //Check Array.opIndexUnary
    ++a[0];
    //a[0]++ //op++ doesn't return, so this shouldn't work, even with 5044 fixed
    assert(a[0] == 2);
    assert(+a[0] == +2);
    assert(-a[0] == -2);
    assert(~a[0] == ~2);

    auto r = a[];
    r[1]  = 0; //Check Array.Range.opIndexAssign
    assert(r[1] == 0);
    r[1] += 1; //Check Array.Range.opIndexOpAssign
    assert(r[1] == 1);

    //Check Array.Range.opIndexUnary
    ++r[0];
    //r[0]++ //op++ doesn't return, so this shouldn't work, even with 5044 fixed
    assert(r[0] == 3);
    assert(+r[0] == +3);
    assert(-r[0] == -3);
    assert(~r[0] == ~3);
}

unittest
{
    import std.algorithm : equal;

    //Test "array-wide" operations
    auto a = Array!int([0, 1, 2]); //Array
    a[] += 5;
    assert(a[].equal([5, 6, 7]));
    ++a[];
    assert(a[].equal([6, 7, 8]));
    a[1 .. 3] *= 5;
    assert(a[].equal([6, 35, 40]));
    a[0 .. 2] = 0;
    assert(a[].equal([0, 0, 40]));

    //Test empty array
    auto a2 = Array!int.init;
    ++a2[];
    ++a2[0 .. 0];
    a2[] = 0;
    a2[0 .. 0] = 0;
    a2[] += 0;
    a2[0 .. 0] += 0;

    //Test "range-wide" operations
    auto r = Array!int([0, 1, 2])[]; //Array.Range
    r[] += 5;
    assert(r.equal([5, 6, 7]));
    ++r[];
    assert(r.equal([6, 7, 8]));
    r[1 .. 3] *= 5;
    assert(r.equal([6, 35, 40]));
    r[0 .. 2] = 0;
    assert(r.equal([0, 0, 40]));

    //Test empty Range
    auto r2 = Array!int.init[];
    ++r2[];
    ++r2[0 .. 0];
    r2[] = 0;
    r2[0 .. 0] = 0;
    r2[] += 0;
    r2[0 .. 0] += 0;
}

// Test issue 11194
unittest {
    static struct S {
        int i = 1337;
        void* p;
        this(this) { assert(i == 1337); }
        ~this() { assert(i == 1337); }
    }
    Array!S arr;
    S s;
    arr ~= s;
    arr ~= s;
}

unittest //11459
{
    static struct S
    {
        bool b;
        alias b this;
    }
    alias A = Array!S;
    alias B = Array!(shared bool);
}

unittest //11884
{
    import std.algorithm : filter;
    auto a = Array!int([1, 2, 2].filter!"true"());
}

unittest //8282
{
    auto arr = new Array!int;
}

unittest //6998
{
    static int i = 0;
    class C
    {
        int dummy = 1;
        this(){++i;}
        ~this(){--i;}
    }

    assert(i == 0);
    auto c = new C();
    assert(i == 1);

    //scope
    {
        auto arr = Array!C(c);
        assert(i == 1);
    }
    //Array should not have destroyed the class instance
    assert(i == 1);

    //Just to make sure the GC doesn't collect before the above test.
    assert(c.dummy ==1);
}
unittest //6998-2
{
    static class C {int i;}
    auto c = new C;
    c.i = 42;
    Array!C a;
    a ~= c;
    a.clear;
    assert(c.i == 42); //fails
}

unittest
{
    static assert(is(Array!int.Range));
    static assert(is(Array!int.ConstRange));
}

unittest // const/immutable Array and Ranges
{
    static void test(A, R, E, S)()
    {
        A a;
        R r = a[];
        assert(r.empty);
        assert(r.length == 0);
        static assert(is(typeof(r.front) == E));
        static assert(is(typeof(r.back) == E));
        static assert(is(typeof(r[0]) == E));
        static assert(is(typeof(r[]) == S));
        static assert(is(typeof(r[0 .. 0]) == S));
    }

    alias A = Array!int;

    test!(A, A.Range, int, A.Range);
    test!(A, const A.Range, const int, A.ConstRange);

    test!(const A, A.ConstRange, const int, A.ConstRange);
    test!(const A, const A.ConstRange, const int, A.ConstRange);

    test!(immutable A, A.ImmutableRange, immutable int, A.ImmutableRange);
    test!(immutable A, const A.ImmutableRange, immutable int, A.ImmutableRange);
    test!(immutable A, immutable A.ImmutableRange, immutable int,
        A.ImmutableRange);
}


////////////////////////////////////////////////////////////////////////////////
// Array!bool
////////////////////////////////////////////////////////////////////////////////

/**
_Array specialized for $(D bool). Packs together values efficiently by
allocating one bit per element.
 */
struct Array(T)
if (is(Unqual!T == bool))
{
    import std.exception : enforce;
    import std.typecons : RefCounted, RefCountedAutoInitialize;

    static immutable uint bitsPerWord = size_t.sizeof * 8;
    private static struct Data
    {
        Array!size_t.Payload _backend;
        size_t _length;
    }
    private RefCounted!(Data, RefCountedAutoInitialize.no) _store;

    private @property ref size_t[] data()
    {
        assert(_store.refCountedStore.isInitialized);
        return _store._backend._payload;
    }

    /**
       Defines the container's primary range.
     */
    struct Range
    {
        private Array _outer;
        private size_t _a, _b;
        /// Range primitives
        @property Range save()
        {
            version (bug4437)
            {
                return this;
            }
            else
            {
                auto copy = this;
                return copy;
            }
        }
        /// Ditto
        @property bool empty()
        {
            return _a >= _b || _outer.length < _b;
        }
        /// Ditto
        @property T front()
        {
            enforce(!empty);
            return _outer[_a];
        }
        /// Ditto
        @property void front(bool value)
        {
            enforce(!empty);
            _outer[_a] = value;
        }
        /// Ditto
        T moveFront()
        {
            enforce(!empty);
            return _outer.moveAt(_a);
        }
        /// Ditto
        void popFront()
        {
            enforce(!empty);
            ++_a;
        }
        /// Ditto
        @property T back()
        {
            enforce(!empty);
            return _outer[_b - 1];
        }
        /// Ditto
        @property void back(bool value)
        {
            enforce(!empty);
            _outer[_b - 1] = value;
        }
        /// Ditto
        T moveBack()
        {
            enforce(!empty);
            return _outer.moveAt(_b - 1);
        }
        /// Ditto
        void popBack()
        {
            enforce(!empty);
            --_b;
        }
        /// Ditto
        T opIndex(size_t i)
        {
            return _outer[_a + i];
        }
        /// Ditto
        void opIndexAssign(T value, size_t i)
        {
            _outer[_a + i] = value;
        }
        /// Ditto
        T moveAt(size_t i)
        {
            return _outer.moveAt(_a + i);
        }
        /// Ditto
        @property size_t length() const
        {
            assert(_a <= _b);
            return _b - _a;
        }
        alias opDollar = length;
        /// ditto
        Range opSlice(size_t low, size_t high)
        {
            assert(_a <= low && low <= high && high <= _b);
            return Range(_outer, _a + low, _a + high);
        }
    }

    /**
       Property returning $(D true) if and only if the container has
       no elements.

       Complexity: $(BIGOH 1)
     */
    @property bool empty()
    {
        return !length;
    }

    unittest
    {
        Array!bool a;
        //a._store._refCountedDebug = true;
        assert(a.empty);
        a.insertBack(false);
        assert(!a.empty);
    }

    /**
       Returns a duplicate of the container. The elements themselves
       are not transitively duplicated.

       Complexity: $(BIGOH n).
     */
    @property Array dup()
    {
        Array result;
        result.insertBack(this[]);
        return result;
    }

    unittest
    {
        Array!bool a;
        assert(a.empty);
        auto b = a.dup;
        assert(b.empty);
        a.insertBack(true);
        assert(b.empty);
    }

    /**
       Returns the number of elements in the container.

       Complexity: $(BIGOH log(n)).
    */
    @property size_t length() const
    {
        return _store.refCountedStore.isInitialized ? _store._length : 0;
    }
    size_t opDollar() const
    {
        return length;
    }

    unittest
    {
        import std.conv : to;
        Array!bool a;
        assert(a.length == 0);
        a.insert(true);
        assert(a.length == 1, to!string(a.length));
    }

    /**
       Returns the maximum number of elements the container can store
       without (a) allocating memory, (b) invalidating iterators upon
       insertion.

       Complexity: $(BIGOH log(n)).
     */
    @property size_t capacity()
    {
        return _store.refCountedStore.isInitialized
            ? cast(size_t) bitsPerWord * _store._backend.capacity
            : 0;
    }

    unittest
    {
        import std.conv : to;
        Array!bool a;
        assert(a.capacity == 0);
        foreach (i; 0 .. 100)
        {
            a.insert(true);
            assert(a.capacity >= a.length, to!string(a.capacity));
        }
    }

    /**
       Ensures sufficient capacity to accommodate $(D n) elements.

       Postcondition: $(D capacity >= n)

       Complexity: $(BIGOH log(e - capacity)) if $(D e > capacity),
       otherwise $(BIGOH 1).
     */
    void reserve(size_t e)
    {
        import std.conv : to;
        _store.refCountedStore.ensureInitialized();
        _store._backend.reserve(to!size_t((e + bitsPerWord - 1) / bitsPerWord));
    }

    unittest
    {
        Array!bool a;
        assert(a.capacity == 0);
        a.reserve(15657);
        assert(a.capacity >= 15657);
    }

    /**
       Returns a range that iterates over all elements of the
       container, in a container-defined order. The container should
       choose the most convenient and fast method of iteration for $(D
       opSlice()).

       Complexity: $(BIGOH log(n))
     */
    Range opSlice()
    {
        return Range(this, 0, length);
    }

    unittest
    {
        Array!bool a;
        a.insertBack([true, false, true, true]);
        assert(a[].length == 4);
    }

    /**
       Returns a range that iterates the container between two
       specified positions.

       Complexity: $(BIGOH log(n))
     */
    Range opSlice(size_t a, size_t b)
    {
        enforce(a <= b && b <= length);
        return Range(this, a, b);
    }

    unittest
    {
        Array!bool a;
        a.insertBack([true, false, true, true]);
        assert(a[0 .. 2].length == 2);
    }

    /**
       Equivalent to $(D opSlice().front) and $(D opSlice().back),
       respectively.

       Complexity: $(BIGOH log(n))
     */
    @property bool front()
    {
        enforce(!empty);
        return data.ptr[0] & 1;
    }

    /// Ditto
    @property void front(bool value)
    {
        enforce(!empty);
        if (value) data.ptr[0] |= 1;
        else data.ptr[0] &= ~cast(size_t) 1;
    }

    unittest
    {
        Array!bool a;
        a.insertBack([true, false, true, true]);
        assert(a.front);
        a.front = false;
        assert(!a.front);
    }

    /// Ditto
    @property bool back()
    {
        enforce(!empty);
        return cast(bool)(data.back & (cast(size_t)1 << ((_store._length - 1) % bitsPerWord)));
    }

    /// Ditto
    @property void back(bool value)
    {
        enforce(!empty);
        if (value)
        {
            data.back |= (cast(size_t)1 << ((_store._length - 1) % bitsPerWord));
        }
        else
        {
            data.back &=
                ~(cast(size_t)1 << ((_store._length - 1) % bitsPerWord));
        }
    }

    unittest
    {
        Array!bool a;
        a.insertBack([true, false, true, true]);
        assert(a.back);
        a.back = false;
        assert(!a.back);
    }

    /**
       Indexing operators yield or modify the value at a specified index.
     */
    bool opIndex(size_t i)
    {
        auto div = cast(size_t) (i / bitsPerWord);
        auto rem = i % bitsPerWord;
        enforce(div < data.length);
        return cast(bool)(data.ptr[div] & (cast(size_t)1 << rem));
    }
    /// ditto
    void opIndexAssign(bool value, size_t i)
    {
        auto div = cast(size_t) (i / bitsPerWord);
        auto rem = i % bitsPerWord;
        enforce(div < data.length);
        if (value) data.ptr[div] |= (cast(size_t)1 << rem);
        else data.ptr[div] &= ~(cast(size_t)1 << rem);
    }
    /// ditto
    void opIndexOpAssign(string op)(bool value, size_t i)
    {
        auto div = cast(size_t) (i / bitsPerWord);
        auto rem = i % bitsPerWord;
        enforce(div < data.length);
        auto oldValue = cast(bool) (data.ptr[div] & (cast(size_t)1 << rem));
        // Do the deed
        auto newValue = mixin("oldValue "~op~" value");
        // Write back the value
        if (newValue != oldValue)
        {
            if (newValue) data.ptr[div] |= (cast(size_t)1 << rem);
            else data.ptr[div] &= ~(cast(size_t)1 << rem);
        }
    }
    /// Ditto
    T moveAt(size_t i)
    {
        return this[i];
    }

    unittest
    {
        Array!bool a;
        a.insertBack([true, false, true, true]);
        assert(a[0] && !a[1]);
        a[0] &= a[1];
        assert(!a[0]);
    }

    /**
       Returns a new container that's the concatenation of $(D this)
       and its argument.

       Complexity: $(BIGOH n + m), where m is the number of elements
       in $(D stuff)
     */
    Array!bool opBinary(string op, Stuff)(Stuff rhs) if (op == "~")
    {
        auto result = this;
        return result ~= rhs;
    }

    unittest
    {
        import std.algorithm : equal;
        Array!bool a;
        a.insertBack([true, false, true, true]);
        Array!bool b;
        b.insertBack([true, true, false, true]);
        assert(equal((a ~ b)[],
                        [true, false, true, true, true, true, false, true]));
    }

    // /// ditto
    // TotalContainer opBinaryRight(Stuff, string op)(Stuff lhs) if (op == "~")
    // {
    //     assert(0);
    // }

    /**
       Forwards to $(D insertAfter(this[], stuff)).
     */
    // @@@BUG@@@
    //ref Array!bool opOpAssign(string op, Stuff)(Stuff stuff) if (op == "~")
    Array!bool opOpAssign(string op, Stuff)(Stuff stuff) if (op == "~")
    {
        static if (is(typeof(stuff[]))) insertBack(stuff[]);
        else insertBack(stuff);
        return this;
    }

    unittest
    {
        import std.algorithm : equal;
        Array!bool a;
        a.insertBack([true, false, true, true]);
        Array!bool b;
        a.insertBack([false, true, false, true, true]);
        a ~= b;
        assert(equal(
                    a[],
                    [true, false, true, true, false, true, false, true, true]));
    }

    /**
       Removes all contents from the container. The container decides
       how $(D capacity) is affected.

       Postcondition: $(D empty)

       Complexity: $(BIGOH n)
     */
    void clear()
    {
        this = Array();
    }

    unittest
    {
        Array!bool a;
        a.insertBack([true, false, true, true]);
        a.clear();
        assert(a.capacity == 0);
    }

    /**
       Sets the number of elements in the container to $(D
       newSize). If $(D newSize) is greater than $(D length), the
       added elements are added to the container and initialized with
       $(D ElementType.init).

       Complexity: $(BIGOH abs(n - newLength))

       Postcondition: $(D _length == newLength)
     */
    @property void length(size_t newLength)
    {
        import std.conv : to;
        _store.refCountedStore.ensureInitialized();
        auto newDataLength =
            to!size_t((newLength + bitsPerWord - 1) / bitsPerWord);
        _store._backend.length = newDataLength;
        _store._length = newLength;
    }

    unittest
    {
        Array!bool a;
        a.length = 1057;
        assert(a.length == 1057);
        foreach (e; a)
        {
            assert(!e);
        }
    }

    /**
       Inserts $(D stuff) in the container. $(D stuff) can be a value
       convertible to $(D ElementType) or a range of objects
       convertible to $(D ElementType).

       The $(D stable) version guarantees that ranges iterating over
       the container are never invalidated. Client code that counts on
       non-invalidating insertion should use $(D stableInsert).

       Returns: The number of elements added.

       Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
       elements in $(D stuff)
     */
    alias insert = insertBack;
    ///ditto
    alias stableInsert = insertBack;

    /**
       Same as $(D insert(stuff)) and $(D stableInsert(stuff))
       respectively, but relax the complexity constraint to linear.
     */
    alias linearInsert = insertBack;
    ///ditto
    alias stableLinearInsert = insertBack;

    /**
       Picks one value in the container, removes it from the
       container, and returns it. The stable version behaves the same,
       but guarantees that ranges iterating over the container are
       never invalidated.

       Precondition: $(D !empty)

       Returns: The element removed.

       Complexity: $(BIGOH log(n))
     */
    T removeAny()
    {
        auto result = back;
        removeBack();
        return result;
    }
    /// ditto
    alias stableRemoveAny = removeAny;

    unittest
    {
        Array!bool a;
        a.length = 1057;
        assert(!a.removeAny());
        assert(a.length == 1056);
        foreach (e; a)
        {
            assert(!e);
        }
    }

    /**
       Inserts $(D value) to the back of the container. $(D stuff) can
       be a value convertible to $(D ElementType) or a range of
       objects convertible to $(D ElementType). The stable version
       behaves the same, but guarantees that ranges iterating over the
       container are never invalidated.

       Returns: The number of elements inserted

       Complexity: $(BIGOH log(n))
     */
    size_t insertBack(Stuff)(Stuff stuff) if (is(Stuff : bool))
    {
        _store.refCountedStore.ensureInitialized();
        auto rem = _store._length % bitsPerWord;
        if (rem)
        {
            // Fits within the current array
            if (stuff)
            {
                data[$ - 1] |= (1u << rem);
            }
            else
            {
                data[$ - 1] &= ~(1u << rem);
            }
        }
        else
        {
            // Need to add more data
            _store._backend.insertBack(stuff);
        }
        ++_store._length;
        return 1;
    }
    /// Ditto
    size_t insertBack(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && is(ElementType!Stuff : bool))
    {
        static if (!hasLength!Stuff) size_t result;
        for (; !stuff.empty; stuff.popFront())
        {
            insertBack(stuff.front);
            static if (!hasLength!Stuff) ++result;
        }
        static if (!hasLength!Stuff) return result;
        else return stuff.length;
    }
    /// ditto
    alias stableInsertBack = insertBack;

    /**
       Removes the value at the front or back of the container. The
       stable version behaves the same, but guarantees that ranges
       iterating over the container are never invalidated. The
       optional parameter $(D howMany) instructs removal of that many
       elements. If $(D howMany > n), all elements are removed and no
       exception is thrown.

       Precondition: $(D !empty)

       Complexity: $(BIGOH log(n)).
     */
    void removeBack()
    {
        enforce(_store._length);
        if (_store._length % bitsPerWord)
        {
            // Cool, just decrease the length
            --_store._length;
        }
        else
        {
            // Reduce the allocated space
            --_store._length;
            _store._backend.length = _store._backend.length - 1;
        }
    }
    /// ditto
    alias stableRemoveBack = removeBack;

    /**
       Removes $(D howMany) values at the front or back of the
       container. Unlike the unparameterized versions above, these
       functions do not throw if they could not remove $(D howMany)
       elements. Instead, if $(D howMany > n), all elements are
       removed. The returned value is the effective number of elements
       removed. The stable version behaves the same, but guarantees
       that ranges iterating over the container are never invalidated.

       Returns: The number of elements removed

       Complexity: $(BIGOH howMany * log(n)).
     */
    /// ditto
    size_t removeBack(size_t howMany)
    {
        if (howMany >= length)
        {
            howMany = length;
            clear();
        }
        else
        {
            length = length - howMany;
        }
        return howMany;
    }

    unittest
    {
        Array!bool a;
        a.length = 1057;
        assert(a.removeBack(1000) == 1000);
        assert(a.length == 57);
        foreach (e; a)
        {
            assert(!e);
        }
    }

    /**
       Inserts $(D stuff) before, after, or instead range $(D r),
       which must be a valid range previously extracted from this
       container. $(D stuff) can be a value convertible to $(D
       ElementType) or a range of objects convertible to $(D
       ElementType). The stable version behaves the same, but
       guarantees that ranges iterating over the container are never
       invalidated.

       Returns: The number of values inserted.

       Complexity: $(BIGOH n + m), where $(D m) is the length of $(D stuff)
     */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    {
        import std.algorithm : bringToFront;
        // TODO: make this faster, it moves one bit at a time
        immutable inserted = stableInsertBack(stuff);
        immutable tailLength = length - inserted;
        bringToFront(
            this[r._a .. tailLength],
            this[tailLength .. length]);
        return inserted;
    }
    /// ditto
    alias stableInsertBefore = insertBefore;

    unittest
    {
        import std.conv : to;
        Array!bool a;
        version (bugxxxx)
        {
            a._store.refCountedDebug = true;
        }
        a.insertBefore(a[], true);
        assert(a.length == 1, to!string(a.length));
        a.insertBefore(a[], false);
        assert(a.length == 2, to!string(a.length));
    }

    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        import std.algorithm : bringToFront;
        // TODO: make this faster, it moves one bit at a time
        immutable inserted = stableInsertBack(stuff);
        immutable tailLength = length - inserted;
        bringToFront(
            this[r._b .. tailLength],
            this[tailLength .. length]);
        return inserted;
    }
    /// ditto
    alias stableInsertAfter = insertAfter;

    unittest
    {
        import std.conv : to;
        Array!bool a;
        a.length = 10;
        a.insertAfter(a[0 .. 5], true);
        assert(a.length == 11, to!string(a.length));
        assert(a[5]);
    }
    /// ditto
    size_t replace(Stuff)(Range r, Stuff stuff) if (is(Stuff : bool))
    {
        if (!r.empty)
        {
            // There is room
            r.front = stuff;
            r.popFront();
            linearRemove(r);
        }
        else
        {
            // No room, must insert
            insertBefore(r, stuff);
        }
        return 1;
    }
    /// ditto
    alias stableReplace = replace;

    unittest
    {
        import std.conv : to;
        Array!bool a;
        a.length = 10;
        a.replace(a[3 .. 5], true);
        assert(a.length == 9, to!string(a.length));
        assert(a[3]);
    }

    /**
       Removes all elements belonging to $(D r), which must be a range
       obtained originally from this container. The stable version
       behaves the same, but guarantees that ranges iterating over the
       container are never invalidated.

       Returns: A range spanning the remaining elements in the container that
       initially were right after $(D r).

       Complexity: $(BIGOH n)
     */
    Range linearRemove(Range r)
    {
        import std.algorithm : copy;
        copy(this[r._b .. length], this[r._a .. length]);
        length = length - r.length;
        return this[r._a .. length];
    }
}

unittest
{
    Array!bool a;
    assert(a.empty);
}

unittest
{
    Array!bool arr;
    arr.insert([false, false, false, false]);
    assert(arr.front == false);
    assert(arr.back == false);
    assert(arr[1] == false);
    auto slice = arr[];
    slice = arr[0 .. $];
    slice = slice[1 .. $];
    slice.front = true;
    slice.back = true;
    slice[1] = true;
    assert(slice.front == true);
    assert(slice.back == true);
    assert(slice[1] == true);
    assert(slice.moveFront == true);
    assert(slice.moveBack == true);
    assert(slice.moveAt(1) == true);
}
