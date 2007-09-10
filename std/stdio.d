
/* Written by Walter Bright
 * www.digitalmars.com
 * Placed in the Public Domain.
 */

/********************************
 * Standard I/O functions that extend $(B std.c.stdio).
 * $(B std.c.stdio) is automatically imported when importing
 * $(B std.stdio).
 * Macros:
 *	WIKI=Phobos/StdStdio
 */

module std.stdio;

public  import std.c.stdio;

import std.format;
import std.utf;

version (DigitalMars)
{
    version (Windows)
    {
	version = DIGITAL_MARS_STDIO;
    }
}


version (DIGITAL_MARS_STDIO)
{
    extern (C)
    {
	int _fputc_nlock(int, FILE*);
	int _fputwc_nlock(int, FILE*);
	int __fp_lock(FILE*);
	void __fp_unlock(FILE*);
    }
    alias _fputc_nlock FPUTC;
    alias _fputwc_nlock FPUTWC;
}
else
{
    alias std.c.stdio.fputc FPUTC;
    alias std.c.stdio.fputwc FPUTWC;

    int __fp_lock(FILE* fp) { return 0; }
    void __fp_unlock(FILE* fp) { }
}

void writefx(FILE* fp, TypeInfo[] arguments, void* argptr, int newline=false)
{   int orientation;

    orientation = fwide(fp, 0);
    try
    {
	/* Do the file stream locking at the outermost level
	 * rather than character by character.
	 */
	__fp_lock(fp);

	if (orientation <= 0)		// byte orientation or no orientation
	{
	    void putc(dchar c)
	    {
		if (c <= 0x7F)
		{
		    FPUTC(c, fp);
		}
		else
		{   char[4] buf;
		    char[] b;

		    b = std.utf.toUTF8(buf, c);
		    for (size_t i = 0; i < b.length; i++)
			FPUTC(b[i], fp);
		}
	    }

	    std.format.doFormat(&putc, arguments, argptr);
	    if (newline)
		FPUTC('\n', fp);
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
			FPUTWC(c, fp);
		    }
		    else
		    {   wchar[2] buf;

			buf[0] = (((c - 0x10000) >> 10) & 0x3FF) + 0xD800;
			buf[1] = ((c - 0x10000) & 0x3FF) + 0xDC00;
			FPUTWC(buf[0], fp);
			FPUTWC(buf[1], fp);
		    }
		}
	    }
	    else version (linux)
	    {
		void putcw(dchar c)
		{
		    FPUTWC(c, fp);
		}
	    }
	    else
	    {
		static assert(0);
	    }

	    std.format.doFormat(&putcw, arguments, argptr);
	    if (newline)
		FPUTWC('\n', fp);
	}
    }
    finally
    {
	__fp_unlock(fp);
    }
}


/***********************************
 * Arguments are formatted per the
 * $(LINK2 std_format.html#format-string, format strings)
 * and written to $(B stdout).
 */

void writef(...)
{
    writefx(stdout, _arguments, _argptr, 0);
}

/***********************************
 * Same as $(B writef), but a newline is appended
 * to the output.
 */

void writefln(...)
{
    writefx(stdout, _arguments, _argptr, 1);
}

/***********************************
 * Same as $(B writef), but output is sent to the
 * stream fp instead of $(B stdout).
 */

void fwritef(FILE* fp, ...)
{
    writefx(fp, _arguments, _argptr, 0);
}

/***********************************
 * Same as $(B writefln), but output is sent to the
 * stream fp instead of $(B stdout).
 */

void fwritefln(FILE* fp, ...)
{
    writefx(fp, _arguments, _argptr, 1);
}
