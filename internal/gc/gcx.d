//
// Copyright (C) 2001-2004 by Digital Mars
// All Rights Reserved
// Written by Walter Bright
// www.digitalmars.com

// D Garbage Collector implementation

/************** Debugging ***************************/

//debug = PRINTF;			// turn on printf's
//debug = COLLECT_PRINTF;		// turn on printf's
//debug = THREADINVARIANT;	// check thread integrity
//debug = LOGGING;		// log allocations / frees
//debug = MEMSTOMP;		// stomp on memory
//debug = SENTINEL;		// add underrun/overrrun protection
//debug = PTRCHECK;		// more pointer checking
//debug = PTRCHECK2;		// thorough but slow pointer checking

/*************** Configuration *********************/

version = STACKGROWSDOWN;	// growing the stack means subtracting from the stack pointer
				// (use for Intel X86 CPUs)
				// else growing the stack means adding to the stack pointer
version = MULTI_THREADED;	// produce multithreaded version

/***************************************************/


debug (PRINTF) import std.c.stdio;

import std.c.stdio;
import std.c.stdlib;
import gcbits;
import std.outofmemory;
import std.gc;
import gcstats;

version (Win32)
{
    import win32;
}

version (linux)
{
    import gclinux;
}


version (MULTI_THREADED)
{
    import std.thread;
}

/* ======================= Leak Detector =========================== */

debug (LOGGING)
{
    struct Log
    {
	void *p;
	uint size;
	uint line;
	char *file;
	void *parent;

	void print()
	{
	    printf("    p = %x, size = %d, parent = %x ", p, size, parent);
	    if (file)
	    {
		printf("%s(%u)", file, line);
	    }
	    printf("\n");
	}
    }


    struct LogArray
    {
	uint dim;
	uint allocdim;
	Log *data;

	void Dtor()
	{
	    if (data)
		std.c.stdlib.free(data);
	    data = null;
	}

	void reserve(uint nentries)
	{
	    assert(dim <= allocdim);
	    if (allocdim - dim < nentries)
	    {
		allocdim = (dim + nentries) * 2;
		assert(dim + nentries <= allocdim);
		if (!data)
		{
		    data = cast(Log *)std.c.stdlib.malloc(allocdim * Log.sizeof);
		}
		else
		{   Log *newdata;

		    newdata = cast(Log *)std.c.stdlib.malloc(allocdim * Log.sizeof);
		    assert(newdata);
		    memcpy(newdata, data, dim * Log.sizeof);
		    std.c.stdlib.free(data);
		    data = newdata;
		}
		assert(!allocdim || data);
	    }
	}

	void push(Log log)
	{
	    reserve(1);
	    data[dim++] = log;
	}

	void remove(uint i)
	{
	    memmove(data + i, data + i + 1, (dim - i) * Log.sizeof);
	    dim--;
	}

	uint find(void *p)
	{
	    for (uint i = 0; i < dim; i++)
	    {
		if (data[i].p == p)
		    return i;
	    }
	    return ~0u;		// not found
	}

	void copy(LogArray *from)
	{
	    reserve(from.dim - dim);
	    assert(from.dim <= allocdim);
	    memcpy(data, from.data, from.dim * Log.sizeof);
	    dim = from.dim;
	}


    }
}

/* ============================ GC =============================== */


//alias int size_t;
alias void (*GC_FINALIZER)(void *p, void *dummy);

class GCLock { }		// just a dummy so we can get a global lock

struct GC
{
    // For passing to debug code
    static uint line;
    static char *file;

    Gcx *gcx;		// implementation
    static ClassInfo gcLock;	// global lock

    void initialize()
    {
	gcLock = GCLock.classinfo;
	gcx = cast(Gcx *)std.c.stdlib.calloc(1, Gcx.sizeof);
	gcx.initialize();
	version (Win32)
	{
	    setStackBottom(win32.os_query_stackBottom());
	}
	version (linux)
	{
	    setStackBottom(gclinux.os_query_stackBottom());
	}
    }


    void Dtor()
    {
	version (linux)
	{
	    //debug(PRINTF) printf("Thread %x ", pthread_self());
	    //debug(PRINTF) printf("GC.Dtor()\n");
	}

	if (gcx)
	{
	    gcx.Dtor();
	    std.c.stdlib.free(gcx);
	    gcx = null;
	}
    }

    invariant
    {
	if (gcx)
	    gcx.thread_Invariant();
    }

    void *malloc(size_t size)
    {	void *p;

	if (std.thread.Thread.nthreads == 1)
	{
	    /* The reason this works is because none of the gc code
	     * can start up a new thread from within mallocNoSync().
	     * Skip the sync for speed reasons.
	     */
	    return mallocNoSync(size);
	}
	else synchronized (gcLock)
	{
	    p = mallocNoSync(size);
	}
	return p;
    }

    void *mallocNoSync(size_t size)
    {   void *p = null;
	Bins bin;

	//debug(PRINTF) printf("GC::malloc(size = %d, gcx = %p)\n", size, gcx);
	assert(gcx);
	//debug(PRINTF) printf("gcx.self = %x, pthread_self() = %x\n", gcx.self, pthread_self());
	if (size)
	{
	    size += SENTINEL_EXTRA;

	    // Compute size bin
	    bin = gcx.findBin(size);

	    if (bin < B_PAGE)
	    {
		p = gcx.bucket[bin];
		if (p == null)
		{
		    if (!gcx.allocPage(bin))	// try to find a new page
		    {
			if (std.thread.Thread.nthreads == 1)
			{
			    /* Then we haven't locked it yet. Be sure
			     * and lock for a collection, since a finalizer
			     * may start a new thread.
			     */
			    synchronized (gcLock)
			    {
				gcx.fullcollectshell();
			    }
			}
			else if (!gcx.fullcollectshell())	// collect to find a new page
			{
			    //gcx.newPool(1);
			}
		    }
		    if (!gcx.bucket[bin] && !gcx.allocPage(bin))
		    {   int result;

			gcx.newPool(1);		// allocate new pool to find a new page
			result = gcx.allocPage(bin);
			if (!result)
			    return null;
		    }
		    p = gcx.bucket[bin];
		}

		// Return next item from free list
		gcx.bucket[bin] = (cast(List *)p).next;
		memset(p + size, 0, binsize[bin] - size);
		//debug(PRINTF) printf("\tmalloc => %x\n", p);
		debug (MEMSTOMP) memset(p, 0xF0, size);
	    }
	    else
	    {
		p = gcx.bigAlloc(size);
		if (!p)
		    return null;
	    }
	    size -= SENTINEL_EXTRA;
	    p = sentinel_add(p);
	    sentinel_init(p, size);
	    gcx.log_malloc(p, size);
	}
	return p;
    }


