
// cfloat

class TypeInfo_q : TypeInfo
{
    char[] toString() { return "cfloat"; }

    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1];
    }

    int equals(void *p1, void *p2)
    {
	return *cast(cfloat *)p1 == *cast(cfloat *)p2;
    }

    int compare(void *p1, void *p2)
    {
        cfloat a = *cast(cfloat *) p1;
        cfloat b = *cast(cfloat *) p2;
        return a < b ? -1 : a > b ? 1 : 0;
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

