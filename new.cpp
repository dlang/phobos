
// Storage allocation

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define __STDC__ 1
#include <gc.h>

#include "mars.h"

GC gc;

extern "C" void *_atopsp;

void new_finalizer(void *p, void *dummy);

extern "C"
{

void gc_init()
{
    gc.init();
    gc.setStackBottom(_atopsp);
    gc.scanStaticData();
}

void gc_term()
{
    gc.fullcollect();
}

Object * __ddecl __d_newclass(ClassInfo *ci)
{
    void *p;

    //printf("__d_newclass(ci = %p)\n", ci);
    p = gc.malloc(ci->initlen);
    //printf(" p = %p\n", p);
    if (!p)
	_d_OutOfMemory();

#if 0
    printf("p = %p\n", p);
    printf("ci = %p, ci->init = %p, len = %d\n", ci, ci->init, ci->initlen);
    printf("vptr = %p\n", *(void **)ci->init);
    printf("vtbl[0] = %p\n", (*(void ***)ci->init)[0]);
    printf("vtbl[1] = %p\n", (*(void ***)ci->init)[1]);
    printf("init[0] = %x\n", ((unsigned *)ci->init)[0]);
    printf("init[1] = %x\n", ((unsigned *)ci->init)[1]);
    printf("init[2] = %x\n", ((unsigned *)ci->init)[2]);
    printf("init[3] = %x\n", ((unsigned *)ci->init)[3]);
    printf("init[4] = %x\n", ((unsigned *)ci->init)[4]);
#endif

    gc.setFinalizer(p, new_finalizer);

    // Initialize it
    p = memcpy(p, ci->init, ci->initlen);

    //printf("initialization done\n");
    return (Object *)p;
}

typedef void __ddecl (*fp_t)(Object *);		// generic function pointer

void __ddecl __d_delclass(Object **p)
{
    if (*p)
    {
#if 0
	ClassInfo ***pc = (ClassInfo ***)*p;
	if (*pc)
	{
	    ClassInfo *c = **pc;

	    if (c->destructor)
	    {
		fp_t fp = (fp_t)c->destructor;
		(*fp)(*p);		// call destructor
	    }
	    *pc = NULL;			// zero vptr
	}
#endif
	gc.free(*p);
	*p = NULL;
    }
}

unsigned long long __ddecl __d_new(unsigned length, unsigned size)
{
    void *p;
    unsigned long long result;

    //printf("__d_new(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	p = gc.malloc(length * size);
	if (!p)
	    _d_OutOfMemory();
	//printf(" p = %p\n", p);
	memset(p, 0, length * size);
	result = (unsigned long long)length + ((unsigned long long)(unsigned)p << 32);
    }
    return result;
}

struct Array
{
    unsigned length;
    void *data;
};

// Perhaps we should get a a size argument like __d_new(), so we
// can zero out the array?

void __ddecl __d_delarray(struct Array *p)
{
    if (p)
    {
	assert(!p->length || p->data);
	if (p->data)
	    gc.free(p->data);
	p->data = NULL;
	p->length = 0;
    }
}


}

void new_finalizer(void *p, void *dummy)
{
    //printf("new_finalizer(p = %p)\n", p);
    ClassInfo ***pc = (ClassInfo ***)p;
    if (*pc)
    {
	ClassInfo *c = **pc;

	if (c->destructor)
	{
	    fp_t fp = (fp_t)c->destructor;
	    (*fp)((Object *)p);		// call destructor
	}
	*pc = NULL;			// zero vptr
    }
}

