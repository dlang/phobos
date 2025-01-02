/**
Provides an allocator wrapper that performs locking to make it thread-safe.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
 */
module phobos.sys.allocators.locking;
import phobos.sys.typecons : Ternary;

export:

/**
Adds a lock around all allocator operations to make it thread safe.
*/
struct AllocatorLocking(PoolAllocator)
{
    ///
    PoolAllocator poolAllocator;

    ///
    enum NeedsLocking = false;

    private
    {
        import phobos.sys.internal.mutualexclusion;

        TestTestSetLockInline mutex;
    }

@system @nogc nothrow:

    ///
    this(return scope ref AllocatorLocking other)
    {
        assert(other.mutex.lock, "Failed to lock mutex");
        scope (exit)
            other.mutex.unlock;

        this.poolAllocator = other.poolAllocator;
        other.poolAllocator = PoolAllocator.init;
    }

    ~this()
    {
    }

    ///
    bool isNull() const @safe
    {
        return poolAllocator.isNull;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        mutex.lock;
        scope (exit)
            mutex.unlock;

        return poolAllocator.allocate(size, ti);
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        mutex.lock;
        scope (exit)
            mutex.unlock;

        return poolAllocator.reallocate(array, newSize);
    }

    ///
    bool deallocate(void[] array)
    {
        if (array is null)
            return false;

        mutex.lock;
        scope (exit)
            mutex.unlock;

        return poolAllocator.deallocate(array);
    }

    static if (__traits(hasMember, PoolAllocator, "owns"))
    {
        ///
        Ternary owns(void[] array)
        {
            mutex.lock;
            scope (exit)
                mutex.unlock;

            return poolAllocator.owns(array);
        }
    }

    static if (__traits(hasMember, PoolAllocator, "deallocateAll"))
    {
        ///
        bool deallocateAll()
        {
            mutex.lock;
            scope (exit)
                mutex.unlock;

            return poolAllocator.deallocateAll();
        }
    }

    static if (__traits(hasMember, PoolAllocator, "empty"))
    {
        ///
        bool empty()
        {
            mutex.lock;
            scope (exit)
                mutex.unlock;

            return poolAllocator.empty();
        }
    }
}

/**
Hooks allocations and add then remove ranges as allocations/deallocations/reallocations occur.
*/
struct GCAllocatorLock(PoolAllocator)
{
    import phobos.sys.allocators.storage.allocatedtree;
    import phobos.sys.allocators.mapping.malloc;
    import phobos.sys.internal.mutualexclusion;

    ///
    PoolAllocator poolAllocator;

    private
    {
        AllocatedTree!() allocatedTree;
        TestTestSetLockInline mutex;
    }

    ///
    enum NeedsLocking = false;

@system @nogc nothrow:

    ///
    this(return scope ref GCAllocatorLock other)
    {
        mutex.lock;
        scope (exit)
            mutex.unlock;

        this.poolAllocator = other.poolAllocator;
        other.poolAllocator = PoolAllocator.init;

        this.allocatedTree = other.allocatedTree;
        other.allocatedTree = typeof(allocatedTree).init;
    }

    ~this()
    {
        import core.memory : GC;

        mutex.lock;
        scope (exit)
            mutex.unlock;

        allocatedTree.deallocateAll((void[] array) {
            GC.removeRange(array.ptr);
            return true;
        });
    }

    ///
    bool isNull() const @safe
    {
        return poolAllocator.isNull;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        import core.memory : GC;

        mutex.lock;
        scope (exit)
            mutex.unlock;

        void[] got = poolAllocator.allocate(size, ti);

        if (got !is null)
        {
            allocatedTree.store(got);
            GC.addRange(got.ptr, got.length, ti);
            return got[0 .. size];
        }

        return null;
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        import core.memory : GC;

        mutex.lock;
        scope (exit)
            mutex.unlock;

        TypeInfo ti;
        auto trueArray = allocatedTree.getTrueRegionOfMemory(array, ti);
        if (trueArray is null)
            return false;
        array = trueArray;

        gcdisable;

        allocatedTree.remove(trueArray);
        GC.removeRange(trueArray.ptr);

        bool got = poolAllocator.reallocate(array, newSize);

        if (got)
        {
            array = array[0 .. newSize];

            allocatedTree.store(array, ti);
            GC.addRange(array.ptr, array.length, ti);
        }
        else
        {
            const pointerDifference = array.ptr - trueArray.ptr;
            const lengthAvailable = trueArray.length - pointerDifference;

            if (lengthAvailable >= newSize)
            {
                got = true;
                array = trueArray[0 .. newSize];
            }

            allocatedTree.store(trueArray, ti);
            GC.addRange(trueArray.ptr, trueArray.length, ti);
        }

        gcenable;
        return got;
    }

    ///
    bool deallocate(void[] array)
    {
        import core.memory : GC;

        if (array is null)
            return false;

        mutex.lock;
        scope (exit)
            mutex.unlock;

        auto trueArray = allocatedTree.getTrueRegionOfMemory(array);
        if (trueArray is null)
            return false;

        assert(trueArray.ptr <= array.ptr);
        assert(trueArray.length >= array.length);

        allocatedTree.remove(trueArray);
        GC.removeRange(trueArray.ptr);

        const got = poolAllocator.deallocate(trueArray);

        return got;
    }

    ///
    Ternary owns(void[] array)
    {
        mutex.lock;
        scope (exit)
            mutex.unlock;

        return allocatedTree.owns(array);
    }

    ///
    bool deallocateAll()
    {
        import core.memory : GC;

        mutex.lock;
        scope (exit)
            mutex.unlock;

        static if (__traits(hasMember, PoolAllocator, "deallocateAll"))
        {
            allocatedTree.deallocateAll((void[] array) {
                GC.removeRange(array.ptr);
                return true;
            });
            return poolAllocator.deallocateAll();
        }
        else
        {
            allocatedTree.deallocateAll((void[] array) {
                GC.removeRange(array.ptr);
                return poolAllocator.deallocate(array);
            });
            return true;
        }
    }

    static if (__traits(hasMember, PoolAllocator, "empty"))
    {
        ///
        bool empty()
        {
            mutex.lock;
            scope (exit)
                mutex.unlock;

            return poolAllocator.empty();
        }
    }
}

private:

extern (C)
{
    pragma(mangle, "gc_enable") static void gcenable() nothrow pure @nogc;
    pragma(mangle, "gc_disable") static void gcdisable() nothrow pure @nogc;
}
