Ddoc

$(SPEC_S Structs &amp; Unions,

	$(P Whereas classes are reference types, structs are value types.
	Any C struct can be exactly represented as a D struct.
	In C++ parlance, a D struct is a
	$(LINK2 glossary.html#pod, POD (Plain Old Data)) type,
	with a trivial constructors and destructors.
	Structs and unions are meant as simple aggregations of data, or as a way
	to paint a data structure over hardware or an external type. External
	types can be defined by the operating system API, or by a file format.
	Object oriented features are provided with the class data type.
	)

	$(P A struct is defined to not have an identity; that is,
	the implementation is free to make bit copies of the struct
	as convenient.)

	$(TABLE1
	<caption>Struct, Class Comparison Table</caption>

	$(TR
	$(TH Feature)
	$(TH struct)
	$(TH class)
	$(TH C struct)
	$(TH C++ struct)
	$(TH C++ class)
	)

	$(TR
	$(TD value type)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD reference type)
	$(NO)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD data members)
	$(YES)
	$(YES)
	$(YES)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD hidden members)
	$(NO)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD static members)
	$(YES)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD default member initializers)
	$(YES)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD bit fields)
	$(NO)
	$(NO)
	$(YES)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD non-virtual member functions)
	$(YES)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD virtual member functions)
	$(NO)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD constructors)
	$(NO)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD destructors)
	$(NO)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD $(LINK2 #StructLiteral, literals))
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD RAII)
	$(NO)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD operator overloading)
	$(YES)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD inheritance)
	$(NO)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD invariants)
	$(YES)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD unit tests)
	$(YES)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD synchronizable)
	$(NO)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD parameterizable)
	$(YES)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD alignment control)
	$(YES)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)

	$(TR
	$(TD member protection)
	$(YES)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD default public)
	$(YES)
	$(YES)
	$(YES)
	$(YES)
	$(NO)
	)

	$(TR
	$(TD tag name space)
	$(NO)
	$(NO)
	$(YES)
	$(YES)
	$(YES)
	)

	$(TR
	$(TD anonymous)
	$(YES)
	$(NO)
	$(YES)
	$(YES)
	$(YES)
	)

$(V2
	$(TR
	$(TD const/invariant)
	$(YES)
	$(YES)
	$(NO)
	$(NO)
	$(NO)
	)
)
	)

$(GRAMMAR
$(I AggregateDeclaration):
	$(I Tag) $(I Identifier) $(I StructBody)
	$(I Tag) $(I Identifier) $(B ;)

$(I Tag):
	$(B struct)
	$(B union)

$(I StructBody):
	$(B {) $(B })
	$(B {) $(I StructBodyDeclarations) $(B })

$(I StructBodyDeclarations):
	$(I StructBodyDeclaration)
	$(I StructBodyDeclaration) $(I StructBodyDeclarations)

$(I StructBodyDeclaration):
	$(I Declaration)
	$(I StaticConstructor)
	$(I StaticDestructor)
	$(I Invariant)
	$(I UnitTest)
	$(I StructAllocator)
	$(I StructDeallocator)

$(I StructAllocator):
	$(I ClassAllocator)

$(I StructDeallocator):
	$(I ClassDeallocator)
)

$(P They work like they do in C, with the following exceptions:)

$(UL
	$(LI no bit fields)
	$(LI alignment can be explicitly specified)
	$(LI no separate tag name space - tag names go into the current scope)
	$(LI declarations like:

------
struct ABC x;
------
	are not allowed, replace with:

------
ABC x;
------
	)
	$(LI anonymous structs/unions are allowed as members of other structs/unions)
	$(LI Default initializers for members can be supplied.)
	$(LI Member functions and static members are allowed.)
)



<h3>Static Initialization of Structs</h3>

	Static struct members are by default initialized to whatever the
	default initializer for the member is, and if none supplied, to
	the default initializer for the member's type.
	If a static initializer is supplied, the
	members are initialized by the member name, 
	colon, expression syntax. The members may be initialized in any order.
	Members not specified in the initializer list are default initialized.

------
struct X { int a; int b; int c; int d = 7;}
static X x = { a:1, b:2};	      // c is set to 0, d to 7
static X z = { c:4, b:5, a:2 , d:5};  // z.a = 2, z.b = 5, z.c = 4, z.d = 5
------

	C-style initialization, based on the order of the members in the
	struct declaration, is also supported:

------
static X q = { 1, 2 };	  // q.a = 1, q.b = 2, q.c = 0, q.d = 7
------
	

<h3>Static Initialization of Unions</h3>

	Unions are initialized explicitly.

------
union U { int a; double b; }
static U u = { b : 5.0 };		// u.b = 5.0
------

	Other members of the union that overlay the initializer,
	but occupy more storage, have 
	the extra storage initialized to zero.

<h3>Dynamic Initialization of Structs</h3>

	$(P Structs can be dynamically initialized from another
	value of the same type:)

----
struct S { int a; }
S t;      // default initialized
t.a = 3;
S s = t;  // s.a is set to 3
----

	$(P If $(TT opCall) is overridden for the struct, and the struct
	is initialized with a value that is of a different type,
	then the $(TT opCall) operator is called:)

----
struct S
{   int a;

    static S $(B opCall)(int v)
    {	S s;
	s.a = v;
	return s;
    }

    static S $(B opCall)(S v)
    {	S s;
	s.a = v.a + 1;
	return s;
    }
}

S s = 3;	// sets s.a to 3
S t = s;	// sets t.a to 3, S.$(B opCall)(s) is not called
----

<h3><a name="StructLiteral">Struct Literals</a></h3>

	$(P Struct literals consist of the name of the struct followed
	by a parenthesized argument list:)

---
struct S { int x; float y; }

int foo(S s) { return s.x; }

foo( S(1, 2) );   // set field x to 1, field y to 2
---

	$(P Struct literals are syntactically like function calls.
	If a struct has a member function named $(CODE opCall), then
	struct literals for that struct are not possible.
	It is an error if there are more arguments than fields of
	the struct.
	If there are fewer arguments than fields, the remaining
	fields are initialized with their respective default
	initializers.
	If there are anonymous unions in the struct, only the first
	member of the anonymous union can be initialized with a
	struct literal, and all subsequent non-overlapping fields are default
	initialized.
	)

<h3>Struct Properties</h3>

$(TABLE1
$(TR $(TD .sizeof) $(TD Size in bytes of struct))
$(TR $(TD .alignof) $(TD Size boundary struct needs to be aligned on))
$(TR $(TD .tupleof) $(TD Gets type tuple of fields))
)

<h3>Struct Field Properties</h3>

$(TABLE1
$(TR $(TD .offsetof) $(TD Offset in bytes of field from beginning of struct))
)

$(V2
$(SECTION3 <a name="ConstStruct">Const and Invariant Structs</a>,

	$(P A struct declaration can have a storage class of
	$(CODE const) or $(CODE invariant). It has an equivalent
	effect as declaring each member of the struct as
	$(CODE const) or $(CODE invariant).
	)

----
const struct S { int a; int b = 2; }

void main()
{
    S s = S(3);    // initializes s.a to 3
    S t;           // initializes t.a to 0
    t = s;         // ok, t.a is now 3
    t.a = 4;       // error, t.a is const
}
----
)
)

)

Macros:
	TITLE=Structs, Unions
	WIKI=Struct
	NO=$(TD &nbsp;)
	YES=$(TD X)
