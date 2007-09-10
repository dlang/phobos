
// ulong

class TypeInfo_m : TypeInfo
{
    uint getHash(void *p)
    {
	return *(ulong *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(ulong *)p1 == *(ulong *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(ulong *)p1 - *(ulong *)p2;
    }

    int tsize()
    {
	return ulong.size;
    }

    void swap(void *p1, void *p2)
    {
	ulong t;

	t = *(ulong *)p1;
	*(ulong *)p1 = *(ulong *)p2;
	*(ulong *)p2 = t;
    }
}

