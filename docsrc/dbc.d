Ddoc

$(SPEC_S Contract Programming,

	Contracts are a breakthrough technique to reduce the programming effort
	for large projects. Contracts are the concept of preconditions, postconditions,
	errors, and invariants.
	Contracts can be done in C++ without modification to the language,
	but the result is
	clumsy and inconsistent.
	<p>

	Building contract support into the language makes for:

	$(OL 
	$(LI a consistent look and feel for the contracts)
	$(LI tool support)
	$(LI it's possible the compiler can generate better code using information gathered
	from the contracts)
	$(LI easier management and enforcement of contracts)
	$(LI handling of contract inheritance)
	)

<img src="d4.gif" alt="Contracts make D bug resistant" border=0>

	The idea of a contract is simple - it's just an expression that must evaluate to true.
	If it does not, the contract is broken, and by definition, the program has a bug in it.
	Contracts form part of the specification for a program, moving it from the documentation
	to the code itself. And as every programmer knows, documentation tends to be incomplete,
	out of date, wrong, or non-existent. Moving the contracts into the code makes them
	verifiable against the program.

<h2>Assert Contract</h2>

	The most basic contract is the
	<a href="expression.html#AssertExpression">assert</a>.
	An assert inserts a checkable expression into
	the code, and that expression must evaluate to true:
------
assert(expression);
------
	C programmers will find it familiar. Unlike C, however, an <code>assert</code>
	in function bodies
	works by throwing an <code>AssertError</code>,
	which can be caught and handled. Catching the contract violation is useful
	when the code must deal with errant uses by other code, when it must be
	failure proof, and as a useful tool for debugging.

<h2>Pre and Post Contracts</h2>

	The pre contracts specify the preconditions before a statement is executed. The most
	typical use of this would be in validating the parameters to a function. The post
	contracts validate the result of the statement. The most typical use of this
	would be in validating the return value of a function and of any side effects it has.
	The syntax is:

------
in
{
    ...contract preconditions...
}
out (result)
{
    ...contract postconditions...
}
body
{
    ...code...
}
------
	By definition, if a pre contract fails, then the body received bad
	parameters.
	An AssertError is thrown. If a post contract fails,
	then there is a bug in the body. An AssertError is thrown.
<p>
	Either the <code>in</code> or the <code>out</code> clause can be omitted.
	If the <code>out</code> clause is for a function
	body, the variable <code>result</code> is declared and assigned the return
	value of the function.
	For example, let's implement a square root function:
------
long square_root(long x)
    in
    {
	assert(x >= 0);
    }
    out (result)
    {
	assert((result * result) <= x && (result+1) * (result+1) >= x);
    }
    body
    {
	return cast(long)std.math.sqrt(cast(real)x);
    }
------
	The assert's in the in and out bodies are called <dfn>contracts</dfn>.
	Any other D
	statement or expression is allowed in the bodies, but it is important
	to ensure that the
	code has no side effects, and that the release version of the code
	will not depend on any 	effects of the code.
	For a release build of the code, the in and out code is not
	inserted.
<p>
	If the function returns a void, there is no result, and so there can be no
	result declaration in the out clause.
	In that case, use:
------
void func()
   out
   {
	...contracts...
   }
   body
   {
	...
   }
------
	In an out statement, $(I result) is initialized and set to the
	return value of the function.

<h2>In, Out and Inheritance</h2>

	$(P If a function in a derived class overrides a function in its
	super class, then only one of
	the $(TT in) contracts of the function and its base functions
	must be satisfied.
	Overriding
	functions then becomes a process of $(I loosening) the $(TT in)
	contracts.
	)

	$(P A function without an $(TT in) contract means that any values
	of the function parameters are allowed. This implies that if any
	function in an inheritance hierarchy has no $(TT in) contract,
	then $(TT in) contracts on functions overriding it have no useful
	effect.
	)

	$(P Conversely, all of the $(TT out) contracts needs to be satisfied,
	so overriding functions becomes a processes of $(I tightening) the
	$(TT out)
	contracts.
	)

<h2>Class Invariants</h2>

	$(P Class invariants are used to specify characteristics of a class that
	always
	must be true (except while executing a member function).
	They are described in $(LINK2 class.html, Classes).
	)

<h2>References</h2>

$(LINK2 http://people.cs.uchicago.edu/~robby/contract-reading-list/, Contracts Reading List)<br>
$(LINK2 http://pandonia.canberra.edu.au/java/contracts/paper-long.html, Adding Contracts to Java)<br>

)

Macros:
	TITLE=Contract Programming
	WIKI=DBC

