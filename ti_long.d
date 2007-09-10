
// long

class TypeInfo_l : TypeInfo
{
    uint getHash(void *p)
    {
	return *(long *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(long *)p1 == *(long *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(long *)p1 - *(long *)p2;
    }

    int tsize()
    {
	return long.size;
    }

    void swap(void *p1, void *p2)
    {
	long t;

	t = *(long *)p1;
	*(long *)p1 = *(long *)p2;
	*(long *)p2 = t;
    }
}

