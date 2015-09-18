module std.experimental.perpetual;
/** TODO: 
 *		redesignn this(size, type) ctor (move to factory???)
 *		documentation
 */

private import std.exception;
private import std.conv : to, emplace;
private import std.file : exists;
private import std.traits : hasIndirections, isCallable, isAssignable, isArray;
import std.stdio;

/**
 * Maps value type object to file.
 *  The value is persistent and may be reused later, as well as
 *   shared with another process/thread. 
 */
struct Perpetual(T)
{
	private ShMem _heap;
	private enum _tag="Perpetual!("~T.stringof~")";

	static if(is(T == Element[],Element))
	{
	/// dynamic array 
		private Element[] _value;
		private enum bool dynamic=true;
		static assert(!hasIndirections!Element
		    , Element.stringof~" is reference type");

		@property Element[] Ref() { return _value; }

		string toString() { return to!string(_value); }

	}
	else
	{
	/// value type
		alias Element=T;
		private Element[] _value;
		private enum bool dynamic=false;
		static assert(!hasIndirections!T
		    , T.stringof~" is reference type");

		@property ref T Ref() {	return _value[0]; }

		static if(!isArray!Element)
			ref Element opIndex(size_t i) { return _value[i]; }

		string toString() { return to!string(_value[0]); }
	}

	static if(isAssignable!Element)
		enum mode=ShMem.Mode.readWrite;
	else
		enum mode=ShMem.Mode.readOnly;

	@property length() const { return _value.length; }

	@property initIndex() const { return _heap.unplowed/Element.sizeof; }



/**
 * Open file and assosiate object with it.
 * The file is extended if smaller than requred. Initialized
 *   with T.init if created or extended.
 */
	this(Arg...)(string path, Arg arg)
	{
		static if(dynamic)
			_heap=shMem(path, mode);
		else
			_heap=shMem(path, Element.sizeof, mode);
		enforce(_heap.length >= Element.sizeof, _tag~": file is too small");

		_value=cast(Element[]) _heap[0.._heap.length];
		static if(isAssignable!Element)
		{
			foreach(i, ref x; _value[initIndex..$])
				emplace(&x, arg);
		}
	}

/**
 * Open file and assosiate object with it.
 * Version for dynamic arrays, creates array of requsted length
 */
	this(Arg...)(size_t len, string path, Arg arg)
	{
		immutable size_t size=len*Element.sizeof;
		
		_heap=shMem(path, size, ShMem.Mode.readWrite);
		_value=cast(Element[]) _heap[0..size];
		static if(isAssignable!Element)
		{
			foreach(x; _value[initIndex..$])
				emplace(&x, arg);
		}
	}
 	

/**
 * Get reference to wrapped object.
 */
	alias Ref this;

}


