Ddoc

$(D_S Converting C $(TT .h) Files to D Modules,

	While D cannot directly compile C source code, it can easily
	interface to C code, be linked with C object files, and call
	C functions in DLLs.
	The interface to C code is normally found in C $(TT .h) files.
	So, the trick to connecting with C code is in converting C
	$(TT .h) files to D modules.
	This turns out to be difficult to do mechanically since
	inevitably some human judgement must be applied.
	This is a guide to doing such conversions.

<h4>Preprocessor</h4>

	$(TT .h) files can sometimes be a bewildering morass of layers of
	macros, $(TT #include) files, $(TT #ifdef)'s, etc. D doesn't
	include a text preprocessor like the C preprocessor,
	so the first step is to remove the need for
	it by taking the preprocessed output. For DMC (the Digital
	Mars C/C++ compiler), the command:

$(CONSOLE
<a href="http://www.digitalmars.com/ctg/sc.html">dmc</a> <a href="http://www.digitalmars.com/ctg/sc.html#dashc">-c</a> program.h <a href="http://www.digitalmars.com/ctg/sc.html#dashe">-e</a> <a href="http://www.digitalmars.com/ctg/sc.html#dashl">-l</a>
)

	will create a file $(TT program.lst) which is the source file after
	all text preprocessing.
	<p>

	Remove all the $(TT #if), $(TT #ifdef), $(TT #include),
	etc. statements.

<h4>Linkage</h4>

	Generally, surround the entire module with:

---------------------------
extern (C)
{
     /* ...file contents... */
}
---------------------------

	to give it C linkage.

<h4>Types</h4>

	A little global search and replace will take care of renaming
	the C types to D types. The following table shows a typical mapping
	for 32 bit C code:
	<p>

	$(TABLE1
	<caption>Mapping C type to D type</caption>
	<tr>
	<th>C type
	<th>D type
	<tr>
	<td>long double
	<td>real
	<tr>
	<td>unsigned long long
	<td>ulong
	<tr>
	<td>long long
	<td>long
	<tr>
	<td>unsigned long
	<td>uint
	<tr>
	<td>long
	<td>int
	<tr>
	<td>unsigned
	<td>uint
	<tr>
	<td>unsigned short
	<td>ushort
	<tr>
	<td>signed char
	<td>byte
	<tr>
	<td>unsigned char
	<td>ubyte
	<tr>
	<td>wchar_t
	<td>wchar or dchar
	<tr>
	<td>bool
	<td>bool, byte, int
	<tr>
	<td>size_t
	<td>size_t
	<tr>
	<td>ptrdiff_t
	<td>ptrdiff_t
	)

<h4>NULL</h4>

	$(TT NULL) and $(TT ((void*)0)) should be replaced
	with $(TT null).

<h4>Numeric Literals</h4>

	Any 'L' or 'l' numeric literal suffixes should be removed,
	as a C $(TT long) is (usually) the same size as a D $(TT int).
	Similarly, 'LL' suffixes should be replaced with a
	single 'L'.
	Any 'u' suffix will work the same in D.

<h4>String Literals</h4>

	In most cases, any 'L' prefix to a string can just be dropped,
	as D will implicitly convert strings to wide characters if
	necessary. However, one can also replace:

$(CCODE
L"string"
)

	with:

---------------------------
"string"w	// for 16 bit wide characters
"string"d	// for 32 bit wide characters
---------------------------

<h4>Macros</h4>

	Lists of macros like:

$(CCODE
#define FOO	1
#define BAR	2
#define ABC	3
#define DEF	40
)

	can be replaced with:

---------------------------
enum
{   FOO = 1,
    BAR = 2,
    ABC = 3,
    DEF = 40
}
---------------------------

	or with:

---------------------------
const int FOO = 1;
const int BAR = 2;
const int ABC = 3;
const int DEF = 40;
---------------------------

	Function style macros, such as:

$(CCODE
#define MAX(a,b) ((a) < (b) ? (b) : (a))
)

	can be replaced with functions:

---------------------------
int MAX(int a, int b) { return (a < b) ? b : a; }
---------------------------

	<!-- Thanks to Jarrett Billingsley for the following tip -->

	The functions, however, won't work if they appear inside static
	initializers that must be evaluated at compile time rather than
	runtime. To do it at compile time, a template can be used:

$(CCODE
#define GT_DEPTH_SHIFT  (0)
#define GT_SIZE_SHIFT   (8)
#define GT_SCHEME_SHIFT (24)
#define GT_DEPTH_MASK   (0xffU << GT_DEPTH_SHIFT)
#define GT_TEXT         ((0x01) << GT_SCHEME_SHIFT)

/* Macro that constructs a graphtype */
#define GT_CONSTRUCT(depth,scheme,size) \
	((depth) | (scheme) | ((size) << GT_SIZE_SHIFT))

/* Common graphtypes */
#define GT_TEXT16  GT_CONSTRUCT(4, GT_TEXT, 16)
)

	The corresponding D version would be:

---------------------------
const uint GT_DEPTH_SHIFT  = 0;
const uint GT_SIZE_SHIFT   = 8;
const uint GT_SCHEME_SHIFT = 24;
const uint GT_DEPTH_MASK   = 0xffU << GT_DEPTH_SHIFT;
const uint GT_TEXT         = 0x01 << GT_SCHEME_SHIFT;

// Template that constructs a graphtype
template GT_CONSTRUCT(uint depth, uint scheme, uint size)
{
 // notice the name of the const is the same as that of the template
 const uint GT_CONSTRUCT = (depth | scheme | (size << GT_SIZE_SHIFT));
}

// Common graphtypes
const uint GT_TEXT16 = GT_CONSTRUCT!(4, GT_TEXT, 16);
---------------------------


<h4>Declaration Lists</h4>

	D doesn't allow declaration lists to change the type.
	Hence:

$(CCODE
int *p, q, t[3], *s;
)

	should be written as:

---------------------------
int* p, s;
int q;
int[3] t;
---------------------------

<h4>Void Parameter Lists</h4>

	Functions that take no parameters:

$(CCODE
int foo(void);
)

	are in D:

---------------------------
int foo();
---------------------------

<h4>Const Type Modifiers</h4>

	D has $(TT const) as a storage class, not a type modifier. Hence, just
	drop any $(TT const) used as a type modifier:

$(CCODE
void foo(const int *p, char *const q);
)

	becomes:

---------------------------
void foo(int* p, char* q);
---------------------------

<h4>Extern Global C Variables</h4>

	Whenever a global variable is declared in D, it is also defined.
	But if it's also defined by the C object file being linked in,
	there will be a multiple definition error. To fix this problem,
	use the extern storage class.
	For example, given a C header file named
	$(TT foo.h):

$(CCODE
struct Foo { };
struct Foo bar;
)

	It can be replaced with the D modules, $(TT foo.d):

---------------------------
struct Foo { }
extern (C)
{
    extern Foo bar;
}
---------------------------


<h4>Typedef</h4>

	$(TT alias) is the D equivalent to the C $(TT typedef):

$(CCODE
typedef int foo;
)

	becomes:

---------------------------
alias int foo;
---------------------------

<h4>Structs</h4>

	Replace declarations like:

$(CCODE
typedef struct Foo
{   int a;
    int b;
} Foo, *pFoo, *lpFoo;
)

	with:

---------------------------
struct Foo
{   int a;
    int b;
}
alias Foo* pFoo, lpFoo;
---------------------------

<h4>Struct Member Alignment</h4>

	A good D implementation by default will align struct members the
	same way as the C compiler it was designed to work with. But
	if the $(TT .h) file has some $(TT #pragma)'s to control alignment, they
	can be duplicated with the D $(TT align) attribute:

$(CCODE
#pragma pack(1)
struct Foo
{
    int a;
    int b;
};
#pragma pack()
)

	becomes:

---------------------------
struct Foo
{
  align (1):
    int a;
    int b;
}
---------------------------

<h4>Nested Structs</h4>

$(CCODE
struct Foo
{
    int a;
    struct Bar
    {
	int c;
    } bar;
};

struct Abc
{
    int a;
    struct
    {
	int c;
    } bar;
};
)

	becomes:

---------------------------
struct Foo
{
    int a;
    struct Bar
    {
	int c;
    }
    Bar bar;
}

struct Abc
{
    int a;
    struct
    {
	int c;
    }
}
---------------------------

<h4>$(TT __cdecl), $(TT __pascal), $(TT __stdcall)</h4>

$(CCODE
int __cdecl x;
int __cdecl foo(int a);
int __pascal bar(int b);
int __stdcall abc(int c);
)

	becomes:

---------------------------
extern (C) int x;
extern (C) int foo(int a);
extern (Pascal) int bar(int b);
extern (Windows) int abc(int c);
---------------------------

<h4>$(TT __declspec(dllimport))</h4>

$(CCODE
__declspec(dllimport) int __stdcall foo(int a);
)

	becomes:

---------------------------
export extern (Windows) int foo(int a);
---------------------------

<h4>$(TT __fastcall)</h4>

	Unfortunately, D doesn't support the $(TT __fastcall) convention.
	Therefore, a shim will be needed, either written in C:

$(CCODE
int __fastcall foo(int a);

int myfoo(int a)
{
    return foo(int a);
}
)

	and compiled with a C compiler that supports $(TT __fastcall) and
	linked in, or compile the above, disassemble it with
	<a href="http://www.digitalmars.com/ctg/obj2asm.html">obj2asm</a>
	and insert it in a D $(TT myfoo) shim with
	<a href="iasm.html">inline assembler</a>.

)

Macros:
	TITLE=Converting C .h Files to D Modules
	WIKI=HToModule
