// Written in the D programming language
// Put in the public domain by Bartosz Milewski

/**
Part of the D programming language runtime library.
Implements _Object monitors used by $(D synchronized) methods and blocks

Author: Bartosz Milewski, Walter Bright
Macros:
    WIKI = Phobos/Monitor
*/

module monitor;

import std.c.stdlib : malloc, free;
import std.c.string : memcpy;

// Don't publicize it: it wonn't work with signals and slots (see std.signals)
T construct(T:Object, A...)(A args)
{
    ClassInfo info = T.classinfo;
    void * p = malloc(info.init.length);
    memcpy(p, info.init.ptr, info.init.length);
    T obj = cast(T)p;
    static if (is(typeof(obj._ctor) == function))
        obj._ctor(args);
    return obj;
}

void destroy(T:Object)(T obj)
{
    static if (is(typeof(obj._dtor) == function))
        obj._dtor();
    free(cast(void*) obj);
}

/* This is what _Object will look like: */
class _Object
{
public:
    FatLock _fatLock;
}

// Global mutex used when lazily initializing _Object._fatLock
OsMutex _monitor_critsect;

class FatLock
{
    void delegate(_Object) [] delegates;
    OsMutex mon;
public:
    void lock() { mon.lock; }
    void unlock() { mon.unlock; }
}

// Called only once by a single thread during startup
extern(C) void _STI_monitor_staticctor()
{
    _monitor_critsect = construct!(OsMutex)();
}

extern(C) void _STD_monitor_staticdtor()
{
    destroy(_monitor_critsect);
}

extern(C) void _d_notify_release(_Object);

// Called when entering synchronized block
extern(C) 
void _d_monitorenter(_Object obj)
{
    //printf("_d_monitorenter(%p), %p\n", obj, obj->monitor);
    // Warning: data race
    if (obj._fatLock is null)
    {
	scope lock = new OsLock (_monitor_critsect);
        if (obj._fatLock is null) // if, in the meantime, another thread didn't set it
        {
	    obj._fatLock = new FatLock;
        }
    }
    obj._fatLock.lock;
}

extern(C) 
void _d_monitorexit(_Object obj)
{
    assert(obj._fatLock !is null);
    obj._fatLock.unlock;
}

/***************************************
 * Called by garbage collector when _Object is free'd.
 */

extern(C) 
void _d_monitorrelease(_Object obj)
{
    if (obj._fatLock !is null)
    {
	_d_notify_release(obj);

        delete obj._fatLock;
        obj._fatLock = null;
    }
}

/**
Scoped locking of OsMutex
*/
scope class OsLock
{
public:
    this (OsMutex mtx)
    {
        _mtx = mtx;
        _mtx.lock ();
    }
    ~this ()
    {
        _mtx.unlock ();
    }
private:
    OsMutex _mtx;
}

/* ================================ Windows ================================= */

version (Windows)
{

private import std.c.windows.windows;

/**
Encapsulates mutual exclusion provided by the underlying operating system. 
$(D OsMutex) is re-entrant, i.e., 
the same thread may lock it multiple times. 
It must unlock it the same number of times.

Note: On Windows, it's implemented as $(D CriticalSection); on Linux, using pthreads.

*/
class OsMutex
{
public:
    this()
    {
        InitializeCriticalSection (&_critSection);
    }
    ~this()
    {
        DeleteCriticalSection (&_critSection);
    }
    final void lock() 
    {
        EnterCriticalSection (&_critSection);
    }
    final void unlock() 
    { 
        LeaveCriticalSection (&_critSection);
    }
private:
    CRITICAL_SECTION    _critSection;
}

} // Windows

/* ================================ linux ================================= */
version (linux)
{

private import std.c.linux.linux;
private import std.c.linux.linuxextern;
extern(C) {
    pthread_mutexattr_t _monitors_attr;
}

class OsMutex
{
public:
    this()
    {
        pthread_mutex_init(&_mtx, _monitors_attr);
    }
    ~this()
    {
        pthread_mutex_destroy(&_mtx);
    }
    final void lock()
    {
        pthread_mutex_lock(&_mtx);
    }
    final void unlock()
    {
        pthread_mutex_unlock(&_mtx);
    }
private:
    pthread_mutex_t _mtx;
}

} // linux

