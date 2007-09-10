
// cdouble

class TypeInfo_r : TypeInfo
{
    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1] +
	       (cast(uint *)p)[2] + (cast(uint *)p)[3];
    }

    int equals(void *p1, void *p2)
    {
	return *cast(cdouble *)p1 == *cast(cdouble *)p2;
    }

    int compare(void *p1, void *p2)
    {
        cdouble a = *cast(cdouble *) p1;
        cdouble b = *cast(cdouble *) p2;
        return a < b ? -1 : a > b ? 1 : 0;
    }

    int tsize()
    {
	return cdouble.size;
    }

    void swap(void *p1, void *p2)
    {
	cdouble t;

	t = *cast(cdouble *)p1;
	*cast(cdouble *)p1 = *cast(cdouble *)p2;
	*cast(cdouble *)p2 = t;
    }
}

