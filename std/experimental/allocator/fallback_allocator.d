module std.experimental.allocator.fallback_allocator;

import std.experimental.allocator.common;

/**
$(D FallbackAllocator) is the allocator equivalent of an "or" operator in
algebra. An allocation request is first attempted with the $(D Primary)
allocator. If that returns $(D null), the request is forwarded to the $(D
Fallback) allocator. All other requests are dispatched appropriately to one of
the two allocators.

In order to work, $(D FallbackAllocator) requires that $(D Primary) defines the
$(D owns) method. This is needed in order to decide which allocator was
responsible for a given allocation.

$(D FallbackAllocator) is useful for fast, special-purpose allocators backed up
by general-purpose allocators. The example below features a stack region backed
up by the $(D GCAllocator).
*/
struct FallbackAllocator(Primary, Fallback)
{
    import std.algorithm, std.traits;

    unittest
    {
        testAllocator!(() => FallbackAllocator());
    }

    /// The primary allocator.
    static if (stateSize!Primary) Primary primary;
    else alias primary = Primary.it;

    /// The fallback allocator.
    static if (stateSize!Fallback) Fallback fallback;
    else alias fallback = Fallback.it;

    /**
    If both $(D Primary) and $(D Fallback) are stateless, $(D FallbackAllocator)
    defines a static instance $(D it).
    */
    static if (!stateSize!Primary && !stateSize!Fallback)
    {
        static FallbackAllocator it;
    }

    /**
    The alignment offered is the minimum of the two allocators' alignment.
    */
    enum uint alignment = min(Primary.alignment, Fallback.alignment);

    /**
    Allocates memory trying the primary allocator first. If it returns $(D
    null), the fallback allocator is tried.
    */
    void[] allocate(size_t s)
    {
        auto result = primary.allocate(s);
        return result.ptr ? result : fallback.allocate(s);
    }

    /**
    $(D FallbackAllocator) offers $(D alignedAllocate) iff at least one of the
    allocators also offers it. It attempts to allocate using either or both.
    */
    static if (hasMember!(Primary, "alignedAllocate")
        || hasMember!(Fallback, "alignedAllocate"))
    void[] alignedAllocate(size_t s, uint a)
    {
        static if (hasMember!(Primary, "alignedAllocate"))
        {
            auto result = primary.alignedAllocate(s, a);
            if (result.ptr) return result;
        }
        static if (hasMember!(Fallback, "alignedAllocate"))
        {
            auto result = fallback.alignedAllocate(s, a);
            if (result.ptr) return result;
        }
        return null;
    }

    /**

    $(D expand) is defined if and only if at least one of the allocators
    defines $(D expand). It works as follows. If $(D primary.owns(b)), then the
    request is forwarded to $(D primary.expand) if it is defined, or fails
    (returning $(D false)) otherwise. If $(D primary) does not own $(D b), then
    the request is forwarded to $(D fallback.expand) if it is defined, or fails
    (returning $(D false)) otherwise.

    */
    static if (hasMember!(Primary, "expand") || hasMember!(Fallback, "expand"))
    bool expand(ref void[] b, size_t delta)
    {
        if (!delta) return true;
        if (!b.ptr)
        {
            b = allocate(delta);
            return b !is null;
        }
        if (primary.owns(b))
        {
            static if (hasMember!(Primary, "expand"))
                return primary.expand(b, delta);
            else
                return false;
        }
        static if (hasMember!(Fallback, "expand"))
            return fallback.expand(b, delta);
        else
            return false;
    }

    /**

    $(D reallocate) works as follows. If $(D primary.owns(b)), then $(D
    primary.reallocate(b, newSize)) is attempted. If it fails, an attempt is
    made to move the allocation from $(D primary) to $(D fallback).

    If $(D primary) does not own $(D b), then $(D fallback.reallocate(b,
    newSize)) is attempted. If that fails, an attempt is made to move the
    allocation from $(D fallback) to $(D primary).

    */
    bool reallocate(ref void[] b, size_t newSize)
    {
        if (newSize == 0)
        {
            static if (hasMember!(typeof(this), "deallocate"))
                deallocate(b);
            return true;
        }
        if (b is null)
        {
            b = allocate(newSize);
            return b !is null;
        }

        bool crossAllocatorMove(From, To)(ref From from, ref To to)
        {
            auto b1 = to.allocate(newSize);
            if (!b1.ptr) return false;
            if (b.length < newSize) b1[0 .. b.length] = b[];
            else b1[] = b[0 .. newSize];
            static if (hasMember!(From, "deallocate"))
                from.deallocate(b);
            b = b1;
            return true;
        }

        if (b is null || primary.owns(b))
        {
            if (primary.reallocate(b, newSize)) return true;
            // Move from primary to fallback
            return crossAllocatorMove(primary, fallback);
        }
        if (fallback.reallocate(b, newSize)) return true;
        // Interesting. Move from fallback to primary.
        return crossAllocatorMove(fallback, primary);
    }

