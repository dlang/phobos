Ddoc

$(D_S D 2.0 Enhancements from D 1.0,

	$(P D 2.0 has many substantial language and library enhancements
	compared with D 1.0.
	This list does not include $(LINK2 changelog.html, bug fixes)
	or $(LINK2 ../1.0/changelog.html, changes that were also made to D 1.0).
	)

$(SECTION2 Core Language Changes,

$(UL
	$(LI $(CODE opAssign) can no longer be overloaded for class objects.)
	$(LI Added $(CODE pure) keyword.)
	$(LI Extended $(LINK2 enum.html, enums) to allow declaration
	 of manifest constants.)
	$(LI Added $(LINK2 struct.html#ConstStruct, const/invariant structs),
	 $(LINK2 class.html#ConstClass, classes) and
	 $(LINK2 interface.html#ConstInterface, interfaces).)
	$(LI Added $(CODE const) and $(CODE invariant) to $(LINK2 expression.html#IsExpression, $(I IsExpression))s.)
	$(LI Added $(CODE typeof(return)) type specifier.)
	$(LI Added overloadable unary * operation as $(CODE opStar()).)
	$(LI Full closure support added.)
	$(LI Transformed all of $(CODE string), $(CODE wstring),
	and $(CODE dstring) into invariant definitions).
	$(LI Added $(LINK2 function.html#overload-sets, Overload Sets) for functions and templates.)
	$(LI $(TT std.math.sin), $(TT cos), $(TT tan) are now evaluated at
	compile time if the argument is a constant.) 
	$(LI Added $(LINK2 cpp_interface.html, C++ interface) for 'plugins'.)
	$(LI Changed result type of
	 $(LINK2 expression.html#IsExpression, $(I IsExpression))
	 from $(CODE int) to $(CODE bool).)
	$(LI Added optional $(I TemplateParameterList) to $(LINK2 expression.html#IsExpression, $(I IsExpression)).)
	$(LI Added warning when $(CODE override) is omitted.)
	$(LI Added new syntax for string literals (delimited, heredoc, D tokens))
	$(LI Added $(CODE __EOF__) token)
	$(LI Added $(LINK2 version.html#PredefinedVersions, $(B D_Version2))
	 predefined identifier to indicate this is a D version 2.0 compiler)
	$(LI Added $(CODE .idup) property for arrays to create invariant
	copies.)
	$(LI Added transitive const and invariant.)
	$(LI $(CODE in) parameter storage class now means scope const.)
	$(LI class and struct invariant declarations now must have a ().)
	$(LI Added $(CODE isSame) and $(CODE compiles) to $(D_KEYWORD __traits).)
	$(LI Added $(LINK2 statement.html#ForeachRangeStatement, ForeachRangeStatement)).
)

)

$(SECTION2 Phobos Library Changes,

$(UL
	$(LI $(LINK2 phobos/std_algorithm.html, std.algorithm): new module)
	$(LI $(LINK2 phobos/std_bitarray.html, std.bitarray): scheduled for deprecation)
	$(LI $(LINK2 phobos/std_bitmanip.html, std.bitmanip): new module with the content of std.bitarray plus the bitfields, FloatRep, and DoubleRep templates)
	$(LI $(LINK2 phobos/std_contracts.html, std.contracts): new module)
	$(LI $(LINK2 phobos/std_conv.html, std.conv):
	 Added $(CODE parse) and $(CODE assumeUnique).
	 Made $(CODE conv_error) a template parameterized on the types being
	 converted.
	 Massive additions.)
	$(LI $(LINK2 phobos/std_file.html, std.file): added $(CODE dirEntries).)
	$(LI $(LINK2 phobos/std_format.html, std.format):
	 Added raw ('r') format specifier for writef*.)
	$(LI $(LINK2 phobos/std_functional.html, std.functional): new module)
	$(LI $(LINK2 phobos/std_getopt.html,std.getopt): new module.)
	$(LI $(LINK2 phobos/std_hiddenfunc.html, std.hiddenfunc): new module)
	$(LI $(LINK2 phobos/std_math.html, std.math): Made nextafter visible for all floating types. Added approxEqual template.)
	$(LI $(LINK2 phobos/std_numeric.html, std.numeric): new module)
	$(LI $(LINK2 phobos/std_path.html, std.path):
	 Added $(CODE rel2abs) (Linux version only).
	 Added the basename and dirname functions (which alias the
	 less gainful names getBaseName and getDirectoryName))
	$(LI $(LINK2 phobos/std_process.html, std.process):
	 Made getpid visible in Linux builds)
	$(LI $(LINK2 phobos/std_stdio, std.stdio):
	 Added $(CODE writeln()) and $(CODE write()),
	 $(CODE writef()) can now only accept a format as its first argument.
	 Added optional terminator to $(CODE readln).
	 Added functions $(CODE fopen), $(CODE popen),
	 $(CODE lines) and $(CODE chunks).)
	$(LI $(LINK2 phobos/std_string.html, std.string):
	 Added munch function and added function chompPrefix.)
	$(LI $(LINK2 phobos/std_random, std.random):
	 Major addition of engines and distributions.)
	$(LI $(LINK2 phobos/std_traits.html, std.traits): new module)
	$(LI $(LINK2 phobos/std_typecons, std.typecons): new module)
	$(LI $(LINK2 phobos/std_variant.html, std.variant): new module.)

	$(LI Incorporated many of the Tango GC structural differences (much more to go still).)
	$(LI Overhaul phobos $(TT linux.mak) and add documentation build logic)
	$(LI Moved $(B next) member from $(B Object.Error) to $(B Object.Exception))
	$(LI Renamed linux library from $(B libphobos.a) to $(B libphobos2.a))

)

)


)

Macros:
	TITLE=D 2.0 Specific Features
	WIKI=D2Features




