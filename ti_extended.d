
// extended

class TypeInfo_e : TypeInfo
{
    uint getHash(void *p)
    {
	return *(extended *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *(extended *)p1 == *(extended *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *(extended *)p1 - *(extended *)p2;
    }

    int tsize()
    {
	return extended.size;
    }

    void swap(void *p1, void *p2)
    {
	extended t;

	t = *(extended *)p1;
	*(extended *)p1 = *(extended *)p2;
	*(extended *)p2 = t;
    }
}

