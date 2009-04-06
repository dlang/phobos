/* Written by Walter Bright
 * http://www.digitalmars.com
 * Placed into public domain.
 */

module std.c.freebsd.pthread;

version (FreeBSD) { } else { static assert(0); }

import std.c.freebsd.freebsd;

extern (C):

enum
{
    PTHREAD_DESTRUCTOR_ITERATIONS = 4,
    PTHREAD_KEYS_MAX = 256,
    PTHREAD_STACK_MIN = 2048,
    PTHREAD_THREADS_MAX = uint.max,
    PTHREAD_BARRIER_SERIAL_THREAD = -1
}

enum
{
    PTHREAD_DETACHED = 1,
    PTHREAD_SCOPE_SYSTEM = 2,
    PTHREAD_INHERIT_SCHED = 4,
    PTHREAD_NOFLOAT = 8,
    PTHREAD_CREATE_DETACHED = PTHREAD_DETACHED,
    PTHREAD_CREATE_JOINABLE = 0,
    PTHREAD_SCOPE_PROCESS = 0,
    PTHREAD_EXPLICIT_SCHED = 0
}

enum
{
    PTHREAD_PROCESS_PRIVATE = 0,
    PTHREAD_PROCESS_SHARED = 1
}

enum
{
    PTHREAD_CANCEL_ENABLE = 0,
    PTHREAD_CANCEL_DISABLE = 1,
    PTHREAD_CANCEL_DEFERRED = 0,
    PTHREAD_CANCEL_ASYNCHRONOUS = 2,
    PTHREAD_CANCELED = cast(void*)1
}

enum
{
    PTHREADS_NEEDS_INIT = 0,
    PTHREAD_DONE_INIT = 1
}

enum
{
    PTHREAD_PRIO_NONE = 0,
    PTHREAD_PRIO_INHERIT = 1,
    PTHREAD_PRIO_PROTECT = 2
}

enum pthread_mutextype
{
    PTHREAD_MUTEX_ERRORCHECK = 1,
    PTHREAD_MUTEX_RECURSIVE = 2,
    PTHREAD_MUTEX_NORMAL = 3,
    PTHREAD_MUTEX_ADAPTIVE_NP = 4,
    PTHREAD_MUTEX_TYPE_MAX,
    PTHREAD_MUTEX_DEFAULT = PTHREAD_MUTEX_ERRORCHECK
}

typedef void* pthread_t;
typedef void* pthread_attr_t;
typedef void* pthread_mutex_t;
typedef void* pthread_mutexattr_t;
typedef void* pthread_cond_t;
typedef void* pthread_condattr_t;
typedef int   pthread_key_t;
typedef void* pthread_rwlock_t;
typedef void* pthread_rwlockattr_t;
typedef void* pthread_barrier_t;
typedef void* pthread_barrierattr_t;
typedef void* pthread_spinlock_t;
typedef void* pthread_addr_t;

alias void* function(void*) pthread_startroutine_t;

struct pthread_once_t
{
    int state;
    pthread_mutex_t mutex;
}

