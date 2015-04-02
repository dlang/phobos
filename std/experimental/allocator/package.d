// Written in the D programming language.

/**
Macros:
WIKI = Phobos/StdAllocator
MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco,
"DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>
TDC = <td nowrap>$(D $1)$+</td>
TDC2 = <td nowrap>$(D $(LREF $0))</td>
RES = $(I result)
POST = $(BR)$(SMALL $(I Post:) $(BLUE $(D $0)))

Copyright: Andrei Alexandrescu 2013-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_allocator.d)

This module implements untyped composable memory allocators. They are $(I
untyped) because they deal exclusively in $(D void[]) and have no notion of what
type the memory allocated would be destined for. They are $(I composable)
because the included allocators are building blocks that can be assembled in
complex nontrivial allocators.

$(P Unlike the allocators for the C and C++ programming languages, which manage
the allocated size internally, these allocators require that the client
maintains (or knows $(I a priori)) the allocation size for each piece of memory
allocated. Put simply, the client must pass the allocated size upon
deallocation. Storing the size in the _allocator has significant negative
performance implications, and is virtually always redundant because client code
needs knowledge of the allocated size in order to avoid buffer overruns. (See
more discussion in a $(WEB open-
std.org/JTC1/SC22/WG21/docs/papers/2013/n3536.html, proposal) for sized
deallocation in C++.) For this reason, allocators herein traffic in $(D void[])
as opposed to $(D void*).)

$(P In order to be usable as an _allocator, a type should implement the
following methods with their respective semantics. Only $(D alignment) and  $(D
allocate) are required. If any of the other methods is missing, the _allocator
is assumed to not have that capability (for example some allocators do not offer
manual deallocation of memory).)

$(BOOKTABLE ,
$(TR $(TH Method name) $(TH Semantics))

$(TR $(TDC uint alignment;, $(POST $(RES) > 0)) $(TD Returns the minimum
alignment of all data returned by the allocator. An allocator may implement $(D
alignment) as a statically-known $(D enum) value only. Applications that need
dynamically-chosen alignment values should use the $(D alignedAllocate) and $(D
alignedReallocate) APIs.))

$(TR $(TDC size_t goodAllocSize(size_t n);, $(POST $(RES) >= n)) $(TD Allocators
customarily allocate memory in discretely-sized chunks. Therefore, a request for
$(D n) bytes may result in a larger allocation. The extra memory allocated goes
unused and adds to the so-called $(WEB goo.gl/YoKffF,internal fragmentation).
The function $(D goodAllocSize(n)) returns the actual number of bytes that would
be allocated upon a request for $(D n) bytes. This module defines a default
implementation that returns $(D n) rounded up to a multiple of the allocator's
alignment.))

$(TR $(TDC void[] allocate(size_t s);, $(POST $(RES) is null || $(RES).length ==
s)) $(TD If $(D s == 0), the call may return any empty slice (including $(D
null)). Otherwise, the call allocates $(D s) bytes of memory and returns the
allocated block, or $(D null) if the request could not be satisfied.))

$(TR $(TDC void[] alignedAllocate(size_t s, uint a);, $(POST $(RES) is null ||
$(RES).length == s)) $(TD Similar to $(D allocate), with the additional
guarantee that the memory returned is aligned to at least $(D a) bytes. $(D a)
must be a power of 2.))

$(TR $(TDC void[] allocateAll();) $(TD Offers all of allocator's memory to the
caller, so it's usually defined by fixed-size allocators. If the allocator is
currently NOT managing any memory, then $(D allocateAll()) shall allocate and
return all memory available to the allocator, and subsequent calls to all
allocation primitives should not succeed (e..g $(D allocate) shall return $(D
null) etc). Otherwise, $(D allocateAll) only works on a best-effort basis, and
the allocator is allowed to return $(D null) even if does have available memory.
Memory allocated with $(D allocateAll) is not otherwise special (e.g. can be
reallocated or deallocated with the usual primitives, if defined).))

$(TR $(TDC bool expand(ref void[] b, size_t delta);, $(POST !$(RES) || b.length
== $(I old)(b).length + delta)) $(TD Expands $(D b) by $(D delta) bytes. If $(D
delta == 0), succeeds without changing $(D b). If $(D b is null), the call
evaluates $(D b = allocate(delta)) and returns $(D b !is null). Otherwise, $(D
b) must be a buffer previously allocated with the same allocator. If expansion
was successful, $(D expand) changes $(D b)'s length to $(D b.length + delta) and
returns $(D true). Upon failure, the call effects no change upon the allocator
object, leaves $(D b) unchanged, and returns $(D false).))

$(TR $(TDC bool reallocate(ref void[] b, size_t s);, $(POST !$(RES) || b.length
== s)) $(TD Reallocates $(D b) to size $(D s), possibly moving memory around.
$(D b) must be $(D null) or a buffer allocated with the same allocator. If
reallocation was successful, $(D reallocate) changes $(D b) appropriately and
returns $(D true). Upon failure, the call effects no change upon the allocator
object, leaves $(D b) unchanged, and returns $(D false). An allocator should
implement $(D reallocate) if it can derive some advantage from doing so;
otherwise, this module defines a $(D reallocate) free function implemented in
terms of $(D expand), $(D allocate), and $(D deallocate).))

$(TR $(TDC bool alignedReallocate(ref void[] b,$(BR) size_t s, uint a);, $(POST
!$(RES) || b.length == s)) $(TD Similar to $(D reallocate), but guarantees the
reallocated memory is aligned at $(D a) bytes. The buffer must have been
originated with a call to $(D alignedAllocate). $(D a) must be a power of 2
greater than $(D (void*).sizeof). An allocator should implement $(D
alignedReallocate) if it can derive some advantage from doing so; otherwise,
this module defines a $(D alignedReallocate) free function implemented in terms
of $(D expand), $(D alignedAllocate), and $(D deallocate).))

$(TR $(TDC bool owns(void[] b);) $(TD Returns $(D true) if $(D b) has been
allocated with this allocator. An allocator should define this method only if it
can decide on ownership precisely and fast (in constant time, logarithmic time,
or linear time with a low multiplication factor). Traditional allocators such as
the C heap do not define such functionality. If $(D b is null), the allocator
shall return $(D false), i.e. no allocator owns the $(D null) slice.))

$(TR $(TDC void[] resolveInternalPointer(void* p);) $(TD If $(D p) is a pointer
somewhere inside a block allocated with this allocator, returns a pointer to the
beginning of the allocated block. Otherwise, returns $(D null). If the pointer
points immediately after an allocated block, the result is implementation
defined.))

$(TR $(TDC void deallocate(void[] b);) $(TD If $(D b is null), does
nothing. Otherwise, deallocates memory previously allocated with this
allocator.))

$(TR $(TDC void deallocateAll();, $(POST empty)) $(TD Deallocates all memory
allocated with this allocator. If an allocator implements this method, it must
specify whether its destructor calls it, too.))

$(TR $(TDC bool empty();) $(TD Returns $(D true) if and only if the allocator
holds no memory (i.e. no allocation has occurred, or all allocations have been
deallocated).))

$(TR $(TDC bool zeroesAllocations;) $(TD Enumerated value indicating whether the
allocator zeroes newly allocated memory automatically. If not defined, it is
assumed the allocator does not zero allocated memory.))

$(TR $(TDC static Allocator it;, $(POST it $(I is a valid) Allocator $(I
object))) $(TD Some allocators are $(I monostate), i.e. have only an instance
and hold only global state. (Notable examples are C's own $(D malloc)-based
allocator and D's garbage-collected heap.) Such allocators must define a static
$(D it) instance that serves as the symbolic placeholder for the global instance
of the allocator. An allocator should not hold state and define $(D it)
simultaneously. Depending on whether the allocator is thread-safe or not, this
instance may be $(D shared).))

$(TR $(TDC void markAllAsUnused();, $(POST empty)) $(TD This routine is meant as
an aid for garbage collectors. It is similar to $(D deallocateAll), with an
important distinction: if there's no intervening call to $(D allocate), a
subsequent call $(D markAsUsed(b)) (see below) for any block $(D b) that had
been allocated prior to calling $(D markAllAsUnused) is guaranteed to restore
the allocation status of $(D b). $(D markAllAsUnused) must not affect memory
managed by the allocator at all. This is unlike $(D deallocateAll), which is
allowed to alter managed memory in any way. The primitive $(D
resolveInternalPointer) must continue working unaffected following a call to $(D
markAllAsUnused).))

$(TR $(TDC bool markAsUsed(void[] b);) $(TD This routine is meant as
an aid for garbage collectors. Following a call to $(D
markAllAsUnused), calling $(D markAsUsed(b)) restores $(D b)'s status as an
allocated block. Just like $(D markAllAsUnused), $(D markAsUsed(b)) is not
supposed to affect $(D b) or any other memory managed by the allocator. The
function returns $(D false) if the block had already been marked by a previous
call to $(D markAsUsed), $(D true) otherwise.))

$(TR $(TDC void doneMarking();) $(TD This routine is meant as
an aid for garbage collectors. This call allows the allocator to clear
state following a call to $(D markAllAsUnused) and a series of calls to $(D
markAsUsed).))

)

The example below features an _allocator modeled after $(WEB goo.gl/m7329l,
jemalloc), which uses a battery of free-list allocators spaced so as to keep
internal fragmentation to a minimum. The $(D FList) definitions specify no
bounds for the freelist because the $(D Segregator) does all size selection in
advance.

Sizes through 3584 bytes are handled via freelists of staggered sizes. Sizes
from 3585 bytes through 4072 KB are handled by a $(D HeapBlock) with a
block size of 4 KB. Sizes above that are passed direct to the $(D Mallocator).

----
    alias FList = FreeList!(GCAllocator, 0, unbounded);
    alias A = Segregator!(
        8, FreeList!(GCAllocator, 0, 8),
        128, Bucketizer!(FList, 1, 128, 16),
        256, Bucketizer!(FList, 129, 256, 32),
        512, Bucketizer!(FList, 257, 512, 64),
        1024, Bucketizer!(FList, 513, 1024, 128),
        2048, Bucketizer!(FList, 1025, 2048, 256),
        3584, Bucketizer!(FList, 2049, 3584, 512),
        4072 * 1024, AllocatorList!(
            () => HeapBlock!(GCAllocator, 4096)(4072 * 1024)),
        GCAllocator
    );
    A tuMalloc;
    auto b = tuMalloc.allocate(500);
    assert(b.length == 500);
    auto c = tuMalloc.allocate(113);
    assert(c.length == 113);
    assert(tuMalloc.expand(c, 14));
    tuMalloc.deallocate(b);
    tuMalloc.deallocate(c);
----

$(H2 Allocating memory for sharing across threads)

One allocation pattern used in multithreaded applications is to share memory
across threads, and to deallocate blocks in a different thread than the one that
allocated it.

All allocators in this module accept and return $(D void[]) (as opposed to
$(D shared void[])). This is because at the time of allocation, deallocation, or
reallocation, the memory is effectively not $(D shared) (if it were, it would
reveal a bug at the application level).

The issue remains of calling $(D a.deallocate(b)) from a different thread than
the one that allocated $(D b). It follows that both threads must have access to
the same instance $(D a) of the respective allocator type. By definition of D,
this is possible only if $(D a) has the $(D shared) qualifier. It follows that
the allocator type must implement $(D allocate) and $(D deallocate) as $(D
shared) methods. That way, the allocator commits to allowing usable $(D shared)
instances.

Conversely, allocating memory with one non-$(D shared) allocator, passing it
across threads (by casting the obtained buffer to $(D shared)), and later
deallocating it in a different thread (either with a different allocator object
or with the same allocator object after casting it to $(D shared)) is illegal.

$(BOOKTABLE $(BIG Synopsis of predefined _allocator building blocks),
$(TR $(TH Allocator) $(TH Description))

$(TR $(TDC2 NullAllocator) $(TD Very good at doing absolutely nothing. A good
starting point for defining other allocators or for studying the API.))

$(TR $(TDC2 GCAllocator) $(TD The system-provided garbage-collector allocator.
This should be the default fallback allocator tapping into system memory. It
offers manual $(D free) and dutifully collects litter.))

$(TR $(TDC2 Mallocator) $(TD The C heap _allocator, a.k.a. $(D
malloc)/$(D realloc)/$(D free). Use sparingly and only for code that is unlikely
to leak.))

$(TR $(TDC2 AlignedMallocator) $(TD Interface to OS-specific _allocators that
support specifying alignment:
$(WEB man7.org/linux/man-pages/man3/posix_memalign.3.html, $(D posix_memalign))
on Posix and $(WEB msdn.microsoft.com/en-us/library/fs9stz4e(v=vs.80).aspx,
$(D __aligned_xxx)) on Windows.))

$(TR $(TDC2 AffixAllocator) $(TD Allocator that allows and manages allocating
extra prefix and/or a suffix bytes for each block allocated.))

$(TR $(TDC2 HeapBlock) $(TD Organizes one contiguous chunk of memory in
equal-size blocks and tracks allocation status at the cost of one bit per
block.))

$(TR $(TDC2 FallbackAllocator) $(TD Allocator that combines two other allocators
 - primary and fallback. Allocation requests are first tried with primary, and
 upon failure are passed to the fallback. Useful for small and fast allocators
 fronting general-purpose ones.))

$(TR $(TDC2 FreeList) $(TD Allocator that implements a $(WEB
wikipedia.org/wiki/Free_list, free list) on top of any other allocator. The
preferred size, tolerance, and maximum elements are configurable at compile- and
run time.))

$(TR $(TDC2 SharedFreeList) $(TD Same features as $(D FreeList), but packaged as
a $(D shared) structure that is accessible to several threads.))

$(TR $(TDC2 SimpleBlocklist) $(TD A simple structure on top of a contiguous
block of storage, organizing it as a singly-linked list of blocks. Each block
has a word-sized header consisting of its length massaged with a bit indicating
whether the block is occupied.))

$(TR $(TDC2 Blocklist) $(TD An enhanced block-list style of allocator building
on top of $(D SimpleBlocklist). Each block in the list stores the block size at
the end of the block as well (similarly to the way
$(WEB http://g.oswego.edu/dl/html/malloc.html, dlmalloc) does), which makes it
possible to iterate the block list backward as well as forward. This makes for
better coalescing properties.))

$(TR $(TDC2 Region) $(TD Region allocator organizes a chunk of memory as a
simple bump-the-pointer allocator.))

$(TR $(TDC2 InSituRegion) $(TD Region holding its own allocation, most often on
the stack. Has statically-determined size.))

$(TR $(TDC2 SbrkRegion) $(TD Region using $(D $(LUCKY sbrk)) for allocating
memory.))

$(TR $(TDC2 MmapAllocator) $(TD Allocator using $(D $(LUCKY mmap)) directly.))

$(TR $(TDC2 StatsCollector) $(TD Collect statistics about any other
allocator.))

$(TR $(TDC2 AllocatorList) $(TD Given an allocator factory, lazily creates as
many allocators as needed to satisfy allocation requests. The allocators are
stored in a linked list. Requests for allocation are satisfied by searching the
list in a linear manner.))

$(TR $(TDC2 Segregator) $(TD Segregates allocation requests by size and
dispatches them to distinct allocators.))

$(TR $(TDC2 Bucketizer) $(TD Divides allocation sizes in discrete buckets and
uses an array of allocators, one per bucket, to satisfy requests.))

$(TR $(TDC2 InternalPointersTree) $(TD Adds support for resolving internal
pointers on top of another allocator.))

)
 */

