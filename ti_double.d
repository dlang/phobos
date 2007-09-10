
// double

class TypeInfo_d : TypeInfo
{
    uint getHash(void *p)
    {
	return *(double *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(double *)p1 == *(double *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(double *)p1 - *(double *)p2;
    }

    int tsize()
    {
	return double.size;
    }

    void swap(void *p1, void *p2)
    {
	double t;

	t = *(double *)p1;
	*(double *)p1 = *(double *)p2;
	*(double *)p2 = t;
    }
}

