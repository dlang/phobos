Ddoc

$(SPEC_S D Application Binary Interface,

	$(P A D implementation that conforms to the D ABI (Application Binary
	Interface)
	will be able to generate libraries, DLL's, etc., that can interoperate
	with
	D binaries built by other implementations.
	)

	$(P Most of this specification remains TBD (To Be Defined).
	)

$(SECTION3 C ABI,

	$(P The C ABI referred to in this specification means the C Application
	Binary Interface of the target system.
	C and D code should be freely linkable together, in particular, D
	code shall have access to the entire C ABI runtime library.
	)
)

$(SECTION3 Basic Types,

	$(P TBD)
)

$(SECTION3 Structs,

	$(P Conforms to the target's C ABI struct layout.)
)

$(SECTION3 Classes,

	$(P An object consists of:)

$(TABLE1
$(TR $(TH offset)		$(TH contents))
$(TR $(TD 0)			$(TD pointer to vtable))
$(TR $(TD $(I ptrsize))		$(TD monitor))
$(TR $(TD $(I ptrsize*2)...)	$(TD non-static members))
)

	$(P The vtable consists of:)

$(TABLE1
$(TR $(TH offset)		$(TH contents))
$(TR $(TD 0)			$(TD pointer to instance of ClassInfo))
$(TR $(TD $(I ptrsize)...)	$(TD pointers to virtual member functions))
)

	$(P The class definition:)

---------
class XXXX
{
    ....
};
---------

	$(P Generates the following:)

	$(UL
	$(LI An instance of Class called ClassXXXX.)

	$(LI A type called StaticClassXXXX which defines all the static members.)

	$(LI An instance of StaticClassXXXX called StaticXXXX for the static members.)
	)
)

$(SECTION3 Interfaces,

	$(P TBD)
)

$(SECTION3 Arrays,

	$(P A dynamic array consists of:)

$(TABLE1
$(TR $(TH offset) $(TH contents))
$(TR $(TD  0)	$(TD  array dimension))
$(TR $(TD  $(I size_t))	$(TD  pointer to array data))
)

	$(P A dynamic array is declared as:)

---------
type[] array;
---------

	$(P whereas a static array is declared as:)

---------
type[dimension] array;
---------

	$(P Thus, a static array always has the dimension statically available as part of the type, and
	so it is implemented like in C. Static array's and Dynamic arrays can be easily converted back
	and forth to each other.
	)
)

$(SECTION3 Associative Arrays,

	$(P Associative arrays consist of a pointer to an opaque, implementation
	defined type.
	The current implementation is contained in phobos/internal/aaA.d.
	)
)

$(SECTION3 Reference Types,

	$(P D has reference types, but they are implicit. For example, classes are always
	referred to by reference; this means that class instances can never reside on the stack
	or be passed as function parameters.
	)

	$(P When passing a static array to a function, the result, although declared as a static array, will
	actually be a reference to a static array. For example:
	)

---------
int[3] abc;
---------

	$(P Passing abc to functions results in these implicit conversions:)

---------
void func(int[3] array); // actually <reference to><array[3] of><int>
void func(int* p);       // abc is converted to a pointer
			 // to the first element
void func(int[] array);	 // abc is converted to a dynamic array
---------
)


$(SECTION3 Name Mangling,

	$(P D accomplishes typesafe linking by $(I mangling) a D identifier
	to include scope and type information.
	)

$(GRAMMAR
$(I MangledName):
    $(B _D) $(I QualifiedName) $(I Type)
    $(B _D) $(I QualifiedName) $(B M) $(I Type)

$(I QualifiedName):
    $(I SymbolName)
    $(I SymbolName) $(I QualifiedName)

$(I SymbolName):
    $(I LName)
    $(I TemplateInstanceName)
)

	$(P The $(B M) means that the symbol is a function that requires
	a $(TT this) pointer.)

	$(P Template Instance Names have the types and values of its parameters
	encoded into it:
	)

$(GRAMMAR
$(I TemplateInstanceName):
    $(Number) $(B __T) $(I LName) $(I TemplateArgs) $(B Z)

$(I TemplateArgs):
    $(I TemplateArg)
    $(I TemplateArg) $(I TemplateArgs)

$(I TemplateArg):
    $(B T) $(I Type)
    $(B V) $(I Type) $(I Value)
    $(B S) $(I LName)

$(I Value):
    $(B n)
    $(I Number)
    $(B N) $(I Number)
    $(B e) $(I HexFloat)
    $(B c) $(I HexFloat) $(B c) $(I HexFloat)
    $(B A) $(I Number) $(I Value)...

$(I HexFloat):
    $(B NAN)
    $(B INF)
    $(B NINF)
    $(B N) $(I HexDigits) $(B P) $(I Exponent)
    $(I HexDigits) $(B P) $(I Exponent)

$(I Exponent):
    $(B N) $(I Number)
    $(I Number)

$(I HexDigits):
    $(I HexDigit)
    $(I HexDigit) $(I HexDigits)

$(I HexDigit):
    $(I Digit)
    $(B A)
    $(B B)
    $(B C)
    $(B D)
    $(B E)
    $(B F)
)

$(DL
	$(DT $(I n))
	$(DD is for $(B null) arguments.)

	$(DT $(I Number))
	$(DD is for positive numeric literals (including
	character literals).)

	$(DT $(B N) $(I Number))
	$(DD is for negative numeric literals.)

	$(DT $(B e) $(I HexFloat))
	$(DD is for real and imaginary floating point literals.)

	$(DT $(B c) $(I HexFloat) $(B c) $(I HexFloat))
	$(DD is for complex floating point literals.)

	$(DT $(I Width) $(I Number) $(B _) $(I HexDigits))
	$(DD $(I Width) is whether the characters
	are 1 byte ($(B a)), 2 bytes ($(B w)) or 4 bytes ($(B d)) in size.
	$(I Number) is the number of characters in the string.
	The $(I HexDigits) are the hex data for the string.
	)

	$(DT $(B A) $(I Number) $(I Value)...)
	$(DD An array literal. $(I Value) is repeated $(I Number) times.
	)
)

$(GRAMMAR
$(I Name):
    $(I Namestart)
    $(I Namestart) $(I Namechars)

$(I Namestart):
    $(B _)
    $(I Alpha)

$(I Namechar):
    $(I Namestart)
    $(I Digit)

$(I Namechars):
    $(I Namechar)
    $(I Namechar) $(I Namechars)
)

	$(P A $(I Name) is a standard D identifier.)

$(GRAMMAR
$(I LName):
    $(I Number) $(I Name)

$(I Number):
    $(I Digit)
    $(I Digit) $(I Number)

$(I Digit):
    $(B 0)
    $(B 1)
    $(B 2)
    $(B 3)
    $(B 4)
    $(B 5)
    $(B 6)
    $(B 7)
    $(B 8)
    $(B 9)
)

	$(P An $(I LName) is a name preceded by a $(I Number) giving
	the number of characters in the $(I Name).
	)
)

$(SECTION3 Type Mangling,

	$(P Types are mangled using a simple linear scheme:)

$(GRAMMAR
$(I Type):
    $(I Const)
    $(I Invariant)
    $(I TypeArray)
    $(I TypeSarray)
    $(I TypeAarray)
    $(I TypePointer)
    $(I TypeFunction)
    $(I TypeIdent)
    $(I TypeClass)
    $(I TypeStruct)
    $(I TypeEnum)
    $(I TypeTypedef)
    $(I TypeDelegate)
    $(I TypeNone)
    $(I TypeVoid)
    $(I TypeByte)
    $(I TypeUbyte)
    $(I TypeShort)
    $(I TypeUshort)
    $(I TypeInt)
    $(I TypeUint)
    $(I TypeLong)
    $(I TypeUlong)
    $(I TypeFloat)
    $(I TypeDouble)
    $(I TypeReal)
    $(I TypeIfloat)
    $(I TypeIdouble)
    $(I TypeIreal)
    $(I TypeCfloat)
    $(I TypeCdouble)
    $(I TypeCreal)
    $(I TypeBool)
    $(I TypeChar)
    $(I TypeWchar)
    $(I TypeDchar)
    $(I TypeTuple)

$(I Const):
    $(B x) $(I Type)

$(I Invariant):
    $(B y) $(I Type)

$(I TypeArray):
    $(B A) $(I Type)

$(I TypeSarray):
    $(B G) $(I Number) $(I Type)

$(I TypeAarray):
    $(B H) $(I Type) $(I Type)

$(I TypePointer):
    $(B P) $(I Type)

$(I TypeFunction):
    $(I CallConvention) $(I Arguments) $(I ArgClose) $(I Type)

$(I CallConvention):
    $(B F)
    $(B U)
    $(B W)
    $(B V)
    $(B R)

$(I Arguments):
    $(I Argument)
    $(I Argument) $(I Arguments)

$(I Argument:)
    $(I Type)
    $(B J) $(I Type)
    $(B K) $(I Type)
    $(B L) $(I Type)

$(I ArgClose)
    $(B X)
    $(B Y)
    $(B Z)

$(I TypeIdent):
    $(B I) $(I LName)

$(I TypeClass):
    $(B C) $(I LName)

$(I TypeStruct):
    $(B S) $(I LName)

$(I TypeEnum):
    $(B E) $(I LName)

$(I TypeTypedef):
    $(B T) $(I LName)

$(I TypeDelegate):
    $(B D) $(I TypeFunction)

$(I TypeNone):
    $(B n)

$(I TypeVoid):
    $(B v)

$(I TypeByte):
    $(B g)

$(I TypeUbyte):
    $(B h)

$(I TypeShort):
    $(B s)

$(I TypeUshort):
    $(B t)

$(I TypeInt):
    $(B i)

$(I TypeUint):
    $(B k)

$(I TypeLong):
    $(B l)

$(I TypeUlong):
    $(B m)

$(I TypeFloat):
    $(B f)

$(I TypeDouble):
    $(B d)

$(I TypeReal):
    $(B e)

$(I TypeIfloat):
    $(B o)

$(I TypeIdouble):
    $(B p)

$(I TypeIreal):
    $(B j)

$(I TypeCfloat):
    $(B q)

$(I TypeCdouble):
    $(B r)

$(I TypeCreal):
    $(B c)

$(I TypeBool):
    $(B b)

$(I TypeChar):
    $(B a)

$(I TypeWchar):
    $(B u)

$(I TypeDchar):
    $(B w)

$(I TypeTuple):
    $(B B) $(I Number) $(I Arguments)
)
)

$(SECTION3 Function Calling Conventions,

	$(P The extern (C) calling convention matches the C calling convention
	used by the supported C compiler on the host system.
	The extern (D) calling convention for x86 is described here.)

$(SECTION4 Register Conventions,

	$(UL

	$(LI EAX, ECX, EDX are scratch registers and can be destroyed
	by a function.)

	$(LI EBX, ESI, EDI, EBP must be preserved across function calls.)

	$(LI EFLAGS is assumed destroyed across function calls, except
	for the direction flag which must be forward.)

	$(LI The FPU stack must be empty when calling a function.)

	$(LI The FPU control word must be preserved across function calls.)

	$(LI Floating point return values are returned on the FPU stack.
	These must be cleaned off by the caller, even if they are not used.)

	)
)

$(SECTION4 Return Value,

	$(UL

	$(LI The types bool, byte, ubyte, short, ushort, int, uint,
	pointer, Object, and interfaces
	are returned in EAX.)

	$(LI long and ulong
	are returned in EDX,EAX, where EDX gets the most significant
	half.)

	$(LI float, double, real, ifloat, idouble, ireal are returned
	in ST0.)

	$(LI cfloat, cdouble, creal are returned in ST1,ST0 where ST1
	is the real part and ST0 is the imaginary part.)

	$(LI Dynamic arrays are returned with the pointer in EDX
	and the length in EAX.)

	$(LI Associative arrays are returned in EAX with garbage
	returned in EDX. The EDX value will probably be removed in
	the future; it's there for backwards compatibility with
	an earlier implementation of AA's.)

	$(LI Delegates are returned with the pointer to the function
	in EDX and the context pointer in EAX.)

	$(LI For Windows, 1, 2 and 4 byte structs are returned in EAX.)

	$(LI For Windows, 8 byte structs are returned in EDX,EAX, where
	EDX gets the most significant half.)

	$(LI For other struct sizes, and for all structs on Linux,
	the return value is stored through a hidden pointer passed as
	an argument to the function.)

	$(LI Constructors return the this pointer in EAX.)

	)
)

$(SECTION4 Parameters,

	$(P The parameters to the non-variadic function:)

---
	foo(a1, a2, ..., an);
---

	$(P are passed as follows:)

	$(TABLE
	$(TR $(TD a1))
	$(TR $(TD a2))
	$(TR $(TD ...))
	$(TR $(TD an))
	$(TR $(TD hidden))
	$(TR $(TD this))
	)

	$(P where $(I hidden) is present if needed to return a struct
	value, and $(I this) is present if needed as the this pointer
	for a member function or the context pointer for a nested
	function.)

	$(P The last parameter is passed in EAX rather than being pushed
	on the stack if the following conditions are met:)

	$(UL
	$(LI It fits in EAX.)
	$(LI It is not a 3 byte struct.)
	$(LI It is not a floating point type.)
	)

	$(P Parameters are always pushed as multiples of 4 bytes,
	rounding upwards,
	so the stack is always aligned on 4 byte boundaries.
	They are pushed most significant first.
	$(B out) and $(B ref) are passed as pointers.
	Static arrays are passed as pointers to their first element.
	On Windows, a real is pushed as a 10 byte quantity,
	a creal is pushed as a 20 byte quantity.
	On Linux, a real is pushed as a 12 byte quantity,
	a creal is pushed as two 12 byte quantities.
	The extra two bytes of pad occupy the 'most significant' position.
	)

	$(P The callee cleans the stack.)

	$(P The parameters to the variadic function:)

---
	void foo(int p1, int p2, int[] p3...)
	foo(a1, a2, ..., an);
---

	$(P are passed as follows:)

	$(TABLE
	$(TR $(TD p1))
	$(TR $(TD p2))
	$(TR $(TD a3))
	$(TR $(TD hidden))
	$(TR $(TD this))
	)

	$(P The variadic part is converted to a dynamic array and the
	rest is the same as for non-variadic functions.)

	$(P The parameters to the variadic function:)

---
	void foo(int p1, int p2, ...)
	foo(a1, a2, a3, ..., an);
---

	$(P are passed as follows:)

	$(TABLE
	$(TR $(TD an))
	$(TR $(TD ...))
	$(TR $(TD a3))
	$(TR $(TD a2))
	$(TR $(TD a1))
	$(TR $(TD _arguments))
	$(TR $(TD hidden))
	$(TR $(TD this))
	)

	$(P The caller is expected to clean the stack.
	$(B _argptr) is not
	passed, it is computed by the callee.)
)
)

$(SECTION3 Exception Handling,

    $(SECTION4 Windows,

	$(P Conforms to the Microsoft Windows Structured Exception Handling
	conventions.
	)
    )

    $(SECTION4 Linux,

	$(P Uses static address range/handler tables.
	TBD
	)
    )
)

$(SECTION3 Garbage Collection,

	$(P The interface to this is found in $(TT phobos/internal/gc).)
)

$(SECTION3 Runtime Helper Functions,

	$(P These are found in $(TT phobos/internal).)
)

$(SECTION3 Module Initialization and Termination,

	$(P TBD)
)

$(SECTION3 Unit Testing,

	$(P TBD)
)

$(SECTION2 Symbolic Debugging,

	$(P D has types that are not represented in existing C or C++ debuggers.
	These are dynamic arrays, associative arrays, and delegates.
	Representing these types as structs causes problems because function
	calling conventions for structs are often different than that for
	these types, which causes C/C++ debuggers to misrepresent things.
	For these debuggers, they are represented as a C type which
	does match the calling conventions for the type.
	The $(B dmd) compiler will generate only C symbolic type info with the
	$(B -gc) compiler switch.
	)

	$(TABLE1
	<caption>Types for C Debuggers</caption>
	$(TR
	$(TH D type)
	$(TH C representation)
	)
	$(TR
	$(TD dynamic array)
	$(TD unsigned long long)
	)
	$(TR
	$(TD associative array)
	$(TD void*)
	)
	$(TR
	$(TD delegate)
	$(TD long long)
	)
	$(TR
	$(TD dchar)
	$(TD unsigned long)
	)
	)

	$(P For debuggers that can be modified to accept new types, the
	following extensions help them fully support the types.
	)

$(SECTION3 <a name="codeview">Codeview Debugger Extensions</a>,

	$(P The D $(B dchar) type is represented by the special
	primitive type 0x78.)

	$(P D makes use of the Codeview OEM generic type record
	indicated by $(B LF_OEM) (0x0015). The format is:)

	$(TABLE1
	<caption>Codeview OEM Extensions for D</caption>
	$(TR
	$(TD field size)
	$(TD 2)
	$(TD 2)
	$(TD 2)
	$(TD 2)
	$(TD 2)
	$(TD 2)
	)
	$(TR
	$(TH D Type)
	$(TH Leaf Index)
	$(TH OEM Identifier)
	$(TH recOEM)
	$(TH num indices)
	$(TH type index)
	$(TH type index)
	)
	$(TR
	$(TD dynamic array)
	$(TD LF_OEM)
	$(TD $(I OEM))
	$(TD 1)
	$(TD 2)
	$(TD @$(I index))
	$(TD @$(I element))
	)
	$(TR
	$(TD associative array)
	$(TD LF_OEM)
	$(TD $(I OEM))
	$(TD 2)
	$(TD 2)
	$(TD @$(I key))
	$(TD @$(I element))
	)
	$(TR
	$(TD delegate)
	$(TD LF_OEM)
	$(TD $(I OEM))
	$(TD 3)
	$(TD 2)
	$(TD @$(I this))
	$(TD @$(I function))
	)
	)

	$(BR) $(BR)

	$(TABLE
	$(TR
	$(TD $(I OEM))
	$(TD 0x42)
	)
	$(TR
	$(TD $(I index))
	$(TD type index of array index)
	)
	$(TR
	$(TD $(I key))
	$(TD type index of key)
	)
	$(TR
	$(TD $(I element))
	$(TD type index of array element)
	)
	$(TR
	$(TD $(I this))
	$(TD type index of context pointer)
	)
	$(TR
	$(TD $(I function))
	$(TD type index of function)
	)
	)

	$(P These extensions can be pretty-printed
	by $(LINK2 http://www.digitalmars.com/ctg/obj2asm.html, obj2asm).

	$(P The $(LINK2 http://ddbg.mainia.de/releases.html, Ddbg) debugger
	supports them.)
	)
)

$(SECTION3 <a name="dwarf">Dwarf Debugger Extensions</a>,
	$(P The following leaf types are added:)

	$(TABLE1
	<caption>Dwarf Extensions for D</caption>
	$(TR
	$(TH D type)
	$(TH Identifier)
	$(TH Value)
	$(TH Format)
	)
	$(TR
	$(TD dynamic array)
	$(TD DW_TAG_darray_type)
	$(TD 0x41)
	$(TD DW_AT_type is element type)
	)
	$(TR
	$(TD associative array)
	$(TD DW_TAG_aarray_type)
	$(TD 0x42)
	$(TD DW_AT_type, is element type, DW_AT_containing_type key type)
	)
	$(TR
	$(TD delegate)
	$(TD DW_TAG_delegate_type)
	$(TD 0x43)
	$(TD DW_AT_type, is function type, DW_AT_containing_type is 'this' type)
	)
	)

	$(P These extensions can be pretty-printed
	by $(LINK2 http://www.digitalmars.com/ctg/dumpobj.html, dumpobj).

	$(P The $(LINK2 http://www.zerobugs.org, ZeroBUGS)
	debugger supports them.)
	)
)


)

)

Macros:
	TITLE=Application Binary Interface
	WIKI=ABI

