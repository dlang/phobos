/*
 * Copyright (c) 2001, 2002
 * Pavel "EvilOne" Minayev
 *  with buffering and endian support added by Ben Hinkle
 *
 * Permission to use, copy, modify, distribute and sell this software
 * and its documentation for any purpose is hereby granted without fee,
 * provided that the above copyright notice appear in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation.  Author makes no representations about
 * the suitability of this software for any purpose. It is provided
 * "as is" without express or implied warranty.
 */

module std.stream;

/* Class structure:
 *  InputStream       interface for reading
 *  OutputStream      interface for writing
 *  Stream            abstract base of stream implementations
 *    File            an OS file stream
 *    BufferedStream  a buffered stream wrapping another stream
 *      BufferedFile  a buffered File
 *    EndianStream    a wrapper stream for swapping byte order and BOMs
 *    MemoryStream    a stream entirely stored in main memory
 *    SliceStream     a portion of another stream
 *    TArrayStream    a stream wrapping an array-like buffer
 */

// generic Stream exception, base class for all
// other Stream exceptions
class StreamException: Exception
{
  this(char[] msg) { super(msg); }
}
alias StreamException StreamError; // for backwards compatibility

// thrown when unable to read data from Stream
class ReadException: StreamException
{
  this(char[] msg) { super(msg); }
}
alias ReadException ReadError; // for backwards compatibility

// thrown when unable to write data to Stream
class WriteException: StreamException
{
  this(char[] msg) { super(msg); }
}
alias WriteException WriteError; // for backwards compatibility

// thrown when unable to move Stream pointer
class SeekException: StreamException
{
  this(char[] msg) { super(msg); }
}
alias SeekException SeekError; // for backwards compatibility


// seek whence...
enum SeekPos
  {
    Set,
    Current,
    End
  }

import std.format;
alias std.format.va_list va_list;
private import std.c.stdio;
alias std.c.stdio.va_list c_va_list;

private 
{
  import std.system;    // for Endian enumeration
  import std.intrinsic; // for bswap
  import std.utf;
}

version (Windows)
{
    private import std.file;
}

// Interface for readable streams
interface InputStream
{
  // reads block of data of specified size,
  // throws ReadException on error
  void readExact(void* buffer, uint size);

  // reads block of data big enough to fill the given
  // array, returns actual number of bytes read
  uint read(ubyte[] buffer);

  // read a single value of desired type,
  // throw ReadException on error
  void read(out byte x); 
  void read(out ubyte x); 
  void read(out short x); 
  void read(out ushort x);
  void read(out int x); 
  void read(out uint x); 
  void read(out long x); 
  void read(out ulong x); 
  void read(out float x); 
  void read(out double x);
  void read(out real x); 
  void read(out ifloat x); 
  void read(out idouble x);
  void read(out ireal x);
  void read(out cfloat x); 
  void read(out cdouble x);
  void read(out creal x);
  void read(out char x); 
  void read(out wchar x); 
  void read(out dchar x); 
	
  // reads a string, written earlier by write()
  void read(out char[] s);
	
  // reads a Unicode string, written earlier by write()
  void read(out wchar[] s);
	
  // reads a line, terminated by either CR, LF, CR/LF, or EOF
  char[] readLine();

  // reads a line, terminated by either CR, LF, CR/LF, or EOF
  // reusing the memory in result and reallocating if needed
  char[] readLine(char[] result);
	
  // reads a Unicode line, terminated by either CR, LF, CR/LF,
  // or EOF; pretty much the same as the above, working with
  // wchars rather than chars
  wchar[] readLineW();

  // reads a Unicode line, terminated by either CR, LF, CR/LF,
  // or EOF; pretty much the same as the above, working with
  // wchars rather than chars
  wchar[] readLineW(wchar[] result);

  // reads a string of given length, throws
  // ReadException on error
  char[] readString(uint length);

  // reads a Unicode string of given length, throws
  // ReadException on error
  wchar[] readStringW(uint length);
	
  // reads and returns next character from the stream,
  // handles characters pushed back by ungetc()
  char getc();
	
  // reads and returns next Unicode character from the
  // stream, handles characters pushed back by ungetc()
  wchar getcw();
	
  // pushes back character c into the stream; only has
  // effect on further calls to getc() and getcw()
  char ungetc(char c);

  // pushes back Unicode character c into the stream; only
  // has effect on further calls to getc() and getcw()
  wchar ungetcw(wchar c);

  int vscanf(char[] fmt, c_va_list args);

  int scanf(char[] format, ...);

  uint available();
}

// Interface for writable streams
interface OutputStream 
{
  // writes block of data of specified size,
  // throws WriteException on error
  void writeExact(void* buffer, uint size);

  // writes the given array of bytes, returns
  // actual number of bytes written
  uint write(ubyte[] buffer);
	
  // write a single value of desired type,
  // throw WriteException on error
  void write(byte x); 
  void write(ubyte x);
  void write(short x);
  void write(ushort x); 
  void write(int x); 
  void write(uint x);
  void write(long x);
  void write(ulong x);
  void write(float x);
  void write(double x);
  void write(real x); 
  void write(ifloat x);
  void write(idouble x);
  void write(ireal x);
  void write(cfloat x);
  void write(cdouble x);
  void write(creal x);
  void write(char x); 
  void write(wchar x);
  void write(dchar x);
	
  // writes a string, together with its length
  void write(char[] s);
	
  // writes a Unicode string, together with its length
  void write(wchar[] s);

  // writes a line, throws WriteException on error
  void writeLine(char[] s);

  // writes a UNICODE line, throws WriteException on error
  void writeLineW(wchar[] s);

  // writes a string, throws WriteException on error
  void writeString(char[] s);

  // writes a UNICODE string, throws WriteException on error
  void writeStringW(wchar[] s);

  // writes data to stream using vprintf() syntax,
  // returns number of bytes written
  uint vprintf(char[] format, c_va_list args);

  // writes data to stream using printf() syntax,
  // returns number of bytes written
  uint printf(char[] format, ...);

  // writes data to stream using writef() syntax,
  void writef(...);

  // writes data with trailing newline
  void writefln(...);
}

// base class for all streams; not really abstract,
// but its instances will do nothing useful
class Stream : InputStream, OutputStream
{
  private import std.string, crc32, std.c.stdlib, std.c.stdio;

  // stream abilities
  bit readable = false;
  bit writeable = false;
  bit seekable = false;
  private bit isopen = true;

  this() {}

  // reads block of data of specified size,
  // returns actual number of bytes read
  abstract uint readBlock(void* buffer, uint size);

  // reads block of data of specified size,
  // throws ReadException on error
  void readExact(void* buffer, uint size)
  {
    uint readsize = readBlock(buffer, size);
    if (readsize != size)
      throw new ReadException("not enough data in stream");
  }

  // reads block of data big enough to fill the given
  // array, returns actual number of bytes read
  uint read(ubyte[] buffer)
  {
    return readBlock(buffer, buffer.length);
  }

  // read a single value of desired type,
  // throw ReadException on error
  void read(out byte x) { readExact(&x, x.sizeof); }
  void read(out ubyte x) { readExact(&x, x.sizeof); }
  void read(out short x) { readExact(&x, x.sizeof); }
  void read(out ushort x) { readExact(&x, x.sizeof); }
  void read(out int x) { readExact(&x, x.sizeof); }
  void read(out uint x) { readExact(&x, x.sizeof); }
  void read(out long x) { readExact(&x, x.sizeof); }
  void read(out ulong x) { readExact(&x, x.sizeof); }
  void read(out float x) { readExact(&x, x.sizeof); }
  void read(out double x) { readExact(&x, x.sizeof); }
  void read(out real x) { readExact(&x, x.sizeof); }
  void read(out ifloat x) { readExact(&x, x.sizeof); }
  void read(out idouble x) { readExact(&x, x.sizeof); }
  void read(out ireal x) { readExact(&x, x.sizeof); }
  void read(out cfloat x) { readExact(&x, x.sizeof); }
  void read(out cdouble x) { readExact(&x, x.sizeof); }
  void read(out creal x) { readExact(&x, x.sizeof); }
  void read(out char x) { readExact(&x, x.sizeof); }
  void read(out wchar x) { readExact(&x, x.sizeof); }
  void read(out dchar x) { readExact(&x, x.sizeof); }
	