    void *calloc(size_t size, size_t n)
    {
	uint len;
	void *p;

	len = size * n;
	p = malloc(len);
	if (p)
	{   //debug(PRINTF) printf("calloc: %x len %d\n", p, len);
	    memset(p, 0, len);
	}
	return p;
    }


    void *realloc(void *p, size_t size)
    {
	if (!size)
	{   if (p)
	    {   free(p);
		p = null;
	    }
	}
	else if (!p)
	{
	    p = malloc(size);
	}
	else
	{   void *p2;
	    uint psize;

	    //debug(PRINTF) printf("GC::realloc(p = %x, size = %u)\n", p, size);
	    version (SENTINEL)
	    {
		sentinel_Invariant(p);
		psize = *sentinel_size(p);
		if (psize != size)
		{
		    p2 = malloc(size);
		    if (psize < size)
			size = psize;
		    //debug(PRINTF) printf("\tcopying %d bytes\n",size);
		    memcpy(p2, p, size);
		    p = p2;
		}
	    }
	    else
	    {
		psize = gcx.findSize(p);	// find allocated size
		if (psize < size ||		// if new size is bigger
		    psize > size * 2)		// or less than half
		{
		    p2 = malloc(size);
		    if (psize < size)
			size = psize;
		    //debug(PRINTF) printf("\tcopying %d bytes\n",size);
		    memcpy(p2, p, size);
		    p = p2;
		}
	    }
	}
	return p;
    }


    void free(void *p)
    {
	Pool *pool;
	uint pagenum;
	Bins bin;
	uint biti;

	if (!p)
	    return;

	// Find which page it is in
	pool = gcx.findPool(p);
	if (!pool)				// if not one of ours
	    return;				// ignore
	sentinel_Invariant(p);
	p = sentinel_sub(p);
	pagenum = (p - pool.baseAddr) / PAGESIZE;

	synchronized (gcLock)
	{
	if (pool.finals.nbits && gcx.finalizer)
	{
	    biti = cast(uint)(p - pool.baseAddr) / 16;
	    if (pool.finals.testClear(biti))
	    {
		(*gcx.finalizer)(sentinel_add(p), null);
	    }
	}

	bin = cast(Bins)pool.pagetable[pagenum];
	if (bin == B_PAGE)		// if large alloc
	{   int npages;
	    uint n;

	    // Free pages
	    npages = 1;
	    n = pagenum;
	    while (++n < pool.ncommitted && pool.pagetable[n] == B_PAGEPLUS)
		npages++;
	    debug (MEMSTOMP) memset(p, 0xF2, npages * PAGESIZE);
	    pool.freePages(pagenum, npages);
	}
	else
	{   // Add to free list
	    List *list = cast(List *)p;

	    debug (MEMSTOMP) memset(p, 0xF2, binsize[bin]);

	    list.next = gcx.bucket[bin];
	    gcx.bucket[bin] = list;
	}
	}
	gcx.log_free(sentinel_add(p));
    }


    /****************************************
     * Determine the allocated size of pointer p.
     * If p is an interior pointer or not a gc allocated pointer,
     * return 0.
     */

    size_t capacity(void *p)
    {
	version (SENTINEL)
	{
	    p = sentinel_sub(p);
	    size_t size = gcx.findSize(p);

	    // Check for interior pointer
	    // This depends on:
	    // 1) size is a power of 2 for less than PAGESIZE values
	    // 2) base of memory pool is aligned on PAGESIZE boundary
	    if (cast(uint)p & (size - 1) & (PAGESIZE - 1))
		size = 0;
	    return size ? size - SENTINAL_EXTRA : 0;
	}
	else
	{
	    if (p == gcx.p_cache)
		return gcx.size_cache;

	    size_t size = gcx.findSize(p);

	    // Check for interior pointer
	    // This depends on:
	    // 1) size is a power of 2 for less than PAGESIZE values
	    // 2) base of memory pool is aligned on PAGESIZE boundary
	    if (cast(uint)p & (size - 1) & (PAGESIZE - 1))
		size = 0;
	    else
	    {
		gcx.p_cache = p;
		gcx.size_cache = size;
	    }

	    return size;
	}
    }


    /****************************************
     * Verify that pointer p:
     *	1) belongs to this memory pool
     *	2) points to the start of an allocated piece of memory
     *	3) is not on a free list
     */

    void check(void *p)
    {
	if (p)
	{
	  synchronized (gcLock)
	  {
	    sentinel_Invariant(p);
	    debug (PTRCHECK)
	    {
		Pool *pool;
		uint pagenum;
		Bins bin;
		uint size;

		p = sentinel_sub(p);
		pool = gcx.findPool(p);
		assert(pool);
		pagenum = (p - pool.baseAddr) / PAGESIZE;
		bin = cast(Bins)pool.pagetable[pagenum];
		assert(bin <= B_PAGE);
		size = binsize[bin];
		assert((cast(uint)p & (size - 1)) == 0);

		debug (PTRCHECK2)
		{
		    if (bin < B_PAGE)
		    {
			// Check that p is not on a free list
			List *list;

			for (list = gcx.bucket[bin]; list; list = list.next)
			{
			    assert(cast(void *)list != p);
			}
		    }
		}
	    }
	  }
	}
    }


    void setStackBottom(void *p)
    {
	version (STACKGROWSDOWN)
	{
	    //p = (void *)((uint *)p + 4);
	    if (p > gcx.stackBottom)
	    {
		//debug(PRINTF) printf("setStackBottom(%x)\n", p);
		gcx.stackBottom = p;
	    }
	}
	else
	{
	    //p = (void *)((uint *)p - 4);
	    if (p < gcx.stackBottom)
	    {
		//debug(PRINTF) printf("setStackBottom(%x)\n", p);
		gcx.stackBottom = cast(char *)p;
	    }
	}
    }

    void scanStaticData()
    {
	void *pbot;
	void *ptop;
	uint nbytes;

	//debug(PRINTF) printf("+GC.scanStaticData()\n");
	os_query_staticdataseg(&pbot, &nbytes);
	ptop = pbot + nbytes;
	addRange(pbot, ptop);
	//debug(PRINTF) printf("-GC.scanStaticData()\n");
    }


    void addRoot(void *p)	// add p to list of roots
    {
	synchronized (gcLock)
	{
	    gcx.addRoot(p);
	}
    }

    void removeRoot(void *p)	// remove p from list of roots
    {
	synchronized (gcLock)
	{
	    gcx.removeRoot(p);
	}
    }

