
// creal

class TypeInfo_c : TypeInfo
{
    uint getHash(void *p)
    {
	return ((uint *)p)[0] + ((uint *)p)[1] +
	       ((uint *)p)[2] + ((uint *)p)[3] +
	       ((uint *)p)[4];
    }

    int equals(void *p1, void *p2)
    {
	return *(creal *)p1 == *(creal *)p2;
    }

    int compare(void *p1, void *p2)
    {
        creal a = *(creal *) p1;
        creal b = *(creal *) p2;
        return a < b ? -1 : a > b ? 1 : 0;
    }

    int tsize()
    {
	return creal.size;
    }

    void swap(void *p1, void *p2)
    {
	creal t;

	t = *(creal *)p1;
	*(creal *)p1 = *(creal *)p2;
	*(creal *)p2 = t;
    }
}

