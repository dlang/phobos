// Copyright (c) 2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

//debug=thread;

import windows;

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
	t.hdl = GetCurrentThread();
	t.stackBottom = os_query_stackBottom();
	synchronized (threadLock)
	{
	    assert(!allThreads[0]);
	    allThreads[0] = t;
	    allThreadsDim = 1;
	    t.idx = 0;
	}
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


