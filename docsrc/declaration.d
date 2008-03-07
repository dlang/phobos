Ddoc

$(SPEC_S Declarations,

$(GRAMMAR
$(I Declaration):
        $(B typedef) $(I Decl)
        $(B alias) $(I Decl)
        $(I Decl)

$(I Decl):
        $(I StorageClasses) $(I Decl)
        $(I BasicType) $(I Declarators) $(B ;)
        $(I BasicType) $(I Declarator) $(I FunctionBody)
	$(GLINK AutoDeclaration)

$(I Declarators):
        $(I DeclaratorInitializer)
        $(I DeclaratorInitializer) $(B ,) $(I DeclaratorIdentifierList)

$(I DeclaratorInitializer):
        $(I Declarator)
        $(I Declarator) $(B =) $(I Initializer)

$(I DeclaratorIdentifierList):
        $(I DeclaratorIdentifier)
        $(I DeclaratorIdentifier) $(B ,) $(I DeclaratorIdentifierList)

$(I DeclaratorIdentifier):
        $(I Identifier)
        $(I Identifier) $(B =) $(I Initializer)

$(I BasicType):
        $(B bool)
        $(B byte)
        $(B ubyte)
        $(B short)
        $(B ushort)
        $(B int)
        $(B uint)
        $(B long)
        $(B ulong)
        $(B char)
        $(B wchar)
        $(B dchar)
        $(B float)
        $(B double)
        $(B real)
        $(B ifloat)
        $(B idouble)
        $(B ireal)
        $(B cfloat)
        $(B cdouble)
        $(B creal)
        $(B void)
        $(B .)$(I IdentifierList)
        $(I IdentifierList)
        $(GLINK Typeof)
        $(GLINK Typeof) $(B .) $(I IdentifierList)

$(I BasicType2):
        $(B *)
        $(B [ ])
        $(B [) $(I Expression) $(B ])
        $(B [) $(I Type) $(B ])
        $(B delegate) $(I Parameters)
        $(B function) $(I Parameters)

$(I Declarator):
        $(I BasicType2) $(I Declarator)
        $(I Identifier)
        $(B () $(I Declarator) $(B ))
        $(I Identifier) $(I DeclaratorSuffixes)
        $(B () $(I Declarator) $(B )) $(I DeclaratorSuffixes)

$(I DeclaratorSuffixes):
        $(I DeclaratorSuffix)
        $(I DeclaratorSuffix) $(I DeclaratorSuffixes)

$(I DeclaratorSuffix):
        $(B [ ])
        $(B [) $(I Expression) $(B ])
        $(B [) $(I Type) $(B ])
	$(I Parameters)

$(I IdentifierList):
        $(I Identifier)
        $(I Identifier) $(B .) $(I IdentifierList)
        $(I TemplateInstance)
        $(I TemplateInstance) $(B .) $(I IdentifierList)

$(I StorageClasses):
	$(I StorageClass)
	$(I StorageClass) $(I StorageClasses)

$(I StorageClass):
        $(B abstract)
        $(B auto)
        $(B const)
        $(B deprecated)
        $(B extern)
        $(B final)
        $(B invariant)
        $(B override)
        $(B scope)
        $(B static)
        $(B synchronized)

$(I Type):
        $(I BasicType)
        $(I BasicType) $(I Declarator2)

$(I Declarator2):
        $(I BasicType2) $(I Declarator2)
        $(B $(LPAREN)) $(I Declarator2) $(B $(RPAREN))
        $(B $(LPAREN)) $(I Declarator2) $(B $(RPAREN)) $(I DeclaratorSuffixes)

$(I Parameters):
	$(B $(LPAREN)) $(I ParameterList) $(B $(RPAREN))
	$(B ( ))

$(I ParameterList):
        $(I Parameter)
        $(I Parameter) $(B ,) $(I ParameterList)
        $(I Parameter) $(B ...)
        $(B ...)

$(I Parameter):
        $(I Declarator)
        $(I Declarator) = $(ASSIGNEXPRESSION)
        $(I InOut) $(I Declarator)
        $(I InOut) $(I Declarator) = $(ASSIGNEXPRESSION)

$(I InOut):
        $(B in)
        $(B out)
        $(B ref)
        $(B lazy)

$(I Initializer):
        $(GLINK VoidInitializer)
	$(I NonVoidInitializer)

$(I NonVoidInitializer):
        $(ASSIGNEXPRESSION)
        $(I ArrayInitializer)
        $(I StructInitializer)

$(I ArrayInitializer):
	$(B [ ])
	$(B [) $(I ArrayMemberInitializations) $(B ])

$(I ArrayMemberInitializations):
	$(I ArrayMemberInitialization)
	$(I ArrayMemberInitialization) $(B ,)
	$(I ArrayMemberInitialization) $(B ,) $(I ArrayMemberInitializations)

$(I ArrayMemberInitialization):
	$(I NonVoidInitializer)
	$(ASSIGNEXPRESSION) $(B :) $(I NonVoidInitializer)

$(I StructInitializer):
	$(B {  })
	$(B {) $(I StructMemberInitializers) $(B })

$(I StructMemberInitializers):
	$(I StructMemberInitializer)
	$(I StructMemberInitializer) $(B ,)
	$(I StructMemberInitializer) $(B ,) $(I StructMemberInitializers)

$(I StructMemberInitializer):
	$(I NonVoidInitializer)
	$(I Identifier) $(B :) $(I NonVoidInitializer)
)

<h3>Declaration Syntax</h3>

$(P Declaration syntax generally reads right to left:)

--------------------
int x;		// x is an int
int* x;		// x is a pointer to int
int** x;	// x is a pointer to a pointer to int
int[] x;	// x is an array of ints
int*[] x;	// x is an array of pointers to ints
int[]* x;	// x is a pointer to an array of ints
--------------------

$(P Arrays read right to left as well:)

--------------------
int[3] x;	// x is an array of 3 ints
int[3][5] x;	// x is an array of 5 arrays of 3 ints
int[3]*[5] x;	// x is an array of 5 pointers to arrays of 3 ints
--------------------

$(P 
Pointers to functions are declared using the $(B function) keyword:
)

--------------------
int $(B function)(char) x;   // x is a pointer to a function taking a char argument
			// and returning an int
int $(B function)(char)[] x; // x is an array of pointers to functions
			// taking a char argument and returning an int
--------------------

$(P 
C-style array declarations may be used as an alternative:
)

--------------------
int x[3];	   // x is an array of 3 ints
int x[3][5];	   // x is an array of 3 arrays of 5 ints
int (*x[5])[3];	   // x is an array of 5 pointers to arrays of 3 ints
int (*x)(char);	   // x is a pointer to a function taking a char argument
		   // and returning an int
int (*[] x)(char); // x is an array of pointers to functions
		   // taking a char argument and returning an int
--------------------

$(P 
In a declaration declaring multiple symbols, all the declarations
must be of the same type:
)

--------------------
int x,y;	// x and y are ints
int* x,y;	// x and y are pointers to ints
int x,*y;	// error, multiple types
int[] x,y;	// x and y are arrays of ints
int x[],y;	// error, multiple types
--------------------

<h3><a name="AutoDeclaration">Implicit Type Inference</a></h3>

$(GRAMMAR
$(I AutoDeclaration):
	$(I StorageClasses) $(I Identifier) $(B =) $(ASSIGNEXPRESSION) $(B ;)
)

	$(P If a declaration starts with a $(I StorageClass) and has
	a $(I NonVoidInitializer) from which the type can be inferred,
	the type on the declaration can be omitted.
	)

----------
static x = 3;	   // x is type int
auto y = 4u;	   // y is type uint
auto s = "string"; // s is type char[6]

class C { ... }

auto c = new C();  // c is a handle to an instance of class C
----------

	The $(I NonVoidInitializer) cannot contain forward references
	(this restriction may be removed in the future).
	The implicitly inferred type is statically bound
	to the declaration at compile time, not run time.


<h3><a name="typedef">Type Defining</a></h3>

	$(P 
	Strong types can be introduced with the typedef. Strong types are semantically a 
	distinct type to the type checking system, for function overloading, and for the debugger.
	)

--------------------
typedef int myint;

void foo(int x) { . }
void foo(myint m) { . }

 .
myint b;
foo(b);	        // calls foo(myint)
--------------------

Typedefs can specify a default initializer different from the
default initializer of the underlying type:

--------------------
typedef int myint = 7;
myint m;        // initialized to 7
--------------------


<h3><a name="alias">Type Aliasing</a></h3>

	$(P 
	It's sometimes convenient to use an alias for a type, such as a shorthand for typing 
	out a long, complex type like a pointer to a function. In D, this is done with the 
	alias declaration:
	)

--------------------
$(B alias) abc.Foo.bar myint;
--------------------

	$(P 
	Aliased types are semantically identical to the types they are aliased to. The 
	debugger cannot distinguish between them, and there is no difference as far as function 
	overloading is concerned. For example:
	)

--------------------
$(B alias) int myint;

void foo(int x) { . }
void foo(myint m) { . }	// error, multiply defined function foo
--------------------

	$(P 
	Type aliases are equivalent to the C typedef.
	)

<h3>Alias Declarations</h3>

	$(P 
	A symbol can be declared as an $(I alias) of another symbol.
	For example:
	)

--------------------
import string;

$(B alias) string.strlen mylen;
 ...
int len = mylen("hello");	// actually calls string.strlen()
--------------------

	$(P 
	The following alias declarations are valid:
	)

--------------------
template Foo2(T) { $(B alias) T t; }
$(B alias) Foo2!(int) t1;
$(B alias) Foo2!(int).t t2;
$(B alias) t1.t t3;
$(B alias) t2 t4;

t1.t v1;	// v1 is type int
t2 v2;		// v2 is type int
t3 v3;		// v3 is type int
t4 v4;		// v4 is type int
--------------------

	$(P 
	Aliased symbols are useful as a shorthand for a long qualified
	symbol name, or as a way to redirect references from one symbol
	to another:
	)

--------------------
version (Win32)
{
    $(B alias) win32.foo myfoo;
}
version (linux)
{
    $(B alias) linux.bar myfoo;
}
--------------------

	$(P 
	Aliasing can be used to 'import' a symbol from an import into the
	current scope:
	)

--------------------
$(B alias) string.strlen strlen;
--------------------

	$(P 
	Aliases can also 'import' a set of overloaded functions, that can
	be overloaded with functions in the current scope:
	)

--------------------
class A {
    int foo(int a) { return 1; }
}

class B : A {
    int foo( int a, uint b ) { return 2; }
}

class C : B {
    int foo( int a ) { return 3; }
    $(B alias) B.foo foo;
}

class D : C  {
}


void test()
{
    D b = new D();
    int i;

    i = b.foo(1, 2u);	// calls B.foo
    i = b.foo(1);	// calls C.foo
}
--------------------

	$(P 
	$(B Note:) Type aliases can sometimes look indistinguishable from
	alias declarations:
	)

--------------------
$(B alias) foo.bar abc;	// is it a type or a symbol?
--------------------

	$(P 
	The distinction is made in the semantic analysis pass.
	)

	$(P Aliases cannot be used for expressions:)

-----------
struct S { static int i; }
S s;

alias s.i a;	// illegal, s.i is an expression
alias S.i b;	// ok
b = 4;		// sets S.i to 4
-----------

<h3><a name="extern">Extern Declarations</a></h3>

	Variable declarations with the storage class $(B extern) are
	not allocated storage within the module.
	They must be defined in some other object file with a matching
	name which is then linked in.
	The primary usefulness of this is to connect with global
	variable declarations in C files.

<h3><a name="typeof">typeof</a></h3>

$(GRAMMAR
$(GNAME Typeof):
        $(B typeof $(LPAREN)) $(I Expression) $(B $(RPAREN))
        $(B typeof $(LPAREN)) $(B return) $(B $(RPAREN))
)

	$(P 
	$(I Typeof) is a way to specify a type based on the type
	of an expression. For example:
	)

--------------------
void func(int i)
{
    $(B typeof)(i) j;	// j is of type int
    $(B typeof)(3 + 6.0) x;	// x is of type double
    $(B typeof)(1)* p;	// p is of type pointer to int
    int[$(B typeof)(p)] a;	// a is of type int[int*]

    writefln("%d", $(B typeof)('c').sizeof);	// prints 1
    double c = cast($(B typeof)(1.0))j;	// cast j to double
}
--------------------

	$(P 
	$(I Expression) is not evaluated, just the type of it is
	generated:
	)

--------------------
void func()
{   int i = 1;
    $(B typeof)(++i) j;	// j is declared to be an int, i is not incremented
    writefln("%d", i);	// prints 1
}
--------------------

	$(P 
	There are $(V1 two) $(V2 three) special cases:
	$(OL
	$(LI $(B typeof(this)) will generate the type of what $(B this)
	would be in a non-static member function, even if not in a member
	function.
	)
	$(LI Analogously, $(B typeof(super)) will generate the type of what
	$(B super) would be in a non-static member function.
	)
$(V2
	$(LI $(B typeof(return)) will, when inside a function scope,
	give the return type of that function.
	)
)
	)
	)

--------------------
class A { }

class B : A
{
    $(B typeof(this)) x;	// x is declared to be a B
    $(B typeof(super)) y;	// y is declared to be an A
}

struct C
{
    $(B typeof(this)) z;	// z is declared to be a C*
    $(B typeof(super)) q;	// error, no super struct for C
}

$(B typeof(this)) r;		// error, no enclosing struct or class
--------------------

	$(P 
	Where $(I Typeof) is most useful is in writing generic
	template code.
	)

<h3>Void Initializations</h3>

$(GRAMMAR
$(GNAME VoidInitializer):
	$(B void)
)

	Normally, variables are initialized either with an explicit
	$(I Initializer) or are set to the default value for the
	type of the variable. If the $(I Initializer) is $(B void),
	however, the variable is not initialized. If its value is
	used before it is set, undefined program behavior will result.

-------------------------
void foo()
{
    int x = void;
    writefln(x);	// will print garbage
}
-------------------------

	Therefore, one should only use $(B void) initializers as a
	last resort when optimizing critical code.

)

Macros:
	TITLE=Declarations
	WIKI=Declaration
	GLINK=$(LINK2 #$0, $(I $0))
	GNAME=$(LNAME2 $0, $0)
	FOO=
