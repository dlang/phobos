
module std.typeinfo.ti_Ag;

private import std.string;
private import std.c.string;

// byte[]

class TypeInfo_Ag : TypeInfo
{
    char[] toString() { return "byte[]"; }

    hash_t getHash(void *p)
    {	byte[] s = *cast(byte[]*)p;
	size_t len = s.length;
	byte *str = s;
	hash_t hash = 0;

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

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	byte[] s1 = *cast(byte[]*)p1;
	byte[] s2 = *cast(byte[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(byte *)s1, cast(byte *)s2, s1.length) == 0;
    }

    int compare(void *p1, void *p2)
    {
	byte[] s1 = *cast(byte[]*)p1;
	byte[] s2 = *cast(byte[]*)p2;
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
	return (byte[]).sizeof;
    }
}

