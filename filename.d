
// Copyright (c) 2001 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

// File name parsing

class FileName
{
    /**************************
     * Get extension.
     * For example, "d:\path\foo.bat" returns "bat".
     */

    static char[] getExt(char[] fullname)
    {
	uint i;

	i = fullname.length;
	while (i > 0)
	{
	    i--;
	    if (fullname[i] == '.')
		break;
	    version(Win32)
	    {
		if (fullname[i] == ':' || fullname[i] == '\')
		    return null;
	    }
	    version(linux)
	    {
		if (fullname[i] == '/')
		    return null;
	    }
	}
	return fullname[i .. fullname.length];
    }

    /**************************
     * Get name.
     * For example, "d:\path\foo.bat" returns "foo.bat".
     */

    static char[] getName(char[] fullname)
	out (result)
	{
	    assert(result.length <= fullname.length);
	}
	body
	{
	    uint i;

	    for (i = fullname.length; i > 0; i--)
	    {
		version(Win32)
		{
		    if (fullname[i - 1] == ':' || fullname[i - 1] == '\')
			return null;
		}
		version(linux)
		{
		    if (fullname[i - 1] == '/')
			return null;
		}
	    }
	    return fullname[i .. fullname.length];
	}


    /****************************
     * Put a default extension on fullname if it doesn't already
     * have an extension.
     */

    static char[] defaultExt(char[] fullname, char[] ext)
    {
	char[] existing;

	existing = getExt(fullname);
	if (existing.length == 0)
	{
	    // Check for fullname ending in '.'
	    if (fullname.length && fullname[fullname.length - 1] == '.')
		fullname ~= ext;
	    else
		fullname = fullname ~ '.' ~ ext;
	}
	return fullname;
    }

}
