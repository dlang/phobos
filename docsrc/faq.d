Ddoc

$(D_S FAQ,

	$(P The same questions keep cropping up, so the obvious thing to do is
	prepare a FAQ.)

	$(UL

	$(LI $(LINK2 http://www.wikiservice.at/wiki4d/wiki.cgi?FaqRoadmap, The D wiki FAQ page)
	with many more questions answered)
	$(LI $(LINK2 comparison.html, What does D have that C++ doesn't?))
	$(ITEMR q1, Why the name D?)
	$(ITEMR q1_1, When can I get a D compiler?)
	$(ITEMR q1_2, Is there linux port of D?)
	$(ITEMR gdc, Is there a GNU version of D?)
	$(ITEMR backend, How do I write my own D compiler for CPU X?)
	$(ITEMR gui, Where can I get a GUI library for D?)
	$(ITEMR ide, Where can I get an IDE for D?)
	$(ITEMR q2, What about templates?)
	$(ITEMR q3, Why emphasize implementation ease?)
	$(ITEMR q4, Why is [expletive deleted] printf left in?)
	$(ITEMR q5, Will D be open source?)
	$(ITEMR q6, Why fall through on switch statements?)
	$(ITEMR q7, Why should I use D instead of Java?)
	$(ITEMR q7_2, Doesn't C++ support strings, bit arrays, etc. with STL?)
	$(ITEMR q7_3, Can't garbage collection be done in C++ with an add-on library?)
	$(ITEMR q7_4, Can't unit testing be done in C++ with an add-on library?)
	$(ITEMR q8, Why have an asm statement in a portable language?)
	$(ITEMR real, What is the point of 80 bit reals?)
	$(ITEMR anonymous, How do I do anonymous struct/unions in D?)
	$(ITEMR printf, How do I get printf() to work with strings?)
	$(ITEMR nan, Why are floating point values default initialized to NaN rather than 0?)
	$(ITEMR assignmentoverloading, Why is overloading of the assignment operator not supported?)
	$(ITEMR keys, The '~' is not on my keyboard?)
	$(ITEMR omf, Can I link in C object files created with another compiler?)
	$(ITEMR regexp_literals, Why not support regular expression literals
		with the /foo/g syntax?)
	$(ITEMR dogfood, Why is the D front end written in C++ rather than D?)
	$(ITEMR cpp_to_D, Why aren't all Digital Mars programs translated to D?)
	$(ITEMR foreach, When should I use a foreach loop rather than a for?)
	$(ITEMR cpp_interface, Why doesn't D have an interface to C++ as well as C?)
	$(ITEMR reference-counting, Why doesn't D use reference counting for garbage collection?)
	$(ITEMR gc_1, Isn't garbage collection slow and non-deterministic?)
$(V2
	$(ITEMR const, Why does D have const?)
)
	)

$(ITEM q1, Why the name D?)

	$(P The original name was the Mars Programming Language. But my friends
	kept calling it D, and I found myself starting to call it D.
	The idea of D being a successor to C goes back at least as far as 1988,
	as in this
	$(LINK2 http://groups.google.com/groups?q=%22d+programming+language&amp;hl=en&amp;lr=&amp;ie=UTF8&amp;oe=UTF8&amp;selm=12055%40brl-adm.ARPA&amp;rnum=1, thread).
	)

$(ITEM q1_1, Where can I get a D compiler?)

	$(P Right $(LINK2 dcompiler.html, here).
	)

$(ITEM q1_2, Is there a linux port of D?)

	$(P Yes, the D compiler includes a linux version.
	)

$(ITEM gdc, Is there a GNU version of D?)

	$(P Yes, David Friedman has integrated the
	$(LINK2 http://dgcc.sourceforge.net/, D frontend with GCC).
	)

$(ITEM backend, How do I write my own D compiler for CPU X?)

	$(P Burton Radons has written a
	<a href="http://www.opend.org/dli/DLinux.html">back end</a>.
	you can use as a guide.
	)

$(ITEM gui, Where can I get a GUI library for D?)

	$(P Since D can call C functions, any GUI library with a C interface is 
	accessible from D. Various D GUI libraries and ports can be found at 
	<a href="http://www.prowiki.org/wiki4d/wiki.cgi?AvailableGuiLibraries">AvailableGuiLibraries</a>.
	)

$(ITEM ide, Where can I get an IDE for D?)

	$(P Try
	$(LINK2 http://www.dsource.org/projects/elephant/, Elephant),
	$(LINK2 http://www.dsource.org/projects/poseidon/, Poseidon),
	or $(LINK2 http://www.dsource.org/projects/leds/, LEDS).
	)

$(ITEM q2, What about templates?)

	$(P D now supports advanced templates.
	)

$(ITEM q3, Why emphasize implementation ease?)

	$(P Isn't ease of use for the user of the language more important? Yes,
	it is.
	But a vaporware language is useless to everyone. The easier a language
	is to implement, the more robust implementations there will be. In C's
	heyday, there were 30 different commercial C compilers for the IBM PC.
	Not many made the transition to C++. In looking at
	the C++ compilers on the market today, how many years of development
	went into each? At least 10 years? Programmers waited years
	for the various pieces of C++ to get implemented after they were
	specified.
	If C++ was not so enormously popular, it's doubtful that very complex
	features
	like multiple inheritance, templates, etc., would ever have been
	implemented.
	)

	$(P I suggest that if a language is easier to implement, then it is
	likely also easier to understand. Isn't it better to spend time learning
	to write better programs than language arcana? If a language can capture
	90% of the power of
	C++ with 10% of its complexity, I argue that is a worthwhile tradeoff.
	)


$(ITEM q4, Why is printf in D?)

	$(P $(B printf) is not part of D, it is part of C's standard
	runtime library which is accessible from D.
	D's standard runtime library has $(B std.stdio.writefln),
	which is as powerful as $(B printf) but much easier to use.
	)


$(ITEM q5, Will D be open source?)

	$(P The front end for D is open source, and the source comes with the
	$(LINK2 dcompiler.html, compiler).
	The runtime library is completely open source.
	David Friedman has integrated the
	$(LINK2 http://home.earthlink.net/~dvdfrdmn/d, D frontend with GCC)
	to create $(B gdc), a completely open source implementation of D.
	)

$(ITEM q6, Why fall through on switch statements?)

	$(P Many people have asked for a requirement that there be a break between
	cases in a switch statement, that C's behavior of silently falling through
	is the cause of many bugs.
	)

	$(P The reason D doesn't change this is for the same reason that integral
	promotion rules and operator precedence rules were kept the same - to
	make code that looks the same as in C operate the same. If it had subtly
	different semantics, it will cause frustratingly subtle bugs.
	)


$(ITEM q7, Why should I use D instead of Java?)

	D is distinct from Java in purpose, philosophy and reality.
	See this <a href="comparison.html">comparison</a>.
	<p>

	Java is designed to be write once, run everywhere. D is designed for writing
	efficient native system apps. Although D and Java share the notion that
	garbage collection is good and multiple inheritance is bad &lt;g&gt;, their
	different design goals mean the languages have very different feels.

$(ITEM q7_2, Doesn't C++ support strings, bit arrays, etc. with STL?)

	$(P In the C++ standard library are mechanisms for doing strings,
	bit arrays, dynamic arrays, associative arrays, bounds checked
	arrays, and complex numbers.
	)

	$(P Sure, all this stuff can be done with libraries,
	following certain coding disciplines, etc. But you can also do
	object oriented programming in C (I've seen it done).
	Isn't it incongruous that something like strings,
	supported by the simplest BASIC interpreter, requires a very
	large and complicated infrastructure to support?
	Just the implementation of a string type in STL is over two
	thousand lines of code, using every advanced feature of templates.
	How much confidence can you have that this is all working
	correctly, how do you fix it if it is not, what do you do with the
	notoriously inscrutable error messages when there's an error
	using it, how can you be sure you are using it correctly
	(so there are no memory leaks, etc.)?
	)

	$(P D's implementation of strings is simple and straightforward.
	There's little doubt about how to use it, no worries about memory leaks,
	error messages are to the point, and it isn't hard to see if it
	is working as expected or not.
	)

$(ITEM q7_3, Can't garbage collection be done in C++ with an add-on library?)

	Yes, I use one myself. It isn't part of the language, though, and
	requires some subverting of the language to make it work.
	Using gc with C++ isn't for the standard or casual C++ programmer.
	Building it into the
	language, like in D, makes it practical for everyday programming chores.
	<p>

	GC isn't that hard to implement, either, unless you're building one
	of the more advanced ones. But a more advanced one is like building
	a better optimizer - the language still works 100% correctly even
	with a simple, basic one. The programming community is better served
	by multiple implementations competing on quality of code generated
	rather than by which corners of the spec are implemented at all.

$(ITEM q7_4, Can't unit testing be done in C++ with an add-on library?)

	Sure. Try one out and then compare it with how D does it.
	It'll be quickly obvious what an improvement building it into
	the language is.

$(ITEM q8, Why have an asm statement in a portable language?)

	An asm statement allows assembly code to be inserted directly into a D
	function. Assembler code will obviously be inherently non-portable. D is
	intended, however, to be a useful language for developing systems apps.
	Systems apps almost invariably wind up with system dependent code in them
	anyway, inline asm isn't much different. Inline asm will be useful for
	things like accessing special CPU instructions, accessing flag bits, special
	computational situations, and super optimizing a piece of code.
	<p>

	Before the C compiler had an inline assembler, I used external assemblers.
	There was constant grief because many, many different versions of the
	assembler were out there, the vendors kept changing the syntax of the
	assemblers, there were many different bugs in different versions, and even
	the command line syntax kept changing. What it all meant was that users
	could not reliably rebuild any code that needed assembler. An inline
	assembler provided reliability and consistency.

$(ITEM real, What is the point of 80 bit reals?)

	More precision enables more accurate floating point computations
	to be done, especially when adding together large numbers of small
	real numbers. Prof. Kahan, who designed the Intel floating point
	unit, has an eloquent
	<a href="http://http.cs.berkeley.edu/~wkahan/JAVAhurt.pdf">paper</a>
	on the subject.

$(ITEM anonymous, How do I do anonymous struct/unions in D?)

-----------------------
import std.stdio;

struct Foo
{
    union { int a; int b; }
    struct { int c; int d; }
}

void main()
{
    writefln(
      "Foo.sizeof = %d, a.offset = %d, b.offset = %d, c.offset = %d, d.offset = %d",
      Foo.sizeof,
      Foo.a.offsetof,
      Foo.b.offsetof,
      Foo.c.offsetof,
      Foo.d.offsetof);
}
-----------------------

$(ITEM printf, How do I get printf() to work with strings?)

	In C, the normal way to printf a string is to use the $(B %s)
	format:

$(CCODE
char s[8];
strcpy(s, "foo");
printf("string = '$(B %s)'\n", s);
)

	Attempting this in D, as in:

---------------------------------
char[] s;
s = "foo";
printf("string = '$(B %s)'\n", s);
---------------------------------

	usually results in garbage being printed, or an access violation.
	The cause is that in C, strings are terminated by a 0 character.
	The $(B %s) format prints until a 0 is encountered.
	In D, strings are not 0 terminated, the size is determined
	by a separate length value. So, strings are printf'd using the
	$(B %.*s) format:

---------------------------------
char[] s;
s = "foo";
printf("string = '$(B %.*s)'\n", s);
---------------------------------

	$(P which will behave as expected.
	Remember, though, that printf's $(B %.*s) will print until the length
	is reached or a 0 is encountered, so D strings with embedded 0's
	will only print up to the first 0.
	)

	$(P Of course, the easier solution is just use $(B std.stdio.writefln)
	which works correctly with D strings.
	)

$(ITEM nan, Why are floating point values default initialized to NaN rather than 0?)

	A floating point value, if no explicit initializer is given,
	is initialized to NaN (Not A Number):

---------------------------------
double d;	// d is set to double.nan
---------------------------------

	NaNs have the interesting property in that whenever a NaN is
	used as an operand in a computation, the result is a NaN. Therefore,
	NaNs will propagate and appear in the output whenever a computation
	made use of one. This implies that a NaN appearing in the output
	is an unambiguous indication of the use of an uninitialized
	variable.
	<p>

	If 0.0 was used as the default initializer for floating point
	values, its effect could easily be unnoticed in the output, and so
	if the default initializer was unintended, the bug may go
	unrecognized.
	<p>

	The default initializer value is not meant to be a useful value,
	it is meant to expose bugs. Nan fills that role well.
	<p>

	But surely the compiler can detect and issue an error message
	for variables used that are not initialized? Most of the time,
	it can, but not always, and what it can do is dependent on the
	sophistication of the compiler's internal data flow analysis.
	Hence, relying on such is unportable and unreliable.
	<p>

	Because of the way CPUs are designed, there is no NaN value for
	integers, so D uses 0 instead. It doesn't have the advantages of
	error detection that NaN has, but at least errors resulting from
	unintended default initializations will be consistent and therefore more
	debuggable.

$(ITEM assignmentoverloading, Why is overloading of the assignment operator not supported?)

	Most of the assignment operator overloading in C++ seems to be needed to
	just keep track of who owns the memory. So by using reference types
	coupled with GC, most of this just gets replaced with copying the
	reference itself. For example, given an array of class objects, the
	array's contents can be moved, sorted, shifted, etc., all without any
	need for overloaded assignments. Ditto for function parameters and
	return values. The references themselves just get moved about. There
	just doesn't seem to be any need for copying the entire contents of one
	class object into another pre-existing class object.
	<p>

	Sometimes, one does need to create a copy of a class object, and for
	that one can still write a copy constructor in D, but they just don't
	seem to be needed remotely as much as in C++.
	<p>

	Structs, being value objects, do get copied about. A copy is defined in
	D to be a bit copy. I've never been comfortable with any object in C++
	that does something other than a bit copy when copied. Most of this
	other behavior stems from that old problem of trying to manage memory.
	Absent that, there doesn't seem to be a compelling rationale for
	having anything other than a bit copy.

$(ITEM keys, The '~' is not on my keyboard?)

	$(P On PC keyboards, hold down the [Alt] key and press the 1, 2, and 6
	keys in sequence on the numeric pad. That will generate a '~'
	character.
	)

$(ITEM omf, Can I link in C object files created with another compiler?)


	DMD produces OMF (Microsoft Object Module Format) object 
	files while other compilers such as VC++ produce COFF object
	files.
	DMD's output is designed to work with DMC, the Digital Mars C
	compiler, which also produces object files in OMF format.
	<p>

	The OMF format that DMD uses is a Microsoft defined format based on an
	earlier Intel designed one. Microsoft at one point decided to abandon it
	in favor of a Microsoft defined variant on COFF.
	<p>

	Using the same object format doesn't mean that any C library in that
	format will successfully link and run. There is a lot more compatibility
	required - such as calling conventions, name mangling, compiler helper
	functions, and hidden assumptions about the way things work. If DMD
	produced Microsoft COFF output files, there is still little chance that
	they would work successfully with object files designed and tested for
	use with VC. There were a lot of problems with this back when
	Microsoft's compilers did generate OMF.
	<p>

	Having a different object file format makes it helpful in identifying
	library files that were not tested to work with DMD. If they are not,
	weird problems would result even if they successfully managed to link
	them together. It really takes an expert to get a binary built with a
	compiler from one vendor to work with the output of another vendor's
	compiler.
	<p>

	That said, the linux version of DMD produces object files in the ELF
	format which is standard on linux, and it is specifically designed to
	work with the standard linux C compiler, gcc.
	<p>

	There is one case where using existing C libraries does work - when
	those libraries come in the form of a DLL conforming to the usual C ABI
	interface. The linkable part of this is called an "import library", and
	Microsoft COFF format import libraries can be successfully converted to
	DMD OMF using the
	<a href="http://www.digitalmars.com/ctg/coff2omf.html">coff2omf</a>
	tool.

$(ITEM regexp_literals, Why not support regular expression literals
	with the $(TT /foo/g) syntax?)

	$(P There are two reasons:
	)

	$(OL

	$(LI The $(TT /foo/g) syntax would make it impossible to separate
	the lexer from the parser, as / is the divide token.)

	$(LI There are already 3 string types; adding the regex literals
	would add 3 more. This would proliferate through much of the compiler,
	debugger info, and library, and is not worth it.)

	)

$(ITEM dogfood, Why is the D front end written in C++ rather than D?)

	$(P The front end is in C++ in order to interface to the existing gcc
	and dmd back ends. 
	It's also meant to be easily interfaced to other existing back ends,
	which are likely written in C++.
	The D implementation of
	$(LINK2 http://www.digitalmars.com/dscript/index.html, DMDScript),
	which performs better than the
	$(LINK2 http://www.digitalmars.com/dscript/cppscript.html, C++ version),
	shows that there is no problem
	writing a professional quality compiler in 100% D.
	)

$(ITEM cpp_to_D, Why aren't all Digital Mars programs translated to D?)

	$(P There is little benefit to translating a complex, debugged, working
	application from one language to another. But new Digital Mars apps are
	implemented in D.)


$(ITEM foreach, When should I use a foreach loop rather than a for?)

	$(P Is it just performance or readability?
	)

	$(P By using foreach, you are letting the compiler decide on the
	optimization rather than worrying about it yourself. For example - are
	pointers or indices better?
	Should I cache the termination condition or not?
	Should I rotate the loop or not?
	The answers to these questions are not easy, and can vary from machine
	to machine. Like register assignment, let the compiler do the
	optimization.)

---
for (int i = 0; i < foo.length; i++)
---

or:

---
for (int i = 0; i < foo.length; ++i)
---

or:

---
for (T* p = &foo[0]; p < &foo[length]; p++)
---

or:

---
T* pend = &foo[length];
for (T* p = &foo[0]; p < pend; ++p)
---

or:

---
T* pend = &foo[length];
T* p = &foo[0];
if (p < pend)
{
	do
	{
	...
	} while (++p < pend);
}
---

and, of course, should I use size_t or int?

---
for (size_t i = 0; i < foo.length; i++)
---

Let the compiler pick!

---
foreach (v; foo)
	...
---

$(P Note that we don't even need to know what the type T needs to be, thus
avoiding bugs when T changes. I don't even have to know if foo is an array, or
an associative array, or a struct, or a collection class. This will also avoid
the common fencepost bug:)

---
for (int i = 0; i <= foo.length; i++)
---

$(P And it also avoids the need to manually create a temporary if foo is a
function call.)

$(P The only reason to use a for loop is if your loop does not fit in the
conventional form, like if you want to change
the termination condition on the fly.)


$(ITEM cpp_interface, Why doesn't D have an interface to C++ as well as C?)

$(V2
	$(P D 2.0 does have a
	$(LINK2 cpp_interface.html, limited interface to C++ code.)
	) Here are some reasons why it isn't a full interface:
)

	$(P Attempting to have D interface with C++ is 
	nearly as complicated as writing a C++ compiler, which would destroy the 
	goal of having D be a reasonably easy language to implement.
	For people with an existing C++ code base that they must work with, they are 
	stuck with C++ (they can't move it to any other language, either).)

	$(P There are many issues that would have to be resolved in order for D
	code to call some arbitrary C++ code that is presumed to be unmodifiable. This
	list certainly isn't complete, it's just to show the scope of the
	difficulties involved.
	)

	$(OL
	$(LI D source code is unicode, C++'s is ASCII with code pages. Or not.
	It's unspecified. This impacts the contents of string literals.)

	$(LI std::string cannot deal with multibyte UTF.)

	$(LI C++ has a tag name space. D does not. Some sort of renaming would
	have to happen.)

	$(LI C++ code often relies on compiler specific extensions.)

	$(LI C++ has namespaces. D has modules. There is no obvious mapping
	between the two.)

	$(LI C++ views source code as one gigantic file (after preprocessing). D
	sees source code as a hierarchy of modules and packages.)

	$(LI Enum name scoping rules behave differently.)

	$(LI C++ code, despite decades of attempts to replace macro features
	with inbuilt ones, relies more heavily than ever on layer after layer of
	arbitrary macros. There is no D analog for token pasting or
	stringizing.)

	$(LI Macro names have global scope across #include files, but are local
	to the gigantic source files.)

	$(LI C++ has arbitrary multiple inheritance and virtual base classes. D
	does not.)

	$(LI C++ does not distinguish between in, out and ref (i.e. inout) parameters.)

	$(LI The C++ name mangling varies from compiler to compiler.)

	$(LI C++ throws exceptions of arbitrary type, not just descendants of
	Object.)

	$(LI C++ overloads based on const and volatile. D does not.)

	$(LI C++ overloads operators in significantly different ways - for
	example, operator[]() overloading for lvalue and rvalue is based on
	const overloading and a proxy class.)

	$(LI C++ overloads operators like &lt; completely independently of
	&gt;.)

	$(LI C++ overloads indirection (operator*).)

	$(LI C++ does not distinguish between a class and a struct object.)

	$(LI The vtbl[] location and layout is different between C++ and D.)

	$(LI The way RTTI is done is completely different. C++ has no
	classinfo.)

	$(LI D does not allow overloading of assignment.)

	$(LI D does not have constructors or destructors for struct objects.)

	$(LI D does not have two phase lookup, nor does it have Koenig (ADL)
	lookup.)

	$(LI C++ relates classes with the 'friend' system, D uses packages and
	modules.)

	$(LI C++ class design tends to revolve around explicit memory allocation
	issues, D's do not.)

	$(LI D's template system is very different.)

	$(LI C++ has 'exception specifications'.)

	$(LI C++ has global operator overloading.)

	$(LI C++ name mangling depends on const and volatile being type
	modifiers.
	Since D does not have const and volatile type modifiers, there is
	no straightforward way to infer the C++ mangled identifier from a D
	type.)

	)

	$(P The bottom line is the language features affect the design of the code. C++
	designs just don't fit with D. Even if you could find a way to automatically
	adapt between the two, the result will be about as enticing as the left side of
	a honda welded to the right side of a camaro. 
	)

$(ITEM reference-counting, Why doesn't D use reference counting for garbage collection?)

	$(P Reference counting has its advantages, but some severe
	disadvantages:
	)

	$(UL

	$(LI Cyclical data structures won't get freed.)

	$(LI Every pointer copy requires an increment and a corresponding
	decrement - including when simply passing a reference to a function.)

	$(LI In a multithreaded app, the incs and decs must be synchronized.)

	$(LI Exception handlers (finally blocks) must be inserted to handle all the
	decs so there are no leaks. Contrary to assertions otherwise, there is
	no such thing as "zero overhead exceptions.")

	$(LI In order to support slicing and interior pointers, as well as
	supporting reference counting on arbitrary allocations of non-object
	data, a separate "wrapper" object must be allocated for each allocation
	to be ref counted. This essentially doubles the number of allocations
	needed.)

	$(LI The wrapper object will mean that all pointers will need to be
	double-dereferenced to access the data.)

	$(LI Fixing the compiler to hide all this stuff from the programmer will
	make it difficult to interface cleanly with C.)

	$(LI Ref counting can fragment the heap thereby consuming more memory
	just like the gc can, though the gc typically will consume more memory
	overall.)

	$(LI Ref counting does not eliminate latency problems, it just reduces
	them.)

	)

	$(P The proposed C++ shared_ptr&lt;&gt;, which implements ref counting,
	suffers from all these faults. I haven't seen a heads up benchmark of
	shared_ptr&lt;&gt; vs mark/sweep, but I wouldn't be surprised if shared_ptr&lt;&gt;
	turned out to be a significant loser in terms of both performance and
	memory consumption.
	)

	$(P That said, D may in the future optionally support some form of ref
	counting, as rc is better for managing scarce resources like file
	handles. 
	)

$(ITEM gc_1, Isn't garbage collection slow and non-deterministic?)

	$(P Yes, but $(B all) dynamic memory management is slow and
	non-deterministic, including malloc/free.
	If you talk to the people who actually do real time
	software, they don't use malloc/free precisely because they are not
	deterministic. They preallocate all data.
	However, the use of GC instead of malloc enables advanced language
	constructs (especially, more powerful array syntax), which greatly
	reduce the number of memory allocations which need to be made.
	This can mean that GC is actually faster than explict management.
	)

$(V2
$(ITEM const, Why does D have const?)

	$(P Constness has 2 main uses:)

	$(OL

	$(LI Better specification of an API. This is of little importance for
	smaller projects or projects done by a very small team. It becomes
	important for large projects worked on by diverse teams. It essentially
	makes explicit what things a function can be expected to change, and
	what things it won't change.
	)

	$(LI It makes functional programming possible. The plum FP gets us is it
	opens the door to automatic parallelization of code! C++ and Java are
	dead in the water when it comes to automatic parallelization - if there
	are multiple cores, the app needs to be painfully and carefully recoded
	to take advantage of them. With FP, this can be done automatically. 
	)

	)
)

$(COMMENT
	> Single inheritance may be easier to implement, but you are losing
	>something.  It's a little concerning how often folks here take the
	>opinion that "Feature X has problems and I never use it anyway, so no
	>body else 'really' needs it."  I'm not specificly blaming you, but i've
	>lost track of how many time if seen that reasoning tonight.  I'm afraid
	>I'll see it a lot in the 275 I still have to read.  


	Your reasoning has merit. The counterargument (and I've discussed
	this at length with my colleagues) is that C++ gives you a dozen ways
	and styles to do X. Programmers tend to develop specific styles and do
	things in certain ways. This leads to one programmer's use of C++ to
	be radically different than another's, almost to the point where
	they are different languages.  C++ is a huge language, and C++
	programmers tend to learn particular "islands" in the language
	and not be too familiar with the rest of it.

	Hence one idea behind D is to *reduce* the number of ways X can be
	accomplished, and reduce the balkanization of programmer expertise.
	Then, one programmer's coding style will look more like another's,
	with the intended result that legacy D code will be more maintainable.
	For example, over the  years I've seen dozens of different ways that
	debug code was inserted into a program, all very different. D has one
	way - with the debug attribute/statement. C++ has a dozen string
	classes plus the native C way of doing strings. D has one way of
	doing strings.

	I intend to further help this along by writing a D style guide,
	"The D Way". There's a start on it all ready with the document
	on how to do error handling: 

	    www.digitalmars.com/d/errors.html

)

)

Macros:
	TITLE=FAQ
	WIKI=FAQ
	ITEMR=$(LI $(LINK2 #$1, $+))
	ITEM=<hr><h3><a name="$1">$+</a></h3>
