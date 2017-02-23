///
module std.experimental.allocator.building_blocks.quantizer;

import std.experimental.allocator.common;

/**
This allocator sits on top of `ParentAllocator` and quantizes allocation
sizes, usually from arbitrary positive numbers to a small set of round numbers
(e.g. powers of two, page sizes etc). This technique is commonly used to:

$(UL
$(LI Preallocate more memory than requested such that later on, when
reallocation is needed (e.g. to grow an array), expansion can be done quickly
in place. Reallocation to smaller sizes is also fast (in-place) when the new
size requested is within the same quantum as the existing size. Code that's
reallocation-heavy can therefore benefit from fronting a generic allocator
with a `Quantizer`. These advantages are present even if
`ParentAllocator` does not support reallocation at all.)
$(LI Improve behavior of allocators sensitive to allocation sizes, such as $(D
FreeList) and `FreeTree`. Rounding allocation requests up makes for smaller
free lists/trees at the cost of slack memory (internal fragmentation).)
)

The following methods are forwarded to the parent allocator if present:
`allocateAll`, `owns`, `deallocateAll`, `empty`.

Preconditions: `roundingFunction` must satisfy three constraints. These are
not enforced (save for the use of `assert`) for the sake of efficiency.
$(OL
$(LI `roundingFunction(n) >= n` for all `n` of type `size_t`;)
$(LI `roundingFunction` must be monotonically increasing, i.e. $(D
roundingFunction(n1) <= roundingFunction(n2)) for all `n1 < n2`;)
$(LI `roundingFunction` must be `pure`, i.e. always return the same
value for a given `n`.)
)
*/
struct Quantizer(ParentAllocator, alias roundingFunction)
{
    import std.traits : hasMember;

    /**
    The parent allocator. Depending on whether `ParentAllocator` holds state
    or not, this is a member variable or an alias for
    `ParentAllocator.instance`.
    */
    static if (stateSize!ParentAllocator)
    {
        ParentAllocator parent;
    }
    else
    {
        alias parent = ParentAllocator.instance;
        static __gshared Quantizer instance;
    }

    /**
    Returns `roundingFunction(n)`.
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
    Gets a larger buffer `buf` by calling
    `parent.allocate(goodAllocSize(n))`. If `buf` is `null`, returns
    `null`. Otherwise, returns `buf[0 .. n]`.
    */
    void[] allocate(size_t n)
    {
        auto result = parent.allocate(goodAllocSize(n));
        return result.ptr ? result.ptr[0 .. n] : null;
    }

    /**
    Defined only if `parent.alignedAllocate` exists and works similarly to
    `allocate` by forwarding to
    `parent.alignedAllocate(goodAllocSize(n), a)`.
    */
    static if (hasMember!(ParentAllocator, "alignedAllocate"))
    void[] alignedAllocate(size_t n, uint)
    {
        auto result = parent.alignedAllocate(goodAllocSize(n));
        return result.ptr ? result.ptr[0 .. n] : null;
    }

    /**
    First checks whether there's enough slack memory preallocated for `b`
    by evaluating `b.length + delta <= goodAllocSize(b.length)`. If that's
    the case, expands `b` in place. Otherwise, attempts to use
    `parent.expand` appropriately if present.
    */
    bool expand(ref void[] b, size_t delta)
    {
        if (!b.ptr) return delta == 0;
        immutable allocated = goodAllocSize(b.length),
            needed = b.length + delta,
            neededAllocation = goodAllocSize(needed);
        assert(b.length <= allocated);
        assert(needed <= neededAllocation);
        assert(allocated <= neededAllocation);
        // Second test needed because expand must work for null pointers, too.
        if (allocated == neededAllocation)
        {
            // Nice!
            b = b.ptr[0 .. needed];
            return true;
        }
        // Hail Mary
        static if (hasMember!(ParentAllocator, "expand"))
        {
            // Expand to the appropriate quantum
            auto original = b.ptr[0 .. allocated];
            assert(goodAllocSize(needed) >= allocated);
            if (!parent.expand(original, neededAllocation - allocated))
                return false;
            // Dial back the size
            b = original.ptr[0 .. needed];
            return true;
        }
        else
        {
            return false;
        }
    }

