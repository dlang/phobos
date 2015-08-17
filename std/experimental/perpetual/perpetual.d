/**
 * Map variable, static array or POD structure to file
 *   to make it shared and persistent between program invocations.
 * Macros:
  * Source:    $(PHOBOSSRC std/perpetual.d)
 */
module std.perpetual;
//import std.stdio;

private import std.file;
private import core.stdc.stdio;
private import std.traits;
private import std.string;
private import std.conv;
private import std.exception;
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
class perpetual(T)
{
	version (Windows) {

	} else version (Posix) {
		private int _fd;
		private void* _map;
	} else
		static assert(0);

	enum _tag="perpetual!("~T.stringof~")";

	static if(is(T == Element[],Element)) {
	// dynamic array 
		private size_t _size=0;
		enum bool dynamic=true;
		static assert(!hasIndirections!Element, Element.stringof~" is reference type");
		@property T Ref() const { return cast(T) _map[0.._size]; }

	} else {
	// value type
		enum bool dynamic=false;
		static assert(!hasIndirections!T, T.stringof~" is reference type");
		@property ref T Ref() const {	return *cast(T*)(_map); }
	}

/**
 * Get reference to wrapped object.
 */
	alias Ref this;

	private bool _owner=true;
	@property auto master() { return _owner; }

/**
 * Return string representation for wrapped object instead of self.
 */
	override string toString() const { return to!string(Ref); }



/**
 * Open file and assosiate object with it.
 * The file is extended if smaller than requred. Initialized
 *   with T.init if created or extended.
 */
	this(string path) {
		map(path);
		static if(dynamic) {
			// we don't need initialization here, the file already exists
			//   so, is to be initialized
		} else if(owner) {
			*cast(T*)(_map)=T.init;
		}
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

		} else version (Posix) {
			int x=msync(_map, T.sizeof, MS_SYNC);
			errnoEnforce(!x, _tag~": sync failed");
		} else
			static assert(0);
	}
	
	
	
	
	
	
	private bool map(string path) {
		version (Windows) {

		} else version (Posix) {
			_fd=open(path.toStringz(), O_RDWR|O_CREAT|O_EXCL, S_IRUSR|S_IWUSR);
			if(_fd < 0) {
				_owner=false;
				_fd=open(path.toStringz(), O_RDWR, S_IRUSR|S_IWUSR);
				if(_fd < 0)
					errnoEnforce(_fd >= 0, _tag~"("~path~")");
			}

			static if(dynamic) {
				//_size=fileSize(path)/Element.sizeof;
				_size=fileSize(path);

			} else {
				if(fileSize(path) < T.sizeof) {
					fileExpand(path);
					_owner=true;
				}
			}

			_map=mmap(null, T.sizeof, PROT_READ|PROT_WRITE, MAP_SHARED, _fd, 0);
			if(_map == MAP_FAILED) {
				close(_fd);
				errnoEnforce(false, _tag~"("~path~")");
			}

			return _owner;

		} else
			static assert(0);
	}


	private void unmap() {
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

}


///
unittest
{
	import std.stdio;
	import std.conv;
	import std.string;
	import std.getopt;
	import std.perpetual;

	struct A { int x; };
	enum Color { black, red, green, blue, white };

	// Usage: test
	// Output:
	//	perpetual!int          : 0
	//	perpetual!double       : nan
	//	perpetual!(A)          : A(0)
	//	perpetual!(int[5])     : [0, 0, 0, 0, 0]
	//	perpetual!(Color)      : black
	//
	// Usage: test --int=12 --real=3.14159 --struct=5 --array=1,2 --color=red
	// Output:
	// perpetual!int          : 12
	// perpetual!double       : 3.14159
	// perpetual!(A)          : A(5)
	// perpetual!(int[5])     : [1, 2, 0, 0, 0]
	// perpetual!(Color)      : red
	void main(string[] argv)
	{
		// persistent int
		auto p0=new perpetual!int("Q1");
		// persistent double
		auto p1=new perpetual!double("Q2");
		// persistent struct
		auto p2=new perpetual!A("Q3");
		// persistent static array of 5 ints
		auto p3=new perpetual!(int[5])("Q4");
		// persistent enum
		auto p4=new perpetual!Color("Q5");

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


