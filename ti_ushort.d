
// ushort

class TypeInfo_t : TypeInfo
{
    uint getHash(void *p)
    {
	return *(ushort *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(ushort *)p1 == *(ushort *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(ushort *)p1 - *(ushort *)p2;
    }

    int tsize()
    {
	return ushort.size;
    }

    void swap(void *p1, void *p2)
    {
	ushort t;

	t = *(ushort *)p1;
	*(ushort *)p1 = *(ushort *)p2;
	*(ushort *)p2 = t;
    }
}

