module std.experimental.allocator.building_blocks.ascending_page_allocator;
import std.experimental.allocator.common;
/**
`AscendingPageAllocator` is a fast and safe allocator which rounds all allocations
to page size multiples. It reserves a range of virtual addresses (`mmap` for Posix
and `VirtualAlloc` for Windows) and allocates memory at consecutive virtual
addresses.

When a chunk of memory is requested, the allocator finds a range of
virtual pages which satisfy the requested size, changing their protection to
read and write using OS primitives (`mprotect` and `VirtualProtect`).
The physical memory is allocated on demand, when the pages are accessed.

Deallocation removes any read/write permissions from the target pages
and notifies the OS to reclaim the physical memory, while keeping the virtual
memory.
*/
struct AscendingPageAllocator
{
    size_t pageSize;
    size_t numPages;
    bool valid;

    // The start of the virtual address range
    void* data;

    // Keeps track of there the next allocation should start
    void* offset;

    // Number of pages which contain alive objects
    size_t pagesUsed;

    void* readWriteLimit;
    enum extraAllocPages = 1000;

    /**
    The allocator receives as a parameter the size in pages of the virtual
    address range (we assume the page size is 4096).
    */
    this(size_t pages)
    {
        import std.exception : enforce;

        valid = true;
        numPages = pages;
        version(Posix)
        {
            import core.sys.posix.sys.mman : mmap, MAP_ANON, PROT_READ,
                   PROT_WRITE, PROT_NONE, MAP_PRIVATE, MAP_FAILED;
            import core.sys.posix.unistd;
            pageSize = cast(size_t) sysconf(_SC_PAGESIZE);
            data = mmap(null, pageSize * pages, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
            enforce(data != MAP_FAILED, "Failed to mmap memory");
        }
        else version(Windows)
        {
            import core.sys.windows.windows : VirtualAlloc, PAGE_NOACCESS,
                   MEM_COMMIT, MEM_RESERVE, GetSystemInfo, SYSTEM_INFO;
            SYSTEM_INFO si;
            GetSystemInfo(&si);
            pageSize = cast(size_t) si.dwPageSize;
            data = VirtualAlloc(null, pageSize * pages, MEM_RESERVE, PAGE_NOACCESS);
            enforce(data != null, "Failed to VirtualAlloc memory");
        }
        offset = data;
        readWriteLimit = data;
    }

    /**
    Round the allocation to the next multiple of the page size.
    The allocation only reserves a range of virtual pages but the actual
    physical memory is allocated on demand, when accessing the memory
    Returns `null` on failure or if the requested size exceeds the remaining capacity.
    */
    void[] allocate(size_t n)
    {
        import std.exception : enforce;
        import std.algorithm : min;

        size_t goodSize = goodAllocSize(n);
        if (offset - data > numPages * pageSize - goodSize)
            return null;

        if (offset + goodSize > readWriteLimit)
        {
            void* newReadWriteLimit = min(data + numPages * pageSize, offset + goodSize + extraAllocPages * pageSize);
            if (newReadWriteLimit != readWriteLimit)
            {
                assert(newReadWriteLimit > readWriteLimit);
                // Give memory back just by changing page protection
                version(Posix)
                {
                    import core.sys.posix.sys.mman : mmap, mprotect,
                           MAP_PRIVATE, MAP_ANON, MAP_FAILED, PROT_NONE, PROT_WRITE, PROT_READ;
                    if (newReadWriteLimit != readWriteLimit)
                    {
                        auto ret = mprotect(readWriteLimit, newReadWriteLimit - readWriteLimit, PROT_WRITE | PROT_READ);
                        enforce(ret == 0, "Failed to allocate memory, mprotect failure");
                    }
                }
                else version(Windows)
                {
                    import core.sys.windows.windows : VirtualAlloc, MEM_COMMIT, VirtualProtect, PAGE_READWRITE, PAGE_NOACCESS;
                    if (newReadWriteLimit != readWriteLimit)
                    {
                        assert(newReadWriteLimit > readWriteLimit);
                        auto ret = VirtualAlloc(readWriteLimit, newReadWriteLimit - readWriteLimit, MEM_COMMIT, PAGE_READWRITE);
                        enforce(ret, "Failed to allocate memory, VirtualAlloc failure");
                    }
                }
                readWriteLimit = newReadWriteLimit;
            }

        }

        void* result = offset;
        offset += goodSize;
        pagesUsed += goodSize / pageSize;

        return cast(void[]) result[0 .. n];
    }

    /**
    Rounds the requested size to the next multiple of the page size
    */
    size_t goodAllocSize(size_t n)
    {
        return n.roundUpToMultipleOf(cast(uint) pageSize);
    }

    /**
    Removes the read/write protection of the pages which the passed buffer covers.
    Hints the OS to reclaim the physical memory(``madvise`` for Posix and
    ``VirtualUnlock`` for Windows).
    If the allocator is no longer valid, and all objects have been deallocated,
    the range of virtual addresses is unmapped.
    */
    version(Posix)
    {
        bool deallocate(void[] buf)
        {
            import core.sys.posix.sys.mman : posix_madvise, POSIX_MADV_DONTNEED, mprotect, PROT_NONE, munmap;
            //import core.sys.darwin.sys.mman : madvise, MADV_FREE;
            import std.exception : enforce;

            size_t goodSize = goodAllocSize(buf.length);
            auto ret = mprotect(buf.ptr, goodSize, PROT_NONE);
            enforce(ret == 0, "Failed to deallocate memory, mprotect failure");

            // posix_madvise to let the OS reclaim the resources
            ret = posix_madvise(buf.ptr, goodSize, POSIX_MADV_DONTNEED);
            //ret = madvise(buf.ptr, goodSize, MADV_FREE);
            enforce(ret == 0, "Failed to deallocate, posix_madvise failure");
            pagesUsed -= goodSize / pageSize;

            if (!valid && pagesUsed == 0)
            {
                ret = munmap(data, numPages * pageSize);
                enforce(ret == 0, "Failed to unmap memory, munmap failure");
                data = null;
                offset = null;
            }

            return true;
        }
    }
    else version(Windows)
    {
        bool deallocate(void[] buf)
        {
            import core.sys.windows.windows : VirtualUnlock, VirtualProtect,
                   VirtualFree, PAGE_NOACCESS, PAGE_READWRITE, MEM_RELEASE, MEM_RESET, VirtualAlloc;
            import std.exception : enforce;

            size_t goodSize = goodAllocSize(buf.length);
            auto ret = VirtualAlloc(buf.ptr, goodSize, MEM_RESET, PAGE_NOACCESS);
            assert(ret, "Failed to allocate, VirtualAlloc failure");
            pagesUsed -= goodSize / pageSize;

            if (!valid && pagesUsed == 0)
            {
                enforce(VirtualFree(data, 0, MEM_RELEASE), "Failed to unmap memory, VirtualFree failure");
                offset = null;
                data = null;
            }

            return true;
        }
    }

    /**
    Return ``true`` if the passed buffer is inside the range of virtual adresses.
    Does not guarantee that the passed buffer is still valid.
    */
    bool owns(void[] buf)
    {
        return buf.ptr >= data && buf.ptr < buf.ptr + numPages * pageSize;
    }

    /**
    Marks the allocator unavailable for further allocations and sets the ``valid``
    flag to ``false``, which unmaps the virtual address range when all memory is deallocated.
    */
    void invalidate()
    {
        import std.exception : enforce;

        valid = false;
        if (pagesUsed == 0) {
            version(Posix)
            {
                import core.sys.posix.sys.mman : munmap;
                auto ret = munmap(data, numPages * pageSize);
                enforce(ret == 0, "Failed to unmap memory, munmap failure");
            }
            else version(Windows)
            {
                import core.sys.windows.windows : VirtualFree, MEM_RELEASE;
                auto ret = VirtualFree(data, 0, MEM_RELEASE);
                enforce(ret != 0, "Failed to unmap memory, VirtualFree failure");
            }
            data = null;
            offset = null;
        }
    }

    /**
    Returns the available size for further allocations in bytes.
    */
    size_t getAvailableSize()
    {
        return numPages * pageSize + data - offset;
    }

    /**
    If the passed buffer is not the last allocation, then ``delta`` can be
    at most the number of bytes left on the last page.
    Otherwise, we can expand the last allocation until the end of the virtual
    address range.
    */
    bool expand(ref void[] b, size_t delta)
    {
        import std.exception : enforce;
        import std.algorithm : min;

        if (!delta) return true;
        if (!b.ptr) return false;

        size_t goodSize = goodAllocSize(b.length);
        size_t bytesLeftOnPage = goodSize - b.length;
        if (b.ptr + goodSize != offset && delta > bytesLeftOnPage)
            return false;

        size_t extraPages = 0;

        if (delta > bytesLeftOnPage)
        {
            extraPages = goodAllocSize(delta - bytesLeftOnPage) / pageSize;
        }
        else
        {
            b = cast(void[]) b.ptr[0 .. b.length + delta];
            return true;
        }

        if (extraPages > numPages)
            return false;

        if (offset - data > pageSize * (numPages - extraPages))
            return false;

        void* newPtrEnd = b.ptr + goodSize + extraPages * pageSize;
        if (newPtrEnd > readWriteLimit)
        {
            void* newReadWriteLimit = min(data + numPages * pageSize, newPtrEnd + extraAllocPages * pageSize);
            version(Posix)
            {
                import core.sys.posix.sys.mman : mprotect, PROT_READ, PROT_WRITE;
                auto ret = mprotect(readWriteLimit, newReadWriteLimit - readWriteLimit, PROT_READ | PROT_WRITE);
                enforce(ret == 0, "Failed to expand, mprotect failure");
            }
            else version(Windows)
            {
                import core.sys.windows.windows : VirtualAlloc, VirtualProtect, PAGE_READWRITE, PAGE_NOACCESS, MEM_COMMIT, MEM_RESERVE;
                auto ret = VirtualAlloc(readWriteLimit, newReadWriteLimit - readWriteLimit, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
                enforce(ret, "Failed to expand, VirtualAlloc failure");
            }
            readWriteLimit = newReadWriteLimit;
        }

        pagesUsed += extraPages;
        offset += extraPages * pageSize;
        b = cast(void[]) b.ptr[0 .. b.length + delta];
        return true;
    }

    /**
    First it tries to ``expand`` to satisfy ``newSize``.
    If not possible, it allocates a new buffer of length ``newSize``,
    copies the contents and deallocates the previous buffer.
    */
    bool reallocate(ref void[] b, size_t newSize)
    {
        if (!newSize) return deallocate(b);
        if (!b) return true;

        if (newSize >= b.length && expand(b, newSize - b.length))
            return true;

        void[] newB = allocate(newSize);
        if (newB.length <= b.length) newB[] = b[0 .. newB.length];
        else newB[0 .. b.length] = b[];
        deallocate(b);
        b = newB;
        return true;
    }
}

@system unittest
{
    static void testrw(void[] b)
    {
        ubyte* buf = cast(ubyte*) b.ptr;
        buf[0] = 100;
        assert(buf[0] == 100);
        buf[b.length - 1] = 101;
        assert(buf[b.length - 1] == 101);
    }

    AscendingPageAllocator a = AscendingPageAllocator(4);
    size_t pageSize = a.pageSize;
    void[] b1 = a.allocate(1);
    assert(a.getAvailableSize() == 3 * pageSize);
    testrw(b1);

    void[] b2 = a.allocate(2);
    assert(a.getAvailableSize() == 2 * pageSize);
    testrw(b2);

    void[] b3 = a.allocate(pageSize + 1);
    assert(a.getAvailableSize() == 0);
    testrw(b3);

    assert(b1.length == 1);
    assert(b2.length == 2);
    assert(b3.length == pageSize + 1);

    assert(a.offset - a.data == 4 * pageSize);
    void[] b4 = a.allocate(4);
    assert(!b4);
    a.invalidate();

    a.deallocate(b1);
    assert(a.data);
    a.deallocate(b2);
    assert(a.data);
    a.deallocate(b3);
    assert(!a.data);
}

@system unittest
{
    static void testrw(void[] b)
    {
        ubyte* buf = cast(ubyte*) b.ptr;
        buf[0] = 100;
        buf[b.length - 1] = 101;

        assert(buf[0] == 100);
        assert(buf[b.length - 1] == 101);
    }

    size_t numPages = 26214;
    AscendingPageAllocator a = AscendingPageAllocator(numPages);
    size_t pageSize = a.pageSize;
    for (int i = 0; i < numPages; i++) {
        void[] buf = a.allocate(pageSize);
        assert(buf.length == pageSize);
        testrw(buf);
        a.deallocate(buf);
    }

    assert(!a.allocate(1));
    assert(a.getAvailableSize() == 0);
    a.invalidate();
    assert(!a.data);
}

@system unittest
{
    static void testrw(void[] b)
    {
        ubyte* buf = cast(ubyte*) b.ptr;
        buf[0] = 100;
        buf[b.length - 1] = 101;

        assert(buf[0] == 100);
        assert(buf[b.length - 1] == 101);
    }

    size_t numPages = 5;
    AscendingPageAllocator a = AscendingPageAllocator(numPages);
    size_t pageSize = a.pageSize;

    void[] b1 = a.allocate(pageSize / 2);
    assert(b1.length == pageSize / 2);

    void[] b2 = a.allocate(pageSize / 2);
    assert(a.expand(b1, pageSize / 2));
    assert(a.expand(b1, 0));
    assert(!a.expand(b1, 1));
    testrw(b1);

    assert(a.expand(b2, pageSize / 2));
    testrw(b2);
    assert(b2.length == pageSize);
    assert(a.getAvailableSize() == pageSize * 3);

    void[] b3 = a.allocate(pageSize / 2);
    assert(a.reallocate(b1, b1.length));
    assert(a.reallocate(b2, b2.length));
    assert(a.reallocate(b3, b3.length));

    assert(b3.length == pageSize / 2);
    testrw(b3);
    assert(a.expand(b3, pageSize / 4));
    testrw(b3);
    assert(a.expand(b3, 0));
    assert(b3.length == pageSize / 2 + pageSize / 4);
    assert(a.expand(b3, pageSize / 4 - 1));
    testrw(b3);
    assert(a.expand(b3, 0));
    assert(b3.length == pageSize - 1);
    assert(a.expand(b3, 2));
    assert(a.expand(b3, 0));
    assert(a.getAvailableSize() == pageSize);
    assert(b3.length == pageSize + 1);
    testrw(b3);

    assert(a.reallocate(b1, b1.length));
    assert(a.reallocate(b2, b2.length));
    assert(a.reallocate(b3, b3.length));

    assert(a.reallocate(b3, 2 * pageSize));
    testrw(b3);
    assert(a.reallocate(b1, pageSize - 1));
    testrw(b1);
    assert(a.expand(b1, 1));
    testrw(b1);
    assert(!a.expand(b1, 1));

    a.invalidate();
    a.deallocate(b1);
    a.deallocate(b2);
    a.deallocate(b3);
    assert(!a.data);
}


@system unittest
{
    static void testrw(void[] b)
    {
        ubyte* buf = cast(ubyte*) b.ptr;
        buf[0] = 100;
        assert(buf[0] == 100);
        buf[b.length - 1] = 101;
        assert(buf[b.length - 1] == 101);
    }
    size_t numPages = 21000;
    enum testNum = 100;
    enum allocPages = 10;
    void[][testNum] buf;
    AscendingPageAllocator a = AscendingPageAllocator(numPages);
    size_t pageSize = a.pageSize;

    for (int i = 0; i < numPages; i += testNum * allocPages)
    {
        for (int j = 0; j < testNum; j++)
        {
            buf[j] = a.allocate(pageSize * allocPages);
            testrw(buf[j]);
        }

        for (int j = 0; j < testNum; j++)
        {
            a.deallocate(buf[j]);
        }
    }
}
