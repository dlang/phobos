module std.experimental.allocator.kernighan_ritchie;
import std.experimental.allocator.null_allocator;

//debug = KRBlock;
debug(KRBlock) import std.stdio;
version(unittest) import std.conv : text;

// KRBlock
/**
$(D KRBlock) draws inspiration from the
$(WEB stackoverflow.com/questions/13159564/explain-this-implementation-of-malloc-from-the-kr-book,
famed allocator) described by Brian Kernighan and Dennis Ritchie in section 8.7
of the book $(WEB amazon.com/exec/obidos/ASIN/0131103628/classicempire, "The C
Programming Language"), Second Edition, Prentice Hall, 1988.

The recommended usage for $(D KRBlock) is as a simple means to add
$(D deallocate) to a region.

A $(D KRBlock) manages a single contiguous chunk of memory by embedding a free
blocks list onto it. It is a very simple allocator with good memory utilization.
$(D KRBlock) has a small control structure and no per-allocation overhead. Its
disadvantages include proneness to fragmentation, a minimum allocation size of
two words, and slow allocation and deallocation  times, in the worst case
proportional to the number of free (previously allocated and then deallocated)
blocks. So $(D KRBlock) should be used for simple allocation patterns, or
for coarse-granular allocations in conjunction with faster allocators.

The smallest size that can be allocated is two words (16 bytes on 64-bit
systems, 8 bytes on 32-bit systems). This is because the free list management
needs two words (one for the length, the other for the next pointer in the
singly-linked list).

Similarities with the Kernighan-Ritchie allocator:

$(UL
$(LI Free blocks have variable size and are linked in a singly-linked list.)
$(LI The freelist is maintained in increasing address order, which makes
coalescing easy.)
$(LI The strategy for finding the next available block is first fit.)
$(LI The free list is circular, with the last node pointing back to the first.)
$(LI Coalescing is carried during deallocation.)
)

Differences from the Kernighan-Ritchie allocator:

$(UL
$(LI Once the chunk is exhausted, the Kernighan-Ritchie allocator allocates
another chunk using operating system primitives. For better composability, $(D
KRBlock) just gets full (returns $(D null) on new allocation requests). The
decision to allocate more blocks is deferred to a higher-level entity. For an
example, see the example below using $(D AllocatorList) in conjunction with $(D
KRBlock).)
$(LI Allocated blocks do not hold a size prefix. This is because in D the size
information is available in client code at deallocation time.)
)

Initially the freelist has only one element, which covers the entire chunk of
memory. The maximum amount that can be allocated is the full chunk (there is no
size overhead for allocated blocks). As memory gets allocated and deallocated,
the free list will evolve accordingly whilst staying sorted at all times.

The $(D ParentAllocator) type parameter is the type of the allocator used to
allocate the memory chunk underlying the $(D KRBlock) object. Choosing the
default ($(D NullAllocator)) means the user is responsible for passing a buffer
at construction (and for deallocating it if necessary). Otherwise, $(D KRBlock)
automatically deallocates the buffer during destruction. For that reason, if
$(D ParentAllocator) is not $(D NullAllocator), then $(D KRBlock) is not
copyable.

*/
struct KRBlock(ParentAllocator = NullAllocator)
{
    import std.experimental.allocator.common : stateSize, alignedAt;
    import std.traits : hasMember;

    private static struct Node
    {
        import std.typecons : tuple, Tuple;

        Node* next;
        size_t size;

        this(this) @disable;

        void[] payload() inout
        {
            return (cast(ubyte*) &this)[0 .. size];
        }

        bool adjacent(in Node* right) const
        {
            assert(right);
            auto p = payload;
            return p.ptr + p.length == right;
        }

        void coalesce()
        {
            if (adjacent(next))
            {
                size += next.size;
                next = next.next;
            }
        }

        Tuple!(void[], Node*) allocateHere(size_t bytes)
        {
            assert(bytes >= Node.sizeof);
            assert(bytes % Node.alignof == 0);
            assert(next);
            assert(!adjacent(next));
            if (size < bytes) return typeof(return)();
            assert(size >= bytes);
            auto leftover = size - bytes;
            if (leftover >= Node.sizeof)
            {
                // There's room for another node
                auto newNode = cast(Node*) ((cast(ubyte*) &this) + bytes);
                newNode.size = leftover;
                newNode.next = next == &this ? newNode : next;
                assert(next);
                return tuple(payload, newNode);
            }
            // No slack space, just return next node
            return tuple(payload, next == &this ? null : next);
        }
    }

