
/**
 * Boilerplate:
 *	$(std_boilerplate.html)
 * Macros:
 *	WIKI = StdPath
 * Copyright:
 *	Copyright (c) 2001-2005 by Digital Mars
 *	All Rights Reserved
 *	www.digitalmars.com
 */

// File name parsing

module std.path;

//debug=path;		// uncomment to turn on debugging printf's

private import std.string;

version(Win32)
{

    const char[1] sep = "\\";	 /// String used to separate directory names in a path.
    const char[1] altsep = "/";	 /// Alternate version of sep[], used in Windows.
    const char[1] pathsep = ";"; /// Path separator string.
    const char[2] linesep = "\r\n"; /// String used to separate lines.
    const char[1] curdir = ".";	 /// String representing the current directory.
    const char[2] pardir = ".."; /// String representing the parent directory.
}
version(linux)
{
    const char[1] sep = "/";	 /// String used to separate directory names in a path.
    const char[0] altsep;	 /// Alternate version of sep[], used in Windows.
    const char[1] pathsep = ":"; /// Path separator string.
    const char[1] linesep = "\n"; /// String used to separate lines.
    const char[1] curdir = ".";	 /// String representing the current directory.
    const char[2] pardir = ".."; /// String representing the parent directory.
}

/**************************
 * Get extension.
 * For example, "d:\path\foo.bat" returns "bat".
 */

char[] getExt(char[] fullname)
{
    uint i;

    i = fullname.length;
    while (i > 0)
    {
	if (fullname[i - 1] == '.')
	    return fullname[i .. fullname.length];
	i--;
	version(Win32)
	{
	    if (fullname[i] == ':' || fullname[i] == '\\')
		break;
	}
	version(linux)
	{
	    if (fullname[i] == '/')
		break;
	}
    }
    return null;
}

unittest
{
    debug(path) printf("path.getExt.unittest\n");
    int i;
    char[] result;

    version (Win32)
	result = getExt("d:\\path\\foo.bat");
    version (linux)
	result = getExt("/path/foo.bat");
    i = cmp(result, "bat");
    assert(i == 0);

    version (Win32)
	result = getExt("d:\\path\\foo.");
    version (linux)
	result = getExt("d/path/foo.");
    i = cmp(result, "");
    assert(i == 0);

    version (Win32)
	result = getExt("d:\\path\\foo");
    version (linux)
	result = getExt("d/path/foo");
    i = cmp(result, "");
    assert(i == 0);

    version (Win32)
	result = getExt("d:\\path.bar\\foo");
    version (linux)
	result = getExt("/path.bar/foo");

    i = cmp(result, "");
    assert(i == 0);

    result = getExt("foo");
    i = cmp(result, "");
    assert(i == 0);
}

/**************************
 * Get base name.
 * For example, "d:\path\foo.bat" returns "foo.bat".
 */

char[] getBaseName(char[] fullname)
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
		if (fullname[i - 1] == ':' || fullname[i - 1] == '\\')
		    break;
	    }
	    version(linux)
	    {
		if (fullname[i - 1] == '/')
		    break;
	    }
	}
	return fullname[i .. fullname.length];
    }

unittest
{
    debug(path) printf("path.getBaseName.unittest\n");
    int i;
    char[] result;

    version (Win32)
	result = getBaseName("d:\\path\\foo.bat");
    version (linux)
	result = getBaseName("/path/foo.bat");
    //printf("result = '%.*s'\n", result);
    i = cmp(result, "foo.bat");
    assert(i == 0);

    version (Win32)
	result = getBaseName("a\\b");
    version (linux)
	result = getBaseName("a/b");
    i = cmp(result, "b");
    assert(i == 0);
}


/**************************
 * Get directory name.
 * For example, "d:\path\foo.bat" returns "d:\path".
 */

char[] getDirName(char[] fullname)
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
		if (fullname[i - 1] == ':')
		    break;
		if (fullname[i - 1] == '\\')
		{   i--;
		    break;
		}
	    }
	    version(linux)
	    {
		if (fullname[i - 1] == '/')
		{   i--;
		    break;
		}
	    }
	}
	return fullname[0 .. i];
    }


/********************************
 * Get drive.
 * For example, "d:\path\foo.bat" returns "d:".
 */

char[] getDrive(char[] fullname)
    out (result)
    {
	assert(result.length <= fullname.length);
    }
    body
    {
	version(Win32)
	{
	    int i;

	    for (i = 0; i < fullname.length; i++)
	    {
		if (fullname[i] == ':')
		    return fullname[0 .. i + 1];
	    }
	    return null;
	}
	version(linux)
	{
	    return null;
	}
    }