  // reads a string, written earlier by write()
  void read(out char[] s)
  {
    int len;
    read(len);
    s = readString(len);
  }
	
  // reads a Unicode string, written earlier by write()
  void read(out wchar[] s)
  {
    int len;
    read(len);
    s = readStringW(len);
  }
	
  // reads a line, terminated by either CR, LF, CR/LF, or EOF
  char[] readLine()
  {
    return readLine(null);
  }

  // reads a line, terminated by either CR, LF, CR/LF, or EOF
  // reusing the memory in buffer if result will fit and otherwise
  // allocates a new string
  char[] readLine(char[] result)
  {
    uint strlen = 0;
    try
      {
	char ch = getc();
	while (readable) {
	  switch (ch)
	    {
	    case '\r':
	      {
		ch = getc();
		if (ch != '\n')
		  ungetc(ch);
	      }
		    
	    case '\n':
	      result.length = strlen;
	      return result;

	    default:
	      if (strlen < result.length) {
		result[strlen] = ch;
	      }
	      else {
		result ~= ch;
	      }
	      strlen++;
	    }
	  ch = getc();
	}
      }
    catch (ReadException e)
      {
	// either this is end of stream, which is okay,
	// or something bad occured while reading
	if (!eof())
	  throw e;
      }
    result.length = strlen;
    return result;
  }
	
  // reads a Unicode line, terminated by either CR, LF, CR/LF,
  // or EOF; pretty much the same as the above, working with
  // wchars rather than chars
  wchar[] readLineW()
  {
    return readLineW(null);
  }

  // reads a Unicode line, terminated by either CR, LF, CR/LF,
  // or EOF; 
  // fills supplied buffer if line fits and otherwise allocates a new string.
  wchar[] readLineW(wchar[] result)
  {
    uint strlen = 0;
    try
      {
	wchar c = getcw();
	while (readable) {
	  switch (c)
	    {
	    case '\r':
	      {
		c = getcw();
		if (c != '\n')
		  ungetcw(c);
	      }
	      
	    case '\n':
	      result.length = strlen;
	      return result;
	      
	    default:
	      if (strlen < result.length) {
		result[strlen] = c;
	      }
	      else {
		result ~= c;
	      }
	      strlen++;
	    }
	  c = getcw();
	}
      }
    catch (ReadException e)
      {
	// either this is end of stream, which is okay,
	// or something bad occured while reading
	if (!eof())
	  throw e;
      }
    result.length = strlen;
    return result;
  }

  // reads a string of given length, throws
  // ReadException on error
  char[] readString(uint length)
  {
    char[] result = new char[length];
    readExact(result, length);
    return result;
  }

  // reads a Unicode string of given length, throws
  // ReadException on error
  wchar[] readStringW(uint length)
  {
    wchar[] result = new wchar[length];
    readExact(result, result.length * wchar.sizeof);
    return result;
  }
	
  // unget buffer
  private wchar[] unget;
	
  // reads and returns next character from the stream,
  // handles characters pushed back by ungetc()
  char getc()
  {
    char c;
    if (unget.length > 1)
      {
	c = unget[unget.length - 1];
	unget.length = unget.length - 1;
      }
    else
      read(c);
    return c;
  }
	
  // reads and returns next Unicode character from the
  // stream, handles characters pushed back by ungetc()
  wchar getcw()
  {
    wchar c;
    if (unget.length > 1)
      {
	c = unget[unget.length - 1];
	unget.length = unget.length - 1;
      }
    else
      read(c);
    return c;
  }
	
  // pushes back character c into the stream; only has
  // effect on further calls to getc() and getcw()
  char ungetc(char c)
  {
    // first byte is a dummy so that we never set length to 0
    if (unget.length == 0)
      unget.length = 1;

    unget ~= c;
    return c;
  }
	
  // pushes back Unicode character c into the stream; only
  // has effect on further calls to getc() and getcw()
  wchar ungetcw(wchar c)
  {
    // first byte is a dummy so that we never set length to 0
    if (unget.length == 0)
      unget.length = 1;

    unget ~= c;
    return c;
  }
	
