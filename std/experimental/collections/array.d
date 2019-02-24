///
module std.experimental.collections.array;

import std.experimental.collections.common;

debug(CollectionArray) import std.stdio;

version(unittest)
{
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.building_blocks.stats_collector;
    import std.experimental.allocator : RCIAllocator, RCISharedAllocator,
           allocatorObject, sharedAllocatorObject;
    import std.stdio;

    private alias SCAlloc = StatsCollector!(Mallocator, Options.bytesUsed);
}

/**
Array container.
Not fully public yet.
*/
struct Array(T)
{
    import std.experimental.allocator : RCIAllocator, RCISharedAllocator,
           make, dispose, stateSize;
    import std.experimental.allocator.building_blocks.affix_allocator;
    import std.traits : isImplicitlyConvertible, Unqual, isArray;
    import std.range.primitives : isInputRange, isInfinite, ElementType, hasLength;
    import std.conv : emplace;
    import core.atomic : atomicOp;
    import std.algorithm.mutation : move;

    package T[] _payload;
    package Unqual!T[] _support;

private:

    static enum double capacityFactor = 3.0 / 2;
    static enum initCapacity = 3;

    mixin(allocatorHandler);

    @nogc nothrow pure @trusted
    void addRef(SupportQual, this Q)(SupportQual support)
    {
        assert(support !is null);
        cast(void) _allocator.opPrefix!("+=")(support, 1);
    }

    void delRef(Unqual!T[] support)
    {
        // Will be optimized away, but the type system infers T's safety
        if (0) { T t = T.init; }

        assert(support !is null);
        if (_allocator.opPrefix!("-=")(support, 1) == 0)
        {
            () @trusted { dispose(_allocator, support); }();
        }
    }

