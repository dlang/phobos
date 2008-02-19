Ddoc

$(SPEC_S Pragmas,

$(GRAMMAR
$(I Pragma):
    $(B pragma) $(B $(LPAREN)) $(I Identifier) $(B $(RPAREN))
    $(B pragma) $(B $(LPAREN)) $(I Identifier) $(B ,) $(I ExpressionList) $(B $(RPAREN))
)


	Pragmas are a way to pass special information to the compiler
	and to add vendor specific extensions to D.
	Pragmas can be used by themselves terminated with a ';',
	they can influence a statement, a block of statements, a declaration, or
	a block of declarations.

-----------------
pragma(ident);		   // just by itself

pragma(ident) declaration; // influence one declaration

pragma(ident):		   // influence subsequent declarations
    declaration;
    declaration;

pragma(ident)		   // influence block of declarations
{   declaration;
    declaration;
}

pragma(ident) statement;   // influence one statement

pragma(ident)		   // influence block of statements
{   statement;
    statement;
}
-----------------

	The kind of pragma it is is determined by the $(I Identifier).
	$(I ExpressionList) is a comma-separated list of
	$(ASSIGNEXPRESSION)s. The $(ASSIGNEXPRESSION)s must be
	parsable as expressions, but what they mean semantically
	is up to the individual pragma semantics.

<h2><a name="Predefined-Pragmas">Predefined Pragmas</a></h2>

	All implementations must support these, even if by just ignoring
	them:

    $(DL

    $(DT $(B msg))
    $(DD Prints a message while compiling, the $(ASSIGNEXPRESSION)s must
	be string literals:
-----------------
pragma(msg, "compiling...");
-----------------
    )

    $(DT $(B lib))
    $(DD Inserts a directive in the object file to link in the library
	specified by the $(ASSIGNEXPRESSION).
	The $(ASSIGNEXPRESSION)s must be a string literal:
-----------------
pragma(lib, "foo.lib");
-----------------
    )
$(V2
    $(DT $(B startaddress))
    $(DD Puts a directive into the object file saying that the
	function specified in the first argument will be the
	start address for the program:
-----------------
void foo() { ... }
pragma(startaddress, foo);
-----------------
	This is not normally used for application level programming,
	but is for specialized systems work.
	For applications code, the start address is taken care of
	by the runtime library.
    )
)

    )

<h2>Vendor Specific Pragmas</h2>

	Vendor specific pragma $(I Identifier)s can be defined if they
	are prefixed by the vendor's trademarked name, in a similar manner
	to version identifiers:

-----------------
pragma(DigitalMars_funky_extension) { ... }
-----------------

	Compilers must diagnose an error for unrecognized $(I Pragma)s,
	even if they are vendor specific ones. This implies that vendor
	specific pragmas should be wrapped in version statements:

-----------------
version (DigitalMars)
{
    pragma(DigitalMars_funky_extension) { ... }
}
-----------------

)

Macros:
	TITLE=Pragmas
	WIKI=Pragma

