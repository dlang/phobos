
#include <windows.h>

#include "os.h"

/***********************************
 * Map memory.
 */

void *os_mem_map(unsigned nbytes)
{
    return VirtualAlloc(NULL, nbytes, MEM_RESERVE, PAGE_READWRITE);
}

/***********************************
 * Commit memory.
 * Returns:
 *	0	success
 *	!=0	failure
 */

int os_mem_commit(void *base, unsigned offset, unsigned nbytes)
{
    void *p;

    p = VirtualAlloc((char *)base + offset, nbytes, MEM_COMMIT, PAGE_READWRITE);
    return (p == NULL);
}


/***********************************
 * Decommit memory.
 * Returns:
 *	0	success
 *	!=0	failure
 */

int os_mem_decommit(void *base, unsigned offset, unsigned nbytes)
{
    return VirtualFree((char *)base + offset, nbytes, MEM_DECOMMIT) == 0; 
}

/***********************************
 * Unmap memory allocated with os_mem_map().
 * Memory must have already been decommitted.
 * Returns:
 *	0	success
 *	!=0	failure
 */

int os_mem_unmap(void *base, unsigned nbytes)
{
    (void)nbytes;
    return VirtualFree(base, 0, MEM_RELEASE) == 0; 
}


/********************************************
 */

pthread_t pthread_self()
{
    return (pthread_t) GetCurrentThreadId();
}

/**********************************************
 * Determine "bottom" of stack (actually the top on Win32 systems).
 */

#if __DMC__
extern "C"
{
    extern void * __cdecl _atopsp;
}
#endif

void *os_query_stackBottom()
{
#if __DMC__
    //return _atopsp;		// not needed
#endif
    _asm
    {
	mov	EAX, FS:4
    }
}

/**********************************************
 * Determine base address and size of static data segment.
 */

#if __DMC__
extern "C"
{
    extern int __cdecl _xi_a;	// &_xi_a just happens to be start of data segment
    extern int __cdecl _edata;	// &_edata is start of BSS segment
    extern int __cdecl _end;	// &_end is past end of BSS
}

void os_query_staticdataseg(void **base, unsigned *nbytes)
{
    *base = (void *)&_xi_a;
    *nbytes = (unsigned)((char *)&_end - (char *)&_xi_a);
}
#endif

#if _MSC_VER
void os_query_staticdataseg(void **base, unsigned *nbytes)
{
    static char dummy = 6;
    SYSTEM_INFO si;
    MEMORY_BASIC_INFORMATION mbi;
    char *p;
    void *bottom = NULL;
    unsigned size = 0;

    // Tests show the following does not work reliably.
    // The reason is that the data segment is arbitrarilly divided
    // up into PAGE_READWRITE and PAGE_WRITECOPY.
    // This means there are multiple regions to query, and
    // can even wind up including the code segment.
    assert(0);				// fix implementation

    GetSystemInfo(&si);
    p = (char *)((unsigned)(&dummy) & ~(si.dwPageSize - 1));
    while (VirtualQuery(p, &mbi, sizeof(mbi)) == sizeof(mbi) &&
        mbi.Protect & (PAGE_READWRITE | PAGE_WRITECOPY) &&
        !(mbi.Protect & PAGE_GUARD) &&
        mbi.AllocationBase != 0)
    {
	bottom = (void *)mbi.BaseAddress;
	size = (unsigned)mbi.RegionSize;

	printf("dwPageSize        = x%x\n", si.dwPageSize);
	printf("&dummy            = %p\n", &dummy);
	printf("BaseAddress       = %p\n", mbi.BaseAddress);
	printf("AllocationBase    = %p\n", mbi.AllocationBase);
	printf("AllocationProtect = x%x\n", mbi.AllocationProtect);
	printf("RegionSize        = x%x\n", mbi.RegionSize);
	printf("State             = x%x\n", mbi.State);
	printf("Protect           = x%x\n", mbi.Protect);
	printf("Type              = x%x\n\n", mbi.Type);

	p -= si.dwPageSize;
    }

    *base = bottom;
    *nbytes = size;
}
#endif