module std.experimental.allocator;

public import
    std.experimental.allocator.affix_allocator,
    std.experimental.allocator.allocator_list,
    std.experimental.allocator.common,
    std.experimental.allocator.fallback_allocator,
    std.experimental.allocator.free_list,
    std.experimental.allocator.gc_allocator,
    std.experimental.allocator.heap_block,
    std.experimental.allocator.mallocator,
    std.experimental.allocator.mmap_allocator,
    std.experimental.allocator.null_allocator,
    std.experimental.allocator.region,
    std.experimental.allocator.stats_collector;

// Example in the synopsis above
unittest
{
    alias FList = FreeList!(GCAllocator, 0, unbounded);
    alias A = Segregator!(
        8, FreeList!(GCAllocator, 0, 8),
        128, Bucketizer!(FList, 1, 128, 16),
        256, Bucketizer!(FList, 129, 256, 32),
        512, Bucketizer!(FList, 257, 512, 64),
        1024, Bucketizer!(FList, 513, 1024, 128),
        2048, Bucketizer!(FList, 1025, 2048, 256),
        3584, Bucketizer!(FList, 2049, 3584, 512),
        4072 * 1024, AllocatorList!(
            () => HeapBlock!(4096)(GCAllocator.it.allocate(4072 * 1024))),
        GCAllocator
    );
    A tuMalloc;
    auto b = tuMalloc.allocate(500);
    assert(b.length == 500);
    auto c = tuMalloc.allocate(113);
    assert(c.length == 113);
    assert(tuMalloc.expand(c, 14));
    tuMalloc.deallocate(b);
    tuMalloc.deallocate(c);
}

