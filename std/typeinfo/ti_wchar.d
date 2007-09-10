

class TypeInfo_u : TypeInfo
{
    uint getHash(void *p)
    {
	return *cast(wchar *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(wchar *)p1 == *cast(wchar *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(wchar *)p1 - *cast(wchar *)p2;
    }

    int tsize()
    {
	return wchar.size;
    }

    void swap(void *p1, void *p2)
    {
	wchar t;

	t = *cast(wchar *)p1;
	*cast(wchar *)p1 = *cast(wchar *)p2;
	*cast(wchar *)p2 = t;
    }
}

