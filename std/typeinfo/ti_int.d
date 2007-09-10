

class TypeInfo_i : TypeInfo
{
    uint getHash(void *p)
    {
	return *cast(uint *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(uint *)p1 == *cast(uint *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(int *)p1 - *cast(int *)p2;
    }

    int tsize()
    {
	return int.size;
    }

    void swap(void *p1, void *p2)
    {
	int t;

	t = *cast(int *)p1;
	*cast(int *)p1 = *cast(int *)p2;
	*cast(int *)p2 = t;
    }
}

