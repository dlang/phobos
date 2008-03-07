Ddoc

$(D_S Writing Win32 DLLs in D,

	$(P DLLs (Dynamic Link Libraries) are one of the foundations
	of system programming for Windows. The D programming
	language enables the creation of several different types of
	DLLs.
	)

	$(P For background information on what DLLs are and how they work
	Chapter 11 of Jeffrey Richter's book
	$(LINK2 http://www.amazon.com/exec/obidos/ASIN/1572315482/classicempire,
	Advanced Windows) is indispensible.
	)

	$(P This guide will show how to create DLLs of various types with D.)

	$(UL 
	$(LI <a href="#Cinterface">DLLs with a C interface</a>)
	$(LI <a href="#com">DLLs that are COM servers</a>)
	$(LI <a href="#Dcode">D code calling D code in DLLs</a>)
	)

<h2><a name="Cinterface">DLLs with a C Interface</a></h2>

	$(P A DLL presenting a C interface can connect to any other code
	in a language that supports calling C functions in a DLL.
	)

	$(P DLLs can be created in D in roughly the same way as in C.
	A $(TT DllMain())
	is required, looking like:
	)

--------------------------------
import std.c.windows.windows;
HINSTANCE g_hInst;

extern (C)
{
	void gc_init();
	void gc_term();
	void _minit();
	void _moduleCtor();
	void _moduleUnitTests();
}

extern (Windows)
BOOL $(B DllMain)(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
	case DLL_PROCESS_ATTACH:
	    gc_init();			// initialize GC
	    _minit();			// initialize module list
	    _moduleCtor();		// run module constructors
	    _moduleUnitTests();		// run module unit tests
	    break;

	case DLL_PROCESS_DETACH:
	    gc_term();			// shut down GC
	    break;

	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	    // Multiple threads not supported yet
	    return false;
    }
    g_hInst=hInstance;
    return true;
}
-------------------------------

	$(P Notes:)
	$(UL 
	$(LI The $(CODE _moduleUnitTests()) call is optional.)
	$(LI The presence of $(TT DllMain()) is recognized by the compiler
		causing it to emit a reference to
		$(LINK2 http://www.digitalmars.com/ctg/acrtused.html, __acrtused_dll)
		and the $(TT phobos.lib) runtime library.)
	)

	Link with a .def
	(<a href="http://www.digitalmars.com/ctg/ctgDefFiles.html">Module Definition File</a>)
	along the lines of:

$(MODDEFFILE
LIBRARY         MYDLL
DESCRIPTION     'My DLL written in D'

EXETYPE		NT
CODE            PRELOAD DISCARDABLE
DATA            PRELOAD SINGLE

EXPORTS
		DllGetClassObject       @2
		DllCanUnloadNow         @3
		DllRegisterServer       @4
		DllUnregisterServer     @5
)

	$(P The functions in the EXPORTS list are for illustration.
	Replace them with the actual exported functions from MYDLL.
	Alternatively, use
	$(LINK2 http://www.digitalmars.com/ctg/implib.html, implib).
	Here's an example of a simple DLL with a function print()
	which prints a string:
	)

	<h4>mydll2.d:</h4>
-------------------------------
module mydll;
export void dllprint() { printf("hello dll world\n"); }
-------------------------------

	$(P Note: We use $(CODE printf)s in these examples
	instead of $(CODE writefln)
	to make the examples as
	simple as possible.)

	<h4>mydll.def:</h4>

$(MODDEFFILE
LIBRARY "mydll.dll"
EXETYPE NT
SUBSYSTEM WINDOWS
CODE SHARED EXECUTE
DATA WRITE
)

	$(P Put the code above that contains $(CODE DllMain()) into a file
	$(TT dll.d).
	Compile and link the dll with the following command:
	)

$(CONSOLE
C:>dmd -ofmydll.dll mydll2.d dll.d mydll.def
C:>implib/system mydll.lib mydll.dll
C:>
)

	$(P which will create mydll.dll and mydll.lib.
	Now for a program, test.d, which will use the dll:
	)

	<h4>test.d:</h4>
-------------------------------
import mydll;

int main()
{
   mydll.dllprint();
   return 0;
}
-------------------------------

	$(P Create a clone of mydll2.d that doesn't have the function bodies:)

	<h4>mydll.d:</h4>
-------------------------------
export void dllprint();
-------------------------------

	Compile and link with the command:

$(CONSOLE
C:>dmd test.d mydll.lib
C:>
)

	and run:
$(CONSOLE
C:>test
hello dll world
C:>
)



<h3>Memory Allocation</h3>

	$(P D DLLs use garbage collected memory management. The question is what
	happens when pointers to allocated data cross DLL boundaries?
	If the DLL presents a C interface, one would assume the reason
	for that is to connect with code written in other languages.
	Those other languages will not know anything about D's memory
	management. Thus, the C interface will have to shield the
	DLL's callers from needing to know anything about it.
	)

	$(P There are many approaches to solving this problem:)

	$(UL 

	$(LI Do not return pointers to D gc allocated memory to the caller of
	the DLL. Instead, have the caller allocate a buffer, and have the DLL
	fill in that buffer.)

	$(LI Retain a pointer to the data within the D DLL so the GC will not free
	it. Establish a protocol where the caller informs the D DLL when it is
	safe to free the data.)

	$(LI Use operating system primitives like VirtualAlloc() to allocate
	memory to be transferred between DLLs.)

	$(LI Use std.c.stdlib.malloc() (or another non-gc allocator) when
	allocating data to be returned to the caller. Export a function
	that will be used by the caller to free the data.)

	)

<h2><a name="com">COM Programming</a></h2>

	Many Windows API interfaces are in terms of COM (Common Object Model)
	objects (also called OLE or ActiveX objects). A COM object is an object
	who's first field is a pointer to a vtbl[], and the first 3 entries
	in that vtbl[] are for QueryInterface(), AddRef(), and Release().
	<p>

	For understanding COM, Kraig Brockshmidt's
	<a href="http://www.amazon.com/exec/obidos/ASIN/1556158432/classicempire">
	Inside OLE</a>
	is an indispensible resource.
	<p>

	COM objects are analogous to D interfaces. Any COM object can be
	expressed as a D interface, and every D object with an interface X
	can be exposed as a COM object X.
	This means that D is compatible with COM objects implemented
	in other languages.
	<p>

	While not strictly necessary, the Phobos library provides an Object
	useful as a super class for all D COM objects, called ComObject.
	ComObject provides a default implementation for
	QueryInterface(), AddRef(), and Release().
	<p>

	Windows COM objects use the Windows calling convention, which is not
	the default for D, so COM functions need to have the attribute
	extern (Windows).

	So, to write a COM object:

-------------------------------
import std.c.windows.com;

class MyCOMobject : ComObject
{
    extern (Windows):
	...
}
-------------------------------

	The sample code includes an example COM client program and server DLL.

<h2><a name="Dcode">D code calling D code in DLLs</a></h2>

	Having DLLs in D be able to talk to each other as if they
	were statically linked together is, of course, very desirable
	as code between applications can be shared, and different
	DLLs can be independently developed.
	<p>

	The underlying difficulty is what to do about garbage collection (gc).
	Each EXE and DLL will have their own gc instance. While
	these gc's can coexist without stepping on each other,
	it's redundant and inefficient to have multiple gc's running.
	The idea explored here is to pick one gc and have the DLLs
	redirect their gc's to use that one. The one gc used here will be
	the one in the EXE file, although it's also possible to make a
	separate DLL just for the gc.
	<p>

	The example will show both how to statically load a DLL, and
	to dynamically load/unload it.
	<p>

	Starting with the code for the DLL, mydll.d:
-------------------------------
/*
 * MyDll demonstration of how to write D DLLs.
 */

import std.c.stdio;
import std.c.stdlib;
import std.string;
import std.c.windows.windows;
import std.gc;

HINSTANCE   g_hInst;

extern (C)
{
	void _minit();
	void _moduleCtor();
	void _moduleDtor();
	void _moduleUnitTests();
}

extern (Windows)
    BOOL $(B DllMain)(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
	    printf("DLL_PROCESS_ATTACH\n");
	    break;

        case DLL_PROCESS_DETACH:
	    printf("DLL_PROCESS_DETACH\n");
	    $(B std.c.stdio._fcloseallp = null;) // so stdio doesn't get closed
	    break;

        case DLL_THREAD_ATTACH:
	    printf("DLL_THREAD_ATTACH\n");
	    return false;

        case DLL_THREAD_DETACH:
	    printf("DLL_THREAD_DETACH\n");
	    return false;
    }
    g_hInst = hInstance;
    return true;
}

export void $(B MyDLL_Initialize)(void* gc)
{
    printf("MyDLL_Initialize()\n");
    std.gc.setGCHandle(gc);
    _minit();
    _moduleCtor();
//  _moduleUnitTests();
}

export void $(B MyDLL_Terminate)()
{
    printf("MyDLL_Terminate()\n");
    _moduleDtor();			// run module destructors
    std.gc.endGCHandle();
}

$(B static this)()
{
    printf("static this for mydll\n");
}

$(B static ~this)()
{
    printf("static ~this for mydll\n");
}

/* --------------------------------------------------------- */

class $(B MyClass)
{
    char[] $(B concat)(char[] a, char[] b)
    {
	return a ~ " " ~ b;
    }

    void $(B free)(char[] s)
    {
	delete s;
    }
}

export MyClass $(B getMyClass)()
{
    return new MyClass();
}
-------------------------------

	<dl>
	<dt>$(B DllMain)
	<dd>This is the main entry point for any D DLL. It gets called
	by the C startup code
	(for DMC++, the source is $(TT \dm\src\win32\dllstart.c)).
	The $(B printf)'s are placed there so one can trace how it gets
	called.
	Notice that the initialization and termination code seen in
	the earlier DllMain sample code isn't there.
	This is because the initialization will depend on who is loading
	the DLL, and how it is loaded (statically or dynamically).
	There isn't much to do here.
	The only oddity is the setting of $(B std.c.stdio._fcloseallp) to
	null. If this is not set to null, the C runtime will flush
	and close all the standard I/O buffers (like $(B stdout),
	$(B stderr), etc.)
	shutting off further output. Setting it to null defers the
	responsibility for that to the caller of the DLL.
	<p>

	<dt>$(B MyDLL_Initialize)
	<dd>So instead we'll have our own DLL initialization routine so
	exactly when it is called can be controlled.
	It must be called after the caller has initialized itself,
	the Phobos runtime library, and the module constructors
	(this would normally be by the time $(B main)() was entered).
	This function takes one argument, a handle to the
	caller's gc. We'll see how that handle is obtained later.
	Instead of $(B gc_init)() being called to initialize
	the DLL's gc, $(B std.gc.setGCHandle)() is called and passed the
	handle to which gc to use.
	This step informs the caller's gc
	which data areas of the DLL to scan.
	Afterwards follows the call to the $(B _minit)() to initialize the
	module tables, and $(B _moduleCtor)() to run the module constructors.
	$(B _moduleUnitTests)() is optional and runs the DLL's unit tests.
	The function is $(B export)ed as that is how a function is made
	visible outside of a DLL.
	<p>

	<dt>$(B MyDLL_Terminate)
	<dd>Correspondingly, this function terminates the DLL, and is
	called prior to unloading it.
	It has two jobs; calling the DLL's module destructors via
	$(B _moduleDtor()) and informing the runtime that
	the DLL will no longer be using the caller's gc via
	$(B std.gc.endGCHandle)().
	That last step is critical, as the DLL will be unmapped from
	memory, and if the gc continues to scan its data areas it will
	cause segment faults.
	<p>

	<dt>$(B static this, static ~this)
	<dd>These are examples of the module's static constructor
	and destructor,
	here with a print in each to verify that they are running
	and when.
	<p>

	<dt>$(B MyClass)
	<dd>This is an example of a class that can be exported from
	and used by the caller of a DLL. The $(B concat) member
	function allocates some gc memory, and $(B free) frees gc
	memory.
	<p>

	<dt>$(B getMyClass)
	<dd>An exported factory that allocates an instance of $(B MyClass)
	and returns a reference to it.
	<p>

	</dl>

	To build the $(TT mydll.dll) DLL:

	$(OL 
	$(LI$(B $(TT dmd -c mydll -g))
	<br>Compiles $(TT mydll.d) into $(TT mydll.obj).
	$(B -g) turns on debug info generation.
	)

	$(LI $(B $(TT dmd mydll.obj \dmd\lib\gcstub.obj mydll.def -g -L/map))
	<br>Links $(TT mydll.obj) into a DLL named $(TT mydll.dll).
	$(TT gcstub.obj) is not required, but it prevents the bulk
	of the gc code from being linked in, since it will not be used
	anyway. It saves about 12Kb.
	$(TT mydll.def) is the
	<a href="http://www.digitalmars.com/ctg/ctgDefFiles.html">Module Definition File</a>,
	and has the contents:

$(MODDEFFILE
LIBRARY         MYDLL
DESCRIPTION     'MyDll demonstration DLL'
EXETYPE		NT
CODE            PRELOAD DISCARDABLE
DATA            PRELOAD SINGLE
)
	$(B -g) turns on debug info generation, and
	$(B -L/map) generates a map file $(TT mydll.map).
	)

	$(LI $(B $(TT implib /noi /system mydll.lib mydll.dll))
	<br>Creates an
	<a href="http://www.digitalmars.com/ctg/implib.html">import library</a>
	$(TT mydll.lib) suitable
	for linking in with an application that will be statically
	loading $(TT mydll.dll).
	)

	)

	$(P Here's $(TT test.d), a sample application that makes use of
	$(TT mydll.dll). There are two versions, one statically binds to
	the DLL, and the other dynamically loads it.
	)

-------------------------------
import std.stdio;
import std.gc;

import mydll;

//version=DYNAMIC_LOAD;

version (DYNAMIC_LOAD)
{
    import std.c.windows.windows;

    alias void function(void*) MyDLL_Initialize_fp;
    alias void function() MyDLL_Terminate_fp;
    alias MyClass function() getMyClass_fp;

    int main()
    {	HMODULE h;
	FARPROC fp;
	MyDLL_Initialize_fp mydll_initialize;
	MyDLL_Terminate_fp  mydll_terminate;

	getMyClass_fp  getMyClass;
	MyClass c;

	printf("Start Dynamic Link...\n");

	h = LoadLibraryA("mydll.dll");
	if (h == null)
	{   printf("error loading mydll.dll\n");
	    return 1;
	}

	fp = GetProcAddress(h, "D5mydll16MyDLL_InitializeFPvZv");
	if (fp == null)
	{   printf("error loading symbol MyDLL_Initialize()\n");
	    return 1;
	}

	mydll_initialize = cast(MyDLL_Initialize_fp) fp;
	(*mydll_initialize)(std.gc.getGCHandle());

	fp = GetProcAddress(h, "D5mydll10getMyClassFZC5mydll7MyClass");
	if (fp == null)
	{   printf("error loading symbol getMyClass()\n");
	    return 1;
	}

	getMyClass = cast(getMyClass_fp) fp;
	c = (*getMyClass)();
	foo(c);

	fp = GetProcAddress(h, "D5mydll15MyDLL_TerminateFZv");
	if (fp == null)
	{   printf("error loading symbol MyDLL_Terminate()\n");
	    return 1;
	}

	mydll_terminate = cast(MyDLL_Terminate_fp) fp;
	(*mydll_terminate)();

	if (FreeLibrary(h) == FALSE)
	{   printf("error freeing mydll.dll\n");
	    return 1;
	}

	printf("End...\n");
	return 0;
    }
}
else
{   // static link the DLL

    int main()
    {
	printf("Start Static Link...\n");
	MyDLL_Initialize(std.gc.getGCHandle());
	foo(getMyClass());
	MyDLL_Terminate();
	printf("End...\n");
	return 0;
    }
}

void foo(MyClass c)
{
    char[] s;

    s = c.concat("Hello", "world!");
    writefln(s);
    c.free(s);
    delete c;
}
-------------------------------

	$(P Let's start with the statically linked version, which is simpler.
	It's compiled and linked with the command:
	)

$(CONSOLE
C:>dmd test mydll.lib -g
)

	$(P Note how it is linked with $(TT mydll.lib), the import library
	for $(TT mydll.dll).
	The code is straightforward, it initializes $(TT mydll.lib) with
	a call to $(B MyDLL_Initialize)(), passing the handle
	to $(TT test.exe)'s gc.
	Then, we can use the DLL and call its functions just as if
	it were part of $(TT test.exe). In $(B foo)(), gc memory
	is allocated and freed both by $(TT test.exe) and $(TT mydll.dll).
	When we're done using the DLL, it is terminated with
	$(B MyDLL_Terminate)().
	)

	$(P Running it looks like this:)

$(CONSOLE
C:>test
DLL_PROCESS_ATTACH
Start Static Link...
MyDLL_Initialize()
static this for mydll
Hello world!
MyDLL_Terminate()
static ~this for mydll
End...
C:>
)

	$(P The dynamically linked version is a little harder to set up.
	Compile and link it with the command:
	)

$(CONSOLE
C:>dmd test -version=DYNAMIC_LOAD -g
)
	$(P The import library $(TT mydll.lib) is not needed.
	The DLL is loaded with a call to
	$(B LoadLibraryA)(),
	and each exported function has to be retrieved via
	a call to
	$(B GetProcAddress)().
	An easy way to get the decorated name to pass to $(B GetProcAddress)()
	is to copy and paste it from the generated $(TT mydll.map) file
	under the $(B Export) heading.
	Once this is done, we can use the member functions of the
	DLL classes as if they were part of $(TT test.exe).
	When done, release the DLL with
	$(B FreeLibrary)().
	)

	$(P Running it looks like this:)

$(CONSOLE
C:>test
Start Dynamic Link...
DLL_PROCESS_ATTACH
MyDLL_Initialize()
static this for mydll
Hello world!
MyDLL_Terminate()
static ~this for mydll
DLL_PROCESS_DETACH
End...
C:>
)

)

Macros:
	TITLE=Writing Win32 DLLs
	WIKI=DLLs
