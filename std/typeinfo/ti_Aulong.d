
private import std.string;

// ulong[]

class TypeInfo_Am : TypeInfo
{
    char[] toString() { return "ulong[]"; }

    uint getHash(void *p)
    {	ulong[] s = *cast(ulong[]*)p;
	uint len = s.length;
	ulong *str = s;
	uint hash = 0;

	while (len)
	{
	    hash *= 9;
	    hash += *cast(uint *)str;
	    str += 1;
	    len -= 1;
	}

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	ulong[] s1 = *cast(ulong[]*)p1;
	ulong[] s2 = *cast(ulong[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(void *)s1, cast(void *)s2, s1.length * ulong.sizeof) == 0;
    }

    int compare(void *p1, void *p2)
    {
	ulong[] s1 = *cast(ulong[]*)p1;
	ulong[] s2 = *cast(ulong[]*)p2;
	uint len = s1.length;

	if (s2.length < len)
	    len = s2.length;
	for (uint u = 0; u < len; u++)
	{
	    int result = s1[u] - s2[u];
	    if (result)
		return result;
	}
	return cast(int)s1.length - cast(int)s2.length;
    }

    int tsize()
    {
	return (ulong[]).sizeof;
    }
}

