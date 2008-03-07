Ddoc

$(SPEC_S Templates,

$(BLOCKQUOTE 
I think that I can safely say that nobody understands template mechanics. -- Richard Deyman
)

$(P	Templates are D's approach to generic programming.
	Templates are defined with a $(I TemplateDeclaration):
)

$(GRAMMAR
$(I TemplateDeclaration):
	$(B template) $(I TemplateIdentifier) $(B $(LPAREN)) $(I TemplateParameterList) $(B $(RPAREN))
		$(B {) DeclDefs $(B })

$(I TemplateIdentifier):
	$(I Identifier)

$(I TemplateParameterList)
	$(I TemplateParameter)
	$(I TemplateParameter) , $(I TemplateParameterList)

$(I TemplateParameter):
	$(GLINK TemplateTypeParameter)
	$(GLINK TemplateValueParameter)
	$(GLINK TemplateAliasParameter)
	$(GLINK TemplateTupleParameter)
$(V2
	$(GLINK TemplateThisParameter))
)

$(P	The body of the $(I TemplateDeclaration) must be syntactically correct
	even if never instantiated. Semantic analysis is not done until
	instantiated. A template forms its own scope, and the template
	body can contain classes, structs, types, enums, variables,
	functions, and other templates.
)
$(P
	Template parameters can be types, values, symbols, or tuples.
	Types can be any type.
	Value parameters must be of an integral type, floating point
	type, or string type and
	specializations for them must resolve to an integral constant,
	floating point constant, null, or a string literal.
	Symbols can be any non-local symbol.
	Tuples are a sequence of 0 or more types, values or symbols.
)
$(P
	Template parameter specializations
	constrain the values or types the $(I TemplateParameter) can
	accept.
)
$(P
	Template parameter defaults are the value or type to use for the
	$(I TemplateParameter) in case one is not supplied.
)

<h2>Explicit Template Instantiation</h2>

$(P
	Templates are explicitly instantiated with:
)

$(GRAMMAR
$(I TemplateInstance):
	$(I TemplateIdentifer) $(B !$(LPAREN)) $(I TemplateArgumentList) $(B $(RPAREN))

$(I TemplateArgumentList):
	$(I TemplateArgument)
	$(I TemplateArgument) , $(I TemplateArgumentList)

$(I TemplateArgument):
	$(I Type)
	$(ASSIGNEXPRESSION)
	$(I Symbol)
)

$(P
	Once instantiated, the declarations inside the template, called
	the template members, are in the scope
	of the $(I TemplateInstance):
)

------
template TFoo(T) { alias T* t; }
...
TFoo!(int).t x;	// declare x to be of type int*
------

$(P
	A template instantiation can be aliased:
)

------
template TFoo(T) { alias T* t; }
alias TFoo!(int) abc;
abc.t x;	// declare x to be of type int*
------

$(P
	Multiple instantiations of a $(I TemplateDeclaration) with the same
	$(I TemplateArgumentList), before implicit conversions,
	all will refer to the same instantiation.
	For example:
)

------
template TFoo(T) { T f; }
alias TFoo!(int) a;
alias TFoo!(int) b;
...
a.f = 3;
assert(b.f == 3);	// a and b refer to the same instance of TFoo
------

$(P
	This is true even if the $(I TemplateInstance)s are done in
	different modules.
)

$(P
	Even if template arguments are implicitly converted to the same
	template parameter type, they still refer to different instances:
)

-----
struct TFoo(int x) { }
static assert(is(TFoo!(3) == TFoo!(2 + 1)));   // 3 and 2+1 are both 3 of type int
static assert(!is(TFoo!(3) == TFoo!(3u)));     // 3u and 3 are different types
-----
$(P
	If multiple templates with the same $(I TemplateIdentifier) are
	declared, they are distinct if they have a different number of
	arguments or are differently specialized.
)
$(P
	For example, a simple generic copy template would be:
)

------
template TCopy(T)
{
    void copy(out T to, T from)
    {
	to = from;
    }
}
------

$(P
	To use the template, it must first be instantiated with a specific
	type:
)

------
int i;
TCopy!(int).copy(i, 3);
------

<h2>Instantiation Scope</h2>

$(P
	$(I TemplateInstantance)s are always performed in the scope of where
	the $(I TemplateDeclaration) is declared, with the addition of the
	template parameters being declared as aliases for their deduced types.
)
$(P
	For example:
)

$(BR)$(BR)
$(U module a)
------
template TFoo(T) { void bar() { func(); } }
------

$(U module b)
------
import a;

void func() { }
alias TFoo!(int) f;	// error: func not defined in module a
------

$(P
	and:
)

$(BR)$(BR)
$(U module a)
------
template TFoo(T) { void bar() { func(1); } }
void func(double d) { }
------

$(U module b)
------
import a;

void func(int i) { }
alias TFoo!(int) f;
...
f.bar();	// will call a.func(double)
------

$(P
	$(I TemplateParameter) specializations and default
	values are evaluated in the scope of the $(I TemplateDeclaration).
)

<h2>Argument Deduction</h2>

	$(P The types of template parameters are deduced for a particular
	template instantiation by comparing the template argument with
	the corresponding template parameter.
	)

	$(P For each template parameter, the following rules are applied in
	order until a type is deduced for each parameter:
	)

	$(OL 
	$(LI If there is no type specialization for the parameter,
	the type of the parameter is set to the template argument.)

	$(LI If the type specialization is dependent on a type parameter,
	the type of that parameter is set to be the corresponding part
	of the type argument.)

	$(LI If after all the type arguments are examined there are any
	type parameters left with no type assigned, they are assigned
	types corresponding to the template argument in the same position
	in the $(I TemplateArgumentList).)

	$(LI If applying the above rules does not result in exactly one
	type for each template parameter, then it is an error.)
	)

	$(P For example:)

------
template TFoo(T) { }
alias TFoo!(int) Foo1;		// (1) T is deduced to be int
alias TFoo!(char*) Foo2;	// (1) T is deduced to be char*

template TBar(T : T*) { }
alias TBar!(char*) Foo3;	// (2) T is deduced to be char

template TAbc(D, U : D[]) { }
alias TAbc!(int, int[]) Bar1;	// (2) D is deduced to be int, U is int[]
alias TAbc!(char, int[]) Bar2;	// (4) error, D is both char and int

template TDef(D : E*, E) { }
alias TDef!(int*, int) Bar3;	// (1) E is int
				// (3) D is int*
------

	$(P Deduction from a specialization can provide values
	for more than one parameter:
	)

---
template Foo(T: T[U], U)
{
    ...
}

Foo!(int[long])  // instantiates Foo with T set to int, U set to long
---

	$(P When considering matches, a class is
	considered to be a match for any super classes or interfaces:
	)

------
class A { }
class B : A { }

template TFoo(T : A) { }
alias TFoo!(B) Foo4;		// (3) T is B

template TBar(T : U*, U : A) { }
alias TBar!(B*, B) Foo5;	// (2) T is B*
				// (3) U is B
------

<h2>Template Type Parameters</h2>

$(GRAMMAR
$(GNAME TemplateTypeParameter):
	$(I Identifier)
	$(I Identifier) $(I TemplateTypeParameterSpecialization)
	$(I Identifier) $(I TemplateTypeParameterDefault)
	$(I Identifier) $(I TemplateTypeParameterSpecialization) $(I TemplateTypeParameterDefault)

$(I TemplateTypeParameterSpecialization):
	 $(B :) $(I Type)

$(I TemplateTypeParameterDefault):
	 $(B =) $(I Type)
)

<h3>Specialization</h3>

	$(P Templates may be specialized for particular types of arguments
	by following the template parameter identifier with a : and the
	specialized type.
	For example:
	)

------
template TFoo(T)        { ... } // #1
template TFoo(T : T[])  { ... } // #2
template TFoo(T : char) { ... } // #3
template TFoo(T,U,V)    { ... } // #4

alias TFoo!(int) foo1;	       // instantiates #1
alias TFoo!(double[]) foo2;    // instantiates #2 with T being double
alias TFoo!(char) foo3;        // instantiates #3
alias TFoo!(char, int) fooe;   // error, number of arguments mismatch
alias TFoo!(char, int, int) foo4; // instantiates #4
------

	$(P The template picked to instantiate is the one that is most specialized
	that fits the types of the $(I TemplateArgumentList).
	Determine which is more specialized is done the same way as the
	C++ partial ordering rules.
	If the result is ambiguous, it is an error.
	)


$(V2
<h2>Template This Parameters</h2>

$(GRAMMAR
$(GNAME TemplateThisParameter):
	$(B this) $(I TemplateTypeParameter)
)

	$(P $(I TemplateThisParameter)s are used in member function templates
	to pick up the type of the $(I this) reference.
	)
---
import std.stdio;

struct S
{
    const void foo(this T)(int i)
    {
	writeln(typeid(T));
    }
}

void main()
{
    const(S) s;
    (&s).foo(1);
    S s2;
    s2.foo(2);
    invariant(S) s3;
    s3.foo(3);
}
---
	$(P Prints:)

$(CONSOLE
const(S)
S
invariant(S)
)
)

<h2>Template Value Parameters</h2>

$(GRAMMAR
$(GNAME TemplateValueParameter):
	$(I Declaration)
	$(I Declaration) $(I TemplateValueParameterSpecialization)
	$(I Declaration) $(I TemplateValueParameterDefault)
	$(I Declaration) $(I TemplateValueParameterSpecialization) $(I TemplateValueParameterDefault)

$(I TemplateValueParameterSpecialization):
	 $(B :) $(I ConditionalExpression)

$(I TemplateValueParameterDefault):
	 $(B =) $(I ConditionalExpression)

)

	$(P This example of template foo has a value parameter that
	is specialized for 10:
	)

------
template foo(U : int, int T : 10)
{
    U x = T;
}

void main()
{
    assert(foo!(int, 10).x == 10);
}
------


<h2><a name="aliasparameters">Template Alias Parameters</a></h2>

$(GRAMMAR
$(GNAME TemplateAliasParameter):
	$(B alias) $(I Identifier)
	$(B alias) $(I Identifier) $(I TemplateAliasParameterSpecialization)
	$(B alias) $(I Identifier) $(I TemplateAliasParameterDefault)
	$(B alias) $(I Identifier) $(I TemplateAliasParameterSpecialization) $(I TemplateAliasParameterDefault)

$(I TemplateAliasParameterSpecialization):
	 $(B :) $(I Type)

$(I TemplateAliasParameterDefault):
	 $(B =) $(I Type)
)

	$(P Alias parameters enable templates to be parameterized with
	any type of D symbol, including global names, local names, typedef names,
	module names, template names, and template instance names.
	It is a superset of the uses of template template parameters in C++.
	)

	$(UL 
	$(LI Global names

------
int x;

template Foo(alias X)
{
    static int* p = &X;
}

void test()
{
    alias Foo!(x) bar;
    *bar.p = 3;		// set x to 3
    static int y;
    alias Foo!(y) abc;
    *abc.p = 3;		// set y to 3
}
------
	)

	$(LI Type names

------
class Foo
{
    static int p;
}

template Bar(alias T)
{
    alias T.p q;
}

void test()
{
    alias Bar!(Foo) bar;
    bar.q = 3;	// sets Foo.p to 3
}
------
	)

	$(LI Module names

------
import std.string;

template Foo(alias X)
{
	alias X.toString y;
}

void test()
{
    alias Foo!(std.string) bar;
    bar.y(3);	// calls std.string.toString(3)
}
------
	)

	$(LI Template names

------
int x;

template Foo(alias X)
{
    static int* p = &X;
}

template Bar(alias T)
{
    alias T!(x) abc;
}

void test()
{
    alias Bar!(Foo) bar;
    *bar.abc.p = 3;	// sets x to 3
}
------
	)

	$(LI Template alias names

------
int x;

template Foo(alias X)
{
    static int* p = &X;
}

template Bar(alias T)
{
    alias T.p q;
}

void test()
{
    alias Foo!(x) foo;
    alias Bar!(foo) bar;
    *bar.q = 3;		// sets x to 3
}
------
	)
	)

<h2>Template Tuple Parameters</h2>

$(GRAMMAR
$(GNAME TemplateTupleParameter):
	$(I Identifier) $(B ...)
)

	$(P If the last template parameter in the $(I TemplateParameterList)
	is declared as a $(I TemplateTupleParameter),
	it is a match with any trailing template arguments.
	The sequence of arguments form a $(I Tuple).
	A $(I Tuple) is not a type, an expression, or a symbol.
	It is a sequence of any mix of types, expressions or symbols.
	)

	$(P A $(I Tuple) whose elements consist entirely of types is
	called a $(I TypeTuple).
	A $(I Tuple) whose elements consist entirely of expressions is
	called an $(I ExpressionTuple).
	)

	$(P A $(I Tuple) can be used as an argument list to instantiate
	another template, or as the list of parameters for a function.
	)

---
template Print(A ...)
{
    void print()
    {
	writefln("args are ", A);
    }
}

template Write(A ...)
{
    void write(A a)	// A is a $(I TypeTuple)
			// a is an $(I ExpressionTuple)
    {
	writefln("args are ", a);
    }
}

void main()
{
    Print!(1,'a',6.8).print();			  // prints: args are 1a6.8
    Write!(int, char, double).write(1, 'a', 6.8); // prints: args are 1a6.8
}
---

	$(P Template tuples can be deduced from the types of
	the trailing parameters
	of an implicitly instantiated function template:)

---
template Foo(T, R...)
{
    void Foo(T t, R r)
    {
	writefln(t);
	static if (r.length)	// if more arguments
	    Foo(r);		// do the rest of the arguments
    }
}

void main()
{
    Foo(1, 'a', 6.8);
}
---
	$(P prints:)

$(CONSOLE
1
a
6.8
)
	$(P The tuple can also be deduced from the type of a delegate
	or function parameter list passed as a function argument:)

----
import std.stdio;

/* R is return type
 * A is first argument type
 * U is $(I TypeTuple) of rest of argument types
 */
R delegate(U) Curry(R, A, U...)(R delegate(A, U) dg, A arg)
{
    struct Foo
    {
	typeof(dg) dg_m;
	typeof(arg) arg_m;

	R bar(U u)
	{
	    return dg_m(arg_m, u);
	}
    }

    Foo* f = new Foo;
    f.dg_m = dg;
    f.arg_m = arg;
    return &f.bar;
}

void main()
{
    int plus(int x, int y, int z)
    {
	return x + y + z;
    }

    auto plus_two = Curry(&plus, 2);
    writefln("%d", plus_two(6, 8));	// prints 16
}
----

	$(P The number of elements in a $(I Tuple) can be retrieved with
	the $(B .length) property. The $(I n)th element can be retrieved
	by indexing the $(I Tuple) with [$(I n)],
	and sub tuples can be created
	with the slicing syntax.
	)

	$(P $(I Tuple)s are static compile time entities, there is no way
	to dynamically change, add, or remove elements.)

	$(P If both a template with a tuple parameter and a template
	without a tuple parameter exactly match a template instantiation,
	the template without a $(I TemplateTupleParameter) is selected.)

<h2>Template Parameter Default Values</h2>

	$(P Trailing template parameters can be given default values:
	)

------
template Foo(T, U = int) { ... }
Foo!(uint,long); // instantiate Foo with T as uint, and U as long
Foo!(uint);	 // instantiate Foo with T as uint, and U as int

template Foo(T, U = T*) { ... }
Foo!(uint);	 // instantiate Foo with T as uint, and U as uint*
------

<h2>Implicit Template Properties</h2>

	$(P If a template has exactly one member in it, and the name of that
	member is the same as the template name, that member is assumed
	to be referred to in a template instantiation:
	)

------
template $(B Foo)(T)
{
    T $(B Foo);	// declare variable Foo of type T
}

void test()
{
    $(B Foo)!(int) = 6;	// instead of Foo!(int).Foo
}
------

<h2>Class Templates</h2>

$(GRAMMAR
$(I ClassTemplateDeclaration):
    $(B class) $(I Identifier) $(B $(LPAREN)) $(I TemplateParameterList) $(B $(RPAREN)) [$(I SuperClass) {$(B ,) $(I InterfaceClass) }] $(I ClassBody)
)

	$(P If a template declares exactly one member, and that member is a class
	with the same name as the template:
	)

------
template $(B Bar)(T)
{
    class $(B Bar)
    {
	T member;
    }
}
------

	$(P then the semantic equivalent, called a $(I ClassTemplateDeclaration)
	can be written as:
	)

------
class $(B Bar)(T)
{
    T member;
}
------

<h2>Struct, Union, and Interface Templates</h2>

	$(P Analogously to class templates, struct, union and interfaces
	can be transformed into templates by supplying a parameter list.
	)

<h2>Function Templates</h2>

	$(P If a template declares exactly one member, and that member is a function
	with the same name as the template:
	)

$(GRAMMAR
$(I FunctionTemplateDeclaration):
    $(I Type) $(I Identifier) $(B $(LPAREN)) $(I TemplateParameterList) $(B $(RPAREN)) $(B $(LPAREN)) $(I FunctionParameterList) $(B $(RPAREN)) $(I FunctionBody)
)

	$(P A function template to compute the square of type $(I T) is:
	)
------
T $(B Square)(T)(T t)
{
    return t * t;
}
------

	$(P Function templates can be explicitly instantiated with a
	!($(I TemplateArgumentList)):
	)

----
writefln("The square of %s is %s", 3, Square!(int)(3));
----

	$(P or implicitly, where the $(I TemplateArgumentList) is deduced
	from the types of the function arguments:
	)

----
writefln("The square of %s is %s", 3, Square(3));  // T is deduced to be int
----

	$(P Function template type parameters that are to be implicitly
	deduced may not have specializations:
	)

------
void $(B Foo)(T : T*)(T t) { ... }

int x,y;
Foo!(int*)(x);   // ok, T is not deduced from function argument
Foo(&y);         // error, T has specialization
------

	$(P Template arguments not implicitly deduced can have default values:
	)

------
void $(B Foo)(T, U=T*)(T t) { U p; ... }

int x;
Foo(&x);    // T is int, U is int*
------


<h2>Recursive Templates</h2>

	$(P Template features can be combined to produce some interesting
	effects, such as compile time evaluation of non-trivial functions.
	For example, a factorial template can be written:
	)

------
template factorial(int n : 1)
{
    enum { factorial = 1 }
}

template factorial(int n)
{
    enum { factorial = n* factorial!(n-1) }
}

void test()
{
    writefln("%s", factorial!(4));	// prints 24
}
------

<h2>Limitations</h2>

	$(P Templates cannot be used to add non-static members or functions
	to classes.
	For example:
	)

------
class Foo
{
    template TBar(T)
    {
	T xx;			// Error
	int func(T) { ... }	// Error

	static T yy;				// Ok
	static int func(T t, int y) { ... } 	// Ok
    }
}
------

	$(P Templates cannot be declared inside functions.
	)

)

Macros:
	TITLE=Templates
	WIKI=Template
	GLINK=$(LINK2 #$0, $(I $0))
	GNAME=<a name=$0>$(I $0)</a>
	DOLLAR=$
	FOO=

