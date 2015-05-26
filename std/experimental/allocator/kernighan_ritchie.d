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
)

Differences from the Kernighan-Ritchie allocator:

$(UL
$(LI Once the chunk is exhausted, the Kernighan-Ritchie allocator allocates
another chunk using operating system primitives. For better composability, $(D
KRBlock) just gets full (returns $(D null) on new allocation requests). The
decision to allocate more blocks is deferred to a higher-level entity. For an
example, see the example below using $(D AllocatorList) in conjunction with $(D
KRBlock).)
$(LI The free list in the Kernighan-Ritchie allocator is circular, with the last
node pointing back to the first; in $(D KRBlock), the root is the lowest
address in the free list and the last pointer is $(D null).)
$(LI Allocated blocks do not hold a size prefix. This is because in D the size
information is available in client code at deallocation time.)
$(LI The Kernighan-Ritchie allocator performs eager coalescing. $(D KRBlock)
coalesces lazily, i.e. only attempts it for allocation requests larger than
the already available blocks. This saves work if most allocations are of
similar size becase there's no repeated churn for coalescing followed by
splitting. Also, the coalescing work is proportional with allocation size,
which is advantageous because large allocations are likely to undergo
relatively intensive work in client code.)
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
    import std.format : format;
    import std.experimental.allocator.common : stateSize, alignedAt;

    private static struct Node
    {
        import std.typecons : tuple, Tuple;

        Node* next;
        size_t size;

        this(this) @disable;

        void[] payload() inout
        {
            assert(!next || &this < next);
            return (cast(ubyte*) &this)[0 .. size];
        }

        bool adjacent(in Node* right) const
        {
            assert(&this < right, text(&this, " vs ", right));
            auto p = payload;
            return p.ptr + p.length == right;
        }

        Tuple!(void[], Node*) allocateHere(size_t bytes)
        {
            assert(bytes >= Node.sizeof);
            assert(bytes % Node.alignof == 0);
            assert(&this < next || !next, text(&this, " vs ", next));
            while (size < bytes)
            {
                // Try to coalesce
                if (!next || !adjacent(next))
                {
                    // no honey
                    return typeof(return)();
                }
                // Coalesce these two nodes
                size += next.size;
                assert(next < next.next || !next.next);
                next = next.next;
            }
            assert(size >= bytes);
            auto leftover = size - bytes;
            if (leftover >= Node.sizeof)
            {
                // There's room for another node
                auto newNode = cast(Node*) ((cast(ubyte*) &this) + bytes);
                newNode.size = leftover;
                newNode.next = next;
                assert(newNode < newNode.next || !next);
                return tuple(payload, newNode);
            }
            // No slack space, just return next node
            return tuple(payload, next);
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

    string toString()
    {
        string s = "KRBlock@";
        s ~= format("%s-%s(0x%s[%s]", &this, &this + 1,
            payload.ptr, payload.length);
        for (auto j = root; j; j = j.next)
        {
            s ~= format(", free(0x%s[%s])", cast(void*) j, j.size);
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
        for (auto i = root; i; i = i.next)
        {
            assert(i < i.next || !i.next);
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
        with (root)
        {
            next = null;
            size = b.length;
        }
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
    static if (!is(ParentAllocator == NullAllocator))
    ~this()
    {
        parent.deallocate(payload);
    }

    /*
    Noncopyable
    */
    static if (!is(ParentAllocator == NullAllocator))
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
        if (!n) return null;
        auto actualBytes = goodAllocSize(n);
        // First fit
        for (auto i = &root; *i; i = &(*i).next)
        {
            assert(i);
            assert(*i);
            assert(*i < (*i).next || !(*i).next,
                text(*i, " >= ", (*i).next));
            auto k = (*i).allocateHere(actualBytes);
            if (k[0] is null) continue;
            assert(k[0].length >= n);
            // Allocated, update freelist
            assert(*i != k[1]);
            *i = k[1];
            assert(!*i || !(*i).next || *i < (*i).next);
            //debug(KRBlock) writefln("KRBlock@%s: allocate returning %s[%s]",
            //    &this,
            //    k[0].ptr, bytes);
            return k[0][0 .. n];
        }
        //debug(KRBlock) writefln("KRBlock@%s: allocate returning null", &this);
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
        // Insert back in the freelist, keeping it sorted by address. Do not
        // coalesce at this time. Instead, do it lazily during allocation.
        if (!b.ptr) return;
        assert(owns(b));
        assert(b.ptr.alignedAt(Node.alignof));
        auto n = cast(Node*) b.ptr;
        n.size = goodAllocSize(b.length);
        // Linear search
        for (auto i = &root; ; i = &(*i).next)
        {
            assert(i);
            assert(b.ptr != *i);
            assert(!(*i) || !(*i).next || *i < (*i).next);
            if (!*i || n < *i)
            {
                // Insert ahead of *i
                n.next = *i;
                assert(n < n.next || !n.next, text(n, " >= ", n.next));
                *i = n;
                assert(!(*i).next || *i < (*i).next,
                    text(*i, " >= ", (*i).next));
                return;
            }
        }
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
        if (!result.ptr && root && !root.next) result = allocate(root.size);
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
        if (root) with (root)
        {
            next = null;
            size = payload.length;
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
    //emplace(p, alloc.move);

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

