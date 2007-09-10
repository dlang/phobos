

class TypeInfo_a : TypeInfo
{
    char[] toString() { return "char"; }

    uint getHash(void *p)
    {
	return *cast(char *)p;
    }

    int equals(void *p1, void *p2)
    {
	return *cast(char *)p1 == *cast(char *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return *cast(char *)p1 - *cast(char *)p2;
    }

    int tsize()
    {
	return char.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	char t;

	t = *cast(char *)p1;
	*cast(char *)p1 = *cast(char *)p2;
	*cast(char *)p2 = t;
    }
}

