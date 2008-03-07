Ddoc

$(D_S Overview,

$(SECTION2 What is D?,

	$(P D is a general purpose systems and applications programming language.
	It is a higher level language than C++, but retains the ability
	to write high performance code and interface directly with the
	operating system
	<acronym title="Application Programming Interface">API</acronym>'s
	and with hardware.
	D is well suited to writing medium to large scale
	million line programs with teams of developers. D is easy
	to learn, provides many capabilities to aid the programmer,
	and is well suited to aggressive compiler optimization technology.

	<img src="d3.png" border=0 align=right alt="D Man">
	)

	$(P D is not a scripting language, nor an interpreted language.
	It doesn't
	come with a <acronym title="Virtual Machine">VM</acronym>,
	a religion, or an overriding
	philosophy. It's a practical language for practical programmers
	who need to get the job done quickly, reliably, and leave behind
	maintainable, easy to understand code.
	)

	$(P D is the culmination of decades of experience implementing
	compilers for many diverse languages, and attempting to construct
	large projects using those languages. D draws inspiration from
	those other languages (most especially C++) and tempers it with
	experience and real world practicality.
	)
)


$(SECTION2 Why D?,

	$(P Why, indeed. Who needs another programming language?
	)

	$(P The software industry has come a long way since the C language was
	invented.
	Many new concepts were added to the language with C++, but backwards
	compatibility with C was maintained, including compatibility with
	nearly all the weaknesses of the original design.
	There have been many attempts to fix those weaknesses, but the
	compatibility issue frustrates it.
	Meanwhile, both C and C++ undergo a constant accretion of new
	features. These new features must be carefully fitted into the
	existing structure without requiring rewriting old code.
	The end result is very complicated - the C standard is nearly
	500 pages, and the C++ standard is about 750 pages!
	C++ is a difficult and costly language to implement,
	resulting in implementation variations that make it frustrating
	to write fully portable C++ code.
	)

	$(P C++ programmers tend to program in particular islands of the language,
	i.e. getting very proficient using certain features while avoiding
	other feature sets. While the code is usually portable from compiler
	to compiler, it can be hard to port it from programmer to programmer.
	A great strength of C++ is that it can support many radically
	different styles of programming - but in long term use, the
	overlapping and contradictory styles are a hindrance.
	)

	$(P C++ implements things like resizable arrays and string concatenation
	as part of the standard library, not as part of the core language.
	Not being part of the core language has several
	$(LINK2 cppstrings.html, suboptimal consequences).
	)

	$(P Can the power and capability of C++ be extracted, redesigned,
	and recast into a language that is simple, orthogonal,
	and practical?
	Can it all be put into a package
	that is easy for compiler
	writers to correctly implement, and
	which enables compilers to efficiently generate aggressively
	optimized code?
	)

	$(P Modern compiler technology has progressed to the point where language
	features for the purpose of compensating for primitive compiler
	technology can be omitted. (An 
	example of this would be the 'register' keyword in C, a more
	subtle example is the macro 
	preprocessor in C.)
	We can rely on modern compiler optimization technology to not
	need language features necessary to get acceptable code quality out of
	primitive compilers.
	)

$(SECTION3 Major Goals of D,

    $(UL
	$(LI Reduce software development costs by at least 10% by adding
	in proven productivity enhancing features and by adjusting language
	features so that 
	common, time-consuming bugs are eliminated from the start.)

	$(LI Make it easier to write code that is portable from compiler
	to compiler, machine to machine, and operating system to operating
	system.)

	$(LI Support multi-paradigm programming, i.e. at a minimum support
	imperative, structured, object oriented, and generic programming
	paradigms.)

	$(LI Have a short learning curve for programmers comfortable with
	programming in C or C++.)

	$(LI Provide low level bare metal access as required.)

	$(LI Make D substantially easier to implement a compiler for than C++.)

	$(LI Be compatible with the local C application binary interface.)

	$(LI Have a context-free grammar.)

	$(LI Easily support writing internationalized applications.)

	$(LI Incorporate Contract Programming and unit testing methodology.)

	$(LI Be able to build lightweight, standalone programs.)

	$(LI Reduce the costs of creating documentation.)
    )
)

$(SECTION3 Features To Keep From C/C++,

	$(P The general look of D is like C and C++. This makes it easier to learn
	and port code to D. Transitioning from C/C++ to D should feel natural.
	The 
	programmer will not have to learn an entirely new way of doing things.
	)

	$(P Using D will not mean that the programmer will become restricted to a
	specialized runtime vm (virtual machine) like the Java vm or the
	Smalltalk vm.
	There is no D vm, it's a straightforward compiler that generates
	linkable object files.
	D connects to the operating system just like C does.
	The usual familiar tools like $(B make) will fit right in with
	D development.
	)

    $(UL
	$(LI The general $(B look and feel) of C/C++ is maintained.
	It uses the same algebraic syntax, most of the same expression
	and statement forms, and the general layout.
	)

	$(LI D programs can be written either in
	C style $(B function-and-data),
	C++ style $(B object-oriented),
	C++ style $(B template metaprogramming),
	or any mix of the three.
	)

	$(LI The $(B compile/link/debug) development model is
	carried forward,
	although nothing precludes D from being compiled into bytecode
	and interpreted. 
	)

	$(LI $(B Exception handling).
	More and more experience with exception handling shows it to be a 
	superior way to handle errors than the C traditional method of using
	error codes and errno globals.
	)

	$(LI $(B Runtime Type Identification).
	This is partially implemented in C++;
	in D it is taken to its 
	next logical step. Fully supporting it enables better garbage
	collection, better debugger support, more automated persistence, etc.
	)

	$(LI D maintains function link compatibility with the $(B C calling
	conventions). This makes 
	it possible for D programs to access operating system API's directly.
	Programmers' knowledge and experience with existing programming API's
	and paradigms can be carried forward to D with minimal effort.
	)

	$(LI $(B Operator overloading).
	D programs can overload operators enabling
	extension of the basic types with user defined types.
	)

	$(LI $(B Template Metaprogramming).
	Templates are a way to implement generic programming.
	Other ways include using macros or having a variant data type.
	Using macros is out. Variants are straightforward, but 
	inefficient and lack type checking.
	The difficulties with C++ templates are their
	complexity, they don't fit well into the syntax of the language,
	all the various rules for conversions and overloading fitted on top of
	it, etc. D offers a much simpler way of doing templates.
	)

	$(LI <acronym title="Resource Acquisition Is Initialization">$(B RAII)</acronym>
	(Resource Acquisition Is Initialization).
	RAII techniques are an essential component of writing reliable
	software.
	)

	$(LI $(B Down and dirty programming). D retains the ability to
	do down-and-dirty programming without resorting to referring to
	external modules compiled in a different language. Sometimes,
	it's just necessary to coerce a pointer or dip into assembly
	when doing systems work. D's goal is not to $(I prevent) down
	and dirty programming, but to minimize the need for it in
	solving routine coding tasks.
	)
    )
)

$(SECTION3 Features To Drop,

$(UL
	$(LI C source code compatibility. Extensions to C that maintain
	source compatibility 
	have already been done (C++ and ObjectiveC). Further work in this
	area is hampered by so much legacy code it is unlikely that significant
	improvements can be made.
	)

	$(LI Link compatibility with C++. The C++ runtime object model is just
	too complicated - properly supporting it would essentially imply
	making D a full C++ compiler too.
	)

	$(LI The C preprocessor. Macro processing is an easy way to extend
	a language, adding in faux features that aren't really there (invisible
	to the symbolic debugger). Conditional compilation, layered with
	#include text, macros, token concatenation, etc., essentially forms
	not one language but two merged together with no obvious distinction
	between them. Even worse (or perhaps for the best) the C preprocessor
	is a very primitive macro language. It's time to step back, look at
	what the preprocessor is used for, and design support for those
	capabilities directly into the language.
	)

	$(LI Multiple inheritance. It's a complex
	feature of debatable value. It's very difficult to implement in an
	efficient manner, and compilers are prone to many bugs in implementing
	it. Nearly all the value of
	<acronym title="multiple inheritance">MI</acronym> can be handled with
	single inheritance
	coupled with interfaces and aggregation. What's left does not
	justify the weight of MI implementation.
	)

	$(LI Namespaces. An attempt to deal with the problems resulting from
	linking together independently developed pieces of code that
	have conflicting names. The idea of modules is simpler and works
	much better.
	)

	$(LI Tag name space. This misfeature of C is where the tag names
	of structs are in a separate but parallel symbol table. C++
	attempted to merge the tag name space with the regular name space,
	while retaining backward compatibility with legacy C code. The
	result is needlessly confusing.
	)

	$(LI Forward declarations. C compilers semantically only know
	about what has lexically preceded the current state. C++ extends this
	a little, in that class members can rely on forward referenced class
	members. D takes this to its logical conclusion, forward declarations
	are no longer necessary at the module level.
	Functions can be defined in a natural
	order rather than the typical inside-out order commonly used in C
	programs to avoid writing forward declarations.
	)

	$(LI Include files. A major cause of slow compiles as each
	compilation unit
	must reparse enormous quantities of header files. Include files
	should be done as importing a symbol table.
	)

	$(LI Trigraphs and digraphs. Unicode is the future.
	)

	$(LI Non-virtual member functions. In C++, a class designer decides
	in advance if a function is to be virtual or not. Forgetting to retrofit
	the base class member function to be virtual when the function gets
	overridden is a common (and very hard to find) coding error.
	Making all member functions virtual, and letting the compiler decide
	if there are no overrides and hence can be converted to non-virtual,
	is much more reliable.
	)

	$(LI Bit fields of arbitrary size.
	Bit fields are a complex, inefficient feature rarely used.
	)

	$(LI Support for 16 bit computers.
	No consideration is given in D for mixed near/far pointers and all the
	machinations necessary to generate good 16 bit code. The D language
	design assumes at least a 32 bit flat memory space. D will fit smoothly
	into 64 bit architectures.
	)

	$(LI Mutual dependence of compiler passes. In C++, successfully parsing
	the source text relies on having a symbol table, and on the various
	preprocessor commands. This makes it
	impossible to preparse C++ source, and makes writing code analyzers
	and syntax directed editors painfully difficult to do correctly.
	)

	$(LI Compiler complexity. Reducing the complexity of an implementation
	makes it more likely that multiple, $(I correct) implementations
	are available.
	)

	$(LI Dumbed down floating point. If one is using hardware that
	implements modern floating point, it should be available to the
	programmer rather than having floating point support dumbed down
	to the lowest common denominator among machines. In particular,
	a D implementation must support IEEE 754 arithmetic and if
	extended precision is available it must be supported.)

	$(LI Template overloading of &lt; and &gt; symbols.
	This choice has caused years of bugs, grief, and confusion
	for programmers, C++ implementors, and C++ source parsing tool
	vendors. It makes it
	impossible to parse C++ code correctly without doing a nearly complete
	C++ compiler. D uses !( and ) which fit neatly and
	unambiguously into the grammar.
	)
)
)

$(SECTION3 Who D is For,

$(UL
	$(LI Programmers who routinely use lint or similar code analysis tools
	to eliminate bugs before the code is even compiled.
	)

	$(LI People who compile with maximum warning levels turned on and who 
	instruct the compiler to treat warnings as errors.
	)

	$(LI Programming managers who are forced to rely on programming style 
	guidelines to avoid common C bugs.
	)

	$(LI Those who decide the promise of C++ object oriented
	programming is not fulfilled due to the complexity of it.
	)

	$(LI Programmers who enjoy the expressive power of C++ but are
	frustrated by
	the need to expend much effort explicitly managing memory and finding
	pointer bugs.
	)

	$(LI Projects that need built-in testing and verification.
	)

	$(LI Teams who write apps with a million lines of code in it.
	)

	$(LI Programmers who think the language should provide enough
	features to obviate 
	the continual necessity to manipulate pointers directly.
	)

	$(LI Numerical programmers. D has many features to directly
	support features needed by numerics programmers, like
	extended floating point precision,
	core support for complex and imaginary floating types
	and defined behavior for
	<acronym title="Not A Number">NaN</acronym>'s and infinities.
	(These are added in the new
	C99 standard, but not in C++.)
	)

	$(LI Programmers who write half their application in scripting
	langauges like Ruby and Python, and the other half in C++ to
	speed up the bottlenecks. D has many of the productivity features
	of Ruby and Python, making it possible to write the entire app
	in one language.)

	$(LI D's lexical analyzer and parser are totally independent of each other and of the 
	semantic analyzer. This means it is easy to write simple tools to manipulate D source 
	perfectly without having to build a full compiler. It also means that source code can be 
	transmitted in tokenized form for specialized applications.
	)
)
)

$(SECTION3 Who D is Not For,

    $(UL
	$(LI Realistically, nobody is going to convert million line C or C++
	programs into D.
	Since D does not compile unmodified C/C++
	source code, D is not for 
	legacy apps.
	(However, D supports legacy C API's very well. D can connect
	directly to any code that exposes a C interface.)
	)

	$(LI As a first programming language - Basic or Java is more suitable
	for beginners. D makes an excellent second language for intermediate
	to advanced programmers.
	)

	$(LI Language purists. D is a practical language, and each feature
	of it is evaluated in that light, rather than by an ideal.
	For example, D has constructs and semantics that virtually eliminate
	the need for pointers for ordinary tasks. But pointers are still
	there, because sometimes the rules need to be broken.
	Similarly, casts are still there for those times when the typing
	system needs to be overridden.
	)
    )
)

)



