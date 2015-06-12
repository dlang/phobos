module std.experimental.allocator.mallocator;
import std.experimental.allocator.common;

/**
   The C heap allocator.
 */
struct Mallocator
{
    unittest { testAllocator!(() => Mallocator.it); }

    /**
    The alignment is a static constant equal to $(D platformAlignment), which
    ensures proper alignment for any D data type.
    */
    enum uint alignment = platformAlignment;

    /**
    Standard allocator methods per the semantics defined above. The
    $(D deallocate) and $(D reallocate) methods are $(D @system) because they
    may move memory around, leaving dangling pointers in user code. Somewhat
    paradoxically, $(D malloc) is $(D @safe) but that's only useful to safe
    programs that can afford to leak memory allocated.
    */
    @trusted void[] allocate(size_t bytes) shared
    {
		import core.stdc.stdlib : malloc;
        if (!bytes) return null;
        auto p = malloc(bytes);
        return p ? p[0 .. bytes] : null;
    }

    /// Ditto
    @system bool deallocate(void[] b) shared
    {
		import core.stdc.stdlib : free;
        free(b.ptr);
        return true;
    }

    /// Ditto
    @system bool reallocate(ref void[] b, size_t s) shared
    {
		import core.stdc.stdlib : realloc;
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
    Returns the global instance of this allocator type. The C heap allocator is
    thread-safe, therefore all of its methods and $(D it) itself are
    $(D shared).
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

    test!Mallocator();
}

version (Posix) private extern(C) int posix_memalign(void**, size_t, size_t);
version (Windows)
{
    private extern(C) void* _aligned_malloc(size_t, size_t);
    private extern(C) void _aligned_free(void *memblock);
    private extern(C) void* _aligned_realloc(void *, size_t, size_t);
}

/**
   Aligned allocator using OS-specific primitives, under a uniform API.
 */
struct AlignedMallocator
{
    unittest { testAllocator!(() => typeof(this).it); }

    /**
    The default alignment is $(D platformAlignment).
    */
    enum uint alignment = platformAlignment;

    /**
    Forwards to $(D alignedAllocate(bytes, platformAlignment)).
    */
    @trusted void[] allocate(size_t bytes) shared
    {
        if (!bytes) return null;
        return alignedAllocate(bytes, alignment);
    }

    /**
    Uses $(WEB man7.org/linux/man-pages/man3/posix_memalign.3.html,
    $(D posix_memalign)) on Posix and
    $(WEB msdn.microsoft.com/en-us/library/8z34s9c6(v=vs.80).aspx,
    $(D __aligned_malloc)) on Windows.
    */
    version(Posix) @trusted
    void[] alignedAllocate(size_t bytes, uint a) shared
    {
        import std.conv : to;
		import core.stdc.errno : ENOMEM;
        assert(a.isGoodDynamicAlignment, to!string(a));
        void* result;
        auto code = posix_memalign(&result, a, bytes);
        if (code == ENOMEM) return null;
        import std.exception : enforce;
        import std.conv : text;
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
    bool deallocate(void[] b) shared
    {
		import core.stdc.stdlib : free;
        free(b.ptr);
        return true;
    }
    else version (Windows) @system
    bool deallocate(void[] b) shared
    {
        _aligned_free(b.ptr);
        return true;
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
    Returns the global instance of this allocator type. The C heap allocator is
    thread-safe, therefore all of its methods and $(D it) itself are
    $(D shared).
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
