
// ubyte

class TypeInfo_h : TypeInfo
{
    uint getHash(void *p)
    {
	return *cast(ubyte *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(ubyte *)p1 == *cast(ubyte *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(ubyte *)p1 - *cast(ubyte *)p2;
    }

    int tsize()
    {
	return ubyte.size;
    }

    void swap(void *p1, void *p2)
    {
	ubyte t;

	t = *cast(ubyte *)p1;
	*cast(ubyte *)p1 = *cast(ubyte *)p2;
	*cast(ubyte *)p2 = t;
    }
}