import std.algorithm, std.conv, std.exception, std.range, std.traits,
    std.typecons, std.typetuple;
version(unittest) import std.random, std.stdio;

// SimpleBlocklist
/*

A $(D SimpleBlockList) manages a contiguous chunk of memory by embedding a block
list onto it. Blocks have variable size, and each is preceded by exactly one
word that holds that block's size plus a bit indicating whether the block is
occupied.

Initially the list has only one element, which covers the entire chunk of
memory. Due to that block's management and a sentinel at the end, the maximum
amount that can be allocated is $(D n - 2 * size_t.sizeof), where $(D n) is the
entire chunk size. The first allocation will adjust the size of the first block
and will likely create a new free block right after it. As memory gets allocated
and deallocated, the block list will evolve accordingly.

$(D SimpleBlockList) is one of the simplest allocators that is also memory
efficient. However, the allocation speed is $(BIGOH O(n)), where $(D n) is the
number of blocks in use. To improve on that, allocations start at the last
deallocation point, which may lead to constant-time allocation in certain
situations. (Deallocations are $(D O(1))).

Fragmentation is also an issue; the allocator does coalescing but has no special
strategy beyond a simple first fit algorithm. Coalescing of blocks is performed
during allocation. However, a block can be coalesced only with the block of its
right (it is not possible to iterate blocks right to left), which means an
allocation may spend more time searching. So $(D SimpleBlockList) should be used
for simple allocation needs, or for coarse-granular allocations in conjunction
with specialized allocators for small objects.

*/
struct SimpleBlocklist
{
    private enum busyMask = ~(size_t.max >> 1);

    private static struct Node
    {
        size_t _size; // that's all the state

        size_t size()
        {
            return _size & ~busyMask;
        }
        void size(size_t s)
        {
            assert(!occupied, "Can only set size for free nodes");
            _size = s;
        }

        bool occupied() const
        {
            return (_size & busyMask) != 0;
        }

        Node* next()
        {
            return cast(Node*) ((cast(void*) &this) + size);
        }

        void occupy()
        {
            assert(!occupied);
            _size |= busyMask;
        }

        void deoccupy()
        {
            _size &= ~busyMask;
        }

        void coalesce()
        {
            if (occupied) return;
            for (;;)
            {
                auto n = cast(Node*) (cast(void*)&this + _size);
                if (n.occupied) break;
                _size += n._size;
            }
        }
    }

    private auto byNode(Node* from)
    {
        static struct Voldemort
        {
            Node* crt;
            bool empty() { return crt._size == size_t.max; }
            ref Node front() { return *crt; }
            void popFront()
            {
                assert(!empty);
                crt = cast(Node*) (cast(void*)crt + crt.size);
            }
            @property Voldemort save() { return this; }
        }
        auto r = Voldemort(from);
        return r;
    }

    private auto byNodeCoalescing(Node* from)
    {
        static struct Voldemort
        {
            Node* crt;
            bool empty() { return crt._size == size_t.max; }
            ref Node front() { return *crt; }
            void popFront()
            {
                assert(!empty);
                crt = cast(Node*) (cast(void*)crt + crt.size);
                crt.coalesce();
            }
            @property Voldemort save() { return this; }
        }
        auto r = Voldemort(from);
        r.front.coalesce();
        return r;
    }

    private Node* deoccupy(void[] b)
    {
        assert(b);
        auto n = cast(Node*) (b.ptr - Node.sizeof);
        n._size &= ~busyMask;
        return n;
    }

    private Node* root;
    private Node* searchStart;
    private size_t size; // redundant but makes owns() O(1)

    version(unittest) void dump()
    {
        writefln("%s {", typeid(this));
        size_t total = 0;
        scope(exit) writefln("} /*total=%s*/", total);
        foreach (ref n; byNode(root))
        {
            writefln("  Block at 0x%s, length=%s, status=%s",
                cast(void*) &n, n.size, n.occupied ? "occupied" : "free");
            total += n.size;
        }
    }

    /**
    Create a $(D SimpleBlocklist) managing a chunk of memory. Memory must be
    larger than two words, word-aligned, and of size multiple of $(D
    size_t.alignof).
    */
    this(void[] b)
    {
        assert(b.length % alignment == 0);
        assert(b.length >= 2 * Node.sizeof);
        root = cast(Node*) b.ptr;
        size = b.length;
        root._size = size - Node.sizeof;
        root.next._size = size_t.max; // very large occupied node
        searchStart = root;
    }

    private void[] allocate(size_t bytes, Node* start)
    {
        const effective = bytes + Node.sizeof;
        const rounded = effective.roundUpToMultipleOf(alignment);
        assert(rounded < size_t.max / 2);
        // First fit
        auto r = find!(a => !a.occupied && a._size >= rounded)
            (byNodeCoalescing(root));
        if (r.empty) return null;
        // Found!
        auto n = &(r.front());
        const slackSize = n._size - rounded;
        if (slackSize > Node.sizeof)
        {
            // Create a new node at the end of the allocation
            n._size = rounded;
            n.next._size = slackSize;
        }
        n.occupy();
        return (cast(void*) (n + 1))[0 .. bytes];
    }

    /// Standard allocator primitives.
    enum alignment = size_t.alignof;

    /// Ditto
    void[] allocate(size_t bytes)
    {
        auto p = allocate(bytes, searchStart);
        return p ? p : allocate(bytes, root);
    }

    /// Ditto
    void deallocate(void[] b)
    {
        if (!b) return;
        searchStart = cast(Node*) (b.ptr - Node.sizeof);
        searchStart.deoccupy();
        // Don't coalesce now, it'll happen at allocation.
    }

    /// Ditto
    void[] allocateAll()
    {
        // Find the last node coalescing on the way, then allocate all available
        // memory.
        auto r = minPos!((a, b) => !a.occupied && a.size > b.size)
            (byNodeCoalescing(root));
        assert(!r.empty);
        auto n = &r.front();
        if (n.occupied) return null;
        n.occupy();
        return (cast(void*) (n + 1))[0 .. n.size - size_t.sizeof];
    }

    /// Ditto
    void deallocateAll()
    {
        root._size = size - Node.sizeof;
    }

    /// Ditto
    bool owns(void[] b)
    {
        return b.ptr >= root && b.ptr + b.length <= cast(void*) root + size;
    }

