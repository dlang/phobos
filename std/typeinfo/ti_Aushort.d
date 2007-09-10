
module std.typeinfo.ti_Aushort;

private import std.c.string;

// ushort[]

class TypeInfo_At : TypeInfo
{
    char[] toString() { return "ushort[]"; }

    hash_t getHash(void *p)
    {	ushort[] s = *cast(ushort[]*)p;
	size_t len = s.length;
	ushort *str = s;
	hash_t hash = 0;

	while (1)
	{
	    switch (len)
	    {
		case 0:
		    return hash;

		case 1:
		    hash *= 9;
		    hash += *cast(ushort *)str;
		    return hash;

		default:
		    hash *= 9;
		    hash += *cast(uint *)str;
		    str += 2;
		    len -= 2;
		    break;
	    }
	}

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	ushort[] s1 = *cast(ushort[]*)p1;
	ushort[] s2 = *cast(ushort[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(void *)s1, cast(void *)s2, s1.length * ushort.sizeof) == 0;
    }

    int compare(void *p1, void *p2)
    {
	ushort[] s1 = *cast(ushort[]*)p1;
	ushort[] s2 = *cast(ushort[]*)p2;
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
	return (ushort[]).sizeof;
    }
}

