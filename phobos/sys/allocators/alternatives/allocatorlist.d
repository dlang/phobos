/**
Provides a growable list of memory allocator instances.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.alternatives.allocatorlist;
import phobos.sys.internal.attribute : hidden;
import phobos.sys.typecons : Ternary;

private
{
    import phobos.sys.allocators.api;

    // guarantee tha each strategy has been initialized
    alias ALRC = AllocatorList!(RCAllocator, (RCAllocator* poolAllocator) => poolAllocator);
}

export:

/**
A simple allocator list that relies on a given allocators (as provided by the factory function) to provide its own memory.

Supports isOnlyOneAllocationOfSize method on the pool allocator to allow knowing if it can free a given allocator instance.

Does not use `TypeInfo`, but will be forwarded on allocation.
*/
struct AllocatorList(PoolAllocator, alias factory)
{
export:
    static assert(__traits(hasMember, TypeOfAllocator, "deallocateAll"),
            "Allocator allocated by factory function must have deallocateAll method.");
    static assert(__traits(hasMember, TypeOfAllocator, "owns"),
            "Allocator allocated by factory function must have owns method.");

    /// Source for all memory, passed by pointer/ref to factory function
    PoolAllocator poolAllocator;

    ///
    enum NeedsLocking = true;

    private
    {
        Node* head;
    }

@system @nogc nothrow:
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
    this(return scope ref AllocatorList other)
    {
        this.tupleof = other.tupleof;
        other.head = null;
        other = AllocatorList.init;
    }

    ///
    void[] allocate(size_t size, TypeInfo ti = null)
    {
        Node* current = head;

        while (current !is null)
        {
            Node* next = current.next;

            void[] ret = current.allocator.allocate(size, ti);

            if (ret.length >= size)
            {
                return ret;
            }
            else if (ret.length > 0)
            {
                current.allocator.deallocate(ret);
            }

            current = next;
        }

        expand(size);
        assert(head !is null);

        if ((current = head) !is null)
        {
            void[] ret = current.allocator.allocate(size, ti);

            if (ret.length >= size)
            {
                return ret;
            }
            else if (ret.length > 0)
            {
                current.allocator.deallocate(ret);
            }
        }

        return null;
    }

    ///
    bool reallocate(ref void[] array, size_t newSize)
    {
        Node* current = head;

        while (current !is null)
        {
            Node* next = current.next;

            if (current.allocator.owns(array) == Ternary.yes)
                return current.allocator.reallocate(array, newSize);

            current = next;
        }

        return false;
    }

    ///
    bool deallocate(void[] array)
    {
        Node** parent = &head;
        Node* current = head;

        while (current !is null)
        {
            Node* next = current.next;

            if (current.allocator.owns(array) == Ternary.yes)
            {
                bool got = current.allocator.deallocate(array);

                if (got)
                {
                    static if (__traits(hasMember, PoolAllocator, "isOnlyOneAllocationOfSize"))
                    {
                        if (current.allocator.isOnlyOneAllocationOfSize(Node.sizeof))
                        {
                            PoolAllocator temp = current.allocator;
                            *parent = current.next;
                            temp.deallocateAll();
                        }
                    }

                    return true;
                }
                else
                    return false;
            }

            parent = &current.next;
            current = next;
        }

        return false;
    }

    ///
    Ternary owns(void[] array)
    {
        Node* current = head;

        while (current !is null)
        {
            Node* next = current.next;

            if (current.allocator.owns(array) == Ternary.yes)
                return Ternary.yes;

            current = next;
        }

        return Ternary.no;
    }

    ///
    bool deallocateAll()
    {
        Node* current = head;

        while (current !is null)
        {
            Node* next = current.next;

            auto currentAllocator = current.allocator;
            currentAllocator.deallocateAll();

            current = next;
        }

        head = null;
        return true;
    }

    ///
    bool empty()
    {
        return false;
    }

private @hidden:
    import std.traits : isPointer, ParameterStorageClassTuple, ParameterStorageClass;

    static if (isPointer!PoolAllocator || (__traits(compiles, factory!PoolAllocator)
            && ParameterStorageClassTuple!(factory!PoolAllocator)[0] == ParameterStorageClass.ref_))
        alias TypeOfAllocator = typeof(factory(poolAllocator));
    else static if (__traits(compiles, typeof(factory())))
        alias TypeOfAllocator = typeof(factory());
    else
        alias TypeOfAllocator = typeof(factory({
                typeof(poolAllocator)* ret;
                return ret;
            }()));

    static struct Node
    {
        TypeOfAllocator allocator;
        Node* next;
    }

    void expand(size_t requesting = 0)
    {
        import std.traits : isPointer, ParameterStorageClass, ParameterStorageClassTuple;
        import std.algorithm : moveEmplace;

        TypeOfAllocator current;

        static if (isPointer!PoolAllocator || (__traits(compiles, factory!PoolAllocator)
                && ParameterStorageClassTuple!(factory!PoolAllocator)[0] == ParameterStorageClass
                .ref_))
            current = factory(poolAllocator);
        else static if (__traits(compiles, typeof(factory())))
            current = factory();
        else
            current = factory(&poolAllocator);

        if (requesting > 0)
            requesting += size_t.sizeof * 8;

        void[] got = current.allocate(Node.sizeof + requesting);
        if (got is null)
            return;

        if (requesting > 0)
        {
            current.deallocate(got);
            got = current.allocate(Node.sizeof);
        }

        Node* currentNode = cast(Node*) got.ptr;

        moveEmplace(current, currentNode.allocator);
        currentNode.next = head;

        head = currentNode;
    }
}

///
unittest
{
    import phobos.sys.allocators.mapping.malloc;
    import phobos.sys.allocators.buffers.region;

    alias AL = AllocatorList!(Region!Mallocator, () => Region!Mallocator());

    AL al;
    assert(!al.isNull);
    assert(!al.empty);

    al = AL();
    assert(!al.isNull);
    assert(!al.empty);

    void[] got = al.allocate(1024);
    assert(got !is null);
    assert(got.length == 1024);
    assert(al.owns(got) == Ternary.yes);
    assert(al.owns(got[10 .. 20]) == Ternary.yes);

    AL al2 = al;
    al = al2;

    bool success = al.reallocate(got, 2048);
    assert(success);
    assert(got.length == 2048);

    assert(al.owns(null) == Ternary.no);
    assert(al.owns(got) == Ternary.yes);
    assert(al.owns(got[10 .. 20]) == Ternary.yes);

    success = al.deallocate(got);
    assert(success);
}