    void markAllAsUnused()
    {
        // Walk WITHOUT coalescing and mark as free.
        foreach (ref n; byNode(root))
        {
            n.deoccupy();
        }
    }
    //
    bool markAsUsed(void[] b)
    {
        // Occupy again
        auto n = cast(Node*) (b.ptr - Node.sizeof);
        if (n.occupied) return false;
        n.occupy();
        return true;
    }
    //
    void doneMarking()
    {
        // Maybe do a coalescing here?
    }
}

unittest
{
    auto alloc = SimpleBlocklist(GCAllocator.it.allocate(1024 * 1024));
    auto p = alloc.allocateAll();
    assert(p.length == 1024 * 1024 - 2 * size_t.sizeof);
    alloc.deallocateAll();
    p = alloc.allocateAll();
    assert(p.length == 1024 * 1024 - 2 * size_t.sizeof);
}

unittest
{
    auto alloc = SimpleBlocklist(GCAllocator.it.allocate(1024 * 1024));
    void[][] array;
    foreach (i; 1 .. 4)
    {
        array ~= alloc.allocate(i);
        assert(array[$ - 1].length == i);
    }
    alloc.deallocate(array[1]);
    alloc.deallocate(array[0]);
    alloc.deallocate(array[2]);
    assert(alloc.allocateAll().length == 1024 * 1024 - 2 * size_t.sizeof);
}

// Blocklist
/**

$(D Blocklist) builds additional structure on top of $(D SimpleBlocklist) by
storing the size of each block not only at the beginning, but also at the end of
the block. This allows $(D Blocklist) to iterate in both directions, which
is used for better coalescing capabilities.

Free block coalescing to the right takes place during allocation, whereas free
block coalescing to the left takes place during deallocation. This makes both
operations $(BIGOH n) in the number of managed blocks, but improves the chance
of finding a good block faster than $(D SimpleBlocklist). After deallocation the
(possibly coalesced) freed block will be the starting point of searching for the
next allocation.

The allocation overhead is two words per allocated block.
*/
struct Blocklist
{
    import std.experimental.allocator.affix_allocator;
    alias AffixAllocator!(SimpleBlocklist, void, size_t) Parent;
    Parent parent;
    private alias Node = SimpleBlocklist.Node;

    private Node* prev(Node* n)
    {
        const lSize = (cast(size_t*) n)[-1];
        return cast(Node*) ((cast(void*) n) - lSize);
    }

    version(unittest) void dump()
    {
        return parent.parent.dump;
    }

    /// Constructs an allocator given a block of memory.
    this(void[] b)
    {
        parent = Parent(SimpleBlocklist(b));
    }

    /// Standard allocator primitives.
    alias alignment = SimpleBlocklist.alignment;

    /// Ditto
    void[] allocate(size_t bytes)
    {
        auto r = parent.allocate(bytes);
        if (r)
        {
            parent.suffix(r) =
                (cast(size_t*) r.ptr)[-1] & ~SimpleBlocklist.busyMask;
        }
        return r;
    }

    /// Ditto
    void deallocate(void[] b)
    {
        // This is the moment to do left coalescing
        if (!b) return;
        auto n = cast(Node*) b.ptr - 1;
        // Can we coalesce to the left?
        for (;;)
        {
            if (n == parent.parent.root) return;
            auto left = prev(n);
            if (left.occupied) break;
            // Yay
            left._size += n._size;
            n = left;
        }
        parent.suffix(b) = n._size;
        parent.deallocate(b);
        parent.parent.searchStart = n;
    }

    /// Ditto
    auto owns(void[] b) { return parent.owns(b); }
    //alias allocateAll = Parent.allocateAll;

    /// Ditto
    auto deallocateAll() { return parent.deallocateAll; }

    /// Ditto
    void markAllAsUnused() { parent.markAllAsUnused(); }

    /// Ditto
    bool markAsUsed(void[] b) { return parent.markAsUsed(b); }

    /// Ditto
    void doneMarking() { parent.doneMarking(); }
}

unittest
{
    auto alloc = Blocklist(new void[4096]);
    void[][] array;
    foreach (i; 1 .. 3)
    {
        array ~= alloc.allocate(i);
        assert(array[$ - 1].length == i);
        assert(alloc.owns(array[$ - 1]));
    }
    array ~= alloc.allocate(103);
    //alloc.dump();
    alloc.deallocate(array[0]);
    alloc.deallocate(array[1]);
    //alloc.dump();
}

/**
Dispatches allocations (and deallocations) between two allocators ($(D
SmallAllocator) and $(D LargeAllocator)) depending on the size allocated, as
follows. All allocations smaller than or equal to $(D threshold) will be
dispatched to $(D SmallAllocator). The others will go to $(D LargeAllocator).

If both allocators are $(D shared), the $(D Segregator) will also offer $(D
shared) methods.
*/
struct Segregator(size_t threshold, SmallAllocator, LargeAllocator)
{
    static if (stateSize!SmallAllocator) SmallAllocator _small;
    else static alias SmallAllocator.it _small;
    static if (stateSize!LargeAllocator) LargeAllocator _large;
    else alias LargeAllocator.it _large;

    version (StdDdoc)
    {
        /**
        The alignment offered is the minimum of the two allocators' alignment.
        */
        enum uint alignment;
        /**
        This method is defined only if at least one of the allocators defines
        it. The good allocation size is obtained from $(D SmallAllocator) if $(D
        s <= threshold), or $(D LargeAllocator) otherwise. (If one of the
        allocators does not define $(D goodAllocSize), the default
        implementation in this module applies.)
        */
        static size_t goodAllocSize(size_t s);
        /**
        The memory is obtained from $(D SmallAllocator) if $(D s <= threshold),
        or $(D LargeAllocator) otherwise.
        */
        void[] allocate(size_t);
        /**
        This method is defined only if both allocators define it. The call is
        forwarded to $(D SmallAllocator) if $(D b.length <= threshold), or $(D
        LargeAllocator) otherwise.
        */
        bool owns(void[] b);
        /**
        This method is defined only if at least one of the allocators defines
        it. If $(D SmallAllocator) defines $(D expand) and $(D b.length +
        delta <= threshold), the call is forwarded to $(D SmallAllocator). If $(
        LargeAllocator) defines $(D expand) and $(D b.length > threshold), the
        call is forwarded to $(D LargeAllocator). Otherwise, the call returns
        $(D false).
        */
        bool expand(ref void[] b, size_t delta);
        /**
        This method is defined only if at least one of the allocators defines
        it. If $(D SmallAllocator) defines $(D reallocate) and $(D b.length <=
        threshold && s <= threshold), the call is forwarded to $(D
        SmallAllocator). If $(D LargeAllocator) defines $(D expand) and $(D
        b.length > threshold && s > threshold), the call is forwarded to $(D
        LargeAllocator). Otherwise, the call returns $(D false).
        */
        bool reallocate(ref void[] b, size_t s);
        /**
        This function is defined only if both allocators define it, and forwards
        appropriately depending on $(D b.length).
        */
        void deallocate(void[] b);
        /**
        This function is defined only if both allocators define it, and calls
        $(D deallocateAll) for them in turn.
        */
        void deallocateAll();
    }

    /**
    Composite allocators involving nested instantiations of $(D Segregator) make
    it difficult to access individual sub-allocators stored within. $(D
    allocatorForSize) simplifies the task by supplying the allocator nested
    inside a $(D Segregator) that is responsible for a specific size $(D s).

    Example:
    ----
    alias A = Segregator!(300,
        Segregator!(200, A1, A2),
        A3);
    A a;
    static assert(typeof(a.allocatorForSize!10) == A1);
    static assert(typeof(a.allocatorForSize!250) == A2);
    static assert(typeof(a.allocatorForSize!301) == A3);
    ----
    */
    ref auto allocatorForSize(size_t s)()
    {
        static if (s <= threshold)
            static if (is(SmallAllocator == Segregator!(Args), Args...))
                return _small.allocatorForSize!s;
            else return _small;
        else
            static if (is(LargeAllocator == Segregator!(Args), Args...))
                return _large.allocatorForSize!s;
            else return _large;
    }