  int vscanf(char[] fmt, c_va_list args)
  {
    void** arg = cast(void**) args;
    int count = 0, i = 0;
    try
      {
	char c = getc();
	while (i < fmt.length)
	  {
	    if (fmt[i] == '%')	// a field
	      {
		i++;
		bit suppress = false;
		if (fmt[i] == '*')	// suppress assignment
		  {
		    suppress = true;
		    i++;
		  }
		// read field width
		int width = 0;
		while (isdigit(fmt[i]))
		  {
		    width = width * 10 + (fmt[i] - '0');
		    i++;
		  }
		if (width == 0)
		  width = -1;
		// D string?
		bit dstr = false;
		if (fmt[i] == '.')
		  {
		    i++;
		    if (fmt[i] == '*')
		      {
			dstr = true;
			i++;
		      }
		  }
		// read the modifier
		char modifier = fmt[i];
		if (modifier == 'h' || modifier == 'l' || modifier == 'L')
		  i++;
		else
		  modifier = 0;
		// check the typechar and act accordingly
		switch (fmt[i])
		  {
		  case 'd':	// decimal/hexadecimal/octal integer
		  case 'D':
		  case 'u':
		  case 'U':
		  case 'o':
		  case 'O':
		  case 'x':
		  case 'X':
		  case 'i':
		  case 'I':
		    {
		      while (iswhite(c))
			{
			  c = getc();
			  count++;
			}
		      bit neg = false;
		      if (c == '-')
			{
			  neg = true;
			  c = getc();
			  count++;
			}
		      else if (c == '+')
			{
			  c = getc();
			  count++;
			}
		      char ifmt = fmt[i] | 0x20;
		      if (ifmt == 'i')	// undetermined base
			{
			  if (c == '0')	// octal or hex
			    {
			      c = getc();
			      count++;
			      if (c == 'x' || c == 'X')	// hex
				{
				  ifmt = 'x';
				  c = getc();
				  count++;
				}
			      else	// octal
				ifmt = 'o';
			    }
			  else	// decimal
			    ifmt = 'd';
			}
		      long n = 0;
		      switch (ifmt)
			{
			case 'd':	// decimal
			case 'u':
			  {
			    while (isdigit(c) && width)
			      {
				n = n * 10 + (c - '0');
				width--;
				c = getc();
				count++;
			      }
			  } break;
							
			case 'o':	// octal
			  {
			    while (isoctdigit(c) && width)
			      {
				n = n * 010 + (c - '0');
				width--;
				c = getc();
				count++;
			      }
			  } break;
							
			case 'x':	// hexadecimal
			  {
			    while (ishexdigit(c) && width)
			      {
				n *= 0x10;
				if (isdigit(c))
				  n += c - '0';
				else
				  n += 0xA + (c | 0x20) - 'a';
				width--;
				c = getc();
				count++;
			      }
			  } break;
			}
		      if (neg)
			n = -n;
		      // check the modifier and cast the pointer
		      // to appropriate type
		      switch (modifier)
			{
			case 'h':	// short
			  {
			    *cast(short*)*arg = n;
			  } break;
							
			case 'L':	// long
			  {
			    *cast(long*)*arg = n;
			  } break;

			default:	// int
			  *cast(int*)*arg = n;
			}
		      i++;
		    } break;
					
		  case 'f':	// float
		  case 'F':
		  case 'e':
		  case 'E':
		  case 'g':
		  case 'G':
		    {
		      while (iswhite(c))
			{
			  c = getc();
			  count++;
			}
		      bit neg = false;
		      if (c == '-')
			{
			  neg = true;
			  c = getc();
			  count++;
			}
		      else if (c == '+')
			{
			  c = getc();
			  count++;
			}
		      real n = 0;
		      while (isdigit(c) && width)
			{
			  n = n * 10 + (c - '0');
			  width--;
			  c = getc();
			  count++;
			}
		      if (width && c == '.')
			{
			  width--;
			  c = getc();
			  count++;
			  double frac = 1;
			  while (isdigit(c) && width)
			    {
			      n = n * 10 + (c - '0');
			      frac *= 10;
			      width--;
			      c = getc();
			      count++;
			    }
			  n /= frac;
			}
		      if (width && (c == 'e' || c == 'E'))
			{
			  width--;
			  c = getc();
			  count++;
			  if (width)
			    {
			      bit expneg = false;
			      if (c == '-')
				{
				  expneg = true;
				  width--;
				  c = getc();
				  count++;
				}
			      else if (c == '+')
				{
				  width--;
				  c = getc();
				  count++;
				}
			      real exp = 0;
			      while (isdigit(c) && width)
				{
				  exp = exp * 10 + (c - '0');
				  width--;
				  c = getc();
				  count++;
				}
			      if (expneg)
				{
				  while (exp--)
				    n /= 10;
				}
			      else
				{
				  while (exp--)
				    n *= 10;
				}
			    }								
			}
		      if (neg)
			n = -n;
		      // check the modifier and cast the pointer
		      // to appropriate type
		      switch (modifier)
			{
			case 'l':	// double
			  {
			    *cast(double*)*arg = n;
			  } break;
							
			case 'L':	// real
			  {
			    *cast(real*)*arg = n;
			  } break;

			default:	// float
			  *cast(float*)*arg = n;
			}
		      i++;
		    } break;
					
		  case 's':	// ANSI string
		    {
		      while (iswhite(c))
			{
			  c = getc();
			  count++;
			}
		      char[] s;
		      while (!iswhite(c))
			{
			  s ~= c;
			  c = getc();
			  count++;
			}
		      if (dstr)	// D string (char[])
			*cast(char[]*)*arg = s;
		      else		// C string (char*)
			{
			  s ~= 0;
			  (cast(char*)*arg)[0 .. s.length] = s[];
			}
		      i++;
		    } break;
					
		  case 'c':	// character(s)
		    {
		      char* s = cast(char*)*arg;
		      if (width < 0)
			width = 1;
		      else
			while (iswhite(c))
			{
			  c = getc();
			  count++;
			}
		      while (width--)
			{
			  *(s++) = c;
			  c = getc();
			  count++;
			}
		      i++;
		    } break;
					
		  case 'n':	// number of chars read so far
		    {
		      *cast(int*)*arg = count;
		      i++;
		    } break;
					
		  default:	// read character as is
		    goto nws;
		  }
		arg++;
	      }
	    else if (iswhite(fmt[i]))	// skip whitespace
	      {
		while (iswhite(c))
		  c = getc();
		i++;
	      }
	    else	// read character as is
	      {
	      nws:			
		if (fmt[i] != c)
		  break;
		c = getc();
		i++;
	      }
	  }
	ungetc(c);
      }
    catch (ReadException e)
      {
	// either this is end of stream, which is okay,
	// or something bad occured while reading
	if (!eof())
	  throw e;
      }
    return count;
  }
	
  int scanf(char[] format, ...)
  {
    c_va_list ap;
    ap = cast(c_va_list) &format;
    ap += format.sizeof;
    return vscanf(format, ap);
  }

  // returns estimated number of bytes available for immediate reading
  uint available()
  {
    return 0;
  }

  // writes block of data of specified size,
  // returns actual number of bytes written
  abstract uint writeBlock(void* buffer, uint size);

  // writes block of data of specified size,
  // throws WriteException on error
  void writeExact(void* buffer, uint size)
  {
    if (writeBlock(buffer, size) != size)
      throw new WriteException("unable to write to stream");
  }

  // writes the given array of bytes, returns
  // actual number of bytes written
  uint write(ubyte[] buffer)
  {
    return writeBlock(buffer, buffer.length);
  }
	
  // write a single value of desired type,
  // throw WriteException on error
  void write(byte x) { writeExact(&x, x.sizeof); }
  void write(ubyte x) { writeExact(&x, x.sizeof); }
  void write(short x) { writeExact(&x, x.sizeof); }
  void write(ushort x) { writeExact(&x, x.sizeof); }
  void write(int x) { writeExact(&x, x.sizeof); }
  void write(uint x) { writeExact(&x, x.sizeof); }
  void write(long x) { writeExact(&x, x.sizeof); }
  void write(ulong x) { writeExact(&x, x.sizeof); }
  void write(float x) { writeExact(&x, x.sizeof); }
  void write(double x) { writeExact(&x, x.sizeof); }
  void write(real x) { writeExact(&x, x.sizeof); }
  void write(ifloat x) { writeExact(&x, x.sizeof); }
  void write(idouble x) { writeExact(&x, x.sizeof); }
  void write(ireal x) { writeExact(&x, x.sizeof); }
  void write(cfloat x) { writeExact(&x, x.sizeof); }
  void write(cdouble x) { writeExact(&x, x.sizeof); }
  void write(creal x) { writeExact(&x, x.sizeof); }
  void write(char x) { writeExact(&x, x.sizeof); }
  void write(wchar x) { writeExact(&x, x.sizeof); }
  void write(dchar x) { writeExact(&x, x.sizeof); }
	
  // writes a string, together with its length
  void write(char[] s)
  {
    write(s.length);
    writeString(s);
  }
	
  // writes a Unicode string, together with its length
  void write(wchar[] s)
  {
    write(s.length);
    writeStringW(s);
  }

  // writes a line, throws WriteException on error
  void writeLine(char[] s)
  {
    writeString(s);
    version (Win32)
      writeString("\r\n");
    else version (Mac)
      writeString("\r");
    else
      writeString("\n");
  }

  // writes a UNICODE line, throws WriteException on error
  void writeLineW(wchar[] s)
  {
    writeStringW(s);
    version (Win32)
      writeStringW("\r\n");
    else version (Mac)
      writeStringW("\r");
    else
      writeStringW("\n");
  }

  // writes a string, throws WriteException on error
  void writeString(char[] s)
  {
    writeExact(s, s.length);
  }

  // writes a UNICODE string, throws WriteException on error
  void writeStringW(wchar[] s)
  {
    writeExact(s, s.length * wchar.sizeof);
  }

  // writes data to stream using vprintf() syntax,
  // returns number of bytes written
  uint vprintf(char[] format, c_va_list args)
  {
    // shamelessly stolen from OutBuffer,
    // by Walter's permission
    char[1024] buffer;
    char* p = buffer;
    char* f = toStringz(format);
    uint psize = buffer.length;
    int count;
    while (true)
      {
	version (Win32)
	  {
	    count = _vsnprintf(p, psize, f, args);
	    if (count != -1)
	      break;
	    psize *= 2;
	    p = cast(char*) alloca(psize);
	  }
	else version (linux)
	  {
	    count = vsnprintf(p, psize, f, args);
	    if (count == -1)
	      psize *= 2;
	    else if (count >= psize)
	      psize = count + 1;
	    else
	      break;
	    p = cast(char*) alloca(psize);
	  }
	else
	  throw new Exception("unsupported platform");
      }
    writeString(p[0 .. count]);
    return count;	
  }

  // writes data to stream using printf() syntax,
  // returns number of bytes written
  uint printf(char[] format, ...)
  {
    c_va_list ap;
    ap = cast(c_va_list) &format;
    ap += format.sizeof;
    return vprintf(format, ap);
  }

