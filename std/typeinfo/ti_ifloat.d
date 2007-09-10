
// ifloat

class TypeInfo_o : TypeInfo
{
    uint getHash(void *p)
    {
	return *cast(uint *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(ifloat *)p1 == *cast(ifloat *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*cast(float *)p1 - *cast(float *)p2);
    }

    int tsize()
    {
	return ifloat.size;
    }

    void swap(void *p1, void *p2)
    {
	ifloat t;

	t = *cast(ifloat *)p1;
	*cast(ifloat *)p1 = *cast(ifloat *)p2;
	*cast(ifloat *)p2 = t;
    }
}

