/**
 * Map variable, POD structure or array to file
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
private import std.algorithm;
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
 * Persistently maps value type object to file
 */
struct Perpetual(T)
{
	version (Windows) {

	} else version (Posix) {
		private int _fd;
		private void* _map;
	} else
		static assert(0);

	enum _tag="Perpetual!("~T.stringof~")";

	static if(is(T == Element[],Element)) {
	// dynamic array 
		private size_t _size=0;
		private enum dynamic=true;
		static assert(!hasIndirections!Element, Element.stringof~" is reference type");
		@property ref T Ref() const { return cast(T) _map[0.._size]; }

	} else {
	// value type
		private enum dynamic=false;
		static assert(!hasIndirections!T, T.stringof~" is reference type");
		@property ref T Ref() const {	return *cast(T*)(_map); }
	}

/**
 * Get reference to wrapped object.
 */
	alias Ref this;

	private bool _owner=true;
	@property auto master() { return _owner; }
	void opAssign(T x) { Ref=x; }

/**
 * Return string representation for wrapped object instead of self.
 */
	string toString() { return to!string(Ref); }



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
		} else if(master) {
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


/**
 * Convenience helper, equivalent to new Persistent!T
 */
auto perpetual(T)(string path)
{
	return Perpetual!T(path);
}



/**
 * Single argument helper,
 *  uses copy ctor/assignment for initialization
 */
auto perpetual(T, U)(string path, U seed)
{
	Perpetual!T p=path;
	if(p.master) {
		static if(isArray!T) {
			static if(isArray!U) {
				auto l=min(T.length, seed.length);
				p[0..l]=seed[0..l];
			} else {
				p[]=seed;
			}
		} else {
			p=seed;
		}
	}
	return p;
}


/**
 * Multi-argument helper,
 *  forwards arguments to ctor
 */
auto perpetual(T, Args...)(string path, Args args)
{
	Perpetual!T p(path);
	if(p.master)
		p=T(args);
	return p;
}


package @property string deleteme() @safe
{
    import std.process : thisProcessID;
    import std.path : buildPath;
    static _deleteme = "perpetual.unittest.";
    static _first = true;

    if(_first)
    {
        _deleteme=buildPath(tempDir(), _deleteme)~to!string(thisProcessID)~".";
        _first=false;
    }

    return _deleteme;
}

///
unittest
{
	import std.stdio;
	import std.conv;
	import std.string;
	import std.math : isNaN;
	import std.perpetual;

	struct A { int x; }
	class B {};
	enum Color { black, red, green, blue, white };
	
	//, deleteme~""
	auto mapped=[deleteme~"0", deleteme~"1", deleteme~"2", deleteme~"3"];
    scope(exit) foreach(file; mapped) { assert(file.exists); remove(file.toStringz); }

	// simple built-in values
	auto p0=perpetual!int(mapped[0]);
	assert(p0 == int.init);
	p0=24;
	assert(p0 == 24);
	assert(p0 < 25);

	auto p1=perpetual!double(mapped[1]);
	assert(isNaN(cast(double) p1));
	p1=3.14159;
	assert(p1 == 3.14159);

	// struct
	auto p2=perpetual!A(mapped[2]);
	assert(p2 == A.init);
	p2=A(7);
	assert(p2.x == 7);

	// static array of integers
	auto p3=perpetual!(int[5])(mapped[3], [7,5,3,1]);
	// view only, map above as array of shorts
	auto p4=perpetual!(immutable(short[]))(mapped[3]);
	

/*
	// view only, map above as array of shorts
	auto p4=perpetual!(immutable(short[]))("Q4");
	// enum
	auto p5=perpetual!Color("Q5", Color.white);
	// character string, reinitialize if new file created
	auto p6=perpetual!(char[])("Q6");
	if(p6.length ==0) {
	// the file wasn't initialized, do with static array
		perpetual!(char[32])("Q6", '_');
		p6=perpetual!(char[])("Q6");
	}
	// view only variant of above
	auto p7=perpetual!string("Q6");
	// double static array with initailization
 	auto p8=perpetual!(char[3][5])("Q7");
	if(p8.master) { foreach(ref x; p8) x="..."; p8[0]="one"; p8[2]="two"; }
	// map of above as plain array
	auto p9=perpetual!(const(char[]))("Q7");
	// map again as dynamic array
	auto pA=perpetual!(char[3][])("Q7");

	//auto pX=new Perpetual!(char*)("Q?"); //ERROR: "char* is reference type"
	//auto pX=new Perpetual!B("Q?"); //ERROR: "B is reference type"
	//auto pX=new Perpetual!(char*[])("Q?"); //ERROR: "char* is reference type"
	//auto pX=new Perpetual!(char*[12])("Q?"); //ERROR: "char*[12] is reference type"
	//auto pX=new Perpetual!(char[string])("Q?"); //ERROR: "char[string] is reference type"
	//auto pX=new Perpetual!(char[][])("Q?"); //ERROR: "char[] is reference type"
	//auto pX=new Perpetual!(char[][3])("Q?"); //ERROR: "char[][3] is reference type"


	getopt(arg
		 , "int", delegate(string key, string val){ p0=to!int(val); }
		 , "real", delegate(string key, string val){ p1=to!double(val); }
		 , "struct", delegate(string key, string val){ p2.x=to!int(val); }
		 , "array", delegate(string key, string val){
		 		auto lst=split(val,",");
				p3[0..lst.length]=to!(int[])(lst);
			}
		 , "color", delegate(string key, string val){ p5=to!Color(val); }
		 , "string", delegate(string key, string val){ p6[0..val.length]=val; }
		);

	writefln("%-32s: %s", typeof(p0).stringof, p0);
	writefln("%-32s: %s", typeof(p1).stringof, p1);
	writefln("%-32s: %s", typeof(p2).stringof, p2);
	writefln("%-32s: %s", typeof(p3).stringof, p3);
	writefln("%-32s: %s", typeof(p4).stringof, p4);
	writefln("%-32s: %s", typeof(p5).stringof, p5);
	writefln("%-32s: %s", typeof(p6).stringof, p6);
	writefln("%-32s: %s", typeof(p7).stringof, p7);
	writefln("%-32s: %s", typeof(p8).stringof, p8);
	writefln("%-32s: %s", typeof(p9).stringof, p9);
	writefln("%-32s: %s", typeof(pA).stringof, pA);
*/
}
