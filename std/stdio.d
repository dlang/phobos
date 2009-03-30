
// Written in the D programming language.

/* Written by Walter Bright and Andrei Alexandrescu
 * http://www.digitalmars.com/d
 * Placed in the Public Domain.
 */

/********************************
 * Standard I/O functions that extend $(B std.c.stdio).
 * $(B std.c.stdio) is $(D_PARAM public)ally imported when importing
 * $(B std.stdio).
 *
 * Authors:
 *
 * $(WEB digitalmars.com, Walter Bright), $(WEB erdani.org, Andrei
Alexandrescu)
 *
 * Macros:
 *	WIKI=Phobos/StdStdio
 */

module std.stdio;

public import std.c.stdio;

import core.memory;
import std.format;
import std.utf;
import std.string;
import core.stdc.errno;
import std.c.stdlib;
import std.c.string;
import std.c.stddef;
import std.c.wcharh;
import std.conv;
import std.traits;
import std.contracts;
import std.file;
import std.typetuple;


version (DigitalMars)
{
    version (Windows)
    {
	// Specific to the way Digital Mars C does stdio
	version = DIGITAL_MARS_STDIO;
    }
}

version (linux)
{
    // Specific to the way Gnu C does stdio
    version = GCC_IO;
}

version (OSX)
{
    version = GENERIC_IO;
}

version (DIGITAL_MARS_STDIO)
{
    extern (C)
    {
	/* **
	 * Digital Mars under-the-hood C I/O functions
	 */
	int _fputc_nlock(int, FILE*);
	int _fputwc_nlock(int, FILE*);
	int _fgetc_nlock(FILE*);
	int _fgetwc_nlock(FILE*);
	int __fp_lock(FILE*);
	void __fp_unlock(FILE*);
    }
    alias _fputc_nlock FPUTC;
    alias _fputwc_nlock FPUTWC;
    alias _fgetc_nlock FGETC;
    alias _fgetwc_nlock FGETWC;

    alias __fp_lock FLOCK;
    alias __fp_unlock FUNLOCK;
}
else version (GCC_IO)
{
    /* **
     * Gnu under-the-hood C I/O functions; see
     * http://www.gnu.org/software/libc/manual/html_node/I_002fO-on-Streams.html#I_002fO-on-Streams
     */
    private import std.c.linux.linux;
    private import core.sys.posix.stdio;
    extern (C)
    {
	int fputc_unlocked(int, FILE*);
	int fputwc_unlocked(wchar_t, FILE*);
	int fgetc_unlocked(FILE*);
	int fgetwc_unlocked(FILE*);
	void flockfile(FILE*);
	void funlockfile(FILE*);
	ssize_t getline(char**, size_t*, FILE*);
	ssize_t getdelim (char**, size_t*, int, FILE*);

	private size_t fwrite_unlocked(const(void)* ptr,
                 size_t size, size_t n, FILE *stream);
    }

    alias fputc_unlocked FPUTC;
    alias fputwc_unlocked FPUTWC;
    alias fgetc_unlocked FGETC;
    alias fgetwc_unlocked FGETWC;

    alias flockfile FLOCK;
    alias funlockfile FUNLOCK;
}
else version (GENERIC_IO)
{
    extern (C)
    {
	void flockfile(FILE*);
	void funlockfile(FILE*);
    }

    alias fputc FPUTC;
    alias fputwc FPUTWC;
    alias fgetc FGETC;
    alias fgetwc FGETWC;

    alias flockfile FLOCK;
    alias funlockfile FUNLOCK;
}
else
{
    static assert(0, "unsupported C I/O system");
}


/*********************
 * Thrown if I/O errors happen.
 */
class StdioException : Exception
{
    uint errno;			// operating system error code

    this(string msg)
    {
	super(msg);
    }

    this(uint errno)
    {
	version (Posix)
	{   char[80] buf = void;
	    auto s = std.c.string.strerror_r(errno, buf.ptr, buf.length);
	}
	else
	{
	    auto s = std.c.string.strerror(errno);
	}
	super(std.string.toString(s).idup);
    }

    static void opCall(string msg)
    {
	throw new StdioException(msg);
    }

    static void opCall()
    {
	throw new StdioException(getErrno);
    }
}

private
void writefx(FILE* fp, TypeInfo[] arguments, void* argptr, int newline=false)
{
    int orientation = fwide(fp, 0);

    /* Do the file stream locking at the outermost level
     * rather than character by character.
     */
    FLOCK(fp);
    scope(exit) FUNLOCK(fp);

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
		auto b = std.utf.toUTF8(buf, c);
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

		    buf[0] = cast(wchar) ((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
		    buf[1] = cast(wchar) (((c - 0x10000) & 0x3FF) + 0xDC00);
		    FPUTWC(buf[0], fp);
		    FPUTWC(buf[1], fp);
		}
	    }
	}
	else version (Posix)
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