    /**
    Expands or shrinks allocated block to an allocated size of $(D
    goodAllocSize(s)). Expansion occurs in place under the conditions required
    by `expand`. Shrinking occurs in place if `goodAllocSize(b.length)
    == goodAllocSize(s)).
    */
    bool reallocate(ref void[] b, size_t s)
    {
        if (!b.ptr)
        {
            b = allocate(s);
            return b.length == s;
        }
        if (s >= b.length && expand(b, s - b.length)) return true;
        immutable toAllocate = goodAllocSize(s),
            allocated = goodAllocSize(b.length);
        // Are the lengths within the same quantum?
        if (allocated == toAllocate)
        {
            // Reallocation (whether up or down) will be done in place
            b = b.ptr[0 .. s];
            return true;
        }
        // Defer to parent (or global) with quantized size
        auto original = b.ptr[0 .. allocated];
        if (!parent.reallocate(original, toAllocate)) return false;
        b = original.ptr[0 .. s];
        return true;
    }

    /**
    Defined only if `ParentAllocator.alignedAllocate` exists. Expansion
    occurs in place under the conditions required by `expand`. Shrinking
    occurs in place if `goodAllocSize(b.length) == goodAllocSize(s)`.
    */
    static if (hasMember!(ParentAllocator, "alignedAllocate"))
    bool alignedReallocate(ref void[] b, size_t s, uint a)
    {
        if (!b.ptr)
        {
            b = alignedAllocate(s);
            return b.length == s;
        }
        if (s >= b.length && expand(b, s - b.length)) return true;
        immutable toAllocate = goodAllocSize(s),
            allocated = goodAllocSize(b.length);
        // Are the lengths within the same quantum?
        if (allocated == toAllocate)
        {
            assert(b.ptr); // code above must have caught this
            // Reallocation (whether up or down) will be done in place
            b = b.ptr[0 .. s];
            return true;
        }
        // Defer to parent (or global) with quantized size
        auto original = b.ptr[0 .. allocated];
        if (!parent.alignedReallocate(original, toAllocate, a)) return false;
        b = original.ptr[0 .. s];
        return true;
    }

    /**
    Defined if `ParentAllocator.deallocate` exists and forwards to
    `parent.deallocate(b.ptr[0 .. goodAllocSize(b.length)])`.
    */
    static if (hasMember!(ParentAllocator, "deallocate"))
    bool deallocate(void[] b)
    {
        if (!b.ptr) return true;
        return parent.deallocate(b.ptr[0 .. goodAllocSize(b.length)]);
    }

    // Forwarding methods
    mixin(forwardToMember("parent",
        "allocateAll", "owns", "deallocateAll", "empty"));
}

///
@system unittest
{
    import std.experimental.allocator.building_blocks.free_tree : FreeTree;
    import std.experimental.allocator.gc_allocator : GCAllocator;
    import std.experimental.allocator.common : roundUpToMultipleOf;

    // Quantize small allocations to a multiple of cache line, large ones to a
    // multiple of page size
    alias MyAlloc = Quantizer!(
        FreeTree!GCAllocator,
        n => n.roundUpToMultipleOf(n <= 16_384 ? 64 : 4096));
    MyAlloc alloc;
    const buf = alloc.allocate(256);
    assert(buf.ptr);
}

@system unittest
{
    import std.experimental.allocator.gc_allocator : GCAllocator;
    alias MyAlloc = Quantizer!(GCAllocator,
        (size_t n) => n.roundUpToMultipleOf(64));
    testAllocator!(() => MyAlloc());
}
