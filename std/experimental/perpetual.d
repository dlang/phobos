module std.experimental.perpetual;

private import std.mmfile;
private import std.exception;
private import std.conv : to;
private import std.file : exists;
private import std.traits : hasIndirections, isCallable, isAssignable;



/**
 * Maps value type object to file.
 *  The value is persistent and may be reused later, as well as
 *   shared with another process/thread. 
 */
struct Perpetual(T)
{
	private MmFile _heap;
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
		private T *_value;
		private enum bool dynamic=false;
		static assert(!hasIndirections!T
		    , T.stringof~" is reference type");
		@property ref T Ref() {	return *_value; }
		string toString() { return to!string(*_value); }
	}



/**
 * Open file and assosiate object with it.
 * The file is extended if smaller than requred. Initialized
 *   with T.init if created or extended.
 */
	this(string path)
	{
		static if(dynamic)
		{
			enforce(exists(path)
			    , _tag~": dynamic array of zero length");
			size_t size=0;
			if(isAssignable!Element)			
				_heap=new MmFile(path, MmFile.Mode.readWrite, 0, null, 0);
			else
				_heap=new MmFile(path, MmFile.Mode.read, 0, null, 0);
			enforce(_heap.length >= Element.sizeof, _tag~": file is too small");
			_value=cast(Element[]) _heap[0.._heap.length];
		}
		else
		{
			size_t size=T.sizeof;
			if(isAssignable!T)			
				_heap=new MmFile(path, MmFile.Mode.readWrite, T.sizeof, null, 0);
			else
				_heap=new MmFile(path, MmFile.Mode.read, T.sizeof, null, 0);
			enforce(_heap.length >= size, _tag~": file is too small");
			_value=cast(T*) _heap[].ptr;
		}
 	}

/**
 * Open file and assosiate object with it.
 * Version for dynamic arrays, creates array of requsted length
 */
	this(size_t len, string path)
	{
		static if(dynamic)
		{
			size_t size=len*Element.sizeof;
			if(isAssignable!Element)			
				_heap=new MmFile(path, MmFile.Mode.readWrite, len*Element.sizeof, null, 0);
			else
				_heap=new MmFile(path, MmFile.Mode.read, len*Element.sizeof, null, 0);
			enforce(_heap.length >= len*Element.sizeof, _tag~": file is too small");
			_value=cast(Element[]) _heap[0..len];

		} else {
			// assert(0);
			this(path);
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
	import std.file : deleteme;

	struct A { int x; };
	class B {};
	enum Color { black, red, green, blue, white };

	string[] file;
	foreach(i; 1..9) file~=deleteme~to!string(i);
	scope(exit) foreach(f; file[]) remove(f);

	// create mapped variables
	{
		auto p0=Perpetual!int(file[0]);
		assert(p0 == 0);
		p0=7;

		auto p1=Perpetual!double(file[1]);
		p1=3.14159;

		// struct
		auto p2=Perpetual!A(file[2]);
		assert(p2.x == int.init);
		p2=A(22);		
		
		// static array of integers
		auto p3=Perpetual!(int[5])(file[3]);
		assert(p3[0] == 0);
		p3=[1,3,5,7,9];

		// enum
		auto p4=Perpetual!Color(file[4]);
		assert(p4 == Color.black);
		p4=Color.red;
		

		// character string, reinitialize if new file created
		auto p5=Perpetual!(char[32])(file[5]);
		p5="hello world";

		// double static array with initailization
		auto p8=Perpetual!(char[3][5])(file[6]);
		foreach(ref x; p8) x="..."; p8[0]="one"; p8[2]="two";

		//auto pX=Perpetual!(char*)("?");     //ERROR: "char* is reference type"
		//auto pX=Perpetual!B("?");           //ERROR: "B is reference type"
		//auto pX=Perpetual!(char*[])("?");   //ERROR: "char* is reference type"
		//auto pX=Perpetual!(char*[12])("?");  //ERROR: "char*[12] is reference type"
		//auto pX=Perpetual!(char[string])("?"); //ERROR: "char[string] is reference type"
		//auto pX=Perpetual!(char[][])("?");    //ERROR: "char[] is reference type"
		//auto pX=Perpetual!(char[][3])("?");   //ERROR: "char[][3] is reference type"
	}
	// destroy everything and unmap files
	
	
	// map again and check the values are preserved
	{
		auto p0=Perpetual!int(file[0]);
		assert(p0 == 7);

		auto p1=Perpetual!double(file[1]);
		assert(p1 == 3.14159);

		// struct
		auto p2=Perpetual!A(file[2]);
		assert(p2 == A(22));
		
		// map int[] as view only of array shorts
		auto p3=Perpetual!(immutable(short[]))(file[3]);
		// Assuming LSB
		assert(p3[0] == 1 && p3[2] == 3 && p3[4] == 5);
		//p3[1]=111; //ERROR: cannot modify immutable expression p3.Ref()[1]

		// enum
		auto p4=Perpetual!Color(file[4]);
		assert(p4 == Color.red);

		// view only variant of char[4]
		auto p5=Perpetual!string(4, file[5]);
		assert(p5 == "hell");
		//p5[0]='A'; //ERROR: cannot modify immutable expression p5.Ref()[0]
		//p5[]="1234"; //ERROR: slice p5.Ref()[] is not mutable


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
	}

}


