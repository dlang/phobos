/*
 * Copyright (c) 2001, 2002
 * Pavel "EvilOne" Minayev
 *
 * Permission to use, copy, modify, distribute and sell this software
 * and its documentation for any purpose is hereby granted without fee,
 * provided that the above copyright notice appear in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation.  Author makes no representations about
 * the suitability of this software for any purpose. It is provided
 * "as is" without express or implied warranty.
 */

module stream;

// generic Stream error, base class for all
// other Stream exceptions
class StreamError: Error
{
	this(char[] msg) { super(msg); }
}

// thrown when unable to read data from Stream
class ReadError: StreamError
{
	this(char[] msg) { super(msg); }
}

// thrown when unable to write data to Stream
class WriteError: StreamError
{
	this(char[] msg) { super(msg); }
}

// thrown when unable to move Stream pointer
class SeekError: StreamError
{
	this(char[] msg) { super(msg); }
}

// seek whence...
enum SeekPos
{
	Set,
	Current,
	End
}

// base class for all streams; not really abstract,
// but its instances will do nothing useful
class Stream
{
	import string, crc32, c.stdlib, c.stdio;

	// for compatibility
	deprecated enum: SeekPos
	{
		set = SeekPos.Set,
		current = SeekPos.Current,
		end = SeekPos.End
	}
	
	// stream abilities
	bit readable = false;
	bit writeable = false;
	bit seekable = false;
	
	this() { }

  // close the stream somehow; the default
  // does nothing
  void close()
  {
  }

	// reads block of data of specified size,
	// returns actual number of bytes read
	abstract uint readBlock(void* buffer, uint size);

	// reads block of data of specified size,
	// throws ReadError on error
	void readExact(void* buffer, uint size)
	{
		if (readBlock(buffer, size) != size)
			throw new ReadError("not enough data in stream");
	}

	// reads block of data big enough to fill the given
	// array, returns actual number of bytes read
	uint read(ubyte[] buffer)
	{
		return readBlock(buffer, buffer.length);
	}

