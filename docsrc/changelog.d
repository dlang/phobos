Ddoc

$(D_S D Change Log,


$(UL 
	$(NEW 011)
	$(NEW 010)
	$(NEW 009)
	$(NEW 008)
	$(NEW 007)
	$(NEW 006)
	$(NEW 005)
	$(NEW 004)
	$(NEW 003)
	$(NEW 002)
	$(NEW 001)
	$(NEW 000)

	$(LI $(LINK2 http://www.digitalmars.com/d/1.0/changelog.html, changelog for 1.0))

	$(LI Download latest D 2.0 alpha
	 <a HREF="http://ftp.digitalmars.com/dmd.2.010.zip" title="download D compiler">
	 D compiler</a> for Win32 and x86 linux)

	$(LI <a href="http://www.digitalmars.com/pnews/index.php?category=2">tech support</a>)
)

$(VERSION 011, Feb 6, 2008, =================================================,

    $(WHATSNEW
	$(LI Added $(CODE nothrow) keyword)
	$(LI Added $(CODE std.c.linux.termios))
	$(LI Re-enabled auto interfaces.)
	$(LI Now allow static arrays to be lvalues.)
	$(LI Now allows implicit casting of $(CODE null) to/from const/invariant.)
	$(LI Now allows implicit casting of $(I StructLiteral)s if each of
	 its arguments can be implicitly cast.)
	$(LI Now allows implicit casting of structs to/from const/invariant if
	 each of its fields can be.)
	$(LI Added $(LINK2 pragma.html#Predefined-Pragmas, pragma startaddress).)
    )

    $(BUGSFIXED
	$(LI $(BUGZILLA 1072): CTFE: crash on for loop with blank increment)
	$(LI $(BUGZILLA 1815): foreach with interval does not increment pointers correctly)
	$(LI $(BUGZILLA 1825): local instantiation and function nesting)
    )
)

$(VERSION 010, Jan 20, 2008, =================================================,

    $(WHATSNEW
	$(LI $(CODE opAssign) can no longer be overloaded for class objects.)
	$(LI $(CODE WinMain) and $(CODE DllMain) can now be in template mixins.)
	$(LI Added $(CODE pure) keyword.)
    )

    $(BUGSFIXED
	$(LI $(BUGZILLA 1319): compiler crashes with functions that take const ref arguments)
	$(LI $(BUGZILLA 1697): Internal error: ..\ztc\cgcod.c 2322 with -O)
	$(LI $(BUGZILLA 1700): ICE attempting to modify member of const return struct)
	$(LI $(BUGZILLA 1707): '==' in TemplateParameterList in IsExpression causes segfault)
	$(LI $(BUGZILLA 1711): typeof with delegate literal not allowed as template parameter)
	$(LI $(BUGZILLA 1713): foreach index with tuples and templates fails)
	$(LI $(BUGZILLA 1718): obscure exit with error code 5)
	$(LI $(BUGZILLA 1719): Compiler crash or unstable code generation with scoped interface instances)
	$(LI $(BUGZILLA 1720): std.math.NotImplemented missing a space in message)
	$(LI $(BUGZILLA 1724): Internal error: toir.c 177)
	$(LI $(BUGZILLA 1725): std.stream.BufferedFile.create should use FileMode.OutNew)
	$(LI $(BUGZILLA 1757): there is an fault  in phobos windows api interface)
	$(LI $(BUGZILLA 1762): Wrong name mangling for pointer args of free extern (C++) functions)
	$(LI $(BUGZILLA 1767): rejects-valid, diagnostic)
	$(LI $(BUGZILLA 1769): Typo on the page about exceptions)
	$(LI $(BUGZILLA 1773): excessively long integer literal)
	$(LI $(BUGZILLA 1779): Compiler crash when deducing more than 2 type args)
	$(LI $(BUGZILLA 1783): DMD 1.025 asserts on code with struct, template, and alias)
	$(LI $(BUGZILLA 1788): dmd segfaults without info)
	$(LI $(NG_digitalmars_D_announce 11066): Re: DMD 1.025 and 2.009 releases)
    )
)

$(VERSION 009, Jan 1, 2008, =================================================,

$(WHATSNEW
	$(LI Redid const/invariant semantics again.)
	$(LI Extended enums to allow declaration of manifest constants.)
)

$(BUGSFIXED
	$(LI $(BUGZILLA 1111): enum value referred to by another value of same enum is considered as enum's base type, not enum type)
	$(LI $(BUGZILLA 1694): Zip::ArchiveMember::name format bug)
	$(LI $(BUGZILLA 1702): ICE when identifier is undefined)
	$(LI $(BUGZILLA 1738): Error on struct without line number)
	$(LI $(BUGZILLA 1742): CTFE fails on some template functions)
	$(LI $(BUGZILLA 1743): interpret.c:1421 assertion failure on CTFE code)
	$(LI $(BUGZILLA 1744): CTFE: crash on assigning void-returning function to variable)
	$(LI $(BUGZILLA 1745): Internal error: ..\ztc\out.c 115)
	$(LI $(BUGZILLA 1749): std.socket not thread-safe due to strerror)
	$(LI $(BUGZILLA 1753): String corruption in recursive CTFE functions)
	$(LI $(NG_digitalmars_D 63456): Cannot overload on constancy of this)
)
)

$(VERSION 008, Nov 27, 2007, =================================================,

$(WHATSNEW
	$(LI std.string: Made munch more general and added function chompPrefix.)
	$(LI std.variant: Added documentation for variantArray)
	$(LI std.traits: Added CommonType template, fixed isStaticArray.)
	$(LI std.bitarray: scheduled for deprecation)
	$(LI std.bitmanip: new module with the content of std.bitarray plus the bitfields, FloatRep, and DoubleRep templates)
	$(LI std.process: Made getpid visible in Linux builds)
	$(LI std.math: Made nextafter visible for all floating types. Added approxEqual template.)
	$(LI std.contracts: Added enforce signature taking an exception)
	$(LI std.conv: Made conv_error a template parameterized on the types being converted.)
	$(LI std.stdio: Cosmetic changes.)
	$(LI std.system: Cosmetic changes.)
	$(LI std.file: Fixed bug in function dirEntries.)
	$(LI std.random: Major addition of engines and distributions.)
	$(LI std.format: Added raw ('r') format specifier for writef*.)
	$(LI std.path: Added rel2abs (Linux version only).)
	$(LI std.algorithm: new module)
	$(LI std.typecons: new module)
	$(LI std.functional: new module)
	$(LI std.numeric: new module)
	$(LI Added $(LINK2 struct.html#ConstStruct, const/invariant structs),
	 $(LINK2 class.html#ConstClass, classes) and
	 $(LINK2 interface.html#ConstInterface, interfaces).)
	$(LI Added $(CODE const) and $(CODE invariant) to $(LINK2 expression.html#IsExpression, IsExpression)s.)
	$(LI Added $(CODE typeof(return)) type specifier.)
	$(LI Changed the way coverage analysis is done so it is independent
	 of order dependencies among modules.)
	$(LI Revamped const/invariant.)
)

$(BUGSFIXED
	$(LI $(BUGZILLA 70): valgrind: Conditional jump or move depends on uninitialised value(s) in elf_findstr)
	$(LI $(BUGZILLA 71): valgrind: Invalid read of size 4 in elf_renumbersyms)
	$(LI $(BUGZILLA 204): Error message on attempting to instantiate an abstract class needs to be improved)
	$(LI $(BUGZILLA 1508): dmd/linux template symbol issues)
	$(LI $(BUGZILLA 1651): .di file generated with -H switch does not translate function() arguments correctly)
	$(LI $(BUGZILLA 1655): Internal error: ..\ztc\cgcod.c 1817)
	$(LI $(BUGZILLA 1656): illegal declaration accepted)
	$(LI $(BUGZILLA 1664): (1.23).stringof  generates bad code)
	$(LI $(BUGZILLA 1665): Internal error: ..\ztc\cod2.c 411)
)
)

$(VERSION 007, Oct 31, 2007, =================================================,

$(WHATSNEW
	$(LI Functors now supported by std.traits.ReturnType().)
	$(LI Transitive const now leaves invariants intact in the tail.)
	$(LI Added overloadable unary * operation as opStar().)
	$(LI Full closure support added.)
	$(LI Data items in static data segment &gt;= 16 bytes in size
	are now paragraph aligned.)
)

$(BUGSFIXED
	$(LI Variables of type void[0] can now be declared.)
	$(LI Static multidimensional arrays can now be initialized with
	other matching static multidimensional arrays.)
	$(LI $(BUGZILLA 318): wait does not release thread resources on Linux)
	$(LI $(BUGZILLA 322): Spawning threads which allocate and free memory leads to pause error on collect)
	$(LI $(BUGZILLA 645): Race condition in std.thread.Thread.pauseAll)
	$(LI $(BUGZILLA 689): Clean up the spec printfs!)
	$(LI $(BUGZILLA 697): No const folding on asm db,dw, etc)
	$(LI $(BUGZILLA 706): incorrect type deduction for array literals in functions)
	$(LI $(BUGZILLA 708): inline assembler: "CVTPS2PI mm, xmm/m128" fails to compile)
	$(LI $(BUGZILLA 709): inline assembler: "CVTPD2PI mm, xmm/m128" fails to compile)
	$(LI $(BUGZILLA 718): Internal error: ../ztc/cgcod.c 562)
	$(LI $(BUGZILLA 723): bad mixin of class definitions at function level: func.c:535: virtual void FuncDeclaration::semantic3(Scope*): Assertion `0' failed)
	$(LI $(BUGZILLA 725): expression.c:6516: virtual Expression* MinAssignExp::semantic(Scope*): Assertion `e2->type->isfloating()' failed.)
	$(LI $(BUGZILLA 726): incorrect error line for "override" mixin)
	$(LI $(BUGZILLA 729): scope(...) statement in SwitchBody causes compiler to segfault)
	$(LI $(BUGZILLA 1258): Garbage collector loses memory upon array concatenation)
	$(LI $(BUGZILLA 1480): std.stream throws the new override warning all over the place)
	$(LI $(BUGZILLA 1483): Errors in threads not directed to stderr)
	$(LI $(BUGZILLA 1557): std.zlib allocates void[]s instead of ubyte[]s, causing leaks.)
	$(LI $(BUGZILLA 1580): concatenating invariant based strings should work)
	$(LI $(BUGZILLA 1593): ICE compiler crash empty return statement in function)
	$(LI $(BUGZILLA 1613): DMD hangs on syntax error)
	$(LI $(BUGZILLA 1618): Typo in std\system.d)
)
)

$(VERSION 006, Oct 16, 2007, =================================================,

$(WHATSNEW
	$(LI $(RED Transformed all of $(CODE string), $(CODE wstring),
	and $(CODE dstring) into invariant definitions).
	Tons of changes in function signatures and
	implementations rippled through the standard library.
	Initial experience
	with invariant strings seems to be highly encouraging.)
	$(LI Implemented $(LINK2 function.html#overload-sets, Overload Sets) for functions and templates.)
	$(LI Added the $(LINK2 phobos/std_getopt.html,std.getopt) module that makes standards-conforming command-line processing easy.)
	$(LI Added the parse and assumeUnique to the $(LINK2 phobos/std_conv.html, std.conv) module.)
	$(LI Added the dirEntries function to the $(LINK2 phobos/std_file.html, std.file) module.)
	$(LI Added the basename and dirname functions (which alias the less gainful names getBaseName and getDirectoryName to the $(LINK2 phobos/std_path.html,std.path) module.))
	$(LI Added optional terminator to readln; added the convenience functions fopen and popen; added functions lines and chunks; all to the $(LINK2 phobos/std_stdio.html, std.stdio) module.)
	$(LI Added the munch function to the $(LINK2 phobos/std_string.html, std.string) module.)
	$(LI Fixed isStaticArray; added BaseClassesTuple, TransitiveBaseTypeTuple, ImplicitConversionTargets, isIntegral, isFloatingPoint, isNumeric, isSomeString, isAssociativeArray, isDynamicArray, isArray; all to the $(LINK2 phobos/std_traits.html, std.traits) module.)
	$(LI Added the $(LINK2 phobos/std_variant.html, std.variant) module.)
	$(LI Incorporated many of the Tango GC structural differences (much more to go still).)
	$(LI Added the $(LINK2 phobos/std_contracts.html, std.contracts) module.)
	$(LI Breaking change: $(CODE std.stdio.writef) can now only accept a format as
	its first argument.)
)

$(BUGSFIXED
   $(LI $(BUGZILLA 1478): Avoid libc network api threadsafety issues)
   $(LI $(BUGZILLA 1491): Suppress SIGPIPE when sending to a dead socket)
   $(LI $(BUGZILLA 1562): Deduction of template alias parameter fails)
   $(LI $(BUGZILLA 1571): Const on function parameters not carried through to .di file)
   $(LI $(BUGZILLA 1575): Cannot do assignment of tuples)
   $(LI $(BUGZILLA 1579): write[ln] fails for obj.toString())
   $(LI $(BUGZILLA 1580): Concatenating invariant based strings should work)
)
)

$(VERSION 005, Oct 1, 2007, =================================================,

$(WHATSNEW
	$(LI $(TT std.math.sin), $(TT cos), $(TT tan) are now evaluated at
	compile time if the argument is a constant.) 
	$(LI Added Cristian Vlasceanu's idea for
	$(LINK2 cpp_interface.html, C++ interface) for 'plugins')
	$(LI Overhaul phobos $(TT linux.mak) and add documentation build logic)
	$(LI Massive additions to $(LINK2 phobos/std_conv.html, std.conv))
	$(LI Add $(CODE writeln()) and $(CODE write()) to $(LINK2 phobos/std_stdio.html, std.stdio))
)

$(BUGSFIXED
	$(LI Fix std.boxer boxing of Object's (unit test failure))
	$(LI Fix std.demangle to not show hidden parameters (this and delegate context pointers))
	$(LI $(BUGZILLA 217): typeof not working properly in internal/object.d)
	$(LI $(BUGZILLA 218): Clean up old code for packed bit array support)
	$(LI $(BUGZILLA 223): Error message for unset constants doesn't specify error location)
	$(LI $(BUGZILLA 278): dmd.conf search path doesn't work)
	$(LI $(BUGZILLA 479): can't compare arrayliteral statically with string)
	$(LI $(BUGZILLA 549): A class derived from a deprecated class is not caught)
	$(LI $(BUGZILLA 550): Shifting by more bits than size of quantity is allowed)
	$(LI $(BUGZILLA 551): Modulo operator works with imaginary and complex operands)
	$(LI $(BUGZILLA 556): is (Type Identifier : TypeSpecialization) doesn't work as it should)
	$(LI $(BUGZILLA 668): Use of *.di files breaks the order of static module construction)
	$(LI $(BUGZILLA 1125): Segfault using tuple in asm code, when size not specified)
	$(LI $(BUGZILLA 1437): dmd crash: "Internal error: ..\ztc\cod4.c 357")
	$(LI $(BUGZILLA 1456): Cannot use a constant with alias template parameters)
	$(LI $(BUGZILLA 1474): regression: const struct with an initializer not recognized as a valid alias template param)
	$(LI $(BUGZILLA 1488): Bad code generation when using tuple from asm)
	$(LI $(BUGZILLA 1510): ICE: Assertion failure: 'ad' on line 925 in file 'func.c')
	$(LI $(BUGZILLA 1523): struct literals not work with typedef)
	$(LI $(BUGZILLA 1530): Aliasing problem in DMD front end code)
	$(LI $(BUGZILLA 1531): cannot access typedef'd class field)
	$(LI $(BUGZILLA 1537): Internal error: ..\ztc\cgcod.c 1521)
)
)

$(VERSION 004, Sep 5, 2007, =================================================,

$(WHATSNEW
	$(LI Added command line switches $(B -defaultlib) and $(B -debuglib))
	$(LI $(BUGZILLA 1445): Add default library options to sc.ini / dmd.conf)
	$(LI Changed result type of IsExpression from int to bool.)
	$(LI Added $(B isSame) and $(B compiles) to $(B __traits).)
	$(LI Added optional $(I TemplateParameterList) to $(I IsExpression).)
	$(LI Added warning when $(B override) is omitted.)
	$(LI Added $(B std.hiddenfunc).)
	$(LI Added trace_term() to object.d to fix $(BUGZILLA 971): No profiling output is generated if the application terminates with exit)
	$(LI Multiple module static constructors/destructors allowed.)
	$(LI Added new syntax for string literals (delimited, heredoc, D tokens))
	$(LI Added __EOF__ token)
)

$(BUGSFIXED
	$(LI Fixed $(NG_digitalmars_D 56414))
	$(LI $(BUGZILLA 961): std.windows.registry stack corruption)
	$(LI $(BUGZILLA 1315): CTFE doesn't default initialise arrays of structs)
	$(LI $(BUGZILLA 1342): struct const not accepted as initializer for another struct)
	$(LI $(BUGZILLA 1363): Compile-time issue with structs in 'for')
	$(LI $(BUGZILLA 1375): CTFE fails for null arrays)
	$(LI $(BUGZILLA 1378): A function call in an array literal causes compiler to crash)
	$(LI $(BUGZILLA 1384): Compiler segfaults when using struct variable like a function with no opCall member.)
	$(LI $(BUGZILLA 1388): multiple static constructors allowed in module)
	$(LI $(BUGZILLA 1414): compiler crashes with CTFE and structs)
	$(LI $(BUGZILLA 1421): Stack Overflow when using __traits(allMembers...))
	$(LI $(BUGZILLA 1423): Registry: corrupted value)
	$(LI $(BUGZILLA 1436): std.date.getLocalTZA() returns wrong values when in DST under Windows)
	$(LI $(BUGZILLA 1446): Missing comma in Final Const and Invariant page title)
	$(LI $(BUGZILLA 1447): CTFE does not work for static member functions of a class)
	$(LI $(BUGZILLA 1448): UTF-8 output to console is seriously broken)
	$(LI $(BUGZILLA 1450): Registry: invalid UTF-8 sequence)
	$(LI $(BUGZILLA 1460): Compiler crash on valid code)
	$(LI $(BUGZILLA 1464): "static" foreach breaks CTFE)
	$(LI $(BUGZILLA 1468): A bug about stack overflow.)
)
)

$(VERSION 003, Jul 21, 2007, =================================================,

$(WHATSNEW
	$(LI Added 0x78 Codeview extension for type $(B dchar).)
	$(LI Moved $(B next) member from $(B Object.Error) to $(B Object.Exception))
	$(LI Added $(LINK2 statement.html#ForeachRangeStatement, ForeachRangeStatement)).
	$(LI Added $(B extern (System)))
	$(LI Added $(LINK2 traits.html, std.traits))
	$(LI $(BUGZILLA 345): updated std.uni.isUniAlpha to Unicode 5.0.0)
)

$(BUGSFIXED
	$(LI $(BUGZILLA 46): Included man files should be updated)
	$(LI $(BUGZILLA 268): Bug with SocketSet and classes)
	$(LI $(BUGZILLA 406): std.loader is broken on linux)
	$(LI $(BUGZILLA 561): Incorrect duplicate error message when trying to create instance of interface)
	$(LI $(BUGZILLA 588): lazy argument and nested symbol support to std.demangle)
	$(LI $(BUGZILLA 668): Use of *.di files breaks the order of static module construction)
	$(LI $(BUGZILLA 1110): std.format.doFormat + struct without toString() == crash)
	$(LI $(BUGZILLA 1300): Issues with struct in compile-time function)
	$(LI $(BUGZILLA 1306): extern (Windows) should work like extern (C) for variables)
	$(LI $(BUGZILLA 1318): scope + ref/out parameters are allowed, contrary to spec)
	$(LI $(BUGZILLA 1320): Attributes spec uses 1.0 const semantics in 2.0 section)
	$(LI $(BUGZILLA 1331): header file genaration generates a ":" instead of ";" at pragma)
	$(LI $(BUGZILLA 1332): Internal error: ../ztc/cod4.c 357)
	$(LI $(BUGZILLA 1333): -inline ICE: passing an array element to an inner class's constructor in a nested function, all in a class or struct)
	$(LI $(BUGZILLA 1336): Internal error when trying to construct a class declared within a unittest from a templated class.)
)
)

$(VERSION 002, Jul 1, 2007, =================================================,

$(WHATSNEW
	$(LI Renamed linux library from $(B libphobos.a) to $(B libphobos2.a))
)

$(BUGSFIXED
	$(LI $(BUGZILLA 540): Nested template member function error - "function expected before ()")
	$(LI $(BUGZILLA 559): Final has no effect on methods)
	$(LI $(BUGZILLA 627): Concatenation of strings to string arrays with ~ corrupts data)
	$(LI $(BUGZILLA 629): Misleading error message "Can only append to dynamic arrays")
	$(LI $(BUGZILLA 639): Escaped tuple parameter ICEs dmd)
	$(LI $(BUGZILLA 641): Complex string operations in template argument ICEs dmd)
	$(LI $(BUGZILLA 657): version(): ignored)
	$(LI $(BUGZILLA 689): Clean up the spec printfs!)
	$(LI $(BUGZILLA 1103): metastrings.ToString fails for long &gt; 0xFFFF_FFFF)
	$(LI $(BUGZILLA 1107): CodeView: wrong CV type for bool)

	$(LI $(BUGZILLA 1118): weird switch statement behaviour)
	$(LI $(BUGZILLA 1186): Bind needs a small fix)
	$(LI $(BUGZILLA 1199): Strange error messages when indexing empty arrays or strings at compile time)
	$(LI $(BUGZILLA 1200): DMD crash: some statements containing only a ConditionalStatement with a false condition)
	$(LI $(BUGZILLA 1203): Cannot create Anonclass in loop)
	$(LI $(BUGZILLA 1204): segfault using struct in CTFE)
	$(LI $(BUGZILLA 1206): Compiler hangs on this() after method in class that forward references struct)
	$(LI $(BUGZILLA 1207): Documentation on destructors is confusing)
	$(LI $(BUGZILLA 1211): mixin("__LINE__") gives incorrect value)
	$(LI $(BUGZILLA 1212): dmd generates bad line info)

	$(LI $(BUGZILLA 1216): Concatenation gives 'non-constant expression' outside CTFE)
	$(LI $(BUGZILLA 1217): Dollar ($) seen as non-constant expression in non-char[] array)
	$(LI $(BUGZILLA 1219): long.max.stringof gets corrupted)
	$(LI $(BUGZILLA 1224): Compilation does not stop on asserts during CTFE)
	$(LI $(BUGZILLA 1228): Class invariants should not be called before the object is fully constructed)
	$(LI $(BUGZILLA 1233): std.string.ifind(char[] s, char[] sub) fails on certain non ascii strings)
	$(LI $(BUGZILLA 1234): Occurrence is misspelled almost everywhere)
	$(LI $(BUGZILLA 1235): std.string.tolower() fails on certain utf8 characters)
	$(LI $(BUGZILLA 1236): Grammar for Floating Literals is incomplete)
	$(LI $(BUGZILLA 1239): ICE when empty tuple is passed to variadic template function)

	$(LI $(BUGZILLA 1242): DMD AV)
	$(LI $(BUGZILLA 1244): Type of array length is unspecified)
	$(LI $(BUGZILLA 1247): No time zone info for India)
	$(LI $(BUGZILLA 1285): Exception typedefs not distinguished by catch)
	$(LI $(BUGZILLA 1287): Iterating over an array of tuples causes "glue.c:710: virtual unsigned int Type::totym(): Assertion `0' failed.")
	$(LI $(BUGZILLA 1290): Two ICEs, both involving real, imaginary, ? : and +=.)
	$(LI $(BUGZILLA 1291): .stringof for a class type returned from a template doesn't work)
	$(LI $(BUGZILLA 1292): Template argument deduction doesn't work)
	$(LI $(BUGZILLA 1294): referencing fields in static arrays of structs passed as arguments generates invalid code)
	$(LI $(BUGZILLA 1295): Some minor errors in the lexer grammar)
)
)

$(VERSION 001, Jun 27, 2007, =================================================,

$(WHATSNEW
	$(LI Added $(B D_Version2) predefined identifier to indicate
	this is a D version 2.0 compiler)
	$(LI Added $(B __VENDOR__) and $(B __VERSION__).)
	$(LI Now an error to use both $(B const) and $(B invariant) as storage
	classes for the same declaration)
	$(LI The $(B .init) property for a variable is now based on its
	type, not its initializer.)
)

$(BUGSFIXED
	$(LI $(B std.compiler) now is automatically updated.)
	$(LI Fixed problem catting mutable to invariant arrays.)
	$(LI Fixed CFTE bug with e++ and e--.)
	$(LI $(BUGZILLA 1254): Using a parameter initialized to void in a compile-time evaluated function doesn't work)
	$(LI $(BUGZILLA 1256): "with" statement with symbol)
	$(LI $(BUGZILLA 1259): Inline build triggers an illegal error msg "Error: S() is not an lvalue")
	$(LI $(BUGZILLA 1260): Another tuple bug)
	$(LI $(BUGZILLA 1261): Regression from overzealous error message)
	$(LI $(BUGZILLA 1262): Local variable of struct type initialized by literal resets when compared to .init)
	$(LI $(BUGZILLA 1263): Template function overload fails when overloading on both template and non-template class)
	$(LI $(BUGZILLA 1268): Struct literals try to initialize static arrays of non-static structs incorrectly)
	$(LI $(BUGZILLA 1269): Compiler crash on assigning to an element of a void-initialized array in CTFE)
	$(LI $(BUGZILLA 1270): -inline produces an ICE)
	$(LI $(BUGZILLA 1272): problems with the new 1.0 section)
	$(LI $(BUGZILLA 1274): 2.0 beta link points to dmd.zip which is the 1.x chain)
	$(LI $(BUGZILLA 1275): ambiguity with 'in' meaning)
	$(LI $(BUGZILLA 1276): static assert message displayed with escaped characters)
	$(LI $(BUGZILLA 1277): "in final const scope" not considered redundant storage classes)
	$(LI $(BUGZILLA 1279): const/invariant functions don't accept const/invariant return types)
	$(LI $(BUGZILLA 1280): std.socket.Socket.send (void[],SocketFlags) should take a const(void)[] instead)
	$(LI $(BUGZILLA 1283): writefln: formatter applies to following variable)
	$(LI $(BUGZILLA 1286): crash on invariant struct member function referencing globals)
)
)

$(VERSION 000, Jun 17, 2007, =================================================,

$(WHATSNEW
	$(LI Added aliases $(B string), $(B wstring), and $(B dstring)
	for strings.)
	$(LI Added $(B .idup) property for arrays to create invariant
	copies.)
	$(LI Added const, invariant, and final.)
	$(LI $(B in) parameter storage class now means final scope const.)
	$(LI foreach value variables now default to final if not declared
	as inout.)
	$(LI class and struct invariant declarations now must have a ().)
)

$(BUGSFIXED
	$(LI Added missing \n to exception message going to stderr.)
	$(LI Fixed default struct initialization for CTFE.)
	$(LI $(BUGZILLA 1226): ICE on a struct literal)
)
)

)

Macros:
	TITLE=Change Log
	WIKI=ChangeLog

	NEW = $(LI Version <a href="#new2_$0">D 2.$0</a>)

	VERSION=
	<div id=version>
	$(B $(LARGE <a name="new2_$1">
	  Version
	  <a HREF="http://ftp.digitalmars.com/dmd.2.$1.zip" title="D 2.$1">D 2.$1</a>
	))
	$(SMALL $(I $2, $3))
	$5
	</div>

	BUGZILLA = <a href="http://d.puremagic.com/issues/show_bug.cgi?id=$0">Bugzilla $0</a>
	DSTRESS = dstress $0
	BUGSFIXED = <div id="bugsfixed"><h4>Bugs Fixed</h4> $(UL $0 )</div>
	WHATSNEW = <div id="whatsnew"><h4>New/Changed Features</h4> $(UL $0 )</div>
	LARGE=<font size=4>$0</font>
