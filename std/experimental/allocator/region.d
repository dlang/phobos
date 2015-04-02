module std.experimental.allocator.region;

import std.experimental.allocator.common;

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
    import std.exception : enforce;

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
    import std.experimental.allocator.mallocator;
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
    import std.experimental.allocator.fallback_allocator;
    import std.experimental.allocator.free_list;
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.heap_block;
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
    FreeList!(FallbackAllocator!(HeapBlock!(64, 64), GCAllocator), 0, 16) r4;
    r4.parent.primary = HeapBlock!(64, 64)(tmp4.allocateAll());
    auto a4 = r4.allocate(104);
    assert(a4.length == 104);
}

unittest
{
    InSituRegion!(4096) r1;
    auto a = r1.allocate(2001);
    assert(a.length == 2001);
    import std.conv : text;
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
