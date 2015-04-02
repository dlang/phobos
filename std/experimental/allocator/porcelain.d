module std.experimental.allocator.porcelain;

import std.experimental.allocator.common;
import std.traits : Select;

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
    import std.conv : emplace;
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
        import std.traits : hasMember;
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
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.free_list;
    import std.experimental.allocator.region;
    import std.experimental.allocator.fallback_allocator;
    auto a = allocatorObject(Mallocator.it);
    auto b = a.allocate(100);
    assert(b.length == 100);

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
    import std.traits : hasMember;

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
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.free_list;
    import std.experimental.allocator.segregator;
    import std.experimental.allocator.bucketizer;
    import std.experimental.allocator.allocator_list;
    import std.experimental.allocator.heap_block;
    import std.experimental.allocator : ThreadLocal;
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
