
/* Written by Walter Bright
 * www.digitalmars.com
 * Placed in the Public Domain.
 */

module std.stdio;

private import std.c.stdio;
private import std.format;
private import std.utf;

private void writex(FILE* fp, TypeInfo[] arguments, void* argptr, int newline)
{   int orientation;

    orientation = fwide(fp, 0);
    if (orientation <= 0)		// byte orientation or no orientation
    {
	void putc(dchar c)
	{
	    if (c <= 0x7F)
	    {
		std.c.stdio.fputc(c, fp);
	    }
	    else
	    {	char[4] buf;
		char[] b;

		b = std.utf.toUTF8(buf, c);
		for (size_t i = 0; i < b.length; i++)
		    std.c.stdio.fputc(b[i], fp);
	    }
	}

	std.format.doFormat(&putc, arguments, argptr);
	if (newline)
	    std.c.stdio.fputc('\n', fp);
    }
    else if (orientation > 0)		// wide orientation
    {
	version (Windows)
	{
	    void putcw(dchar c)
	    {
		assert(isValidDchar(c));
		if (c <= 0xFFFF)
		{
		    std.c.stdio.fputwc(c, fp);
		}
		else
		{   wchar[2] buf;

		    buf[0] = (((c - 0x10000) >> 10) & 0x3FF) + 0xD800;
		    buf[1] = ((c - 0x10000) & 0x3FF) + 0xDC00;
		    std.c.stdio.fputwc(buf[0], fp);
		    std.c.stdio.fputwc(buf[1], fp);
		}
	    }
	}
	else version (linux)
	{
	    void putcw(dchar c)
	    {
		std.c.stdio.fputwc(c, fp);
	    }
	}
	else
	{
	    static assert(0);
	}

	std.format.doFormat(&putcw, arguments, argptr);
	if (newline)
	    std.c.stdio.fputwc('\n', fp);
    }
}


void writef(...)
{
    writex(stdout, _arguments, _argptr, 0);
}

void writefln(...)
{
    writex(stdout, _arguments, _argptr, 1);
}

void fwritef(FILE* fp, ...)
{
    writex(fp, _arguments, _argptr, 0);
}

void fwritefln(FILE* fp, ...)
{
    writex(fp, _arguments, _argptr, 1);
}

