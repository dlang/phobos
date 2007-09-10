/*
	Copyright (C) 2004 Christopher E. Miller
	
	This software is provided 'as-is', without any express or implied
	warranty.  In no event will the authors be held liable for any damages
	arising from the use of this software.
	
	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:
	
	1. The origin of this software must not be misrepresented; you must not
	   claim that you wrote the original software. If you use this software
	   in a product, an acknowledgment in the product documentation would be
	   appreciated but is not required.
	2. Altered source versions must be plainly marked as such, and must not be
	   misrepresented as being the original software.
	3. This notice may not be removed or altered from any source distribution.
*/


module std.socketstream;

private import std.stream;
private import std.socket;


class SocketStream: Stream
{
	private:
	bit prevCr = false;
	bit atEof = false;
	Socket sock;
	
	
	public:
	this(Socket sock, FileMode mode)
	{
		if(mode & FileMode.In)
			readable = true;
		if(mode & FileMode.Out)
			writeable = true;
		
		this.sock = sock;
	}
	
	
	this(Socket sock)
	{
		writeable = readable = true;
		this.sock = sock;
	}
	
	
	Socket socket()
	{
		return sock;
	}
	
	
	override uint readBlock(void* _buffer, uint size)
	in
	{
		assert(readable);
	}
	body
	{
		ubyte* buffer = cast(ubyte*)_buffer;
		int len;
		uint need = size;
		
		for(;;)
		{
			if(!need)
				return size;
			
			len = sock.receive(buffer[0 .. need]);
			if(len <= 0)
			{
				if(!len)
					atEof = true;
				break;
			}
			
			buffer += len;
			need -= len;
		}
		return size - need;
	}
	
	
	override char getc()
	{
		char ch;
		
		if(prevCr)
		{
			prevCr = false;
			ch = super.getc();
			if(ch != '\n')
				return ch;
		}
		
		return super.getc();
	}
	
	
	override wchar getcw()
	{
		wchar ch;
		
		if(prevCr)
		{
			prevCr = false;
			ch = super.getcw();
			if(ch != '\n')
				return ch;
		}
		
		return super.getcw();
	}
	
	
	override char[] readLine()
	{
		char[] result;
		try
		{
			for(;;)
			{
				char ch = getc();
				switch(ch)
				{
					case '\r':
						prevCr = true;
					case '\n':
						return result;
					
					default:
						result ~= ch;
				}
			}
		}
		catch(ReadError re)
		{
			if(!eof())
				throw re;
		}
		return result;
	}
	
	
	override wchar[] readLineW()
	{
		wchar[] result;
		try
		{
			for(;;)
			{
				char ch = getcw();
				switch(ch)
				{
					case '\r':
						prevCr = true;
					case '\n':
						return result;
					
					default:
						result ~= ch;
				}
			}
		}
		catch(ReadError re)
		{
			if(!eof())
				throw re;
		}
		return result;
	}
	
	
	override uint writeBlock(void* _buffer, uint size)
	in
	{
		assert(writeable);
	}
	body
	{
		ubyte* buffer = cast(ubyte*)_buffer;
		int len;
		uint need = size;
		
		for(;;)
		{
			if(!need)
				return size;
			
			len = sock.send(buffer[0 .. need]);
			if(len <= 0)
				break;
			
			buffer += len;
			need -= len;
		}
		return size - need;
	}
	
	
	override ulong seek(long offset, SeekPos whence)
	{
		throw new SeekError("Cannot seek a socket.");
		return 0;
	}
	
	
	override char[] toString()
	{
		return sock.toString();
	}
	
	
	override bit eof()
	{
		return atEof;
	}
	
	
	override void close()
	{
		sock.close();
	}
}

