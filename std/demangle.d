
// Written in the D programming language.

/*
 * Placed into the Public Domain.
 */

/****
 * Demangle D mangled names.
 * Macros:
 *	WIKI = Phobos/StdDemangle
 */

/* Authors:
 *	Walter Bright, Digital Mars, www.digitalmars.com
 *	Thomas Kuehne
 */

module std.demangle;

//debug=demangle;		// uncomment to turn on debugging printf's

private import std.ctype;
private import std.string;
private import std.utf;

private import std.stdio;

private class MangleException : Exception
{
    this()
    {
	super("MangleException");
    }
}

/*****************************
 * Demangle D mangled names.
 *
 * If it is not a D mangled name, it returns its argument name.
 * Example:
 *	This program reads standard in and writes it to standard out,
 *	pretty-printing any found D mangled names.
-------------------
import std.stdio;
import std.ctype;
import std.demangle;

int main()
{   char[] buffer;
    bool inword;
    int c;

    while ((c = fgetc(stdin)) != EOF)
    {
	if (inword)
	{
	    if (c == '_' || isalnum(c))
		buffer ~= cast(char) c;
	    else
	    {
		inword = false;
		writef(demangle(buffer), cast(char) c);
	    }
	}
	else
	{   if (c == '_' || isalpha(c))
	    {	inword = true;
		buffer.length = 0;
		buffer ~= cast(char) c;
	    }
	    else
		writef(cast(char) c);
	}
    }
    if (inword)
	writef(demangle(buffer));
    return 0;
}
-------------------
 */

