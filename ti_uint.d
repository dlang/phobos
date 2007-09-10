

class TypeInfo_k : TypeInfo
{
    uint getHash(void *p)
    {
	return *(uint *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(uint *)p1 == *(uint *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(uint *)p1 - *(uint *)p2;
    }

    int tsize()
    {
	return uint.size;
    }

    void swap(void *p1, void *p2)
    {
	int t;

	t = *(uint *)p1;
	*(uint *)p1 = *(uint *)p2;
	*(uint *)p2 = t;
    }
}