/***********************************
 * If the first argument $(D_PARAM args[0]) is a $(D_PARAM FILE*), for
 * each argument $(D_PARAM arg) in $(D_PARAM args[1..$]), format the
 * argument (as per $(LINK2 std_conv.html, to!(string)(arg))) and
 * write the resulting string to $(D_PARAM args[0]). If $(D_PARAM
 * args[0]) is not a $(D_PARAM FILE*), the call is equivalent to
 * $(D_PARAM write(stdout, args)).
 *
 * A call without any arguments will fail to compile. In the
 * exceedingly rare case you'd want to print a $(D_PARAM FILE*) to
 * $(D_PARAM stdout) as a hex pointer, $(D_PARAM write("", myFilePtr))
 * will do the trick.
 *
 * In case of an I/O error, throws an StdioException.
 */
void write(T...)(T args)
{
    static if (is(typeof(args[0]) : FILE*))
    {
        alias args[0] target;
        enum first = 1;
    }
    else
    {
        alias stdout target;
        enum first = 0;
    }
    writef(target, "", args[first .. $]);
    static if (args.length && is(typeof(args[$ - 1]) : dchar)) {
        if (args[$ - 1] == '\n') fflush(target);
    }
}

unittest
{
    void[] buf;
    write(buf);
    // test write
    string file = "dmd-build-test.deleteme.txt";
    FILE* f = fopen(file, "w");
    assert(f, getcwd());
    scope(exit) { std.file.remove(file); }
    write(f, "Hello, ",  "world number ", 42, "!");
    fclose(f) == 0 || assert(false);
    assert(cast(char[]) std.file.read(file) == "Hello, world number 42!");
    // test write on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout = fopen(file, "w");
    assert(stdout);
    Object obj;
    write("Hello, ",  "world number ", 42, "! ", obj);
    fclose(stdout) == 0 || assert(false);
    auto result = cast(char[]) std.file.read(file);
    assert(result == "Hello, world number 42! null", result);
}

/***********************************
 * Equivalent to $(D_PARAM write(args, '\n')).  Calling $(D_PARAM
 * writeln) without arguments is valid and just prints a newline to
 * the standard output.
 */
void writeln(T...)(T args)
{
    write(args, '\n');
}

unittest
{
    // test writeln
    string file = "dmd-build-test.deleteme.txt";
    FILE* f = fopen(file, "w");
    assert(f);
    scope(exit) { std.file.remove(file); }
    writeln(f, "Hello, ",  "world number ", 42, "!");
    fclose(f) == 0 || assert(false);
  version (Windows)
    assert(cast(char[]) std.file.read(file) == "Hello, world number 42!\r\n");
  else
    assert(cast(char[]) std.file.read(file) == "Hello, world number 42!\n");
    // test writeln on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout = fopen(file, "w");
    assert(stdout);
    writeln("Hello, ",  "world number ", 42, "!");
    fclose(stdout) == 0 || assert(false);
  version (Windows)
    assert(cast(char[]) std.file.read(file) == "Hello, world number 42!\r\n");
  else
    assert(cast(char[]) std.file.read(file) == "Hello, world number 42!\n");
}

/***********************************
 * If the first argument $(D_PARAM args[0]) is a $(D_PARAM FILE*), use
 * $(LINK2 std_format.html#format-string, the format specifier) in
 * $(D_PARAM args[1]) to control the formatting of $(D_PARAM
 * args[2..$]), and write the resulting string to $(D_PARAM args[0]).
 * If $(D_PARAM arg[0]) is not a $(D_PARAM FILE*), the call is
 * equivalent to $(D_PARAM writef(stdout, args)).
 *

IMPORTANT:

New behavior starting with D 2.006: unlike previous versions,
$(D_PARAM writef) (and also $(D_PARAM writefln)) only scans its first
string argument for format specifiers, but not subsequent string
arguments. This decision was made because the old behavior made it
unduly hard to simply print string variables that occasionally
embedded percent signs.

Also new starting with 2.006 is support for positional
parameters with
$(LINK2 http://opengroup.org/onlinepubs/009695399/functions/printf.html,
POSIX) syntax.

Example:

-------------------------
writef("Date: %2$s %1$s", "October", 5); // "Date: 5 October"
------------------------

The positional and non-positional styles can be mixed in the same
format string. (POSIX leaves this behavior undefined.) The internal
counter for non-positional parameters tracks the next parameter after
the largest positional parameter already used.

New starting with 2.008: raw format specifiers. Using the "%r"
specifier makes $(D_PARAM writef) simply write the binary
representation of the argument. Use "%-r" to write numbers in little
endian format, "%+r" to write numbers in big endian format, and "%r"
to write numbers in platform-native format.

*/

