// Written in the D programming language

/*
 *  Copyright (C) 2002-2007 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

/**************************
 * The thread module defines the class $(B Thread).
 *
 * $(B Thread) is the basis
 * for writing multithreaded applications. Each thread
 * has a unique instance of class $(B Thread) associated with it.
 * It is important to use the $(B Thread) class to create and manage
 * threads as the garbage collector needs to know about all the threads.
 *
 * Authors: Walter Bright, Bartosz Milewski
 *
 * Macros:
 *      WIKI=Phobos/StdThread
 */

module std.thread;

import std.c.stdio;

//debug=thread;

version (Win32)
{
private import std.c.windows.windows;

extern (Windows) alias uint (*stdfp)(void *);

extern (C)
    thread_hdl _beginthreadex(void* security, uint stack_size,
        stdfp start_addr, void* arglist, uint initflag,
        thread_id* thrdaddr);

private const uint  WAIT_TIMEOUT = 258;

/**
 * The type of the thread handle used by the operating system.
 * For Windows, it is equivalent to a HANDLE from windows.d.
 */
alias HANDLE thread_hdl;

alias uint thread_id;

} // Win32
version (linux)
{
private import std.c.linux.linux;
private import std.c.linux.linuxextern;

alias uint pthread_t;
extern (C) alias void (*__sighandler_t)(int);

struct sigset_t
{
    uint __val[1024 / (8 * uint.sizeof)];
}

enum SA_RESTART = 0x10000000u;

struct sigaction_t
{
    __sighandler_t sa_handler;
    sigset_t sa_mask;
    int sa_flags;
    void (*sa_restorer)();
}

struct pthread_attr_t
{
    int __detachstate;
    int __schedpolicy;
    struct __schedparam
    {
        int __sched_priority;
    }
    int __inheritsched;
    int __scope;
    size_t __guardsize;
    int __stackaddr_set;
    void *__stackaddr;
    size_t __stacksize;
}

unittest
{
    assert(sigset_t.sizeof  == 128);
    assert(sigaction_t.sizeof == 140);
    assert(sem_t.sizeof == 16);
}

extern (C)
{
    int pthread_create(pthread_t*, void*, void* (*)(void*), void*);
    int pthread_join(pthread_t, void**);
    int pthread_kill(pthread_t, int);
    pthread_t pthread_self();
    int pthread_equal(pthread_t, pthread_t);
    int pthread_attr_init(pthread_attr_t*);
    int pthread_attr_setstacksize(pthread_attr_t *, size_t);
    int pthread_cancel(pthread_t);
    int pthread_setcancelstate(int, int*);
    int pthread_setcanceltype(int, int*);
    int sched_yield();
    int sigfillset(sigset_t*);
    int sigdelset(sigset_t*, int);
    int sigaction(int, sigaction_t*, sigaction_t*);
    int sigsuspend(sigset_t*);

    enum
    {
        PTHREAD_CANCEL_ENABLE,
        PTHREAD_CANCEL_DISABLE
    }

    enum
    {
        PTHREAD_CANCEL_DEFERRED,
        PTHREAD_CANCEL_ASYNCHRONOUS
    }
}
} // linux

/**
 * Thrown for errors.
 */
class ThreadError : Error
{
    this(string s)
    {
        super("Thread error: " ~ s);
    }
}


/**
 * One of these is created for each thread.
 */
class Thread
{
    /**
     * Constructor used by classes derived from Thread that override main(). 
     * The optional stacksize parameter default value of 0 will cause threads
     * to be created with the default size for the executable - Dave Fladebo
     */
    this(size_t stacksize = 0)
    {
        init(stacksize);
    }

    /**
     * Constructor used by classes derived from Thread that override run().
     */
    this(int (*fp)(void *), void *arg, size_t stacksize = 0)
    {
        this.fp = fp;
        this.arg = arg;
        init(stacksize);
    }

    /**
     * Constructor used by classes derived from Thread that override run().
     */
    this(int delegate() dg, size_t stacksize = 0)
    {
        this.dg = dg;
        init(stacksize);
    }

