
import std.string;

// Object[]

class TypeInfo_AC : TypeInfo
{
    uint getHash(void *p)
    {	Object[] s = *(Object[]*)p;
	uint len = s.length;
	uint hash = 0;

	for (uint u = 0; u < len; u++)
	    hash += s[u].toHash();

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	Object[] s1 = *(Object[]*)p1;
	Object[] s2 = *(Object[]*)p2;

	if (s1.length == s2.length)
	{
	    for (uint u = 0; u < s1.length; u++)
	    {
		// Do not pass null's to Object.eq()
		if (s1[u] === s2[u] ||
		    (s1[u] !== null && s2[u] !== null && s1[u].eq(s2[u])))
		    continue;
		return 0;
	    }
	    return 1;
	}
	return 0;
    }

    int compare(void *p1, void *p2)
    {
	Object[] s1 = *(Object[]*)p1;
	Object[] s2 = *(Object[]*)p2;
	int c;

	c = cast(int)s1.length - cast(int)s2.length;
	if (c == 0)
	{
	    for (uint u = 0; u < s1.length; u++)
	    {	Object o1 = s1[u];
		Object o2 = s2[u];

		if (o1 === o2)
		    continue;

		// Regard null references as always being "less than"
		if (o1)
		{
		    if (!o2)
		    {	c = 1;
			break;
		    }
		    c = o1.cmp(o2);
		    if (c)
			break;
		}
		else
		{   c = -1;
		    break;
		}
	    }
	}
	return c;
    }

    int tsize()
    {
	return (Object[]).size;
    }
}

