
import object;
import c.stdio;

/*************************************
 * Attempts to cast Object o to class c.
 * Returns o if successful, null if not.
 */

extern (C):

Object _d_dynamic_cast(Object o, ClassInfo c)
{   ClassInfo oc;

    //printf("__d_dynamic_cast(o = %p, c = %p)\n", o, c);

    if (o)
    {
	oc = o.classinfo;
	if (!_d_isbaseof(oc, c))
	    o = null;
    }
    //printf("\tresult = %p\n", o);
    return o;
}

int _d_isbaseof(ClassInfo oc, ClassInfo c)
{   int i;

    if (oc == c)
	return 1;
    do
    {
	if (oc.base == c)
	    return 1;
	for (i = 0; i < oc.interfaces.length; i++)
	{
	    ClassInfo ic;

	    ic = oc.interfaces[i].classinfo;
	    if (ic == c || _d_isbaseof(ic, c))
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
	if (oic == ic)
	{
	    return (void *)oc.interfaces[i].vtbl;
	}
    }
    assert(0);
    return null;
}
