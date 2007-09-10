
import object;
import std.c.stdio;

/*************************************
 * Attempts to cast Object o to class c.
 * Returns o if successful, null if not.
 */

extern (C):

Object _d_interface_cast(void* p, ClassInfo c)
{   Object o;

    //printf("_d_interface_cast(p = %p, c = '%.*s')\n", p, c.name);
    if (p)
    {
	Interface *pi = **cast(Interface ***)p;

	//printf("\tpi.offset = %d\n", pi.offset);
	o = cast(Object)(p - pi.offset);
	return _d_dynamic_cast(o, c);
    }
    return o;
}

Object _d_dynamic_cast(Object o, ClassInfo c)
{   ClassInfo oc;
    uint offset = 0;

    //printf("_d_dynamic_cast(o = %p, c = '%.*s')\n", o, c.name);

    if (o)
    {
	oc = o.classinfo;
	if (_d_isbaseof2(oc, c, offset))
	{
	    //printf("\toffset = %d\n", offset);
	    o = cast(Object)(cast(void*)o + offset);
	}
	else
	    o = null;
    }
    //printf("\tresult = %p\n", o);
    return o;
}

int _d_isbaseof2(ClassInfo oc, ClassInfo c, inout uint offset)
{   int i;

    if (oc === c)
	return 1;
    do
    {
	if (oc.base === c)
	    return 1;
	for (i = 0; i < oc.interfaces.length; i++)
	{
	    ClassInfo ic;

	    ic = oc.interfaces[i].classinfo;
	    if (ic === c)
	    {	offset = oc.interfaces[i].offset;
		return 1;
	    }
	}
	for (i = 0; i < oc.interfaces.length; i++)
	{
	    ClassInfo ic;

	    ic = oc.interfaces[i].classinfo;
	    if (_d_isbaseof2(ic, c, offset))
	    {	offset = oc.interfaces[i].offset;
		return 1;
	    }
	}
	oc = oc.base;
    } while (oc);
    return 0;
}

int _d_isbaseof(ClassInfo oc, ClassInfo c)
{   int i;

    if (oc === c)
	return 1;
    do
    {
	if (oc.base === c)
	    return 1;
	for (i = 0; i < oc.interfaces.length; i++)
	{
	    ClassInfo ic;

	    ic = oc.interfaces[i].classinfo;
	    if (ic === c || _d_isbaseof(ic, c))
		return 1;
	}
	oc = oc.base;
    } while (oc);
    return 0;
}

/*********************************
 * Find the vtbl[] associated with Interface ic.
 */

void *_d_interface_vtbl(ClassInfo ic, Object o)
{   int i;
    ClassInfo oc;

    //printf("__d_interface_vtbl(o = %p, ic = %p)\n", o, ic);

    assert(o);

    oc = o.classinfo;
    for (i = 0; i < oc.interfaces.length; i++)
    {
	ClassInfo oic;

	oic = oc.interfaces[i].classinfo;
	if (oic === ic)
	{
	    return cast(void *)oc.interfaces[i].vtbl;
	}
    }
    assert(0);
    return null;
}
