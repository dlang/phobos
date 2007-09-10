
// cdouble

class TypeInfo_r : TypeInfo
{
    uint getHash(void *p)
    {
	return ((uint *)p)[0] + ((uint *)p)[1] +
	       ((uint *)p)[2] + ((uint *)p)[3];
    }

    int equals(void *p1, void *p2)
    {
	return *(cdouble *)p1 == *(cdouble *)p2;
    }

    int compare(void *p1, void *p2)
    {
        cdouble a = *(cdouble *) p1;
        cdouble b = *(cdouble *) p2;
        return a < b ? -1 : a > b ? 1 : 0;
    }

    int tsize()
    {
	return cdouble.size;
    }

    void swap(void *p1, void *p2)
    {
	cdouble t;

	t = *(cdouble *)p1;
	*(cdouble *)p1 = *(cdouble *)p2;
	*(cdouble *)p2 = t;
    }
}

