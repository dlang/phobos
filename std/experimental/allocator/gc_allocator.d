module std.experimental.allocator.gc_allocator;
import std.experimental.allocator.common;

/**
D's built-in garbage-collected allocator.
 */
struct GCAllocator
{
    import core.memory : GC;
    unittest { testAllocator!(() => GCAllocator.instance); }

    /**
    The alignment is a static constant equal to $(D platformAlignment), which
    ensures proper alignment for any D data type.
    */
    enum uint alignment = platformAlignment;

    /**
    Standard allocator methods per the semantics defined above. The $(D
    deallocate) and $(D reallocate) methods are $(D @system) because they may
    move memory around, leaving dangling pointers in user code.
    */
    @trusted void[] allocate(size_t bytes) shared
    {
        if (!bytes) return null;
        auto p = GC.malloc(bytes);
        return p ? p[0 .. bytes] : null;
    }

    /// Ditto
    @system bool expand(ref void[] b, size_t delta) shared
    {
        if (delta == 0) return true;
        if (b is null)
        {
            b = allocate(delta);
            return b.ptr != null; // we assume allocate will achieve the correct size.
        }
        immutable curLength = GC.sizeOf(b.ptr);
        assert(curLength != 0); // we have a valid GC pointer here
        immutable desired = b.length + delta;
        if(desired > curLength) // check to see if the current block can't hold the data
        {
            immutable sizeRequest = desired - curLength;
            immutable newSize = GC.extend(b.ptr, sizeRequest, sizeRequest);
            if (newSize == 0)
            {
                // expansion unsuccessful
                return false;
            }
            assert(newSize >= desired);
        }
        b = b.ptr[0 .. desired];
        return true;
    }

    /// Ditto
    @system bool reallocate(ref void[] b, size_t newSize) shared
    {
        import core.exception : OutOfMemoryError;
        try
        {
            auto p = cast(ubyte*) GC.realloc(b.ptr, newSize);
            b = p[0 .. newSize];
        }
        catch (OutOfMemoryError)
        {
            // leave the block in place, tell caller
            return false;
        }
        return true;
    }

    /// Ditto
    void[] resolveInternalPointer(void* p) shared
    {
        auto r = GC.addrOf(p);
        if (!r) return null;
        return r[0 .. GC.sizeOf(r)];
    }

    /// Ditto
    @system bool deallocate(void[] b) shared
    {
        GC.free(b.ptr);
        return true;
    }

    /// Ditto
    size_t goodAllocSize(size_t n) shared
    {
        if(n == 0)
            return 0;
        if(n <= 16)
            return 16;

        import core.bitop: bsr;

        auto largestBit = bsr(n-1) + 1;
        if (largestBit <= 12) // 4096 or less
            return size_t(1) << largestBit;

        // larger, we use a multiple of 4096.
        return ((n + 4095) / 4096) * 4096;
    }

    /**
    Returns the global instance of this allocator type. The garbage collected
    allocator is thread-safe, therefore all of its methods and `instance` itself
    are $(D shared).
    */

    static shared GCAllocator instance;

    // Leave it undocummented for now.
    @trusted void collect() shared
    {
        GC.collect();
    }
}

///
unittest
{
    auto buffer = GCAllocator.instance.allocate(1024 * 1024 * 4);
    // deallocate upon scope's end (alternatively: leave it to collection)
    scope(exit) GCAllocator.instance.deallocate(buffer);
    //...
}

unittest
{
    auto b = GCAllocator.instance.allocate(10_000);
    assert(GCAllocator.instance.expand(b, 1));
}

unittest
{
    import core.memory: GC;

    // test allocation sizes
    assert(GCAllocator.instance.goodAllocSize(1) == 16);
    for(size_t s = 16; s <= 8192; s *= 2)
    {
        assert(GCAllocator.instance.goodAllocSize(s) == s);
        assert(GCAllocator.instance.goodAllocSize(s - (s / 2) + 1) == s);

        auto buffer = GCAllocator.instance.allocate(s);
        scope(exit) GCAllocator.instance.deallocate(buffer);

        assert(GC.sizeOf(buffer.ptr) == s);

        auto buffer2 = GCAllocator.instance.allocate(s - (s / 2) + 1);
        scope(exit) GCAllocator.instance.deallocate(buffer2);

        assert(GC.sizeOf(buffer2.ptr) == s);
    }

    // anything above a page is simply rounded up to next page
    assert(GCAllocator.instance.goodAllocSize(4096 * 4 + 1) == 4096 * 5);
}
