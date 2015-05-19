module std.experimental.allocator.mmap_allocator;

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
        if (!bytes) return null;
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
        if (b.ptr) munmap(b.ptr, b.length) == 0 || assert(0);
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
