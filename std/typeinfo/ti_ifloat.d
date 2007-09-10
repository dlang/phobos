
// ifloat

class TypeInfo_o : TypeInfo
{
    char[] toString() { return "ifloat"; }

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
	return ifloat.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	ifloat t;

	t = *cast(ifloat *)p1;
	*cast(ifloat *)p1 = *cast(ifloat *)p2;
	*cast(ifloat *)p2 = t;
    }
}

