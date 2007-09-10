
// short

class TypeInfo_s : TypeInfo
{
    uint getHash(void *p)
    {
	return *(short *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(short *)p1 == *(short *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(short *)p1 - *(short *)p2;
    }

    int tsize()
    {
	return short.size;
    }

    void swap(void *p1, void *p2)
    {
	short t;

	t = *(short *)p1;
	*(short *)p1 = *(short *)p2;
	*(short *)p2 = t;
    }
}