    /**
     * Destructor
     *
     * If the thread hasn't been joined yet, detach it.
     */
version (Win32)
{
    ~this()
    {
        if (state != TS.FINISHED)
            CloseHandle(hdl);
    }
} // Win32
version (linux)
{
    ~this()
    {
        pthread_cond_destroy(&waitCond);
        pthread_mutex_destroy(&waitMtx);
        if (state != TS.FINISHED)
            pthread_detach(id);
    }
} // linux
    /**
     * The handle to this thread assigned by the operating system. This is set
     * to thread_id.init if the thread hasn't been started yet.
     */
version (Win32)
{
    thread_hdl hdl;

    void* stackBottom;
} // Win32
version (linux)
{
    pthread_t id;
    void* stackBottom;
    void* stackTop;
} // linux

    /**
     * Create a new thread and start it running. The new thread initializes
     * itself and then calls run(). start() can only be called once.
     */
version (Win32)
{
    void start()
    {
        synchronized (Thread.classinfo)
        {
            if (state != TS.INITIAL)
                error("already started");

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

            state = TS.RUNNING;
            hdl = _beginthreadex(null, cast(uint)stacksize, &threadstart, cast(void*)this, 0, &id);
            if (hdl == cast(thread_hdl)0)
            {
                allThreads[idx] = null;
                nthreads--;
                state = TS.FINISHED;
                idx = -1;
                error("failed to start");
            }
        }
    }
} // Win32
version (linux)
{
    void start()
    {
        if (state != TS.INITIAL)
            error("already started");

        synchronized (Thread.classinfo)
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
        //printf("creating thread x%x\n", this);
        //result = pthread_create(&id, null, &threadstart, this);
        // Create with thread attributes to allow non-default stack size - Dave Fladebo
        int result = pthread_create(&id, &threadAttrs, &threadstart, cast(void*)this);
        if (result)
        {   state = TS.FINISHED;
            synchronized (Thread.classinfo) allThreads[idx] = null;
            idx = -1;
            error("failed to start");   // BUG: should report errno
        }
        //printf("t = x%x, id = %d\n", this, id);
    }
} // linux

    /**
     * Entry point for a thread. If not overridden, it calls the function
     * pointer fp and argument arg passed in the constructor, or the delegate
     * dg.
     * Returns: the thread exit code, which is normally 0.
     */
    int run()
    {
        if (fp)
            return fp(arg);
        else if (dg)
            return dg();
        assert(0);
    }

    /*****************************
     * Wait for this thread to terminate.
     * Simply returns if thread has already terminated.
     * Throws: $(B ThreadError) if the thread hasn't begun yet or
     * is called on itself.
     */
version (Win32)
{
    void wait()
    {
        if (isSelf)
            error("wait on self");
        if (state != TS.FINISHED)
        {   DWORD dw;

            dw = WaitForSingleObject(hdl, 0xFFFFFFFF);
            state = TS.FINISHED;
            CloseHandle(hdl);
            hdl = null;
        }
    }
} // Win32
version (linux)
{
    void wait()
    {
        if (isSelf)
            error("wait on self");

        if (state != TS.FINISHED)
        {
            void *value;

            int result = pthread_join(id, &value);
            state = TS.FINISHED;
            if (result)
                error("failed to wait");
        }
    }
} // linux

