Ddoc

$(D_S Tuples,

	$(P A tuple is a sequence of elements. Those elements can
	be types, expressions, or aliases.
	The number and elements of a tuple are fixed at compile time;
	they cannot be changed at run time.
	)

	$(P Tuples have characteristics of both
	structs and arrays. Like structs, the tuple
	elements can be of different types. Like arrays,
	the elements can be accessed via indexing.
	)

	$(P So how does one construct a tuple? There isn't a specific
	tuple literal syntax. But since variadic template parameters
	create tuples, we can define a template to create one:
	)

---
template Tuple(E...)
{
    alias E Tuple;
}
---

	$(P and it's used like:)

---
Tuple!(int, long, float)	// create a tuple of 3 types
Tuple!(3, 7, 'c')		// create a tuple of 3 expressions
Tuple!(int, 8)			// create a tuple of a type and an expression
---

	$(P In order to symbolically refer to a tuple, use an alias:)

---
alias Tuple!(float, float, 3) TP; // TP is now a tuple of two floats and 3
---

	$(P Tuples can be used as arguments to templates, and if so
	they are 'flattened' out into a list of arguments.
	This makes it straightforward to append a new element to
	an existing tuple or concatenate tuples:)

---
alias Tuple!(TP, 8) TR;  // TR is now float,float,3,8
alias Tuple!(TP, TP) TS; // TS is float,float,3,float,float,3
---

	$(P Tuples share many characteristics with arrays.
	For starters, the number of elements in a tuple can
	be retrieved with the $(B .length) property:)

---
TP.length	// evaluates to 3
---

	$(P Tuples can be indexed:)

---
TP[1] f = TP[2];	// f is declared as a float and initialized to 3
---

	$(P and even sliced:)

---
alias TP[0..length-1] TQ; // TQ is now the same as Tuple!(float, float)
---

	$(P Yes, $(B length) is defined within the [ ]s.
	There is one restriction: the indices for indexing and slicing
	must be evaluatable at compile time.)

---
void foo(int i)
{
    TQ[i] x;		// error, i is not constant
}
---

	$(P These make it simple to produce the 'head' and 'tail'
	of a tuple. The head is just TP[0], the tail
	is TP[1 .. length].
	Given the head and tail, mix with a little conditional
	compilation, and we can implement some classic recursive
	algorithms with templates.
	For example, this template returns a tuple consisting
	of the trailing type arguments $(I TL) with the first occurrence
	of the first type argument $(I T) removed:
	)
---
template Erase(T, TL...)
{
    static if (TL.length == 0)
	// 0 length tuple, return self
        alias TL Erase;
    else static if (is(T == TL[0]))
	// match with first in tuple, return tail
        alias TL[1 .. length] Erase;
    else
	// no match, return head concatenated with recursive tail operation
        alias Tuple!(TL[0], Erase!(T, TL[1 .. length])) Erase;
}
---

<h3>Type Tuples</h3>

	$(P If a tuple's elements are solely types,
	it is called a $(I TypeTuple)
	(sometimes called a type list).
	Since function parameter lists are a list of types,
	a type tuple can be retrieved from them.
	One way is using an $(ISEXPRESSION):
	)

---
int foo(int x, long y);

...
static if (is(foo P == function))
    alias P TP;
// TP is now the same as Tuple!(int, long)
---

	$(P This is generalized in the template
	$(LINK2 phobos/std_traits.html, std.traits).ParameterTypeTuple:
	)

---
import std.traits;

...
alias ParameterTypeTuple!(foo) TP;	// TP is the tuple (int, long)
---

	$(P $(I TypeTuple)s can be used to declare a function:)

---
float bar(TP);	// same as float bar(int, long)
---

	$(P If implicit function template instantiation is being done,
	the type tuple representing the parameter types can be deduced:
	)
---
int foo(int x, long y);

void Bar(R, P...)(R function(P))
{
    writefln("return type is ", typeid(R));
    writefln("parameter types are ", typeid(P));
}

...
Bar(&foo);
---

	$(P Prints:)

$(CONSOLE
return type is int
parameter types are (int,long)
)

	$(P Type deduction can be used to create a function that
	takes an arbitrary number and type of arguments:)

---
void Abc(P...)(P p)
{
    writefln("parameter types are ", typeid(P));
}

Abc(3, 7L, 6.8);
---

	$(P Prints:)

$(CONSOLE
parameter types are (int,long,double)
)

	$(P For a more comprehensive treatment of this aspect, see
	$(LINK2 variadic-function-templates.html, Variadic Templates).
	)


<h3>Expression Tuples</h3>

	$(P If a tuple's elements are solely expressions,
	it is called an $(I ExpressionTuple).
	The Tuple template can be used to create one:
	)

---
alias Tuple!(3, 7L, 6.8) ET;

...
writefln(ET);            // prints 376.8
writefln(ET[1]);         // prints 7
writefln(ET[1..length]); // prints 76.8
---

	$(P It can be used to create an array literal:)

---
alias Tuple!(3, 7, 6) AT;

...
int[] a = [AT];		// same as [3,7,6]
---

	$(P The data fields of a struct or class can be
	turned into an expression tuple using the $(B .tupleof)
	property:)

---
struct S { int x; long y; }

void foo(int a, long b)
{
    writefln(a, b);
}

...
S s;
s.x = 7;
s.y = 8;
foo(s.x, s.y);	// prints 78
foo(s.tupleof);	// prints 78
s.tupleof[1] = 9;
s.tupleof[0] = 10;
foo(s.tupleof); // prints 109
s.tupleof[2] = 11;  // error, no third field of S
---

	$(P A type tuple can be created from the data fields
	of a struct using $(B typeof):)

---
writefln(typeid(typeof(S.tupleof)));	// prints (int,long)
---

	$(P This is encapsulated in the template
	$(LINK2 phobos/std_traits.html, std.traits).FieldTypeTuple.
	)

<h3>Looping</h3>

	$(P While the head-tail style of functional programming works
	with tuples, it's often more convenient to use a loop.
	The $(I ForeachStatement) can loop over either $(I TypeTuple)s
	or $(I ExpressionTuple)s.
	)

---
alias Tuple!(int, long, float) TL;
foreach (i, T; TL)
    writefln("TL[%d] = ", i, typeid(T));

alias Tuple!(3, 7L, 6.8) ET;
foreach (i, E; ET)
    writefln("ET[%d] = ", i, E);
---

	$(P Prints:)

$(CONSOLE
TL[0] = int
TL[1] = long
TL[2] = float
ET[0] = 3
ET[1] = 7
ET[2] = 6.8
)

<h3>Tuple Declarations</h3>

	$(P A variable declared with a $(I TypeTuple) becomes an
	$(I ExpressionTuple):)

---
alias Tuple!(int, long) TL;

void foo(TL tl)
{
    writefln(tl, tl[1]);
}

foo(1, 6L);	// prints 166
---

<h3>Putting It All Together</h3>

	$(P These capabilities can be put together to implement
	a template that will encapsulate all the arguments to
	a function, and return a delegate that will call the function
	with those arguments.)

---
import std.stdio;

R delegate() CurryAll(Dummy=void, R, U...)(R function(U) dg, U args)
{
    struct Foo
    {
	typeof(dg) dg_m;
	U args_m;

	R bar()
	{
	    return dg_m(args_m);
	}
    }

    Foo* f = new Foo;
    f.dg_m = dg;
    foreach (i, arg; args)
	f.args_m[i] = arg;
    return &f.bar;
}

R delegate() CurryAll(R, U...)(R delegate(U) dg, U args)
{
    struct Foo
    {
	typeof(dg) dg_m;
	U args_m;

	R bar()
	{
	    return dg_m(args_m);
	}
    }

    Foo* f = new Foo;
    f.dg_m = dg;
    foreach (i, arg; args)
	f.args_m[i] = arg;
    return &f.bar;
}


void main()
{
    static int plus(int x, int y, int z)
    {
	return x + y + z;
    }

    auto plus_two = CurryAll(&plus, 2, 3, 4);
    writefln("%d", plus_two());
    assert(plus_two() == 9);

    int minus(int x, int y, int z)
    {
	return x + y + z;
    }

    auto minus_two = CurryAll(&minus, 7, 8, 9);
    writefln("%d", minus_two());
    assert(minus_two() == 24);
}
---

	$(P The reason for the $(I Dummy) parameter is that one
	cannot overload two templates with the same parameter list.
	So we make them different by giving one a dummy parameter. 
	)

<h3>Future Directions</h3>

	$(UL
	$(LI Return tuples from functions.)
	$(LI Use operators on tuples, like =, +=, etc.)
	$(LI Have tuple properties like $(B .init) which will apply
	the property to each of the tuple members.)
	)

)

Macros:
	TITLE=Tuples
	WIKI=Tuples
META_KEYWORDS=D Programming Language, template metaprogramming,
variadic templates, tuples, currying
META_DESCRIPTION=Tuples in the D programming language