  private void doFormatCallback(dchar c) 
  {
    char[4] buf;
    char[] b;
    b = std.utf.toUTF8(buf, c);
    writeString(b);
  }

  // writes data to stream using writef() syntax,
  void writef(...) 
  {
    doFormat(&doFormatCallback,_arguments,_argptr);
  }

  // writes data with trailing newline
  void writefln(...)
  {
    doFormat(&doFormatCallback,_arguments,_argptr);
    writeLine("");
  }

  // copies all data from given stream into this one,
  // may throw ReadException or WriteException on failure
  void copyFrom(Stream s)
  {
    uint pos = position();
    s.position(0);
    copyFrom(s, s.size());
    s.position(pos);
  }
	
  // copies specified number of bytes from given stream into
  // this one, may throw ReadException or WriteException on failure
  void copyFrom(Stream s, uint count)
  {
    ubyte[] buf;
    buf.length = s.size();
    s.readExact(buf, buf.length);
    writeExact(buf, buf.length);
  }
	
  // moves pointer to given position, relative to beginning of stream,
  // end of stream, or current position, returns new position
  abstract ulong seek(long offset, SeekPos whence);

  // seek from the beginning of the stream.
  ulong seekSet(long offset) { return seek (offset, SeekPos.Set); }

  // seek from the current point in the stream.
  ulong seekCur(long offset) { return seek (offset, SeekPos.Current); }

  // seek from the end of the stream.
  ulong seekEnd(long offset) { return seek (offset, SeekPos.End); }
	
  // sets position
  void position(ulong pos) { seek(pos, SeekPos.Set); }
	
  // returns current position
  ulong position() { return seek(0, SeekPos.Current); }

  // returns size of stream
  ulong size()
  {
    ulong pos = position(), result = seek(0, SeekPos.End);
    position(pos);
    return result;
  }

  // returns true if end of stream is reached, false otherwise
  bit eof() { return position() == size(); }

  // returns true if the stream is open
  bit isOpen() { return isopen; }

  // flush the buffer if writeable
  void flush() 
  { 
    if (unget.length > 1)
      unget.length = 1; // keep at least 1 so that data ptr stays
  }

  // close the stream somehow; the default just flushes the buffer
  void close()
  {
    if (isopen)
      flush();
    isopen = false;
  }

  // creates a string in memory containing copy of stream data	
  override char[] toString()
  {
    if (!isopen)
      return super.toString();
    uint pos = position();
    char[] result;
    result.length = size();
    position(0);
    readBlock(result, result.length);
    position(pos);
    return result;
  }
	
  // calculates CRC-32 of data in stream
  override uint toHash()
  {
    if (!isopen)
      return super.toHash();
    ulong pos = position();
    uint crc = init_crc32 ();
    position(0);
    for (long i = 0; i < size(); i++)
      {
	ubyte c;
	read(c);
	crc = update_crc32(c, crc);
      }
    position(pos);
    return crc;
  }

}

// A stream that wraps a source stream in a buffer
class BufferedStream : Stream 
{
  Stream s;             // source stream
  ubyte[] buffer;       // buffer, if any
  uint bufferCurPos;    // current position in buffer
  uint bufferLen;       // amount of data in buffer
  bit bufferDirty = false;
  uint bufferSourcePos; // position in buffer of source stream position
  ulong streamPos;      // absolute position in source stream 

  /* Example of relationship between fields:
   *
   *  s             ...01234567890123456789012EOF
   *  buffer                |--                     --|
   *  bufferCurPos                       |
   *  bufferLen             |--            --|
   *  bufferSourcePos                        |
   *
   */

  invariant
  {
    assert(bufferSourcePos <= bufferLen);
    assert(bufferCurPos <= bufferLen);
    assert(bufferLen <= buffer.length);
  }

  const uint DefaultBufferSize = 8192;

  this(Stream source, uint bufferSize = DefaultBufferSize) 
  {
    super();
    if (bufferSize)
      buffer = new ubyte[bufferSize];
    s = source;
    updateAttribs();
  }

  void updateAttribs()
  {
    if (s !== null) {
      readable = s.readable;
      writeable = s.writeable;
      seekable = s.seekable;
      isopen = s.isOpen();
    } else {
      readable = writeable = seekable = false;
      isopen = false;
    }
    streamPos = 0;
    bufferLen = bufferSourcePos = bufferCurPos = 0;
    bufferDirty = false;
  }

  // close source and stream
  override void close() 
  { 
    if (isopen) {
      super.close();
      s.close();
      updateAttribs();
    }
  }

  // reads block of data of specified size using any buffered data
  // returns actual number of bytes read
  override uint readBlock(void* result, uint size) 
  {
    ubyte* buf = cast(ubyte*)result;
    uint readsize = 0;
    
    if (bufferCurPos + size <= bufferLen) 
      { // buffer has all the data so copy it
	buf[0 .. size] = buffer[bufferCurPos .. bufferCurPos+size];
	bufferCurPos += size;
	readsize = size;
	goto ExitRead;
      } 

    readsize = bufferLen - bufferCurPos;
    if (readsize > 0) 
      { // buffer has some data so copy what is left
	buf[0 .. readsize] = buffer[bufferCurPos .. bufferLen];
	buf += readsize;
	bufferCurPos += readsize;
	size -= readsize;
      }

    flush();

    if (size >= buffer.length) 
      { // buffer can't hold the data so fill output buffer directly
	uint siz = s.readBlock(buf, size);
	readsize += siz;
	streamPos += siz;
      }
    else
      { // read a new block into buffer
	bufferLen = s.readBlock(buffer, buffer.length);
	if (bufferLen < size) size = bufferLen;
	buf[0 .. size] = buffer[0 .. size];
	bufferSourcePos = bufferLen;
	streamPos += bufferLen;
	bufferCurPos = size;
	readsize += size;
      }

  ExitRead:
    return readsize;
  }

  // write block of data of specified size
  // returns actual number of bytes written
  override uint writeBlock(void* result, uint size)
  {
    ubyte* buf = cast(ubyte*)result;
    uint writesize = 0;

    if (bufferLen == 0)
      { // buffer is empty so fill it if possible
	if ((size < buffer.length) && (readable))
	  { // read in data if the buffer is currently empty
	    bufferLen = s.readBlock(buffer,buffer.length);
	    bufferSourcePos = bufferLen;
	    streamPos += bufferLen;
	  }
	else if (size >= buffer.length)
	  { // buffer can't hold the data so write it directly and exit
	    writesize = s.writeBlock(buf,size);
	    streamPos += writesize;
	    goto ExitWrite;
	  }
      }

    if (bufferCurPos + size <= buffer.length) 
      { // buffer has space for all the data so copy it and exit
	buffer[bufferCurPos .. bufferCurPos+size] = buf[0 .. size];
	bufferCurPos += size;
	bufferLen = bufferCurPos > bufferLen ? bufferCurPos : bufferLen;
	writesize = size;
	bufferDirty = true;
	goto ExitWrite;
      } 

    writesize = buffer.length - bufferCurPos;
    if (writesize > 0) 
      { // buffer can take some data
	buffer[bufferCurPos .. buffer.length] = buf[0 .. writesize];
	bufferCurPos = bufferLen = buffer.length;
	buf += writesize;
	size -= writesize;
	bufferDirty = true;
      }

    assert(bufferCurPos == buffer.length);
    assert(bufferLen == buffer.length);

    flush();

    writesize += writeBlock(buf,size);

  ExitWrite:
    return writesize;
  }

