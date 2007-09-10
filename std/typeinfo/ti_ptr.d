
// pointer

module std.typeinfo.ti_ptr;

class TypeInfo_P : TypeInfo
{
    uint getHash(void *p)
    {
	return cast(uint)*cast(void* *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(void* *)p1 == *cast(void* *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(void* *)p1 - *cast(void* *)p2;
    }

    size_t tsize()
    {
	return (void*).sizeof;
    }

    void swap(void *p1, void *p2)
    {
	void* t;

	t = *cast(void* *)p1;
	*cast(void* *)p1 = *cast(void* *)p2;
	*cast(void* *)p2 = t;
    }
}

