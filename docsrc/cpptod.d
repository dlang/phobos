Ddoc

$(COMMUNITY Programming in D for C++ Programmers,

<img src="cpp1.gif" border=0 align=right alt="C++">

Every experienced C++ programmer accumulates a series of idioms and techniques
which become second nature. Sometimes, when learning a new language, those
idioms can be so comfortable it's hard to see how to do the equivalent in the
new language. So here's a collection of common C++ techniques, and how to do the
corresponding task in D.
<p>

See also: <a href="ctod.html">Programming in D for C Programmers</a>

$(UL
	$(LI $(LINK2 #constructors, Defining Constructors))
	$(LI $(LINK2 #baseclass, Base class initialization))
	$(LI $(LINK2 #structcmp, Comparing structs))
	$(LI $(LINK2 #typedefs, Creating a new typedef'd type))
	$(LI $(LINK2 #friends, Friends))
	$(LI $(LINK2 #operatoroverloading, Operator overloading))
	$(LI $(LINK2 #usingdeclaration, Namespace using declarations))
	$(LI $(LINK2 #raii, RAII (Resource Acquisition Is Initialization)))
	$(LI $(LINK2 #properties, Properties))
	$(LI $(LINK2 #recursivetemplates, Recursive Templates))
	$(LI $(LINK2 #metatemplates, Meta Templates))
	$(LI $(LINK2 #typetraits, Type Traits))
)


<hr><!-- -------------------------------------------- -->

<h3><a name="constructors">Defining constructors</a></h3>

<h4>The C++ Way</h4>

	Constructors have the same name as the class:

$(CPPCODE
class Foo
{
	Foo(int x); 
};
)

<h4>The D Way</h4>

	Constructors are defined with the this keyword:

------
class Foo
{
	this(int x) { } 
}
------

	which reflects how they are used in D.

<hr><!-- -------------------------------------------- -->
<h3><a name="baseclass">Base class initialization</a></h3>

<h4>The C++ Way</h4>

	Base constructors are called using the base initializer syntax.

$(CPPCODE
class A { A() {... } };
class B : A
{
     B(int x)
	: A()		// call base constructor 
     {	...
     }
};)

<h4>The D Way</h4>

	The base class constructor is called with the super syntax:

------
class A { this() { ... } }
class B : A
{
     this(int x)
     {	...
	super();	// call base constructor 
	...
     }
}
------

	It's superior to C++ in that the base constructor call can be flexibly placed anywhere in the derived 
	constructor. D can also have one constructor call another one:

------
class A
{	int a;
	int b;
	this() { a = 7; b = foo(); } 
	this(int x)
	{
	    this();
	    a = x;
	}
}
------

	Members can also be initialized to constants before the constructor is ever called, so the above example is 
	equivalently written as:

------
class A
{	int a = 7;
	int b;
	this() { b = foo(); } 
	this(int x)
	{
	    this();
	    a = x;
	}
}
------

<hr><!-- -------------------------------------------- -->
<h3><a name="structcmp">Comparing structs</a></h3>

<h4>The C++ Way</h4>

	While C++ defines struct assignment in a simple, convenient manner:

$(CPPCODE
struct A x, y; 
...
x = y;
)

	it does not for struct comparisons. Hence, to compare two struct
	instances for equality:

$(CPPCODE
#include &lt;string.h&gt;

struct A x, y;

inline bool operator==(const A&amp; x, const A&amp; y)
{
    return (memcmp(&amp;x, &amp;y, sizeof(struct A)) == 0); 
}
...
if (x == y)
    ...
)

	Note that the operator overload must be done for every struct
	needing to be compared, and the implementation of that overloaded
	operator is free of any language help with type checking.
	The C++ way has an additional problem in that just inspecting the
	(x == y) does not give a clue what is actually happening, you have
	to go and find the particular overloaded operator==() that applies
	to verify what it really does.
	<p>

	There's a nasty bug lurking in the memcmp() implementation of operator==().
	The layout of a struct, due to alignment, can have 'holes' in it.
	C++ does not guarantee those holes are assigned any values, and so
	two different struct instances can have the same value for each member,
	but compare different because the holes contain different garbage.
	<p>

	To address this, the operator==() can be implemented to do a memberwise
	compare. Unfortunately, this is unreliable because (1) if a member is added
	to the struct definition one may forget to add it to operator==(), and
	(2) floating point nan values compare unequal even if their bit patterns
	match.
	<p>

	There just is no robust solution in C++.

<h4>The D Way</h4>

	D does it the obvious, straightforward way:

------
A x, y;
...
if (x == y) 
    ...
------

<hr><!-- -------------------------------------------- -->
<h3><a name="typedefs">Creating a new typedef'd type</a></h3>

<h4>The C++ Way</h4>

	Typedef's in C++ are weak, that is, they really do not introduce
	a new type. The compiler doesn't distinguish between a typedef
	and its underlying type.

$(CPPCODE
#define HANDLE_INIT	((Handle)(-1))
typedef void *Handle;
void foo(void *);
void bar(Handle);

Handle h = HANDLE_INIT;
foo(h);			// coding bug not caught 
bar(h);			// ok
)

	The C++ solution is to create a dummy struct whose sole
	purpose is to get type checking and overloading on the new type.

$(CPPCODE
#define HANDLE_INIT	((void *)(-1)) 
struct Handle
{   void *ptr;

    // default initializer
    Handle() { ptr = HANDLE_INIT; }

    Handle(int i) { ptr = (void *)i; }

    // conversion to underlying type 
    operator void*() { return ptr; }
};
void bar(Handle);

Handle h;
bar(h);
h = func();
if (h != HANDLE_INIT)
    ...
)

<h4>The D Way</h4>

	No need for idiomatic constructions like the above. Just write:

------
typedef void* Handle = cast(void*)-1; 
void bar(Handle);

Handle h;
bar(h);
h = func();
if (h != Handle.init)
    ...
------

	Note how a default initializer can be supplied for the typedef as
	a value of the underlying type.

<hr><!-- -------------------------------------------- -->
<h3><a name="friends">Friends</a></h3>

<h4>The C++ Way</h4>

	Sometimes two classes are tightly related but not by inheritance,
	but need to access each other's private members. This is done
	using $(TT friend) declarations:

$(CPPCODE
class A
{
    private:
	int a;

    public:
	int foo(B *j);
	friend class B;
	friend int abc(A *);
};

class B
{
    private:
	int b;

    public:
	int bar(A *j);
	friend class A;
};

int A::foo(B *j) { return j->b; }
int B::bar(A *j) { return j->a; } 

int abc(A *p) { return p->a; }
)

<h4>The D Way</h4>

	In D, friend access is implicit in being a member of the same
	module. It makes sense that tightly related classes should be
	in the same module, so implicitly granting friend access to
	other module members solves the problem neatly:

------
module X;

class A
{
    private:
	static int a;

    public:
	int foo(B j) { return j.b; }
}

class B
{
    private:
	static int b;

    public:
	int bar(A j) { return j.a; } 
}

int abc(A p) { return p.a; }
------

	The $(TT private) attribute prevents other modules from
	accessing the members.

<hr><!-- -------------------------------------------- -->
<h3><a name="operatoroverloading">Operator overloading</a></h3>

<h4>The C++ Way</h4>

	Given a struct that creates a new arithmetic data type,
	it's convenient to overload the comparison operators so
	it can be compared against integers:

$(CPPCODE
struct A
{
	int operator &lt;  (int i);
	int operator &lt;= (int i);
	int operator &gt;  (int i);
	int operator &gt;= (int i);
};

int operator &lt;  (int i, A &a) { return a &gt;  i; }
int operator &lt;= (int i, A &a) { return a &gt;= i; }
int operator &gt;  (int i, A &a) { return a &lt;  i; }
int operator &gt;= (int i, A &a) { return a &lt;= i; } 
)

	A total of 8 functions are necessary.

<h4>The D Way</h4>

	D recognizes that the comparison operators are all fundamentally
	related to each other. So only one function is necessary:

------
struct A
{
	int opCmp(int i); 
}
------

	The compiler automatically interprets all the
	&lt;, &lt;=, &gt; and &gt;=
	operators in terms of the $(TT cmp) function, as well
	as handling the cases where the left operand is not an
	object reference.
	<p>

	Similar sensible rules hold for other operator overloads,
	making using operator overloading in D much less tedious and less
	error prone. Far less code needs to be written to accomplish
	the same effect.

<hr><!-- -------------------------------------------- -->
<h3><a name="usingdeclaration">Namespace using declarations</a></h3>

<h4>The C++ Way</h4>

	A $(I using-declaration) in C++ is used to bring a name from
	a namespace scope into the current scope:

$(CPPCODE
namespace foo
{
    int x;
}
using foo::x;
)

<h4>The D Way</h4>

	D uses modules instead of namespaces and #include files, and
	alias declarations take the place of using declarations:

------
/** Module foo.d **/
module foo;
int x;

/** Another module **/ 
import foo;
alias foo.x x;
------

	Alias is a much more flexible than the single purpose using
	declaration. Alias can be used to rename symbols, refer to
	template members, refer to nested class types, etc.

<hr><!-- -------------------------------------------- -->
<h3><a name="raii">RAII (Resource Acquisition Is Initialization)</a></h3>

<h4>The C++ Way</h4>

	In C++, resources like memory, etc., all need to be handled
	explicitly. Since destructors automatically get called when
	leaving a scope, RAII is implemented by putting the resource
	release code into the destructor:

$(CPPCODE
class File
{   Handle *h;

    ~File()
    {
	h->release(); 
    }
};
)

<h4>The D Way</h4>

	The bulk of resource release problems are simply keeping track
	of and freeing memory. This is handled automatically in D by
	the garbage collector. The second common resources used are semaphores
	and locks, handled automatically with D's $(TT synchronized)
	declarations and statements.
	<p>

	The few RAII issues left are handled by $(I scope) classes.
	Scope classes get their destructors run when they go out of scope.

------
scope class File
{   Handle h;

    ~this()
    {
	h.release();
    }
}

void test()
{
    if (...)
    {   scope f = new File();
	...
    } // f.~this() gets run at closing brace, even if 
      // scope was exited via a thrown exception
}
------

<hr><!-- -------------------------------------------- -->
<h3><a name="properties">Properties</a></h3>

<h4>The C++ Way</h4>

	It is common practice to define a field,
	along with object-oriented
	get and set functions for it:

$(CPPCODE
class Abc
{
  public:
    void setProperty(int newproperty) { property = newproperty; } 
    int getProperty() { return property; }

  private:
    int property;
};

Abc a;
a.setProperty(3);
int x = a.getProperty();
)

	All this is quite a bit of typing, and it tends to make
	code unreadable by filling
	it with getProperty() and setProperty() calls.

<h4>The D Way</h4>

	Properties can be get and set using the normal field syntax,
	yet the get and set will invoke methods instead.

------
class Abc
{
    // set 
    void property(int newproperty) { myprop = newproperty; }

    // get
    int property() { return myprop; }

  private:
    int myprop;
}
------

	which is used as:

------
Abc a;
a.property = 3;		// equivalent to a.property(3)
int x = a.property;	// equivalent to int x = a.property() 
------

	Thus, in D a property can be treated like it was a simple field name.
	A property can start out actually being a simple field name,
	but if later if becomes 
	necessary to make getting and setting it function calls,
	no code needs to be modified other 
	than the class definition.
	It obviates the wordy practice of defining get and set properties
	'just in case' a derived class should need to override them.
	It's also a way to have interface classes, which do not have
	data fields, behave syntactically as if they did.

<hr><!-- -------------------------------------------- -->
<h3><a name="recursivetemplates">Recursive Templates</a></h3>

<h4>The C++ Way</h4>

	An advanced use of templates is to recursively expand
	them, relying on specialization to end it. A template
	to compute a factorial would be:

$(CPPCODE
template&lt;int n&gt; class factorial
{
    public:
	enum { result = n * factorial&lt;n - 1&gt;::result }; 
};

template&lt;&gt; class factorial&lt;1&gt;
{
    public:
	enum { result = 1 };
};

void test()
{
    printf("%d\n", factorial&lt;4&gt;::result); // prints 24
}
)

<h4>The D Way</h4>

	The D version is analogous, though a little simpler, taking
	advantage of promotion of single template members to the
	enclosing name space:

------
template factorial(int n)
{
    enum { factorial = n * .factorial!(n-1) }
}

template factorial(int n : 1)
{
    enum { factorial = 1 }
}

void test()
{
    writefln("%d", factorial!(4));	// prints 24 
}
------

<hr><!-- -------------------------------------------- -->

<h3><a name="metatemplates">Meta Templates</a></h3>

	The problem: create a typedef for a signed integral type that is at
	least $(I nbits) in size.

<h4>The C++ Way</h4>

	This example is simplified and adapted from one written by
	Dr. Carlo Pescio in
	<a href="http://www.eptacom.net/pubblicazioni/pub_eng/paramint.html">
	Template Metaprogramming: Make parameterized integers portable with this novel technique</a>.
	<p>

	There is no way in C++ to do conditional compilation based
	on the result of an expression based on template parameters, so
	all control flow follows from pattern matching of the template
	argument against various explicit template specializations.
	Even worse, there is no way to do template specializations based
	on relationships like "less than or equal to", so the example
	uses a clever technique where the template is recursively expanded,
	incrementing the template value argument by one each time, until
	a specialization matches.
	If there is no match, the result is an unhelpful recursive compiler
	stack overflow or internal error, or at best a strange syntax
	error.
	<p>

	A preprocessor macro is also needed to make up for the lack
	of template typedefs.

$(CPPCODE
#include &lt;limits.h&gt;

template&lt; int nbits &gt; struct Integer
{
    typedef Integer&lt; nbits + 1 &gt; :: int_type int_type ;
} ;

struct Integer&lt; 8 &gt;
{
    typedef signed char int_type ;
} ;

struct Integer&lt; 16 &gt; 
{
    typedef short int_type ;
} ;

struct Integer&lt; 32 &gt; 
{
    typedef int int_type ;
} ;

struct Integer&lt; 64 &gt;
{
    typedef long long int_type ;
} ;

// If the required size is not supported, the metaprogram
// will increase the counter until an internal error is
// signaled, or INT_MAX is reached. The INT_MAX 
// specialization does not define a int_type, so a 
// compiling error is always generated
struct Integer&lt; INT_MAX &gt;
{
} ;

// A bit of syntactic sugar
#define Integer( nbits ) Integer&lt; nbits &gt; :: int_type 

#include &lt;stdio.h&gt;

int main()
{
    Integer( 8 ) i ;
    Integer( 16 ) j ;
    Integer( 29 ) k ;
    Integer( 64 ) l ;
    printf("%d %d %d %d\n",
	sizeof(i), sizeof(j), sizeof(k), sizeof(l)); 
    return 0 ;
}
)

<h4>The C++ Boost Way</h4>

	This version uses the C++ Boost library. It was provided
	by David Abrahams.

$(CPPCODE
#include &lt;boost/mpl/if.hpp&gt;
#include &lt;boost/mpl/assert.hpp&gt;

template &lt;int nbits&gt; struct Integer
    : mpl::if_c&lt;(nbits &lt;= 8), signed char
    , mpl::if_c&lt;(nbits &lt;= 16), short
    , mpl::if_c&lt;(nbits &lt;= 32), long
    , long long&gt;::type &gt;::type &gt;
{
    BOOST_MPL_ASSERT_RELATION(nbits, &lt;=, 64);
}

#include &lt;stdio.h&gt;

int main()
{
    Integer&lt; 8 &gt; i ;
    Integer&lt; 16 &gt; j ;
    Integer&lt; 29 &gt; k ;
    Integer&lt; 64 &gt; l ;
    printf("%d %d %d %d\n",
	sizeof(i), sizeof(j), sizeof(k), sizeof(l)); 
    return 0 ;
}
)

<h4>The D Way</h4>

	The D version could also be written with recursive templates,
	but there's a better way.
	Unlike the C++ example, this one is fairly easy to
	figure out what is going on.
	It compiles quickly, and gives a sensible compile time message
	if it fails.

------
import std.stdio;

template Integer(int nbits)
{
    static if (nbits <= 8)
	alias byte Integer;
    else static if (nbits <= 16)
	alias short Integer;
    else static if (nbits <= 32)
	alias int Integer;
    else static if (nbits <= 64)
	alias long Integer;
    else
	static assert(0);
}

int main()
{
    Integer!(8) i ;
    Integer!(16) j ;
    Integer!(29) k ;
    Integer!(64) l ;
    writefln("%d %d %d %d",
	i.sizeof, j.sizeof, k.sizeof, l.sizeof); 
    return 0;
}
------

<hr><!-- -------------------------------------------- -->

<h3><a name="typetraits">Type Traits</a></h3>

	Type traits are another term for being able to find out
	properties of a type at compile time.

<h4>The C++ Way</h4>

	The following template comes from
	<a href="http://www.amazon.com/exec/obidos/ASIN/0201734842/ref=ase_classicempire/102-2957199-2585768">
	C++ Templates: The Complete Guide, David Vandevoorde, Nicolai M. Josuttis</a>
	pg. 353 which determines if the template's argument type
	is a function:

$(CPPCODE
template&lt;typename T&gt; class IsFunctionT
{
    private:
	typedef char One;
	typedef struct { char a[2]; } Two;
	template&lt;typename U&gt; static One test(...);
	template&lt;typename U&gt; static Two test(U (*)[1]);
    public:
	enum { Yes = sizeof(IsFunctionT&lt;T&gt;::test&lt;T&gt;(0)) == 1 };
};

void test()
{
    typedef int (fp)(int);

    assert(IsFunctionT&lt;fp&gt;::Yes == 1);
}
)

	This template relies on the $(SFINAE) principle.
	Why it works is a fairly advanced template topic.

<h4>The D Way</h4>

	$(ACRONYM SFINAE, Substitution Failure Is Not An Error)
	can be done in D without resorting to template argument
	pattern matching:

------
template IsFunctionT(T)
{
    static if ( is(T[]) )
	const int IsFunctionT = 0;
    else
	const int IsFunctionT = 1;
}

void test()
{
    typedef int fp(int);

    assert(IsFunctionT!(fp) == 1);
}
------

	The task of discovering if a type is a function doesn't need a
	template at all, nor does it need the subterfuge of attempting to
	create the invalid array of functions type.
	The $(ISEXPRESSION) expression can test it directly:

------
void test()
{
    alias int fp(int);

    assert( is(fp == function) );
}
------


)

Macros:
	TITLE=Programming in D for C++ Programmers
	WIKI=CPPtoD

