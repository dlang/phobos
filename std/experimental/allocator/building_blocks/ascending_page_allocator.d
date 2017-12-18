module std.experimental.allocator.building_blocks.ascending_page_allocator;
import std.experimental.allocator.common;

/**
`AscendingPageAllocator` is a fast and safe allocator that rounds all allocations
to multiples of the system's page size. It reserves a range of virtual addresses
(using `mmap` on Posix and `VirtualAlloc` on Windows) and allocates memory at consecutive virtual
addresses.

When a chunk of memory is requested, the allocator finds a range of
virtual pages that satisfy the requested size, changing their protection to
read/write using OS primitives (`mprotect` and `VirtualProtect`, respectively).
The physical memory is allocated on demand, when the pages are accessed.

Deallocation removes any read/write permissions from the target pages
and notifies the OS to reclaim the physical memory, while keeping the virtual
memory.

Because the allocator does not reuse memory, any dangling references to
deallocated memory will always result in deterministically crashing the process.

See_Also:
$(HTTPS microsoft.com/en-us/research/wp-content/uploads/2017/07/snowflake-extended.pdf, Project Snoflake) for the general approach.
*/
struct AscendingPageAllocator
{
    import std.typecons : Ternary;

private:
    size_t pageSize;
    size_t numPages;

    // The start of the virtual address range
    void* data;

    // Keeps track of there the next allocation should start
    void* offset;

    // Number of pages which contain alive objects
    size_t pagesUsed;

