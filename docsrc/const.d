Ddoc

$(D_S Here A Const$(COMMA) There A Const,

$(P $(I by Walter Bright))


$(P
In a small, experimental program, it's great to benefit from a programming
system that's flexible, permissive, and not too pedantic.
As the complexity of a program increases, it gets more beneficial
to specify the semantics of a declaration in the code itself.
Programmers want to carve subdomains in the large application and confine
specific state changes to small sections of code. Doing so rids them of
long-distance coupling among portions of code that modify the same data.
Documentation is unreliable as it is inevitably wrong, misleading,
incomplete, out of date, or just plain missing.
Of significant utility in this is the notion of constness.
C and C++ have added the ability to specify the constness of variables
and functions, and it has clearly demonstrated over time that it is
popular and useful, and many consider it crucial for developing
large programs.
In an attempt to simplify, Java dropped const. Its handling of
immutable strings and the often-used technique of preemptive copy-out are
awkward at best. As a consequence, putting const back into the language has
become a favorite indoor sport for industry and academia alike.
But C++'s const has a number of important shortcomings, so D took the
opportunity to reengineer the concept from top to bottom.
This article explores what constness is good for, how C++ constness
addresses it, and how D addresses it.
)


<h2>What Do We Want From Const?</h2>

$(P
There are a number of benefits that can be derived from knowing something
is constant, including benefits to optimization and code generation:
)

$(OL
$(LI	Constant data need never be copied! It can be infinitely shared (e.g.
	via pointers and references) as there is never contention on it. This
	leads to programs that are both correct and efficient.
)

$(LI	The most obvious is to just be able to name a manifest constant
	or string.
)

$(LI	Constant data can be placed into ROM (read only memory).
)

$(LI	Const parameters indicate that a function will not modify whatever
	its arguments refer to, with a direct positive effect on modularity.
)

$(LI	Constant data indicates that other threads or other aliases to the data
	cannot modify it.
)

$(LI	A constant can be propagated and folded, which pulls operations
	from run time into compile time.
)

$(LI	Data flow analysis is aided when there's a guarantee that constant
	data will not change as a side effect of other operations.
)

$(LI	Constant data can be cached or mirrored in registers without
	needing to synchronize them with memory.
)

$(LI	Const reduces the cognitive load on the programmer - by looking at
	constness in the declaration, he can learn things about whatever
	uses that declaration without having to slog through that code.
)
)


<h2>How Does C++ Const Stack Up?</h2>


$(P
C++ const comes in two forms: const as a storage class, and const
as a type attribute.
)

$(P
Const as a storage class is most useful for
declaring manifest constants, such as:
)

$(CPPCODE
const int X = 3;
)

$(P
and the language guarantees that $(CODE X) will never be anything but 3.
$(CODE X) can be put into ROM, and the optimizer can reliably replace all
rvalues of $(CODE X) with 3. Const is a storage class when it applies to the
top level type of the declaration. <a href="#note1">[1]</a>
)

$(P
Const as a type attribute is different. It becomes a type attribute
when it does not apply to the top level type of a declaration:
)

$(CPPCODE
int x = 3;
const int *p = &x;
)

$(P
Here the const applies to the int that $(CODE p) is pointing to, not $(CODE p).
Const as a type attribute means that a read only view of data is taken.
It doesn't mean that the data is constant. For example:
)

$(CPPCODE
int x = 3;
const int *p = &x;
*p = 4;		// error, read-only view

const int *q = &x;
int z = *q;	// z is set to 3
x = 5;		// ok
int y = *q;	// y is set to 5
)

$(P
$(CODE z) is not equal to $(CODE y), even though $(CODE *q) is const.
This is one instance of the so-called aliasing problem,
since while the above
snippet is trivial, the existence of such aliases can be very hard
to detect in a complex program. It is impossible for the compiler to
reliably detect it. This means that the compiler cannot cache 3 in
a register and reuse the cached value to replace $(CODE *q), it must
go back and actually dereference $(CODE q) again.
)

$(P
Consider a function defined as:
)

$(CPPCODE
void foo(const int *p);
)

$(P
Ostensibly, it looks like I can safely pass references to my int variables to
$(CODE foo()) and be assured that $(CODE foo()) won't be changing my ints.
But that isn't true:
)

$(CPPCODE
void foo(const int *p)
{
    int *q = const_cast&lt;int *&gt;(p);
    *q = 4;
}
)

$(P
$(CODE foo()) has not only cast away the constness, but it has gone and modified
my precious int variable, even though $(CODE foo())'s interface promised it
would not.
Even worse, this is legal and well-defined C++, and must be supported by
any C++ compiler. While writing such code is frowned upon by professional
C++ programmers, the fact that it is legal means that the compiler
is of no help in enforcing it.
)

$(P
So, if someone is doing a code review, and sees a function parameter declared
as a pointer to const, he must carefully review all the code in that function,
and all the code in functions called by that function that take the parameter
as an argument, to see if it is modified or not. This defeats much
of the purpose in declaring a parameter as const.
)

$(P
But there are more problems with C++ const. Consider a class:
)

$(CPPCODE
class C;
void foo(const C *p);
...
C c;
foo(&c);
)

$(P
Does $(CODE foo()) modify the contents of $(CODE c)?
Sure, through the $(CODE const_cast), but
there's another legal way. class $(CODE C) could have mutable members:
)

$(CPPCODE
class C
{
    public: mutable int x;
};

void foo(const C *p)
{
    p-&gt;x = 3;	// ok, C::x is mutable
}
)

$(P
So our beleagured code reviewer now has to search the definition of $(CODE C)
for
mutable members to see if $(CODE foo()) could modify $(CODE c).
)

$(P
The justification for mutable is the concept called $(I logical const), where
an object appears to be const to an external viewer, but internally can
change. An example would be a class that maintains a cached internal result
of an expensive operation. The difficulty with this is two-fold. First,
there is no language support at all to ensure that mutable is not used for
something other than logical constness. It can be very difficult for a code
reviewer to determine if mutable is used correctly in this manner or not.
It is impossible to do automated detection of logical constness.
Mutable can be and is used for other purposes, and that is completely
legal and well-defined C++.
Second, having const references to mutable data renders unreliable the
ability to rely on const references not being modifiable, which has unfortunate
consequences for optimization and writing inherently threadsafe code.
It goes back to making it impossible to write generic code that must
not modify anything referenced by its parameters.
)

$(P
There's one more problem. Suppose class $(CODE C) is the root of a collection,
which we'll trivially represent as $(CODE T*):
)

$(CPPCODE
class C
{
    T *q;
};
)

$(P
and a function $(CODE foo()) which reads the collection, and returns some
information about it:
)

$(CPPCODE
int foo(const C *p);
)

$(P
The $(CODE const) only applies to the contents of class $(CODE C), it does not
apply to
whatever $(CODE q) points to:
)

$(CPPCODE
int foo(const C *p)
{
    *p-&gt;q = ...;	// ok, we can modify whatever C::q points to
    return 0;
}
)

$(P
There is no way to specify in $(CODE foo())'s interface that it promises not to
modify
anything through its parameters. In other words, const is not transitive.
This is especially troublesome when attempting to write generic function
APIs based on unknown types:
)

$(CPPCODE
template&lt;T&gt; int foo(const T *p) { ... }
)

$(P
Without knowing the instantiated type of $(CODE T), it is impossible to know
if $(CODE foo()) is modifying things through its parameter or not.
)


$(P
To summarize the difficulties with C++ const:
)

$(OL
$(LI	Const type attributes do not mean immutable data, they only mean
	a read-only view of the data. Other references to the same data
	can modify it at any time.
)

$(LI	It is legal and defined behavior to cast away const-ness and change
	the data anyway if the data was originally mutable.
)

$(LI	Mutable members override the constness of the declaration.
)

$(LI	Const is not transitive; there is no way to specify the constness
	of a complex type at the point of use of it.
)
)


$(P
C++ const is not a good match with the goals listed at the beginning of this
article. That means that it's worth a redesign.
)



<h2>Constness In D</h2>

$(P
Clearly, there are two distinct meanings
to constant - meanings that are routinely conflated. One is that constant
data really is constant. It never changes. It's different enough that
it needs a different name. In D, this kind of constant is called an
invariant.
)

$(P
Invariant data solves the aliasing problem, because even if there are
other aliases to the same data, since it is invariant, those references
cannot alter the data. The more invariant data a program uses, the
easier it is to understand. Invariants form a touchstone,
a reference point, for exploring the meaning of the rest of the code.
If the value of an invariant does change, it is a clear indication of
a severe program bug.
It's helpful to have this constraint statically enforced.
)

$(P
The second kind of constant is a readonly view of data, even
though the data may be changed through another mutable reference to that
same data. This is called const, and is an invaluable modularity aid. One
function wants to look at some data; a module has the data, but wants to control
changes to it; all they need is a little protocol that allows the function to
look at the data, in confidence that it can't change it.
)

$(P
Mutable references can be implicitly converted to const (as in C++).
Invariant references can also be implicitly converted to const.
But const cannot be implicitly converted to invariant, and neither can
mutable references.
Essentially, const is a weaker form of invariant because it says: "you can't
change this data; someone else may or may not be able to change it."
)

$(P
Const references are usually used in function APIs, where the function
is guaranteeing it will not change any data reachable through that const
reference.
)

$(P
Which brings up another aspect of const in D - it's transitive.
Const in C++ is not transitive, which means one can have a pointer
to const pointer to mutable int. To declare a variable that is const
at each level, one must write:
)

$(CPPCODE
int const *const *const *p;   // C++
)

$(P
The $(CODE const) is left associative, so the declaration is a pointer to const
pointer to const pointer to const int. Const being transitive in D means
that every reference reachable through the const is also const.
An entire logical region of an application can be protected by placing only one
qualifier.
To reflect that, the syntax is different, using constructor-like notation:
)

---
const(int **)* p;	// D
---

$(P
Here the $(CODE const) applies to the part of the type that is in parentheses.
Note that the syntax makes it impossible to declare things like
a pointer to a const pointer to a mutable type.
This slight loss in expressiveness is justifiable by the considerable power of
transitive protection.
)

$(P
Transitive const solves the problem of specifying function interfaces
to data structs that truly are read only, even if they are generic functions
dealing with unknown types.
)

$(P
Analogously to const, invariant types are transitive and follow the same
syntactical pattern as const.
)


$(P
Because a static type system can be a straitjacket, there needs to be
a way to circumvent it for special cases. Like C++, D allows the casting away
of constness and invariantness. Unlike C++, if the programmer then
subverts the const or invariant guarantee and changes the underlying data,
then undefined behavior results.
)


<h2>References</h2>

$(UL
	$(LI $(LINK2 http://en.wikipedia.org/wiki/Const, Const-correctness) Wikipedia)
)

<h2>Acknowledgments</h2>

$(P
Many thanks for Andrei Alexandrescu, Bartosz Milewski, Brad Roberts,
David Held, Eric Niebler and many other members of the D community for their
major contributions to the design of the new const system.
)

$(P
Many thanks in particular to Andrei Alexandrescu for reviewing this
article and making many invaluable suggestions for improving it.
)

<h2>Notes</h2>

$(P
<a name="note1">[1]</a> Several people have questioned this, arguing
that const_cast allows a const object to be legitimatedly changed.
The relevant standard paragraph is C++98 7.1.5.1-4:

<blockquote>
Except that any class member declared mutable (7.1.1) can be modified, any attempt to modify a const
object during its lifetime (3.8) results in undefined behavior.
</blockquote>
)

)

Macros:
	TITLE=Here a Const, There a Const
	WIKI=Const
	D_CODE = <pre class="d_code2">$0</pre>
	CPPCODE2 = <pre class="cppcode2">$0</pre>
	ERROR = $(RED $(B error))
	COMMA=,
META_KEYWORDS=D Programming Language, const, final, invariant, mutable,
logical constness, C++
META_DESCRIPTION=Why const was redesigned in D.