void writef(T...)(T args)
{
    PrivateFileWriter!(char) w;
    enum errorMessage =
        "You must pass a formatting string as the first"
        " argument to writef. If no formatting is needed,"
        " you may want to use write.";
    static if (is(typeof(args[0]) : FILE*))
    {
        alias args[0] target;
        enum first = 1;
    }
    else
    {
        alias stdout target;
        enum first = 0;
    }
    w.backend = target;
    FLOCK(w.backend);
    scope(exit) FUNLOCK(w.backend);
    static if (!isSomeString!(T[first]))
    {
        // bacward compatibility hack
        std.format.formattedWrite(w, "", args[first .. $]);
    }
    else
    {
        std.format.formattedWrite(w, args[first .. $]);
    }
}

unittest
{
    // test writef
    string file = "dmd-build-test.deleteme.txt";
    auto f = fopen(file, "w");
    assert(f);
    scope(exit) { std.file.remove(file); }
    writef(f, "Hello, %s world number %s!", "nice", 42);
    fclose(f) == 0 || assert(false);
    assert(cast(char[]) std.file.read(file) ==  "Hello, nice world number 42!");
    // test write on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout = fopen(file, "w");
    assert(stdout);
    writef("Hello, %s world number %s!", "nice", 42);
    fclose(stdout) == 0 || assert(false);
    assert(cast(char[]) std.file.read(file) == "Hello, nice world number 42!");
}

/***********************************
 * Equivalent to $(D_PARAM writef(args, '\n')).
 */
void writefln(T...)(T args)
{
    writef(args, '\n');
}

unittest
{
    // test writefln
    string file = "dmd-build-test.deleteme.txt";
    FILE* f = fopen(file, "w");
    assert(f);
    scope(exit) { std.file.remove(file); }
    writefln(f, "Hello, %s world number %s!", "nice", 42);
    fclose(f) == 0 || assert(false);
  version (Windows)
    assert(cast(char[]) std.file.read(file) == "Hello, nice world number 42!\r\n");
  else
    assert(cast(char[]) std.file.read(file) == "Hello, nice world number 42!\n");
    // test write on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout = fopen(file, "w");
    assert(stdout);
    writefln("Hello, %s world number %s!", "nice", 42);
    foreach (F ; TypeTuple!(ifloat, idouble, ireal))
    {
        F a = 5i;
        F b = a % 2;
        writefln(b);
    }
    fclose(stdout) == 0 || assert(false);
    auto read = cast(char[]) std.file.read(file);
  version (Windows)
    assert(read == "Hello, nice world number 42!\r\n1\r\n1\r\n1\r\n", read);
  else
    assert(read == "Hello, nice world number 42!\n1\n1\n1\n", read);
}

/***********************************
 * Kept for backward compatibility. Use $(D_PARAM writef) instead.
 */
void fwritef(FILE* fp, ...)
{
    writefx(fp, _arguments, _argptr, 0);
}

/***********************************
 * Kept for backward compatibility. Use $(D_PARAM writefln) instead.
 */
void fwritefln(FILE* fp, ...)
{
    writefx(fp, _arguments, _argptr, 1);
}

/**********************************
 * Read line from stream $(D_PARAM fp).
 * Returns:
 *	$(D_PARAM null) for end of file,
 *	$(D_PARAM char[]) for line read from $(D_PARAM fp), including terminating character
 * Params:
 *	$(D_PARAM fp) = input stream
 *	$(D_PARAM terminator) = line terminator, '\n' by default
 * Throws:
 *	$(D_PARAM StdioException) on error
 * Example:
 *	Reads $(D_PARAM stdin) and writes it to $(D_PARAM stdout).
---
import std.stdio;

int main()
{
    char[] buf;
    while ((buf = readln()) != null)
	write(buf);
    return 0;
}
---
*/
string readln(FILE* fp = stdin, dchar terminator = '\n')
{
    char[] buf;
    readln(fp, buf, terminator);
    return assumeUnique(buf);
}

