
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

    int equals(void *p1, void *p2)
    {
	return *cast(creal *)p1 == *cast(creal *)p2;
    }

    int compare(void *p1, void *p2)
    {
        creal a = *cast(creal *) p1;
        creal b = *cast(creal *) p2;
        return a < b ? -1 : a > b ? 1 : 0;
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

