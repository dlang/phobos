
// real

class TypeInfo_e : TypeInfo
{
    char[] toString() { return "real"; }

    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1] + (cast(ushort *)p)[4];
    }

    int equals(void *p1, void *p2)
    {
	return *cast(real *)p1 == *cast(real *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*cast(real *)p1 - *cast(real *)p2);
    }

    int tsize()
    {
	return real.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	real t;

	t = *cast(real *)p1;
	*cast(real *)p1 = *cast(real *)p2;
	*cast(real *)p2 = t;
    }
}

