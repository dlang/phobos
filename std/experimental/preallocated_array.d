module std.experimental.preallocated_array;


public import std.container.util;
version(unittest) import std.stdio, std.container, std.range, std.algorithm;

/**
Array type that uses a $(XREF2 range, isRandomAccessRange, random access range)
as fixed storage location. No memory is ever allocated. Throws if not enough
space is left for an operation to succeed.
 */
struct PreallocatedArray(Store)
    if (isRandomAccessRange!Store && hasLength!Store)
{

import core.exception, std.algorithm, std.conv, std.exception,
       std.range, std.traits, std.typecons;

/**
    $(XREF2 range, isRandomAccessRange, random access range) that provides
    the same range primitives as $(D Store).

    $(LREF opIndex) and $(LREF opSlice) return values of this type.
 */
    alias Range = Store;

/**
 * The type of the elements that can be stored in this
 * PreallocatedArray.
 */
    alias Element = ElementType!Range;

    private:

    static struct Data 
    {
        Store store;
        size_t length;
    }

    alias Payload = RefCounted!(Data, RefCountedAutoInitialize.no);
    Payload _payload;

    @property
    ref inout(Store) store() inout
    { 
        assert(_payload.refCountedStore().isInitialized);
        return _payload.store; 
    }

    public:
/**
    Constructor taking a random access range of type $(D Store).

    Params:
        store = $(XREF2 range, isRandomAccessRange, random access range) used as a store
        initialLength = the initial length of the PreallocatedArray. If set two $(D 0),
                        all elements in store will be overwritten and if set to
                        $(D range.length) no elements can be inserted into the
                        $(D PreallocatedArray) until some are removed.
 */
    this(Store store, size_t initialLength = size_t.max)
    {
        _payload = Payload(move(store), min(initialLength, store.length));
    }


/**
Comparison for equality.

    Two PreallocatedArrays are equal, if they have the same length and
    corresponding elements are equal.
 */
    bool opEquals(ref const(PreallocatedArray) rhs) const
    {
        return length == rhs.length && equal(store[0 .. length], rhs.store[0 .. length]);
    }
    
/// ditto
    bool opEquals(const(PreallocatedArray) rhs) const
    {
        return this == rhs;
    }

static if (is(typeof(store.dup)))
{
/**
Duplicates the container. The elements themselves are not transitively
duplicated. The underlying store must support $(D .dup) as well.

Complexity: $(BIGOH n).
 */
    @property PreallocatedArray dup()
    {
        return PreallocatedArray(store.dup, length);
    }
}



/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
 */
    @property bool empty() const
    {
        return _payload is Payload.init ? 0 : length == 0;
    }

/**
Returns the number of elements in the container.

Complexity: $(BIGOH 1).
 */
    @property size_t length() const
    {
        return _payload is Payload.init ? 0 : _payload.length;
    }

    /// ditto
    alias opDollar = length;

/**
Set length.
Params:
    nlength = the new length
Precondition: $(D nlength <= capacity)

Complexity: $(BIGOH 1).
 */
    @property void length(size_t nlength) 
    {
        enforceEx!RangeError(nlength <= capacity);
        enforce(_payload.refCountedStore().isInitialized, "Cannot adjust length for uninitialized payload");
        
        size_t start = min(length, nlength);
        size_t stop = max(length, nlength);
        _payload.length = nlength;
        
        for(size_t idx = start; idx < stop; ++idx)
        {
            store[idx] = Element.init;
        }
    }
    
/**
Returns the maximum number of elements the container can store 

Complexity: $(BIGOH 1)
 */
    @property size_t capacity() const
    {
        return _payload is Payload.init ? 0 : store.length;
    }

/**
Returns a $(XREF range, isRandomAccessRange, random access range)
of type $(LREF Range) that iterates over elements of the container, in
forward order.

Complexity: $(BIGOH 1)
 */
    Range opIndex()
    {
        return store[0 .. length];
    }

/**
Returns a range that iterates over elements of the container from
index $(D i) up to (excluding) index $(D j).

Params:
    i = index of first element in result
    j = index of first element not in result.

Precondition: $(D i <= j && j <= length)

Complexity: $(BIGOH 1)
 */
    Range opSlice(size_t i, size_t j)
    {
        boundsCheck(j);
        return store[i .. j];
    }


/**
Forward to $(D opSlice().front) and $(D opSlice().back), respectively.

Precondition: $(D !empty)

Complexity: $(BIGOH 1)
 */
    @property ref Element front()
    {
        boundsCheck(0);
        return store[0];
    }

    /// ditto
    @property ref Element back()
    {
        boundsCheck(0);
        return store[length - 1];
    }

/**
Indexing operators yield or modify the value at a specified index.

Precondition: $(D i < length)

Complexity: $(BIGOH 1)
 */
    ref Element opIndex(size_t i)
    {
        boundsCheck(i);
        return store[i];
    }

/**
Slicing operations execute an operation on an entire slice.

Forwards everything to the underlying range.

Precondition: $(D i < j && j < length)

Complexity: $(BIGOH slice.length)
 */
    void opSliceAssign(Element value)
    {
        store[0 .. length] = value;
    }

    /// ditto
    void opSliceAssign(Element value, size_t i, size_t j)
    {
        boundsCheck(j);
        store[i .. j] = value;
    }

    /// ditto
    void opSliceUnary(string op)()
        if (op == "++" || op == "--")
    {
        mixin(op~"store[];");
    }

    /// ditto
    void opSliceUnary(string op)(size_t i, size_t j)
        if (op == "++" || op == "--")
    {
        mixin(op~"store[i .. j];");
    }

    /// ditto
    void opSliceOpAssign(string op)(Elementvalue)
    {
        mixin("store[] "~op~"= value;");
    }

    /// ditto
    void opSliceOpAssign(string op)(Elementvalue, size_t i, size_t j)
    {
        mixin("store[i .. j] "~op~"= value;");
    }

/**
Forwards to $(LREF insertBack).
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
        removeBack(length);
    }

/**
Releases the underlying store. This PreallocatedArray
instance is unuseable afterwarts.

 */
    Store release()
    {
        auto result = move(store);
        return result[0 .. length];
    }

/**
Picks one value in an unspecified position in the container, removes
it from the container, and returns it. PreallocatedArray forwards removeAny to
removeBack.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH log(n)).
 */
    Element removeAny()
    {
        auto result = move(back);
        removeBack();
        return result;
    }
    /// ditto
    alias stableRemoveAny = removeAny;
/**
Inserts $(D value) to the front or back of the container. $(D stuff)
can be a value convertible to $(D Element) or a $(XREF2 range, isInputRange, range) of objects convertible
to $(D Element). The stable version behaves the same, but guarantees that
ranges iterating over the container are never invalidated.

Params:
    stuff = Either a $(XREF2 range, isInputRange, range) of elements to insert or an value convertible to $(D Element).

Returns: The number of elements inserted

Complexity: $(BIGOH m * log(n)), where $(D m) is the number of
elements in $(D stuff)
 */
    size_t insertBack(Stuff)(Stuff stuff)
        if (isImplicitlyConvertible!(Stuff, Element))
    {
        assert(_payload.refCountedStore.isInitialized);
        if (length == capacity)
            throw new RangeError("not enough room to insert stuff");
        length = length + 1;
        store[length-1] = stuff;
        return 1;
    }

    /// ditto
    size_t insertBack(Stuff)(Stuff stuff)
        if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, Element))
    {
        
        static if (hasLength!Stuff)
        {
            if (stuff.length > (capacity - length))
                throw new RangeError("not enough room to insert stuff");
                
            size_t count = stuff.length;
            while(!stuff.empty)
            {
                insertBack(stuff.front);
                stuff.popFront;
            }
                
            return count;
        }
        else
        {
            size_t count; 
            foreach(s; stuff)
            {
                count += insertBack(s);
            }
        
            return count;
        }
    }

    /// ditto
    alias insert = insertBack;

