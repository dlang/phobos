Ddoc

$(D_S Rationale,

	$(P Questions about the reasons for various design decisions for
	D often come up. This addresses many of them.
	)

<h2>Operator Overloading</h2>

<h3>Why not name them operator+(), operator*(), etc.?</h3>

	$(P This is the way C++ does it, and it is appealing to be able
	to refer to overloading '+' with 'operator+'. The trouble is
	things don't quite fit. For example, there are the
	comparison operators <, <=, >, and >=. In C++, all four must
	be overloaded to get complete coverage. In D, only a cmp()
	function must be defined, and the comparison operations are
	derived from that by semantic analysis.
	)

	$(P Overloading operator/() also provides no symmetric way, as a member
	function, to overload the reverse operation. For example,
	)

------
class A
{
    int operator/(int i);		// overloads (a/i)
    static operator/(int i, A a)	// overloads (i/a)
}
------

	$(P The second overload does the reverse overload, but
	it cannot be virtual, and so has a confusing asymmetry with
	the first overload.
	)

<h3>Why not allow globally defined operator overload functions?</h3>

	$(OL 
	$(LI Operator overloading can only be done with an argument
	as an object, so they logically belong as member functions
	of that object. That does leave the case of what to do
	when the operands are objects of different types:

------
class A { }
class B { }
int opAdd(class A, class B);
------

	Should opAdd() be in class A or B? The obvious stylistic solution
	would be to put it in the class of the first operand,

------
class A
{
    int opAdd(class B) { }
}
------
	)

	$(LI Operator overloads usually need access to private members
	of a class, and making them global breaks the object oriented
	encapsulation of a class.
	)

	$(LI (2) can be addressed by operator overloads automatically gaining
	"friend" access, but such unusual behavior is at odds with D
	being simple.
	)

	)

<h3>Why not allow user definable operators?</h3>

	$(P These can be very useful for attaching new infix operations
	to various unicode symbols. The trouble is that in D,
	the tokens are supposed to be completely independent of the
	semantic analysis. User definable operators would break that.
	)

<h3>Why not allow user definable operator precedence?</h3>

	$(P The trouble is this affects the syntax analysis, and the syntax
	analysis is supposed to be completely independent of the
	semantic analysis in D.
	)

<h3>Why not use operator names like __add__ and __div__ instead
 of opAdd, opDiv, etc.?</h3>

	$(P __ keywords should indicate a proprietary language extension,
	not a basic part of the language.
	)

<h3>Why not have binary operator overloads be static members, so both
arguments are specified, and there no longer is any issue with the reverse
operations?</h3>

	$(P This means that the operator overload cannot be virtual, and
	so likely would be implemented as a shell around another
	virtual function to do the real work. This will wind up looking
	like an ugly hack. Secondly, the opCmp() function is already
	an operator overload in Object, it needs to be virtual for several
	reasons, and making it asymmetric with the way other operator
	overloads are done is unnecessary confusion.
	)

<h2>Properties</h2>

<h3>Why does D have properties like T.infinity in the core language to give the
infinity of a floating point type, rather than doing it in a library like C++:
	$(CODE std::numeric_limits<T>::infinity)
?</h3>

	Let's rephrase that as "if there's a way to express it in the existing
	language, why build it in to the core language?"
	In regards to T.infinity:

	$(OL 
	$(LI Building it in to the core language means the core language knows
	what a floating point infinity is. Being layered in templates, typedefs,
	casts, const bit patterns, etc., it doesn't know what it is, and is
	unlikely to give sensible error messages if misused.
	)

	$(LI A side effect of (1) is it is unlikely to be able to use it
	effectively in constant folding and other optimizations.
	)

	$(LI Instantiating templates, loading $(CODE #include) files, etc., all costs
	compile time and memory.
	)

	$(LI The worst, though, is the lengths gone to just to get at infinity,
	implying "the language and compiler don't know anything about IEEE 754
	floating point - so it cannot be relied on." And in fact
	many otherwise excellent C++ compilers
	do not handle NaN's correctly in floating point comparisons.
	(Digital Mars C++ does do it correctly.)
	C++98 doesn't say anything about NaN or Infinity handling in expressions
	or library functions. So it must be assumed it doesn't work.
	)

	)

	$(P To sum up, there's a lot more to supporting NaNs and infinities than
	having a template that returns a bit pattern. It has to be built in to
	the compiler's core logic, and it has to permeate all the library code
	that deals with floating point. And it has to be in the Standard.
	)

	$(P To illustrate, if either op1 or op2 or both are NaN, then:)

------
(op1 < op2)
------
	$(P does not yield the same result as:)
------
!(op1 >= op2)
------
	$(P if the NaNs are done correctly.)

<h2>Why use $(TT static if(0)) rather than $(TT if (0)?)</h2>

    $(P Some limitations are:)

    $(OL 
    $(LI if (0) introduces a new scope, static if(...) does not. Why does this
    matter? It matters if one wants to conditionally declare a new variable:

------
static if (...) int x; else long x;
x = 3;
------

    whereas:

------
if (...) int x; else long x;
x = 3;    // error, x is not defined
------
    )

    $(LI False static if conditionals don't have to semantically work. For
    example, it may depend on a conditionally compiled declaration somewhere
    else:

------
static if (...) int x;
int test()
{
    static if (...) return x;
    else return 0;
}
------
    )

    $(LI Static if's can appear where only declarations are allowed:

------
class Foo
{
	static if (...)
	    int x;
}
------
    )

    $(LI Static if's can declare new type aliases:

------
static if (0 || is(int T)) T x;
    )
------
    )

)

Macros:
	TITLE=Rationale
	WIKI=Rationale

