Ddoc

$(SPEC_S Conditional Compilation,

	$(P $(I Conditional compilation) is the process of selecting which
	code to compile and which code to not compile.
	(In C and C++, conditional compilation is done with the preprocessor
	directives $(CODE #if) / $(CODE #else) / $(CODE #endif).)
	)

$(GRAMMAR
$(I ConditionalDeclaration):
    $(I Condition) $(I DeclarationBlock)
    $(I Condition) $(I DeclarationBlock) $(B else) $(I DeclarationBlock)
    $(I Condition) $(B :) $(I Declarations)

$(I DeclarationBlock):
    $(I Declaration)
    $(B {) $(I Declarations) $(B })
    $(B { })

$(I Declarations):
    $(I Declaration)
    $(I Declaration) $(I Declarations)

$(I ConditionalStatement):
    $(I Condition) $(I NoScopeNonEmptyStatement)
    $(I Condition) $(I NoScopeNonEmptyStatement) $(B else) $(I NoScopeNonEmptyStatement)
)

	$(P If the $(I Condition) is satisfied, then the following
	$(I DeclarationBlock) or $(I Statement) is compiled in.
	If it is not satisfied, the $(I DeclarationBlock) or $(I Statement)
	after the optional $(CODE else) is compiled in.
	)

	$(P Any $(I DeclarationBlock) or $(I Statement) that is not
	compiled in still must be syntactically correct.
	)

	$(P No new scope is introduced, even if the
	$(I DeclarationBlock) or $(I Statement)
	is enclosed by $(CODE { }).
	)

	$(P $(I ConditionalDeclaration)s and $(I ConditionalStatement)s
	can be nested.
	)

	$(P The $(LINK2 #staticassert, $(I StaticAssert)) can be used
	to issue errors at compilation time for branches of the conditional
	compilation that are errors.
	)

	$(P $(I Condition) comes in the following forms:
	)

$(GRAMMAR
$(I Condition):
    $(LINK2 #version, $(I VersionCondition))
    $(LINK2 #debug, $(I DebugCondition))
    $(LINK2 #staticif, $(I StaticIfCondition))
)

<h2>$(LNAME2 version, Version Condition)</h2>

	$(P Versions enable multiple versions of a module to be implemented
	with a single source file.
	)

$(GRAMMAR
$(I VersionCondition):
	$(B version $(LPAREN)) $(I Integer) $(B $(RPAREN))
	$(B version $(LPAREN)) $(I Identifier) $(B $(RPAREN))
)

	$(P The $(I VersionCondition) is satisfied if the $(I Integer)
	is greater than or equal to the current $(I version level),
	or if $(I Identifier) matches a $(I version identifier).
	)

	$(P The $(I version level) and $(I version identifier) can
	be set on the command line by the $(B -version) switch
	or in the module itself with a $(GLINK VersionSpecification),
	or they can be predefined by the compiler.
	)

	$(P Version identifiers are in their own unique name space, they do
	not conflict with debug identifiers or other symbols in the module.
	Version identifiers defined in one module have no influence
	over other imported modules.
	)

------
int k;
version (Demo)	// compile in this code block for the demo version
{   int i;
    int k;	// error, k already defined

    i = 3;
}
x = i;		// uses the i declared above
------

------
version (X86)
{
    ... // implement custom inline assembler version
}
else
{
    ... // use default, but slow, version
}
------

<h3>Version Specification</h3>

$(GRAMMAR
$(GNAME VersionSpecification)
    $(B version =) $(I Identifier) $(B ;)
    $(B version =) $(I Integer) $(B ;)
)

	$(P The version specification makes it straightforward to group
	a set of features under one major version, for example:
	)

------
version (ProfessionalEdition)
{
    version = FeatureA;
    version = FeatureB;
    version = FeatureC;
}
version (HomeEdition)
{
    version = FeatureA;
}
...
version (FeatureB)
{
    ... implement Feature B ...
}
------

	$(P Version identifiers or levels may not be forward referenced:
	)

------
version (Foo)
{
    int x;
}
version = Foo;	// error, Foo already used
------
	$(P $(I VersionSpecification)s may only appear at module scope.)

	$(P While the debug and version conditions superficially behave the
	same,
	they are intended for very different purposes. Debug statements
	are for adding debug code that is removed for the release version.
	Version statements are to aid in portability and multiple release
	versions.
	)

	$(P Here's an example of a $(I full) version as opposed to
	a $(I demo) version:)

------
class Foo
{
    int a, b;

    version(full)
    {
	int extrafunctionality()
	{
	    ...
	    return 1;		// extra functionality is supported
	}
    }
    else // demo
    {
	int extrafunctionality()
	{
	    return 0;		// extra functionality is not supported
	}
    }
}
------

	Various different version builds can be built with a parameter
	to version:

------
version($(I n)) // add in version code if version level is >= $(I n)
{
   ... version code ...
}

version($(I identifier)) // add in version code if version
                         // keyword is $(I identifier)
{
   ... version code ...
}
------

	$(P These are presumably set by the command line as
	$(TT -version=$(I n)) and $(TT -version=$(I identifier)).
	)


<h3><a name="PredefinedVersions">Predefined Versions</a></h3>

	$(P Several environmental version identifiers and identifier
	name spaces are predefined for consistent usage.
	Version identifiers do not conflict
	with other identifiers in the code, they are in a separate name space.
	Predefined version identifiers are global, i.e. they apply to
	all modules being compiled and imported.
	)

	$(TABLE1
	<caption>Predefined Version Identifiers</caption>
	$(TR $(TH Version Identifier) $(TH Description))
	$(TR $(TD $(B DigitalMars)) $(TD Digital Mars is the compiler vendor))
	$(TR $(TD $(B X86)) $(TD Intel and AMD 32 bit processors))
	$(TR $(TD $(B X86_64)) $(TD AMD and Intel 64 bit processors))
	$(TR $(TD $(B Windows)) $(TD Microsoft Windows systems))
	$(TR $(TD $(B Win32)) $(TD Microsoft 32 bit Windows systems))
	$(TR $(TD $(B Win64)) $(TD Microsoft 64 bit Windows systems))
	$(TR $(TD $(B linux)) $(TD All linux systems))
	$(TR $(TD $(B LittleEndian)) $(TD Byte order, least significant first))
	$(TR $(TD $(B BigEndian)) $(TD Byte order, most significant first))
	$(TR $(TD $(B D_Coverage)) $(TD Coverage analyser is implemented and the $(B -cov) switch is thrown))
	$(TR $(TD $(B D_InlineAsm_X86)) $(TD Inline assembler for X86 is implemented))
	$(V2 $(TR $(TD $(B D_Version2)) $(TD This is a D version 2 compiler)))
	$(TR $(TD $(B none)) $(TD Never defined; used to just disable a section of code))
	$(TR $(TD $(B all)) $(TD Always defined; used as the opposite of $(B none)))
	)

	$(P Others will be added as they make sense and new implementations appear.
	)

	$(P It is inevitable that the D language will evolve over time.
	Therefore, the version identifier namespace beginning with "D_"
	is reserved for identifiers indicating D language specification
	or new feature conformance.
	)

	$(P Furthermore, predefined version identifiers from this list cannot
	be set from the command line or from version statements.
	(This prevents things like both $(B Windows) and $(B linux)
	being simultaneously set.)
	)

	$(P Compiler vendor specific versions can be predefined if the
	trademarked vendor
	identifier prefixes it, as in:
	)

------
version(DigitalMars_funky_extension)
{
    ...
}
------

	$(P It is important to use the right version identifier for the right
	purpose. For example, use the vendor identifier when using a vendor
	specific feature. Use the operating system identifier when using
	an operating system specific feature, etc.
	)


<h2>$(LNAME2 debug, Debug Condition)</h2>

	$(P Two versions of programs are commonly built,
	a release build and a debug build.
	The debug build includes extra error checking code,
	test harnesses, pretty-printing code, etc.
	The debug statement conditionally compiles in its
	statement body.
	It is D's way of what in C is done
	with $(CODE #ifdef DEBUG) / $(CODE #endif) pairs.
	)

$(GRAMMAR
$(I DebugCondition):
    $(B debug)
    $(B debug $(LPAREN)) $(I Integer) $(B $(RPAREN))
    $(B debug $(LPAREN)) $(I Identifier) $(B $(RPAREN))
)

	$(P The $(B debug) condition is satisfied when the $(B -debug) switch is
	thrown on the compiler.
	)

	$(P The $(B debug $(LPAREN)) $(I Integer) $(B $(RPAREN)) condition is satisfied
	when the debug
	level is &gt;= $(I Integer).
	)

	$(P The $(B debug $(LPAREN)) $(I Identifier) $(B $(RPAREN)) condition is satisfied
	when the debug identifier matches $(I Identifier).
	)

------
class Foo
{
	int a, b;
    debug:
	int flag;
}
------


<h3>Debug Specification</h3>

$(GRAMMAR
$(GNAME DebugSpecification)
    $(B debug =) $(I Identifier) $(B ;)
    $(B debug =) $(I Integer) $(B ;)
)

	$(P Debug identifiers and levels are set either by the command line switch
	$(B -debug) or by a $(I DebugSpecification).
	)

	$(P Debug specifications only affect the module they appear in, they
	do not affect any imported modules. Debug identifiers are in their
	own namespace, independent from version identifiers and other
	symbols.
	)

	$(P It is illegal to forward reference a debug specification:
	)

------
debug (foo) writefln("Foo");
debug = foo;	// error, foo used before set
------

	$(P $(I DebugSpecification)s may only appear at module scope.)

	$(P Various different debug builds can be built with a parameter to
	debug:
	)

------
debug($(I Integer)) { }    // add in debug code if debug level is >= $(I Integer)
debug($(I identifier)) { } // add in debug code if debug keyword is $(I identifier)
------

	$(P These are presumably set by the command line as
	$(TT -debug=$(I n)) and $(TT -debug=$(I identifier)).
	)

<h2>$(LNAME2 staticif, Static If Condition)</h2>

$(GRAMMAR
$(I StaticIfCondition):
    $(B static if $(LPAREN)) $(ASSIGNEXPRESSION) $(B $(RPAREN))
)

	$(P $(ASSIGNEXPRESSION) is implicitly converted to a boolean type,
	and is evaluated at compile time.
	The condition is satisfied if it evaluates to $(B true).
	It is not satisfied if it evaluates to $(B false).
	)

	$(P It is an error if $(ASSIGNEXPRESSION) cannot be implicitly converted
	to a boolean type or if it cannot be evaluated at compile time.
	)

	$(P $(I StaticIfCondition)s
	can appear in module, class, template, struct, union, or function scope.
	In function scope, the symbols referred to in the
	$(ASSIGNEXPRESSION) can be any that can normally be referenced
	by an expression at that point.
	)

------
const int i = 3;
int j = 4;

$(B static if) (i == 3)	// ok, at module scope
    int x;

class C
{   const int k = 5;

    $(B static if) (i == 3)	// ok
	int x;
    $(B else)
	long x;

    $(B static if) (j == 3)	// error, j is not a constant
	int y;

    $(B static if) (k == 5)	// ok, k is in current scope
	int z;
}

template INT(int i)
{
    $(B static if) (i == 32)
	alias int INT;
    $(B else static if) (i == 16)
	alias short INT;
    $(B else)
	static assert(0);	// not supported
}

INT!(32) a;	// a is an int
INT!(16) b;	// b is a short
INT!(17) c;	// error, static assert trips
------

	$(P A $(I StaticIfConditional) condition differs from an
	$(I IfStatement) in the following ways:
	)

	$(OL 
	$(LI It can be used to conditionally compile declarations,
	not just statements.
	)
	$(LI It does not introduce a new scope even if $(B { })
	are used for conditionally compiled statements.
	)
	$(LI For unsatisfied conditions, the conditionally compiled code
	need only be syntactically correct. It does not have to be
	semantically correct.
	)
	$(LI It must be evaluatable at compile time.
	)
	)


<h2>$(LNAME2 staticassert, Static Assert)</h2>

$(GRAMMAR
$(I StaticAssert):
    $(B static assert $(LPAREN)) $(ASSIGNEXPRESSION) $(B $(RPAREN);)
    $(B static assert $(LPAREN)) $(ASSIGNEXPRESSION) $(B ,) $(ASSIGNEXPRESSION) $(B $(RPAREN);)
)

	$(P $(ASSIGNEXPRESSION) is evaluated at compile time, and converted
	to a boolean value. If the value is true, the static assert
	is ignored. If the value is false, an error diagnostic is issued
	and the compile fails.
	)

	$(P Unlike $(I AssertExpression)s, $(I StaticAssert)s are always
	checked and evaluted by the compiler unless they appear in an
	unsatisfied conditional.
	)

------
void foo()
{
    if (0)
    {
	assert(0);	  // never trips
	static assert(0); // always trips
    }
    version (BAR)
    {
    }
    else
    {
	static assert(0); // trips when version BAR is not defined
    }
}
------

	$(P $(I StaticAssert) is useful tool for drawing attention to conditional
	configurations not supported in the code.
	)

	$(P The optional second $(ASSIGNEXPRESSION) can be used to supply
	additional information, such as a text string, that will be
	printed out along with the error diagnostic.
	)
)

Macros:
	TITLE=Conditional Compilation
	WIKI=Version

