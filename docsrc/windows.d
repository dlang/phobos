Ddoc

$(D_S D for Win32,

	$(P This describes the D implementation for 32 bit Windows systems.
	Naturally,
	Windows specific D features are not portable to other platforms.
	)

	$(P Instead of the:)

$(CCODE
#include &lt;windows.h&gt;
)
	$(P of C, in D there is:)

--------------------
import std.c.windows.windows;
--------------------


<h2>Calling Conventions</h2>

	$(P In C, the Windows API calling conventions are $(CODE __stdcall).
	In D, it is simply:
	)

--------------------
extern (Windows)
{
	/* ... function declarations ... */
}
--------------------


	$(P The Windows linkage attribute sets both the calling convention
	and the name mangling scheme to be compatible with Windows.
	)

	$(P For functions that in C would be $(CODE __declspec(dllimport)) or
	$(CODE __declspec(dllexport)), use the $(CODE export) attribute:
	)

--------------------
export void func(int foo);
--------------------

	$(P If no function body is given, it's imported. If a function body
	is given, it's exported.
	)

<h2>Windows Executables</h2>

	$(P Windows GUI applications can be written with D.
	A sample such can be found in $(TT \dmd\samples\d\winsamp.d)
	)

	$(P These are required:)

	$(OL 

	$(LI Instead of a $(CODE main) function serving as the entry point,
	a $(CODE WinMain) function is needed.
	)

	$(LI $(CODE WinMain) must follow this form:
--------------------
import std.c.windows.windows;

extern (C) void gc_init();
extern (C) void gc_term();
extern (C) void _minit();
extern (C) void _moduleCtor();
extern (C) void _moduleDtor();
extern (C) void _moduleUnitTests();

extern (Windows)
int $(B WinMain)(HINSTANCE hInstance,
	HINSTANCE hPrevInstance,
	LPSTR lpCmdLine,
	int nCmdShow)
{
    int result;

    gc_init();			// initialize garbage collector
    _minit();			// initialize module constructor table

    try
    {
	_moduleCtor();		// call module constructors
	_moduleUnitTests();	// run unit tests (optional)

	result = $(B myWinMain)(hInstance, hPrevInstance, lpCmdLine, nCmdShow);

	_moduleDtor();		// call module destructors
    }

    catch (Object o)		// catch any uncaught exceptions
    {
	MessageBoxA(null, cast(char *)o.toString(), "Error",
		    MB_OK | MB_ICONEXCLAMATION);
	result = 0;		// failed
    }

    gc_term();			// run finalizers; terminate garbage collector
    return result;
}

int $(B myWinMain)(HINSTANCE hInstance,
	HINSTANCE hPrevInstance,
	LPSTR lpCmdLine,
	int nCmdShow)
{
    /* ... insert user code here ... */
}
--------------------

	The $(TT myWinMain()) function is where the user code goes, the
	rest of $(TT WinMain) is boilerplate to initialize and shut down
	the D runtime system.
	)

	$(LI A $(CODE .def)
	($(LINK2 http://www.digitalmars.com/ctg/ctgDefFiles.html, Module Definition File))
	with at least the following
	two lines in it:

$(MODDEFFILE
EXETYPE NT
SUBSYSTEM WINDOWS
)

	Without those, Win32 will open a text console window whenever
	the application is run.
	)

	$(LI The presence of $(TT WinMain()) is recognized by the compiler
		causing it to emit a reference to
		$(LINK2 http://www.digitalmars.com/ctg/acrtused.html, __acrtused_dll)
		and the phobos.lib runtime library.
	)

	)
)

Macros:
	TITLE=Windows
	WIKI=Windows
