
// real

class TypeInfo_e : TypeInfo
{
    uint getHash(void *p)
    {
	return ((uint *)p)[0] + ((uint *)p)[1] + ((ushort *)p)[4];
    }

    int equals(void *p1, void *p2)
    {
	return *(real *)p1 == *(real *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*(real *)p1 - *(real *)p2);
    }

    int tsize()
    {
	return real.size;
    }

    void swap(void *p1, void *p2)
    {
	real t;

	t = *(real *)p1;
	*(real *)p1 = *(real *)p2;
	*(real *)p2 = t;
    }
}

