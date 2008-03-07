Ddoc

$(SPEC_S Interfacing to C++,

	$(P
	While D is fully capable of
	$(LINK2 interfaceToC.html, interfacing to C),
	its ability to interface to C++ is much more limited.
	There are three ways to do it:
	)

	$(OL

	$(LI Use C++'s ability to create a C interface, and then
	use D's ability to
	$(LINK2 interfaceToC.html, interface with C)
	to access that interface.
	)

	$(LI Use C++'s ability to create a COM interface, and then
	use D's ability to
	$(LINK2 COM.html, interface with COM)
	to access that interface.
	)

	$(LI Use the limited ability described here to connect
	directly to C++ functions and classes.
	)

	)

<h2>The General Idea</h2>

	$(P Being 100% compatible with C++ means more or less adding
	a fully functional C++ compiler front end to D.
	Anecdotal evidence suggests that writing such is a minimum
	of a 10 man-year project, essentially making a D compiler
	with such capability unimplementable.
	Other languages looking to hook up to C++ face the same
	problem, and the solutions have been:
	)

	$(OL
	$(LI Support the COM interface (but that only works for Windows).)
	$(LI Laboriously construct a C wrapper around
	the C++ code.)
	$(LI Use an automated tool such as SWIG to construct a
	C wrapper.)
	$(LI Reimplement the C++ code in the other language.)
	$(LI Give up.)
	)

	$(P D takes a pragmatic approach that assumes a couple
	modest accommodations can solve a significant chunk of
	the problem:
	)

	$(UL
	$(LI matching C++ name mangling conventions)
	$(LI matching C++ function calling conventions)
	$(LI matching C++ virtual function table layout for single inheritance)
	)

<h2>Calling C++ Global Functions From D</h2>

	$(P Given a C++ function in a C++ source file:)

$(CPPCODE
#include &lt;iostream&gt;

using namespace std;

int foo(int i, int j, int k)
{
    cout &lt;&lt; "i = " &lt;&lt; i &lt;&lt; endl;
    cout &lt;&lt; "j = " &lt;&lt; j &lt;&lt; endl;
    cout &lt;&lt; "k = " &lt;&lt; k &lt;&lt; endl;

    return 7;
}
)

	$(P In the corresponding D code, $(CODE foo)
	is declared as having C++ linkage and function calling conventions:
	)

------
extern (C++) int foo(int i, int j, int k);
------

	$(P and then it can be called within the D code:)

------
extern (C++) int foo(int i, int j, int k);

void main()
{
    foo(1,2,3);
}
------

	$(P Compiling the two files, the first with a C++ compiler,
	the second with a D compiler, linking them together,
	and then running it yields:)

$(CONSOLE
i = 1
j = 2
k = 3
)

	$(P There are several things going on here:)

	$(UL 
	$(LI D understands how C++ function names are "mangled" and the
	correct C++ function call/return sequence.)

	$(LI Because modules are not part of C++, each function with
	C++ linkage must be globally unique within the program.)

	$(LI There are no __cdecl, __far, __stdcall, __declspec, or other
	such nonstandard C++ extensions in D.)

	$(LI There are no volatile type modifiers in D.)

	$(LI Strings are not 0 terminated in D. See "Data Type Compatibility"
	for more information about this. However, string literals in D are
	0 terminated.)

	)

	$(P C++ functions that reside in namespaces cannot be
	direcly called from D.
	)


<h2>Calling Global D Functions From C++</h2>

	$(P To make a D function accessible from C++, give it
	C++ linkage:)

---
import std.stdio;

extern (C++) int foo(int i, int j, int k)
{
    writefln("i = %s", i);
    writefln("j = %s", j);
    writefln("k = %s", k);
    return 1;
}

extern (C++) void bar();

void main()
{
    bar();
}
---

	$(P The C++ end looks like:)

$(CPPCODE
int foo(int i, int j, int k);

void bar()
{
    foo(6, 7, 8);
}
)

	$(P Compiling, linking, and running produces the output:)

$(CONSOLE
i = 6
j = 7
k = 8
)


<h2>Classes</h2>

	$(P D classes are singly rooted by Object, and have an
	incompatible layout from C++ classes.
	D interfaces, however, are very similar to C++ single
	inheritance class heirarchies.
	So, a D interface with the attribute of $(CODE extern (C++))
	will have a virtual function pointer table (vtbl[]) that
	exactly matches C++'s.
	A regular D interface has a vtbl[] that differs in that
	the first entry in the vtbl[] is a pointer to D's RTTI info,
	whereas in C++ the first entry points to the first virtual
	function.
	)

<h2>Calling C++ Virtual Functions From D</h2>

	$(P Given C++ source code defining a class like:)

$(CPPCODE
#include &lt;iostream&gt;

using namespace std;

class D
{
  public:
    virtual int bar(int i, int j, int k)
    {
	cout &lt;&lt; "i = " &lt;&lt; i &lt;&lt; endl;
	cout &lt;&lt; "j = " &lt;&lt; j &lt;&lt; endl;
	cout &lt;&lt; "k = " &lt;&lt; k &lt;&lt; endl;
	return 8;
    }
};

D *getD()
{
    D *d = new D();
    return d;
}
)

	$(P We can get at it from D code like:)

---
extern (C++)
{
  interface D
  {
    int bar(int i, int j, int k);
  }

  D getD();
}

void main()
{
    D d = getD();
    d.bar(9,10,11);
}
---

<h2>Calling D Virtual Functions From C++</h2>

	$(P Given D code like:)

---
extern (C++) int callE(E);

extern (C++) interface E
{
    int bar(int i, int j, int k);
}

class F : E
{
    extern (C++) int bar(int i, int j, int k)
    {
	writefln("i = ", i);
	writefln("j = ", j);
	writefln("k = ", k);
	return 8;
    }
}

void main()
{
    F f = new F();
    callE(f);
}
---

	$(P The C++ code to access it looks like:)

$(CPPCODE
class E
{
  public:
    virtual int bar(int i, int j, int k);
};


int callE(E *e)
{
    return e->bar(11,12,13);
}
)

	$(P Note:)

	$(UL
	$(LI non-virtual functions, and static member functions,
	cannot be accessed.)

	$(LI class fields can only be accessed via virtual getter
	and setter methods.)
	)

<h2>Function Overloading</h2>

	$(P C++ and D follow different rules for function overloading.
	D source code, even when calling $(CODE extern (C++)) functions,
	will still follow D overloading rules.
	)


<h2>Storage Allocation</h2>

	$(P C++ code explicitly manages memory with calls to
	$(CODE ::operator new()) and $(CODE ::operator delete()).
	D allocates memory using the D garbage collector,
	so no explicit delete's are necessary.
	D's new and delete are not compatible with C++'s
	$(CODE ::operator new) and $(CODE::operator delete).
	Attempting to allocate memory with C++ $(CODE ::operator new)
	and deallocate it with D's $(CODE delete), or vice versa, will
	result in miserable failure.
	)

	$(P D can still explicitly allocate memory using std.c.stdlib.malloc()
	and std.c.stdlib.free(), these are useful for connecting to C++
	functions that expect malloc'd buffers, etc.
	)

	$(P If pointers to D garbage collector allocated memory are passed to
	C++ functions, it's critical to ensure that that memory will not
	be collected by the garbage collector before the C++ function is
	done with it. This is accomplished by:
	)

	$(UL 

	$(LI Making a copy of the data using std.c.stdlib.malloc() and passing
	the copy instead.)

	$(LI Leaving a pointer to it on the stack (as a parameter or
	automatic variable), as the garbage collector will scan the stack.)

	$(LI Leaving a pointer to it in the static data segment, as the
	garbage collector will scan the static data segment.)

	$(LI Registering the pointer with the garbage collector with the
	std.gc.addRoot() or std.gc.addRange() calls.)

	)

	$(P An interior pointer to the allocated memory block is sufficient
	to let the GC
	know the object is in use; i.e. it is not necessary to maintain
	a pointer to the beginning of the allocated memory.
	)

	$(P The garbage collector does not scan the stacks of threads not
	created by the D Thread interface. Nor does it scan the data
	segments of other DLL's, etc.
	)

<h2>Data Type Compatibility</h2>

	$(TABLE1
	<caption>D And C Type Equivalence</caption>

	$(TR
	$(TH D type)
	$(TH C type)
	)

	$(TR
	$(TD $(B void))
	$(TD $(B void))
	)

	$(TR
	$(TD $(B byte))
	$(TD $(B signed char))
	)

	$(TR
	$(TD $(B ubyte))
	$(TD $(B unsigned char))
	)

	$(TR
	$(TD $(B char))
	$(TD $(B char) (chars are unsigned in D))
	)

	$(TR
	$(TD $(B wchar))
	$(TD $(B wchar_t) (when sizeof(wchar_t) is 2))
	)

	$(TR
	$(TD $(B dchar))
	$(TD $(B wchar_t) (when sizeof(wchar_t) is 4))
	)

	$(TR
	$(TD $(B short))
	$(TD $(B short))
	)

	$(TR
	$(TD $(B ushort))
	$(TD $(B unsigned short))
	)

	$(TR
	$(TD $(B int))
	$(TD $(B int))
	)

	$(TR
	$(TD $(B uint))
	$(TD $(B unsigned))
	)

	$(TR
	$(TD $(B long))
	$(TD $(B long long))
	)

	$(TR
	$(TD $(B ulong))
	$(TD $(B unsigned long long))
	)

	$(TR
	$(TD $(B float))
	$(TD $(B float))
	)

	$(TR
	$(TD $(B double))
	$(TD $(B double))
	)

	$(TR
	$(TD $(B real))
	$(TD $(B long double))
	)

	$(TR
	$(TD $(B ifloat))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(B idouble))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(B ireal))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(B cfloat))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(B cdouble))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(B creal))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(B struct))
	$(TD $(B struct))
	)

	$(TR
	$(TD $(B union))
	$(TD $(B union))
	)

	$(TR
	$(TD $(B enum))
	$(TD $(B enum))
	)

	$(TR
	$(TD $(B class))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(I type)$(B *))
	$(TD $(I type) $(B *))
	)

	$(TR
	$(TD no equivalent)
	$(TD $(I type) $(B &amp;))
	)

	$(TR
	$(TD $(I type)$(B [)$(I dim)$(B ]))
	$(TD $(I type)$(B [)$(I dim)$(B ]))
	)

	$(TR
	$(TD $(I type)$(B [)$(I dim)$(B ]*))
	$(TD $(I type)$(B (*)[)$(I dim)$(B ]))
	)

	$(TR
	$(TD $(I type)$(B []))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(I type)$(B [)$(I type)$(B ]))
	$(TD no equivalent)
	)

	$(TR
	$(TD $(I type) $(B function)$(B $(LPAREN))$(I parameters)$(B $(RPAREN)))
	$(TD $(I type)$(B (*))$(B $(LPAREN))$(I parameters)$(B $(RPAREN)))
	)

	$(TR
	$(TD $(I type) $(B delegate)$(B $(LPAREN))$(I parameters)$(B $(RPAREN)))
	$(TD no equivalent)
	)

	)

	$(P These equivalents hold for most 32 bit C++ compilers.
	The C++ standard
	does not pin down the sizes of the types, so some care is needed.
	)

