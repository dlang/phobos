/**
 * Map variable, static array or POD structure to file
 *   to make it shared and persistent between program invocations.
 * Macros:
  * Source:    $(PHOBOSSRC std/persistent.d)
 */
module std.persistent;

private import std.file;
private import core.stdc.stdio;
private import core.stdc.stdlib;
private import core.stdc.errno;
private import std.path;
private import std.string;
import std.conv, std.exception, std.stdio;
version (Windows) {
	private import core.sys.windows.windows;
	private import std.utf;
	private import std.windows.syserror;
} else version (Posix) {
	private import core.sys.posix.fcntl;
	private import core.sys.posix.unistd;
	private import core.sys.posix.sys.mman;
	private import core.sys.posix.sys.stat;
} else {
	static assert(0);
}



/**
 * Persistent maps value type object to file
 */
class Persistent(T)
{
	version (Windows) {

	} else version (Posix) {

	} else
		static assert(0);

/**
 * Open file and assosiate object with it.
 * The file is extended if smaller than requred. Initialized
 *   with T.init if created or extended.
 */
	this(string path) {
		auto owner=map(path);
       _ref=cast(T*)(_map);
	   if(owner)
	   	*_ref=T.init;
 	}



/**
 * Unmap the file and release resources.
 * The file is left on the disk and may be reopened.
 */
	~this() {
		unmap();
	}



/**
 * Flash memory to disc.
 */
	void sync() {
		version (Windows) {
			FlushViewOfFile(data.ptr, data.length);
		} else version (Posix) {
			int x=msync(_ref, T.sizeof, MS_SYNC);
			errnoEnforce(!x, _tag~": sync failed");
		} else
			static assert(0);
	}
	
	
/**
 * Return string representation for wrapped object instead of self.
 */
	override string toString() { return to!string(*_ref); }
	
/**
 * Get reference to wrapped object.
 */
	@property ref T Ref() {	return *_ref; }
/**
 * Silently convert to reference to wrapped object.
 */
	alias Ref this;

	
	
	
	private bool map(string path) {
		bool owner=true;
		version (Windows) {

		} else version (Posix) {
			_fd=open(path.toStringz(), O_RDWR|O_CREAT|O_EXCL, S_IRUSR|S_IWUSR);
			if(_fd < 0) {
				owner=false;
				_fd=open(path.toStringz(), O_RDWR, S_IRUSR|S_IWUSR);
				if(_fd < 0)
					errnoEnforce(_fd >= 0, _tag~"("~path~")");
			}

			if(fileSize(path) < T.sizeof) {
				fileExpand(path);
				owner=true;
			}

			_map=mmap(null, T.sizeof, PROT_READ|PROT_WRITE, MAP_SHARED, _fd, 0);
			if(_map == MAP_FAILED) {
				close(_fd);
				errnoEnforce(false, _tag~"("~path~")");
			}

			return owner;

		} else
			static assert(0);
	}


	private void unmap() {
		bool owner=true;
		version (Windows) {

		} else version (Posix) {
			sync();
			munmap(_map, T.sizeof);
			close(_fd);

		} else
			static assert(0);
	}

	
	private size_t fileSize(string path) {
		version (Windows) {

		} else version (Posix) {
			stat_t st;
			if(fstat(_fd, &st)) {
				close(_fd);
				errnoEnforce(false, _tag~"("~path~")");
			}
			return st.st_size;
	
		} else
			static assert(0);
	}

	private void fileExpand(string path) {
		version (Windows) {

		} else version (Posix) {
			lseek(_fd, T.sizeof-1, SEEK_SET);
			char c=0;
			core.sys.posix.unistd.write(_fd, &c, 1);
		} else
			static assert(0);
	}

private:
	version (Windows) {
		HANDLE hFile = INVALID_HANDLE_VALUE;
		HANDLE hFileMap = null;
		uint dwDesiredAccess;
	} else version (Posix) {
		int _fd;
		void* _map=null;
		enum _tag="Persistent!("~T.stringof~")";
		T* _ref=null;
	} else
		static assert(0);
}


///
unittest
{
	import std.stdio;
	import std.conv;
	import std.string;
	import std.getopt;
	import std.persistent;

	struct A { int x; };
	enum Color { black, red, green, blue, white };

	// Usage: test
	// Output:
	//	Persistent!int          : 0
	//	Persistent!double       : nan
	//	Persistent!(A)          : A(0)
	//	Persistent!(int[5])     : [0, 0, 0, 0, 0]
	//	Persistent!(Color)      : black
	//
	// Usage: test --int=12 --real=3.14159 --struct=5 --array=1,2 --color=red
	// Output:
	// Persistent!int          : 12
	// Persistent!double       : 3.14159
	// Persistent!(A)          : A(5)
	// Persistent!(int[5])     : [1, 2, 0, 0, 0]
	// Persistent!(Color)      : red
	void main(string[] argv)
	{
		// persistent int
		auto p0=new Persistent!int("Q1");
		// persistent double
		auto p1=new Persistent!double("Q2");
		// persistent struct
		auto p2=new Persistent!A("Q3");
		// persistent static array of 5 ints
		auto p3=new Persistent!(int[5])("Q4");
		// persistent enum
		auto p4=new Persistent!Color("Q5");

		getopt(arg
			 , "int", delegate(string key, string val){ p0=to!int(val); }
			 , "real", delegate(string key, string val){ p1=to!double(val); }
			 , "struct", delegate(string key, string val){ p2.x=to!int(val); }
			 , "array", delegate(string key, string val){
		 			auto lst=split(val,",");
					p3[0..lst.length]=to!(int[])(lst);
				}
			 , "color", delegate(string key, string val){ p4=to!Color(val); } 
			);


		writefln("%-24s: %s", typeof(p0).stringof, p0);
		writefln("%-24s: %s", typeof(p1).stringof, p1);
		writefln("%-24s: %s", typeof(p2).stringof, p2);
		writefln("%-24s: %s", typeof(p3).stringof, p3);
		writefln("%-24s: %s", typeof(p4).stringof, p4);
	}
}


