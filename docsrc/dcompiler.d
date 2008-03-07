Ddoc

$(D_S Compiler for D Programming Language,

	$(UL 
	$(LI D for <a href="#Win32">Win32</a>)
	$(LI D for <a href="#linux">x86 Linux</a>)
	$(LI <a href="#general">general</a>)
	)

<h2>Downloads</h2>

	$(LINK2 http://www.digitalmars.com/d/download.html, Download D Compiler)

<h2>Files Common to Win32 and Linux</h2>

	$(DL

	$(DT $(TT \dmd\src\phobos\)
	$(DD D runtime library source)
	)

	$(DT $(TT \dmd\src\dmd\)
	$(DD D compiler front end source under dual (GPL and Artistic) license)
	)

	$(DT $(TT \dmd\html\d\)
	$(DD Documentation)
	)

	$(DT $(TT \dmd\samples\d\)
	$(DD Sample D programs)
	)

	)

<hr>
<h1><a name="Win32">DMD Win32 D Compiler</a></h1>

<h2>Requirements and Downloads</h2>

	$(UL 
	$(LI 32 bit Windows (Win32) operating system, such as Windows XP)

	$(LI Download dmd)

	$(LI Download
	 <a href="http://ftp.digitalmars.com/dmc.zip" title="download dmc.zip">
	 dmc.zip (linker and utilities)</a> for Win32
	)

	)

<h2>Files</h2>

	$(DL

	$(DT $(TT \dmd\bin\dmd.exe)
	$(DD D compiler executable)
	)

	$(DT $(TT \dmd\bin\shell.exe)
	$(DD Simple command line shell)
	)

	$(DT $(TT \dmd\bin\sc.ini)
	$(DD Global compiler settings)
	)

	$(DT $(TT \dmd\lib\phobos.lib)
	$(DD D runtime library)
	)

	)

<h2>Installation</h2>

	$(P Open a console window (for Windows XP this is done by
	clicking on [Start][Command Prompt]).
	All the tools are command line tools, which means
	they are run from a console window.
	Switch to the root directory.
	Unzip the files in the root directory.
	$(TT dmd.zip) will create
	a $(TT \dmd) directory with all the files in it.
	$(TT dmc.zip) will create
	a $(TT \dm) directory with all the files in it.
	)

	$(P A typical session might look like:)

$(CONSOLE
C:\Documents and Settings\Your Name&gt;cd \ 
C:\&gt;unzip dmd.zip
C:\&gt;unzip dmc.zip
)

<h2>Example</h2>

	$(P Run:)

$(CONSOLE
\dmd\bin\shell all.sh
)

	$(P in the $(TT \dmd\samples\d) directory for several small examples.)

<h2>Compiler Arguments and Switches</h2>

	$(DL
	  $(DT $(B dmd) $(I files)... -$(I switches)...
		$(DD )
	  )

	  $(DT $(I files)...
		$(DD
		<table border=1 cellpadding=4 cellspacing=0 summary="File Extensions">
		$(TR
		$(TH Extension)
		$(TH File Type)
		)
		$(TR
		$(TD $(I none))
		$(TD D source files)
		)
		$(TR
		$(TD $(B .d))
		$(TD D source files)
		)
		$(TR
		$(TD $(B .di))
		$(TD $(LINK2 #interface_files, D interface files))
		)
		$(TR
		$(TD $(B .obj))
		$(TD Object files to link in)
		)
		$(TR
		$(TD $(B .lib))
		$(TD Object code libraries to search)
		)
		$(TR
		$(TD $(B .exe))
		$(TD Name output executable file)
		)
		$(TR
		$(TD $(B .def))
		$(TD module definition file)
		)
		$(TR
		$(TD $(B .res))
		$(TD resource file)
		)
		</table>
		)
	  )

	  $(DT $(B @)$(I cmdfile)
		$(DD reads compiler arguments and switches from
		text file $(I cmdfile))
	  )

	  $(DT $(B -c)
		$(DD compile only, do not link)
	  )

	  $(DT $(B -cov)
		$(DD instrument for $(LINK2 code_coverage.html, code coverage analysis))
	  )

	  $(DT $(B -D)
		$(DD Generate $(LINK2 ddoc.html, documentation) from source.)
	  )

	  $(DT $(B -Dd)$(I docdir)
		$(DD write documentation file to $(I docdir) directory)
	  )

	  <dt>$(B -Df)$(I filename)</dt>
		$(DD write documentation file to $(I filename))

	  <dt>$(B -d)</dt>
		<dd>allow deprecated features
	  <dt>$(B -debug)</dt>
		<dd>compile in debug code
	  <dt>$(B -debug=)$(I level)</dt>
		<dd>compile in debug code <= $(I level)
	  $(DT $(B -debug=)$(I ident))
		$(DD compile in debug code identified by $(I ident))

	  $(DT $(B -debuglib=)$(I libname))
		$(DD link in $(I libname) as the default library when
		compiling for symbolic debugging instead of $(B phobos.lib))
	  $(DT $(B -defaultlib=)$(I libname))
		$(DD link in $(I libname) as the default library when
		not compiling for symbolic debugging instead of $(B phobos.lib))

	  $(DT $(B -g)
		$(DD add CodeView 4 symbolic debug info with
		$(LINK2 abi.html#codeview, D extensions)
		for debuggers such as
		$(LINK2 http://ddbg.mainia.de/releases.html, Ddbg))
	  )
	  $(DT $(B -gc)
		$(DD add CodeView 4 symbolic debug info in C format
		for debuggers such as
		$(TT \dmd\bin\windbg))
	  )

	  $(DT $(B -H))
		$(DD generate D interface file)

	  $(DT $(B -Hd)$(I dir))
		$(DD write D interface file to $(I dir) directory)

	  $(DT $(B -Hf)$(I filename))
		$(DD write D interface file to $(I filename))

	  <dt>$(B --help)</dt>
		<dd>print help
	  <dt>$(B -inline)
		<dd>inline expand functions
	  $(DT $(B -I)$(I path)
		$(DD where to look for imports. $(I path) is a ; separated
		list of paths. Multiple $(B -I)'s can be used, and the paths
		are searched in the same order.
		)
	  )
	  $(DT $(B -J)$(I path)
		$(DD where to look for files for $(I ImportExpression)s.
		This switch is required in order to use $(I ImportExpression)s.
		$(I path) is a ; separated
		list of paths. Multiple $(B -J)'s can be used, and the paths
		are searched in the same order.
		)
	  )
	  <dt>$(B -L)$(I linkerflag)
		<dd>pass $(I linkerflag) to the linker, for example,
		$(TT /ma/li)

	  $(DT $(B -nofloat))
		$(DD Prevents emission of $(B __fltused) reference in
		object files, even if floating point code is present.
		Useful for library code. Windows only.)

	  $(DT $(B -O))
		$(DD Optimize generated code.)

	  $(DT $(B -o-))
		$(DD Suppress generation of object file. Useful in
		conjuction with $(B -D) or $(B -H) flags.)

	  <dt>$(B -od)$(I objdir)</dt>
		$(DD write object files relative to directory $(I objdir)
		instead of to the current directory)
	  <dt>$(B -of)$(I filename)</dt>
		<dd>set output file name to $(I filename) in the output
		directory
	  <dt>$(B -op)</dt>
		<dd>normally the path for $(B .d) source files is stripped
		off when generating an object file name. $(B -op) will leave
		it on.
	  <dt>$(B -profile)</dt>
		<dd><a href="http://www.digitalmars.com/ctg/trace.html">profile</a>
		the runtime performance
		of the generated code
	  <dt>$(B -quiet)</dt>
		<dd>suppress non-essential compiler messages
	  <dt>$(B -release)</dt>
		<dd>compile release version, which means not generating
		code for contracts and asserts
	  $(DT $(B -run) $(I srcfile args...))
		$(DD compile, link, and run the program $(I srcfile) with the
		rest of the
		command line, $(I args...), as the arguments to the program.
		No .obj or .exe file is left behind.)
	  <dt>$(B -unittest)</dt>
		<dd>compile in unittest code, also turns on asserts
	  <dt>$(B -v)</dt>
		<dd>verbose
	  <dt>$(B -version=)$(I level)</dt>
		<dd>compile in version code >= $(I level)
	  <dt>$(B -version=)$(I ident)</dt>
		<dd>compile in version code identified by $(I ident)
	  <dt>$(B -w)</dt>
		$(DD enable <a href="warnings.html">warnings</a>)
	)

<h2>Linking</h2>

	$(P Linking is done directly by the $(B dmd) compiler after a successful
	compile. To prevent $(B dmd) from running the linker, use the
	$(B -c) switch.
	)

	$(P The programs must be linked with the D runtime library $(B phobos.lib),
	followed by the C runtime library $(B snn.lib).
	This is done automatically as long as the directories for the
	libraries are on the LIB environment variable path. A typical
	way to set LIB would be:
	)

$(CONSOLE
set LIB=\dmd\lib;\dm\lib
)

<h2>Environment Variables</h2>

	$(P The D compiler dmd uses the following environment variables:
	)

	$(DL

	<dt>$(B DFLAGS)
	<dd>The value of $(B DFLAGS) is treated as if it were appended to the
	command line to $(B dmd.exe).

	<dt>$(B LIB)
	<dd>The linker uses $(B LIB) to search for library files. For D, it will
	normally be set to:

$(CONSOLE
set LIB=\dmd\lib;\dm\lib
)

	<dt>$(B LINKCMD)
	<dd> $(B dmd) normally runs the linker by looking for $(B link.exe)
	along the $(B PATH). To use a specific linker instead, set the
	$(B LINKCMD) environment variable to it. For example:

$(CONSOLE
set LINKCMD=\dm\bin\link
)

	<dt>$(B PATH)
	<dd>If the linker is not found in the same directory as $(B dmd.exe)
	is in, the $(B PATH) is searched for it.
	$(B Note:) other linkers named
	$(B link.exe) will likely not work.
	Make sure the Digital Mars $(B link.exe)
	is found first in the $(B PATH) before other $(B link.exe)'s,
	or use $(B LINKCMD) to specifically identify which linker
	to use.

	)

<h2><a name="sc_ini">sc.ini Initialization File</a></h2>

	$(P $(B dmd) will look for the initialization file $(B sc.ini) in the
	following sequence of directories:
	)

	$(OL
	$(LI current working directory)
	$(LI directory specified by the $(B HOME) environment variable)
	$(LI directory $(B dmd.exe) resides in)
	)

	$(P If found, environment variable
	settings in the file will override any existing settings.
	This is handy to make $(B dmd) independent of programs with
	conflicting use of environment variables.
	)

<h3>Initialization File Format</h3>

	$(P Comments are lines that begin with $(TT ;) and are ignored.
	)

	$(P Environment variables follow the $(TT [Environment]) section
	heading, in $(I NAME)=$(I value) pairs.
	The $(I NAME)s are treated as upper case.
	Comments are lines that start with ;.
	For example:
	)

$(SCINI
; sc.ini file for dmd
; Names enclosed by %% are searched for in the existing environment
; and inserted. The special name %@P% is replaced with the path
; to this file.
[Environment]
LIB="%@P%\..\lib";\dm\lib
DFLAGS="-I%@P%\..\src\phobos"
LINKCMD="%@P%\..\..\dm\bin"
DDOCFILE=mysettings.ddoc
)

<h3>Location Independence of sc.ini</h3>

	$(P The $(B %@P%) is replaced with the path to $(TT sc.ini).
	Thus, if the fully qualified file name $(TT sc.ini) is
	$(TT c:\dmd\bin\sc.ini), then $(B %@P%) will be replaced with
	$(TT c:\dmd\bin), and the above $(TT sc.ini) will be
	interpreted as:
	)

$(SCINI
[Environment]
LIB="c:\dmd\bin\..\lib";\dm\lib
DFLAGS="-Ic:\dmd\bin\..\src\phobos"
LINKCMD="c:\dmd\bin\..\..\dm\bin"
DDOCFILE=mysettings.ddoc
)

	$(P This enables your dmd setup to be moved around without having
	to re-edit $(TT sc.ini).
	)

<h2>Common Installation Problems</h2>

	$(UL 
	$(LI Using Cygwin's $(B unzip) utility has been known to cause
	strange problems.
	)
	$(LI Running the compiler under Cygwin's command shell has
	been also known to cause problems. Try getting it to work
	under the regular Windows shell $(B cmd.exe) before trying Cygwin's.
	)
	$(LI Installing $(B dmd) and $(B dmc) into directory paths with spaces
	in them causes problems.
	)
	)

<hr>
<h1><a name="linux">Linux D Compiler</a></h1>

<h2>Requirements and Downloads</h2>

	$(UL 
	$(LI 32 bit x86 Linux operating system)

	$(LI Download dmd)

	$(LI Gnu C compiler (gcc))

	)

<h2>Files</h2>

	<dl>

	<dt>$(TT /dmd/bin/dmd)
	<dd>D compiler executable

	<dt>$(TT /dmd/bin/dumpobj)
	<dd>Elf file dumper

	<dt>$(TT /dmd/bin/obj2asm)
	<dd>Elf file disassembler

	<dt>$(TT /dmd/bin/dmd.conf)
	<dd>Global compiler settings (copy to $(TT /etc/dmd.conf))

	<dt>$(TT /dmd/lib/$(LIB))
	<dd>D runtime library (copy to $(TT /usr/lib/$(LIB)))

	</dl>

<h2>Installation</h2>

	$(OL 

	$(LI Unzip the archive into your home directory.
	It will create
	a $(TT ~/dmd) directory with all the files in it.
	All the tools are command line tools, which means
	they are run from a console window.)

	$(LI Copy $(TT dmd.conf) to $(TT /etc):

$(CONSOLE
cp dmd/bin/dmd.conf /etc
)
	)

	$(LI Give execute permission to the following files:

$(CONSOLE
chmod u+x dmd/bin/{dmd,dumpobj,obj2asm,rdmd}
)
	)

	$(LI Put $(TT dmd/bin) on your $(B PATH),
	or copy the linux executables
	to $(TT /usr/local/bin))

	$(LI Copy the library to $(TT /usr/lib):

$(CONSOLE
cp dmd/lib/$(LIB) /usr/lib
)
	)

	)

<h2>Compiler Arguments and Switches</h2>

	<dl><dl>
	  <dt>$(B dmd) $(I files)... -$(I switch)...
	  <p>
	  <dt>$(I files)...
		<dd>
		<table border=1 cellpadding=4 cellspacing=0 summary="File Extensions">
		$(TR
		$(TH Extension)
		$(TH File Type)
		)
		$(TR
		$(TD $(I none))
		$(TD D source files)
		)
		$(TR
		$(TD $(B .d))
		$(TD D source files)
		)
		$(TR
		$(TD $(B .di))
		$(TD $(LINK2 #interface_files, D interface files))
		)
		$(TR
		$(TD $(B .o))
		$(TD Object files to link in)
		)
		$(TR
		$(TD $(B .a))
		$(TD Library files to link in)
		)
		</table>

	  <dt>$(B -c)</dt>
		$(DD compile only, do not link)

	  <dt>$(B -cov)</dt>
		$(DD instrument for $(LINK2 code_coverage.html, code coverage analysis))

	  <dt>$(B -D)</dt>
		$(DD generate documentation)

	  <dt>$(B -Dd)$(I docdir)</dt>
		$(DD write documentation file to $(I docdir) directory)

	  <dt>$(B -Df)$(I filename)</dt>
		$(DD write documentation file to $(I filename))

	  <dt>$(B -d)</dt>
		<dd>allow deprecated features
	  <dt>$(B -debug)</dt>
		<dd>compile in debug code
	  <dt>$(B -debug=)$(I level)</dt>
		<dd>compile in debug code <= $(I level)
	  <dt>$(B -debug=)$(I ident)</dt>
		<dd>compile in debug code identified by $(I ident)

	  $(DT $(B -debuglib=)$(I libname))
		$(DD link in $(I libname) as the default library when
		compiling for symbolic debugging instead of $(B $(LIB)))
	  $(DT $(B -defaultlib=)$(I libname))
		$(DD link in $(I libname) as the default library when
		not compiling for symbolic debugging instead of $(B $(LIB)))

	  <dt>$(B -fPIC)</dt>
		<dd>generate position independent code

	  $(DT $(B -g)
		$(DD add Dwarf symbolic debug info with
		$(LINK2 abi.html#dwarf, D extensions)
		for debuggers such as
		$(LINK2 http://www.zerobugs.org/, ZeroBUGS))
	  )
	  $(DT $(B -gc)
		$(DD add Dwarf symbolic debug info in C format
		for debuggers such as
		<tt>gdb</tt>)
	  )

	  $(DT $(B -H))
		$(DD generate D interface file)

	  $(DT $(B -Hd)$(I dir))
		$(DD write D interface file to $(I dir) directory)

	  $(DT $(B -Hf)$(I filename))
		$(DD write D interface file to $(I filename))

	  <dt>$(B --help)</dt>
		<dd>print help
	  <dt>$(B -inline)
		<dd>inline expand functions
	  $(DT $(B -I)$(I path)
		$(DD where to look for imports. $(I path) is a ; separated
		list of paths. Multiple $(B -I)'s can be used, and the paths
		are searched in the same order.
		)
	  )
	  $(DT $(B -J)$(I path)
		$(DD where to look for files for $(I ImportExpression)s.
		This switch is required in order to use $(I ImportExpression)s.
		$(I path) is a ; separated
		list of paths. Multiple $(B -J)'s can be used, and the paths
		are searched in the same order.
		)
	  )
	  <dt>$(B -L)$(I linkerflag)
		<dd>pass $(I linkerflag) to the linker, for example,
		$(TT -M)
	  <dt>$(B -O)</dt>
		<dd>optimize
	  <dt>$(B -o-)</dt>
		<dd>suppress generation of object file
	  <dt>$(B -od)$(I objdir)</dt>
		<dd>write object files relative to directory $(I objdir)
		instead of to the current directory
	  <dt>$(B -of)$(I filename)</dt>
		<dd>set output file name to $(I filename) in the output
		directory
	  <dt>$(B -op)</dt>
		<dd>normally the path for $(B .d) source files is stripped
		off when generating an object file name. $(B -op) will leave
		it on.
	  <dt>$(B -quiet)</dt>
		<dd>suppress non-essential compiler messages
	  <dt>$(B -profile)</dt>
		<dd><a href="http://www.digitalmars.com/ctg/trace.html">profile</a>
		the runtime performance
		of the generated code
	  <dt>$(B -release)</dt>
		<dd>compile release version
	  $(DT $(B -run) $(I srcfile args...))
		$(DD compile, link, and run the program $(I srcfile) with the
		rest of the
		command line, $(I args...), as the arguments to the program.
		No .o or executable file is left behind.)
	  <dt>$(B -unittest)</dt>
		<dd>compile in unittest code
	  <dt>$(B -v)</dt>
		<dd>verbose
	  <dt>$(B -version=)$(I level)</dt>
		<dd>compile in version code >= $(I level)
	  <dt>$(B -version=)$(I ident)</dt>
		<dd>compile in version code identified by $(I ident)
	  <dt>$(B -w)</dt>
		<dd>enable <a href="warnings.html">warnings</a>
	</dl></dl>

<h2>Linking</h2>

	$(P Linking is done directly by the $(B dmd) compiler after a successful
	compile. To prevent $(B dmd) from running the linker, use the
	$(B -c) switch.
	)

	$(P The actual linking is done by running $(B gcc).
	This ensures compatibility with modules compiled with $(B gcc).
	)

<h2>Environment Variables</h2>

	The D compiler dmd uses the following environment variables:

	$(DL

	<dt>$(B CC)
	<dd> $(B dmd) normally runs the linker by looking for $(B gcc)
	along the $(B PATH). To use a specific linker instead, set the
	$(B CC) environment variable to it. For example:

$(CONSOLE
set CC=gcc
)

	<dt>$(B DFLAGS)
	<dd>The value of $(B DFLAGS) is treated as if it were appended to the
	command line to $(B dmd).

	)

<h2>dmd.conf Initialization File</h2>

	$(P The Linux dmd file $(TT dmd.conf) is the same as $(TT sc.conf)
	for Windows, it's just that the file has a different name,
	enabling a setup common to both Windows and Linux to be created
	without having to re-edit the file.)

	$(P $(B dmd) will look for the initialization file $(B dmd.conf) in the
	following sequence of directories:)

	$(OL
	$(LI current working directory)
	$(LI directory specified by the $(B HOME) environment variable)
	$(LI directory $(B dmd) resides in)
	$(LI $(B /etc/))
	)

	$(P If found, environment variable
	settings in the file will override any existing settings.
	This is handy to make $(B dmd) independent of programs with
	conflicting use of environment variables.
	)

	$(P Environment variables follow the $(TT [Environment]) section
	heading, in $(I NAME)=$(I value) pairs.
	The $(I NAME)s are treated as upper case.
	Comments are lines that start with ;.
	For example:
	)

$(SCINI
; dmd.conf file for dmd
; Names enclosed by %% are searched for in the existing environment
; and inserted. The special name %@P% is replaced with the path
; to this file.
[Environment]
DFLAGS="-I%@P%/../src/phobos"
)

<h2>Differences from Win32 version</h2>

	$(UL 
	$(LI String literals are read-only. Attempting to write to them
	will cause a segment violation.)

	$(LI The configuration file is $(TT /etc/dmd.conf))
	)

<hr>
<h1><a name="general">General</a></h1>

<h2><a name="interface_files">D Interface Files</a></h2>

	$(P When an import declaration is processed in a D source file,
	the compiler searches for the D source file corresponding to
	the import, and processes that source file to extract the
	information needed from it. Alternatively, the compiler can
	instead look for a corresponding $(I D interface file).
	A D interface file contains only what an import of the module
	needs, rather than the whole implementation of that module.
	)

	$(P The advantages of using a D interface file for imports rather
	than a D source file are:
	)

	$(UL
	$(LI D interface files are often significantly smaller and much
	faster to process than the corresponding D source file.)
	$(LI They can be used to hide the source code, for example,
	one can ship an object code library along with D interface files
	rather than the complete source code.)
	)

	$(P D interface files can be created by the compiler from a
	D source file by using the $(B -H) switch to the compiler.
	D interface files have the $(B .di) file extension.
	When the compiler resolves an import declaration, it first looks
	for a $(B .di) D interface file, then it looks for a D source
	file.
	)

	$(P D interface files bear some analogous similarities to C++
	header files. But they are not required in the way that C++
	header files are, and they are not part of the D language.
	They are a feature of the compiler, and serve only as an optimization
	of the build process.
	)
)

Macros:
	TITLE=DMD Compiler
	WIKI=DCompiler
	LIB=$(V1 libphobos.a)$(V2 libphobos2.a)