    static string immutableInsert(StuffType)(string stuff)
    {
        static if (hasLength!StuffType)
        {
            auto stuffLengthStr = q{
                size_t stuffLength = } ~ stuff ~ ".length;";
        }
        else
        {
            auto stuffLengthStr = q{
                import std.range.primitives : walkLength;
                size_t stuffLength = walkLength(} ~ stuff ~ ");";
        }

        return stuffLengthStr ~ q{
        _allocator = immutable AllocatorHandler(allocator);
        auto tmpSupport = (() @trusted => cast(Unqual!T[])(_allocator.allocate(stuffLength * T.sizeof)))();
        assert(stuffLength == 0 || (stuffLength > 0 && tmpSupport !is null));
        size_t i = 0;
        foreach (item; } ~ stuff ~ q{)
        {
          (() @trusted => emplace(&tmpSupport[i++], item))();
        }
        _support = (() @trusted => cast(typeof(_support))(tmpSupport))();
        _payload = (() @trusted => cast(typeof(_payload))(_support[0 .. stuffLength]))();
        if (_support) addRef(_support);
        };
    }

    void destroyUnused()
    {
        debug(CollectionArray)
        {
            writefln("Array.destroyUnused: begin");
            scope(exit) writefln("Array.destroyUnused: end");
        }
        if (_support !is null)
        {
            delRef(_support);
        }
    }

public:
    /**
    Constructs a qualified array that will use the provided
    allocator object. For `immutable` objects, a `RCISharedAllocator` must
    be supplied.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object

    Complexity: $(BIGOH 1)
    */
    this(A, this Q)(A allocator)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator)))
    {
        debug(CollectionArray)
        {
            writefln("Array.ctor: begin");
            scope(exit) writefln("Array.ctor: end");
        }
        static if (is(Q == immutable) || is(Q == const))
        {
            T[] empty;
            this(allocator, empty);
        }
        else
        {
            setAllocator(allocator);
        }
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.experimental.allocator : theAllocator, processAllocator;

        auto a = Array!int(theAllocator);
        auto ca = const Array!int(processAllocator);
        auto ia = immutable Array!int(processAllocator);
    }

    /**
    Constructs a qualified array out of a number of items.
    Because no allocator was provided, the array will use the
    $(REF, GCAllocator, std,experimental,allocator,gc_allocator).

    Params:
         values = a variable number of items, either in the form of a
                  list or as a built-in array

    Complexity: $(BIGOH m), where `m` is the number of items.
    */
    this(U, this Q)(U[] values...) @trusted // TODO fix for -dip1000
    if (isImplicitlyConvertible!(U, T))
    {
        this(defaultAllocator!(typeof(this)), values);
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        // Create a list from a list of ints
        {
            auto a = Array!int(1, 2, 3);
            assert(equal(a, [1, 2, 3]));
        }
        // Create a list from an array of ints
        {
            auto a = Array!int([1, 2, 3]);
            assert(equal(a, [1, 2, 3]));
        }
        // Create a list from a list from an input range
        {
            auto a = Array!int(1, 2, 3);
            auto a2 = Array!int(a);
            assert(equal(a2, [1, 2, 3]));
        }
    }

    /**
    Constructs a qualified array out of a number of items
    that will use the provided allocator object.
    For `immutable` objects, a `RCISharedAllocator` must be supplied.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object
         values = a variable number of items, either in the form of a
                  list or as a built-in array

    Complexity: $(BIGOH m), where `m` is the number of items.
    */
    this(A, U, this Q)(A allocator, U[] values...)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator))
        && isImplicitlyConvertible!(U, T))
    {
        debug(CollectionArray)
        {
            writefln("Array.ctor: begin");
            scope(exit) writefln("Array.ctor: end");
        }
        static if (is(Q == immutable) || is(Q == const))
        {
            mixin(immutableInsert!(typeof(values))("values"));
        }
        else
        {
            setAllocator(allocator);
            insert(0, values);
        }
    }

    /**
    Constructs a qualified array out of an
    $(REF_ALTTEXT input range, isInputRange, std,range,primitives).
    Because no allocator was provided, the array will use the
    $(REF, GCAllocator, std,experimental,allocator,gc_allocator).
    If `Stuff` defines `length`, `Array` will use it to reserve the
    necessary amount of memory.

    Params:
         stuff = an input range of elements that are implitictly convertible
                 to `T`

    Complexity: $(BIGOH m), where `m` is the number of elements in the range.
    */
    this(Stuff, this Q)(Stuff stuff)
    if (isInputRange!Stuff && !isInfinite!Stuff
        && isImplicitlyConvertible!(ElementType!Stuff, T)
        && !is(Stuff == T[]))
    {
        this(defaultAllocator!(typeof(this)), stuff);
    }

    /**
    Constructs a qualified array out of an
    $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
    that will use the provided allocator object.
    For `immutable` objects, a `RCISharedAllocator` must be supplied.
    If `Stuff` defines `length`, `Array` will use it to reserve the
    necessary amount of memory.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object
         stuff = an input range of elements that are implitictly convertible
                 to `T`

    Complexity: $(BIGOH m), where `m` is the number of elements in the range.
    */
    this(A, Stuff, this Q)(A allocator, Stuff stuff)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator))
        && isInputRange!Stuff
        && isImplicitlyConvertible!(ElementType!Stuff, T)
        && !is(Stuff == T[]))
    {
        debug(CollectionArray)
        {
            writefln("Array.ctor: begin");
            scope(exit) writefln("Array.ctor: end");
        }
        static if (is(Q == immutable) || is(Q == const))
        {
            mixin(immutableInsert!(typeof(stuff))("stuff"));
        }
        else
        {
            setAllocator(allocator);
            insert(0, stuff);
        }
    }

    this(this)
    {
        debug(CollectionArray)
        {
            writefln("Array.postblit: begin");
            scope(exit) writefln("Array.postblit: end");
        }
        _allocator.bootstrap();
        if (_support !is null)
        {
            addRef(_support);
            debug(CollectionArray) writefln("Array.postblit: Array %s has refcount: %s",
                    _support, *prefCount(_support));
        }
    }

    // Immutable ctors
    // Very important to pass the allocator by ref! (Related to postblit bug)
    private this(SuppQual, PaylQual, AllocQual, this Qualified)(SuppQual support,
            PaylQual payload, ref AllocQual _newAllocator)
        if (is(typeof(_support) : typeof(support)))
    {
        _support = support;
        _payload = payload;
        // Needs a bootstrap
        // bootstrap is the equivalent of incRef
        _newAllocator.bootstrap();
        _allocator = _newAllocator;
        if (_support !is null)
        {
            addRef(_support);
            debug(CollectionArray) writefln("Array.ctor immutable: Array %s has "
                    ~ "refcount: %s", _support, *prefCount(_support));
        }
    }

    ~this()
    {
        debug(CollectionArray)
        {
            writefln("Array.dtor: Begin for instance %s of type %s",
                cast(size_t)(&this), typeof(this).stringof);
            scope(exit) writefln("Array.dtor: End for instance %s of type %s",
                    cast(size_t)(&this), typeof(this).stringof);
        }
        destroyUnused();
    }

    static if (is(T == int))
    nothrow pure @safe unittest
    {
        auto a = Array!int(1, 2, 3);

        // Infer safety
        static assert(!__traits(compiles, () @safe { Array!Unsafe(Unsafe(1)); }));
        static assert(!__traits(compiles, () @safe { auto a = const Array!Unsafe(Unsafe(1)); }));
        static assert(!__traits(compiles, () @safe { auto a = immutable Array!Unsafe(Unsafe(1)); }));

        static assert(!__traits(compiles, () @safe { Array!UnsafeDtor(UnsafeDtor(1)); }));
        static assert(!__traits(compiles, () @safe { auto s = const Array!UnsafeDtor(UnsafeDtor(1)); }));
        static assert(!__traits(compiles, () @safe { auto s = immutable Array!UnsafeDtor(UnsafeDtor(1)); }));

        // Infer purity
        static assert(!__traits(compiles, () pure { Array!Impure(Impure(1)); }));
        static assert(!__traits(compiles, () pure { auto a = const Array!Impure(Impure(1)); }));
        static assert(!__traits(compiles, () pure { auto a = immutable Array!Impure(Impure(1)); }));

        static assert(!__traits(compiles, () pure { Array!ImpureDtor(ImpureDtor(1)); }));
        static assert(!__traits(compiles, () pure { auto s = const Array!ImpureDtor(ImpureDtor(1)); }));
        static assert(!__traits(compiles, () pure { auto s = immutable Array!ImpureDtor(ImpureDtor(1)); }));

        // Infer throwability
        static assert(!__traits(compiles, () nothrow { Array!Throws(Throws(1)); }));
        static assert(!__traits(compiles, () nothrow { auto a = const Array!Throws(Throws(1)); }));
        static assert(!__traits(compiles, () nothrow { auto a = immutable Array!Throws(Throws(1)); }));

        static assert(!__traits(compiles, () nothrow { Array!ThrowsDtor(ThrowsDtor(1)); }));
        static assert(!__traits(compiles, () nothrow { auto s = const Array!ThrowsDtor(ThrowsDtor(1)); }));
        static assert(!__traits(compiles, () nothrow { auto s = immutable Array!ThrowsDtor(ThrowsDtor(1)); }));
    }

    private @nogc nothrow pure @trusted
    size_t slackFront() const
    {
        return _payload.ptr - _support.ptr;
    }

    private @nogc nothrow pure @trusted
    size_t slackBack() const
    {
        return _support.ptr + _support.length - _payload.ptr - _payload.length;
    }

    /**
    Return the number of elements in the array.

    Returns:
         the length of the array.

    Complexity: $(BIGOH 1).
    */
    @nogc nothrow pure @safe
    size_t length() const
    {
        return _payload.length;
    }

    /// ditto
    alias opDollar = length;

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int(1, 2, 3);
        assert(a.length == 3);
        assert(a[$ - 1] == 3);
    }

    /**
    Set the length of the array to `len`. `len` must be less than or equal
    to the `capacity` of the array.

    Params:
         len = a positive integer

    Complexity: $(BIGOH 1).
    */
    @nogc nothrow pure @trusted
    void forceLength(size_t len)
    {
        assert(len <= capacity);
        _payload = cast(T[])(_support[slackFront .. len]);
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int(1, 2, 3);
        a.forceLength(2);
        assert(a.length == 2);
    }

    /**
    Get the available capacity of the `array`; this is equal to `length` of
    the array plus the available pre-allocated, free, space.

    Returns:
         a positive integer denoting the capacity.

    Complexity: $(BIGOH 1).
    */
    @nogc nothrow pure @safe
    size_t capacity() const
    {
        return length + slackBack;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int(1, 2, 3);
        a.reserve(10);
        assert(a.capacity == 10);
    }

    /**
    Reserve enough memory from the allocator to store `n` elements.
    If the current `capacity` exceeds `n` nothing will happen.
    If `n` exceeds the current `capacity`, an attempt to `expand` the
    current array is made. If `expand` is successful, all the expanded
    elements are default initialized to `T.init`. If the `expand` fails
    a new buffer will be allocated, the old elements of the array will be
    copied and the new elements will be default initialized to `T.init`.

    Params:
         n = a positive integer

    Complexity: $(BIGOH max(length, n)).
    */
    void reserve(size_t n)
    {
        debug(CollectionArray)
        {
            writefln("Array.reserve: begin");
            scope(exit) writefln("Array.reserve: end");
        }

        // Will be optimized away, but the type sistem infers T's safety
        if (0) { T t = T.init; }

        if (n <= capacity) { return; }

        // TODO: why would we want to overwrite the user-defined allocator?
        auto a = threadAllocatorObject();
        setAllocator(a);

        if (_support && _allocator.opCmpPrefix!"=="(_support, 0))
        {
            void[] buf = _support;
            if (_allocator.expand(buf, (n - capacity) * T.sizeof))
            {
                const oldLength = _support.length;
                _support = (() @trusted => cast(Unqual!T[])(buf))();
                // Emplace extended buf
                // TODO: maybe? emplace only if T has indirections
                foreach (i; oldLength .. _support.length)
                {
                    emplace(&_support[i]);
                }
                return;
            }
            else
            {
                assert(0, "Array.reserve: Failed to expand array.");
            }
        }

        auto tmpSupport = (() @trusted => cast(Unqual!T[])(_allocator.allocate(n * T.sizeof)))();
        assert(tmpSupport !is null);
        for (size_t i = 0; i < tmpSupport.length; ++i)
        {
            if (i < _payload.length)
            {
                emplace(&tmpSupport[i], _payload[i]);
            }
            else
            {
                emplace(&tmpSupport[i]);
            }
        }
        //tmpSupport[0 .. _payload.length] = _payload[];
        destroyUnused();
        _support = tmpSupport;
        addRef(_support);
        _payload = (() @trusted => cast(T[])(_support[0 .. _payload.length]))();
        assert(capacity >= n);
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        auto stuff = [1, 2, 3];
        Array!int a;
        a.reserve(stuff.length);
        a ~= stuff;
        assert(equal(a, stuff));
    }

    /**
    Inserts the elements of an
    $(REF_ALTTEXT input range, isInputRange, std,range,primitives), or a
    variable number of items, at the given `pos`.

    If no allocator was provided when the array was created, the
    $(REF, GCAllocator, std,experimental,allocator,gc_allocator) will be used.
    If `Stuff` defines `length`, `Array` will use it to reserve the
    necessary amount of memory.

    Params:
         pos = a positive integer
         stuff = an input range of elements that are implicitly convertible
                 to `T`; a variable number of items either in the form of a
                 list or as a built-in array

    Returns:
         The number of elements inserted

    Complexity: $(BIGOH max(length, pos + m)), where `m` is the number of
                elements in the range.
    */
    size_t insert(Stuff)(size_t pos, Stuff stuff)
    if (!isArray!(typeof(stuff)) && isInputRange!Stuff && !isInfinite!Stuff
        && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        debug(CollectionArray)
        {
            writefln("Array.insert: begin");
            scope(exit) writefln("Array.insert: end");
        }

        // Will be optimized away, but the type system infers T's safety
        if (0) { T t = T.init; }

        auto a = threadAllocatorObject();
        setAllocator(a);

        static if (hasLength!Stuff)
        {
            size_t stuffLength = stuff.length;
        }
        else
        {
            import std.range.primitives : walkLength;
            size_t stuffLength = walkLength(stuff);
        }
        if (stuffLength == 0) return 0;

        auto tmpSupport = (() @trusted => cast(Unqual!T[])(_allocator.allocate(stuffLength * T.sizeof)))();
        assert(stuffLength == 0 || (stuffLength > 0 && tmpSupport !is null));
        // TODO: emplacement is already done in reserve
        for (size_t i = 0; i < tmpSupport.length; ++i)
        {
                emplace(&tmpSupport[i]);
        }

        size_t i = 0;
        foreach (item; stuff)
        {
            tmpSupport[i++] = item;
        }
        size_t result = insert(pos, tmpSupport);
        () @trusted { dispose(_allocator, tmpSupport); }();
        return result;
    }

    /// ditto
    size_t insert(Stuff)(size_t pos, Stuff[] stuff...)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        debug(CollectionArray)
        {
            writefln("Array.insert: begin");
            scope(exit) writefln("Array.insert: end");
        }

        // Will be optimized away, but the type system infers T's safety
        if (0) { T t = T.init; }

        assert(pos <= _payload.length);
        auto a = threadAllocatorObject();
        setAllocator(a);

        if (stuff.length == 0) return 0;
        if (stuff.length > slackBack)
        {
            double newCapacity = capacity ? capacity * capacityFactor : stuff.length;
            while (newCapacity < capacity + stuff.length)
            {
                newCapacity = newCapacity * capacityFactor;
            }
            reserve((() @trusted => cast(size_t)(newCapacity))());
        }
        //_support[pos + stuff.length .. _payload.length + stuff.length] =
            //_support[pos .. _payload.length];
        for (size_t i = _payload.length + stuff.length - 1; i >= pos +
                stuff.length; --i)
        {
            // Avoids underflow if payload is empty
            _support[i] = _support[i - stuff.length];
        }
        _support[pos .. pos + stuff.length] = stuff[];
        _payload = (() @trusted => cast(T[])(_support[0 .. _payload.length + stuff.length]))();
        return stuff.length;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        Array!int a;
        assert(a.empty);

        size_t pos = 0;
        pos += a.insert(pos, 1);
        pos += a.insert(pos, [2, 3]);
        assert(equal(a, [1, 2, 3]));
        assert(pos == 4);
    }

    /**
    Check whether there are no more references to this array instance.

    Returns:
         `true` if this is the only reference to this array instance;
         `false` otherwise.

    Complexity: $(BIGOH 1).
    */
    @nogc nothrow pure @safe
    bool isUnique(this _)()
    {
        debug(CollectionArray)
        {
            writefln("Array.isUnique: begin");
            scope(exit) writefln("Array.isUnique: end");
        }

        if (_support !is null)
        {
            return cast(bool) _allocator.opCmpPrefix!"=="(_support, 1);
        }
        return true;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int(24, 42);
        assert(a.isUnique);
        {
            auto a2 = a;
            assert(!a.isUnique);
            a2.front = 0;
            assert(a.front == 0);
        } // a2 goes out of scope
        assert(a.isUnique);
    }

    /**
    Check if the array is empty.

    Returns:
         `true` if there are no elements in the array; `false` otherwise.

    Complexity: $(BIGOH 1).
    */
    @nogc nothrow pure @safe
    bool empty() const
    {
        return length == 0;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        Array!int a;
        assert(a.empty);
        size_t pos = 0;
        a.insert(pos, 1);
        assert(!a.empty);
    }

    /**
    Provide access to the first element in the array. The user must check
    that the array isn't `empty`, prior to calling this function.

    Returns:
         a reference to the first element.

    Complexity: $(BIGOH 1).
    */
    ref auto front(this _)()
    {
        assert(!empty, "Array.front: Array is empty");
        return _payload[0];
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int(1, 2, 3);
        assert(a.front == 1);
        a.front = 0;
        assert(a.front == 0);
    }

    /**
    Advance to the next element in the array. The user must check
    that the array isn't `empty`, prior to calling this function.

    Complexity: $(BIGOH 1).
    */
    @nogc nothrow pure @safe
    void popFront()
    {
        debug(CollectionArray)
        {
            writefln("Array.popFront: begin");
            scope(exit) writefln("Array.popFront: end");
        }
        assert(!empty, "Array.popFront: Array is empty");
        _payload = _payload[1 .. $];
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto stuff = [1, 2, 3];
        auto a = Array!int(stuff);
        size_t i = 0;
        while (!a.empty)
        {
            assert(a.front == stuff[i++]);
            a.popFront;
        }
        assert(a.empty);
    }

    /**
    Advance to the next element in the array. The user must check
    that the array isn't `empty`, prior to calling this function.

    This must be used in order to iterate through a `const` or `immutable`
    array For a mutable array this is equivalent to calling `popFront`.

    Returns:
         an array that starts with the next element in the original array.

    Complexity: $(BIGOH 1).
    */
    Qualified tail(this Qualified)()
    {
        debug(CollectionArray)
        {
            writefln("Array.tail: begin");
            scope(exit) writefln("Array.tail: end");
        }
        assert(!empty, "Array.tail: Array is empty");

        static if (is(Qualified == immutable) || is(Qualified == const))
        {
            return this[1 .. $];
        }
        else
        {
            return .tail(this);
        }
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto ia = immutable Array!int([1, 2, 3]);
        assert(ia.tail.front == 2);
    }

    /**
    Eagerly iterate over each element in the array and call `fun` over each
    element. This should be used to iterate through `const` and `immutable`
    arrays.

    Normally, the entire array is iterated. If partial iteration (early stopping)
    is desired, `fun` needs to return a value of type
    $(REF Flag, std,typecons)`!"each"` (`Yes.each` to continue iteration, or
    `No.each` to stop).

    Params:
         fun = unary function to apply on each element of the array.

    Returns:
         `Yes.each` if it has iterated through all the elements in the array,
         or `No.each` otherwise.

    Complexity: $(BIGOH n).
    */