/**********************************
 * Read line from stream $(D_PARAM fp) and write it to $(D_PARAM
 * buf[]), including terminating character.
 *
 * This is often faster than $(D_PARAM readln(FILE*)) because the buffer
 * is reused each call. Note that reusing the buffer means that
 * the previous contents of it need to be copied if needed.
 * Params:
 *	$(D_PARAM fp) = input stream
 *	$(D_PARAM buf) = buffer used to store the resulting line data. buf
 *		is resized as necessary.
 * Returns:
 *	0 for end of file, otherwise
 *	number of characters read
 * Throws:
 *	$(D_PARAM StdioException) on error
 * Example:
 *	Reads $(D_PARAM stdin) and writes it to $(D_PARAM stdout).
---
import std.stdio;

int main()
{
    char[] buf;
    while (readln(stdin, buf))
	write(buf);
    return 0;
}
---
This method is more efficient than the one in the previous example
because $(D_PARAM readln(stdin, buf)) reuses (if possible) memory
allocated by $(D_PARAM buf), whereas $(D_PARAM buf = readln()) makes a
new memory allocation with every line.
*/
size_t readln(FILE* fp, inout char[] buf, dchar terminator = '\n')
{
    version (DIGITAL_MARS_STDIO)
    {
	FLOCK(fp);
	scope(exit) FUNLOCK(fp);

	if (__fhnd_info[fp._file] & FHND_WCHAR)
	{   /* Stream is in wide characters.
	     * Read them and convert to chars.
	     */
	    static assert(wchar_t.sizeof == 2);
	    buf.length = 0;
	    int c2;
	    for (int c = void; (c = FGETWC(fp)) != -1; )
	    {
		if ((c & ~0x7F) == 0)
		{   buf ~= c;
		    if (c == terminator)
			break;
		}
		else
		{
		    if (c >= 0xD800 && c <= 0xDBFF)
		    {
			if ((c2 = FGETWC(fp)) != -1 ||
			    c2 < 0xDC00 && c2 > 0xDFFF)
			{
			    StdioException("unpaired UTF-16 surrogate");
			}
			c = ((c - 0xD7C0) << 10) + (c2 - 0xDC00);
		    }
		    std.utf.encode(buf, c);
		}
	    }
	    if (ferror(fp))
		StdioException();
	    return buf.length;
	}

	auto sz = GC.sizeOf(buf.ptr);
	//auto sz = buf.length;
	buf = buf.ptr[0 .. sz];
	if (fp._flag & _IONBF)
	{
	    /* Use this for unbuffered I/O, when running
	     * across buffer boundaries, or for any but the common
	     * cases.
	     */
        L1:
	    char *p;

	    if (sz)
	    {
		p = buf.ptr;
	    }
	    else
	    {
		sz = 64;
		p = cast(char*) GC.malloc(sz, GC.BlkAttr.NO_SCAN);
		buf = p[0 .. sz];
	    }
	    size_t i = 0;
	    for (int c; (c = FGETC(fp)) != -1; )
	    {
		if ((p[i] = cast(char)c) != terminator)
		{
		    i++;
		    if (i < sz)
			continue;
		    buf = p[0 .. i];
		    buf ~= readln(fp);
		    return buf.length;
		}
		else
		{
		    buf = p[0 .. i + 1];
		    return i + 1;
		}
	    }
	    if (ferror(fp))
		StdioException();
	    buf = p[0 .. i];
	    return i;
	}
	else
	{
	    int u = fp._cnt;
	    char* p = fp._ptr;
	    int i;
	    if (fp._flag & _IOTRAN)
	    {   /* Translated mode ignores \r and treats ^Z as end-of-file
		 */
		char c;
		while (1)
		{
		    if (i == u)		// if end of buffer
			goto L1;	// give up
		    c = p[i];
		    i++;
		    if (c != '\r')
		    {
			if (c == terminator)
			    break;
			if (c != 0x1A)
			    continue;
			goto L1;
		    }
		    else
		    {   if (i != u && p[i] == terminator)
			    break;
			goto L1;
		    }
		}
		if (i > sz)
		{
		    buf = cast(char[])GC.malloc(i, GC.BlkAttr.NO_SCAN)[0 .. i];
		}
		if (i - 1)
		    memcpy(buf.ptr, p, i - 1);
		buf[i - 1] = terminator;
		buf = buf[0 .. i];
		if (terminator == '\n' && c == '\r')
		    i++;
	    }
	    else
	    {
		while (1)
		{
		    if (i == u)		// if end of buffer
			goto L1;	// give up
		    auto c = p[i];
		    i++;
		    if (c == terminator)
			break;
		}
		if (i > sz)
		{
		    buf = cast(char[])GC.malloc(i, GC.BlkAttr.NO_SCAN)[0 .. i];
		}
		memcpy(buf.ptr, p, i);
		buf = buf[0 .. i];
	    }
	    fp._cnt -= i;
	    fp._ptr += i;
	    return i;
	}
    }
    else version (GCC_IO)
    {
             if (fwide(fp, 0) > 0)
             {   /* Stream is in wide characters.
                  * Read them and convert to chars.
                  */
                 FLOCK(fp);
                 scope(exit) FUNLOCK(fp);
                 version (Windows)
                 {
                     buf.length = 0;
                     int c2;
                     for (int c = void; (c = FGETWC(fp)) != -1; )
                     {
                         if ((c & ~0x7F) == 0)
                         {   buf ~= c;
                             if (c == terminator)
                                 break;
                         }
                         else
                         {
                             if (c >= 0xD800 && c <= 0xDBFF)
                             {
                                 if ((c2 = FGETWC(fp)) != -1 ||
                                     c2 < 0xDC00 && c2 > 0xDFFF)
                                 {
                                     StdioException("unpaired UTF-16 surrogate");
                                 }
                                 c = ((c - 0xD7C0) << 10) + (c2 - 0xDC00);
                             }
                             std.utf.encode(buf, c);
                         }
                     }
                     if (ferror(fp))
                         StdioException();
                     return buf.length;
                 }
                 else version (Posix)
                      {
                          buf.length = 0;
                          for (int c; (c = FGETWC(fp)) != -1; )
                          {
                              if ((c & ~0x7F) == 0)
                                  buf ~= c;
                              else
                                  std.utf.encode(buf, cast(dchar)c);
                              if (c == terminator)
                                  break;
                          }
                          if (ferror(fp))
                              StdioException();
                          return buf.length;
                      }
                 else
                 {
                     static assert(0);
                 }
             }

             char *lineptr = null;
             size_t n = 0;
             auto s = getdelim(&lineptr, &n, terminator, fp);
             scope(exit) free(lineptr);
             if (s < 0)
             {
                 if (ferror(fp))
                     StdioException();
                 buf.length = 0;		// end of file
                 return 0;
             }
             buf = buf.ptr[0 .. GC.sizeOf(buf.ptr)];
             if (s <= buf.length)
             {
                 buf.length = s;
                 buf[] = lineptr[0 .. s];
             }
             else
             {
                 buf = lineptr[0 .. s].dup;
             }
             return s;
    }
    else version (GENERIC_IO)
    {
	FLOCK(fp);
	scope(exit) FUNLOCK(fp);
	if (fwide(fp, 0) > 0)
	{   /* Stream is in wide characters.
	     * Read them and convert to chars.
	     */
	    version (Windows)
	    {
		buf.length = 0;
		int c2;
		for (int c; (c = FGETWC(fp)) != -1; )
		{
		    if ((c & ~0x7F) == 0)
		    {   buf ~= c;
			if (c == terminator)
			    break;
		    }
		    else
		    {
			if (c >= 0xD800 && c <= 0xDBFF)
			{
			    if ((c2 = FGETWC(fp)) != -1 ||
				c2 < 0xDC00 && c2 > 0xDFFF)
			    {
				StdioException("unpaired UTF-16 surrogate");
			    }
			    c = ((c - 0xD7C0) << 10) + (c2 - 0xDC00);
			}
			std.utf.encode(buf, c);
		    }
		}
		if (ferror(fp))
		    StdioException();
		return buf.length;
	    }
	    else version (Posix)
	    {
		buf.length = 0;
		for (int c; (c = FGETWC(fp)) != -1; )
		{
		    if ((c & ~0x7F) == 0)
			buf ~= c;
		    else
			std.utf.encode(buf, cast(dchar)c);
		    if (c == terminator)
			break;
		}
		if (ferror(fp))
		    StdioException();
		return buf.length;
	    }
	    else
	    {
		static assert(0);
	    }
	}

	buf.length = 0;
	for (int c; (c = FGETC(fp)) != -1; )
	{
	    buf ~= c;
	    if (c == terminator)
		break;
	}
	if (ferror(fp))
	    StdioException();
	return buf.length;
    }
    else
    {
	static assert(0);
    }
}

