// Copyright (C) 2000 by Digital Mars
// All Rights Reserved
// Written by Walter Bright

#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>
#include	<stdarg.h>

#include	"mars.h"

/*********************************************
 * Return pointer to interface function.
 */

void * __stdcall _d_interface(Object *o, unsigned vindex, ClassInfo *interface)
{   ClassInfo *cb;
    int i;

    //printf("_d_interface(o = %p, vindex = x%x, interface = %p)\n",o,vindex,interface);
    cb = (ClassInfo *)o->vptr[0];
    if (cb == interface)
	return o->vptr[vindex];
    for (i = 0; i < cb->interfacelen; i++)
    {	int x;

	if (cb->interfaces[i].classinfo == interface)
	{
	    return cb->interfaces[i].vtbl.vptr[vindex];
	}
    }
    return NULL;
}