	// read a single value of desired type,
	// throw ReadError on error
	void read(out byte x) { readExact(&x, x.size); }
	void read(out ubyte x) { readExact(&x, x.size); }
	void read(out short x) { readExact(&x, x.size); }
	void read(out ushort x) { readExact(&x, x.size); }
	void read(out int x) { readExact(&x, x.size); }
	void read(out uint x) { readExact(&x, x.size); }
	void read(out long x) { readExact(&x, x.size); }
	void read(out ulong x) { readExact(&x, x.size); }
	void read(out float x) { readExact(&x, x.size); }
	void read(out double x) { readExact(&x, x.size); }
	void read(out real x) { readExact(&x, x.size); }
	void read(out ireal x) { readExact(&x, x.size); }
	void read(out creal x) { readExact(&x, x.size); }
	void read(out char x) { readExact(&x, x.size); }
	void read(out wchar x) { readExact(&x, x.size); }
	
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
		char[] result;
		try
		{
			char c = getc();
			while (readable)
			{
				switch (c)
				{
					case "\r":
					{
						c = getc();
						if (c != "\n")
							ungetc(c);
					}
					
					case "\n":
						return result;
					
					default:
						result ~= c;
				}
				c = getc();
			}
		}
		catch (ReadError e)
		{
			// either this is end of stream, which is okay,
			// or something bad occured while reading
			if (!eof())
				throw e;
		}
		return result;
	}
	
	// reads a Unicode line, terminated by either CR, LF, CR/LF,
	// or EOF; pretty much the same as the above, working with
	// wchars rather than chars
	wchar[] readLineW()
	{
		wchar[] result;
		try
		{
			wchar c = getcw();
			while (readable)
			{
				switch (c)
				{
					case "\r":
					{
						c = getcw();
						if (c != "\n")
							ungetcw(c);
					}
					
					case "\n":
						return result;
					
					default:
						result ~= c;
				}
				c = getcw();
			}
		}
		catch (ReadError e)
		{
			// either this is end of stream, which is okay,
			// or something bad occured while reading
			if (!eof())
				throw e;
		}
		return result;
	}

	// reads a string of given length, throws
	// ReadError on error
	char[] readString(uint length)
	{
		char[] result = new char[length];
		readExact(result, length);
		return result;
	}

	// reads a Unicode string of given length, throws
	// ReadError on error
	wchar[] readStringW(uint length)
	{
		wchar[] result = new wchar[length];
		readExact(result, result.length * wchar.size);
		return result;
	}
	
	// unget buffer
	private wchar[] unget;
	
	// reads and returns next character from the stream,
	// handles characters pushed back by ungetc()
	char getc()
	{
		char c;
		if (unget.length)
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
		if (unget.length)
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
		unget ~= c;
		return c;
	}
	
	// pushes back Unicode character c into the stream; only
	// has effect on further calls to getc() and getcw()
	wchar ungetcw(wchar c)
	{
		unget ~= c;
		return c;
	}
	
	int vscanf(char[] fmt, va_list args)
	{
		void** arg = cast(void**) args;
		int count = 0, i = 0;
		char c = getc();
		while (i < fmt.length)
		{
			if (fmt[i] == "%")	// a field
			{
				i++;
				bit suppress = false;
				if (fmt[i] == "*")	// suppress assignment
				{
					suppress = true;
					i++;
				}
				// read field width
				int width = 0;
				while (isdigit(fmt[i]))
				{
					width = width * 10 + (fmt[i] - "0");
					i++;
				}
				if (width == 0)
					width = -1;
				// D string?
				bit dstr = false;
				if (fmt[i] == ".")
				{
					i++;
					if (fmt[i] == "*")
					{
						dstr = true;
						i++;
					}
				}
				// read the modifier
				char modifier = fmt[i];
				if (modifier == "h" || modifier == "l" || modifier == "L")
					i++;
				else
					modifier = 0;
				// check the typechar and act accordingly
				switch (fmt[i])
				{
					case "d":	// decimal/hexadecimal/octal integer
					case "D":
					case "u":
					case "U":
					case "o":
					case "O":
					case "x":
					case "X":
					case "i":
					case "I":
					{
						while (iswhite(c))
						{
							c = getc();
							count++;
						}
						bit neg = false;
						if (c == "-")
						{
							neg = true;
							c = getc();
							count++;
						}
						else if (c == "+")
						{
							c = getc();
							count++;
						}
						char ifmt = fmt[i] | 0x20;
						if (ifmt == "i")	// undetermined base
						{
							if (c == "0")	// octal or hex
							{
								c = getc();
								count++;
								if (c == "x" || c == "X")	// hex
								{
									ifmt = "x";
									c = getc();
									count++;
								}
								else	// octal
									ifmt = "o";
							}
							else	// decimal
								ifmt = "d";
						}
						long n = 0;
						switch (ifmt)
						{
							case "d":	// decimal
							case "u":
							{
								while (isdigit(c) && width)
								{
									n = n * 10 + (c - "0");
									width--;
									c = getc();
									count++;
								}
							} break;
							
							case "o":	// octal
							{
								while (isoctdigit(c) && width)
								{
									n = n * 010 + (c - "0");
									width--;
									c = getc();
									count++;
								}
							} break;
							
							case "x":	// hexadecimal
							{
								while (ishexdigit(c) && width)
								{
									n *= 0x10;
									if (isdigit(c))
										n += c - "0";
									else
										n += 0xA + (c | 0x20) - "a";
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
							case "h":	// short
							{
								*cast(short*)*arg = n;
							} break;
							
							case "L":	// long
							{
								*cast(long*)*arg = n;
							} break;

							default:	// int
								*cast(int*)*arg = n;
						}
						i++;
					} break;
					
					case "f":	// float
					case "F":
					case "e":
					case "E":
					case "g":
					case "G":
					{
						while (iswhite(c))
						{
							c = getc();
							count++;
						}
						bit neg = false;
						if (c == "-")
						{
							neg = true;
							c = getc();
							count++;
						}
						else if (c == "+")
						{
							c = getc();
							count++;
						}
						real n = 0;
						while (isdigit(c) && width)
						{
							n = n * 10 + (c - "0");
							width--;
							c = getc();
							count++;
						}
						if (width && c == ".")
						{
							width--;
							c = getc();
							count++;
							double frac = 1;
							while (isdigit(c) && width)
							{
								n = n * 10 + (c - "0");
								frac *= 10;
								width--;
								c = getc();
								count++;
							}
							n /= frac;
						}
						if (width && (c == "e" || c == "E"))
						{
							width--;
							c = getc();
							count++;
							if (width)
							{
								bit expneg = false;
								if (c == "-")
								{
									expneg = true;
									width--;
									c = getc();
									count++;
								}
								else if (c == "+")
								{
									width--;
									c = getc();
									count++;
								}
								real exp = 0;
								while (isdigit(c) && width)
								{
									exp = exp * 10 + (c - "0");
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
							case "l":	// double
							{
								*cast(double*)*arg = n;
							} break;
							
							case "L":	// real
							{
								*cast(real*)*arg = n;
							} break;

							default:	// float
								*cast(float*)*arg = n;
						}
						i++;
					} break;
					
					case "s":	// ANSI string
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
					
					case "c":	// character(s)
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
					
					case "n":	// number of chars read so far
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
		return count;
	}
	
	int scanf(char[] format, ...)
	{
		va_list ap;
		ap = cast(va_list) &format;
		ap += format.size;
		return vscanf(format, ap);
	}

	// writes block of data of specified size,
	// returns actual number of bytes written
	abstract uint writeBlock(void* buffer, uint size);

	// writes block of data of specified size,
	// throws WriteError on error
	void writeExact(void* buffer, uint size)
	{
		if (writeBlock(buffer, size) != size)
			throw new WriteError("unable to write to stream");
	}

	// writes the given array of bytes, returns
	// actual number of bytes written
	uint write(ubyte[] buffer)
	{
		return writeBlock(buffer, buffer.length);
	}
	
	// write a single value of desired type,
	// throw WriteError on error
	void write(byte x) { writeExact(&x, x.size); }
	void write(ubyte x) { writeExact(&x, x.size); }
	void write(short x) { writeExact(&x, x.size); }
	void write(ushort x) { writeExact(&x, x.size); }
	void write(int x) { writeExact(&x, x.size); }
	void write(uint x) { writeExact(&x, x.size); }
	void write(long x) { writeExact(&x, x.size); }
	void write(ulong x) { writeExact(&x, x.size); }
	void write(float x) { writeExact(&x, x.size); }
	void write(double x) { writeExact(&x, x.size); }
	void write(real x) { writeExact(&x, x.size); }
	void write(ireal x) { writeExact(&x, x.size); }
	void write(creal x) { writeExact(&x, x.size); }
	void write(char x) { writeExact(&x, x.size); }
	void write(wchar x) { writeExact(&x, x.size); }
	
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

	// writes a line, throws WriteError on error
	void writeLine(char[] s)
	{
		writeString(s);
		version (Win32)
			writeString("\r\n");
/+			
		else version (Mac)
			writeString("\r");
+/			
		else	// probably *NIX
			writeString("\n");
	}

	// writes a UNICODE line, throws WriteError on error
	void writeLineW(wchar[] s)
	{
		writeStringW(s);
		version (Win32)
			writeStringW("\r\n");
/+			
		else version (Mac)
			writeStringW("\r");
+/			
		else	// probably *NIX
			writeStringW("\n");
	}

	// writes a string, throws WriteError on error
	void writeString(char[] s)
	{
		writeExact(s, s.length);
	}

	// writes a UNICODE string, throws WriteError on error
	void writeStringW(wchar[] s)
	{
		writeExact(s, s.length * wchar.size);
	}

	// writes data to stream using vprintf() syntax,
	// returns number of bytes written
	uint vprintf(char[] format, va_list args)
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
			}
			else
				throw new Error("unsupported platform");
			p = cast(char*) alloca(psize);
		}
		writeString(p[0 .. count]);
		return count;	
    }

	// writes data to stream using printf() syntax,
	// returns number of bytes written
	uint printf(char[] format, ...)
	{
		va_list ap;
		ap = cast(va_list) &format;
		ap += format.size;
		return vprintf(format, ap);
	}

	// copies all data from given stream into this one,
	// may throw ReadError or WriteError on failure
	void copyFrom(Stream s)
	{
		uint pos = position();
		s.position(0);
		copyFrom(s, s.size());
		s.position(pos);
	}
	
	// copies specified number of bytes from given stream into
	// this one, may throw ReadError or WriteError on failure
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

	// creates a string in memory containing copy of stream data	
	override char[] toString()
	{
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

// generic File error, base class for all
// other File exceptions
class StreamFileError: StreamError
{
	this(char[] msg) { super(msg); }
}

// thrown when unable to open file
class OpenError: StreamFileError
{
	this(char[] msg) { super(msg); }
}

// thrown when unable to create file
class CreateError: StreamFileError
{
	this(char[] msg) { super(msg); }
}

// access modes; may be or'ed
enum FileMode
{
	In = 1,
	Out = 2,
	// for compatibility with older versions
	input = In,
	output = Out
}

// just a file on disk
class File: Stream
{
	import windows;

	// for compatibility with old versions...
	deprecated enum: FileMode
	{
		toread = FileMode.In,
		towrite = FileMode.Out
	}

	private HANDLE hFile;

	this() { hFile = null; }
	
	// opens existing handle; use with care!
	this(HANDLE hFile, FileMode mode)
	{
		this.hFile = hFile;
		readable = cast(bit)(mode & FileMode.In);
		writeable = cast(bit)(mode & FileMode.Out);
	}
	
	// opens file for reading	
	this(char[] filename) { this(); open(filename); }
	
	// opens file in requested mode
	this(char[] filename, FileMode mode) { this(); open(filename, mode); }
	
	// destructor, closes file if still opened
	~this() { close(); }
	
	// opens file for reading	
	void open(char[] filename) { open(filename, FileMode.In); }
	
	// opens file in requested mode
	void open(char[] filename, FileMode mode)
	{
		close();
		int access = 0, share = 0;
		if (mode & FileMode.In)
		{
			readable = true;
			access |= GENERIC_READ;
			share |= FILE_SHARE_READ;
		}
		if (mode & FileMode.Out)
		{
			writeable = true;
			access |= GENERIC_WRITE;
		}
		seekable = true;
		hFile = CreateFileA(toStringz(filename), access, share,
			null, OPEN_EXISTING, 0, null);
		if (hFile == INVALID_HANDLE_VALUE)
			throw new OpenError("file '" ~ filename ~ "' not found");
	}

	// creates file for writing
	void create(char[] filename) { create(filename, FileMode.Out); }

	// creates file in requested mode
	void create(char[] filename, FileMode mode)
	{
		close();
		int access = 0, share = 0;
		if (mode & FileMode.In)
		{
			access |= GENERIC_READ;
			share |= FILE_SHARE_READ;
		}
		if (mode & FileMode.Out)
		{
			access |= GENERIC_WRITE;
		}
		hFile = CreateFileA(toStringz(filename), access, share,
			null, CREATE_ALWAYS, 0, null);
		seekable = true;
		readable = cast(bit)(mode & FileMode.In);
		writeable = cast(bit)(mode & FileMode.Out);
		if (hFile == INVALID_HANDLE_VALUE)
			throw new CreateError("unable to create file '" ~ filename ~ "'");
	}
	
	// closes file, if it is open; otherwise, does nothing
  override void close()
	{
		if (hFile)
		{
			CloseHandle(hFile);
			hFile = null;
			readable = writeable = seekable = false;
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
		ReadFile(hFile, buffer, size, &size, null);
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
		WriteFile(hFile, buffer, size, &size, null);
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
		uint result = SetFilePointer(hFile, offset, null, rel);
		if (result == 0xFFFFFFFF)
			throw new SeekError("unable to move file pointer");
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
	    assert(file.position() == 19 + 13 + 4);
	    // we must be at the end of file
	    assert(file.eof());
	    file.close();
	    // no operations are allowed when file is closed
	    assert(!file.readable && !file.writeable && !file.seekable);
	    file.open("stream.$$$");
	    // should be ok to read
	    assert(file.readable);
	    assert(!string.cmp(file.readLine(), "Testing stream.d:"));
	    // jump over "Hello, "
	    file.seek(7, SeekPos.Current);
	    assert(file.position() == 19 + 7);
	    assert(!string.cmp(file.readString(6), "world!"));
	    i = 0; file.read(i);
	    assert(i == 666);
        // string#1 + string#2 + int should give exacly that
	    assert(file.position() == 19 + 13 + 4);
	    // we must be at the end of file
	    assert(file.eof());
	    file.close();
	    remove("stream.$$$");
    }
}

// virtual stream residing in memory
class MemoryStream: Stream
{
    ubyte[] buf; // current data
    uint len; // current data length
    uint cur; // current file position

    // clear to an empty buffer.
	this() { this((ubyte[]) null); }

    // use this buffer, non-copying.
    this(ubyte[] buf)
    {
        super ();
        this.buf = buf;
        this.len = buf.length;
        readable = writeable = seekable = true;
    }

    // use this buffer, non-copying.
    this(byte[] buf) { this((ubyte[]) buf); }

    // use this buffer, non-copying.
    this(char[] buf) { this((ubyte[]) buf); }

    // ensure the stream can hold this many bytes.
    void reserve(uint count)
    {
        if (cur + count > buf.length)
            buf.length = (cur + count) * 2;
    }
	
	// returns pointer to stream data
	ubyte[] data() { return buf [0 .. len]; }
	
	override uint readBlock(void* buffer, uint size)
	// since in-blocks are not inherited, redefine them
	in
	{
		assert(readable);
	}
	body
	{
		ubyte* cbuf = cast(ubyte*) buffer;
		if (len - cur < size)
			size = len - cur;
		cbuf[0 .. size] = buf[cur .. cur + size];
		cur += size;
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
        ubyte* cbuf = cast(ubyte*) buffer;

        reserve (size);
        buf[cur .. cur + size] = cbuf[0 .. size];
        cur += size;
        if (cur > len)
            len = cur;
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
	
	override char[] toString()
	{
		return (char[]) data ();
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
        assert ((char[]) m.data () == "Hello, wield");
        m.seekEnd (0);
        m.writeString ("Foo");
        assert (m.position () == 15);
        m.writeString ("Foo foo foo foo foo foo foo");
        assert (m.position () == 42);
    }
}

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

        m = new MemoryStream ("Hello, world");
        s = new SliceStream (m, 4, 8);
        assert (s.size () == 4);
        assert (s.writeBlock ((char *) "Vroom", 5) == 4);
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
	return c == " " || c == "\t" || c == "\r" || c == "\n";
}

private bit isdigit(char c)
{
	return c >= "0" && c <= "9";
}

private bit isoctdigit(char c)
{
	return c >= "0" && c <= "7";
}

private bit ishexdigit(char c)
{
	return isdigit(c) || (c >= "A" && c <= "F") || (c >= "a" && c <= "f");
}

// API imports
private extern(Windows)
{
	private import windows;
	HANDLE GetStdHandle(DWORD);
}

// standard IO devices
File stdin, stdout, stderr;

static this()
{
	// open standard I/O devices
	stdin = new File(GetStdHandle(-10), FileMode.In);
	stdout = new File(GetStdHandle(-11), FileMode.Out);
	stderr = new File(GetStdHandle(-12), FileMode.Out);
}

import string;
import file;
