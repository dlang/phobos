module std.experimental.allocator.allocator_list;

import std.experimental.allocator.common;

/**
Given $(D make) as a function that returns fresh allocators, $(D
AllocatorList) creates an allocator that lazily creates as many allocators
are needed for satisfying client allocation requests.

The management data of the allocators is stored in memory obtained from the
allocators themselves, in a private linked list.
*/
struct AllocatorList(alias make)
{
    import std.traits : hasMember;
    import std.conv : emplace;
    import std.algorithm : move;
    /// Alias for $(D typeof(make)).
    alias typeof(make()) Allocator;
    static struct Node
    {
        Allocator a;
        Node* next;
        bool nextIsInitialized;
    }
    private Node* _root;

    /**
    Standard primitives.
    */
    enum uint alignment = Allocator.alignment;

    /// Ditto
    void[] allocate(size_t s)
    {
        auto result = allocateNoGrow(s);
        if (result.ptr) return result;
        // Must create a new allocator object
        if (!_root)
        {
            // I mean _brand_ new allocator object
            auto newNodeStack = Node(make());
            // Weird: store the new node inside its own allocated storage!
            _root = cast(Node*) newNodeStack.a.allocate(Node.sizeof).ptr;
            if (!_root)
            {
                // Are you serious? Not even the first allocation?
                return null;
            }
            newNodeStack.move(*_root);
            // Make sure we reserve room for the next next node
            _root.next = cast(Node*) _root.a.allocate(Node.sizeof).ptr;
            assert(_root.next);
            // root is set up, serve from it
            return allocateNoGrow(s);
        }
        // No room left, must append a new allocator
        auto n = _root;
        while (n.nextIsInitialized) n = n.next;
        if (!n.next)
        {
            // Resources truly exhausted, not much to do
            return null;
        }
        static assert(is(typeof(Node(make(), null, false)) == Node));
        emplace(n.next, make(), cast(Node*) null, false);
        n.nextIsInitialized = true;
        // Reserve room for the next next allocator
        n.next.next = cast(Node*) allocateNoGrow(Node.sizeof).ptr;
        // Rare failure cases leave nextIsInitialized to false
        if (!n.next.next) n.nextIsInitialized = false;
        // TODO: would be nice to bring the new allocator to the front.
        // All done!
        return allocateNoGrow(s);
    }

    private void[] allocateNoGrow(size_t bytes)
    {
        void[] result;
        if (!_root) return result;
        for (auto n = _root; ; n = n.next)
        {
            result = n.a.allocate(bytes);
            if (result.ptr) break;
            if (!n.nextIsInitialized) break;
        }
        return result;
    }

    /// Defined only if $(D Allocator.owns) is defined.
    static if (hasMember!(Allocator, "owns"))
    bool owns(void[] b)
    {
        if (!_root || !b.ptr) return false;
        for (auto n = _root; ; n = n.next)
        {
            if (n.a.owns(b)) return true;
            if (!n.nextIsInitialized) break;
        }
        return false;
    }

    /// Defined only if $(D Allocator.resolveInternalPointer) is defined.
    static if (hasMember!(Allocator, "resolveInternalPointer"))
    void[] resolveInternalPointer(void* p)
    {
        if (!_root) return null;
        for (auto n = _root; ; n = n.next)
        {
            if (auto r = n.a.resolveInternalPointer(p)) return p;
            if (!n.nextIsInitialized) break;
        }
        return null;
    }

    /// Defined only if $(D Allocator.expand) is defined.
    static if (hasMember!(Allocator, "expand"))
    bool expand(ref void[] b, size_t delta)
    {
        if (!b.ptr) return delta == 0 || (b = allocate(delta)) !is null;
        if (!_root) return false;
        for (auto n = _root; ; n = n.next)
        {
            if (n.a.owns(b)) return n.a.expand(b, delta);
            if (!n.nextIsInitialized) break;
        }
        return false;
    }

    /// Allows moving data from one $(D Allocator) to another.
    bool reallocate(ref void[] b, size_t s)
    {
        if (!b.ptr) return (b = allocate(s)) !is null;
        // First attempt to reallocate within the existing node
        if (!_root) return false;
        for (auto n = _root; ; n = n.next)
        {
            if (n.a.owns(b) && n.a.reallocate(b, s)) return true;
            if (!n.nextIsInitialized) break;
        }
        // Failed, but we may find new memory in a new node.
        auto newB = allocate(s);
        if (!newB.ptr) return false;
        newB[] = b[];
        static if (hasMember!(Allocator, "deallocate"))
            deallocate(b);
        b = newB;
        return true;
    }

    /// Defined only if $(D Allocator.deallocate) is defined.
    static if (hasMember!(Allocator, "deallocate"))
    void deallocate(void[] b)
    {
        if (!b.ptr || !_root)
        {
            return;
        }
        for (auto n = _root; ; n = n.next)
        {
            if (n.a.owns(b)) return n.a.deallocate(b);
            if (!n.nextIsInitialized) break;
        }
        assert(false);
    }

