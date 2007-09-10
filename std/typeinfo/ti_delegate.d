
// delegate

alias void delegate(int) dg;

class TypeInfo_D : TypeInfo
{
    uint getHash(void *p)
    {	long l = *(long *)p;

	return (uint)(l + (l >> 32));
    }

    int equals(void *p1, void *p2)
    {
	return *(dg *)p1 == *(dg *)p2;
    }

    int tsize()
    {
	return dg.size;
    }

    void swap(void *p1, void *p2)
    {
	dg t;

	t = *(dg *)p1;
	*(dg *)p1 = *(dg *)p2;
	*(dg *)p2 = t;
    }
}

