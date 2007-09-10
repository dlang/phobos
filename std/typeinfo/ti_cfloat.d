
// cfloat

class TypeInfo_q : TypeInfo
{
    char[] toString() { return "cfloat"; }

    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1];
    }

    static int _equals(cfloat f1, cfloat f2)
    {
	return f1 == f2;
    }

    static int _compare(cfloat f1, cfloat f2)
    {
        return f1 < f2 ? -1 : f1 > f2 ? 1 : 0;
    }

    int equals(void *p1, void *p2)
    {
	return _equals(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    int compare(void *p1, void *p2)
    {
	return _compare(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    int tsize()
    {
	return cfloat.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	cfloat t;

	t = *cast(cfloat *)p1;
	*cast(cfloat *)p1 = *cast(cfloat *)p2;
	*cast(cfloat *)p2 = t;
    }
}

