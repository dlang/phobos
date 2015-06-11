module std.experimental.allocator.gc_allocator;
import std.experimental.allocator.common;

/**
D's built-in garbage-collected allocator.
 */
struct GCAllocator
{
    import core.memory;
    unittest { testAllocator!(() => GCAllocator.it); }

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
    @trusted bool expand(ref void[] b, size_t delta) shared
    {
        if (delta == 0) return true;
        if (b is null)
        {
            b = allocate(delta);
            return b.length == delta;
        }
        immutable desired = b.length + delta;
        auto newSize = GC.extend(b.ptr, desired, desired);
        if (newSize == 0)
        {
            // expansion unsuccessful
            return false;
        }
        assert(newSize >= desired);
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

    /**
    Returns the global instance of this allocator type. The garbage collected
    allocator is thread-safe, therefore all of its methods and $(D it) itself
    are $(D shared).
    */

    static shared GCAllocator it;

    // Leave it undocummented for now.
    @trusted void collect() shared
    {
        GC.collect();
    }
}

///
unittest
{
    auto buffer = GCAllocator.it.allocate(1024 * 1024 * 4);
    scope(exit) GCAllocator.it.deallocate(buffer); // or leave it to collection
    //...
}

unittest
{
    auto b = GCAllocator.it.allocate(10000);
    assert(GCAllocator.it.expand(b, 1));
}