    void addRange(void *pbot, void *ptop)	// add range to scan for roots
    {
	//debug(PRINTF) printf("+GC.addRange(pbot = x%x, ptop = x%x)\n", pbot, ptop);
	synchronized (gcLock)
	{
	    gcx.addRange(pbot, ptop);
	}
	//debug(PRINTF) printf("-GC.addRange()\n");
    }

    void removeRange(void *pbot)		// remove range
    {
	synchronized (gcLock)
	{
	    gcx.removeRange(pbot);
	}
    }

    void fullCollect()		// do full garbage collection
    {
	debug(PRINTF) printf("GC.fullCollect()\n");
	synchronized (gcLock)
	{
	    gcx.fullcollectshell();
	}

	version (none)
	{
	    GCStats stats;

	    getStats(stats);
	    debug(PRINTF) printf("poolsize = %x, usedsize = %x, freelistsize = %x\n",
		    stats.poolsize, stats.usedsize, stats.freelistsize);
	}

	gcx.log_collect();
    }

    void fullCollectNoStack()		// do full garbage collection
    {
	gcx.noStack++;
	fullCollect();
	gcx.noStack--;
    }

    void genCollect()	// do generational garbage collection
    {
	synchronized (gcLock)
	{
	    gcx.fullcollectshell();
	}
    }

    void minimize()	// minimize physical memory usage
    {
	// Not implemented, ignore
    }

    void setFinalizer(void *p, GC_FINALIZER pFn)
    {
	synchronized (gcLock)
	{
	    gcx.finalizer = pFn;
	    gcx.doFinalize(p);
	}
    }

    void enable()
    {
	synchronized (gcLock)
	{
	    assert(gcx.disabled > 0);
	    gcx.disabled--;
	}
    }

    void disable()
    {
	synchronized (gcLock)
	{
	    gcx.disabled++;
	}
    }

    /*****************************************
     * Retrieve statistics about garbage collection.
     * Useful for debugging and tuning.
     */

    void getStats(out GCStats stats)
    {
	uint psize = 0;
	uint usize = 0;
	uint flsize = 0;

	uint n;
	uint bsize = 0;

	//debug(PRINTF) printf("getStats()\n");
	memset(&stats, 0, GCStats.sizeof);

	synchronized (gcLock)
	{
	    for (n = 0; n < gcx.npools; n++)
	    {   Pool *pool = gcx.pooltable[n];

		psize += pool.ncommitted * PAGESIZE;
		for (uint j = 0; j < pool.ncommitted; j++)
		{
		    Bins bin = cast(Bins)pool.pagetable[j];
		    if (bin == B_FREE)
			stats.freeblocks++;
		    else if (bin == B_PAGE)
			stats.pageblocks++;
		    else if (bin < B_PAGE)
			bsize += PAGESIZE;
		}
	    }

	    for (n = 0; n < B_PAGE; n++)
	    {
		//debug(PRINTF) printf("bin %d\n", n);
		for (List *list = gcx.bucket[n]; list; list = list.next)
		{
		    //debug(PRINTF) printf("\tlist %x\n", list);
		    flsize += binsize[n];
		}
	    }
	}

	usize = bsize - flsize;

	stats.poolsize = psize;
	stats.usedsize = bsize - flsize;
	stats.freelistsize = flsize;
    }
}




/* ============================ Gcx =============================== */

enum
{   PAGESIZE =	  4096,
    COMMITSIZE = (4096*16),
    POOLSIZE =   (4096*256),
}

enum
{
    B_16,
    B_32,
    B_64,
    B_128,
    B_256,
    B_512,
    B_1024,
    B_2048,
    B_PAGE,		// start of large alloc
    B_PAGEPLUS,		// continuation of large alloc
    B_FREE,		// free page
    B_UNCOMMITTED,	// memory not committed for this page
    B_MAX
}

alias ubyte Bins;

struct List
{
    List *next;
}

struct Range
{
    void *pbot;
    void *ptop;
}

const uint binsize[B_MAX] = [ 16,32,64,128,256,512,1024,2048,4096 ];
const uint notbinsize[B_MAX] = [ ~(16u-1),~(32u-1),~(64u-1),~(128u-1),~(256u-1),
				~(512u-1),~(1024u-1),~(2048u-1),~(4096u-1) ];


/* ============================ Gcx =============================== */

struct Gcx
{
    debug (THREADINVARIANT)
    {
	pthread_t self;
	void thread_Invariant()
	{
	    if (self != pthread_self())
		printf("thread_Invariant(): gcx = %x, self = %x, pthread_self() = %x\n", this, self, pthread_self());
	    assert(self == pthread_self());
	}
    }
    else
    {
	void thread_Invariant() { }
    }

    void *p_cache;
    uint size_cache;

    uint nroots;
    uint rootdim;
    void **roots;

    uint nranges;
    uint rangedim;
    Range *ranges;

    uint noStack;	// !=0 means don't scan stack
    uint log;		// turn on logging
    uint anychanges;
    void *stackBottom;
    uint inited;
    int disabled;	// turn off collections if >0

    byte *minAddr;	// min(baseAddr)
    byte *maxAddr;	// max(topAddr)

    uint npools;
    Pool **pooltable;

    List *bucket[B_MAX];	// free list for each size

    GC_FINALIZER finalizer;	// finalizer function (one per GC)

    void initialize()
    {   int dummy;

	(cast(byte *)this)[0 .. Gcx.sizeof] = 0;
	stackBottom = cast(char *)&dummy;
	log_init();
	debug (THREADINVARIANT)
	    self = pthread_self();
	//printf("gcx = %p, self = %x\n", this, self);
	inited = 1;
    }

    void Dtor()
    {
	inited = 0;

	for (uint i = 0; i < npools; i++)
	{   Pool *pool = pooltable[i];

	    pool.Dtor();
	    std.c.stdlib.free(pool);
	}
	if (pooltable)
	    std.c.stdlib.free(pooltable);

	if (roots)
	    std.c.stdlib.free(roots);

	if (ranges)
	    std.c.stdlib.free(ranges);
    }

    void Invariant() { }

