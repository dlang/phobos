/**
Provides statistics about a given allocator that it wraps.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.stats;
import phobos.sys.typecons : Ternary;
import core.atomic;

private
{
    import phobos.sys.allocators.api;

    alias Stats = StatsAllocator!RCAllocator;
}

export:

/// Tracks some information related to allocation
struct StatsAllocator(PoolAllocator)
{
    ///
    PoolAllocator poolAllocator;

    static if (__traits(hasMember, PoolAllocator, "NeedsLocking"))
    {
        ///
        enum NeedsLocking = PoolAllocator.NeedsLocking;
    }
    else
    {
        ///
        enum NeedsLockin = false;
    }

    ///
    __gshared RCAllocatorInstance!StatsAllocator instance;

    ///
    struct Info
    {
        ///
        size_t callsToOwns, callsToAllocate, callsToAllocateSuccessful, callsToReallocate,
            callsToReallocateSuccessful, callsToDeallocation,
            callsToDeallocationSuccessful, callsToEmpty;
        ///
        size_t numberOfReallocationsInPlace;
        ///
        size_t bytesAllocated, maximumBytesAllocatedOverTime;
    }

    private
    {
        shared(Info) info;
    }

@system @nogc nothrow:

    ///
    bool isNull() const @safe
    {
        return poolAllocator.isNull;
    }

    ///
    this(return scope ref StatsAllocator other)
    {
        this.tupleof = other.tupleof;
        other = StatsAllocator.init;
    }

    private
    {
        void updateCAS()
        {
            size_t bytes, max;

            for (bytes = atomicLoad(info.bytesAllocated),
                    max = atomicLoad(info.maximumBytesAllocatedOverTime); bytes < max;
                cas(&info.maximumBytesAllocatedOverTime, bytes, max))
            {
            }
        }
    }

    ///
    Info get()
    {
        return info;
    }

    ///
    void[] allocate(size_t length, TypeInfo ti = null)
    {
        atomicOp!"+="(info.callsToAllocate, 1);
        void[] ret = poolAllocator.allocate(length, ti);

        if (ret !is null)
        {
            atomicOp!"+="(info.callsToAllocateSuccessful, 1);
            atomicOp!"+="(info.bytesAllocated, ret.length);
        }

        updateCAS;
        return ret;
    }

    ///
    bool deallocate(void[] data)
    {
        atomicOp!"+="(info.callsToDeallocation, 1);
        bool ret = poolAllocator.deallocate(data);

        if (ret)
        {
            atomicOp!"+="(info.callsToDeallocationSuccessful, 1);
            atomicOp!"-="(info.bytesAllocated, data.length);
        }

        return ret;
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        atomicOp!"+="(info.callsToReallocate, 1);
        void[] original = array;

        bool ret = poolAllocator.reallocate(array, newSize);

        if (ret)
            atomicOp!"+="(info.callsToReallocateSuccessful, 1);

        if (array.ptr !is null && array.ptr !is original.ptr)
            atomicOp!"+="(info.numberOfReallocationsInPlace, 1);

        if (array.ptr !is original.ptr)
        {
            atomicOp!"-="(info.bytesAllocated, original.length);
            atomicOp!"+="(info.bytesAllocated, array.length);
        }

        updateCAS;
        return ret;
    }

    static if (__traits(hasMember, PoolAllocator, "owns"))
    {
        ///
        Ternary owns(void[] array)
        {
            atomicOp!"+="(info.callsToOwns, 1);
            return poolAllocator.owns(array);
        }
    }

    static if (__traits(hasMember, PoolAllocator, "deallocateAll"))
    {
        ///
        bool deallocateAll()
        {
            atomicStore(info.bytesAllocated, 0);
            return poolAllocator.deallocateAll();
        }
    }

    static if (__traits(hasMember, PoolAllocator, "empty"))
    {
        ///
        bool empty()
        {
            atomicOp!"+="(info.callsToEmpty, 1);
            return poolAllocator.empty();
        }
    }
}
