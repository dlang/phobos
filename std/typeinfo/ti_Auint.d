
private import std.string;

// uint[]

class TypeInfo_Ak : TypeInfo
{
    char[] toString() { return "uint[]"; }

    uint getHash(void *p)
    {	uint[] s = *cast(uint[]*)p;
	size_t len = s.length;
	uint *str = s;
	uint hash = 0;

	while (len)
	{
	    hash *= 9;
	    hash += *cast(uint *)str;
	    str++;
	    len--;
	}

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	uint[] s1 = *cast(uint[]*)p1;
	uint[] s2 = *cast(uint[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(void *)s1, cast(void *)s2, s1.length * uint.sizeof) == 0;
    }

    int compare(void *p1, void *p2)
    {
	uint[] s1 = *cast(uint[]*)p1;
	uint[] s2 = *cast(uint[]*)p2;
	size_t len = s1.length;

	if (s2.length < len)
	    len = s2.length;
	for (size_t u = 0; u < len; u++)
	{
	    int result = s1[u] - s2[u];
	    if (result)
		return result;
	}
	return cast(int)s1.length - cast(int)s2.length;
    }

    size_t tsize()
    {
	return (uint[]).sizeof;
    }
}

