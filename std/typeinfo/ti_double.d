
// double

class TypeInfo_d : TypeInfo
{
    char[] toString() { return "double"; }

    uint getHash(void *p)
    {
	return (cast(uint *)p)[0] + (cast(uint *)p)[1];
    }

    int equals(void *p1, void *p2)
    {
	return *cast(double *)p1 == *cast(double *)p2;
    }

    int compare(void *p1, void *p2)
    {
	return cast(int)(*cast(double *)p1 - *cast(double *)p2);
    }

    int tsize()
    {
	return double.sizeof;
    }

    void swap(void *p1, void *p2)
    {
	double t;

	t = *cast(double *)p1;
	*cast(double *)p1 = *cast(double *)p2;
	*cast(double *)p2 = t;
    }
}

