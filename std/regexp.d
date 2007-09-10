
// Regular Expressions
// Copyright (c) 2000-2003 by Digital Mars
// All Rights Reserved
// Written by Walter Bright
// www.digitalmars.com

/*
	Escape sequences:

	\nnn starts out a 1, 2 or 3 digit octal sequence,
	where n is an octal digit. If nnn is larger than
	0377, then the 3rd digit is not part of the sequence
	and is not consumed.
	For maximal portability, use exactly 3 digits.

	\xXX starts out a 1 or 2 digit hex sequence. X
	is a hex character. If the first character after the \x
	is not a hex character, the value of the sequence is 'x'
	and the XX are not consumed.
	For maximal portability, use exactly 2 digits.

	\uUUUU is a unicode sequence. There are exactly
	4 hex characters after the \u, if any are not, then
	the value of the sequence is 'u', and the UUUU are not
	consumed.

	Character classes:

	[a-b], where a is greater than b, will produce
	an error.
 */

module std.regexp;

//debug = regexp;		// uncomment to turn on debugging printf's

private
{
    import std.c.stdio;
    import std.c.stdlib;
    import std.string;
    import std.ctype;
    import std.outbuffer;
}

/************************************
 * One of these gets thrown on compilation error
 */

class RegExpError : Error
{
    this(char[] msg)
    {
	super(msg);
    }
}

struct regmatch_t
{
    int rm_so;			// index of start of match
    int rm_eo;			// index past end of match
}

alias char tchar;		// so we can make a wchar version

class RegExp
{
    public this(tchar[] pattern, tchar[] attributes)
    {
	pmatch = (&gmatch)[0 .. 1];
	compile(pattern, attributes);
    }

    uint re_nsub;		// number of parenthesized subexpression matches
    regmatch_t[] pmatch;	// array [re_nsub + 1]

    tchar[] input;		// the string to search

    // per instance:

    tchar[] pattern;		// source text of the regular expression

    tchar[] flags;		// source text of the attributes parameter

    int errors;

    uint attributes;

    enum REA
    {
	global		= 1,	// has the g attribute
	ignoreCase	= 2,	// has the i attribute
	multiline	= 4,	// if treat as multiple lines separated
				// by newlines, or as a single line
	dotmatchlf	= 8,	// if . matches \n
    }


private:
    uint src;			// current source index in input[]
    uint src_start;		// starting index for match in input[]
    uint p;			// position of parser in pattern[]
    regmatch_t gmatch;		// match for the entire regular expression
				// (serves as storage for pmatch[0])

    ubyte[] program;		// pattern[] compiled into regular expression program
    OutBuffer buf;




/******************************************/

// Opcodes

enum : ubyte
{
    REend,		// end of program
    REchar,		// single character
    REichar,		// single character, case insensitive
    REwchar,		// single wide character
    REiwchar,		// single wide character, case insensitive
    REanychar,		// any character
    REanystar,		// ".*"
    REstring,		// string of characters
    REistring,		// string of characters, case insensitive
    REtestbit,		// any in bitmap, non-consuming
    REbit,		// any in the bit map
    REnotbit,		// any not in the bit map
    RErange,		// any in the string
    REnotrange,		// any not in the string
    REor,		// a | b
    REplus,		// 1 or more
    REstar,		// 0 or more
    REquest,		// 0 or 1
    REnm,		// n..m
    REnmq,		// n..m, non-greedy version
    REbol,		// beginning of line
    REeol,		// end of line
    REparen,		// parenthesized subexpression
    REgoto,		// goto offset

