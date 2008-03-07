Ddoc

$(SPEC_S Final$(COMMA) Const$(COMMA) and Invariant,

	$(P
	Being able to specify what parts of variables data can change, and under
	what conditions, can add greatly to the understandability of interfaces,
	being able to analyse code for correctness, and improve code
	generation.
	)

	$(P
	With invariant, const and final, the programmer can carefully control
	these attributes.
	)

<h2>Invariant Storage Class</h2>

	$(P
	An invariant declaration cannot change, ever, and any data
	that can be referenced through the invariant cannot ever
	change. Initializers for invariant declarations can be placed into
	ROM (Read Only Memory).
	)

---
	invariant int x = 3;	// x is set to 3
	invariant int y;	// y is set to int.init, which is 0
	x = 4;			// error, x is invariant
	y = 5;			// error, y is invariant
---

	$(P
	The initializer for an invariant declaration must be evaluatable
	at compile time:
	)

---
	int foo(int f) { return f * 3; }
	int i = 5;
	invariant int x = 3 * 4;	// ok, 12
	invariant int y = i + 1;	// error, cannot evaluate at compile time
	invariant int z = foo(2) + 1;	// ok, foo(2) can be evaluated at compile time, 7
---

	$(P
	Data referred to by an invariant is also invariant:
	)

---
	invariant char[] s = "foo";
	s[0] = 'a';		// error, invariant
---

	$(P
	An implementation is allowed to replace an instance of an invariant
	declaration with the initializer for that declaration.
	Therefore, it is not legal to take the address of an invariant:
	)

---
	invariant int i = 3;
	invariant* p = &i;	// error, cannot take address of invariant
---

	$(P
	Invariant members of a class or struct do not take up
	any space in instances of those objects:
	)

---
	struct S
	{   int x;
	    invariant int y;
	}

	writefln(S.sizeof);	// prints 4, not 8
---

	$(P
	The type of an invariant declaration is itself invariant.
	)

<h2>Const Storage Class</h2>

	$(P
	A const declaration is exactly like an invariant declaration,
	with the following differences:
	)

	$(UL
	$(LI Any data referenced by the const declaration cannot be
	changed from the const declaration, but it might be changed
	by other references to the same data.)

	$(LI The type of a const declaration is itself const.)
	)

<h2>Final Storage Class</h2>

	$(P
	A final declaration is one that, once initialized, can never
	change its value.
	)

---
	final int x = 3;
	x = 4;		// error, x is final
---

	$(P
	Final declarations can be initialized either by an initializer,
	or by a constructor:
	)

---
	final int x;
	static this()
	{
	    x = 4;	// ok, can initialize final x inside constructor
	    x = 5;	// still ok, because still in constructor
	}
	...
	x = 6;		// error, x is final

	class C
	{
	    final int s;
	    this()
	    {	s = 3;	// ok, can initialize in constructor
	    }
	}
---

	$(P
	Final declarations are stored and do take up space,
	therefore their address can be taken.
	)

	$(P
	Taking the address of a final variable of type T results in a
	type that's const(T)*.
	)

---
	final int x = 3;
	auto p = &x;		// p is const(int)*
	*p = 4;			// error, *p is const
---

	$(P
	Final declarations are themselves neither invariant nor const.
	)

---
	int x = 4;
	final int* p = &x;
	p = null;		// error, p is final
	*p = 3;			// ok, x is now 3
---

<h2>Invariant Type</h2>

	$(P
	Data that will never change its value can be typed as invariant.
	The invariant keyword can be used as a $(I type constructor):
	)

---
	invariant(char)[] s = "hello";
---

	$(P
	The invariant applies to the type within the following parentheses.
	So, while s can be assigned new values, the contents of s[] cannot
	be:
	)

---
	s[0] = 'b';	// error, s[] is invariant
	s = null;	// ok, s itself is not invariant
---

	$(P
	Invariantness is transitive, meaning it applies to anything that
	can be referenced from the invariant type:
	)

---
	invariant(char*)** p = ...;
	p = ...;	// ok, p is not final
	*p = ...;	// *p is not invariant
	**p = ...;	// error, **p is invariant
	***p = ...;	// error, ***p is invariant
---

	$(P
	The invariantness also only applies to what is referred to, not
	the declaration itself:
	)

---
	invariant(char*) p = ...;
	p = ...;	// ok, invariant doesn't apply to p itself
	*p = ...;	// error, invariant applies to what p refers to
---

<h2>Creating Invariant Data</h2>

	$(P
	The first way is to use a literal that is already invariant,
	such as string literals. String literals are always invariant.
	)

---
	auto s = "hello";   // s is invariant(char)[5]
	char[] p = "world"; // error, cannot implicitly convert invariant
			    // to mutable
---

	$(P
	The second way is to cast data to invariant.
	When doing so, it is up to the programmer to ensure that no
	other mutable references to the same data exist.
	)

---
	char[] s = ...;
	invariant(char)[] p = cast(invariant)s;     // undefined behavior
	invariant(char)[] p = cast(invariant)s.dup; // ok, unique reference
---

	$(P
	The .idup property is a convenient way to create an invariant
	copy of an array:
	)

---
	auto p = s.idup;
	p[0] = ...;	  // error, p[] is invariant
---

<h2>Removing Invariant With A Cast</h2>

	$(P
	The invariant type can be removed with a cast:
	)

---
	invariant int* p = ...;
	int* q = cast(int*)p;
---

	$(P
	This does not mean, however, that one can change the data:
	)

---
	*q = 3; // allowed by compiler, but result is undefined behavior
---

	$(P
	The ability to cast away invariant-correctness is necessary in
	some cases where the static typing is incorrect and not fixable, such
	as when referencing code in a library one cannot change.
	Casting is, as always, a blunt and effective instrument, and
	when using it to cast away invariant-correctness, one must assume
	the responsibility to ensure the invariantness of the data, as
	the compiler will no longer be able to statically do so.
	)

<h2>Invariant Doesn't Apply To Declared Symbols</h2>

	$(P
	Consider the struct:
	)

---
	struct S
	{
	    int x;
	    int* p;
	}
---

	$(P
	In order to be able to use structs as user-defined wrappers
	for builtin types, it must be possible to declare a struct instance
	as having its members be mutable, but what it refers to to
	not be mutable. But all that's syntactically available is:
	)

---
	invariant(S) s;
---

	$(P
	Therefore, the invariant qualifier doesn't apply to the symbol
	itself being declared. It only applies to anything indirectly
	referenced by the symbol. Hence,
	)

---
	s.x = 3;   // ok
	*s.p = 3;  // error, it's invariant
---

	$(P
	For consistency's sake, then this must apply generally:
	)

---
	int x;
	invariant(int*) p;
	p = cast(invariant)&x;    // ok
	*p = 3;    // error, invariant

	invariant(int) y;
	y = 3;        // ok
	auto q = cast(invariant)&y;  // q's type is invariant(int)*
	*q = 4;       // error, invariant
---

	$(P
	A similar situation applies to classes. Given:
	)

---
	class C
	{
	    int x;
	    int* p;
	}

	invariant(C) c;
	c = new C;      // (1) ok
	c.x = 3;        // (2) error, invariant
	*c.p = 4;       // (3) error, invariant
---

	$(P
	Note that the c.x is an error, while the s.x is not. The reason is
	that c is already a reference type - so the invariant does not
	apply to c itself (1), but it does apply to what c refers to (2) and
	anything transitively referred to (3).
	)

<h2>Invariant Member Functions</h2>

	$(P
	Invariant member functions are guaranteed that the object
	and anything referred to by the this reference is invariant.
	They are declared as:
	)

---
	struct S
	{   int x;

	    invariant void foo()
	    {
		x = 4;	// error, x is invariant
		this.x = 4;   // error, x is invariant
	    }
	}
---

<h2>Const Type</h2>

	$(P
	Const types are like invariant types, except that const
	forms a read-only $(I view) of data. Other aliases to that
	same data may change it at any time.
	)

<h2>Const Member Functions</h2>

	$(P
	Const member functions are functions that are not allowed to
	change any part of the object through the member function's
	this reference.
	)

<h2>Implicit Conversions</h2>

	$(P
	Mutable and invariant types can be implicitly converted to const.
	Mutable types cannot be implicitly converted to invariant,
	and vice versa.
	)

<h2>Comparing D Invariant, Const and Final with C++ Const</h2>

	<table border=2 cellpadding=4 cellspacing=0 class="comp">
	<caption>Final, Const, Invariant Comparison</caption>

	<thead>
	$(TR
	$(TH Feature)
	$(TH D)
	$(TH C++98)
	)
	</thead>

	<tbody>

	$(TR
	$(TD final keyword)
	$(TD Yes)
	$(TD No)
	)

	$(TR
	$(TD const keyword)
	$(TD Yes)
	$(TD Yes)
	)

	$(TR
	$(TD invariant keyword)
	$(TD Yes)
	$(TD No)
	)

	$(TR
	$(TD const notation)
	$(TD Functional:
---
// ptr to const ptr to const int
const(int*)* p;
---
	)
	$(TD Postfix:
$(CPPCODE
// ptr to const ptr to const int
const int *const *p;
)
	)
	)

	$(TR
	$(TD transitive const)
	$(TD Yes:
---
const int** p;  // const ptr to const ptr to const int
**p = 3;    // error
---
	 )
	$(TD No:
$(CPPCODE
int** const p; // const ptr to ptr to int
**p = 3;    // ok
)
	 )
	)

	$(TR
	$(TD cast away const)
	$(TD Yes:
---
const(int)* p;   // ptr to const int
int* q = cast(int*)p; // ok
---
	)
	$(TD Yes:
$(CPPCODE
const int* p;   // ptr to const int
int* q = const_cast&lt;int*&gt;p; // ok
)
	)
	)

	$(TR
	$(TD modification after casting away const)
	$(TD No:
---
const(int)* p;   // ptr to const int
int* q = cast(int*)p;
*q = 3;   // undefined behavior
---
	)
	$(TD Yes:
$(CPPCODE
const int* p;   // ptr to const int
int* q = const_cast&lt;int*&gt;p;
*q = 3;   // ok
)
	)
	)

	$(TR
	$(TD overloading of top level const)
	$(TD No:
---
void foo(int x);
void foo(const int x);  // error
---
	)
	$(TD No:
$(CPPCODE
void foo(int x);
void foo(const int x);  // error
)
	)
	)

	$(TR
	$(TD aliasing of const with mutable)
	$(TD Yes:
---
void foo(const int* x, int* y)
{
   bar(*x); // bar(3)
   *y = 4;
   bar(*x); // bar(4)
}
...
int i = 3;
foo(&i, &i);
---
	)
	$(TD Yes:
$(CPPCODE
void foo(const int* x, int* y)
{
   bar(*x); // bar(3)
   *y = 4;
   bar(*x); // bar(4)
}
...
int i = 3;
foo(&i, &i);
)
	)
	)

	$(TR
	$(TD aliasing of invariant with mutable)
	$(TD Yes:
---
void foo(invariant int* x, int* y)
{
   bar(*x); // bar(3)
   *y = 4;  // undefined behavior
   bar(*x); // bar(??)
}
...
int i = 3;
foo(cast(invariant)&i, &i);
---
	)
	$(TD No invariants)
	)

	$(TR
	$(TD type of string literal)
	$(TD invariant(char)[])
	$(TD const char*)
	)


	$(TR
	$(TD implicit conversion of string literal to non-const)
	$(TD not allowed)
	$(TD allowed, but deprecated)
	)

	</tbody>
	</table>

)

Macros:
	TITLE=Final$(COMMA) Const$(COMMA) and Invariant
	WIKI=FinalConstInvariant
	NO=<td class="compNo">No</td>
	NO1=<td class="compNo"><a href="$1">No</a></td>
	YES=<td class="compYes">Yes</td>
	YES1=<td class="compYes"><a href="$1">Yes</a></td>
	D_CODE = <pre class="d_code2">$0</pre>
	CPPCODE2 = <pre class="cppcode2">$0</pre>
	ERROR = $(RED $(B error))
	COMMA=,
META_KEYWORDS=D Programming Language, const,
final, invariant
META_DESCRIPTION=Comparison of const between the
D programming language, C++, and C++0x