    // state {
    /**
    If $(D ParentAllocator) holds state, $(D parent) is a public member of type
    $(D KRBlock). Otherwise, $(D parent) is an $(D alias) for
    $(D ParentAllocator.it).
    */
    static if (stateSize!ParentAllocator) ParentAllocator parent;
    else alias parent = ParentAllocator.it;
    private void[] payload;
    Node* root;
    // }

    auto byNodePtr()
    {
        static struct Range
        {
            Node* start, current;
            @property bool empty() { return !current; }
            @property Node* front() { return current; }
            void popFront()
            {
                current = current.next;
                if (current == start) current = null;
            }
            @property Range save() { return this; }
        }
        import std.range : isForwardRange;
        static assert(isForwardRange!Range);
        return Range(root, root);
    }

    string toString()
    {
        import std.format : format;
        string s = "KRBlock@";
        s ~= format("%s-%s(0x%s[%s]", &this, &this + 1,
            payload.ptr, payload.length);
        Node* lastNode = null;
        foreach (node; byNodePtr)
        {
            s ~= format(", %sfree(0x%s[%s])",
                lastNode && lastNode.adjacent(node) ? "+" : "",
                cast(void*) node, node.size);
            lastNode = node;
        }
        s ~= ')';
        return s;
    }

    private void assertValid(string s)
    {
        if (!payload.ptr)
        {
            assert(!root, s);
            return;
        }
        if (!root)
        {
            return;
        }
        assert(root >= payload.ptr, s);
        assert(root < payload.ptr + payload.length, s);

        // Check that the list terminates
        size_t n;
        foreach (node; byNodePtr)
        {
            assert(node.next);
            assert(!node.adjacent(node.next));
            assert(n++ < payload.length / Node.sizeof, s);
        }
    }

    /**
    Create a $(D KRBlock). If $(D ParentAllocator) is not $(D NullAllocator),
    $(D KRBlock)'s destructor will call $(D parent.deallocate).

    Params:
    b = Block of memory to serve as support for the allocator. Memory must be
    larger than two words and word-aligned.
    n = Capacity desired. This constructor is defined only if $(D
    ParentAllocator) is not $(D NullAllocator).
    */
    this(void[] b)
    {
        if (b.length < Node.sizeof)
        {
            // Init as empty
            assert(root is null);
            assert(payload is null);
            return;
        }
        assert(b.length >= Node.sizeof);
        assert(b.ptr.alignedAt(Node.alignof));
        assert(b.length >= 2 * Node.sizeof);
        payload = b;
        root = cast(Node*) b.ptr;
        // Initialize the free list with all list
        root.next = root;
        root.size = b.length;
        debug(KRBlock) writefln("KRBlock@%s: init with %s[%s]", &this,
            b.ptr, b.length);
    }

    /// Ditto
    static if (!is(ParentAllocator == NullAllocator))
    this(size_t n)
    {
        assert(n > Node.sizeof);
        this(parent.allocate(n));
    }

    /// Ditto
    static if (!is(ParentAllocator == NullAllocator)
        && hasMember!(ParentAllocator, "deallocate"))
    ~this()
    {
        parent.deallocate(payload);
    }

    /*
    Noncopyable
    */
    @disable this(this);

    /**
    Word-level alignment.
    */
    enum alignment = Node.alignof;

    /**
    Allocates $(D n) bytes. Allocation searches the list of available blocks
    until a free block with $(D n) or more bytes is found (first fit strategy).
    The block is split (if larger) and returned.

    Params: n = number of bytes to _allocate

    Returns: A word-aligned buffer of $(D n) bytes, or $(D null).
    */
    void[] allocate(size_t n)
    {
        if (!n || !root) return null;
        auto actualBytes = goodAllocSize(n);
        // Try to allocate from next after the iterating node
        for (auto pnode = root;;)
        {
            assert(!pnode.adjacent(pnode.next));
            auto k = pnode.next.allocateHere(actualBytes);
            if (k[0] !is null)
            {
                // awes
                assert(k[0].length >= n);
                if (root == pnode.next) root = k[1];
                pnode.next = k[1];
                return k[0][0 .. n];
            }
            pnode = pnode.next;
            if (pnode == root) break;
        }
        return null;
    }

