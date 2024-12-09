/**
List based memory allocation and storage strategies.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.buffers.freelist;
import phobos.sys.allocators.mapping : GoodAlignment;
public import phobos.sys.allocators.buffers.defs : FitsStrategy;
public import phobos.sys.allocators.predefined : HouseKeepingAllocator;
import phobos.sys.allocators.storage.allocatedlist;
import phobos.sys.internal.attribute : hidden;
import phobos.sys.typecons : Ternary;

private
{
    import phobos.sys.allocators.api;

    // guarantee tha each strategy has been initialized
    alias HCFreeList = HouseKeepingFreeList!(RCAllocator);

    alias FreeListFirstFit = FreeList!(RCAllocator, FitsStrategy.FirstFit);
    alias FreeListNextFit = FreeList!(RCAllocator, FitsStrategy.NextFit);
    alias FreeListBestFit = FreeList!(RCAllocator, FitsStrategy.BestFit);
    alias FreeListWorstFit = FreeList!(RCAllocator, FitsStrategy.WorstFit);

}

export:

/**
A free list dedicated for house keeping tasks.

Fixed sized allocations, does not handle alignment, coalesce blocks of memory together nor splitting.

Does not use `TypeInfo`, but will be forwarded on allocation.
*/
struct HouseKeepingFreeList(PoolAllocator)
{
export:
    /// Source for all memory
    PoolAllocator poolAllocator;

    ///
    enum NeedsLocking = true;

    invariant
    {
        assert(head.next is null || !poolAllocator.isNull);

        version (none)
        {
            Node* current = cast(Node*) head.next;
            while (current !is null)
                current = current.next;
        }
    }

    private
    {
        Node head;
    }

@system @nogc nothrow:

    ///
     ~this()
    {
        Node* current = head.next;

        while (current !is null)
        {
            Node* next = current.next;

            poolAllocator.deallocate(current.recreate());

            current = next;
        }

        head.next = null;
    }

    ///
    bool isNull() const @safe
    {
        return poolAllocator.isNull;
    }

    ///
    this(return scope ref HouseKeepingFreeList other)
    {
        this.tupleof = other.tupleof;
        other.head.next = null;
        other = HouseKeepingFreeList.init;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        Node* current = head.next;

        if (current !is null && current.available >= size)
            return listAllocate(&head, current, size);
        else
        {
            size_t toAllocate = size < Node.sizeof ? Node.sizeof : size;
            void[] ret = poolAllocator.allocate(toAllocate, ti);

            if (ret !is null)
                return ret[0 .. size];
            else
                return null;
        }
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        return poolAllocator.reallocate(array, newSize);
    }

    ///
    bool deallocate(void[] data)
    {
        if (data is null)
            return false;

        Node* node = cast(Node*) data.ptr;
        node.available = data.length;
        node.next = head.next;

        head.next = node;
        return true;
    }

    static if (__traits(hasMember, PoolAllocator, "owns"))
    {
        ///
        Ternary owns(void[] array)
        {
            return poolAllocator.owns(array);
        }
    }

    static if (__traits(hasMember, PoolAllocator, "deallocateAll"))
    {
        ///
        bool deallocateAll()
        {
            if (poolAllocator.deallocateAll())
            {
                head.next = null;
                return true;
            }

            return false;
        }
    }

    static if (__traits(hasMember, PoolAllocator, "empty"))
    {
        ///
        bool empty()
        {
            return poolAllocator.empty();
        }
    }

private:
    static struct Node
    {
        Node* next;
        size_t available;

    @system @nogc nothrow @hidden:

        void[] recreate()
        {
            return (cast(void*)&this)[0 .. available];
        }
    }

    void[] listAllocate(Node* previous, Node* current, size_t size)
    {
        previous.next = current.next;
        return current.recreate()[0 .. size];
    }
}