/** ditto */
size_t readln(inout char[] buf, dchar terminator = '\n')
{
    return readln(stdin, buf, terminator);
}

/** ditto */
// TODO: optimize this
size_t readln(FILE* f, inout wchar[] buf, dchar terminator = '\n')
{
    string s = readln(f, terminator);
    if (!s.length) return 0;
    buf.length = 0;
    foreach (wchar c; s)
    {
        buf ~= c;
    }
    return buf.length;
}

/** ditto */
// TODO: fold this together with wchar
size_t readln(FILE* f, inout dchar[] buf, dchar terminator = '\n')
{
    string s = readln(f, terminator);
    if (!s.length) return 0;
    buf.length = 0;
    foreach (dchar c; s)
    {
        buf ~= c;
    }
    return buf.length;
}

/***********************************
 * Convenience function that forwards to $(D_PARAM std.c.stdio.fopen)
 * with appropriately-constructed C-style strings.
 */
FILE* fopen(in char[] name, in char[] mode = "r")
{
    const namez = toStringz(name), modez = toStringz(mode);
    auto result = std.c.stdio.fopen(namez, modez);
    version(linux)
    {
        if (!result && getErrno == EOVERFLOW)
        {
            // attempt fopen64, maybe the file was very large
            result = fopen64(namez, modez);
        }
    }
    return result;
}

