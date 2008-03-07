Ddoc

$(D_S Variadic Templates,

	$(P The problem statement is simple: write a function that
	takes an arbitrary number of values of arbitrary types,
	and print those values out one per line in a manner
	appropriate to the type. For example, the code:
	)

----
print(7, 'a', 6.8);
----

	$(P should output:
	)

$(CONSOLE
7
'a'
6.8
)

	$(P We'll explore how this can
	be done in standard C++, followed by doing it using
	the proposed variadic template C++ extension.
	Then, we'll do it the various ways the D programming
	language makes possible.
	)

<h3>C++ Solutions</h3>

<h4>The Standard C++ Solution</h4>

	$(P The straightforward way to do this in standard C++
	is to use a series of function templates, one for
	each number of arguments:
	)

$(CCODE
#include &lt;iostream&gt;
using namespace::std;

void print()
{
}

template&lt;class T1&gt; void print(T1 a1)
{
    cout &lt;&lt; a1 &lt;&lt; endl;
}

template&lt;class T1, class T2&gt; void print(T1 a1, T2 a2)
{
    cout &lt;&lt; a1 &lt;&lt; endl;
    cout &lt;&lt; a2 &lt;&lt; endl;
}

template&lt;class T1, class T2, class T3&gt; void print(T1 a1, T2 a2, T3 a3)
{
    cout &lt;&lt; a1 &lt;&lt; endl;
    cout &lt;&lt; a2 &lt;&lt; endl;
    cout &lt;&lt; a3 &lt;&lt; endl;
}

... etc ...
)

	$(P This poses significant problems:
	)

	$(P One, the function
	implementor must decide in advance what the maximum number
	of arguments the function will have. The implementor will
	usually err on the side of excess, and ten, or even twenty
	overloads of print() will be written. Yet inevitably, some
	user somewhere will require just one more argument.
	So this solution is never quite thoroughly right.
	)

	$(P Two, the logic of the function template body must be
	cut and paste duplicated, then carefully modified,
	for every one of those function templates. If the logic
	needs to be adjusted, all of those function templates must
	receive the same adjustment, which is tedious and error
	prone.
	)

	$(P Three, as is typical for function overloads, there is no
	obvious visual connection between them, they stand independently.
	This makes it more difficult to understand the code,
	especially if the implementor isn't careful to place them
	and format them in a consistent style.
	)

	$(P Four, it leads to source code bloat which slows down
	compilation.
	)

<h4>The C++ Extension Solution</h4>

	$(P Douglas Gregor has proposed a
	variadic template scheme [1]
	for C++ that solves these problems.
	The result looks like:
	)

$(CCODE
void print()
{
}

template&lt;class T, class... U&gt; void print(T a1, U... an)
{
    cout &lt;&lt; a1 &lt;&lt; newline;
    print(an...);
}
)

	$(P It uses recursive function template instantiation
	to pick off the arguments one by one.
	A specialization with no arguments ends the recursion.
  	It's a neat and tidy solution, but with one glaring problem:
	it's a proposed extension, which means it isn't part
	of the C++ standard, may not get into the C++ standard
	in its current form, may not get into the standard
	in any form, and even if it does, it may be many, many
	years before the feature is commonly implemented.
	)

<h3>D Programming Language Solutions</h3>

<h4>The D Look Ma No Templates Solution</h4>

	$(P It is not practical to solve this problem in C++ without
	using templates. In D, one can because D supports typesafe
	variadic function parameters.
	)

------
import std.stdio;

void print(...)
{
    foreach (arg; _arguments)
    {
	writefx(stdout, (&arg)[0 .. 1], _argptr, 1);
	auto size = arg.tsize();
	_argptr += ((size + size_t.sizeof - 1) & ~(size_t.sizeof - 1));
    }
}
------

	$(P It isn't elegant or the most efficient,
	but it does work, and it is neatly
	encapsulated into a single function.
	(It relies on the predefined parameters _argptr and _arguments
	which give a pointer to the values and their types, respectively.)
	)

<h4>Translating the Variadic C++ Solution into D</h4>

	$(P Variadic templates in D enable a straightforward translation
	of the proposed C++ variadic syntax:
	)

---
void print()()
{
}

void print(T, A...)(T t, A a)
{
    writefln(t);
    print(a);
}
---

	$(P There are two function templates. The first provides the
	degenerate case of no arguments, and a terminus for the
	recursion of the second. The second has two arguments:
	t for the first value and a for the rest of the values.
	A... says the parameter is a tuple, and implicit function
	template instantiation will fill in A with the list of
	all the types following t. So, print(7, 'a', 6.8) will
	fill in int for T, and a tuple (char, double) for A.
	The parameter a becomes an expression tuple of the arguments.
	)

	$(P The function works by printing the first parameter t,
	and then recursively calling itself with the remaining arguments
	a. The recursion terminates when there are no longer any
	arguments by calling print()().
	)

<h4>The Static If Solution</h4>

	$(P It would be nice to encapsulate all the logic into a
	single function. One way to do that is by using
	static if's, which provide for conditional compilation:
	)

---
void print(A...)(A a)
{
    static if (a.length)
    {
	writefln(a[0]);
	static if (a.length > 1)
	    print(a[1 .. length]);
    }
}
---

	$(P Tuples can be manipulated much like arrays.
	So a.length resolves to the number of expressions
	in the tuple a. a[0] gives the first expression
	in the tuple. a[1 .. length] creates a new tuple
	by slicing the original tuple.
	)

<h4>The Foreach Solution</h4>

	$(P But since tuples can be manipulated like arrays,
	we can use a foreach statement to 'loop' over
	the tuple's expressions:
	)

---
void print(A...)(A a)
{
    foreach(t; a)
	writefln(t);
}
---

	$(P The end result is remarkably simple, self-contained, compact
	and efficient.
	)

<h3>Acknowledgments</h3>

	$(OL

	$(LI Thanks to Andrei Alexandrescu for explaining to me how
	variadic templates need to work and why they are so important.
	)

	$(LI Thanks to Douglas Gregor, Jaakko Jaervi, and Gary Powell
	for their inspirational work
	on C++ variadic templates.
	)

	)

<h3>References</h3>

	$(OL

	$(LI $(LINK2 http://www.osl.iu.edu/~dgregor/cpp/variadic-templates.pdf, Variadic Templates N2080))

	)

)

Macros:
	TITLE=Variadic Templates
	WIKI=VariadicTemplates