    invariant
    {
	if (inited)
	{
	//printf("Gcx.invariant(): this = %p\n", this);
	    uint i;

	    // Assure we're called on the right thread
	    debug (THREADINVARIANT) assert(self == pthread_self());

	    for (i = 0; i < npools; i++)
	    {   Pool *pool = pooltable[i];

		pool.Invariant();
		if (i == 0)
		{
		    assert(minAddr == pool.baseAddr);
		}
		if (i + 1 < npools)
		{
		    assert(pool.opCmp(pooltable[i + 1]) < 0);
		}
		else if (i + 1 == npools)
		{
		    assert(maxAddr == pool.topAddr);
		}
	    }

	    if (roots)
	    {
		assert(rootdim != 0);
		assert(nroots <= rootdim);
	    }

	    if (ranges)
	    {
		assert(rangedim != 0);
		assert(nranges <= rangedim);

		for (i = 0; i < nranges; i++)
		{
		    assert(ranges[i].pbot);
		    assert(ranges[i].ptop);
		    assert(ranges[i].pbot <= ranges[i].ptop);
		}
	    }

	    for (i = 0; i < B_PAGE; i++)
	    {
		for (List *list = bucket[i]; list; list = list.next)
		{
		}
	    }
	}
    }


    /***************************************
     */

    void addRoot(void *p)
    {
	if (nroots == rootdim)
	{
	    uint newdim = rootdim * 2 + 16;
	    void **newroots;

	    newroots = cast(void **)std.c.stdlib.malloc(newdim * newroots[0].sizeof);
	    assert(newroots);
	    if (roots)
	    {   memcpy(newroots, roots, nroots * newroots[0].sizeof);
		std.c.stdlib.free(roots);
	    }
	    roots = newroots;
	    rootdim = newdim;
	}
	roots[nroots] = p;
	nroots++;
    }


    void removeRoot(void *p)
    {
	uint i;
	for (i = nroots; i--;)
	{
	    if (roots[i] == p)
	    {
		nroots--;
		memmove(roots + i, roots + i + 1, (nroots - i) * roots[0].sizeof);
		return;
	    }
	}
	assert(0);
    }

    /***************************************
     */

    void addRange(void *pbot, void *ptop)
    {
	debug(PRINTF) printf("Thread %x ", pthread_self());
	debug(PRINTF) printf("%x.Gcx::addRange(%x, %x), nranges = %d\n", this, pbot, ptop, nranges);
	if (nranges == rangedim)
	{
	    uint newdim = rangedim * 2 + 16;
	    Range *newranges;

	    newranges = cast(Range *)std.c.stdlib.malloc(newdim * newranges[0].sizeof);
	    assert(newranges);
	    if (ranges)
	    {   memcpy(newranges, ranges, nranges * newranges[0].sizeof);
		std.c.stdlib.free(ranges);
	    }
	    ranges = newranges;
	    rangedim = newdim;
	}
	ranges[nranges].pbot = pbot;
	ranges[nranges].ptop = ptop;
	nranges++;
    }


    void removeRange(void *pbot)
    {
	debug(PRINTF) printf("Thread %x ", pthread_self());
	debug(PRINTF) printf("%x.Gcx.removeRange(%x), nranges = %d\n", this, pbot, nranges);
	for (uint i = nranges; i--;)
	{
	    if (ranges[i].pbot == pbot)
	    {
		nranges--;
		memmove(ranges + i, ranges + i + 1, (nranges - i) * ranges[0].sizeof);
		return;
	    }
	}
	debug(PRINTF) printf("Wrong thread\n");

	// This is a fatal error, but ignore it.
	// The problem is that we can get a Close() call on a thread
	// other than the one the range was allocated on.
	//assert(zero);
    }

    /*******************************
     * Find Pool that pointer is in.
     * Return null if not in a Pool.
     * Assume pooltable[] is sorted.
     */

    Pool *findPool(void *p)
    {
	if (p >= minAddr && p < maxAddr)
	{
	    if (npools == 1)
	    {
		return pooltable[0];
	    }

	    for (uint i = 0; i < npools; i++)
	    {   Pool *pool;

		pool = pooltable[i];
		if (p < pool.topAddr)
		{   if (pool.baseAddr <= p)
			return pool;
		    break;
		}
	    }
	}
	return null;
    }


    /*******************************
     * Find size of pointer p.
     * Returns 0 if not a gc'd pointer
     */

    uint findSize(void *p)
    {
	Pool *pool;
	uint size = 0;

	pool = findPool(p);
	if (pool)
	{
	    uint pagenum;
	    Bins bin;

	    pagenum = (cast(uint)(p - pool.baseAddr)) / PAGESIZE;
	    bin = cast(Bins)pool.pagetable[pagenum];
	    size = binsize[bin];
	    if (bin == B_PAGE)
	    {   uint npages = pool.ncommitted;
		ubyte* pt;
		uint i;

		pt = &pool.pagetable[0];
		for (i = pagenum + 1; i < npages; i++)
		{
		    if (pt[i] != B_PAGEPLUS)
			break;
		}
		size = (i - pagenum) * PAGESIZE;
	    }
	}
	return size;
    }


    /*******************************
     * Compute bin for size.
     */

    static Bins findBin(uint size)
    {   Bins bin;

	if (size <= 256)
	{
	    if (size <= 64)
	    {
		if (size <= 16)
		    bin = B_16;
		else if (size <= 32)
		    bin = B_32;
		else
		    bin = B_64;
	    }
	    else
	    {
		if (size <= 128)
		    bin = B_128;
		else
		    bin = B_256;
	    }
	}
	else
	{
	    if (size <= 1024)
	    {
		if (size <= 512)
		    bin = B_512;
		else
		    bin = B_1024;
	    }
	    else
	    {
		if (size <= 2048)
		    bin = B_2048;
		else
		    bin = B_PAGE;
	    }
	}
	return bin;
    }

    /****************************************
     * Allocate a chunk of memory that is larger than a page.
     * Return null if out of memory.
     */

    void *bigAlloc(uint size)
    {
	Pool *pool;
	uint npages;
	uint n;
	uint pn;
	uint freedpages;
	void *p;
	int state;

	npages = (size + PAGESIZE - 1) / PAGESIZE;

	for (state = 0; ; )
	{
	    // This code could use some refinement when repeatedly
	    // allocating very large arrays.

	    for (n = 0; n < npools; n++)
	    {
		pool = pooltable[n];
		pn = pool.allocPages(npages);
		if (pn != ~0u)
		    goto L1;
	    }

	    // Failed
	    switch (state)
	    {
		case 0:
		    // Try collecting
		    freedpages = fullcollectshell();
		    if (freedpages >= npools * ((POOLSIZE / PAGESIZE) / 4))
		    {   state = 1;
			continue;
		    }
		    // Allocate new pool
		    pool = newPool(npages);
		    if (!pool)
		    {   state = 2;
			continue;
		    }
		    pn = pool.allocPages(npages);
		    assert(pn != ~0u);
		    goto L1;

		case 1:
		    // Allocate new pool
		    pool = newPool(npages);
		    if (!pool)
			goto Lnomemory;
		    pn = pool.allocPages(npages);
		    assert(pn != ~0u);
		    goto L1;

		case 2:
		    goto Lnomemory;
	    }
	}

      L1:
	pool.pagetable[pn] = B_PAGE;
	if (npages > 1)
	    memset(&pool.pagetable[pn + 1], B_PAGEPLUS, npages - 1);
	p = pool.baseAddr + pn * PAGESIZE;
	memset(cast(char *)p + size, 0, npages * PAGESIZE - size);
	debug (MEMSTOMP) memset(p, 0xF1, size);
	//debug(PRINTF) printf("\tp = %x\n", p);
	return p;

      Lnomemory:
	assert(0);
	return null;
    }