///
unittest
{
    import phobos.sys.allocators.mapping.malloc;
    import phobos.sys.allocators.buffers.region;

    alias HK = HouseKeepingFreeList!(Region!Mallocator);

    HK hk;
    assert(!hk.empty);
    assert(!hk.isNull);

    hk = HK();
    assert(!hk.empty);
    assert(!hk.isNull);

    void[] got = hk.allocate(1024);
    assert(got !is null);
    assert(got.length == 1024);
    assert(hk.owns(got) == Ternary.yes);
    assert(hk.owns(got[10 .. 20]) == Ternary.yes);

    bool success = hk.reallocate(got, 2048);
    assert(success);
    assert(got.length == 2048);

    assert(hk.owns(null) == Ternary.no);
    assert(hk.owns(got) == Ternary.yes);
    assert(hk.owns(got[10 .. 20]) == Ternary.yes);

    success = hk.deallocate(got);
    assert(success);
}

/**
A simple straight forward free list that supports first-fit, next-fit and best-fit strategies, with optional alignment and minimum stored size.

This is not designed to be fast, it exists to be a base line. Use FreeTree if you care about performance.

Does not use `TypeInfo`, but will be forwarded on allocation.

Warning: does not destroy on deallocation.

See_Also: FreeTree
*/
struct FreeList(PoolAllocator, FitsStrategy Strategy = FitsStrategy.NextFit,
        size_t DefaultAlignment = GoodAlignment, size_t DefaultMinimumStoredSize = 0)
{
export:
    /// Source for all memory
    PoolAllocator poolAllocator;
    /// Ensure all return pointers from stored source are aligned to a multiply of this
    size_t alignedTo = DefaultAlignment;
    // Ensure all memory stored are at least this size
    size_t minimumStoredSize = DefaultMinimumStoredSize;

    ///
    enum NeedsLocking = true;

    invariant
    {
        assert(alignedTo > 0);
        assert(head.next is null || !poolAllocator.isNull);
    }

    private
    {
        Node head;

        static if (Strategy == FitsStrategy.NextFit)
        {
            Node* previous;
        }

        AllocatedList!() allocations, fullAllocations;
    }

scope @system @nogc nothrow:

    ///
     ~this()
    {
        deallocateAll();
    }

    ///
    bool isNull() const @safe
    {
        return poolAllocator.isNull;
    }

    ///
    this(return scope ref FreeList other)
    {
        this.tupleof = other.tupleof;
        other.head = Node.init;
        static if (Strategy == FitsStrategy.NextFit)
            other.previous = null;
        other = FreeList.init;
    }

    static if (Strategy == FitsStrategy.FirstFit)
    {
        ///
        void[] allocate(size_t size, TypeInfo ti = null)
        {
            Node* previous = &head;

            for (;;)
            {
                assert(previous !is null);
                Node* current = previous.next;

                if (current is null)
                {
                    size_t toAllocateSize = size;
                    if (size < Node.sizeof)
                        toAllocateSize = Node.sizeof;

                    auto ret = poolAllocator.allocate(toAllocateSize, ti);
                    if (ret is null)
                        return null;

                    if (ret.length < toAllocateSize)
                    {
                        poolAllocator.deallocate(ret);
                        return null;
                    }

                    allocations.store(ret);
                    fullAllocations.store(ret);
                    return ret[0 .. size];
                }
                else if (!current.fitsAlignment(size, alignedTo))
                    previous = current.next;
                else
                    return listAllocate(previous, current, size);
            }

            assert(0);
        }
    }
    else static if (Strategy == FitsStrategy.NextFit)
    {
        ///
        void[] allocate(size_t size, TypeInfo ti = null)
        {
            Node* start = previous;

            for (;;)
            {
                Node* current;

                if (start is null)
                {
                    head.next = &head;

                    previous = &head;
                    start = previous;
                    current = start.next;
                }
                else
                    current = start.next;

                if (previous is start)
                {
                    size_t toAllocateSize = size;
                    if (size < Node.sizeof)
                        toAllocateSize = Node.sizeof;

                    auto ret = poolAllocator.allocate(toAllocateSize, ti);
                    if (ret is null)
                        return null;

                    if (ret.length < toAllocateSize)
                    {
                        poolAllocator.deallocate(ret);
                        return null;
                    }

                    allocations.store(ret);
                    fullAllocations.store(ret);
                    return ret[0 .. size];
                }
                else if (!current.fitsAlignment(size, alignedTo))
                    previous = current.next;
                else
                    return listAllocate(previous, current, size);
            }

            assert(0);
        }
    }
    else static if (Strategy == FitsStrategy.BestFit)
    {
        ///
        void[] allocate(size_t size, TypeInfo ti = null)
        {
            Node* best, previous = &head, bestPrevious;
            size_t bestSize = size_t.max;

            while (previous !is null)
            {
                Node* current = previous.next;

                if (current is null || current.available == size)
                {
                    if (current !is null)
                    {
                        bestPrevious = previous;
                        best = current;
                    }

                    break;
                }
                else if (current.fitsAlignment(size, alignedTo) && bestSize > current.available)
                {
                    assert(best !is current);
                    best = current;
                    bestPrevious = previous;
                    bestSize = current.available;
                }

                previous = current.next;
            }

            if (best !is null)
                return listAllocate(bestPrevious, best, size);

            {
                size_t toAllocateSize = size;
                if (size < Node.sizeof)
                    toAllocateSize = Node.sizeof;

                auto ret = poolAllocator.allocate(toAllocateSize, ti);
                if (ret is null)
                    return null;

                if (ret.length < toAllocateSize)
                {
                    poolAllocator.deallocate(ret);
                    return null;
                }

                allocations.store(ret);
                fullAllocations.store(ret);
                return ret[0 .. size];
            }
        }
    }
    else static if (Strategy == FitsStrategy.WorstFit)
    {
        ///
        void[] allocate(size_t size, TypeInfo ti = null)
        {
            Node* previous = &head, largest, largestPrevious;
            size_t largestSize;

            while (previous.next !is null)
            {
                Node* current = previous.next;

                if (current.available > largestSize)
                {
                    largestSize = current.available;
                    largest = current;
                    largestPrevious = previous;
                }

                previous = current;
            }

            if (largestSize < size)
            {
                size_t toAllocateSize = size;
                if (size < Node.sizeof)
                    toAllocateSize = Node.sizeof;

                auto ret = poolAllocator.allocate(toAllocateSize, ti);
                if (ret is null)
                    return null;

                if (ret.length < toAllocateSize)
                {
                    poolAllocator.deallocate(ret);
                    return null;
                }

                allocations.store(ret);
                fullAllocations.store(ret);
                return ret[0 .. size];
            }
            else
                return listAllocate(largestPrevious, largest, size);
        }
    }
    else
        static assert(0, "Unimplemented fit strategy");

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        if (void[] actual = allocations.getTrueRegionOfMemory(array))
        {
            size_t pointerDifference = array.ptr - actual.ptr;
            size_t amountLeft = actual.length - pointerDifference;

            if (amountLeft >= newSize)
            {
                array = array.ptr[0 .. newSize];
                return true;
            }
        }

        return false;
    }

    ///
    bool deallocate(void[] array)
    {
        void[] trueArray = allocations.getTrueRegionOfMemory(array);

        if (trueArray !is null)
        {
            allocations.remove(trueArray);

            if (trueArray.length >= Node.sizeof)
            {
                Node* node = cast(Node*) trueArray.ptr;
                node.available = trueArray.length;

                assert(head.next !is node);
                node.next = head.next;
                head.next = node;
                return true;
            }
        }

        return false;
    }

    ///
    Ternary owns(void[] array)
    {
        return fullAllocations.owns(array);
    }

    ///
    bool deallocateAll()
    {
        allocations.deallocateAll(null);
        fullAllocations.deallocateAll(&poolAllocator.deallocate);

        {
            head.next = null;

            static if (Strategy == FitsStrategy.NextFit)
            {
                previous = null;
            }
        }

        static if (__traits(hasMember, PoolAllocator, "deallocateAll"))
        {
            poolAllocator.deallocateAll();
        }

        return true;
    }

    static if (__traits(hasMember, PoolAllocator, "empty"))
    {
        ///
        bool empty()
        {
            return poolAllocator.empty();
        }
    }

