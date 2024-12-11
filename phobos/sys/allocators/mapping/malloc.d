/**
Provides memory mapping via the libc malloc/realloc/free functions.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.mapping.malloc;
import phobos.sys.allocators.api : RCAllocatorInstance;

export:

/**
Libc malloc + realloc + free based memory allocator, should be treated as a mapping allocator but can be used as an allocator.

Does not use `TypeInfo` argument on allocation.

Warning: Deallocating using this without keeping track of roots will fail.

Warning: does not destroy on deallocation.
*/
struct Mallocator
{
export:

    ///
    enum NeedsLocking = false;

    ///
    enum isNull = false;

    ///
    __gshared RCAllocatorInstance!Mallocator instance;

@nogc pure nothrow @system:

    ///
    bool empty()
    {
        return false;
    }

    ///
    void[] allocate(size_t length, TypeInfo ti = null)
    {
        // implementation defined behavior == bad
        if (length == 0)
            return null;

        void* ret = pureMalloc(length);

        version (none)
        {
            import core.stdc.stdio;

            debug printf("allocate length %zd, got pointer %p\n", length, ret);
            debug fflush(stdout);
        }

        if (ret is null)
            return null;
        else
            return ret[0 .. length];
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        // implementation defined behavior == bad
        if (newSize == 0)
            return false;

        void* ret = pureRealloc(array.ptr, newSize);

        version (none)
        {
            import core.stdc.stdio;

            debug printf("reallocate old length %zd, new length %zd, old pointer %p, new pointer %p\n",
                    array.length, newSize, array.ptr, ret);
            debug fflush(stdout);
        }

        if (ret !is null)
        {
            array = ret[0 .. newSize];
            return true;
        }
        else
        {
            return false;
        }
    }

    ///
    bool deallocate(void[] data)
    {
        version (none)
        {
            import core.stdc.stdio;

            debug printf("deallocate length %zd, pointer %p\n", data.length, data.ptr);
            debug fflush(stdout);
        }

        if (data.ptr !is null)
        {
            pureFree(data.ptr);
            return true;
        }
        else
            return false;
    }
}

private:

// copied from druntime
extern (C) pure @system @nogc nothrow
{
    pragma(mangle, "malloc") void* pureMalloc(size_t);
    pragma(mangle, "calloc") void* pureCalloc(size_t nmemb, size_t size);
    pragma(mangle, "realloc") void* pureRealloc(void* ptr, size_t size);
    pragma(mangle, "free") void pureFree(void* ptr);
}
