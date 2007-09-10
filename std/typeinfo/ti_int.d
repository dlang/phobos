

class TypeInfo_i : TypeInfo
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
	return *(int *)p1 - *(int *)p2;
    }

    int tsize()
    {
	return int.size;
    }

    void swap(void *p1, void *p2)
    {
	int t;

	t = *(int *)p1;
	*(int *)p1 = *(int *)p2;
	*(int *)p2 = t;
    }
}

