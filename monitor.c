

// Copyright (c) 2000-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com



#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
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
