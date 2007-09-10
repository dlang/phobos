// string.d
// Written by Walter Bright
// Copyright (c) 2001 Digital Mars
// All Rights Reserved
// www.digitalmars.com

// String handling functions.
//
// To copy or not to copy?
//
// When a function takes a string as a parameter, and returns a string,
// is that string the same as the input string, modified in place, or
// is it a modified copy of the input string? The D array convention is
// "copy-on-write". This means that if no modifications are done, the
// original string (or slices of it) can be returned. If any modifications
// are done, the returned string is a copy.
//
// The code is not optimized for speed, that will have to wait
// until the design is solidified.

//debug=string;		// uncomment to turn on debugging printf's

debug(string)
{
    import stdio;	// for printf()
}

extern (C)
{
    // Functions from the C library.
    int strlen(char *);
    int strcmp(char *, char *);
    int memcmp(char *, char *, uint);
    char *strcpy(char *, char *);
    int atoi(char *);
    long atoll(char *);
    double atof(char *);
    char *strstr(char *, char *);
    char *strchr(char *, char);
    char *strrchr(char *, char);
    char *memchr(char *, char, uint);
    void *memcpy(void *, void *, uint);
}

/************** Exceptions ****************/

class StringException : Exception
{
    this(char[] msg)
    {
	this.msg = msg;
    }
}

/************** Constants ****************/

const char[16] hexdigits = "0123456789ABCDEF";
const char[10] digits    = "0123456789";
const char[8]  octdigits = "01234567";
const char[26] lowercase = "abcdefghijklmnopqrstuvwxyz";
const char[26] uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const char[52] letters   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			   "abcdefghijklmnopqrstuvwxyz";
const char[6] whitespace = " \t\v\r\n\f";

/**********************************
 * Returns !=0 if c is whitespace
 */

private int iswhite(char c)
{
    return find(whitespace, c) != -1;
}

/*********************************
 * Convert string to integer / extended.
 */

long atoi(char[] s)
{
    return atoll(toCharz(s));
}

extended atof(char[] s)
{
    // BUG: should implement atold()
    return atof(toCharz(s));
}

/**********************************
 * Compare two strings.
 * Returns:
 *	<0	s1 < s2
 *	=0	s1 == s2
 *	>0	s1 > s2
 */

int cmp(char[] s1, char[] s2)
{
    uint len = s1.length;
    int result;

    if (s2.length < len)
	len = s2.length;
    result = memcmp(s1, s2, len);
    if (result == 0)
	result = cast(int)s1.length - cast(int)s2.length;
    return result;
}

unittest
{
    int result;

    debug(string) printf("string.cmp.unittest\n");
    result = cmp("abc", "abc");
    assert(result == 0);
    result = cmp(null, null);
    assert(result == 0);
    result = cmp("", "");
    assert(result == 0);
    result = cmp("abc", "abcd");
    assert(result < 0);
    result = cmp("abcd", "abc");
    assert(result > 0);
    result = cmp("abc", "abd");
    assert(result < 0);
    result = cmp("bbc", "abc");
    assert(result > 0);
}

/*********************************
 * Converts a D array of chars to a C-style 0 terminated string.
 */

char* toCharz(char[] string)
    in
    {
	if (string)
	{
	    // No embedded 0's
	    for (uint i = 0; i < string.length; i++)
		assert(string[i] != 0);
	}
    }
    out (result)
    {
	if (result)
	{   assert(strlen(result) == string.length);
	    assert(memcmp(result, string, string.length) == 0);
	}
    }
    body
    {
	char* p;
	char[] copy;

	if (string == null)
	    return null;

	p = &string[string.length];

	// Peek past end of string[], if it's 0, no conversion necessary.
	// Note that the compiler will put a 0 past the end of static
	// strings, and the storage allocator will put a 0 past the end
	// of newly allocated char[]'s.
	if (*p == 0)
	    return string;

	// Need to make a copy
	copy = new char[string.length + 1];
	copy[0..string.length] = string;
	return copy;
    }

unittest
{
    debug(string) printf("string.toCharz.unittest\n");

    char* p = toCharz("foo");
    assert(strlen(p) == 3);
    char foo[] = "abbzxyzzy";
    p = toCharz(foo[3..5]);
    assert(strlen(p) == 2);
}

/******************************************
 * Find first occurrance of c in string s.
 * Return index in s where it is found.
 * Return -1 if not found.
 */

int find(char[] s, char c)
{
    char* p;

    p = memchr(s, c, s.length);
    if (p)
	return p - cast(char *)s;
    else
	return -1;
}

