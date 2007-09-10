
// float

class TypeInfo_f : TypeInfo
{
    char[] toString() { return "float"; }

    uint getHash(void *p)
    {
	return *cast(uint *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(float *)p1 == *cast(float *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*cast(float *)p1 - *cast(float *)p2);
    }

    int tsize()
    {
	return float.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	float t;

	t = *cast(float *)p1;
	*cast(float *)p1 = *cast(float *)p2;
	*cast(float *)p2 = t;
    }
}

