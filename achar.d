
extern (C)
{
    int memcmp(char *, char *, int);
}

class Achar
{
    static int compare(char[] a, char[] b)
    {	int result;

	result = b.length - a.length;
	if (result == 0)
	    result = memcmp((char *)a, (char *)b, a.length);
	return result;
    }

    static int equals(char[] a, char[] b)
    {
	return	(b.length == a.length) &&
		(memcmp((char *)a, (char *)b, a.length) == 0);
    }
}
