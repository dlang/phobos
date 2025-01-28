/*
A list of allocations.

Prefer this over `AllocatedTree` if you do not need to lookup the true range of a memory.

See_Also: AllocatedTree

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.storage.allocatedlist;
public import phobos.sys.allocators.predefined : HouseKeepingAllocator;
import phobos.sys.allocators.api;
import phobos.sys.internal.attribute : hidden;
import phobos.sys.typecons : Ternary;

private
{
    alias AL = AllocatedList!(RCAllocator, RCAllocator);
}

/**
A list of all allocated memory, optionally supports a pool allocator that can be used to automatically deallocate all stored memory.

Warning: You must remove all memory (i.e. by deallocateAll) prior to destruction or you will get an error.

Warning: does not destroy on deallocation.
*/
struct AllocatedList(InternalAllocator = HouseKeepingAllocator!(), PoolAllocator = void)
{
export:
    ///
    InternalAllocator internalAllocator;

    static if (!is(PoolAllocator == void))
    {
        ///
        PoolAllocator poolAllocator;
    }

    ///
    enum NeedsLocking = true;

    invariant
    {
        assert(head.next is null || !internalAllocator.isNull);
    }

    private
    {
        Node head;

        static struct Node
        {
            Node* next;
            void[] array;

            bool matches(scope void* other) scope nothrow @nogc @hidden
            {
                return array.ptr <= other && (array.ptr + array.length) > other;
            }
        }
    }

@system @nogc nothrow:

    ///
     ~this()
    {
        static if (!is(PoolAllocator == void))
        {
            if (!poolAllocator.isNull)
                deallocateAll();
        }

        assert(head.next is null,
                "You didn't deallocate all memory before destruction of allocated list.");
    }

    ///
    bool isNull() const @safe
    {
        return internalAllocator.isNull;
    }

    ///
    this(return scope ref AllocatedList other)
    {
        this.tupleof = other.tupleof;
        other.head.next = null;
        other = AllocatedList.init;
    }

    static if (!is(PoolAllocator == void))
    {
        ///
        void deallocateAll()
        {
            deallocateAll(!poolAllocator.isNull ? &poolAllocator.deallocate : null);
        }
    }

    ///
    void deallocateAll(scope bool delegate(void[] array) nothrow @nogc deallocator)
    {
        Node* current = head.next;

        while (current !is null)
        {
            Node* next = current.next;

            if (deallocator !is null)
                deallocator(current.array);
            internalAllocator.deallocate((cast(void*) current)[0 .. Node.sizeof]);

            current = next;
        }

        head.next = null;
    }

    ///
    void store(void[] array)
    {
        if (array is null)
            return;

        Node* previous = &head;

        while (previous.next !is null && previous.next.array.ptr <= array.ptr)
        {
            Node* current = previous.next;

            if (current.matches(array.ptr))
            {
                void* actualStartPtr = current.array.ptr < array.ptr ? current.array.ptr
                    : array.ptr, actualEndPtr = (current.array.ptr + current.array.length) > (
                            array.ptr + array.length) ? (current.array.ptr + current.array.length) : (
                            array.ptr + array.length);
                size_t actualLength = actualEndPtr - actualStartPtr;

                if (current.array.ptr !is actualStartPtr)
                {
                    previous.next = current.next;
                    current.array = actualStartPtr[0 .. actualLength];

                    previous = &head;

                    while (previous.next !is null && previous.next.array.ptr <= array.ptr)
                    {
                        previous = previous.next;
                    }

                    current.next = previous.next;
                    previous.next = current;
                }
                else if (current.array.length != actualLength)
                {
                    current.array = actualStartPtr[0 .. actualLength];
                }

                return;
            }

            previous = current;
        }

        Node* newNode = cast(Node*) internalAllocator.allocate(Node.sizeof);
        assert(newNode !is null);

        newNode.next = previous.next;
        newNode.array = array;
        previous.next = newNode;
    }

    /// Caller is responsible for deallocation of memory
    void remove(void[] array)
    {
        if (array is null)
            return;

        Node* previous = &head;

        while (previous.next !is null && previous.next.array.ptr <= array.ptr)
        {
            Node* current = previous.next;

            if (current.matches(array.ptr))
            {
                previous.next = current.next;
                internalAllocator.deallocate((cast(void*) current)[0 .. Node.sizeof]);
                return;
            }

            previous = current;
        }
    }

    ///
    Ternary owns(void[] array)
    {
        if (array is null)
            return Ternary.no;

        Node* previous = &head;

        while (previous.next !is null && previous.next.array.ptr <= array.ptr)
        {
            Node* current = previous.next;

            if (current.matches(array.ptr))
                return Ternary.yes;

            previous = current;
        }

        return Ternary.no;
    }

    ///
    bool empty()
    {
        return head.next is null;
    }

    /// If memory is stored by us, will return the true region of memory associated with it.
    void[] getTrueRegionOfMemory(void[] array)
    {
        if (array is null)
            return null;

        Node* previous = &head;

        while (previous.next !is null && previous.next.array.ptr <= array.ptr)
        {
            Node* current = previous.next;

            if (current.matches(array.ptr))
                return current.array;

            previous = current;
        }

        return null;
    }
}

///
unittest
{
    alias AL = AllocatedList!();

    AL al;
    assert(!al.isNull);
    assert(al.empty);

    al = AL();
    assert(!al.isNull);
    assert(al.empty);

    void[] someArray = new void[1024];
    al.store(someArray);
    assert(!al.empty);

    assert(al.owns(null) == Ternary.no);
    assert(al.owns(someArray) == Ternary.yes);
    assert(al.owns(someArray[10 .. 20]) == Ternary.yes);
    assert(al.getTrueRegionOfMemory(someArray[10 .. 20]) is someArray);

    al.remove(someArray);
    assert(al.owns(someArray) == Ternary.no);
    assert(al.empty);

    al.store(someArray);
    assert(!al.empty);

    int got;
    al.deallocateAll((array) { got += array == someArray ? 1 : 0; return true; });
    assert(got == 1);
}
