Ddoc

$(D_S Const and Invariant,

	$(P When examining a data structure or interface, it is very
	helpful to be able to easily tell which data can be expected to not
	change, which data might change, and who may change that data.
	This is done with the aid of the language typing system.
	Data can be marked as const or invariant, with the default being
	changeable (or $(I mutable)).
	)

	$(P $(I invariant) applies to data that cannot change.
	Invariant data values, once constructed, remain the same for
	the duration of the program's
	execution.
	Invariant data can be placed in ROM (Read Only Memory) or in
	memory pages marked by the hardware as read only.
	Since invariant data does not change, it enables many opportunities
	for program optimization, and has applications in functional
	style programming.
	)

	$(P $(I const) applies to data that cannot be changed by
	the const reference to that data. It may, however, be changed
	by another reference to that same data.
	Const finds applications in passing data through interfaces
	that promise not to modify them.
	)

	$(P Both invariant and const are $(I transitive), which means
	that any data reachable through an invariant reference is also
	invariant, and likewise for const.
	)

$(SECTION2 Invariant Storage Class,

	$(P
	The simplest invariant declarations use it as a storage class.
	It can be used to declare manifest constants.
	)

---
invariant int x = 3;	// x is set to 3
x = 4;			// error, x is invariant
char[x] s;		// s is an array of 3 char's
---

	$(P The type can be inferred from the initializer:
	)
---
invariant y = 4;	// y is of type int
y = 5;			// error, y is invariant
---

	$(P If the initializer is not present, the invariant can
	be initialized from the corresponding constructor:
	)

---
invariant int z;
void test()
{
    z = 3;		// error, z is invariant
}
static this()
{
    z = 3;    // ok, can set invariant that doesn't have
              // static initializer
}
---
	$(P
	The initializer for a non-local invariant declaration must be
	evaluatable
	at compile time:
	)

---
int foo(int f) { return f * 3; }
int i = 5;
invariant x = 3 * 4;      // ok, 12
invariant y = i + 1;      // error, cannot evaluate at compile time
invariant z = foo(2) + 1; // ok, foo(2) can be evaluated at compile time, 7
---

	$(P The initializer for a non-static local invariant declaration
	is evaluated at compile time:
	)
---
int foo(int f)
{
  invariant x = f + 1;  // evaluated at run time
  x = 3;                // error, x is invariant
}
---

	$(P
	Because invariant is transitive, data referred to by an invariant is
	also invariant:
	)

---
invariant char[] s = "foo";
s[0] = 'a';  // error, s refers to invariant data
s = "bar";   // error, s is invariant
---

	$(P Invariant declarations can appear as lvalues, i.e. they can
	have their address taken, and occupy storage.
	)
)

$(SECTION2 Const Storage Class,

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

$(COMMENT
$(TABLE1

$(TR $(TH &nbsp;) $(TH AddrOf) $(TH CTFEInit) $(TH Static) $(TH Field) $(TH Stack) $(TH Ctor))

$(TR $(TD &nbsp;)
 $(TD Can the address be taken?)
 $(TD Is compile time function evaluation done on the initializer?)
 $(TD allocated as static data?)
 $(TD allocated as a per-instance field?)
 $(TD allocated on the stack?)
 $(TD Can the variable be assigned to in a constructor?)
)


$(TR $(TH Global data))

$(TR $(TD1 const T x;)		$(Y)	$(N)	$(Y)	$(N)	$(N)	$(Y))
$(TR $(TD1 const T x = 3;)		$(N)	$(Y)	$(N)	$(N)	$(N)	$(N))
$(TR $(TD1 static const T x;)	$(Y)	$(N)	$(Y)	$(N)	$(N)	$(Y))
$(TR $(TD1 static const T x = 3;)	$(Y)	$(Y)	$(Y)	$(N)	$(N)	$(N))


$(TR $(TH Class Members))

$(TR $(TD1 const T x;)		$(Y)	$(N)	$(N)	$(Y)	$(N)	$(Y))
$(TR $(TD1 const T x = 3;)		$(N)	$(Y)	$(N)	$(N)	$(N)	$(N))
$(TR $(TD1 static const T x;)	$(Y)	$(N)	$(Y)	$(N)	$(N)	$(Y))
$(TR $(TD1 static const T x = 3;)	$(Y)	$(Y)	$(Y)	$(N)	$(N)	$(N))


$(TR $(TH Local Variables))

$(TR $(TD1 const T x;)		$(Y)	$(Y)	$(N)	$(N)	$(Y)	$(N))
$(TR $(TD1 const T x = 3;)		$(Y)	$(N)	$(N)	$(N)	$(Y)	$(N))
$(TR $(TD1 static const T x;)	$(Y)	$(Y)	$(Y)	$(N)	$(N)	$(N))
$(TR $(TD1 static const T x = 3;)	$(Y)	$(Y)	$(Y)	$(N)	$(N)	$(N))

$(TR $(TH Function Parameters))

$(TR $(TD1 const T x;)		$(Y)	$(N)	$(N)	$(N)	$(Y)	$(N))
)


$(P Notes:)

$(OL
$(LI If CTFEInit is true, then the initializer can also be used for
constant folding.)
)


$(TABLE1
<caption>Template Argument Deduced Type</caption>
$(TR $(TH &nbsp;)               $(TH mutable $(CODE T)) $(TH1 const(T)) $(TH1 invariant(T)))
$(TR $(TD1 foo(U))              $(TDE T) $(TDE T) $(TDE T))
$(TR $(TD1 foo(U:U))            $(TDE T) $(TDE const(T)) $(TDE invariant(T)))
$(TR $(TD1 foo(U:const(U)))     $(TDI T) $(TDE T) $(TDI T))
$(TR $(TD1 foo(U:invariant(U))) $(NM) $(NM) $(TDE T))
)

$(P Where:)

$(TABLE1
$(TR $(TD $(GREEN green)) $(TD exact match))
$(TR $(TD $(ORANGE orange)) $(TD implicit conversion))
)
)
)

$(SECTION2 Invariant Type,

	$(P
	Data that will never change its value can be typed as invariant.
	The invariant keyword can be used as a $(I type constructor):
	)

---
invariant(char)[] s = "hello";
---

	$(P
	The invariant applies to the type within the following parentheses.
	So, while $(CODE s) can be assigned new values,
	the contents of $(CODE s[]) cannot be:
	)

---
s[0] = 'b';  // error, s[] is invariant
s = null;    // ok, s itself is not invariant
---

	$(P
	Invariantness is transitive, meaning it applies to anything that
	can be referenced from the invariant type:
	)

---
invariant(char*)** p = ...;
p = ...;        // ok, p is not invariant
*p = ...;       // ok, *p is not invariant
**p = ...;      // error, **p is invariant
***p = ...;     // error, ***p is invariant
---

	$(P Invariant used as a storage class is equivalent to using
	invariant as a type constructor for the entire type of a
	declaration:)

---
invariant int x = 3;   // x is typed as invariant(int)
invariant(int) y = 3;  // y is invariant
---
)


$(SECTION2 Creating Invariant Data,

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
	The $(CODE .idup) property is a convenient way to create an invariant
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
)


$(SECTION2 Invariant Member Functions,

	$(P
	Invariant member functions are guaranteed that the object
	and anything referred to by the $(CODE this) reference is invariant.
	They are declared as:
	)

---
struct S
{   int x;

    invariant void foo()
    {
	x = 4;	    // error, x is invariant
	this.x = 4; // error, x is invariant
    }
}
---
)


$(SECTION2 Const Type,

	$(P
	Const types are like invariant types, except that const
	forms a read-only $(I view) of data. Other aliases to that
	same data may change it at any time.
	)
)


$(SECTION2 Const Member Functions,

	$(P
	Const member functions are functions that are not allowed to
	change any part of the object through the member function's
	this reference.
	)
)


$(SECTION2 Implicit Conversions,

	$(P
	Mutable and invariant types can be implicitly converted to const.
	Mutable types cannot be implicitly converted to invariant,
	and vice versa.
	)
)


$(SECTION2 Comparing D Invariant and Const with C++ Const,

	<table border=2 cellpadding=4 cellspacing=0 class="comp">
	<caption>Const, Invariant Comparison</caption>

	<thead>
	$(TR
	$(TH Feature)
	$(TH D)
	$(TH C++98)
	)
	</thead>

	<tbody>

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
//ptr to const ptr to const int
const(int*)* p;
---
	)
	$(TD Postfix:
$(CPPCODE
//ptr to const ptr to const int
const int *const *p;
)
	)
	)

	$(TR
	$(TD transitive const)
	$(TD Yes:
---
//const ptr to const ptr to const int
const int** p;
**p = 3; // error
---
	 )
	$(TD No:
$(CPPCODE
// const ptr to ptr to int
int** const p;
**p = 3;    // ok
)
	 )
	)

	$(TR
	$(TD cast away const)
	$(TD Yes:
---
// ptr to const int
const(int)* p;
int* q = cast(int*)p; // ok
---
	)
	$(TD Yes:
$(CPPCODE
// ptr to const int
const int* p;
int* q = const_cast&lt;int*&gt;p; //ok
)
	)
	)

	$(TR
	$(TD modification after casting away const)
	$(TD No:
---
// ptr to const int
const(int)* p;
int* q = cast(int*)p;
*q = 3;   // undefined behavior
---
	)
	$(TD Yes:
$(CPPCODE
// ptr to const int
const int* p;
int* q = const_cast&lt;int*&gt;p;
*q = 3;   // ok
)
	)
	)

	$(TR
	$(TD overloading of top level const)
	$(TD Yes:
---
void foo(int x);
void foo(const int x);  //ok
---
	)
	$(TD No:
$(CPPCODE
void foo(int x);
void foo(const int x);  //error
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


)

Macros:
	TH1=<th nowrap="nowrap">$(CODE $0)</th>
	TD1=<td nowrap="nowrap">$(CODE $0)</td>
	TDE=<td nowrap="nowrap">$(GREEN $(CODE $0))</td>
	TDI=<td nowrap="nowrap">$(ORANGE $(CODE $0))</td>
	NM=$(TD $(RED no match))
	Y=$(TD $(GREEN Yes))
	N=$(TD $(RED No))
	TITLE=Const and Invariant
	WIKI=ConstInvariant
	NO=<td class="compNo">No</td>
	NO1=<td class="compNo"><a href="$1">No</a></td>
	YES=<td class="compYes">Yes</td>
	YES1=<td class="compYes"><a href="$1">Yes</a></td>
	D_CODE = <pre class="d_code2">$0</pre>
	CPPCODE2 = <pre class="cppcode2">$0</pre>
	ERROR = $(RED $(B error))
	COMMA=,
META_KEYWORDS=D Programming Language, const, invariant
META_DESCRIPTION=Comparison of const between the
D programming language, C++, and C++0x

