
// Copyright (c) 2001 by Digital Mars
// www.digitalmars.com
// Convert Win32 error code to string

class SysError
{
    import c.stdio;
    import string;

    static char[] msg(uint errcode)
    {
	char[] result;

	switch (errcode)
	{
	    case 2:	result = "file not found";	break;
	    case 3:	result = "path not found";	break;
	    case 4:	result = "too many open files";	break;
	    case 5:	result = "access denied";	break;
	    case 6:	result = "invalid handle";	break;
	    case 8:	result = "not enough memory";	break;
	    case 14:	result = "out of memory";	break;
	    case 15:	result = "invalid drive";	break;
	    case 21:	result = "not ready";		break;
	    case 32:	result = "sharing violation";	break;

	    default:
		result = new char[uint.size * 3 + 1];
		sprintf(result, "%u", errcode);
		result = result[0 .. strlen(result)];
		break;
	}

	return result;
    }
}
