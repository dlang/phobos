

class TypeInfo_u : TypeInfo
{
    uint getHash(void *p)
    {
	return *(wchar *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(wchar *)p1 == *(wchar *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(wchar *)p1 - *(wchar *)p2;
    }

    int tsize()
    {
	return wchar.size;
    }

    void swap(void *p1, void *p2)
    {
	wchar t;

	t = *(wchar *)p1;
	*(wchar *)p1 = *(wchar *)p2;
	*(wchar *)p2 = t;
    }
}

