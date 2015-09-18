module std.experimental.shmem;
private import std.exception;
private import std.string;
private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.stdio;
private import std.conv;



version (Windows)
{
private import core.sys.windows.windows;
private import std.utf;
private import std.windows.syserror;
}
else version (Posix)
{
private import core.sys.posix.fcntl;
private import core.sys.posix.unistd;
private import core.sys.posix.sys.mman;
private import core.sys.posix.sys.stat;
}
else
{
    static assert(0);
}



class ShMem
{
    enum Mode
    {
          readOnly		/// Read existing file
        , readWrite		/// Read/Write, create if not existing
        , noExpand		/// Read/Write existing file, do not increaze file size
    }





	this(string path, size_t len, Mode mode =Mode.readWrite)
	{
		fileOpen(path, mode);
		scope(failure) { close(_fd); _fd=-1; }

		auto size=fileSize(path);
		if(size < len)
		{
			enforce(writeable && mode != Mode.noExpand, path~": file is too short");
			_index=size;
			_master=true;
			size=fileExpand(path, len);
		}
		else
		{
			_index=len;
		}

		map(path, len);
	}


	this(string path, Mode mode =Mode.readWrite)
	{
		fileOpen(path, mode);
		scope(failure) { close(_fd); _fd=-1; }

		auto len=fileSize(path);
		enforce(len > 0, path~": zero size file");
		_index=len;
		_master=false;

		map(path, len);
	}


	~this()
	{
		if(_fd >= 0)
		{
			unmap();
			close(_fd);
			_fd=-1;
		}
	}


    void[] opSlice()
    {
        return _data[0..$];
    }

    void[] opSlice(size_t i, size_t k)
    {
        return _data[i..k];
    }

    void opSlice(size_t i)
    {
        return _data[i];
    }

    @property auto length() const { return _data.length; }

    @property bool writeable() const { return _writeable; }

    @property bool master() const { return _master; }

    @property auto unplowed() const { return _index; }

	






	private int _fd;
	private void[] _data;
	private bool _writeable;
	private bool _master;
	private size_t _index;
	

	private int fileOpen(string path, Mode mode)
	{
		version(Posix)
		{
			/// in read-only mode, the file must exist
			if(mode == Mode.readOnly)
			{
				_fd=core.sys.posix.fcntl.open(toStringz(path), O_RDONLY);
				errnoEnforce(_fd >= 0, path);
				_master=false;
				_writeable=false;
				return _fd;
			}
			else
			{
				/// try to create the file
				_fd=core.sys.posix.fcntl.open(toStringz(path), O_RDWR|O_CREAT|O_EXCL, S_IRUSR|S_IWUSR);
				if(_fd >= 0)
				{
					_master=true;
					_writeable=true;
					return _fd;
				}

				/// otherwise, try to open read/write existing file
				_fd=core.sys.posix.fcntl.open(toStringz(path), O_RDWR, S_IRUSR|S_IWUSR);
				if(_fd >= 0)
				{
					_master=false;
					_writeable=true;
					return _fd;
				}

				/// last chance, try to open as read-only
				_fd=core.sys.posix.fcntl.open(toStringz(path), O_RDONLY, S_IRUSR);
				if(_fd >= 0)
				{
					_master=false;
					_writeable=false;
					return _fd;
				}

				errnoEnforce(false, path);
			}
		}
		else version(Windows)
		{

		}

		errnoEnforce(_fd >= 0, path);
		return _fd;
	}


	
	private size_t fileSize(string path)
	{
		version(Posix)
		{
			stat_t st;
			errnoEnforce(!.stat(toStringz(path), &st), path);
			return st.st_size;
		}
		else version(Windows)
		{

		}
	}



	private size_t fileExpand(string path, size_t len)
	{
		version(Posix)
		{
			errnoEnforce(lseek(_fd, len-1, SEEK_SET) == (len-1), path);
			char c=0;
			errnoEnforce(core.sys.posix.unistd.write(_fd, &c, 1) == 1, path);

		}
		else version(Windows)
		{
		}
		
		return fileSize(path);
	}



	private void map(string path, size_t size)
	{
		version(Posix)
		{
			void* heap=MAP_FAILED;
			if(writeable)
				heap=mmap(null, size, PROT_READ|PROT_WRITE, MAP_SHARED, _fd, 0);
			else
				heap=mmap(null, size, PROT_READ, MAP_SHARED, _fd, 0);
			errnoEnforce(heap != MAP_FAILED, path~" : "~to!string(size));
			_data=heap[0..size];

		}
		else version(Windows)
		{

		}
	}



	private void unmap()
	{
		version(Posix)
		{
			munmap(_data.ptr, _data.length);
		}
		else version(Windows)
		{
			
		}
	}

}



ShMem shMem(string path, size_t len, ShMem.Mode mode=ShMem.Mode.readWrite)
{
	return new ShMem(path, len, mode);
}


ShMem shMem(string path, ShMem.Mode mode=ShMem.Mode.readWrite)
{
	return new ShMem(path, mode);
}






unittest
{
	import std.conv : octal;
	import std.file : remove;
	//import std.file : deleteme;
	string deleteme="test.";
	

	string file=deleteme~"1";
	scope(exit) remove(file);

	
	{
		auto s1=shMem(file, 8);
		enforce(s1.master);
		enforce(s1.writeable);
		enforce(s1.unplowed == 0);
		enforce(s1.length == 8);

		int[] i=cast(int[]) s1[];
		enforce(i.length == 2);
		i[0]=12;
		i[1]=13;
	}
	{
		auto s2=shMem(file, 12);
		enforce(s2.master);
		enforce(s2.writeable);
		enforce(s2.unplowed == 8);
		enforce(s2.length == 12);

		int[] i=cast(int[]) s2[];
		enforce(i.length == 3);
		enforce(i[0] == 12);
		enforce(i[1] == 13);
	}
	{
		auto s3=shMem(file, 4, ShMem.Mode.readOnly);
		enforce(!s3.master);
		enforce(!s3.writeable);
		enforce(s3.unplowed == 4);
		enforce(s3.length == 4);

		int[] i=cast(int[]) s3[];
		enforce(i.length == 1);
		enforce(i[0] == 12);
	}
	{
		auto s4=shMem(file);
		enforce(!s4.master);
		enforce(s4.writeable);
		enforce(s4.unplowed == 12);
		enforce(s4.length == 12);
	}
	{
		assertThrown(shMem(file, 24, ShMem.Mode.readOnly));
	}
	{
		chmod(toStringz(file), octal!444);
		assertThrown(shMem(file, 24));
	}


}

