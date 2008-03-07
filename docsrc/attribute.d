Ddoc

$(SPEC_S Attributes,

$(GRAMMAR
$(GNAME AttributeSpecifier):
    $(I Attribute) $(B :)
    $(I Attribute) $(I DeclarationBlock)

$(I Attribute):
    $(LINK2 #linkage, $(I LinkageAttribute))
    $(LINK2 #align, $(I AlignAttribute))
    $(LINK2 pragma.html, $(I Pragma))
    $(LINK2 #deprecated, $(B deprecated))
    $(GLINK ProtectionAttribute)
    $(B static)
    $(B final)
    $(LINK2 #override, $(B override))
    $(LINK2 #abstract, $(B abstract))
    $(LINK2 #const, $(B const))
    $(LINK2 #auto, $(B auto))
    $(LINK2 #scope, $(B scope))

$(I DeclarationBlock)
    $(LINK2 module.html#DeclDef, $(I DeclDef))
    $(B { })
    $(B {) $(LINK2 module.html#DeclDefs, $(I DeclDefs)) $(B })
)

	$(P Attributes are a way to modify one or more declarations.
	The general forms are:
	)

<pre>
attribute declaration;		affects the declaration

attribute:			affects all declarations until the end of
				the current scope
    declaration;
    declaration;
    ...

attribute			affects all declarations in the block
{
    declaration;
    declaration;
    ...
}
</pre>

	$(P For attributes with an optional else clause:)

<pre>
attribute
    declaration;
else
    declaration;

attribute			affects all declarations in the block
{
    declaration;
    declaration;
    ...
}
else
{
    declaration;
    declaration;
    ...
}
</pre>

<h2>$(LNAME2 linkage, Linkage Attribute)</h2>

$(GRAMMAR
$(I LinkageAttribute):
	$(B extern)
	$(B extern) $(B $(LPAREN)) $(I LinkageType) $(B $(RPAREN))

$(I LinkageType):
	$(B C)
	$(B C++)
	$(B D)
	$(B Windows)
	$(B Pascal)
	$(B System)
)

	$(P D provides an easy way to call C functions and operating
	system API functions, as compatibility with both is essential.
	The $(I LinkageType) is case sensitive, and is meant to be
	extensible by the implementation (they are not keywords).
	$(B C) and $(B D) must be supplied, the others are what
	makes sense for the implementation.
	$(B C++) is reserved for future use.
	$(B System) is the same as $(B Windows) on Windows platforms,
	and $(B C) on other platforms.
	$(B Implementation Note:)
	for Win32 platforms, $(B Windows) and $(B Pascal) should exist.
	)

	$(P C function calling conventions are 
	specified by:
	)

---------------
extern (C):
	int foo();	// call foo() with C conventions
---------------

	$(P D conventions are:)

---------------
extern (D):
---------------

	$(P or:)

---------------
extern:
---------------


	$(P Windows API conventions are:)

---------------
extern (Windows):
    void *VirtualAlloc(
    void *lpAddress,
    uint dwSize,
    uint flAllocationType,
    uint flProtect
    );
---------------

<h2>$(LNAME2 align, Align Attribute)</h2>

$(GRAMMAR
$(I AlignAttribute):
	$(B align)
	$(B align) $(B $(LPAREN)) $(I Integer) $(B $(RPAREN))
)

	$(P Specifies the alignment of struct members. $(B align) by itself
	sets it to the default, which matches the default member alignment
	of the companion C compiler. $(I Integer) specifies the alignment
	which matches the behavior of the companion C compiler when non-default
	alignments are used.
	)

	$(P Matching the behavior of the companion C compiler can have some
	surprising results, such as the following for Digital Mars C++:
	)

---------------
struct S
{   align(4) byte a;	// placed at offset 0
    align(4) byte b;	// placed at offset 1
}
---------------

	$(P $(I AlignAttribute) is meant for C ABI compatiblity, which is not
	the same thing as binary compatibility across diverse platforms.
	For that, use packed structs:
	)

---------------
align (1) struct S
{   byte a;	// placed at offset 0
    byte[3] filler1;
    byte b;	// placed at offset 4
    byte[3] filler2;
}
---------------

	$(P A value of 1 means that no alignment is done;
	members are packed together.
	)

	$(P Do not align references or pointers that were allocated
	using $(I NewExpression) on boundaries that are not
	a multiple of $(TT size_t). The garbage collector assumes that pointers
	and references to gc allocated objects will be on $(TT size_t)
	byte boundaries. If they are not, undefined behavior will
	result.
	)

	$(P $(I AlignAttribute) is ignored when applied to declarations
	that are not structs or struct members.
	)

<h2>$(LNAME2 deprecated, Deprecated Attribute)</h2>

	$(P It is often necessary to deprecate a feature in a library,
	yet retain it for backwards compatibility. Such
	declarations can be marked as deprecated, which means 
	that the compiler can be set to produce an error
	if any code refers to deprecated 
	declarations:
	)

---------------
deprecated
{
	void oldFoo();
}
---------------

	$(P $(B Implementation Note:) The compiler should have a switch
	specifying if deprecated declarations should be compiled with
	out complaint or not.
	)


<h2>Protection Attribute</h2>

$(GRAMMAR
$(GNAME ProtectionAttribute):
    $(B private)
    $(B package)
    $(B protected)
    $(B public)
    $(B export)
)

	$(P Protection is an attribute that is one of
	$(B private), $(B package), $(B protected),
	$(B public) or $(B export).
	)

	$(P Private means that only members of the enclosing class can access
	the member, or members and functions in the same module as the
	enclosing class.
	Private members cannot be overridden.
	Private module members are equivalent to $(B static) declarations
	in C programs.
	)

	$(P Package extends private so that package members can be accessed
	from code in other modules that are in the same package.
	This applies to the innermost package only, if a module is in
	nested packages.
	)

	$(P Protected means that only members of the enclosing class or any
	classes derived from that class,
	or members and functions in the same module
	as the enclosing class, can access the member.
	If accessing a protected instance member through a derived class member
	function,
	that member can only be accessed for the object instance
	which is the 'this' object for the member function call.
	Protected module members are illegal.
	)

	$(P Public means that any code within the executable can access the member.
	)

	$(P Export means that any code outside the executable can access the
	member. Export 
	is analogous to exporting definitions from a DLL.
	)

<h2>$(LNAME2 const, Const Attribute)</h2>

$(GRAMMAR
$(B const)
)

	$(P The $(B const) attribute declares constants that can be
	evaluated at compile time. For example:
	)

---------------
const int foo = 7;

const
{
    double bar = foo + 6;
}
---------------

$(V1
	$(P A const declaration without an initializer must be initialized
	in a constructor (for class fields) or in a static constructor
	(for static class members, or module variable declarations).
	)

---------------
const int x;
const int y;

static this()
{
    x = 3;	// ok
    // error: y not initialized
}

void foo()
{
    x = 4;	// error, x is const and not in static constructor
}

class C
{
    const int a;
    const int b;
    static const int c;
    static const int d;

    this()
    {   a = 3;		// ok
	a = 4;		// ok, multiple initialization allowed
	C p = this;
	p.a = 4;	// error, only members of this instance
	c = 5;		// error, should initialize in static constructor
	// error, b is not initialized
    }

    this(int x)
    {
	this();		// ok, forwarding constructor
    }

    static this()
    {
	c = 3;		// ok
	// error, d is not initialized
    }
}
---------------

	$(P It is not an error to have const module variable declarations without
	initializers if there is no constructor. This is to support the practice
	of having modules serve only as declarations that are not linked in,
	the implementation of it will be in another module that is linked in.
	)
)


<h2>$(LNAME2 override, Override Attribute)</h2>

$(GRAMMAR
$(B override)
)

	$(P The $(B override) attribute applies to virtual functions.
	It means that the function must override a function with the
	same name and parameters in a base class. The override attribute
	is useful for catching errors when a base class's member function
	gets its parameters changed, and all derived classes need to have
	their overriding functions updated.
	)

---------------
class Foo
{
    int bar();
    int abc(int x);
}

class Foo2 : Foo
{
    override
    {
	int bar(char c);	// error, no bar(char) in Foo
	int abc(int x);		// ok
    }
}
---------------

<h2>Static Attribute</h2>

$(GRAMMAR
$(B static)
)

	$(P The $(B static) attribute applies to functions and data.
	It means that the declaration does not apply to a particular
	instance of an object, but to the type of the object. In
	other words, it means there is no $(B this) reference.
	$(B static) is ignored when applied to other declarations.
	)

---------------
class Foo
{
    static int bar() { return 6; }
    int foobar() { return 7; }
}

...

Foo f = new Foo;
Foo.bar();	// produces 6
Foo.foobar();	// error, no instance of Foo
f.bar();	// produces 6;
f.foobar();	// produces 7;
---------------

$(P
	Static functions are never virtual.
)
$(P
	Static data has only one instance for the entire program,
	not once per object.
)
$(P
	Static does not have the additional C meaning of being local
	to a file. Use the $(B private) attribute in D to achieve that.
	For example:
)

---------------
module foo;
int x = 3;		// x is global
private int y = 4;	// y is local to module foo
---------------


<h2>$(LNAME2 auto, Auto Attribute)</h2>

$(GRAMMAR
$(B auto)
)

	$(P The $(B auto) attribute is used when there are no other attributes
	and type inference is desired.
	)

---
auto i = 6.8;	// declare i as a double
---

<h2>$(LNAME2 scope, Scope Attribute)</h2>

$(GRAMMAR
$(B scope)
)

$(P
	The $(B scope) attribute is used for local variables and for class
	declarations. For class declarations, the $(B scope) attribute creates
	a $(I scope) class.
	For local declarations, $(B scope) implements the RAII (Resource
	Acquisition Is Initialization) protocol. This means that the
	destructor for an object is automatically called when the
	reference to it	goes out of scope. The destructor is called even
	if the scope is exited via a thrown exception, thus $(B scope)
	is used to guarantee cleanup.
)
$(P
	If there is more than one $(B scope) variable going out of scope
	at the same point, then the destructors are called in the reverse
	order that the variables were constructed.
)
$(P
	$(B scope) cannot be applied to globals, statics, data members, ref
	or out parameters. Arrays of $(B scope)s are not allowed, and $(B scope)
	function return values are not allowed. Assignment to a $(B scope),
	other than initialization, is not allowed.
	$(B Rationale:) These restrictions may get relaxed in the future
	if a compelling reason to appears.
)

<h2>$(LNAME2 abstract, Abstract Attribute)</h2>

$(P
	If a class is abstract, it cannot be instantiated
	directly. It can only be instantiated as a base class of
	another, non-abstract, class.
)
$(P
	Classes become abstract if they are defined within an
	abstract attribute, or if any of the virtual member functions
	within it are declared as abstract.
)
$(P
	Non-virtual functions cannot be declared as abstract.
)
$(P
	Functions declared as abstract can still have function
	bodies. This is so that even though they must be overridden,
	they can still provide 'base class functionality.'
)

)

Macros:
	TITLE=Attributes
	WIKI=Attribute