private @hidden:
    static struct Node
    {
        Node* next;
        size_t available;

    @system @nogc nothrow @hidden:

        void[] recreate()
        {
            return (cast(void*)&this)[0 .. available];
        }

        bool fitsAlignment(size_t needed, size_t alignedTo)
        {
            if (alignedTo == 0)
                return true;

            size_t padding = alignedTo - ((cast(size_t)&this) % alignedTo);
            if (padding == alignedTo)
                padding = 0;

            return needed + padding <= available;
        }
    }

    void[] listAllocate(Node* previous, Node* current, size_t size)
    {
        Node* result = current;

        size_t toAddAlignment = alignedTo - ((cast(size_t) result) % alignedTo);

        if (toAddAlignment == alignedTo)
            toAddAlignment = 0;

        size_t remainderAvailable = current.available - (toAddAlignment + size);

        if (shouldSplit(current.available, size, alignedTo)
                && remainderAvailable >= minimumStoredSize)
        {
            allocations.store(result.recreate()[toAddAlignment .. toAddAlignment + size]);
            Node* remainder = cast(Node*)&result.recreate()[toAddAlignment + size];

            remainder.next = result.next;
            remainder.available = remainderAvailable;
            previous.next = remainder;
        }
        else
        {
            allocations.store(result.recreate());
            previous.next = current.next;
        }

        return result.recreate()[toAddAlignment .. toAddAlignment + size];
    }
}

