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
    alias FList = Freelist!(GCAllocator, 0, unbounded);
    alias A = Segregator!(
        8, Freelist!(GCAllocator, 0, 8),
        128, Bucketizer!(FList, 1, 128, 16),
        256, Bucketizer!(FList, 129, 256, 32),
        512, Bucketizer!(FList, 257, 512, 64),
        1024, Bucketizer!(FList, 513, 1024, 128),
        2048, Bucketizer!(FList, 1025, 2048, 256),
        3584, Bucketizer!(FList, 2049, 3584, 512),
        4072 * 1024, CascadingAllocator!(
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

$(TR $(TDC2 Freelist) $(TD Allocator that implements a $(WEB
wikipedia.org/wiki/Free_list, free list) on top of any other allocator. The
preferred size, tolerance, and maximum elements are configurable at compile- and
run time.))

$(TR $(TDC2 SharedFreelist) $(TD Same features as $(D Freelist), but packaged as
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

$(TR $(TDC2 AllocatorWithStats) $(TD Collect statistics about any other
allocator.))

$(TR $(TDC2 CascadingAllocator) $(TD Given an allocator factory, lazily creates as
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
    std.experimental.allocator.common,
    std.experimental.allocator.gc_allocator,
    std.experimental.allocator.heap_block,
    std.experimental.allocator.mallocator,
    std.experimental.allocator.null_allocator;

// Example in the synopsis above
unittest
{
    alias FList = Freelist!(GCAllocator, 0, unbounded);
    alias A = Segregator!(
        8, Freelist!(GCAllocator, 0, 8),
        128, Bucketizer!(FList, 1, 128, 16),
        256, Bucketizer!(FList, 129, 256, 32),
        512, Bucketizer!(FList, 257, 512, 64),
        1024, Bucketizer!(FList, 513, 1024, 128),
        2048, Bucketizer!(FList, 1025, 2048, 256),
        3584, Bucketizer!(FList, 2049, 3584, 512),
        4072 * 1024, CascadingAllocator!(
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

/**
$(D FallbackAllocator) is the allocator equivalent of an "or" operator in
algebra. An allocation request is first attempted with the $(D Primary)
allocator. If that returns $(D null), the request is forwarded to the $(D
Fallback) allocator. All other requests are dispatched appropriately to one of
the two allocators.

In order to work, $(D FallbackAllocator) requires that $(D Primary) defines the
$(D owns) method. This is needed in order to decide which allocator was
responsible for a given allocation.

$(D FallbackAllocator) is useful for fast, special-purpose allocators backed up
by general-purpose allocators. The example below features a stack region backed
up by the $(D GCAllocator).
*/
struct FallbackAllocator(Primary, Fallback)
{
    unittest
    {
        testAllocator!(() => FallbackAllocator());
    }

    /// The primary allocator.
    static if (stateSize!Primary) Primary primary;
    else alias primary = Primary.it;

    /// The fallback allocator.
    static if (stateSize!Fallback) Fallback fallback;
    else alias fallback = Fallback.it;

    /**
    If both $(D Primary) and $(D Fallback) are stateless, $(D FallbackAllocator)
    defines a static instance $(D it).
    */
    static if (!stateSize!Primary && !stateSize!Fallback)
    {
        static FallbackAllocator it;
    }

    /**
    The alignment offered is the minimum of the two allocators' alignment.
    */
    enum uint alignment = min(Primary.alignment, Fallback.alignment);

    /**
    Allocates memory trying the primary allocator first. If it returns $(D
    null), the fallback allocator is tried.
    */
    void[] allocate(size_t s)
    {
        auto result = primary.allocate(s);
        return result ? result : fallback.allocate(s);
    }

    /**
    $(D FallbackAllocator) offers $(D alignedAllocate) iff at least one of the
    allocators also offers it. It attempts to allocate using either or both.
    */
    static if (hasMember!(Primary, "alignedAllocate")
        || hasMember!(Fallback, "alignedAllocate"))
    void[] alignedAllocate(size_t s, uint a)
    {
        static if (hasMember!(Primary, "alignedAllocate"))
        {
            if (auto result = primary.alignedAllocate(s, a)) return result;
        }
        static if (hasMember!(Fallback, "alignedAllocate"))
        {
            if (auto result = fallback.alignedAllocate(s, a)) return result;
        }
        return null;
    }

    /**

    $(D expand) is defined if and only if at least one of the allocators
    defines $(D expand). It works as follows. If $(D primary.owns(b)), then the
    request is forwarded to $(D primary.expand) if it is defined, or fails
    (returning $(D false)) otherwise. If $(D primary) does not own $(D b), then
    the request is forwarded to $(D fallback.expand) if it is defined, or fails
    (returning $(D false)) otherwise.

    */
    static if (hasMember!(Primary, "expand") || hasMember!(Fallback, "expand"))
    bool expand(ref void[] b, size_t delta)
    {
        if (!delta) return true;
        if (!b)
        {
            b = allocate(delta);
            return b !is null;
        }
        if (primary.owns(b))
        {
            static if (hasMember!(Primary, "expand"))
                return primary.expand(b, delta);
            else
                return false;
        }
        static if (hasMember!(Fallback, "expand"))
            return fallback.expand(b, delta);
        else
            return false;
    }

    /**

    $(D reallocate) works as follows. If $(D primary.owns(b)), then $(D
    primary.reallocate(b, newSize)) is attempted. If it fails, an attempt is
    made to move the allocation from $(D primary) to $(D fallback).

    If $(D primary) does not own $(D b), then $(D fallback.reallocate(b,
    newSize)) is attempted. If that fails, an attempt is made to move the
    allocation from $(D fallback) to $(D primary).

    */
    bool reallocate(ref void[] b, size_t newSize)
    {
        if (newSize == 0)
        {
            static if (hasMember!(typeof(this), "deallocate"))
                deallocate(b);
            return true;
        }
        if (b is null)
        {
            b = allocate(newSize);
            return b !is null;
        }

        bool crossAllocatorMove(From, To)(ref From from, ref To to)
        {
            auto b1 = to.allocate(newSize);
            if (!b1) return false;
            if (b.length < newSize) b1[0 .. b.length] = b[];
            else b1[] = b[0 .. newSize];
            static if (hasMember!(From, "deallocate"))
                from.deallocate(b);
            b = b1;
            return true;
        }

        if (b is null || primary.owns(b))
        {
            if (primary.reallocate(b, newSize)) return true;
            // Move from primary to fallback
            return crossAllocatorMove(primary, fallback);
        }
        if (fallback.reallocate(b, newSize)) return true;
        // Interesting. Move from fallback to primary.
        return crossAllocatorMove(fallback, primary);
    }

    static if (hasMember!(Primary, "alignedAllocate")
        || hasMember!(Fallback, "alignedAllocate"))
    bool alignedReallocate(ref void[] b, size_t newSize, uint a)
    {
        bool crossAllocatorMove(From, To)(ref From from, ref To to)
        {
            static if (!hasMember!(To, "alignedAllocate"))
            {
                return false;
            }
            else
            {
                auto b1 = to.alignedAllocate(newSize, a);
                if (!b1) return false;
                if (b.length < newSize) b1[0 .. b.length] = b[];
                else b1[] = b[0 .. newSize];
                static if (hasMember!(From, "deallocate"))
                    from.deallocate(b);
                b = b1;
                return true;
            }
        }

        static if (hasMember!(Primary, "alignedAllocate"))
        {
            if (b is null || primary.owns(b))
            {
                return primary.alignedReallocate(b, newSize, a)
                    || crossAllocatorMove(primary, fallback);
            }
        }
        static if (hasMember!(Fallback, "alignedAllocate"))
        {
            return fallback.alignedReallocate(b, newSize, a)
                || crossAllocatorMove(fallback, primary);
        }
        else
        {
            return false;
        }
    }

    /**
    $(D owns) is defined if and only if both allocators define $(D owns).
    Returns $(D primary.owns(b) || fallback.owns(b)).
    */
    static if (hasMember!(Primary, "owns") && hasMember!(Fallback, "owns"))
    bool owns(void[] p)
    {
        return primary.owns(b) || fallback.owns(p);
    }

    /**
    $(D resolveInternalPointer) is defined if and only if both allocators
    define it.
    */
    static if (hasMember!(Primary, "resolveInternalPointer")
        && hasMember!(Fallback, "resolveInternalPointer"))
    void[] resolveInternalPointer(void* p)
    {
        if (auto r = primary.resolveInternalPointer(p)) return r;
        if (auto r = fallback.resolveInternalPointer(p)) return r;
        return null;
    }

    /**
    $(D deallocate) is defined if and only if at least one of the allocators
    define    $(D deallocate). It works as follows. If $(D primary.owns(b)),
    then the request is forwarded to $(D primary.deallocate) if it is defined,
    or is a no-op otherwise. If $(D primary) does not own $(D b), then the
    request is forwarded to $(D fallback.deallocate) if it is defined, or is a
    no-op otherwise.
    */
    static if (hasMember!(Primary, "deallocate")
        || hasMember!(Fallback, "deallocate"))
    void deallocate(void[] b)
    {
        if (primary.owns(b))
        {
            static if (hasMember!(Primary, "deallocate"))
                primary.deallocate(b);
        }
        else
        {
            static if (hasMember!(Fallback, "deallocate"))
                return fallback.deallocate(b);
        }
    }

    /**
    $(D empty) is defined if both allocators also define it.
    */
    static if (hasMember!(Primary, "empty") && hasMember!(Fallback, "empty"))
    bool empty()
    {
        return primary.empty && fallback.empty;
    }

    /**
    $(D zeroesAllocations) is defined if both allocators also define it.
    */
    static if (hasMember!(Primary, "zeroesAllocations")
        && hasMember!(Fallback, "zeroesAllocations"))
    enum bool zeroesAllocations = Primary.zeroesAllocations
        && Fallback.zeroesAllocations;

    static if (hasMember!(Primary, "markAllAsUnused")
        && hasMember!(Fallback, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            primary.markAllAsUnused();
            fallback.markAllAsUnused();
        }
        //
        bool markAsUsed(void[] b)
        {
            if (primary.owns(b)) primary.markAsUsed(b);
            else fallback.markAsUsed(b);
        }
        //
        void doneMarking()
        {
            primary.doneMarking();
            falback.doneMarking();
        }
    }
}

///
unittest
{
    FallbackAllocator!(InSituRegion!16384, GCAllocator) a;
    // This allocation uses the stack
    auto b1 = a.allocate(1024);
    assert(b1.length == 1024, text(b1.length));
    assert(a.primary.owns(b1));
    // This large allocation will go to the Mallocator
    auto b2 = a.allocate(1024 * 1024);
    assert(!a.primary.owns(b2));
    a.deallocate(b1);
    a.deallocate(b2);
}

/**

$(WEB en.wikipedia.org/wiki/Free_list, Free list allocator), stackable on top of
another allocator. Allocation requests between $(D min) and $(D max) bytes are
rounded up to $(D max) and served from a singly-linked list of buffers
deallocated in the past. All other allocations are directed to $(D
ParentAllocator). Due to the simplicity of free list management, allocations
from the free list are fast.

If a program makes many allocations in the interval $(D [minSize, maxSize]) and
then frees most of them, the freelist may grow large, thus making memory
inaccessible to requests of other sizes. To prevent that, the $(D maxNodes)
parameter allows limiting the size of the free list. Alternatively, $(D
deallocateAll) cleans the free list.

$(D Freelist) attempts to reduce internal fragmentation and improve cache
locality by allocating multiple nodes at once, under the control of the $(D
batchCount) parameter. This makes $(D Freelist) an efficient front for small
object allocation on top of a large-block allocator. The default value of $(D
batchCount) is 8, which should amortize freelist management costs to negligible
in most cases.

One instantiation is of particular interest: $(D Freelist!(0,unbounded)) puts
every deallocation in the freelist, and subsequently serves any allocation from
the freelist (if not empty). There is no checking of size matching, which would
be incorrect for a freestanding allocator but is both correct and fast when an
owning allocator on top of the free list allocator (such as $(D Segregator)) is
already in charge of handling size checking.

*/
struct Freelist(ParentAllocator,
    size_t minSize, size_t maxSize = minSize,
    uint batchCount = 8, size_t maxNodes = unbounded)
{
    static assert(minSize != unbounded, "Use minSize = 0 for no low bound.");
    static assert(maxSize >= (void*).sizeof,
        "Maximum size must accommodate a pointer.");

    static if (minSize != chooseAtRuntime)
    {
        alias min = minSize;
    }
    else
    {
        size_t _min = chooseAtRuntime;
        @property size_t min() const
        {
            assert(_min != chooseAtRuntime);
            return _min;
        }
        @property void min(size_t x)
        {
            enforce(x <= _max);
            _min = x;
        }
        static if (maxSize == chooseAtRuntime)
        {
            // Both bounds can be set, provide one function for setting both in
            // one shot.
            void setBounds(size_t low, size_t high)
            {
                enforce(low <= high && high >= (void*).sizeof);
                _min = low;
                _max = high;
            }
        }
    }

    private bool tooSmall(size_t n) const
    {
        static if (minSize == 0) return false;
        else return n < min;
    }

    static if (maxSize != chooseAtRuntime)
    {
        alias max = maxSize;
    }
    else
    {
        size_t _max;
        @property size_t max() const { return _max; }
        @property void max(size_t x)
        {
            enforce(x >= _min && x >= (void*).sizeof);
            _max = x;
        }
    }

    private bool tooLarge(size_t n) const
    {
        static if (maxSize == unbounded) return false;
        else return n > max;
    }

    private bool inRange(size_t n) const
    {
        static if (minSize == maxSize && minSize != chooseAtRuntime)
            return n == maxSize;
        else return !tooSmall(n) && !tooLarge(n);
    }

    version (StdDdoc)
    {
        /**
        Properties for getting and setting bounds. Setting a bound is only
        possible if the respective compile-time parameter has been set to $(D
        chooseAtRuntime). $(D setBounds) is defined only if both $(D minSize)
        and $(D maxSize) are set to $(D chooseAtRuntime).
        */
        @property size_t min();
        /// Ditto
        @property void min(size_t newMinSize);
        /// Ditto
        @property size_t max();
        /// Ditto
        @property void max(size_t newMaxSize);
        /// Ditto
        void setBounds(size_t newMin, size_t newMax);
        ///
        unittest
        {
            Freelist!(Mallocator, chooseAtRuntime, chooseAtRuntime) a;
            // Set the maxSize first so setting the minSize doesn't throw
            a.max = 128;
            a.min = 64;
            a.setBounds(64, 128); // equivalent
            assert(a.max == 128);
            assert(a.min == 64);
        }
    }

    /**
    The parent allocator. Depending on whether $(D ParentAllocator) holds state
    or not, this is a member variable or an alias for $(D ParentAllocator.it).
    */
    static if (stateSize!ParentAllocator) ParentAllocator parent;
    else alias parent = ParentAllocator.it;

    private struct Node { Node* next; }
    static assert(ParentAllocator.alignment >= Node.alignof);
    private Node* _root;
    private uint nodesAtATime = batchCount;

    static if (maxNodes != unbounded)
    {
        private size_t nodes;
        private void incNodes() { ++nodes; }
        private void decNodes() { assert(nodes); --nodes; }
        private bool nodesFull() { return nodes >= maxNodes; }
    }
    else
    {
        private static void incNodes() { }
        private static void decNodes() { }
        private enum bool nodesFull = false;
    }

    /**
    Alignment is defined as $(D parent.alignment). However, if $(D
    parent.alignment > maxSize), objects returned from the freelist will have a
    smaller _alignment, namely $(D maxSize) rounded up to the nearest multiple
    of 2. This allows $(D Freelist) to minimize internal fragmentation by
    allocating several small objects within an allocated block. Also, there is
    no disruption because no object has smaller size than its _alignment.
    */
    enum uint alignment = ParentAllocator.alignment;

    /**
    Returns $(D max) for sizes in the interval $(D [min, max]), and $(D
    parent.goodAllocSize(bytes)) otherwise.
    */
    size_t goodAllocSize(size_t bytes)
    {
        if (inRange(bytes)) return maxSize == unbounded ? bytes : max;
        return parent.goodAllocSize(bytes);
    }

    /**
    Allocates memory either off of the free list or from the parent allocator.
    */
    void[] allocate(size_t bytes)
    {
        assert(bytes < size_t.max / 2);
        if (!inRange(bytes)) return parent.allocate(bytes);
        // Round up allocation to max
        if (maxSize != unbounded) bytes = max;
        if (!_root) return allocateFresh(bytes);
        // Pop off the freelist
        auto result = (cast(ubyte*) _root)[0 .. bytes];
        _root = _root.next;
        decNodes();
        return result;
    }

    private void[] allocateFresh(const size_t bytes)
    {
        assert(!_root);
        assert(bytes == max || max == unbounded);
        assert(max > 0);
        if (nodesAtATime == 1)
        {
            // Easy case, just get it over with
            return parent.allocate(bytes);
        }
        static if (maxSize != unbounded && maxSize != chooseAtRuntime)
        {
            static assert((parent.alignment + max) % Node.alignof == 0,
                text("(", parent.alignment, " + ", max, ") % ",
                 Node.alignof));
        }
        else
        {
            assert((parent.alignment + bytes) % Node.alignof == 0,
                text("(", parent.alignment, " + ", bytes, ") % ",
                 Node.alignof));
        }

        auto data = parent.allocate(nodesAtATime * bytes);
        if (!data) return null;
        auto result = data[0 .. bytes];
        auto n = data[bytes .. $];
        _root = cast(Node*) n.ptr;
        for (;;)
        {
            if (n.length < bytes)
            {
                (cast(Node*) data.ptr).next = null;
                break;
            }
            (cast(Node*) data.ptr).next = cast(Node*) n.ptr;
            data = n;
            n = data[bytes .. $];
        }
        return result;
    }

    /**
    Forwards to $(parent.owns) if implemented.
    */
    static if (hasMember!(ParentAllocator, "owns"))
    bool owns(void[] b)
    {
        return parent.owns(b);
    }

    /**
    Forwards to $(D parent).
    */
    static if (hasMember!(ParentAllocator, "expand"))
    bool expand(void[] b, size_t s)
    {
        return parent.expand(b, s);
    }

    /// Ditto
    static if (hasMember!(ParentAllocator, "reallocate"))
    bool reallocate(void[] b, size_t s)
    {
        return parent.reallocate(b, s);
    }

    /**
    Intercepts deallocations and caches those of the appropriate size in the
    freelist. For all others, forwards to $(D parent.deallocate) or does nothing
    if $(D Parent) does not define $(D deallocate).
    */
    void deallocate(void[] block)
    {
        if (!nodesFull && inRange(block.length))
        {
            static if (minSize == 0)
            {
                // In this case a null pointer might have made it this far.
                if (block is null) return;
            }
            auto t = _root;
            _root = cast(Node*) block.ptr;
            _root.next = t;
            incNodes();
        }
        else
        {
            static if (is(typeof(parent.deallocate(block))))
                parent.deallocate(block);
        }
    }

    /**
    If $(D ParentAllocator) defines $(D deallocateAll), just forwards to it and
    reset the freelist. Otherwise, walks the list and frees each object in turn.
    */
    void deallocateAll()
    {
        static if (hasMember!(ParentAllocator, "deallocateAll"))
        {
            parent.deallocateAll();
        }
        else static if (hasMember!(ParentAllocator, "deallocate"))
        {
            for (auto n = _root; n; n = n.next)
            {
                parent.deallocate((cast(ubyte*)n)[0 .. max]);
            }
        }
        _root = null;
    }

    /// GC helper primitives.
    static if (hasMember!(ParentAllocator, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            // Time to come clean about the stashed data.
            static if (hasMember!(ParentAllocator, "deallocate"))
            for (auto n = _root; n; n = n.next)
            {
                parent.deallocate((cast(ubyte*)n)[0 .. max]);
            }
            _root = null;
        }
        //
        bool markAsUsed(void[] b) { return parent.markAsUsed(b); }
        //
        void doneMarking() { parent.doneMarking(); }
    }
}

unittest
{
    Freelist!(GCAllocator, 0, 8, 1) fl;
    assert(fl._root is null);
    auto b1 = fl.allocate(7);
    //assert(fl._root !is null);
    auto b2 = fl.allocate(8);
    assert(fl._root is null);
    fl.deallocate(b1);
    assert(fl._root !is null);
    auto b3 = fl.allocate(8);
    assert(fl._root is null);
}

/**
Freelist shared across threads. Allocation and deallocation are lock-free. The
parameters have the same semantics as for $(D Freelist).
*/
struct SharedFreelist(ParentAllocator,
    size_t minSize, size_t maxSize = minSize,
    uint batchCount = 8, size_t maxNodes = unbounded)
{
    static assert(minSize != unbounded, "Use minSize = 0 for no low bound.");
    static assert(maxSize >= (void*).sizeof,
        "Maximum size must accommodate a pointer.");

    private import core.atomic;

    static if (minSize != chooseAtRuntime)
    {
        alias min = minSize;
    }
    else
    {
        shared size_t _min = chooseAtRuntime;
        @property size_t min() const shared
        {
            assert(_min != chooseAtRuntime);
            return _min;
        }
        @property void min(size_t x) shared
        {
            enforce(x <= max);
            enforce(cas(&_min, chooseAtRuntime, x),
                "SharedFreelist.min must be initialized exactly once.");
        }
        static if (maxSize == chooseAtRuntime)
        {
            // Both bounds can be set, provide one function for setting both in
            // one shot.
            void setBounds(size_t low, size_t high) shared
            {
                enforce(low <= high && high >= (void*).sizeof);
                enforce(cas(&_min, chooseAtRuntime, low),
                    "SharedFreelist.min must be initialized exactly once.");
                enforce(cas(&_max, chooseAtRuntime, high),
                    "SharedFreelist.max must be initialized exactly once.");
            }
        }
    }

    private bool tooSmall(size_t n) const shared
    {
        static if (minSize == 0) return false;
        else static if (minSize == chooseAtRuntime) return n < _min;
        else return n < minSize;
    }

    static if (maxSize != chooseAtRuntime)
    {
        alias max = maxSize;
    }
    else
    {
        shared size_t _max = chooseAtRuntime;
        @property size_t max() const shared { return _max; }
        @property void max(size_t x) shared
        {
            enforce(x >= _min && x >= (void*).sizeof);
            enforce(cas(&_max, chooseAtRuntime, x),
                "SharedFreelist.max must be initialized exactly once.");
        }
    }

    private bool tooLarge(size_t n) const shared
    {
        static if (maxSize == unbounded) return false;
        else static if (maxSize == chooseAtRuntime) return n > _max;
        else return n > maxSize;
    }

    private bool inRange(size_t n) const shared
    {
        static if (minSize == maxSize && minSize != chooseAtRuntime)
            return n == maxSize;
        else return !tooSmall(n) && !tooLarge(n);
    }

    static if (maxNodes != unbounded)
    {
        private shared size_t nodes;
        private void incNodes() shared
        {
            atomicOp!("+=")(nodes, 1);
        }
        private void decNodes() shared
        {
            assert(nodes);
            atomicOp!("-=")(nodes, 1);
        }
        private bool nodesFull() shared
        {
            return nodes >= maxNodes;
        }
    }
    else
    {
        private static void incNodes() { }
        private static void decNodes() { }
        private enum bool nodesFull = false;
    }

    version (StdDdoc)
    {
        /**
        Properties for getting (and possibly setting) the bounds. Setting bounds
        is allowed only once , and before any allocation takes place. Otherwise,
        the primitives have the same semantics as those of $(D Freelist).
        */
        @property size_t min();
        /// Ditto
        @property void min(size_t newMinSize);
        /// Ditto
        @property size_t max();
        /// Ditto
        @property void max(size_t newMaxSize);
        /// Ditto
        void setBounds(size_t newMin, size_t newMax);
        ///
        unittest
        {
            Freelist!(Mallocator, chooseAtRuntime, chooseAtRuntime) a;
            // Set the maxSize first so setting the minSize doesn't throw
            a.max = 128;
            a.min = 64;
            a.setBounds(64, 128); // equivalent
            assert(a.max == 128);
            assert(a.min == 64);
        }
    }

    /**
    The parent allocator. Depending on whether $(D ParentAllocator) holds state
    or not, this is a member variable or an alias for $(D ParentAllocator.it).
    */
    static if (stateSize!ParentAllocator) shared ParentAllocator parent;
    else alias parent = ParentAllocator.it;

    private struct Node { Node* next; }
    static assert(ParentAllocator.alignment >= Node.alignof);
    private Node* _root;
    private uint nodesAtATime = batchCount;

    /// Standard primitives.
    enum uint alignment = ParentAllocator.alignment;

    /// Ditto
    size_t goodAllocSize(size_t bytes) shared
    {
        if (inRange(bytes)) return maxSize == unbounded ? bytes : max;
        return parent.goodAllocSize(bytes);
    }

    /// Ditto
    bool owns(void[] b) shared const
    {
        if (inRange(b.length)) return true;
        static if (hasMember!(ParentAllocator, "owns"))
            return parent.owns(b);
        else
            return false;
    }

    /**
    Forwards to $(D parent), which must also support $(D shared) primitives.
    */
    static if (hasMember!(ParentAllocator, "expand"))
    bool expand(void[] b, size_t s)
    {
        return parent.expand(b, s);
    }

    /// Ditto
    static if (hasMember!(ParentAllocator, "reallocate"))
    bool reallocate(void[] b, size_t s)
    {
        return parent.reallocate(b, s);
    }

    /// Ditto
    void[] allocate(size_t bytes) shared
    {
        assert(bytes < size_t.max / 2);
        if (!inRange(bytes)) return parent.allocate(bytes);
        if (maxSize != unbounded) bytes = max;
        if (!_root) return allocateFresh(bytes);
        // Pop off the freelist
        shared Node* oldRoot = void, next = void;
        do
        {
            oldRoot = _root; // atomic load
            next = oldRoot.next; // atomic load
        }
        while (!cas(&_root, oldRoot, next));
        // great, snatched the root
        decNodes();
        return (cast(ubyte*) oldRoot)[0 .. bytes];
    }

    private void[] allocateFresh(const size_t bytes) shared
    {
        assert(bytes == max || max == unbounded);
        if (nodesAtATime == 1)
        {
            // Easy case, just get it over with
            return parent.allocate(bytes);
        }
        static if (maxSize != unbounded && maxSize != chooseAtRuntime)
        {
            static assert(
                (parent.alignment + max) % Node.alignof == 0,
                text("(", parent.alignment, " + ", max, ") % ",
                 Node.alignof));
        }
        else
        {
            assert((parent.alignment + bytes) % Node.alignof == 0,
                text("(", parent.alignment, " + ", bytes, ") % ",
                 Node.alignof));
        }

        auto data = parent.allocate(nodesAtATime * bytes);
        if (!data) return null;
        auto result = data[0 .. bytes];
        auto n = data[bytes .. $];
        auto newRoot = cast(shared Node*) n.ptr;
        shared Node* lastNode;
        for (;;)
        {
            if (n.length < bytes)
            {
                lastNode = cast(shared Node*) data.ptr;
                break;
            }
            (cast(Node*) data.ptr).next = cast(Node*) n.ptr;
            data = n;
            n = data[bytes .. $];
        }
        // Created the list, now wire the new nodes in considering another
        // thread might have also created some nodes.
        do
        {
            lastNode.next = _root;
        }
        while (!cas(&_root, lastNode.next, newRoot));
        return result;
    }

    /// Ditto
    void deallocate(void[] b) shared
    {
        if (!nodesFull && inRange(b.length))
        {
            auto newRoot = cast(shared Node*) b.ptr;
            shared Node* oldRoot;
            do
            {
                oldRoot = _root;
                newRoot.next = oldRoot;
            }
            while (!cas(&_root, oldRoot, newRoot));
            incNodes();
        }
        else
        {
            static if (is(typeof(parent.deallocate(block))))
                parent.deallocate(block);
        }
    }

    /// Ditto
    void deallocateAll() shared
    {
        static if (hasMember!(ParentAllocator, "deallocateAll"))
        {
            parent.deallocateAll();
        }
        else static if (hasMember!(ParentAllocator, "deallocate"))
        {
            for (auto n = _root; n; n = n.next)
            {
                parent.deallocate((cast(ubyte*)n)[0 .. max]);
            }
        }
        _root = null;
    }
}

unittest
{
    import core.thread, std.concurrency;

    static shared SharedFreelist!(Mallocator, 64, 128, 8, 100) a;

    assert(a.goodAllocSize(1) == platformAlignment);

    auto b = a.allocate(100);
    a.deallocate(b);

    static void fun(Tid tid, int i)
    {
        scope(exit) tid.send(true);
        auto b = cast(ubyte[]) a.allocate(100);
        b[] = cast(ubyte) i;

        assert(b.equal(repeat(cast(ubyte) i, b.length)));
        a.deallocate(b);
    }

    Tid[] tids;
    foreach (i; 0 .. 1000)
    {
        tids ~= spawn(&fun, thisTid, i);
    }

    foreach (i; 0 .. 1000)
    {
        assert(receiveOnly!bool);
    }
}

unittest
{
    shared SharedFreelist!(Mallocator, chooseAtRuntime, chooseAtRuntime,
        8, 100) a;
    auto b = a.allocate(64);
}

// SimpleBlocklist
/**

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

/*
(This type is not public.)

A $(D BasicRegion) allocator allocates memory straight from an externally-
provided storage as backend. There is no deallocation, and once the region is
full, allocation requests return $(D null). Therefore, $(D Region)s are often
used in conjunction with freelists and a fallback general-purpose allocator.

The region only stores two words, corresponding to the current position in the
store and the available length. One allocation entails rounding up the
allocation size for alignment purposes, bumping the current pointer, and
comparing it against the limit.

The $(D minAlign) parameter establishes alignment. If $(D minAlign > 1), the
sizes of all allocation requests are rounded up to a multiple of $(D minAlign).
Applications aiming at maximum speed may want to choose $(D minAlign = 1) and
control alignment externally.
*/
private struct BasicRegion(uint minAlign = platformAlignment)
{
    static assert(minAlign.isGoodStaticAlignment);
    private void* _current, _end;

    /**
    Constructs a region backed by a user-provided store.
    */
    this(void[] store)
    {
        static if (minAlign > 1)
        {
            auto newStore = cast(void*) roundUpToMultipleOf(
                cast(ulong) store.ptr,
                alignment);
            enforce(newStore <= store.ptr + store.length);
            _current = newStore;
        }
        else
        {
            _current = store;
        }
        _end = store.ptr + store.length;
    }

    /**
    The postblit of $(D BasicRegion) is disabled because such objects should not
    be copied around naively.
    */
    //@disable this(this);

    /**
    Standard allocator primitives.
    */
    enum uint alignment = minAlign;

    /// Ditto
    void[] allocate(size_t bytes)
    {
        static if (minAlign > 1)
            const rounded = bytes.roundUpToMultipleOf(alignment);
        else
            alias rounded = bytes;
        auto newCurrent = _current + rounded;
        if (newCurrent > _end) return null;
        auto result = _current[0 .. bytes];
        _current = newCurrent;
        assert(cast(ulong) result.ptr % alignment == 0);
        return result;
    }

    /// Ditto
    void[] alignedAllocate(size_t bytes, uint a)
    {
        // Just bump the pointer to the next good allocation
        auto save = _current;
        _current = cast(void*) roundUpToMultipleOf(
            cast(ulong) _current, a);
        if (auto b = allocate(bytes)) return b;
        // Failed, rollback
        _current = save;
        return null;
    }

    /// Allocates and returns all memory available to this region.
    void[] allocateAll()
    {
        auto result = _current[0 .. available];
        _current = _end;
        return result;
    }
    /// Nonstandard property that returns bytes available for allocation.
    size_t available() const
    {
        return _end - _current;
    }
}

/*
For implementers' eyes: Region adds more capabilities on top of $(BasicRegion)
at the cost of one extra word of storage. $(D Region) "remembers" the beginning
of the region and therefore is able to provide implementations of $(D owns) and
$(D deallocateAll). For most applications the performance distinction between
$(D BasicRegion) and $(D Region) is unimportant, so the latter should be the
default choice.
*/

/**
A $(D Region) allocator manages one block of memory provided at construction.
There is no deallocation, and once the region is full, allocation requests
return $(D null). Therefore, $(D Region)s are often used in conjunction
with freelists, a fallback general-purpose allocator, or both.

The region stores three words corresponding to the start of the store, the
current position in the store, and the end of the store. One allocation entails
rounding up the allocation size for alignment purposes, bumping the current
pointer, and comparing it against the limit.

The $(D minAlign) parameter establishes alignment. If $(D minAlign > 1), the
sizes of all allocation requests are rounded up to a multiple of $(D minAlign).
Applications aiming at maximum speed may want to choose $(D minAlign = 1) and
control alignment externally.
*/
struct Region(uint minAlign = platformAlignment)
{
    static assert(minAlign.isGoodStaticAlignment);

    private BasicRegion!(minAlign) base;
    private void* _begin;

    /**
    Constructs a $(D Region) object backed by $(D buffer), which must be aligned
    to $(D minAlign).
    */
    this(void[] buffer)
    {
        base = BasicRegion!minAlign(buffer);
        assert(buffer.ptr !is &this);
        _begin = base._current;
    }

    /**
    Standard primitives.
    */
    enum uint alignment = minAlign;

    /// Ditto
    void[] allocate(size_t bytes)
    {
        return base.allocate(bytes);
    }

    /// Ditto
    void[] alignedAllocate(size_t bytes, uint a)
    {
        return base.alignedAllocate(bytes, a);
    }

    /// Ditto
    bool owns(void[] b) const
    {
        return b.ptr >= _begin && b.ptr + b.length <= base._end
            || b is null;
    }

    /// Ditto
    void deallocateAll()
    {
        base._current = _begin;
    }

    /**
    Nonstandard function that gives away the initial buffer used by the range,
    and makes the range unavailable for further allocations. This is useful for
    deallocating the memory assigned to the region.
    */
    void[] relinquish()
    {
        auto result = _begin[0 .. base._end - _begin];
        base._current = base._end;
        return result;
    }
}

///
unittest
{
    auto reg = Region!()(Mallocator.it.allocate(1024 * 64));
    scope(exit) Mallocator.it.deallocate(reg.relinquish);
    auto b = reg.allocate(101);
    assert(b.length == 101);
}

/**

$(D InSituRegion) is a convenient region that carries its storage within itself
(in the form of a statically-sized array).

The first template argument is the size of the region and the second is the
needed alignment. Depending on the alignment requested and platform details,
the actual available storage may be smaller than the compile-time parameter. To
make sure that at least $(D n) bytes are available in the region, use
$(D InSituRegion!(n + a - 1, a)).

*/
struct InSituRegion(size_t size, size_t minAlign = platformAlignment)
{
    static assert(minAlign.isGoodStaticAlignment);
    static assert(size >= minAlign);

    @disable this(this);

    // The store will be aligned to double.alignof, regardless of the requested
    // alignment.
    union
    {
        private ubyte[size] _store = void;
        private double _forAlignmentOnly = void;
    }
    private void* _crt, _end;

    /**
    An alias for $(D minAlign), which must be a valid alignment (nonzero power
    of 2). The start of the region and all allocation requests will be rounded
    up to a multiple of the alignment.

    ----
    InSituRegion!(4096) a1;
    assert(a1.alignment == platformAlignment);
    InSituRegion!(4096, 64) a2;
    assert(a2.alignment == 64);
    ----
    */
    enum uint alignment = minAlign;

    private void lazyInit()
    {
        assert(!_crt);
        _crt = cast(void*) roundUpToMultipleOf(
            cast(ulong) _store.ptr, alignment);
        _end = _store.ptr + _store.length;
    }

    /**
    Allocates $(D bytes) and returns them, or $(D null) if the region cannot
    accommodate the request. For efficiency reasons, if $(D bytes == 0) the
    function returns an empty non-null slice.
    */
    void[] allocate(size_t bytes)
    {
        // Oddity: we don't return null for null allocation. Instead, we return
        // an empty slice with a non-null ptr.
        const rounded = bytes.roundUpToMultipleOf(alignment);
        auto newCrt = _crt + rounded;
        assert(newCrt >= _crt); // big overflow
    again:
        if (newCrt <= _end)
        {
            assert(_crt); // this relies on null + size > null
            auto result = _crt[0 .. bytes];
            _crt = newCrt;
            return result;
        }
        // slow path
        if (_crt) return null;
        // Lazy initialize _crt
        lazyInit();
        newCrt = _crt + rounded;
        goto again;
    }

    /**
    As above, but the memory allocated is aligned at $(D a) bytes.
    */
    void[] alignedAllocate(size_t bytes, uint a)
    {
        // Just bump the pointer to the next good allocation
        auto save = _crt;
        _crt = cast(void*) roundUpToMultipleOf(
            cast(ulong) _crt, a);
        if (auto b = allocate(bytes)) return b;
        // Failed, rollback
        _crt = save;
        return null;
    }

    /**
    Returns $(D true) if and only if $(D b) is the result of a successful
    allocation. For efficiency reasons, if $(D b is null) the function returns
    $(D false).
    */
    bool owns(void[] b) const
    {
        // No nullptr
        return b.ptr >= _store.ptr
            && b.ptr + b.length <= _store.ptr + _store.length;
    }

    /**
    Deallocates all memory allocated with this allocator.
    */
    void deallocateAll()
    {
        _crt = _store.ptr;
    }

    /**
    Allocates all memory available with this allocator.
    */
    void[] allocateAll()
    {
        auto s = available;
        auto result = _crt[0 .. s];
        _crt = _end;
        return result;
    }

    /**
    Nonstandard function that returns the bytes available for allocation.
    */
    size_t available()
    {
        if (!_crt) lazyInit();
        return _end - _crt;
    }
}

///
unittest
{
    // 128KB region, allocated to x86's cache line
    InSituRegion!(128 * 1024, 64) r1;
    auto a1 = r1.allocate(101);
    assert(a1.length == 101);

    // 128KB region, with fallback to the garbage collector.
    FallbackAllocator!(InSituRegion!(128 * 1024), GCAllocator) r2;
    auto a2 = r1.allocate(102);
    assert(a2.length == 102);

    // Reap with GC fallback.
    InSituRegion!(128 * 1024, 8) tmp3;
    FallbackAllocator!(HeapBlock!(64, 8), GCAllocator) r3;
    r3.primary = HeapBlock!(64, 8)(tmp3.allocateAll());
    auto a3 = r3.allocate(103);
    assert(a3.length == 103);

    // Reap/GC with a freelist for small objects up to 16 bytes.
    InSituRegion!(128 * 1024, 64) tmp4;
    Freelist!(FallbackAllocator!(HeapBlock!(64, 64), GCAllocator), 0, 16) r4;
    r4.parent.primary = HeapBlock!(64, 64)(tmp4.allocateAll());
    auto a4 = r4.allocate(104);
    assert(a4.length == 104);
}

unittest
{
    InSituRegion!(4096) r1;
    auto a = r1.allocate(2001);
    assert(a.length == 2001);
    assert(r1.available == 2080, text(r1.available));

    InSituRegion!(65536, 1024*4) r2;
    assert(r2.available <= 65536);
    a = r2.allocate(2001);
    assert(a.length == 2001);
}

private extern(C) void* sbrk(long);
private extern(C) int brk(shared void*);

/**

Allocator backed by $(D $(LUCKY sbrk)) for Posix systems. Due to the fact that
$(D sbrk) is not thread-safe $(WEB lifecs.likai.org/2010/02/sbrk-is-not-thread-
safe.html, by design), $(D SbrkRegion) uses a mutex internally. This implies
that uncontrolled calls to $(D brk) and $(D sbrk) may affect the workings of $(D
SbrkRegion) adversely.

*/
version(Posix) struct SbrkRegion(uint minAlign = platformAlignment)
{
    import core.sys.posix.pthread;
    static shared pthread_mutex_t sbrkMutex;

    static assert(minAlign.isGoodStaticAlignment);
    static assert(size_t.sizeof == (void*).sizeof);
    private shared void* _brkInitial, _brkCurrent;

    /**
    Instance shared by all callers.
    */
    static shared SbrkRegion it;

    /**
    Standard allocator primitives.
    */
    enum uint alignment = minAlign;

    /// Ditto
    void[] allocate(size_t bytes) shared
    {
        static if (minAlign > 1)
            const rounded = bytes.roundUpToMultipleOf(alignment);
        else
            alias rounded = bytes;
        pthread_mutex_lock(cast(pthread_mutex_t*) &sbrkMutex) || assert(0);
        scope(exit) pthread_mutex_unlock(cast(pthread_mutex_t*) &sbrkMutex)
            || assert(0);
        // Assume sbrk returns the old break. Most online documentation confirms
        // that, except for http://www.inf.udec.cl/~leo/Malloc_tutorial.pdf,
        // which claims the returned value is not portable.
        auto p = sbrk(rounded);
        if (p == cast(void*) -1)
        {
            return null;
        }
        if (!_brkInitial)
        {
            _brkInitial = cast(shared) p;
            assert(cast(size_t) _brkInitial % minAlign == 0,
                "Too large alignment chosen for " ~ typeof(this).stringof);
        }
        _brkCurrent = cast(shared) (p + rounded);
        return p[0 .. bytes];
    }

    /// Ditto
    void[] alignedAllocate(size_t bytes, uint a) shared
    {
        pthread_mutex_lock(cast(pthread_mutex_t*) &sbrkMutex) || assert(0);
        scope(exit) pthread_mutex_unlock(cast(pthread_mutex_t*) &sbrkMutex)
            || assert(0);
        if (!_brkInitial)
        {
            // This is one extra call, but it'll happen only once.
            _brkInitial = cast(shared) sbrk(0);
            assert(cast(size_t) _brkInitial % minAlign == 0,
                "Too large alignment chosen for " ~ typeof(this).stringof);
            (_brkInitial != cast(void*) -1) || assert(0);
            _brkCurrent = _brkInitial;
        }
        immutable size_t delta = cast(shared void*) roundUpToMultipleOf(
            cast(ulong) _brkCurrent, a) - _brkCurrent;
        // Still must make sure the total size is aligned to the allocator's
        // alignment.
        immutable rounded = (bytes + delta).roundUpToMultipleOf(alignment);

        auto p = sbrk(rounded);
        if (p == cast(void*) -1)
        {
            return null;
        }
        _brkCurrent = cast(shared) (p + rounded);
        return p[delta .. delta + bytes];
    }

    /**

    The $(D expand) method may only succeed if the argument is the last block
    allocated. In that case, $(D expand) attempts to push the break pointer to
    the right.

    */
    bool expand(ref void[] b, size_t delta) shared
    {
        if (b is null) return (b = allocate(delta)) !is null;
        assert(_brkInitial && _brkCurrent); // otherwise where did b come from?
        pthread_mutex_lock(cast(pthread_mutex_t*) &sbrkMutex) || assert(0);
        scope(exit) pthread_mutex_unlock(cast(pthread_mutex_t*) &sbrkMutex)
            || assert(0);
        if (_brkCurrent != b.ptr + b.length) return false;
        // Great, can expand the last block
        static if (minAlign > 1)
            const rounded = delta.roundUpToMultipleOf(alignment);
        else
            alias rounded = bytes;
        auto p = sbrk(rounded);
        if (p == cast(void*) -1)
        {
            return false;
        }
        _brkCurrent = cast(shared) (p + rounded);
        b = b.ptr[0 .. b.length + delta];
        return true;
    }

    /// Ditto
    bool owns(void[] b) shared
    {
        // No need to lock here.
        assert(!_brkCurrent || b.ptr + b.length <= _brkCurrent);
        return _brkInitial && b.ptr >= _brkInitial;
    }

    /**

    The $(D deallocate) method only works (and returns $(D true))  on systems
    that support reducing the  break address (i.e. accept calls to $(D sbrk)
    with negative offsets). OSX does not accept such. In addition the argument
    must be the last block allocated.

    */
    bool deallocate(void[] b) shared
    {
        static if (minAlign > 1)
            const rounded = b.length.roundUpToMultipleOf(alignment);
        else
            const rounded = b.length;
        pthread_mutex_lock(cast(pthread_mutex_t*) &sbrkMutex) || assert(0);
        scope(exit) pthread_mutex_unlock(cast(pthread_mutex_t*) &sbrkMutex)
            || assert(0);
        if (_brkCurrent != b.ptr + b.length) return false;
        assert(b.ptr >= _brkInitial);
        if (sbrk(-rounded) == cast(void*) -1)
            return false;
        _brkCurrent = cast(shared) b.ptr;
        return true;
    }

    /**
    The $(D deallocateAll) method only works (and returns $(D true)) on systems
    that support reducing the  break address (i.e. accept calls to $(D sbrk)
    with negative offsets). OSX does not accept such.
    */
    bool deallocateAll() shared
    {
        pthread_mutex_lock(cast(pthread_mutex_t*) &sbrkMutex) || assert(0);
        scope(exit) pthread_mutex_unlock(cast(pthread_mutex_t*) &sbrkMutex)
            || assert(0);
        return !_brkInitial || brk(_brkInitial) == 0;
    }

    /// Standard allocator API.
    bool empty()
    {
        // Also works when they're both null.
        return _brkCurrent == _brkInitial;
    }

    /// Ditto
    enum bool zeroesAllocations = true;
}

version(Posix) unittest
{
    // Let's test the assumption that sbrk(n) returns the old address
    auto p1 = sbrk(0);
    auto p2 = sbrk(4096);
    assert(p1 == p2);
    auto p3 = sbrk(0);
    assert(p3 == p2 + 4096);
    // Try to reset brk, but don't make a fuss if it doesn't work
    sbrk(-4096);
}

version(Posix) unittest
{
    alias alloc = SbrkRegion!(8).it;
    auto a = alloc.alignedAllocate(2001, 4096);
    assert(a.length == 2001);
    auto b = alloc.allocate(2001);
    assert(b.length == 2001);
    assert(alloc.owns(a));
    assert(alloc.owns(b));
    // reducing the brk does not work on OSX
    version(OSX) {} else
    {
        assert(alloc.deallocate(b));
        assert(alloc.deallocateAll);
    }
}

// MmapAllocator
/**

Allocator (currently defined only for Posix) using $(D $(LUCKY mmap)) and $(D
$(LUCKY munmap)) directly. There is no additional structure: each call to $(D
allocate(s)) issues a call to $(D mmap(null, s, PROT_READ | PROT_WRITE,
MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)), and each call to $(D deallocate(b)) issues
$(D munmap(b.ptr, b.length)). So $(D MmapAllocator) is usually intended for
allocating large chunks to be managed by fine-granular allocators.

*/
version(Posix) struct MmapAllocator
{
    import core.sys.posix.sys.mman;
    /// The one shared instance.
    static shared MmapAllocator it;

    /**
    Alignment is page-size and hardcoded to 4096 (even though on certain systems
    it could be larger).
    */
    enum size_t alignment = 4096;

    /// Allocator API.
    void[] allocate(size_t bytes) shared
    {
        version(OSX) import core.sys.osx.sys.mman : MAP_ANON;
        else static assert(false, "Add import for MAP_ANON here.");
        auto p = mmap(null, bytes, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANON, -1, 0);
        if (p is MAP_FAILED) return null;
        return p[0 .. bytes];
    }

    /// Ditto
    void deallocate(void[] b) shared
    {
        munmap(b.ptr, b.length) == 0 || assert(0);
    }

    /// Ditto
    enum zeroesAllocations = true;
}

version(Posix) unittest
{
    alias alloc = MmapAllocator.it;
    auto p = alloc.allocate(100);
    assert(p.length == 100);
    alloc.deallocate(p);
}

/**
_Options for $(D AllocatorWithStats) defined below. Each enables during
compilation one specific counter, statistic, or other piece of information.
*/
enum Options : uint
{
    /**
    Counts the number of calls to $(D owns).
    */
    numOwns = 1u << 0,
    /**
    Counts the number of calls to $(D allocate). All calls are counted,
    including requests for zero bytes or failed requests.
    */
    numAllocate = 1u << 1,
    /**
    Counts the number of calls to $(D allocate) that succeeded, i.e. they were
    for more than zero bytes and returned a non-null block.
    */
    numAllocateOK = 1u << 2,
    /**
    Counts the number of calls to $(D expand), regardless of arguments or
    result.
    */
    numExpand = 1u << 3,
    /**
    Counts the number of calls to $(D expand) that resulted in a successful
    expansion.
    */
    numExpandOK = 1u << 4,
    /**
    Counts the number of calls to $(D reallocate), regardless of arguments or
    result.
    */
    numReallocate = 1u << 5,
    /**
    Counts the number of calls to $(D reallocate) that succeeded. (Reallocations
    to zero bytes count as successful.)
    */
    numReallocateOK = 1u << 6,
    /**
    Counts the number of calls to $(D reallocate) that resulted in an in-place
    reallocation (no memory moved). If this number is close to the total number
    of reallocations, that indicates the allocator finds room at the current
    block's end in a large fraction of the cases, but also that internal
    fragmentation may be high (the size of the unit of allocation is large
    compared to the typical allocation size of the application).
    */
    numReallocateInPlace = 1u << 7,
    /**
    Counts the number of calls to $(D deallocate).
    */
    numDeallocate = 1u << 8,
    /**
    Counts the number of calls to $(D deallocateAll).
    */
    numDeallocateAll = 1u << 9,
    /**
    Chooses all $(D numXxx) flags.
    */
    numAll = (1u << 10) - 1,
    /**
    Tracks total cumulative bytes allocated by means of $(D allocate),
    $(D expand), and $(D reallocate) (when resulting in an expansion). This
    number always grows and indicates allocation traffic. To compute bytes
    currently allocated, subtract $(D bytesDeallocated) (below) from
    $(D bytesAllocated).
    */
    bytesAllocated = 1u << 10,
    /**
    Tracks total cumulative bytes deallocated by means of $(D deallocate) and
    $(D reallocate) (when resulting in a contraction). This number always grows
    and indicates deallocation traffic.
    */
    bytesDeallocated = 1u << 11,
    /**
    Tracks the sum of all $(D delta) values in calls of the form
    $(D expand(b, delta)) that succeed (return $(D true)).
    */
    bytesExpanded = 1u << 12,
    /**
    Tracks the sum of all $(D b.length - s) with $(D b.length > s) in calls of
    the form $(D realloc(b, s)) that succeed (return $(D true)).
    */
    bytesContracted = 1u << 13,
    /**
    Tracks the sum of all bytes moved as a result of calls to $(D realloc) that
    were unable to reallocate in place. A large number (relative to $(D
    bytesAllocated)) indicates that the application should use larger
    preallocations.
    */
    bytesMoved = 1u << 14,
    /**
    Measures the sum of extra bytes allocated beyond the bytes requested, i.e.
    the $(WEB goo.gl/YoKffF, internal fragmentation). This is the current
    effective number of slack bytes, and it goes up and down with time.
    */
    bytesSlack = 1u << 15,
    /**
    Measures the maximum bytes allocated over the time. This is useful for
    dimensioning allocators.
    */
    bytesHighTide = 1u << 16,
    /**
    Chooses all $(D byteXxx) flags.
    */
    bytesAll = ((1u << 17) - 1) & ~numAll,
    /**
    Instructs $(D AllocatorWithStats) to store the size asked by the caller for
    each allocation. All per-allocation data is stored just before the actually
    allocation (see $(D AffixAllocator)).
    */
    callerSize = 1u << 17,
    /**
    Instructs $(D AllocatorWithStats) to store the caller module for each
    allocation.
    */
    callerModule = 1u << 18,
    /**
    Instructs $(D AllocatorWithStats) to store the caller's file for each
    allocation.
    */
    callerFile = 1u << 19,
    /**
    Instructs $(D AllocatorWithStats) to store the caller $(D __FUNCTION__) for
    each allocation.
    */
    callerFunction = 1u << 20,
    /**
    Instructs $(D AllocatorWithStats) to store the caller's line for each
    allocation.
    */
    callerLine = 1u << 21,
    /**
    Instructs $(D AllocatorWithStats) to store the time of each allocation.
    */
    callerTime = 1u << 22,
    /**
    Chooses all $(D callerXxx) flags.
    */
    callerAll = ((1u << 23) - 1) & ~numAll & ~bytesAll,
    /**
    Combines all flags above.
    */
    all = (1u << 23) - 1
}

/**

Allocator that collects extra data about allocations. Since each piece of
information adds size and time overhead, statistics can be individually enabled
or disabled through compile-time $(D flags).

All stats of the form $(D numXxx) record counts of events occurring, such as
calls to functions and specific results. The stats of the form $(D bytesXxx)
collect cumulative sizes.

In addition, the data $(D callerSize), $(D callerModule), $(D callerFile), $(D
callerLine), and $(D callerTime) is associated with each specific allocation.
This data prefixes each allocation.

*/
struct AllocatorWithStats(Allocator, uint flags = Options.all)
{
private:
    // Per-allocator state
    mixin(define("ulong",
        "numOwns",
        "numAllocate",
        "numAllocateOK",
        "numExpand",
        "numExpandOK",
        "numReallocate",
        "numReallocateOK",
        "numReallocateInPlace",
        "numDeallocate",
        "numDeallocateAll",
        "bytesAllocated",
        "bytesDeallocated",
        "bytesExpanded",
        "bytesContracted",
        "bytesMoved",
        "bytesSlack",
        "bytesHighTide",
    ));

    static string define(string type, string[] names...)
    {
        string result;
        foreach (v; names)
            result ~= "static if (flags & Options."~v~") {"
                "private "~type~" _"~v~";"
                "public const("~type~") "~v~"() const { return _"~v~"; }"
                "}";
        return result;
    }

    void add(string counter)(Signed!size_t n)
    {
        mixin("static if (flags & Options." ~ counter
            ~ ") _" ~ counter ~ " += n;");
    }

    void up(string counter)() { add!counter(1); }
    void down(string counter)() { add!counter(-1); }

    version (StdDdoc)
    {
        /**
        Read-only properties enabled by the homonym $(D flags) chosen by the
        user.

        Example:
        ----
        AllocatorWithStats!(Mallocator,
            Options.bytesAllocated | Options.bytesDeallocated) a;
        auto d1 = a.allocate(10);
        auto d2 = a.allocate(11);
        a.deallocate(d1);
        assert(a.bytesAllocated == 21);
        assert(a.bytesDeallocated == 10);
        ----
        */
        @property ulong numOwns() const;
        /// Ditto
        @property ulong numAllocate() const;
        /// Ditto
        @property ulong numAllocateOK() const;
        /// Ditto
        @property ulong numExpand() const;
        /// Ditto
        @property ulong numExpandOK() const;
        /// Ditto
        @property ulong numReallocate() const;
        /// Ditto
        @property ulong numReallocateOK() const;
        /// Ditto
        @property ulong numReallocateInPlace() const;
        /// Ditto
        @property ulong numDeallocate() const;
        /// Ditto
        @property ulong numDeallocateAll() const;
        /// Ditto
        @property ulong bytesAllocated() const;
        /// Ditto
        @property ulong bytesDeallocated() const;
        /// Ditto
        @property ulong bytesExpanded() const;
        /// Ditto
        @property ulong bytesContracted() const;
        /// Ditto
        @property ulong bytesMoved() const;
        /// Ditto
        @property ulong bytesSlack() const;
        /// Ditto
        @property ulong bytesHighTide() const;
    }

    // Do flags require any per allocation state?
    enum hasPerAllocationState = flags & (Options.callerTime
        | Options.callerModule | Options.callerFile | Options.callerLine);

    version (StdDdoc)
    {
        /**
        Per-allocation information that can be iterated upon by using
        $(D byAllocation). This only tracks live allocations and is useful for
        e.g. tracking memory leaks.

        Example:
        ----
        AllocatorWithStats!(Mallocator, Options.all) a;
        auto d1 = a.allocate(10);
        auto d2 = a.allocate(11);
        a.deallocate(d1);
        foreach (ref e; a.byAllocation)
        {
            writeln("Allocation module: ", e.callerModule);
        }
        ----
        */
        public struct AllocationInfo
        {
            /**
            Read-only property defined by the corresponding flag chosen in
            $(D options).
            */
            @property size_t callerSize() const;
            /// Ditto
            @property string callerModule() const;
            /// Ditto
            @property string callerFile() const;
            /// Ditto
            @property uint callerLine() const;
            /// Ditto
            @property uint callerFunction() const;
            /// Ditto
            @property const(SysTime) callerTime() const;
        }
    }
    else static if (hasPerAllocationState)
    {
        public struct AllocationInfo
        {
            import std.datetime;
            mixin(define("string", "callerModule", "callerFile",
                "callerFunction"));
            mixin(define("uint", "callerLine"));
            mixin(define("size_t", "callerSize"));
            mixin(define("SysTime", "callerTime"));
            private AllocationInfo* _prev, _next;
        }
        AllocationInfo* _root;
        alias MyAllocator = AffixAllocator!(Allocator, AllocationInfo);

        public auto byAllocation()
        {
            struct Voldemort
            {
                private AllocationInfo* _root;
                bool empty() { return _root is null; }
                ref AllocationInfo front() { return *_root; }
                void popFront() { _root = _root._next; }
                Voldemort save() { return this; }
            }
            return Voldemort(_root);
        }
    }
    else
    {
        alias MyAllocator = Allocator;
    }

public:
    // Parent allocator (publicly accessible)
    static if (stateSize!MyAllocator) MyAllocator parent;
    else alias parent = MyAllocator.it;

    enum uint alignment = Allocator.alignment;

    static if (hasMember!(Allocator, "owns"))
    bool owns(void[] b)
    {
        up!"numOwns";
        return parent.owns(b);
    }

    void[] allocate
        (string m = __MODULE__, string f = __FILE__, ulong n = __LINE__,
            string fun = __FUNCTION__)
        (size_t bytes)
    {
        up!"numAllocate";
        auto result = parent.allocate(bytes);
        add!"bytesAllocated"(result.length);
        add!"bytesSlack"(this.goodAllocSize(result.length) - result.length);
        add!"numAllocateOK"(result || !bytes); // allocating 0 bytes is OK
        static if (flags & Options.bytesHighTide)
        {
            const bytesNow = bytesAllocated - bytesDeallocated;
            if (_bytesHighTide < bytesNow) _bytesHighTide = bytesNow;
        }
        static if (hasPerAllocationState)
        {
            auto p = &parent.prefix(result);
            static if (flags & Options.callerSize)
                p._callerSize = bytes;
            static if (flags & Options.callerModule)
                p._callerModule = m;
            static if (flags & Options.callerFile)
                p._callerFile = f;
            static if (flags & Options.callerFunction)
                p._callerFunction = fun;
            static if (flags & Options.callerLine)
                p._callerLine = n;
            static if (flags & Options.callerTime)
            {
                import std.datetime;
                p._callerTime =  Clock.currTime;
            }
            // Wire the new info into the list
            assert(p._prev is null);
            p._next = _root;
            if (_root) _root._prev = p;
            _root = p;
        }
        return result;
    }

    static if (hasMember!(Allocator, "expand"))
    bool expand(ref void[] b, size_t s)
    {
        up!"numExpand";
        static if (flags & Options.bytesSlack)
            const bytesSlackB4 = goodAllocSize(b.length) - b.length;
        auto result = parent.expand(b, s);
        if (result)
        {
            up!"numExpandOK";
            add!"bytesExpanded"(s);
            add!"bytesSlack"(goodAllocSize(b.length) - b.length - bytesSlackB4);
        }
        return result;
    }

    bool reallocate(ref void[] b, size_t s)
    {
        up!"numReallocate";
        static if (flags & Options.bytesSlack)
            const bytesSlackB4 = this.goodAllocSize(b.length) - b.length;
        static if (flags & Options.numReallocateInPlace)
            const oldB = b.ptr;
        static if (flags & Options.bytesMoved)
            const oldLength = b.length;
        static if (hasPerAllocationState)
            const reallocatingRoot = b && _root is &parent.prefix(b);
        if (!parent.reallocate(b, s)) return false;
        up!"numReallocateOK";
        add!"bytesSlack"(this.goodAllocSize(b.length) - b.length
            - bytesSlackB4);
        if (oldB == b.ptr)
        {
            // This was an in-place reallocation, yay
            up!"numReallocateInPlace";
            const Signed!size_t delta = b.length - oldLength;
            if (delta >= 0)
            {
                // Expansion
                add!"bytesAllocated"(delta);
                add!"bytesExpanded"(delta);
            }
            else
            {
                // Contraction
                add!"bytesDeallocated"(-delta);
                add!"bytesContracted"(-delta);
            }
        }
        else
        {
            // This was a allocate-move-deallocate cycle
            add!"bytesAllocated"(b.length);
            add!"bytesMoved"(oldLength);
            add!"bytesDeallocated"(oldLength);
            static if (hasPerAllocationState)
            {
                // Stitch the pointers again, ho-hum
                auto p = &parent.prefix(b);
                if (p._next) p._next._prev = p;
                if (p._prev) p._prev._next = p;
                if (reallocatingRoot) _root = p;
            }
        }
        return true;
    }

    void deallocate(void[] b)
    {
        up!"numDeallocate";
        add!"bytesDeallocated"(b.length);
        add!"bytesSlack"(-(this.goodAllocSize(b.length) - b.length));
        // Remove the node from the list
        static if (hasPerAllocationState)
        {
            auto p = &parent.prefix(b);
            if (p._next) p._next._prev = p._prev;
            if (p._prev) p._prev._next = p._next;
            if (_root is p) _root = p._next;
        }
        parent.deallocate(b);
    }

    static if (hasMember!(Allocator, "deallocateAll"))
    void deallocateAll()
    {
        up!"numDeallocateAll";
        // Must force bytesDeallocated to match bytesAllocated
        static if ((flags & Options.bytesDeallocated)
                && (flags & Options.bytesDeallocated))
            _bytesDeallocated = _bytesAllocated;
        parent.deallocateAll();
        static if (hasPerAllocationState) _root = null;
    }
}

string forward(string p, string[] names...)
{
    string r;
    foreach (n; names)
    {
        r ~= "static if (hasMember!(typeof("~p~"), `"~n~"`)"
            ~ ") auto ref "~n~"(T_...)(T_ t_) { return "~p~"."~n~"(t_); }\n";
    }
    return r;
}

unittest
{
    struct A
    {
        static int fun(int, string) { return 42; }
        static int gun(int, string, double) { return 43; }
    }
    struct B
    {
        A a;
        //pragma(msg, forward("a", "fun", "gun"));
        mixin(forward("a", "fun", "gun"));
    }
    B b;
    assert(b.fun(1, "a") == 42);
    assert(b.gun(1, "a", 3) == 43);
}

unittest
{
    void test(Allocator)()
    {
        Allocator a;
        auto b1 = a.allocate(100);
        assert(a.numAllocate == 1);
        auto b2 = a.allocate(101);
        assert(a.numAllocate == 2);
        assert(a.bytesAllocated == 201);
        auto b3 = a.allocate(202);
        assert(a.numAllocate == 3);
        assert(a.bytesAllocated == 403);

        assert(walkLength(a.byAllocation) == 3);

        foreach (ref e; a.byAllocation)
        {
            if (false) writeln(e);
        }

        a.deallocate(b2);
        assert(a.numDeallocate == 1);
        a.deallocate(b1);
        assert(a.numDeallocate == 2);
        a.deallocate(b3);
        assert(a.numDeallocate == 3);
        assert(a.numAllocate == a.numDeallocate);
        assert(a.bytesDeallocated == 403);
    }

    test!(AllocatorWithStats!Mallocator)();
    test!(AllocatorWithStats!(Freelist!(Mallocator, 128)))();
}

//struct ArrayOfAllocators(alias make)
//{
//    alias Allocator = typeof(make());
//    private Allocator[] allox;

//    void[] allocate(size_t bytes)
//    {
//        void[] result = allocateNoGrow(bytes);
//        if (result) return result;
//        // Everything's full to the brim, create a new allocator.
//        auto newAlloc = make();
//        assert(&newAlloc !is newAlloc.initial);
//        // Move the array to the new allocator
//        assert(Allocator.alignment % Allocator.alignof == 0);
//        const arrayBytes = (allox.length + 1) * Allocator.sizeof;
//        Allocator[] newArray = void;
//        do
//        {
//            if (arrayBytes < bytes)
//            {
//                // There is a chance we can find room in the existing allocator.
//                newArray = cast(Allocator[]) allocateNoGrow(arrayBytes);
//                if (newArray) break;
//            }
//            newArray = cast(Allocator[]) newAlloc.allocate(arrayBytes);
//            writeln(newArray.length);
//            assert(newAlloc.initial !is &newArray[$ - 1]);
//            if (!newArray) return null;
//        } while (false);

//        assert(newAlloc.initial !is &newArray[$ - 1]);

//        // Move data over to the new position
//        foreach (i, ref e; allox)
//        {
//            writeln(&e, " ", e.base.store_.ptr, " ", e.initial);
//            e.move(newArray[i]);
//        }
//        auto recoveredBytes = allox.length * Allocator.sizeof;
//        static if (hasMember!(Allocator, "deallocate"))
//            deallocate(allox);
//        allox = newArray;
//        assert(&allox[$ - 1] !is newAlloc.initial);
//        newAlloc.move(allox[$ - 1]);
//        assert(&allox[$ - 1] !is allox[$ - 1].initial);
//        if (recoveredBytes >= bytes)
//        {
//            // The new request may be served from the just-freed memory. Recurse
//            // and be bold.
//            return allocateNoGrow(bytes);
//        }
//        // Otherwise, we can't possibly fetch memory from anywhere else but the
//        // fresh new allocator.
//        return allox.back.allocate(bytes);
//    }

//    private void[] allocateNoGrow(size_t bytes)
//    {
//        void[] result;
//        foreach (ref a; allox)
//        {
//            result = a.allocate(bytes);
//            if (result) break;
//        }
//        return result;
//    }

//    bool owns(void[] b)
//    {
//        foreach (i, ref a; allox)
//        {
//            if (a.owns(b)) return true;
//        }
//        return false;
//    }

//    static if (hasMember!(Allocator, "deallocate"))
//    void deallocate(void[] b)
//    {
//        foreach (i, ref a; allox)
//        {
//            if (!a.owns(b)) continue;
//            a.deallocate(b);
//            break;
//        }
//    }
//}
//
//version(none) unittest
//{
//    ArrayOfAllocators!({ return Region!()(new void[1024 * 4096]); }) a;
//    assert(a.allox.length == 0);
//    auto b1 = a.allocate(1024 * 8192);
//    assert(b1 is null);
//    b1 = a.allocate(1024 * 10);
//    assert(b1.length == 1024 * 10);
//    assert(a.allox.length == 1);
//    auto b2 = a.allocate(1024 * 4095);
//    assert(a.allox.length == 2);
//}


/**
Given $(D make) as a function that returns fresh allocators, $(D
CascadingAllocator) creates an allocator that lazily creates as many allocators
are needed for satisfying client allocation requests.

The management data of the allocators is stored in memory obtained from the
allocators themselves, in a private linked list.
*/
struct CascadingAllocator(alias make)
{
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
        if (result) return result;
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
            if (result) break;
            if (!n.nextIsInitialized) break;
        }
        return result;
    }

    /// Defined only if $(D Allocator.owns) is defined.
    static if (hasMember!(Allocator, "owns"))
    bool owns(void[] b)
    {
        if (!_root || !b) return false;
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
        if (!b) return delta == 0 || (b = allocate(delta)) !is null;
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
        if (!b) return (b = allocate(s)) !is null;
        // First attempt to reallocate within the existing node
        if (!_root) return false;
        for (auto n = _root; ; n = n.next)
        {
            if (n.a.owns(b) && n.a.reallocate(b, s)) return true;
            if (!n.nextIsInitialized) break;
        }
        // Failed, but we may find new memory in a new node.
        auto newB = allocate(s);
        if (!newB) return false;
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
        if (!b || !_root)
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
    CascadingAllocator!({ return Region!()(new void[1024 * 4096]); }) a;
    auto b1 = a.allocate(1024 * 8192);
    assert(b1 is null); // can't allocate more than 4MB at a time
    b1 = a.allocate(1024 * 10);
    assert(b1.length == 1024 * 10);
    a.deallocateAll();
}

unittest
{
    CascadingAllocator!({ return Region!()(new void[1024 * 4096]); }) a;
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
                128, Freelist!(Mallocator, 0, 128),
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
            128, Freelist!(Mallocator, 0, 128),
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
    Bucketizer!(Freelist!(Mallocator, 0, unbounded),
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
    alias ThreadLocal!(Freelist!(GCAllocator, 0, 8, 1)) Allocator;
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

    Freelist!(GCAllocator, 0, 8, 1) fl;
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
    alias FList = Freelist!(GCAllocator, 0, unbounded);
    alias A = ThreadLocal!(
        Segregator!(
            8, Freelist!(GCAllocator, 0, 8),
            128, Bucketizer!(FList, 1, 128, 16),
            256, Bucketizer!(FList, 129, 256, 32),
            512, Bucketizer!(FList, 257, 512, 64),
            1024, Bucketizer!(FList, 513, 1024, 128),
            2048, Bucketizer!(FList, 1025, 2048, 256),
            3584, Bucketizer!(FList, 2049, 3584, 512),
            4072 * 1024, CascadingAllocator!(
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

    alias FList = Freelist!(GCAllocator, 0, unbounded);
    alias A = Segregator!(
        8, Freelist!(GCAllocator, 0, 8),
        128, Bucketizer!(FList, 1, 128, 16),
        256, Bucketizer!(FList, 129, 256, 32),
        512, Bucketizer!(FList, 257, 512, 64),
        1024, Bucketizer!(FList, 513, 1024, 128),
        2048, Bucketizer!(FList, 1025, 2048, 256),
        3584, Bucketizer!(FList, 2049, 3584, 512),
        4072 * 1024, CascadingAllocator!(
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
