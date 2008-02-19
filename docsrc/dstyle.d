Ddoc

$(D_S The D Style,

$(P
	$(I The D Style) is a set of style conventions for writing
	D programs. The D Style is not enforced by the compiler, it is
	purely cosmetic and a matter of choice. Adhering to the D Style,
	however, will make it easier for others to work with your
	code and easier for you to work with others' code.
	The D Style can form the starting point for a project
	style guide customized for your project team.
)

$(P
	Submissions to Phobos and other official D source code will
	follow these guidelines.
)

<h3>White Space</h3>

$(UL
	$(LI One statement per line.)

	$(LI Hardware tabs are at 8 column increments. Avoid using
	hardware tabs if they are set at a different value.)

	$(LI Each indentation level will be four columns.)

	$(LI Operators are separated by single spaces from their operands.)

	$(LI Two blank lines separating function bodies.)

	$(LI One blank line separating variable declarations from statements
	in function bodies.)
)

<h3>Comments</h3>

$(UL
	$(LI Use // comments to document a single line:
-------------------------------
statement;	// comment
statement;	// comment
-------------------------------
	)

	$(LI Use block comments to document a multiple line block of
	statements:
-------------------------------
/*
 * comment
 * comment
 */
 statement;
 statement;
-------------------------------
	)

	$(LI Use nesting comments to 'comment out' a piece of trial code:
-------------------------------
/+++++
    /*
     * comment
     * comment
     */
     statement;
     statement;
 +++++/
-------------------------------
	)
)

<h3>Naming Conventions</h3>

$(DL
    $(DT General)
	<dd>Names formed by joining multiple words should have each word
	other than the first capitalized.
	Names shall not begin with an underscore '_'.

-------------------------------
int myFunc();
-------------------------------

    $(DT Module)
	$(DD Module and package names are all lower case, and only contain
	the characters [a..z][0..9][_]. This avoids problems dealing
	with case insensitive file systems.)

    $(DT C Modules)
	$(DD Modules that are interfaces to C functions go into the "c"
	package, for example:
-------------------------------
import std.c.stdio;
-------------------------------
	Module names should be all lower case.
	)

    $(DT Class, Struct, Union, Enum, Template names)
	$(DD are capitalized.

-------------------------------
class Foo;
class FooAndBar;
-------------------------------
	)

    $(DT Function names)
	$(DD Function names are not capitalized.

-------------------------------
int done();
int doneProcessing();
-------------------------------
	)

    $(DT Const names)
	$(DD Are in all caps.)

    $(DT Enum member names)
	$(DD Are in all caps.)

)

<h3>Meaningless Type Aliases</h3>

	$(P Things like:)

-------------------------------
alias void VOID;
alias int INT;
alias int* pint;
-------------------------------

	$(P should be avoided.)

<h3>Declaration Style</h3>

	$(P Since the declarations are left-associative, left justify them:)

-------------------------------
int[] x, y;	// makes it clear that x and y are the same type
int** p, q;	// makes it clear that p and q are the same type
-------------------------------

	$(P to emphasize their relationship. Do not use the C style:)

-------------------------------
int []x, y;	// confusing since y is also an int[]
int **p, q;	// confusing since q is also an int**
-------------------------------

<h3>Operator Overloading</h3>

	$(P Operator overloading is a powerful tool to extend the basic
	types supported by the language. But being powerful, it has
	great potential for creating obfuscated code. In particular,
	the existing D operators have conventional meanings, such
	as '+' means 'add' and '&lt;&lt;' means 'shift left'.
	Overloading operator '+' with a meaning different from 'add'
	is arbitrarily confusing and should be avoided. 
	)

<h3>Hungarian Notation</h3>

	$(P Using hungarian notation to denote the type of a variable
	is a bad idea.
	However, using notation to denote the purpose of a variable
	(that cannot be expressed by its type) is often a good
	practice.)

<h3>Documentation</h3>

$(P
	All public declarations will be documented in
	$(LINK2 ddoc.html, Ddoc) format.
)

<h3>Unit Tests</h3>

$(P
	As much as practical, all functions will be exercised
	by unit tests using unittest blocks immediately following
	the function to be tested.
	Every path of code should be executed at least once,
	verified by the $(LINK2 code_coverage.html, code coverage analyzer).
)

)

Macros:
	TITLE=The D Style
	WIKI=DStyle

