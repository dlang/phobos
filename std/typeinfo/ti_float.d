
// float

class TypeInfo_f : TypeInfo
{
    uint getHash(void *p)
    {
	return *(uint *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(float *)p1 == *(float *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(float *)p1 - *(float *)p2;
    }

    int tsize()
    {
	return float.size;
    }

    void swap(void *p1, void *p2)
    {
	float t;

	t = *(float *)p1;
	*(float *)p1 = *(float *)p2;
	*(float *)p2 = t;
    }
}