unittest
{
    debug(string) printf("string.find.unittest\n");

    int i;

    i = find(null, cast(char)'a');
    assert(i == -1);
    i = find("def", cast(char)'a');
    assert(i == -1);
    i = find("abba", cast(char)'a');
    assert(i == 0);
    i = find("def", cast(char)'f');
    assert(i == 2);
}


/******************************************
 * Find last occurrance of c in string s.
 * Return index in s where it is found.
 * Return -1 if not found.
 */

int rfind(char[] s, char c)
{
    int i;

    for (i = s.length; i-- > 0;)
    {
	if (s[i] == c)
	    break;
    }
    return i;
}

unittest
{
    debug(string) printf("string.rfind.unittest\n");

    int i;

    i = rfind(null, cast(char)'a');
    assert(i == -1);
    i = rfind("def", cast(char)'a');
    assert(i == -1);
    i = rfind("abba", cast(char)'a');
    assert(i == 3);
    i = rfind("def", cast(char)'f');
    assert(i == 2);
}

/*************************************
 * Find first occurrance of sub[] in string s[].
 * Return index in s[] where it is found.
 * Return -1 if not found.
 */

int find(char[] s, char[] sub)
    out (result)
    {
	if (result == -1)
	{
	}
	else
	{
	    assert(0 <= result && result < s.length - sub.length + 1);
	    assert(memcmp(&s[result], sub, sub.length) == 0);
	}
    }
    body
    {
	int imax;
	char c;

	if (sub.length == 0)
	    return 0;
	imax = s.length - sub.length + 1;
	c = sub[0];
	for (int i = 0; i < imax; i++)
	{
	    if (s[i] == c)
	    {
		if (memcmp(&s[i + 1], &sub[1], sub.length - 1) == 0)
		    return i;
	    }
	}
	return -1;
    }


/*************************************
 * Find last occurrance of sub in string s.
 * Return index in s where it is found.
 * Return -1 if not found.
 */

int rfind(char[] s, char[] sub)
    out (result)
    {
	if (result == -1)
	{
	}
	else
	{
	    assert(0 <= result && result < s.length - sub.length + 1);
	    assert(memcmp(&s[result], sub, sub.length) == 0);
	}
    }
    body
    {
	char c;

	if (sub.length == 0)
	    return s.length;
	c = sub[0];
	for (int i = s.length - sub.length; i >= 0; i--)
	{
	    if (s[i] == c)
	    {
		if (memcmp(&s[i + 1], &sub[1], sub.length - 1) == 0)
		    return i;
	    }
	}
	return -1;
    }


/************************************
 * Convert string to lower case.
 */

char[] tolower(char[] s)
{
    int changed;
    int i;

    changed = 0;
    for (i = 0; i < s.length; i++)
    {
	char c = s[i];
	if ('A' <= c && c <= 'Z')
	{
	    if (!changed)
	    {	char[] r = new char[s.length];
		r[] = s;
		s = r;
		changed = 1;
	    }
	    s[i] = c + (cast(char)'a' - 'A');
	}
    }
    return s;
}

unittest
{
    debug(string) printf("string.tolower.unittest\n");

    char[] s1 = "FoL";
    char[] s2;

    s2 = tolower(s1);
    assert(cmp(s2, "fol") == 0);
    assert(s2 != s1);
}

/************************************
 * Convert string to upper case.
 */

char[] toupper(char[] s)
{
    int changed;
    int i;

    changed = 0;
    for (i = 0; i < s.length; i++)
    {
	char c = s[i];
	if ('a' <= c && c <= 'z')
	{
	    if (!changed)
	    {	char[] r = new char[s.length];
		r[] = s;
		s = r;
		changed = 1;
	    }
	    s[i] = c - (cast(char)'a' - 'A');
	}
    }
    return s;
}

unittest
{
    debug(string) printf("string.toupper.unittest\n");

    char[] s1 = "FoL";
    char[] s2;

    s2 = toupper(s1);
    assert(cmp(s2, "FOL") == 0);
    assert(s2 != s1);
}


/********************************************
 * Capitalize first character of string.
 */

char[] capitalize(char[] s)
{
    if (s.length)
    {
	char c = s[0];
	if ('a' <= c && c <= 'z')
	{   char[] r = new char[s.length];
	    r[] = s;
	    s = r;
	    s[0] = c - (cast(char)'a' - 'A');
	}
    }
    return s;
}

unittest
{
    debug(string) printf("string.capitalize.unittest\n");

    char[] s1 = "foL";
    char[] s2;

    s2 = capitalize(s1);
    assert(cmp(s2, "FoL") == 0);
    assert(s2 != s1);
}


