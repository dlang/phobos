Ddoc

$(COMMUNITY D's Contract Programming vs C++'s,

	Many people have written me saying that D's Contract Programming
	(DbC) does not add anything that C++ does not already support.
	They go on to illustrate their point with a technique for doing DbC in
	C++.
	<p>

	It makes sense to review what DbC is, how it is done in D,
	and stack that up with what each of the various C++ DbC techniques
	can do.
	<p>

	Digital Mars C++ adds
	<a href="../ctg/contract.html">extensions to C++</a>
	to support DbC, but they are not covered here because they are not
	part of standard C++ and are not supported by any other C++ compiler.

<h2>Contract Programming in D</h2>

	This is more fully documented in the D
	<a href="dbc.html">Contract Programming</a> document.
	To sum up, DbC in D has the following characteristics:

	$(OL 

	$(LI The $(I assert) is the basic contract.
	)

	$(LI When an assert contract fails, it throws an exception.
	Such exceptions can be caught and handled, or allowed to
	terminate the program.
	)

	$(LI Classes can have $(I class invariants) which are
	checked upon entry and exit of each public class member function,
	the exit of each constructor, and the entry of the destructor.
	)

	$(LI Assert contracts on object references check the class
	invariant for that object.
	)

	$(LI Class invariants are inherited, that means that a derived
	class invariant will implicitly call the base class invariant.
	)

	$(LI Functions can have $(I preconditions) and $(I postconditions).
	)

	$(LI For member functions in a class inheritance hierarchy, the
	precondition of a derived class function are OR'd together
	with the preconditions of all the functions it overrides.
	The postconditions are AND'd together.
	)

	$(LI By throwing a compiler switch, DbC code can be enabled
	or can be withdrawn from the compiled code.
	)

	$(LI Code works semantically the same with or without DbC
	checking enabled.
	)

	)

<h2>Contract Programming in C++</h2>

<h3>The $(TT assert) Macro</h3>

	C++ does have the basic $(TT assert) macro, which tests its argument
	and if it fails, aborts the program. $(TT assert) can be turned
	on and off with the $(TT NDEBUG) macro.
	<p>

	$(TT assert) does not know anything about class invariants,
	and does not throw an exception when it fails. It just aborts
	the program after writing a message. $(TT assert) relies on
	a macro text preprocessor to work.
	<p>

	$(TT assert) is where explicit support for DbC in Standard C++
	begins and ends.

<h3>Class Invariants</h3>

	Consider a class invariant in D:

----------
class A
{
    $(B invariant)() { ...contracts... }

    this() { ... }	// constructor
    ~this() { ... }	// destructor

    void foo() { ... }	// public member function
}

class B : A
{
    $(B invariant)() { ...contracts... }
    ...
}
----------

	To accomplish the equivalent in C++ (thanks to Bob Bell for providing
	this):

$(CCODE
template<typename T>
inline void check_invariant(T& iX)
{
#ifdef DBC
    iX.invariant();
#endif
}

// A.h:

class A {
    public:
#ifdef DBG
       virtual void invariant() { ...contracts... }
#endif
       void foo();
};

// A.cpp:

void A::foo()
{
    check_invariant(*this);
    ...
    check_invariant(*this);
}

// B.h:

#include "A.h"

class B : public A {
    public:
#ifdef DBG
	virtual void invariant()
	{   ...contracts...
	   A::invariant();
	}
#endif
       void bar();
};

// B.cpp:

void B::barG()
{
    check_invariant(*this);
    ...
    check_invariant(*this);
}
)

	There's an additional complication with $(TT A::foo()). Upon every
	normal exit from the function, the $(TT invariant()) should be
	called.
	This means that code that looks like:

$(CCODE
int A::foo()
{
    ...
    if (...)
	return bar();
    return 3;
}
)

	would need to be written as:

$(CCODE
int A::foo()
{
    int result;
    check_invariant(*this);
    ...
    if (...)
    {
	result = bar();
	check_invariant(*this);
	return result;
    }
    check_invariant(*this);
    return 3;
}
)

	Or recode the function so it has a single exit point.
	One possibility to mitigate this is to use RAII techniques:

$(CCODE
int A::foo()
{
#if DBC
    struct Sentry {
       Sentry(A& iA) : mA(iA) { check_invariants(iA); }
       ~Sentry() { check_invariants(mA); }
       A& mA;
    } sentry(*this);
#endif
    ...
    if (...)
	return bar();
    return 3;
}
)

	The #if DBC is still there because some compilers may not
	optimize the whole thing away if check_invariants compiles to nothing.

<h2>Preconditions and Postconditions</h2>

	Consider the following in D:

----------
void foo()
    in { ...preconditions... }
    out { ...postconditions... }
    body
    {
	...implementation...
    }
----------

	This is nicely handled in C++ with the nested Sentry struct:

$(CCODE
void foo()
{
    struct Sentry
    {   Sentry() { ...preconditions... }
	~Sentry() { ...postconditions... }
    } sentry;
    ...implementation...
}
)

	If the preconditions and postconditions consist of nothing
	more than $(TT assert) macros, the whole doesn't need to
	be wrapped in a $(TT #ifdef) pair, since a good C++ compiler will
	optimize the whole thing away if the $(TT assert)s are turned off.
	<p>

	But suppose $(TT foo()) sorts an array, and the postcondition needs
	to walk the array and verify that it really is sorted. Now
	the shebang needs to be wrapped in $(TT #ifdef):

$(CCODE
void foo()
{
#ifdef DBC
    struct Sentry
    {   Sentry() { ...preconditions... }
	~Sentry() { ...postconditions... }
    } sentry;
#endif
    ...implementation...
}
)

	(One can make use of the C++ rule that templates are only
	instantiated when used can be used to avoid the $(TT #ifdef), by
	putting the conditions into a template function referenced
	by the $(TT assert).)
	<p>

	Let's add a return value to $(TT foo()) that needs to be checked in
	the postconditions. In D:

----------
int foo()
    in { ...preconditions... }
    out (result) { ...postconditions... }
    body
    {
	...implementation...
	if (...)
	    return bar();
	return 3;
    }
----------

	In C++:

$(CCODE
int foo()
{
#ifdef DBC
    struct Sentry
    {   int result;
	Sentry() { ...preconditions... }
	~Sentry() { ...postconditions... }
    } sentry;
#endif
    ...implementation...
    if (...)
    {   int i = bar();
#ifdef DBC
	sentry.result = i;
#endif
	return i;
    }
#ifdef DBC
    sentry.result = 3;
#endif
    return 3;
}
)

	Now add a couple parameters to $(TT foo()). In D:

----------
int foo(int a, int b)
    in { ...preconditions... }
    out (result) { ...postconditions... }
    body
    {
	...implementation...
	if (...)
	    return bar();
	return 3;
    }
----------

	In C++:

$(CCODE
int foo(int a, int b)
{
#ifdef DBC
    struct Sentry
    {   int a, b;
	int result;
	Sentry(int a, int b)
	{   this->a = a;
	    this->b = b;
	    ...preconditions...
	}
	~Sentry() { ...postconditions... }
    } sentry(a,b);
#endif
    ...implementation...
	if (...)
	{   int i = bar();
#ifdef DBC
	    sentry.result = i;
#endif
	    return i;
	}
#ifdef DBC
	sentry.result = 3;
#endif
	return 3;
}
)

<h2>Preconditions and Postconditions for Member Functions</h2>

	Consider the use of preconditions and postconditions for a
	polymorphic function in D:

----------
class A
{
    void foo()
	in { ...Apreconditions... }
	out { ...Apostconditions... }
	body
	{
	    ...implementation...
	}
}

class B : A
{
    void foo()
	in { ...Bpreconditions... }
	out { ...Bpostconditions... }
	body
	{
	    ...implementation...
	}
}
----------

	The semantics for a call to $(TT B.foo()) are:

	$(UL 
	$(LI Either Apreconditions or Bpreconditions must be satisfied.)
	$(LI Both Apostconditions and Bpostconditions must be satisfied.)
	)

	Let's get this to work in C++:

$(CCODE
class A
{
protected:
    #if DBC
    int foo_preconditions() { ...Apreconditions... }
    void foo_postconditions() { ...Apostconditions... }
    #else
    int foo_preconditions() { return 1; }
    void foo_postconditions() { }
    #endif

    void foo_internal()
    {
	...implementation...
    }

public:
    virtual void foo()
    {
	foo_preconditions();
	foo_internal();
	foo_postconditions();
    }
};

class B : A
{
protected:
    #if DBC
    int foo_preconditions() { ...Bpreconditions... }
    void foo_postconditions() { ...Bpostconditions... }
    #else
    int foo_preconditions() { return 1; }
    void foo_postconditions() { }
    #endif

    void foo_internal()
    {
	...implementation...
    }

public:
    virtual void foo()
    {
	assert(foo_preconditions() || A::foo_preconditions());
	foo_internal();
	A::foo_postconditions();
	foo_postconditions();
    }
};
)

	Something interesting has happened here. The preconditions can
	no longer be done using $(TT assert), since the results need
	to be OR'd together. I'll leave as a reader exercise adding
	in a class invariant, function return values for $(TT foo()),
	and parameters
	for $(TT foo()).

<h2>Conclusion</h2>

	These C++ techniques can work up to a point. But, aside from
	$(TT assert), they are not standardized and so will vary from
	project to project. Furthermore, they require much tedious
	adhesion to a particular convention, and add significant clutter
	to the code. Perhaps that's why it's rarely seen in practice.
	<p>

	By adding support for DbC into the language, D offers an easy
	way to use DbC and get it right. Being in the language standardizes
	the way it will be used from project to project.

<h2>References</h2>

	Chapter C.11 introduces the theory and rationale of
	Contract Programming in
	<a href="http://www.amazon.com/exec/obidos/ASIN/0136291554/classicempire">
	Object-Oriented Software Construction
	</a><br>
	Bertrand Meyer, Prentice Hall
	<p>

	Chapters 24.3.7.1 to 24.3.7.3 discuss Contract Programming in C++ in
	<a href="http://www.amazon.com/exec/obidos/ASIN/0201700735/classicempire">
	The C++ Programming Language Special Edition
	</a><br>
	Bjarne Stroustrup, Addison-Wesley
	<p>

)

Macros:
	TITLE=D's Contract Programming vs C++'s
	WIKI=CppDbc