    /******************************
     * Wait for this thread to terminate or until milliseconds time has
     * elapsed, whichever occurs first.
     * Simply returns if thread has already terminated.
     * Throws: $(B ThreadError) if the thread hasn't begun yet or
     * is called on itself.
     */
version (Win32)
{
    void wait(uint milliseconds)
    {
        if (isSelf)
            error("wait on self");
        if (state != TS.FINISHED)
        {   DWORD dw;

            dw = WaitForSingleObject(hdl, milliseconds);
            if (dw != WAIT_TIMEOUT)
            {
                state = TS.FINISHED;
                CloseHandle(hdl);
                hdl = null;
            }
        }
    }
} // Win32
version (linux)
{
    void wait(uint milliseconds)
    {
        // Implemented for POSIX systems by Dave Fladebo
        if (isSelf)
            error("wait on self");
        if (state != TS.FINISHED)
        {
            timespec ts; 
            timeval  tv;

            pthread_mutex_lock(&waitMtx);
            gettimeofday(&tv, null);
            ts.tv_sec = cast(__time_t)tv.tv_sec + cast(__time_t)(milliseconds / 1_000);
            ts.tv_nsec = (tv.tv_usec * 1_000) + ((milliseconds % 1_000) * 1_000_000);
            if (ts.tv_nsec > 1_000_000_000)
            {
                ts.tv_sec += 1;
                ts.tv_nsec -= 1_000_000_000;
            }
            if (pthread_cond_timedwait(&waitCond, &waitMtx, &ts))
            {
                int oldstate, oldtype;
                pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, &oldstate);
                pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, &oldtype);

                if (pthread_cancel(id))     // thread was not completed in the timeout period, cancel it
                {
                    pthread_mutex_unlock(&waitMtx);
                    error("cannot terminate thread via timed wait");
                }

                pthread_setcancelstate(oldstate, null);
                pthread_setcanceltype(oldtype, null);

                state = TS.TERMINATED;
                synchronized (Thread.classinfo)
                {
                    allThreads[idx] = null;
                    idx = -1;
                    nthreads--;
                }

                pthread_mutex_unlock(&waitMtx);
            }
            else
            {
                pthread_mutex_unlock(&waitMtx);
                wait(); // condition has been signalled as complete (see threadstart()), terminate normally
            }
        }
    }
} // linux

    /**
     * The state of a thread.
     */
    enum TS
    {
        INITIAL,        /// The thread hasn't been started yet.
        RUNNING,        /// The thread is running or paused.
        TERMINATED,     /// The thread has ended.
        FINISHED        /// The thread has been cleaned up
    }

    /**
     * Returns the state of a thread.
     */
    TS getState()
    {
        return state;
    }

    /**
     * The priority of a thread.
     */
version (Win32)
{
    enum PRIORITY
    {
        INCREASE,       /// Increase thread priority
        DECREASE,       /// Decrease thread priority
        IDLE,           /// Assign thread low priority
        CRITICAL,       /// Assign thread high priority
        NORMAL,
    }
} // Win32
version (linux)
{
    enum PRIORITY
    {
        INCREASE,
        DECREASE,
        IDLE,
        CRITICAL
    }
} // linux

    /**
     * Adjust the priority of this thread.
     * Throws: ThreadError if cannot set priority
     */
version (Win32)
{
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
            case PRIORITY.NORMAL:
                nPriority = THREAD_PRIORITY_NORMAL;
                break;
            default:
                assert(0);
        }

        if (SetThreadPriority(hdl, nPriority) == THREAD_PRIORITY_ERROR_RETURN)
            error("set priority");
    }
} // Win32
version (linux)
{
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
} // linux

    /**
     * Returns true if this thread is the current thread.
     */
version (Win32)
{
    bool isSelf()
    {
        //printf("id = %d, self = %d\n", id, pthread_self());
        return (id == GetCurrentThreadId());
    }
} // Win32
version (linux)
{
    int isSelf()
    {
        //printf("id = %d, self = %d\n", id, pthread_self());
        return pthread_equal(pthread_self(), id);
    }
} // linux

    /**
     * Returns a reference to the Thread for the thread that called the
     * function.
     */
version (Win32)
{
    static Thread getThis()
    {
        //printf("getThis(), allThreadsDim = %d\n", allThreadsDim);
        thread_id id = GetCurrentThreadId();
        for (int i = 0; i < allThreadsDim; i++)
        {
            Thread t = allThreads[i];
            if (t && id == t.id)
            {
                return t;
            }
        }
        printf("didn't find it\n");
        assert(0);
    }
} // Win32
version (linux)
{
    static Thread getThis()
    {
        //printf("getThis(), allThreadsDim = %d\n", allThreadsDim);
        pthread_t id = pthread_self();
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
        printf("didn't find it\n");
        assert(null);
    }
} // linux

    /**
     * Returns an array of all the threads currently running.
     */
    static Thread[] getAll()
    {
        synchronized (Thread.classinfo) return allThreads[0 .. allThreadsDim];
    }

    /**
     * Suspend execution of this thread.
     */