static if(0)
{
    template each(alias fun)
    {
        import std.typecons : Flag, Yes, No;
        import std.functional : unaryFun;
        import std.experimental.allocator.collections.slist : SList;

        Flag!"each" each(this Q)()
        if (is (typeof(unaryFun!fun(T.init))))
        {
            alias fn = unaryFun!fun;

            auto sl = SList!(const Array!T)(this);
            while (!sl.empty && !sl.front.empty)
            {
                static if (!is(typeof(fn(T.init)) == Flag!"each"))
                {
                    cast(void) fn(sl.front.front);
                }
                else
                {
                    if (fn(sl.front.front) == No.each)
                        return No.each;
                }
                sl ~= sl.front.tail;
                sl.popFront;
            }
            return Yes.each;
        }
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.typecons : Flag, Yes, No;

        auto ia = immutable Array!int([1, 2, 3]);

        static bool foo(int x) { return x > 0; }
        static Flag!"each" bar(int x) { return x > 1 ? Yes.each : No.each; }

        assert(ia.each!foo == Yes.each);
        assert(ia.each!bar == No.each);
    }
}

    //int opApply(int delegate(const ref T) dg) const
    //{
        //if (_payload.length && dg(_payload[0])) return 1;
        //if (!this.empty) this.tail.opApply(dg);
        //return 0;
    //}

    /**
    Perform a shallow copy of the array.

    Returns:
         a new reference to the current array.

    Complexity: $(BIGOH 1).
    */
    ref auto save(this _)()
    {
        debug(CollectionArray)
        {
            writefln("Array.save: begin");
            scope(exit) writefln("Array.save: end");
        }
        return this;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto stuff = [1, 2, 3];
        auto a = Array!int(stuff);
        size_t i = 0;

        auto tmp = a.save;
        while (!tmp.empty)
        {
            assert(tmp.front == stuff[i++]);
            tmp.popFront;
        }
        assert(tmp.empty);
        assert(!a.empty);
    }

    // TODO: needs to know if _allocator is shared or not
    // We also need to create a tmp array for all the elements
    Array!T idup(this Q)();

    /**
    Perform a copy of the array. This will create a new array that will copy
    the elements of the current array. This will `NOT` call `dup` on the
    elements of the array, regardless if `T` defines it or not.

    Returns:
         a new mutable array.

    Complexity: $(BIGOH n).
    */
    Array!T dup(this Q)()
    {
        debug(CollectionArray)
        {
            writefln("Array.dup: begin");
            scope(exit) writefln("Array.dup: end");
        }
        Array!T result;
        result._allocator = _allocator;

        static if (is(Q == immutable) || is(Q == const))
        {
            result.reserve(length);
            foreach(i; 0 .. length)
            {
                result ~= this[i];
            }
        }
        else
        {
            result.insert(0, this);
        }
        return result;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        auto stuff = [1, 2, 3];
        auto a = immutable Array!int(stuff);
        auto aDup = a.dup;
        assert(equal(aDup, stuff));
        aDup.front = 0;
        assert(aDup.front == 0);
        assert(a.front == 1);
    }

    /**
    Return a slice to the current array. This is equivalent to calling
    `save`.

    Returns:
         an array that references the current array.

    Complexity: $(BIGOH 1)
    */
    Qualified opSlice(this Qualified)()
    {
        debug(CollectionArray)
        {
            writefln("Array.opSlice(): begin");
            scope(exit) writefln("Array.opSlice(): end");
        }
        return this.save;
    }

    /**
    Return a slice to the current array that is bounded by `start` and `end`.
    `start` must be less than or equal to `end` and `end` must be less than
    or equal to `length`.

    Returns:
         an array that references the current array.

    Params:
         start = a positive integer
         end = a positive integer

    Complexity: $(BIGOH 1)
    */
    Qualified opSlice(this Qualified)(size_t start, size_t end)
    in
    {
        assert(start <= end && end <= length,
               "Array.opSlice(s, e): Invalid bounds: Ensure start <= end <= length");
    }
    body
    {
        debug(CollectionArray)
        {
            scope(failure) assert(0, "Array.opSlice");
            writefln("Array.opSlice(%d, %d): begin", start, end);
            scope(exit) writefln("Array.opSlice(%d, %d): end", start, end);
        }
        return typeof(this)(_support, _payload[start .. end], _allocator);
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        auto stuff = [1, 2, 3];
        auto a = Array!int(stuff);
        assert(equal(a[], stuff));
        assert(equal(a[1 .. $], stuff[1 .. $]));
    }

    /**
    Provide access to the element at `idx` in the array.
    `idx` must be less than `length`.

    Returns:
         a reference to the element found at `idx`.

    Params:
         idx = a positive integer

    Complexity: $(BIGOH 1).
    */
    ref auto opIndex(this _)(size_t idx)
    in
    {
        assert(idx < length, "Array.opIndex: Index out of bounds");
    }
    body
    {
        return _payload[idx];
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int([1, 2, 3]);
        assert(a[2] == 3);
    }

    /**
    Apply an unary operation to the element at `idx` in the array.
    `idx` must be less than `length`.

    Returns:
         a reference to the element found at `idx`.

    Params:
         idx = a positive integer

    Complexity: $(BIGOH 1).
    */
    ref auto opIndexUnary(string op)(size_t idx)
    in
    {
        assert(idx < length, "Array.opIndexUnary!" ~ op ~ ": Index out of bounds");
    }
    body
    {
        mixin("return " ~ op ~ "_payload[idx];");
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int([1, 2, 3]);
        int x = --a[2];
        assert(a[2] == 2);
        assert(x == 2);
    }

    /**
    Assign `elem` to the element at `idx` in the array.
    `idx` must be less than `length`.

    Returns:
         a reference to the element found at `idx`.

    Params:
         elem = an element that is implicitly convertible to `T`
         idx = a positive integer

    Complexity: $(BIGOH 1).
    */
    ref auto opIndexAssign(U)(U elem, size_t idx)
    if (isImplicitlyConvertible!(U, T))
    in
    {
        assert(idx < length, "Array.opIndexAssign: Index out of bounds");
    }
    body
    {
        return _payload[idx] = elem;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int([1, 2, 3]);
        a[2] = 2;
        assert(a[2] == 2);
        (a[2] = 3)++;
        assert(a[2] == 4);
    }

    /**
    Assign `elem` to all element in the array.

    Returns:
         a reference to itself

    Params:
         elem = an element that is implicitly convertible to `T`

    Complexity: $(BIGOH n).
    */
    ref auto opIndexAssign(U)(U elem)
    if (isImplicitlyConvertible!(U, T))
    body
    {
        _payload[] = elem;
        return this;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        auto a = Array!int([1, 2, 3]);
        a[] = 0;
        assert(a.equal([0, 0, 0]));
    }

    /**
    Assign `elem` to the element at `idx` in the array.
    `idx` must be less than `length`.

    Returns:
         a reference to the element found at `idx`.

    Params:
         elem = an element that is implicitly convertible to `T`
         indices = a positive integer

    Complexity: $(BIGOH n).
    */
    auto opSliceAssign(U)(U elem, size_t start, size_t end)
    if (isImplicitlyConvertible!(U, T))
    in
    {
        assert(start <= end, "Array.opSliceAssign: Index out of bounds");
        assert(end < length, "Array.opSliceAssign: Index out of bounds");
    }
    body
    {
        return _payload[start .. end] = elem;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        auto a = Array!int([1, 2, 3, 4, 5, 6]);
        a[1 .. 3] = 0;
        assert(a.equal([1, 0, 0, 4, 5, 6]));
    }

    /**
    Assign to the element at `idx` in the array the result of
    $(D a[idx] op elem).
    `idx` must be less than `length`.

    Returns:
         a reference to the element found at `idx`.

    Params:
         elem = an element that is implicitly convertible to `T`
         idx = a positive integer

    Complexity: $(BIGOH 1).
    */
    ref auto opIndexOpAssign(string op, U)(U elem, size_t idx)
    if (isImplicitlyConvertible!(U, T))
    in
    {
        assert(idx < length, "Array.opIndexOpAssign!" ~ op ~ ": Index out of bounds");
    }
    body
    {
        mixin("return _payload[idx]" ~ op ~ "= elem;");
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto a = Array!int([1, 2, 3]);
        a[2] += 2;
        assert(a[2] == 5);
        (a[2] += 3)++;
        assert(a[2] == 9);
    }

    /**
    Create a new array that results from the concatenation of this array
    with `rhs`.

    Params:
         rhs = can be an element that is implicitly convertible to `T`, an
               input range of such elements, or another `Array`

    Returns:
         the newly created array

    Complexity: $(BIGOH n + m), where `m` is the number of elements in `rhs`.
    */
    auto ref opBinary(string op, U)(auto ref U rhs)
        if (op == "~" &&
            (is (U : const typeof(this))
             || is (U : T)
             || (isInputRange!U && isImplicitlyConvertible!(ElementType!U, T))
            ))
    {
        debug(CollectionArray)
        {
            writefln("Array.opBinary!~: begin");
            scope(exit) writefln("Array.opBinary!~: end");
        }

        auto newArray = this.dup();
        static if (is(U : const typeof(this)))
        {
            foreach(i; 0 .. rhs.length)
            {
                newArray ~= rhs[i];
            }
        }
        else
        {
            newArray.insert(length, rhs);
            // Or
            // newArray ~= rhs;
        }
        return newArray;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        auto a = Array!int(1);
        auto a2 = a ~ 2;

        assert(equal(a2, [1, 2]));
        a.front = 0;
        assert(equal(a2, [1, 2]));
    }

    /**
    Assign `rhs` to this array. The current array will now become another
    reference to `rhs`, unless `rhs` is `null`, in which case the current
    array will become empty. If `rhs` refers to the current array nothing will
    happen.

    If there are no more references to the previous array, the previous
    array will be destroyed; this leads to a $(BIGOH n) complexity.

    Params:
         rhs = a reference to an array

    Returns:
         a reference to this array

    Complexity: $(BIGOH n).
    */
    auto ref opAssign()(auto ref typeof(this) rhs)
    {
        debug(CollectionArray)
        {
            scope(failure) assert(0, "Array.opAssign");
            writefln("Array.opAssign: begin: %s", rhs);
            scope(exit) writefln("Array.opAssign: end");
        }

        if (rhs._support !is null && _support is rhs._support)
        {
            if (rhs._payload is _payload)
                return this;
        }

        if (rhs._support !is null)
        {
            rhs.addRef(rhs._support);
            debug(CollectionArray) writefln("Array.opAssign: Array %s has refcount: %s",
                    rhs._payload, *prefCount(rhs._support));
        }
        destroyUnused();
        _support = rhs._support;
        _payload = rhs._payload;
        _allocator = rhs._allocator;
        return this;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        auto a = Array!int(1);
        auto a2 = Array!int(1, 2);

        a = a2; // this will free the old a
        assert(equal(a, [1, 2]));
        a.front = 0;
        assert(equal(a2, [0, 2]));
    }

    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        auto arr = Array!int(1, 2, 3, 4, 5, 6);
        auto arr1 = arr[1 .. $];
        auto arr2 = arr[3 .. $];
        arr1 = arr2;
        assert(arr1.equal([4, 5, 6]));
        assert(arr2.equal([4, 5, 6]));
    }

    /**
    Append the elements of `rhs` at the end of the array.

    If no allocator was provided when the list was created, the
    $(REF, GCAllocator, std,experimental,allocator,gc_allocator) will be used.

    Params:
         rhs = can be an element that is implicitly convertible to `T`, an
               input range of such elements, or another `Array`

    Returns:
         a reference to this array

    Complexity: $(BIGOH n + m), where `m` is the number of elements in `rhs`.
    */
    auto ref opOpAssign(string op, U)(auto ref U rhs)
        if (op == "~" &&
            (is (U == typeof(this))
             || is (U : T)
             || (isInputRange!U && isImplicitlyConvertible!(ElementType!U, T))
            ))
    {
        debug(CollectionArray)
        {
            writefln("Array.opOpAssign!~: %s begin", typeof(this).stringof);
            scope(exit) writefln("Array.opOpAssign!~: %s end", typeof(this).stringof);
        }
        insert(length, rhs);
        return this;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        import std.algorithm.comparison : equal;

        Array!int a;
        auto a2 = Array!int(4, 5);
        assert(a.empty);

        a ~= 1;
        a ~= [2, 3];
        assert(equal(a, [1, 2, 3]));

        // append an input range
        a ~= a2;
        assert(equal(a, [1, 2, 3, 4, 5]));
        a2.front = 0;
        assert(equal(a, [1, 2, 3, 4, 5]));
    }

    ///
    bool opEquals()(auto ref typeof(this) rhs) const
    {
        import std.algorithm.comparison : equal;
        return _support.equal(rhs);
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto arr1 = Array!int(1, 2);
        auto arr2 = Array!int(1, 2);
        auto arr3 = Array!int(2, 3);
        assert(arr1 == arr2);
        assert(arr2 == arr1);
        assert(arr1 != arr3);
        assert(arr3 != arr1);
        assert(arr2 != arr3);
        assert(arr3 != arr2);
    }

    ///
    int opCmp(U)(auto ref U rhs)
    if (isInputRange!U && isImplicitlyConvertible!(ElementType!U, T))
    {
        import std.algorithm.comparison : min, equal;
        import std.math : sgn;
        import std.range.primitives : empty, front, popFront;
        auto r1 = this;
        auto r2 = rhs;
        for (;!r1.empty && !r2.empty; r1.popFront, r2.popFront)
        {
            if (r1.front < r2.front)
                return -1;
            else if (r1.front > r2.front)
                return 1;
        }
        // arrays are equal until here, but it could be that one of them is shorter
        if (r1.empty && r2.empty)
            return 0;
        return r1.empty ? -1 : 1;
    }

    ///
    static if (is(T == int))
    @safe unittest
    {
        auto arr1 = Array!int(1, 2);
        auto arr2 = Array!int(1, 2);
        auto arr3 = Array!int(2, 3);
        auto arr4 = Array!int(0, 3);
        assert(arr1 <= arr2);
        assert(arr2 >= arr1);
        assert(arr1 < arr3);
        assert(arr3 > arr1);
        assert(arr4 < arr1);
        assert(arr4 < arr3);
        assert(arr3 > arr4);
    }

    static if (is(T == int))
    @safe unittest
    {
        auto arr1 = Array!int(1, 2);
        auto arr2 = [1, 2];
        auto arr3 = Array!int(2, 3);
        auto arr4 = [0, 3];
        assert(arr1 <= arr2);
        assert(arr2 >= arr1);
        assert(arr1 < arr3);
        assert(arr3 > arr1);
        assert(arr4 < arr1);
        assert(arr4 < arr3);
        assert(arr3 > arr4);
    }

    ///
    auto toHash() const
    {
        return _support.hashOf;
    }

    ///
    @safe unittest
    {
        auto arr1 = Array!int(1, 2);
        assert(arr1.toHash == Array!int(1, 2).toHash);
        arr1 ~= 3;
        assert(arr1.toHash != Array!int(1, 2).toHash);
        assert(arr1.toHash == Array!int(1, 2, 3).toHash);
        assert(Array!int().toHash == Array!int().toHash);
    }
}

