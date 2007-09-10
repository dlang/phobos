
// ubyte

class TypeInfo_h : TypeInfo
{
    uint getHash(void *p)
    {
	return *(ubyte *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(ubyte *)p1 == *(ubyte *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(ubyte *)p1 - *(ubyte *)p2;
    }

    int tsize()
    {
	return ubyte.size;
    }

    void swap(void *p1, void *p2)
    {
	ubyte t;

	t = *(ubyte *)p1;
	*(ubyte *)p1 = *(ubyte *)p2;
	*(ubyte *)p2 = t;
    }
}

