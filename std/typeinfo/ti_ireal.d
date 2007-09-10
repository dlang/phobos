
// ireal

class TypeInfo_j : TypeInfo
{
    uint getHash(void *p)
    {
	return ((uint *)p)[0] + ((uint *)p)[1] + ((ushort *)p)[4];
    }

    int equals(void *p1, void *p2)
    {
	return *(ireal *)p1 == *(ireal *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*(real *)p1 - *(real *)p2);
    }

    int tsize()
    {
	return ireal.size;
    }

    void swap(void *p1, void *p2)
    {
	ireal t;

	t = *(ireal *)p1;
	*(ireal *)p1 = *(ireal *)p2;
	*(ireal *)p2 = t;
    }
}

