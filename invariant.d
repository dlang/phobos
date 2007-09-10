
import object;
import stdio;

void _d_invariant(Object o)
{   ClassInfo c;

    //printf("__d_invariant(%p)\n", o);

    // BUG: needs to be filename/line of caller, not library routine
    assert(o != null);	// just do null check, not invariant check

    c = o.classinfo;
    do
    {
	if (c._invariant)
	{
	    (*c._invariant)(o);
	}
	c = c.base;
    } while (c);
}
