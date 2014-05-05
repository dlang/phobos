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

The example below features an allocator modeled after $(WEB goo.gl/m7329l,
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

module std.allocator;

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

/*
Ternary by Timon Gehr and Andrei Alexandrescu.
*/
private struct Ternary
{
    private ubyte value = 6;
    private static Ternary make(ubyte b)
    {
        Ternary r = void;
        r.value = b;
        return r;
    }

    enum no = make(0), yes = make(2), unknown = make(6);

    this(bool b) { value = b << 1; }

    void opAssign(bool b) { value = b << 1; }

    Ternary opUnary(string s)() if (s == "~")
    {
        return make(386 >> value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "|")
    {
        return make(25512 >> value + rhs.value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "&")
    {
        return make(26144 >> value + rhs.value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "^")
    {
        return make(26504 >> value + rhs.value & 6);
    }
}

unittest
{
    alias f = Ternary.no, t = Ternary.yes, u = Ternary.unknown;
    auto truthTableAnd =
    [
        t, t, t,
        t, u, u,
        t, f, f,
        u, t, u,
        u, u, u,
        u, f, f,
        f, t, f,
        f, u, f,
        f, f, f,
    ];

    auto truthTableOr =
    [
        t, t, t,
        t, u, t,
        t, f, t,
        u, t, t,
        u, u, u,
        u, f, u,
        f, t, t,
        f, u, u,
        f, f, f,
    ];

    auto truthTableXor =
    [
        t, t, f,
        t, u, u,
        t, f, t,
        u, t, u,
        u, u, u,
        u, f, u,
        f, t, t,
        f, u, u,
        f, f, f,
    ];

    for (auto i = 0; i != truthTableAnd.length; i += 3)
    {
        assert((truthTableAnd[i] & truthTableAnd[i + 1])
            == truthTableAnd[i + 2]);
        assert((truthTableOr[i] | truthTableOr[i + 1])
            == truthTableOr[i + 2]);
        assert((truthTableXor[i] ^ truthTableXor[i + 1])
            == truthTableXor[i + 2]);
    }

    Ternary a;
    assert(a == Ternary.unknown);
    static assert(!is(typeof({ if (a) {} })));
    assert(!is(typeof({ auto b = Ternary(3); })));
    a = true;
    assert(a == Ternary.yes);
    a = false;
    assert(a == Ternary.no);
    a = Ternary.unknown;
    assert(a == Ternary.unknown);
    Ternary b;
    b = a;
    assert(b == a);
    assert(~Ternary.yes == Ternary.no);
    assert(~Ternary.no == Ternary.yes);
    assert(~Ternary.unknown == Ternary.unknown);
}

/**
Returns the size in bytes of the state that needs to be allocated to hold an
object of type $(D T). $(D stateSize!T) is zero for $(D struct)s that are not
nested and have no nonstatic member variables.
 */
template stateSize(T)
{
    static if (is(T == class) || is(T == interface))
        enum stateSize = __traits(classInstanceSize, T);
    else static if (is(T == struct) || is(T == union))
        enum stateSize = FieldTypeTuple!T.length || isNested!T ? T.sizeof : 0;
    else static if (is(T == void))
        enum size_t stateSize = 0;
    else
        enum stateSize = T.sizeof;
}

unittest
{
    static assert(stateSize!void == 0);
    struct A {}
    static assert(stateSize!A == 0);
    struct B { int x; }
    static assert(stateSize!B == 4);
    interface I1 {}
    //static assert(stateSize!I1 == 2 * size_t.sizeof);
    class C1 {}
    static assert(stateSize!C1 == 3 * size_t.sizeof);
    class C2 { char c; }
    static assert(stateSize!C2 == 4 * size_t.sizeof);
    static class C3 { char c; }
    static assert(stateSize!C3 == 2 * size_t.sizeof + char.sizeof);
}

/**
$(D chooseAtRuntime) is a compile-time constant of type $(D size_t) that several
parameterized structures in this module recognize to mean deferral to runtime of
the exact value. For example, $(D HeapBlock!(Allocator, 4096)) (described in
detail below) defines a block allocator with block size of 4096 bytes, whereas
$(D HeapBlock!(Allocator, chooseAtRuntime)) defines a block allocator that has a
field storing the block size, initialized by the user.
*/
enum chooseAtRuntime = size_t.max - 1;

/**
$(D unbounded) is a compile-time constant of type $(D size_t) that several
parameterized structures in this module recognize to mean "infinite" bounds for
the parameter. For example, $(D Freelist) (described in detail below) accepts a
$(D maxNodes) parameter limiting the number of freelist items. If $(D unbounded)
is passed for $(D maxNodes), then there is no limit and no checking for the
number of nodes.
*/
enum unbounded = size_t.max;

/**
The alignment that is guaranteed to accommodate any D object allocation on the
current platform.
*/
enum uint platformAlignment = std.algorithm.max(double.alignof, real.alignof);

/**
The default good size allocation is deduced as $(D n) rounded up to the
allocator's alignment.
*/
size_t goodAllocSize(A)(auto ref A a, size_t n)
{
    return n.roundUpToMultipleOf(a.alignment);
}

/**
The default $(D reallocate) function first attempts to use $(D expand). If $(D
Allocator.expand) is not defined or returns $(D false), $(D reallocate)
allocates a new block of memory of appropriate size and copies data from the old
block to the new block. Finally, if $(D Allocator) defines $(D deallocate), $(D
reallocate) uses it to free the old memory block.

$(D reallocate) does not attempt to use $(D Allocator.reallocate) even if
defined. This is deliberate so allocators may use it internally within their own
implementation of $(D reallocate).

*/
bool reallocate(Allocator)(ref Allocator a, ref void[] b, size_t s)
{
    if (b.length == s) return true;
    static if (hasMember!(Allocator, "expand"))
    {
        if (b.length <= s && a.expand(b, s - b.length)) return true;
    }
    auto newB = a.allocate(s);
    if (newB.length <= b.length) newB[] = b[0 .. newB.length];
    else newB[0 .. b.length] = b[];
    static if (hasMember!(Allocator, "deallocate"))
        a.deallocate(b);
    b = newB;
    return true;
}

/**

The default $(D alignedReallocate) function first attempts to use $(D expand).
If $(D Allocator.expand) is not defined or returns $(D false),  $(D
alignedReallocate) allocates a new block of memory of appropriate size and
copies data from the old block to the new block. Finally, if $(D Allocator)
defines $(D deallocate), $(D alignedReallocate) uses it to free the old memory
block.

$(D alignedReallocate) does not attempt to use $(D Allocator.reallocate) even if
defined. This is deliberate so allocators may use it internally within their own
implementation of $(D reallocate).

*/
bool alignedReallocate(Allocator)(ref Allocator alloc,
        ref void[] b, size_t s, uint a)
{
    static if (hasMember!(Allocator, "expand"))
    {
        if (b.length <= s && b.ptr.alignedAt(a)
            && alloc.expand(b, s - b.length)) return true;
    }
    else
    {
        if (b.length == s) return true;
    }
    auto newB = alloc.alignedAllocate(s, a);
    if (newB.length <= b.length) newB[] = b[0 .. newB.length];
    else newB[0 .. b.length] = b[];
    static if (hasMember!(Allocator, "deallocate"))
        alloc.deallocate(b);
    b = newB;
    return true;
}

/*
  _   _       _ _          _ _                 _
 | \ | |     | | |   /\   | | |               | |
 |  \| |_   _| | |  /  \  | | | ___   ___ __ _| |_ ___  _ __
 | . ` | | | | | | / /\ \ | | |/ _ \ / __/ _` | __/ _ \| '__|
 | |\  | |_| | | |/ ____ \| | | (_) | (_| (_| | || (_) | |
 |_| \_|\__,_|_|_/_/    \_\_|_|\___/ \___\__,_|\__\___/|_|
*/
/**
$(D NullAllocator) is an emphatically empty implementation of the allocator interface. Although it has no direct use, it is useful as a "terminator" in composite allocators.
*/
struct NullAllocator
{
    /**
    $(D NullAllocator) advertises a relatively large _alignment equal to 64 KB.
    This is because $(D NullAllocator) never actually needs to honor this
    alignment and because composite allocators using $(D NullAllocator)
    shouldn't be unnecessarily constrained.
    */
    enum uint alignment = 64 * 1024;
    /// Always returns $(D null).
    void[] allocate(size_t) shared { return null; }
    /// Always returns $(D null).
    void[] alignedAllocate(size_t, uint) shared { return null; }
    /// Always returns $(D null).
    void[] allocateAll() shared { return null; }
    /**
    These methods return $(D false).
    Precondition: $(D b is null). This is because there is no other possible
    legitimate input.
    */
    bool expand(ref void[] b, size_t) shared
    { assert(b is null); return false; }
    /// Ditto
    bool reallocate(ref void[] b, size_t) shared
    { assert(b is null); return false; }
    /// Ditto
    bool alignedReallocate(ref void[] b, size_t, uint) shared
    { assert(b is null); return false; }
    /// Returns $(D b is null).
    bool owns(void[] b) shared { return false; }
    /**
    Returns $(D null).
    */
    void[] resolveInternalPointer(void*) shared { return null; }
    /**
    No-op.
    Precondition: $(D b is null)
    */
    void deallocate(void[] b) shared { assert(b is null); }
    /**
    No-op.
    */
    void deallocateAll() shared { }
    /**
    Returns $(D true).
    */
    bool empty() shared { return true; }
    /**
    Returns the $(D shared) global instance of the $(D NullAllocator).
    */
    static shared NullAllocator it;
    /// No-op
    void markAllAsUnused() shared {}
    /// Returns $(D false).
    bool markAsUsed(void[]) shared { return false; }
    /// No-op
    void doneMarking() shared {}
}

unittest
{
    auto b = NullAllocator.it.allocate(100);
    assert(b is null);
    NullAllocator.it.deallocate(b);
    NullAllocator.it.deallocateAll();
    assert(!NullAllocator.it.owns(null));
}

/**
D's built-in garbage-collected allocator.
 */
struct GCAllocator
{
    unittest { testAllocator!(() => GCAllocator.it); }
    private import core.memory;

    /**
    The alignment is a static constant equal to $(D platformAlignment), which
    ensures proper alignment for any D data type.
    */
    enum uint alignment = platformAlignment;

    /**
    Standard allocator methods per the semantics defined above. The $(D deallocate) and $(D reallocate) methods are $(D @system) because they may move memory around, leaving dangling pointers in user code.
    */
    @trusted void[] allocate(size_t bytes) shared
    {
        auto p = GC.malloc(bytes);
        return p ? p[0 .. bytes] : null;
    }

    /// Ditto
    @trusted bool expand(ref void[] b, size_t delta) shared
    {
        if (delta == 0) return true;
        if (b is null)
        {
            b = allocate(delta);
            return b !is null;
        }
        auto newSize = GC.extend(b.ptr, b.length + delta,
            b.length + delta);
        if (newSize == 0)
        {
            // expansion unsuccessful
            return false;
        }
        assert(newSize >= b.length + delta);
        b = b.ptr[0 .. newSize];
        return true;
    }

    /// Ditto
    @system bool reallocate(ref void[] b, size_t newSize) shared
    {
        import core.exception : OutOfMemoryError;
        try
        {
            auto p = cast(ubyte*) GC.realloc(b.ptr, newSize);
            b = p[0 .. newSize];
        }
        catch (OutOfMemoryError)
        {
            // leave the block in place, tell caller
            return false;
        }
        return true;
    }

    /// Ditto
    void[] resolveInternalPointer(void* p) shared
    {
        auto r = GC.addrOf(p);
        if (!r) return null;
        return r[0 .. GC.sizeOf(r)];
    }

    /// Ditto
    @system void deallocate(void[] b) shared
    {
        GC.free(b.ptr);
    }

    /**
    Returns the global instance of this allocator type. The garbage collected allocator is thread-safe, therefore all of its methods and $(D it) itself are $(D shared).
    */
    static shared GCAllocator it;

    // Leave it undocummented for now.
    @trusted void collect() shared
    {
        GC.collect();
    }
}

///
unittest
{
    auto buffer = GCAllocator.it.allocate(1024 * 1024 * 4);
    scope(exit) GCAllocator.it.deallocate(buffer); // or leave it to collection
    //...
}

unittest
{
    auto b = GCAllocator.it.allocate(10000);
    assert(GCAllocator.it.expand(b, 1));
}

/**
   The C heap allocator.
 */
struct Mallocator
{
    unittest { testAllocator!(() => Mallocator.it); }
    private import core.stdc.stdlib;

    /**
    The alignment is a static constant equal to $(D platformAlignment), which ensures proper alignment for any D data type.
    */
    enum uint alignment = platformAlignment;

    /**
    Standard allocator methods per the semantics defined above. The $(D deallocate) and $(D reallocate) methods are $(D @system) because they may move memory around, leaving dangling pointers in user code. Somewhat paradoxically, $(D malloc) is $(D @safe) but that's only useful to safe programs that can afford to leak memory allocated.
    */
    @trusted void[] allocate(size_t bytes) shared
    {
        auto p = malloc(bytes);
        return p ? p[0 .. bytes] : null;
    }

    /// Ditto
    @system void deallocate(void[] b) shared
    {
        free(b.ptr);
    }

    /// Ditto
    @system bool reallocate(ref void[] b, size_t s) shared
    {
        if (!s)
        {
            // fuzzy area in the C standard, see http://goo.gl/ZpWeSE
            // so just deallocate and nullify the pointer
            deallocate(b);
            b = null;
            return true;
        }
        auto p = cast(ubyte*) realloc(b.ptr, s);
        if (!p) return false;
        b = p[0 .. s];
        return true;
    }

    /**
    Returns the global instance of this allocator type. The C heap allocator is thread-safe, therefore all of its methods and $(D it) itself are $(D shared).
    */
    static shared Mallocator it;
}

///
unittest
{
    auto buffer = Mallocator.it.allocate(1024 * 1024 * 4);
    scope(exit) Mallocator.it.deallocate(buffer);
    //...
}

unittest
{
    static void test(A)()
    {
        int* p = null;
        p = new int;
        *p = 42;
        assert(*p == 42);
    }

    test!GCAllocator();
    test!Mallocator();
}

unittest
{
    static void test(A)()
    {
        Object p = null;
        p = new Object;
        assert(p !is null);
    }

    test!GCAllocator();
    test!Mallocator();
}

version (Posix) extern(C) int posix_memalign(void**, size_t, size_t);
version (Windows)
{
    extern(C) void* _aligned_malloc(size_t, size_t);
    extern(C) void _aligned_free(void *memblock);
    extern(C) void* _aligned_realloc(void *, size_t, size_t);
}

/**
   Aligned allocator using OS-specific primitives, under a uniform API.
 */
struct AlignedMallocator
{
    unittest { testAllocator!(() => typeof(this).it); }

    private import core.stdc.stdlib;

    /**
    The default alignment is $(D platformAlignment).
    */
    enum uint alignment = platformAlignment;

    /**
    Forwards to $(D alignedAllocate(bytes, platformAlignment)).
    */
    @trusted void[] allocate(size_t bytes) shared
    {
        return alignedAllocate(bytes, alignment);
    }

    version (Posix) import core.stdc.errno, core.sys.posix.stdlib;

    /**
    Uses $(WEB man7.org/linux/man-pages/man3/posix_memalign.3.html,
    $(D posix_memalign)) on Posix and
    $(WEB msdn.microsoft.com/en-us/library/8z34s9c6(v=vs.80).aspx,
    $(D __aligned_malloc)) on Windows.
    */
    version(Posix) @trusted
    void[] alignedAllocate(size_t bytes, uint a) shared
    {
        assert(a.isGoodDynamicAlignment);
        void* result;
        auto code = posix_memalign(&result, a, bytes);
        if (code == ENOMEM) return null;
        enforce(code == 0, text("Invalid alignment requested: ", a));
        return result[0 .. bytes];
    }
    else version(Windows) @trusted
    void[] alignedAllocate(size_t bytes, uint a) shared
    {
        auto result = _aligned_malloc(bytes, a);
        return result ? result[0 .. bytes] : null;
    }
    else static assert(0);

    /**
    Calls $(D free(b.ptr)) on Posix and
    $(WEB msdn.microsoft.com/en-US/library/17b5h8td(v=vs.80).aspx,
    $(D __aligned_free(b.ptr))) on Windows.
    */
    version (Posix) @system
    void deallocate(void[] b) shared
    {
        free(b.ptr);
    }
    else version (Windows) @system
    void deallocate(void[] b) shared
    {
        _aligned_free(b.ptr);
    }
    else static assert(0);

    /**
    On Posix, forwards to $(D realloc). On Windows, forwards to
    $(D alignedReallocate(b, newSize, platformAlignment)).
    */
    version (Posix) @system bool reallocate(ref void[] b, size_t newSize) shared
    {
        return Mallocator.it.reallocate(b, newSize);
    }
    version (Windows) @system
    bool reallocate(ref void[] b, size_t newSize) shared
    {
        return alignedReallocate(b, newSize, alignment);
    }

    /**
    On Posix, uses $(D alignedAllocate) and copies data around because there is
    no realloc for aligned memory. On Windows, calls
    $(WEB msdn.microsoft.com/en-US/library/y69db7sx(v=vs.80).aspx,
    $(D __aligned_realloc(b.ptr, newSize, a))).
    */
    version (Windows) @system
    bool alignedReallocate(ref void[] b, size_t s, uint a) shared
    {
        if (!s)
        {
            deallocate(b);
            b = null;
            return true;
        }
        auto p = cast(ubyte*) _aligned_realloc(b.ptr, s, a);
        if (!p) return false;
        b = p[0 .. s];
        return true;
    }

    /**
    Returns the global instance of this allocator type. The C heap allocator is thread-safe, therefore all of its methods and $(D it) itself are $(D shared).
    */
    static shared AlignedMallocator it;
}

///
unittest
{
    auto buffer = AlignedMallocator.it.alignedAllocate(1024 * 1024 * 4, 128);
    scope(exit) AlignedMallocator.it.deallocate(buffer);
    //...
}

/**
Returns s rounded up to a multiple of base.
*/
private size_t roundUpToMultipleOf(size_t s, uint base)
{
    assert(base);
    auto rem = s % base;
    return rem ? s + base - rem : s;
}

unittest
{
    assert(10.roundUpToMultipleOf(11) == 11);
    assert(11.roundUpToMultipleOf(11) == 11);
    assert(12.roundUpToMultipleOf(11) == 22);
    assert(118.roundUpToMultipleOf(11) == 121);
}

private size_t divideRoundUp(size_t a, size_t b)
{
    assert(b);
    return (a + b - 1) / b;
}

/**
Returns s rounded up to a multiple of base.
*/
private void[] roundStartToMultipleOf(void[] s, uint base)
{
    assert(base);
    auto p = cast(void*) roundUpToMultipleOf(
        cast(size_t) s.ptr, base);
    auto end = s.ptr + s.length;
    return p[0 .. end - p];
}

unittest
{
    void[] p;
    assert(roundStartToMultipleOf(p, 16) is null);
    p = new ulong[10];
    assert(roundStartToMultipleOf(p, 16) is p);
}

/**
Returns $(D s) rounded up to the nearest power of 2.
*/
private size_t roundUpToPowerOf2(size_t s)
{
    assert(s <= (size_t.max >> 1) + 1);
    --s;
    static if (size_t.sizeof == 4)
        alias Shifts = TypeTuple!(1, 2, 4, 8, 16);
    else
        alias Shifts = TypeTuple!(1, 2, 4, 8, 16, 32);
    foreach (i; Shifts)
    {
        s |= s >> i;
    }
    return s + 1;
}

unittest
{
    assert(0.roundUpToPowerOf2 == 0);
    assert(1.roundUpToPowerOf2 == 1);
    assert(2.roundUpToPowerOf2 == 2);
    assert(3.roundUpToPowerOf2 == 4);
    assert(7.roundUpToPowerOf2 == 8);
    assert(8.roundUpToPowerOf2 == 8);
    assert(10.roundUpToPowerOf2 == 16);
    assert(11.roundUpToPowerOf2 == 16);
    assert(12.roundUpToPowerOf2 == 16);
    assert(118.roundUpToPowerOf2 == 128);
    assert((size_t.max >> 1).roundUpToPowerOf2 == (size_t.max >> 1) + 1);
    assert(((size_t.max >> 1) + 1).roundUpToPowerOf2 == (size_t.max >> 1) + 1);
}

/*
*/
bool alignedAt(void* ptr, uint alignment)
{
    return cast(size_t) ptr % alignment == 0;
}

/*
*/
void* alignDownTo(void* ptr, uint alignment)
{
    assert(alignment.isPowerOf2);
    return cast(void*) (cast(size_t) ptr & ~(alignment - 1UL));
}

/**

Allocator that adds some extra data before (of type $(D Prefix)) and/or after
(of type $(D Suffix)) any allocation made with its parent allocator. This is
useful for uses where additional allocation-related information is needed, such
as mutexes, reference counts, or walls for debugging memory corruption errors.

If $(D Prefix) is not $(D void), $(D Allocator) must guarantee an alignment at
least as large as $(D Prefix.alignof).

Suffixes are slower to get at because of alignment rounding, so prefixes should
be preferred. However, small prefixes blunt the alignment so if a large
alignment with a small affix is needed, suffixes should be chosen.

 */
struct AffixAllocator(Allocator, Prefix, Suffix = void)
{
    static assert(
        !stateSize!Prefix || Allocator.alignment >= Prefix.alignof,
        "AffixAllocator does not work with allocators offering a smaller"
        ~ " alignment than the prefix alignment.");
    static assert(alignment % Suffix.alignof == 0,
        "This restriction could be relaxed in the future.");

    /**
    If $(D Prefix) is $(D void), the alignment is that of the parent. Otherwise, the alignment is the same as the $(D Prefix)'s alignment.
    */
    enum uint alignment =
        stateSize!Prefix ? Prefix.alignof : Allocator.alignment;

    /**
    If the parent allocator $(D Allocator) is stateful, an instance of it is
    stored as a member. Otherwise, $(D AffixAllocator) uses $(D Allocator.it).
    In either case, the name $(D _parent) is uniformly used for accessing the
    parent allocator.
    */
    static if (stateSize!Allocator) Allocator parent;
    else alias parent = Allocator.it;

    template Impl()
    {
        size_t goodAllocSize(size_t s)
        {
            return parent.goodAllocSize(actualAllocationSize(s));
        }

        private size_t actualAllocationSize(size_t s) const
        {
            static if (!stateSize!Suffix)
            {
                return s + stateSize!Prefix;
            }
            else
            {
                return
                    roundUpToMultipleOf(s + stateSize!Prefix, Suffix.alignof)
                    + stateSize!Suffix;
            }
        }

        private void[] actualAllocation(void[] b) const
        {
            assert(b !is null);
            return (b.ptr - stateSize!Prefix)
                [0 .. actualAllocationSize(b.length)];
        }

        void[] allocate(size_t bytes)
        {
            auto result = parent.allocate(actualAllocationSize(bytes));
            if (result is null) return null;
            static if (stateSize!Prefix)
                emplace!Prefix(cast(Prefix*)result.ptr);
            static if (stateSize!Suffix)
                emplace!Suffix(
                    cast(Suffix*)(result.ptr + result.length - Suffix.sizeof));
            return result[stateSize!Prefix .. stateSize!Prefix + bytes];
        }

        static if (hasMember!(Allocator, "allocateAll"))
        void[] allocateAll()
        {
            auto result = parent.allocateAll();
            if (result is null) return null;
            static if (stateSize!Prefix)
            {
                assert(result.length > stateSize!Prefix);
                if (result.length <= stateSize!Prefix) return null;
                emplace!Prefix(cast(Prefix*)result.ptr);
                result = result[stateSize!Prefix .. $];
            }
            static if (stateSize!Suffix)
            {
                // Ehm, find a properly aligned place for the suffix
                auto p = (result.ptr + result.length - stateSize!Suffix)
                    .alignDownTo(Suffix.alignof);
                assert(p > result.ptr);
                if (p <= result.ptr) return null;
                emplace!Suffix(cast(Suffix*) p);
                result = result[0 .. p - result.ptr];
            }
            return result;
        }

        static if (hasMember!(Allocator, "owns"))
        bool owns(void[] b)
        {
            return b !is null && parent.owns(actualAllocation(b));
        }

        static if (hasMember!(Allocator, "resolveInternalPointer"))
        void[] resolveInternalPointer(void* p)
        {
            auto p1 = parent.resolveInternalPointer(p);
            if (p1 is null) return p1;
            p1 = p1[stateSize!Prefix .. $];
            auto p2 = (p1.ptr + p1.length - stateSize!Suffix)
                    .alignDownTo(Suffix.alignof);
            return p1[0 .. p2 - p1.ptr];
        }

        static if (!stateSize!Suffix && hasMember!(Allocator, "expand"))
        bool expand(ref void[] b, size_t delta)
        {
            auto t = actualAllocation(b);
            auto result = parent.expand(t, delta);
            if (!result) return false;
            b = b.ptr[0 .. b.length + delta];
            return true;
        }

        static if (hasMember!(Allocator, "reallocate"))
        bool reallocate(ref void[] b, size_t s)
        {
            if (b is null)
            {
                b = allocate(s);
                return b !is null || s == 0;
            }
            auto t = actualAllocation(b);
            auto result = parent.reallocate(t, actualAllocationSize(s));
            if (!result) return false; // no harm done
            b = t.ptr[stateSize!Prefix .. stateSize!Prefix + s];
            return true;
        }

        static if (hasMember!(Allocator, "deallocate"))
        void deallocate(void[] b)
        {
            auto p = b.ptr - stateSize!Prefix;
            parent.deallocate(p[0 .. actualAllocationSize(b.length)]);
        }

        static if (hasMember!(Allocator, "deallocateAll"))
        void deallocateAll()
        {
            parent.deallocateAll();
        }

        static if (hasMember!(Allocator, "empty"))
        bool empty()
        {
            return parent.empty;
        }

        static if (hasMember!(Allocator, "zeroesAllocations"))
        alias zeroesAllocations = Allocator.zeroesAllocations;

        // Extra functions
        static if (stateSize!Prefix)
            static ref Prefix prefix(void[] b)
            {
                return (cast(Prefix*)b.ptr)[-1];
            }
        static if (stateSize!Suffix)
            ref Suffix suffix(void[] b)
            {
                auto p = b.ptr - stateSize!Prefix
                    + actualAllocationSize(b.length);
                return (cast(Suffix*) p)[-1];
            }

        //
        static if (hasMember!(Allocator, "markAllAsUnused"))
        {
            void markAllAsUnused() { parent.markAllAsUnused(); }
            //
            bool markAsUsed(void[] b)
            {
                assert(b);
                return parent.markAsUsed(actualAllocation(b));
            }
            //
            void doneMarking() { parent.doneMarking(); }
        }
    }

    version (StdDdoc)
    {
        /**
        Standard allocator methods. Each is defined if and only if the parent
        allocator defines the homonym method (except for $(D goodAllocSize),
        which may use the global default). Also, the methods will be $(D
        shared) if the parent allocator defines them as such.
        */
        size_t goodAllocSize(size_t);
        /// Ditto
        void[] allocate(size_t);
        /// Ditto
        bool owns(void[]);
        /// Ditto
        bool expand(ref void[] b, size_t delta);
        /// Ditto
        bool reallocate(ref void[] b, size_t s);
        /// Ditto
        void deallocate(void[] b);
        /// Ditto
        void deallocateAll();
        /// Ditto
        bool empty();
        /// Ditto
        enum bool zeroesAllocations = false;
        /// Ditto
        void markAllAsUnused();
        /// Ditto
        bool markAsUsed(void[] b);
        /// Ditto
        void doneMarking();

        /**
        The $(D it) singleton is defined if and only if the parent allocator has no state and defines its own $(D it) object.
        */
        static AffixAllocator it;

        /**
        Affix access functions offering mutable references to the affixes of a block previously allocated with this allocator. $(D b) may not be null. They are defined if and only if the corresponding affix is not $(D void).

        Precondition: $(D b !is null)
        */
        static ref Prefix prefix(void[] b);
        /// Ditto
        static ref Suffix suffix(void[] b);
    }
    else static if (is(typeof(Allocator.it) == shared))
    {
        static shared AffixAllocator it;
        shared { mixin Impl!(); }
    }
    else
    {
        mixin Impl!();
        static if (stateSize!Allocator == 0)
            static __gshared AffixAllocator it;
    }
}

///
unittest
{
    // One word before and after each allocation.
    alias A = AffixAllocator!(Mallocator, size_t, size_t);
    auto b = A.it.allocate(11);
    A.it.prefix(b) = 0xCAFE_BABE;
    A.it.suffix(b) = 0xDEAD_BEEF;
    assert(A.it.prefix(b) == 0xCAFE_BABE && A.it.suffix(b) == 0xDEAD_BEEF);
}

unittest
{
    testAllocator!(() => AffixAllocator!(Mallocator, size_t, size_t).it);
    testAllocator!({
        auto hb = HeapBlock!128(new void[128 * 4096]);
        AffixAllocator!(HeapBlock!128, size_t, size_t) a;
        a.parent = hb;
        return a;
    });
}

unittest
{
    alias A = AffixAllocator!(Mallocator, size_t);
    auto b = A.it.allocate(10);
    A.it.prefix(b) = 10;
    assert(A.it.prefix(b) == 10);

    alias B = AffixAllocator!(NullAllocator, size_t);
    b = B.it.allocate(100);
    assert(b is null);
}

/**
Returns the number of most significant ones before a zero can be found in $(D x). If $(D x) contains no zeros (i.e. is equal to $(D ulong.max)), returns 64.
*/
private uint leadingOnes(ulong x)
{
    uint result = 0;
    while (cast(long) x < 0)
    {
        ++result;
        x <<= 1;
    }
    return result;
}

unittest
{
    assert(leadingOnes(0) == 0);
    assert(leadingOnes(~0UL) == 64);
    assert(leadingOnes(0xF000_0000_0000_0000) == 4);
    assert(leadingOnes(0xE400_0000_0000_0000) == 3);
    assert(leadingOnes(0xC700_0200_0000_0000) == 2);
    assert(leadingOnes(0x8000_0030_0000_0000) == 1);
    assert(leadingOnes(0x2000_0000_0000_0000) == 0);
}

/**
Finds a run of contiguous ones in $(D x) of length at least $(D n).
*/
private uint findContigOnes(ulong x, uint n)
{
    while (n > 1)
    {
        immutable s = n >> 1;
        x &= x << s;
        n -= s;
    }
    return leadingOnes(~x);
}

unittest
{
    assert(findContigOnes(0x0000_0000_0000_0300, 2) == 54);

    assert(findContigOnes(~0UL, 1) == 0);
    assert(findContigOnes(~0UL, 2) == 0);
    assert(findContigOnes(~0UL, 32) == 0);
    assert(findContigOnes(~0UL, 64) == 0);
    assert(findContigOnes(0UL, 1) == 64);

    assert(findContigOnes(0x4000_0000_0000_0000, 1) == 1);
    assert(findContigOnes(0x0000_0F00_0000_0000, 4) == 20);
}

/**
Returns the number of trailing zeros of $(D x).
*/
private uint trailingZeros(ulong x)
{
    uint result;
    while (result < 64 && !(x & (1UL << result)))
    {
        ++result;
    }
    return result;
}

unittest
{
    assert(trailingZeros(0) == 64);
    assert(trailingZeros(1) == 0);
    assert(trailingZeros(2) == 1);
    assert(trailingZeros(3) == 0);
    assert(trailingZeros(4) == 2);
}

/*
Unconditionally sets the bits from lsb through msb in w to zero.
*/
private void setBits(ref ulong w, uint lsb, uint msb)
{
    assert(lsb <= msb && msb < 64);
    const mask = (ulong.max << lsb) & (ulong.max >> (63 - msb));
    w |= mask;
}

unittest
{
    ulong w;
    w = 0; setBits(w, 0, 63); assert(w == ulong.max);
    w = 0; setBits(w, 1, 63); assert(w == ulong.max - 1);
    w = 6; setBits(w, 0, 1); assert(w == 7);
    w = 6; setBits(w, 3, 3); assert(w == 14);
}

/* Are bits from lsb through msb in w zero? If so, make then 1
and return the resulting w. Otherwise, just return 0.
*/
private bool setBitsIfZero(ref ulong w, uint lsb, uint msb)
{
    assert(lsb <= msb && msb < 64);
    const mask = (ulong.max << lsb) & (ulong.max >> (63 - msb));
    if (w & mask) return false;
    w |= mask;
    return true;
}

// Assigns bits in w from lsb through msb to zero.
private void resetBits(ref ulong w, uint lsb, uint msb)
{
    assert(lsb <= msb && msb < 64);
    const mask = (ulong.max << lsb) & (ulong.max >> (63 - msb));
    w &= ~mask;
}

/*
Bit disposition is MSB=0 (leftmost, big endian).
*/
private struct BitVector
{
    ulong[] _rep;

    auto rep() { return _rep; }

    this(ulong[] data) { _rep = data; }

    void opSliceAssign(bool b) { _rep[] = b ? ulong.max : 0; }

    void opSliceAssign(bool b, ulong x, ulong y)
    {
        assert(x <= y && y <= _rep.length * 64);
        if (x == y) return;
        --y;
        immutable size_t i1 = x / 64;
        immutable uint b1 = 63 - x % 64;
        immutable size_t i2 = y / 64;
        immutable uint b2 = 63 - y % 64;
        assert(i1 <= i2 && i2 < _rep.length);
        if (i1 == i2)
        {
            // Inside the same word
            assert(b1 >= b2);
            if (b) setBits(_rep[i1], b2, b1);
            else resetBits(_rep[i1], b2, b1);
        }
        else
        {
            // Spans multiple words
            assert(i1 < i2);
            if (b) setBits(_rep[i1], 0, b1);
            else resetBits(_rep[i1], 0, b1);
            _rep[i1 + 1 .. i2] = b;
            if (b) setBits(_rep[i2], b2, 63);
            else resetBits(_rep[i2], b2, 63);
        }
    }

    bool opIndex(ulong x)
    {
        assert(x < length);
        return (_rep[x / 64] & (0x8000_0000_0000_0000UL >> (x % 64))) != 0;
    }

    void opIndexAssign(bool b, ulong x)
    {
        auto i = x / 64, j = 0x8000_0000_0000_0000UL >> (x % 64);
        if (b) _rep[i] |= j;
        else _rep[i] &= ~j;
    }

    ulong length() const
    {
        return _rep.length * 64;
    }

    /* Returns the index of the first 1 to the right of i (including i itself),
    or length if not found.
    */
    ulong find1(ulong i)
    {
        assert(i < length);
        auto w = i / 64;
        auto b = i % 64; // 0 through 63, 0 when i == 0
        auto mask = ulong.max >> b;
        if (auto current = _rep[w] & mask)
        {
            // Great, found
            return w * 64 + leadingOnes(~current);
        }
        // The current word doesn't have the solution, find the leftmost 1
        // going to the right.
        for (++w; w < _rep.length; ++w)
        {
            if (auto current = _rep[w])
            {
                return w * 64 + leadingOnes(~current);
            }
        }
        return length;
    }

    /* Returns the index of the first 1 to the left of i (including i itself),
    or ulong.max if not found.
    */
    ulong find1Backward(ulong i)
    {
        assert(i < length);
        auto w = i / 64;
        auto b = 63 - (i % 64); // 0 through 63, 63 when i == 0
        auto mask = ~((1UL << b) - 1);
        assert(mask != 0);
        // First, let's see if the current word has a bit larger than ours.
        if (auto currentWord = _rep[w] & mask)
        {
            // Great, this word contains the result.
            return w * 64 + 63 - currentWord.trailingZeros;
        }
        // The current word doesn't have the solution, find the rightmost 1
        // going to the left.
        while (w >= 1)
        {
            --w;
            if (auto currentWord = _rep[w])
                return w * 64 + (63 - currentWord.trailingZeros);
        }
        return ulong.max;
    }

    /// Are all bits zero?
    bool allAre0() const
    {
        foreach (w; _rep) if (w) return false;
        return true;
    }

    /// Are all bits one?
    bool allAre1() const
    {
        foreach (w; _rep) if (w != ulong.max) return false;
        return true;
    }

    ulong findZeros(immutable size_t howMany, ulong start)
    {
        assert(start < length);
        assert(howMany > 64);
        auto i = start / 64;
        while (_rep[i] & 1)
        {
            // No trailing zeros in this word, try the next one
            if (++i == _rep.length) return ulong.max;
            start = i * 64;
        }
        // Adjust start to have only trailing zeros after it
        auto prefixLength = 64;
        while (_rep[i] & (ulong.max >> (64 - prefixLength)))
        {
            assert(prefixLength > 0);
            --prefixLength;
            ++start;
        }

        assert(howMany > prefixLength, text(prefixLength));
        auto needed = howMany - prefixLength;
        for (++i; needed >= 64; needed -= 64, ++i)
        {
            if (i >= _rep.length) return ulong.max;
            if (_rep[i] != 0) return findZeros(howMany, i * 64);
        }
        // Leftover < 64 bits
        assert(needed < 64);
        if (!needed) return start;
        if (i >= _rep.length) return ulong.max;
        if (leadingOnes(~_rep[i]) >= needed) return start;
        return findZeros(howMany, i * 64);
    }
}

unittest
{
    auto v = BitVector(new ulong[10]);
    assert(v.length == 640);

    v[] = 0;
    v[53] = 1;
    assert(v[52] == 0);
    assert(v[53] == 1);
    assert(v[54] == 0);

    v[] = 0;
    v[53 .. 55] = 1;
    assert(v[52] == 0);
    assert(v[53] == 1);
    assert(v[54] == 1);
    assert(v[55] == 0);

    v[] = 0;
    v[2 .. 65] = 1;
    assert(v.rep[0] == 0x3FFF_FFFF_FFFF_FFFF);
    assert(v.rep[1] == 0x8000_0000_0000_0000);
    assert(v.rep[2] == 0);

    v[] = 0;
    assert(v.find1Backward(0) == ulong.max);
    assert(v.find1Backward(43) == ulong.max);
    assert(v.find1Backward(83) == ulong.max);

    v[0] = 1;
    assert(v.find1Backward(0) == 0);
    assert(v.find1Backward(43) == 0);
    assert(v.find1Backward(83) == 0, text(v.find1Backward(83)));

    v[0] = 0;
    v[101] = 1;
    assert(v.find1Backward(0) == ulong.max);
    assert(v.find1Backward(43) == ulong.max);
    assert(v.find1Backward(83) == ulong.max);
    assert(v.find1Backward(100) == ulong.max);
    assert(v.find1Backward(101) == 101);
    assert(v.find1Backward(553) == 101);

    v[0 .. v.length] = 0;
    v[v.length .. v.length] = 0;
    v[0 .. 0] = 0;

    v[] = 0;
    assert(v.find1(0) == v.length);
    v[139] = 1;
    assert(v.find1(0) == 139);
    assert(v.find1(100) == 139);
    assert(v.find1(138) == 139);
    assert(v.find1(139) == 139);
    assert(v.find1(140) == v.length);

    v[] = 0;
    assert(v.findZeros(100, 0) == 0);
    foreach (i; 0 .. 500)
        assert(v.findZeros(100, i) == i, text(v.findZeros(100, i), " != ", i));
    assert(v.findZeros(540, 99) == 99);
    assert(v.findZeros(99, 540) == 540);
    assert(v.findZeros(540, 100) == 100);
    assert(v.findZeros(640, 0) == 0);
    assert(v.findZeros(641, 1) == ulong.max);
    assert(v.findZeros(641, 100) == ulong.max);
}

/**

$(D HeapBlock) implements a simple heap consisting of one contiguous area
of memory organized in blocks, each of size $(D theBlockSize). A block is a unit
of allocation. A bitmap serves as bookkeeping data, more precisely one bit per
block indicating whether that block is currently allocated or not.

There are advantages to storing bookkeeping data separated from the payload
(as opposed to e.g. $(D AffixAllocator)). The layout is more compact, searching
for a free block during allocation enjoys better cache locality, and
deallocation does not touch memory around the payload being deallocated (which
is often cold).

Allocation requests are handled on a first-fit basis. Although linear in
complexity, allocation is in practice fast because of the compact bookkeeping
representation, use of simple and fast bitwise routines, and memoization of the
first available block position. A known issue with this general approach is
fragmentation, partially mitigated by coalescing. Since $(D HeapBlock) does
not maintain the allocated size, freeing memory implicitly coalesces free blocks
together. Also, tuning $(D blockSize) has a considerable impact on both internal
and external fragmentation.

The size of each block can be selected either during compilation or at run
time. Statically-known block sizes are frequent in practice and yield slightly
better performance. To choose a block size statically, pass it as the $(D
blockSize) parameter as in $(D HeapBlock!(Allocator, 4096)). To choose a block
size parameter, use $(D HeapBlock!(Allocator, chooseAtRuntime)) and pass the
block size to the constructor.

TODO: implement $(D alignedAllocate) and $(D alignedReallocate).

*/
struct HeapBlock(size_t theBlockSize, uint theAlignment = platformAlignment)
{
    unittest
    {
        auto m = AlignedMallocator.it.alignedAllocate(1024 * 64, theAlignment);
        testAllocator!(() => HeapBlock(m));
    }
    static assert(theBlockSize > 0 && theAlignment.isGoodStaticAlignment);

    /**
    If $(D blockSize == chooseAtRuntime), $(D HeapBlock) offers a read/write
    property $(D blockSize). It must be set to a power of two before any use
    of the allocator. Otherwise, $(D blockSize) is an alias for $(D
    theBlockSize).
    */
    static if (theBlockSize != chooseAtRuntime)
    {
        alias blockSize = theBlockSize;
    }
    else
    {
        @property uint blockSize() { return _blockSize; }
        @property void blockSize(uint s)
        {
            assert(!_control && s % alignment == 0);
            _blockSize = s;
        }
        private uint _blockSize;
    }

    /**
    The alignment offered is user-configurable statically through parameter
    $(D theAlignment), defaulted to $(D platformAlignment).
    */
    alias alignment = theAlignment;

    private uint _blocks;
    private BitVector _control;
    private void[] _payload;
    private size_t _startIdx;

    /**
    Constructs a block allocator given a hunk of memory. The layout puts the
    bitmap at the front followed immediately by the payload.
    */
    this(void[] data)
    {
        assert(data.ptr.alignedAt(alignment), "Data must be aligned properly");

        immutable ulong totalBits = data.length * 8;
        immutable ulong bitsPerBlock = blockSize * 8 + 1;
        // Get a first estimate
        _blocks = to!uint(totalBits / bitsPerBlock);

        // Reality is a bit more complicated, iterate until a good number of
        // blocks found.
        for (; _blocks; --_blocks)
        {
            immutable size_t controlWords = (_blocks + 63) / 64;
            immutable controlBytesRounded =
                roundUpToMultipleOf(controlWords * 8, alignment);
            immutable payloadBytes = _blocks * blockSize;
            if (data.length >= controlBytesRounded + payloadBytes)
            {
                // Enough room, yay. Initialize everything.
                _control = BitVector((cast(ulong*)data.ptr)[0 .. controlWords]);
                _control[] = 0;
                _payload = data[controlBytesRounded .. $];
                assert(payloadBytes <= _payload.length);
                _payload = _payload[0 .. payloadBytes];
                break;
            }
        }
    }

    /*
    Adjusts the memoized _startIdx to the leftmost control word that has at
    least one zero bit. Assumes all control words to the left of $(D
    _control[_startIdx]) are already occupied.
    */
    private void adjustStartIdx()
    {
        while (_startIdx < _control.rep.length
            && _control.rep[_startIdx] == ulong.max)
        {
            ++_startIdx;
        }
    }

    /*
    Returns the blocks corresponding to the control bits starting at word index
    wordIdx and bit index msbIdx (MSB=0) for a total of howManyBlocks.
    */
    private void[] blocksFor(size_t wordIdx, uint msbIdx, size_t howManyBlocks)
    {
        assert(msbIdx <= 63);
        const start = (wordIdx * 64 + msbIdx) * blockSize;
        const end = start + blockSize * howManyBlocks;
        if (end <= _payload.length) return _payload[start .. end];
        // This could happen if we have more control bits than available memory.
        // That's possible because the control bits are rounded up to fit in
        // 64-bit words.
        return null;
    }

    /**
    Standard allocator methods per the semantics defined above. The $(D
    deallocate) and $(D reallocate) methods are $(D @system) because they may
    move memory around, leaving dangling pointers in user code.

    BUGS: Neither $(D deallocateAll) nor the destructor free the original memory
    block. Either user code or the parent allocator should carry that.
    */
    @trusted void[] allocate(const size_t s)
    {
        const blocks = s.divideRoundUp(blockSize);
        //writefln("Allocating %s blocks each of size %s", blocks, blockSize);
        void[] result = void;

    switcharoo:
        switch (blocks)
        {
        case 1:
            // inline code here for speed
            // find the next available block
            foreach (i; _startIdx .. _control.rep.length)
            {
                const w = _control.rep[i];
                if (w == ulong.max) continue;
                uint j = leadingOnes(w);
                assert(j < 64);
                assert((_control.rep[i] & ((1UL << 63) >> j)) == 0);
                _control.rep[i] |= (1UL << 63) >> j;
                if (i == _startIdx)
                {
                    adjustStartIdx();
                }
                result = blocksFor(i, j, 1);
                break switcharoo;
            }
            goto case 0; // fall through
        case 0:
            return null;
        case 2: .. case 63:
            result = smallAlloc(cast(uint) blocks);
            break;
        default:
            result = hugeAlloc(blocks);
            break;
        }
        return result ? result.ptr[0 .. s] : null;
    }

    /// Ditto
    void[] allocateAll()
    {
        if (!empty) return null;
        _control[] = 1;
        return _payload;
    }

    /// Ditto
    bool owns(void[] b) const
    {
        assert(b.ptr !is null || b.length == 0, "Corrupt block.");
        return b.ptr >= _payload.ptr
            && b.ptr + b.length <= _payload.ptr + _payload.length;
    }

    /*
    Tries to allocate "blocks" blocks at the exact position indicated by the
    position wordIdx/msbIdx (msbIdx counts from MSB, i.e. MSB has index 0). If
    it succeeds, fills "result" with the result and returns tuple(size_t.max,
    0). Otherwise, returns a tuple with the next position to search.
    */
    private Tuple!(size_t, uint) allocateAt(size_t wordIdx, uint msbIdx,
            size_t blocks, ref void[] result)
    {
        assert(blocks > 0);
        assert(wordIdx < _control.rep.length);
        assert(msbIdx <= 63);
        if (msbIdx + blocks <= 64)
        {
            // Allocation should fit this control word
            if (setBitsIfZero(_control.rep[wordIdx],
                    cast(uint) (64 - msbIdx - blocks), 63 - msbIdx))
            {
                // Success
                result = blocksFor(wordIdx, msbIdx, blocks);
                return tuple(size_t.max, 0u);
            }
            // Can't allocate, make a suggestion
            return msbIdx + blocks == 64
                ? tuple(wordIdx + 1, 0u)
                : tuple(wordIdx, cast(uint) (msbIdx + blocks));
        }
        // Allocation spans two control words or more
        auto mask = ulong.max >> msbIdx;
        if (_control.rep[wordIdx] & mask)
        {
            // We can't allocate the rest of this control word,
            // return a suggestion.
            return tuple(wordIdx + 1, 0u);
        }
        // We can allocate the rest of this control word, but we first need to
        // make sure we can allocate the tail.
        if (wordIdx + 1 == _control.rep.length)
        {
            // No more memory
            return tuple(_control.rep.length, 0u);
        }
        auto hint = allocateAt(wordIdx + 1, 0, blocks - 64 + msbIdx, result);
        if (hint[0] == size_t.max)
        {
            // We did it!
            _control.rep[wordIdx] |= mask;
            result = blocksFor(wordIdx, msbIdx, blocks);
            return tuple(size_t.max, 0u);
        }
        // Failed, return a suggestion that skips this whole run.
        return hint;
    }

    /* Allocates as many blocks as possible at the end of the blocks indicated
    by wordIdx. Returns the number of blocks allocated. */
    private uint allocateAtTail(size_t wordIdx)
    {
        assert(wordIdx < _control.rep.length);
        const available = trailingZeros(_control.rep[wordIdx]);
        _control.rep[wordIdx] |= ulong.max >> available;
        return available;
    }

    private void[] smallAlloc(uint blocks)
    {
        assert(blocks >= 2 && blocks <= 64, text(blocks));
        foreach (i; _startIdx .. _control.rep.length)
        {
            // Test within the current 64-bit word
            const v = _control.rep[i];
            if (v == ulong.max) continue;
            auto j = findContigOnes(~v, blocks);
            if (j < 64)
            {
                // yay, found stuff
                setBits(_control.rep[i], 64 - j - blocks, 63 - j);
                return blocksFor(i, j, blocks);
            }
            // Next, try allocations that cross a word
            auto available = trailingZeros(v);
            if (available == 0) continue;
            if (i + 1 >= _control.rep.length) break;
            assert(available < blocks); // otherwise we should have found it
            auto needed = blocks - available;
            assert(needed > 0 && needed < 64);
            if (allocateAtFront(i + 1, needed))
            {
                // yay, found a block crossing two words
                _control.rep[i] |= (1UL << available) - 1;
                return blocksFor(i, 64 - available, blocks);
            }
        }
        return null;
    }

    private void[] hugeAlloc(size_t blocks)
    {
        assert(blocks > 64);
        if (_startIdx == _control._rep.length)
        {
            assert(_control.allAre1);
            return null;
        }
        auto i = _control.findZeros(blocks, _startIdx * 64);
        if (i == ulong.max) return null;
        // Allocate those bits
        _control[i .. i + blocks] = 1;
        return _payload[i * blockSize .. (i + blocks) * blockSize];
        //void[] result;
        //auto pos = tuple(_startIdx, 0);
        //for (;;)
        //{
        //    if (pos[0] >= _control.rep.length)
        //    {
        //        // No more memory
        //        return null;
        //    }
        //    pos = allocateAt(pos[0], pos[1], blocks, result);
        //    if (pos[0] == size_t.max)
        //    {
        //        // Found and allocated
        //        return result;
        //    }
        //}
    }

    // Rounds sizeInBytes to a multiple of blockSize.
    private size_t bytes2blocks(size_t sizeInBytes)
    {
        return (sizeInBytes + blockSize - 1) / blockSize;
    }

    /* Allocates given blocks at the beginning blocks indicated by wordIdx.
    Returns true if allocation was possible, false otherwise. */
    private bool allocateAtFront(size_t wordIdx, uint blocks)
    {
        assert(wordIdx < _control.rep.length && blocks >= 1 && blocks <= 64);
        const mask = (1UL << (64 - blocks)) - 1;
        if (_control.rep[wordIdx] > mask) return false;
        // yay, works
        _control.rep[wordIdx] |= ~mask;
        return true;
    }

    /// Ditto
    @trusted bool expand(ref void[] b, immutable size_t delta)
    {
        if (delta == 0) return true;
        if (b is null)
        {
            b = allocate(delta);
            return b !is null;
        }

        const blocksOld = bytes2blocks(b.length);
        const blocksNew = bytes2blocks(b.length + delta);
        assert(blocksOld <= blocksNew);

        // Possibly we have enough slack at the end of the block!
        if (blocksOld == blocksNew)
        {
            b = b.ptr[0 .. b.length + delta];
            return true;
        }

        assert((b.ptr - _payload.ptr) % blockSize == 0);
        const blockIdx = (b.ptr - _payload.ptr) / blockSize;
        const blockIdxAfter = blockIdx + blocksOld;
        //writefln("blockIdx: %s, blockIdxAfter: %s", blockIdx, blockIdxAfter);

        // Try the maximum
        const wordIdx = blockIdxAfter / 64,
            msbIdx = cast(uint) (blockIdxAfter % 64);
        void[] p;
        auto hint = allocateAt(wordIdx, msbIdx,  blocksNew - blocksOld, p);
        if (hint[0] != size_t.max)
        {
            return false;
        }
        // Expansion successful
        assert(p.ptr == b.ptr + blocksOld * blockSize,
            text(p.ptr, " != ", b.ptr + blocksOld * blockSize));
        b = b.ptr[0 .. b.length + delta];
        return true;
    }

    /// Ditto
    @system bool reallocate(ref void[] b, size_t newSize)
    {
        if (newSize == 0)
        {
            deallocate(b);
            b = null;
            return true;
        }
        if (newSize < b.length)
        {
            // Shrink. Will shrink in place by deallocating the trailing part.
            auto newCapacity = bytes2blocks(newSize) * blockSize;
            deallocate(b[newCapacity .. $]);
            b = b[0 .. newSize];
            return true;
        }
        // Attempt an in-place expansion first
        const delta = newSize - b.length;
        if (expand(b, delta)) return true;
        // Go the slow route
        return .reallocate(this, b, newSize);
    }

    /// Ditto
    void deallocate(void[] b)
    {
        if (b is null) return;
        // Round up size to multiple of block size
        auto blocks = b.length.divideRoundUp(blockSize);
        // Locate position
        auto pos = b.ptr - _payload.ptr;
        assert(pos % blockSize == 0);
        auto blockIdx = pos / blockSize;
        auto wordIdx = blockIdx / 64, msbIdx = cast(uint) (blockIdx % 64);
        if (_startIdx > wordIdx) _startIdx = wordIdx;

        // Three stages: heading bits, full words, leftover bits
        if (msbIdx)
        {
            if (blocks + msbIdx <= 64)
            {
                resetBits(_control.rep[wordIdx],
                    cast(uint) (64 - msbIdx - blocks),
                    63 - msbIdx);
                return;
            }
            else
            {
                _control.rep[wordIdx] &= ulong.max << 64 - msbIdx;
                blocks -= 64 - msbIdx;
                ++wordIdx;
                msbIdx = 0;
            }
        }

        // Stage 2: reset one word at a time
        for (; blocks >= 64; blocks -= 64)
        {
            _control.rep[wordIdx++] = 0;
        }

        // Stage 3: deal with leftover bits, if any
        assert(wordIdx <= _control.rep.length);
        if (blocks)
        {
            _control.rep[wordIdx] &= ulong.max >> blocks;
        }
    }

    /// Ditto
    void deallocateAll()
    {
        _control[] = 0;
        _startIdx = 0;
    }

    /// Ditto
    bool empty()
    {
        return _control.allAre0();
    }

    void dump()
    {
        writefln("%s @ %s {", typeid(this), cast(void*) _control._rep.ptr);
        scope(exit) writeln("}");
        assert(_payload.length == blockSize * _blocks);
        assert(_control.length >= _blocks);
        writefln("  _startIdx=%s; blockSize=%s; blocks=%s",
            _startIdx, blockSize, _blocks);
        if (!_control.length) return;
        uint blockCount = 1;
        bool inAllocatedStore = _control[0];
        void* start = _payload.ptr;
        for (size_t i = 1;; ++i)
        {
            if (i >= _blocks || _control[i] != inAllocatedStore)
            {
                writefln("  %s block at 0x%s, length: %s (%s*%s)",
                    inAllocatedStore ? "Busy" : "Free",
                    cast(void*) start,
                    blockCount * blockSize,
                    blockCount, blockSize);
                if (i >= _blocks) break;
                assert(i < _control.length);
                inAllocatedStore = _control[i];
                start = _payload.ptr + blockCount * blockSize;
                blockCount = 1;
            }
            else
            {
                ++blockCount;
            }
        }
    }
}

///
unittest
{
    // Create a block allocator on top of a 10KB stack region.
    InSituRegion!(10240, 64) r;
    auto a = HeapBlock!(64, 64)(r.allocateAll());
    static assert(hasMember!(InSituRegion!(10240, 64), "allocateAll"));
    auto b = a.allocate(100);
    assert(b.length == 100);
}

unittest
{
    testAllocator!(() => HeapBlock!(64)(new void[1024 * 64]));
}

unittest
{
    static void testAllocateAll(size_t bs)(uint blocks, uint blocksAtATime)
    {
        assert(bs);
        auto a = HeapBlock!(bs)(
            GCAllocator.it.allocate((blocks * bs * 8 + blocks) / 8)
        );
        assert(blocks >= a._blocks, text(blocks, " < ", a._blocks));
        blocks = a._blocks;

        // test allocation of 0 bytes
        auto x = a.allocate(0);
        assert(x is null);
        // test allocation of 1 byte
        x = a.allocate(1);
        assert(x.length == 1 || blocks == 0,
            text(x.ptr, " ", x.length, " ", a));
        a.deallocateAll();

        //writeln("Control words: ", a._control.length);
        //writeln("Payload bytes: ", a._payload.length);
        bool twice = true;

    begin:
        foreach (i; 0 .. blocks / blocksAtATime)
        {
            auto b = a.allocate(bs * blocksAtATime);
            assert(b.length == bs * blocksAtATime, text(i, ": ", b.length));
        }
        assert(a.allocate(bs * blocksAtATime) is null);
        assert(a.allocate(1) is null);

        // Now deallocate all and do it again!
        a.deallocateAll();

        // Test deallocation

        auto v = new void[][blocks / blocksAtATime];
        foreach (i; 0 .. blocks / blocksAtATime)
        {
            auto b = a.allocate(bs * blocksAtATime);
            assert(b.length == bs * blocksAtATime, text(i, ": ", b.length));
            v[i] = b;
        }
        assert(a.allocate(bs * blocksAtATime) is null);
        assert(a.allocate(1) is null);

        foreach (i; 0 .. blocks / blocksAtATime)
        {
            a.deallocate(v[i]);
        }

        foreach (i; 0 .. blocks / blocksAtATime)
        {
            auto b = a.allocate(bs * blocksAtATime);
            assert(b.length == bs * blocksAtATime, text(i, ": ", b.length));
            v[i] = b;
        }

        foreach (i; 0 .. v.length)
        {
            a.deallocate(v[i]);
        }

        if (twice)
        {
            twice = false;
            goto begin;
        }

        a.deallocateAll;

        // test expansion
        if (blocks >= blocksAtATime)
        {
            foreach (i; 0 .. blocks / blocksAtATime - 1)
            {
                auto b = a.allocate(bs * blocksAtATime);
                assert(b.length == bs * blocksAtATime, text(i, ": ", b.length));
                (cast(ubyte[]) b)[] = 0xff;
                a.expand(b, blocksAtATime * bs)
                    || assert(0, text(i));
                (cast(ubyte[]) b)[] = 0xfe;
                assert(b.length == bs * blocksAtATime * 2, text(i, ": ", b.length));
                a.reallocate(b, blocksAtATime * bs) || assert(0);
                assert(b.length == bs * blocksAtATime, text(i, ": ", b.length));
            }
        }
    }

    testAllocateAll!(1)(0, 1);
    testAllocateAll!(1)(8, 1);
    testAllocateAll!(4096)(128, 1);

    testAllocateAll!(1)(0, 2);
    testAllocateAll!(1)(128, 2);
    testAllocateAll!(4096)(128, 2);

    testAllocateAll!(1)(0, 4);
    testAllocateAll!(1)(128, 4);
    testAllocateAll!(4096)(128, 4);

    testAllocateAll!(1)(0, 3);
    testAllocateAll!(1)(24, 3);
    testAllocateAll!(3000)(100, 1);
    testAllocateAll!(3000)(100, 3);

    testAllocateAll!(1)(0, 128);
    testAllocateAll!(1)(128 * 1, 128);
    testAllocateAll!(128 * 20)(13 * 128, 128);
}

// HeapBlockWithInternalPointers
/**

A $(D HeapBlock) with additional structure for supporting $(D
resolveInternalPointer). To that end, $(D HeapBlockWithInternalPointers) adds a
bitmap (one bit per block) that marks object starts. The bitmap itself has
variable size and is allocated together with regular allocations.

The time complexity of $(D resolveInternalPointer) is $(BIGOH k), where $(D k)
is the size of the object within which the internal pointer is looked up.

*/
struct HeapBlockWithInternalPointers(
    size_t theBlockSize, uint theAlignment = platformAlignment)
{
    unittest
    {
        auto m = AlignedMallocator.it.alignedAllocate(1024 * 64, theAlignment);
        testAllocator!(() => HeapBlockWithInternalPointers(m));
    }
    private HeapBlock!(theBlockSize, theAlignment) _heap;
    private BitVector _allocStart;

    this(void[] b) { _heap = HeapBlock!(theBlockSize, theAlignment)(b); }

    // Makes sure there's enough room for _allocStart
    private bool ensureRoomForAllocStart(size_t len)
    {
        if (_allocStart.length >= len) return true;
        // Must ensure there's room
        immutable oldLength = _allocStart.rep.length;
        immutable bits = len.roundUpToMultipleOf(64);
        void[] b = _allocStart.rep;
        if (!_heap.reallocate(b, bits / 8)) return false;
        assert(b.length * 8 == bits, text(b.length * 8, " != ", bits));
        _allocStart = BitVector(cast(ulong[]) b);
        assert(_allocStart.rep.length * 64 == bits);
        _allocStart.rep[oldLength .. $] = ulong.max;
        return true;
    }

    /**
    Allocator primitives.
    */
    alias alignment = theAlignment;

    /// Ditto
    void[] allocate(size_t bytes)
    {
        auto r = _heap.allocate(bytes);
        if (!r) return r;
        immutable block = (r.ptr - _heap._payload.ptr) / _heap.blockSize;
        immutable blocks =
            (r.length + _heap.blockSize - 1) / _heap.blockSize;
        if (!ensureRoomForAllocStart(block + blocks))
        {
            // Failed, free r and bailout
            _heap.deallocate(r);
            return null;
        }
        assert(block < _allocStart.length);
        assert(block + blocks <= _allocStart.length);
        // Mark the _allocStart bits
        assert(blocks > 0);
        _allocStart[block] = 1;
        _allocStart[block + 1 .. block + blocks] = 0;
        assert(block + blocks == _allocStart.length
            || _allocStart[block + blocks] == 1);
        return r;
    }

    /// Ditto
    void[] allocateAll()
    {
        auto r = _heap.allocateAll();
        if (!r) return r;
        // Carve space at the end for _allocStart
        auto p = alignDownTo(r.ptr + r.length - 8, ulong.alignof);
        r = r[0 .. p - r.ptr];
        // Initialize _allocStart
        _allocStart = BitVector(cast(ulong[]) p[0 .. 8]);
        _allocStart[] = 0;
        immutable block = (r.ptr - _heap._payload.ptr) / _heap.blockSize;
        assert(block < _allocStart.length);
        _allocStart[block] = 1;
        return r;
    }

    /// Ditto
    bool expand(ref void[] b, size_t bytes)
    {
        if (!bytes) return true;
        if (b is null)
        {
            b = allocate(bytes);
            return b !is null;
        }
        immutable oldBlocks =
            (b.length + _heap.blockSize - 1) / _heap.blockSize;
        assert(oldBlocks);
        immutable newBlocks =
            (b.length + bytes + _heap.blockSize - 1) / _heap.blockSize;
        assert(newBlocks >= oldBlocks);
        immutable block = (b.ptr - _heap._payload.ptr) / _heap.blockSize;
        assert(_allocStart[block]);
        if (!ensureRoomForAllocStart(block + newBlocks)
                || !_heap.expand(b, bytes))
        {
            return false;
        }
        // Zero only the expanded bits
        _allocStart[block + oldBlocks .. block + newBlocks] = 0;
        assert(_allocStart[block]);
        return true;
    }

    /// Ditto
    void deallocate(void[] b)
    {
        // No need to touch _allocStart here - except for the first bit, it's
        // meaningless in freed memory. The first bit is already 1.
        _heap.deallocate(b);
        // TODO: one smart thing to do is reduce memory occupied by
        // _allocStart if we're freeing the rightmost block.
    }

    /// Ditto
    void[] resolveInternalPointer(void* p)
    {
        if (p < _heap._payload.ptr
            || p >= _heap._payload.ptr + _heap._payload.length)
        {
            return null;
        }
        // Find block start
        auto block = (p - _heap._payload.ptr) / _heap.blockSize;
        if (block >= _allocStart.length) return null;
        // This may happen during marking, so comment it out.
        // if (!_heap._control[block]) return null;
        // Within an allocation, must find the 1 just to the left of it
        auto i = _allocStart.find1Backward(block);
        if (i == ulong.max) return null;
        auto j = _allocStart.find1(i + 1);
        return _heap._payload.ptr[_heap.blockSize * i .. _heap.blockSize * j];
    }

    /// Ditto
    bool empty()
    {
        return _heap.empty;
    }

    /// Ditto
    void markAllAsUnused()
    {
        // Mark all deallocated memory with 1 so we minimize damage created by
        // false pointers. TODO: improve speed.
        foreach (i, ref e; _allocStart.rep)
        {
            // Set to 1 all bits in _allocStart[i] that were 0 in control, and
            // leave the others unchanged.
            // (0, 0) => 1; (0, 1) => 0; (1, 0) => 1; (1, 1) => 1
            e |= ~_heap._control.rep[i];
        }
        // Now zero all control bits
        _heap._control[] = 0;
        // EXCEPT for the _allocStart block itself
        markAsUsed(_allocStart.rep);
    }
    /// Ditto
    bool markAsUsed(void[] b)
    {
        // Locate position
        auto pos = b.ptr - _heap._payload.ptr;
        assert(pos % _heap.blockSize == 0);
        auto blockIdx = pos / _heap.blockSize;
        if (_heap._control[blockIdx]) return false;
        // Round up size to multiple of block size
        auto blocks = b.length.divideRoundUp(_heap.blockSize);
        _heap._control[blockIdx .. blockIdx + blocks] = 1;
        return true;
    }
    /// Ditto
    void doneMarking()
    {
        // Nothing to do, what's free stays free.
    }
}

unittest
{
    auto h = HeapBlockWithInternalPointers!(4096)(new void[4096 * 1024]);
    auto b = h.allocate(123);
    assert(b.length == 123);
    auto p = h.resolveInternalPointer(b.ptr + 17);
    assert(p.ptr is b.ptr);
    assert(p.length >= b.length);
    b = h.allocate(4096);
    assert(h.resolveInternalPointer(b.ptr) is b);
    assert(h.resolveInternalPointer(b.ptr + 11) is b);
    assert(h.resolveInternalPointer(b.ptr - 40970) is null);

    assert(h.expand(b, 1));
    assert(b.length == 4097);
    assert(h.resolveInternalPointer(b.ptr + 4096).ptr is b.ptr);
}

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
MAP_PRIVATE | MAP_ANON, -1, 0)), and each call to $(D deallocate(b)) issues $(D
munmap(b.ptr, b.length)). So $(D MmapAllocator) is usually intended for
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
    Allocator buckets[(max - (min - 1)) / step];

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
Dynamic version of an allocator. This should be used wherever a uniform type is
required for encapsulating various allocator implementations.

TODO: add support for $(D shared).
*/
class CAllocator
{
    /**
    Returns the alignment offered. By default this method returns $(D platformAlignment).
    */
    @property uint alignment()
    {
        return platformAlignment;
    }

    /**
    Sets the alignment and returns $(D true) on success, $(D false) if not
    supported. By default returns $(D false). An allocator implementation could
    throw an exception if it does allow setting the alignment but an invalid
    value is passed.
    */
    @property bool alignment(uint)
    {
        return false;
    }

    /**
    Returns the good allocation size that guarantees zero internal
    fragmentation. By default returns $(D s) rounded up to the nearest multiple
    of $(D alignment).
    */
    size_t goodAllocSize(size_t s)
    {
        return s.roundUpToMultipleOf(alignment);
    }

    /**
    Allocates memory.
    */
    abstract void[] allocate(size_t);

    /**
    Returns $(D true) if the allocator supports $(D owns). By default returns
    $(D false).
    */
    bool supportsOwns()
    {
        return false;
    }

    /**
    Returns $(D true) if the allocator owns $(D b). By default issues $(D
    assert(false)).
    */
    bool owns(void[] b)
    {
        assert(false);
    }

    /// Expands a memory block in place.
    abstract bool expand(ref void[], size_t);

    /// Reallocates a memory block.
    abstract bool reallocate(ref void[] b, size_t);

    /// Deallocates a memory block. Returns $(D false) if deallocation is not
    /// supported.
    abstract bool deallocate(void[]);

    /// Deallocates all memory. Returns $(D false) if not supported.
    abstract bool deallocateAll();

    /// Returns $(D true) if allocator supports $(D allocateAll). By default
    /// returns $(D false).
    bool supportsAllocateAll()
    {
        return false;
    }

    /**
    Allocates and returns all memory available to this allocator. By default
    issues $(D assert(false)).
    */
    void[] allocateAll()
    {
        assert(false);
    }
}

/**
Implementation of $(D CAllocator) using $(D Allocator). This adapts a
statically-built allocator type to a uniform dynamic interface that is directly
usable by non-templated code.
*/
class CAllocatorImpl(Allocator) : CAllocator
{
    /**
    The implementation is available as a public member.
    */
    static if (stateSize!Allocator) Allocator impl;
    else alias impl = Allocator.it;

    /// Returns $(D impl.alignment).
    override @property uint alignment()
    {
        return impl.alignment;
    }

    /**
    If $(D Allocator) supports alignment setting, performs it and returns $(D
    true). Otherwise, returns $(D false).
    */
    override @property bool alignment(uint a)
    {
        static if (is(typeof(impl.alignment = a)))
        {
            impl.alignment = a;
            return true;
        }
        else
        {
            return false;
        }
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
    Returns $(D true) if $(D Allocator) supports $(D owns).
    */
    override bool supportsOwns()
    {
        return hasMember!(Allocator, "owns");
    }

    /**
    Overridden only if $(D Allocator) implements $(D owns). In that case,
    returns $(D impl.owns(b)).
    */
    static if (hasMember!(Allocator, "owns"))
    bool owns(void[] b)
    {
        return impl.owns(b);
    }

    /// Returns $(D impl.expand(b, s)) if defined, $(D false) otherwise.
    override bool expand(ref void[] b, size_t s)
    {
        static if (hasMember!(Allocator, "expand"))
            return impl.expand(b, s);
        else
            return false;
    }

    /// Returns $(D impl.reallocate(b, s)).
    override bool reallocate(ref void[] b, size_t s)
    {
        return impl.reallocate(b, s);
    }

    /// Calls $(D impl.deallocate(b)) and returns $(D true) if defined,
    /// otherwise returns $(D false).
    override bool deallocate(void[] b)
    {
        static if (hasMember!(Allocator, "deallocate"))
        {
            impl.deallocate(b);
            return true;
        }
        else
        {
            return false;
        }
    }

    /// Calls $(D impl.deallocateAll()) and returns $(D true) if defined,
    /// otherwise returns $(D false).
    override bool deallocateAll()
    {
        static if (hasMember!(Allocator, "deallocateAll"))
        {
            impl.deallocateAll();
            return true;
        }
        else
        {
            return false;
        }
    }

    /// Returns $(D true) if allocator supports $(D allocateAll). By default
    /// returns $(D false).
    override bool supportsAllocateAll()
    {
        return hasMember!(Allocator, "allocateAll");
    }

    /**
    Overridden only if $(D Allocator) implements $(D allocateAll). In that case,
    returns $(D impl.allocateAll()).
    */
    static if (hasMember!(Allocator, "deallocateAll"))
    void[] allocateAll()
    {
        return impl.allocateAll();
    }
}

///
unittest
{
    /// Define an allocator bound to the built-in GC.
    CAllocator alloc = new CAllocatorImpl!GCAllocator;
    auto b = alloc.allocate(42);
    assert(b.length == 42);
    assert(alloc.deallocate(b));

    // Define an elaborate allocator and bind it to the class API.
    // Note that the same variable "alloc" is used.
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

    alloc = new CAllocatorImpl!A;
    b = alloc.allocate(101);
    assert(alloc.deallocate(b));
}

private bool isPowerOf2(uint x)
{
    return (x & (x - 1)) == 0;
}

private bool isGoodStaticAlignment(uint x)
{
    return x.isPowerOf2 && x > 0;
}

private bool isGoodDynamicAlignment(uint x)
{
    return x.isPowerOf2 && x >= (void*).sizeof;
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

void testAllocator(alias make)()
{
    alias A = typeof(make());
    auto a = make();

    // Test alignment
    static assert(A.alignment.isPowerOf2);

    // Test goodAllocSize
    assert(a.goodAllocSize(1) >= A.alignment);
    assert(a.goodAllocSize(11) >= 11.roundUpToMultipleOf(A.alignment));
    assert(a.goodAllocSize(111) >= 111.roundUpToMultipleOf(A.alignment));

    // Test allocate
    auto b1 = a.allocate(1);
    assert(b1.length == 1);
    static if (hasMember!(A, "zeroesAllocations"))
    {
        assert((cast(byte*) b1.ptr) == 0);
    }
    auto b2 = a.allocate(2);
    assert(b2.length == 2);
    assert(b2.ptr + b2.length <= b1.ptr || b1.ptr + b1.length <= b2.ptr);

    // Test alignedAllocate
    static if (hasMember!(A, "alignedAllocate"))
    {{
        auto b3 = a.alignedAllocate(1, 256);
        assert(b3.length == 1);
        assert(b3.ptr.alignedAt(256));
        assert(a.alignedReallocate(b3, 2, 512));
        assert(b3.ptr.alignedAt(512));
        static if (hasMember!(A, "alignedDeallocate"))
        {
            a.alignedDeallocate(b3);
        }
    }}
    else
    {
        static assert(!hasMember!(A, "alignedDeallocate"));
        static assert(!hasMember!(A, "alignedReallocate"));
    }

    static if (hasMember!(A, "allocateAll"))
    {{
        auto aa = make();
        if (aa.allocateAll())
        {
            // Can't get any more memory
            assert(!aa.allocate(1));
        }
        auto ab = make();
        auto b4 = ab.allocateAll();
        assert(b4.length);
        // Can't get any more memory
        assert(!ab.allocate(1));
    }}

    static if (hasMember!(A, "expand"))
    {{
        assert(a.expand(b1, 0));
        auto len = b1.length;
        if (a.expand(b1, 102))
        {
            assert(b1.length == len + 102, text(b1.length, " != ", len + 102));
        }
        auto aa = make();
        void[] b5 = null;
        assert(aa.expand(b5, 0));
        assert(b5 is null);
        assert(aa.expand(b5, 1));
        assert(b5.length == 1);
    }}

    void[] b6 = null;
    assert(a.reallocate(b6, 0));
    assert(b6.length == 0);
    assert(a.reallocate(b6, 1));
    assert(b6.length == 1, text(b6.length));

    // Test owns
    static if (hasMember!(A, "owns"))
    {{
        assert(!a.owns(null));
        assert(a.owns(b1));
        assert(a.owns(b2));
        assert(a.owns(b6));
    }}

    static if (hasMember!(A, "resolveInternalPointer"))
    {{
        assert(a.resolveInternalPointer(null) is null);
        auto p = a.resolveInternalPointer(b1.ptr);
        assert(p.ptr is b1.ptr && p.length >= b1.length);
        p = a.resolveInternalPointer(b1.ptr + b1.length / 2);
        assert(p.ptr is b1.ptr && p.length >= b1.length);
        p = a.resolveInternalPointer(b2.ptr);
        assert(p.ptr is b2.ptr && p.length >= b2.length);
        p = a.resolveInternalPointer(b2.ptr + b2.length / 2);
        assert(p.ptr is b2.ptr && p.length >= b2.length);
        p = a.resolveInternalPointer(b6.ptr);
        assert(p.ptr is b6.ptr && p.length >= b6.length);
        p = a.resolveInternalPointer(b6.ptr + b6.length / 2);
        assert(p.ptr is b6.ptr && p.length >= b6.length);
        static int[10] b7 = [ 1, 2, 3 ];
        assert(a.resolveInternalPointer(b7.ptr) is null);
        assert(a.resolveInternalPointer(b7.ptr + b7.length / 2) is null);
        assert(a.resolveInternalPointer(b7.ptr + b7.length) is null);
        int[3] b8 = [ 1, 2, 3 ];
        assert(a.resolveInternalPointer(b8.ptr).ptr is null);
        assert(a.resolveInternalPointer(b8.ptr + b8.length / 2) is null);
        assert(a.resolveInternalPointer(b8.ptr + b8.length) is null);
    }}

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
