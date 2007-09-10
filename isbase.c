
#include <stdio.h>

#include "mars.h"

/****************************
 * Determine if b is a base class of c
 */

int _d_isbaseof(ClassInfo *b, ClassInfo *c)
{
    // BUG: should check interfaces

    //printf("_d_isbaseof(%p, %p)\n", b, c);
    while (b != c)
    {
	c = c->baseClass;
	if (!c)
	    return 0;
    }
    return 1;
}

/*****************************
 * Used for downcasting
 */

Object * __ddecl _d_dynamic_cast(ClassInfo *ci, Object *o)
{
    if (_d_isbaseof(ci, (ClassInfo *)(o->vptr[0])))
	return o;
    return NULL;
}