  override ulong seek(long offset, SeekPos whence)
  in
  {
    assert(seekable);
    assert(s.seekable);
  }
  body
  {
    if ((whence != SeekPos.Current) ||
	(offset + bufferCurPos < 0) ||
	(offset + bufferCurPos >= bufferLen))
      {
	flush();
	streamPos = s.seek(offset,whence);
      }
    else
      {
	bufferCurPos += offset;
      }
    return streamPos-bufferSourcePos+bufferCurPos;
  }

  override void flush()
  out
  {
    assert(bufferCurPos == 0);
    assert(bufferSourcePos == 0);
    assert(bufferLen == 0);
  }
  body
  {
    super.flush();
    if (writeable && bufferDirty) 
      {
	if (bufferSourcePos != 0) 
	  {
	    // move actual file pointer to front of buffer
	    streamPos = s.seek(-bufferSourcePos, SeekPos.Current);
	  }
	// write buffer out
	bufferSourcePos = s.writeBlock(buffer,bufferLen);
	if (bufferSourcePos != bufferLen) 
	  {
	    throw new WriteException("Unable to write to stream");
	  }
      }
    long diff = bufferCurPos-bufferSourcePos;
    if (diff != 0) 
      {
	// move actual file pointer to current position
	streamPos = s.seek(diff, SeekPos.Current);
      }
    // reset buffer data to be empty
    bufferSourcePos = bufferCurPos = bufferLen = 0;
    bufferDirty = false;
  }

  // returns true if end of stream is reached, false otherwise
  override bit eof() 
  { 
    if ((buffer.length == 0) || !readable)
      {
	return super.eof();
      }
    if (bufferCurPos == bufferLen)
      {
	if ((bufferLen != buffer.length) &&
	    (bufferLen != 0))
	  {
	    return true;
	  }
      }
    else
      return false;
    uint res = s.readBlock(buffer,buffer.length);
    bufferSourcePos = bufferLen = res;
    streamPos += res;
    bufferCurPos = 0;
    return res == 0;
  }

  // returns size of stream
  ulong size()
  {
    flush();
    return s.size();
  }

  // returns estimated number of bytes available for immediate reading
  uint available()
  {
    return bufferLen - bufferCurPos;
  }

}

// generic File error, base class for all
// other File exceptions
class StreamFileException: StreamException
{
  this(char[] msg) { super(msg); }
}

// thrown when unable to open file
class OpenException: StreamFileException
{
  this(char[] msg) { super(msg); }
}

// access modes; may be or'ed
enum FileMode
  {
    In = 1,
    Out = 2,
    OutNew = 6, // includes FileMode.Out
    Append = 10 // includes FileMode.Out
  }

version (Win32)
{
  private import std.c.windows.windows;
  // BVH: should be part of windows.d
  extern (Windows) void FlushFileBuffers(HANDLE hFile);
}
version (linux)
{
  private import std.c.linux.linux;
  alias int HANDLE;
}

// just a file on disk without buffering
class File: Stream
{

  version (Win32)
  {
    private HANDLE hFile;
  }
  version (linux)
  {
    private HANDLE hFile = -1;
  }

  this()
  {
    super();
    version (Win32)
      {
	hFile = null;
      }
    version (linux)
      {
	hFile = -1;
      }
    isopen = false;
  }
	
  // opens existing handle; use with care!
  this(HANDLE hFile, FileMode mode)
  {
    super();
    this.hFile = hFile;
    readable = cast(bit)(mode & FileMode.In);
    writeable = cast(bit)(mode & FileMode.Out);
  }
	
  // opens file in requested mode
  this(char[] filename, FileMode mode = FileMode.In) { this(); open(filename, mode); }
	
	
  // opens file in requested mode
  void open(char[] filename, FileMode mode = FileMode.In)
  {
    close();
    int access, share, createMode;
    parseMode(mode, access, share, createMode);
    seekable = true;
    readable = cast(bit)(mode & FileMode.In);
    writeable = cast(bit)(mode & FileMode.Out);
    version (Win32)
      {
	if (std.file.useWfuncs)
	  {
	    hFile = CreateFileW(std.utf.toUTF16z(filename), access, share,
				null, createMode, 0, null);
	  }
	else
	  {
	    hFile = CreateFileA(std.file.toMBSz(filename), access, share,
				null, createMode, 0, null);
	  }
	isopen = hFile != INVALID_HANDLE_VALUE;
      }
    version (linux)
      {
	hFile = std.c.linux.linux.open(toStringz(filename), access | createMode, share);
	isopen = hFile != -1;
      }
    if (!isopen)
      throw new OpenException("file '" ~ filename ~ "' not found");
    else if ((mode & FileMode.Append) == FileMode.Append) 
      seekEnd(0);
  }

  private void parseMode(int mode, 
			 out int access, 
			 out int share,
			 out int createMode)
  {
    version (Win32)
      {
	if (mode & FileMode.In)
	  {
	    access |= GENERIC_READ;
	    share |= FILE_SHARE_READ;
	    createMode = OPEN_EXISTING;
	  }
	if (mode & FileMode.Out)
	  {
	    access |= GENERIC_WRITE;
	    createMode = OPEN_ALWAYS; // will create if not present
	  }
	if ((mode & FileMode.OutNew) == FileMode.OutNew)
	  {
	    createMode = CREATE_ALWAYS; // resets file
	  }
      }
    version (linux)
      {
	if (mode & FileMode.In)
	  {
	    access = O_RDONLY;
	    share = 0660;
	  }
	if (mode & FileMode.Out)
	  {
	    createMode = O_CREAT; // will create if not present
	    access = O_WRONLY;
	    share = 0660;
	  }
	if (access == (O_WRONLY | O_RDONLY))
	  {
	    access = O_RDWR;
	  }
	if ((mode & FileMode.OutNew) == FileMode.OutNew)
	  {
	    access |= O_TRUNC; // resets file
	  }
      }
  }

  // creates file for writing
  void create(char[] filename) 
  { 
    create(filename, FileMode.OutNew); 
  }

  // creates file in requested mode
  void create(char[] filename, FileMode mode)
  {
    close();
    open(filename, mode | FileMode.OutNew);
  }

  override void flush() 
  {
    super.flush();
    version (Win32)
      {
	FlushFileBuffers(hFile);
      }
  }

  // closes file, if it is open; otherwise, does nothing
  override void close()
  {
    if (isopen && hFile)
      {
	version (Win32)
	  {
	    CloseHandle(hFile);
	    hFile = null;
	  }
	version (linux)
	  {
	    std.c.linux.linux.close(hFile);
	    hFile = -1;
	  }
	readable = writeable = seekable = false;
	isopen = false;
      }
  }

  // destructor, closes file if still opened
  ~this() { close(); }

  version (Win32)
  {
    // returns size of stream
    ulong size()
      {
	uint sizehi;
	uint sizelow = GetFileSize(hFile,&sizehi);
	return (sizehi << 32)+sizelow;
      }
  }

  override uint readBlock(void* buffer, uint size)
  // since in-blocks are not inherited, redefine them
  in
  {
    assert(readable);
  }
  body
  {
    version (Win32)
      {
	ReadFile(hFile, buffer, size, &size, null);
      }
    version (linux)
      {
	size = std.c.linux.linux.read(hFile, buffer, size);
	if (size == -1)
	  size = 0;
      }
    return size;
  }

  override uint writeBlock(void* buffer, uint size)
    // since in-blocks are not inherited, redefine them
    in
  {
    assert(writeable);
  }
  body
  {
    version (Win32)
      {
	WriteFile(hFile, buffer, size, &size, null);
      }
    version (linux)
      {
	size = std.c.linux.linux.write(hFile, buffer, size);
      }
    return size;
  }
	
  override ulong seek(long offset, SeekPos rel)
    // since in-blocks are not inherited, redefine them
    in
  {
    assert(seekable);
  }
  body
  {
    version (Win32)
      {
	uint result = SetFilePointer(hFile, offset, null, rel);
	if (result == 0xFFFFFFFF)
	  throw new SeekException("unable to move file pointer");
      }
    version (linux)
      {
	ulong result = lseek(hFile, offset, rel);
	if (result == 0xFFFFFFFF)
	  throw new SeekException("unable to move file pointer");
      }
    return result;
  }

