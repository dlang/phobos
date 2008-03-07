Ddoc

$(SPEC_S Enums - Enumerated Types,

$(GRAMMAR
$(I EnumDeclaration):
	$(B enum) $(I EnumTag) $(I EnumBody)
	$(B enum) $(I EnumBody)
	$(B enum) $(I EnumTag) $(B :) $(I EnumBaseType) $(I EnumBody)
	$(B enum) $(B :) $(I EnumBaseType) $(I EnumBody)

$(I EnumTag):
	$(I Identifier)

$(I EnumBaseType):
	$(I Type)

$(I EnumBody):
	$(B ;)
	$(B {) $(I EnumMembers) $(B })

$(I EnumMembers):
	$(I EnumMember)
	$(I EnumMember) $(B ,)
	$(I EnumMember) $(B ,) $(I EnumMembers)

$(I EnumMember):
	$(I Identifier)
	$(I Identifier) $(B =) $(ASSIGNEXPRESSION)
$(V2
	$(I Type) $(I Identifier) $(B =) $(ASSIGNEXPRESSION))
)

	$(P Enum declarations are used to define a group of constants.
	They come in two forms:
	)
	$(OL
	$(LI Named enums, which have an $(I EnumTag).)
	$(LI Anonymous enums, which do not have an $(I EnumTag).)
	)

<h2>Named Enums</h2>

	$(P
	Named enums are used to declare related
	constants and group them by giving them a unique type.
	The $(I EnumMembers)
	are declared in the scope of the enum $(I EnumTag).
	The enum $(I EnumTag) declares a new type, and all
	the $(I EnumMembers) have that type.
	)

	$(P This defines a new type $(CODE X) which has values
	$(CODE X.A=0), $(CODE X.B=1), $(CODE X.C=2):)

------
enum X { A, B, C }	// named enum
------

$(V1
	$(P If the $(I EnumBaseType) is not explicitly set, it is set to
	type $(CODE int).)
)
$(V2
	$(P If the $(I EnumBaseType) is not explicitly set, and the first
	$(I EnumMember) has an initializer, it is set to the type of that
	initializer. Otherwise, it defaults to
	type $(CODE int).)

	$(P Named enum members may not have individual $(I Type)s.
	)
)

	$(P A named enum member can be implicitly cast to its $(I EnumBaseType),
	but $(I EnumBaseType) types
	cannot be implicitly cast to an enum type.
	)

	$(P The value of an $(I EnumMember) is given by its initializer.
	If there is no initializer, it is given the value of the
	previous $(I EnumMember) + 1. If it is the first $(I EnumMember),
	it's value is 0.
	)

	$(P Enums must have at least one member.
	)

<h3>Enum Default Initializer</h3>

	$(P The $(CODE .init) property of an enum type is the value
	of the first member of that enum.
	This is also the default initializer for the enum type.
	)

------
enum X { A=3, B, C }
X x;		// x is initialized to 3
------

<h3>Enum Properties</h3>

	$(P Enum properties only exist for named enums.
	)

	$(TABLE1
	$(CAPTION Named Enum Properties)
	$(TR $(TD .init) $(TD First enum member value))
	$(TR $(TD .min) $(TD Smallest value of enum))
	$(TR $(TD .max) $(TD Largest value of enum))
	$(TR $(TD .sizeof) $(TD Size of storage for an enumerated value))
	)

	$(P For example:)

---
enum X { A=3, B, C }
X.min     // is X.A
X.max     // is X.C
X.sizeof  // is same as int.sizeof
---

$(V2
	$(P The $(I EnumBaseType) of named enums must support comparison
	in order to compute the $(CODE .max) and $(CODE .min) properties.
	)
)

<h2>Anonymous Enums</h2>

	$(P If the enum $(I Identifier) is not present, then the enum
	is an $(I anonymous enum), and the $(I EnumMembers) are declared
	in the scope the $(I EnumDeclaration) appears in.
	No new type is created; the $(I EnumMembers) have the type of the
	$(I EnumBaseType).
	)

	The $(I EnumBaseType) is the underlying type of the enum.
$(V1
	$(P It must be an integral type.
	If omitted, it defaults to $(B int).
	)
)
$(V2
	$(P If omitted, the $(I EnumMembers) can have different types.
	Those types are given by the first of:
	)

	$(OL
	$(LI The $(I Type), if present.)
	$(LI The type of the $(I AssignExpression), if present.)
	$(LI The type of the previous $(I EnumMember), if present.)
	$(LI $(CODE int))
	)
)

------
enum { A, B, C }	// anonymous enum
------

	$(P Defines the constants A=0, B=1, C=2, all of type int.)

	$(P Enums must have at least one member.
	)

	$(P The value of an $(I EnumMember) is given by its initializer.
	If there is no initializer, it is given the value of the
	previous $(I EnumMember) + 1. If it is the first $(I EnumMember),
	it's value is 0.
	)

------
enum { A, B = 5+7, C, D = 8+C, E }
------

	$(P Sets A=0, B=12, C=13, D=21, and E=22, all of type int.)

---
enum : long { A = 3, B }
---

	$(P Sets A=3, B=4 all of type long.)

$(V2
---
enum : string
{
    A = "hello",
    B = "betty",
    C     // error, cannot add 1 to "betty"
}
---

---
enum
{
    A = 1.2f,   // A is 1.2f of type float
    B,          // B is 2.2f of type float
    int C = 3,  // C is 3 of type int
    D           // D is 4 of type int
}
---

<h3>Manifest Constants</h3>

	$(P If there is only one member of an anonymous enum, the { } can
	be omitted:
	)

---
enum i = 4;      // i is 4 of type int
enum long l = 3; // l is 3 of type long
---

	$(P Such declarations are not lvalues, meaning their address
	cannot be taken.)
)

)

Macros:
	TITLE=Enums
	WIKI=Enum

