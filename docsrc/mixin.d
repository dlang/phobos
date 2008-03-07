Ddoc

$(D_S Mixins,

	$(P Mixins (not to be confused with
	$(LINK2 template-mixin.html, template mixins))
	enable string constants to be compiled as regular D code
	and inserted into the program.
	Combining this with compile time manipulation of strings
	enables the creation of domain-specific languages.
	)

	$(P For example, here we can create a template that generates
	a struct with the named members:
	)

---
template GenStruct(char[] Name, char[] M1)
{
    const char[] GenStruct = "struct " ~ Name ~ "{ int " ~ M1 ~ "; }";
}

mixin(GenStruct!("Foo", "bar"));
---
	$(P which generates:)
---
struct Foo { int bar; }
---


	$(P Superficially, since D mixins can manipulate text and compile
	the result, it has some similar properties to the C preprocessor.
	But there are major, fundamental differences:
	)

$(UL

	$(LI The C preprocessing step occurs $(B before) lexical analysis.
	This makes it impossible to lex or parse C without access to
	all of the context, including all #include'd files, paths and all
	relevant compiler switches.

	Mixins occur during semantic analysis, and do not affect
	the lexing or parsing process.
	Lexing and parsing can still occur without semantic analysis.
	)


	$(LI The C preprocessor can be used to create what appears to
	be different syntax:

$(CCODE
#define BEGIN {
#define END   }

BEGIN
  int x = 3;
  foo(x);
END
)

	This monkey business is impossible with mixins.
	Mixed in text must form complete declarations,
	statements, or expressions.
	)

	$(LI C macros will affect everything following that has
	the same name, even if they are in nested scopes.
	C macros cut across all scopes.
	This problem is called being not "coding hygenic".

	Mixins follow the usual scoping rules, and is
	hygenic.
	)

	$(LI C preprocessing expressions follow a different syntax
	and have different semantic rules than the C language.
	The C preprocessor is technically a different language.

	Mixins are in the same language.
	)

	$(LI C const declarations and C++ templates are invisible
	to C preprocessing.

	Mixins can be manipulated using templates and const
	declarations.
	)
)

)

Macros:
	TITLE=Mixins
	WIKI=Mixins



