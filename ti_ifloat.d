
// ifloat

class TypeInfo_o : TypeInfo
{
    uint getHash(void *p)
    {
	return *(uint *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(ifloat *)p1 == *(ifloat *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(float *)p1 - *(float *)p2;
    }

    int tsize()
    {
	return ifloat.size;
    }

    void swap(void *p1, void *p2)
    {
	ifloat t;

	t = *(ifloat *)p1;
	*(ifloat *)p1 = *(ifloat *)p2;
	*(ifloat *)p2 = t;
    }
}