    /***********************************
     * Allocate a new pool with at least npages in it.
     * Sort it into pooltable[].
     * Return null if failed.
     */

    Pool *newPool(uint npages)
    {
	Pool *pool;
	Pool **newpooltable;
	uint newnpools;
	uint i;

	//debug(PRINTF) printf("************Gcx::newPool(npages = %d)****************\n", npages);

	// Round up to COMMITSIZE pages
	npages = (npages + (COMMITSIZE/PAGESIZE) - 1) & ~(COMMITSIZE/PAGESIZE - 1);

	// Minimum of POOLSIZE
	if (npages < POOLSIZE/PAGESIZE)
	    npages = POOLSIZE/PAGESIZE;

	// Allocate successively larger pools up to 8 megs
	if (npools)
	{   uint n;

	    n = npools;
	    if (n > 8)
		n = 8;			// cap pool size at 8 megs
	    n *= (POOLSIZE / PAGESIZE);
	    if (npages < n)
		npages = n;
	}

	pool = cast(Pool *)std.c.stdlib.calloc(1, Pool.sizeof);
	if (pool)
	{
	    pool.initialize(npages);
	    if (!pool.baseAddr)
		goto Lerr;

	    newnpools = npools + 1;
	    newpooltable = cast(Pool **)std.c.stdlib.realloc(pooltable, newnpools * (Pool *).sizeof);
	    if (!newpooltable)
		goto Lerr;

	    // Sort pool into newpooltable[]
	    for (i = 0; i < npools; i++)
	    {
		if (pool.opCmp(newpooltable[i]) < 0)
		     break;
	    }
	    memmove(newpooltable + i + 1, newpooltable + i, (npools - i) * (Pool *).sizeof);
	    newpooltable[i] = pool;

	    pooltable = newpooltable;
	    npools = newnpools;

	    minAddr = pooltable[0].baseAddr;
	    maxAddr = pooltable[npools - 1].topAddr;
	}
	return pool;

      Lerr:
	pool.Dtor();
	std.c.stdlib.free(pool);
	return null;
    }


    /*******************************
     * Allocate a page of bin's.
     * Returns:
     *	0	failed
     */

    int allocPage(Bins bin)
    {
	Pool *pool;
	uint n;
	uint pn;
	byte *p;
	byte *ptop;

	//debug(PRINTF) printf("Gcx::allocPage(bin = %d)\n", bin);
	for (n = 0; n < npools; n++)
	{
	    pool = pooltable[n];
	    pn = pool.allocPages(1);
	    if (pn != ~0u)
		goto L1;
	}
	return 0;		// failed

      L1:
	pool.pagetable[pn] = cast(ubyte)bin;

	// Convert page to free list
	uint size = binsize[bin];
	List **b = &bucket[bin];

	p = pool.baseAddr + pn * PAGESIZE;
	ptop = p + PAGESIZE;
	for (; p < ptop; p += size)
	{
	    (cast(List *)p).next = *b;
	    *b = cast(List *)p;
	}
	return 1;
    }


    /************************************
     * Search a range of memory values and mark any pointers into the GC pool.
     */

    void mark(void *pbot, void *ptop)
    {
	void **p1 = cast(void **)pbot;
	void **p2 = cast(void **)ptop;
	uint changes = 0;

	//if (log) debug(PRINTF) printf("Gcx::mark(%x .. %x)\n", pbot, ptop);
	for (; p1 < p2; p1++)
	{
	    Pool *pool;
	    byte *p = cast(byte *)(*p1);

	    //if (log) debug(PRINTF) printf("\tmark %x\n", p);
	    if (p >= minAddr)
	    {
		pool = findPool(p);
		if (pool)
		{
		    uint offset = cast(uint)(p - pool.baseAddr);
		    uint biti;
		    uint pn = offset / PAGESIZE;
		    Bins bin = cast(Bins)pool.pagetable[pn];

		    //debug(PRINTF) printf("\t\tfound pool %x, base=%x, pn = %d, bin = %d, biti = x%x\n", pool, pool.baseAddr, pn, bin, biti);

		    // Adjust bit to be at start of allocated memory block
		    if (bin <= B_PAGE)
		    {
			biti = (offset & notbinsize[bin]) >> 4;
			//debug(PRINTF) printf("\t\tbiti = x%x\n", biti);
		    }
		    else if (bin == B_PAGEPLUS)
		    {
			do
			{   --pn;
			} while (cast(Bins)pool.pagetable[pn] == B_PAGEPLUS);
			biti = pn * (PAGESIZE / 16);
		    }
		    else
		    {
			// Don't mark bits in B_FREE or B_UNCOMMITTED pages
			continue;
		    }

		    //debug(PRINTF) printf("\t\tmark(x%x) = %d\n", biti, pool.mark.test(biti));
		    if (!pool.mark.test(biti))
		    {
			//if (log) debug(PRINTF) printf("\t\tmarking %x\n", p);
			pool.mark.set(biti);
			pool.scan.set(biti);
			changes = 1;
			log_parent(sentinel_add(pool.baseAddr + biti * 16), sentinel_add(pbot));
		    }
		}
	    }
	}
	anychanges |= changes;
    }

    /*********************************
     * Return number of full pages free'd.
     */

    uint fullcollectshell()
    {
	// The purpose of the 'shell' is to ensure all the registers
	// get put on the stack so they'll be scanned
	void *sp;
	uint result;
	asm
	{
	    pushad		;
	    mov	sp[EBP],ESP	;
	}
	result = fullcollect(sp);
	asm
	{
	    popad		;
	}
	return result;
    }