    // On allocation requests, we allocate an extra 'extraAllocPages' pages
    // The address up to which we have permissions is stored in 'readWriteLimit'
    void* readWriteLimit;
    enum extraAllocPages = 1000;

public:
    enum uint alignment = 4096;
    /**
    The allocator receives as a parameter the size in pages of the virtual
    address range
    */
    this(size_t n)
    {
        version(Posix)
        {
            import core.sys.posix.sys.mman : mmap, MAP_ANON, PROT_NONE,
                MAP_PRIVATE, MAP_FAILED;
            import core.sys.posix.unistd : sysconf, _SC_PAGESIZE;

            pageSize = cast(size_t) sysconf(_SC_PAGESIZE);
            numPages = n.roundUpToMultipleOf(cast(uint) pageSize) / pageSize;
            data = mmap(null, pageSize * numPages, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
            if (data == MAP_FAILED)
                assert(0, "Failed to mmap memory");
        }
        else version(Windows)
        {
            import core.sys.windows.windows : VirtualAlloc, PAGE_NOACCESS,
                MEM_RESERVE, GetSystemInfo, SYSTEM_INFO;

            SYSTEM_INFO si;
            GetSystemInfo(&si);
            pageSize = cast(size_t) si.dwPageSize;
            numPages = n.roundUpToMultipleOf(cast(uint) pageSize) / pageSize;
            data = VirtualAlloc(null, pageSize * numPages, MEM_RESERVE, PAGE_NOACCESS);
            if (!data)
                assert(0, "Failed to VirtualAlloc memory");
        }
        else
        {
            static assert(0, "Unsupported OS version");
        }

        offset = data;
        readWriteLimit = data;
    }

    /**
    Rounds the allocation size to the next multiple of the page size.
    The allocation only reserves a range of virtual pages but the actual
    physical memory is allocated on demand, when accessing the memory.

    Params:
    n = Bytes to allocate

    Returns:
    `null` on failure or if the requested size exceeds the remaining capacity.
    */
    void[] allocate(size_t n)
    {
        import std.algorithm.comparison : min;

        immutable pagedBytes = numPages * pageSize;
        size_t goodSize = goodAllocSize(n);
        if (goodSize > pagedBytes || offset - data > pagedBytes - goodSize)
            return null;

        if (offset + goodSize > readWriteLimit)
        {
            void* newReadWriteLimit = min(data + pagedBytes, offset + goodSize + extraAllocPages * pageSize);
            if (newReadWriteLimit != readWriteLimit)
            {
                assert(newReadWriteLimit > readWriteLimit);
                version(Posix)
                {
                    import core.sys.posix.sys.mman : mprotect, PROT_WRITE, PROT_READ;

                    auto ret = mprotect(readWriteLimit, newReadWriteLimit - readWriteLimit, PROT_WRITE | PROT_READ);
                    if (ret != 0)
                        return null;
                }
                else version(Windows)
                {
                    import core.sys.windows.windows : VirtualAlloc, MEM_COMMIT, PAGE_READWRITE;

                    auto ret = VirtualAlloc(readWriteLimit, newReadWriteLimit - readWriteLimit,
                        MEM_COMMIT, PAGE_READWRITE);
                    if (!ret)
                        return null;
                }
                else
                {
                    static assert(0, "Unsupported OS");
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
    Rounds the allocation size to the next multiple of the page size.
    The allocation only reserves a range of virtual pages but the actual
    physical memory is allocated on demand, when accessing the memory.

    The allocated memory is aligned to the specified alignment `a`.

    Params:
    n = Bytes to allocate
    a = Alignment

    Returns:
    `null` on failure or if the requested size exceeds the remaining capacity.
    */
    void[] alignedAllocate(size_t n, uint a)
    {
        void* alignedStart = cast(void*) roundUpToMultipleOf(cast(size_t) offset, a);
        assert(alignedStart.alignedAt(a));
        immutable pagedBytes = numPages * pageSize;
        size_t goodSize = goodAllocSize(n);
        if (goodSize > pagedBytes ||
            alignedStart - data > pagedBytes - goodSize)
            return null;

        auto oldOffset = offset;
        offset = alignedStart;
        auto result = allocate(n);
        if (!result)
            offset = oldOffset;
        return result;
    }

    /**
    Rounds the requested size to the next multiple of the page size.
    */
    size_t goodAllocSize(size_t n)
    {
        return n.roundUpToMultipleOf(cast(uint) pageSize);
    }

    /**
    Decommit all physical memory associated with the buffer given as parameter,
    but keep the range of virtual addresses.

    On POSIX systems `deallocate` calls `mmap` with `MAP_FIXED' a second time to decommit the memory.
    On Windows, it uses `VirtualFree` with `MEM_DECOMMIT`.
    */
    version(Posix)
    {
        bool deallocate(void[] buf)
        {
            import core.sys.posix.sys.mman : mmap, MAP_FAILED, MAP_PRIVATE,
                MAP_ANON, MAP_FIXED, PROT_NONE, munmap;

            size_t goodSize = goodAllocSize(buf.length);
            auto ptr = mmap(buf.ptr, goodSize, PROT_NONE, MAP_ANON | MAP_PRIVATE | MAP_FIXED, -1, 0);
            if (ptr == MAP_FAILED)
                 return false;

            pagesUsed -= goodSize / pageSize;
            return true;
        }
    }
    else version(Windows)
    {
        bool deallocate(void[] buf)
        {
            import core.sys.windows.windows : VirtualFree, MEM_RELEASE, MEM_DECOMMIT;

            size_t goodSize = goodAllocSize(buf.length);
            auto ret = VirtualFree(buf.ptr, goodSize, MEM_DECOMMIT);
            if (ret == 0)
                 return false;

            pagesUsed -= goodSize / pageSize;
            return true;
        }
    }
    else
    {
        static assert(0, "Unsupported OS");
    }

    /**
    Returns `Ternary.yes` if the passed buffer is inside the range of virtual adresses.
    Does not guarantee that the passed buffer is still valid.
    */
    Ternary owns(void[] buf)
    {
        if (!data)
            return Ternary.no;
        return Ternary(buf.ptr >= data && buf.ptr < buf.ptr + numPages * pageSize);
    }

    /**
    Removes the memory mapping causing all physical memory to be decommited and
    the virtual address space to be reclaimed.
    */
    bool deallocateAll()
    {
        version(Posix)
        {
            import core.sys.posix.sys.mman : munmap;
            auto ret = munmap(data, numPages * pageSize);
            if (ret != 0)
                assert(0, "Failed to unmap memory, munmap failure");
        }
        else version(Windows)
        {
            import core.sys.windows.windows : VirtualFree, MEM_RELEASE;
            auto ret = VirtualFree(data, 0, MEM_RELEASE);
            if (ret == 0)
                assert(0, "Failed to unmap memory, VirtualFree failure");
        }
        else
        {
            assert(0, "Unsupported OS version");
        }
        data = null;
        offset = null;
        return true;
    }

    /**
    Returns the available size for further allocations in bytes.
    */
    size_t getAvailableSize()
    {
        return numPages * pageSize + data - offset;
    }

    /**
    If the passed buffer is not the last allocation, then `delta` can be
    at most the number of bytes left on the last page.
    Otherwise, we can expand the last allocation until the end of the virtual
    address range.
    */
    bool expand(ref void[] b, size_t delta)
    {
        import std.algorithm.comparison : min;

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
            if (newReadWriteLimit > readWriteLimit)
            {
                version(Posix)
                {
                    import core.sys.posix.sys.mman : mprotect, PROT_READ, PROT_WRITE;

                    auto ret = mprotect(readWriteLimit, newReadWriteLimit - readWriteLimit, PROT_READ | PROT_WRITE);
                    if (ret != 0)
                        return false;
                }
                else version(Windows)
                {
                    import core.sys.windows.windows : VirtualAlloc, PAGE_READWRITE, MEM_COMMIT;
                    auto ret = VirtualAlloc(readWriteLimit, newReadWriteLimit - readWriteLimit,
                        MEM_COMMIT, PAGE_READWRITE);
                    if (!ret)
                        return false;
                }
                else
                {
                    assert(0, "Unsupported OS version");
                }
                readWriteLimit = newReadWriteLimit;
            }
        }

        pagesUsed += extraPages;
        offset += extraPages * pageSize;
        b = cast(void[]) b.ptr[0 .. b.length + delta];
        return true;
    }

    /**
    Returns `Ternary.yes` if the allocator does not contain any alive objects
    and `Ternary.no` otherwise.
    */
    Ternary empty()
    {
        return Ternary(pagesUsed == 0);
    }

    /**
    Unmaps the whole virtual address range on destruction.
    */
    ~this()
    {
        if (data)
            deallocateAll();
    }
}

version (unittest)
{
    static void testrw(void[] b)
    {
        ubyte* buf = cast(ubyte*) b.ptr;
        buf[0] = 100;
        assert(buf[0] == 100);
        buf[b.length - 1] = 101;
        assert(buf[b.length - 1] == 101);
    }

    static size_t getPageSize()
    {
        size_t pageSize;
        version(Posix)
        {
            import core.sys.posix.unistd : sysconf, _SC_PAGESIZE;

            pageSize = cast(size_t) sysconf(_SC_PAGESIZE);
        }
        else version(Windows)
        {
            import core.sys.windows.windows : GetSystemInfo, SYSTEM_INFO;

            SYSTEM_INFO si;
            GetSystemInfo(&si);
            pageSize = cast(size_t) si.dwPageSize;
        }
        return pageSize;
    }
}

@system unittest
{
    size_t pageSize = getPageSize();
    AscendingPageAllocator a = AscendingPageAllocator(4 * pageSize);
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

    a.deallocate(b1);
    assert(a.data);
    a.deallocate(b2);
    assert(a.data);
    a.deallocate(b3);
}

@system unittest
{
    size_t pageSize = getPageSize();
    size_t numPages = 26214;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);
    for (int i = 0; i < numPages; i++)
    {
        void[] buf = a.allocate(pageSize);
        assert(buf.length == pageSize);
        testrw(buf);
        a.deallocate(buf);
    }

    assert(!a.allocate(1));
    assert(a.getAvailableSize() == 0);
}

@system unittest
{
    size_t pageSize = getPageSize();
    size_t numPages = 26214;
    uint alignment = cast(uint) pageSize;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);
    for (int i = 0; i < numPages; i++)
    {
        void[] buf = a.alignedAllocate(pageSize, alignment);
        assert(buf.length == pageSize);
        testrw(buf);
        a.deallocate(buf);
    }

    assert(!a.allocate(1));
    assert(a.getAvailableSize() == 0);
}

@system unittest
{
    size_t pageSize = getPageSize();
    size_t numPages = 5;
    uint alignment = cast(uint) pageSize;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);

    void[] b1 = a.allocate(pageSize / 2);
    assert(b1.length == pageSize / 2);

    void[] b2 = a.alignedAllocate(pageSize / 2, alignment);
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

    a.deallocate(b1);
    a.deallocate(b2);
    a.deallocate(b3);
}

@system unittest
{
    size_t pageSize = getPageSize();
    size_t numPages = 21000;
    enum testNum = 100;
    enum allocPages = 10;
    void[][testNum] buf;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);

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

@system unittest
{
    size_t pageSize = getPageSize();
    enum numPages = 2;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);
    void[] b = a.allocate((numPages + 1) * pageSize);
    assert(b is null);
    b = a.allocate(1);
    assert(b.length == 1);
    assert(a.getAvailableSize() == pageSize);
    a.deallocateAll();
    assert(!a.data && !a.offset);
}

