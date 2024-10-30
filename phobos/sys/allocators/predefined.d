/**
A set of predefined but useful memory allocators.

There are multiple categories of allocators defined here, they are:

- Mapping: Raw memory mapping, for configuring address ranges to hardware.
- House keeping: used for fixed sized memory allocations (not arrays) and are meant for internals to data structures.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.predefined;
import phobos.sys.allocators.api;
import phobos.sys.allocators.buffers.region;
import phobos.sys.allocators.buffers.freelist;
import phobos.sys.allocators.alternatives.allocatorlist;
import phobos.sys.typecons : Ternary;

private
{
    alias HouseKeepingAllocatorTest = HouseKeepingAllocator!RCAllocator;
}

export:

public import phobos.sys.allocators.mapping : DefaultMapper, GoodAlignment;

/// An allocator specializing in fixed size allocations that can be deallocated all at once.
alias HouseKeepingAllocator(MappingAllocator = DefaultMapper, size_t AlignedTo = 0) = HouseKeepingFreeList!(
        AllocatorList!(MappingAllocator,
        (poolAllocator) => Region!(typeof(poolAllocator), AlignedTo)(null, poolAllocator)));

/// Accumulator of memory regions that can be deallocated all at once, not thread safe.
alias MemoryRegionsAllocator(size_t DefaultSize = 0, MappingAllocator = DefaultMapper) = AllocatorList!(
        Region!(MappingAllocator,
        GoodAlignment, DefaultSize), () => Region!(MappingAllocator,
        GoodAlignment, DefaultSize)());

/**
A house keeping allocator that will ensure there are LSB bits available for tags

Use ``(pointer & TaggedPointerHouseKeepingAllocator.Mask)`` to get tags and ``(pointer & TaggedPointerHouseKeepingAllocator.PointerMask)`` to get the pointer.

Warning: ensure that the memory returned has been added as a root to any GC you use, if you store GC memory in it.
*/
template TaggedPointerHouseKeepingAllocator(MappingAllocator = DefaultMapper, int BitsToTag = 1)
{
    static assert(BitsToTag > 0,
            "Zero bits to tag is equivalent to packing memory without any alignment. Must be above zero.");
    static assert(BitsToTag < size_t.sizeof * 4,
            "The number of bits in the tag should be less than half the bits in a pointer...");

    ///
    alias TaggedPointerHouseKeepingAllocator = HouseKeepingAllocator!(MappingAllocator,
            2 ^^ BitsToTag);

    /// Mask to get the bits that contain the tag(s)
    enum Mask = (2 ^^ BitsToTag) - 1;
    /// Mask to get the bits that contain the pointer
    enum PointerMask = ~Mask;
}

version (D_BetterC)
{
}
else
{
    /// The garbage collector
    struct GCAllocator
    {
        ///
        enum NeedsLocking = false;

        __gshared RCAllocatorInstance!GCAllocator instance;

    export @system nothrow @nogc:

        this(ref GCAllocator other)
        {
        }

        ~this()
        {
        }

        bool isNull()
        {
            return false;
        }

        ///
        void[] allocate(size_t amount, TypeInfo ti = null)
        {
            auto got = gcmalloc(amount, 0, ti);

            version (none)
            {
                import core.stdc.stdio;

                debug printf("requested %zd, got %p\n", amount, got);
                debug fflush(stdout);
            }

            if (got is null)
                return null;

            return got[0 .. amount];
        }

        ///
        bool reallocate(ref void[] array, size_t newSize)
        {
            void* newPtr = gcrealloc(array.ptr, newSize);
            if (newPtr is null)
                return false;

            array = newPtr[0 .. newSize];
            return true;
        }

        ///
        bool deallocate(void[] array)
        {
            gcfree(array.ptr);
            return true;
        }

        ///
        Ternary owns(void[] array)
        {
            return gc_sizeOf(array.ptr) > 0 ? Ternary.yes : Ternary.no;
        }
    }
}

private:

version (D_BetterC)
{
}
else
{
    extern (C) @system nothrow @nogc
    {
        pragma(mangle, "gc_malloc") void* gcmalloc(size_t sz, uint ba = 0,
                const scope TypeInfo ti = null);
        pragma(mangle, "gc_realloc") void* gcrealloc(return scope void* p,
                size_t sz, uint ba = 0, const TypeInfo ti = null);
        pragma(mangle, "gc_free") void gcfree(void* p);
        size_t gc_sizeOf(void* p);
    }
}
