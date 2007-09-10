
// byte

class TypeInfo_g : TypeInfo
{
    uint getHash(void *p)
    {
	return *(byte *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(byte *)p1 == *(byte *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(byte *)p1 - *(byte *)p2;
    }

    int tsize()
    {
	return byte.size;
    }

    void swap(void *p1, void *p2)
    {
	byte t;

	t = *(byte *)p1;
	*(byte *)p1 = *(byte *)p2;
	*(byte *)p2 = t;
    }
}

