
// pointer

class TypeInfo_P : TypeInfo
{
    uint getHash(void *p)
    {
	return (uint)*(void* *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(void* *)p1 == *(void* *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(void* *)p1 - *(void* *)p2;
    }

    int tsize()
    {
	return (void*).size;
    }

    void swap(void *p1, void *p2)
    {
	void* t;

	t = *(void* *)p1;
	*(void* *)p1 = *(void* *)p2;
	*(void* *)p2 = t;
    }
}