version (Posix)
{
    extern(C) FILE* popen(const char*, const char*);

/***********************************
 * Convenience function that forwards to $(D_PARAM std.c.stdio.popen)
 * with appropriately-constructed C-style strings.
 */
    FILE* popen(in char[] name, in char[] mode = "r")
    {
        return popen(toStringz(name), toStringz(mode));
    }
}

/*
 * Convenience function that forwards to $(D_PARAM std.c.stdio.fwrite)
 * and throws an exception upon error
 */
private void binaryWrite(T)(FILE* f, T obj)
{
    invariant result = fwrite(obj.ptr, obj[0].sizeof, obj.length, f);
    if (result != obj.length) StdioException();
}

/*
 * Implements the static Writer interface for a FILE*. Instantiate it
 * with the character type, e.g. PrivateFileWriter!(char),
 * PrivateFileWriter!(wchar), or PrivateFileWriter!(dchar). Regardless of
 * instantiation, PrivateFileWriter supports all character widths; it only is
 * the most efficient at accepting the character type it was
 * instantiated with.
 *
 * */
private struct PrivateFileWriter(Char)
{
    alias Char NativeChar;
    FILE* backend;
    int orientation;

    void write(C)(in C[] s)
    {
        if (!orientation) orientation = fwide(backend, 0);
        if (orientation <= 0 && C.sizeof == 1)
        {
            // lucky case: narrow chars on narrow stream
            if (std.c.stdio.fwrite(s.ptr, C.sizeof, s.length, backend)
                != s.length)
            {
                StdioException();
            }
        }
        else
        {
            // put each character in turn
            foreach (C c; s)
            {
                putchar(c);
            }
        }
    }

    void putchar(C)(in C c)
    {
        if (!orientation) orientation = fwide(backend, 0);
        static if (c.sizeof == 1)
        {
            // simple char
            if (orientation <= 0) FPUTC(c, backend);
            else FPUTWC(c, backend);
        }
        else static if (c.sizeof == 2)
        {
            if (orientation <= 0)
            {
                if (c <= 0x7F)
                {
                    FPUTC(c, backend);
                }
                else
                {
                    char[4] buf;
                    auto b = std.utf.toUTF8(buf, c);
                    foreach (i ; 0 .. b.length)
                        FPUTC(b[i], backend);
                }
            }
            else
            {
                FPUTWC(c, backend);
            }
        }
        else // 32-bit characters
        {
            if (orientation <= 0)
            {
                if (c <= 0x7F)
                {
                    FPUTC(c, backend);
                }
                else
                {
                    char[4] buf;
                    auto b = std.utf.toUTF8(buf, c);
                    foreach (i ; 0 .. b.length)
                        FPUTC(b[i], backend);
                }
            }
            else
            {
                version (Windows)
                {
                    assert(isValidDchar(c));
                    if (c <= 0xFFFF)
                    {
                        FPUTWC(c, backend);
                    }
                    else
                    {
                        FPUTWC(cast(wchar) ((((c - 0x10000) >> 10) & 0x3FF)
                                            + 0xD800), backend);
                        FPUTWC(cast(wchar) (((c - 0x10000) & 0x3FF) + 0xDC00),
                               backend);
                    }
                }
                else version (Posix)
                {
                    FPUTWC(c, backend);
                }
                else
                {
                    static assert(0);
                }
            }
        }
    }
}

/**
 * Iterates through the lines of a file by using $(D_PARAM foreach).
 *
 * Example:
 *
---------
void main()
{
  foreach (string line; lines(stdin))
  {
    ... use line ...
  }
}
---------
 The line terminator ('\n' by default) is part of the string read (it
could be missing in the last line of the file). Several types are
supported for $(D_PARAM line), and the behavior of $(D_PARAM lines)
changes accordingly:

$(OL $(LI If $(D_PARAM line) has type $(D_PARAM string), $(D_PARAM
wstring), or $(D_PARAM dstring), a new string of the respective type
is allocated every read.) $(LI If $(D_PARAM line) has type $(D_PARAM
char[]), $(D_PARAM wchar[]), $(D_PARAM dchar[]), the line's content
will be reused (overwritten) across reads.) $(LI If $(D_PARAM line)
has type $(D_PARAM invariant(ubyte)[]), the behavior is similar to
case (1), except that no UTF checking is attempted upon input.) $(LI
If $(D_PARAM line) has type $(D_PARAM ubyte[]), the behavior is
similar to case (2), except that no UTF checking is attempted upon
input.))

In all cases, a two-symbols versions is also accepted, in which case
the first symbol (of integral type, e.g. $(D_PARAM ulong) or $(D_PARAM
uint)) tracks the zero-based number of the current line.

Example:
----
  foreach (ulong i, string line; lines(stdin))
  {
    ... use line ...
  }
----

 In case of an I/O error, an $(D_PARAM StdioException) is thrown.
 */

