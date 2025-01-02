/**
Attempts to use one memory allocator and if that fails uses another.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.alternatives.fallback;
import phobos.sys.typecons : Ternary;

private
{
    import phobos.sys.allocators.api;

    alias FBRC = FallbackAllocator!(RCAllocator, RCAllocator);
}

export:

/**
A simple fall back allocator, try primary if not try secondary otherwise use primary.

Does not use `TypeInfo`, but will be forwarded on allocation.
*/
struct FallbackAllocator(Primary, Secondary)
{
export:
    ///
    Primary primary;
    ///
    Secondary secondary;

    ///
    enum NeedsLocking = () {
        bool ret;

        static if (__traits(hasMember, Primary, "NeedsLocking"))
            if (Primary.NeedsLocking)
                ret = true;
        static if (__traits(hasMember, Secondary, "NeedsLocking"))
            if (Secondary.NeedsLocking)
                ret = true;

        return ret;
    }();

@system @nogc nothrow:

    this(return scope ref FallbackAllocator other)
    {
        this.tupleof = other.tupleof;
        other = FallbackAllocator.init;
    }

    ///
    bool isNull() const @safe
    {
        return primary.isNull || secondary.isNull;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        if (isNull)
            return null;
        else
        {
            void[] ret = primary.allocate(size, ti);

            if (ret is null)
                ret = secondary.allocate(size, ti);

            return ret;
        }
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        if (isNull)
            return false;
        else if (primary.owns(array) == Ternary.yes || secondary.owns(array) == Ternary.no)
            return primary.reallocate(array, newSize);
        else
            return secondary.reallocate(array, newSize);
    }

    ///
    bool deallocate(void[] array)
    {
        if (isNull)
            return false;
        else if (primary.owns(array) == Ternary.yes || secondary.owns(array) == Ternary.no)
            return primary.deallocate(array);
        else
            return secondary.deallocate(array);
    }

    ///
    Ternary owns(void[] array)
    {
        if (isNull)
            return Ternary.no;
        else
            return primary.owns(array) == Ternary.yes ? Ternary.yes : secondary.owns(array);
    }

    static if (__traits(hasMember, Primary, "deallocateAll")
            && __traits(hasMember, Secondary, "deallocateAll"))
    {
        ///
        bool deallocateAll()
        {
            if (isNull)
                return false;
            else
            {
                primary.deallocateAll();
                secondary.deallocateAll();
                return true;
            }
        }
    }

    static if (__traits(hasMember, Primary, "empty") && __traits(hasMember, Secondary, "empty"))
    {
        ///
        bool empty()
        {
            return isNull || primary.empty() && secondary.empty();
        }
    }
}
