
// ireal

class TypeInfo_j : TypeInfo
{
    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1] + (cast(ushort *)p)[4];
    }

    int equals(void *p1, void *p2)
    {
	return *cast(ireal *)p1 == *cast(ireal *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*cast(real *)p1 - *cast(real *)p2);
    }

    int tsize()
    {
	return ireal.size;
    }

    void swap(void *p1, void *p2)
    {
	ireal t;

	t = *cast(ireal *)p1;
	*cast(ireal *)p1 = *cast(ireal *)p2;
	*cast(ireal *)p2 = t;
    }
}

