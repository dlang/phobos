
// dchar

class TypeInfo_w : TypeInfo
{
    uint getHash(void *p)
    {
	return *(dchar *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(dchar *)p1 == *(dchar *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(dchar *)p1 - *(dchar *)p2;
    }

    int tsize()
    {
	return dchar.size;
    }

    void swap(void *p1, void *p2)
    {
	dchar t;

	t = *(dchar *)p1;
	*(dchar *)p1 = *(dchar *)p2;
	*(dchar *)p2 = t;
    }
}

