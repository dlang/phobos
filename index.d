Ddoc

Phobos is the standard runtime library that comes with the
D language compiler. Also, check out the
<a href="http://www.prowiki.org/wiki4d/wiki.cgi?Phobos">wiki for Phobos</a>.


<h2>Philosophy</h2>

	Each module in Phobos conforms as much as possible to the
	following design goals. These are goals
	rather than requirements because D is not a religion,
	it's a programming language, and it recognizes that
	sometimes the goals are contradictory and counterproductive
	in certain situations, and programmers have
	jobs that need to get done.

	<dl><dl>


	<dt>Machine and Operating System Independent Interfaces

	<dd>It's pretty well accepted that gratuitous non-portability
	should be avoided. This should not be
	construed, however, as meaning that access to unusual
	features of an operating system should be prevented.


	<dt>Simple Operations should be Simple

	<dd>A common and simple operation, like writing an array of
	bytes to a file, should be simple to
	code. I haven't seen a class library yet that simply and efficiently
	implemented common, basic file I/O operations.


	<dt>Classes should strive to be independent of one another

	<dd>It's discouraging to pull in a megabyte of code bloat
	by just trying to read a file into an array of
	bytes. Class independence also means that classes that turn
	out to be mistakes can be deprecated and redesigned without
	forcing a rewrite of the rest of the class library.


	<dt>No pointless wrappers around C runtime library functions or OS API functions

	<dd>D provides direct access to C runtime library functions
	and operating system API functions.
	Pointless D wrappers around those functions just adds blather,
	bloat, baggage and bugs.


	<dt>Class implementations should use DBC

	<dd>This will prove that DBC (Contract Programming) is worthwhile.
	Not only will it aid in debugging the class, but
	it will help every class user use the class correctly.
	DBC in the class library will have great leverage.


	<dt>Use Exceptions for Error Handling

	<dd>See <a href="../errors.html">Error Handling in D</a>.

	</dl></dl>

<hr>
<h2>Imports</h2>

	Runtime library modules can be imported with the
	<b>import</b> statement. Each module falls into one of several
	packages:

	<dl>
	<dt><a href="#std">std</a>
	<dd>These are the core modules.
	<p>

	<dl>
	<dt><a href="#std_windows">std.windows</a>
	<dd>Modules specific to the Windows operating system.
	<p>

	<dt><a href="#std_linux">std.linux</a>
	<dd>Modules specific to the Linux operating system.
	<p>

	<dt><a href="#std_c">std.c</a>
	<dd>Modules that are simply interfaces to C functions.
	For example, interfaces to standard C library functions
	will be in std.c, such as std.c.stdio would be the interface
	to C's stdio.h.
	<p>

	<dl>
	<dt><a href="#std_c_windows">std.c.windows</a>
	<dd>Modules corresponding to the C Windows API functions.
	<p>

	<dt><a href="#std_c_linux">std.c.linux</a>
	<dd>Modules corresponding to the C Linux API functions.
	<p>

	</dl>
	</dl>

	</dl>

	<dl>
	<dt><b>etc</b>
	<dd>This is the root of a hierarchy of modules mirroring the std
	hierarchy. Modules in etc are not standard D modules. They are
	here because they are experimental, or for some other reason are
	not quite suitable for std, although they are still useful.
	<p>
	</dl>

<hr>
<a name="std"><h3>std: Core library modules</h3></a>

	<dl>

	<dt><a href="std_ascii.html"><b>std.ascii</b></a>
	<dd>Functions that operate on ASCII characters.

	<dt><a href="std_base64.html"><b>std.base64</b></a>
	<dd>Encode/decode base64 format.

	<dt><a href="std_bigint.html"><b>std.bigint</b></a>
	<dd>Arbitrary-precision ('bignum') arithmetic

$(V1
	<dt><a href="std_bitarray.html"><b>std.bitarray</b></a>
	<dd>Arrays of bits.

	<dt><a href="std_boxer.html"><b>std.boxer</b></a>
	<dd>Box/unbox types.
)
	<dt><a href="std_compiler.html"><b>std.compiler</b></a>
	<dd>Information about the D compiler implementation.

	<dt><a href="std_conv.html"><b>std.conv</b></a>
	<dd>Conversion of strings to integers.

$(V1
	<dt><a href="std_date.html"><b>std.date</b></a>
	<dd>Date and time functions. Support locales.
)

	<dt><a href="std_datetime.html"><b>std.datetime</b></a>
	<dd>Date and time-related types and functions.

	<dt><a href="std_file.html"><b>std.file</b></a>
	<dd>Basic file operations like read, write, append.

	<dt><a href="std_format.html"><b>std.format</b></a>
	<dd>Formatted conversions of values to strings.