@system unittest
{
    size_t pageSize = getPageSize();
    enum numPages = 26;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);
    uint alignment = cast(uint) ((numPages / 2) * pageSize);
    void[] b = a.alignedAllocate(pageSize, alignment);
    assert(b.length == pageSize);
    testrw(b);
    assert(b.ptr.alignedAt(alignment));
    a.deallocateAll();
    assert(!a.data && !a.offset);
}

@system unittest
{
    size_t pageSize = getPageSize();
    enum numPages = 10;
    AscendingPageAllocator a = AscendingPageAllocator(numPages * pageSize);
    uint alignment = cast(uint) (2 * pageSize);

    void[] b1 = a.alignedAllocate(pageSize, alignment);
    assert(b1.length == pageSize);
    testrw(b1);
    assert(b1.ptr.alignedAt(alignment));

    void[] b2 = a.alignedAllocate(pageSize, alignment);
    assert(b2.length == pageSize);
    testrw(b2);
    assert(b2.ptr.alignedAt(alignment));

    void[] b3 = a.alignedAllocate(pageSize, alignment);
    assert(b3.length == pageSize);
    testrw(b3);
    assert(b3.ptr.alignedAt(alignment));

    void[] b4 = a.allocate(pageSize);
    assert(b4.length == pageSize);
    testrw(b4);

    assert(a.deallocate(b1));
    assert(a.deallocate(b2));
    assert(a.deallocate(b3));
    assert(a.deallocate(b4));

    a.deallocateAll();
    assert(!a.data && !a.offset);
}