<h2>Structs and Unions</h2>

	$(P D structs and unions are analogous to C's.
	)

	$(P C code often adjusts the alignment and packing of struct members
	with a command line switch or with various implementation specific
	#pragma's. D supports explicit alignment attributes that correspond
	to the C compiler's rules. Check what alignment the C code is using,
	and explicitly set it for the D struct declaration.
	)

	$(P D does not support bit fields. If needed, they can be emulated
	with shift and mask operations.
	$(LINK2 htod.html, htod) will convert bit fields to inline functions that
	do the right shift and masks.
	)

<h2>Object Construction and Destruction</h2>

	$(P Similarly to storage allocation and deallocation, objects
	constructed in D code should be destructed in D,
	and objects constructed
	in C++ should be destructed in C++ code.
	)

<h2>Special Member Functions</h2>

	$(P D cannot call C++ special member functions, and vice versa.
	These include constructors, destructors, conversion operators,
	operator overloading, and allocators.
	)

<h2>Runtime Type Identification</h2>

	$(P D runtime type identification
	uses completely different techniques than C++.
	The two are incompatible.)

<h2>C++ Class Objects by Value</h2>

	$(P D can access POD (Plain Old Data) C++ structs, and it can
	access C++ class virtual functions by reference.
	It cannot access C++ classes by value.
	)

<h2>C++ Templates</h2>

	$(P D templates have little in common with C++ templates,
	and it is very unlikely that any sort of reasonable method
	could be found to express C++ templates in a link-compatible
	way with D.
	)

	$(P This means that the C++ STL, and C++ Boost, likely will
	never be accessible from D.
	)

<h2>Exception Handling</h2>

	$(P D and C++ exception handling are completely different.
	Throwing exceptions across the boundaries between D
	and C++ code will likely not work.
	)

<h2>Future Developments</h2>

	$(P How the upcoming C++0x standard will affect this is not
	known.)

	$(P Over time, more aspects of the C++ ABI may be accessible
	directly from D.)

)

Macros:
	TITLE=Interfacing to C++
	WIKI=InterfaceToCPP