/********************************************
 * Capitalize all words in string.
 * Remove leading and trailing whitespace.
 * Replace all sequences of whitespace with a single space.
 */

char[] capwords(char[] s)
{
    char[] r;
    int inword;
    int i;
    int istart;

    istart = 0;
    inword = 0;
    for (i = 0; i < s.length; i++)
    {
	switch (s[i])
	{
	    case ' ':
	    case \t:
	    case \f:
	    case \r:
	    case \n:
	    case \v:
		if (inword)
		{
		    r ~= s[istart .. i];
		    inword = 0;
		}
		break;

	    default:
		if (!inword)
		{
		    if (r.length)
			r ~= ' ';
		    istart = i;
		    inword = 1;
		}
		break;
	}
    }
    if (inword)
    {
	r ~= s[istart .. i];
    }

    // Go back through r and capitalize the words
    inword = 0;
    for (i = 0; i < r.length; i++)
    {
	char c = r[i];

	if (c >= 'A' && c <= 'Z')
	{
	    inword = 1;
	}
	else if (c >= 'a' && c <= 'z')
	{
	    if (inword == 0)
	    {
		c -= (char)'a' - 'A';
		r[i] = c;
	    }
	    inword = 1;
	}
	else
	    inword = 0;
    }

    return r;
}


unittest
{
    debug(string) printf("string.capwords.unittest\n");

    char[] s1 = "\tfoo abc(aD)*  \t  (q P  ";
    char[] s2;

    s2 = capwords(s1);
    //printf("s2 = '%.*s'\n", s2);
    assert(cmp(s2, "Foo Abc(AD)* (Q P") == 0);
}


/********************************************
 * Concatenate all the strings together into one
 * string; use sep[] as the separator.
 */

char[] join(char[][] words, char[] sep)
{
    uint len;
    uint seplen;
    uint i;
    uint j;
    char[] result;

    if (words.length)
    {
	len = 0;
	for (i = 0; i < words.length; i++)
	    len += words[i].length;

	seplen = sep.length;
	len += (words.length - 1) * seplen;

	result = new char[len];

	i = 0;
	while (true)
	{
	    uint wlen = words[i].length;

	    result[j .. j + wlen] = words[i];
	    j += wlen;
	    i++;
	    if (i >= words.length)
		break;
	    result[j .. j + seplen] = sep;
	    j += seplen;
	}
	assert(j == len);
    }
    return result;
}

unittest
{
    debug(string) printf("string.join.unittest\n");

    char[] word1 = "peter";
    char[] word2 = "paul";
    char[] word3 = "jerry";
    char[3][] words;
    char[] r;
    int i;

    words[0] = word1;
    words[1] = word2;
    words[2] = word3;
    r = join(words, ",");
    i = cmp(r, "peter,paul,jerry");
    assert(i == 0);
}


/**************************************
 * Split s[] into an array of words,
 * using whitespace as the delimiter.
 */

char[][] split(char[] s)
{
    uint i;
    uint istart;
    int inword;
    char[][] words;

    inword = 0;
    for (i = 0; i < s.length; i++)
    {
	switch (s[i])
	{
	    case ' ':
	    case \t:
	    case \f:
	    case \r:
	    case \n:
	    case \v:
		if (inword)
		{
		    words ~= s[istart .. i];
		    inword = 0;
		}
		break;

	    default:
		if (!inword)
		{   istart = i;
		    inword = 1;
		}
		break;
	}
    }
    if (inword)
	words ~= s[istart .. i];
    return words;
}

unittest
{
    debug(string) printf("string.join.split1\n");

    char[] s = " peter paul\tjerry ";
    char[][] words;
    int i;

    words = split(s);
    assert(words.length == 3);
    i = cmp(words[0], "peter");
    assert(i == 0);
    i = cmp(words[1], "paul");
    assert(i == 0);
    i = cmp(words[2], "jerry");
    assert(i == 0);
}


/**************************************
 * Split s[] into an array of words,
 * using delim[] as the delimiter.
 */

char[][] split(char[] s, char[] delim)
    in
    {
	assert(delim.length > 0);
    }
    body
    {
	uint i;
	uint j;
	char[][] words;

	i = 0;
	if (s.length)
	{
	    while (true)
	    {
		j = find(s[i .. s.length], delim);
		if (j == -1)
		{
		    words ~= s[i .. s.length];
		    break;
		}
		words ~= s[i .. i + j];
		i += j + delim.length;
		if (i == s.length)
		{
		    words ~= "";
		    break;
		}
	    }
	}
	return words;
    }