/****************************
 * If filename doesn't already have an extension,
 * append the extension ext and return the result.
 */

char[] defaultExt(char[] filename, char[] ext)
{
    char[] existing;

    existing = getExt(filename);
    if (existing.length == 0)
    {
	// Check for filename ending in '.'
	if (filename.length && filename[filename.length - 1] == '.')
	    filename ~= ext;
	else
	    filename = filename ~ "." ~ ext;
    }
    return filename;
}


/****************************
 * Strip any existing extension off of filename and add the new extension ext.
 * Return the result.
 */

char[] addExt(char[] filename, char[] ext)
{
    char[] existing;

    existing = getExt(filename);
    if (existing.length == 0)
    {
	// Check for filename ending in '.'
	if (filename.length && filename[filename.length - 1] == '.')
	    filename ~= ext;
	else
	    filename = filename ~ "." ~ ext;
    }
    else
    {
	filename = filename[0 .. filename.length - existing.length] ~ ext;
    }
    return filename;
}


/*************************************
 * Return !=0 if path is absolute (i.e. it starts from the root directory).
 */

int isabs(char[] path)
{
    char[] d = getDrive(path);

    return d.length < path.length && path[d.length] == sep[0];
}

/*************************************
 * Join two path components p1 and p2 and return the result.
 */

char[] join(char[] p1, char[] p2)
{
    if (!p2.length)
	return p1;
    if (!p1.length)
	return p2;

    char[] p;
    char[] d1;

    version(Win32)
    {
	if (getDrive(p2))
	{
	    p = p2;
	}
	else
	{
	    d1 = getDrive(p1);
	    if (p1.length == d1.length)
	    {
		p = p1 ~ p2;
	    }
	    else if (p2[0] == '\\')
	    {
		if (d1.length == 0)
		    p = p2;
		else if (p1[p1.length - 1] == '\\')
		    p = p1 ~ p2[1 .. p2.length];
		else
		    p = p1 ~ p2;
	    }
	    else if (p1[p1.length - 1] == '\\')
	    {
		p = p1 ~ p2;
	    }
	    else
	    {
		p = p1 ~ sep ~ p2;
	    }
	}
    }
    version(linux)
    {
	if (p2[0] == sep[0])
	{
	    p = p2;
	}
	else if (p1[p1.length - 1] == sep[0])
	{
	    p = p1 ~ p2;
	}
	else
	{
	    p = p1 ~ sep ~ p2;
	}
    }
    return p;
}

unittest
{
    debug(path) printf("path.join.unittest\n");

    char[] p;
    int i;

    p = join("foo", "bar");
    version (Win32)
	i = cmp(p, "foo\\bar");
    version (linux)
	i = cmp(p, "foo/bar");
    assert(i == 0);

    version (Win32)
    {	p = join("foo\\", "bar");
	i = cmp(p, "foo\\bar");
    }
    version (linux)
    {	p = join("foo/", "bar");
	i = cmp(p, "foo/bar");
    }
    assert(i == 0);

    version (Win32)
    {	p = join("foo", "\\bar");
	i = cmp(p, "\\bar");
    }
    version (linux)
    {	p = join("foo", "/bar");
	i = cmp(p, "/bar");
    }
    assert(i == 0);

    version (Win32)
    {	p = join("foo\\", "\\bar");
	i = cmp(p, "\\bar");
    }
    version (linux)
    {	p = join("foo/", "/bar");
	i = cmp(p, "/bar");
    }
    assert(i == 0);

    version(Win32)
    {
	p = join("d:", "bar");
	i = cmp(p, "d:bar");
	assert(i == 0);

	p = join("d:\\", "bar");
	i = cmp(p, "d:\\bar");
	assert(i == 0);

	p = join("d:\\", "\\bar");
	i = cmp(p, "d:\\bar");
	assert(i == 0);

	p = join("d:\\foo", "bar");
	i = cmp(p, "d:\\foo\\bar");
	assert(i == 0);

	p = join("d:", "\\bar");
	i = cmp(p, "d:\\bar");
	assert(i == 0);

	p = join("foo", "d:");
	i = cmp(p, "d:");
	assert(i == 0);

	p = join("foo", "d:\\");
	i = cmp(p, "d:\\");
	assert(i == 0);

	p = join("foo", "d:\\bar");
	i = cmp(p, "d:\\bar");
	assert(i == 0);
    }
}


