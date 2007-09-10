
// cfloat

class TypeInfo_q : TypeInfo
{
    uint getHash(void *p)
    {
	return ((uint *)p)[0] + ((uint *)p)[1];
    }

    int equals(void *p1, void *p2)
    {
	return *(cfloat *)p1 == *(cfloat *)p2;
    }

    int compare(void *p1, void *p2)
    {
        cfloat a = *(cfloat *) p1;
        cfloat b = *(cfloat *) p2;
        return a < b ? -1 : a > b ? 1 : 0;
    }

    int tsize()
    {
	return cfloat.size;
    }

    void swap(void *p1, void *p2)
    {
	cfloat t;

	t = *(cfloat *)p1;
	*(cfloat *)p1 = *(cfloat *)p2;
	*(cfloat *)p2 = t;
    }
}

