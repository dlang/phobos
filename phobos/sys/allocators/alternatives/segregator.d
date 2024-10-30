/**
Allows splitting of allocations between two sizes of allocations.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.alternatives.segregator;
import phobos.sys.typecons : Ternary;

private
{
    import phobos.sys.allocators.api;

    alias SegRC = Segregator!(RCAllocator, RCAllocator, 1024);
}

export:

/**
Splits memory allocations based upon size. Uses small <= threshold < large.

Does not use `TypeInfo`, but will be forwarded on allocation.
*/
struct Segregator(SmallAllocator, LargeAllocator, size_t threshold)
{
export:
    ///
    SmallAllocator smallAllocator;
    ///
    LargeAllocator largeAllocator;

    ///
    enum NeedsLocking = () {
        bool ret;

        static if (__traits(hasMember, SmallAllocator, "NeedsLocking"))
            if (SmallAllocator.NeedsLocking)
                ret = true;
        static if (__traits(hasMember, LargeAllocator, "NeedsLocking"))
            if (LargeAllocator.NeedsLocking)
                ret = true;

        return ret;
    }();

scope @system @nogc nothrow:

    this(return scope ref Segregator other)
    {
        this.tupleof = other.tupleof;
        other = Segregator.init;
    }

    ///
    bool isNull() const
    {
        return smallAllocator.isNull || largeAllocator.isNull;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        if (isNull)
            return null;
        else
        {
            if (size <= threshold)
                return smallAllocator.allocate(size, ti);
            else
                return largeAllocator.allocate(size, ti);
        }
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        if (isNull)
            return false;
        else if (smallAllocator.owns(array) == Ternary.yes)
            return smallAllocator.reallocate(array, newSize);
        else
            return largeAllocator.reallocate(array, newSize);
    }

    ///
    bool deallocate(void[] array)
    {
        if (isNull)
            return false;
        else if (smallAllocator.owns(array) == Ternary.yes)
            return smallAllocator.deallocate(array);
        else
            return largeAllocator.deallocate(array);
    }

    static if (__traits(hasMember, SmallAllocator, "owns")
            && __traits(hasMember, LargeAllocator, "owns"))
    {
        ///
        Ternary owns(void[] array)
        {
            if (isNull)
                return Ternary.no;
            else if (largeAllocator.owns(array) != Ternary.yes)
                return smallAllocator.owns(array);
            else
                return largeAllocator.owns(array);
        }
    }

    static if (__traits(hasMember, SmallAllocator, "deallocateAll")
            && __traits(hasMember, LargeAllocator, "deallocateAll"))
    {
        ///
        bool deallocateAll()
        {
            if (isNull)
                return false;
            else
            {
                smallAllocator.deallocateAll();
                largeAllocator.deallocateAll();
                return true;
            }
        }
    }

    static if (__traits(hasMember, SmallAllocator, "empty")
            && __traits(hasMember, LargeAllocator, "empty"))
    {
        ///
        bool empty()
        {
            return isNull || smallAllocator.empty() && largeAllocator.empty();
        }
    }
}

/// A segregator based upon the page size with a multiplier
struct SegregatorPageThreshold(SmallAllocator, LargeAllocator, size_t multiplier = 1)
{
export:
    ///
    SmallAllocator smallAllocator;
    ///
    LargeAllocator largeAllocator;

    private
    {
        size_t threshold;
    }

    ///
    enum NeedsLocking = () {
        bool ret;

        static if (__traits(hasMember, SmallAllocator, "NeedsLocking"))
            if (SmallAllocator.NeedsLocking)
                ret = true;
        static if (__traits(hasMember, LargeAllocator, "NeedsLocking"))
            if (LargeAllocator.NeedsLocking)
                ret = true;

        return ret;
    }();

@system @nogc nothrow:

    ///
    this(size_t threshold)
    {
        this.threshold = threshold;
    }

    this(return scope ref SegregatorPageThreshold other)
    {
        this.tupleof = other.tupleof;
        other = SegregatorPageThreshold.init;
    }

    ///
    bool isNull() const @safe
    {
        return smallAllocator.isNull || largeAllocator.isNull;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        import phobos.sys.allocators.mapping.vars : PAGESIZE;

        if (threshold == 0)
            threshold = multiplier * PAGESIZE;
        assert(threshold > 0);

        if (isNull)
            return null;
        else
        {
            if (size <= threshold)
                return smallAllocator.allocate(size, ti);
            else
                return largeAllocator.allocate(size, ti);
        }
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        if (isNull)
            return false;
        else if (smallAllocator.owns(array) == Ternary.yes)
            return smallAllocator.reallocate(array, newSize);
        else
            return largeAllocator.reallocate(array, newSize);
    }

    ///
    bool deallocate(void[] array)
    {
        if (isNull)
            return false;
        else if (smallAllocator.owns(array) == Ternary.yes)
            return smallAllocator.deallocate(array);
        else
            return largeAllocator.deallocate(array);
    }

    static if (__traits(hasMember, SmallAllocator, "owns")
            && __traits(hasMember, LargeAllocator, "owns"))
    {
        ///
        Ternary owns(void[] array)
        {
            if (isNull)
                return Ternary.no;
            else if (largeAllocator.owns(array) != Ternary.yes)
                return smallAllocator.owns(array);
            else
                return largeAllocator.owns(array);
        }
    }

    static if (__traits(hasMember, SmallAllocator, "deallocateAll")
            && __traits(hasMember, LargeAllocator, "deallocateAll"))
    {
        ///
        bool deallocateAll()
        {
            if (isNull)
                return false;
            else
            {
                smallAllocator.deallocateAll();
                largeAllocator.deallocateAll();
                return true;
            }
        }
    }

    static if (__traits(hasMember, SmallAllocator, "empty")
            && __traits(hasMember, LargeAllocator, "empty"))
    {
        ///
        bool empty()
        {
            return isNull || smallAllocator.empty() && largeAllocator.empty();
        }
    }
}