    /// Defined only if $(D Allocator.deallocateAll) is defined.
    static if (hasMember!(Allocator, "deallocateAll"))
    void deallocateAll()
    {
        if (!_root) return;
        // This is tricky because the list of allocators is threaded through the
        // allocators themselves. Malloc to the rescue!
        // First compute the number of allocators
        uint k = 0;
        for (auto n = _root; ; n = n.next)
        {
            ++k;
            if (!n.nextIsInitialized) break;
        }
        import std.experimental.allocator.mallocator;
        auto nodes =
            cast(Node*[]) Mallocator.it.allocate(k * (Allocator*).sizeof);
        scope(exit) Mallocator.it.deallocate(nodes);
        foreach (ref n; nodes)
        {
            n = _root;
            _root = _root.next;
        }
        _root = null;
        // Now we can deallocate in peace
        foreach (n; nodes)
        {
            n.a.deallocateAll();
        }
    }

    static if (hasMember!(Allocator, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            if (!_root) return;
            for (auto n = _root; ; n = n.next)
            {
                n.a.markAllAsUnused();
                if (!n.nextIsInitialized) break;
            }
            // Mark the list's memory as used
            for (auto n = _root; ; n = n.next)
            {
                markAsUsed(n[0 .. 1]);
                if (!n.nextIsInitialized) break;
            }
        }
        //
        bool markAsUsed(void[] b)
        {
            if (!_root) return;
            for (auto n = _root; ; n = n.next)
            {
                if (n.a.owns(b))
                {
                    n.a.markAsUsed(b);
                    break;
                }
                if (!n.nextIsInitialized) break;
            }
        }
        //
        void doneMarking()
        {
            if (!_root) return;
            for (auto n = _root; ; n = n.next)
            {
                n.a.doneMarking();
                if (!n.nextIsInitialized) break;
            }
        }
    }
}

///
unittest
{
    // Create an allocator based upon 4MB regions, fetched from the GC heap.
    import std.experimental.allocator.region;
    AllocatorList!({ return Region!()(new void[1024 * 4096]); }) a;
    auto b1 = a.allocate(1024 * 8192);
    assert(b1 is null); // can't allocate more than 4MB at a time
    b1 = a.allocate(1024 * 10);
    assert(b1.length == 1024 * 10);
    a.deallocateAll();
}

unittest
{
    import std.experimental.allocator.region;
    AllocatorList!({ return Region!()(new void[1024 * 4096]); }) a;
    auto b1 = a.allocate(1024 * 8192);
    assert(b1 is null);
    assert(!a._root.nextIsInitialized);
    b1 = a.allocate(1024 * 10);
    assert(b1.length == 1024 * 10);
    auto b2 = a.allocate(1024 * 4095);
    assert(a._root.nextIsInitialized);
    a.deallocateAll();
    assert(!a._root);
}

version(none) struct ArrayOfAllocators(alias make)
{
    alias Allocator = typeof(make());
    private Allocator[] allox;

    void[] allocate(size_t bytes)
    {
        void[] result = allocateNoGrow(bytes);
        if (result) return result;
        // Everything's full to the brim, create a new allocator.
        auto newAlloc = make();
        assert(&newAlloc !is newAlloc.initial);
        // Move the array to the new allocator
        assert(Allocator.alignment % Allocator.alignof == 0);
        const arrayBytes = (allox.length + 1) * Allocator.sizeof;
        Allocator[] newArray = void;
        do
        {
            if (arrayBytes < bytes)
            {
                // There is a chance we can find room in the existing allocator.
                newArray = cast(Allocator[]) allocateNoGrow(arrayBytes);
                if (newArray) break;
            }
            newArray = cast(Allocator[]) newAlloc.allocate(arrayBytes);
            writeln(newArray.length);
            assert(newAlloc.initial !is &newArray[$ - 1]);
            if (!newArray) return null;
        } while (false);

        assert(newAlloc.initial !is &newArray[$ - 1]);

        // Move data over to the new position
        foreach (i, ref e; allox)
        {
            writeln(&e, " ", e.base.store_.ptr, " ", e.initial);
            e.move(newArray[i]);
        }
        auto recoveredBytes = allox.length * Allocator.sizeof;
        static if (hasMember!(Allocator, "deallocate"))
            deallocate(allox);
        allox = newArray;
        assert(&allox[$ - 1] !is newAlloc.initial);
        newAlloc.move(allox[$ - 1]);
        assert(&allox[$ - 1] !is allox[$ - 1].initial);
        if (recoveredBytes >= bytes)
        {
            // The new request may be served from the just-freed memory. Recurse
            // and be bold.
            return allocateNoGrow(bytes);
        }
        // Otherwise, we can't possibly fetch memory from anywhere else but the
        // fresh new allocator.
        return allox.back.allocate(bytes);
    }

    private void[] allocateNoGrow(size_t bytes)
    {
        void[] result;
        foreach (ref a; allox)
        {
            result = a.allocate(bytes);
            if (result) break;
        }
        return result;
    }

    bool owns(void[] b)
    {
        foreach (i, ref a; allox)
        {
            if (a.owns(b)) return true;
        }
        return false;
    }

    static if (hasMember!(Allocator, "deallocate"))
    void deallocate(void[] b)
    {
        foreach (i, ref a; allox)
        {
            if (!a.owns(b)) continue;
            a.deallocate(b);
            break;
        }
    }
}

version(none) unittest
{
    ArrayOfAllocators!({ return Region!()(new void[1024 * 4096]); }) a;
    assert(a.allox.length == 0);
    auto b1 = a.allocate(1024 * 8192);
    assert(b1 is null);
    b1 = a.allocate(1024 * 10);
    assert(b1.length == 1024 * 10);
    assert(a.allox.length == 1);
    auto b2 = a.allocate(1024 * 4095);
    assert(a.allox.length == 2);
}
