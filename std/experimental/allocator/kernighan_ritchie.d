/**
Contains a number of artifacts related to the famed allocator described by Brian
Kernighan and Dennis Ritchie in section 8.7 of the book "The C Programming
Language" Second Edition, Prentice Hall, 1988.
*/
module std.experimental.allocator.kernighan_ritchie;

// KRBlock
/**
A $(D KRBlock) manages a single contiguous chunk of memory by embedding a free
blocks list onto it. It is a very simple allocator with low size overhead. Its
disadvantages include proneness to fragmentation and slow allocation and
deallocation  times, in the worst case proportional to the number of free nodes.
So $(D KRBlock) should be used for simple allocation needs, or for
coarse-granular allocations in conjunction with specialized allocators for small
objects.

The smallest size that can be allocated is two words (16 bytes on 64-bit
systems). This is because the freelist management needs two words (one for the
length, the other for the next pointer in the singly-linked list).

Similarities with the Kernighan-Ritchie allocator:

$(UL

$(LI Free blocks have variable size and are linked in a singly-linked list.)

$(LI The freelist is maintained in increasing address order.)

$(LI The strategy for finding the next available block is first fit.)

)

Differences from the Kernighan-Ritchie allocator:

$(UL

$(LI Once the chunk is exhausted, the Kernighan-Ritchie allocator allocates
another chunk. The $(D KRBlock) just gets full (returns $(D null) on
new allocation requests). The decision to allocate more blocks is left to a
higher-level entity.)

$(LI The freelist in the Kernighan-Ritchie allocator is circular, with the last
node pointing back to the first; in $(D KRBlock), the last pointer is
$(D null).)

$(LI Allocated blocks do not have a size prefix. This is because in D the size
information is available in client code at deallocation time.)

$(LI The Kernighan-Ritchie allocator performs eager coalescing. $(D KRBlock)
coalesces lazily, i.e. only attempts it for allocation requests larger than
the memory available. This saves work if most allocations are of similar size
becase there's no repeated churn for coalescing followed by splitting. Also,
the coalescing work is proportional with allocation size, which is advantageous
because large allocations are likely to undergo relatively intensive work in
client code.)

)

Initially the freelist has only one element, which covers the entire chunk of
memory. The maximum amount that can be allocated is the full chunk (there is no
size overhead for allocated blocks). As memory gets allocated and deallocated,
the free list will evolve accordingly whilst staying sorted at all times.

*/
struct KRBlock
{
    private static struct Node
    {
        import std.typecons;

        Node* next;
        size_t size;

        this(this) @disable;

        void[] payload()
        {
            return (cast(ubyte*) &this)[0 .. size];
        }

        Tuple!(void[], Node*) allocateHere(size_t bytes)
        {
            while (size < bytes)
            {
                // Try to coalesce
                if (!next || !adjacent(next))
                {
                    // no honey
                    return typeof(return)();
                }
                next = next.next;
                size = cast(ubyte*) next + next.size - cast(ubyte*) &this;
                if (size >= bytes) break;
            }
            assert(size >= bytes);
            auto leftover = size - bytes;
            if (leftover > Node.sizeof)
            {
                // There's room for another node
                auto newNode = cast(Node*) ((cast(ubyte*) &this) + bytes);
                newNode.size = leftover;
                newNode.next = next;
                next = newNode;
                return tuple(payload, newNode);
            }
            // No slack space, just return next node
            return tuple(payload, next);
        }

        bool adjacent(in Node* right) const
        {
            assert(&this < right);
            return cast(ubyte*) &this + size + Node.sizeof >=
                cast(ubyte*) right;
        }
    }

    void[] payload;
    private Node root; // size is unused for the root

    /**
    Create a $(D KRBlock) managing a chunk of memory. Memory must be
    larger than two words, word-aligned, and of size multiple of $(D
    size_t.alignof).
    */
    this(void[] b)
    {
        assert(b.length > Node.sizeof);
        assert(b.length % alignment == 0);
        assert(b.length >= 2 * Node.sizeof);
        payload = b;
        root.next = cast(Node*) b.ptr;
        root.size = size_t.max; // asserts will fail if read
        // Initialize the free list with all list
        with (root.next)
        {
            next = null;
            size = b.length;
        }
    }

    /** Alignment is the same as for a $(D struct) consisting of two words (a
    pointer followed by a $(D size_t).)
    */
    enum alignment = Node.alignof;

    /// Allocator primitives.
    void[] allocate(size_t bytes)
    {
        auto actualBytes = goodAllocSize(bytes);
        // First fit
        for (auto i = &root, j = root.next; j; i = j, j = j.next)
        {
            auto k = j.allocateHere(actualBytes);
            if (k[0] is null) continue;
            // Allocated, update freelist
            i.next = k[1];
            return k[0][0 .. bytes];
        }
        return null;
    }

    /// Ditto
    void deallocate(void[] b)
    {
        // Insert back in the freelist, keeping it sorted by address. Do not
        // coalesce at this time. Instead, do it lazily during allocation.
        if (!b) return;
        auto n = cast(Node*) b.ptr;
        n.size = goodAllocSize(b.length);
        // Linear search
        for (auto i = &root, j = root.next; ; i = j, j = j.next)
        {
            if (!j)
            {
                // Insert at end
                i.next = n;
                n.next = null;
                break;
            }
            if (j < n) continue;
            // node is in between i and j
            assert(n < j);
            n.next = j;
            i.next = n;
            break;
        }
    }

    /// Ditto
    void[] allocateAll()
    {
        return allocate(payload.length);
    }

    /// Ditto
    void deallocateAll()
    {
        root.next = cast(Node*) payload.ptr;
        // Initialize the free list with all list
        with (root.next)
        {
            next = null;
            size = payload.length;
        }
    }

    /// Ditto
    bool owns(void[] b)
    {
        return b.ptr >= payload.ptr && b.ptr < payload.ptr + payload.length;
    }

    // Ditto
    static size_t goodAllocSize(size_t s)
    {
        import std.experimental.allocator.common : roundUpToMultipleOf;
        return s <= Node.sizeof
            ? Node.sizeof : s.roundUpToMultipleOf(alignment);
    }
}

///
unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock(GCAllocator.it.allocate(1024 * 1024));
    void[][] array;
    foreach (i; 1 .. 4)
    {
        array ~= alloc.allocate(i);
        assert(array[$ - 1].length == i);
    }
    alloc.deallocate(array[1]);
    alloc.deallocate(array[0]);
    alloc.deallocate(array[2]);
    assert(alloc.allocateAll().length == 1024 * 1024);
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock(GCAllocator.it.allocate(1024 * 1024));
    auto p = alloc.allocateAll();
    assert(p.length == 1024 * 1024);
    alloc.deallocateAll();
    p = alloc.allocateAll();
    assert(p.length == 1024 * 1024);
}

unittest
{
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.common;
    auto m = Mallocator.it.allocate(1024 * 64);
    testAllocator!(() => KRBlock(m));
}
