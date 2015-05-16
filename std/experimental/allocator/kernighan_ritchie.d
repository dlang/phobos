/**
Contains a number of artifacts related to the
$(WEB stackoverflow.com/questions/13159564/explain-this-implementation-of-malloc-from-the-kr-book
famed allocator) described by Brian Kernighan and Dennis Ritchie in section 8.7
of the book "The C Programming Language" Second Edition, Prentice Hall, 1988.
*/
module std.experimental.allocator.kernighan_ritchie;
import std.experimental.allocator.null_allocator;

//debug = KRBlock;
debug(KRBlock) import std.stdio;
version(unittest) import std.conv : text;

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
    static if (stateSize!ParentAllocator)
    {
        ParentAllocator parent;
    }
    else
    {
        alias parent = ParentAllocator.it;
    }
    private void[] payload;
    Node* root;
    size_t totalAllocated;
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
    Create a $(D KRBlock) managing a chunk of memory. Memory must be
    larger than two words, word-aligned, and of size multiple of $(D
    size_t.alignof).
    */
    this(void[] b)
    {
        assert(b.length > Node.sizeof);
        assert(b.ptr.alignedAt(Node.alignof));
        assert(b.length >= 2 * Node.sizeof);
        payload = b;
        root = cast(Node*) b.ptr;
        assert(totalAllocated == 0);
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
        this(parent.allocate(n));
    }

    /**
    Destructor releases parent's memory if $(D ParentAllocator) is not $(D
    NullAllocator).
    */
    static if (!is(ParentAllocator == NullAllocator))
    ~this()
    {
        parent.deallocate(payload);
    }

    /**
    Noncopyable
    */
    @disable this(this);

    /**
    Alignment is the same as for a $(D struct) consisting of two words (a
    pointer followed by a $(D size_t).)
    */
    enum alignment = Node.alignof;

    /// Allocator primitives.
    void[] allocate(size_t bytes)
    {
        if (!bytes) return null;
        auto actualBytes = goodAllocSize(bytes);
        // First fit
        for (auto i = &root; *i; i = &(*i).next)
        {
            assert(i);
            assert(*i);
            assert(*i < (*i).next || !(*i).next,
                text(*i, " >= ", (*i).next));
            auto k = (*i).allocateHere(actualBytes);
            if (k[0] is null) continue;
            assert(k[0].length >= bytes);
            // Allocated, update freelist
            assert(*i != k[1]);
            *i = k[1];
            assert(!*i || !(*i).next || *i < (*i).next);
            //debug(KRBlock) writefln("KRBlock@%s: allocate returning %s[%s]",
            //    &this,
            //    k[0].ptr, bytes);
            totalAllocated += actualBytes;
            return k[0][0 .. bytes];
        }
        //debug(KRBlock) writefln("KRBlock@%s: allocate returning null", &this);
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
        assert(b.ptr.alignedAt(Node.alignof));
        auto n = cast(Node*) b.ptr;
        n.size = goodAllocSize(b.length);
        totalAllocated -= n.size;
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

    /// Ditto
    void[] allocateAll()
    {
        //debug(KRBlock) assertValid("allocateAll");
        //debug(KRBlock) scope(exit) assertValid("allocateAll");
        auto result = allocate(payload.length);
        // The attempt above has coalesced all possible blocks
        if (!result.ptr && root && !root.next) result = allocate(root.size);
        return result;
    }

    /// Ditto
    void deallocateAll()
    {
        debug(KRBlock) assertValid("deallocateAll");
        debug(KRBlock) scope(exit) assertValid("deallocateAll");
        root = cast(Node*) payload.ptr;
        totalAllocated = 0;
        // Initialize the free list with all list
        with (root)
        {
            next = null;
            size = payload.length;
        }
        assert(empty);
    }

    /// Ditto
    bool owns(void[] b)
    {
        debug(KRBlock) assertValid("owns");
        debug(KRBlock) scope(exit) assertValid("owns");
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
    bool empty() const
    {
        return totalAllocated == 0;
    }
}

///
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
    AllocatorList!(n => KRBlock!Mallocator(max(n, 1024 * 1024))) alloc;
    void[][49] array;
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
        assert(alloc.owns(array[i]));
        alloc.deallocate(array[i]);
    }
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
    AllocatorList!((n) {
        auto result = KRBlock!Mallocator(max(n, 1024 * 1024));
        return result;
    }) alloc;
    void[][490] array;
    foreach (i; 0 .. array.length)
    {
        auto length = i * 100000 + 1;
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
    testAllocator!(() => AllocatorList!(n => KRBlock!GCAllocator(max(n, 1024 * 1024)))());
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    auto alloc = KRBlock!GCAllocator(1024 * 1024);
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

unittest
{
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.common;
    auto m = Mallocator.it.allocate(1024 * 64);
    testAllocator!(() => KRBlock!()(m));
}

