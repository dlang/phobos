// Written in the D programming language
// Put in the public domain by Bartosz Milewski

/**
Defines thread synchronization primitives.

Note:

A lot of synchronization can be done using built-in monitors
by defining $(D synchronized) methods. 
(every object is a potential monitor--behavior inherited from $(D Object).)
Use std.synchro for those cases
where simple monitors are not sufficient.

Author: Bartosz Milewski
Macros:
      WIKI=Phobos/StdSynchro
*/

module std.synchro;

import std.c.stdio;

//debug=thread;

/**
Defines a common interface for lockable objects (e.g., mutexes).
*/
interface Lockable
{
    void lock();
    void unlock();
}

/**
Scoped object that locks a $(D Lockable) for the duration of a scope.

Note:

If the mutex is associated with an object, and the lock is taken for the 
whole scope of a method, it's probably better to declare the method sd $(D synchronized) 
and use the mutex that's built into every $(D Object).

Example:
----
import std.synchro;

Mutex mtx;

static this()
{
    mtx = new Mutex;
}

void f()
{
    scope lock = new Lock(mtx);
    // access shared data
    // end of scope: mutex released
}
----
*/
scope class Lock
{
public:
    this (Lockable mtx)
    {
        _mtx = mtx;
        _mtx.lock ();
    }
    ~this ()
    {
        _mtx.unlock ();
    }
private:
    Lockable _mtx;
}

/* ================================ Windows ================================= */

version (Windows)
{

private import std.c.windows.windows;

/**
Implements mutual exclusion. $(D Mutex) is re-entrant, i.e., 
the same thread may lock it multiple times. 
It must unlock it the same number of times.

Note: On Windows, it's implemented as $(D CriticalSection); on Linux, using pthreads.

Example: See the $(D Lock) example
*/
class Mutex: Lockable
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
    override void lock() 
    {
        EnterCriticalSection (&_critSection);
    }
    override void unlock() 
    { 
        LeaveCriticalSection (&_critSection);
    }
/**
    Returns $(D true) if lock taken. 
*/
    bool trylock()
    {
        return TryEnterCriticalSection(&_critSection) != 0; // lock taken
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
    extern pthread_mutexattr_t _monitors_attr;
}

class Mutex: Lockable
{
public:
    this()
    {
        pthread_mutex_init(&_mtx, &_monitors_attr);
    }
    ~this()
    {
        pthread_mutex_destroy(&_mtx);
    }
    override void lock()
    {
        pthread_mutex_lock(&_mtx);
    }
    override void unlock()
    {
        pthread_mutex_unlock(&_mtx);
    }
    bool trylock()
    {
        return pthread_mutex_trylock(&_mtx) == 0; // lock taken
    }
private:
    pthread_mutex_t _mtx;
}

} // linux

version(unittest)
{
    import std.synchro;
    import std.thread;
    import std.stdio;
    
    int glob;}

unittest
{
    //writeln("_monitors_attr = ", _monitors_attr.__mutexkind);
    Mutex mtx = new Mutex;

    void inc_glob_twice()
    {
        scope lock = new Lock(mtx);
        assert(glob % 2 == 0);
        glob++;
        {
            // Test lock re-entrancy
            scope lock2 = new Lock(mtx);
            glob++;
        }
    }
    
    int f()
    {
        for (int i = 0; i < 1000; ++i)
            inc_glob_twice();
        return 0;
    }
    
    auto thr1 = new Thread(&f);
    auto thr2 = new Thread(&f);
    thr1.start;
    thr2.start;
    thr1.wait;
    thr2.wait;
    //writeln("end synchro");
}