///
unittest {
	import std.stdio;
	import std.conv;
	import std.string;
	import std.file : remove;
	import core.sys.posix.sys.stat;
	//import std.file : deleteme;
	string deleteme="test.";

	struct A { int x; };
	class B {};
	enum Color { black, red, green, blue, white };

	string[] file;
	foreach(i; 0..8) file~=deleteme~to!string(i);
	scope(exit) foreach(f; file[]) remove(f);

	/// Part 1: create mapped variables
	{
		// single int value, default initializer, test assignable
		auto p0=Perpetual!int(file[0]);
		assert(p0 == int.init);
		p0=7;

		// single double value initialized in ctor
		auto p1=Perpetual!double(file[1], 2.71828);
		assert(p1 == 2.71828);
		p1=3.14159;

		// struct, initialized in ctor
		auto p2=Perpetual!A(file[2], 22);
		assert(p2.x == 22);
		
		// static array of integers, assignable
		auto p3=Perpetual!(int[5])(file[3]);
		assert(p3[0] == int.init);
		p3=[1,3,5,7,9];
		assert(p3[0] == 1);

		// enum, initialized in ctor
		auto p4=Perpetual!Color(file[4], Color.red);
		assert(p4 == Color.red);
		

		// character string
		auto p5=Perpetual!(char[32])(file[5]);
		p5="hello world";

		// double static array
		auto p8=Perpetual!(char[3][5])(file[6]);
		foreach(ref x; p8) x="..."; p8[0]="one"; p8[2]="two";


		/// Compile time errors
		// Perpetual!(char*)("?");        //ERROR: "char* is reference type"
		// Perpetual!B("?");              //ERROR: "B is reference type"
		// Perpetual!(char*[])("?");      //ERROR: "char* is reference type"
		// Perpetual!(char*[12])("?");    //ERROR: "char*[12] is reference type"
		// Perpetual!(char[string])("?"); //ERROR: "char[string] is reference type"
		// Perpetual!(char[][])("?");     //ERROR: "char[] is reference type"
		// Perpetual!(char[][3])("?");    //ERROR: "char[][3] is reference type"
	}
	/// destroy everything and unmap files
	

	
	/// Part 2: map again and check the values are preserved
	{
		// Was previosly mapped as int and assigned 7
		auto p0=Perpetual!int(file[0]);
		assert(p0 == 7);

		// Was previousli mapped as double and assigned 3.14159
		auto p1=Perpetual!double(file[1]);
		assert(p1 == 3.14159);

		// struct with int member initialized with 22
		auto p2=Perpetual!A(file[2]);
		assert(p2 == A(22));
		
		// Was mapped as int[5], remap as view only of array shorts
		auto p3=Perpetual!(immutable(short[]))(file[3]);
		// Assuming LSB
		assert(p3.length == 10);
		assert(p3[0] == 1 && p3[2] == 3 && p3[4] == 5);
		//p3[1]=111; //ERROR: cannot modify immutable expression

		// enum, was set to Color.red
		auto p4=Perpetual!Color(file[4]);
		assert(p4 == Color.red);

		// view only variant of char[4]
		auto p5=Perpetual!string(4, file[5]);
		assert(p5 == "hell");
		//p5[0]='A'; //ERROR: cannot modify immutable expression
		//p5[]="1234"; //ERROR: slice is not mutable


		// map of double array as plain array
		auto p6=Perpetual!(const(char[]))(file[6]);
		assert(p6[0..5] == "one..");
		// map again as dynamic array
		auto p7=Perpetual!(char[3][])(file[6]);
		assert(p7.length == 5);
		assert(p7[2] == "two");
		//p7[0]="null"; //ERROR: Array lengths don't match for copy: 4 != 3
		p7[0]="nil";

		// ctor with size parameter 
		//assertThrown(Perpetual!(char)(45, deleteme));


		{ File(file[7],"w").write("12345678"); }
		chmod(file[7].toStringz, octal!444);
		// mutable array can't be mapped on read-only file 
		assertThrown(Perpetual!(int[])(file[7]));
		// immutable array can be mapped
		auto p8=Perpetual!(immutable(int)[])(file[7]);
		assert(p8.length == 2);

		auto p9=Perpetual!int(3,file[0]);
		assert(p9 == 7);
		assert(p9[0] == 7);
		assert(p9[1] == 0);
		assert(p9.length == 3);
		//p9[3];	// RangeError: Range violation


		auto pA=Perpetual!(char[4])(4,file[5]);
		assert(pA.length == 4);
		assert(pA == "hell");
	}

}







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



package class ShMem
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

    void opIndex(size_t i)
    {
        return _data[i];
    }

    @property auto length() const { return _data.length; }

    @property bool writeable() const { return _writeable; }

    @property bool master() const { return _master; }

    @property auto unplowed() const { return _index; }

	






	version(Posix)
	{
		private int _fd;
		private void[] _data;
		private bool _writeable;
		private bool _master;
		private size_t _index;
	}
	version(Windows)
	{

	}
	

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
				_fd=.open(toStringz(path), O_RDWR|O_CREAT|O_EXCL, S_IRUSR|S_IWUSR);
				if(_fd >= 0)
				{
					_master=true;
					_writeable=true;
					return _fd;
				}

				/// otherwise, try to open read/write existing file
				_fd=.open(toStringz(path), O_RDWR, S_IRUSR|S_IWUSR);
				if(_fd >= 0)
				{
					_master=false;
					_writeable=true;
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

