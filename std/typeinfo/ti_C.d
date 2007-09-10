
private import std.string;

// Object

class TypeInfo_C : TypeInfo
{
    uint getHash(void *p)
    {
	Object o = *cast(Object*)p;
	assert(o);
	return o.toHash();
    }

    int equals(void *p1, void *p2)
    {
	Object o1 = *cast(Object*)p1;
	Object o2 = *cast(Object*)p2;

	return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

    int compare(void *p1, void *p2)
    {
	Object o1 = *cast(Object*)p1;
	Object o2 = *cast(Object*)p2;
	int c = 0;

	// Regard null references as always being "less than"
	if (o1 != o2)
	{
	    if (o1)
	    {	if (!o2)
		    c = 1;
		else
		    c = o1.opCmp(o2);
	    }
	    else
		c = -1;
	}
	return c;
    }

    int tsize()
    {
	return Object.sizeof;
    }
}

