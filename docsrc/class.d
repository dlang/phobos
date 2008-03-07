Ddoc

$(SPEC_S Classes,

	$(P The object-oriented features of D all come from classes. The class
	hierarchy
	has as its root the class Object. Object defines a minimum level of functionality
	that each derived class has, and a default implementation for that functionality.
	)

	$(P Classes are programmer defined types. Support for classes are what
	make D an object oriented language, giving it encapsulation, inheritance,
	and polymorphism. D classes support the single inheritance paradigm, extended
	by adding support for interfaces. Class objects are instantiated by reference
	only.
	)

	$(P A class can be exported, which means its name and all its
	non-private
	members are exposed externally to the DLL or EXE.
	)

	$(P A class declaration is defined:
	)

$(GRAMMAR
$(I ClassDeclaration):
	$(B class) $(I Identifier) $(I BaseClassList)<sub>opt</sub> $(I ClassBody)

$(I BaseClassList):
	$(B :) $(I SuperClass)
	$(B :) $(I SuperClass) $(I InterfaceClasses)
	$(B :) $(I InterfaceClass)

$(I SuperClass):
	$(I Identifier)
	$(I Protection) $(I Identifier)

$(I InterfaceClasses):
	$(I InterfaceClass)
	$(I InterfaceClass) $(I InterfaceClasses)

$(I InterfaceClass):
	$(I Identifier)
	$(I Protection) $(I Identifier)

$(I Protection):
	$(B private)
	$(B package)
	$(B public)
	$(B export)

$(I ClassBody):
	$(B {) $(B })
	$(B {) $(I ClassBodyDeclarations) $(B })

$(I ClassBodyDeclarations):
	$(I ClassBodyDeclaration)
	$(I ClassBodyDeclaration) $(I ClassBodyDeclarations)

$(I ClassBodyDeclaration):
	$(I Declaration)
	$(GLINK Constructor)
	$(GLINK Destructor)
	$(GLINK StaticConstructor)
	$(GLINK StaticDestructor)
	$(GLINK Invariant)
	$(GLINK UnitTest)
	$(GLINK ClassAllocator)
	$(GLINK ClassDeallocator)
)

Classes consist of:

$(DL
	$(DT a super class)
	$(DT interfaces)
	$(DT dynamic fields)
	$(DT static fields)
	$(DT types)
	$(DT functions)
	$(DD
	$(DL
	    $(DT static functions)
	    $(DT dynamic functions)
	    $(DT $(LINK2 #constructors, constructors))
	    $(DT $(LINK2 #destructors, destructors))
	    $(DT $(LINK2 #staticconstructor, static constructors))
	    $(DT $(LINK2 #staticdestructor, static destructors))
	    $(DT $(LINK2 #invariants, invariants))
	    $(DT $(LINK2 #unittest, unit tests))
	    $(DT $(LINK2 #allocators, allocators))
	    $(DT $(LINK2 #deallocators, deallocators))
	)
	)
)

	A class is defined:

------
class Foo
{
    ... members ...
}
------

	Note that there is no trailing ; after the closing } of the class
	definition.
	It is also not possible to declare a variable var like:

------
class Foo { } var;
------

	Instead:

------
class Foo { }
Foo var;
------

<h3>Fields</h3>

	Class members are always accessed with the . operator. There are no :: or -> 
	operators as in C++.
	<p>

	The D compiler is free to rearrange the order of fields in a class to
	optimally pack them in an implementation-defined manner.
	Consider the fields much like the local
	variables in a function - 
	the compiler assigns some to registers and shuffles others around all to
	get the optimal 
	stack frame layout. This frees the code designer to organize the fields
	in a manner that 
	makes the code more readable rather than being forced to organize it
	according to 
	machine optimization rules. Explicit control of field layout is provided
	by struct/union 
	types, not classes.

<h3>Field Properties</h3>

	The $(B .offsetof) property gives the offset in bytes of the field
	from the beginning of the class instantiation.
	$(B .offsetof) can only be applied to fields qualified with the
	type of the class, not expressions which produce the type of
	the field itself:

------
class Foo
{
    int x;
}
...
void test(Foo foo)
{
    size_t o;

    o = Foo.x$(B .offsetof);   // yields 8
    o = foo.x$(B .offsetof);   // error, .offsetof an int type
}
------

<h3>Class Properties</h3>

	$(P The $(B .tupleof) property returns an $(I ExpressionTuple)
	of all the fields
	in the class, excluding the hidden fields and the fields in the
	base class.
	)
---
class Foo { int x; long y; }
void test(Foo foo)
{
    foo.tupleof[0] = 1;		// set foo.x to 1
    foo.tupleof[1] = 2;		// set foo.y to 2
    foreach (x; foo.tupleof)
	writef(x);		// prints 12
}
---

<h3>Super Class</h3>

	All classes inherit from a super class. If one is not specified,
	it inherits from Object. Object forms the root of the D class
	inheritance hierarchy.

<h3>$(LNAME2 constructors, Constructors)</h3>

$(GRAMMAR
$(GNAME Constructor):
	$(B this) $(I Parameters) $(I FunctionBody)
)

	Members are always initialized to the default initializer
	for their type, which is usually 0 for integer types and
	NAN for floating point types.
	This eliminates an entire
	class of obscure problems that come from 
	neglecting to initialize a member in one of the constructors.
	In the class definition,
	there can be a static initializer to be 
	used instead of the default:

------
class Abc
{
    int a;	// default initializer for a is 0
    long b = 7;	// default initializer for b is 7
    float f;	// default initializer for f is NAN
}
------

	This static initialization is done before any constructors are
	called.
	<p>

	Constructors are defined with a function name of $(B this)
	and having no return value:

------
class Foo
{
    $(B this)(int x)		// declare constructor for Foo
    {   ...
    }
    $(B this)()
    {   ...
    }
}
------

	Base class construction is done by calling the base class
	constructor by the name $(B super):

------
class A { this(int y) { } }

class B : A
{
    int j;
    this()
    {
	...
	$(B super)(3);	// call base constructor A.this(3)
	...
    }
}
------

	Constructors can also call other constructors for the same class
	in order to share common initializations:

------
class C
{
    int j;
    this()
    {
	...
    }
    this(int i)
    {
	$(B this)();
	j = i;
    }
}
------

	If no call to constructors via $(B this) or $(B super) appear
	in a constructor, and the base class has a constructor, a call
	to $(B super)() is inserted at the beginning of the constructor.
	<p>

	If there is no constructor for a class, but there is a constructor
	for the base class, a default constructor of the form:

------
this() { }
------

	$(P is implicitly generated.)

	$(P Class object construction is very flexible, but some restrictions
	apply:)

	$(OL
	$(LI It is illegal for constructors to mutually call each other:

------
this() { this(1); }
this(int i) { this(); }	// illegal, cyclic constructor calls
------
	)

	$(LI If any constructor call appears inside a constructor, any
	path through the constructor must make exactly one constructor
	call:

------
this()	{ a || super(); }	// illegal

this() { (a) ? this(1) : super(); }	// ok

this()
{
    for (...)
    {
	super();	// illegal, inside loop
    }
}
------
	)

	$(LI It is illegal to refer to $(B this) implicitly or explicitly
	prior to making a constructor call.)

	$(LI Constructor calls cannot appear after labels (in order to make
	it easy to check for the previous conditions in the presence of goto's).)

	)

	$(P Instances of class objects are created with $(I NewExpression)s:)

------
A a = new A(3);
------

	$(P The following steps happen:)

$(OL
	$(LI Storage is allocated for the object.
	If this fails, rather than return $(B null), an 
	$(B OutOfMemoryException) is thrown.
	Thus, tedious checks for null references are unnecessary.
	)

	$(LI The raw data is statically initialized using the values provided
	in the class definition.
	The pointer to the vtbl[] (the array of pointers to virtual functions)
	is assigned.
	This ensures that constructors are 
	passed fully formed objects for which virtual functions can be called.
	This operation is equivalent to doing a memory copy of a static 
	version of the object onto the newly allocated one,
	although more advanced compilers 
	may be able to optimize much of this away.
	)

	$(LI If there is a constructor defined for the class,
	the constructor matching the 
	argument list is called.
	)

	$(LI If class invariant checking is turned on, the class invariant
	is called at the end of the constructor.
	)
)

<h3>$(LNAME2 destructors, Destructors)</h3>

$(GRAMMAR
$(GNAME Destructor):
	$(B ~this()) $(I FunctionBody)
)

	The garbage collector calls the destructor function when the object
	is deleted. The syntax 
	is:

------
class Foo
{
	~this()		// destructor for Foo
	{
	}
}
------

	There can be only one destructor per class, the destructor
	does not have any parameters, 
	and has no attributes. It is always virtual.
	<p>

	The destructor is expected to release any resources held by the object.
	<p>

	The  program can explicitly inform the garbage collector that an
	object is no longer referred to (with the delete expression), and
	then the garbage collector calls the destructor  
	immediately, and adds the object's memory to the free storage.
	The destructor is guaranteed to never be called twice.
	<p>

	The destructor for the super class automatically gets called when
	the destructor ends. There is no way to call the super destructor
	explicitly.
	<p>

	When the garbage collector calls a destructor for an object of a class
	that has
	members that are references to garbage collected objects, those
	references are no longer valid. This means that destructors
	cannot reference sub objects.
	This is because that the garbage collector does not collect objects
	in any guaranteed order, so there is no guarantee that any pointers
	or references to any other garbage collected objects exist when the garbage
	collector runs the destructor for an object.
	This rule does not apply to auto objects or objects deleted
	with the $(I DeleteExpression), as the destructor is not being run
	by the garbage collector, meaning all references are valid.
	<p>

	The garbage collector is not guaranteed to run the destructor
	for all unreferenced objects. Furthermore, the order in which the
	garbage collector calls destructors for unreference objects
	is not specified.
	<p>

	Objects referenced from the data segment never get collected
	by the gc.

<h3>Static Constructors</h3>

$(GRAMMAR
$(GNAME StaticConstructor):
	$(B static this()) $(I FunctionBody)
)

	A static constructor is defined as a function that performs
	initializations before the 
	$(TT main()) function gets control. Static constructors are used to
	initialize
	static class members 
	with values that cannot be computed at compile time.
	<p>

	Static constructors in other languages are built implicitly by using
	member 
	initializers that can't be computed at compile time. The trouble with
	this stems from not 
	having good control over exactly when the code is executed, for example:

------
class Foo
{
    static int a = b + 1;
    static int b = a * 2;
}
------

	What values do a and b end up with, what order are the initializations
	executed in, what 
	are the values of a and b before the initializations are run, is this a
	compile error, or is this 
	a runtime error? Additional confusion comes from it not being obvious if
	an initializer is 
	static or dynamic.
	<p>

	D makes this simple. All member initializations must be determinable by
	the compiler at 
	compile time, hence there is no order-of-evaluation dependency for
	member 
	initializations, and it is not possible to read a value that has not
	been initialized. Dynamic 
	initialization is performed by a static constructor, defined with
	a special syntax $(TT static this()).

------
class Foo
{
    static int a;		// default initialized to 0
    static int b = 1;
    static int c = b + a;	// error, not a constant initializer

    $(B static this)()		// static constructor
    {
	a = b + 1;		// a is set to 2
	b = a * 2;		// b is set to 4
    }
}
------

	$(TT static this()) is called by the startup code before
	$(TT main()) is called. If it returns normally 
	(does not throw an exception), the static destructor is added
	to the list of functions to be 
	called on program termination.
	Static constructors have empty parameter lists.
	<p>

	Static constructors within a module are executed in the lexical
	order in which they appear.
	All the static constructors for modules that are directly or
	indirectly imported
	are executed before the static constructors for the importer.
	<p>

	The $(B static) in the static constructor declaration is not
	an attribute, it must appear immediately before the $(B this):

------
class Foo
{
    static this() { ... }	// a static constructor
    static private this() { ... } // not a static constructor
    static
    {
	this() { ... }		// not a static constructor
    }
    static:
	this() { ... }		// not a static constructor
}
------

<h3>Static Destructors</h3>

$(GRAMMAR
$(GNAME StaticDestructor):
	$(B static ~this()) $(I FunctionBody)
)

	A static destructor is defined as a special static function with the
	syntax $(TT static ~this()).

------
class Foo
{
    static ~this()		// static destructor
    {
    }
}
------

	A static destructor gets called on program termination, but only if
	the static constructor 
	completed successfully.
	Static destructors have empty parameter lists.
	Static destructors get called in the reverse order that the static
	constructors were called in.
	<p>

	The $(B static) in the static destructor declaration is not
	an attribute, it must appear immediately before the $(B ~this):

------
class Foo
{
    static ~this() { ... }	// a static destructor
    static private ~this() { ... } // not a static destructor
    static
    {
	~this() { ... }		// not a static destructor
    }
    static:
	~this() { ... }		// not a static destructor
}
------

<h3>$(LNAME2 invariants, Class Invariants)</h3>

$(GRAMMAR
$(GNAME Invariant):
	$(B invariant()) $(I BlockStatement)
)

    Class invariants are used to specify characteristics of a class that always
    must be true (except while executing a member function). For example, a
    class representing a date might have an invariant that the day must be 1..31
    and the hour must be 0..23:

------
class Date
{
    int day;
    int hour;

    $(B invariant())
    {
	assert(1 <= day && day <= 31);
	assert(0 <= hour && hour < 24);
    }
}
------

	$(P The class invariant is a contract saying that the asserts must hold
	true.
	The invariant is checked when a class constructor completes,
	at the start of the class destructor, before a public or exported
	member is run, and after a public or exported function finishes.
	)

	$(P The code in the invariant may not call any public non-static members
	of the
	class, either directly or indirectly.
	Doing so will result in a stack overflow, as the invariant will wind
	up being called in an infinitely recursive manner.
	)

	$(P Since the invariant is called at the start of public or
	exported members, such members should not be called from
	constructors.
	)

------
class Foo
{
    public void f() { }
    private void g() { }

    $(B invariant())
    {
	f();  // error, cannot call public member function from invariant
	g();  // ok, g() is not public
    }
}
------

	The invariant
	can be checked when a class object is the argument to an
	<code>assert()</code> expression, as:

------
Date mydate;
...
assert(mydate);		// check that class Date invariant holds
------

	Invariants contain assert expressions, and so when they fail,
	they throw a $(TT AssertError)s.
	Class invariants are inherited, that is,
	any class invariant is implicitly anded with the invariants of its base
	classes.
	<p>

	There can be only one $(I Invariant) per class.
	<p>

	When compiling for release, the invariant code is not generated, and the compiled program
	runs at maximum speed.

<h3>Unit Tests</h3>

$(GRAMMAR
$(GNAME UnitTest):
	$(B unittest) $(I FunctionBody)
)

	Unit tests are a series of test cases applied to a class to determine
	if it is working properly. Ideally, unit tests should be run every
	time a program is compiled. The best way to make sure that unit
	tests do get run, and that they are maintained along with the class
	code is to put the test code right in with the class implementation
	code.
	<p>

	Classes can have a special member function called:

------
unittest
{
    ...test code...
}
------

	A compiler switch, such as $(B -unittest) for $(B dmd), will
	cause the unittest test code to be compiled and incorporated into
	the resulting executable. The unittest code gets run after
	static initialization is run and before the $(TT main())
	function is called.
	<p>

	For example, given a class Sum that is used to add two values:

------
class Sum
{
    int add(int x, int y) { return x + y; }

    unittest
    {
	Sum sum = new Sum;
	assert(sum.add(3,4) == 7);
	assert(sum.add(-2,0) == -2);
    }
}
------

<h3>$(LNAME2 allocators, Class Allocators)</h3>

$(GRAMMAR
$(GNAME ClassAllocator):
	$(B new) $(I Parameters) $(I FunctionBody)
)

	A class member function of the form:

------
new(uint size)
{
    ...
}
------

	is called a class allocator.
	The class allocator can have any number of parameters, provided
	the first one is of type uint.
	Any number can be defined for a class, the correct one is
	determined by the usual function overloading rules.
	When a new expression:

------
new Foo;
------

	is executed, and Foo is a class that has
	an allocator, the allocator is called with the first argument
	set to the size in bytes of the memory to be allocated for the
	instance.
	The allocator must allocate the memory and return it as a
	$(TT void*).
	If the allocator fails, it must not return a $(B null), but
	must throw an exception.
	If there is more than one parameter to the allocator, the
	additional arguments are specified within parentheses after
	the $(B new) in the $(I NewExpression):

------
class Foo
{
    this(char[] a) { ... }

    new(uint size, int x, int y)
    {
	...
    }
}

...

new(1,2) Foo(a);	// calls new(Foo.sizeof,1,2)
------

	$(P Derived classes inherit any allocator from their base class,
	if one is not specified.
	)

	$(P The class allocator is not called if the instance is created
	on the stack.
	)

	$(P See also
	$(LINK2 memory.html#newdelete, Explicit Class Instance Allocation).
	)

<h3>$(LNAME2 deallocators, Class Deallocators)</h3>

$(GRAMMAR
$(GNAME ClassDeallocator):
	$(B delete) $(I Parameters) $(I FunctionBody)
)

	A class member function of the form:

------
delete(void *p)
{
    ...
}
------

	is called a class deallocator.
	The deallocator must have exactly one parameter of type $(TT void*).
	Only one can be specified for a class.
	When a delete expression:

------
delete f;
------

	$(P is executed, and f is a reference to a class instance that has
	a deallocator, the deallocator is called with a pointer to the
	class instance after the destructor (if any) for the class is
	called. It is the responsibility of the deallocator to free
	the memory.
	)

	$(P Derived classes inherit any deallocator from their base class,
	if one is not specified.
	)

	$(P The class allocator is not called if the instance is created
	on the stack.
	)

	$(P See also
	$(LINK2 memory.html#newdelete, Explicit Class Instance Allocation).
	)

<h3>$(LNAME2 auto, Scope Classes)</h3>

	A scope class is a class with the $(B scope) attribute, as in:

------
scope class Foo { ... }
------

	The scope characteristic is inherited, so if any classes derived
	from a scope class are also scope.
	<p>

	An scope class reference can only appear as a function local variable.
	It must be declared as being $(B scope):

------
scope class Foo { ... }

void func()
{
    Foo f;	// error, reference to scope class must be scope
    scope Foo g = new Foo();	// correct
}
------

	When an scope class reference goes out of scope, the destructor
	(if any) for it is automatically called. This holds true even if
	the scope was exited via a thrown exception.

<h3>$(LNAME2 final, Final Classes)</h3>

	$(P Final classes cannot be subclassed:)

---
final class A { }
class B : A { }  // error, class A is final
---

<h2>$(LNAME2 nested, Nested Classes)</h2>

	A $(I nested class) is a class that is declared inside the scope
	of a function or another class.
	A nested class has access to the variables and other symbols
	of the classes and functions it is nested inside:

------
class Outer
{
    int m;

    class Inner
    {
	int foo()
	{
	    return m;	// Ok to access member of Outer
	}
    }
}

void func()
{   int m;

    class Inner
    {
	int foo()
	{
	    return m;	// Ok to access local variable m of func()
	}
    }
}
------

	If a nested class has the $(B static) attribute, then it can
	not access variables of the enclosing scope that are local to the
	stack or need a $(B this):

------
class Outer
{
    int m;
    static int n;

    static class Inner
    {
	int foo()
	{
	    return m;	// Error, Inner is static and m needs a $(B this)
	    return n;	// Ok, n is static
	}
    }
}

void func()
{   int m;
    static int n;

    static class Inner
    {
	int foo()
	{
	    return m;	// Error, Inner is static and m is local to the stack
	    return n;	// Ok, n is static
	}
    }
}
------

	Non-static nested classes work by containing an extra hidden member
	(called the context pointer)
	that is the frame pointer of the enclosing function if it is nested
	inside a function, or the $(B this) of the enclosing class's instance
	if it is nested inside a class.
	<p>

	When a non-static nested class is instantiated, the context pointer
	is assigned before the class's constructor is called, therefore
	the constructor has full access to the enclosing variables.
	A non-static nested class can only be instantiated when the necessary
	context pointer information is available:

------
class Outer
{
    class Inner { }

    static class SInner { }
}

void func()
{
    class Nested { }

    Outer o = new Outer;	// Ok
    Outer.Inner oi = new Outer.Inner;	// Error, no 'this' for Outer
    Outer.SInner os = new Outer.SInner;	// Ok

    Nested n = new Nested;	// Ok
}
------

	While a non-static nested class can access the stack variables
	of its enclosing function, that access becomes invalid once
	the enclosing function exits:

------
class Base
{
    int foo() { return 1; }
}

Base func()
{   int m = 3;

    class Nested : Base
    {
	int foo() { return m; }
    }

    Base b = new Nested;

    assert(b.foo() == 3);	// Ok, func() is still active
    return b;
}

int test()
{
    Base b = func();
    return b.foo();		// Error, func().m is undefined
}
------

	If this kind of functionality is needed, the way to make it work
	is to make copies of the needed variables within the nested class's
	constructor:

------
class Base
{
    int foo() { return 1; }
}

Base func()
{   int m = 3;

    class Nested : Base
    {   int m_;

	this() { m_ = m; }
	int foo() { return m_; }
    }

    Base b = new Nested;

    assert(b.foo() == 3);	// Ok, func() is still active
    return b;
}

int test()
{
    Base b = func();
    return b.foo();		// Ok, using cached copy of func().m
}
------

	$(P A $(I this) can be supplied to the creation of an
	inner class instance by prefixing it to the $(I NewExpression):
	)

---------
class Outer
{   int a;

    class Inner
    {
	int foo()
	{
	    return a;
	}
    }
}

int bar()
{
    Outer o = new Outer; 
    o.a = 3;
    Outer.Inner oi = $(B o).new Inner;
    return oi.foo();	// returns 3
}
---------

	$(P Here $(B o) supplies the $(I this) to the outer class
	instance of $(B Outer).
	)

	$(P The property $(B .outer) used in a nested class gives the
	$(B this) pointer to its enclosing class. If the enclosing
	context is not a class, the $(B .outer) will give the pointer
	to it as a $(B void*) type.
	)

----
class Outer
{
    class Inner
    {
	Outer foo()
	{
	    return this.$(B outer);
	}
    }

    void bar()
    {
	Inner i = new Inner;
	assert(this == i.foo());
    }
}

void test()
{
    Outer o = new Outer;
    o.bar();
}
----

<h3>$(LNAME2 anonymous, Anonymous Nested Classes)</h3>

	$(P An anonymous nested class is both defined and instantiated with
	a $(I NewAnonClassExpression):
	)

$(GRAMMAR
$(I NewAnonClassExpression):
    $(B new $(LPAREN))$(I ArgumentList)$(B $(RPAREN))<sub>opt</sub> $(B class $(LPAREN))$(I ArgumentList)$(B $(RPAREN))<sub>opt</sub> $(I SuperClass)<sub>opt</sub> $(I InterfaceClasses)<sub>opt</sub> $(I ClassBody)
)

	$(P which is equivalent to:
	)

------
class $(I Identifier) : $(I SuperClass) $(I InterfaceClasses)
	$(I ClassBody)

new ($(I ArgumentList)) $(I Identifier) ($(I ArgumentList));
------

	$(P where $(I Identifier) is the name generated for the anonymous
	nested class.
	)

$(V2
$(SECTION3 <a name="ConstClass">Const and Invariant Classes</a>,
	$(P If a $(I ClassDeclaration) has a $(CODE const) or $(CODE invariant)
	storage class, then it is as if each member of the class
	was declared with that storage class.
	If a base class is const or invariant, then all classes derived
	from it are also const or invariant.
	)
)
)

)

Macros:
	TITLE=Classes
	WIKI=Class
	GLINK=$(LINK2 #$0, $(I $0))
	GNAME=<a name=$0>$(I $0)</a>
	DOLLAR=$
	FOO=

