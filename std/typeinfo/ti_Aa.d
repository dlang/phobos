
private import std.string;

// char[]

class TypeInfo_Aa : TypeInfo
{
    char[] toString() { return "char[]"; }

    uint getHash(void *p)
    {	char[] s = *cast(char[]*)p;
	uint hash = 0;

version (all)
{
	foreach (char c; s)
	    hash = hash * 11 + c;
}
else
{
	size_t len = s.length;
	char *str = s;

	while (1)
	{
	    switch (len)
	    {
		case 0:
		    return hash;

		case 1:
		    hash *= 9;
		    hash += *cast(ubyte *)str;
		    return hash;

		case 2:
		    hash *= 9;
		    hash += *cast(ushort *)str;
		    return hash;

		case 3:
		    hash *= 9;
		    hash += (*cast(ushort *)str << 8) +
			    (cast(ubyte *)str)[2];
		    return hash;

		default:
		    hash *= 9;
		    hash += *cast(uint *)str;
		    str += 4;
		    len -= 4;
		    break;
	    }
	}
}
	return hash;
    }

    int equals(void *p1, void *p2)
    {
	char[] s1 = *cast(char[]*)p1;
	char[] s2 = *cast(char[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(char *)s1, cast(char *)s2, s1.length) == 0;
    }

    int compare(void *p1, void *p2)
    {
	char[] s1 = *cast(char[]*)p1;
	char[] s2 = *cast(char[]*)p2;

	return std.string.cmp(s1, s2);
    }

    size_t tsize()
    {
	return (char[]).sizeof;
    }
}