unittest
{
    debug(string) printf("string.join.split2\n");

    char[] s = ",peter,paul,jerry,";
    char[][] words;
    int i;

    words = split(s, ",");
    assert(words.length == 5);
    i = cmp(words[0], "");
    assert(i == 0);
    i = cmp(words[1], "peter");
    assert(i == 0);
    i = cmp(words[2], "paul");
    assert(i == 0);
    i = cmp(words[3], "jerry");
    assert(i == 0);
    i = cmp(words[4], "");
    assert(i == 0);

    s = s[0 .. s.length - 1];	// lop off trailing ','
    words = split(s, ",");
    assert(words.length == 4);
    i = cmp(words[3], "jerry");
    assert(i == 0);

    s = s[1 .. s.length];	// lop off leading ','
    words = split(s, ",");
    assert(words.length == 3);
    i = cmp(words[0], "peter");
    assert(i == 0);
}


/**************************************
 * Split s[] into an array of lines,
 * using CR, LF, or CR-LF as the delimiter.
 */

char[][] splitlines(char[] s)
{
    uint i;
    uint istart;
    char[][] lines;

    for (i = 0; i < s.length; i++)
    {	char c;

	c = s[i];
	if (c == \r || c == \n)
	{
	    lines ~= s[istart .. i];
	    istart = i + 1;
	    if (c == \r && i + 1 < s.length && s[i + 1] == \n)
	    {
		i++;
		istart++;
	    }
	}
    }
    if (istart != i)
	lines ~= s[istart .. i];
    return lines;
}

unittest
{
    debug(string) printf("string.join.splitlines\n");

    char[] s = "\rpeter\n\rpaul\r\njerry\n";
    char[][] lines;
    int i;

    lines = splitlines(s);
    //printf("lines.length = %d\n", lines.length);
    assert(lines.length == 5);
    //printf("lines[0] = %llx, '%.*s'\n", lines[0], lines[0]);
    assert(lines[0].length == 0);
    i = cmp(lines[1], "peter");
    assert(i == 0);
    assert(lines[2].length == 0);
    i = cmp(lines[3], "paul");
    assert(i == 0);
    i = cmp(lines[4], "jerry");
    assert(i == 0);

    s = s[0 .. s.length - 1];	// lop off trailing \n
    lines = splitlines(s);
    //printf("lines.length = %d\n", lines.length);
    assert(lines.length == 5);
    i = cmp(lines[4], "jerry");
    assert(i == 0);
}


/*****************************************
 * Strips leading or trailing whitespace, or both.
 */

char[] stripl(char[] s)
{
    uint i;

    for (i = 0; i < s.length; i++)
    {
	if (!iswhite(s[i]))
	    break;
    }
    return s[i .. s.length];
}

char[] stripr(char[] s)
{
    uint i;

    for (i = s.length; i > 0; i--)
    {
	if (!iswhite(s[i - 1]))
	    break;
    }
    return s[0 .. i];
}

char[] strip(char[] s)
{
    return stripr(stripl(s));
}

unittest
{
    char[] s;
    int i;

    s = strip("  foo\t ");
    i = cmp(s, "foo");
    assert(i == 0);
}


/*******************************************
 * Left justify, right justify, or center string
 * in field width chars wide.
 */

char[] ljustify(char[] s, int width)
{
    if (s.length >= width)
	return s;
    char[] r = new char[width];
    r[0..s.length] = s;
    r[s.length .. width] = (char)' ';
    return r;
}

char[] rjustify(char[] s, int width)
{
    if (s.length >= width)
	return s;
    char[] r = new char[width];
    r[0 .. width - s.length] = (char)' ';
    r[width - s.length .. width] = s;
    return r;
}

char[] center(char[] s, int width)
{
    if (s.length >= width)
	return s;
    char[] r = new char[width];
    int left = (width - s.length) / 2;
    r[0 .. left] = (char)' ';
    r[left .. left + s.length] = s;
    r[left + s.length .. width] = (char)' ';
    return r;
}

unittest
{
    debug(string) printf("string.justify.unittest\n");

    char[] s = "hello";
    char[] r;
    int i;

    r = ljustify(s, 8);
    i = cmp(r, "hello   ");
    assert(i == 0);

    r = rjustify(s, 8);
    i = cmp(r, "   hello");
    assert(i == 0);

    r = center(s, 8);
    i = cmp(r, " hello  ");
    assert(i == 0);

    r = zfill(s, 8);
    i = cmp(r, "000hello");
    assert(i == 0);
}


