
import string;

// uint[]

class TypeInfo_Ak : TypeInfo
{
    uint getHash(void *p)
    {	uint[] s = *(uint[]*)p;
	uint len = s.length;
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
	uint[] s1 = *(uint[]*)p1;
	uint[] s2 = *(uint[]*)p2;

	return s1.length == s2.length &&
	       memcmp((void *)s1, (void *)s2, s1.length * uint.size) == 0;
    }

    int compare(void *p1, void *p2)
    {
	uint[] s1 = *(uint[]*)p1;
	uint[] s2 = *(uint[]*)p2;
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
	return (uint[]).size;
    }
}

