/**
Contains a number of artifacts related to the
$(WEB stackoverflow.com/questions/13159564/explain-this-implementation-of-malloc-from-the-kr-book
famed allocator) described by Brian Kernighan and Dennis Ritchie in section 8.7
of the book "The C Programming Language" Second Edition, Prentice Hall, 1988.
*/
module std.experimental.allocator.kernighan_ritchie;

//debug = KRBlock;
debug(KRBlock) import std.stdio;

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
    import std.format : format;

    private static struct Node
    {
        import std.typecons;

        Node* next;
        size_t size;

        //this(this) @disable;

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
                size = cast(ubyte*) next + next.size - cast(ubyte*) &this;
                next = next.next;
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

    private void[] payload;
    Node root; // size for the root contains total bytes allocated

    string toString()
    {
        string s = "KRBlock@";
        s ~= format("%s-%s(0x%s[%s]", &this, &this + 1,
            payload.ptr, payload.length);
        for (auto j = root.next; j; j = j.next)
        {
            s ~= format(", free(0x%s[%s])", cast(void*) j, j.size);
        }
        s ~= ')';
        assert(root.next != &root);
        return s;
    }

    private void assertValid(string s)
    {
        if (!payload.ptr)
        {
            assert(!root.next, s);
            return;
        }
        if (!root.next)
        {
            return;
        }
        assert(root.next >= payload.ptr, s);
        assert(root.next < payload.ptr + payload.length, s);

        // Check that the list terminates
        size_t n;
        for (auto i = &root, j = root.next; j; i = j, j = j.next)
        {
            assert(n++ < payload.length / Node.sizeof, s);
        }
    }

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
        root.size = 0;
        // Initialize the free list with all list
        with (root.next)
        {
            next = null;
            size = b.length;
        }
        debug(KRBlock) writefln("KRBlock@%s: init with %s[%s]", &this,
            b.ptr, b.length);
    }

    /** Alignment is the same as for a $(D struct) consisting of two words (a
    pointer followed by a $(D size_t).)
    */
    enum alignment = Node.alignof;

    /// Allocator primitives.
    void[] allocate(size_t bytes)
    {
        if (!bytes) return null;
        auto actualBytes = goodAllocSize(bytes);
        // First fit
        for (auto i = &root, j = root.next; j; i = j, j = j.next)
        {
            assert(j != &root);
            auto k = j.allocateHere(actualBytes);
            if (k[0] is null) continue;
            // Allocated, update freelist
            i.next = k[1];
            debug(KRBlock) writefln("KRBlock@%s: allocate returning %s[%s]",
                &this,
                k[0].ptr, bytes);
            root.size += actualBytes;
            return k[0][0 .. bytes];
        }
        debug(KRBlock) writefln("KRBlock@%s: allocate returning null", &this);
        return null;
    }

    /// Ditto
    void deallocate(void[] b)
    {
        debug(KRBlock) writefln("KRBlock@%s: deallocate(%s[%s])", &this,
            b.ptr, b.length);
        // Insert back in the freelist, keeping it sorted by address. Do not
        // coalesce at this time. Instead, do it lazily during allocation.
        if (!b.ptr) return;
        assert(owns(b));
        assert(b.ptr !is &root, format("This is weird @%s[%s]", b.ptr, b.length));
        auto n = cast(Node*) b.ptr;
        n.size = goodAllocSize(b.length);
        root.size -= n.size;
        // Linear search
        for (auto i = &root, j = root.next; ; i = j, j = j.next)
        {
            if (!j)
            {
                // Insert at end
                i.next = n;
                n.next = null;
                return;
            }
            if (j < n) continue;
            // node is in between i and j
            assert(i != n && j != n,
                format("Double deallocation of block %s (%s bytes)",
                    b.ptr, b.length));
            n.next = j;
            i.next = n;
            return;
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
        root.size = 0;
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

    /// Ditto
    static size_t goodAllocSize(size_t s)
    {
        import std.experimental.allocator.common : roundUpToMultipleOf;
        return s <= Node.sizeof
            ? Node.sizeof : s.roundUpToMultipleOf(alignment);
    }

    /// Ditto
    bool empty() const { return root.size == 0; }
}

///
unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock(GCAllocator.it.allocate(1024 * 1024));
    assert(alloc.empty);
    void[][] array;
    foreach (i; 1 .. 4)
    {
        array ~= alloc.allocate(i);
        assert(!alloc.empty);
        assert(array[$ - 1].length == i);
    }
    alloc.deallocate(array[1]);
    alloc.deallocate(array[0]);
    alloc.deallocate(array[2]);
    assert(alloc.empty);
    assert(alloc.allocateAll().length == 1024 * 1024);
    assert(!alloc.empty);
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock(GCAllocator.it.allocate(1024 * 1024));
    auto store = alloc.allocate(KRBlock.sizeof);
    assert(alloc.root.next !is &alloc.root);
    auto p = cast(KRBlock* ) store.ptr;
    import std.algorithm : move;
    alloc.move(*p);
    assert(p.root.next !is &p.root);
    //writeln(*p);

    void[][] array;
    foreach (i; 1 .. 4)
    {
        array ~= p.allocate(i);
        assert(array[$ - 1].length == i);
    }
    p.deallocate(array[1]);
    p.deallocate(array[0]);
    p.deallocate(array[2]);
    assert(p.allocateAll() is null);
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

// KRAllocator
/**
$(D KRAllocator) implements a full-fledged KR-style allocator based upon

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
*/
struct KRAllocator(ParentAllocator)
{
    import std.experimental.allocator.common : stateSize;
    import std.algorithm : isSorted, map;

    // state {
    static if (stateSize!ParentAllocator) ParentAllocator parent;
    else alias parent = ParentAllocator.it;
    private KRBlock[] blocks;
    // } state

    //@disable this(this);

    private KRBlock* blockFor(void[] b)
    {
        import std.range : isInputRange;
        static assert(isInputRange!(KRBlock[]));
        import std.range : assumeSorted;
        auto ub = blocks.map!((ref a) => a.payload.ptr)
            .assumeSorted
            .upperBound(b.ptr);
        if (ub.length == blocks.length) return null;
        auto result = &(blocks[$ - ub.length - 1]);
        assert(result.payload.ptr <= b.ptr);
        return result.payload.ptr + result.payload.length > b.ptr
            ? result : null;
    }

    /// Allocator primitives
    enum alignment = KRBlock.alignment;

    /// ditto
    static size_t goodAllocSize(size_t n)
    {
        return KRBlock.goodAllocSize(n);
    }

    void[] allocate(size_t n)
    {
        foreach (ref alloc; blocks)
        {
            auto result = alloc.allocate(n);
            if (result.ptr)
            {
                return result;
            }
        }
        // Couldn't allocate using the current battery of allocators, get a
        // new one
        import std.conv : emplace;
        import std.algorithm : max, move, swap;
        void[] untypedBlocks = blocks;

        auto n00b = KRBlock(parent.allocate(
            max(1024 * 64, untypedBlocks.length + KRBlock.sizeof + n)));
        untypedBlocks =
            n00b.allocate(untypedBlocks.length + KRBlock.sizeof);
        untypedBlocks[0 .. $ - KRBlock.sizeof] = cast(void[]) blocks[];
        deallocate(blocks);
        blocks = cast(KRBlock[]) untypedBlocks;
        n00b.move(blocks[$ - 1]);

        // Bubble the new element into the sorted array
        for (auto i = blocks.length - 1; i > 0; --i)
        {
            if (blocks[i - 1].payload.ptr < blocks[i].payload.ptr)
            {
                return blocks[i].allocate(n);
            }
            swap(blocks[i], blocks[i - 1]);
        }
        assert(blocks.map!((ref a) => a.payload.ptr).isSorted);
        return blocks[0].allocate(n);
    }

    bool owns(void[] b)
    {
        return blockFor(b) !is null;
    }

    void deallocate(void[] b)
    {
        if (!b.ptr) return;
        if (auto block = blockFor(b))
        {
            assert(block.owns(b));
            return block.deallocate(b);
        }
        assert(false, "KRAllocator.deallocate: invalid argument.");
    }

    void deallocateAll()
    {
        blocks = null;
    }
}

///
unittest
{
    import std.experimental.allocator.gc_allocator, std.algorithm, std.array,
        std.stdio;
    KRAllocator!GCAllocator alloc;
    void[][] array;
    foreach (i; 1 .. 4)
    {
        array ~= alloc.allocate(i);
        assert(array[$ - 1].ptr);
        assert(array.length == 1 || array[$ - 2].ptr != array[$ - 1].ptr);
        assert(array[$ - 1].length == i);
        assert(alloc.owns(array.back));
        assert(alloc.blockFor(array.front) !is null);
        assert(alloc.blockFor(array.back) !is null);
    }
    alloc.deallocate(array[1]);
    alloc.deallocate(array[0]);
    alloc.deallocate(array[2]);
    import std.experimental.allocator.common;
    testAllocator!(() => KRAllocator!GCAllocator());
}
