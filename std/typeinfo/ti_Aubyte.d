
module std.typeinfo.ti_Aubyte;

private import std.string;
private import std.c.string;

// ubyte[]

class TypeInfo_Ah : TypeInfo
{
    char[] toString() { return "ubyte[]"; }

    hash_t getHash(void *p)
    {	ubyte[] s = *cast(ubyte[]*)p;
	size_t len = s.length;
	ubyte *str = s.ptr;
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
	ubyte[] s1 = *cast(ubyte[]*)p1;
	ubyte[] s2 = *cast(ubyte[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(ubyte *)s1, cast(ubyte *)s2, s1.length) == 0;
    }

    int compare(void *p1, void *p2)
    {
	char[] s1 = *cast(char[]*)p1;
	char[] s2 = *cast(char[]*)p2;

	return std.string.cmp(s1, s2);
    }

    size_t tsize()
    {
	return (ubyte[]).sizeof;
    }
}

// void[]

class TypeInfo_Av : TypeInfo_Ah
{
    char[] toString() { return "void[]"; }
}

// bool[]

class TypeInfo_Ab : TypeInfo_Ah
{
    char[] toString() { return "bool[]"; }
}
