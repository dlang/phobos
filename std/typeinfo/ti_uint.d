

class TypeInfo_k : TypeInfo
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
	return *cast(uint *)p1 - *cast(uint *)p2;
    }

    int tsize()
    {
	return uint.size;
    }

    void swap(void *p1, void *p2)
    {
	int t;

	t = *cast(uint *)p1;
	*cast(uint *)p1 = *cast(uint *)p2;
	*cast(uint *)p2 = t;
    }
}

