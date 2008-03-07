Ddoc

$(D_S htod,

$(P	While D is binary compatible with C code, it cannot
	compile C code nor C header files. In order for
	D to link with C code, the C declarations residing
	in C header files need to be converted to a D
	module. $(B htod) is a migration tool to aid in
	convering C header files.
)
$(P	$(B htod) is built from the front end of the Digital
	Mars C and C++ compiler. It works just like a C or
	C++ compiler except that its output is a D module
	rather than object code.
)
$(P	The macro $(B __HTOD__) is predefined and set to $(B 1),
	which is handy for improving C header files to give better
	D output.
)

<h3>Download</h3>

$(P	$(LINK2 http://ftp.digitalmars.com/htod.zip, htod)
)

<h3>Usage</h3>

$(GRAMMAR
$(B htod) $(I cheader.h) [$(I dimport.d)] [$(B -cpp)] [$(B -hc)] [$(B -hi)] [$(B -hs)] [$(B -ht)] { $(I C compiler switches) }
)

$(P where:)

$(DL

$(DT $(I cheader.h)
$(DD C or C++ header input file
)
)

$(DT $(I dimport.d)
$(DD D source code output file (defaults to $(I cheader).d)
)
)

$(DT $(B -cpp)
$(DD Indicates a C++ header file
)
)

$(DT $(B -hc)
$(DD By default, $(B htod) will insert the C and C++ declarations
in a file into the output file prefixed by $(TT //C     ).
$(B -hc) will suppress this.
Use only if you're confident that $(B htod) is generating the
correct output file (such as if the header file was modified with
$(B __HTOD__)).
)
)

$(DT $(B -hi)
$(DD By default, $(B htod) will represent a $(TT #include "file") with
a corresponding $(B import) statement. The $(B -hi) will cause the
declarations in the included file to be converted to D declarations as
well. The declarations in all included files are parsed regardless.
$(B -hi) is handy when replacing an entire hierarchy of include files
with a single D import.
System includes like $(TT #include &lt;file&gt;) are not affected
by $(B -hi).
See also $(B -hs).
)
)

$(DT $(B -ht)
$(DD By default, $(B htod) will write types using typedef names as
using those names. $(B -ht) will cause the underlying types to be
used instead. This is very useful for "drilling down" layers of
macros, typedefs, and #includes to find out the underlying type.
)
)

$(DT $(B -hs)
$(DD Works just like $(B -hi), except that system includes are
migrated as well.
)
)

$(DT $(I C compiler switches)
$(DD C or C++ compiler switches, such as $(B -D) and $(B -I) as documented
for $(LINK2 http://www.digitalmars.com/ctg/dmc.html, dmc).
)
)

)

<h3>Example</h3>

$(P The C test.h file:)

$(CCODE
unsigned u;
#define MYINT int
void bar(int x, long y, long long z);
)

$(P Translated with:)

$(CONSOLE
htod test.h
)

$(P Produces the file test.d:)

---
/* Converted to D from test.h by htod */
module test;
//C     unsigned u;
extern (C):
uint u;
//C     #define MYINT int
//C     void bar(int x, long y, long long z);
alias int MYINT;
void  bar(int x, int y, long z);
---

$(P The C declarations are prefixed by the string $(TT "//C     ").)

<h3>Type Mappings</h3>

$(P	C types are mapped as follows. These mappings are correct
	for Digital Mars C/C++, but may not be correct for your
	C compiler. D basic types have fixed sizes, while C basic
	type sizes are implementation defined.
)

	$(TABLE1
	<caption>Mapping C to D types</caption>
	$(TR $(TH C type) $(TH D type))
	$(TR $(TD void) $(TD void))
	$(TR $(TD _Bool) $(TD bool))
	$(TR $(TD wchar_t) $(TD wchar))
	$(TR $(TD char) $(TD char))
	$(TR $(TD signed char) $(TD byte))
	$(TR $(TD unsigned char) $(TD ubyte))
	$(TR $(TD short) $(TD short))
	$(TR $(TD unsigned short) $(TD ushort))
	$(TR $(TD int) $(TD int))
	$(TR $(TD unsigned) $(TD uint))
	$(TR $(TD long) $(TD int))
	$(TR $(TD unsigned long) $(TD uint))
	$(TR $(TD long long) $(TD long))
	$(TR $(TD unsigned long long) $(TD ulong))
	$(TR $(TD float) $(TD float))
	$(TR $(TD double) $(TD double))
	$(TR $(TD long double) $(TD real))
	$(TR $(TD _Imaginary float) $(TD ifloat))
	$(TR $(TD _Imaginary double) $(TD idouble))
	$(TR $(TD _Imaginary long double) $(TD ireal))
	$(TR $(TD _Complex float) $(TD cfloat))
	$(TR $(TD _Complex double) $(TD cdouble))
	$(TR $(TD _Complex long double) $(TD creal))
	)

<h3>Limitations</h3>

$(P	There is no one to one correspondence of C declarations
	to D declarations. A review of the D module output will
	be necessary to ensure the right decisions are made.
	Furthermore:
)

$(OL
	$(LI Whereever
	practical, C headers should be written using $(B typedef)'s and
	$(B enum)'s rather than macros.
	$(B htod) will attempt to convert simple macro $(B #define)'s
	to $(B alias) and $(B const) declarations.
	Even so, macros are fully expanded before further analysis.)

	$(LI No attempt is made to convert C conditional compilation
	into D $(B version) or $(B static if) declarations.)

	$(LI No output is generated for false conditional compilation
	sections.)

	$(LI $(B htod) converts declarations only, it does not convert
	C code.)

	$(LI Declarations with C++ linkage cannot be converted.
	A C interface must be made for any C++ code.)

	$(LI C language extensions present in the C .h file
	may not be recognized.)

	$(LI Pragmas are not translated.)

	$(LI The tag names are assumed to not collide with
	names in the regular name space.)

	$(LI Any character data that is not ASCII will need
	to be converted as necessary to UTF.)

	$(LI The C $(B char) type is assumed to map to the
	D $(B char) type. However, these should be examined individually
	to see if they should instead be translated to $(B byte) or
	$(B ubyte) types. Whether the C $(B char) type is signed or
	unsigned is implementation defined. The D $(B char) type
	is unsigned.)

	$(LI Named C enum members are not inserted into the surrounding
	scope as they are in C.)

	$(LI D modules are each in their own name space, but C
	header files are all in the same global name space. This means
	that D references to names defined in other modules may
	need to be qualified.)
)

<h3>Bugs</h3>

$(OL
	$(LI Anything other than the default struct member
	alignment is not accounted for.)

	$(LI No Linux version.)
)

)

Macros:
	TITLE=htod
	WIKI=htod
