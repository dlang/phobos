// D programming language runtime library
// Public Domain
// written by Walter Bright, Digital Mars
// www.digitalmars.com

// This is written in C because nobody has written a pthreads interface
// to D yet.


#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#if _WIN32
#elif linux
#define USE_PTHREADS	1
#else
#endif

#if _WIN32
#include <windows.h>
#endif

#if USE_PTHREADS
#include <pthread.h>
#endif

#include "mars.h"

// This is what the monitor reference in Object points to
typedef struct Monitor
{
    Array delegates;	// for the notification system

#if _WIN32
    CRITICAL_SECTION mon;
#endif

#if USE_PTHREADS
    pthread_mutex_t mon;
#endif
} Monitor;

#define MONPTR(h)	(&((Monitor *)(h)->monitor)->mon)

static volatile int inited;

void _d_notify_release(Object *);

/* =============================== Win32 ============================ */

#if _WIN32

static CRITICAL_SECTION _monitor_critsec;

void _STI_monitor_staticctor()
{
    if (!inited)
    {	InitializeCriticalSection(&_monitor_critsec);
	inited = 1;
    }
}

void _STD_monitor_staticdtor()
{
    if (inited)
    {	inited = 0;
	DeleteCriticalSection(&_monitor_critsec);
    }
}

void _d_monitorenter(Object *h)
{
    //printf("_d_monitorenter(%p), %p\n", h, h->monitor);
    if (!h->monitor)
    {	Monitor *cs;

	cs = (Monitor *)calloc(sizeof(Monitor), 1);
	assert(cs);
	EnterCriticalSection(&_monitor_critsec);
	if (!h->monitor)	// if, in the meantime, another thread didn't set it
	{
	    h->monitor = (void *)cs;
	    InitializeCriticalSection(&cs->mon);
	    cs = NULL;
	}
	LeaveCriticalSection(&_monitor_critsec);
	if (cs)			// if we didn't use it
	    free(cs);
    }
    //printf("-_d_monitorenter(%p)\n", h);
    EnterCriticalSection(MONPTR(h));
    //printf("-_d_monitorenter(%p)\n", h);
}

void _d_monitorexit(Object *h)
{
    //printf("_d_monitorexit(%p)\n", h);
    assert(h->monitor);
    LeaveCriticalSection(MONPTR(h));
}

/***************************************
 * Called by garbage collector when Object is free'd.
 */

void _d_monitorrelease(Object *h)
{
    if (h->monitor)
    {
	_d_notify_release(h);

	DeleteCriticalSection(MONPTR(h));

	// We can improve this by making a free list of monitors
	free((void *)h->monitor);

	h->monitor = NULL;
    }
}

#endif

/* =============================== linux ============================ */

#if USE_PTHREADS

// Includes attribute fixes from David Friedman's GDC port

static pthread_mutex_t _monitor_critsec;
static pthread_mutexattr_t _monitors_attr;

void _STI_monitor_staticctor()
{
    if (!inited)
    {
	pthread_mutexattr_init(&_monitors_attr);
	pthread_mutexattr_settype(&_monitors_attr, PTHREAD_MUTEX_RECURSIVE_NP);
	pthread_mutex_init(&_monitor_critsec, 0);
	inited = 1;
    }
}

void _STD_monitor_staticdtor()
{
    if (inited)
    {	inited = 0;
	pthread_mutex_destroy(&_monitor_critsec);
	pthread_mutexattr_destroy(&_monitors_attr);
    }
}

void _d_monitorenter(Object *h)
{
    //printf("_d_monitorenter(%p), %p\n", h, h->monitor);
    if (!h->monitor)
    {	Monitor *cs;

	cs = (Monitor *)calloc(sizeof(Monitor), 1);
	assert(cs);
	pthread_mutex_lock(&_monitor_critsec);
	if (!h->monitor)	// if, in the meantime, another thread didn't set it
	{
	    h->monitor = (void *)cs;
	    pthread_mutex_init(&cs->mon, & _monitors_attr);
	    cs = NULL;
	}
	pthread_mutex_unlock(&_monitor_critsec);
	if (cs)			// if we didn't use it
	    free(cs);
    }
    //printf("-_d_monitorenter(%p)\n", h);
    pthread_mutex_lock(MONPTR(h));
    //printf("-_d_monitorenter(%p)\n", h);
}

void _d_monitorexit(Object *h)
{
    //printf("+_d_monitorexit(%p)\n", h);
    assert(h->monitor);
    pthread_mutex_unlock(MONPTR(h));
    //printf("-_d_monitorexit(%p)\n", h);
}

/***************************************
 * Called by garbage collector when Object is free'd.
 */

void _d_monitorrelease(Object *h)
{
    if (h->monitor)
    {
	_d_notify_release(h);

	pthread_mutex_destroy(MONPTR(h));

	// We can improve this by making a free list of monitors
	free((void *)h->monitor);

	h->monitor = NULL;
    }
}

#endif