    enum uint alignment = min(SmallAllocator.alignment,
        LargeAllocator.alignment);

    template Impl()
    {
        void[] allocate(size_t s)
        {
            return s <= threshold ? _small.allocate(s) : _large.allocate(s);
        }

        static if (hasMember!(SmallAllocator, "deallocate")
                && hasMember!(LargeAllocator, "deallocate"))
        void deallocate(void[] data)
        {
            data.length <= threshold
                ? _small.deallocate(data)
                : _large.deallocate(data);
        }

        size_t goodAllocSize(size_t s)
        {
            return s <= threshold
                ? _small.goodAllocSize(s)
                : _large.goodAllocSize(s);
        }

        static if (hasMember!(SmallAllocator, "owns")
                && hasMember!(LargeAllocator, "owns"))
        bool owns(void[] b)
        {
            return b.length <= threshold ? _small.owns(b) : _large.owns(b);
        }

        static if (hasMember!(SmallAllocator, "expand")
                || hasMember!(LargeAllocator, "expand"))
        bool expand(ref void[] b, size_t delta)
        {
            if (b.length + delta <= threshold)
            {
                // Old and new allocations handled by _small
                static if (hasMember!(SmallAllocator, "expand"))
                    return _small.expand(b, delta);
                else
                    return false;
            }
            if (b.length > threshold)
            {
                // Old and new allocations handled by _large
                static if (hasMember!(LargeAllocator, "expand"))
                    return _large.expand(b, delta);
                else
                    return false;
            }
            // Oops, cross-allocator transgression
            return false;
        }

        static if (hasMember!(SmallAllocator, "reallocate")
                || hasMember!(LargeAllocator, "reallocate"))
        bool reallocate(ref void[] b, size_t s)
        {
            static if (hasMember!(SmallAllocator, "reallocate"))
                if (b.length <= threshold && s <= threshold)
                {
                    // Old and new allocations handled by _small
                    return _small.reallocate(b, s);
                }
            static if (hasMember!(LargeAllocator, "reallocate"))
                if (b.length > threshold && s > threshold)
                {
                    // Old and new allocations handled by _large
                    return _large.reallocate(b, s);
                }
            // Cross-allocator transgression
            return .reallocate(this, b, s);
        }

        static if (hasMember!(SmallAllocator, "deallocateAll")
                && hasMember!(LargeAllocator, "deallocateAll"))
        void deallocateAll()
        {
            _small.deallocateAll();
            _large.deallocateAll();
        }

        static if (hasMember!(SmallAllocator, "resolveInternalPointer")
                && hasMember!(LargeAllocator, "resolveInternalPointer"))
        void[] resolveInternalPointer(void* p)
        {
            if (auto r = _small.resolveInternalPointer(p)) return r;
            return _large.resolveInternalPointer(p);
        }

        static if (hasMember!(SmallAllocator, "markAllAsUnused")
                && hasMember!(LargeAllocator, "markAllAsUnused"))
        {
            void markAllAsUnused()
            {
                _small.markAllAsUnused();
                _large.markAllAsUnused();
            }

            bool markAsUsed(void[] b)
            {
                return b.length <= threshold
                    ? _small.markAsUsed(b)
                    : _large.markAsUsed(b);
            }

            void doneMarking()
            {
                _small.doneMarking();
                _large.doneMarking();
            }
        }
    }

    enum sharedMethods =
        !stateSize!SmallAllocator
        && !stateSize!LargeAllocator
        && is(typeof(SmallAllocator.it) == shared)
        && is(typeof(LargeAllocator.it) == shared);
    //pragma(msg, sharedMethods);

    static if (sharedMethods)
    {
        static shared Segregator it;
        shared { mixin Impl!(); }
    }
    else
    {
        static if (!stateSize!SmallAllocator && !stateSize!LargeAllocator)
            static __gshared Segregator it;
        mixin Impl!();
    }
}

///
unittest
{
    alias A =
        Segregator!(
            1024 * 4,
            Segregator!(
                128, FreeList!(Mallocator, 0, 128),
                GCAllocator),
            Segregator!(
                1024 * 1024, Mallocator,
                GCAllocator)
            );
    A a;
    auto b = a.allocate(200);
    assert(b.length == 200);
    a.deallocate(b);
}

/**
A $(D Segregator) with more than three arguments expands to a composition of
elemental $(D Segregator)s, as illustrated by the following example:

----
alias A =
    Segregator!(
        n1, A1,
        n2, A2,
        n3, A3,
        A4
    );
----

With this definition, allocation requests for $(D n1) bytes or less are directed
to $(D A1); requests between $(D n1 + 1) and $(D n2) bytes (inclusive) are
directed to $(D A2); requests between $(D n2 + 1) and $(D n3) bytes (inclusive)
are directed to $(D A3); and requests for more than $(D n3) bytes are directed
to $(D A4). If some particular range should not be handled, $(D NullAllocator)
may be used appropriately.

*/
template Segregator(Args...) if (Args.length > 3)
{
    // Binary search
    private enum cutPoint = ((Args.length - 2) / 4) * 2;
    static if (cutPoint >= 2)
    {
        alias Segregator = .Segregator!(
            Args[cutPoint],
            .Segregator!(Args[0 .. cutPoint], Args[cutPoint + 1]),
            .Segregator!(Args[cutPoint + 2 .. $])
        );
    }
    else
    {
        // Favor small sizes
        alias Segregator = .Segregator!(
            Args[0],
            Args[1],
            .Segregator!(Args[2 .. $])
        );
    }

    // Linear search
    //alias Segregator = .Segregator!(
    //    Args[0], Args[1],
    //    .Segregator!(Args[2 .. $])
    //);
}

///
unittest
{
    alias A =
        Segregator!(
            128, FreeList!(Mallocator, 0, 128),
            1024 * 4, GCAllocator,
            1024 * 1024, Mallocator,
            GCAllocator
        );
    A a;
    auto b = a.allocate(201);
    assert(b.length == 201);
    a.deallocate(b);
}

/**

A $(D Bucketizer) uses distinct allocators for handling allocations of sizes in
the intervals $(D [min, min + step - 1]), $(D [min + step, min + 2 * step - 1]),
$(D [min + 2 * step, min + 3 * step - 1]), $(D ...), $(D [max - step + 1, max]).

$(D Bucketizer) holds a fixed-size array of allocators and dispatches calls to
them appropriately. The size of the array is $(D (max + 1 - min) / step), which
must be an exact division.

Allocations for sizes smaller than $(D min) or larger than $(D max) are illegal
for $(D Bucketizer). To handle them separately, $(D Segregator) may be of use.

*/
struct Bucketizer(Allocator, size_t min, size_t max, size_t step)
{
    static assert((max - (min - 1)) % step == 0,
        "Invalid limits when instantiating " ~ Bucketizer.stringof);

    //static if (min == chooseAtRuntime) size_t _min;
    //else alias _min = min;
    //static if (max == chooseAtRuntime) size_t _max;
    //else alias _max = max;
    //static if (step == chooseAtRuntime) size_t _step;
    //else alias _step = step;

    /// The array of allocators is publicly available for e.g. initialization
    /// and inspection.
    Allocator[(max - (min - 1)) / step] buckets;

    /**
    The alignment offered is the same as $(D Allocator.alignment).
    */
    enum uint alignment = Allocator.alignment;

    /**
    Rounds up to the maximum size of the bucket in which $(D bytes) falls.
    */
    size_t goodAllocSize(size_t bytes) const
    {
        // round up bytes such that bytes - min + 1 is a multiple of step
        assert(bytes >= min);
        const min_1 = min - 1;
        return min_1 + roundUpToMultipleOf(bytes - min_1, step);
    }

    /**
    Returns $(D b.length >= min && b.length <= max).
    */
    bool owns(void[] b) const
    {
        return b.length >= min && b.length <= max;
    }