char[] demangle(char[] name)
{
    size_t ni = 2;
    char[] delegate() fparseTemplateInstanceName;

    static void error()
    {
	//writefln("error()");
	throw new MangleException();
    }

    static ubyte ascii2hex(char c)
    {
	if (!isxdigit(c))
	    error();
	return cast(ubyte)
	      ( (c >= 'a') ? c - 'a' + 10 :
	        (c >= 'A') ? c - 'A' + 10 :
			     c - '0'
	      );
    }

    size_t parseNumber()
    {
	//writefln("parseNumber() %d", ni);
	size_t result;

	while (ni < name.length && isdigit(name[ni]))
	{   int i = name[ni] - '0';
	    if (result > (size_t.max - i) / 10)
		error();
	    result = result * 10 + i;
	    ni++;
	}
	return result;
    }

    char[] parseSymbolName()
    {
	//writefln("parseSymbolName() %d", ni);
	size_t i = parseNumber();
	if (ni + i > name.length)
	    error();
	char[] result;
	if (i >= 5 &&
	    name[ni] == '_' &&
	    name[ni + 1] == '_' &&
	    name[ni + 2] == 'T')
	{
	    size_t nisave = ni;
	    bool err;
	    ni += 3;
	    try
	    {
		result = fparseTemplateInstanceName();
		if (ni != nisave + i)
		    err = true;
	    }
	    catch (MangleException me)
	    {
		err = true;
	    }
	    ni = nisave;
	    if (err)
		goto L1;
	    goto L2;
	}
      L1:
	result = name[ni .. ni + i];
      L2:
	ni += i;
	return result;
    }

    char[] parseQualifiedName()
    {
	//writefln("parseQualifiedName() %d", ni);
	char[] result;

	while (ni < name.length && isdigit(name[ni]))
	{
	    if (result.length)
		result ~= ".";
	    result ~= parseSymbolName();
	}
	return result;
    }

    char[] parseType(char[] identifier = null)
    {
	//writefln("parseType() %d", ni);
	int isdelegate = 0;
      Lagain:
	if (ni >= name.length)
	    error();
	char[] p;
	switch (name[ni++])
	{
	    case 'v':	p = "void";	goto L1;
	    case 'b':	p = "bit";	goto L1;
	    case 'x':	p = "bool";	goto L1;
	    case 'g':	p = "byte";	goto L1;
	    case 'h':	p = "ubyte";	goto L1;
	    case 's':	p = "short";	goto L1;
	    case 't':	p = "ushort";	goto L1;
	    case 'i':	p = "int";	goto L1;
	    case 'k':	p = "uint";	goto L1;
	    case 'l':	p = "long";	goto L1;
	    case 'm':	p = "ulong";	goto L1;
	    case 'f':	p = "float";	goto L1;
	    case 'd':	p = "double";	goto L1;
	    case 'e':	p = "real";	goto L1;
	    case 'o':	p = "ifloat";	goto L1;
	    case 'p':	p = "idouble";	goto L1;
	    case 'j':	p = "ireal";	goto L1;
	    case 'q':	p = "cfloat";	goto L1;
	    case 'r':	p = "cdouble";	goto L1;
	    case 'c':	p = "creal";	goto L1;
	    case 'a':	p = "char";	goto L1;
	    case 'u':	p = "wchar";	goto L1;
	    case 'w':	p = "dchar";	goto L1;

	    case 'A':				// dynamic array
		p = parseType() ~ "[]";
		goto L1;

	    case 'P':				// pointer
		p = parseType() ~ "*";
		goto L1;

	    case 'G':				// static array
	    {	size_t ns = ni;
		parseNumber();
		size_t ne = ni;
		p = parseType() ~ "[" ~ name[ns .. ne] ~ "]";
		goto L1;
	    }

	    case 'H':				// associative array
		p = parseType();
		p = parseType() ~ "[" ~ p ~ "]";
		goto L1;

	    case 'D':				// delegate
		isdelegate = 1;
		goto Lagain;

	    case 'F':				// D function
	    case 'U':				// C function
	    case 'W':				// Windows function
	    case 'V':				// Pascal function
	    case 'R':				// C++ function
	    {	char mc = name[ni - 1];
		char[] args;

		while (1)
		{
		    if (ni >= name.length)
			error();
		    char c = name[ni];
		    if (c == 'Z')
			break;
		    if (c == 'X')
		    {
		        args ~= " ...";
			break;
		    }
		    if (args.length)
			args ~= ", ";
		    switch (c)
		    {
			case 'J':
			    args ~= "out ";
			    ni++;
			    goto default;

			case 'K':
			    args ~= "inout ";
			    ni++;
			    goto default;

			case 'L':
			    args ~= "lazy ";
			    ni++;
			    goto default;

			default:
			    args ~= parseType();
			    continue;

			case 'Y':
			    args ~= "...";
			    break;
		    }
		    break;
		}
		ni++;
		if (!isdelegate && identifier.length)
		{
		    switch (mc)
		    {
			case 'F': p = null;                break; // D function
			case 'U': p = "extern (C) ";       break; // C function
			case 'W': p = "extern (Windows) "; break; // Windows function
			case 'V': p = "extern (Pascal) ";  break; // Pascal function
			default:  assert(0);
		    }
		    p ~= parseType() ~ " " ~ identifier ~ "(" ~ args ~ ")";
		    return p;
		}
		p = parseType() ~
		    (isdelegate ? " delegate(" : " function(") ~
		    args ~
		    ")";
		isdelegate = 0;
		goto L1;
	    }

	    case 'C':	p = "class ";	goto L2;
	    case 'S':	p = "struct ";	goto L2;
	    case 'E':	p = "enum ";	goto L2;
	    case 'T':	p = "typedef ";	goto L2;

	    L2:	p ~= parseQualifiedName();
		goto L1;

	    L1:
		if (isdelegate)
		    error();		// 'D' must be followed by function
		if (identifier.length)
		    p ~= " " ~ identifier;
		return p;

	    default:
		size_t i = ni - 1;
		ni = name.length;
		p = name[i .. length];
		goto L1;
	}
	assert(0);
    }

    char[] parseTemplateInstanceName()
    {
	char[] result = parseSymbolName() ~ "!(";
	int nargs;

	while (1)
	{   size_t i;

	    if (ni >= name.length)
		error();
	    if (nargs && name[ni] != 'Z')
		result ~= ", ";
	    nargs++;
	    switch (name[ni++])
	    {
		case 'T':
		    result ~= parseType();
		    continue;

		case 'V':

		    void getReal()
		    {   real r;
			ubyte *p = cast(ubyte *)&r;

			if (ni + 10 * 2 > name.length)
			    error();
			for (i = 0; i < 10; i++)
			{   ubyte b;

			    b = cast(ubyte)
				(
				 (ascii2hex(name[ni + i * 2]) << 4) +
				  ascii2hex(name[ni + i * 2 + 1])
				);
			    p[i] = b;
			}
			result ~= format(r);
			ni += 10 * 2;
		    }

		    result ~= parseType() ~ " ";
		    if (ni >= name.length)
			error();
		    switch (name[ni++])
		    {
			case '0': case '1': case '2': case '3': case '4':
			case '5': case '6': case '7': case '8': case '9':
			    i = ni - 1;
			    while (ni < name.length && isdigit(name[ni]))
				ni++;
			    result ~= name[i .. ni];
			    break;

			case 'N':
			    i = ni;
			    while (ni < name.length && isdigit(name[ni]))
				ni++;
			    if (i == ni)
				error();
			    result ~= "-" ~ name[i .. ni];
			    break;

			case 'n':
			    result ~= "null";
			    break;

			case 'e':
			    getReal();
			    break;

			case 'c':
			    getReal();
			    result ~= '+';
			    getReal();
			    result ~= 'i';
			    break;

			case 'a':
			case 'w':
			case 'd':
			{   char m = name[ni - 1];
			    if (m == 'a')
				m = 'c';
			    size_t n = parseNumber();
			    if (ni >= name.length || name[ni++] != '_' ||
				ni + n * 2 > name.length)
				error();
			    result ~= '"';
			    for (i = 0; i < n; i++)
			    {	char c;

				c = (ascii2hex(name[ni + i * 2]) << 4) +
				     ascii2hex(name[ni + i * 2 + 1]);
				result ~= c;
			    }
			    ni += n * 2;
			    result ~= '"';
			    result ~= m;
			    break;
			}

			default:
			    error();
			    break;
		    }
		    continue;

		case 'S':
		    result ~= parseSymbolName();
		    continue;

		case 'Z':
		    break;

		default:
		    error();
	    }
	    break;
	}
	result ~= ")";
	return result;
    }

    if (name.length < 3 ||
	name[0] != '_' ||
	name[1] != 'D' ||
	!isdigit(name[2]))
    {
	goto Lnot;
    }

    fparseTemplateInstanceName = &parseTemplateInstanceName;

    try
    {
	char[] result = parseQualifiedName();
	result = parseType(result);
	if (ni != name.length)
	    goto Lnot;
	return result;
    }
    catch (MangleException e)
    {
    }

Lnot:
    // Not a recognized D mangled name; so return original
    return name;
}


