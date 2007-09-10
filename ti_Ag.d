
import string;

// byte[]

class TypeInfo_Ag : TypeInfo
{
    uint getHash(void *p)
    {	byte[] s = *(byte[]*)p;
	uint len = s.length;
	byte *str = s;
	uint hash = 0;

	while (1)
	{
	    switch (len)
	    {
		case 0:
		    return hash;

		case 1:
		    hash *= 9;
		    hash += *(ubyte *)str;
		    return hash;

		case 2:
		    hash *= 9;
		    hash += *(ushort *)str;
		    return hash;

		case 3:
		    hash *= 9;
		    hash += (*(ushort *)str << 8) +
			    ((ubyte *)str)[2];
		    return hash;

		default:
		    hash *= 9;
		    hash += *(uint *)str;
		    str += 4;
		    len -= 4;
		    break;
	    }
	}

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	byte[] s1 = *(byte[]*)p1;
	byte[] s2 = *(byte[]*)p2;

	return s1.length == s2.length &&
	       memcmp((byte *)s1, (byte *)s2, s1.length) == 0;
    }

    int compare(void *p1, void *p2)
    {
	char[] s1 = *(char[]*)p1;
	char[] s2 = *(char[]*)p2;

	return string.cmp(s1, s2);
    }

    int tsize()
    {
	return (byte[]).size;
    }
}

