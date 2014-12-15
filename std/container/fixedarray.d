module std.container.fixedarray;

import core.exception, std.algorithm, std.conv, std.exception, std.range,
        std.traits, std.typecons;

public import std.container.util;
version(unittest) import std.stdio, std.container;

/**
Array type that uses a random access range as fixed storage location. 
No memory is ever allocated. Throws if not enough space is left
for an operation to succeed. */
struct FixedArray(Store)
    if(isRandomAccessRange!Store && hasLength!Store)
{

/**
    Random access range that provides the same range primitives as Store.
    */
    alias Range = Store;

    private {
        alias T = ElementType!Range;
        Store _store;
        size_t _length;
    }

/**
Constructor taking a random access range
     */
    this(Store s, size_t initialLength = size_t.max)
    {
        _store = s;
        _length = min(initialLength, _store.length);
    }


/**
Comparison for equality.
     */
    bool opEquals(FixedArray rhs)
    {
        return opEquals(rhs);
    }

    /// ditto
    bool opEquals(ref FixedArray rhs)
    {
        if(length != rhs.length)
            return false;
        return equal(_store[0 .. _length], rhs._store[0 .. _length]);
    }

static if(is(typeof(_store.dup())))
{
/**
Duplicates the container. The elements themselves are not transitively
duplicated. The underlying store must support .dup as well.

Complexity: $(BIGOH n).
     */
    @property FixedArray dup()
    {
        return FixedArray(_store.dup, _length);
    }
}



/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
     */
    @property bool empty() const
    {
        return _length == 0;
    }

/**
Returns the number of elements in the container.

Complexity: $(BIGOH 1).
     */
    @property size_t length() const
    {
        return _length;
    }

    /// ditto
    alias opDollar = length;

/**
Set length.

Precondition: $(D nlength <= capacity)

Complexity: $(BIGOH 1).
     */

    @property void length(size_t nlength) 
    {
        version(assert) if (nlength > capacity) throw new RangeError();
        _length = nlength;
    }
/**
Returns the maximum number of elements the container can store 

Complexity: $(BIGOH 1)
     */
    @property size_t capacity() const
    {
        return _store.length;
    }

/**
Returns a range that iterates over elements of the container, in
forward order.

Complexity: $(BIGOH 1)
     */
    Range opIndex()
    {
        return _store[0 .. length];
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
        return _store[i .. j];
    }


/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Precondition: $(D !empty)

Complexity: $(BIGOH 1)
     */
    @property ref T front()
    {
        version (assert) if (empty) throw new RangeError();
        return _store[0];
    }

    /// ditto
    @property ref T back()
    {
        version (assert) if (empty) throw new RangeError();
        return _store[_length - 1];
    }

/**
Indexing operators yield or modify the value at a specified index.

Precondition: $(D i < length)

Complexity: $(BIGOH 1)
     */
    ref T opIndex(size_t i)
    {
        version (assert) if (i >= _length) throw new RangeError();
        return _store[i];
    }

/**
Slicing operations execute an operation on an entire slice.

Forwards everything to the underlying range.

Precondition: $(D i < j && j < length)

Complexity: $(BIGOH slice.length)
     */
    void opSliceAssign(T value)
    {
        _store[0 .. length] = value;
    }

    /// ditto
    void opSliceAssign(T value, size_t i, size_t j)
    {
        version(assert) if(j < length) throw new RangeError;
        _store[i .. j] = value;
    }

    /// ditto
    void opSliceUnary(string op)()
        if(op == "++" || op == "--")
    {
        mixin(op~"_store[];");
    }

    /// ditto
    void opSliceUnary(string op)(size_t i, size_t j)
        if(op == "++" || op == "--")
    {
        mixin(op~"_store[i .. j];");
    }

    /// ditto
    void opSliceOpAssign(string op)(T value)
    {
        mixin("_store[] "~op~"= value;");
    }

    /// ditto
    void opSliceOpAssign(string op)(T value, size_t i, size_t j)
    {
        mixin("_store[i .. j] "~op~"= value;");
    }

/**
Forwards to $(D insertBack(stuff)).
     */
    void opOpAssign(string op, Stuff)(Stuff stuff)
        if (op == "~")
    {
        insertBack(stuff);
    }

/**
Removes all contents from the container. 

Postcondition: $(D empty)

Complexity: $(BIGOH n)
     */
    void clear()
    {
        _length = 0;
    }

/**
Releases the underlying store. This FixedArray
instance is unuseable afterwarts.

     */
    Store release()
    {
        auto result = move(_store);
        return result[0 .. _length];
    }

/**
Picks one value in an unspecified position in the container, removes
it from the container, and returns it. FixedArray forwards removeAny to
removeBack.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH log(n)).
     */
    T removeAny()
    {
        auto result = move(back);
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
    if (isImplicitlyConvertible!(Stuff, T))
    {
        if(length == capacity)
            throw new RangeError("not enough room to insert stuff");
        _store[_length] = stuff;
        ++_length;
        return 1;
    }

    /// ditto
    size_t insertBack(Stuff)(Stuff stuff)
    if(isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        static if(hasLength!Stuff)
        {
            if(stuff.length > (capacity - length))
                throw new RangeError("not enough room to insert stuff");
        }
            
        size_t count;
        foreach(s; stuff)
            count += insertBack(s);
        
        return count;
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
        version(assert) if(empty) throw new RangeError;
        /* static if superfluos? */
        static if (hasElaborateDestructor!T)
            .destroy(_store[length - 1]);
        
        --_length;
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
            foreach (ref e; _store[length - howMany .. length])
                .destroy(e);

        _length -= howMany;
        return howMany;
    }
    /// ditto
    alias stableRemoveBack = removeBack;
}

/// use static array as store
unittest
{
    size_t[12] store;
    auto fx = FixedArray!(size_t[])(store[], 0);

    foreach(i; 0 .. store.length)
        fx.insertBack(i);
    
    foreach(i; 1 .. store.length)
    {
        assert(fx[i] > fx[i - 1]);
    }

    try {
        fx.insertBack(13);
        assert(false);
    }
    catch(RangeError e) {}

    auto firstFive = fx[0 .. 5];
    assert(equal(firstFive, [0, 1, 2, 3, 4]));

    fx[] = 1;
    foreach(i; fx[])
    {
        assert(i == 1);
    }
}

/**
 * Wrap store in a fixedArray and return it
 */
auto fixedArray(Store)(Store s, size_t initialLength = size_t.max)
{
	auto fA = FixedArray!(Store)(s, initialLength);
	return fA;
}

/// create a fixed array over  double[]
unittest
{
	double[] store = new double[100];
	auto fa = fixedArray(store, 50);

	assert(fa.length == 50);
	assert(fa.capacity == 100);

	assert(10 == fa.removeBack(10));
	fa[$-1] = 12.0;
	assert(fa.removeAny() == 12.0);
}


// equality
unittest
{
    double[] store = new double[100];
    auto fa1 = fixedArray(store, 50);
    fa1[] = 12;

    auto fa2 = fixedArray(new double[100], 50);
    fa2[] = 12;
    assert(fa1 == fa2);

    fa2.insertBack([1, 2, 3, 4]);
    assert(fa1 != fa2);
    fa2.removeBack(4);

    auto fa3 = fixedArray(fa1.release(), 50);
    assert(fa3 == fa2);
}

// dup
unittest
{
    {
        auto store = Array!int(iota(0, 50));
        auto fa1 = fixedArray(store[0 .. 25]);
        auto fa2 = fixedArray(store[25 .. $]);

        foreach(i,j; zip(fa1[], retro(fa2[])))
            assert(i + j == 49);

        // cannot dup
        static assert(!is(typeof(fa1.dup)));
    }
    {
        auto store = new int[20];
        auto fa = fixedArray(store);
        auto fa2 = fa.dup();

        assert(equal(fa[], fa2[]));
        fa2[12] = 12;
        assert(!equal(fa[], fa2[]));
    }
}