    /**
    Directs the call to either one of the $(D buckets) allocators.
    */
    void[] allocate(size_t bytes)
    {
        // Choose the appropriate allocator
        const i = (bytes - min) / step;
        assert(i < buckets.length);
        const actual = goodAllocSize(bytes);
        auto result = buckets[i].allocate(actual);
        return result.ptr[0 .. bytes];
    }

    /**
    This method allows expansion within the respective bucket range. It succeeds
    if both $(D b.length) and $(D b.length + delta) fall in a range of the form
    $(D [min + k * step, min + (k + 1) * step - 1]).
    */
    bool expand(ref void[] b, size_t delta)
    {
        assert(b.length >= min && b.length <= max);
        const available = goodAllocSize(b.length);
        const desired = b.length + delta;
        if (available < desired) return false;
        b = b.ptr[0 .. desired];
        return true;
    }

    /**
    This method is only defined if $(D Allocator) defines $(D deallocate).
    */
    static if (hasMember!(Allocator, "deallocate"))
    void deallocate(void[] b)
    {
        const i = (b.length - min) / step;
        assert(i < buckets.length);
        const actual = goodAllocSize(b.length);
        buckets.ptr[i].deallocate(b.ptr[0 .. actual]);
    }

    /**
    This method is only defined if all allocators involved define $(D
    deallocateAll), and calls it for each bucket in turn.
    */
    static if (hasMember!(Allocator, "deallocateAll"))
    void deallocateAll()
    {
        foreach (ref a; buckets)
        {
            a.deallocateAll();
        }
    }

    /**
    This method is only defined if all allocators involved define $(D
    resolveInternalPointer), and tries it for each bucket in turn.
    */
    static if (hasMember!(Allocator, "resolveInternalPointer"))
    void[] resolveInternalPointer(void* p)
    {
        foreach (ref a; buckets)
        {
            if (auto r = a.resolveInternalPointer(p)) return r;
        }
        return null;
    }

    static if (hasMember!(Allocator, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            foreach (ref a; buckets)
            {
                a.markAllAsUnused();
            }
        }
        //
        bool markAsUsed(void[] b)
        {
            const i = (b.length - min) / step;
            assert(i < buckets.length);
            const actual = goodAllocSize(b.length);
            return buckets.ptr[i].markAsUsed(b.ptr[0 .. actual]);
        }
        //
        void doneMarking()
        {
            foreach (ref a; buckets)
            {
                a.doneMarking();
            }
        }
    }
}

///
unittest
{
    Bucketizer!(FreeList!(Mallocator, 0, unbounded),
        65, 512, 64) a;
    auto b = a.allocate(400);
    assert(b.length == 400, text(b.length));
    a.deallocate(b);
}

/**

Stores an allocator object in thread-local storage (i.e. non-$(D shared) D
global). $(D ThreadLocal!A) is a subtype of $(D A) so it appears to implement
$(D A)'s allocator primitives.

$(D A) must hold state, otherwise $(D ThreadLocal!A) refuses instantiation. This
means e.g. $(D ThreadLocal!Mallocator) does not work because $(D Mallocator)'s
state is not stored as members of $(D Mallocator), but instead is hidden in the
C library implementation.

*/
struct ThreadLocal(A)
{
    static assert(stateSize!A,
        typeof(A).stringof
        ~ " does not have state so it cannot be used with ThreadLocal");

    /**
    The allocator instance.
    */
    static A it;

    /**
    $(D ThreadLocal!A) is a subtype of $(D A) so it appears to implement
    $(D A)'s allocator primitives.
    */
    alias it this;

    /**
    $(D ThreadLocal) disables all constructors. The intended usage is
    $(D ThreadLocal!A.it).
    */
    @disable this();
    /// Ditto
    @disable this(this);
}

///
unittest
{
    static assert(!is(ThreadLocal!Mallocator));
    static assert(!is(ThreadLocal!GCAllocator));
    alias ThreadLocal!(FreeList!(GCAllocator, 0, 8, 1)) Allocator;
    auto b = Allocator.it.allocate(5);
    static assert(hasMember!(Allocator, "allocate"));
}

/**
Dynamic version of an allocator. This should be used wherever a uniform type is
required for encapsulating various allocator implementations.

See_Also: $(LREF ISharedAllocator)
*/
interface IAllocator
{
    /**
    Returns the alignment offered. $(COMMENT By default this method returns $(D platformAlignment).)
    */
    @property uint alignment();

    /**
    Returns the good allocation size that guarantees zero internal
    fragmentation. $(COMMENT By default returns $(D s) rounded up to the nearest multiple
    of $(D alignment).)
    */
    size_t goodAllocSize(size_t s);

    /**
    Allocates memory. The default returns $(D null).
    */
    void[] allocate(size_t);

    /**
    Returns $(D Ternary.yes) if the allocator owns $(D b), $(D Ternary.no) if
    the allocator doesn't own $(D b), and $(D Ternary.unknown) if ownership not
    supported by the allocator. $(COMMENT By default returns $(D Ternary.unknown).)
    */
    Ternary owns(void[] b);

    /**
    Expands a memory block in place. If expansion not supported
    by the allocator, returns $(D Ternary.unknown). If implemented, returns $(D
    Ternary.yes) if expansion succeeded, $(D Ternary.no) otherwise.
    */
    Ternary expand(ref void[], size_t);

    /// Reallocates a memory block. $(COMMENT By default returns $(D false).)
    bool reallocate(ref void[], size_t);

    /**
    Deallocates a memory block. Returns $(D Ternary.unknown) if deallocation is
    not supported. A simple way to check that an allocator supports
    deallocation is to call $(D deallocate(null)).
    */
    Ternary deallocate(void[]);

    /**
    Deallocates all memory. Returns $(D Ternary.unknown) if deallocation is
    not supported.
    */
    Ternary deallocateAll();

    /**
    Allocates and returns all memory available to this allocator. $(COMMENT By default
    returns $(D null).)
    */
    void[] allocateAll();
}

/**
Shared version of $(LREF IAllocator).
*/
interface ISharedAllocator
{
    /**
    These methods prescribe similar semantics to their $(D CAllocator)
    counterparts for shared allocators.
    */
    @property uint alignment() shared;

    /// Ditto
    size_t goodAllocSize(size_t s) shared;

    /// Ditto
    void[] allocate(size_t) shared;

    /// Ditto
    Ternary owns(void[] b) shared;

    /// Ditto
    Ternary expand(ref void[], size_t) shared;

    /// Ditto
    bool reallocate(ref void[], size_t) shared;

    /// Ditto
    Ternary deallocate(void[]) shared;

    /// Ditto
    Ternary deallocateAll() shared;

    /// Ditto
    void[] allocateAll() shared;
}

/**

Returns a dynamically-typed $(D CAllocator) built around a given
statically-typed allocator $(D a) of type $(D A), as follows.

$(UL
$(LI If $(D A) has no state, the resulting object is allocated in static
shared storage.)
$(LI If $(D A) has state and is copyable, the result will store a copy of it
within. The result itself is allocated in its own statically-typed allocator.)
$(LI If $(D A) has state and is not copyable, the result will move the
passed-in argument into the result. The result itself is allocated in its own
statically-typed allocator.)
)

*/
auto allocatorObject(A)(auto ref A a)
{
    alias Result = Select!(is(A == shared),
        shared ISharedAllocator, IAllocator);
    static if (stateSize!A == 0)
    {
        enum s = stateSize!(CAllocatorImpl!A).divideRoundUp(ulong.sizeof);
        static __gshared ulong[s] state;
        static __gshared Result result;
        if (!result)
        {
            // Don't care about a few races
            result = cast(Result) emplace!(CAllocatorImpl!A)(state[]);
        }
        assert(result);
        return result;
    }
    else static if (is(typeof({ A b = a; A c = b; }))) // copyable
    {
        auto state = a.allocate(stateSize!(CAllocatorImpl!A));
        static if (hasMember!(A, "deallocate"))
        {
            scope(failure) a.deallocate(state);
        }
        return cast(Result) emplace!(CAllocatorImpl!A)(state);
    }
    else // the allocator object is not copyable
    {
        // This is sensitive... create on the stack and then move
        enum s = stateSize!(CAllocatorImpl!A).divideRoundUp(ulong.sizeof);
        ulong[s] state;
        emplace!(CAllocatorImpl!A)(state[], move(a));
        auto dynState = a.allocate(stateSize!(CAllocatorImpl!A));
        // Bitblast the object in its final destination
        dynState[] = state[];
        return cast(A) dynState.ptr;
    }
}