version(unittest) private nothrow pure @safe
void testConcatAndAppend(RCIAllocator allocator)
{
    import std.algorithm.comparison : equal;

    auto a = Array!(int)(allocator, 1, 2, 3);
    Array!(int) a2 = Array!(int)(allocator);

    auto a3 = a ~ a2;
    assert(equal(a3, [1, 2, 3]));

    auto a4 = a3;
    a3 = a3 ~ 4;
    assert(equal(a3, [1, 2, 3, 4]));
    a3 = a3 ~ [5];
    assert(equal(a3, [1, 2, 3, 4, 5]));
    assert(equal(a4, [1, 2, 3]));

    a4 = a3;
    a3 ~= 6;
    assert(equal(a3, [1, 2, 3, 4, 5, 6]));
    a3 ~= [7];

    a3 ~= a3;
    assert(equal(a3, [1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 6, 7]));

    Array!int a5 = Array!(int)(allocator);
    a5 ~= [1, 2, 3];
    assert(equal(a5, [1, 2, 3]));
    auto a6 = a5;
    a5 = a5;
    a5[0] = 10;
    assert(equal(a5, a6));

    // Test concat with mixed qualifiers
    auto a7 = immutable Array!(int)(a5);
    assert(a7.front == 10);
    a5.front = 1;
    assert(a7.front == 10);
    auto a8 = a5 ~ a7;
    assert(equal(a8, [1, 2, 3, 10, 2, 3]));

    auto a9 = const Array!(int)(a5);
    auto a10 = a5 ~ a9;
    assert(equal(a10, [1, 2, 3, 1, 2, 3]));
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testConcatAndAppend(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testSimple(RCIAllocator allocator)
{
    import std.algorithm.comparison : equal;
    import std.algorithm.searching : canFind;

    auto a = Array!int(allocator);
    assert(a.empty);
    assert(a.isUnique);

    size_t pos = 0;
    a.insert(pos, 1, 2, 3);
    assert(a.front == 1);
    assert(equal(a, a));
    assert(equal(a, [1, 2, 3]));

    a.popFront();
    assert(a.front == 2);
    assert(equal(a, [2, 3]));

    a.insert(pos, [4, 5, 6]);
    a.insert(pos, 7);
    a.insert(pos, [8]);
    assert(equal(a, [8, 7, 4, 5, 6, 2, 3]));

    a.insert(a.length, 0, 1);
    a.insert(a.length, [-1, -2]);
    assert(equal(a, [8, 7, 4, 5, 6, 2, 3, 0, 1, -1, -2]));

    a.front = 9;
    assert(equal(a, [9, 7, 4, 5, 6, 2, 3, 0, 1, -1, -2]));

    auto aTail = a.tail;
    assert(aTail.front == 7);
    aTail.front = 8;
    assert(aTail.front == 8);
    assert(a.tail.front == 8);
    assert(!a.isUnique);

    assert(canFind(a, 2));
    assert(!canFind(a, -10));
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testSimple(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testSimpleImmutable(RCIAllocator allocator)
{
    import std.algorithm.comparison : equal;
    import std.algorithm.searching : canFind;

    auto a = Array!(immutable int)(allocator);
    assert(a.empty);

    size_t pos = 0;
    a.insert(pos, 1, 2, 3);
    assert(a.front == 1);
    assert(equal(a, a));
    assert(equal(a, [1, 2, 3]));

    a.popFront();
    assert(a.front == 2);
    assert(equal(a, [2, 3]));
    assert(a.tail.front == 3);

    a.insert(pos, [4, 5, 6]);
    a.insert(pos, 7);
    a.insert(pos, [8]);
    assert(equal(a, [8, 7, 4, 5, 6, 2, 3]));

    a.insert(a.length, 0, 1);
    a.insert(a.length, [-1, -2]);
    assert(equal(a, [8, 7, 4, 5, 6, 2, 3, 0, 1, -1, -2]));

    // Cannot modify immutable values
    static assert(!__traits(compiles, a.front = 9));

    assert(canFind(a, 2));
    assert(!canFind(a, -10));
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testSimpleImmutable(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testCopyAndRef(RCIAllocator allocator)
{
    import std.algorithm.comparison : equal;

    auto aFromList = Array!int(allocator, 1, 2, 3);
    auto aFromRange = Array!int(allocator, aFromList);
    assert(equal(aFromList, aFromRange));

    aFromList.popFront();
    assert(equal(aFromList, [2, 3]));
    assert(equal(aFromRange, [1, 2, 3]));

    size_t pos = 0;
    Array!int aInsFromRange = Array!int(allocator);
    aInsFromRange.insert(pos, aFromList);
    aFromList.popFront();
    assert(equal(aFromList, [3]));
    assert(equal(aInsFromRange, [2, 3]));

    Array!int aInsBackFromRange = Array!int(allocator);
    aInsBackFromRange.insert(pos, aFromList);
    aFromList.popFront();
    assert(aFromList.empty);
    assert(equal(aInsBackFromRange, [3]));

    auto aFromRef = aInsFromRange;
    auto aFromDup = aInsFromRange.dup;
    assert(aInsFromRange.front == 2);
    aFromRef.front = 5;
    assert(aInsFromRange.front == 5);
    assert(aFromDup.front == 2);
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testCopyAndRef(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testImmutability(RCISharedAllocator allocator)
{
    import std.algorithm.comparison : equal;

    auto a = immutable Array!(int)(allocator, 1, 2, 3);
    auto a2 = a;
    auto a3 = a2.save();

    assert(a2.front == 1);
    assert(a2[0] == a2.front);
    static assert(!__traits(compiles, a2.front = 4));
    static assert(!__traits(compiles, a2.popFront()));

    auto a4 = a2.tail;
    assert(a4.front == 2);
    static assert(!__traits(compiles, a4 = a4.tail));

    // Create a mutable copy from an immutable array
    auto a5 = a.dup();
    assert(equal(a5, [1, 2, 3]));
    assert(a5.front == 1);
    a5.front = 2;
    assert(a5.front == 2);
    assert(a.front == 1);
    assert(equal(a5, [2, 2, 3]));
}

version(unittest) private nothrow pure @safe
void testConstness(RCISharedAllocator allocator)
{
    auto a = const Array!(int)(allocator, 1, 2, 3);
    auto a2 = a;
    auto a3 = a2.save();

    assert(a2.front == 1);
    assert(a2[0] == a2.front);
    static assert(!__traits(compiles, a2.front = 4));
    static assert(!__traits(compiles, a2.popFront()));

    auto a4 = a2.tail;
    assert(a4.front == 2);
    static assert(!__traits(compiles, a4 = a4.tail));
}

@safe unittest
{
    import std.conv;
    import std.experimental.allocator : processAllocator;
    SCAlloc statsCollectorAlloc;
    // TODO: StatsCollector needs to be made shareable
    //auto _allocator = sharedAllocatorObject(&statsCollectorAlloc);

    () nothrow pure @safe {
        testImmutability(processAllocatorObject());
        testConstness(processAllocatorObject());
    }();
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testWithStruct(RCIAllocator allocator, RCISharedAllocator sharedAlloc)
{
    import std.algorithm.comparison : equal;

    auto array = Array!int(allocator, 1, 2, 3);
    {
        auto arrayOfArrays = Array!(Array!int)(allocator, array);
        assert(equal(arrayOfArrays.front, [1, 2, 3]));
        arrayOfArrays.front.front = 2;
        assert(equal(arrayOfArrays.front, [2, 2, 3]));
        static assert(!__traits(compiles, arrayOfArrays.insert(1)));

        auto immArrayOfArrays = immutable Array!(Array!int)(sharedAlloc, array);
        assert(immArrayOfArrays.front.front == 2);
        static assert(!__traits(compiles, immArrayOfArrays.front.front = 2));
    }
    assert(equal(array, [2, 2, 3]));
}

@safe unittest
{
    import std.conv;
    import std.experimental.allocator : processAllocator;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testWithStruct(_allocator, processAllocatorObject());
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testWithClass(RCIAllocator allocator)
{
    class MyClass
    {
        int x;
        this(int x) { this.x = x; }
    }

    MyClass c = new MyClass(10);
    {
        auto a = Array!MyClass(allocator, c);
        assert(a.front.x == 10);
        assert(a.front is c);
        a.front.x = 20;
    }
    assert(c.x == 20);
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testWithClass(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testOpOverloads(RCIAllocator allocator)
{
    auto a = Array!int(allocator, 1, 2, 3, 4);
    assert(a[0] == 1); // opIndex

    // opIndexUnary
    ++a[0];
    assert(a[0] == 2);
    --a[0];
    assert(a[0] == 1);
    a[0]++;
    assert(a[0] == 2);
    a[0]--;
    assert(a[0] == 1);

    // opIndexAssign
    a[0] = 2;
    assert(a[0] == 2);

    // opIndexOpAssign
    a[0] /= 2;
    assert(a[0] == 1);
    a[0] *= 2;
    assert(a[0] == 2);
    a[0] -= 1;
    assert(a[0] == 1);
    a[0] += 1;
    assert(a[0] == 2);
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testOpOverloads(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

version(unittest) private nothrow pure @safe
void testSlice(RCIAllocator allocator)
{
    import std.algorithm.comparison : equal;

    auto a = Array!int(allocator, 1, 2, 3, 4);
    auto b = a[];
    assert(equal(a, b));
    b[1] = 5;
    assert(a[1] == 5);

    size_t startPos = 2;
    auto c = b[startPos .. $];
    assert(equal(c, [3, 4]));
    c[0] = 5;
    assert(equal(a, b));
    assert(equal(a, [1, 5, 5, 4]));
    assert(a.capacity == b.capacity && b.capacity == c.capacity + startPos);

    c ~= 5;
    assert(equal(c, [5, 4, 5]));
    assert(equal(a, b));
    assert(equal(a, [1, 5, 5, 4]));
}

@safe unittest
{
    import std.conv;
    SCAlloc statsCollectorAlloc;
    {
        auto _allocator = (() @trusted => allocatorObject(&statsCollectorAlloc))();
        () nothrow pure @safe {
            testSlice(_allocator);
        }();
    }
    auto bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "Array ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");
}

/*@nogc*/ nothrow pure @safe
unittest
{
    Array!int a;
    auto b = Array!int(1, 2, 3);
}
