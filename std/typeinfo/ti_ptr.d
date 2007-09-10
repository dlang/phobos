
// pointer

module std.typeinfo.ti_ptr;

class TypeInfo_P : TypeInfo
{
    hash_t getHash(in void *p)
    {
	return cast(uint)*cast(void* *)p;
    }

    int equals(in void *p1, in void *p2)
    {
	return *cast(void* *)p1 == *cast(void* *)p2;
    }

    int compare(in void *p1, in void *p2)
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

    uint flags()
    {
	return 1;
    }
}