$(SECTION2 Major Features of D,

	$(P This section lists some of the more interesting features of D
	in various categories.
	)

$(SECTION3 Object Oriented Programming,

    $(SECTION4 Classes,

	$(P D's object oriented nature comes from classes.
	The inheritance model is single inheritance enhanced
	with interfaces. The class Object sits at the root
	of the inheritance hierarchy, so all classes implement
	a common set of functionality.
	Classes are instantiated
	by reference, and so complex code to clean up after exceptions
	is not required.
	)
    )

    $(SECTION4 Operator Overloading,

	$(P Classes can be crafted that work with existing operators to extend
	the type system to support new types. An example would be creating
	a bignumber class and then overloading the +, -, * and / operators
	to enable using ordinary algebraic syntax with them.
	)
    )
)

$(SECTION3 Productivity,

    $(SECTION4 Modules,

	$(P Source files have a one-to-one correspondence with modules.
	Instead of #include'ing the text of a file of declarations,
	just import the module. There is no need to worry about
	multiple imports of the same module, no need to wrapper header
	files with $(TT #ifndef/#endif) or $(TT #pragma once) kludges,
	etc.
	)
    )

    $(SECTION4 Declaration vs Definition,

	$(P C++ usually requires that functions and classes be declared twice - the declaration
	that goes in the .h header file, and the definition that goes in the .c source
	file. This is an error prone and tedious process. Obviously, the programmer 
	should only need to write it once, and the compiler should then extract the 
	declaration information and make it available for symbolic importing. This is 
	exactly how D works.
	)

	$(P Example:
	)

-----------------------
class ABC
{
    int func() { return 7; }
    static int z = 7;
}
int q;
-----------------------

	$(P There is no longer a need for a separate definition of member functions, static
	members, externs, nor for clumsy syntaxes like:
	)

$(CCODE
int ABC::func() { return 7; }
int ABC::z = 7;
extern int q;
)

	$(P Note: Of course, in C++, trivial functions like $(TT { return 7; })
	are written inline too, but complex ones are not. In addition, if
	there are any forward references, the functions need to be prototyped.
	The following will not work in C++:
	)

$(CCODE
class Foo
{
    int foo(Bar *c) { return c->bar(); }
};

class Bar
{
  public:
    int bar() { return 3; }
};
)

	$(P But the equivalent D code will work:
	)

-----------------------
class Foo
{
    int foo(Bar c) { return c.bar; }
}

class Bar
{
    int bar() { return 3; }
}
-----------------------

	$(P Whether a D function is inlined or not is determined by the
	optimizer settings.
	)
    )

    $(SECTION4 Templates,

	$(P D templates offer a clean way to support generic programming while
	offering the power of partial specialization.
	Template classes and template functions are available, along
	with variadic template arguments and tuples.
	)
    )

    $(SECTION4 Associative Arrays,

	$(P Associative arrays are arrays with an arbitrary data type as
	the index rather than being limited to an integer index.
	In essence, associated arrays are hash tables. Associative
	arrays make it easy to build fast, efficient, bug-free symbol
	tables.
	)
    )

    $(SECTION4 Real Typedefs,

	$(P C and C++ typedefs are really type $(I aliases), as no new
	type is really introduced. D implements real typedefs, where:
	)

-----------------------
typedef int handle;
-----------------------

	$(P really does create a new type $(B handle). Type checking is
	enforced, and typedefs participate in function overloading.
	For example:
	)

-----------------------
int foo(int i);
int foo(handle h);
-----------------------
    )

    $(SECTION4 Documentation,

	$(P Documentation has traditionally been done twice - first there
	are comments documenting what a function does, and then this gets
	rewritten into a separate html or man page.
	And naturally, over time, they'll tend to diverge as the code
	gets updated and the separate documentation doesn't.
	Being able to generate the requisite polished documentation directly
	from the comments embedded in the source will not only cut the time
	in half needed to prepare documentation, it will make it much easier
	to keep the documentation in sync with the code.
	$(LINK2 ddoc.html, Ddoc) is the specification for the D
	documentation generator. This page was generated by Ddoc, too.
	)

	$(P Although third party tools exist to do this for C++, they have some
	serious shortcomings:

	$(UL

	$(LI It is spectacularly difficult to parse C++ 100% correctly. To
	do so really requires a full C++ compiler. Third party tools tend to
	parse only a subset of C++ correctly, so their use will constrain
	the source code to that subset.)

	$(LI Different compilers support different versions of C++ and have
	different extensions to C++. Third party tools have a problem matching
	all these variations.)

	$(LI Third party tools may not be available for all the desired
	platforms, and they're necessarily on a different upgrade cycle
	from the compilers.)

	$(LI Having it builtin to the compiler means it is standardized across
	all D implementations. Having a default one ready to go at all times
	means it is far more likely to be used.)

	)
	)
    )
)

$(SECTION3 Functions,

	$(P D has the expected support for ordinary functions including
	global functions, overloaded functions, inlining of functions,
	member functions, virtual functions, function pointers, etc.
	In addition:
	)

    $(SECTION4 Nested Functions,

	$(P Functions can be nested within other functions.
	This is highly useful for code factoring, locality, and
	function closure techniques.
	)
    )

    $(SECTION4 Function Literals,

	$(P Anonymous functions can be embedded directly into an expression.
	)
    )

    $(SECTION4 Dynamic Closures,

	$(P Nested functions and class member functions can be referenced
	with closures (also called delegates), making generic programming
	much easier and type safe.
	)
    )

    $(SECTION4 In Out and Inout Parameters,

	$(P Not only does specifying this help make functions more
	self-documenting, it eliminates much of the necessity for pointers
	without sacrificing anything, and it opens up possibilities
	for more compiler help in finding coding problems.
	)

	$(P Such makes it possible for D to directly interface to a
	wider variety of foreign API's. There would be no need for
	workarounds like "Interface Definition Languages".
	)
    )
)

$(SECTION3 Arrays,

	$(P C arrays have several faults that can be corrected:
	)

	$(UL

	$(LI Dimension information is not carried around with
	the array, and so has to be stored and passed separately.
	The classic example of this are the argc and argv
	parameters to $(TT main(int $(D_PARAM argc), char *$(D_PARAM argv)[])).
	(In D, main is declared as $(TT main(char[][] $(D_PARAM args))).)
	)

	$(LI Arrays are not first class objects. When an array	is passed to a function, it is
	converted to a pointer, even though the prototype confusingly says it's an 
	array. When this conversion happens, all array type information
	gets lost.
	)

	$(LI C arrays cannot be resized. This means that even simple aggregates like a stack 
	need to be constructed as a complex class.)

	$(LI C arrays cannot be bounds checked, because they don't know
	what the array bounds are.)

	$(LI Arrays are declared with the [] after the identifier. This leads to
	very clumsy 
	syntax to declare things like a pointer to an array:

$(CCODE
int (*array)[3];
)

	$(P In D, the [] for the array go on the left:
	)

-----------------------
int[3]* array;		// declares a pointer to an array of 3 ints
long[] func(int x);	// declares a function returning an array of longs
-----------------------

	$(P which is much simpler to understand.
	)
	)
	)

	$(P D arrays come in several varieties: pointers, static arrays, dynamic
	arrays, and associative arrays.
	)

	$(P See $(LINK2 arrays.html, Arrays).
	)

    $(SECTION4 Strings,

	$(P String manipulation is so common, and so clumsy in C and C++, that
	it needs direct support in the language. Modern languages handle
	string concatenation, copying, etc., and so does D. Strings are
	a direct consequence of improved array handling.
	)
    )
)

$(SECTION3 Resource Management,

    $(SECTION4 Automatic Memory Management,

	$(P D memory allocation is fully garbage collected. Empirical experience
	suggests that a lot of the complicated features of C++ are necessary
	in order to manage memory deallocation. With garbage collection, the
	language gets much simpler.
	)

	$(P There's a perception that garbage collection is for lazy, junior
	programmers. I remember when that was said about C++, after all,
	there's nothing in C++ that cannot be done in C, or in assembler
	for that matter.
	)

	$(P Garbage collection eliminates the tedious, error prone memory
	allocation
	tracking code necessary in C and C++. This not only means much
	faster development time and lower maintenance costs,
	but the resulting program frequently runs
	faster!
	)

	$(P Sure, garbage collectors can be used with C++, and I've used them
	in my own C++ projects. The language isn't friendly to collectors,
	however, impeding the effectiveness of it. Much of the runtime
	library code can't be used with
	collectors.
	)

	$(P For a fuller discussion of this, see
	$(LINK2 garbage.html, garbage collection).
	)
    )

    $(SECTION4 Explicit Memory Management,

	$(P Despite D being a garbage collected language, the new and delete
	operations can be overridden for particular classes so that
	a custom allocator can be used.
	)
    )

    $(SECTION4 RAII,

	$(P RAII is a modern software development technique to manage resource
	allocation and deallocation. D supports RAII in a controlled,
	predictable manner that is independent of the garbage collection
	cycle.
	)
    )
)


$(SECTION3 Performance,

    $(SECTION4 Lightweight Aggregates,

	$(P D supports simple C style structs, both for compatibility with
	C data structures and because they're useful when the full power
	of classes is overkill.
	)
    )

    $(SECTION4 Inline Assembler,

	$(P Device drivers, high performance system applications, embedded systems,
	and specialized code sometimes need to dip into assembly language
	to get the job done. While D implementations are not required
	to implement the inline assembler, it is defined and part of the
	language. Most assembly code needs can be handled with it,
	obviating the need for separate assemblers or DLL's.
	)

	$(P Many D implementations will also support intrinsic functions
	analogously to C's support of intrinsics for I/O port manipulation,
	direct access to special floating point operations, etc.
	)
    )
)


$(SECTION3 Reliability,

	$(P A modern language should do all it can to help the programmer flush
	out bugs in the code. Help can come in many forms;
	from making it easy to use more robust techniques, 
	to compiler flagging of obviously incorrect code, to runtime checking.
	)

    $(SECTION4 Contracts,

	$(P Contract Programming (invented by B. Meyer) is a revolutionary
	technique
	to aid in ensuring the correctness of programs. D's version of
	DBC includes function preconditions, function postconditions, class
	invariants, and assert contracts.
	See $(LINK2 dbc.html, Contracts) for D's implementation.
	)
    )

    $(SECTION4 Unit Tests,

	$(P Unit tests can be added to a class, such that they are automatically
	run upon program startup. This aids in verifying, in every build,
	that class implementations weren't inadvertently broken. The unit
	tests form part of the source code for a class. Creating them
	becomes a natural part of the class development process, as opposed
	to throwing the finished code over the wall to the testing group.
	)

	$(P Unit tests can be done in other languages, but the result is kludgy
	and the languages just aren't accommodating of the concept.
	Unit testing is a main feature of D. For library functions it works
	out great, serving both to guarantee that the functions
	actually work and to illustrate how to use the functions.
	)

	$(P Consider the many C++ library and application code bases out there for
	download on the web. How much of it comes with *any* verification
	tests at all, let alone unit testing? Less than 1%? The usual practice
	is if it compiles, we assume it works. And we wonder if the warnings
	the compiler spits out in the process are real bugs or just nattering
	about nits.
	)

	$(P Along with Contract Programming, unit testing makes D far and away
	the best language for writing reliable, robust systems applications.
	Unit testing also gives us a quick-and-dirty estimate of the quality
	of some unknown piece of D code dropped in our laps - if it has no
	unit tests and no contracts, it's unacceptable.
	)
    )


    $(SECTION4 Debug Attributes and Statements,

	$(P Now debug is part of the syntax of the language.
	The code can be enabled or disabled at compile time, without the
	use of macros or preprocessing commands. The debug syntax enables
	a consistent, portable, and understandable recognition that real
	source code needs to be able to generate both debug compilations and
	release compilations.
	)
    )

    $(SECTION4 Exception Handling,

	$(P The superior $(I try-catch-finally) model is used rather than just
	try-catch. There's no need to create dummy objects just to have
	the destructor implement the $(I finally) semantics.
	)
    )

    $(SECTION4 Synchronization,

	$(P Multithreaded programming is becoming more and more mainstream,
	and D provides primitives to build multithreaded programs with.
	Synchronization can be done at either the method or the object level.
	)

-----------------------
synchronized int func() { ... }
-----------------------

	$(P Synchronized functions allow only one thread at a time to be
	executing that function.
	)

	$(P The synchronize statement puts a mutex around a block of statements,
	controlling access either by object or globally.
	)
    )

    $(SECTION4 Support for Robust Techniques,

	$(UL
	$(LI Dynamic arrays instead of pointers)

	$(LI Reference variables instead of pointers)

	$(LI Reference objects instead of pointers)

	$(LI Garbage collection instead of explicit memory management)

	$(LI Built-in primitives for thread synchronization)

	$(LI No macros to inadvertently slam code)

	$(LI Inline functions instead of macros)

	$(LI Vastly reduced need for pointers)

	$(LI Integral type sizes are explicit)

	$(LI No more uncertainty about the signed-ness of chars)

	$(LI No need to duplicate declarations in source and header files.)

	$(LI Explicit parsing support for adding in debug code.)
	)
    )

    $(SECTION4 Compile Time Checks,

	$(UL
	$(LI Stronger type checking)

	$(LI No empty ; for loop bodies)

	$(LI Assignments do not yield boolean results)

	$(LI Deprecating of obsolete API's)
	)
    )

    $(SECTION4 Runtime Checking,

	$(UL
	$(LI assert() expressions)

	$(LI array bounds checking)

	$(LI undefined case in switch exception)

	$(LI out of memory exception)

	$(LI In, out, and class invariant Contract Programming support)
	)
    )
)

$(SECTION3 Compatibility,

    $(SECTION4 Operator precedence and evaluation rules,

	$(P D retains C operators and their precedence rules, order of
	evaluation rules, and promotion rules. This avoids subtle
	bugs that might arise from being so used to the way C
	does things that one has a great deal of trouble finding
	bugs due to different semantics.
	)
    )

    $(SECTION4 Direct Access to C API's,

	$(P Not only does D have data types that correspond to C types,
	it provides direct access to C functions. There is no need
	to write wrapper functions, parameter swizzlers, nor code to copy
	aggregate members one by one.
	)
    )

    $(SECTION4 Support for all C data types,

	$(P Making it possible to interface to any C API or existing C
	library code. This support includes structs, unions, enums,
	pointers, and all C99 types.
	D includes the capability to
	set the alignment of struct members to ensure compatibility with
	externally imposed data formats.
	)
    )

    $(SECTION4 OS Exception Handling,

	$(P D's exception handling mechanism will connect to the way
	the underlying operating system handles exceptions in
	an application.
	)
    )

    $(SECTION4 Uses Existing Tools,

	$(P D produces code in standard object file format, enabling the use
	of standard assemblers, linkers, debuggers, profilers, exe compressors,
	and other analyzers, as well as linking to code written in other
	languages.
	)
    )
)

$(SECTION3 Project Management,

    $(SECTION4 Versioning,

	$(P D provides built-in support for generation of multiple versions
	of a program from the same text. It replaces the C preprocessor
	#if/#endif technique.
	)
    )

    $(SECTION4 Deprecation,

	$(P As code evolves over time, some old library code gets replaced
	with newer, better versions. The old versions must be available
	to support legacy code, but they can be marked as $(I deprecated).
	Code that uses deprecated versions will be normally flagged
	as illegal, but would be allowed by a compiler switch.
	This will make it easy for maintenance
	programmers to identify any dependence on deprecated features.
	)
    )
)
)


$(SECTION2 Sample D Program (sieve.d),

--------------------------
/* Sieve of Eratosthenes prime numbers */

import std.stdio;

bool[8191] flags;
 
int main()
{   int i, count, prime, k, iter;

    writefln("10 iterations");
    for (iter = 1; iter <= 10; iter++)
    {	count = 0;
	flags[] = 1;
	for (i = 0; i < flags.length; i++)
	{   if (flags[i])
	    {	prime = i + i + 3;
		k = i + prime;
		while (k < flags.length)
		{
		    flags[k] = 0;
		    k += prime;
		}
		count += 1;
	    }
	}
    }
    writefln("%d primes", count);
    return 0;
}
--------------------------
)

)

Macros:
	TITLE=Overview
	WIKI=Overview