/*****************************************
 * Same as rjustify(), but fill with '0's
 */

char[] zfill(char[] s, int width)
{
    if (s.length >= width)
	return s;
    char[] r = new char[width];
    r[0 .. width - s.length] = (char)'0';
    r[width - s.length .. width] = s;
    return r;
}

/********************************************
 * Replace occurrences of from[] with to[] in s[].
 */

char[] replace(char[] s, char[] from, char[] to)
{
    char[] p;
    int i;
    int istart;

    //printf("replace('%.*s','%.*s','%.*s')\n", s, from, to);
    istart = 0;
    while (istart < s.length)
    {
	i = find(s[istart .. s.length], from);
	if (i == -1)
	{
	    p ~= s[istart .. s.length];
	    break;
	}
	p ~= s[istart .. istart + i];
	p ~= to;
	istart += i + from.length;
    }
    return p;
}

unittest
{
    debug(string) printf("string.replace.unittest\n");

    char[] s = "This is a foo foo list";
    char[] from = "foo";
    char[] to = "silly";
    char[] r;
    int i;

    r = replace(s, from, to);
    i = cmp(r, "This is a silly silly list");
    assert(i == 0);
}


/***********************************************
 * Count up all instances of sub[] in s[].
 */

int count(char[] s, char[] sub)
{
    int i;
    int j;
    int count = 0;

    for (i = 0; i < s.length; i += j + sub.length)
    {
	j = find(s[i .. s.length], sub);
	if (j == -1)
	    break;
	count++;
    }
    return count;
}

unittest
{
    debug(string) printf("string.count.unittest\n");

    char[] s = "This is a fofofof list";
    char[] sub = "fof";
    int i;

    i = count(s, sub);
    assert(i == 2);
}


/************************************************
 * Replace tabs with the appropriate number of spaces.
 * tabsize is the distance between tab stops.
 */

char[] expandtabs(char[] s, int tabsize)
{
    char[] r;
    int i;
    int istart;
    int col;
    static char[8] spaces = "        ";

    col = 0;
    for (i = 0; i < s.length; i++)
    {
	char c;

	c = s[i];
	if (c == \t)
	{   int tabstop;

	    r ~= s[istart .. i];
	    istart = i + 1;

	    tabstop = col + tabsize;
	    tabstop -= tabstop % tabsize;
	    while (col < tabstop)
	    {
		int n = tabstop - col;
		if (n > spaces.length)
		    n = spaces.length;
		r ~= spaces[0 .. n];
		col += n;
	    }
	}
	else
	{
	    col++;
	}
    }
    r ~= s[istart .. i];
    return r;
}

unittest
{
    debug(string) printf("string.expandtabs.unittest\n");

    char[] s = "This \tis\t a fofof\tof list";
    char[] r;
    int i;

    r = expandtabs(s, 8);
    i = cmp(r, "This    is       a fofof        of list");
    assert(i == 0);
}


/************************************
 * Construct translation table for translate().
 */

char[] maketrans(char[] from, char[] to)
    in
    {
	assert(from.length == to.length);
    }
    body
    {
	char[] t = new char[256];
	int i;

	for (i = 0; i < 256; i++)
	    t[i] = cast(char)i;

	for (i = 0; i < from.length; i++)
	    t[from[i]] = to[i];

	return t;
    }

/******************************************
 * Translate characters in s[] using table created by maketrans().
 * Delete chars in delchars[].
 */

char[] translate(char[] s, char[] transtab, char[] delchars)
    in
    {
	assert(transtab.length == 256);
    }
    body
    {
	char[] r;
	int i;
	int count;
	bit[256] deltab;

	deltab[] = 0;
	for (i = 0; i < delchars.length; i++)
	    deltab[delchars[i]] = 1;

	count = 0;
	for (i = 0; i < s.length; i++)
	{
	    if (!deltab[s[i]])
		count++;
	}

	r = new char[count];
	count = 0;
	for (i = 0; i < s.length; i++)
	{   char c = s[i];

	    if (!deltab[c])
	    {
		r[count] = transtab[c];
		count++;
	    }
	}

	return r;
    }

unittest
{
    debug(string) printf("string.translate.unittest\n");

    char[] from = "abcdef";
    char[] to   = "ABCDEF";
    char[] s    = "The quick dog fox";
    char[] t;
    char[] r;
    int i;

    t = maketrans(from, to);
    r = translate(s, t, "kg");
    //printf("r = '%.*s'\n", r);
    i = cmp(r, "ThE quiC Do Fox");
    assert(i == 0);
}