/**
Removes the value at the back of the container. The stable version
behaves the same, but guarantees that ranges iterating over the
container are never invalidated.

Precondition: $(D !empty)

Complexity: $(BIGOH log(1)).
 */
    void removeBack()
    {
        boundsCheck(0);
        /* static if superfluos? */
        static if (hasElaborateDestructor!Element)
        {
            .destroy(store[length - 1]);
            store[length - 1] = Element.init;
        }
        
        length = length - 1;
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

Params:
    howMany = How many elements should be removed.

Returns: The number of elements removed

Complexity: $(BIGOH howMany).
 */
    size_t removeBack(size_t howMany)
    {
        howMany = min(howMany, length);
        
        foreach(i; 0 .. howMany)
            removeBack();
            
        return howMany;
    }
    
    /// ditto
    alias stableRemoveBack = removeBack;
    
    private void boundsCheck(size_t idx)
    {
        import std.exception;
        import std.string;
        version(D_NoBoundsChecks) {}
        else
        {
            enforceEx!RangeError(idx < length, format("Index %s out of bounds [0-%s]", idx, length));
        }
        
    }
}

/// use static array as store
unittest 
{
    size_t[12] store;
    auto fx = PreallocatedArray!(size_t[])(store[], 0);

    foreach(i; 0 .. store.length)
        fx.insertBack(i);
    
    foreach(i; 1 .. store.length)
        assert(fx[i] > fx[i - 1]);

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
 * Wrap store, which must be a $(XREF2 range, isRandomAccessRange, random access range)
 * in a preallocated array and return it
 */
auto preallocatedArray(Store)(Store s, size_t initialLength = size_t.max)
{
	auto fA = PreallocatedArray!(Store)(s, initialLength);
	return fA;
}

/// create a fixed array over  double[]
unittest
{
	double[] store = new double[100];
	auto fa = preallocatedArray(store, 50);

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
    auto fa1 = preallocatedArray(store, 50);
    fa1[] = 12;

    auto fa2 = preallocatedArray(new double[100], 50);
    fa2[] = 12;
    assert(fa1 == fa2);

    fa2.insertBack([1, 2, 3, 4]);
    assert(fa1 != fa2);
    fa2.removeBack(4);

    auto fa3 = preallocatedArray(fa1.release(), 50);
    assert(fa3 == fa2);
}

// dup
unittest
{
    {
        auto store = Array!int(iota(0, 50));
        auto fa1 = preallocatedArray(store[0 .. 25]);
        auto fa2 = preallocatedArray(store[25 .. $]);

        foreach(i,j; zip(fa1[], retro(fa2[])))
            assert(i + j == 49);

        // cannot dup
        static assert(!is(typeof(fa1.dup)));
    }
    {
        auto store = new int[20];
        auto fa = preallocatedArray(store);
        auto fa2 = fa.dup();

        assert(equal(fa[], fa2[]));
        const fa3 = fa;
        assert(fa3 == fa2);
        fa2[12] = 12;
        assert(!equal(fa[], fa2[]));
    }
}