unittest
{
    auto a = allocatorObject(Mallocator.it);
    auto b = a.allocate(100);
    assert(b.length == 100, text(b.length));

    FreeList!(GCAllocator, 0, 8, 1) fl;
    auto sa = allocatorObject(fl);
    b = a.allocate(101);
    assert(b.length == 101);

    FallbackAllocator!(InSituRegion!(10240, 64), GCAllocator) fb;
    // Doesn't work yet...
    //a = allocatorObject(fb);
    //b = a.allocate(102);
    //assert(b.length == 102);
}

/**

Implementation of $(D CAllocator) using $(D Allocator). This adapts a
statically-built allocator type to a uniform dynamic interface (either $(D
IAllocator) or $(D ISharedAllocator), depending on whether $(D Allocator) offers
a shared instance $(D it) or not) that is directly usable by non-templated code.

Usually $(D CAllocatorImpl) is used indirectly by calling
$(LREF allocatorObject).
*/
class CAllocatorImpl(Allocator)
    : Select!(is(typeof(Allocator.it) == shared), ISharedAllocator, IAllocator)
{
    /**
    The implementation is available as a public member.
    */
    static if (stateSize!Allocator) Allocator impl;
    else alias impl = Allocator.it;

    template Impl()
    {
        /// Returns $(D impl.alignment).
        override @property uint alignment()
        {
            return impl.alignment;
        }

        /**
        Returns $(D impl.goodAllocSize(s)).
        */
        override size_t goodAllocSize(size_t s)
        {
            return impl.goodAllocSize(s);
        }

        /**
        Returns $(D impl.allocate(s)).
        */
        override void[] allocate(size_t s)
        {
            return impl.allocate(s);
        }

        /**
        Overridden only if $(D Allocator) implements $(D owns). In that case,
        returns $(D impl.owns(b)).
        */
        override Ternary owns(void[] b)
        {
            static if (hasMember!(Allocator, "owns")) return impl.owns(b);
            else return Ternary.unknown;
        }

        /// Returns $(D impl.expand(b, s)) if defined, $(D false) otherwise.
        override Ternary expand(ref void[] b, size_t s)
        {
            static if (hasMember!(Allocator, "expand"))
                return Ternary(impl.expand(b, s));
            else
                return Ternary.unknown;
        }

        /// Returns $(D impl.reallocate(b, s)).
        override bool reallocate(ref void[] b, size_t s)
        {
            return impl.reallocate(b, s);
        }

        /// Calls $(D impl.deallocate(b)) and returns $(D true) if defined,
        /// otherwise returns $(D false).
        override Ternary deallocate(void[] b)
        {
            static if (hasMember!(Allocator, "deallocate"))
            {
                static if (is(typeof(impl.deallocate(b)) == bool))
                {
                    return impl.deallocate(b);
                }
                else
                {
                    impl.deallocate(b);
                    return Ternary.yes;
                }
            }
            else
            {
                return Ternary.unknown;
            }
        }

        /// Calls $(D impl.deallocateAll()) and returns $(D true) if defined,
        /// otherwise returns $(D false).
        override Ternary deallocateAll()
        {
            static if (hasMember!(Allocator, "deallocateAll"))
            {
                impl.deallocateAll();
                return Ternary.yes;
            }
            else
            {
                return Ternary.unknown;
            }
        }

        /**
        Overridden only if $(D Allocator) implements $(D allocateAll). In that
        case, returns $(D impl.allocateAll()).
        */
        override void[] allocateAll()
        {
            static if (hasMember!(Allocator, "allocateAll"))
                return impl.allocateAll();
            else
                return null;
        }
    }

    static if (is(typeof(Allocator.it) == shared))
        shared { mixin Impl!(); }
    else
        mixin Impl!();
}

///
unittest
{
    /// Define an allocator bound to the built-in GC.
    shared ISharedAllocator alloc = allocatorObject(GCAllocator.it);
    auto b = alloc.allocate(42);
    assert(b.length == 42);
    assert(alloc.deallocate(b) == Ternary.yes);

    // Define an elaborate allocator and bind it to the class API.
    // Note that the same variable "alloc" is used.
    alias FList = FreeList!(GCAllocator, 0, unbounded);
    alias A = ThreadLocal!(
        Segregator!(
            8, FreeList!(GCAllocator, 0, 8),
            128, Bucketizer!(FList, 1, 128, 16),
            256, Bucketizer!(FList, 129, 256, 32),
            512, Bucketizer!(FList, 257, 512, 64),
            1024, Bucketizer!(FList, 513, 1024, 128),
            2048, Bucketizer!(FList, 1025, 2048, 256),
            3584, Bucketizer!(FList, 2049, 3584, 512),
            4072 * 1024, AllocatorList!(
                () => HeapBlock!(4096)(GCAllocator.it.allocate(4072 * 1024))),
            GCAllocator
        )
    );

    auto alloc2 = allocatorObject(A.it);
    b = alloc.allocate(101);
    assert(alloc.deallocate(b) == Ternary.yes);
}

/*
(Not public.)

A binary search tree that uses no allocation of its own. Instead, it relies on
user code to allocate nodes externally. Then $(D EmbeddedTree)'s primitives wire
the nodes appropriately.

Warning: currently $(D EmbeddedTree) is not using rebalancing, so it may
degenerate. A red-black tree implementation storing the color with one of the
pointers is planned for the future.
*/
private struct EmbeddedTree(T, alias less)
{
    static struct Node
    {
        T payload;
        Node* left, right;
    }

    private Node* root;

    private Node* insert(Node* n, ref Node* backref)
    {
        backref = n;
        n.left = n.right = null;
        return n;
    }

    Node* find(Node* data)
    {
        for (auto n = root; n; )
        {
            if (less(data, n))
            {
                n = n.left;
            }
            else if (less(n, data))
            {
                n = n.right;
            }
            else
            {
                return n;
            }
        }
        return null;
    }

    Node* insert(Node* data)
    {
        if (!root)
        {
            root = data;
            data.left = data.right = null;
            return root;
        }
        auto n = root;
        for (;;)
        {
            if (less(data, n))
            {
                if (!n.left)
                {
                    // Found insertion point
                    return insert(data, n.left);
                }
                n = n.left;
            }
            else if (less(n, data))
            {
                if (!n.right)
                {
                    // Found insertion point
                    return insert(data, n.right);
                }
                n = n.right;
            }
            else
            {
                // Found
                return n;
            }
            if (!n) return null;
        }
    }

    Node* remove(Node* data)
    {
        auto n = root;
        Node* parent = null;
        for (;;)
        {
            if (!n) return null;
            if (less(data, n))
            {
                parent = n;
                n = n.left;
            }
            else if (less(n, data))
            {
                parent = n;
                n = n.right;
            }
            else
            {
                // Found
                remove(n, parent);
                return n;
            }
        }
    }

    private void remove(Node* n, Node* parent)
    {
        assert(n);
        assert(!parent || parent.left == n || parent.right == n);
        Node** referrer = parent
            ? (parent.left == n ? &parent.left : &parent.right)
            : &root;
        if (!n.left)
        {
            *referrer = n.right;
        }
        else if (!n.right)
        {
            *referrer = n.left;
        }
        else
        {
            // Find the leftmost child in the right subtree
            auto leftmost = n.right;
            Node** leftmostReferrer = &n.right;
            while (leftmost.left)
            {
                leftmostReferrer = &leftmost.left;
                leftmost = leftmost.left;
            }
            // Unlink leftmost from there
            *leftmostReferrer = leftmost.right;
            // Link leftmost in lieu of n
            leftmost.left = n.left;
            leftmost.right = n.right;
            *referrer = leftmost;
        }
    }