/*********************************
 * Match file name characters c1 and c2.
 * Case sensitivity depends on the operating system.
 */

int fncharmatch(dchar c1, dchar c2)
{
    version (Win32)
    {
	if (c1 != c2)
	{
	    if ('A' <= c1 && c1 <= 'Z')
		c1 += cast(char)'a' - 'A';
	    if ('A' <= c2 && c2 <= 'Z')
		c2 += cast(char)'a' - 'A';
	    return c1 == c2;
	}
	return true;
    }
    version (linux)
    {
	return c1 == c2;
    }
}

/************************************
 * Match filename with pattern, using the following wildcards:
 *
 *	<table>
 *	<tr><td><b>*</b> <td>match 0 or more characters
 *	<tr><td><b>?</b> <td>match any character
 *	<tr><td><b>[</b><i>chars</i><b>]</b> <td>match any character that appears between the []
 *	<tr><td><b>[!</b><i>chars</i><b>]</b> <td>match any character that does not appear between the [! ]
 *	</table>
 *
 * Matching is case sensitive on a file system that is case sensitive.
 *
 * Returns:
 *	!=0 for match
 */

int fnmatch(char[] filename, char[] pattern)
    in
    {
	// Verify that pattern[] is valid
	int i;
	int inbracket = false;

	for (i = 0; i < pattern.length; i++)
	{
	    switch (pattern[i])
	    {
		case '[':
		    assert(!inbracket);
		    inbracket = true;
		    break;

		case ']':
		    assert(inbracket);
		    inbracket = false;
		    break;

		default:
		    break;
	    }
	}
    }
    body
    {
	int pi;
	int ni;
	char pc;
	char nc;
	int j;
	int not;
	int anymatch;

	ni = 0;
	for (pi = 0; pi < pattern.length; pi++)
	{
	    pc = pattern[pi];
	    switch (pc)
	    {
		case '*':
		    if (pi + 1 == pattern.length)
			goto match;
		    for (j = ni; j < filename.length; j++)
		    {
			if (fnmatch(filename[j .. filename.length], pattern[pi + 1 .. pattern.length]))
			    goto match;
		    }
		    goto nomatch;

		case '?':
		    if (ni == filename.length)
			goto nomatch;
		    ni++;
		    break;

		case '[':
		    if (ni == filename.length)
			goto nomatch;
		    nc = filename[ni];
		    ni++;
		    not = 0;
		    pi++;
		    if (pattern[pi] == '!')
		    {	not = 1;
			pi++;
		    }
		    anymatch = 0;
		    while (1)
		    {
			pc = pattern[pi];
			if (pc == ']')
			    break;
			if (!anymatch && fncharmatch(nc, pc))
			    anymatch = 1;
			pi++;
		    }
		    if (!(anymatch ^ not))
			goto nomatch;
		    break;

		default:
		    if (ni == filename.length)
			goto nomatch;
		    nc = filename[ni];
		    if (!fncharmatch(pc, nc))
			goto nomatch;
		    ni++;
		    break;
	    }
	}
	if (ni < filename.length)
	    goto nomatch;

    match:
	return true;

    nomatch:
	return false;
    }

unittest
{
    debug(path) printf("path.fnmatch.unittest\n");

    version (Win32)
	assert(fnmatch("foo", "Foo"));
    version (linux)
	assert(!fnmatch("foo", "Foo"));
    assert(fnmatch("foo", "*"));
    assert(fnmatch("foo.bar", "*"));
    assert(fnmatch("foo.bar", "*.*"));
    assert(fnmatch("foo.bar", "foo*"));
    assert(fnmatch("foo.bar", "f*bar"));
    assert(fnmatch("foo.bar", "f*b*r"));
    assert(fnmatch("foo.bar", "f???bar"));
    assert(fnmatch("foo.bar", "[fg]???bar"));
    assert(fnmatch("foo.bar", "[!gh]*bar"));

    assert(!fnmatch("foo", "bar"));
    assert(!fnmatch("foo", "*.*"));
    assert(!fnmatch("foo.bar", "f*baz"));
    assert(!fnmatch("foo.bar", "f*b*x"));
    assert(!fnmatch("foo.bar", "[gh]???bar"));
    assert(!fnmatch("foo.bar", "[!fg]*bar"));
    assert(!fnmatch("foo.bar", "[fg]???baz"));
}
