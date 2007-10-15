
// float

module std.typeinfo.ti_float;

private import std.math;

class TypeInfo_f : TypeInfo
{
    override string toString() { return "float"; }

    override hash_t getHash(in void *p)
    {
	return *cast(uint *)p;
    }

    static int _equals(float f1, float f2)
    {
	return f1 == f2 ||
		(isnan(f1) && isnan(f2));
    }

    static int _compare(float d1, float d2)
    {
	if (d1 !<>= d2)		// if either are NaN
	{
	    if (isnan(d1))
	    {	if (isnan(d2))
		    return 0;
		return -1;
	    }
	    return 1;
	}
	return (d1 == d2) ? 0 : ((d1 < d2) ? -1 : 1);
    }

    override int equals(in void *p1, in void *p2)
    {
	return _equals(*cast(float *)p1, *cast(float *)p2);
    }

    override int compare(in void *p1, in void *p2)
    {
	return _compare(*cast(float *)p1, *cast(float *)p2);
    }

    override size_t tsize()
    {
	return float.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
	float t;

	t = *cast(float *)p1;
	*cast(float *)p1 = *cast(float *)p2;
	*cast(float *)p2 = t;
    }

    override void[] init()
    {	static float r;

	return (cast(float *)&r)[0 .. 1];
    }
}

