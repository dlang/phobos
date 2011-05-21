/**
 * pthread for OpenBSD
 */

module std.c.openbsd.pthread;

version (OpenBSD) { } else { static assert(0); }

import std.c.openbsd.openbsd;

extern (C):



typedef void	*pthread_t;
typedef void	*pthread_attr_t;
typedef void	*pthread_mutex_t;
typedef void	*pthread_mutexattr_t;
typedef void	*pthread_cond_t;
typedef void	*pthread_condattr_t;
typedef int 	pthread_key_t;
typedef void	*pthread_rwlock_t;
typedef void	*pthread_rwlockattr_t;

alias void* pthread_addr_t;
alias void* function(void*) pthread_startroutine_t;

struct pthread_once_t
{
    int	state;
    pthread_mutex_t mutex;
}

enum pthread_mutextype
{
    PTHREAD_MUTEX_ERRORCHECK = 1,	
    PTHREAD_MUTEX_RECURSIVE = 2,	
    PTHREAD_MUTEX_NORMAL = 3,	
    PTHREAD_MUTEX_TYPE_MAX
}

int pthread_atfork(void function(), void function(), void function());
int pthread_attr_destroy(pthread_attr_t *);
int pthread_attr_getstack(pthread_attr_t *, void **, size_t *);
int pthread_attr_getstacksize(pthread_attr_t *, size_t *);
int pthread_attr_getstackaddr(pthread_attr_t *, void **);
int pthread_attr_getguardsize(pthread_attr_t *, size_t *);
int pthread_attr_getdetachstate(pthread_attr_t *, int *);
int pthread_attr_init(pthread_attr_t *);
int pthread_attr_setstacksize(pthread_attr_t *, size_t);
int pthread_attr_setstack(pthread_attr_t *, void *, size_t);
int pthread_attr_setstackaddr(pthread_attr_t *, void *);
int pthread_attr_setguardsize(pthread_attr_t *, size_t);
int pthread_attr_setdetachstate(pthread_attr_t *, int);
void pthread_cleanup_pop(int);
void pthread_cleanup_push(void function (void *), void *routine_arg);
int pthread_condattr_destroy(pthread_condattr_t *);
int pthread_condattr_init(pthread_condattr_t *);
int pthread_cond_broadcast(pthread_cond_t *);
int pthread_cond_destroy(pthread_cond_t *);
int pthread_cond_init(pthread_cond_t *, pthread_condattr_t *);
int pthread_cond_signal(pthread_cond_t *);
int pthread_cond_timedwait(pthread_cond_t *, pthread_mutex_t *, timespec *);
int pthread_cond_wait(pthread_cond_t *, pthread_mutex_t *);
int pthread_create(pthread_t *, pthread_attr_t *, void *function (void *), void *);
int pthread_detach(pthread_t);
int pthread_equal(pthread_t, pthread_t);
void pthread_exit(void *);
void *pthread_getspecific(pthread_key_t);
int pthread_join(pthread_t, void **);
int pthread_key_create(pthread_key_t *, void function (void *));
int pthread_key_delete(pthread_key_t);
int pthread_kill(pthread_t, int);
int pthread_mutexattr_init(pthread_mutexattr_t *);
int pthread_mutexattr_destroy(pthread_mutexattr_t *);
int pthread_mutexattr_gettype(pthread_mutexattr_t *, int *);
int pthread_mutexattr_settype(pthread_mutexattr_t *, int);
int pthread_mutex_destroy(pthread_mutex_t *);
int pthread_mutex_init(pthread_mutex_t *, pthread_mutexattr_t *);
int pthread_mutex_lock(pthread_mutex_t *);
int pthread_mutex_trylock(pthread_mutex_t *);
int pthread_mutex_unlock(pthread_mutex_t *);
int pthread_once(pthread_once_t *, void function ());
int pthread_rwlock_destroy(pthread_rwlock_t *);
int pthread_rwlock_init(pthread_rwlock_t *, pthread_rwlockattr_t *);
int pthread_rwlock_rdlock(pthread_rwlock_t *);
int pthread_rwlock_timedrdlock(pthread_rwlock_t *, timespec *);
int pthread_rwlock_timedwrlock(pthread_rwlock_t *, timespec *);
int pthread_rwlock_tryrdlock(pthread_rwlock_t *);
int pthread_rwlock_trywrlock(pthread_rwlock_t *);
int pthread_rwlock_unlock(pthread_rwlock_t *);
int pthread_rwlock_wrlock(pthread_rwlock_t *);
int pthread_rwlockattr_init(pthread_rwlockattr_t *);
int pthread_rwlockattr_getpshared(pthread_rwlockattr_t *, int *);
int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *, int);
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *);
pthread_t thread_self();
int pthread_setspecific(pthread_key_t, __const void *);
int pthread_sigmask(int, sigset_t *, sigset_t *);
int pthread_cancel(pthread_t);
int pthread_setcancelstate(int, int *);
int pthread_setcanceltype(int, int *);
void pthread_testcancel();
int pthread_getprio(pthread_t);
int pthread_setprio(pthread_t, int);
void pthread_yield();
int pthread_mutexattr_getprioceiling(pthread_mutexattr_t *, int *);
int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *, int);
int pthread_mutex_getprioceiling(pthread_mutex_t *, int *);
int pthread_mutex_setprioceiling(pthread_mutex_t *, int, int *);
int pthread_mutexattr_getprotocol(pthread_mutexattr_t *, int *);
int pthread_mutexattr_setprotocol(pthread_mutexattr_t *, int);
int pthread_attr_getinheritsched(pthread_attr_t *, int *);
int pthread_attr_getschedparam(pthread_attr_t *, sched_param *);
int pthread_attr_getschedpolicy(pthread_attr_t *, int *);
int pthread_attr_getscope(pthread_attr_t *, int *);
int pthread_attr_setinheritsched(pthread_attr_t *, int);
int pthread_attr_setschedparam(pthread_attr_t *, sched_param *);
int pthread_attr_setschedpolicy(pthread_attr_t *, int);
int pthread_attr_setscope(pthread_attr_t *, int);
int pthread_getschedparam(pthread_t pthread, int *, sched_param *);
int pthread_setschedparam(pthread_t, int, sched_param *);
int pthread_getconcurrency();
int pthread_setconcurrency(int);


