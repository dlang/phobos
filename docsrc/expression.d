Ddoc

$(SPEC_S Expressions,

	$(P C and C++ programmers will find the D expressions very familiar,
	with a few interesting additions.
	)

	$(P Expressions are used to compute values with a resulting type.
	These values can then be assigned,
	tested, or ignored. Expressions can also have side effects.
	)

<h2>Evaluation Order</h2>

	$(P Unless otherwise specified, the implementation is free to evaluate
	the components of an expression in any order. It is an error
	to depend on order of evaluation when it is not specified.
	For example, the following are illegal:
	)
-------------
i = i++;
c = a + (a = b);
func(++i, ++i);
-------------
	$(P If the compiler can determine that the result of an expression
	is illegally dependent on the order of evaluation, it can issue
	an error (but is not required to). The ability to detect these kinds
	of errors is a quality of implementation issue.
	)

<h2><a name="Expression">Expressions</a></h2>

$(GRAMMAR
$(GNAME Expression):
	$(GLINK AssignExpression)
	$(GLINK AssignExpression) $(B ,) $(I Expression)
)

	The left operand of the $(B ,) is evaluated, then the right operand
	is evaluated. The type of the expression is the type of the right
	operand, and the result is the result of the right operand.
	

<h2>Assign Expressions</h2>

$(GRAMMAR
$(GNAME AssignExpression):
	$(GLINK ConditionalExpression)
	$(GLINK ConditionalExpression) $(B =) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B +=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B -=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B *=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B /=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B %=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B &=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B |=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B ^=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B ~=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B &lt;&lt;=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B &gt;&gt;=) $(I AssignExpression)
	$(GLINK ConditionalExpression) $(B &gt;&gt;&gt;=) $(I AssignExpression)
)

	The right operand is implicitly converted to the type of the
	left operand, and assigned to it. The result type is the type
	of the lvalue, and the result value is the value of the lvalue
	after the assignment.
	<p>

	The left operand must be an lvalue.

<h3>Assignment Operator Expressions</h3>

	Assignment operator expressions, such as:

--------------
$(I a op= b)
--------------

	are semantically equivalent to:

--------------
$(I a = a op b)
--------------

	except that operand $(I a) is only evaluated once.

<h2>Conditional Expressions</h2>

$(GRAMMAR
$(GNAME ConditionalExpression):
	$(GLINK OrOrExpression)
	$(GLINK OrOrExpression) $(B ?) $(GLINK Expression) $(B :) $(I ConditionalExpression)
)

	The first expression is converted to bool, and is evaluated.
	If it is true, then the second expression is evaluated, and
	its result is the result of the conditional expression.
	If it is false, then the third expression is evaluated, and
	its result is the result of the conditional expression.
	If either the second or third expressions are of type void,
	then the resulting type is void. Otherwise, the second and third
	expressions are implicitly converted to a common type which becomes
	the result type of the conditional expression.

<h2>OrOr Expressions</h2>

$(GRAMMAR
$(GNAME OrOrExpression):
	$(GLINK AndAndExpression)
	$(I OrOrExpression) $(B ||) $(GLINK AndAndExpression)
)

	The result type of an $(I OrOrExpression) is bool,
	unless the right operand
	has type void, when the result is type void.
	<p>

	The $(I OrOrExpression) evaluates its left operand.

	If the left operand, converted to type bool, evaluates to
	true, then the right operand is not evaluated. If the result type of
	the $(I OrOrExpression) is bool then the result of the
	expression is true.

	If the left operand is false, then the right
	operand is evaluated.
	If the result type of
	the $(I OrOrExpression) is bool then the result of the
	expression is the right operand converted to type bool.


<h2>AndAnd Expressions</h2>

$(GRAMMAR
$(GNAME AndAndExpression):
	$(GLINK OrExpression)
	$(I AndAndExpression) $(B &&) $(GLINK OrExpression)

)

	$(P The result type of an $(I AndAndExpression) is bool, unless the right operand
	has type void, when the result is type void.
	)

	$(P The $(I AndAndExpression) evaluates its left operand.
	)

	$(P If the left operand, converted to type bool, evaluates to
	false, then the right operand is not evaluated. If the result type of
	the $(I AndAndExpression) is bool then the result of the
	expression is false.
	)

	$(P If the left operand is true, then the right
	operand is evaluated.
	If the result type of
	the $(I AndAndExpression) is bool then the result of the
	expression is the right operand converted to type bool.
	)


<h2>Bitwise Expressions</h2>

	Bit wise expressions perform a bitwise operation on their operands.
	Their operands must be integral types.
	First, the default integral promotions are done. Then, the bitwise
	operation is done.

<h3>Or Expressions</h3>

$(GRAMMAR
$(GNAME OrExpression):
	$(GLINK XorExpression)
	$(I OrExpression) $(B |) $(GLINK XorExpression)
)

	The operands are OR'd together.

<h3>Xor Expressions</h3>

$(GRAMMAR
$(GNAME XorExpression):
	$(GLINK AndExpression)
	$(I XorExpression) $(B ^) $(GLINK AndExpression)
)

	The operands are XOR'd together.

<h3>And Expressions</h3>

$(GRAMMAR
$(GNAME AndExpression):
	$(GLINK CmpExpression)
	$(I AndExpression) $(B &) $(GLINK CmpExpression)
)

	The operands are AND'd together.


<h2><a name="CmpExpression">Compare Expressions</a></h2>

$(GRAMMAR
$(GNAME CmpExpression):
	$(GLINK EqualExpression)
	$(GLINK IdentityExpression)
	$(GLINK RelExpression)
	$(GLINK InExpression)
)

<h2><a name="EqualExpression">Equality Expressions</a></h2>

