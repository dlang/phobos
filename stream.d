/*
 * Copyright (c) 2001
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

import windows;
import string;

// generic Stream error, base class for all
// other Stream exceptions
class StreamError: Exception
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

// base class for all streams; not really abstract,
// but its instances will do nothing
class Stream
{
	// seek from...
	enum { set, current, end }
	
	// stream abilities
	bit readable = false;
	bit writeable = false;
	bit seekable = false;
	
	this() { }

	// reads block of data of specified size,
	// returns actual number of bytes read
	uint readBlock(void* buffer, uint size)
	in
	{
		assert(readable);
	}
	body
	{
		return 0;
	}

	// reads block of data of specified size,
	// throws ReadError on error
	void readExact(void* buffer, uint size)
	{
		if (readBlock(buffer, size) != size)
			throw new ReadError("not enough data in stream");
	}

	// read a single value of desired type,
	// throw ReadError on error
	void read(out byte x) { readExact(&x, x.size); }
	void read(out ubyte x) { readExact(&x, x.size); }
	void read(out short x) { readExact(&x, x.size); }
	void read(out ushort x) { readExact(&x, x.size); }
	void read(out int x) { readExact(&x, x.size); }
	void read(out uint x) { readExact(&x, x.size); }
	void read(out char x) { readExact(&x, x.size); }
	void read(out wchar x) { readExact(&x, x.size); }

	// reads a line, terminated by either CR/LF, LF or EOF
	char[] readLine()
	{
		char[] result;
		char c;
		try
		{
			read(c);
			while (c != 10)
			{
				if (c != 13)
					result ~= c;
				read(c);
			}
		}
		finally
		{
			return result;
		}
	}

	// reads a string of given length, throws
	// ReadError on error
	char[] readString(uint length)
	{
		char[] result = new char[length];
		readExact(result, length);
		return result;
	}

	// writes block of data of specified size,
	// returns actual number of bytes written
	uint writeBlock(void* buffer, uint size)
	in
	{
		assert(writeable);
	}
	body
	{
		return 0;
	}

	// writes block of data of specified size,
	// throws WriteError on error
	void writeExact(void* buffer, uint size)
	{
		if (writeBlock(buffer, size) != size)
			throw new WriteError("unable to write to stream");
	}

	// write a single value of desired type,
	// throw WriteError on error
	void write(byte x) { writeExact(&x, x.size); }
	void write(ubyte x) { writeExact(&x, x.size); }
	void write(short x) { writeExact(&x, x.size); }
	void write(ushort x) { writeExact(&x, x.size); }
	void write(int x) { writeExact(&x, x.size); }
	void write(uint x) { writeExact(&x, x.size); }
	void write(char x) { writeExact(&x, x.size); }
	void write(wchar x) { writeExact(&x, x.size); }

	// writes a line, terminated by LF,

	// throws WriteError on error
	void writeLine(char[] s)
	{
		writeString(s);
		write(cast(char)"\n");
	}

	// writes a string, throws WriteError on error
	void writeString(char[] s)
	{
		writeExact(s, s.length);
	}

	// moves pointer to given position, relative to beginning of stream,
	// end of stream, or current position, returns new position
	uint seek(uint offset, int rel)
	in
	{
		assert(seekable);
	}
	body
	{
		return 0;
	}
	
	// sets position
	void position(uint pos) { seek(pos, set); }
	
	// returns current position
	uint position() { return seek(0, current); }

	// returns size of stream
	uint size()
	{
		uint pos = position(), result = seek(0, end);
		position(pos);
		return result;
	}

	// returns true if end of stream is reached, false otherwise
	bit eof() { return position() == size(); }
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

// just a file on disk
class File: Stream
{
	// access modes; may be or'ed
	enum { toread = 1, towrite = 2 }

	private HANDLE hFile;

	this() { hFile = (HANDLE)null; }
	
	// opens file for reading	
	this(char[] filename) { this(); open(filename); }
	
	// opens file in requested mode
	this(char[] filename, int mode) { this(); open(filename, mode); }
	
	// destructor, closes file if still opened
	~this() { close(); }
	
	// opens file for reading	
	void open(char[] filename) { open(filename, toread); }
	
	// opens file in requested mode
	void open(char[] filename, int mode)
	{
		close();
		int access = 0, share = 0;
		if (mode & toread)
		{
			readable = true;
			access |= GENERIC_READ;
			share |= FILE_SHARE_READ;
		}
		if (mode & towrite)
		{
			writeable = true;
			access |= GENERIC_WRITE;
		}
		seekable = true;
		hFile = CreateFileA(toStringz(filename), access, share, null,
			OPEN_EXISTING, 0, (HANDLE)null);
		if (hFile == INVALID_HANDLE_VALUE)
			throw new OpenError("file not found");
	}

	// creates file for writing
	void create(char[] filename) { create(filename, towrite); }

	// creates file in requested mode
	void create(char[] filename, int mode)
	{
		close();
		int access = 0, share = 0;
		if (mode & toread)
		{
			access |= GENERIC_READ;
			share |= FILE_SHARE_READ;
		}
		if (mode & towrite)
		{
			access |= GENERIC_WRITE;
		}
		hFile = CreateFileA(toStringz(filename), access, share, null,
			CREATE_ALWAYS, 0, (HANDLE)null);
		seekable = true;
		readable = mode & toread;
		writeable = mode & towrite;
		if (hFile == INVALID_HANDLE_VALUE)
			throw new CreateError("unable to create file");
	}
	
	// closes file, if it is open; otherwise, does nothing
	void close()
	{
		if (hFile)
		{
			CloseHandle(hFile);
			hFile = (HANDLE)null;
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
	
	override uint seek(uint offset, int rel)
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
	// to mess with WinAPI
	HANDLE handle() { return hFile; }
}

// virtual stream residing in memory
class MemoryStream: Stream
{
	import string;

	private char[] stream;
	private uint ptr = 0;
	
	this() { readable = writeable = seekable = true; }
	
	override uint readBlock(void* buffer, uint size)
	// since in-blocks are not inherited, redefine them
	in
	{
		assert(readable);
	}
	body
	{
		char* cbuf = cast(char*) buffer;
		if (stream.length - ptr < size)
			size = stream.length - ptr;
		cbuf[0 .. size] = stream[ptr .. ptr+size];
		ptr += size;
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
		char* cbuf = cast(char*) buffer;
		uint rewrite = stream.length - ptr;
		if (rewrite > size)
			rewrite = size;
		stream[ptr .. ptr+rewrite] = cbuf[0 .. rewrite];
		stream ~= cbuf[rewrite .. size];
		ptr += size;
		return size;
	}

	override uint seek(uint offset, int rel)
	// since in-blocks are not inherited, redefine them
	in
	{
		assert(seekable);
	}
	body
	{
		switch (rel)
		{
		case set:		ptr = offset; break;
		case current:	ptr += offset; break;
		case end:		ptr = stream.length - offset; break;
		}
		if (ptr < 0)
			ptr = 0;
		else if (ptr > stream.length)
			ptr = stream.length;
		return ptr;
	}
	
	// returns stream contents in form of string
	char[] toString()
	{
		return stream;
	}
}

// whatever...
alias MemoryStream StringStream;