  // OS-specific property, just in case somebody wants
  // to mess with underlying API
  HANDLE handle() { return hFile; }

  // run a few tests
  unittest
  {
    File file = new File;
    int i = 666;
    file.create("stream.$$$");
    // should be ok to write
    assert(file.writeable);
    file.writeLine("Testing stream.d:");
    file.writeString("Hello, world!");
    file.write(i);
    // string#1 + string#2 + int should give exacly that
    version (Win32)
      assert(file.position() == 19 + 13 + 4);
    version (linux)
      assert(file.position() == 18 + 13 + 4);
    // we must be at the end of file
    assert(file.eof());
    file.close();
    // no operations are allowed when file is closed
    assert(!file.readable && !file.writeable && !file.seekable);
    file.open("stream.$$$");
    // should be ok to read
    assert(file.readable);
    char[] line = file.readLine();
    char[] exp = "Testing stream.d:";
    assert(line[0] == 'T');
    assert(line.length == exp.length);
    assert(!std.string.cmp(line, "Testing stream.d:"));
    // jump over "Hello, "
    file.seek(7, SeekPos.Current);
    version (Win32)
      assert(file.position() == 19 + 7);
    version (linux)
      assert(file.position() == 18 + 7);
    assert(!std.string.cmp(file.readString(6), "world!"));
    i = 0; file.read(i);
    assert(i == 666);
    // string#1 + string#2 + int should give exacly that
    version (Win32)
      assert(file.position() == 19 + 13 + 4);
    version (linux)
      assert(file.position() == 18 + 13 + 4);
    // we must be at the end of file
    assert(file.eof());
    file.close();
    remove("stream.$$$");
  }
}

// a buffered file on disk
class BufferedFile: BufferedStream
{

  // opens file for reading	
  this()
  {
    super(new File());
  }

  // opens file in requested mode and buffer size
  this(char[] filename, FileMode mode = FileMode.In, 
       uint bufferSize = DefaultBufferSize) 
  {
    super(new File(filename,mode),bufferSize);
  }

  // opens file for reading with requested buffer size
  this(File file, uint bufferSize = DefaultBufferSize) 
  {
    super(file,bufferSize);
  }

  // opens existing handle; use with care!
  this(HANDLE hFile, FileMode mode, uint buffersize)
  {
    super(new File(hFile,mode),buffersize);
  }

  // opens file in requested mode
  void open(char[] filename, FileMode mode = FileMode.In)
  in
  {
    assert(!(s is null));
  }
  body
  {
    File sf = cast(File)s;
    sf.open(filename,mode);
    updateAttribs();
  }

  // creates file in requested mode
  void create(char[] filename, FileMode mode = FileMode.Out)
  {
    File sf = cast(File)s;
    sf.create(filename,mode);
    updateAttribs();
  }

  // run a few tests same as File
  unittest
  {
    BufferedFile file = new BufferedFile;
    int i = 666;
    file.create("stream.$$$");
    // should be ok to write
    assert(file.writeable);
    file.writeLine("Testing stream.d:");
    file.writeString("Hello, world!");
    file.write(i);
    // string#1 + string#2 + int should give exacly that
    version (Win32)
      assert(file.position() == 19 + 13 + 4);
    version (linux)
      assert(file.position() == 18 + 13 + 4);
    // we must be at the end of file
    assert(file.eof());
    file.close();
    // no operations are allowed when file is closed
    assert(!file.readable && !file.writeable && !file.seekable);
    file.open("stream.$$$");
    // should be ok to read
    assert(file.readable);
    assert(!std.string.cmp(file.readLine(), "Testing stream.d:"));
    // jump over "Hello, "
    file.seek(7, SeekPos.Current);
    version (Win32)
      assert(file.position() == 19 + 7);
    version (linux)
      assert(file.position() == 18 + 7);
    assert(!std.string.cmp(file.readString(6), "world!"));
    i = 0; file.read(i);
    assert(i == 666);
    // string#1 + string#2 + int should give exacly that
    version (Win32)
      assert(file.position() == 19 + 13 + 4);
    version (linux)
      assert(file.position() == 18 + 13 + 4);
    // we must be at the end of file
    assert(file.eof());
    file.close();
    remove("stream.$$$");
  }

}

enum BOM { UTF8, UTF16LE, UTF16BE, UTF32LE, UTF32BE }

private const int NBOMS = 5;
Endian[NBOMS] BOMEndian = [std.system.endian, 
		       Endian.LittleEndian, Endian.BigEndian,
		       Endian.LittleEndian, Endian.BigEndian];

ubyte[][NBOMS] ByteOrderMarks;
ubyte[3] BOM_UTF8_data = [0xEF, 0xBB, 0xBF];
ubyte[2] BOM_UTF16LE_data = [0xFF, 0xFE];
ubyte[2] BOM_UTF16BE_data = [0xFE, 0xFF];
ubyte[4] BOM_UTF32LE_data = [0xFF, 0xFE, 0x00, 0x00];
ubyte[4] BOM_UTF32BE_data = [0x00, 0x00, 0xFE, 0xFF];

// A stream that wraps a source stream with endian support
class EndianStream : Stream 
{
  Stream s;             // source stream
  Endian endian;        // endianness of the source stream

  // Construct an Endian stream with specified endianness, defaulting
  // to the native endiannes.
  this(Stream source, Endian end = std.system.endian) 
  {
    super();
    s = source;
    endian = end;
    readable = s.readable;
    writeable = s.writeable;
    seekable = s.seekable;
    isopen = s.isOpen();
  }

  /* Return -1 if no BOM and otherwise read the BOM and return it.
   * If there is no BOM then the bytes read are pushed back onto
   * the ungetc buffer or ungetcw buffer. Pass ungetCharSize == 2
   * to use ungetcw instead of ungetc.
   */
  int readBOM(int ungetCharSize = 1)
  {
    ubyte[4] BOM_buffer;
    int n = 0;       // the number of read bytes
    int result = -1; // the last match or -1
    for (int i=0; i < NBOMS; ++i)
      {
	int j;
	ubyte[] bom = ByteOrderMarks[i];
	for (j=0; j < bom.length; ++j)
	  {
	    if (n <= j) // have to read more
	      {
		if (eof()) 
		  break;
		readExact(&BOM_buffer[n++],1);
	      }
	    if (BOM_buffer[j] != bom[j]) 
	      break;
	  }
	if (j == bom.length) // found a match
	  result = i;
      }
    int m = 0;
    if (result != -1)
    {
      endian = BOMEndian[result]; // set stream endianness
      m = ByteOrderMarks[result].length;
    }
    if ((ungetCharSize == 1 && result == -1) || (result == BOM.UTF8))
      {
	while (n-- > m)
	  ungetc(BOM_buffer[n]);
      }
    else  // should eventually support unget for dchar as well
      {
	if (n & 1) // make sure we have an even number of bytes
	  readExact(&BOM_buffer[n++],1);
	while (n > m)
	  {
	    n -= 2;
	    wchar cw = *(cast(wchar*)&BOM_buffer[n]);
	    fixBO(&cw,2);
	    ungetcw(cw);
	  }
      }
    return result;
  }