$(GRAMMAR
$(GNAME EqualExpression):
	$(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B ==) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !=) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B is) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !is) $(GLINK ShiftExpression)
)

	Equality expressions compare the two operands for equality ($(B ==))
	or inequality ($(B !=)).
	The type of the result is bool. The operands
	go through the usual conversions to bring them to a common type before
	comparison.
	<p>

	If they are integral values or pointers, equality
	is defined as the bit pattern of the type matches exactly.
	Equality for struct objects means the bit patterns of the objects
	match exactly (the existence of alignment holes in the objects
	is accounted for, usually by setting them all to 0 upon
	initialization).
	Equality for floating point types is more complicated. -0 and
	+0 compare as equal. If either or both operands are NAN, then
	both the == returns false and != returns true. Otherwise, the bit
	patterns are compared for equality.
	<p>

	For complex numbers, equality is defined as equivalent to:

<pre>
x.re == y.re && x.im == y.im
</pre>

	and inequality is defined as equivalent to:

<pre>
x.re != y.re || x.im != y.im
</pre>

	For class and struct objects, the expression $(TT (a == b))
	is rewritten as
	$(TT a.opEquals(b)), and $(TT (a != b)) is rewritten as
	$(TT !a.opEquals(b)).
	<p>

	For static and dynamic arrays, equality is defined as the
	lengths of the arrays
	matching, and all the elements are equal.
	

<h2><a name="IdentityExpression">Identity Expressions</a></h2>

$(GRAMMAR
$(GNAME IdentityExpression):
	$(GLINK ShiftExpression) $(B is) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !is) $(GLINK ShiftExpression)
)

	The $(B is) compares for identity.
	To compare for not identity, use $(TT $(I e1) $(B !is) $(I e2)).
	The type of the result is bool. The operands
	go through the usual conversions to bring them to a common type before
	comparison.
	<p>

	For operand types other than class objects, static or dynamic arrays,
	identity is defined as being the same as equality.
	<p>

	For class objects, identity is defined as the object references
	are for the same object. Null class objects can be compared with
	$(B is).
	<p>

	For static and dynamic arrays, identity is defined as referring
	to the same array elements.
	<p>

	The identity operator $(B is) cannot be overloaded.

<h2>Relational Expressions</h2>

$(GRAMMAR
$(GNAME RelExpression):
	$(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B &lt;) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B &lt;=) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B &gt;) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B &gt;=) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !&lt;&gt;=) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !&lt;&gt;) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B &lt;&gt;) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B &lt;&gt;=) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !&gt;) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !&gt;=) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !&lt;) $(GLINK ShiftExpression)
	$(GLINK ShiftExpression) $(B !&lt;=) $(GLINK ShiftExpression)
)

	First, the integral promotions are done on the operands.
	The result type of a relational expression is bool.
	<p>

	For class objects, the result of Object.opCmp() forms the left
	operand, and 0 forms the right operand. The result of the
	relational expression (o1 op o2) is:

<pre>
(o1.opCmp(o2) op 0)
</pre>

	It is an error to compare objects if one is $(B null).
	<p>

	For static and dynamic arrays, the result of the relational
	op is the result of the operator applied to the first non-equal
	element of the array. If two arrays compare equal, but are of
	different lengths, the shorter array compares as "less" than the
	longer array.


<h3>Integer comparisons</h3>

	Integer comparisons happen when both operands are integral
	types.
	<p>

	$(TABLE1
	<caption>Integer comparison operators</caption>
	<tr>
	<th>Operator</th><th>Relation</th>
	</tr><tr>
	<td>&lt;</td>		<td>less</td>
	</tr><tr>
	<td>&gt;</td>		<td>greater</td>
	</tr><tr>
	<td>&lt;=</td>		<td>less or equal</td>
	</tr><tr>
	<td>&gt;=</td>		<td>greater or equal</td>
	</tr><tr>
	<td>==</td>		<td>equal</td>
	</tr><tr>
	<td>!=</td>		<td>not equal</td>
	</tr>
	)

	$(P It is an error to have one operand be signed and the other
	unsigned for a &lt;, &lt;=, &gt; or &gt;= expression.
	Use casts to make both operands signed or both operands unsigned.
	)

<h3><a name="floating_point_comparisons">Floating point comparisons</a></h3>

	If one or both operands are floating point, then a floating
	point comparison is performed.
	<p>

	Useful floating point operations must take into account NAN values.
	In particular, a relational operator can have NAN operands.
	The result of a relational operation on float 
	values is less, greater, equal, or unordered (unordered means
	either or both of the 
	operands is a NAN). That means there are 14 possible comparison
	conditions to test for:
	<p>

	$(TABLE1
	<caption>Floating point comparison operators</caption>
	<tr>
	<th>Operator
	<th>Greater Than
	<th>Less Than
	<th>Equal
	<th>Unordered
	<th>Exception
	<th>Relation

	<tr>
	<td> ==		<td> F <td> F <td> T <td> F <td> no	<td> equal

	<tr>
	<td> !=		<td> T <td> T <td> F <td> T <td> no	<td> unordered, less, or greater

	<tr>
	<td> &gt;	<td> T <td> F <td> F <td> F <td> yes	<td> greater

	<tr>
	<td> &gt;=	<td> T <td> F <td> T <td> F <td> yes	<td> greater or equal

	<tr>
	<td> &lt;	<td> F <td> T <td> F <td> F <td> yes	<td> less

	<tr>
	<td> &lt;=	<td> F <td> T <td> T <td> F <td> yes	<td> less or equal

	<tr>
	<td> !&lt;&gt;=	<td> F <td> F <td> F <td> T <td> no	<td> unordered

	<tr>
	<td> &lt;&gt;	<td> T <td> T <td> F <td> F <td> yes	<td> less or greater

	<tr>
	<td> &lt;&gt;=	<td> T <td> T <td> T <td> F <td> yes	<td> less, equal, or greater

	<tr>
	<td> !&lt;=	<td> T <td> F <td> F <td> T <td> no	<td> unordered or greater

	<tr>
	<td> !&lt;	<td> T <td> F <td> T <td> T <td> no	<td> unordered, greater, or equal

	<tr>
	<td> !&gt;=	<td> F <td> T <td> F <td> T <td> no	<td> unordered or less

	<tr>
	<td> !&gt;	<td> F <td> T <td> T <td> T <td> no	<td> unordered, less, or equal

	<tr>
	<td> !&lt;&gt;	<td> F <td> F <td> T <td> T <td> no	<td> unordered or equal

	)

	<h4>Notes:</h4>

	$(OL
	$(LI For floating point comparison operators, (a !op b) is not the same
	as !(a op b).)
	$(LI "Unordered" means one or both of the operands is a NAN.)
	$(LI "Exception" means the $(I Invalid Exception) is raised if one
		of the operands is a NAN. It does not mean an exception
		is thrown. The $(I Invalid Exception) can be checked
		using the functions in $(LINK2 phobos/std_c_fenv.html, std.c.fenv).
	)
	)

