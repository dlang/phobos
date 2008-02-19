Ddoc

$(SPEC_S Interfacing to C,

	$(P D is designed to fit comfortably with a C compiler for the target
	system. D makes up for not having its own VM by relying on the
	target environment's C runtime library. It would be senseless to
	attempt to port to D or write D wrappers for the vast array of C APIs
	available. How much easier it is to just call them directly.
	)

	$(P This is done by matching the C compiler's data types, layouts,
	and function call/return sequences.
	)

<h2>Calling C Functions</h2>

	$(P C functions can be called directly from D. There is no need for
	wrapper functions, argument swizzling, and the C functions do not
	need to be put into a separate DLL.
	)

	$(P The C function must be declared and given a calling convention,
	most likely the "C" calling convention, for example:
	)

------
extern (C) int strcmp(char* string1, char* string2);
------

	$(P and then it can be called within D code in the obvious way:)

------
import std.string;
int myDfunction(char[] s)
{
    return strcmp(std.string.toStringz(s), "foo");
}
------

	$(P There are several things going on here:)

	$(UL 
	$(LI D understands how C function names are "mangled" and the
	correct C function call/return sequence.)

	$(LI C functions cannot be overloaded with another C function
	with the same name.)

	$(LI There are no __cdecl, __far, __stdcall, __declspec, or other
	such C type modifiers in D. These are handled by attributes, such
	as $(TT extern (C)).)

	$(LI There are no const or volatile type modifiers in D. To declare
	a C function that uses those type modifiers, just drop those
	keywords from the declaration.)

	$(LI Strings are not 0 terminated in D. See "Data Type Compatibility"
	for more information about this. However, string literals in D are
	0 terminated.)

	)

	$(P C code can correspondingly call D functions, if the D functions
	use an attribute that is compatible with the C compiler, most likely
	the extern (C):)

------
// myfunc() can be called from any C function
extern (C)
{
    void myfunc(int a, int b)
    {
	...
    }
}
------

<h2>Storage Allocation</h2>

	$(P C code explicitly manages memory with calls to malloc() and
	free(). D allocates memory using the D garbage collector,
	so no explicit free's are necessary.
	)

	$(P D can still explicitly allocate memory using std.c.stdlib.malloc()
	and std.c.stdlib.free(), these are useful for connecting to C
	functions that expect malloc'd buffers, etc.
	)

	$(P If pointers to D garbage collector allocated memory are passed to
	C functions, it's critical to ensure that that memory will not
	be collected by the garbage collector before the C function is
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
	$(TD $(B float _Imaginary))
	)

	$(TR
	$(TD $(B idouble))
	$(TD $(B double _Imaginary))
	)

	$(TR
	$(TD $(B ireal))
	$(TD $(B long double _Imaginary))
	)

	$(TR
	$(TD $(B cfloat))
	$(TD $(B float _Complex))
	)

	$(TR
	$(TD $(B cdouble))
	$(TD $(B double _Complex))
	)

	$(TR
	$(TD $(B creal))
	$(TD $(B long double _Complex))
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

	$(P These equivalents hold for most 32 bit C compilers. The C standard
	does not pin down the sizes of the types, so some care is needed.
	)

<h2>Calling printf()</h2>

	$(P This mostly means checking that the printf format specifier
	matches the corresponding D data type.
	Although printf is designed to handle 0 terminated strings,
	not D dynamic arrays of chars, it turns out that since D
	dynamic arrays are a length followed by a pointer to the data,
	the $(TT %.*s) format works perfectly:
	)

------
void foo(char[] string)
{
    printf("my string is: %.*s\n", string);
}
------

	$(P The $(CODE printf) format string literal
	in the example doesn't end with $(CODE '\0').
	This is because string literals,
	when they are not part of an initializer to a larger data structure,
	have a $(CODE '\0') character helpfully stored after the end of them.
	)

	$(P An improved D function for formatted output is
	$(CODE std.stdio.writef()).
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

$(V1
<hr>
<h1>Interfacing to C++</h1>

	$(P D does not provide an interface to C++, other than
	through $(LINK2 ../COM.html, COM programming). Since D, however,
	interfaces directly to C, it can interface directly to
	C++ code if it is declared as having C linkage.
	)

	$(P D class objects are incompatible with C++ class objects.
	)
)

)

Macros:
	TITLE=Interfacing to C
	WIKI=InterfaceToC