struct lines
{
    private FILE * f;
    private dchar terminator = '\n';
    private string fileName;

    static lines opCall(FILE* f, dchar terminator = '\n')
    {
        lines result;
        result.f = f;
        result.terminator = terminator;
        return result;
    }

    // Keep these commented lines for later, when Walter fixes the
    // exception model.

//     static lines opCall(string fName, dchar terminator = '\n')
//     {
//         auto f = enforce(fopen(fName),
//             new StdioException("Cannot open file `"~fName~"' for reading"));
//         auto result = lines(f, terminator);
//         result.fileName = fName;
//         return result;
//     }

    int opApply(D)(D dg)
    {
//         scope(exit) {
//             if (fileName.length && fclose(f))
//                 StdioException("Could not close file `"~fileName~"'");
//         }
        alias ParameterTypeTuple!(dg) Parms;
        static if (isSomeString!(Parms[$ - 1]))
        {
            enum bool duplicate = is(Parms[$ - 1] == string)
                || is(Parms[$ - 1] == wstring) || is(Parms[$ - 1] == dstring);
            int result = 0;
            static if (is(Parms[$ - 1] : const(char)[]))
                alias char C;
            else static if (is(Parms[$ - 1] : const(wchar)[]))
                alias wchar C;
            else static if (is(Parms[$ - 1] : const(dchar)[]))
                alias dchar C;
            C[] line;
            static if (Parms.length == 2)
                Parms[0] i = 0;
            for (;;)
            {
                if (!readln(f, line, terminator)) break;
                auto copy = to!(Parms[$ - 1])(line);
                static if (Parms.length == 2)
                {
                    result = dg(i, copy);
                    ++i;
                }
                else
                {
                    result = dg(copy);
                }
                if (result != 0) break;
            }
            return result;
        }
        else
        {
            // raw read
            return opApplyRaw(dg);
        }
    }
    // no UTF checking
    int opApplyRaw(D)(D dg)
    {
        alias ParameterTypeTuple!(dg) Parms;
        enum duplicate = is(Parms[$ - 1] : invariant(ubyte)[]);
        int result = 1;
        int c = void;
        FLOCK(f);
	scope(exit) FUNLOCK(f);
        ubyte[] buffer;
        static if (Parms.length == 2)
            Parms[0] line = 0;
        while ((c = FGETC(f)) != -1)
        {
            buffer ~= to!(ubyte)(c);
            if (c == terminator)
            {
                static if (duplicate)
                    auto arg = assumeUnique(buffer);
                else
                    alias buffer arg;
                // unlock the file while calling the delegate
                FUNLOCK(f);
                scope(exit) FLOCK(f);
                static if (Parms.length == 1)
                {
                    result = dg(arg);
                }
                else
                {
                    result = dg(line, arg);
                    ++line;
                }
                if (result) break;
                static if (!duplicate)
                    buffer.length = 0;
            }
        }
        // can only reach when FGETC returned -1
        if (!feof(f)) throw new StdioException(ferror(f)); // error occured
        return result;
    }
}

