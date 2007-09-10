
import string;

// Object

class TypeInfo_C : TypeInfo
{
    uint getHash(void *p)
    {
	Object o = *(Object*)p;
	assert(o);
	return o.toHash();
    }

    int equals(void *p1, void *p2)
    {
	Object o1 = *(Object*)p1;
	Object o2 = *(Object*)p2;

	return o1 == o2 || (o1 && o1.cmp(o2) == 0);
    }

    int compare(void *p1, void *p2)
    {
	Object o1 = *(Object*)p1;
	Object o2 = *(Object*)p2;
	int c = 0;

	// Regard null references as always being "less than"
	if (o1 != o2)
	{
	    if (o1)
	    {	if (!o2)
		    c = 1;
		else
		    c = o1.cmp(o2);
	    }
	    else
		c = -1;
	}
	return c;
    }

    int tsize()
    {
	return Object.size;
    }
}

