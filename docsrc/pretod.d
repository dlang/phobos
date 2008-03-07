Ddoc

$(COMMUNITY The C Preprocessor Versus D,

	$(P Back when C was invented, compiler technology was primitive.
	Installing a text
	macro preprocessor onto the front end was a straightforward
	and easy way to add many
	powerful features. The increasing size & complexity of programs
	have illustrated
	that these features come with many inherent problems.
	D doesn't have a preprocessor; but
	D provides a more scalable means to solve the same problems.
	)

$(UL 
	$(LI <a href="#headerfiles">Header Files</a>)
	$(LI <a href="#pragmaonce">#pragma once</a>)
	$(LI <a href="#pragmapack">#pragma pack</a>)
	$(LI <a href="#macros">Macros</a>)
	$(LI <a href="#conditionalcompilation">Conditional Compilation</a>)
	$(LI <a href="#codefactoring">Code Factoring</a>)
	$(LI <a href="#staticassert">#error and Static Asserts</a>)
	$(LI <a href="#mixins">Template Mixins</a>)
)

<hr><!-- -------------------------------------------- -->
$(SECTION3 <a name="headerfiles">Header Files</a>,

$(CWAY

	$(P C and C++ rely heavily on textual inclusion of header files.
	This frequently results in the compiler having to recompile tens of thousands
	of lines of code over and over again for every source file, an obvious
	source of slow compile times. What header files are normally used for is
	more appropriately done doing a symbolic, rather than textual, insertion.
	This is done with the import statement. Symbolic inclusion means the compiler
	just loads an already compiled symbol table. The needs for macro "wrappers" to
	prevent multiple #inclusion, funky #pragma once syntax, and incomprehensible
	fragile syntax for precompiled headers are simply unnecessary and irrelevant to 
	D.
	)

$(CCODE
#include &lt;stdio.h&gt;
)
)

$(DWAY

	$(P D uses symbolic imports:)

---------
import std.c.stdio;
---------
)
)

<hr><!-- -------------------------------------------- -->
<h3><a name="pragmaonce">#pragma once</a></h3>

$(CWAY

	$(P C header files frequently need to be protected against
	being #include'd multiple times.
	To do it, a header file will contain the line:
	)

$(CCODE
#pragma once
)

	$(P or the more portable:)

$(CCODE
#ifndef __STDIO_INCLUDE
#define __STDIO_INCLUDE
... header file contents
#endif
)
)

$(DWAY
	$(P Completely unnecessary since D does a symbolic include of import
	files; they only get imported once no matter how many times
	the import declaration appears.
	)
)

<hr><!-- -------------------------------------------- -->
<h3><a name="pragmapack">#pragma pack</a></h3>

$(CWAY
	$(P This is used in C to adjust the alignment for structs.)
)

$(DWAY
	$(P For D classes, there is no need to adjust the alignment (in fact, the
	compiler is free to rearrange the data fields to get the optimum layout,
	much as the compiler will rearrange local variables on the stack frame).
	For D structs that get mapped onto externally defined data structures,
	there is a need, and it is handled with:
	)

---------
struct Foo
{
	align (4):	// use 4 byte alignment
	...
}
---------
)

<hr><!-- -------------------------------------------- -->
<h3><a name="macros">Macros</a></h3>

	$(P Preprocessor macros add powerful features and flexibility to C. But
	they have a downside:
	)

$(UL 
	$(LI Macros have no concept of scope; they are valid from the point of definition
	to the end of the source. They cut a swath across .h files, nested code, etc. When
	#include'ing tens of thousands of lines of macro definitions, it becomes 
	problematical to avoid inadvertent macro expansions.
	)

	$(LI Macros are unknown to the debugger. Trying to debug a program with 
	symbolic data is undermined by the debugger only knowing about macro 
	expansions, not the macros themselves.
	)

	$(LI Macros make it impossible to tokenize source code, as an earlier macro change 
	can arbitrarily redo tokens.
	)

	$(LI The purely textual basis of macros leads to arbitrary and inconsistent usage,
	making code using macros error prone. (Some attempt to resolve this was 
	introduced with templates in C++.)
	)

	$(LI Macros are still used to make up for deficits in the language's expressive
	capability, such as for "wrappers" around header files.
	)
)


	$(P Here's an enumeration of the common uses for macros, and the
	corresponding feature in D:
	)

$(OL 
	$(LI Defining literal constants:

	$(CWAY

$(CCODE
#define VALUE	5
)
	)

	$(DWAY

---------
const int VALUE = 5;
---------
	)
	)

	$(LI Creating a list of values or flags:

	$(CWAY

$(CCODE
int flags:
#define FLAG_X	0x1
#define FLAG_Y	0x2
#define FLAG_Z	0x4
...
flags |= FLAG_X;
)
	)

	$(DWAY

---------
enum FLAGS { X = 0x1, Y = 0x2, Z = 0x4 };
FLAGS flags;
...
flags |= FLAGS.X;
---------
	)
	)

	$(LI Distinguishing between ascii chars and wchar chars:

	$(CWAY

$(CCODE
#if UNICODE
    #define dchar	wchar_t
    #define TEXT(s)	L##s
#else
    #define dchar	char
    #define TEXT(s)	s
#endif

...
dchar h[] = TEXT("hello");
)
	)

	$(DWAY

---------
dchar[] h = "hello";
---------


	D's optimizer will inline the function, and will do the conversion of the
	string constant at compile time.
	<p>
	)
	)

	$(LI Supporting legacy compilers:

	$(CWAY

$(CCODE
#if PROTOTYPES
#define P(p)	p
#else
#define P(p)	()
#endif
int func P((int x, int y));
)
	)

	$(DWAY
	By making the D compiler open source, it will largely
	avoid the problem of syntactical backwards compatibility.
	)
	)

	$(LI Type aliasing:

	$(CWAY

$(CCODE
#define INT 	int
)
	)

	$(DWAY

---------
alias int INT;
---------
	)
	)

	$(LI Using one header file for both declaration and definition:

	$(CWAY

$(CCODE
#define EXTERN extern
#include "declarations.h"
#undef EXTERN
#define EXTERN
#include "declarations.h"
)

	In declarations.h:

$(CCODE
EXTERN int foo;
)
	)

	$(DWAY

	The declaration and the definition are the same, so there is no need
	to muck with the storage class to generate both a declaration and a definition
	from the same source.
	)
	)

	$(LI Lightweight inline functions:

	$(CWAY

$(CCODE
#define X(i)	((i) = (i) / 3)
)
	)

	$(DWAY

---------
int X(ref int i) { return i = i / 3; }
---------

	The compiler optimizer will inline it; no efficiency is lost.
	)
	)

	$(LI Assert function file and line number information:

	$(CWAY

$(CCODE
#define assert(e)	((e) || _assert(__LINE__, __FILE__))
)
	)

	$(DWAY

	assert() is a built-in expression primitive. Giving the compiler
	such knowledge of assert() also enables the optimizer to know about things
	like the _assert() function never returns.
	)
	)

	$(LI Setting function calling conventions:

	$(CWAY

$(CCODE
#ifndef _CRTAPI1
#define _CRTAPI1 __cdecl
#endif
#ifndef _CRTAPI2
#define _CRTAPI2 __cdecl
#endif

int _CRTAPI2 func();
)
	)

	$(DWAY

	Calling conventions can be specified in blocks, so there's no
	need to change it for every function:

---------
extern (Windows)
{
    int onefunc();
    int anotherfunc();
}
---------
	)
	)

	$(LI Hiding __near or __far pointer weirdness:

	$(CWAY

$(CCODE
#define LPSTR	char FAR *
)
	)

	$(DWAY

	D doesn't support 16 bit code, mixed pointer sizes, and different
	kinds of pointers, and so the problem is just
	irrelevant.
	)
	)

	$(LI Simple generic programming:

	$(CWAY

	Selecting which function to use based on text substitution:

$(CCODE
#ifdef UNICODE
int getValueW(wchar_t *p);
#define getValue getValueW
#else
int getValueA(char *p);
#define getValue getValueA
#endif
)
	)

	$(DWAY

	D enables declarations of symbols that are $(I aliases) of
	other symbols:

---------
version (UNICODE)
{
    int getValueW(wchar[] p);
    alias getValueW getValue;
}
else
{
    int getValueA(char[] p);
    alias getValueA getValue;
}
---------
	)
	)

)

<hr><!-- -------------------------------------------- -->
<h3><a name="conditionalcompilation">Conditional Compilation</a></h3>


$(CWAY

	$(P Conditional compilation is a powerful feature of the C preprocessor,
	but it has its downside:)

    $(UL 
	$(LI The preprocessor has no concept of scope. #if/#endif can be
	interleaved with code in a completely unstructured and disorganized
	fashion, making things difficult to follow.
	)

	$(LI Conditional compilation triggers off of macros - macros that
	can conflict with identifiers used in the program.
	)

	$(LI #if expressions are evaluated in subtly different ways than
	C expressions are.
	)

	$(LI The preprocessor language is fundamentally different in concept
	than C, for example, whitespace and line terminators mean things to
	the preprocessor that they do not in C.
	)
    )
)

$(DWAY

	$(P D supports conditional compilation:)

    $(OL 
	$(LI Separating version specific functionality into separate modules.
	)

	$(LI The debug statement for enabling/disabling debug harnesses,
	extra printing, etc.
	)

	$(LI The version statement for dealing with multiple versions
	of the program generated from a single set of sources.
	)

	$(LI The if (0) statement.
	)

	$(LI The /+ +/ nesting comment can be used to comment out blocks
	of code.
	)
    )
)

<hr><!-- -------------------------------------------- -->
<h3><a name="codefactoring">Code Factoring</a></h3>

$(CWAY

	$(P It's common in a function to have a repetitive sequence
	of code to be executed in multiple places. Performance
	considerations preclude factoring it out into a separate
	function, so it is implemented as a macro. For example,
	consider this fragment from a byte code interpreter:
	)

$(CCODE
unsigned char *ip;	// byte code instruction pointer
int *stack;
int spi;		// stack pointer
...
#define pop()		(stack[--spi])
#define push(i)		(stack[spi++] = (i))
while (1)
{
    switch (*ip++)
    {
	case ADD:
	    op1 = pop();
	    op2 = pop();
	    result = op1 + op2;
	    push(result);
	    break;

	case SUB:
	...
    }
}
)

	$(P This suffers from numerous problems:
	)

	$(OL 
	$(LI The macros must evaluate to expressions and cannot declare
	any variables. Consider the difficulty of extending them to
	check for stack overflow/underflow.
	)
	$(LI The macros exist outside of the semantic symbol table, so
	remain in scope even outside of the function they are declared in.
	)
	$(LI Parameters to macros are passed textually, not by value,
	meaning that the macro implementation needs to be careful to not
	use the parameter more than once, and must protect it with ().
	)
	$(LI Macros are invisible to the debugger, which sees only the
	expanded expressions.
	)
	)
)

$(DWAY

	$(P D neatly addresses this with nested functions:)

---------
ubyte* ip;		// byte code instruction pointer
int[] stack;		// operand stack
int spi;		// stack pointer
...

int pop()        { return stack[--spi]; }
void push(int i) { stack[spi++] = i; }

while (1)
{
    switch (*ip++)
    {
	case ADD:
	    op1 = pop();
	    op2 = pop();
	    push(op1 + op2);
	    break;

	case SUB:
	...
    }
}
---------

	$(P The problems addressed are:)

	$(OL 
	$(LI The nested functions have available the full expressive
	power of D functions. The array accesses already are bounds
	checked (adjustable by compile time switch).
	)
	$(LI Nested function names are scoped just like any other name.
	)
	$(LI Parameters are passed by value, so need to worry about
	side effects in the parameter expressions.
	)
	$(LI Nested functions are visible to the debugger.
	)
	)

	$(P Additionally, nested functions can be inlined by the implementation
	resulting in the same high performance that the C macro version
	exhibits.
	)
)

<hr><!-- -------------------------------------------- -->
<h3><a name="staticassert">#error and Static Asserts</a></h3>

	$(P Static asserts are user defined checks made at compile time;
	if the check fails the compile issues an error and fails.
	)

$(CWAY

	$(P The first way is to use the $(TT #error) preprocessing directive:
	)

$(CCODE
#if FOO || BAR
    ... code to compile ...
#else
#error "there must be either FOO or BAR"
#endif
)

	$(P This has the limitations inherent in preprocessor expressions
	(i.e. integer constant expressions only, no casts, no $(TT sizeof),
	no symbolic constants, etc.).
	)

	$(P These problems can be circumvented to some extent by defining a
	$(TT static_assert) macro (thanks to M. Wilson):
	)

$(CCODE
#define static_assert(_x) do { typedef int ai[(_x) ? 1 : 0]; } while(0)
)

	$(P and using it like:)

$(CCODE
void foo(T t)
{
    static_assert(sizeof(T) < 4);
    ...
}
)

	$(P This works by causing a compile time semantic error if the condition
	evaluates
	to false. The limitations of this technique are a sometimes very
	confusing error message from the compiler, along with an inability
	to use a $(TT static_assert) outside of a function body.
	)
)

$(DWAY

	$(P D has the <a href="version.html#staticassert">static assert</a>,
	which can be used anywhere a declaration
	or a statement can be used. For example:
	)

---------
version (FOO)
{
    class Bar
    {
	const int x = 5;
	static assert(Bar.x == 5 || Bar.x == 6);

	void foo(T t)
	{
	    static assert(T.sizeof < 4);
	    ...
	}
    }
}
else version (BAR)
{
    ...
}
else
{
    static assert(0);	// unsupported version
}
---------
)

<hr><!-- -------------------------------------------- -->
<h3><a name="mixins">Template Mixins</a></h3>

	$(P D $(LINK2 template-mixin.html, template mixins)
	superficially look just
	like using C's preprocessor to insert blocks of code and
	parse them in the scope of where they are instantiated.
	But the advantages of mixins over macros are:
	)

	$(OL 
	$(LI Mixins substitute in parsed declaration trees that pass muster with
	the language syntax, macros substitute in arbitrary preprocessor tokens
	that have no organization.
	)

	$(LI Mixins are in the same language. Macros are a separate and
	distinct language layered on top of C++, with its own expression rules,
	its own types, its distinct symbol table, its own scoping rules, etc. 
	)

	$(LI Mixins are selected based on partial specialization rules, macros
	have no overloading.
	)

	$(LI Mixins create a scope, macros do not.
	)

	$(LI Mixins are compatible with syntax parsing tools, macros are not.
	)

	$(LI Mixin semantic information and symbol tables are passed through to
	the debugger, macros are lost in translation.
	)

	$(LI Mixins have override conflict resolution rules, macros just
	collide.
	)

	$(LI Mixins automatically create unique identifiers as required using a
	standard algorithm, macros have to do it manually with kludgy token
	pasting.
	)

	$(LI Mixin value arguments with side effects are evaluated once, macro
	value arguments get evaluated each time they are used in the expansion
	(leading to weird bugs).
	)

	$(LI Mixin argument replacements don't need to be 'protected' with
	parentheses to avoid operator precedence regrouping.
	)

	$(LI Mixins can be typed as normal D code of arbitrary length, multiline
	macros have to be backslash line-spliced, can't use // to end of line
	comments, etc.
	)

	$(LI Mixins can define other mixins. Macros cannot create other macros.
	)

	)

)

Macros:
	TITLE=The C Preprocessor vs D
	WIKI=PreToD
	CWAY=$(SECTION4 The C Preprocessor Way, $0)
	DWAY=$(SECTION4 The D Way, $0)

