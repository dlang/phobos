
module std.typeinfo.ti_Adchar;

private import std.c.string;

// dchar[]

class TypeInfo_Aw : TypeInfo
{
    char[] toString() { return "dchar[]"; }

    hash_t getHash(void *p)
    {	dchar[] s = *cast(dchar[]*)p;
	size_t len = s.length;
	dchar *str = s.ptr;
	hash_t hash = 0;

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
	dchar[] s1 = *cast(dchar[]*)p1;
	dchar[] s2 = *cast(dchar[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(void *)s1, cast(void *)s2, s1.length * dchar.sizeof) == 0;
    }

    int compare(void *p1, void *p2)
    {
	dchar[] s1 = *cast(dchar[]*)p1;
	dchar[] s2 = *cast(dchar[]*)p2;
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
	return (dchar[]).sizeof;
    }
}

