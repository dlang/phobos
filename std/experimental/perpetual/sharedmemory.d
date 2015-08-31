module std.sharedMemory;
import std.stdio;
private import std.exception;
private import std.string;
private import core.stdc.stdio;

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
    static assert(0, "Unsupported OS");
}



class SharedMemory
{
	private void _data[];
	private string _path;     // nbame of the shared file
	private bool _owner;      // true iff the file was created
	private bool _writeable;  // false iff the memory is read-only
	private size_t _size;     // size of shared memory
	private size_t _unplowed; // index of added memory,
	                          //  0 if the entire file was created
							  //  _size if the file exists and is longer than requested
							  
	version (Windows)
	{
	}
	else version (Posix)
	{
		private int _fd;
		private void* _map;
	}
	else
	{
		static assert(0);
	}



	@property bool creator() const { return _owner; }
	@property bool writeable() const { return _writeable; }
	@property auto freshIndex() const { return _unplowed; }
	@property size_t length() const { return _data.length; }
	@property const(void[]) data() const { return _data; }
	@property void[] data()
	{
		enforce(writeable, _path~": read-only file");
		return _data;
	}
	alias data this;
	

	
	this(string path, size_t size)
	{
		_path=path;
		map(path, size);
		_data=_map[0.._size];
	}
	
	
	
	this(string path)
	{
		_path=path;
		map(path, fileSize(path));
		_data=_map[0.._size];
	}
	
	
	
	~this()
	{
		unmap();
	}
	
	
	/**
	 * Flash memory to disc.
	 */
	void sync() {
		version (Windows) {

		} else version (Posix) {
			errnoEnforce(!msync(_map, _size, MS_SYNC), _path~": sync failed");

		} else {
			static assert(0);
		}
	}
	
	
	
	// Create shared memory of desired size
	private void map(string path, size_t size)
	{
		scope(failure) close(_fd);
		
		// Enforce atomic file creation
		// Only one of concurrent processec will succeed at this point
		if(fileCreate(path))
		{
			fileExpand(path, size);
			_owner=true;
			_writeable=true;
			_size=size;
			_unplowed=0;
			createMap(path);
		
		}
		// Try to open existing file in read/write mode
		else if(fileOpen(path))
		{
			_owner=false;
			_writeable=true;
			_unplowed=_size=size;
			if(fileSize(path) < size)
			{
				_unplowed=fileSize(path);
				fileExpand(path, size);
			}
			createMap(path);
		}
		// Try to open existing file in read-only mode
		else
		{
			errnoEnforce(fileOpenR(path), path);
			_owner=false;
			_writeable=false;
			_unplowed=_size=fileSize(path);
			createMapR(path);
		}
	}
	
	


	// Destroy shared memory, release resources
	private void unmap() {
		version (Windows) {

		} else version (Posix) {
			sync();
			munmap(_map, _size);
			close(_fd);

		} else {
			static assert(0);
		}
	}



	// Exclusively creates the file, fails if already exists
	private bool fileCreate(string path)
	{
		version (Windows) {

		} else version (Posix) {
			_fd=open(path.toStringz(), O_RDWR|O_CREAT|O_EXCL, S_IRUSR|S_IWUSR);
			return _fd >= 0;
			
		} else {
			static assert(0);
		}
	}


	
	// Open existing file in read/write mode, fails if not writable
	private bool fileOpen(string path)
	{
		version (Windows) {

		} else version (Posix) {
			_fd=open(path.toStringz(), O_RDWR);
			return _fd >= 0;
			
		} else {
			static assert(0);
		}
	}
	


	// Open existing file in read-only mode
	private bool fileOpenR(string path)
	{
		version (Windows) {

		} else version (Posix) {
			_fd=open(path.toStringz(), O_RDONLY);
			return _fd >= 0;

		} else {
			static assert(0);
		}
	}




	// Return current file size
	private size_t fileSize(string path) {
		version (Windows) {

		} else version (Posix) {
			stat_t st;
			errnoEnforce(!fstat(_fd, &st), path);
			return st.st_size;
	
		} else {
			static assert(0);
		}
	}



	// Expands current file to desired size
	private void fileExpand(string path, size_t size)
	{
		version (Windows) {

		} else version (Posix) {
			errnoEnforce(lseek(_fd, size-1, SEEK_SET) == (size-1), path);
			char c=0;
			errnoEnforce(core.sys.posix.unistd.write(_fd, &c, 1) == 1, path);

		} else {
			static assert(0);
		}
	}


	// CreAtes shared memory in read/write mode
	private void createMap(string path)
	{
		version (Windows) {

		} else version (Posix) {
			_map=mmap(null, _size, PROT_READ|PROT_WRITE, MAP_SHARED, _fd, 0);
			errnoEnforce(_map != MAP_FAILED, path);

		} else {
			static assert(0);
		}
	}


	
	// CreAtes shared memory in read-only mode
	private void createMapR(string path)
	{
		version (Windows) {

		} else version (Posix) {
			_map=mmap(null, _size, PROT_READ, MAP_SHARED, _fd, 0);
			errnoEnforce(_map != MAP_FAILED, path);

		}
		else
		{
			static assert(0);
		}
	}

}



auto sharedMemory(string path, size_t size)
{
	return new SharedMemory(path, size);
}


auto sharedMemory(string path)
{
	return new SharedMemory(path);
}


auto sharedConstMemory(string path)
{
	return new const(SharedMemory)(path);
}


package @property string deleteme() @safe
{
    import std.path : buildPath;
    import std.file : tempDir;
    import std.conv : to;
    import std.process : thisProcessID;
    static _deleteme = "deleteme.dmd.unittest.pid";
    static _first = true;

    if(_first)
    {
        _deleteme = buildPath(tempDir(), _deleteme) ~ to!string(thisProcessID);
        _first = false;
    }

    return _deleteme;
}


unittest
{
	//import std.file : deleteme;
	import std.conv : octal;
	auto file=deleteme;
	scope(exit) std.file.remove(file);
	
	{
		auto m=sharedMemory(file, 32);
		assert(m.length == 32);
		assert(m.creator);
		assert(m.writeable);
		assert(m.freshIndex == 0);
		
		int[] i=cast(int[]) m;
		assert(i.length == 8);
		i[]=17;
	}
	
	{
		auto m=sharedMemory(file, 40);
		assert(m.length == 40);
		assert(!m.creator);
		assert(m.writeable);
		assert(m.freshIndex == 32);
		
		auto i=cast(int[]) m;
		assert(i.length == 10);
		assert(i[0] == 17 && i[1] == 17);
	}

	{
		chmod(file.toStringz, octal!444);
		auto m=sharedConstMemory(file);
		assert(m.length == 40);
		assert(!m.creator);
		assert(!m.writeable);
		assert(m.freshIndex == 40);
		
		auto i=cast(int[]) m;
		i[0]=0;
		//auto i=cast(const(int)[]) m;
		assert(i.length == 10);
		assert(i[0] == 17 && i[1] == 17);
	}

}	


/* void main(string[] arg)
{
	auto m=new SharedMemory(arg[1], 32);
	writeln("size=", m.length, ", master=", m.creator, ", writeable=", m.writeable, ", plow at=", m.freshIndex);

	auto l=cast(const(int[])) m;
	writeln("int.size=", l.length);

	auto i=cast(int[]) m;
	writeln("int.size=", i.length);
	i[]=1;
}

 */
