// Written in the D programming language.

/**
Macros:
WIKI = Phobos/StdAllocator
MYREF = <a href="std_experimental_allocator_$2.html">$1</a>&nbsp;
MYREF2 = <a href="std_experimental_allocator_$2.html#$1">$1</a>&nbsp;
TDC = <td nowrap>$(D $1)$+</td>
TDC2 = <td nowrap>$(D $(MYREF $1,$+))</td>
TDC3 = <td nowrap>$(D $(MYREF2 $1,$+))</td>
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

$(TR $(TDC2 NullAllocator, null_allocator) $(TD Very good at doing absolutely nothing. A good
starting point for defining other allocators or for studying the API.))

$(TR $(TDC2 GCAllocator, gc_allocator) $(TD The system-provided garbage-collector allocator.
This should be the default fallback allocator tapping into system memory. It
offers manual $(D free) and dutifully collects litter.))

$(TR $(TDC2 Mallocator, mallocator) $(TD The C heap _allocator, a.k.a. $(D
malloc)/$(D realloc)/$(D free). Use sparingly and only for code that is unlikely
to leak.))

$(TR $(TDC3 AlignedMallocator, mallocator) $(TD Interface to OS-specific _allocators that
support specifying alignment:
$(WEB man7.org/linux/man-pages/man3/posix_memalign.3.html, $(D posix_memalign))
on Posix and $(WEB msdn.microsoft.com/en-us/library/fs9stz4e(v=vs.80).aspx,
$(D __aligned_xxx)) on Windows.))

$(TR $(TDC2 AffixAllocator, affix_allocator) $(TD Allocator that allows and manages allocating
extra prefix and/or a suffix bytes for each block allocated.))

$(TR $(TDC2 HeapBlock, heap_block) $(TD Organizes one contiguous chunk of memory in
equal-size blocks and tracks allocation status at the cost of one bit per
block.))

$(TR $(TDC2 FallbackAllocator, fallback_allocator) $(TD Allocator that combines two other allocators
 - primary and fallback. Allocation requests are first tried with primary, and
 upon failure are passed to the fallback. Useful for small and fast allocators
 fronting general-purpose ones.))

$(TR $(TDC2 FreeList, free_list) $(TD Allocator that implements a $(WEB
wikipedia.org/wiki/Free_list, free list) on top of any other allocator. The
preferred size, tolerance, and maximum elements are configurable at compile- and
run time.))

$(TR $(TDC3 SharedFreeList, free_list) $(TD Same features as $(D FreeList), but packaged as
a $(D shared) structure that is accessible to several threads.))

$(TR $(TDC2 FreeTree, free_tree) $(TD Allocator similar to $(D FreeList) that uses a
binary search tree to adaptively store not one, but many free lists.))

$(TR $(TDC2 Region, region) $(TD Region allocator organizes a chunk of memory as a
simple bump-the-pointer allocator.))

$(TR $(TDC3 InSituRegion, region) $(TD Region holding its own allocation, most often on
the stack. Has statically-determined size.))

$(TR $(TDC3 SbrkRegion, region) $(TD Region using $(D $(LUCKY sbrk)) for allocating
memory.))

$(TR $(TDC2 MmapAllocator, mmap_allocator) $(TD Allocator using $(D $(LUCKY mmap)) directly.))

$(TR $(TDC2 StatsCollector, stats_collector) $(TD Collect statistics about any other
allocator.))

$(TR $(TDC2 Quantizer, quantizer) $(TD Allocates in coarse-grained quantas, thus
improving performance of reallocations by often reallocating in place. The drawback is higher memory consumption because of allocated and unused memory.))

$(TR $(TDC2 AllocatorList, allocator_list) $(TD Given an allocator factory, lazily creates as
many allocators as needed to satisfy allocation requests. The allocators are
stored in a linked list. Requests for allocation are satisfied by searching the
list in a linear manner.))

$(TR $(TDC2 Segregator, segregator) $(TD Segregates allocation requests by size and
dispatches them to distinct allocators.))

$(TR $(TDC2 Bucketizer, bucketizer) $(TD Divides allocation sizes in discrete buckets and
uses an array of allocators, one per bucket, to satisfy requests.))

$(COMMENT $(TR $(TDC2 InternalPointersTree) $(TD Adds support for resolving internal
pointers on top of another allocator.)))

)
 */

module std.experimental.allocator;

public import
    std.experimental.allocator.affix_allocator,
    std.experimental.allocator.allocator_list,
    std.experimental.allocator.bucketizer,
    std.experimental.allocator.common,
    std.experimental.allocator.fallback_allocator,
    std.experimental.allocator.free_list,
    std.experimental.allocator.gc_allocator,
    std.experimental.allocator.heap_block,
    std.experimental.allocator.mallocator,
    std.experimental.allocator.mmap_allocator,
    std.experimental.allocator.null_allocator,
    std.experimental.allocator.porcelain,
    std.experimental.allocator.region,
    std.experimental.allocator.segregator,
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
            (n) => HeapBlock!(4096)(GCAllocator.it.allocate(
                max(n, 4072 * 1024)))),
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
    alias ThreadLocal!(FreeList!(GCAllocator, 0, 8)) Allocator;
    auto b = Allocator.it.allocate(5);
    static assert(hasMember!(Allocator, "allocate"));
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

/*

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
        if (!r.ptr) return r;
        Tree.Node* n = &parent.prefix(r);
        n.payload = bytes;
        blockMap.insert(n) || assert(0);
        return r;
    }

    /// Ditto
    void deallocate(void[] b)
    {
        if (!b.ptr) return;
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
            (size_t n) => HeapBlock!(4096)(GCAllocator.it.allocate(
                max(n, 4072 * 1024)))),
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

unittest
{
    auto a = allocatorObject(Mallocator.it);
    auto b = a.allocate(100);
    assert(b.length == 100);

    FreeList!(GCAllocator, 0, 8) fl;
    auto sa = allocatorObject(fl);
    b = a.allocate(101);
    assert(b.length == 101);

    FallbackAllocator!(InSituRegion!(10240, 64), GCAllocator) fb;
    // Doesn't work yet...
    //a = allocatorObject(fb);
    //b = a.allocate(102);
    //assert(b.length == 102);
}

///
unittest
{
    /// Define an allocator bound to the built-in GC.
    IAllocator alloc = allocatorObject(GCAllocator.it);
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
                (n) => HeapBlock!(4096)(GCAllocator.it.allocate(
                    max(n, 4072 * 1024)))),
            GCAllocator
        )
    );

    auto alloc2 = allocatorObject(A.it);
    b = alloc.allocate(101);
    assert(alloc.deallocate(b) == Ternary.yes);
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
