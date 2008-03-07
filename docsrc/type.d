Ddoc

$(SPEC_S Types,

$(SECTION2 Basic Data Types,

	$(TABLE1
	$(TR $(TH Keyword) $(TH Description) $(TH Default Initializer (.init))
	)
	$(TR
		$(TD $(TT void))
		$(TD no type)
		$(TD -)
	)
	$(TR
		$(TD $(TT bool))
		$(TD boolean value)
		$(TD false)
	)
	$(TR
		$(TD $(TT byte))
		$(TD signed 8 bits)
		$(TD 0)
	)
	$(TR
		$(TD $(TT ubyte))
		$(TD unsigned 8 bits)
		$(TD 0)
	)
	$(TR
		$(TD $(TT short))
		$(TD signed 16 bits)
		$(TD 0)
	)
	$(TR
		$(TD $(TT ushort))
		$(TD unsigned 16 bits)
		$(TD 0)
	)
	$(TR
		$(TD $(TT int))
		$(TD signed 32 bits)
		$(TD 0)
	)
	$(TR
		$(TD $(TT uint))
		$(TD unsigned 32 bits)
		$(TD 0)
	)
	$(TR
		$(TD $(TT long))
		$(TD signed 64 bits)
		$(TD 0L)
	)
	$(TR
		$(TD $(TT ulong))
		$(TD unsigned 64 bits)
		$(TD 0L)
	)
	$(TR
		$(TD $(TT cent))
		$(TD signed 128 bits (reserved for future use))
		$(TD 0)
	)
	$(TR
		$(TD $(TT ucent))
		$(TD unsigned 128 bits (reserved for future use))
		$(TD 0)
	)
	$(TR
		$(TD $(TT float))
		$(TD 32 bit floating point)
		$(TD float.nan)
	)
	$(TR
		$(TD $(TT double))
		$(TD 64 bit floating point)
		$(TD double.nan)
	)
	$(TR
		$(TD $(TT real))
		$(TD largest hardware implemented floating
		point size ($(B Implementation Note:) 80 bits for Intel CPUs))
		$(TD real.nan)
	)
	$(TR
		$(TD $(TT ifloat))
		$(TD imaginary float)
		$(TD float.nan * 1.0i)
	)
	$(TR
		$(TD $(TT idouble))
		$(TD imaginary double)
		$(TD double.nan * 1.0i)
	)
	$(TR
		$(TD $(TT ireal))
		$(TD imaginary real)
		$(TD real.nan * 1.0i)
	)
	$(TR
		$(TD $(TT cfloat))
		$(TD a complex number of two float values)
		$(TD float.nan + float.nan * 1.0i)
	)
	$(TR
		$(TD $(TT cdouble))
		$(TD complex double)
		$(TD double.nan + double.nan * 1.0i)
	)
	$(TR
		$(TD $(TT creal))
		$(TD complex real)
		$(TD real.nan + real.nan * 1.0i)
	)
	$(TR
		$(TD $(TT char))
		$(TD unsigned 8 bit UTF-8)
		$(TD 0xFF)
	)
	$(TR
		$(TD $(TT wchar))
		$(TD unsigned 16 bit UTF-16)
		$(TD 0xFFFF)
	)
	$(TR
		$(TD $(TT dchar))
		$(TD unsigned 32 bit UTF-32)
		$(TD 0x0000FFFF)
	)
	)
)


$(SECTION2 Derived Data Types,

    $(UL 
	$(LI pointer)
	$(LI array)
	$(LI associative array)
	$(LI function)
	$(LI delegate)
    )
)

$(SECTION2 User Defined Types,

    $(UL 
	$(LI alias)
	$(LI typedef)
	$(LI enum)
	$(LI struct)
	$(LI union)
	$(LI class)
    )
)


$(SECTION2 Base Types,

	$(P The $(I base type) of an enum is the type it is based on:)

---
enum E : T { ... }	// T is the $(I base type) of E
---

	$(P The $(I base type) of a typedef is the type it is formed from:)

---
typedef T U;		// T is the $(I base type) of U
---
)


$(SECTION2 Pointer Conversions,

	$(P Casting pointers to non-pointers and vice versa is allowed in D,
	however, do not do this for any pointers that point to data
	allocated by the garbage collector.
	)
)

$(SECTION2 Implicit Conversions,

	$(P Implicit conversions are used to automatically convert
	types as required.
	)

	$(P A typedef or enum can be implicitly converted to its base
	type, but going the other way requires an explicit
	conversion. For example:
	)

-------------------
typedef int myint;
int i;
myint m;
i = m;			// OK
m = i;			// error
m = cast(myint)i;	// OK
-------------------
)


$(SECTION2 Integer Promotions,

	$(P Integer Promotions are conversions of the following types:
	)

	$(TABLE1
	$(TR 
	$(TH from)
	$(TH to)
	)
	$(TR 
	$(TD bool)
	$(TD int)
	)
	$(TR 
	$(TD byte)
	$(TD int)
	)
	$(TR 
	$(TD ubyte)
	$(TD int)
	)
	$(TR 
	$(TD short)
	$(TD int)
	)
	$(TR 
	$(TD ushort)
	$(TD int)
	)
	$(TR 
	$(TD char)
	$(TD int)
	)
	$(TR 
	$(TD wchar)
	$(TD int)
	)
	$(TR 
	$(TD dchar)
	$(TD uint)
	)
	)

	$(P If a typedef or enum has as a base type one of the types
	in the left column, it is converted to the type in the right
	column.
	)
)


$(SECTION2 Usual Arithmetic Conversions,

	$(P The usual arithmetic conversions convert operands of binary
	operators to a common type. The operands must already be
	of arithmetic types.
	The following rules are applied
	in order, looking at the base type:
	)

    $(OL
	$(LI If either operand is real, the other operand is
	converted to real.)

	$(LI Else if either operand is double, the other operand is
	converted to double.)

	$(LI Else if either operand is float, the other operand is
	converted to float.)

	$(LI Else the integer promotions are done on each operand,
	followed by:

	$(OL 
	    $(LI If both are the same type, no more conversions are done.)

	    $(LI If both are signed or both are unsigned, the
	    smaller type is converted to the larger.)

	    $(LI If the signed type is larger than the unsigned
	    type, the unsigned type is converted to the signed type.)

	    $(LI The signed type is converted to the unsigned type.)
	)
	)
    )

	$(P If one or both of the operand types is a typedef or enum after
	undergoing the above conversions, the result type is:)

	$(OL
	$(LI If the operands are the same type, the result will be the
	that type.)
	$(LI If one operand is a typedef or enum and the other is the base type
	of that typedef or enum, the result is the base type.)
	$(LI If the two operands are different typedefs or enums but of the same
	base type, then the result is that base type.)
	)

	$(P Integer values cannot be implicitly converted to another
	type that cannot represent the integer bit pattern after integral
	promotion. For example:)

---
ubyte  u1 = cast(byte)-1;   // error, -1 cannot be represented in a ubyte
ushort u2 = cast(short)-1;  // error, -1 cannot be represented in a ushort
uint   u3 = cast(int)-1;    // ok, -1 can be represented in a uint
ulong  u4 = cast(ulong)-1;  // ok, -1 can be represented in a ulong
---

	$(P Floating point types cannot be implicitly converted to
	integral types.
	)

	$(P Complex floating point types cannot be implicitly converted
	to non-complex floating point types.
	)

	$(P Imaginary floating point types cannot be implicitly converted to
	float, double, or real types. Float, double, or real types
	cannot be implicitly converted to imaginary floating
	point types.
	)
)


$(SECTION2 bool,

	$(P The bool type is a 1 byte size type that can only hold the
	value $(D_KEYWORD true) or $(D_KEYWORD false).
	The only operators that can accept operands of type bool are:
	&amp; | ^ &amp;= |= ^= ! &amp;&amp; || ?:.
	A bool value can be implicitly converted to any integral type,
	with $(D_KEYWORD false) becoming 0 and $(D_KEYWORD true) becoming 1.
	The numeric literals 0 and 1 can be implicitly
	converted to the bool values $(D_KEYWORD false) and $(D_KEYWORD true),
	respectively.
	Casting an expression to bool means testing for 0 or !=0 for
	arithmetic types, and $(D_KEYWORD null) or !=$(D_KEYWORD null)
	for pointers or references.
	)
)


$(SECTION2 <a name="delegates">Delegates</a>,

	$(P There are no pointers-to-members in D, but a more useful
	concept called $(I delegates) are supported.
	Delegates are an aggregate of two pieces of data: an
	object reference and a function pointer. The object reference
	forms the $(I this) pointer when the function is called.
	)

	$(P Delegates are declared similarly to function pointers,
	except that the keyword $(B delegate) takes the place
	of (*), and the identifier occurs afterwards:
	)

-------------------
int function(int) fp;	// fp is pointer to a function
int delegate(int) dg;	// dg is a delegate to a function
-------------------

	$(P The C style syntax for declaring pointers to functions is
	also supported:
	)

-------------------
int (*fp)(int);		// fp is pointer to a function
-------------------

	$(P A delegate is initialized analogously to function pointers:
	)

-------------------
int func(int);
fp = &func;		// fp points to func

class OB
{   int member(int);
}
OB o;
dg = &o.member;		// dg is a delegate to object $(I o) and
			// member function $(I member)
-------------------

	$(P Delegates cannot be initialized with static member functions
	or non-member functions.
	)

	$(P Delegates are called analogously to function pointers:
	)

-------------------
fp(3);		// call func(3)
dg(3);		// call o.member(3)
-------------------
)

)

Macros:
	TITLE=Types
	WIKI=Type