unittest
{
    string file = "dmd-build-test.deleteme.txt";
    scope(exit) { std.file.remove(file); }
    alias TypeTuple!(string, wstring, dstring,
                     char[], wchar[], dchar[])
        TestedWith;
    foreach (T; TestedWith) {
        // test looping with an empty file
        std.file.write(file, "");
        auto f = fopen(file, "r");
        foreach (T line; lines(f))
        {
            assert(false);
        }
        fclose(f) == 0 || assert(false);

        // test looping with a file with three lines
        std.file.write(file, "Line one\nline two\nline three\n");
        f = fopen(file, "r");
        uint i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(line == "Line one\n");
            else if (i == 1) assert(line == "line two\n");
            else if (i == 2) assert(line == "line three\n");
            else assert(false);
            ++i;
        }
        fclose(f) == 0 || assert(false);

        // test looping with a file with three lines, last without a newline
        std.file.write(file, "Line one\nline two\nline three");
        f = fopen(file, "r");
        i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(line == "Line one\n");
            else if (i == 1) assert(line == "line two\n");
            else if (i == 2) assert(line == "line three");
            else assert(false);
            ++i;
        }
        fclose(f) == 0 || assert(false);
    }

    // test with ubyte[] inputs
    alias TypeTuple!(invariant(ubyte)[], ubyte[])
        TestedWith2;
    foreach (T; TestedWith2) {
        // test looping with an empty file
        std.file.write(file, "");
        auto f = fopen(file, "r");
        foreach (T line; lines(f))
        {
            assert(false);
        }
        fclose(f) == 0 || assert(false);

        // test looping with a file with three lines
        std.file.write(file, "Line one\nline two\nline three\n");
        f = fopen(file, "r");
        uint i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n",
                T.stringof ~ " " ~ cast(char[]) line);
            else if (i == 2) assert(cast(char[]) line == "line three\n");
            else assert(false);
            ++i;
        }
        fclose(f) == 0 || assert(false);

        // test looping with a file with three lines, last without a newline
        std.file.write(file, "Line one\nline two\nline three");
        f = fopen(file, "r");
        i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n");
            else if (i == 2) assert(cast(char[]) line == "line three");
            else assert(false);
            ++i;
        }
        fclose(f) == 0 || assert(false);

    }

    foreach (T; TypeTuple!(ubyte[]))
    {
        // test looping with a file with three lines, last without a newline
        // using a counter too this time
        std.file.write(file, "Line one\nline two\nline three");
        auto f = fopen(file, "r");
        uint i = 0;
        foreach (ulong j, T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n");
            else if (i == 2) assert(cast(char[]) line == "line three");
            else assert(false);
            ++i;
        }
        fclose(f) == 0 || assert(false);
    }
}

/**
Iterates through a file a chunk at a time by using $(D_PARAM
foreach).

Example:

---------
void main()
{
  foreach (ubyte[] buffer; chunks(stdin, 4096))
  {
    ... use buffer ...
  }
}
---------

The content of $(D_PARAM buffer) is reused across calls. In the
 example above, $(D_PARAM buffer.length) is 4096 for all iterations,
 except for the last one, in which case $(D_PARAM buffer.length) may
 be less than 4096 (but always greater than zero).

 In case of an I/O error, an $(D_PARAM StdioException) is thrown.
*/

struct chunks
{
    private FILE* f;
    private size_t size;
    private string fileName;

    static chunks opCall(FILE* f, size_t size)
    {
        assert(f && size);
        chunks result;
        result.f = f;
        result.size = size;
        return result;
    }

//     static chunks opCall(string fName, size_t size)
//     {
//         auto f = enforce(fopen(fName),
//             new StdioException("Cannot open file `"~fName~"' for reading"));
//         auto result = chunks(f, size);
//         result.fileName  = fName;
//         return result;
//     }

    int opApply(D)(D dg)
    {
        const maxStackSize = 1024 * 16;
        ubyte[] buffer = void;
        if (size < maxStackSize)
            buffer = (cast(ubyte*) alloca(size))[0 .. size];
        else
            buffer = new ubyte[size];
        size_t r = void;
        int result = 1;
        uint tally = 0;
        while ((r = std.c.stdio.fread(buffer.ptr,
                                      buffer[0].sizeof, size, f)) > 0)
        {
            assert(r <= size);
            if (r != size)
            {
                // error occured
                if (!feof(f)) throw new StdioException(ferror(f));
                buffer.length = r;
            }
            static if (is(typeof(dg(tally, buffer)))) {
                if ((result = dg(tally, buffer)) != 0) break;
            } else {
                if ((result = dg(buffer)) != 0) break;
            }
            ++tally;
        }
        return result;
    }
}

unittest
{
    string file = "dmd-build-test.deleteme.txt";
    scope(exit) { std.file.remove(file); }
    // test looping with an empty file
    std.file.write(file, "");
    auto f = fopen(file, "r");
    foreach (ubyte[] line; chunks(f, 4))
    {
        assert(false);
    }
    fclose(f) == 0 || assert(false);

    // test looping with a file with three lines
    std.file.write(file, "Line one\nline two\nline three\n");
    f = fopen(file, "r");
    uint i = 0;
    foreach (ubyte[] line; chunks(f, 3))
    {
        if (i == 0) assert(cast(char[]) line == "Lin");
        else if (i == 1) assert(cast(char[]) line == "e o");
        else if (i == 2) assert(cast(char[]) line == "ne\n");
        else break;
        ++i;
    }
    fclose(f) == 0 || assert(false);
}