    uint fullcollect(void *stackTop)
    {
	uint n;
	Pool *pool;

	debug(COLLECT_PRINTF) printf("Gcx.fullcollect()\n");

	Thread.pauseAll();

	p_cache = null;
	size_cache = 0;

	anychanges = 0;
	for (n = 0; n < npools; n++)
	{
	    pool = pooltable[n];
	    pool.mark.zero();
	    pool.scan.zero();
	    pool.freebits.zero();
	}

	// Mark each free entry, so it doesn't get scanned
	for (n = 0; n < B_PAGE; n++)
	{
	    for (List *list = bucket[n]; list; list = list.next)
	    {
		pool = findPool(list);
		assert(pool);
		pool.freebits.set(cast(uint)(cast(byte *)list - pool.baseAddr) / 16);
	    }
	}

	for (n = 0; n < npools; n++)
	{
	    pool = pooltable[n];
	    pool.mark.copy(&pool.freebits);
	}

	version (MULTI_THREADED)
	{
	    // Scan stacks and registers for each paused thread
	    Thread[] threads = Thread.getAll();
	    //thread_id id = cast(thread_id) GetCurrentThread();
	    for (n = 0; n < threads.length; n++)
	    {   Thread t = threads[n];

		if (t && t.getState() == Thread.TS.RUNNING)
		{
		    if (noStack && threads.length == 1)
			break;

		    version (Win32)
		    {
			CONTEXT context;

			context.ContextFlags = CONTEXT_INTEGER | CONTEXT_CONTROL;
			if (!GetThreadContext(t.hdl, &context))
			{
			    assert(0);
			}
			debug (PRINTF) printf("mt scan stack bot = %x, top = %x\n", context.Esp, t.stackBottom);
			mark(cast(void *)context.Esp, t.stackBottom);
			mark(&context.Edi, &context.Eip);
		    }
		    version (linux)
		    {
			// The registers are already stored in the stack
			//printf("Thread: ESP = x%x, stackBottom = x%x, isSelf = %d\n", Thread.getESP(), t.stackBottom, t.isSelf());
			if (t.isSelf())
			    t.stackTop = Thread.getESP();

			version (STACKGROWSDOWN)
			    mark(t.stackTop, t.stackBottom);
			else
			    mark(t.stackBottom, t.stackTop);
		    }
		}
	    }
	}
	else
	{
	    if (!noStack)
	    {
		// Scan stack for main thread
		debug(PRINTF) printf(" scan stack bot = %x, top = %x\n", stackTop, stackBottom);
		version (STACKGROWSDOWN)
		    mark(stackTop, stackBottom);
		else
		    mark(stackBottom, stackTop);
	    }
	}

	// Scan roots[]
	debug(COLLECT_PRINTF) printf("scan roots[]\n");
	mark(roots, roots + nroots);

	// Scan ranges[]
	debug(COLLECT_PRINTF) printf("scan ranges[]\n");
	//log++;
	for (n = 0; n < nranges; n++)
	{
	    debug(COLLECT_PRINTF) printf("\t%x .. %x\n", ranges[n].pbot, ranges[n].ptop);
	    mark(ranges[n].pbot, ranges[n].ptop);
	}
	//log--;

	debug(COLLECT_PRINTF) printf("\tscan heap\n");
	while (anychanges)
	{
	    anychanges = 0;
	    for (n = 0; n < npools; n++)
	    {
		uint *bbase;
		uint *b;
		uint *btop;

		pool = pooltable[n];

		bbase = pool.scan.base();
		btop = bbase + pool.scan.nwords;
		for (b = bbase; b < btop;)
		{   Bins bin;
		    uint pn;
		    uint u;
		    uint bitm;
		    byte *o;

		    bitm = *b;
		    if (!bitm)
		    {   b++;
			continue;
		    }
		    *b = 0;

		    o = pool.baseAddr + (b - bbase) * 32 * 16;
		    if (!(bitm & 0xFFFF))
		    {
			bitm >>= 16;
			o += 16 * 16;
		    }
		    for (; bitm; o += 16, bitm >>= 1)
		    {
			if (!(bitm & 1))
			    continue;

			pn = (o - pool.baseAddr) / PAGESIZE;
			bin = cast(Bins)pool.pagetable[pn];
			if (bin < B_PAGE)
			{
			    mark(o, o + binsize[bin]);
			}
			else if (bin == B_PAGE || bin == B_PAGEPLUS)
			{
			    if (bin == B_PAGEPLUS)
			    {
				while (pool.pagetable[pn - 1] != B_PAGE)
				    pn--;
			    }
			    u = 1;
			    while (pn + u < pool.ncommitted && pool.pagetable[pn + u] == B_PAGEPLUS)
				u++;
			    mark(o, o + u * PAGESIZE);
			}
		    }
		}
	    }
	}

	// Free up everything not marked
	debug(COLLECT_PRINTF) printf("\tfree'ing\n");
	uint freedpages = 0;
	uint freed = 0;
	for (n = 0; n < npools; n++)
	{   uint pn;
	    uint ncommitted;
	    uint *bbase;

	    pool = pooltable[n];
	    bbase = pool.mark.base();
	    ncommitted = pool.ncommitted;
	    for (pn = 0; pn < ncommitted; pn++, bbase += PAGESIZE / (32 * 16))
	    {
		Bins bin = cast(Bins)pool.pagetable[pn];

		if (bin < B_PAGE)
		{   byte *p;
		    byte *ptop;
		    uint biti;
		    uint bitstride;
		    uint size = binsize[bin];

		    p = pool.baseAddr + pn * PAGESIZE;
		    ptop = p + PAGESIZE;
		    biti = pn * (PAGESIZE/16);
		    bitstride = size / 16;

    version(none) // BUG: doesn't work because freebits() must also be cleared
    {
		    // If free'd entire page
		    if (bbase[0] == 0 && bbase[1] == 0 && bbase[2] == 0 && bbase[3] == 0 &&
			bbase[4] == 0 && bbase[5] == 0 && bbase[6] == 0 && bbase[7] == 0)
		    {
			for (; p < ptop; p += size, biti += bitstride)
			{
			    if (finalizer && pool.finals.nbits &&
				pool.finals.testClear(biti))
			    {
				(*finalizer)(cast(List *)sentinel_add(p), null);
			    }

			    List *list = cast(List *)p;
			    //debug(PRINTF) printf("\tcollecting %x\n", list);
			    log_free(sentinel_add(list));

			    debug (MEMSTOMP) memset(p, 0xF3, size);
			}
			pool.pagetable[pn] = B_FREE;
			freed += PAGESIZE;
			//debug(PRINTF) printf("freeing entire page %d\n", pn);
			continue;
		    }
    }
		    for (; p < ptop; p += size, biti += bitstride)
		    {
			if (!pool.mark.test(biti))
			{
			    sentinel_Invariant(sentinel_add(p));

			    pool.freebits.set(biti);
			    if (finalizer && pool.finals.nbits &&
				pool.finals.testClear(biti))
			    {
				(*finalizer)(cast(List *)sentinel_add(p), null);
			    }

			    List *list = cast(List *)p;
			    debug(PRINTF) printf("\tcollecting %x\n", list);
			    log_free(sentinel_add(list));

			    debug (MEMSTOMP) memset(p, 0xF3, size);

			    freed += size;
			}
		    }
		}
		else if (bin == B_PAGE)
		{   uint biti = pn * (PAGESIZE / 16);

		    if (!pool.mark.test(biti))
		    {   byte *p = pool.baseAddr + pn * PAGESIZE;

			sentinel_Invariant(sentinel_add(p));
			if (finalizer && pool.finals.nbits &&
			    pool.finals.testClear(biti))
			{
			    (*finalizer)(sentinel_add(p), null);
			}

			debug(COLLECT_PRINTF) printf("\tcollecting big %x\n", p);
			log_free(sentinel_add(p));
			pool.pagetable[pn] = B_FREE;
			freedpages++;
			debug (MEMSTOMP) memset(p, 0xF3, PAGESIZE);
			while (pn + 1 < ncommitted && pool.pagetable[pn + 1] == B_PAGEPLUS)
			{
			    pn++;
			    pool.pagetable[pn] = B_FREE;
			    freedpages++;

			    debug (MEMSTOMP)
			    {   p += PAGESIZE;
				memset(p, 0xF3, PAGESIZE);
			    }
			}
		    }
		}
	    }
	}

	// Zero buckets
	bucket[] = null;

	// Free complete pages, rebuild free list
	debug(COLLECT_PRINTF) printf("\tfree complete pages\n");
	uint recoveredpages = 0;
	for (n = 0; n < npools; n++)
	{   uint pn;
	    uint ncommitted;

	    pool = pooltable[n];
	    ncommitted = pool.ncommitted;
	    for (pn = 0; pn < ncommitted; pn++)
	    {
		Bins bin = cast(Bins)pool.pagetable[pn];
		uint biti;
		uint u;

		if (bin < B_PAGE)
		{
		    uint size = binsize[bin];
		    uint bitstride = size / 16;
		    uint bitbase = pn * (PAGESIZE / 16);
		    uint bittop = bitbase + (PAGESIZE / 16);
		    byte *p;

		    biti = bitbase;
		    for (biti = bitbase; biti < bittop; biti += bitstride)
		    {   if (!pool.freebits.test(biti))
			    goto Lnotfree;
		    }
		    pool.pagetable[pn] = B_FREE;
		    recoveredpages++;
		    continue;

		 Lnotfree:
		    p = pool.baseAddr + pn * PAGESIZE;
		    for (u = 0; u < PAGESIZE; u += size)
		    {   biti = bitbase + u / 16;
			if (pool.freebits.test(biti))
			{   List *list;

			    list = cast(List *)(p + u);
			    if (list.next != bucket[bin])	// avoid unnecessary writes
				list.next = bucket[bin];
			    bucket[bin] = list;
			}
		    }
		}
	    }
	}

	debug(COLLECT_PRINTF) printf("recovered pages = %d\n", recoveredpages);
	debug(COLLECT_PRINTF) printf("\tfree'd %u bytes, %u pages from %u pools\n", freed, freedpages, npools);

	Thread.resumeAll();

	return freedpages + recoveredpages;
    }