    static if (hasMember!(Primary, "alignedAllocate")
        || hasMember!(Fallback, "alignedAllocate"))
    bool alignedReallocate(ref void[] b, size_t newSize, uint a)
    {
        bool crossAllocatorMove(From, To)(ref From from, ref To to)
        {
            static if (!hasMember!(To, "alignedAllocate"))
            {
                return false;
            }
            else
            {
                auto b1 = to.alignedAllocate(newSize, a);
                if (!b1) return false;
                if (b.length < newSize) b1[0 .. b.length] = b[];
                else b1[] = b[0 .. newSize];
                static if (hasMember!(From, "deallocate"))
                    from.deallocate(b);
                b = b1;
                return true;
            }
        }

        static if (hasMember!(Primary, "alignedAllocate"))
        {
            if (b is null || primary.owns(b))
            {
                return primary.alignedReallocate(b, newSize, a)
                    || crossAllocatorMove(primary, fallback);
            }
        }
        static if (hasMember!(Fallback, "alignedAllocate"))
        {
            return fallback.alignedReallocate(b, newSize, a)
                || crossAllocatorMove(fallback, primary);
        }
        else
        {
            return false;
        }
    }

    /**
    $(D owns) is defined if and only if both allocators define $(D owns).
    Returns $(D primary.owns(b) || fallback.owns(b)).
    */
    static if (hasMember!(Primary, "owns") && hasMember!(Fallback, "owns"))
    bool owns(void[] p)
    {
        return primary.owns(b) || fallback.owns(p);
    }

    /**
    $(D resolveInternalPointer) is defined if and only if both allocators
    define it.
    */
    static if (hasMember!(Primary, "resolveInternalPointer")
        && hasMember!(Fallback, "resolveInternalPointer"))
    void[] resolveInternalPointer(void* p)
    {
        if (auto r = primary.resolveInternalPointer(p)) return r;
        if (auto r = fallback.resolveInternalPointer(p)) return r;
        return null;
    }

    /**
    $(D deallocate) is defined if and only if at least one of the allocators
    define    $(D deallocate). It works as follows. If $(D primary.owns(b)),
    then the request is forwarded to $(D primary.deallocate) if it is defined,
    or is a no-op otherwise. If $(D primary) does not own $(D b), then the
    request is forwarded to $(D fallback.deallocate) if it is defined, or is a
    no-op otherwise.
    */
    static if (hasMember!(Primary, "deallocate")
        || hasMember!(Fallback, "deallocate"))
    void deallocate(void[] b)
    {
        if (primary.owns(b))
        {
            static if (hasMember!(Primary, "deallocate"))
                primary.deallocate(b);
        }
        else
        {
            static if (hasMember!(Fallback, "deallocate"))
                return fallback.deallocate(b);
        }
    }

    /**
    $(D empty) is defined if both allocators also define it.
    */
    static if (hasMember!(Primary, "empty") && hasMember!(Fallback, "empty"))
    bool empty()
    {
        return primary.empty && fallback.empty;
    }

    /**
    $(D zeroesAllocations) is defined if both allocators also define it.
    */
    static if (hasMember!(Primary, "zeroesAllocations")
        && hasMember!(Fallback, "zeroesAllocations"))
    enum bool zeroesAllocations = Primary.zeroesAllocations
        && Fallback.zeroesAllocations;

    static if (hasMember!(Primary, "markAllAsUnused")
        && hasMember!(Fallback, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            primary.markAllAsUnused();
            fallback.markAllAsUnused();
        }
        //
        bool markAsUsed(void[] b)
        {
            if (primary.owns(b)) primary.markAsUsed(b);
            else fallback.markAsUsed(b);
        }
        //
        void doneMarking()
        {
            primary.doneMarking();
            falback.doneMarking();
        }
    }
}

///
version(none) unittest
{
    import std.experimental.allocator.region;
    FallbackAllocator!(InSituRegion!16384, GCAllocator) a;
    // This allocation uses the stack
    auto b1 = a.allocate(1024);
    assert(b1.length == 1024, text(b1.length));
    assert(a.primary.owns(b1));
    // This large allocation will go to the Mallocator
    auto b2 = a.allocate(1024 * 1024);
    assert(!a.primary.owns(b2));
    a.deallocate(b1);
    a.deallocate(b2);
}