$(V1
	<dt><a href="std_gc.html"><b>std.gc</b></a>
	<dd>Control the garbage collector.
)
	<dt><a href="std_math.html"><b>std.math</b></a>
	<dd>Include all the usual math functions like sin, cos, atan, etc.

	<dt><a href="std_md5.html"><b>std.md5</b></a>
	<dd>Compute MD5 digests.

	<dt><a href="std_mmfile.html"><b>std.mmfile</b></a>
	<dd>Memory mapped files.

	<dt><a href="object.html"><b>object</b></a>
	<dd>The root class of the inheritance hierarchy

	<dt><a href="std_outbuffer.html"><b>std.outbuffer</b></a>
	<dd>Assemble data into an array of bytes

	<dt><a href="std_path.html"><b>std.path</b></a>
	<dd>Manipulate file names, path names, etc.

	<dt><a href="std_process.html"><b>std.process</b></a>
	<dd>Create/destroy threads.

	<dt><a href="std_random.html"><b>std.random</b></a>
	<dd>Random number generation.

$(V1
	<dt><a href="std_recls.html"><b>std.recls</b></a>
	<dd>Recursively search file system and (currently Windows
	only) FTP sites.
)
	<dt><a href="std_regex.html"><b>std.regex</b></a>
	<dd>The usual regular expression functions.

	<dt><a href="std_socket.html"><b>std.socket</b></a>
	<dd>Sockets.

	<dt><a href="std_socketstream.html"><b>std.socketstream</b></a>
	<dd>Stream for a blocking, connected <b>Socket</b>.

	<dt><a href="std_stdint.html"><b>std.stdint</b></a>
	<dd>Integral types for various purposes.

	<dt><a href="std_stdio.html"><b>std.stdio</b></a>
	<dd>Standard I/O.

	<dt><a href="std_cstream.html"><b>std.cstream</b></a>
	<dd>Stream I/O.

	<dt><a href="std_stream.html"><b>std.stream</b></a>
	<dd>Stream I/O.

	<dt><a href="std_string.html"><b>std.string</b></a>
	<dd>Basic string operations not covered by array ops.

	<dt><a href="std_system.html"><b>std.system</b></a>
	<dd>Inquire about the CPU, operating system.

	<!--dt><a href="std_thread.html"><b>std.thread</b></a>
	<dd>One per thread. Operations to do on a thread.-->

	<dt><a href="std_uni.html"><b>std.base64</b></a>
	<dd>Functions that operate on Unicode characters.

	<dt><a href="std_uri.html"><b>std.uri</b></a>
	<dd>Encode and decode Uniform Resource Identifiers (URIs).

	<dt><a href="std_utf.html"><b>std.utf</b></a>
	<dd>Encode and decode utf character encodings.

	<dt><a href="std_zip.html"><b>std.zip</b></a>
	<dd>Read/write zip archives.

	<dt><a href="std_zlib.html"><b>std.zlib</b></a>
	<dd>Compression / Decompression of data.

	</dl>

<hr><!-- ===================================== -->
<a name="std_windows"><h3>std.windows: Modules specific to the Windows operating system</h3></a>

	<dl>

	<dt><b>std.windows.syserror</b></a>
	<dd>Convert Windows error codes to strings.

	</dl>

<hr><!-- ===================================== -->
<a name="std_linux"><h3>std.linux: Modules specific to the Linux operating system</h3></a>

<hr><!-- ===================================== -->
<a name="std_c"><h3>std.c: Interface to C functions</h3></a>

	<dl>

	<dt><a href="#stdio"><b>std.c.stdio</b></a>
	<dd>Interface to C stdio functions like printf().

	</dl>

<hr><!-- ===================================== -->
<a name="std_c_windows"><h3>std.c.windows: Interface to C Windows functions</h3></a>

	<dl>

	<dt><b>std.c.windows.windows</b>
	<dd>Interface to Windows APIs

	</dl>

<hr><!-- ===================================== -->
<a name="std_c_linux"><h3>std.c.linux: Interface to C Linux functions</h3></a>

	<dl>

	<dt><b>std.c.linux.linux</b>
	<dd>Interface to Linux APIs

	</dl>

<hr><!-- ===================================== -->
<a name="stdio"><h2>std.c.stdio</h2></a>

<dl><dl>
	<dt>int <b>printf</b>(char* format, ...)
	<dd>C printf() function.
</dl></dl>

Macros:
	TITLE=Phobos Runtime Library
	WIKI=Phobos