    /*********************************
     * Run finalizer on p when it is free'd.
     */

    void doFinalize(void *p)
    {
	Pool *pool = findPool(p);
	assert(pool);

	// Only allocate finals[] if we actually need it
	if (!pool.finals.nbits)
	    pool.finals.alloc(pool.mark.nbits);

	pool.finals.set((p - pool.baseAddr) / 16);
    }



    /***** Leak Detector ******/
    debug (LOGGING)
    {
	LogArray current;
	LogArray prev;

	void log_init()
	{
	    //debug(PRINTF) printf("+log_init()\n");
	    current.reserve(1000);
	    prev.reserve(1000);
	    //debug(PRINTF) printf("-log_init()\n");
	}

	void log_malloc(void *p, uint size)
	{
	    //debug(PRINTF) printf("+log_malloc(p = %x, size = %d)\n", p, size);
	    Log log;

	    log.p = p;
	    log.sizeof = size;
	    log.line = GC.line;
	    log.file = GC.file;
	    log.parent = null;

	    GC.line = 0;
	    GC.file = null;

	    current.push(log);
	    //debug(PRINTF) printf("-log_malloc()\n");
	}

	void log_free(void *p)
	{
	    //debug(PRINTF) printf("+log_free(%x)\n", p);
	    uint i;

	    i = current.find(p);
	    if (i == ~0u)
	    {
		debug(PRINTF) printf("free'ing unallocated memory %x\n", p);
	    }
	    else
		current.remove(i);
	    //debug(PRINTF) printf("-log_free()\n");
	}

	void log_collect()
	{
	    //debug(PRINTF) printf("+log_collect()\n");
	    // Print everything in current that is not in prev

	    debug(PRINTF) printf("New pointers this cycle: --------------------------------\n");
	    int used = 0;
	    for (uint i = 0; i < current.dim; i++)
	    {
		uint j;

		j = prev.find(current.data[i].p);
		if (j == ~0u)
		    current.data[i].print();
		else
		    used++;
	    }

	    debug(PRINTF) printf("All roots this cycle: --------------------------------\n");
	    for (uint i = 0; i < current.dim; i++)
	    {
		void *p;
		uint j;

		p = current.data[i].p;
		if (!findPool(current.data[i].parent))
		{
		    j = prev.find(current.data[i].p);
		    if (j == ~0u)
			debug(PRINTF) printf("N");
		    else
			debug(PRINTF) printf(" ");;
		    current.data[i].print();
		}
	    }

	    debug(PRINTF) printf("Used = %d-------------------------------------------------\n", used);
	    prev.copy(&current);

	    debug(PRINTF) printf("-log_collect()\n");
	}

	void log_parent(void *p, void *parent)
	{
	    //debug(PRINTF) printf("+log_parent()\n");
	    uint i;

	    i = current.find(p);
	    if (i == ~0u)
	    {
		debug(PRINTF) printf("parent'ing unallocated memory %x, parent = %x\n", p, parent);
		Pool *pool;
		pool = findPool(p);
		assert(pool);
		uint offset = cast(uint)(p - pool.baseAddr);
		uint biti;
		uint pn = offset / PAGESIZE;
		Bins bin = cast(Bins)pool.pagetable[pn];
		biti = (offset & notbinsize[bin]);
		debug(PRINTF) printf("\tbin = %d, offset = x%x, biti = x%x\n", bin, offset, biti);
	    }
	    else
	    {
		current.data[i].parent = parent;
	    }
	    //debug(PRINTF) printf("-log_parent()\n");
	}

    }
    else
    {
	void log_init() { }
	void log_malloc(void *p, uint size) { }
	void log_free(void *p) { }
	void log_collect() { }
	void log_parent(void *p, void *parent) { }
    }
};

