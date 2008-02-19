Ddoc

$(SPEC_S Interfaces,

$(GRAMMAR
$(I InterfaceDeclaration):
	$(B interface) $(I Identifier) $(I InterfaceBody)
	$(B interface) $(I Identifier) $(B :) $(I SuperInterfaces) $(I InterfaceBody)

$(I SuperInterfaces)
	$(I Identifier)
	$(I Identifier) $(B ,) $(I SuperInterfaces)

$(I InterfaceBody):
	$(B {) DeclDefs $(B })
)

	Interfaces describe a list of functions that a class that inherits
	from the interface must implement.
	A class that implements an interface can be converted to a reference
	to that interface. Interfaces correspond to the interface exposed
	by operating system objects, like COM/OLE/ActiveX for Win32.
	<p>

	Interfaces cannot derive from classes; only from other interfaces.
	Classes cannot derive from an interface multiple times.

------
interface D
{
    void foo();
}

class A : D, D	// error, duplicate interface
{
}
------

	An instance of an interface cannot be created.


------
interface D
{
    void foo();
}

...

D d = new D();		// error, cannot create instance of interface
------

	Interface member functions do not have implementations.

------
interface D
{
    void bar() { }	// error, implementation not allowed
}
------

	All interface functions must be defined in a class that inherits
	from that interface:

------
interface D
{
    void foo();
}

class A : D
{
    void foo() { }	// ok, provides implementation
}

class B : D
{
    int foo() { }	// error, no void foo() implementation
}
------

	Interfaces can be inherited and functions overridden:

------
interface D
{
    int foo();
}

class A : D
{
    int foo() { return 1; }
}

class B : A
{
    int foo() { return 2; }
}

...

B b = new B();
b.foo();		// returns 2
D d = cast(D) b;	// ok since B inherits A's D implementation
d.foo();		// returns 2;
------

	$(P Interfaces can be reimplemented in derived classes:)

------
interface D
{
    int foo();
}

class A : D
{
    int foo() { return 1; }
}

class B : A, D
{
    int foo() { return 2; }
}

...

B b = new B();
b.foo();		// returns 2
D d = cast(D) b;
d.foo();		// returns 2
A a = cast(A) b;
D d2 = cast(D) a;
d2.foo();		// returns 2, even though it is A's D, not B's D
------

	$(P A reimplemented interface must implement all the interface
	functions, it does not inherit them from a super class:
	)

------
interface D
{
    int foo();
}

class A : D
{
    int foo() { return 1; }
}

class B : A, D
{
}		// error, no foo() for interface D
------

$(V2
$(SECTION2 <a name="ConstInterface">Const and Invariant Interfaces</a>,
	$(P If an interface has $(CODE const) or $(CODE invariant) storage
	class, then all members of the interface are
	$(CODE const) or $(CODE invariant).
	This storage class is not inherited.
	)
)
)

$(SECTION2 COM Interfaces,

	$(P A variant on interfaces is the COM interface. A COM interface is
	designed to map directly onto a Windows COM object. Any COM object
	can be represented by a COM interface, and any D object with
	a COM interface can be used by external COM clients.
	)

	$(P A COM interface is defined as one that derives from the interface
	$(TT std.c.windows.com.IUnknown). A COM interface differs from
	a regular D interface in that:
	)

	$(UL
	$(LI It derives from the interface $(TT std.c.windows.com.IUnknown).)
	$(LI It cannot be the argument of a $(I DeleteExpression).)
	$(LI References cannot be upcast to the enclosing class object, nor
	can they be downcast to a derived interface. To accomplish this,
	an appropriate $(TT QueryInterface()) would have to be implemented
	for that interface in standard COM fashion.)
	)
)

)

Macros:
	TITLE=Interfaces
	WIKI=Interface

