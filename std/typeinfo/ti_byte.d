
// byte

class TypeInfo_g : TypeInfo
{
    uint getHash(void *p)
    {
	return *cast(byte *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(byte *)p1 == *cast(byte *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(byte *)p1 - *cast(byte *)p2;
    }

    int tsize()
    {
	return byte.size;
    }

    void swap(void *p1, void *p2)
    {
	byte t;

	t = *cast(byte *)p1;
	*cast(byte *)p1 = *cast(byte *)p2;
	*cast(byte *)p2 = t;
    }
}

