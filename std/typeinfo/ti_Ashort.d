
private import std.string;

// short[]

class TypeInfo_As : TypeInfo
{
    uint getHash(void *p)
    {	short[] s = *cast(short[]*)p;
	uint len = s.length;
	short *str = s;
	uint hash = 0;

	while (1)
	{
	    switch (len)
	    {
		case 0:
		    return hash;

		case 1:
		    hash *= 9;
		    hash += *cast(short *)str;
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
	short[] s1 = *cast(short[]*)p1;
	short[] s2 = *cast(short[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(void *)s1, cast(void *)s2, s1.length * short.sizeof) == 0;
    }

    int compare(void *p1, void *p2)
    {
	short[] s1 = *cast(short[]*)p1;
	short[] s2 = *cast(short[]*)p2;
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
	return (short[]).sizeof;
    }
}