    /**
    Deallocates $(D b), which is assumed to have been previously allocated with
    this allocator. Deallocation performs a linear search in the free list to
    preserve its sorting order. It follows that blocks with higher addresses in
    allocators with many free blocks are slower to deallocate.

    Params: b = block to be deallocated
    */
    void deallocate(void[] b)
    {
        debug(KRBlock) writefln("KRBlock@%s: deallocate(%s[%s])", &this,
            b.ptr, b.length);
        if (!b.ptr) return;
        assert(owns(b));
        assert(b.ptr.alignedAt(Node.alignof));
        // Insert back in the freelist, keeping it sorted by address. Do not
        // coalesce at this time. Instead, do it lazily during allocation.
        auto n = cast(Node*) b.ptr;
        n.size = goodAllocSize(b.length);

        if (!root)
        {
            // What a sight for sore eyes
            root = n;
            root.next = root;
            return;
        }

        version(assert) foreach (test; byNodePtr)
        {
            assert(test != n);
        }
        // Linear search
        auto pnode = root;
        do
        {
            assert(pnode && pnode.next);
            assert(pnode != n);
            assert(pnode.next != n);
            if (pnode < pnode.next)
            {
                if (pnode >= n || n >= pnode.next) continue;
                // Insert in between pnode and pnode.next
                n.next = pnode.next;
                pnode.next = n;
                n.coalesce;
                pnode.coalesce;
                root = pnode;
                return;
            }
            else if (pnode < n)
            {
                // Insert at the end of the list
                n.next = pnode.next;
                pnode.next = n;
                pnode.coalesce;
                root = pnode;
                return;
            }
            else if (n < pnode.next)
            {
                // Insert at the front of the list
                n.next = pnode.next;
                pnode.next = n;
                n.coalesce;
                root = n;
                return;
            }
        }
        while ((pnode = pnode.next) != root);
        assert(0, "Wrong parameter passed to deallocate");
    }

    /**
    Allocates all memory available to this allocator. If the allocator is empty,
    returns the entire available block of memory. Otherwise, it still performs
    a best-effort allocation: if there is no fragmentation (e.g. $(D allocate)
    has been used but not $(D deallocate)), allocates and returns the only
    available block of memory.

    The operation takes time proportional to the number of adjacent free blocks
    at the front of the free list. These blocks get coalesced, whether
    $(D allocateAll) succeeds or fails due to fragmentation.
    */
    void[] allocateAll()
    {
        //debug(KRBlock) assertValid("allocateAll");
        //debug(KRBlock) scope(exit) assertValid("allocateAll");
        auto result = allocate(payload.length);
        // The attempt above has coalesced all possible blocks
        if (!result.ptr && root && root == root.next)
            result = allocate(root.size);
        return result;
    }

    ///
    unittest
    {
        import std.experimental.allocator.gc_allocator;
        auto alloc = KRBlock!GCAllocator(1024 * 64);
        auto b1 = alloc.allocate(2048);
        assert(b1.length == 2048);
        auto b2 = alloc.allocateAll;
        assert(b2.length == 1024 * 62);
    }

    /**
    Deallocates all memory currently allocated, making the allocator ready for
    other allocations. This is a $(BIGOH 1) operation.
    */
    void deallocateAll()
    {
        debug(KRBlock) assertValid("deallocateAll");
        debug(KRBlock) scope(exit) assertValid("deallocateAll");
        root = cast(Node*) payload.ptr;
        // Initialize the free list with all list
        if (root)
        {
            root.next = root;
            root.size = payload.length;
        }
    }

    /**
    Checks whether the allocator is responsible for the allocation of $(D b).
    It does a simple $(BIGOH 1) range check. $(D b) should be a buffer either
    allocated with $(D this) or obtained through other means.
    */
    bool owns(void[] b)
    {
        debug(KRBlock) assertValid("owns");
        debug(KRBlock) scope(exit) assertValid("owns");
        return b.ptr >= payload.ptr && b.ptr < payload.ptr + payload.length;
    }

    /**
    Adjusts $(D n) to a size suitable for allocation (two words or larger,
    word-aligned).
    */
    static size_t goodAllocSize(size_t n)
    {
        import std.experimental.allocator.common : roundUpToMultipleOf;
        return n <= Node.sizeof
            ? Node.sizeof : n.roundUpToMultipleOf(alignment);
    }

    bool empty()
    {
        return root && root.size == payload.length;
    }
}

/**
$(D KRBlock) is preferable to $(D Region) as a front for a general-purpose
allocator if $(D deallocate) is needed, yet the actual deallocation traffic is
relatively low. The example below shows a $(D KRBlock) using stack storage
fronting the GC allocator.
*/
unittest
{
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.fallback_allocator;
    // KRBlock fronting a general-purpose allocator
    ubyte[1024 * 128] buf;
    auto alloc = fallbackAllocator(KRBlock!()(buf), GCAllocator.it);
    auto b = alloc.allocate(100);
    assert(b.length == 100);
    assert(alloc.primary.owns(b));
}