version (Win32)
{
    void pause()
    {
        if (state != TS.RUNNING || SuspendThread(hdl) == 0xFFFFFFFF)
            error("cannot pause");
    }
} // Win32
version (linux)
{
    void pause()
    {
        if (state == TS.RUNNING)
        {
            if (pthread_kill(id, SIGUSR1))
                error("cannot pause");
            else
                sem_wait(&flagSuspend); // wait for acknowledgement
        }
        else
            error("cannot pause");
    }
} // linux

    /**
     * Resume execution of this thread.
     */
version (Win32)
{
    void resume()
    {
        if (state != TS.RUNNING || ResumeThread(hdl) == 0xFFFFFFFF)
            error("cannot resume");
    }
} // Win32
version (linux)
{
    void resume()
    {
        if (state == TS.RUNNING)
        {
            if (pthread_kill(id, SIGUSR2))
                error("cannot resume");
        }
        else
            error("cannot resume");
    }
} // linux

    /**
     * Suspend execution of all threads but this thread.
     */
version (Win32)
{
    static void pauseAll()
    {
        synchronized (Thread.classinfo)
        {
            if (nthreads > 1)
            {
                thread_id thisid = GetCurrentThreadId();

                for (int i = 0; i < allThreadsDim; i++)
                {
                    Thread t = allThreads[i];
                    if (t && t.id != thisid && t.state == TS.RUNNING)
                        t.pause();
                }
            }
        }
    }
} // Win32
version (linux)
{
    static void pauseAll()
    {
        synchronized (Thread.classinfo)
        {
            if (nthreads > 1)
            {
                pthread_t thisid = pthread_self();
                int npause = 0;

                for (int i = 0; i < allThreadsDim; i++)
                {
                    Thread t = allThreads[i];
                    if (t && !pthread_equal(thisid, t.id) && t.state == TS.RUNNING)
                    {
                        if (pthread_kill(t.id, SIGUSR1))
                            t.error("cannot pause");
                        else
                            npause++;   // count of paused threads
                    }
                }

                // Wait for each paused thread to acknowledge
                while (npause--)
                {
                    sem_wait(&flagSuspend);
                }
            }
        }
    }
} // linux

    /**
     * Resume execution of all paused threads.
     */
version (Win32)
{
    static void resumeAll()
    {
        synchronized (Thread.classinfo)
        {
            if (nthreads > 1)
            {
                thread_id thisid = GetCurrentThreadId();

                for (int i = 0; i < allThreadsDim; i++)
                {
                    Thread t = allThreads[i];
                    if (t && t.id != thisid && t.state == TS.RUNNING)
                        t.resume();
                }
            }
        }
    }
} // Win32
version (linux)
{
    static void resumeAll()
    {
        synchronized (Thread.classinfo)
        {
            if (nthreads > 1)
            {
                pthread_t thisid = pthread_self();

                for (int i = 0; i < allThreadsDim; i++)
                {
                    Thread t = allThreads[i];
                    if (t && t.id != thisid && t.state == TS.RUNNING)
                        t.resume();
                }
            }
        }
    }
} // linux

    /**
     * Give up the remainder of this thread's time slice.
     */
version (Win32)
{
    static void yield()
    {
        Sleep(0);
    }
} // Win32
version (linux)
{
    static void yield()
    {
        sched_yield();
    }
} // linux

    /**
     *
     */
    static uint nthreads = 1;
    static __thread uint myCompactThreadId; // 11-bit ((idx << 1) | 1)
    enum uint TID_BITS = 11;

  private:

    static uint allThreadsDim;
    // On Linux, set max to Windows equivalent for compatibility.
    // pthread_create will fail gracefully if stack limit
    // is reached prior to allThreads max.
    enum uint MAX_THREADS = (1 << (TID_BITS - 1)); // 0x400
    static Thread[MAX_THREADS] allThreads;  // length matches value in C runtime
    static assert(MAX_THREADS == 0x400);

    TS state;
    int idx = -1;                       // index into allThreads[]

    int (*fp)(void *);
    void *arg;

    int delegate() dg;

