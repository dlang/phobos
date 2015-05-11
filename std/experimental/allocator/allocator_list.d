module std.experimental.allocator.allocator_list;

import std.experimental.allocator.common;
version(unittest) import std.stdio;

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
    import std.algorithm : min, move;
    import std.experimental.allocator.stats_collector;

    /// Alias for $(D typeof(make)).
    alias Allocator = typeof(make());
    // Allocator used internally
    private alias SAllocator = StatsCollector!(Allocator, Options.bytesUsed);

    private static struct Node
    {
        // Allocator in this node
        SAllocator a;
        uint nextIdx = uint.max; // not a pointer - we want this relocatable

        // Is this node unused?
        void setUnused() { nextIdx = nextIdx.max - 1; }
        bool unused() const { return nextIdx == nextIdx.max - 1; }

        // Just forward everything to the allocator
        alias a this;
    }

    // State is stored in an array, but it has a list threaded through it by
    // means of "next".
    private Node[] allocators;
    private uint rootIndex = uint.max;

    private auto byLRU()
    {
        static struct Result
        {
            Node* first;
            Node* current;
            bool empty() { return current is null; }
            ref Node front()
            {
                assert(!empty);
                assert(!current.unused);
                return *current;
            }
            void popFront()
            {
                assert(first && current && !current.unused);
                assert(first + current.nextIdx != current);
                if (current.nextIdx == current.nextIdx.max) current = null;
                else current = first + current.nextIdx;
            }
            Result save() { return this; }
        }
        if (!allocators.length) return Result();
        assert(rootIndex < allocators.length);
        return Result(allocators.ptr, allocators.ptr + rootIndex);
    }

    ~this()
    {
        deallocateAll;
    }

    /**
    The alignment offered.
    */
    enum uint alignment = Allocator.alignment;

    /// Ditto
    void[] allocate(size_t s)
    {
        auto result = allocateNoGrow(s);
        if (result.ptr) return result;
        if (auto newAlloc = addAllocator) result = newAlloc.allocate(s);
        return result;
    }

    // Allocate from the existing pool of allocators
    private void[] allocateNoGrow(size_t bytes)
    {
        // Try one of the existing allocators
        foreach (ref n; byLRU)
        {
            auto result = n.allocate(bytes);
            if (!result.ptr) continue;
            // Bring to front the lastly used allocator
            auto index = cast(uint) (&n - allocators.ptr);
            if (index != rootIndex)
            {
                assert(index < allocators.length);
                n.nextIdx = rootIndex;
                rootIndex = index;
            }
            return result;
        }
        return null;
    }

    // Reallocate from the existing pool of allocators.
    bool reallocateNoGrow(ref void[] b, size_t s)
    {
        if (!b.ptr)
        {
            b = allocateNoGrow(s);
            return b.ptr !is null || s == 0;
        }
        // First attempt to reallocate within the existing node
        import std.algorithm : find;
        auto owner = byLRU.find!((ref n) => n.owns(b));
        assert(!owner.empty);
        if (owner.front.reallocate(b, s)) return true;
        // Failed, but we may find new memory in a new node.
        auto newB = allocateNoGrow(s);
        if (!newB.ptr) return false;
        auto copy = min(b.length, s);
        newB[0 .. copy] = b[0 .. copy];
        static if (hasMember!(Allocator, "deallocate"))
        {
            // We still know n owns b from above
            owner.front.deallocate(b);
        }
        b = newB;
        return true;
    }

    // Find an empty (unused) slot for a Node, return its index. Does not create
    // a new allocator object.
    private uint findEmptySlot()
    {
        // Try past unused slots
        foreach (uint i, ref n; allocators)
        {
            if (n.unused) return i;
        }
        // Try to expand in place
        void[] t = allocators;
        if (this.reallocateNoGrow(t, t.length + Node.sizeof))
        {
            allocators = cast(Node[]) t;
            assert(0 < allocators.length && allocators.length < uint.max);
            return cast(uint) allocators.length - 1;
        }
        // No can do
        return uint.max;
    }

    private Node* addAllocator()
    {
        auto i = findEmptySlot;
        if (i < i.max)
        {
            // Found, set up the new one as root
            Node* n = &allocators[i];
            emplace(&n.a, make());
            assert(n.bytesUsed == 0);
            n.nextIdx = rootIndex;
            rootIndex = i;
            return n;
        }
        // Must create a new allocator object on the stack and move it
        auto newNode = Node(SAllocator(make()), rootIndex);
        // Weird: store the new node inside its own allocated storage!
        auto buf = newNode.allocate((allocators.length + 1) * Node.sizeof);
        if (!buf.ptr)
        {
            // Terrible, too many allocators
            return null;
        }
        // Move over existing allocators
        buf[0 .. $ - Node.sizeof] = allocators[];
        static if (hasMember!(Allocator, "deallocate"))
            this.deallocate(allocators);
        allocators = cast(Node[]) buf;
        assert(allocators.length > 0);
        // Move node to the last position and set in the root position
        auto newNodeFinal = &allocators[$ - 1];
        newNode.move(*newNodeFinal);
        assert(newNodeFinal.nextIdx == rootIndex);
        rootIndex = cast(uint) allocators.length - 1;
        return newNodeFinal;
    }

    /// Defined only if $(D Allocator.owns) is defined.
    static if (hasMember!(Allocator, "owns"))
    bool owns(void[] b)
    {
        import std.algorithm : canFind;
        return byLRU.canFind!((ref n) => n.owns(b));
    }

    /// Defined only if $(D Allocator.resolveInternalPointer) is defined.
    static if (hasMember!(Allocator, "resolveInternalPointer"))
    void[] resolveInternalPointer(void* p)
    {
        foreach (ref n; byLRU)
        {
            if (auto r = n.resolveInternalPointer(p)) return r;
        }
        return null;
    }

    /// Defined only if $(D Allocator.expand) is defined.
    static if (hasMember!(Allocator, "expand")
        && hasMember!(Allocator, "owns"))
    bool expand(ref void[] b, size_t delta)
    {
        foreach (ref n; byLRU)
        {
            if (n.owns(b)) return n.expand(b, delta);
        }
        return false;
    }

    /// Allows moving data from one $(D Allocator) to another.
    bool reallocate(ref void[] b, size_t s)
    {
        // First attempt to reallocate within the existing node
        foreach (ref n; byLRU)
        {
            if (!n.owns(b)) continue;
            if (n.reallocate(b, s)) return true;
            break;
        }
        // Failed, but we may find new memory in a new node.
        auto newB = allocate(s);
        if (!newB.ptr) return false;
        auto copy = min(b.length, s);
        newB[0 .. copy] = b[0 .. copy];
        static if (hasMember!(Allocator, "deallocate"))
            deallocate(b);
        b = newB;
        return true;
    }

    /**
     Defined if $(D Allocator.deallocate) and $(D Allocator.owns) are defined.
    */
    static if (hasMember!(Allocator, "deallocate")
        && hasMember!(Allocator, "owns"))
    void deallocate(void[] b)
    {
        foreach (ref n; byLRU)
        {
            if (n.owns(b)) return n.deallocate(b);
        }
        assert(false);
    }

    /// Defined only if $(D Allocator.deallocateAll) is defined.
    static if (hasMember!(Allocator, "deallocateAll")
        && hasMember!(Allocator, "owns"))
    void deallocateAll()
    {
        if (!allocators.length) return;
        // This is tricky because the list of allocators is threaded through
        // the allocators themselves.
        Node* owner;
        for (auto n = byLRU; !n.empty; )
        {
            if (n.front.owns(allocators))
            {
                // Skip this guy for now
                owner = &n.front();
                n.popFront;
                continue;
            }
            n.front.deallocateAll();
            auto oldN = &n.front();
            n.popFront;
            destroy(*oldN);
        }
        assert(owner);
        // Move the remaining allocator on stack, then deallocate from it too
        Allocator temp = void;
        import core.stdc.string : memcpy;
        memcpy(&temp, &owner.a, Allocator.sizeof);
        static __gshared Allocator empty;
        memcpy(&owner.a, &empty, Allocator.sizeof);
        temp.deallocateAll;
        allocators = null;
        rootIndex = rootIndex.max;
        // temp's destructor will take care of the rest
    }

    bool empty() const
    {
        return !allocators.length;
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
    b1 = a.allocate(1024 * 10);
    assert(b1.length == 1024 * 10);
    auto b2 = a.allocate(1024 * 4095);
    a.deallocateAll();
    assert(a.empty);
}