int pthread_atfork(void function(), void function(), void function());
int pthread_attr_destroy(pthread_attr_t*);
int pthread_attr_getdetachstate(in pthread_attr_t*, int*);
int pthread_attr_getguardsize(in pthread_attr_t*, size_t*);
int pthread_attr_getinheritsched(in pthread_attr_t*, int*);
int pthread_attr_getschedparam(in pthread_attr_t*, sched_param*);
int pthread_attr_getschedpolicy(in pthread_attr_t*, int*);
int pthread_attr_getscope(in pthread_attr_t*, int*);
int pthread_attr_getstack(in pthread_attr_t*, void**, size_t*);
int pthread_attr_getstackaddr(in pthread_attr_t*, void**);
int pthread_attr_getstacksize(in pthread_attr_t*, size_t*);
int pthread_attr_init(pthread_attr_t*);
int pthread_attr_setdetachstate(pthread_attr_t*, int);
int pthread_attr_setguardsize(pthread_attr_t*, size_t);
int pthread_attr_setinheritsched(pthread_attr_t*, int);
int pthread_attr_setschedparam(pthread_attr_t*, in sched_param*);
int pthread_attr_setschedpolicy(pthread_attr_t*, int);
int pthread_attr_setscope(pthread_attr_t*, int);
int pthread_attr_setstack(pthread_attr_t*, void*, size_t);
int pthread_attr_setstackaddr(pthread_attr_t*, void*);
int pthread_attr_setstacksize(pthread_attr_t*, size_t);
int pthread_barrier_destroy(pthread_barrier_t*);
int pthread_barrier_init(pthread_barrier_t*, in pthread_barrierattr_t*, uint);
int pthread_barrier_wait(pthread_barrier_t*);
int pthread_barrierattr_destroy(pthread_barrierattr_t*);
int pthread_barrierattr_getpshared(in pthread_barrierattr_t*, int*);
int pthread_barrierattr_init(pthread_barrierattr_t*);
int pthread_barrierattr_setpshared(pthread_barrierattr_t*, int);
int pthread_cancel(pthread_t);
int pthread_cond_broadcast(pthread_cond_t*);
int pthread_cond_destroy(pthread_cond_t*);
int pthread_cond_init(pthread_cond_t*, in pthread_condattr_t*);
int pthread_cond_signal(pthread_cond_t*);
int pthread_cond_timedwait(pthread_cond_t*, pthread_mutex_t*, in timespec*);
int pthread_cond_wait(pthread_cond_t*, pthread_mutex_t*);
int pthread_condattr_destroy(pthread_condattr_t*);
int pthread_condattr_getclock(in pthread_condattr_t*, clockid_t*);
int pthread_condattr_getpshared(in pthread_condattr_t*, int*);
int pthread_condattr_init(pthread_condattr_t*);
int pthread_condattr_setclock(pthread_condattr_t*, clockid_t);
int pthread_condattr_setpshared(pthread_condattr_t*, int);
int pthread_create(pthread_t*, in pthread_attr_t*, void* function(void*), void*);
int pthread_detach(pthread_t);
int pthread_equal(pthread_t, pthread_t);
int pthread_getconcurrency();
int pthread_getprio(pthread_t);
int pthread_getschedparam(pthread_t pthread, int*, sched_param*);
int pthread_join(pthread_t, void**);
int pthread_key_create(pthread_key_t*, void function(void*));
int pthread_key_delete(pthread_key_t);
int pthread_kill(pthread_t, int);
int pthread_mutex_destroy(pthread_mutex_t*);
int pthread_mutex_getprioceiling(pthread_mutex_t*, int*);
int pthread_mutex_init(pthread_mutex_t*, in pthread_mutexattr_t*);
int pthread_mutex_lock(pthread_mutex_t*);
int pthread_mutex_setprioceiling(pthread_mutex_t*, int, int*);
int pthread_mutex_timedlock(pthread_mutex_t*, in timespec*);
int pthread_mutex_trylock(pthread_mutex_t*);
int pthread_mutex_unlock(pthread_mutex_t*);
int pthread_mutexattr_destroy(pthread_mutexattr_t*);
int pthread_mutexattr_getprioceiling(pthread_mutexattr_t*, int*);
int pthread_mutexattr_getprotocol(pthread_mutexattr_t*, int*);
int pthread_mutexattr_getpshared(in pthread_mutexattr_t*, int*);
int pthread_mutexattr_gettype(pthread_mutexattr_t*, int*);
int pthread_mutexattr_init(pthread_mutexattr_t*);
int pthread_mutexattr_setprioceiling(pthread_mutexattr_t*, int);
int pthread_mutexattr_setprotocol(pthread_mutexattr_t*, int);
int pthread_mutexattr_setpshared(pthread_mutexattr_t*, int);
int pthread_mutexattr_settype(pthread_mutexattr_t*, int);
int pthread_once(pthread_once_t*, void function());
int pthread_rwlock_destroy(pthread_rwlock_t*);
int pthread_rwlock_init(pthread_rwlock_t*, in pthread_rwlockattr_t*);
int pthread_rwlock_rdlock(pthread_rwlock_t*);
int pthread_rwlock_timedrdlock(pthread_rwlock_t*, in timespec*);
int pthread_rwlock_timedwrlock(pthread_rwlock_t*, in timespec*);
int pthread_rwlock_tryrdlock(pthread_rwlock_t*);
int pthread_rwlock_trywrlock(pthread_rwlock_t*);
int pthread_rwlock_unlock(pthread_rwlock_t*);
int pthread_rwlock_wrlock(pthread_rwlock_t*);
int pthread_rwlockattr_destroy(pthread_rwlockattr_t*);
int pthread_rwlockattr_getpshared(in pthread_rwlockattr_t*, int*);
int pthread_rwlockattr_init(pthread_rwlockattr_t*);
int pthread_rwlockattr_setpshared(pthread_rwlockattr_t*, int);
int pthread_setcancelstate(int, int*);
int pthread_setcanceltype(int, int*);
int pthread_setconcurrency(int);
int pthread_setprio(pthread_t, int);
int pthread_setschedparam(pthread_t, int, in sched_param*);
int pthread_setspecific(pthread_key_t, in void*);
int pthread_sigmask(int, in __sigset_t*, __sigset_t*);
int pthread_spin_destroy(pthread_spinlock_t*);
int pthread_spin_init(pthread_spinlock_t*, int);
int pthread_spin_lock(pthread_spinlock_t*);
int pthread_spin_trylock(pthread_spinlock_t*);
int pthread_spin_unlock(pthread_spinlock_t*);
pthread_t pthread_self();
void pthread_cleanup_pop(int);
void pthread_cleanup_push(void function(void*), void*);
void pthread_exit(void*);
void pthread_testcancel();
void pthread_yield();
void* pthread_getspecific(pthread_key_t);

