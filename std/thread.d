// Copyright (c) 2002-2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

module std.thread;

//debug=thread;

/* ================================ Win32 ================================= */

version (Win32)
{

private import std.c.windows.windows;

extern (Windows) alias uint (*stdfp)(void *);

extern (C)
    thread_hdl _beginthreadex(void* security, uint stack_size,
	stdfp start_addr, void* arglist, uint initflag,
	thread_id* thrdaddr);

// This is equivalent to a HANDLE from windows.d
alias HANDLE thread_hdl;

alias uint thread_id;

class ThreadError : Error
{
    this(char[] s)
    {
	super("Thread error: " ~ s);
    }
}

class Thread
{
    this()
    {
    }

    this(int (*fp)(void *), void *arg)
    {
	this.fp = fp;
	this.arg = arg;
    }

    this(int delegate() dg)
    {
	this.dg = dg;
    }

    thread_hdl hdl;
    thread_id id;
    void* stackBottom;

    void start()
    {
	if (state != TS.INITIAL)
	    error("already started");

	synchronized (threadLock)
	{
	    for (int i = 0; 1; i++)
	    {
		if (i == allThreads.length)
		    error("too many threads");
		if (!allThreads[i])
		{   allThreads[i] = this;
		    idx = i;
		    if (i >= allThreadsDim)
			allThreadsDim = i + 1;
		    break;
		}
	    }
	    nthreads++;
	}

	state = TS.RUNNING;
	hdl = _beginthreadex(null, 0, &threadstart, this, 0, &id);
	if (hdl == cast(thread_hdl)0)
	{   state = TS.TERMINATED;
	    allThreads[idx] = null;
	    idx = -1;
	    error("failed to start");
	}
    }

    int run()
    {
	if (fp)
	    return fp(arg);
	else if (dg)
	    return dg();
    }

    void wait()
    {
	if (this === getThis())
	    error("wait on self");
	if (state == TS.RUNNING)
	{   DWORD dw;

	    dw = WaitForSingleObject(hdl, 0xFFFFFFFF);
	}
    }

    void wait(uint milliseconds)
    {
	if (this === getThis())
	    error("wait on self");
	if (state == TS.RUNNING)
	{   DWORD dw;

	    dw = WaitForSingleObject(hdl, milliseconds);
	}
    }

    enum TS
    {
	INITIAL,
	RUNNING,
	TERMINATED
    }

    TS getState()
    {
	return state;
    }

    enum PRIORITY
    {
	INCREASE,
	DECREASE,
	IDLE,
	CRITICAL
    }

    void setPriority(PRIORITY p)
    {
	int nPriority;

	switch (p)
	{
	    case PRIORITY.INCREASE:
		nPriority = THREAD_PRIORITY_ABOVE_NORMAL;
		break;
	    case PRIORITY.DECREASE:
		nPriority = THREAD_PRIORITY_BELOW_NORMAL;
		break;
	    case PRIORITY.IDLE:
		nPriority = THREAD_PRIORITY_IDLE;
		break;
	    case PRIORITY.CRITICAL:
		nPriority = THREAD_PRIORITY_TIME_CRITICAL;
		break;
	}

	if (SetThreadPriority(hdl, nPriority) == THREAD_PRIORITY_ERROR_RETURN)
	    error("set priority");
    }

    static Thread getThis()
    {
	thread_id id;
	Thread result;

	//printf("getThis(), allThreadsDim = %d\n", allThreadsDim);
	synchronized (threadLock)
	{
	    id = GetCurrentThreadId();
	    for (int i = 0; i < allThreadsDim; i++)
	    {
		Thread t = allThreads[i];
		if (t && id == t.id)
		{
		    return t;
		}
	    }
	}
	printf("didn't find it\n");
	assert(result);
	return result;
    }

    static Thread[] getAll()
    {
	return allThreads[0 .. allThreadsDim];
    }

    void pause()
    {
	if (state != TS.RUNNING || SuspendThread(hdl) == 0xFFFFFFFF)
	    error("cannot pause");
    }

    void resume()
    {
	if (state != TS.RUNNING || ResumeThread(hdl) == 0xFFFFFFFF)
	    error("cannot resume");
    }

    static void pauseAll()
    {
	if (nthreads > 1)
	{
	    Thread tthis = getThis();

	    for (int i = 0; i < allThreadsDim; i++)
	    {   Thread t;

		t = allThreads[i];
		if (t && t !== tthis && t.state == TS.RUNNING)
		    t.pause();
	    }
	}
    }

    static void resumeAll()
    {
	if (nthreads > 1)
	{
	    Thread tthis = getThis();

	    for (int i = 0; i < allThreadsDim; i++)
	    {   Thread t;

		t = allThreads[i];
		if (t && t !== tthis && t.state == TS.RUNNING)
		    t.resume();
	    }
	}
    }

    static void yield()
    {
	Sleep(0);
    }

    static uint nthreads = 1;

  private:

    static uint allThreadsDim;
    static Object threadLock;
    static Thread[0x400] allThreads;	// length matches value in C runtime

    TS state;
    int idx = -1;			// index into allThreads[]

    int (*fp)(void *);
    void *arg;

    int delegate() dg;

    void error(char[] msg)
    {
	throw new ThreadError(msg);
    }


    /************************************************
     * This is just a wrapper to interface between C rtl and Thread.run().
     */

    extern (Windows) static uint threadstart(void *p)
    {
	Thread t = cast(Thread)p;
	int result;

	debug (thread) printf("Starting thread %d\n", t.idx);
	t.stackBottom = os_query_stackBottom();
	try
	{
	    result = t.run();
	}
	catch (Object o)
	{
	    printf("Error: ");
	    o.print();
	    result = 1;
	}

	debug (thread) printf("Ending thread %d\n", t.idx);
	t.state = TS.TERMINATED;
	allThreads[t.idx] = null;
	t.idx = -1;
	nthreads--;
	return result;
    }


    /**************************************
     * Create a Thread for global main().
     */

    static this()
    {
	threadLock = new Object();

	Thread t = new Thread();

	t.state = TS.RUNNING;
	t.id = GetCurrentThreadId();
	t.hdl = Thread.getCurrentThreadHandle();
	t.stackBottom = os_query_stackBottom();

	synchronized (threadLock)
	{
	    assert(!allThreads[0]);
	    allThreads[0] = t;
	    allThreadsDim = 1;
	    t.idx = 0;
	}
    }

    static ~this()
    {
	CloseHandle(allThreads[0].hdl);
	allThreads[0].hdl = GetCurrentThread();
    }
          
    /********************************************
     * Returns the handle of the current thread.
     * This is needed because GetCurrentThread() always returns -2 which
     * is a pseudo-handle representing the current thread.
     * The returned thread handle is a windows resource and must be explicitly
     * closed.
     * Many thanks to Justin (jhenzie@mac.com) for figuring this out
     * and providing the fix.
     */
    static thread_hdl getCurrentThreadHandle()
    {
	thread_hdl currentThread = GetCurrentThread();
	thread_hdl actualThreadHandle;
	thread_hdl currentProcess = cast(thread_hdl)-1;

	uint access = cast(uint)0x00000002;

	DuplicateHandle(currentProcess, currentThread, currentProcess,
			 &actualThreadHandle, cast(uint)0, TRUE, access);

	return actualThreadHandle;
     }
}


/**********************************************
 * Determine "bottom" of stack (actually the top on Win32 systems).
 */

void *os_query_stackBottom()
{
    asm
    {
	naked			;
	mov	EAX,FS:4	;
	ret			;
    }
}

}

