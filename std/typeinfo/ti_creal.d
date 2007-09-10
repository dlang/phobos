
// creal

class TypeInfo_c : TypeInfo
{
    char[] toString() { return "creal"; }

    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1] +
	       (cast(uint *)p)[2] + (cast(uint *)p)[3] +
	       (cast(uint *)p)[4];
    }

    static int _equals(creal f1, creal f2)
    {
	return f1 == f2;
    }

    static int _compare(creal f1, creal f2)
    {
        return f1 < f2 ? -1 : f1 > f2 ? 1 : 0;
    }

    int equals(void *p1, void *p2)
    {
	return _equals(*cast(creal *)p1, *cast(creal *)p2);
    }

    int compare(void *p1, void *p2)
    {
	return _compare(*cast(creal *)p1, *cast(creal *)p2);
    }

    int tsize()
    {
	return creal.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	creal t;

	t = *cast(creal *)p1;
	*cast(creal *)p1 = *cast(creal *)p2;
	*cast(creal *)p2 = t;
    }
}