version (Win32)
{
    thread_id id;
    size_t stacksize = 0;
} // Win32
version (linux)
{
    static sem_t flagSuspend;
    int flags = 0;

    pthread_attr_t threadAttrs;
    pthread_mutex_t waitMtx;
    pthread_cond_t waitCond;
} // linux

    void error(string msg)
    {
        throw new ThreadError(msg);
    }

    void SetMyCompactThreadId()
    {
        myCompactThreadId = ((idx << 1) | 1);
    }

version (Win32)
{
    void init(size_t stacksize = 0)
    {
        this.stacksize = stacksize;
    }
} // Win32
version (linux)
{
    void init(size_t stackSize)
    {
        // set to default values regardless
        // passing this as the 2nd arg. for pthread_create()
        // w/o setting an attribute is equivalent to passing null.
        pthread_attr_init(&threadAttrs);
        if (stackSize > 0)
        {
            if (pthread_attr_setstacksize(&threadAttrs,stackSize))
                error("cannot set stack size");
        }

        if (pthread_mutex_init(&waitMtx, null))
            error("cannot initialize wait mutex");

        if (pthread_cond_init(&waitCond, null))
            error("cannot initialize wait condition");
    }
} // linux
   /* ***********************************************
     * This is just a wrapper to interface between C rtl and Thread.run().
     */

version (Win32)
{
    extern (Windows) static uint threadstart(void *p)
    {
        Thread t = cast(Thread)p;
        t.SetMyCompactThreadId();
        int result;

        debug (thread) printf("Starting thread %d\n", t.idx);
        t.stackBottom = os_query_stackBottom();
        try
        {
            result = t.run();
        }
        catch (Object o)
        {
            fprintf(stderr, "Error: %.*s\n", o.toString());
            result = 1;
        }

        debug (thread) printf("Ending thread %d\n", t.idx);
        synchronized (Thread.classinfo)
        {
            allThreads[t.idx] = null;
            nthreads--;
            t.state = TS.TERMINATED;
            t.idx = -1;
        }
        return result;
    }
} // Win32
version (linux)
{
    /************************************************
     * This is just a wrapper to interface between C rtl and Thread.run().
     */

    extern (C) static void *threadstart(void *p)
    {
        Thread t = cast(Thread)p;
        t.SetMyCompactThreadId();
        int result;

        debug (thread) printf("Starting thread x%x (%d)\n", t, t.idx);

        // Need to set t.id here, because thread is off and running
        // before pthread_create() sets it.
        t.id = pthread_self();

        t.stackBottom = getESP();
        try
        {
            if(t.state == TS.RUNNING)
                pthread_cond_signal(&t.waitCond);     // signal the wait condition (see the timed wait function)
            result = t.run();
        }
        catch (Object o)
        {
            fprintf(stderr, "Error: %.*s\n", o.toString());
            result = 1;
        }

        debug (thread) printf("Ending thread %d\n", t.idx);
        t.state = TS.TERMINATED;
        synchronized (Thread.classinfo)
        {
            allThreads[t.idx] = null;
            t.idx = -1;
            nthreads--;
        }
        return cast(void*)result;
    }
} // linux


    /**************************************
     * Create a Thread for global main().
     */

version (Win32)
{
    public static void thread_init()
    {
        Thread t = new Thread();

        t.state = TS.RUNNING;
        t.id = GetCurrentThreadId();
        t.hdl = Thread.getCurrentThreadHandle();
        t.stackBottom = os_query_stackBottom();

        assert(!allThreads[0]);
        allThreads[0] = t;
        allThreadsDim = 1;
        t.idx = 0;
        t.SetMyCompactThreadId();
   }
} // Win32
version (linux)
{
    public static void thread_init()
    {
        Thread t = new Thread();

        t.state = TS.RUNNING;
        t.id = pthread_self();

        version (none)
        {
            // See discussion: http://autopackage.org/forums/viewtopic.php?t=22
            static void** libc_stack_end;

            if (libc_stack_end == libc_stack_end.init)
            {
                void* handle = dlopen(null, RTLD_NOW);
                libc_stack_end = cast(void **)dlsym(handle, "__libc_stack_end");
                dlclose(handle);
            }
            t.stackBottom = *libc_stack_end;
        }
        else
        {
            t.stackBottom = cast(void*)__libc_stack_end;
        }

        assert(!allThreads[0]);
        allThreads[0] = t;
        allThreadsDim = 1;
        t.idx = 0;
        t.SetMyCompactThreadId();

        /* Install signal handlers so we can suspend/resume threads
         */

        int result;
        sigaction_t sigact;
        result = sigfillset(&sigact.sa_mask);
        if (result)
            goto Lfail;
        sigact.sa_handler = &pauseHandler;
        sigact.sa_flags = SA_RESTART;
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
        t.error("cannot initialize threads");
    }
} // linux