///
unittest
{
    import phobos.sys.allocators.mapping.malloc;
    import phobos.sys.allocators.buffers.region;

    void perform(FL)()
    {
        FL fl;
        assert(!fl.empty);
        assert(!fl.isNull);

        fl = FL();
        assert(!fl.empty);
        assert(!fl.isNull);

        void[] got1 = fl.allocate(1024);
        assert(got1 !is null);
        assert(got1.length == 1024);
        assert(fl.owns(null) == Ternary.no);
        assert(fl.owns(got1) == Ternary.yes);
        assert(fl.owns(got1[10 .. 20]) == Ternary.yes);

        void[] got2 = fl.allocate(512);
        assert(got2 !is null);
        assert(got2.length == 512);
        assert(fl.owns(null) == Ternary.no);
        assert(fl.owns(got2) == Ternary.yes);
        assert(fl.owns(got2[10 .. 20]) == Ternary.yes);

        void[] got3 = fl.allocate(1024);
        assert(got3 !is null);
        assert(got3.length == 1024);
        assert(fl.owns(null) == Ternary.no);
        assert(fl.owns(got3) == Ternary.yes);
        assert(fl.owns(got3[10 .. 20]) == Ternary.yes);

        bool success = fl.reallocate(got1, 2048);
        assert(!success);
        assert(got1.length == 1024);

        success = fl.deallocate(got1);
        assert(success);
        success = fl.deallocate(got2);
        assert(success);
        success = fl.deallocate(got3);
        assert(success);

        got1 = fl.allocate(512);
        assert(got1 !is null);
        assert(got1.length == 512);
        assert(fl.owns(null) == Ternary.no);
        assert(fl.owns(got1) == Ternary.yes);
        assert(fl.owns(got1[10 .. 20]) == Ternary.yes);
    }

    perform!(FreeList!(Region!Mallocator, FitsStrategy.FirstFit));
    perform!(FreeList!(Region!Mallocator, FitsStrategy.NextFit));
    perform!(FreeList!(Region!Mallocator, FitsStrategy.BestFit));
    perform!(FreeList!(Region!Mallocator, FitsStrategy.WorstFit));
}

private @hidden:

bool shouldSplit()(size_t poolSize, size_t forSize, size_t alignment) @system @nogc nothrow pure
{
    if (alignment == 0)
        alignment = (void*).sizeof * 2;

    forSize += (void*).sizeof * 4;
    return (poolSize + alignment) > forSize;
}