<h2><a name="InExpression">In Expressions</a></h2>

$(GRAMMAR
$(I InExpression):
	$(GLINK ShiftExpression) $(B in) $(GLINK ShiftExpression)
)

	An associative array can be tested to see if an element is in the array:

-------------
int foo[char[]];
...
if ("hello" in foo)
	...
-------------

	The $(B in) expression has the same precedence as the
	relational expressions $(B &lt;), $(B &lt;=), 
	etc.
	The return value of the $(I InExpression) is $(B null)
	if the element is not in the array;
	if it is in the array it is a pointer to the element.

<h2>Shift Expressions</h2>

$(GRAMMAR
$(GNAME ShiftExpression):
	$(GLINK AddExpression)
	$(I ShiftExpression) $(B &lt;&lt;) $(GLINK AddExpression)
	$(I ShiftExpression) $(B &gt;&gt;) $(GLINK AddExpression)
	$(I ShiftExpression) $(B &gt;&gt;&gt;) $(GLINK AddExpression)
)

	The operands must be integral types, and undergo the usual integral
	promotions. The result type is the type of the left operand after
	the promotions. The result value is the result of shifting the bits
	by the right operand's value.
	<p>

	$(B &lt;&lt;) is a left shift.
	$(B &gt;&gt;) is a signed right shift.
	$(B &gt;&gt;&gt;) is an unsigned right shift.
	<p>

	It's illegal to shift by more bits than the size of the
	quantity being shifted:

-------------
int c;
c << 33;	// error
-------------

<h2>Add Expressions</h2>

$(GRAMMAR
$(GNAME AddExpression):
	$(GLINK MulExpression)
	$(I AddExpression) $(B +) $(GLINK MulExpression)
	$(I AddExpression) $(B -) $(GLINK MulExpression)
	$(GLINK CatExpression)
)

	$(P If the operands are of integral types, they undergo integral
	promotions, and then are brought to a common type using the
	usual arithmetic conversions.
	)

	$(P If either operand is a floating point type, the other is implicitly
	converted to floating point and they are brought to a common type
	via the usual arithmetic conversions.
	)

	$(P If the operator is $(B +) or $(B -), and
	the first operand is a pointer, and the second is an integral type,
	the resulting type is the type of the first operand, and the resulting
	value is the pointer plus (or minus) the second operand multiplied by
	the size of the type pointed to by the first operand.
	)

	$(P If the second operand is a pointer, and the first is an integral type,
	and the operator is $(B +),
	the operands are reversed and the pointer arithmetic just described
	is applied.
	)

	$(P Add expressions for floating point operands are not associative.
	)

<h2>Cat Expressions</h2>

$(GRAMMAR
$(GNAME CatExpression):
	$(I AddExpression) $(B ~) $(GLINK MulExpression)
)

	$(P A $(I CatExpression) concatenates arrays, producing
	a dynmaic array with the result. The arrays must be
	arrays of the same element type. If one operand is an array
	and the other is of that array's element type, that element
	is converted to an array of length 1 of that element,
	and then the concatenation is performed.
	)

<h2>Mul Expressions</h2>

$(GRAMMAR
$(GNAME MulExpression):
	$(GLINK UnaryExpression)
	$(I MulExpression) $(B *) $(GLINK UnaryExpression)
	$(I MulExpression) $(B /) $(GLINK UnaryExpression)
	$(I MulExpression) $(B %) $(GLINK UnaryExpression)
)

	$(P The operands must be arithmetic types. They undergo integral
	promotions, and then are brought to a common type using the
	usual arithmetic conversions.
	)

	$(P For integral operands, the $(B *), $(B /), and $(B %)
	correspond to multiply, divide, and modulus operations.
	For multiply, overflows are ignored and simply chopped to fit
	into the integral type. If the right operand of divide or modulus
	operators is 0, an Exception is thrown.
	)

	$(P For integral operands of the $(B %) operator, the sign of the
	result is positive if the operands are positive, otherwise the
	sign of the result is implementation defined.
	)

	$(P For floating point operands, the operations correspond to the
	IEEE 754 floating point equivalents.
	)

	$(P Mul expressions for floating point operands are not associative.
	)

<h2><a name="UnaryExpression">Unary Expressions</a></h2>

