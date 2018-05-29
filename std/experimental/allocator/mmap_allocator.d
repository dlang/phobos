// Written in the D programming language.
/**
Source: $(PHOBOSSRC std/experimental/allocator/_mmap_allocator.d)
*/
module std.experimental.allocator.mmap_allocator;

/**
Allocator (currently defined only for Posix and Windows) using
$(D $(LINK2 https://en.wikipedia.org/wiki/Mmap, mmap))
and $(D $(LUCKY munmap)) directly (or their Windows equivalents). There is no
additional structure: each call to `allocate(s)` issues a call to
$(D mmap(null, s, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)),
and each call to `deallocate(b)` issues $(D munmap(b.ptr, b.length)).
So `MmapAllocator` is usually intended for allocating large chunks to be
managed by fine-granular allocators.
*/
struct MmapAllocator
{
    /// The one shared instance.
    static shared const MmapAllocator instance;

    /**
    Alignment is page-size and hardcoded to 4096 (even though on certain systems
    it could be larger).
    */
    enum size_t alignment = 4096;

    version(Posix)
    {
        /// Allocator API.
        pure nothrow @nogc @safe
        void[] allocate(size_t bytes) shared const
        {
            import core.sys.posix.sys.mman : MAP_ANON, PROT_READ,
                PROT_WRITE, MAP_PRIVATE, MAP_FAILED;
            if (!bytes) return null;
            auto p = (() @trusted => pureMmap(null, bytes, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANON, -1, 0))();
            if (p is MAP_FAILED) return null;
            return (() @trusted => p[0 .. bytes])();
        }

        /// Ditto
        pure nothrow @nogc
        bool deallocate(void[] b) shared const
        {
            if (b.ptr) pureMunmap(b.ptr, b.length) == 0 || assert(0);
            return true;
        }
    }
    else version(Windows)
    {
        import core.sys.windows.windows : VirtualAlloc, VirtualFree, MEM_COMMIT,
            PAGE_READWRITE, MEM_RELEASE;

        /// Allocator API.
        pure nothrow @nogc @safe
        void[] allocate(size_t bytes) shared const
        {
            if (!bytes) return null;
            auto p = (() @trusted => VirtualAlloc(null, bytes, MEM_COMMIT, PAGE_READWRITE))();
            if (p == null)
                return null;
            return (() @trusted => p[0 .. bytes])();
        }

        /// Ditto
        pure nothrow @nogc
        bool deallocate(void[] b) shared const
        {
            return b.ptr is null || VirtualFree(b.ptr, 0, MEM_RELEASE) != 0;
        }
    }
}

// pure wrappers around `mmap` and `munmap` because they are used here locally
// solely to perform allocation and deallocation which in this case is `pure`
version(Posix)
extern (C) private pure @system @nogc nothrow
{
    public import core.sys.posix.sys.types : off_t;
    pragma(mangle, "fakePureErrnoImpl") ref int fakePureErrno();
    pragma(mangle, "mmap") void* fakePureMmap(void*, size_t, int, int, int, off_t);
    pragma(mangle, "munmap") int fakePureMunmap(void*, size_t);
}

version(Posix)
private void* pureMmap(void* a, size_t b, int c, int d, int e, off_t f) @trusted pure @nogc nothrow
{
    const errnosave = fakePureErrno();
    void* ret = fakePureMmap(a, b, c, d, e, f);
    fakePureErrno() = errnosave;
    return ret;
}

version(Posix)
private int pureMunmap(void* a, size_t b) @trusted pure @nogc nothrow
{
    const errnosave = fakePureErrno();
    const ret = fakePureMunmap(a, b);
    fakePureErrno() = errnosave;
    return ret;
}

pure nothrow @safe @nogc unittest
{
    alias alloc = MmapAllocator.instance;
    auto p = alloc.allocate(100);
    assert(p.length == 100);
    () @trusted { alloc.deallocate(p); p = null; }();
}