    REwordboundary,
    REnotwordboundary,
    REdigit,
    REnotdigit,
    REspace,
    REnotspace,
    REword,
    REnotword,
    REbackref,
};

// BUG: should this include '$'?
private int isword(tchar c) { return isalnum(c) || c == '_'; }

private uint inf = ~0u;

/*********************************
 * Throws RegExpError on error
 */

void compile(tchar[] pattern, tchar[] attributes)
{
    //printf("RegExp.compile('%.*s', '%.*s')\n", pattern, attributes);

    this.attributes = 0;
    for (uint i = 0; i < attributes.length; i++)
    {   REA att;

	switch (attributes[i])
	{
	    case 'g': att = REA.global;		break;
	    case 'i': att = REA.ignoreCase;	break;
	    case 'm': att = REA.multiline;	break;
	    default:
		error("unrecognized attribute");
		return;
	}
	if (this.attributes & att)
	{   error("redundant attribute");
	    return;
	}
	this.attributes |= att;
    }

    input = null;

    this.pattern = pattern;
    this.flags = attributes;

    uint oldre_nsub = re_nsub;
    re_nsub = 0;
    errors = 0;

    buf = new OutBuffer();
    buf.reserve(pattern.length * 8);
    p = 0;
    parseRegexp();
    if (p < pattern.length)
    {	error("unmatched ')'");
    }
    optimize();
    program = buf.data;
    buf.data = null;
    delete buf;

    if (re_nsub > oldre_nsub)
    {
	if (pmatch === &gmatch)
	    pmatch = null;
	pmatch.length = re_nsub + 1;
    }
    pmatch[0].rm_so = 0;
    pmatch[0].rm_eo = 0;
}

/********************************************
 * Split string[] into an array of strings, using the regular expression as the separator.
 * Returns:
 * 	array of slices into string[]
 */

public tchar[][] split(tchar[] string)
{
    debug(regexp) printf("regexp.split()\n");

    tchar[][] result;

    if (string.length)
    {
	int p = 0;
	int q;
	for (q = p; q != string.length;)
	{
	    if (test(string, q))
	    {	int e;

		q = pmatch[0].rm_so;
		e = pmatch[0].rm_eo;
		if (e != p)
		{
		    result ~= string[p .. q];
		    for (int i = 1; i < pmatch.length; i++)
		    {
			int so = pmatch[i].rm_so;
			int eo = pmatch[i].rm_eo;
			if (so == eo)
			{   so = 0;	// -1 gives array bounds error
			    eo = 0;
			}
			result ~= string[so .. eo];
		    }
		    q = p = e;
		    continue;
		}
	    }
	    q++;
	}
	result ~= string[p .. string.length];
    }
    else if (!test(string))
	result ~= string;
    return result;
}

unittest
{
    debug(regexp) printf("regexp.split.unittest()\n");

    RegExp r = new RegExp("a*?", null);
    tchar[][] result;
    tchar[] j;
    int i;

    result = r.split("ab");

    assert(result.length == 2);
    i = std.string.cmp(result[0], "a");
    assert(i == 0);
    i = std.string.cmp(result[1], "b");
    assert(i == 0);

    r = new RegExp("a*", null);
    result = r.split("ab");
    assert(result.length == 2);
    i = std.string.cmp(result[0], "");
    assert(i == 0);
    i = std.string.cmp(result[1], "b");
    assert(i == 0);

    r = new RegExp("<(\\/)?([^<>]+)>", null);
    result = r.split("a<b>font</b>bar<TAG>hello</TAG>");

    for (i = 0; i < result.length; i++)
    {
	//debug(regexp) printf("result[%d] = '%.*s'\n", i, result[i]);
    }

    j = join(result, ",");
    //printf("j = '%.*s'\n", j);
    i = std.string.cmp(j, "a,,b,font,/,b,bar,,TAG,hello,/,TAG,");
    assert(i == 0);

    r = new RegExp("a[bc]", null);
    result = r.match("123ab");
    j = join(result, ",");
    i = std.string.cmp(j, "ab");
    assert(i == 0);
    
    result = r.match("ac");
    j = join(result, ",");
    i = std.string.cmp(j, "ac");
    assert(i == 0);
}

/*************************************************
 * Search string[] for match.
 * Returns:
 *	>=0	index of match
 *	-1	no match
 */

public int search(tchar[] string)
{
    int i;

    i = test(string);
    if (i)
	i = pmatch[0].rm_so;
    else
	i = -1;			// no match
    return i;
}

unittest
{
    debug(regexp) printf("regexp.search.unittest()\n");

    int i;
    RegExp r = new RegExp("abc", null);
    i = r.search("xabcy");
    assert(i == 1);
    i = r.search("cba");
    assert(i == -1);
}


/*************************************************
 * Search string[] for match.
 * Returns:
 *	if global, return same value as exec(string)
 *	if not global, return array of all matches
 */

public tchar[][] match(tchar[] string)
{
    tchar[][] result;

    if (attributes & REA.global)
    {
	int lastindex = 0;

	while (test(string, lastindex))
	{   int eo = pmatch[0].rm_eo;

	    result ~= input[pmatch[0].rm_so .. eo];
	    if (lastindex == eo)
		lastindex++;		// always consume some source
	    else
		lastindex = eo;
	}
    }
    else
    {
	result = exec(string);
    }
    return result;
}

unittest
{
    debug(regexp) printf("regexp.match.unittest()\n");

    int i;
    tchar[][] result;
    tchar[] j;
    RegExp r;

    r = new RegExp("a[bc]", null);
    result = r.match("1ab2ac3");
    j = join(result, ",");
    i = std.string.cmp(j, "ab");
    assert(i == 0);

    r = new RegExp("a[bc]", "g");
    result = r.match("1ab2ac3");
    j = join(result, ",");
    i = std.string.cmp(j, "ab,ac");
    assert(i == 0);
}


/*************************************************
 * Find regular expression matches in string[]. Replace those matches
 * with a new string composed of format[] merged with the result of the
 * matches.
 * If global, replace all matches. Otherwise, replace first match.
 * Return the new string.
 */

public tchar[] replace(tchar[] string, tchar[] format)
{
    tchar[] result;
    int lastindex;
    int offset;

    result = string;
    lastindex = 0;
    offset = 0;
    for (;;)
    {
	if (!test(string, lastindex))
	    break;

	int so = pmatch[0].rm_so;
	int eo = pmatch[0].rm_eo;

	tchar[] replacement = replace(format);
	result = replaceSlice(result, result[offset + so .. offset + eo], replacement);

	if (attributes & REA.global)
	{
	    offset += replacement.length - (eo - so);

	    if (lastindex == eo)
		lastindex++;		// always consume some source
	    else
		lastindex = eo;
	}
	else
	    break;
    }

    return result;
}

unittest
{
    debug(regexp) printf("regexp.replace.unittest()\n");

    int i;
    tchar[] result;
    RegExp r;

    r = new RegExp("a[bc]", "g");
    result = r.replace("1ab2ac3", "x$&y");
    i = std.string.cmp(result, "1xaby2xacy3");
    assert(i == 0);
}


/*************************************************
 * Search string[] for match.
 * Returns:
 *	array of slices into string[] representing matches
 */

public tchar[][] exec(tchar[] string)
{
    debug(regexp) printf("regexp.exec(string = '%.*s')\n", string);
    input = string;
    pmatch[0].rm_so = 0;
    pmatch[0].rm_eo = 0;
    return exec();
}

/*************************************************
 * Search string[] for next match.
 * Returns:
 *	array of slices into string[] representing matches
 */

public tchar[][] exec()
{
    if (!test())
	return null;

    tchar[][] result;

    result = new tchar[][pmatch.length];
    for (int i = 0; i < pmatch.length; i++)
    {
	if (pmatch[i].rm_so == pmatch[i].rm_eo)
	    result[i] = null;
	else
	    result[i] = input[pmatch[i].rm_so .. pmatch[i].rm_eo];
    }

    return result;
}

/************************************************
 * Search string[] for match.
 * Returns:
 *	0	no match
 *	!=0	match
 */

public int test(tchar[] string)
{
    return test(string, pmatch[0].rm_eo);
}

/************************************************
 * Pick up where last test() left off, and search again.
 * Returns:
 *	0	no match
 *	!=0	match
 */

public int test()
{
    return test(input, pmatch[0].rm_eo);
}

/************************************************
 * Test input[] starting at startindex against compiled in pattern[].
 * Returns:
 *	0	no match
 *	!=0	match
 */

int test(char[] string, int startindex)
{
    tchar firstc;
    uint si;

    input = string;
    debug (regexp) printf("RegExp.test(input[] = '%.*s', startindex = %d)\n", input, startindex);
    pmatch[0].rm_so = 0;
    pmatch[0].rm_eo = 0;
    if (startindex < 0 || startindex > input.length)
    {
	return 0;			// fail
    }
    debug(regexp) printProgram(program);

    // First character optimization
    firstc = 0;
    if (program[0] == REchar)
    {
	firstc = program[1];
	if (attributes & REA.ignoreCase && isalpha(firstc))
	    firstc = 0;
    }

    for (si = startindex; ; si++)
    {
	if (firstc)
	{
	    if (si == input.length)
		break;			// no match
	    if (input[si] != firstc)
	    {
		si++;
		if (!chr(si, firstc))	// if first character not found
		    break;		// no match
	    }
	}
	for (int i = 0; i < re_nsub + 1; i++)
	{
	    pmatch[i].rm_so = -1;
	    pmatch[i].rm_eo = -1;
	}
	src_start = src = si;
	if (trymatch(0, program.length))
	{
	    pmatch[0].rm_so = si;
	    pmatch[0].rm_eo = src;
	    debug(regexp) printf("start = %d, end = %d\n", gmatch.rm_so, gmatch.rm_eo);
	    return 1;
	}
	// If possible match must start at beginning, we are done
	if (program[0] == REbol || program[0] == REanystar)
	{
	    if (attributes & REA.multiline)
	    {
		// Scan for the next \n
		if (!chr(si, '\n'))
		    break;		// no match if '\n' not found
	    }
	    else
		break;
	}
	if (si == input.length)
	    break;
	debug(regexp) printf("Starting new try: '%.*s'\n", input[si + 1 .. input.length]);
    }
    return 0;		// no match
}

int chr(inout uint si, tchar c)
{
    for (; si < input.length; si++)
    {
	if (input[si] == c)
	    return 1;
    }
    return 0;
}


void printProgram(ubyte[] prog)
{
  debug(regexp)
  {
    uint pc;
    uint len;
    uint n;
    uint m;
    ushort *pu;
    uint *puint;

    printf("printProgram()\n");
    for (pc = 0; pc < prog.length; )
    {
	printf("%3d: ", pc);

	//printf("prog[pc] = %d, REchar = %d, REnmq = %d\n", prog[pc], REchar, REnmq);
	switch (prog[pc])
	{
	    case REchar:
		printf("\tREchar '%c'\n", prog[pc + 1]);
		pc += 1 + char.size;
		break;

	    case REichar:
		printf("\tREichar '%c'\n", prog[pc + 1]);
		pc += 1 + char.size;
		break;

	    case REwchar:
		printf("\tREwchar '%c'\n", *(wchar *)&prog[pc + 1]);
		pc += 1 + wchar.size;
		break;

	    case REiwchar:
		printf("\tREiwchar '%c'\n", *(wchar *)&prog[pc + 1]);
		pc += 1 + wchar.size;
		break;

	    case REanychar:
		printf("\tREanychar\n");
		pc++;
		break;

	    case REstring:
		len = *(uint *)&prog[pc + 1];
		printf("\tREstring x%x, '%.*s'\n", len,
			(&prog[pc + 1 + uint.size])[0 .. len]);
		pc += 1 + uint.size + len * tchar.size;
		break;

	    case REistring:
		len = *(uint *)&prog[pc + 1];
		printf("\tREistring x%x, '%.*s'\n", len,
			(&prog[pc + 1 + uint.size])[0 .. len]);
		pc += 1 + uint.size + len * tchar.size;
		break;

	    case REtestbit:
		pu = (ushort *)&prog[pc + 1];
		printf("\tREtestbit %d, %d\n", pu[0], pu[1]);
		len = pu[1];
		pc += 1 + 2 * ushort.size + len;
		break;

	    case REbit:
		pu = (ushort *)&prog[pc + 1];
		len = pu[1];
		printf("\tREbit cmax=%02x, len=%d:", pu[0], len);
		for (n = 0; n < len; n++)
		    printf(" %02x", prog[pc + 1 + 2 * ushort.size + n]);
		printf("\n");
		pc += 1 + 2 * ushort.size + len;
		break;

	    case REnotbit:
		pu = (ushort *)&prog[pc + 1];
		printf("\tREnotbit %d, %d\n", pu[0], pu[1]);
		len = pu[1];
		pc += 1 + 2 * ushort.size + len;
		break;

	    case RErange:
		len = *(uint *)&prog[pc + 1];
		printf("\tRErange %d\n", len);
		// BUG: REAignoreCase?
		pc += 1 + uint.size + len;
		break;

	    case REnotrange:
		len = *(uint *)&prog[pc + 1];
		printf("\tREnotrange %d\n", len);
		// BUG: REAignoreCase?
		pc += 1 + uint.size + len;
		break;

	    case REbol:
		printf("\tREbol\n");
		pc++;
		break;

	    case REeol:
		printf("\tREeol\n");
		pc++;
		break;

	    case REor:
		len = *(uint *)&prog[pc + 1];
		printf("\tREor %d, pc=>%d\n", len, pc + 1 + uint.size + len);
		pc += 1 + uint.size;
		break;

	    case REgoto:
		len = *(uint *)&prog[pc + 1];
		printf("\tREgoto %d, pc=>%d\n", len, pc + 1 + uint.size + len);
		pc += 1 + uint.size;
		break;

	    case REanystar:
		printf("\tREanystar\n");
		pc++;
		break;

	    case REnm:
	    case REnmq:
		// len, n, m, ()
		puint = (uint *)&prog[pc + 1];
		len = puint[0];
		n = puint[1];
		m = puint[2];
		printf("\tREnm%.*s len=%d, n=%u, m=%u, pc=>%d\n",
		    (prog[pc] == REnmq) ? "q" : " ",
		    len, n, m, pc + 1 + uint.size * 3 + len);
		pc += 1 + uint.size * 3;
		break;

	    case REparen:
		// len, n, ()
		puint = (uint *)&prog[pc + 1];
		len = puint[0];
		n = puint[1];
		printf("\tREparen len=%d n=%d, pc=>%d\n", len, n, pc + 1 + uint.size * 2 + len);
		pc += 1 + uint.size * 2;
		break;

	    case REend:
		printf("\tREend\n");
		return;

	    case REwordboundary:
		printf("\tREwordboundary\n");
		pc++;
		break;

	    case REnotwordboundary:
		printf("\tREnotwordboundary\n");
		pc++;
		break;

	    case REdigit:
		printf("\tREdigit\n");
		pc++;
		break;

	    case REnotdigit:
		printf("\tREnotdigit\n");
		pc++;
		break;

	    case REspace:
		printf("\tREspace\n");
		pc++;
		break;

	    case REnotspace:
		printf("\tREnotspace\n");
		pc++;
		break;

	    case REword:
		printf("\tREword\n");
		pc++;
		break;

	    case REnotword:
		printf("\tREnotword\n");
		pc++;
		break;

	    case REbackref:
		printf("\tREbackref %d\n", prog[1]);
		pc += 2;
		break;

	    default:
		assert(0);
	}
    }
  }
}


/**************************************************
 * Match input against a section of the program[].
 * Returns:
 *	1 if successful match
 *	0 no match
 */

int trymatch(int pc, int pcend)
{   int srcsave;
    uint len;
    uint n;
    uint m;
    uint count;
    uint pop;
    uint ss;
    regmatch_t *psave;
    uint c1;
    uint c2;
    ushort* pu;
    uint* puint;

    debug(regexp)
	printf("RegExp.trymatch(pc = %d, src = '%.*s', pcend = %d)\n",
	    pc, input[src .. input.length], pcend);
    srcsave = src;
    psave = null;
    for (;;)
    {
	if (pc == pcend)		// if done matching
	{   debug(regex) printf("\tprogend\n");
	    return 1;
	}

	//printf("\top = %d\n", program[pc]);
	switch (program[pc])
	{
	    case REchar:
		if (src == input.length)
		    goto Lnomatch;
		debug(regexp) printf("\tREchar '%c', src = '%c'\n", program[pc + 1], input[src]);
		if (program[pc + 1] != input[src])
		    goto Lnomatch;
		src++;
		pc += 1 + char.size;
		break;

	    case REichar:
		if (src == input.length)
		    goto Lnomatch;
		debug(regexp) printf("\tREichar '%c', src = '%c'\n", program[pc + 1], input[src]);
		c1 = program[pc + 1];
		c2 = input[src];
		if (c1 != c2)
		{
		    if (islower((tchar)c2))
			c2 = std.ctype.toupper((tchar)c2);
		    else
			goto Lnomatch;
		    if (c1 != c2)
			goto Lnomatch;
		}
		src++;
		pc += 1 + char.size;
		break;

	    case REwchar:
		debug(regexp) printf("\tREwchar '%c', src = '%c'\n", *((wchar *)&program[pc + 1]), input[src]);
		if (src == input.length)
		    goto Lnomatch;
		if (*((wchar *)&program[pc + 1]) != input[src])
		    goto Lnomatch;
		src++;
		pc += 1 + wchar.size;
		break;

	    case REiwchar:
		debug(regexp) printf("\tREiwchar '%c', src = '%c'\n", *((wchar *)&program[pc + 1]), input[src]);
		if (src == input.length)
		    goto Lnomatch;
		c1 = *((wchar *)&program[pc + 1]);
		c2 = input[src];
		if (c1 != c2)
		{
		    if (islower(cast(tchar)c2))
			c2 = std.ctype.toupper(cast(tchar)c2);
		    else
			goto Lnomatch;
		    if (c1 != c2)
			goto Lnomatch;
		}
		src++;
		pc += 1 + wchar.size;
		break;

	    case REanychar:
		debug(regexp) printf("\tREanychar\n");
		if (src == input.length)
		    goto Lnomatch;
		if (!(attributes & REA.dotmatchlf) && input[src] == (tchar)'\n')
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REstring:
		len = *(uint *)&program[pc + 1];
		debug(regexp) printf("\tREstring x%x, '%.*s'\n", len,
			(&program[pc + 1 + uint.size])[0 .. len]);
		if (src + len > input.length)
		    goto Lnomatch;
		if (memcmp(&program[pc + 1 + uint.size], &input[src], len * tchar.size))
		    goto Lnomatch;
		src += len;
		pc += 1 + uint.size + len * tchar.size;
		break;

	    case REistring:
		len = *(uint *)&program[pc + 1];
		debug(regexp) printf("\tREistring x%x, '%.*s'\n", len,
			(&program[pc + 1 + uint.size])[0 .. len]);
		if (src + len > input.length)
		    goto Lnomatch;
		version (Win32)
		{
		    if (memicmp(cast(char*)&program[pc + 1 + uint.size], &input[src], len * tchar.size))
			goto Lnomatch;
		}
		else
		{
		    if (icmp((cast(char*)&program[pc + 1 + uint.size])[0..len],
			     input[src .. src + len]))
			goto Lnomatch;
		}
		src += len;
		pc += 1 + uint.size + len * tchar.size;
		break;

	    case REtestbit:
		pu = ((ushort *)&program[pc + 1]);
		debug(regexp) printf("\tREtestbit %d, %d, '%c', x%02x\n",
		    pu[0], pu[1], input[src], input[src]);
		if (src == input.length)
		    goto Lnomatch;
		len = pu[1];
		c1 = input[src];
		//printf("[x%02x]=x%02x, x%02x\n", c1 >> 3, ((&program[pc + 1 + 4])[c1 >> 3] ), (1 << (c1 & 7)));
		if (c1 <= pu[0] &&
		    !((&(program[pc + 1 + 4]))[c1 >> 3] & (1 << (c1 & 7))))
		    goto Lnomatch;
		pc += 1 + 2 * ushort.size + len;
		break;

	    case REbit:
		pu = ((ushort *)&program[pc + 1]);
		debug(regexp) printf("\tREbit %d, %d, '%c'\n",
		    pu[0], pu[1], input[src]);
		if (src == input.length)
		    goto Lnomatch;
		len = pu[1];
		c1 = input[src];
		if (c1 > pu[0])
		    goto Lnomatch;
		if (!((&program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
		    goto Lnomatch;
		src++;
		pc += 1 + 2 * ushort.size + len;
		break;

	    case REnotbit:
		pu = ((ushort *)&program[pc + 1]);
		debug(regexp) printf("\tREnotbit %d, %d, '%c'\n",
		    pu[0], pu[1], input[src]);
		if (src == input.length)
		    goto Lnomatch;
		len = pu[1];
		c1 = input[src];
		if (c1 <= pu[0] &&
		    ((&program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
		    goto Lnomatch;
		src++;
		pc += 1 + 2 * ushort.size + len;
		break;

	    case RErange:
		len = *(uint *)&program[pc + 1];
		debug(regexp) printf("\tRErange %d\n", len);
		if (src == input.length)
		    goto Lnomatch;
		// BUG: REA.ignoreCase?
		if (memchr((char*)&program[pc + 1 + uint.size], input[src], len) == null)
		    goto Lnomatch;
		src++;
		pc += 1 + uint.size + len;
		break;

	    case REnotrange:
		len = *(uint *)&program[pc + 1];
		debug(regexp) printf("\tREnotrange %d\n", len);
		if (src == input.length)
		    goto Lnomatch;
		// BUG: REA.ignoreCase?
		if (memchr((char*)&program[pc + 1 + uint.size], input[src], len) != null)
		    goto Lnomatch;
		src++;
		pc += 1 + uint.size + len;
		break;

	    case REbol:
		debug(regexp) printf("\tREbol\n");
		if (src == 0)
		{
		}
		else if (attributes & REA.multiline)
		{
		    if (input[src - 1] != '\n')
			goto Lnomatch;
		}
		else
		    goto Lnomatch;
		pc++;
		break;

	    case REeol:
		debug(regexp) printf("\tREeol\n");
		if (src == input.length)
		{
		}
		else if (attributes & REA.multiline && input[src] == '\n')
		    src++;
		else
		    goto Lnomatch;
		pc++;
		break;

	    case REor:
		len = ((uint *)&program[pc + 1])[0];
		debug(regexp) printf("\tREor %d\n", len);
		pop = pc + 1 + uint.size;
		ss = src;
		if (trymatch(pop, pcend))
		{
		    if (pcend != program.length)
		    {	int s;

			s = src;
			if (trymatch(pcend, program.length))
			{   debug(regexp) printf("\tfirst operand matched\n");
			    src = s;
			    return 1;
			}
			else
			{
			    // If second branch doesn't match to end, take first anyway
			    src = ss;
			    if (!trymatch(pop + len, program.length))
			    {
				debug(regexp) printf("\tfirst operand matched\n");
				src = s;
				return 1;
			    }
			}
			src = ss;
		    }
		    else
		    {	debug(regexp) printf("\tfirst operand matched\n");
			return 1;
		    }
		}
		pc = pop + len;		// proceed with 2nd branch
		break;

	    case REgoto:
		debug(regexp) printf("\tREgoto\n");
		len = ((uint *)&program[pc + 1])[0];
		pc += 1 + uint.size + len;
		break;

	    case REanystar:
		debug(regexp) printf("\tREanystar\n");
		pc++;
		for (;;)
		{   int s1;
		    int s2;

		    s1 = src;
		    if (src == input.length)
			break;
		    if (!(attributes & REA.dotmatchlf) && input[src] == '\n')
			break;
		    src++;
		    s2 = src;

		    // If no match after consumption, but it
		    // did match before, then no match
		    if (!trymatch(pc, program.length))
		    {
			src = s1;
			// BUG: should we save/restore pmatch[]?
			if (trymatch(pc, program.length))
			{
			    src = s1;		// no match
			    break;
			}
		    }
		    src = s2;
		}
		break;

	    case REnm:
	    case REnmq:
		// len, n, m, ()
		puint = (uint *)&program[pc + 1];
		len = puint[0];
		n = puint[1];
		m = puint[2];
		debug(regexp) printf("\tREnm%s len=%d, n=%u, m=%u\n", (program[pc] == REnmq) ? (char*)"q" : (char*)"", len, n, m);
		pop = pc + 1 + uint.size * 3;
		for (count = 0; count < n; count++)
		{
		    if (!trymatch(pop, pop + len))
			goto Lnomatch;
		}
		if (!psave && count < m)
		{
		    //version (Win32)
			psave = (regmatch_t *)alloca((re_nsub + 1) * regmatch_t.size);
		    //else
			//psave = new regmatch_t[re_nsub + 1];
		}
		if (program[pc] == REnmq)	// if minimal munch
		{
		    for (; count < m; count++)
		    {   int s1;

			memcpy(psave, pmatch, (re_nsub + 1) * regmatch_t.size);
			s1 = src;

			if (trymatch(pop + len, program.length))
			{
			    src = s1;
			    memcpy(pmatch, psave, (re_nsub + 1) * regmatch_t.size);
			    break;
			}

			if (!trymatch(pop, pop + len))
			{   debug(regexp) printf("\tdoesn't match subexpression\n");
			    break;
			}

			// If source is not consumed, don't
			// infinite loop on the match
			if (s1 == src)
			{   debug(regexp) printf("\tsource is not consumed\n");
			    break;
			}
		    }
		}
		else	// maximal munch
		{
		    for (; count < m; count++)
		    {   int s1;
			int s2;

			memcpy(psave, pmatch, (re_nsub + 1) * regmatch_t.size);
			s1 = src;
			if (!trymatch(pop, pop + len))
			{   debug(regexp) printf("\tdoesn't match subexpression\n");
			    break;
			}
			s2 = src;

			// If source is not consumed, don't
			// infinite loop on the match
			if (s1 == s2)
			{   debug(regexp) printf("\tsource is not consumed\n");
			    break;
			}

			// If no match after consumption, but it
			// did match before, then no match
			if (!trymatch(pop + len, program.length))
			{
			    src = s1;
			    if (trymatch(pop + len, program.length))
			    {
				src = s1;		// no match
				memcpy(pmatch, psave, (re_nsub + 1) * regmatch_t.size);
				break;
			    }
			}
			src = s2;
		    }
		}
		debug(regexp) printf("\tREnm len=%d, n=%u, m=%u, DONE count=%d\n", len, n, m, count);
		pc = pop + len;
		break;

	    case REparen:
		// len, ()
		debug(regexp) printf("\tREparen\n");
		puint = (uint *)&program[pc + 1];
		len = puint[0];
		n = puint[1];
		pop = pc + 1 + uint.size * 2;
		ss = src;
		if (!trymatch(pop, pop + len))
		    goto Lnomatch;
		pmatch[n + 1].rm_so = ss;
		pmatch[n + 1].rm_eo = src;
		pc = pop + len;
		break;

	    case REend:
		debug(regexp) printf("\tREend\n");
		return 1;		// successful match

	    case REwordboundary:
		debug(regexp) printf("\tREwordboundary\n");
		if (src > 0 && src < input.length)
		{
		    c1 = input[src - 1];
		    c2 = input[src];
		    if (!(
			  (isword((tchar)c1) && !isword((tchar)c2)) ||
			  (!isword((tchar)c1) && isword((tchar)c2))
			 )
		       )
			goto Lnomatch;
		}
		pc++;
		break;

	    case REnotwordboundary:
		debug(regexp) printf("\tREnotwordboundary\n");
		if (src == 0 || src == input.length)
		    goto Lnomatch;
		c1 = input[src - 1];
		c2 = input[src];
		if (
		    (isword((tchar)c1) && !isword((tchar)c2)) ||
		    (!isword((tchar)c1) && isword((tchar)c2))
		   )
		    goto Lnomatch;
		pc++;
		break;

	    case REdigit:
		debug(regexp) printf("\tREdigit\n");
		if (src == input.length)
		    goto Lnomatch;
		if (!isdigit(input[src]))
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REnotdigit:
		debug(regexp) printf("\tREnotdigit\n");
		if (src == input.length)
		    goto Lnomatch;
		if (isdigit(input[src]))
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REspace:
		debug(regexp) printf("\tREspace\n");
		if (src == input.length)
		    goto Lnomatch;
		if (!isspace(input[src]))
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REnotspace:
		debug(regexp) printf("\tREnotspace\n");
		if (src == input.length)
		    goto Lnomatch;
		if (isspace(input[src]))
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REword:
		debug(regexp) printf("\tREword\n");
		if (src == input.length)
		    goto Lnomatch;
		if (!isword(input[src]))
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REnotword:
		debug(regexp) printf("\tREnotword\n");
		if (src == input.length)
		    goto Lnomatch;
		if (isword(input[src]))
		    goto Lnomatch;
		src++;
		pc++;
		break;

	    case REbackref:
	    {
		n = program[pc + 1];
		debug(regexp) printf("\tREbackref %d\n", n);

		int so = pmatch[n + 1].rm_so;
		int eo = pmatch[n + 1].rm_eo;
		len = eo - so;
		if (src + len > input.length)
		    goto Lnomatch;
		else if (attributes & REA.ignoreCase)
		{
		    if (icmp(input[src .. src + len], input[so .. eo]))
			goto Lnomatch;
		}
		else if (memcmp(&input[src], &input[so], len * tchar.size))
		    goto Lnomatch;
		src += len;
		pc += 2;
		break;
	    }

	    default:
		assert(0);
	}
    }

Lnomatch:
    debug(regexp) printf("\tnomatch pc=%d\n", pc);
    src = srcsave;
    return 0;
}

/* =================== Compiler ================== */

int parseRegexp()
{   uint offset;
    uint gotooffset;
    uint len1;
    uint len2;

    //printf("parseRegexp() '%.*s'\n", pattern[p .. pattern.length]);
    offset = buf.offset;
    for (;;)
    {
	assert(p <= pattern.length);
	if (p == pattern.length)
	{   buf.write(REend);
	    return 1;
	}
	switch (pattern[p])
	{
	    case ')':
		return 1;

	    case '|':
		p++;
		gotooffset = buf.offset;
		buf.write(REgoto);
		buf.write((uint)0);
		len1 = buf.offset - offset;
		buf.spread(offset, 1 + uint.size);
		gotooffset += 1 + uint.size;
		parseRegexp();
		len2 = buf.offset - (gotooffset + 1 + uint.size);
		buf.data[offset] = REor;
		((uint *)&buf.data[offset + 1])[0] = len1;
		((uint *)&buf.data[gotooffset + 1])[0] = len2;
		break;

	    default:
		parsePiece();
		break;
	}
    }
}

int parsePiece()
{   uint offset;
    uint len;
    uint n;
    uint m;
    ubyte op;
    int plength = pattern.length;

    //printf("parsePiece() '%.*s'\n", pattern[p .. pattern.length]);
    offset = buf.offset;
    parseAtom();
    if (p == plength)
	return 1;
    switch (pattern[p])
    {
	case '*':
	    // Special optimization: replace .* with REanystar
	    if (buf.offset - offset == 1 &&
		buf.data[offset] == REanychar &&
		p + 1 < plength &&
		pattern[p + 1] != '?')
	    {
		buf.data[offset] = REanystar;
		p++;
		break;
	    }

	    n = 0;
	    m = inf;
	    goto Lnm;

	case '+':
	    n = 1;
	    m = inf;
	    goto Lnm;

	case '?':
	    n = 0;
	    m = 1;
	    goto Lnm;

	case '{':	// {n} {n,} {n,m}
	    p++;
	    if (p == plength || !isdigit(pattern[p]))
		goto Lerr;
	    n = 0;
	    do
	    {
		// BUG: handle overflow
		n = n * 10 + pattern[p] - '0';
		p++;
		if (p == plength)
		    goto Lerr;
	    } while (isdigit(pattern[p]));
	    if (pattern[p] == '}')		// {n}
	    {	m = n;
		goto Lnm;
	    }
	    if (pattern[p] != ',')
		goto Lerr;
	    p++;
	    if (p == plength)
		goto Lerr;
	    if (pattern[p] == '}')		// {n,}
	    {	m = inf;
		goto Lnm;
	    }
	    if (!isdigit(pattern[p]))
		goto Lerr;
	    m = 0;			// {n,m}
	    do
	    {
		// BUG: handle overflow
		m = m * 10 + pattern[p] - '0';
		p++;
		if (p == plength)
		    goto Lerr;
	    } while (isdigit(pattern[p]));
	    if (pattern[p] != '}')
		goto Lerr;
	    goto Lnm;

	Lnm:
	    p++;
	    op = REnm;
	    if (p < plength && pattern[p] == '?')
	    {	op = REnmq;	// minimal munch version
		p++;
	    }
	    len = buf.offset - offset;
	    buf.spread(offset, 1 + uint.size * 3);
	    buf.data[offset] = op;
	    uint* puint = (uint *)&buf.data[offset + 1];
	    puint[0] = len;
	    puint[1] = n;
	    puint[2] = m;
	    break;

	default:
	    break;
    }
    return 1;

Lerr:
    error("badly formed {n,m}");
}

int parseAtom()
{   ubyte op;
    uint offset;
    tchar c;

    //printf("parseAtom() '%.*s'\n", pattern[p .. pattern.length]);
    if (p < pattern.length)
    {
	c = pattern[p];
	switch (c)
	{
	    case '*':
	    case '+':
	    case '?':
		error("*+? not allowed in atom");
		p++;
		return 0;

	    case '(':
		p++;
		buf.write(REparen);
		offset = buf.offset;
		buf.write((uint)0);		// reserve space for length
		buf.write(re_nsub);
		re_nsub++;
		parseRegexp();
		*(uint *)&buf.data[offset] =
		    buf.offset - (offset + uint.size * 2);
		if (p == pattern.length || pattern[p] != ')')
		{
		    error("')' expected");
		    return 0;
		}
		p++;
		break;

	    case '[':
		if (!parseRange())
		    return 0;
		break;

	    case '.':
		p++;
		buf.write(REanychar);
		break;

	    case '^':
		p++;
		buf.write(REbol);
		break;

	    case '$':
		p++;
		buf.write(REeol);
		break;

	    case '\\':
		p++;
		if (p == pattern.length)
		{   error("no character past '\\'");
		    return 0;
		}
		c = pattern[p];
		switch (c)
		{
		    case 'b':    op = REwordboundary;	 goto Lop;
		    case 'B':    op = REnotwordboundary; goto Lop;
		    case 'd':    op = REdigit;		 goto Lop;
		    case 'D':    op = REnotdigit;	 goto Lop;
		    case 's':    op = REspace;		 goto Lop;
		    case 'S':    op = REnotspace;	 goto Lop;
		    case 'w':    op = REword;		 goto Lop;
		    case 'W':    op = REnotword;	 goto Lop;

		    Lop:
			buf.write(op);
			p++;
			break;

		    case 'f':
		    case 'n':
		    case 'r':
		    case 't':
		    case 'v':
		    case 'c':
		    case 'x':
		    case 'u':
		    case '0':
			c = escape();
			goto Lbyte;

		    case '1': case '2': case '3':
		    case '4': case '5': case '6':
		    case '7': case '8': case '9':
			c -= '1';
			if (c < re_nsub)
			{   buf.write(REbackref);
			    buf.write((ubyte)c);
			}
			else
			{   error("no matching back reference");
			    return 0;
			}
			p++;
			break;

		    default:
			p++;
			goto Lbyte;
		}
		break;

	    default:
		p++;
	    Lbyte:
		op = REchar;
		if (attributes & REA.ignoreCase)
		{
		    if (isalpha(c))
		    {
			op = REichar;
			c = std.ctype.toupper(c);
		    }
		}
		if (op == REchar && c <= 0xFF)
		{
		    // Look ahead and see if we can make this into
		    // an REstring
		    int q;
		    int len;

		    for (q = p; q < pattern.length; ++q)
		    {	tchar qc = pattern[q];

			switch (qc)
			{
			    case '{':
			    case '*':
			    case '+':
			    case '?':
				if (q == p)
				    goto Lchar;
				q--;
				break;

			    case '(':	case ')':
			    case '|':
			    case '[':	case ']':
			    case '.':	case '^':
			    case '$':	case '\\':
			    case '}':
				break;

			    default:
				continue;
			}
			break;
		    }
		    len = q - p;
		    if (len > 0)
		    {
			debug(regexp) printf("writing string len %d, c = '%c', pattern[p] = '%c'\n", len+1, c, pattern[p]);
			buf.reserve(5 + (1 + len) * tchar.size);
			buf.write((attributes & REA.ignoreCase) ? REistring : REstring);
			buf.write(len + 1);
			buf.write(c);
			buf.write(pattern[p .. p + len]);
			p = q;
			break;
		    }
		}
		if (c & ~0xFF)
		{
		    // Convert to wchar opcode
		    op = (op == REchar) ? REwchar : REiwchar;
		    buf.write(op);
		    buf.write(c);
		}
		else
		{
		 Lchar:
		    debug(regexp) printf("It's an REchar '%c'\n", c);
		    buf.write(op);
		    buf.write((char)c);
		}
		break;
	}
    }
    return 1;
}

private:
class Range
{
    uint maxc;
    uint maxb;
    OutBuffer buf;
    ubyte* base;
    bit[] bits;

    this(OutBuffer buf)
    {
	this.buf = buf;
	if (buf.data.length)
	    this.base = &buf.data[buf.offset];
    }

    void setbitmax(uint u)
    {   uint b;

	if (u > maxc)
	{
	    maxc = u;
	    b = u / 8;
	    if (b >= maxb)
	    {	uint u;

		u = base ? base - &buf.data[0] : 0;
		buf.fill0(b - maxb + 1);
		base = &buf.data[u];
		maxb = b + 1;
		bits = ((bit*)this.base)[0 .. maxc + 1];
	    }
	}
    }

    void setbit2(uint u)
    {
	setbitmax(u + 1);
	//printf("setbit2 [x%02x] |= x%02x\n", u >> 3, 1 << (u & 7));
	bits[u] = 1;
    }

};

int parseRange()
{   ubyte op;
    int c;
    int c2;
    uint i;
    uint cmax;
    uint offset;

    cmax = 0x7F;
    p++;
    op = REbit;
    if (p == pattern.length)
	goto Lerr;
    if (pattern[p] == '^')
    {   p++;
	op = REnotbit;
	if (p == pattern.length)
	    goto Lerr;
    }
    buf.write(op);
    offset = buf.offset;
    buf.write(cast(uint)0);		// reserve space for length
    buf.reserve(128 / 8);
    Range r = new Range(buf);
    if (op == REnotbit)
	r.setbit2(0);
    switch (pattern[p])
    {
	case ']':
	case '-':
	    c = pattern[p];
	    p++;
	    r.setbit2(c);
	    break;

	default:
	    break;
    }

    enum RS { start, rliteral, dash };
    RS rs;

    rs = RS.start;
    for (;;)
    {
	if (p == pattern.length)
	    goto Lerr;
	switch (pattern[p])
	{
	    case ']':
		switch (rs)
		{   case RS.dash:
			r.setbit2('-');
		    case RS.rliteral:
			r.setbit2(c);
			break;
		    case RS.start:
			break;
		}
		p++;
		break;

	    case '\\':
		p++;
		r.setbitmax(cmax);
		if (p == pattern.length)
		    goto Lerr;
		switch (pattern[p])
		{
		    case 'd':
			for (i = '0'; i <= '9'; i++)
			    r.bits[i] = 1;
			goto Lrs;

		    case 'D':
			for (i = 1; i < '0'; i++)
			    r.bits[i] = 1;
			for (i = '9' + 1; i <= cmax; i++)
			    r.bits[i] = 1;
			goto Lrs;

		    case 's':
			for (i = 0; i <= cmax; i++)
			    if (isspace(i))
				r.bits[i] = 1;
			goto Lrs;

		    case 'S':
			for (i = 1; i <= cmax; i++)
			    if (!isspace(i))
				r.bits[i] = 1;
			goto Lrs;

		    case 'w':
			for (i = 0; i <= cmax; i++)
			    if (isword((tchar)i))
				r.bits[i] = 1;
			goto Lrs;

		    case 'W':
			for (i = 1; i <= cmax; i++)
			    if (!isword((tchar)i))
				r.bits[i] = 1;
			goto Lrs;

		    Lrs:
			switch (rs)
			{   case RS.dash:
				r.setbit2('-');
			    case RS.rliteral:
				r.setbit2(c);
				break;
			}
			rs = RS.start;
			continue;

		    default:
			break;
		}
		c2 = escape();
		goto Lrange;

	    case '-':
		p++;
		if (rs == RS.start)
		    goto Lrange;
		else if (rs == RS.rliteral)
		    rs = RS.dash;
		else if (rs == RS.dash)
		{
		    r.setbit2(c);
		    r.setbit2('-');
		    rs = RS.start;
		}
		continue;

	    default:
		c2 = pattern[p];
		p++;
	    Lrange:
		switch (rs)
		{   case RS.rliteral:
			r.setbit2(c);
		    case RS.start:
			c = c2;
			rs = RS.rliteral;
			break;

		    case RS.dash:
			if (c > c2)
			{   error("inverted range in character class");
			    return 0;
			}
			r.setbitmax(c2);
			//printf("c = %x, c2 = %x\n",c,c2);
			for (; c <= c2; c++)
			    r.bits[c] = 1;
			rs = RS.start;
			break;
		}
		continue;
	}
	break;
    }
    //printf("maxc = %d, maxb = %d\n",r.maxc,r.maxb);
    ((ushort *)&buf.data[offset])[0] = (ushort)r.maxc;
    ((ushort *)&buf.data[offset])[1] = (ushort)r.maxb;
    if (attributes & REA.ignoreCase)
    {
	// BUG: what about wchar?
	r.setbitmax(0x7F);
	for (c = 'a'; c <= 'z'; c++)
	{
	    if (r.bits[c])
		r.bits[c + 'A' - 'a'] = 1;
	    else if (r.bits[c + 'A' - 'a'])
		r.bits[c] = 1;
	}
    }
    return 1;

Lerr:
    error("invalid range");
    return 0;
}

void error(char[] msg)
{
    errors++;
    debug(regexp) printf("error: %.*s\n", msg);
//assert(0);
//*(char*)0=0;
    throw new RegExpError(msg);
}

// p is following the \ char
int escape()
in
{
    assert(p < pattern.length);
}
body
{   int c;
    int i;
    tchar tc;

    c = pattern[p];		// none of the cases are multibyte
    switch (c)
    {
	case 'b':    c = '\b';	break;
	case 'f':    c = '\f';	break;
	case 'n':    c = '\n';	break;
	case 'r':    c = '\r';	break;
	case 't':    c = '\t';	break;
	case 'v':    c = '\v';	break;

	// BUG: Perl does \a and \e too, should we?

	case 'c':
	    ++p;
	    if (p == pattern.length)
		goto Lretc;
	    c = pattern[p];
	    // Note: we are deliberately not allowing wchar letters
	    if (!(('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')))
	    {
	     Lcerr:
		error("letter expected following \\c");
		return 0;
	    }
	    c &= 0x1F;
	    break;

	case '0':
	case '1':
	case '2':
	case '3':
	case '4':
	case '5':
	case '6':
	case '7':
	    c -= '0';
	    for (i = 0; i < 2; i++)
	    {
		p++;
		if (p == pattern.length)
		    goto Lretc;
		tc = pattern[p];
		if ('0' <= tc && tc <= '7')
		{   c = c * 8 + (tc - '0');
		    // Treat overflow as if last
		    // digit was not an octal digit
		    if (c >= 0xFF)
		    {	c >>= 3;
			return c;
		    }
		}
		else
		    return c;
	    }
	    break;

	case 'x':
	    c = 0;
	    for (i = 0; i < 2; i++)
	    {
		p++;
		if (p == pattern.length)
		    goto Lretc;
		tc = pattern[p];
		if ('0' <= tc && tc <= '9')
		    c = c * 16 + (tc - '0');
		else if ('a' <= tc && tc <= 'f')
		    c = c * 16 + (tc - 'a' + 10);
		else if ('A' <= tc && tc <= 'F')
		    c = c * 16 + (tc - 'A' + 10);
		else if (i == 0)	// if no hex digits after \x
		{
		    // Not a valid \xXX sequence
		    return 'x';
		}
		else
		    return c;
	    }
	    break;

	case 'u':
	    c = 0;
	    for (i = 0; i < 4; i++)
	    {
		p++;
		if (p == pattern.length)
		    goto Lretc;
		tc = pattern[p];
		if ('0' <= tc && tc <= '9')
		    c = c * 16 + (tc - '0');
		else if ('a' <= tc && tc <= 'f')
		    c = c * 16 + (tc - 'a' + 10);
		else if ('A' <= tc && tc <= 'F')
		    c = c * 16 + (tc - 'A' + 10);
		else
		{
		    // Not a valid \uXXXX sequence
		    p -= i;
		    return 'u';
		}
	    }
	    break;

	default:
	    break;
    }
    p++;
Lretc:
    return c;
}

/* ==================== optimizer ======================= */

void optimize()
{   ubyte[] prog;
    int i;

    debug(regexp) printf("RegExp.optimize()\n");
    prog = buf.toBytes();
    for (i = 0; 1;)
    {
	//printf("\tprog[%d] = %d, %d\n", i, prog[i], REstring);
	switch (prog[i])
	{
	    case REend:
	    case REanychar:
	    case REanystar:
	    case REbackref:
	    case REeol:
	    case REchar:
	    case REichar:
	    case REwchar:
	    case REiwchar:
	    case REstring:
	    case REistring:
	    case REtestbit:
	    case REbit:
	    case REnotbit:
	    case RErange:
	    case REnotrange:
	    case REwordboundary:
	    case REnotwordboundary:
	    case REdigit:
	    case REnotdigit:
	    case REspace:
	    case REnotspace:
	    case REword:
	    case REnotword:
		return;

	    case REbol:
		i++;
		continue;

	    case REor:
	    case REnm:
	    case REnmq:
	    case REparen:
	    case REgoto:
	    {
		OutBuffer bitbuf = new OutBuffer;
		Range r = new Range(bitbuf);
		uint offset;

		offset = i;
		if (startchars(r, prog[i .. prog.length]))
		{
		    debug(regexp) printf("\tfilter built\n");
		    buf.spread(offset, 1 + 4 + r.maxb);
		    buf.data[offset] = REtestbit;
		    ((ushort *)&buf.data[offset + 1])[0] = (ushort)r.maxc;
		    ((ushort *)&buf.data[offset + 1])[1] = (ushort)r.maxb;
		    i = offset + 1 + 4;
		    buf.data[i .. i + r.maxb] = r.base[0 .. r.maxb];
		}
		return;
	    }
	    default:
		assert(0);
	}
    }
}

/////////////////////////////////////////
// OR the leading character bits into r.
// Limit the character range from 0..7F,
// trymatch() will allow through anything over maxc.
// Return 1 if success, 0 if we can't build a filter or
// if there is no point to one.

int startchars(Range r, ubyte[] prog)
{   tchar c;
    uint maxc;
    uint maxb;
    uint len;
    uint b;
    uint n;
    uint m;
    ubyte* pop;
    int i;

    //printf("RegExp.startchars(prog = %p, progend = %p)\n", prog, progend);
    for (i = 0; i < prog.length;)
    {
	switch (prog[i])
	{
	    case REchar:
		c = prog[i + 1];
		if (c <= 0x7F)
		    r.setbit2(c);
		return 1;

	    case REichar:
		c = prog[i + 1];
		if (c <= 0x7F)
		{   r.setbit2(c);
		    r.setbit2(std.ctype.tolower((tchar)c));
		}
		return 1;

	    case REwchar:
	    case REiwchar:
		return 1;

	    case REanychar:
		return 0;		// no point

	    case REstring:
		len = *(uint *)&prog[i + 1];
		assert(len);
		c = *(tchar *)&prog[i + 1 + uint.size];
		debug(regexp) printf("\tREstring %d, '%c'\n", len, c);
		if (c <= 0x7F)
		    r.setbit2(c);
		return 1;

	    case REistring:
		len = *(uint *)&prog[i + 1];
		assert(len);
		c = *(tchar *)&prog[i + 1 + uint.size];
		debug(regexp) printf("\tREistring %d, '%c'\n", len, c);
		if (c <= 0x7F)
		{   r.setbit2(std.ctype.toupper((tchar)c));
		    r.setbit2(std.ctype.tolower((tchar)c));
		}
		return 1;

	    case REtestbit:
	    case REbit:
		maxc = ((ushort *)&prog[i + 1])[0];
		maxb = ((ushort *)&prog[i + 1])[1];
		if (maxc <= 0x7F)
		    r.setbitmax(maxc);
		else
		    maxb = r.maxb;
		for (b = 0; b < maxb; b++)
		    r.base[b] |= prog[i + 1 + 4 + b];
		return 1;

	    case REnotbit:
		maxc = ((ushort *)&prog[i + 1])[0];
		maxb = ((ushort *)&prog[i + 1])[1];
		if (maxc <= 0x7F)
		    r.setbitmax(maxc);
		else
		    maxb = r.maxb;
		for (b = 0; b < maxb; b++)
		    r.base[b] |= ~prog[i + 1 + 4 + b];
		return 1;

	    case REbol:
	    case REeol:
		return 0;

	    case REor:
		len = ((uint *)&prog[i + 1])[0];
		return startchars(r, prog[i + 1 + uint.size .. prog.length]) &&
		       startchars(r, prog[i + 1 + uint.size + len .. prog.length]);

	    case REgoto:
		len = ((uint *)&prog[i + 1])[0];
		i += 1 + uint.size + len;
		break;

	    case REanystar:
		return 0;

	    case REnm:
	    case REnmq:
		// len, n, m, ()
		len = ((uint *)&prog[i + 1])[0];
		n   = ((uint *)&prog[i + 1])[1];
		m   = ((uint *)&prog[i + 1])[2];
		pop = &prog[i + 1 + uint.size * 3];
		if (!startchars(r, pop[0 .. len]))
		    return 0;
		if (n)
		    return 1;
		i += 1 + uint.size * 3 + len;
		break;

	    case REparen:
		// len, ()
		len = ((uint *)&prog[i + 1])[0];
		n   = ((uint *)&prog[i + 1])[1];
		pop = &prog[0] + i + 1 + uint.size * 2;
		return startchars(r, pop[0 .. len]);

	    case REend:
		return 0;

	    case REwordboundary:
	    case REnotwordboundary:
		return 0;

	    case REdigit:
		r.setbitmax('9');
		for (c = '0'; c <= '9'; c++)
		    r.bits[c] = 1;
		return 1;

	    case REnotdigit:
		r.setbitmax(0x7F);
		for (c = 0; c <= '0'; c++)
		    r.bits[c] = 1;
		for (c = '9' + 1; c <= r.maxc; c++)
		    r.bits[c] = 1;
		return 1;

	    case REspace:
		r.setbitmax(0x7F);
		for (c = 0; c <= r.maxc; c++)
		    if (isspace(c))
			r.bits[c] = 1;
		return 1;

	    case REnotspace:
		r.setbitmax(0x7F);
		for (c = 0; c <= r.maxc; c++)
		    if (!isspace(c))
			r.bits[c] = 1;
		return 1;

	    case REword:
		r.setbitmax(0x7F);
		for (c = 0; c <= r.maxc; c++)
		    if (isword((tchar)c))
			r.bits[c] = 1;
		return 1;

	    case REnotword:
		r.setbitmax(0x7F);
		for (c = 0; c <= r.maxc; c++)
		    if (!isword((tchar)c))
			r.bits[c] = 1;
		return 1;

	    case REbackref:
		return 0;
	}
    }
    return 1;
}

/* ==================== replace ======================= */

/************************************
 * This version of replace() uses:
 *	&	replace with the match
 *	\n	replace with the nth parenthesized match, n is 1..9
 *	\c	replace with char c
 */

public tchar[] replaceOld(tchar[] format)
{
    OutBuffer buf;
    tchar[] result;
    tchar c;

//printf("replace: this = %p so = %d, eo = %d\n", this, pmatch[0].rm_so, pmatch[0].rm_eo);
//printf("3input = '%.*s'\n", input);
    buf = new OutBuffer();
    buf.reserve(format.length * tchar.size);
    for (uint i; i < format.length; i++)
    {
	c = format[i];
	switch (c)
	{
	    case '&':
//printf("match = '%.*s'\n", input[pmatch[0].rm_so .. pmatch[0].rm_eo]);
		buf.write(input[pmatch[0].rm_so .. pmatch[0].rm_eo]);
		break;

	    case '\\':
		if (i + 1 < format.length)
		{
		    c = format[++i];
		    if (c >= '1' && c <= '9')
		    {   uint i;

			i = c - '0';
			if (i <= re_nsub && pmatch[i].rm_so != pmatch[i].rm_eo)
			    buf.write(input[pmatch[i].rm_so .. pmatch[i].rm_eo]);
			break;
		    }
		}
		buf.write(c);
		break;

	    default:
		buf.write(c);
		break;
	}
    }
    result = cast(tchar[])buf.toBytes();
    return result;
}

// This version of replace uses:
//	$$	$
//	$&	The matched substring.
//	$`	The portion of string that precedes the matched substring.
//	$'	The portion of string that follows the matched substring.
//	$n	The nth capture, where n is a single digit 1-9
//		and $n is not followed by a decimal digit.
//	$nn	The nnth capture, where nn is a two-digit decimal
//		number 01-99.
//		If nnth capture is undefined or more than the number
//		of parenthesized subexpressions, use the empty
//		string instead.
//
//	Any other $ are left as is.

public tchar[] replace(tchar[] format)
{
    return replace3(format, input, pmatch[0 .. re_nsub + 1]);
}

// Static version that doesn't require a RegExp object to be created

private tchar[] replace3(tchar[] format, tchar[] input, regmatch_t[] pmatch)
{
    OutBuffer buf;
    tchar[] result;
    tchar c;
    uint c2;
    int rm_so;
    int rm_eo;
    int i;
    int f;

//    printf("replace3(format = '%.*s', input = '%.*s')\n", format, input);
    buf = new OutBuffer();
    buf.reserve(format.length * tchar.size);
    for (f = 0; f < format.length; f++)
    {
	c = format[f];
      L1:
	if (c != '$')
	{
	    buf.write(c);
	    continue;
	}
	++f;
	if (f == format.length)
	{
	    buf.write(cast(tchar)'$');
	    break;
	}
	c = format[f];
	switch (c)
	{
	    case '&':
		rm_so = pmatch[0].rm_so;
		rm_eo = pmatch[0].rm_eo;
		goto Lstring;

	    case '`':
		rm_so = 0;
		rm_eo = pmatch[0].rm_so;
		goto Lstring;

	    case '\'':
		rm_so = pmatch[0].rm_eo;
		rm_eo = input.length;
		goto Lstring;

	    case '0': case '1': case '2': case '3': case '4':
	    case '5': case '6': case '7': case '8': case '9':
		i = c - '0';
		if (f + 1 == format.length)
		{
		    if (i == 0)
		    {
			buf.write(cast(tchar)'$');
			buf.write(c);
			continue;
		    }
		}
		else
		{
		    c2 = format[f + 1];
		    if (c2 >= '0' && c2 <= '9')
		    {   i = (c - '0') * 10 + (c2 - '0');
			f++;
		    }
		    if (i == 0)
		    {
			buf.write(cast(tchar)'$');
			buf.write(c);
			c = c2;
			goto L1;
		    }
		}

		if (i < pmatch.length)
		{   rm_so = pmatch[i].rm_so;
		    rm_eo = pmatch[i].rm_eo;
		    goto Lstring;
		}
		break;

	    Lstring:
		if (rm_so != rm_eo)
		    buf.write(input[rm_so .. rm_eo]);
		break;

	    default:
		buf.write(cast(tchar)'$');
		buf.write(c);
		break;
	}
    }
    result = (tchar[])buf.toBytes();
    return result;
}

}