$(GRAMMAR
$(I UnaryExpression):
	$(GLINK PostfixExpression)
	$(B &amp;) $(I UnaryExpression)
	$(B ++) $(I UnaryExpression)
	$(B --) $(I UnaryExpression)
	$(B *) $(I UnaryExpression)
	$(B -) $(I UnaryExpression)
	$(B +) $(I UnaryExpression)
	$(B !) $(I UnaryExpression)
	$(B ~) $(I UnaryExpression)
	$(B $(LPAREN)) $(I Type) $(B $(RPAREN) .) $(I Identifier)
	$(GLINK NewExpression)
	$(GLINK DeleteExpression)
	$(GLINK CastExpression)
	$(LINK2 class.html#anonymous, $(I NewAnonClassExpression))
)


<h3>New Expressions</h3>

$(GRAMMAR
$(GNAME NewExpression):
	$(I NewArguments) $(I Type) $(B [) $(I AssignExpression) $(B ])
	$(I NewArguments) $(I Type) $(B $(LPAREN)) $(GLINK ArgumentList) $(B $(RPAREN))
	$(I NewArguments) $(I Type)
	$(I NewArguments) $(I ClassArguments) $(I BaseClasslist)<sub>opt</sub> $(B {) $(I DeclDefs) $(B } )

$(GNAME NewArguments):
	$(B new $(LPAREN)) $(GLINK ArgumentList) $(B $(RPAREN))
	$(B new ( ))
	$(B new)

$(GNAME ClassArguments):
	$(B class $(LPAREN)) $(GLINK ArgumentList) $(B $(RPAREN))
	$(B class ( ))
	$(B class)

$(GNAME ArgumentList):
	$(I AssignExpression)
	$(I AssignExpression) $(B ,) $(I ArgumentList)
)

	$(P $(I NewExpression)s are used to allocate memory on the garbage
	collected heap (default) or using a class or struct specific allocator.
	)

	$(P To allocate multidimensional arrays, the declaration reads
	in the same order as the prefix array declaration order.
	)

-------------
char[][] foo;	// dynamic array of strings
...
foo = new char[][30];	// allocate array of 30 strings
-------------

	$(P The above allocation can also be written as:)

-------------
foo = new char[][](30);	// allocate array of 30 strings
-------------

	$(P To allocate the nested arrays, multiple arguments can be used:)

---------------
int[][][] bar;
...
bar = new int[][][](5,20,30);
---------------

	$(P Which is equivalent to:)

----------
bar = new int[][][5];
foreach (ref a; bar)
{
    a = new int[][20];
    foreach (ref b; a)
    {
	b = new int[30];
    }
}
-----------

	$(P If there is a $(B new $(LPAREN)) $(I ArgumentList) $(B $(RPAREN)),
	then
	those arguments are passed to the class or struct specific allocator
	function after the size argument.
	)

	$(P If a $(I NewExpression) is used as an initializer for
	a function local variable with $(B scope) storage class,
	and the $(I ArgumentList) to $(B new) is empty, then
	the instance is allocated on the stack rather than the heap
	or using the class specific allocator.
	)

<h3>Delete Expressions</h3>

$(GRAMMAR
$(GNAME DeleteExpression):
	$(B delete) $(GLINK UnaryExpression)
)
	$(P If the $(I UnaryExpression) is a class object reference, and
	there is a destructor for that class, the destructor
	is called for that object instance.
	)

	$(P Next, if the $(I UnaryExpression) is a class object reference, or
	a pointer to a struct instance, and the class or struct
	has overloaded operator delete, then that operator delete is called
	for that class object instance or struct instance.
	)

	$(P Otherwise, the garbage collector is called to immediately free the
	memory allocated for the class instance or struct instance.
	If the garbage collector was not used to allocate the memory for
	the instance, undefined behavior will result.
	)

	$(P If the $(I UnaryExpression) is a pointer or a dynamic array,
	the garbage collector is called to immediately release the
	memory.
	If the garbage collector was not used to allocate the memory for
	the instance, undefined behavior will result.
	)

	$(P The pointer, dynamic array, or reference is set to $(B null)
	after the delete is performed.
	)

	$(P If $(I UnaryExpression) is a variable allocated
	on the stack, the class destructor (if any) is called for that
	instance. Neither the garbage collector nor any class deallocator
	is called.
	)

<h3>Cast Expressions</h3>

$(GRAMMAR
$(GNAME CastExpression):
	$(B cast $(LPAREN)) $(I Type) $(B $(RPAREN)) $(GLINK UnaryExpression)
)

	$(P A $(I CastExpression) converts the $(I UnaryExpression)
	to $(I Type).
	)

-------------
$(B cast)(foo) -p;	// cast (-p) to type foo
(foo) - p;	// subtract p from foo
-------------

	$(P Any casting of a class reference to a 
	derived class reference is done with a runtime check to make sure it
	really is a downcast. $(B null) is the result if it isn't.
	$(B Note:) This is equivalent to the behavior of the
	dynamic_cast operator in C++.
	)

-------------
class A { ... }
class B : A { ... }

void test(A a, B b)
{
     B bx = a;		// error, need cast
     B bx = cast(B) a;	// bx is null if a is not a B
     A ax = b;		// no cast needed
     A ax = cast(A) b;	// no runtime check needed for upcast
}
-------------

	$(P In order to determine if an object $(TT o) is an instance of
	a class $(TT B) use a cast:
	)

-------------
if ($(B cast)(B) o)
{
    // o is an instance of B
}
else
{
    // o is not an instance of B
}
-------------

	$(P Casting a floating point literal from one type to another
	changes its type, but internally it is retained at full
	precision for the purposes of constant folding.
	)

---
void test()
{
    real a = 3.40483L;
    real b;
    b = 3.40483;         // literal is not truncated to double precision
    assert(a == b);
    assert(a == 3.40483);
    assert(a == 3.40483L);
    assert(a == 3.40483F);
    double d = 3.40483;	// truncate literal when assigned to variable
    assert(d != a);     // so it is no longer the same
    const double x = 3.40483; // assignment to const is not
    assert(x == a);           // truncated if the initializer is visible
}
---

	$(P Casting a value $(I v) to a struct $(I S), when value is not a struct
	of the same type, is equivalent to:
	)

---
S(v)
---

<h2>Postfix Expressions</h2>

$(GRAMMAR
$(GNAME PostfixExpression):
	$(GLINK PrimaryExpression)
	$(I PostfixExpression) $(B .) $(I Identifier)
	$(I PostfixExpression) $(B .) $(GLINK NewExpression)
	$(I PostfixExpression) $(B ++)
	$(I PostfixExpression) $(B --)
	$(I PostfixExpression) $(B ( ))
	$(I PostfixExpression) $(B $(LPAREN)) $(I ArgumentList) $(B $(RPAREN))
	$(GLINK IndexExpression)
	$(GLINK SliceExpression)
)

<h2>Index Expressions</h2>

$(GRAMMAR
$(GNAME IndexExpression):
	$(GLINK PostfixExpression) $(B [) $(I ArgumentList) $(B ])
)

	$(P $(I PostfixExpression) is evaluated.

	If $(I PostfixExpression) is an expression of type
	static array or dynamic array, the symbol $(DOLLAR) is
	set to be the the number of elements in the array.

	If $(I PostfixExpression) is an $(I ExpressionTuple),
	the symbol $(DOLLAR) is
	set to be the the number of elements in the tuple.

	A new declaration scope is created for the evaluation of the
	$(I ArgumentList) and $(DOLLAR) appears in that scope only.
	)

	$(P If $(I PostfixExpression) is an $(I ExpressionTuple),
	then the $(I ArgumentList) must consist of only one argument,
	and that must be statically evaluatable to an integral constant.
	That integral constant $(I n) then selects the $(I n)th
	expression in the $(I ExpressionTuple), which is the result
	of the $(I IndexExpression).
	It is an error if $(I n) is out of bounds of the $(I ExpressionTuple).
	)

<h2>Slice Expressions</h2>

$(GRAMMAR
$(GNAME SliceExpression):
	$(GLINK PostfixExpression) $(B [ ])
	$(GLINK PostfixExpression) $(B [) $(I AssignExpression) $(B ..) $(I AssignExpression) $(B ])
)

	$(P $(I PostfixExpression) is evaluated.
	if $(I PostfixExpression) is an expression of type
	static array or dynamic array, the variable $(B length)
	(and the special variable $(DOLLAR))
	is declared and set to be the length of the array.
	A new declaration scope is created for the evaluation of the
	$(I AssignExpression)..$(I AssignExpression)
	and $(B length) (and $(DOLLAR)) appears in that scope only.
	)

	$(P The first $(I AssignExpression) is taken to be the inclusive
	lower bound
	of the slice, and the second $(I AssignExpression) is the
	exclusive upper bound.
	The result of the expression is a slice of the $(I PostfixExpression)
	array.
	)

	$(P If the $(B [ ]) form is used, the slice is of the entire
	array.
	)

	$(P The type of the slice is a dynamic array of the element
	type of the $(I PostfixExpression).
	)

	$(P If $(I PostfixExpression) is an $(I ExpressionTuple), then
	the result of the slice is a new $(I ExpressionTuple) formed
	from the upper and lower bounds, which must statically evaluate
	to integral constants.
	It is an error if those
	bounds are out of range.
	)

<h2>Primary Expressions</h2>

$(GRAMMAR
$(GNAME PrimaryExpression):
	$(I Identifier)
	$(B .)$(I Identifier)
	$(B this)
	$(B super)
	$(B null)
	$(B true)
	$(B false)
	$(B $)
	$(I NumericLiteral)
	$(GLINK CharacterLiteral)
	$(GLINK StringLiterals)
	$(GLINK ArrayLiteral)
	$(GLINK AssocArrayLiteral)
	$(GLINK FunctionLiteral)
	$(GLINK AssertExpression)
	$(GLINK MixinExpression)
	$(GLINK ImportExpression)
	$(I BasicType) $(B .) $(I Identifier)
	$(B typeid $(LPAREN)) $(I Type) $(B $(RPAREN))
	$(GLINK IsExpression)
	$(B $(LPAREN)) $(I Expression) $(B $(RPAREN))
$(V2
	$(I TraitsExpression))
)

<h3>.Identifier</h3>

	$(I Identifier) is looked up at module scope, rather than the current
	lexically nested scope.

<h3>this</h3>

	$(P Within a non-static member function, $(B this) resolves to
	a reference to the object for which the function was called.
	If the object is an instance of a struct, $(B this) will
	be a pointer to that instance.
	If a member function is called with an explicit reference
	to $(B typeof(this)), a non-virtual call is made:
	)

-------------
class A
{
    char get() { return 'A'; }

    char foo() { return $(B typeof(this)).get(); }
    char bar() { return $(B this).get(); }
}

class B : A
{
    char get() { return 'B'; }
}

void main()
{
    B b = new B();

    b.foo();		// returns 'A'
    b.bar();		// returns 'B'
}
-------------


<h3>super</h3>

	$(P $(B super) is identical to $(B this), except that it is
	cast to $(B this)'s base class.
	It is an error if there is no base class.
	It is an error to use $(B super) within a struct member function.
	(Only class $(TT Object) has no base class.)
	$(B super) is not allowed in struct member
	functions.
	If a member function is called with an explicit reference
	to $(B super), a non-virtual call is made.
	)

<h3>null</h3>

	$(P $(B null) represents the null value for
	pointers, pointers to functions, delegates,
	dynamic arrays, associative arrays,
	and class objects.
	If it has not already been cast to a type,
	it is given the type (void *) and it is an exact conversion
	to convert it to the null value for pointers, pointers to
	functions, delegates, etc.
	After it is cast to a type, such conversions are implicit,
	but no longer exact.
	)

<h3>true, false</h3>

	These are of type $(B bool) and when cast to another integral
	type become the values 1 and 0,
	respectively.

<h3><a name="CharacterLiteral">Character Literals</a></h3>

	Character literals are single characters and resolve to one
	of type $(B char), $(B wchar), or $(B dchar).
	If the literal is a \u escape sequence, it resolves to type $(B wchar).
	If the literal is a \U escape sequence, it resolves to type $(B dchar).
	Otherwise, it resolves to the type with the smallest size it
	will fit into.

<h3>String Literals</h3>

$(GRAMMAR
$(GNAME StringLiterals):
	$(LINK2 lex.html#StringLiteral, $(I StringLiteral))
	$(I StringLiterals) $(LINK2 lex.html#StringLiteral, $(I StringLiteral))
)

<h3>Array Literals</h3>

$(GRAMMAR
$(GNAME ArrayLiteral):
	$(B [) $(GLINK ArgumentList) $(B ])
)

	$(P Array literals are a comma-separated list of $(I AssignExpression)s
	between square brackets [ and ].
	The $(I AssignExpression)s form the elements of a static array,
	the length of the array is the number of elements.
	The type of the first element is taken to be the type of
	all the elements, and all elements are implicitly converted
	to that type.
	If that type is a static array, it is converted to a dynamic
	array.
	)

---
[1,2,3];	// type is int[3], with elements 1, 2 and 3
[1u,2,3];	// type is uint[3], with elements 1u, 2u, and 3u
---

	$(P If any of the arguments in the $(I ArgumentList) are
	an $(I ExpressionTuple), then the elements of the $(I ExpressionTuple)
	are inserted as arguments in place of the tuple.
	)

<h3>Associative Array Literals</h3>

$(GRAMMAR
$(GNAME AssocArrayLiteral):
	$(B [) $(I KeyValuePairs) $(B ])

$(I KeyValuePairs):
	$(I KeyValuePair)
	$(I KeyValuePair) $(B ,) $(I KeyValuePairs)

$(I KeyValuePair):
	$(I KeyExpression) $(B :) $(I ValueExpression)

$(I KeyExpression):
	$(GLINK ConditionalExpression)

$(I ValueExpression):
	$(GLINK ConditionalExpression)
)

	$(P Associative array literals are a comma-separated list of
	$(I key):$(I value) pairs
	between square brackets [ and ].
	The list cannot be empty.
	The type of the first key is taken to be the type of
	all the keys, and all subsequent keys are implicitly converted
	to that type.
	The type of the first value is taken to be the type of
	all the values, and all subsequent values are implicitly converted
	to that type.
	An $(I AssocArrayLiteral) cannot be used to statically initialize
	anything.
	)

---
[21u:"he",38:"ho",2:"hi"]; // type is char[2][uint], with keys 21u, 38u and 2u
                           // and values "he", "ho", and "hi"
---

	$(P If any of the keys or values in the $(I KeyValuePairs) are
	an $(I ExpressionTuple), then the elements of the $(I ExpressionTuple)
	are inserted as arguments in place of the tuple.
	)

<h3>Function Literals</h3>

$(GRAMMAR
$(GNAME FunctionLiteral)
	$(B function) $(I Type)<sub>opt</sub> $(B $(LPAREN)) $(I ParameterList) $(B $(RPAREN))<sub>opt</sub> $(I FunctionBody)
	$(B delegate) $(I Type)<sub>opt</sub> $(B $(LPAREN)) $(I ParameterList) $(B $(RPAREN))<sub>opt</sub> $(I FunctionBody)
	$(B $(LPAREN)) $(I ParameterList) $(B $(RPAREN)) $(I FunctionBody)
	$(I FunctionBody)
)

	$(I FunctionLiteral)s enable embedding anonymous functions
	and anonymous delegates directly into expressions.
	$(I Type) is the return type of the function or delegate,
	if omitted it is inferred from any $(I ReturnStatement)s
	in the $(I FunctionBody).
	$(B $(LPAREN)) $(I ArgumentList) $(B $(RPAREN))
	forms the arguments to the function.
	If omitted it defaults to the empty argument list $(B ()).
	The type of a function literal is pointer to function or
	pointer to delegate.
	If the keywords $(B function) or $(B delegate) are omitted,
	it defaults to being a delegate.
	<p>

	For example:

-------------
int function(char c) fp;	// declare pointer to a function

void test()
{
    static int foo(char c) { return 6; }

    fp = &foo;
}
-------------

	is exactly equivalent to:

-------------
int function(char c) fp;

void test()
{
    fp = $(B function int(char c) { return 6;}) ;
}
-------------

	And:

-------------
int abc(int delegate(long i));

void test()
{   int b = 3;
    int foo(long c) { return 6 + b; }

    abc(&foo);
}
-------------

	is exactly equivalent to:

-------------
int abc(int delegate(long i));

void test()
{   int b = 3;

    abc( $(B delegate int(long c) { return 6 + b; }) );
}
-------------

	$(P and the following where the return type $(B int) is
	inferred:)

-------------
int abc(int delegate(long i));

void test()
{   int b = 3;

    abc( $(B (long c) { return 6 + b; }) );
}
-------------

	Anonymous delegates can behave like arbitrary statement literals.
	For example, here an arbitrary statement is executed by a loop:

-------------
double test()
{   double d = 7.6;
    float f = 2.3;

    void loop(int k, int j, void delegate() statement)
    {
	for (int i = k; i < j; i++)
	{
	    statement();
	}
    }

    loop(5, 100, $(B { d += 1; }) );
    loop(3, 10,  $(B { f += 3; }) );

    return d + f;
}
-------------

	When comparing with <a href="function.html#nested">nested
	functions</a>, the $(B function) form is analogous to static
	or non-nested functions, and the $(B delegate) form is
	analogous to non-static nested functions. In other words,
	a delegate literal can access stack variables in its enclosing
	function, a function literal cannot.


<h3>Assert Expressions</h3>

$(GRAMMAR
$(GNAME AssertExpression):
	$(B assert $(LPAREN)) $(I AssignExpression) $(B $(RPAREN))
	$(B assert $(LPAREN)) $(I AssignExpression) $(B ,) $(I AssignExpression) $(B $(RPAREN))
)

	$(P Asserts evaluate the $(I expression). If the result is false,
	an $(B AssertError) is thrown. If the result is true, then no
	exception is thrown.
	It is an error if the $(I expression) contains any side effects
	that the program depends on. The compiler may optionally not
	evaluate assert expressions at all.
	The result type of an assert expression is $(TT void).
	Asserts are a fundamental part of the
	<a href="dbc.html">Contract Programming</a>
	support in D.
	)

	$(P The expression $(TT assert(0)) is a special case; it
	signifies that it is unreachable code.
	Either $(B AssertError) is thrown at runtime if it is reachable,
	or the execution is halted
	(on the x86 processor, a $(B HLT) instruction can be used to halt
	execution).
	The optimization and code generation phases of compilation may
	assume that it is unreachable code.
	)

	$(P The second $(I Expression), if present, must be implicitly
	convertible to type $(TT char[]). It is evaluated if the
	result is false, and the string result is appended to the
	$(B AssertError)'s message.
	)

----
void main()
{
    assert(0, "an" ~ " error message");
}
----

	$(P When compiled and run, it will produce the message:)

$(CONSOLE
Error: AssertError Failure test.d(3) an error message
)


<h3><a name="MixinExpression">Mixin Expressions</a></h3>

$(GRAMMAR
$(I MixinExpression):
	$(B mixin $(LPAREN)) $(GLINK AssignExpression) $(B $(RPAREN))
)

	$(P The $(I AssignExpression) must evaluate at compile time
	to a constant string.
	The text contents of the string must be compilable as a valid
	$(I AssignExpression), and is compiled as such.
	)

---
int foo(int x)
{
    return mixin("x + 1") * 7;  // same as ((x + 1) * 7)
}
---

<h3><a name="ImportExpression">Import Expressions</a></h3>

$(GRAMMAR
$(I ImportExpression):
	$(B import $(LPAREN)) $(GLINK AssignExpression) $(B $(RPAREN))
)

	$(P The $(I AssignExpression) must evaluate at compile time
	to a constant string.
	The text contents of the string are interpreted as a file
	name. The file is read, and the exact contents of the file
	become a string literal.
	)

---
void foo()
{
    // Prints contents of file foo.txt
    writefln( import("foo.txt") );
}
---

<h3><a name="typeidexpression">Typeid Expressions</a></h3>

$(GRAMMAR
$(I TypeidExpression):
    $(B typeid $(LPAREN)) $(I Type) $(B $(RPAREN))
)

	Returns an instance of class
	$(LINK2 phobos/object.html, $(B TypeInfo))
	corresponding
	to $(I Type).

<h3><a name="IsExpression">IsExpression</a></h3>

$(GRAMMAR
$(I IsExpression):
	$(B is $(LPAREN)) $(I Type) $(B $(RPAREN))
	$(B is $(LPAREN)) $(I Type) $(B :) $(I TypeSpecialization) $(B $(RPAREN))
	$(B is $(LPAREN)) $(I Type) $(B ==) $(I TypeSpecialization) $(B $(RPAREN))
	$(B is $(LPAREN)) $(I Type) $(I Identifier) $(B $(RPAREN))
	$(B is $(LPAREN)) $(I Type) $(I Identifier) $(B :) $(I TypeSpecialization) $(B $(RPAREN))
	$(B is $(LPAREN)) $(I Type) $(I Identifier) $(B ==) $(I TypeSpecialization) $(B $(RPAREN))
	$(V2 $(B is $(LPAREN)) $(I Type) $(I Identifier) $(B :) $(I TypeSpecialization) $(B ,) $(I TemplateParameterList) $(B $(RPAREN))
	$(B is $(LPAREN)) $(I Type) $(I Identifier) $(B ==) $(I TypeSpecialization) $(B ,) $(I TemplateParameterList) $(B $(RPAREN))
)

$(I TypeSpecialization):
	$(I Type)
	$(B typedef)
	$(B struct)
	$(B union)
	$(B class)
	$(B interface)
	$(B enum)
	$(B function)
	$(B delegate)
	$(B super)
$(V2
	$(B const)
	$(B interface)
))

	$(I IsExpression)s are evaluated at compile time and are
	used for checking for valid types, comparing types for equivalence,
	determining if one type can be implicitly converted to another,
	and deducing the subtypes of a type.
	The result of an $(I IsExpression) is an int of type 0
	if the condition is not satisified, 1 if it is.
	<p>

	$(I Type) is the type being tested. It must be syntactically
	correct, but it need not be semantically correct.
	If it is not semantically correct, the condition is not satisfied.
	<p>

	$(I Identifier) is declared to be an alias of the resulting
	type if the condition is satisfied. The $(I Identifier) forms
	can only be used if the $(I IsExpression) appears in a
	<a href="version.html#staticif">$(I StaticIfCondition)</a>.
	<p>

	$(I TypeSpecialization) is the type that $(I Type) is being
	compared against.
	<p>

	The forms of the $(I IsExpression) are:

	$(OL

	$(LI $(B is $(LPAREN)) $(I Type) $(B $(RPAREN))$(BR)
	The condition is satisfied if $(I Type) is semantically
	correct (it must be syntactically correct regardless).

-------------
alias int func(int);	// func is a alias to a function type
void foo()
{
    if ( $(B is)(func[]) )	// not satisfied because arrays of
			// functions are not allowed
	writefln("satisfied");
    else
	writefln("not satisfied");

    if ($(B is)([][]))	// error, [][] is not a syntactically valid type
	...
}
-------------
	)

	$(LI $(B is $(LPAREN)) $(I Type) $(B :) $(I TypeSpecialization) $(B $(RPAREN))<br>
	The condition is satisfied if $(I Type) is semantically
	correct and it is the same as
	or can be implicitly converted to $(I TypeSpecialization).
	$(I TypeSpecialization) is only allowed to be a $(I Type).

-------------
alias short bar;
void foo(bar x)
{
    if ( $(B is)(bar : int) )	// satisfied because short can be
				// implicitly converted to int
	writefln("satisfied");
    else
	writefln("not satisfied");
}
-------------
	)

	$(LI $(B is $(LPAREN)) $(I Type) $(B ==) $(I TypeSpecialization) $(B $(RPAREN))<br>
	The condition is satisfied if $(I Type) is semantically
	correct and is the same type as $(I TypeSpecialization).
	<p>

	If $(I TypeSpecialization) is one of
		$(B typedef)
		$(B struct)
		$(B union)
		$(B class)
		$(B interface)
		$(B enum)
		$(B function)
		$(B delegate)
$(V2		$(B const)
		$(B invariant)
)
	then the condition is satisifed if $(I Type) is one of those.

-------------
alias short bar;
typedef char foo;
void test(bar x)
{
    if ( $(B is)(bar == int) )	// not satisfied because short is not
				// the same type as int
	writefln("satisfied");
    else
	writefln("not satisfied");

    if ( $(B is)(foo == typedef) ) // satisfied because foo is a typedef
	writefln("satisfied");
    else
	writefln("not satisfied");
}
-------------
	)

	$(LI $(B is $(LPAREN)) $(I Type) $(I Identifier) $(B $(RPAREN))<br>
	The condition is satisfied if $(I Type) is semantically
	correct. If so, $(I Identifier)
	is declared to be an alias of $(I Type).

-------------
alias short bar;
void foo(bar x)
{
    static if ( $(B is)(bar T) )
	alias T S;
    else
	alias long S;
    writefln(typeid(S));   // prints "short"

    if ( $(B is)(bar T) )  // error, $(I Identifier) T form can
		      // only be in $(LINK2 version.html#staticif, $(I StaticIfCondition))s
	...
}
-------------
	)

	$(LI $(B is $(LPAREN)) $(I Type) $(I Identifier) $(B :) $(I TypeSpecialization) $(B $(RPAREN))<br>

	$(P
	The condition is satisfied if $(I Type) is the same as
	$(I TypeSpecialization), or if $(I Type) is a class and
	$(I TypeSpecialization) is a base class or base interface
	of it.
	The $(I Identifier) is declared to be either an alias of the
	$(I TypeSpecialization) or, if $(I TypeSpecialization) is
	dependent on $(I Identifier), the deduced type.
	)

-------------
alias int bar;
alias long* abc;
void foo(bar x, abc a)
{
    static if ( $(B is)(bar T : int) )
	alias T S;
    else
	alias long S;

    writefln(typeid(S));	// prints "int"

    static if ( $(B is)(abc U : U*) )
	U u;

    writefln(typeid(typeof(u)));	// prints "long"
}
-------------

	$(P The way the type of $(I Identifier) is determined is analogous
	to the way template parameter types are determined by
	$(I TemplateTypeParameterSpecialization).
	)
	)

	$(LI $(B is $(LPAREN)) $(I Type) $(I Identifier) $(B ==) $(I TypeSpecialization) $(B $(RPAREN))<br>


	$(P The condition is satisfied if $(I Type) is semantically
	correct and is the same as $(I TypeSpecialization).
	The $(I Identifier) is declared to be either an alias of the
	$(I TypeSpecialization) or, if $(I TypeSpecialization) is
	dependent on $(I Identifier), the deduced type.
	)

	$(P If $(I TypeSpecialization) is one of
		$(B typedef)
		$(B struct)
		$(B union)
		$(B class)
		$(B interface)
		$(B enum)
		$(B function)
		$(B delegate)
$(V2		$(B const)
		$(B invariant)
)
	then the condition is satisifed if $(I Type) is one of those.
	Furthermore, $(I Identifier) is set to be an alias of the type:
	)

	$(TABLE1
	$(TR
	$(TH keyword)
	$(TH alias type for $(I Identifier))
	)
	$(TR
	$(TD $(CODE typedef))
	$(TD the type that $(I Type) is a typedef of)
	)
	$(TR
	$(TD $(CODE struct))
	$(TD $(I Type))
	)
	$(TR
	$(TD $(CODE union))
	$(TD $(I Type))
	)
	$(TR
	$(TD $(CODE class))
	$(TD $(I Type))
	)
	$(TR
	$(TD $(CODE interface))
	$(TD $(I Type))
	)
	$(TR
	$(TD $(CODE super))
	$(TD $(I TypeTuple) of base classes and interfaces)
	)
	$(TR
	$(TD $(CODE enum))
	$(TD the base type of the enum)
	)
	$(TR
	$(TD $(CODE function))
	$(TD $(I TypeTuple) of the function parameter types)
	)
	$(TR
	$(TD $(CODE delegate))
	$(TD the function type of the delegate)
	)
	$(TR
	$(TD $(CODE return))
	$(TD the return type of the function, delegate, or function pointer)
	)
$(V2
	$(TR
	$(TD $(CODE const))
	$(TD $(I Type))
	)
	$(TR
	$(TD $(CODE invariant))
	$(TD $(I Type))
	)
)
	)

-------------
alias short bar;
enum E : byte { Emember }
void foo(bar x)
{
    static if ( $(B is)(bar T == int) ) // not satisfied, short is not int
	alias T S;
    alias T U;			   // error, T is not defined

    static if ( $(B is)(E V == enum) )  // satisified, E is an enum
	V v;			   // v is declared to be a byte
}
-------------
	)

$(V2
	$(LI $(B is $(LPAREN)) $(I Type) $(I Identifier) $(B :) $(I TypeSpecialization) $(B ,) $(I TemplateParameterList) $(B $(RPAREN))$(BR)
	$(B is $(LPAREN)) $(I Type) $(I Identifier) $(B ==) $(I TypeSpecialization) $(B ,) $(I TemplateParameterList) $(B $(RPAREN))

	$(P More complex types can be pattern matched; the
	$(I TemplateParameterList) declares symbols based on the
	parts of the pattern that are matched, analogously to the
	way implied template parameters are matched.
	)

---
import std.stdio;

void main()
{
  alias long[char[]] AA;

  static if (is(AA T : T[U], U : const char[]))
  {
    writefln(typeid(T));	// long
    writefln(typeid(U));	// const char[]
  }

  static if (is(AA A : A[B], B : int))
  {
    assert(0);  // should not match, as B is not an int
  }

  static if (is(int[10] W : W[V], int V))
  {
    writefln(typeid(W));	// int
    writefln(V);		// 10
  }

  static if (is(int[10] X : X[Y], int Y : 5))
  {
    assert(0);	// should not match, Y should be 10
  }
}
---

	)
)
	)


)

Macros:
	TITLE=Expressions
	WIKI=Expression
	GLINK=$(LINK2 #$0, $(I $0))
	GNAME=<a name=$0>$(I $0)</a>
	DOLLAR=$
	FOO=