    bool empty() const
    {
        return !root;
    }

    void dump()
    {
        writeln(typeid(this), " @ ", cast(void*) &this);
        dump(root, 3);
    }

    void dump(Node* r, uint indent)
    {
        write(repeat(' ', indent).array);
        if (!r)
        {
            writeln("(null)");
            return;
        }
        writeln(r.payload, " @ ", cast(void*) r);
        dump(r.left, indent + 3);
        dump(r.right, indent + 3);
    }

    void assertSane()
    {
        static bool isBST(Node* r, Node* lb, Node* ub)
        {
            if (!r) return true;
            if (lb && !less(lb, r)) return false;
            if (ub && !less(r, ub)) return false;
            return isBST(r.left, lb, r) &&
                isBST(r.right, r, ub);
        }
        if (isBST(root, null, null)) return;
        dump;
        assert(0);
    }
}

unittest
{
    alias a = GCAllocator.it;
    alias Tree = EmbeddedTree!(int, (a, b) => a.payload < b.payload);
    Tree t;
    assert(t.empty);
    int[] vals = [ 6, 3, 9, 1, 0, 2, 8, 11 ];
    foreach (v; vals)
    {
        auto n = new Tree.Node(v, null, null);
        assert(t.insert(n));
        assert(n);
        t.assertSane;
    }
    assert(!t.empty);
    foreach (v; vals)
    {
        Tree.Node n = { v };
        assert(t.remove(&n));
        t.assertSane;
    }
    assert(t.empty);
}

/**

$(D InternalPointersTree) adds a primitive on top of another allocator: calling
$(D resolveInternalPointer(p)) returns the block within which the internal
pointer $(D p) lies. Pointers right after the end of allocated blocks are also
considered internal.

The implementation stores three additional words with each allocation (one for
the block size and two for search management).

*/
struct InternalPointersTree(Allocator)
{
    alias Tree = EmbeddedTree!(size_t,
        (a, b) => cast(void*) a + a.payload < cast(void*) b);
    alias Parent = AffixAllocator!(Allocator, Tree.Node);

    // Own state
    private Tree blockMap;

    alias alignment = Parent.alignment;

    /**
    The implementation is available as a public member.
    */
    static if (stateSize!Parent) Parent parent;
    else alias parent = Parent.it;

    /// Allocator API.
    void[] allocate(size_t bytes)
    {
        auto r = parent.allocate(bytes);
        if (!r) return r;
        Tree.Node* n = &parent.prefix(r);
        n.payload = bytes;
        blockMap.insert(n) || assert(0);
        return r;
    }

    /// Ditto
    void deallocate(void[] b)
    {
        if (!b) return;
        Tree.Node* n = &parent.prefix(b);
        blockMap.remove(n) || assert(false);
        parent.deallocate(b);
    }

    /// Ditto
    static if (hasMember!(Allocator, "reallocate"))
    bool reallocate(ref void[] b, size_t s)
    {
        auto n = &parent.prefix(b);
        assert(n.payload == b.length);
        blockMap.remove(n) || assert(0);
        if (!parent.reallocate(b, s))
        {
            // Failed, must reinsert the same node in the tree
            assert(n.payload == b.length);
            blockMap.insert(n) || assert(0);
            return false;
        }
        // Insert the new node
        n = &parent.prefix(b);
        n.payload = s;
        blockMap.insert(n) || assert(0);
        return true;
    }

    /// Ditto
    bool owns(void[] b)
    {
        return resolveInternalPointer(b.ptr) !is null;
    }

    /// Ditto
    bool empty()
    {
        return blockMap.empty;
    }

    /** Returns the block inside which $(D p) resides, or $(D null) if the
    pointer does not belong.
    */
    void[] resolveInternalPointer(void* p)
    {
        // Must define a custom find
        Tree.Node* find()
        {
            for (auto n = blockMap.root; n; )
            {
                if (p < n)
                {
                    n = n.left;
                }
                else if (p > (cast(void*) (n + 1)) + n.payload)
                {
                    n = n.right;
                }
                else
                {
                    return n;
                }
            }
            return null;
        }

        auto n = find();
        if (!n) return null;
        return (cast(void*) (n + 1))[0 .. n.payload];
    }

    static if (hasMember!(Parent, "markAllAsUnused"))
    {
        void markAllAsUnused() { parent.markAllAsUnused(); }
        //
        bool markAsUsed(void[] b)
        {
            return parent.markAsUsed(actualAllocation(b));
        }
        //
        void doneMarking() { parent.doneMarking(); }
    }
}

unittest
{
    InternalPointersTree!(Mallocator) a;
    int[] vals = [ 6, 3, 9, 1, 2, 8, 11 ];
    void[][] allox;
    foreach (v; vals)
    {
        allox ~= a.allocate(v);
    }
    a.blockMap.assertSane;

    foreach (b; allox)
    {
        auto p = a.resolveInternalPointer(b.ptr);
        assert(p.ptr is b.ptr && p.length >= b.length);
        p = a.resolveInternalPointer(b.ptr + b.length);
        assert(p.ptr is b.ptr && p.length >= b.length);
        p = a.resolveInternalPointer(b.ptr + b.length / 2);
        assert(p.ptr is b.ptr && p.length >= b.length);
        auto bogus = new void[b.length];
        assert(a.resolveInternalPointer(bogus.ptr) is null);
    }

    foreach (b; allox.randomCover)
    {
        a.deallocate(b);
    }

    assert(a.empty);
}

//version (std_allocator_benchmark)
unittest
{
    static void testSpeed(A)()
    {
        static if (stateSize!A) A a;
        else alias a = A.it;

        void[][128] bufs;

        import std.random;
        foreach (i; 0 .. 100_000)
        {
            auto j = uniform(0, bufs.length);
            switch (uniform(0, 2))
            {
            case 0:
                a.deallocate(bufs[j]);
                bufs[j] = a.allocate(uniform(0, 4096));
                break;
            case 1:
                a.deallocate(bufs[j]);
                bufs[j] = null;
                break;
            default:
                assert(0);
            }
        }
    }

    alias FList = FreeList!(GCAllocator, 0, unbounded);
    alias A = Segregator!(
        8, FreeList!(GCAllocator, 0, 8),
        128, Bucketizer!(FList, 1, 128, 16),
        256, Bucketizer!(FList, 129, 256, 32),
        512, Bucketizer!(FList, 257, 512, 64),
        1024, Bucketizer!(FList, 513, 1024, 128),
        2048, Bucketizer!(FList, 1025, 2048, 256),
        3584, Bucketizer!(FList, 2049, 3584, 512),
        4072 * 1024, AllocatorList!(
            () => HeapBlock!(4096)(GCAllocator.it.allocate(4072 * 1024))),
        GCAllocator
    );

    import std.datetime, std.experimental.allocator.null_allocator;
    if (false) writeln(benchmark!(
        testSpeed!NullAllocator,
        testSpeed!Mallocator,
        testSpeed!GCAllocator,
        testSpeed!(ThreadLocal!A),
        testSpeed!(A),
    )(20)[].map!(t => t.to!("seconds", double)));
}

__EOF__

version(none) struct TemplateAllocator
{
    enum alignment = platformAlignment;
    static size_t goodAllocSize(size_t s)
    {
    }
    void[] allocate(size_t)
    {
    }
    bool owns(void[])
    {
    }
    bool expand(ref void[] b, size_t)
    {
    }
    bool reallocate(ref void[] b, size_t)
    {
    }
    void deallocate(void[] b)
    {
    }
    void deallocateAll()
    {
    }
    void[] allocateAll()
    {
    }
    static shared TemplateAllocator it;
}