/**
The code below defines a scalable allocator consisting of 1 MB (or larger)
blocks fetched from the garbage-collected heap. Each block is organized as a
KR-style heap. More blocks are allocated and freed on a need basis.

This is the closest example to the allocator introduced in the K$(AMP)R book.
It should perform slightly better because instead of searching through one
large free list, it searches through several shorter lists in LRU order. Also,
it actually returns memory to the operating system when possible.
*/
unittest
{
    import std.algorithm : max;
    import std.experimental.allocator.gc_allocator,
        std.experimental.allocator.mmap_allocator,
        std.experimental.allocator.allocator_list;
    AllocatorList!(n => KRBlock!MmapAllocator(max(n * 16, 1024 * 1024))) alloc;
}

unittest
{
    import std.algorithm : max;
    import std.experimental.allocator.gc_allocator,
        std.experimental.allocator.mallocator,
        std.experimental.allocator.allocator_list;
    /*
    Create a scalable allocator consisting of 1 MB (or larger) blocks fetched
    from the garbage-collected heap. Each block is organized as a KR-style
    heap. More blocks are allocated and freed on a need basis.
    */
    AllocatorList!(n => KRBlock!Mallocator(max(n * 16, 1024 * 1024)),
        NullAllocator) alloc;
    void[][50] array;
    foreach (i; 0 .. array.length)
    {
        auto length = i * 100000 + 1;
        array[i] = alloc.allocate(length);
        assert(array[i].ptr);
        assert(array[i].length == length);
    }
    import std.random;
    randomShuffle(array[]);
    foreach (i; 0 .. array.length)
    {
        assert(array[i].ptr);
        assert(alloc.owns(array[i]));
        alloc.deallocate(array[i]);
    }
}

unittest
{
    import std.algorithm : max;
    import std.experimental.allocator.gc_allocator,
        std.experimental.allocator.mmap_allocator,
        std.experimental.allocator.allocator_list;
    /*
    Create a scalable allocator consisting of 1 MB (or larger) blocks fetched
    from the garbage-collected heap. Each block is organized as a KR-style
    heap. More blocks are allocated and freed on a need basis.
    */
    AllocatorList!((n) {
        auto result = KRBlock!MmapAllocator(max(n * 2, 1024 * 1024));
        return result;
    }) alloc;
    void[][490] array;
    foreach (i; 0 .. array.length)
    {
        auto length = i * 10000 + 1;
        array[i] = alloc.allocate(length);
        assert(array[i].ptr);
        foreach (j; 0 .. i)
        {
            assert(array[i].ptr != array[j].ptr);
        }
        assert(array[i].length == length);
    }
    import std.random;
    randomShuffle(array[]);
    foreach (i; 0 .. array.length)
    {
        assert(alloc.owns(array[i]));
        alloc.deallocate(array[i]);
    }
}

unittest
{
    import std.experimental.allocator.gc_allocator,
        std.experimental.allocator.allocator_list, std.algorithm;
    import std.experimental.allocator.common;
    testAllocator!(() => AllocatorList!(
        n => KRBlock!GCAllocator(max(n * 16, 1024 * 1024)))());
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock!GCAllocator(1024 * 1024);
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
    auto alloc = KRBlock!()(GCAllocator.it.allocate(1024 * 1024));
    auto store = alloc.allocate(KRBlock!().sizeof);
    auto p = cast(KRBlock!()* ) store.ptr;
    import std.conv : emplace;
    import std.algorithm : move;
    import core.stdc.string : memcpy;

    memcpy(p, &alloc, alloc.sizeof);
    emplace(&alloc);

    void[][100] array;
    foreach (i; 0 .. array.length)
    {
        auto length = 100 * i + 1;
        array[i] = p.allocate(length);
        assert(array[i].length == length, text(array[i].length));
        assert(p.owns(array[i]));
    }
    import std.random;
    randomShuffle(array[]);
    foreach (i; 0 .. array.length)
    {
        assert(p.owns(array[i]));
        p.deallocate(array[i]);
    }
    auto b = p.allocateAll();
    assert(b.length == 1024 * 1024 - KRBlock!().sizeof, text(b.length));
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock!()(GCAllocator.it.allocate(1024 * 1024));
    auto p = alloc.allocateAll();
    assert(p.length == 1024 * 1024);
    alloc.deallocateAll();
    p = alloc.allocateAll();
    assert(p.length == 1024 * 1024);
}

