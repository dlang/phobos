Ddoc

$(SPEC_S Statements,

C and C++ programmers will find the D statements very familiar, with a few
interesting additions.

$(GRAMMAR
$(GNAME Statement):
    $(B ;)
    $(GLINK NonEmptyStatement)
    $(GLINK ScopeBlockStatement)

$(GNAME NoScopeNonEmptyStatement):
    $(GLINK NonEmptyStatement)
    $(GLINK BlockStatement)

$(GNAME NoScopeStatement):
    $(B ;)
    $(GLINK NonEmptyStatement)
    $(GLINK BlockStatement)

$(GNAME NonEmptyOrScopeBlockStatement):
    $(GLINK NonEmptyStatement)
    $(GLINK ScopeBlockStatement)

$(GNAME NonEmptyStatement):
    $(GLINK LabeledStatement)
    $(GLINK ExpressionStatement)
    $(GLINK DeclarationStatement)
    $(GLINK IfStatement)
    $(LINK2 version.html, $(I ConditionalStatement))
    $(GLINK WhileStatement)
    $(GLINK DoStatement)
    $(GLINK ForStatement)
    $(GLINK ForeachStatement)
    $(GLINK SwitchStatement)
    $(GLINK CaseStatement)
    $(GLINK DefaultStatement)
    $(GLINK ContinueStatement)
    $(GLINK BreakStatement)
    $(GLINK ReturnStatement)
    $(GLINK GotoStatement)
    $(GLINK WithStatement)
    $(GLINK SynchronizedStatement)
    $(GLINK TryStatement)
    $(GLINK ScopeGuardStatement)
    $(GLINK ThrowStatement)
    $(GLINK VolatileStatement)
    $(GLINK AsmStatement)
    $(GLINK PragmaStatement)
    $(GLINK MixinStatement)
$(V2      $(GLINK ForeachRangeStatement))
)

<h2>$(LNAME2 ScopeStatement, Scope Statements)</h2>

$(GRAMMAR
$(I ScopeStatement):
    $(GLINK NonEmptyStatement)
    $(GLINK BlockStatement)
)

	$(P A new scope for local symbols
	is introduced for the $(I NonEmptyStatement)
	or $(GLINK BlockStatement).
	)

	$(P Even though a new scope is introduced,
	local symbol declarations cannot shadow (hide) other
	local symbol declarations in the same function.
	)

--------------
void func1(int x)
{   int x;	// illegal, x shadows parameter x

    int y;

    { int y; }	// illegal, y shadows enclosing scope's y

    void delegate() dg;
    dg = { int y; };	// ok, this y is not in the same function

    struct S
    {
	int y;		// ok, this y is a member, not a local
    }

    { int z; }
    { int z; }	// ok, this z is not shadowing the other z

    { int t; }
    { t++;   }	// illegal, t is undefined
}
--------------

$(P
	The idea is to avoid bugs in complex functions caused by
	scoped declarations inadvertently hiding previous ones.
	Local names should all be unique within a function.
)


<h2>$(LNAME2 ScopeBlockStatement, Scope Block Statements)</h2>

$(GRAMMAR
$(I ScopeBlockStatement):
    $(GLINK BlockStatement)
)

	$(P A scope block statement introduces a new scope for the
	$(GLINK BlockStatement).
	)

<h2>$(LNAME2 LabeledStatement, Labeled Statements)</h2>

$(P	Statements can be labeled. A label is an identifier that
	precedes a statement.
)

$(GRAMMAR
$(I LabelledStatement):
    $(I Identifier) ':' $(PSSEMI)
)

$(P
	Any statement can be labelled, including empty statements,
	and so can serve as the target
	of a goto statement. Labelled statements can also serve as the
	target of a break or continue statement.
)
$(P
	Labels are in a name space independent of declarations, variables,
	types, etc.
	Even so, labels cannot have the same name as local declarations.
	The label name space is the body of the function
	they appear in. Label name spaces do not nest, i.e. a label
	inside a block statement is accessible from outside that block.
)

<h2>$(LNAME2 BlockStatement, Block Statement)</h2>

$(GRAMMAR
$(I BlockStatement):
    $(B { })
    $(B {) $(I StatementList) $(B })

$(GNAME StatementList):
    $(PSSEMI_PSCURLYSCOPE)
    $(PSSEMI_PSCURLYSCOPE) $(I StatementList)
)

$(P
	A block statement is a sequence of statements enclosed
	by { }. The statements are executed in lexical order.
)
<h2>$(LNAME2 ExpressionStatement, Expression Statement)</h2>

$(GRAMMAR
$(I ExpressionStatement):
    $(I Expression) $(B ;)
)

	The expression is evaluated.
	<p>

	Expressions that have no effect, like $(TT (x + x)),
	are illegal
	in expression statements.
	If such an expression is needed, casting it to $(D_KEYWORD void) will
	make it legal.

----
int x;
x++;                // ok
x;                  // illegal
1+1;                // illegal
cast(void)(x + x);  // ok
----

<h2>$(LNAME2 DeclarationStatement, Declaration Statement)</h2>

	Declaration statements declare variables and types.

$(GRAMMAR
$(I DeclarationStatement):
    $(I Declaration)
)

	$(P Some declaration statements:)

----
int a;		 // declare a as type int and initialize it to 0
struct S { }	 // declare struct s
alias int myint;
----

<h2>$(LNAME2 IfStatement, If Statement)</h2>

	If statements provide simple conditional execution of statements.

$(GRAMMAR
$(I IfStatement):
	$(B if $(LPAREN)) $(I IfCondition) $(B $(RPAREN)) $(I ThenStatement)
	$(B if $(LPAREN)) $(I IfCondition) $(B $(RPAREN)) $(I ThenStatement) $(B else) $(I ElseStatement)

$(I IfCondition):
	$(I Expression)
	$(B auto) $(I Identifier) $(B =) $(I Expression)
	$(I Declarator) $(B =) $(I Expression)

$(I ThenStatement):
	$(PSSCOPE)

$(I ElseStatement):
	$(PSSCOPE)
)

	$(I Expression) is evaluated and must have a type that
	can be converted to a boolean. If it's true the
	$(I ThenStatement) is transferred to, else the $(I ElseStatement)
	is transferred to.
	<p>

	The 'dangling else' parsing problem is solved by associating the
	else with the nearest if statement.
	<p>

	If an $(B auto) $(I Identifier) is provided, it is declared and
	initialized
	to the value
	and type of the $(I Expression). Its scope extends from when it is
	initialized to the end of the $(I ThenStatement).
	<p>

	If a $(I Declarator) is provided, it is declared and
	initialized
	to the value
	of the $(I Expression). Its scope extends from when it is
	initialized to the end of the $(I ThenStatement).

---
import std.regexp;
...
if (auto m = std.regexp.search("abcdef", "b(c)d"))
{
    writefln("[%s]", m.pre);      // prints [a]
    writefln("[%s]", m.post);     // prints [ef]
    writefln("[%s]", m.match(0)); // prints [bcd]
    writefln("[%s]", m.match(1)); // prints [c]
    writefln("[%s]", m.match(2)); // prints []
}
else
{
    writefln(m.post);    // error, m undefined
}
writefln(m.pre);         // error, m undefined
---

<h2>$(LNAME2 WhileStatement, While Statement)</h2>

$(GRAMMAR
$(I WhileStatement):
    $(B while $(LPAREN)) $(I Expression) $(B $(RPAREN)) $(PSSCOPE)
)

	While statements implement simple loops.

	$(I Expression) is evaluated and must have a type that
	can be converted to a boolean. If it's true the
	$(PSSCOPE) is executed. After the $(PSSCOPE) is executed,
	the $(I Expression) is evaluated again, and if true the
	$(PSSCOPE) is executed again. This continues until the
	$(I Expression) evaluates to false.

---
int i = 0;
while (i < 10)
{
    foo(i);
    i++;
}
---

	A $(GLINK BreakStatement) will exit the loop.
	A $(GLINK ContinueStatement)
	will transfer directly to evaluating $(I Expression) again.

<h2>$(LNAME2 DoStatement, Do Statement)</h2>

$(GRAMMAR
$(I DoStatement):
    $(B do) $(PSSCOPE) $(B  while $(LPAREN)) $(I Expression) $(B $(RPAREN))
)

	Do while statements implement simple loops.

	$(PSSCOPE) is executed. Then
	$(I Expression) is evaluated and must have a type that
	can be converted to a boolean. If it's true the
	loop is iterated again.
	This continues until the
	$(I Expression) evaluates to false.

---
int i = 0;
do
{
    foo(i);
} while (++i < 10);
---

	A $(GLINK BreakStatement) will exit the loop.
	A $(GLINK ContinueStatement)
	will transfer directly to evaluating $(I Expression) again.

<h2>$(LNAME2 ForStatement, For Statement)</h2>

	For statements implement loops with initialization,
	test, and increment clauses.

$(GRAMMAR
$(I ForStatement):
	$(B for $(LPAREN))$(I Initialize) $(I Test)$(B ;) $(I Increment)$(B $(RPAREN)) $(PSSCOPE)

$(I Initialize):
	$(B ;)
	$(PS0)

$(I Test):
	$(I empty)
	$(I Expression)

$(I Increment):
	$(I empty)
	$(I Expression)
)

	$(P $(I Initialize) is executed.
	$(I Test) is evaluated and must have a type that
	can be converted to a boolean. If it's true the
	statement is executed. After the statement is executed,
	the $(I Increment) is executed.
	Then $(I Test) is evaluated again, and if true the
	statement is executed again. This continues until the
	$(I Test) evaluates to false.
	)

	$(P A $(GLINK BreakStatement) will exit the loop.
	A $(GLINK ContinueStatement)
	will transfer directly to the $(I Increment).
	)

	$(P A $(I ForStatement) creates a new scope.
	If $(I Initialize) declares a variable, that variable's scope
	extends through the end of the for statement. For example:
	)

--------------
for (int i = 0; i < 10; i++)
	foo(i);
--------------

	is equivalent to:

--------------
{   int i;
    for (i = 0; i < 10; i++)
	foo(i);
}
--------------

	Function bodies cannot be empty:

--------------
for (int i = 0; i < 10; i++)
	;	// illegal
--------------

	Use instead:

--------------
for (int i = 0; i < 10; i++)
{
}
--------------

	The $(I Initialize) may be omitted. $(I Test) may also be
	omitted, and if so, it is treated as if it evaluated to true.

<h2>$(LNAME2 ForeachStatement, Foreach Statement)</h2>

	A foreach statement loops over the contents of an aggregate.

$(GRAMMAR
$(I ForeachStatement):
    $(I Foreach $(LPAREN))$(I ForeachTypeList)$(B ;) $(I Aggregate)$(B $(RPAREN)) $(PSSCOPE)

$(GNAME Foreach):
    $(B foreach)
    $(B foreach_reverse)

$(I ForeachTypeList):
    $(I ForeachType)
    $(I ForeachType) , $(I ForeachTypeList)

$(GNAME ForeachType):
    $(B ref) $(I Type) $(I Identifier)
    $(I Type) $(I Identifier)
    $(B ref) $(I Identifier)
    $(I Identifier)

$(I Aggregate):
    $(I Expression)
    $(I Tuple)
)

$(P
	$(I Aggregate) is evaluated. It must evaluate to an expression
	of type static array, dynamic array, associative array,
	struct, class, delegate, or tuple.
	The $(PS0) is executed, once for each element of the
	aggregate.
	At the start of each iteration, the variables declared by
	the $(I ForeachTypeList)
	are set to be a copy of the elements of the aggregate.
	If the variable is $(B ref), it is a reference to the
	contents of that aggregate.
)
$(P
	The aggregate must be loop invariant, meaning that
	elements to the aggregate cannot be added or removed from it
	in the $(PS0).
)
$(P
	If the aggregate is a static or dynamic array, there
	can be one or two variables declared. If one, then the variable
	is said to be the $(I value) set to the elements of the array,
	one by one. The type of the
	variable must match the type of the array contents, except for the
	special cases outlined below.
	If there are
	two variables declared, the first is said to be the $(I index)
	and the second is said to be the $(I value). The $(I index)
	must be of $(B int) or $(B uint) type, it cannot be $(I ref),
	and it is set to be the index of the array element.
)
--------------
char[] a;
...
foreach (int i, char c; a)
{
    writefln("a[%d] = '%c'", i, c);
}
--------------

	$(P For $(B foreach), the
	elements for the array are iterated over starting at index 0
	and continuing to the maximum of the array.
	For $(B foreach_reverse), the array elements are visited in the reverse
	order.
	)

	$(P If the aggregate expression is a static or dynamic array of
	$(B char)s, $(B wchar)s, or $(B dchar)s, then the $(I Type) of
	the $(I value)
	can be any of $(B char), $(B wchar), or $(B dchar).
	In this manner any UTF array
	can be decoded into any UTF type:
	)

--------------
char[] a = "\xE2\x89\xA0";	// \u2260 encoded as 3 UTF-8 bytes

foreach (dchar c; a)
{
    writefln("a[] = %x", c);	// prints 'a[] = 2260'
}

dchar[] b = "\u2260";

foreach (char c; b)
{
    writef("%x, ", c);	// prints 'e2, 89, a0, '
}
--------------


	$(P Aggregates can be string literals, which can be accessed
	as char, wchar, or dchar arrays:
	)

--------------
void test()
{
    foreach (char c; "ab")
    {
	writefln("'%s'", c);
    }
    foreach (wchar w; "xy")
    {
	writefln("'%s'", w);
    }
}
--------------

	$(P which would print:
	)

$(CONSOLE
'a'
'b'
'x'
'y'
)

	$(P If the aggregate expression is an associative array, there
	can be one or two variables declared. If one, then the variable
	is said to be the $(I value) set to the elements of the array,
	one by one. The type of the
	variable must match the type of the array contents. If there are
	two variables declared, the first is said to be the $(I index)
	and the second is said to be the $(I value). The $(I index)
	must be of the same type as the indexing type of the associative
	array. It cannot be $(I ref),
	and it is set to be the index of the array element.
	The order in which the elements of the array is unspecified
	for $(B foreach). $(B foreach_reverse) for associative arrays
	is illegal.
	)

--------------
double[char[]] a;	// $(I index) type is char[], $(I value) type is double
...
foreach (char[] s, double d; a)
{
    writefln("a['%s'] = %g", s, d);
}
--------------

	$(P
	If it is a struct or class object, the $(B foreach) is defined by
	the special $(I opApply) member function.
	The $(B foreach_reverse) behavior is defined by the special
	$(I opApplyReverse) member function.
	These special functions must be defined by the type in order
	to use the corresponding foreach statement.
	The functions have the type:
	)

--------------
int $(B opApply)(int delegate(ref $(I Type) [, ...]) $(I dg));

int $(B opApplyReverse)(int delegate(ref $(I Type) [, ...]) $(I dg));
--------------

	$(P where $(I Type) matches the $(I Type) used in the $(I ForeachType)
	declaration of $(I Identifier). Multiple $(I ForeachType)s
	correspond with multiple $(I Type)'s in the delegate type
	passed to $(B opApply) or $(B opApplyReverse).
	There can be multiple $(B opApply) and $(B opApplyReverse) functions,
	one is selected
	by matching the type of $(I dg) to the $(I ForeachType)s
	of the $(I ForeachStatement).
	The body of the apply
	function iterates over the elements it aggregates, passing them
	each to the $(I dg) function. If the $(I dg) returns 0, then
	apply goes on to the next element.
	If the $(I dg) returns a nonzero value, apply must cease
	iterating and return that value. Otherwise, after done iterating
	across all the elements, apply will return 0.
	)

	$(P For example, consider a class that is a container for two elements:
	)

--------------
class Foo
{
    uint array[2];

    int $(B opApply)(int delegate(ref uint) $(I dg))
    {   int result = 0;

	for (int i = 0; i < array.length; i++)
	{
	    result = $(I dg)(array[i]);
	    if (result)
		break;
	}
	return result;
    }
}
--------------

	An example using this might be:

--------------
void test()
{
    Foo a = new Foo();

    a.array[0] = 73;
    a.array[1] = 82;

    foreach (uint u; a)
    {
	writefln("%d", u);
    }
}
--------------

	which would print:

$(CONSOLE
73
82
)
	$(P If $(I Aggregate) is a delegate, the type signature of
	the delegate is of the same as for $(B opApply). This enables
	many different named looping strategies to coexist in the same
	class or struct.)

	$(P $(B ref) can be used to update the original elements:
	)

--------------
void test()
{
    static uint[2] a = [7, 8];

    foreach (ref uint u; a)
    {
	u++;
    }
    foreach (uint u; a)
    {
	writefln("%d", u);
    }
}
--------------

	which would print:

$(CONSOLE
8
9
)
	$(P $(B ref) can not be applied to the index values.)

	$(P If not specified, the $(I Type)s in the $(I ForeachType) can be
	inferred from
	the type of the $(I Aggregate).
	)

	$(P The aggregate itself must not be resized, reallocated, free'd,
	reassigned or destructed
	while the foreach is iterating over the elements.
	)

--------------
int[] a;
int[] b;
foreach (int i; a)
{
    a = null;			// error
    a.length = a.length + 10;	// error
    a = b;			// error
}
a = null;			// ok
--------------

$(P
	If the aggregate is a tuple, there
	can be one or two variables declared. If one, then the variable
	is said to be the $(I value) set to the elements of the tuple,
	one by one. If the type of the
	variable is given, it must match the type of the tuple contents.
	If it is not given, the type of the variable is set to the type
	of the tuple element, which may change from iteration to iteration.
	If there are
	two variables declared, the first is said to be the $(I index)
	and the second is said to be the $(I value). The $(I index)
	must be of $(B int) or $(B uint) type, it cannot be $(I ref),
	and it is set to be the index of the tuple element.
)

$(P
	If the tuple is a list of types, then the foreach statement
	is executed once for each type, and the value is aliased to that
	type.
)

-----
import std.stdio;
import std.typetuple;	// for TypeTuple

void main()
{
    alias TypeTuple!(int, long, double) TL;

    foreach (T; TL)
    {
	writefln(typeid(T));
    }
}
-----

	$(P Prints:)

$(CONSOLE
int
long
double
)

	$(P A $(GLINK BreakStatement) in the body of the foreach will exit the
	foreach, a $(GLINK ContinueStatement) will immediately start the
	next iteration.
	)

<h2>$(LNAME2 SwitchStatement, Switch Statement)</h2>

	A switch statement goes to one of a collection of case
	statements depending on the value of the switch
	expression.

$(GRAMMAR
$(I SwitchStatement):
	$(B switch $(LPAREN)) $(I Expression) $(B $(RPAREN)) $(PSSCOPE)

$(GNAME CaseStatement):
	$(B case) $(I ExpressionList) $(B :) $(PSSEMI_PSCURLYSCOPE)

$(GNAME DefaultStatement):
	$(B default:) $(PSSEMI_PSCURLYSCOPE)
)

	$(I Expression) is evaluated. The result type T must be
	of integral type or char[], wchar[] or dchar[]. The result is
	compared against each of the case expressions. If there is
	a match, the corresponding case statement is transferred to.
	<p>

	The case expressions, $(I ExpressionList), are a comma separated
	list of expressions.
	<p>

	If none of the case expressions match, and there is a default
	statement, the default statement is transferred to.
	<p>

	If none of the case expressions match, and there is not a default
	statement, a SwitchError is thrown. The reason for this is
	to catch the common programming error of adding a new value to
	an enum, but failing to account for the extra value in
	switch statements. This behavior is unlike C or C++.
	<p>

	The case expressions must all evaluate to a constant value
	or array, and be implicitly convertible to the type T of the
	switch $(I Expression).
	<p>

	Case expressions must all evaluate to distinct values.
	There may not be two or more default statements.
	<p>

	Case statements and default statements associated with the switch
	can be nested within block statements; they do not have to be in
	the outermost block. For example, this is allowed:

--------------
    switch (i)
    {
	case 1:
	{
	    case 2:
	}
	    break;
    }
--------------

	Like in C and C++, case statements 'fall through' to subsequent
	case values. A break statement will exit the switch $(I BlockStatement).
	For example:

--------------
switch (i)
{
    case 1:
	x = 3;
    case 2:
	x = 4;
	break;

    case 3,4,5:
	x = 5;
	break;
}
--------------

	will set x to 4 if i is 1.
	<p>

	$(B Note:) Unlike C and C++, strings can be used in switch
	expressions. For example:

--------------
char[] name;
...
switch (name)
{
    case "fred":
    case "sally":
	...
}
--------------

	For applications like command line switch processing, this
	can lead to much more straightforward code, being clearer and
	less error prone. Both ascii and wchar strings are allowed.
	<p>

	$(B Implementation Note:) The compiler's code generator may
	assume that the case
	statements are sorted by frequency of use, with the most frequent
	appearing first and the least frequent last. Although this is
	irrelevant as far as program correctness is concerned, it is of
	performance interest.


<h2>$(LNAME2 ContinueStatement, Continue Statement)</h2>

$(GRAMMAR
$(I ContinueStatement):
    $(B continue;)
    $(B continue) $(I Identifier) $(B ;)
)

	A continue aborts the current iteration of its enclosing loop
	statement, and starts the next iteration.

	continue executes the next iteration of its innermost enclosing
	while, for, or do loop. The increment clause is executed.
	<p>

	If continue is followed by $(I Identifier), the $(I Identifier)
	must be the label of an enclosing while, for, or do
	loop, and the next iteration of that loop is executed.
	It is an error if
	there is no such statement.
	<p>

	Any intervening finally clauses are executed, and any intervening
	synchronization objects are released.
	<p>

	$(B Note:) If a finally clause executes a return, throw, or goto
	out of the finally clause,
	the continue target is never reached.

---
for (i = 0; i < 10; i++)
{
    if (foo(i))
	continue;
    bar();
}
---

<h2>$(LNAME2 BreakStatement, Break Statement)</h2>

$(GRAMMAR
$(I BreakStatement):
    $(B break;)
    $(B break) $(I Identifier) $(B ;)
)

	A break exits the enclosing statement.

	break exits the innermost enclosing while, for, do, or switch
	statement, resuming execution at the statement following it.
	<p>

	If break is followed by $(I Identifier), the $(I Identifier)
	must be the label of an enclosing while, for, do or switch
	statement, and that statement is exited. It is an error if
	there is no such statement.
	<p>

	Any intervening finally clauses are executed, and any intervening
	synchronization objects are released.
	<p>

	$(B Note:) If a finally clause executes a return, throw, or goto
	out of the finally clause,
	the break target is never reached.

---
for (i = 0; i < 10; i++)
{
    if (foo(i))
	break;
}
---

<h2>$(LNAME2 ReturnStatement, Return Statement)</h2>

$(GRAMMAR
$(I ReturnStatement):
    $(B return;)
    $(B return) $(I Expression) $(B ;)
)

	A return exits the current function and supplies its return
	value.

	$(I Expression) is required if the function specifies
	a return type that is not void.
	The $(I Expression) is implicitly converted to the
	function return type.
	<p>

	At least one return statement, throw statement, or assert(0) expression
	is required if the function
	specifies a return type that is not void.
	<p>

	$(I Expression) is allowed even if the function specifies
	a $(B void) return type. The $(I Expression) will be evaluated,
	but nothing will be returned.
	<p>

	Before the function actually returns,
	any objects with auto storage duration are destroyed,
	any enclosing finally clauses are executed,
	any scope(exit) statements are executed,
	any scope(success) statements are executed,
	and any enclosing synchronization
	objects are released.
	<p>

	The function will not return if any enclosing finally clause
	does a return, goto or throw that exits the finally clause.
	<p>

	If there is an out postcondition
	(see $(LINK2 dbc.html, Contract Programming)),
	that postcondition is executed
	after the $(I Expression) is evaluated and before the function
	actually returns.

---
int foo(int x)
{
    return x + 3;
}
---

<h2>$(LNAME2 GotoStatement, Goto Statement)</h2>

$(GRAMMAR
$(I GotoStatement):
    $(B goto) $(I Identifier) $(B ;)
    $(B goto) $(B default) $(B ;)
    $(B goto) $(B case) $(B ;)
    $(B goto) $(B case) $(I Expression) $(B ;)
)

	A goto transfers to the statement labelled with
	$(I Identifier).

---
    if (foo)
	goto L1;
    x = 3;
L1:
    x++;
---

	The second form, $(TT goto default;), transfers to the
	innermost $(I DefaultStatement) of an enclosing $(I SwitchStatement).
	<p>

	The third form, $(TT goto case;), transfers to the
	next $(I CaseStatement) of the innermost enclosing
	$(I SwitchStatement).
	<p>

	The fourth form, $(TT goto case $(I Expression);), transfers to the
	$(I CaseStatement) of the innermost enclosing $(I SwitchStatement)
	with a matching $(I Expression).

---
switch (x)
{
    case 3:
	goto case;
    case 4:
	goto default;
    case 5:
	goto case 4;
    default:
	x = 4;
	break;
}
---
	Any intervening finally clauses are executed, along with
	releasing any intervening synchronization mutexes.
	<p>

	It is illegal for a $(I GotoStatement) to be used to skip
	initializations.

<h2>$(LNAME2 WithStatement, With Statement)</h2>

	The with statement is a way to simplify repeated references
	to the same object.

$(GRAMMAR
$(I WithStatement):
	$(B with) $(B $(LPAREN)) $(I Expression) $(B $(RPAREN)) $(PSSCOPE)
	$(B with) $(B $(LPAREN)) $(I Symbol) $(B $(RPAREN)) $(PSSCOPE)
	$(B with) $(B $(LPAREN)) $(I TemplateInstance) $(B $(RPAREN)) $(PSSCOPE)
)

	where $(I Expression) evaluates to a class reference or struct
	instance.
	Within the with body the referenced object is searched first for
	identifier symbols. The $(I WithStatement)

--------------
$(B with) (expression)
{
    ...
    ident;
}
--------------

	is semantically equivalent to:

--------------
{
    Object tmp;
    tmp = expression;
    ...
    tmp.ident;
}
--------------

	Note that $(TT expression) only gets evaluated once.
	The with statement does not change what $(B this) or
	$(B super) refer to.
	<p>

	For $(I Symbol) which is a scope or $(I TemplateInstance),
	the corresponding scope is searched when looking up symbols.
	For example:

--------------
struct Foo
{
    typedef int Y;
}
...
Y y;		// error, Y undefined
with (Foo)
{
    Y y;	// same as Foo.Y y;
}
--------------

<h2>$(LNAME2 SynchronizedStatement, Synchronized Statement)</h2>

	The synchronized statement wraps a statement with
	critical section to synchronize access among multiple threads.

$(GRAMMAR
$(I SynchronizedStatement):
    $(B synchronized) $(PSSCOPE)
    $(B synchronized $(LPAREN)) $(I Expression) $(B $(RPAREN)) $(PSSCOPE)
)

	Synchronized allows only one thread at a time to execute
	$(I ScopeStatement).
	<p>

	synchronized ($(I Expression)), where $(I Expression) evaluates to an
	Object reference, allows only one thread at a time to use
	that Object to execute the $(I ScopeStatement).
	If $(I Expression) is an instance of an $(I Interface), it is
	cast to an $(I Object).
	<p>

	The synchronization gets released even if $(I ScopeStatement) terminates
	with an exception, goto, or return.
	<p>

	Example:

--------------
synchronized { ... }
--------------

	This implements a standard critical section.

<h2>$(LNAME2 TryStatement, Try Statement)</h2>

	Exception handling is done with the try-catch-finally statement.

$(GRAMMAR
$(I TryStatement):
	$(B try) $(PSSCOPE) $(I Catches)
	$(B try) $(PSSCOPE) $(I Catches) $(I FinallyStatement)
	$(B try) $(PSSCOPE) $(I FinallyStatement)

$(I Catches):
	$(I LastCatch)
	$(I Catch)
	$(I Catch) $(I Catches)

$(I LastCatch):
	$(B catch) $(PS0)

$(I Catch):
	$(B catch $(LPAREN)) $(I CatchParameter) $(B $(RPAREN)) $(PS0)

$(I FinallyStatement):
	$(B finally) $(PS0)
)

	$(P $(I CatchParameter) declares a variable v of type T, where T is
	Object
	or derived from Object. v is initialized by the throw expression if
	T is of the same type or a base class of the throw expression.
	The catch clause will be executed if the exception object is of
	type T or derived from T.
	)

	$(P If just type T is given and no variable v, then the catch clause
	is still executed.
	)

	$(P It is an error if any $(I CatchParameter) type T1 hides
	a subsequent $(I Catch) with type T2, i.e. it is an error if
	T1 is the same type as or a base class of T2.
	)

	$(P $(I LastCatch) catches all exceptions.
	)

	$(P The $(I FinallyStatement) is always executed, whether
	the $(B try) $(I ScopeStatement) exits with a goto, break,
	continue, return, exception, or fall-through.
	)

	$(P If an exception is raised in the $(I FinallyStatement) and
	is not caught before the $(I FinallyStatement) is executed,
	the new exception replaces any existing exception:
	)

--------------
import std.stdio;

int main()
{
    try
    {
	try
	{
	    throw new Exception("first");
	}
	finally
	{
	    writefln("finally");
	    throw new Exception("second");
	}
    }
    catch(Exception e)
    {
	writefln("catch %s", e.msg);
    }
    writefln("done");
    return 0;
}
--------------

    prints:

$(CONSOLE
finally
catch second
done
)

	$(P A $(I FinallyStatement) may not exit with a goto, break,
	continue, or return; nor may it be entered with a goto.
	)

	$(P A $(I FinallyStatement) may not contain any $(I Catches).
	This restriction may be relaxed in future versions.
	)

<h2>$(LNAME2 ThrowStatement, Throw Statement)</h2>

	Throw an exception.

$(GRAMMAR
$(I ThrowStatement):
	$(B throw) $(I Expression) $(B ;)
)

	$(I Expression) is evaluated and must be an Object reference.
	The Object reference is thrown as an exception.

---
throw new Exception("message");
---

<h2>$(LNAME2 ScopeGuardStatement, Scope Guard Statement)</h2>

$(GRAMMAR
$(I ScopeGuardStatement):
	$(B scope(exit)) $(PSCURLYSCOPE)
	$(B scope(success)) $(PSCURLYSCOPE)
	$(B scope(failure)) $(PSCURLYSCOPE)
)

	The $(I ScopeGuardStatement) executes $(PSCURLYSCOPE) at the close
	of the current scope, rather than at the point where the
	$(I ScopeGuardStatement) appears.
	$(B scope(exit)) executes $(PSCURLYSCOPE) when the scope
	exits normally or when it exits due to exception unwinding.
	$(B scope(failure)) executes $(PSCURLYSCOPE) when the scope
	exits due to exception unwinding.
	$(B scope(success)) executes $(PSCURLYSCOPE) when the scope
	exits normally.
	<p>

	If there are multiple $(I ScopeGuardStatement)s in a scope, they
	are executed in the reverse lexical order in which they appear.
	If any auto instances are to be destructed upon the close of the
	scope, they also are interleaved with the $(I ScopeGuardStatement)s
	in the reverse lexical order in which they appear.

----
writef("1");
{
    writef("2");
    scope(exit) writef("3");
    scope(exit) writef("4");
    writef("5");
}
writefln();
----

	writes:

$(CONSOLE
12543
)

----
{
    scope(exit) writef("1");
    scope(success) writef("2");
    scope(exit) writef("3");
    scope(success) writef("4");
}
writefln();
----

	writes:

$(CONSOLE
4321
)

----
class Foo
{
    this() { writef("0"); }
    ~this() { writef("1"); }
}

try
{
    scope(exit) writef("2");
    scope(success) writef("3");
    auto Foo f = new Foo();
    scope(failure) writef("4");
    throw new Exception("msg");
    scope(exit) writef("5");
    scope(success) writef("6");
    scope(failure) writef("7");
}
catch (Exception e)
{
}
writefln();
----

	writes:

$(CONSOLE
0412
)

	A $(B scope(exit)) or $(B scope(success)) statement
	may not exit with a throw, goto, break, continue, or
	return; nor may it be entered with a goto.

<h2>$(LNAME2 VolatileStatement, Volatile Statement)</h2>

	No code motion occurs across volatile statement boundaries.

$(GRAMMAR
$(I VolatileStatement):
	$(B volatile) $(PSSEMI_PSCURLYSCOPE)
	$(B volatile) $(B ;)
)

	$(PSSEMI_PSCURLYSCOPE) is evaluated.
	Memory writes occurring before the $(PSSEMI_PSCURLYSCOPE) are
	performed before any reads within or after the $(PSSEMI_PSCURLYSCOPE).
	Memory reads occurring after the $(PSSEMI_PSCURLYSCOPE) occur after
	any writes before or within $(PSSEMI_PSCURLYSCOPE) are completed.
	<p>

	A volatile statement does not guarantee atomicity. For that,
	use synchronized statements.

<h2>$(LNAME2 asm, Asm Statement)</h2>

	Inline assembler is supported with the asm statement:

$(GRAMMAR
$(I AsmStatement):
	$(B asm { })
	$(B asm {) $(I AsmInstructionList) $(B })

$(I AsmInstructionList):
	$(I AsmInstruction) $(B ;)
	$(I AsmInstruction) $(B ;) $(I AsmInstructionList)
)

	An asm statement enables the direct use of assembly language
	instructions. This makes it easy to obtain direct access to special
	CPU features without resorting to an external assembler. The
	D compiler will take care of the function calling conventions,
	stack setup, etc.
	<p>

	The format of the instructions is, of course, highly dependent
	on the native instruction set of the target CPU, and so is
	$(LINK2 iasm.html, implementation defined).
	But, the format will follow the following
	conventions:

	$(UL 
	$(LI It must use the same tokens as the D language uses.)
	$(LI The comment form must match the D language comments.)
	$(LI Asm instructions are terminated by a ;, not by an
	end of line.)
	)

	These rules exist to ensure that D source code can be tokenized
	independently of syntactic or semantic analysis.
	<p>

	For example, for the Intel Pentium:

--------------
int x = 3;
asm
{
    mov	EAX,x;		// load x and put it in register EAX
}
--------------

	Inline assembler can be used to access hardware directly:

--------------
int gethardware()
{
    asm
    {
	    mov	EAX, dword ptr 0x1234;
    }
}
--------------

	For some D implementations, such as a translator from D to C, an
	inline assembler makes no sense, and need not be implemented.
	The version statement can be used to account for this:

--------------
version (D_InlineAsm_X86)
{
    asm
    {
	...
    }
}
else
{
    /* ... some workaround ... */
}
--------------

<h2>$(LNAME2 PragmaStatement, Pragma Statement)</h2>

$(GRAMMAR
$(I PragmaStatement):
    $(LINK2 pragma.html, $(I Pragma)) $(PSSEMI)
)

<h2>$(LNAME2 MixinStatement, Mixin Statement)</h2>

$(GRAMMAR
$(I MixinStatement):
    $(B mixin) $(B $(LPAREN)) $(ASSIGNEXPRESSION) $(B $(RPAREN)) $(B ;)
)

	$(P The $(ASSIGNEXPRESSION) must evaluate at compile time
	to a constant string.
	The text contents of the string must be compilable as a valid
	$(GLINK StatementList), and is compiled as such.
	)

---
import std.stdio;

void main()
{
    int j;
    mixin("
	int x = 3;
	for (int i = 0; i < 3; i++)
	    writefln(x + i, ++j);
	");    // ok

    const char[] s = "int y;";
    mixin(s);  // ok
    y = 4;     // ok, mixin declared y

    char[] t = "y = 3;";
    mixin(t);  // error, t is not evaluatable at compile time

    mixin("y =") 4; // error, string must be complete statement

    mixin("y =" ~ "4;");  // ok
}
---

$(V2
<h2>$(LNAME2 ForeachRangeStatement, Foreach Range Statement)</h2>

	A foreach range statement loops over the specified range.

$(GRAMMAR
$(I ForeachRangeStatement):
    $(GLINK Foreach) $(LPAREN)$(GLINK ForeachType)$(B ;) $(I LwrExpression) $(B ..) $(I UprExpression) $(B $(RPAREN)) $(PSSCOPE)

$(I LwrExpression):
    $(I Expression)

$(I UprExpression):
    $(I Expression)
)

	$(P
	$(I ForeachType) declares a variable with either an explicit type,
	or a type inferred from $(I LwrExpression) and $(I UprExpression).
	The $(I ScopeStatement) is then executed $(I n) times, where $(I n)
	is the result of $(I UprExpression) - $(I LwrExpression).
	If $(I UprExpression) is less than or equal to $(I LwrExpression),
	the $(I ScopeStatement) is executed zero times.
	If $(I Foreach) is $(B foreach), then the variable is set to
	$(I LwrExpression), then incremented at the end of each iteration.
	If $(I Foreach) is $(B foreach_reverse), then the variable is set to
	$(I UprExpression), then decremented before each iteration.
	$(I LwrExpression) and $(I UprExpression) are each evaluated
	exactly once, regardless of how many times the $(I ScopeStatement)
	is executed.
	)

---
import std.stdio;

int foo()
{
    writefln("foo");
    return 10;
}

void main()
{
    foreach (i; 0 .. foo())
    {
	writef(i);
    }
}
---

	$(P Prints:)

$(CONSOLE
foo0123456789
)
)

)

Macros:
	TITLE=Statements
	WIKI=Statement
	GLINK=$(LINK2 #$0, $(I $0))
	GNAME=$(LNAME2 $0, $0)
	PSSEMI_PSCURLYSCOPE=$(GLINK Statement)
	PS0=$(GLINK NoScopeNonEmptyStatement)
	PSSCOPE=$(GLINK ScopeStatement)
	PSCURLY=$(GLINK BlockStatement)
	PSSEMI=$(GLINK NoScopeStatement)
	PSCURLY_PSSCOPE=$(GLINK ScopeBlockStatement)
	PSCURLYSCOPE=$(GLINK NonEmptyOrScopeBlockStatement)
	FOO=

