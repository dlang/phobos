
/**
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
//private import std.stdio;

private import std.string;

version(linux)
{
    private import std.c.stdlib;
    private import std.c.linux.linux;
    private import std.outofmemory;
}

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
 * Get name without extension.
 * For example, "d:\path\foo.bat" returns "d:\path\foo".
 */

char[] getName(char[] fullname)
{
    uint i;

    i = fullname.length;
    while (i > 0)
    {
	if (fullname[i - 1] == '.')
	    return fullname[0 .. i - 1];
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
    debug(path) printf("path.getName.unittest\n");
    int i;
    char[] result;

    result = getName("foo.bar");
    i = cmp(result, "foo");
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

/**
 * Performs tilde expansion in paths.
 *
 * There are two ways of using tilde expansion in a path. One
 * involves using the tilde alone or followed by a path separator. In
 * this case, the tilde will be expanded with the value of the
 * environment variable <i>HOME</i>.  The second way is putting
 * a username after the tilde (i.e. <tt>~john/Mail</tt>). Here,
 * the username will be searched for in the user database
 * (i.e. <tt>/etc/passwd</tt> on Unix systems) and will expand to
 * whatever path is stored there.  The username is considered the
 * string after the tilde ending at the first instance of a path
 * separator.
 *
 * Note that using the <i>~user</i> syntax may give different
 * values from just <i>~</i> if the environment variable doesn't
 * match the value stored in the user database.
 *
 * When the environment variable version is used, the path won't
 * be modified if the environment variable doesn't exist. When the
 * database version is used, the path won't be modified if the user
 * doesn't exist in the database or there is not enough memory to
 * perform the query.
 *
 * Returns: inputPath with the tilde expanded, or just inputPath
 * if it could not be expanded.
 * For Windows, expandTilde() merely returns its argument inputPath.
 *
 * Throws: std.OutOfMemory
 *
 * Examples:
 * -----
 * import std.path;
 *
 * void process_file(char[] filename)
 * {
 *     char[] path = expandTilde(filename);
 *     ...
 * }
 * -----
 *
 * -----
 * import std.path;
 *
 * const char[] RESOURCE_DIR_TEMPLATE = "~/.applicationrc";
 * char[] RESOURCE_DIR;    // This gets expanded in main().
 *
 * int main(char[][] args)
 * {
 *     RESOURCE_DIR = expandTilde(RESOURCE_DIR_TEMPLATE);
 *     ...
 * }
 * -----
 * Version: Available since v0.143.
 * Authors: Grzegorz Adam Hankiewicz, Thomas Kuehne.
 */

char[] expandTilde(char[] inputPath)
{
    version(linux)
    {
	static assert(sep.length == 1);

        // Return early if there is no tilde in path.
        if (inputPath.length < 1 || inputPath[0] != '~')
	    return inputPath;

	if (inputPath.length == 1 || inputPath[1] == sep[0])
	    return expandFromEnvironment(inputPath);
        else
	    return expandFromDatabase(inputPath);
    }
    else version(Windows)
    {
	// Put here real windows implementation.
	return inputPath;
    }
    else
    {
	static assert(0); // Guard. Implement on other platforms.
    }
}


unittest
{
    debug(path) printf("path.expandTilde.unittest\n");

    version (linux)
    {
	// Retrieve the current home variable.
	char* c_home = getenv("HOME");

	// Testing when there is no environment variable.
	unsetenv("HOME");
	assert(expandTilde("~/") == "~/");
	assert(expandTilde("~") == "~");

	// Testing when an environment variable is set.
	int ret = setenv("HOME", "dmd/test\0", 1);
	assert(ret == 0);
	assert(expandTilde("~/") == "dmd/test/");
	assert(expandTilde("~") == "dmd/test");

	// The same, but with a variable ending in a slash.
	ret = setenv("HOME", "dmd/test/\0", 1);
	assert(ret == 0);
	assert(expandTilde("~/") == "dmd/test/");
	assert(expandTilde("~") == "dmd/test");

	// Recover original HOME variable before continuing.
	if (c_home)
	    setenv("HOME", c_home, 1);
	else
	    unsetenv("HOME");

	// Test user expansion for root. Are there unices without /root?
	assert(expandTilde("~root") == "/root");
	assert(expandTilde("~root/") == "/root/");
	assert(expandTilde("~Idontexist/hey") == "~Idontexist/hey");
    }
}

version (linux)
{

/**
 * Replaces the tilde from path with the environment variable HOME.
 */
private char[] expandFromEnvironment(char[] path)
{
    assert(path.length >= 1);
    assert(path[0] == '~');
    
    // Get HOME and use that to replace the tilde.
    char* home = getenv("HOME");
    if (home == null)
        return path;

    return combineCPathWithDPath(home, path, 1);
}


/**
 * Joins a path from a C string to the remainder of path.
 *
 * The last path separator from c_path is discarded. The result
 * is joined to path[char_pos .. length] if char_pos is smaller
 * than length, otherwise path is not appended to c_path.
 */
private char[] combineCPathWithDPath(char* c_path, char[] path, int char_pos)
{
    assert(c_path != null);
    assert(path.length > 0);
    assert(char_pos >= 0);

    // Search end of C string
    size_t end = std.string.strlen(c_path);

    // Remove trailing path separator, if any
    if (end && c_path[end - 1] == sep[0])
	end--;

    // Create our own copy, as lifetime of c_path is undocumented
    char[] cp = c_path[0 .. end].dup;

    // Do we append something from path?
    if (char_pos < path.length)
	cp ~= path[char_pos .. length];

    return cp;
}


/**
 * Replaces the tilde from path with the path from the user database.
 */
private char[] expandFromDatabase(char[] path)
{
    assert(path.length > 2 || (path.length == 2 && path[1] != sep[0]));
    assert(path[0] == '~');

    // Extract username, searching for path separator.
    char[] username;
    int last_char = find(path, sep[0]);

    if (last_char == -1)
    {
        username = path[1 .. length] ~ '\0';
	last_char = username.length + 1;
    }
    else
    {
        username = path[1 .. last_char] ~ '\0';
    }
    assert(last_char > 1);
    
    // Reserve C memory for the getpwnam_r() function.
    passwd result;
    int extra_memory_size = 5 * 1024;
    void* extra_memory;

    while (1)
    {
	extra_memory = std.c.stdlib.malloc(extra_memory_size);
	if (extra_memory == null)
	    goto Lerror;

	// Obtain info from database.
	passwd *verify;
	std.c.stdlib.setErrno(0);
	if (getpwnam_r(username, &result, extra_memory, extra_memory_size,
		&verify) == 0)
	{
	    // Failure if verify doesn't point at result.
	    if (verify != &result)
		// username is not found, so return path[]
		goto Lnotfound;
	    break;
	}

	if (std.c.stdlib.getErrno() != ERANGE)
	    goto Lerror;

	// extra_memory isn't large enough
	std.c.stdlib.free(extra_memory);
	extra_memory_size *= 2;
    }

    path = combineCPathWithDPath(result.pw_dir, path, last_char);

Lnotfound:
    std.c.stdlib.free(extra_memory);
    return path;

Lerror:
    // Errors are going to be caused by running out of memory
    if (extra_memory)
	std.c.stdlib.free(extra_memory);
    _d_OutOfMemory();
    return null;
}

}