/* ============================ Pool  =============================== */

struct Pool
{
    byte* baseAddr;
    byte* topAddr;
    GCBits mark;
    GCBits scan;
    GCBits finals;
    GCBits freebits;

    uint npages;
    uint ncommitted;	// ncommitted <= npages
    ubyte* pagetable;

    void initialize(uint npages)
    {
	uint poolsize;

	//debug(PRINTF) printf("Pool::Pool(%u)\n", npages);
	poolsize = npages * PAGESIZE;
	assert(poolsize >= POOLSIZE);
	baseAddr = cast(byte *)os_mem_map(poolsize);

	// Some of the code depends on page alignment of memory pools
	assert((cast(uint)baseAddr & (PAGESIZE - 1)) == 0);

	if (!baseAddr)
	{
	    //debug(PRINTF) printf("GC fail: poolsize = x%x, errno = %d\n", poolsize, errno);
	    //debug(PRINTF) printf("message = '%s'\n", sys_errlist[errno]);

	    npages = 0;
	    poolsize = 0;
	}
	//assert(baseAddr);
	topAddr = baseAddr + poolsize;

	mark.alloc(poolsize / 16);
	scan.alloc(poolsize / 16);
	freebits.alloc(poolsize / 16);

	pagetable = cast(ubyte*)std.c.stdlib.malloc(npages);
	memset(pagetable, B_UNCOMMITTED, npages);

	this.npages = npages;
	ncommitted = 0;
    }

    void Dtor()
    {
	if (baseAddr)
	{
	    int result;

	    if (ncommitted)
	    {
		result = os_mem_decommit(baseAddr, 0, ncommitted * PAGESIZE);
		assert(result == 0);
		ncommitted = 0;
	    }

	    if (npages)
	    {
		result = os_mem_unmap(baseAddr, npages * PAGESIZE);
		assert(result == 0);
		npages = 0;
	    }

	    baseAddr = null;
	    topAddr = null;
	}
	if (pagetable)
	    std.c.stdlib.free(pagetable);

	mark.Dtor();
	scan.Dtor();
	finals.Dtor();
	freebits.Dtor();
    }

    void Invariant() { }

    invariant
    {
	//mark.Invariant();
	//scan.Invariant();
	//finals.Invariant();
	//freebits.Invariant();

	if (baseAddr)
	{
	    //if (baseAddr + npages * PAGESIZE != topAddr)
		//printf("baseAddr = %p, npages = %d, topAddr = %p\n", baseAddr, npages, topAddr);
	    assert(baseAddr + npages * PAGESIZE == topAddr);
	    assert(ncommitted <= npages);
	}

	for (uint i = 0; i < npages; i++)
	{   Bins bin = cast(Bins)pagetable[i];

	    assert(bin < B_MAX);
	}
    }

    /**************************************
     * Allocate n pages from Pool.
     * Returns ~0u on failure.
     */

    uint allocPages(uint n)
    {
	uint i;
	uint n2;

	//debug(PRINTF) printf("Pool::allocPages(n = %d)\n", n);
	n2 = n;
	for (i = 0; i < ncommitted; i++)
	{
	    if (pagetable[i] == B_FREE)
	    {
		if (--n2 == 0)
		{   //debug(PRINTF) printf("\texisting pn = %d\n", i - n + 1);
		    return i - n + 1;
		}
	    }
	    else
		n2 = n;
	}
	if (ncommitted + n <= npages)
	{
	    uint tocommit;

	    tocommit = (n + (COMMITSIZE/PAGESIZE) - 1) & ~(COMMITSIZE/PAGESIZE - 1);
	    if (ncommitted + tocommit > npages)
		tocommit = npages - ncommitted;
	    //debug(PRINTF) printf("\tlooking to commit %d more pages\n", tocommit);
	    //fflush(stdout);
	    if (os_mem_commit(baseAddr, ncommitted * PAGESIZE, tocommit * PAGESIZE) == 0)
	    {
		memset(pagetable + ncommitted, B_FREE, tocommit);
		i = ncommitted;
		ncommitted += tocommit;

		while (i && pagetable[i - 1] == B_FREE)
		    i--;

		return i;
	    }
	    //debug(PRINTF) printf("\tfailed to commit %d pages\n", tocommit);
	}

	return ~0u;
    }

    /**********************************
     * Free npages pages starting with pagenum.
     */

    void freePages(uint pagenum, uint npages)
    {
	memset(&pagetable[pagenum], B_FREE, npages);
    }

    /***************************
     * Used for sorting pooltable[]
     */

    int opCmp(Pool *p2)
    {
	return baseAddr - p2.baseAddr;
    }
}


/* ============================ SENTINEL =============================== */


version (SENTINEL)
{
    const uint SENTINEL_PRE = 0xF4F4F4F4;	// 32 bits
    const ubyte SENTINEL_POST = 0xF5;		// 8 bits
    const uint SENTINEL_EXTRA = 2 * uint.sizeof + 1;

    uint* sentinel_size(void *p)  { return &(cast(uint *)p)[-2]; }
    uint* sentinel_pre(void *p)   { return &(cast(uint *)p)[-1]; }
    ubyte* sentinel_post(void *p) { return &(cast(ubyte *)p)[sentinel_size(p)]; }

    void sentinel_init(void *p, uint size)
    {
	*sentinel_size(p) = size;
	*sentinel_pre(p) = SENTINEL_PRE;
	*sentinel_post(p) = SENTINEL_POST;
    }

    void sentinel_Invariant(void *p)
    {
	assert(*sentinel_pre(p) == SENTINEL_PRE);
	assert(*sentinel_post(p) == SENTINEL_POST);
    }

    void *sentinel_add(void *p)
    {
	return p + 2 * uint.sizeof;
    }

    void *sentinel_sub(void *p)
    {
	return p - 2 * uint.sizeof;
    }
}
else
{
    const uint SENTINEL_EXTRA = 0;

    void sentinel_init(void *p, uint size)
    {
    }

    void sentinel_Invariant(void *p)
    {
    }

    void *sentinel_add(void *p)
    {
	return p;
    }

    void *sentinel_sub(void *p)
    {
	return p;
    }
}


