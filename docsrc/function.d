Ddoc

$(SPEC_S Functions,

$(GRAMMAR
$(I FunctionBody):
	$(I BlockStatement)
	$(I BodyStatement)
	$(I InStatement) $(I BodyStatement)
	$(I OutStatement) $(I BodyStatement)
	$(I InStatement) $(I OutStatement) $(I BodyStatement)
	$(I OutStatement) $(I InStatement) $(I BodyStatement)

$(I InStatement):
	$(B in) $(I BlockStatement)

$(I OutStatement):
	$(B out) $(I BlockStatement)
	$(B out) $(B $(LPAREN)) $(I Identifier) $(B $(RPAREN)) $(I BlockStatement)

$(I BodyStatement):
	$(B body) $(I BlockStatement)
)

<h3>Virtual Functions</h3>

	Virtual functions are functions that are called indirectly
	through a function
	pointer table, called a vtbl[], rather than directly.
	All non-static non-private non-template member functions are virtual.
	This may sound
	inefficient, but since the D compiler knows all of the class
	hierarchy when generating code, all
	functions that are not overridden can be optimized to be non-virtual.
	In fact, since
	C++ programmers tend to "when in doubt, make it virtual", the D way of
	"make it
	virtual unless we can prove it can be made non-virtual" results, on
	average, in many
	more direct function calls. It also results in fewer bugs caused by
	not declaring
	a function virtual that gets overridden.
	<p>

	Functions with non-D linkage cannot be virtual, and hence cannot be
	overridden.
	<p>

	Member template functions cannot be virtual, and hence cannot be
	overridden.
	<p>

	Functions marked as $(TT final) may not be overridden in a
	derived class, unless they are also $(TT private).
	For example:

------
class A
{
    int def() { ... }
    final int foo() { ... }
    final private int bar() { ... }
    private int abc() { ... }
}

class B : A
{
    int def() { ... }	// ok, overrides A.def
    int foo() { ... }	// error, A.foo is final
    int bar() { ... }	// ok, A.bar is final private, but not virtual
    int abc() { ... }	// ok, A.abc is not virtual, B.abc is virtual
}

void test(A a)
{
    a.def();	// calls B.def
    a.foo();	// calls A.foo
    a.bar();	// calls A.bar
    a.abc();	// calls A.abc
}

void func()
{   B b = new B();
    test(b);
}
------

	<a name="covariant">Covariant return types</a>
	are supported, which means that the
	overriding function in a derived class can return a type
	that is derived from the type returned by the overridden function:

------
class A { }
class B : A { }

class Foo
{
    A test() { return null; }
}

class Bar : Foo
{
    B test() { return null; }	// overrides and is covariant with Foo.test()
}
------

<h3>Function Inheritance and Overriding</h3>

	A functions in a derived class with the same name and parameter
	types as a function in a base class overrides that function:

------
class A
{
    int foo(int x) { ... }
}

class B : A
{
    override int foo(int x) { ... }
}

void test()
{
    B b = new B();
    bar(b);
}

void bar(A a)
{
    a.foo(1);	// calls B.foo(int)
}
------

	$(P However, when doing overload resolution, the functions in the base
	class are not considered:
	)

------
class A
{
    int foo(int x) { ... }
    int foo(long y) { ... }
}

class B : A
{
    override int foo(long x) { ... }
}

void test()
{
    B b = new B();
    b.foo(1);	// calls B.foo(long), since A.foo(int) not considered
    A a = b;
$(V1      a.foo(1);	// calls A.foo(int))
$(V2      a.foo(1);	// issues runtime error (instead of calling A.foo(int)))
}
------

	$(P To consider the base class's functions in the overload resolution
	process, use an $(I AliasDeclaration):
	)

------
class A
{
    int foo(int x) { ... }
    int foo(long y) { ... }
}

class B : A
{
    $(B alias A.foo foo;)
    override int foo(long x) { ... }
}

void test()
{
    B b = new B();
    bar(b);
}

void bar(A a)
{
    a.foo(1);		// calls A.foo(int)
    B b = new B();
    b.foo(1);		// calls A.foo(int)
}
------

$(V2
	$(P If such an $(I AliasDeclaration) is not used, the derived
	class's functions completely override all the functions of the
	same name in the base class, even if the types of the parameters
	in the base class functions are different. If, through
	implicit conversions to the base class, those other functions do
	get called, an $(CODE std.HiddenFuncError) exception is raised:
	)
---
import std.hiddenfunc;

class A
{
     void set(long i) { }
     void $(B set)(int i)  { }
}
class B : A
{
     void set(long i) { }
}

void foo(A a)
{   int i;
    try
    {
        a.$(B set)(3);   // error, throws runtime exception since
                    // A.set(int) should not be available from B
    }
    catch ($(B HiddenFuncError) o)
    {
	i = 1;
    }
    assert(i == 1);
}

void main()
{
    foo(new B);
}
---
	$(P If an $(CODE HiddenFuncError) exception is thrown in your program,
	the use of overloads and overrides needs to be reexamined in the
	relevant classes.)
)

	$(P A function parameter's default value is not inherited:)

------
class A
{
    void foo(int $(B x = 5)) { ... }
}

class B : A
{
    void foo(int $(B x = 7)) { ... }
}

class C : B
{
    void foo(int $(B x)) { ... }
}


void test()
{
    A a = new A();
    a.foo();		// calls A.foo(5)

    B b = new B();
    b.foo();		// calls B.foo(7)

    C c = new C();
    c.foo();		// error, need an argument for C.foo
}
------


<h3>Inline Functions</h3>

	There is no inline keyword. The compiler makes the decision whether to 
	inline a function or not, analogously to the register keyword no
	longer being relevant to a 
	compiler's decisions on enregistering variables.
	(There is no register keyword either.)


<h2><a name="function-overloading">Function Overloading</a></h2>

	$(P In C++, there are many complex levels of function overloading, with
	some defined as "better" matches than others. If the code designer
	takes advantage of the more subtle 
	behaviors of overload function selection, the code can become
	difficult to maintain. Not 
	only will it take a C++ expert to understand why one function is
	selected over another, but different C++ compilers can implement
	this tricky feature differently, producing 
	subtly disastrous results.
	)

	$(P In D, function overloading is simple. It matches exactly, it matches
	with implicit conversions, or it does not match. If there is more than
	one match, it is an error.
	)

	$(P Functions defined with non-D linkage cannot be overloaded.
	)

$(V2
<h2><a name="overload-sets">Overload Sets</a></h2>

	$(P Functions declared at the same scope overload against each
	other, and are called an $(I Overload Set).
	A typical example of an overload set are functions defined
	at module level:
	)

---
module A;
void foo() { }
void foo(long i) { }
---

	$(P $(CODE A.foo()) and $(CODE A.foo(long)) form an overload set.
	A different module can also define functions with the same name:
	)

---
module B;
class C { }
void foo(C) { }
void foo(int i) { }
---

	$(P and A and B can be imported by a third module, C.
	Both overload sets, the $(CODE A.foo) overload set and the $(CODE B.foo)
	overload set, are found. An instance of $(CODE foo) is selected
	based on it matching in exactly one overload set:
	)

---
import A;
import B;

void bar(C c)
{
    foo();    // calls A.foo()
    foo(1L);  // calls A.foo(long)
    foo(c);   // calls B.foo(C)
    foo(1,2); // error, does not match any foo
    foo(1);   // error, matches A.foo(long) and B.foo(int)
    A.foo(1); // calls A.foo(long)
}
---

	$(P Even though $(CODE B.foo(int)) is a better match than $(CODE
	A.foo(long)) for $(CODE foo(1)),
	it is an error because the two matches are in
	different overload sets.
	)

	$(P Overload sets can be merged with an alias declaration:)

---
import A;
import B;

alias A.foo foo;
alias B.foo foo;

void bar(C c)
{
    foo();    // calls A.foo()
    foo(1L);  // calls A.foo(long)
    foo(c);   // calls B.foo(C)
    foo(1,2); // error, does not match any foo
    foo(1);   // calls B.foo(int)
    A.foo(1); // calls A.foo(long)
}
---

)


<h3><a name="parameters">Function Parameters</a></h3>

$(V1
	Parameters are $(B in), $(B out), $(B ref) or $(B lazy).
	$(B in) is the default; the others work like 
	storage classes. For example:

------
int foo(int x, out int y, ref int z, int q);
------

	x is $(B in), y is $(B out), z is $(B ref), and q is $(B in).
	<p>

	$(B out) is rare enough, and $(B ref) even rarer, to
	attach the keywords to
	them and leave $(B in) as 
	the default.
)
$(V2
	Parameter storage classes are $(B in), $(B out),
	$(B ref), $(B lazy), $(B final), $(B const), $(B invariant), or
	$(B scope).
	 For example:

------
int foo(in int x, out int y, ref int z, int q);
------

	$(P
	x is $(B in), y is $(B out), z is $(B ref), and q is none.
	)

	$(P
	The $(B in) storage class is equivalent to $(B const scope).
	)

	$(P
	If no storage class is specified, the parameter becomes a mutable
	copy of its argument.
	)
)

	$(UL 
	$(LI The function declaration makes it clear what the inputs and
	outputs to the function are.)
	$(LI It eliminates the need for IDL as a separate language.)
	$(LI It provides more information to the compiler, enabling more
	error checking and 
	possibly better code generation.)
	)

	$(P
	$(B out) parameters are set to the default initializer for the
	type of it. For example:
	)
------
void foo(out int x)
{
    // x is set to 0 at start of foo()
}

int a = 3;
foo(a);
// a is now 0


void abc(out int x)
{
    x = 2;
}

int y = 3;
abc(y);
// y is now 2


void def(ref int x)
{
    x += 1;
}

int z = 3;
def(z);
// z is now 4
------------

	$(P For dynamic array and object parameters, which are passed
	by reference, in/out/ref
	apply only to the reference and not the contents.
	)

	$(P Lazy arguments are evaluated not when the function is called,
	but when the parameter is evaluated within the function. Hence,
	a lazy argument can be executed 0 or more times. A lazy parameter
	cannot be an lvalue.)

---
void dotimes(int n, lazy void exp)
{
    while (n--)
	exp();
}

void test()
{   int x;
    dotimes(3, writefln(x++));
}
---

	$(P prints to the console:)

$(CONSOLE
0
1
2
)

	$(P A lazy parameter of type $(TT void) can accept an argument
	of any type.)

<a name="variadic"><h2>Variadic Functions</h2></a>

	Functions taking a variable number of arguments are called
	variadic functions. A variadic function can take one of
	three forms:

	$(OL
	$(LI C-style variadic functions)
	$(LI Variadic functions with type info)
	$(LI Typesafe variadic functions)
	)


<h3>C-style Variadic Functions</h3>

	A C-style variadic function is declared as taking
	a parameter of ... after the required function parameters.
	It has non-D linkage, such as $(TT extern (C)):

------
extern (C) int foo(int x, int y, ...);

foo(3, 4);	// ok
foo(3, 4, 6.8);	// ok, one variadic argument
foo(2);		// error, y is a required argument
------

	There must be at least one non-variadic parameter declared.

------
extern (C) int def(...); // error, must have at least one parameter
------

	C-style variadic functions match the C calling convention for
	variadic functions, and is most useful for calling C library
	functions like $(TT printf).
	The implementiations of these variadic functions have a special
	local variable declared for them,
	$(B _argptr), which is a $(TT void*) pointer to the first of the
	variadic
	arguments. To access the arguments, $(B _argptr) must be cast
	to a pointer to the expected argument type:

------
foo(3, 4, 5);	// first variadic argument is 5

int foo(int x, int y, ...)
{   int z;

    z = *cast(int*)$(B _argptr);	// z is set to 5
}
------

	To protect against the vagaries of stack layouts on different
	CPU architectures, use $(B std.c.stdarg) to access the variadic
	arguments:

------
import $(B std.c.stdarg);
------

<h3>D-style Variadic Functions</h3>

	Variadic functions with argument and type info are declared as taking
	a parameter of ... after the required function parameters.
	It has D linkage, and need not have any non-variadic parameters
	declared:

------
int abc(char c, ...);	// one required parameter: c
int def(...);		// ok
------

	These variadic functions have a special local variable declared for
	them,
	$(B _argptr), which is a $(TT void*) pointer to the first of the
	variadic
	arguments. To access the arguments, $(B _argptr) must be cast
	to a pointer to the expected argument type:

------
foo(3, 4, 5);	// first variadic argument is 5

int foo(int x, int y, ...)
{   int z;

    z = *cast(int*)$(B _argptr);	// z is set to 5
}
------

	An additional hidden argument
	with the name $(B _arguments) and type $(TT TypeInfo[])
	is passed to the function.
	$(B _arguments) gives the number of arguments and the type
	of each, enabling the creation of typesafe variadic functions.

------
import std.stdio;

class Foo { int x = 3; }
class Bar { long y = 4; }

void printargs(int x, ...)
{
    writefln("%d arguments", $(B _arguments).length);
    for (int i = 0; i < $(B _arguments).length; i++)
    {   $(B _arguments)[i].print();

	if ($(B _arguments)[i] == typeid(int))
	{
	    int j = *cast(int *)_argptr;
	    _argptr += int.sizeof;
	    writefln("\t%d", j);
	}
	else if ($(B _arguments)[i] == typeid(long))
	{
	    long j = *cast(long *)_argptr;
	    _argptr += long.sizeof;
	    writefln("\t%d", j);
	}
	else if ($(B _arguments)[i] == typeid(double))
	{
	    double d = *cast(double *)_argptr;
	    _argptr += double.sizeof;
	    writefln("\t%g", d);
	}
	else if ($(B _arguments)[i] == typeid(Foo))
	{
	    Foo f = *cast(Foo*)_argptr;
	    _argptr += Foo.sizeof;
	    writefln("\t%X", f);
	}
	else if ($(B _arguments)[i] == typeid(Bar))
	{
	    Bar b = *cast(Bar*)_argptr;
	    _argptr += Bar.sizeof;
	    writefln("\t%X", b);
	}
	else
	    assert(0);
    }
}

void main()
{
    Foo f = new Foo();
    Bar b = new Bar();

    writefln("%X", f);
    printargs(1, 2, 3L, 4.5, f, b);
}
------

	which prints:

------
00870FE0
5 arguments
int
        2
long
        3
double
        4.5
Foo
        00870FE0
Bar
        00870FD0
------

	To protect against the vagaries of stack layouts on different
	CPU architectures, use $(B std.stdarg) to access the variadic
	arguments:

------
import std.stdio;
import $(B std.stdarg);

void foo(int x, ...)
{
    writefln("%d arguments", _arguments.length);
    for (int i = 0; i < _arguments.length; i++)
    {   _arguments[i].print();

	if (_arguments[i] == typeid(int))
	{
	    int j = $(B va_arg)!(int)(_argptr);
	    writefln("\t%d", j);
	}
	else if (_arguments[i] == typeid(long))
	{
	    long j = $(B va_arg)!(long)(_argptr);
	    writefln("\t%d", j);
	}
	else if (_arguments[i] == typeid(double))
	{
	    double d = $(B va_arg)!(double)(_argptr);
	    writefln("\t%g", d);
	}
	else if (_arguments[i] == typeid(FOO))
	{
	    FOO f = $(B va_arg)!(FOO)(_argptr);
	    writefln("\t%X", f);
	}
	else
	    assert(0);
    }
}
------

<h3>Typesafe Variadic Functions</h3>

	Typesafe variadic functions are used when the variable argument
	portion of the arguments are used to construct an array or
	class object.
	<p>

	For arrays:

------
int test()
{
    return sum(1, 2, 3) + sum(); // returns 6+0
}

int func()
{
    int[3] ii = [4, 5, 6];
    return sum(ii);		// returns 15
}

int sum(int[] ar ...)
{
    int s;
    foreach (int x; ar)
	s += x;
    return s;
}
------

	For static arrays:

------
int test()
{
    return sum(2, 3);	// error, need 3 values for array
    return sum(1, 2, 3); // returns 6
}

int func()
{
    int[3] ii = [4, 5, 6];
    int[] jj = ii;
    return sum(ii);		// returns 15
    return sum(jj);		// error, type mismatch
}

int sum(int[3] ar ...)
{
    int s;
    foreach (int x; ar)
	s += x;
    return s;
}
------

	For class objects:

------
class Foo
{
    int x;
    char[] s;

    this(int x, char[] s)
    {
	this.x = x;
	this.s = s;
    }
}

void test(int x, Foo f ...);

...

Foo g = new Foo(3, "abc");
test(1, g);		// ok, since g is an instance of Foo
test(1, 4, "def");	// ok
test(1, 5);		// error, no matching constructor for Foo
------

	An implementation may construct the object or array instance
	on the stack. Therefore, it is an error to refer to that
	instance after the variadic function has returned:

------
Foo test(Foo f ...)
{
    return f;	// error, f instance contents invalid after return
}

int[] test(int[] a ...)
{
    return a;		// error, array contents invalid after return
    return a[0..1];	// error, array contents invalid after return
    return a.dup;	// ok, since copy is made
}
------

	For other types, the argument is built with itself, as in:

------
int test(int i ...)
{
    return i;
}

...
test(3);	// returns 3
test(3, 4);	// error, too many arguments
int[] x;
test(x);	// error, type mismatch
------

<h3>Lazy Variadic Functions</h3>

	$(P If the variadic parameter is an array of delegates
	with no parameters:
	)

---
void foo(int delegate()[] dgs ...);
---

	$(P Then each of the arguments whose type does not match that
	of the delegate is converted to a delegate.
	)

---
int delegate() dg;
foo(1, 3+x, dg, cast(int delegate())null);
---

	$(P is the same as:)

---
foo( { return 1; }, { return 3+x; }, dg, null );
---

<h2>Local Variables</h2>

	$(P It is an error to use a local variable without first assigning it a
	value. The implementation may not always be able to detect these
	cases. Other language compilers sometimes issue a warning for this,
	but since it is always a bug, it should be an error.
	)

	$(P It is an error to declare a local variable that is never referred to.
	Dead variables, like anachronistic dead code, are just a source of
	confusion for maintenance programmers.
	)

	$(P It is an error to declare a local variable that hides another local
	variable in the same function:
	)

------
void func(int x)
{   int x;		error, hides previous definition of x
     double y;
     ...
     {   char y;	error, hides previous definition of y
	  int z;
     }
     {   wchar z;	legal, previous z is out of scope
     }
}
------

	$(P While this might look unreasonable, in practice whenever
	this is done it either is a 
	bug or at least looks like a bug.
	)

	$(P It is an error to return the address of or a reference to a
	local variable.
	)

	$(P It is an error to have a local variable and a label with the same
	name.
	)

<h2><a name="nested">Nested Functions</a></h2>

	$(P Functions may be nested within other functions:)

------
int bar(int a)
{
    int foo(int b)
    {
	int abc() { return 1; }

	return b + abc();
    }
    return foo(a);
}

void test()
{
    int i = bar(3);	// i is assigned 4
}
------

	$(P Nested functions can be accessed only if the name is in scope.)

------
void foo()
{
   void A()
   {
     B();   // error, B() is forward referenced
     C();   // error, C undefined
   }
   void B()
   {
       A();	// ok, in scope
       void C()
       {
           void D()
           {
               A();      // ok
               B();      // ok
               C();      // ok
               D();      // ok
           }
       }
   }
   A(); // ok
   B(); // ok
   C(); // error, C undefined
}
------

	$(P and:)

------
int bar(int a)
{
    int foo(int b) { return b + 1; }
    int abc(int b) { return foo(b); }	// ok
    return foo(a);
}

void test()
{
    int i = bar(3);	// ok
    int j = bar.foo(3);	// error, bar.foo not visible
}
------

	$(P Nested functions have access to the variables and other symbols
	defined by the lexically enclosing function.
	This access includes both the ability to read and write them.
	)

------
int bar(int a)
{   int c = 3;

    int foo(int b)
    {
	b += c;		// 4 is added to b
	c++;		// bar.c is now 5
	return b + c;	// 12 is returned
    }
    c = 4;
    int i = foo(a);	// i is set to 12
    return i + c;	// returns 17
}

void test()
{
    int i = bar(3);	// i is assigned 17
}
------

	$(P This access can span multiple nesting levels:)

------
int bar(int a)
{   int c = 3;

    int foo(int b)
    {
	int abc()
	{
	    return c;	// access bar.c
	}
	return b + c + abc();
    }
    return foo(3);
}
------

	$(P Static nested functions cannot access any stack variables of
	any lexically enclosing function, but can access static variables.
	This is analogous to how static member functions behave.
	)

------
int bar(int a)
{   int c;
    static int d;

    static int foo(int b)
    {
	b = d;		// ok
	b = c;		// error, foo() cannot access frame of bar()
	return b + 1;
    }
    return foo(a);
}
------

	$(P Functions can be nested within member functions:)

------
struct Foo
{   int a;

    int bar()
    {   int c;

	int foo()
	{
	    return c + a;
	}
	return 0;
    }
}
------

	$(P Member functions of nested classes and structs do not have
	access to the stack variables of the enclosing function, but
	do have access to the other symbols:
	)

------
void test()
{   int j;
    static int s;

    struct Foo
    {   int a;

	int bar()
	{   int c = s;		// ok, s is static
	    int d = j;		// error, no access to frame of test()

	    int foo()
	    {
		int e = s;	// ok, s is static
		int f = j;	// error, no access to frame of test()
		return c + a;	// ok, frame of bar() is accessible,
				// so are members of Foo accessible via
				// the 'this' pointer to Foo.bar()
	    }

	    return 0;
	}
    }
}
------

	$(P Nested functions always have the D function linkage type.
	)

	$(P Unlike module level declarations, declarations within function
	scope are processed in order. This means that two nested functions
	cannot mutually call each other:
	)

------
void test()
{
    void foo() { bar(); }	// error, bar not defined
    void bar() { foo(); }	// ok
}
------

	$(P The solution is to use a delegate:)

------
void test()
{
    void delegate() fp;
    void foo() { fp(); }
    void bar() { foo(); }
    fp = &bar;
}
------

	$(P $(B Future directions:) This restriction may be removed.)


<h3><a name="closures">Delegates, Function Pointers, and $(V1 Dynamic) Closures</a></h3>

	$(P A function pointer can point to a static nested function:)

------
int function() fp;

void test()
{   static int a = 7;
    static int foo() { return a + 3; }

    fp = &foo;
}

void bar()
{
    test();
    int i = fp();	// i is set to 10
}
------

	$(P A delegate can be set to a non-static nested function:)

------
int delegate() dg;

void test()
{   int a = 7;
    int foo() { return a + 3; }

    dg = &foo;
    int i = dg();	// i is set to 10
}
------

$(V1
	$(P The stack variables, however, are not valid once the function
	declaring them has exited, in the same manner that pointers to
	stack variables are not valid upon exit from a function:
	)

------
int* bar()
{   int b;
    test();
    int i = dg();	// error, test.a no longer exists
    return &b;		// error, bar.b not valid after bar() exits
}
------
)
$(V2
	$(P The stack variables referenced by a nested function are
	still valid even after the function exits (this is different
	from D 1.0). This is called a $(I closure).
	Returning addresses of stack variables, however, is not
	a closure and is an error.
	)

------
int* bar()
{   int b;
    test();
    int i = dg();	// ok, test.a is in a closure and still exists
    return &b;		// error, bar.b not valid after bar() exits
}
------
)

	$(P Delegates to non-static nested functions contain two pieces of
	data: the pointer to the stack frame of the lexically enclosing
	function (called the $(I frame pointer)) and the address of the
	function. This is analogous to struct/class non-static member
	function delegates consisting of a $(I this) pointer and
	the address of the member function.
	Both forms of delegates are interchangeable, and are actually
	the same type:
	)

------
struct Foo
{   int a = 7;
    int bar() { return a; }
}

int foo(int delegate() dg)
{
    return dg() + 1;
}

void test()
{
    int x = 27;
    int abc() { return x; }
    Foo f;
    int i;

    i = foo(&abc);	// i is set to 28
    i = foo(&f.bar);	// i is set to 8
}
------

	$(P This combining of the environment and the function is called
	a $(I dynamic closure).
	)

	$(P The $(B .ptr) property of a delegate will return the
	$(I frame pointer) value as a $(TT void*).
	)

	$(P The $(B .funcptr) property of a delegate will return the
	$(I function pointer) value as a function type.
	)

	$(P $(B Future directions:) Function pointers and delegates may merge
	into a common syntax and be interchangeable with each other.
	)

<h3>Anonymous Functions and Anonymous Delegates</h3>

	$(P See $(LINK2 expression.html#FunctionLiteral, Function Literals).
	)

<h2>main() Function</h2>

	$(P For console programs, $(TT main()) serves as the entry point.
	It gets called after all the module initializers are run, and
	after any unittests are run.
	After it returns, all the module destructors are run.
	$(TT main()) must be declared using one of the following forms:
	)

----
void main() { ... }
void main(char[][] args) { ... }
int main() { ... }
int main(char[][] args) { ... }
----

<h2><a name="interpretation">Compile Time Function Execution</a></h2>

	$(P A subset of functions can be executed at compile time.
	This is useful when constant folding algorithms need to
	include recursion and looping.
	In order to be executed at compile time, a function must
	meet the following criteria:
	)

	$(OL

	$(LI function arguments must all be:
	    $(UL
		$(LI integer literals)
		$(LI floating point literals)
		$(LI character literals)
		$(LI string literals)
		$(LI array literals where the members are all items
		in this list)
		$(LI associative array literals where the members are all items
		in this list)
		$(LI struct literals where the members are all items
		in this list)
		$(LI const variables initialized with a member of
		this list)
	    )
	)

	$(LI function parameters may not be variadic,
	or $(B lazy))

	$(LI the function may not be nested or synchronized)

	$(LI the function may not be a non-static member, i.e.
	it may not have a $(CODE this) pointer)

	$(LI expressions in the function may not:
	    $(UL
		$(LI throw exceptions)
		$(LI use pointers, delegates, non-const arrays,
		or classes)
		$(LI reference any global state or variables)
		$(LI reference any local static variables)
		$(LI new or delete)
		$(LI call any function that is not
		executable at compile time)
	    )
	)

	$(LI the following statement types are not allowed:
	    $(UL
		$(LI synchronized statements)
		$(LI throw statements)
		$(LI with statements)
		$(LI scope statements)
		$(LI try-catch-finally statements)
		$(LI labelled break and continue statements)
	     )
	)

	$(LI as a special case, the following properties
	can be executed at compile time:
		$(TABLE1
		$(TR $(TD $(CODE .dup)))
		$(TR $(TD $(CODE .length)))
		$(TR $(TD $(CODE .keys)))
		$(TR $(TD $(CODE .values)))
		)
	)

	)

	$(P In order to be executed at compile time, the function
	must appear in a context where it must be so executed, for
	example:)

	$(UL
	$(LI initialization of a static variable)
	$(LI dimension of a static array)
	$(LI argument for a template value parameter)
	)

---
template eval( A... )
{
    const typeof(A[0]) eval = A[0];
}

int square(int i) { return i * i; }

void foo()
{
  static j = square(3);     // compile time
  writefln(j);
  writefln(square(4));      // run time
  writefln(eval!(square(5))); // compile time
}
---

	$(P Executing functions at compile time can take considerably
	longer than executing it at run time.
	If the function goes into an infinite loop, it will hang at
	compile time (rather than hanging at run time).
	)

	$(P Functions executed at compile time can give different results
	from run time in the following scenarios:
	)

	$(UL

	$(LI floating point computations may be done at a higher
	precision than run time)
	$(LI dependency on implementation defined order of evaluation)
	$(LI use of uninitialized variables)

	)

	$(P These are the same kinds of scenarios where different
	optimization settings affect the results.)

<h3>String Mixins and Compile Time Function Execution</h3>

	$(P Any functions that execute at compile time must also
	be executable at run time. The compile time evaluation of
	a function does the equivalent of running the function at
	run time. This means that the semantics of a function cannot
	depend on compile time values of the function. For example:)

---
int foo(char[] s)
{
    return mixin(s);
}

const int x = foo("1");
---

	$(P is illegal, because the runtime code for foo() cannot be
	generated. A function template would be the appropriate
	method to implement this sort of thing.)
)

Macros:
	TITLE=Functions
	WIKI=Function

