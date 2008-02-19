Ddoc

$(SPEC_S Operator Overloading,

	$(P Overloading is accomplished by interpreting specially named
	struct and class member functions as being implementations of unary and
	binary operators. No additional syntax is used.
	)

<h2>Unary Operator Overloading</h2>


	$(TABLE1
	<caption>Overloadable Unary Operators</caption>

	$(TR $(TH$(I op)) $(TH$(I opfunc)) )

	$(TR
	$(TD -$(I e))
	$(TD $(CODE opNeg))
	)

	$(TR
	$(TD +$(I e))
	$(TD $(CODE opPos))
	)

	$(TR
	$(TD ~$(I e))
	$(TD $(CODE opCom))
	)

$(V2
	$(TR
	$(TD *$(I e))
	$(TD $(CODE opStar))
	)
)

	$(TR
	$(TD $(I e)++)
	$(TD $(CODE opPostInc))
	)

	$(TR
	$(TD $(I e)--)
	$(TD $(CODE opPostDec))
	)

	$(TR
	$(TD cast($(I type))$(I e))
	$(TD $(CODE opCast))
	)

	)


	$(P Given a unary
	overloadable operator $(I op) and its corresponding
	class or struct member
	function name $(I opfunc), the syntax:
	)

---
$(I op) a
---

	$(P where $(I a) is a class or struct object reference,
	is interpreted as if it was written as:
	)
---
a.$(I opfunc)()
---

<h3>Overloading ++$(I e) and --$(I e)</h3>

	$(P Since ++$(I e) is defined to be semantically equivalent
	to ($(I e) += 1), the expression ++$(I e) is rewritten
	as ($(I e) += 1), and then checking for operator overloading
	is done. The situation is analogous for --$(I e).
	)

<h3>Examples</h3>

	$(OL 
	$(LI
-------
class A { int $(B opNeg)(); }
A a;
-a;	// equivalent to a.opNeg();
-------
	)
	$(LI
-------
class A { int $(B opNeg)(int i); }
A a;
-a;	// equivalent to a.opNeg(), which is an error
-------
	)
	)

<h3>Overloading cast($(I type))$(I e)</h3>

	$(P The member function $(I e).$(B opCast()) is called,
	and the return value of $(B opCast()) is implicitly converted
	to $(I type). Since functions cannot be overloaded based on
	return value, there can be only one $(B opCast) per struct or
	class.
	Overloading the cast operator does not affect implicit casts, it
	only applies to explicit casts.
	)

-------
struct A
{
    int $(B opCast)() { return 28; }
}

void test()
{
    A a;

    long i = cast(long)a;   // i is set to 28L
    void* p = cast(void*)a; // error, cannot implicitly
			    // convert int to void*
    int j = a;		    // error, cannot implicitly convert
			    // A to int
}
-------

<h2>Binary Operator Overloading</h2>


	$(TABLE1
	<caption>Overloadable Binary Operators</caption>

	$(TR $(TH $(I op))
	$(TH commutative?)
	$(TH $(I opfunc))
	$(TH $(I opfunc_r))
	)

	$(TR $(TD +) $(TD yes) $(TD $(CODE opAdd)) $(TD $(CODE opAdd_r)))

	$(TR $(TD -) $(TD no) $(TD $(CODE opSub)) $(TD $(CODE opSub_r)))

	$(TR $(TD *) $(TD yes) $(TD $(CODE opMul)) $(TD $(CODE opMul_r)))

	$(TR $(TD /) $(TD no) $(TD $(CODE opDiv)) $(TD $(CODE opDiv_r)))

	$(TR $(TD %) $(TD no) $(TD $(CODE opMod)) $(TD $(CODE opMod_r)))

	$(TR $(TD &) $(TD yes) $(TD $(CODE opAnd)) $(TD $(CODE opAnd_r)))

	$(TR $(TD |) $(TD yes) $(TD $(CODE opOr)) $(TD $(CODE opOr_r)))

	$(TR $(TD ^) $(TD yes) $(TD $(CODE opXor)) $(TD $(CODE opXor_r)))

	$(TR $(TD &lt;&lt;) $(TD no) $(TD $(CODE opShl)) $(TD $(CODE opShl_r)))

	$(TR $(TD &gt;&gt;) $(TD no) $(TD $(CODE opShr)) $(TD $(CODE opShr_r)))

	$(TR $(TD &gt;&gt;&gt;) $(TD no) $(TD $(CODE opUShr)) $(TD $(CODE opUShr_r)))

	$(TR $(TD ~) $(TD no) $(TD $(CODE opCat)) $(TD $(CODE opCat_r)))

	$(TR $(TD ==) $(TD yes) $(TD $(CODE opEquals)) $(TD  -))

	$(TR $(TD !=) $(TD yes) $(TD $(CODE opEquals)) $(TD  -))

	$(TR $(TD &lt;) $(TD yes) $(TD $(CODE opCmp)) $(TD  -))

	$(TR $(TD &lt;=) $(TD yes) $(TD $(CODE opCmp)) $(TD  -))

	$(TR $(TD &gt;) $(TD yes) $(TD $(CODE opCmp)) $(TD  -))

	$(TR $(TD &gt;=) $(TD yes) $(TD $(CODE opCmp)) $(TD  -))

	$(TR $(TD =) $(TD no ) $(TD $(CODE opAssign)) $(TD -) )

	$(TR $(TD +=) $(TD no) $(TD $(CODE opAddAssign)) $(TD  -))

	$(TR $(TD -=) $(TD no) $(TD $(CODE opSubAssign)) $(TD  -))

	$(TR $(TD *=) $(TD no) $(TD $(CODE opMulAssign)) $(TD  -))

	$(TR $(TD /=) $(TD no) $(TD $(CODE opDivAssign)) $(TD  -))

	$(TR $(TD %=) $(TD no) $(TD $(CODE opModAssign)) $(TD  -))

	$(TR $(TD &=) $(TD no) $(TD $(CODE opAndAssign)) $(TD  -))

	$(TR $(TD |=) $(TD no) $(TD $(CODE opOrAssign)) $(TD  -))

	$(TR $(TD ^=) $(TD no) $(TD $(CODE opXorAssign)) $(TD  -))

	$(TR $(TD &lt;&lt;=) $(TD no) $(TD $(CODE opShlAssign)) $(TD  -))

	$(TR $(TD &gt;&gt;=) $(TD no) $(TD $(CODE opShrAssign)) $(TD  -))

	$(TR $(TD &gt;&gt;&gt;=) $(TD no) $(TD $(CODE opUShrAssign)) $(TD  -))

	$(TR $(TD ~=) $(TD no) $(TD $(CODE opCatAssign)) $(TD  -))

	$(TR $(TD in ) $(TD no ) $(TD $(CODE opIn) ) $(TD $(CODE opIn_r) ))

	)

	$(P Given a binary
	overloadable operator $(I op) and its corresponding
	class or struct member
	function name $(I opfunc) and $(I opfunc_r),
	and the syntax:
	)

---
a $(I op) b
---

	the following sequence of rules is applied, in order, to determine
	which form is used:

	$(OL 
	$(LI The expression is rewritten as both:
---
a.$(I opfunc)(b)
b.$(I opfunc_r)(a)
---
	If any $(I a.opfunc) or $(I b.opfunc_r) functions exist,
	then overloading is applied
	across all of them and the best match is used. If either exist,
	and there is no argument match, then it is an error.
	)

	$(LI If the operator is commutative, then the following
	forms are tried:
---
a.$(I opfunc_r)(b)
b.$(I opfunc)(a)
---
	)

	$(LI If $(I a) or $(I b) is a struct or class object reference,
	it is an error.
	)
	)

<h4>Examples</h4>

	$(OL 
	$(LI

-------
class A { int $(B opAdd)(int i); }
A a;
a + 1;	// equivalent to a.opAdd(1)
1 + a;	// equivalent to a.opAdd(1)
-------
	)
	$(LI

-------
class B { int $(B opDiv_r)(int i); }
B b;
1 / b;	// equivalent to b.opDiv_r(1)
-------
	)
	$(LI
-------
class A { int $(B opAdd)(int i); }
class B { int $(B opAdd_r)(A a); }
A a;
B b;
a + 1;	// equivalent to a.opAdd(1)
a + b;	// equivalent to b.opAdd_r(a)
b + a;	// equivalent to b.opAdd_r(a)
-------
	)
	$(LI
-------
class A { int $(B opAdd)(B b);  int $(B opAdd_r)(B b); }
class B { }
A a;
B b;
a + b;	// equivalent to a.opAdd(b)
b + a;	// equivalent to a.opAdd_r(b)
-------
	)
	$(LI
-------
class A { int $(B opAdd)(B b);  int $(B opAdd_r)(B b); }
class B { int $(B opAdd_r)(A a); }
A a;
B b;
a + b;	// ambiguous: a.opAdd(b) or b.opAdd_r(a)
b + a;	// equivalent to a.opAdd_r(b)
-------
	)
	)

<h3>Overloading == and !=</h3>

	$(P Both operators use the $(CODE $(B opEquals)()) function.
	The expression
	$(CODE (a == b)) is rewritten as $(CODE a.$(B opEquals)(b)),
	and $(CODE (a != b)) is rewritten as $(CODE !a.$(B opEquals)(b)).
	)

	$(P The member function $(CODE $(B opEquals)()) is defined as part of
	Object as:
	)

-------
int $(B opEquals)(Object o);
-------

	$(P so that every class object has a default $(CODE $(B opEquals)()).
	But every class definition which will be using == or != should
	expect to need to override opEquals. The parameter to the overriding
	function must be of type $(CODE Object), not the type for the class.
	)

	$(P Structs and unions (hereafter just called structs) can
	provide a member function:
	)

-------
int $(B opEquals)(S s)
-------
	$(P or:)
-------
int $(B opEquals)(S* s)
-------

	$(P where $(CODE S) is the struct name, to define how equality is
	determined.)

	$(P If a struct has no $(B opEquals) function declared for it,
	a bit compare of the contents of the two structs is done to
	determine equality or inequality.
	)

	$(P $(B Note:) Comparing a reference to a class object against $(B null)
	should be done as:
	)
-------
if (a is null)
-------
	$(P and not as:)
-------
if (a == null)
-------
	$(P The latter is converted to:)
-------
if (a.$(B opEquals)(null))
-------
	$(P which will fail if $(CODE $(B opEquals)()) is a virtual function.)

<h3>Overloading &lt;, &lt;=, &gt; and &gt;=</h3>

	$(P These comparison operators all use the $(CODE $(B opCmp)()) function.
	The expression
	$(CODE (a $(I op) b)) is rewritten as $(CODE (a.$(B opCmp)(b) $(I op) 0)).
	The commutative operation is rewritten as $(CODE (0 $(I op) b.$(B opCmp)(a)))
	)

	$(P The member function $(CODE $(B opCmp)()) is defined as part of Object
	as:
	)

-------
int $(B opCmp)(Object o);
-------

	$(P so that every class object has a $(CODE $(B opCmp)()).
	)

	$(P If a struct has no $(B opCmp)() function declared for it, attempting
	to compare two structs is an error.
	)

<h4>Rationale</h4>

	$(P The reason for having both $(B opEquals)() and $(B opCmp)() is
	that:)

	$(UL
	$(LI Testing for equality can sometimes be a much more efficient
	operation than testing for less or greater than.)
	$(LI Having an opCmp defined in Object makes it possible to
	make associative arrays work generically for classes.)
	$(LI For some objects, testing for less or greater makes no sense.
	This is why Object.opCmp throws a runtime error.
	opCmp must be overridden in each class for which comparison
	makes sense.)
	)

	$(P The parameter to $(B opEquals) and $(B opCmp)
	for class definitions must
	be of type Object, rather than the type of the particular class,
	in order to override the Object.$(B opEquals) and Object.$(B opCmp)
	functions properly.
	)

<h2>Function Call Operator Overloading $(I f)()</h2>

	$(P The function call operator, (), can be overloaded by
	declaring a function named $(B opCall):
	)

-------
struct F
{
    int $(B opCall)();
    int $(B opCall)(int x, int y, int z);
}

void test()
{   F f;
    int i;

    i = f$(B ());		// same as i = f.opCall();
    i = f$(B (3,4,5));	// same as i = f.opCall(3,4,5);
}
-------

	$(P In this way a struct or class object can behave as if it
	were a function.
	)

<h2>Array Operator Overloading</h2>

<h3>Overloading Indexing $(I a)[$(I i)]</h3>

	$(P The array index operator, [], can be overloaded by
	declaring a function named $(B opIndex) with one
	or more parameters.
	Assignment to an array can be overloaded with a function
	named $(B opIndexAssign) with two or more parameters.
	The first parameter is the rvalue of the assignment expression.
	)

-------
struct A
{
    int $(B opIndex)(size_t i1, size_t i2, size_t i3);
    int $(B opIndexAssign)(int value, size_t i1, size_t i2);
}

void test()
{   A a;
    int i;

    i = a$(B [)5,6,7$(B ]);	// same as i = a.opIndex(5,6,7);
    a$(B [)i,3$(B ]) = 7;		// same as a.opIndexAssign(7,i,3);
}
-------

	$(P In this way a struct or class object can behave as if it
	were an array.
	)

	$(P $(B Note:) Array index overloading currently does not
	work for the lvalue of an $(I op)=, ++, or -- operator.
	)


<h3>Overloading Slicing $(I a)[] and $(I a)[$(I i) .. $(I j)]</h3>

	$(P Overloading the slicing operator means overloading expressions
	like $(CODE a[]) and $(CODE a[i .. j]).
	This can be done by declaring a function named $(B opSlice).
	Assignment to a slice can be done by declaring $(B opSliceAssign).
	)

-------
class A
{
    int $(B opSlice)();		 		  // overloads a[]
    int $(B opSlice)(size_t x, size_t y);		  // overloads a[i .. j]

    int $(B opSliceAssign)(int v);			  // overloads a[] = v
    int $(B opSliceAssign)(int v, size_t x, size_t y); // overloads a[i .. j] = v
}

void test()
{   A a = new A();
    int i;
    int v;

    i = a$(B []);		// same as i = a.opSlice();
    i = a$(B [)3..4$(B ]);	// same as i = a.opSlice(3,4);

    a$(B []) = v;		// same as a.opSliceAssign(v);
    a$(B [)3..4$(B ]) = v;	// same as a.opSliceAssign(v,3,4);
}
-------

<h2>Assignment Operator Overloading</h2>

	$(P The assignment operator $(CODE =) can be overloaded if the
	lvalue is a struct $(V1 or class) aggregate, and $(CODE opAssign)
	is a member function of that aggregate.)

	$(P The assignment operator cannot be overloaded for rvalues
	that can be implicitly cast to the lvalue type.
	Furthermore, the following parameter signatures for $(CODE opAssign)
	are not allowed:)

---
opAssign(...)
opAssign(T)
opAssign(T, ...)
opAssign(T ...)
opAssign(T, U = defaultValue, etc.)
---

	$(P where $(I T) is the same type as the aggregate type $(I A),
	is implicitly
	convertible to $(I A), or if $(I A) is a struct and $(I T)
	is a pointer to a type that is
	implicitly convertible to $(I A).
	)

<h2>Future Directions</h2>

	$(P The operators $(CODE ! . && || ?:) and a few others will
	likely never be overloadable.
	)
)

Macros:
	TITLE=Operator Overloading
	WIKI=OperatorOverloading