  // Correct the byte order of buffer to match native endianness.
  // size must be even
  final void fixBO(void* buffer, uint size)
  {
    if (endian != std.system.endian) 
      {
	ubyte* startb = cast(ubyte*)buffer;
	uint* start = cast(uint*)buffer;
	switch (size)
	  {
	  case 0: break;
	  case 2: 
	    {
	      ubyte x = *startb;
	      *startb = *(startb+1);
	      *(startb+1) = x;
	      break;
	    }
	  case 4:
	    {
	      *start = bswap(*start);
	      break;
	    }
	  default:
	    {
	      uint* end = cast(uint*)(buffer + size - uint.sizeof);
	      while (start < end)
		{
		  uint x = bswap(*start);
		  *start = bswap(*end);
		  *end = x;
		  ++start;
		  --end;
		}
	      startb = cast(ubyte*)start;
	      ubyte* endb = cast(ubyte*)end;
	      int len = uint.sizeof - (startb - endb);
	      if (len > 0)
		fixBO(startb,len);
	    }
	  }
      }
  }

  uint readBlock(void* buffer, uint size)
  {
    return s.readBlock(buffer,size);
  }

  void read(out short x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out ushort x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out int x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out uint x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out long x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out ulong x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out float x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out double x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out real x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out ifloat x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out idouble x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out ireal x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out cfloat x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out cdouble x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out creal x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out wchar x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }
  void read(out dchar x) { readExact(&x, x.sizeof); fixBO(&x,x.sizeof); }

  wchar[] readStringW(uint length)
  {
    wchar[] result = new wchar[length];
    readExact(result, result.length * wchar.sizeof);
    while (length--)
      fixBO(&result[length],2);
    return result;
  }
  
  // Write the specified BOM to the source stream
  void writeBOM(BOM b) 
  {
    ubyte[] bom = ByteOrderMarks[b];
    writeBlock(bom,bom.length);
  }

