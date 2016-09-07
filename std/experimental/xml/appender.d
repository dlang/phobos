/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/*
*   Appender implementation that uses a custom allocator. Meant for internal usage.
*/

module std.experimental.xml.appender;

/*
*   Appender implementation that uses a custom allocator. Meant for internal usage.
*/
package struct Appender(T, Alloc)
{
    import std.experimental.allocator;
    import std.array;
    import std.range.primitives;
    import std.traits;

    Alloc* allocator;
    private Unqual!T[] arr;
    private size_t used;

    public this(ref Alloc alloc)
    {
        allocator = &alloc;
    }
    public this(Alloc* alloc)
    {
        allocator = alloc;
    }

    public void put(U)(U item)
        if(!isInputRange!U)
    {
        static if (isSomeChar!T && isSomeChar!U && T.sizeof < U.sizeof)
        {
            import std.utf : encode, UseReplacementDchar;
            Unqual!T[T.sizeof == 1 ? 4 : 2] encoded;
            auto len = encode!(UseReplacementDchar.yes)(encoded, item);
            put(encoded[0 .. len]);
        }
        else
        {
            ensureAddable(1);
            arr[used++] = cast(T)item;
        }
    }

    public void put(Range)(Range range)
        if (isInputRange!Range)
    {
        static if (isSomeChar!T && is(Unqual!(ElementEncodingType!Range) == Unqual!T))
        {
            auto len = range.length;
            ensureAddable(len);
            arr[used..(used+len)] = range[];
            used += len;
        }
        else static if (!(isSomeChar!T && isSomeChar!(ElementType!Range)) &&
                    is(typeof(range.length) == size_t))
        {
            auto len = range.length;
            ensureAddable(len);

            static if (is(typeof(arr[] = range[])))
            {
                arr[used..(used+len)] = range[];
            }
            else
            {
                import std.conv : emplaceRef;
                foreach (ref it ; arr[used..(used+len)])
                {
                    emplaceRef!T(it, range.front);
                    range.popFront();
                }
            }
            used += len;
        }
        else
        {
            // Generic input range
            for (; !range.empty; range.popFront())
            {
                put(range.front);
            }
        }
    }

    private void ensureAddable(size_t sz)
    {
        import std.algorithm : max;

        if (arr.length - used >= sz)
            return;

        auto requiredGrowth = sz + used - arr.length;

        size_t delta;
        if (arr.length == 0)
            delta = max(8, requiredGrowth);
        if (arr.length < 512)
            delta = max(arr.length, requiredGrowth);
        else
            delta = max(arr.length/2, requiredGrowth);

        if (!arr.length)
        {
            arr = allocator.makeArray!(Unqual!T)(delta);
            assert(arr, "Could not allocate array");
        }
        else
        {
            auto done = allocator.expandArray(arr, delta);
            assert(done, "Could not grow appender array");
        }
    }

    /*
     * Reserve at least newCapacity elements for appending.  Note that more elements
     * may be reserved than requested.  If newCapacity <= capacity, then nothing is
     * done.
     */
    void reserve(size_t newCapacity)
    {
        if (arr)
        {
            if (newCapacity > arr.length)
                ensureAddable(newCapacity - used);
        }
        else
        {
            ensureAddable(newCapacity);
        }
    }

    /*
     * Returns the capacity of the array (the maximum number of elements the
     * managed array can accommodate before triggering a reallocation).  If any
     * appending will reallocate, $(D capacity) returns $(D 0).
     */
    @property size_t capacity() const
    {
        return arr.length;
    }

    /*
     * Returns the managed array.
     */
    @property inout(T)[] data() inout @trusted
    {
        /* @trusted operation:
         * casting Unqual!T[] to inout(T)[]
         */
        return cast(typeof(return))(arr[0..used]);
    }

    /*
     * Clears the managed array.  This allows the elements of the array to be reused
     * for appending.
     */
    void clear() pure nothrow
    {
        used = 0;
    }

    /*
     * Shrinks the managed array to the given length.
     */
    void shrinkTo(size_t newLength) pure nothrow
    {
        assert(used >= newLength, "Trying to shrink appender to a greater size");
        used = newLength;
    }
}

@nogc unittest
{
    import std.experimental.allocator.mallocator;

    static immutable arr1 = [1];
    static immutable arr234 = [2, 3, 4];
    static immutable arr1234 = [1, 2, 3, 4];

    auto app = Appender!(int, shared(Mallocator))(Mallocator.instance);
    assert(app.data is null);

    app.put(1);
    assert(app.data == arr1);

    app.put(arr234);
    assert(app.data == arr1234);
}