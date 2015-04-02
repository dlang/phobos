module std.experimental.allocator.bucketizer;

/**

A $(D Bucketizer) uses distinct allocators for handling allocations of sizes in
the intervals $(D [min, min + step - 1]), $(D [min + step, min + 2 * step - 1]),
$(D [min + 2 * step, min + 3 * step - 1]), $(D ...), $(D [max - step + 1, max]).

$(D Bucketizer) holds a fixed-size array of allocators and dispatches calls to
them appropriately. The size of the array is $(D (max + 1 - min) / step), which
must be an exact division.

Allocations for sizes smaller than $(D min) or larger than $(D max) are illegal
for $(D Bucketizer). To handle them separately, $(D Segregator) may be of use.

*/
struct Bucketizer(Allocator, size_t min, size_t max, size_t step)
{
    import std.traits : hasMember;
    import std.experimental.allocator.common : roundUpToMultipleOf;

    static assert((max - (min - 1)) % step == 0,
        "Invalid limits when instantiating " ~ Bucketizer.stringof);

    //static if (min == chooseAtRuntime) size_t _min;
    //else alias _min = min;
    //static if (max == chooseAtRuntime) size_t _max;
    //else alias _max = max;
    //static if (step == chooseAtRuntime) size_t _step;
    //else alias _step = step;

    /// The array of allocators is publicly available for e.g. initialization
    /// and inspection.
    Allocator[(max - (min - 1)) / step] buckets;

    /**
    The alignment offered is the same as $(D Allocator.alignment).
    */
    enum uint alignment = Allocator.alignment;

    /**
    Rounds up to the maximum size of the bucket in which $(D bytes) falls.
    */
    size_t goodAllocSize(size_t bytes) const
    {
        // round up bytes such that bytes - min + 1 is a multiple of step
        assert(bytes >= min);
        const min_1 = min - 1;
        return min_1 + roundUpToMultipleOf(bytes - min_1, step);
    }

    /**
    Returns $(D b.length >= min && b.length <= max).
    */
    bool owns(void[] b) const
    {
        return b.length >= min && b.length <= max;
    }

    /**
    Directs the call to either one of the $(D buckets) allocators.
    */
    void[] allocate(size_t bytes)
    {
        // Choose the appropriate allocator
        const i = (bytes - min) / step;
        assert(i < buckets.length);
        const actual = goodAllocSize(bytes);
        auto result = buckets[i].allocate(actual);
        return result.ptr[0 .. bytes];
    }

    /**
    This method allows expansion within the respective bucket range. It succeeds
    if both $(D b.length) and $(D b.length + delta) fall in a range of the form
    $(D [min + k * step, min + (k + 1) * step - 1]).
    */
    bool expand(ref void[] b, size_t delta)
    {
        assert(b.length >= min && b.length <= max);
        const available = goodAllocSize(b.length);
        const desired = b.length + delta;
        if (available < desired) return false;
        b = b.ptr[0 .. desired];
        return true;
    }

    /**
    This method is only defined if $(D Allocator) defines $(D deallocate).
    */
    static if (hasMember!(Allocator, "deallocate"))
    void deallocate(void[] b)
    {
        const i = (b.length - min) / step;
        assert(i < buckets.length);
        const actual = goodAllocSize(b.length);
        buckets.ptr[i].deallocate(b.ptr[0 .. actual]);
    }

    /**
    This method is only defined if all allocators involved define $(D
    deallocateAll), and calls it for each bucket in turn.
    */
    static if (hasMember!(Allocator, "deallocateAll"))
    void deallocateAll()
    {
        foreach (ref a; buckets)
        {
            a.deallocateAll();
        }
    }

    /**
    This method is only defined if all allocators involved define $(D
    resolveInternalPointer), and tries it for each bucket in turn.
    */
    static if (hasMember!(Allocator, "resolveInternalPointer"))
    void[] resolveInternalPointer(void* p)
    {
        foreach (ref a; buckets)
        {
            if (auto r = a.resolveInternalPointer(p)) return r;
        }
        return null;
    }

    static if (hasMember!(Allocator, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            foreach (ref a; buckets)
            {
                a.markAllAsUnused();
            }
        }
        //
        bool markAsUsed(void[] b)
        {
            const i = (b.length - min) / step;
            assert(i < buckets.length);
            const actual = goodAllocSize(b.length);
            return buckets.ptr[i].markAsUsed(b.ptr[0 .. actual]);
        }
        //
        void doneMarking()
        {
            foreach (ref a; buckets)
            {
                a.doneMarking();
            }
        }
    }
}

///
unittest
{
    import std.experimental.allocator.free_list;
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.common;
    Bucketizer!(FreeList!(Mallocator, 0, unbounded),
        65, 512, 64) a;
    auto b = a.allocate(400);
    assert(b.length == 400);
    a.deallocate(b);
}