unittest
{
    debug(demangle) printf("demangle.demangle.unittest\n");

    static char[][2][] table =
    [
	[ "printf",	"printf" ],
	[ "_foo",	"_foo" ],
	[ "_D88",	"_D88" ],
	[ "_D4test3fooAa", "char[] test.foo"],
	[ "_D8demangle8demangleFAaZAa", "char[] demangle.demangle(char[])" ],
	[ "_D6object6Object8opEqualsFC6ObjectZi", "int object.Object.opEquals(class Object)" ],
	[ "_D4test2dgDFiYd", "double delegate(int, ...) test.dg" ],
	[ "_D4test58__T9factorialVde67666666666666860140VG5aa5_68656c6c6fVPvnZ9factorialf", "float test.factorial!(double 4.2, char[5] \"hello\"c, void* null).factorial" ],
	[ "_D4test101__T9factorialVde67666666666666860140Vrc9a999999999999d9014000000000000000c00040VG5aa5_68656c6c6fVPvnZ9factorialf", "float test.factorial!(double 4.2, cdouble 6.8+3i, char[5] \"hello\"c, void* null).factorial" ],
	[ "_D4test34__T3barVG3uw3_616263VG3wd3_646566Z1xi", "int test.bar!(wchar[3] \"abc\"w, dchar[3] \"def\"d).x" ],
	[ "_D8demangle4testFLC6ObjectLDFLiZiZi", "int demangle.test(lazy class Object, lazy int delegate(lazy int))"],
	[ "_D8demangle4testFAiXi", "int demangle.test(int[] ...)"],
	[ "_D8demangle4testFLAiXi", "int demangle.test(lazy int[] ...)"] 
    ];

    foreach (char[][2] name; table)
    {
	char[] r = demangle(name[0]);
	//writefln("[ \"%s\", \"%s\" ],", name[0], r);
	assert(r == name[1]);
    }
}