  uint writeBlock(void* buffer, uint size)
  {
    return s.writeBlock(buffer,size);
  }
  void write(short x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(ushort x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(int x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(uint x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(long x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(ulong x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(float x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(double x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(real x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(ifloat x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(idouble x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(ireal x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(cfloat x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(cdouble x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(creal x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(wchar x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }
  void write(dchar x) { fixBO(&x,x.sizeof); writeExact(&x, x.sizeof); }

  void writeStringW(wchar[] str)
  {
    foreach(wchar cw;str)
      {
	fixBO(&cw,2);
	s.writeExact(&cw, 2);
      }
  }

  // close stream
  override void close() 
  { 
    if (isopen) {
      s.close();
      isopen = false;
    }
  }

  override ulong seek(long offset, SeekPos whence)
  {
     return s.seek(offset,whence);
  }

  override void flush() { super.flush(); s.flush();  }
  override bit eof() { return s.eof();  }
  override ulong size() { return s.size();  }
  
  unittest {
    MemoryStream m;
    m = new MemoryStream ();
    EndianStream em = new EndianStream(m,Endian.BigEndian);
    uint x = 0x11223344;
    em.write(x);
    assert( m.data[0] == 0x11 );
    assert( m.data[1] == 0x22 );
    assert( m.data[2] == 0x33 );
    assert( m.data[3] == 0x44 );
    em.position(0);
    ushort x2 = 0x5566;
    em.write(x2);
    assert( m.data[0] == 0x55 );
    assert( m.data[1] == 0x66 );
    em.position(0);
    static ubyte[12] x3 = [1,2,3,4,5,6,7,8,9,10,11,12];
    em.fixBO(x3,12);
    if (std.system.endian == Endian.LittleEndian) {
      assert( x3[0] == 12 );
      assert( x3[1] == 11 );
      assert( x3[2] == 10 );
      assert( x3[4] == 8 );
      assert( x3[5] == 7 );
      assert( x3[6] == 6 );
      assert( x3[8] == 4 );
      assert( x3[9] == 3 );
      assert( x3[10] == 2 );
      assert( x3[11] == 1 );
    }
    em.endian = Endian.LittleEndian;
    em.write(x);
    assert( m.data[0] == 0x44 );
    assert( m.data[1] == 0x33 );
    assert( m.data[2] == 0x22 );
    assert( m.data[3] == 0x11 );
    em.position(0);
    em.write(x2);
    assert( m.data[0] == 0x66 );
    assert( m.data[1] == 0x55 );
    em.position(0);
    em.fixBO(x3,12);
    if (std.system.endian == Endian.BigEndian) {
      assert( x3[0] == 12 );
      assert( x3[1] == 11 );
      assert( x3[2] == 10 );
      assert( x3[4] == 8 );
      assert( x3[5] == 7 );
      assert( x3[6] == 6 );
      assert( x3[8] == 4 );
      assert( x3[9] == 3 );
      assert( x3[10] == 2 );
      assert( x3[11] == 1 );
    }
    em.writeBOM(BOM.UTF8);
    assert( m.position() == 3 );
    assert( m.data[0] == 0xEF );
    assert( m.data[1] == 0xBB );
    assert( m.data[2] == 0xBF );
    em.writeString ("Hello, world");
    em.position(0);
    assert( m.position() == 0 );
    assert( em.readBOM == BOM.UTF8 );
    assert( m.position() == 3 );
    assert( em.getc() == 'H' );
    em.position(0);
    em.writeBOM(BOM.UTF16BE);
    assert( m.data[0] == 0xFE );
    assert( m.data[1] == 0xFF );
    em.position(0);
    em.writeBOM(BOM.UTF16LE);
    assert( m.data[0] == 0xFF );
    assert( m.data[1] == 0xFE );
    em.position(0);
    em.writeString ("Hello, world");
    em.position(0);
    assert( em.readBOM == -1 );
    assert( em.getc() == 'H' );
    assert( em.getc() == 'e' );
    assert( em.getc() == 'l' );
    assert( em.getc() == 'l' );
    em.position(0);
  }
}

// Parameterized stream class that wraps an array-like type.
// The Buffer type must support .length, opIndex and opSlice
class TArrayStream(Buffer): Stream
{
  Buffer buf; // current data
  uint len; // current data length
  uint cur; // current file position

  // use this buffer, non-copying.
  this(Buffer buf)
  {
    super ();
    this.buf = buf;
    this.len = buf.length;
    readable = writeable = seekable = true;
  }
	
  override uint readBlock(void* buffer, uint size)
  {
    ubyte* cbuf = cast(ubyte*) buffer;
    if (len - cur < size)
      size = len - cur;
    ubyte[] ubuf = cast(ubyte[])buf[cur .. cur + size];
    cbuf[0 .. size] = ubuf[];
    cur += size;
    return size;
  }
	
  override uint writeBlock(void* buffer, uint size)
  {
    ubyte* cbuf = cast(ubyte*) buffer;
    ubyte[] ubuf = cast(ubyte[])buf[cur .. cur + size];
    ubuf[] = cbuf[0 .. size];
    cur += size;
    if (cur > len)
      len = cur;
    return size;
  }

  override ulong seek(long offset, SeekPos rel)
  {
    long scur; // signed to saturate to 0 properly

    switch (rel)
      {
      case SeekPos.Set: scur = offset; break;
      case SeekPos.Current: scur = cur + offset; break;
      case SeekPos.End: scur = len + offset; break;
      }

    if (scur < 0)
      cur = 0;
    else if (scur > len)
      cur = len;
    else
      cur = scur;

    return cur;
  }
}
/* Test the TArrayStream */
unittest
{
  char[100] buf;
  TArrayStream!(char[]) m;

  m = new TArrayStream!(char[]) (buf);
  m.writeString ("Hello, world");
  assert (m.position () == 12);
  assert (m.seekSet (0) == 0);
  assert (m.seekCur (4) == 4);
  assert (m.seekEnd (-8) == 92);
  assert (m.size () == 100);
  assert (m.seekSet (4) == 4);
  assert (m.readString (4) == "o, w");
  m.writeString ("ie");
  assert (buf[0..12] == "Hello, wield");
}

// virtual stream residing in memory
class MemoryStream: TArrayStream!(ubyte[])
{

  // clear to an empty buffer.
  this() { this(cast(ubyte[]) null); }

  // use this buffer, non-copying.
  this(ubyte[] buf)
  {
    super (buf);
  }

  // use this buffer, non-copying.
  this(byte[] buf) { this(cast(ubyte[]) buf); }

  // use this buffer, non-copying.
  this(char[] buf) { this(cast(ubyte[]) buf); }

  // ensure the stream can hold this many bytes.
  void reserve(uint count)
  {
    if (cur + count > buf.length)
      buf.length = (cur + count) * 2;
  }
	
  // returns pointer to stream data
  ubyte[] data() { return buf [0 .. len]; }
	
  override uint writeBlock(void* buffer, uint size)
  {
    reserve(size);
    return super.writeBlock(buffer,size);
  }
  override char[] toString()
  {
    return cast(char[]) data ();
  }

  /* Test the whole class. */
  unittest
  {
    MemoryStream m;

    m = new MemoryStream ();
    m.writeString ("Hello, world");
    assert (m.position () == 12);
    assert (m.seekSet (0) == 0);
    assert (m.seekCur (4) == 4);
    assert (m.seekEnd (-8) == 4);
    assert (m.size () == 12);
    assert (m.readString (4) == "o, w");
    m.writeString ("ie");
    assert (cast(char[]) m.data () == "Hello, wield");
    m.seekEnd (0);
    m.writeString ("Foo");
    assert (m.position () == 15);
    m.writeString ("Foo foo foo foo foo foo foo");
    assert (m.position () == 42);
    m.seekSet(0);
    m.writef("%d %d %s",100,345,"hello");
    char[] str = m.toString;
    assert (str[0..13] == "100 345 hello");
  }
}


/****************************
  BVH 8/04: 
  currently fails due to MmFile being auto, so leaving commented out
  until MmFile can be used in objects

import std.mmfile;
// stream wrapping memory-mapped files
alias TArrayStream!(MmFile) MmFileStream;

unittest
{
  MmFile mf = new MmFile("testing.txt");
  MmFileStream m;

  m = new MmFileStream (mf);
  m.writeString ("Hello, world");
  assert (m.position () == 12);
  assert (m.seekSet (0) == 0);
  assert (m.seekCur (4) == 4);
  assert (m.seekEnd (-8) == 4);
  assert (m.size () == 12);
  assert (m.readString (4) == "o, w");
  m.writeString ("ie");
  assert (cast(char[]) m.data () == "Hello, wield");
  m.seekEnd (0);
  m.writeString ("Foo");
  assert (m.position () == 15);
  m.writeString ("Foo foo foo foo foo foo foo");
  assert (m.position () == 42);
}
********************************/

// slices off a portion of another stream, making seeking
// relative to the boundaries of the slice.
class SliceStream : Stream
{
  Stream base; // stream to base this off of.
  ulong low; // low stream offset.
  ulong high; // high stream offset.
  bit bounded; // upper-bounded by high.
  bit nestClose; // if set, close base when closing this stream.

  // set the base stream and the low offset but leave the high unbounded.
  this (Stream base, ulong low)
  in
  {
    assert (base !== null);
    assert (low <= base.size ());
  }
  body
  {
    super ();
    this.base = base;
    this.low = low;
    this.high = 0;
    this.bounded = false;
    readable = base.readable;
    writeable = base.writeable;
    seekable = base.seekable;
  }

  // set the base stream, the low offset, and the high offset.
  this (Stream base, ulong low, ulong high)
  in
  {
    assert (base !== null);
    assert (low <= high);
    assert (high <= base.size ());
  }
  body
  {
    super ();
    this.base = base;
    this.low = low;
    this.high = high;
    this.bounded = true;
    readable = base.readable;
    writeable = base.writeable;
    seekable = base.seekable;
  }

  override void close ()
  {
    try
      {
	if (base !== null && nestClose)
	  base.close ();
      }
    finally
      base = null;
  }

  override uint readBlock (void *buffer, uint size)
  in
  {
    assert (readable);
  }
  body
  {
    if (bounded)
      {
	ulong pos = base.position ();

	if (pos > high)
	  return 0;
	if (size > high - pos)
	  size = high - pos;
      }

    return base.readBlock (buffer, size);
  }

  override uint writeBlock (void *buffer, uint size)
  in
  {
    assert (writeable);
  }
  body
  {
    if (bounded)
      {
	ulong pos = base.position ();

	if (pos > high)
	  return 0;
	if (size > high - pos)
	  size = high - pos;
      }

    return base.writeBlock (buffer, size);
  }

  override ulong seek(long offset, SeekPos rel)
  in
  {
    assert (seekable);
  }
  body
  {
    long output;

    switch (rel)
      {
      case SeekPos.Set:
	output = low + offset;
	break;

      case SeekPos.Current:
	output = base.position () + offset;
	break;

      case SeekPos.End:
	if (bounded)
	  output = high + offset;
	else
	  {
	    output = base.seek (offset, SeekPos.End);
	    assert (output >= low);
	    return output - low;
	  }
      }

    if (output < low)
      output = low;
    else if (bounded && output > high)
      output = high;

    output = base.seek (output, SeekPos.Set);
    assert (output >= low);
    return output - low;
  }

  /* Test the whole class. */
  unittest
  {
    MemoryStream m;
    SliceStream s;

    m = new MemoryStream ((cast(char[])"Hello, world").dup);
    s = new SliceStream (m, 4, 8);
    assert (s.size () == 4);
    assert (s.writeBlock (cast(char *) "Vroom", 5) == 4);
    assert (s.position () == 4);
    assert (s.seekEnd (-2) == 2);
    assert (s.seekEnd (2) == 4);
    s = new SliceStream (m, 4);
    assert (s.size () == 8);
    assert (s.toString () == "Vrooorld");
    s.seekEnd (0);
    s.writeString (", etcetera.");
    assert (s.position () == 19);
    assert (s.seekSet (0) == 0);
    assert (m.position () == 4);
  }
}

// helper functions
private bit iswhite(char c)
{
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

private bit isdigit(char c)
{
  return c >= '0' && c <= '9';
}

private bit isoctdigit(char c)
{
  return c >= '0' && c <= '7';
}

private bit ishexdigit(char c)
{
  return isdigit(c) || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

// standard IO devices
File stdin, stdout, stderr;

version (Win32)
{
  // API imports
  private extern(Windows)
    {
      private import std.c.windows.windows;
      HANDLE GetStdHandle(DWORD);
    }

  static this()
    {
      // init ByteOrderMarks
      ByteOrderMarks[BOM.UTF8] = BOM_UTF8_data;
      ByteOrderMarks[BOM.UTF16LE] = BOM_UTF16LE_data;
      ByteOrderMarks[BOM.UTF16BE] = BOM_UTF16BE_data;
      ByteOrderMarks[BOM.UTF32LE] = BOM_UTF32LE_data;
      ByteOrderMarks[BOM.UTF32BE] = BOM_UTF32BE_data;

      // open standard I/O devices
      stdin = new File(GetStdHandle(cast(uint)-10), FileMode.In);
      stdout = new File(GetStdHandle(cast(uint)-11), FileMode.Out);
      stderr = new File(GetStdHandle(cast(uint)-12), FileMode.Out);
    }
}

version (linux)
{
  static this()
    {
      // init ByteOrderMarks
      ByteOrderMarks[BOM.UTF8] = BOM_UTF8_data;
      ByteOrderMarks[BOM.UTF16LE] = BOM_UTF16LE_data;
      ByteOrderMarks[BOM.UTF16BE] = BOM_UTF16BE_data;
      ByteOrderMarks[BOM.UTF32LE] = BOM_UTF32LE_data;
      ByteOrderMarks[BOM.UTF32BE] = BOM_UTF32BE_data;

      // open standard I/O devices
      stdin = new File(0, FileMode.In);
      stdout = new File(1, FileMode.Out);
      stderr = new File(2, FileMode.Out);
    }
}

