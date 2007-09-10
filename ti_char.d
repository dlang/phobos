

class TypeInfo_a : TypeInfo
{
    uint getHash(void *p)
    {
	return *(char *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(char *)p1 == *(char *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(char *)p1 - *(char *)p2;
    }

    int tsize()
    {
	return char.size;
    }

    void swap(void *p1, void *p2)
    {
	char t;

	t = *(char *)p1;
	*(char *)p1 = *(char *)p2;
	*(char *)p2 = t;
    }
}

