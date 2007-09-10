
// idouble

class TypeInfo_p : TypeInfo
{
    uint getHash(void *p)
    {
	return ((uint *)p)[0] + ((uint *)p)[1];
    }

    int equals(void *p1, void *p2)
    {
	return *(idouble *)p1 == *(idouble *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(double *)p1 - *(double *)p2;
    }

    int tsize()
    {
	return idouble.size;
    }

    void swap(void *p1, void *p2)
    {
	idouble t;

	t = *(idouble *)p1;
	*(idouble *)p1 = *(idouble *)p2;
	*(idouble *)p2 = t;
    }
}

