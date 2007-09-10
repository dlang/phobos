// Copyright (C) 2000-2003 by Digital Mars, www.digitalmars.com
// All Rights Reserved
// Written by Walter Bright

/* ================================= Win32 ============================ */

#if _WIN32

#include	<windows.h>

/******************************************
 * Enter/exit critical section.
 */

/* We don't initialize critical sections unless we actually need them.
 * So keep a linked list of the ones we do use, and in the static destructor
 * code, walk the list and release them.
 */

typedef struct D_CRITICAL_SECTION
{
    struct D_CRITICAL_SECTION *next;
    CRITICAL_SECTION cs;
} D_CRITICAL_SECTION;

static D_CRITICAL_SECTION *dcs_list;
static D_CRITICAL_SECTION critical_section;
static volatile int inited;

void _d_criticalenter(D_CRITICAL_SECTION *dcs)
{
    if (!dcs->next)
    {
	EnterCriticalSection(&critical_section.cs);
	if (!dcs->next)	// if, in the meantime, another thread didn't set it
	{
	    dcs->next = dcs_list;
	    dcs_list = dcs;
	    InitializeCriticalSection(&dcs->cs);
	}
	LeaveCriticalSection(&critical_section.cs);
    }
    EnterCriticalSection(&dcs->cs);
}

void _d_criticalexit(D_CRITICAL_SECTION *dcs)
{
    LeaveCriticalSection(&dcs->cs);
}

void _STI_critical_init()
{
    if (!inited)
    {	InitializeCriticalSection(&critical_section.cs);
	dcs_list = &critical_section;
	inited = 1;
    }
}

void _STD_critical_term()
{
    if (inited)
    {	inited = 0;
	while (dcs_list)
	{
	    DeleteCriticalSection(&dcs_list->cs);
	    dcs_list = dcs_list->next;
	}
	DeleteCriticalSection(&critical_section.cs);
    }
}

#endif

/* ================================= linux ============================ */

#if linux

#include	<pthread.h>

/******************************************
 * Enter/exit critical section.
 */

/* We don't initialize critical sections unless we actually need them.
 * So keep a linked list of the ones we do use, and in the static destructor
 * code, walk the list and release them.
 */

typedef struct D_CRITICAL_SECTION
{
    struct D_CRITICAL_SECTION *next;
    pthread_mutex_t cs;
} D_CRITICAL_SECTION;

static D_CRITICAL_SECTION *dcs_list;
static D_CRITICAL_SECTION critical_section;
static volatile int inited;

void _d_criticalenter(D_CRITICAL_SECTION *dcs)
{
    if (!dcs->next)
    {
	pthread_mutex_lock(&critical_section.cs);
	if (!dcs->next)	// if, in the meantime, another thread didn't set it
	{
	    dcs->next = dcs_list;
	    dcs_list = dcs;
	    pthread_mutex_init(&dcs->cs, 0);
	}
	pthread_mutex_unlock(&critical_section.cs);
    }
    pthread_mutex_lock(&dcs->cs);
}

void _d_criticalexit(D_CRITICAL_SECTION *dcs)
{
    pthread_mutex_unlock(&dcs->cs);
}

void _STI_critical_init()
{
    if (!inited)
    {	pthread_mutex_init(&critical_section.cs, 0);
	dcs_list = &critical_section;
	inited = 1;
    }
}

void _STD_critical_term()
{
    if (inited)
    {	inited = 0;
	while (dcs_list)
	{
	    pthread_mutex_destroy(&dcs_list->cs);
	    dcs_list = dcs_list->next;
	}
	pthread_mutex_destroy(&critical_section.cs);
    }
}

#endif