/* ================================ linux ================================= */

version (linux)
{

private import std.c.linux.linux;
private import std.c.linux.linuxextern;

alias uint pthread_t;
extern (C) alias void (*__sighandler_t)(int);

struct sigset_t
{
    uint __val[1024 / (8 * uint.size)];
}

struct sigaction_t
{
    __sighandler_t sa_handler;
    sigset_t sa_mask;
    int sa_flags;
    void (*sa_restorer)();
}

struct _pthread_fastlock
{
    int __status;
    int __spinlock;
}

struct sem_t
{
    _pthread_fastlock __sem_lock;
    int __sem_value;
    void* __sem_waiting;
}

unittest
{
    assert(sigset_t.size  == 128);
    assert(sigaction_t.size == 140);
    assert(sem_t.size == 16);
}

extern (C)
{
    int pthread_create(pthread_t*, void*, void* (*)(void*), void*);
    int pthread_join(pthread_t, void**);
    int pthread_kill(pthread_t, int);
    pthread_t pthread_self();
    int pthread_equal(pthread_t, pthread_t);
    int sem_wait(sem_t*);
    int sem_init(sem_t*, int, uint);
    int sem_post(sem_t*);
    int sched_yield();
    int sigfillset(sigset_t*);
    int sigdelset(sigset_t*, int);
    int sigaction(int, sigaction_t*, sigaction_t*);
    int sigsuspend(sigset_t*);
}

class ThreadError : Error
{
    this(char[] s)
    {
	super("Thread error: " ~ s);
    }
}

class Thread
{
    this()
    {
    }

    this(int (*fp)(void *), void *arg)
    {
	this.fp = fp;
	this.arg = arg;
    }

    this(int delegate() dg)
    {
	this.dg = dg;
    }

    pthread_t id;
    void* stackBottom;
    void* stackTop;

    void start()
    {
	if (state != TS.INITIAL)
	    error("already started");

	synchronized (threadLock)
	{
	    for (int i = 0; 1; i++)
	    {
		if (i == allThreads.length)
		    error("too many threads");
		if (!allThreads[i])
		{   allThreads[i] = this;
		    idx = i;
		    if (i >= allThreadsDim)
			allThreadsDim = i + 1;
		    break;
		}
	    }
	    nthreads++;
	}

	state = TS.RUNNING;
	int result;
	//printf("creating thread x%x\n", this);
	result = pthread_create(&id, null, &threadstart, this);
	if (result)
	{   state = TS.TERMINATED;
	    allThreads[idx] = null;
	    idx = -1;
	    error("failed to start");	// BUG: should report errno
	}
	//printf("t = x%x, id = %d\n", this, id);
    }

    int run()
    {
	if (fp)
	    return fp(arg);
	else if (dg)
	    return dg();
    }

    void wait()
    {
	if (this === getThis())
	    error("wait on self");
	if (state == TS.RUNNING)
	{   int result;
	    void *value;

	    result = pthread_join(id, &value);
	    if (result)
		error("failed to wait");
	}
    }

    void wait(uint milliseconds)
    {
	wait();
	/+ not implemented
	if (this === getThis())
	    error("wait on self");
	if (state == TS.RUNNING)
	{   DWORD dw;

	    dw = WaitForSingleObject(hdl, milliseconds);
	}
	+/
    }

    enum TS
    {
	INITIAL,
	RUNNING,
	TERMINATED
    }

    TS getState()
    {
	return state;
    }

    enum PRIORITY
    {
	INCREASE,
	DECREASE,
	IDLE,
	CRITICAL
    }

    void setPriority(PRIORITY p)
    {
	/+ not implemented
	int nPriority;

	switch (p)
	{
	    case PRIORITY.INCREASE:
		nPriority = THREAD_PRIORITY_ABOVE_NORMAL;
		break;
	    case PRIORITY.DECREASE:
		nPriority = THREAD_PRIORITY_BELOW_NORMAL;
		break;
	    case PRIORITY.IDLE:
		nPriority = THREAD_PRIORITY_IDLE;
		break;
	    case PRIORITY.CRITICAL:
		nPriority = THREAD_PRIORITY_TIME_CRITICAL;
		break;
	}

	if (SetThreadPriority(hdl, nPriority) == THREAD_PRIORITY_ERROR_RETURN)
	    error("set priority");
	+/
    }

    int isSelf()
    {
	//printf("id = %d, self = %d\n", id, pthread_self());
	return pthread_equal(pthread_self(), id);
    }

    static Thread getThis()
    {
	pthread_t id;
	Thread result;

	//printf("getThis(), allThreadsDim = %d\n", allThreadsDim);
	synchronized (threadLock)
	{
	    id = pthread_self();
	    //printf("id = %d\n", id);
	    for (int i = 0; i < allThreadsDim; i++)
	    {
		Thread t = allThreads[i];
		//printf("allThreads[%d] = x%x, id = %d\n", i, t, (t ? t.id : 0));
		if (t && pthread_equal(id, t.id))
		{
		    return t;
		}
	    }
	}
	printf("didn't find it\n");
	assert(result);
	return result;
    }

    static Thread[] getAll()
    {
	return allThreads[0 .. allThreadsDim];
    }

    void pause()
    {
	if (state == TS.RUNNING)
	{   int result;

	    result = pthread_kill(id, SIGUSR1);
	    if (result)
		error("cannot pause");
	    else
		sem_wait(&flagSuspend);	// wait for acknowledgement
	}
	else
	    error("cannot pause");
    }

    void resume()
    {
	if (state == TS.RUNNING)
	{   int result;

	    result = pthread_kill(id, SIGUSR2);
	    if (result)
		error("cannot resume");
	}
	else
	    error("cannot resume");
    }

    static void pauseAll()
    {
	if (nthreads > 1)
	{
	    Thread tthis = getThis();
	    int npause = 0;

	    for (int i = 0; i < allThreadsDim; i++)
	    {   Thread t;

		t = allThreads[i];
		if (t && t !== tthis && t.state == TS.RUNNING)
		{   int result;

		    result = pthread_kill(t.id, SIGUSR1);
		    if (result)
			getThis().error("cannot pause");
		    else
			npause++;	// count of paused threads
		}

		// Wait for each paused thread to acknowledge
		while (npause--)
		{
		    sem_wait(&flagSuspend);
		}
	    }
	}
    }

    static void resumeAll()
    {
	if (nthreads > 1)
	{
	    Thread tthis = getThis();

	    for (int i = 0; i < allThreadsDim; i++)
	    {   Thread t;

		t = allThreads[i];
		if (t && t !== tthis && t.state == TS.RUNNING)
		    t.resume();
	    }
	}
    }

    static void yield()
    {
	sched_yield();
    }

    static uint nthreads = 1;

  private:

    static uint allThreadsDim;
    static Object threadLock;
    static Thread[/*_POSIX_THREAD_THREADS_MAX*/ 100] allThreads;
    static sem_t flagSuspend;

    TS state;
    int idx = -1;			// index into allThreads[]
    int flags = 0;

    int (*fp)(void *);
    void *arg;

    int delegate() dg;

    void error(char[] msg)
    {
	throw new ThreadError(msg);
    }


    /************************************************
     * This is just a wrapper to interface between C rtl and Thread.run().
     */

    extern (C) static void *threadstart(void *p)
    {
	Thread t = cast(Thread)p;
	int result;

	debug (thread) printf("Starting thread x%x (%d)\n", t, t.idx);

	// Need to set t.id here, because thread is off and running
	// before pthread_create() sets it.
	t.id = pthread_self();

	t.stackBottom = getESP();
	try
	{
	    result = t.run();
	}
	catch (Object o)
	{
	    printf("Error: ");
	    o.print();
	    result = 1;
	}

	debug (thread) printf("Ending thread %d\n", t.idx);
	t.state = TS.TERMINATED;
	allThreads[t.idx] = null;
	t.idx = -1;
	nthreads--;
	return (void*)result;
    }


    /**************************************
     * Create a Thread for global main().
     */

    static this()
    {
	threadLock = new Object();

	Thread t = new Thread();

	t.state = TS.RUNNING;
	t.id = pthread_self();
	t.stackBottom = (void*)__libc_stack_end;
	synchronized (threadLock)
	{
	    assert(!allThreads[0]);
	    allThreads[0] = t;
	    allThreadsDim = 1;
	    t.idx = 0;
	}

	/* Install signal handlers so we can suspend/resume threads
	 */

	int result;
	sigaction_t sigact;
	result = sigfillset(&sigact.sa_mask);
	if (result)
	    goto Lfail;
	sigact.sa_handler = &pauseHandler;
	result = sigaction(SIGUSR1, &sigact, null);
	if (result)
	    goto Lfail;
	sigact.sa_handler = &resumeHandler;
	result = sigaction(SIGUSR2, &sigact, null);
	if (result)
	    goto Lfail;

	result = sem_init(&flagSuspend, 0, 0);
	if (result)
	    goto Lfail;

	return;

      Lfail:
	getThis().error("cannot initialize threads");
    }

    /**********************************
     * This gets called when a thread gets SIGUSR1.
     */

    extern (C) static void pauseHandler(int sig)
    {	int result;

	// Save all registers on the stack so they'll be scanned by the GC
	asm
	{
	    pusha	;
	}

	assert(sig == SIGUSR1);
	sem_post(&flagSuspend);

	sigset_t sigmask;
	result = sigfillset(&sigmask);
	assert(result == 0);
	result = sigdelset(&sigmask, SIGUSR2);
	assert(result == 0);

	Thread t = getThis();
	t.stackTop = getESP();
	t.flags &= ~1;
	while (1)
	{
	    sigsuspend(&sigmask);	// suspend until SIGUSR2
	    if (t.flags & 1)		// ensure it was resumeHandler()
		break;
	}

	// Restore all registers
	asm
	{
	    popa	;
	}
    }

    /**********************************
     * This gets called when a thread gets SIGUSR2.
     */

    extern (C) static void resumeHandler(int sig)
    {
	Thread t = getThis();

	t.flags |= 1;
    }

    static void* getESP()
    {
	asm
	{   naked	;
	    mov EAX,ESP	;
	    ret		;
	}
    }
}


}