version (Win32)
{
    static ~this()
    {
        if (allThreadsDim)
        {
            CloseHandle(allThreads[0].hdl);
            allThreads[0].hdl = GetCurrentThread();
        }
    }
} // Win32
version (linux)
{
    /**********************************
     * This gets called when a thread gets SIGUSR1.
     */

    extern (C) static void pauseHandler(int sig)
    {
        int result;

        // Save all registers on the stack so they'll be scanned by the GC
        asm
        {
            pusha   ;
        }

        assert(sig == SIGUSR1);

        sigset_t sigmask;
        result = sigfillset(&sigmask);
        assert(result == 0);
        result = sigdelset(&sigmask, SIGUSR2);
        assert(result == 0);

        Thread t = getThis();
        t.stackTop = getESP();
        t.flags &= ~1;
        // Release the semaphore _after_ stackTop is set
        sem_post(&flagSuspend);
        while (1)
        {
            sigsuspend(&sigmask);  // suspend until SIGUSR2
            if (t.flags & 1)       // ensure it was resumeHandler()
                break;
        }

        // Restore all registers
        asm
        {
            popa    ;
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

    public static void* getESP()
    {
        asm
        {   naked       ;
            mov EAX,ESP ;
            ret         ;
        }
    }
} // linux
          
    /********************************************
     * Returns the handle of the current thread.
     * This is needed because GetCurrentThread() always returns -2 which
     * is a pseudo-handle representing the current thread.
     * The returned thread handle is a windows resource and must be explicitly
     * closed.
     * Many thanks to Justin (jhenzie@mac.com) for figuring this out
     * and providing the fix.
     */
version (Win32)
{
    static thread_hdl getCurrentThreadHandle()
    {
        thread_hdl currentThread = GetCurrentThread();
        thread_hdl actualThreadHandle;

        //thread_hdl currentProcess = cast(thread_hdl)-1;
        thread_hdl currentProcess = GetCurrentProcess(); // http://www.digitalmars.com/drn-bin/wwwnews?D/21217


        uint access = cast(uint)0x00000002;

        DuplicateHandle(currentProcess, currentThread, currentProcess,
                         &actualThreadHandle, cast(uint)0, TRUE, access);

        return actualThreadHandle;
     }
} // Win32

} // Thread


version (Win32)
{
/**********************************************
 * Determine "bottom" of stack (actually the top on Win32 systems).
 */

void *os_query_stackBottom()
{
    asm
    {
        naked                   ;
        mov     EAX,FS:4        ;
        ret                     ;
    }
}
} // Win32

unittest
{
	printf("Start thread test\n");
    class Foo
    {
        int _i, _j;
        synchronized void Inc()
        {
            verify();
            ++_i;
            ++_j;
            verify();
        }
        synchronized void verify()
        {
            assert(_i == _j);
        }
    }

    auto foo = new Foo;

    int test()
    {
        assert(Thread.getThis.isSelf);
        Thread.getThis.yield;
        for (int i = 0; i < 1000; ++i)
            foo.Inc;
        return 0;
    }
    Thread[100] threads;
    for (int i = 0; i < 100; ++i)
        threads[i] = new Thread(&test);
    for (int i = 0; i < 100; ++i)
        threads[i].start;
    for (int i = 0; i < 100; ++i)
        threads[i].wait;
    for (int i = 0; i < 100; ++i)
        assert(threads[i].getState == Thread.TS.FINISHED);
	printf("Thread test successful\n");
}
