// Copyright (c) 2000-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com



#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

/* =============================== Win32 ============================ */

#if _WIN32

#include <windows.h>

#include "mars.h"

static CRITICAL_SECTION _monitor_critsec;
static volatile int inited;

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
    {	CRITICAL_SECTION *cs;

	cs = (CRITICAL_SECTION *)calloc(sizeof(CRITICAL_SECTION), 1);
	assert(cs);
	EnterCriticalSection(&_monitor_critsec);
	if (!h->monitor)	// if, in the meantime, another thread didn't set it
	{
	    h->monitor = (unsigned)cs;
	    InitializeCriticalSection(cs);
	    cs = NULL;
	}
	LeaveCriticalSection(&_monitor_critsec);
	if (cs)			// if we didn't use it
	    free(cs);
    }
    //printf("-_d_monitorenter(%p)\n", h);
    EnterCriticalSection((CRITICAL_SECTION *)h->monitor);
    //printf("-_d_monitorenter(%p)\n", h);
}

void _d_monitorexit(Object *h)
{
    //printf("_d_monitorexit(%p)\n", h);
    assert(h->monitor);
    LeaveCriticalSection((CRITICAL_SECTION *)h->monitor);
}

/***************************************
 * Called by garbage collector when Object is free'd.
 */

void _d_monitorrelease(Object *h)
{
    if (h->monitor)
    {	DeleteCriticalSection((CRITICAL_SECTION *)h->monitor);

	// We can improve this by making a free list of monitors
	free((void *)h->monitor);

	h->monitor = 0;
    }
}

#endif

/* =============================== linux ============================ */

#if linux

// Includes attribute fixes from David Friedman's GDC port

#include <pthread.h>

#include "mars.h"

static pthread_mutex_t _monitor_critsec;
static pthread_mutexattr_t _monitors_attr;
static volatile int inited;

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
    {	pthread_mutex_t *cs;

	cs = (pthread_mutex_t *)calloc(sizeof(pthread_mutex_t), 1);
	assert(cs);
	pthread_mutex_lock(&_monitor_critsec);
	if (!h->monitor)	// if, in the meantime, another thread didn't set it
	{
	    h->monitor = (unsigned)cs;
	    pthread_mutex_init(cs, & _monitors_attr);
	    cs = NULL;
	}
	pthread_mutex_unlock(&_monitor_critsec);
	if (cs)			// if we didn't use it
	    free(cs);
    }
    //printf("-_d_monitorenter(%p)\n", h);
    pthread_mutex_lock((pthread_mutex_t *)h->monitor);
    //printf("-_d_monitorenter(%p)\n", h);
}

void _d_monitorexit(Object *h)
{
    //printf("+_d_monitorexit(%p)\n", h);
    assert(h->monitor);
    pthread_mutex_unlock((pthread_mutex_t *)h->monitor);
    //printf("-_d_monitorexit(%p)\n", h);
}

/***************************************
 * Called by garbage collector when Object is free'd.
 */

void _d_monitorrelease(Object *h)
{
    if (h->monitor)
    {	pthread_mutex_destroy((pthread_mutex_t *)h->monitor);

	// We can improve this by making a free list of monitors
	free((void *)h->monitor);

	h->monitor = 0;
    }
}

#endif
