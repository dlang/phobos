
// idouble

class TypeInfo_p : TypeInfo
{
    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1];
    }

    int equals(void *p1, void *p2)
    {
	return *cast(idouble *)p1 == *cast(idouble *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*cast(double *)p1 - *cast(double *)p2);
    }

    int tsize()
    {
	return idouble.size;
    }

    void swap(void *p1, void *p2)
    {
	idouble t;

	t = *cast(idouble *)p1;
	*cast(idouble *)p1 = *cast(idouble *)p2;
	*cast(idouble *)p2 = t;
    }
}

