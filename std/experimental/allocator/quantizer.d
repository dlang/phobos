module std.experimental.allocator.quantizer;

import std.experimental.allocator.common;

/**
This allocator sits on top of $(D ParentAllocator) and quantizes allocation
sizes, usually from arbitrary positive numbers to a small set of round numbers
(e.g. powers of two, page sizes etc). This technique is commonly used to:

$(UL
$(LI Preallocate more memory than requested such that later on, when
reallocation is needed (e.g. to grow an array), expansion can be done quickly
in place. Reallocation to smaller sizes is also fast (in-place) when the new
size requested is within the same quantum as the existing size. Code that's
reallocation-heavy can therefore benefit from fronting a generic allocator
with a $(D Quantizer). These advantages are present even if
$(D ParentAllocator) does not support reallocation at all.)
$(LI Improve behavior of allocators sensitive to allocation sizes, such as $(D
FreeList) and $(D FreeTree). Rounding allocation requests up makes for smaller
free lists/trees at the cost of slack memory (internal fragmentation).)
)

The following methods are forwarded to the parent allocator if present:
$(D allocateAll), $(D owns), $(D deallocateAll), $(D empty).

Preconditions: $(D roundingFunction(n) >= n) for all $(D n) of type
$(D size_t).
*/
struct Quantizer(ParentAllocator, alias roundingFunction)
{
    import std.traits : hasMember;

    /**
    The parent allocator. Depending on whether $(D ParentAllocator) holds state
    or not, this is a member variable or an alias for $(D ParentAllocator.it).
    */
    static if (stateSize!ParentAllocator)
    {
        ParentAllocator parent;
    }
    else
    {
        alias parent = ParentAllocator.it;
        static __gshared Quantizer it;
    }

    /**
    Returns $(D roundingFunction(n)). It is required that
    $(D roundingFunction(n) >= n). For efficiency reasons, this is only
    $(D assert)ed (checked in debug mode).
    */
    size_t goodAllocSize(size_t n)
    {
        auto result = roundingFunction(n);
        assert(result >= n);
        return result;
    }

    /**
    Alignment is identical to that of the parent.
    */
    enum alignment = ParentAllocator.alignment;

    /**
    Gets a larger buffer $(D buf) by calling
    $(D parent.allocate(goodAllocSize(n))). If $(D buf) is $(D null), returns
    $(D null). Otherwise, returns $(D buf[0 .. n]).
    */
    void[] allocate(size_t n)
    {
        auto result = parent.allocate(goodAllocSize(n));
        return result.ptr ? result.ptr[0 .. n] : null;
    }

    /**
    Defined only if $(D parent.alignedAllocate) exists and works similarly to
    $(D allocate) by forwarding to
    $(D parent.alignedAllocate(goodAllocSize(n), a)).
    */
    static if (hasMember!(ParentAllocator, "alignedAllocate"))
    void[] alignedAllocate(size_t n, uint a)
    {
        auto result = parent.alignedAllocate(goodAllocSize(n));
        return result.ptr ? result.ptr[0 .. n] : null;
    }

    /**
    First checks whether there's enough slack memory preallocated for $(D b)
    by evaluating $(D b.length + delta <= goodAllocSize(b.length)). If that's
    the case, expands $(D b) in place. Otherwise, attempts to use
    $(D parent.expand) appropriately if present.
    */
    bool expand(ref void[] b, size_t delta)
    {
        auto max = goodAllocSize(b.length);
        auto needed = b.length + delta;
        if (max >= needed)
        {
            // Nice!
            b = b.ptr[0 .. needed];
            return true;
        }
        // Hail Mary
        static if (hasMember!(ParentAllocator, "expand"))
        {
            if (!parent.expand(b, goodAllocSize(needed) - b.length))
                return false;
            // Dial back the size
            b = b.ptr[0 .. needed];
            return true;
        }
        else
        {
            return false;
        }
    }

    /**
    In case of shrinkage, shrinks in place if $(D goodAllocSize(s) ==
    goodAllocSize(b.length)), i.e. the existing and requested size fall within the same quantum. In case of expansion, attempts in-place expansion. If
    neither approach succeeds, defers to $(D parent.reallocate(b,
    goodAllocSize(s)).)
    */
    bool reallocate(ref void[] b, size_t s)
    {
        immutable gs = goodAllocSize(s);
        if (s < b.length)
        {
            // Are the lengths within the same quantum?
            if (gs == goodAllocSize(b.length))
            {
                // Reallocation will be done in place
                b = b.ptr[0 .. s];
                return true;
            }
        }
        else if (expand(b, s - b.length))
        {
            return true;
        }
        // Defer to parent (or global) with quantized size
        return parent.reallocate(b, gs);
    }

    /**
    Defined only if $(D ParentAllocator.alignedAllocate) exists. In case of
    shrinkage, shrinks in place if $(D goodAllocSize(s) ==
    goodAllocSize(b.length)), i.e. the existing and requested size fall within
    the same quantum. In case of expansion, attempts in-place expansion. If
    neither approach succeeds, defers to
    $(D parent.alignedReallocate(b, goodAllocSize(s), a)).
    */
    static if (hasMember!(ParentAllocator, "alignedReallocate"))
    bool alignedReallocate(ref void[] b, size_t s, uint a)
    {
        immutable gs = goodAllocSize(s);
        if (s < b.length)
        {
            // Are the lengths within the same quantum?
            if (gs == goodAllocSize(b.length))
            {
                // Reallocation will be done in place
                b = b.ptr[0 .. s];
                return true;
            }
        }
        else if (expand(b, s - b.length))
        {
            return true;
        }
        // Defer to parent (or global) with quantized size
        return parent.alignedReallocate(b, gs, a);
    }

    /**
    Defined if $(D ParentAllocator.deallocate) exists and passes the
    rounded-up buffer to it.
    */
    static if (hasMember!(ParentAllocator, "deallocate"))
    void deallocate(void[] b)
    {
        parent.deallocate(b.ptr[0 .. goodAllocSize(b.length)]);
    }

    /**
    Defined if $(D ParentAllocator.zeroesAllocations) exists.
    */
    static if (hasMember!(ParentAllocator, "zeroesAllocations"))
        alias zeroesAllocations = ParentAllocator.zeroesAllocations;

    // Forwarding methods
    mixin(forwardToMember("parent",
        "allocateAll", "owns", "deallocateAll", "empty"));
}

///
unittest
{
    import std.experimental.allocator.free_tree,
        std.experimental.allocator.gc_allocator;
    // Quantize small allocations to a multiple of cache line, large ones to a
    // multiple of page size
    alias MyAlloc = Quantizer!(
        FreeTree!GCAllocator,
        n => n.roundUpToMultipleOf(n <= 16384 ? 64 : 4096));
    MyAlloc alloc;
    auto buf = alloc.allocate(256);
    assert(buf.ptr);
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    alias MyAlloc = Quantizer!(GCAllocator,
        (size_t n) => n.roundUpToMultipleOf(64));
    testAllocator!(() => MyAlloc());
}
