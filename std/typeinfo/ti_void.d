
// void

class TypeInfo_v : TypeInfo
{
    char[] toString() { return "void"; }

    uint getHash(void *p)
    {
	assert(0);
	return *cast(byte *)p;
    }

    int equals(void *p1, void *p2)
    {
	assert(0);
	return *cast(byte *)p1 == *cast(byte *)p2;
    }

    int compare(void *p1, void *p2)
    {
	assert(0);
	return *cast(byte *)p1 - *cast(byte *)p2;
    }

    int tsize()
    {
	return void.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	byte t;

	assert(0);
	t = *cast(byte *)p1;
	*cast(byte *)p1 = *cast(byte *)p2;
	*cast(byte *)p2 = t;
    }
}

