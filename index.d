Ddoc

$(P Phobos is the standard runtime library that comes with the D language
compiler.)

$(P Generally, the $(D std) namespace is used for the main modules in the
Phobos standard library. The $(D etc) namespace is used for external C/C++
library bindings. The $(D core) namespace is used for low-level D runtime
functions.)

$(P The following table is a quick reference guide for which Phobos modules to
use for a given category of functionality. Note that some modules may appear in
more than one category, as some Phobos modules are quite generic and can be
applied in a variety of situations.)

$(BOOKTABLE ,
    $(TR
        $(TH Modules)
        $(TH Description)
    )
    $(LEADINGROW Algorithms &amp; ranges)
    $(TR
        $(TD
            $(LINK2 std_algorithm_package.html, std.algorithm)$(BR)
            $(LINK2 std_range_package.html, std.range)$(BR)
            $(LINK2 std_range_primitives.html, std.range.primitives)$(BR)
            $(LINK2 std_range_interfaces.html, std.range.interfaces)
        )
        $(TD Generic algorithms that work with $(LINK2 std_range.html, ranges)
            of any type, including strings, arrays, and other kinds of
            sequentially-accessed data. Algorithms include searching,
            comparison, iteration, sorting, set operations, and mutation.
        )
    )
    $(LEADINGROW Array manipulation)
    $(TR
        $(TD
            $(LINK2 std_array.html, std.array)$(BR)
            $(LINK2 std_algorithm_package.html, std.algorithm)
        )
        $(TD Convenient operations commonly used with built-in arrays.
            Note that many common array operations are subsets of more generic
            algorithms that work with arbitrary ranges, so they are found in
            $(D std.algorithm).
        )
    )
    $(LEADINGROW Containers)
    $(TR
        $(TD
            $(LINK2 std_container_array.html, std.container.array)$(BR)
            $(LINK2 std_container_binaryheap.html, std.container.binaryheap)$(BR)
            $(LINK2 std_container_dlist.html, std.container.dlist)$(BR)
            $(LINK2 std_container_rbtree.html, std.container.rbtree)$(BR)
            $(LINK2 std_container_slist.html, std.container.slist)
        )
        $(TD See $(LINK2 std_container_package.html, std.container.*) for an
            overview.
        )
    )
    $(LEADINGROW Data formats)
    $(TR
        $(TD
            $(LINK2 std_base64.html, std.base64)$(BR)
            $(LINK2 std_csv.html, std.csv)$(BR)
            $(LINK2 std_json.html, std.json)$(BR)
            $(LINK2 std_xml.html, std.xml)$(BR)
            $(LINK2 std_zip.html, std.zip)$(BR)
            $(LINK2 std_zlib.html, std.zlib)
        )
        $(TD Modules for reading/writing different data formats.
        )
    )
    $(LEADINGROW Data integrity)
    $(TR
        $(TD
            $(LINK2 std_digest_crc, std.digest.crc)$(BR)
            $(LINK2 std_digest_digest, std.digest.digest)$(BR)
            $(LINK2 std_digest_md, std.digest.md)$(BR)
            $(LINK2 std_digest_ripemd, std.digest.ripemd)$(BR)
            $(LINK2 std_digest_sha, std.digest.sha)$(BR)
        )
        $(TD Hash algorithms for verifying data integrity.
        )
    )
    $(LEADINGROW Date &amp; time)
    $(TR
        $(TD
            $(LINK2 std_datetime.html, std.datetime)$(BR)
            $(LINK2 core_time.html, core.time)
        )
        $(TD $(D std.datetime) provides convenient access to date and time
        representations.$(BR)
        $(D core.time) implements low-level time primitives.
        )
    )
    $(LEADINGROW Exception handling)
    $(TR
        $(TD
            $(LINK2 std_exception.html, std.exception)$(BR)
            $(LINK2 core_exception.html, core.exception)
        )
        $(TD $(D std.exception) implements routines related to exceptions.
            $(D core.exception) defines built-in exception types and low-level
            language hooks required by the compiler.
        )
    )
    $(LEADINGROW External library bindings)
    $(TR
        $(TD
            $(LINK2 etc_c_curl.html, etc.c.curl)$(BR)
            $(LINK2 etc_c_sqlite3.html, etc.c.sqlite3)$(BR)
            $(LINK2 etc_c_zlib.html, etc.c.zlib)
        )
        $(TD Various bindings to external C libraries.
        )
    )
    $(LEADINGROW I/O &amp; File system)
    $(TR
        $(TD
            $(LINK2 std_file.html, std.file)$(BR)
            $(LINK2 std_path.html, std.path)$(BR)
            $(LINK2 std_stdio.html, std.stdio)
        )
        $(TD
            $(D std.stdio) is the main module for I/O.$(BR)
            $(D std.file) is for accessing the operating system's filesystem,
            and $(D std.path) is for manipulating filesystem pathnames in a
            platform-independent way.$(BR)
	    Note that $(D std.stream) and $(D std.cstream) are older,
	    deprecated modules scheduled to be replaced in the future; new
	    client code should avoid relying on them.
        )
    )
    $(LEADINGROW Memory management)
    $(TR
        $(TD
            $(LINK2 core_memory.html, core.memory)$(BR)
            $(LINK2 std_typecons.html, std.typecons)$(BR)
        )
        $(TD
            $(D core.memory) provides an API for user code to control the
            built-in garbage collector.$(BR)
            $(D std.typecons) contains primitives for building scoped variables
            and reference-counted types.
        )
    )
    $(LEADINGROW Metaprogramming)
    $(TR
        $(TD 
            $(LINK2 std_traits.html, std.traits)$(BR)
            $(LINK2 std_typecons.html, std.typecons)$(BR)
            $(LINK2 std_typetuple.html, std.typetuple)$(BR)
            $(LINK2 core_demangle.html, core.demangle)
        )
        $(TD
            These modules provide the primitives for compile-time introspection
            and metaprogramming.
        )
    )
    $(LEADINGROW Multitasking)
    $(TR
        $(TD
            $(LINK2 std_concurrency, std.concurrency)$(BR)
            $(LINK2 std_parallelism, std.parallelism)$(BR)
            $(LINK2 std_process, std.process)$(BR)
            $(LINK2 core_atomic, core.atomic)$(BR)
            $(LINK2 core_sync_barrier, core.sync.barrier)$(BR)
            $(LINK2 core_sync_condition, core.sync.condition)$(BR)
            $(LINK2 core_sync_exception, core.sync.exception)$(BR)
            $(LINK2 core_sync_mutex, core.sync.mutex)$(BR)
            $(LINK2 core_sync_rwmutex, core.sync.rwmutex)$(BR)
            $(LINK2 core_sync_semaphore, core.sync.semaphore)$(BR)
            $(LINK2 core_thread, core.thread)
        )
        $(TD These modules provide primitives for concurrent processing,
	    multithreading, synchronization, and interacting with operating
	    system processes.$(BR)

            $(D core.atomic) provides primitives for lock-free concurrent
            programming.$(BR)

            $(D core.sync.*) modules provide low-level concurrent
            programming building blocks.$(BR)

            $(D core.thread) implements multithreading primitives.
        )
    )
    $(LEADINGROW Networking)
    $(TR
        $(TD
            $(LINK2 std_socket.html, std.socket)$(BR)
            $(LINK2 std_socketstream.html, std.socketstream)$(BR)
            $(LINK2 std_net_curl.html, std.net.curl)$(BR)
            $(LINK2 std_net_isemail.html, std.net.isemail)
        )
        $(TD Utilities for networking.
        )
    )
    $(LEADINGROW Numeric)
    $(TR
        $(TD
            $(LINK2 std_bigint.html, std.bigint)$(BR)
            $(LINK2 std_complex.html, std.complex)$(BR)
            $(LINK2 std_math.html, std.math)$(BR)
            $(LINK2 std_mathspecial.html, std.mathspecial)$(BR)
            $(LINK2 std_numeric.html, std.numeric)$(BR)
            $(LINK2 std_random.html, std.random)
        )
        $(TD These modules provide the standard mathematical functions and
            numerical algorithms.$(BR)
            $(D std.bigint) provides an arbitrary-precision integer type.$(BR)
            $(D std.complex) provides a complex number type.$(BR)
            $(D std.random) provides pseudo-random number generators.
        )
    )
    $(LEADINGROW Paradigms)
    $(TR
        $(TD
            $(LINK2 std_functional, std.functional)$(BR)
            $(LINK2 std_algorithm_package, std.algorithm)$(BR)
            $(LINK2 std_signals, std.signals)
        )
        $(TD $(D std.functional), along with the lazy algorithms of
            $(D std.algorithm), provides utilities for writing functional-style
            code in D.$(BR)

            $(D std.signals) provides a signal-and-slots framework for
            event-driven programming.
        )
    )
    $(LEADINGROW Runtime utilities)
    $(TR
        $(TD
            $(LINK2 std_getopt.html, std.getopt)$(BR)
            $(LINK2 std_compiler.html, std.compiler)$(BR)
            $(LINK2 std_system.html, std.system)$(BR)
            $(LINK2 core_cpuid.html, core.cpuid)$(BR)
            $(LINK2 core_memory.html, core.memory)$(BR)
        )
        $(TD Various modules for interacting with the execution environment and
            compiler.$(BR)
            $(D std.getopt) implements parsing of command-line arguments.$(BR)
            $(D std.compiler) provides compiler information, mainly the
            compiler vendor string and language version.$(BR)
            $(D std.system) provides information about the runtime environment,
            such as OS type and endianness.$(BR)
            $(D core.cpuid) provides information on the capabilities of the
            CPU the program is running on.$(BR)
            $(D core.memory) allows user code to control the built-in garbage
            collector.
        )
    )
    $(LEADINGROW String manipulation)
    $(TR
        $(TD
            $(LINK2 std_string.html, std.string)$(BR)
            $(LINK2 std_array.html, std.array)$(BR)
            $(LINK2 std_algorithm_package.html, std.algorithm)$(BR)
            $(LINK2 std_uni, std.uni)$(BR)
            $(LINK2 std_utf, std.utf)$(BR)
            $(LINK2 std_format.html, std.format)$(BR)
            $(LINK2 std_path.html, std.path)$(BR)
            $(LINK2 std_regex.html, std.regex)$(BR)
            $(LINK2 std_ascii, std.ascii)$(BR)
            $(LINK2 std_encoding.html, std.encoding)$(BR)
            $(LINK2 std_windows_charset.html, std.windows.charset)
        )
        $(TD $(D std.string) contains functions that work specifically with
            strings.$(BR)

            Many string manipulations are special cases of more generic
            algorithms that work with general arrays, or generic ranges; these
            are found in $(D std.array) and $(D std.algorithm).$(BR)

            D strings are encoded in Unicode; $(D std.uni) provides operations
            that work with Unicode strings in general, while $(D std.utf) deals
            with specific Unicode encodings and conversions between them.$(BR)

            $(D std.format) provides $(D printf)-style format string
            formatting, with D's own improvements and extensions.$(BR)

            For manipulating filesystem pathnames, $(D std.path) is
            provided.$(BR)

            $(D std.regex) is a very fast library for string matching and
            substitution using regular expressions.$(BR)

            $(D std.ascii) provides routines specific to the ASCII subset of
            Unicode.

            Windows-specific character set support is provided by
            $(D std.windows.charset).

            Rudimentary support for other string encodings is provided by
            $(D std.encoding).
        )
    )
    $(LEADINGROW Type manipulations)
    $(TR
        $(TD
            $(LINK2 std_conv.html, std.conv)$(BR)
            $(LINK2 std_typecons.html, std.typecons)$(BR)
            $(LINK2 std_bitmanip.html, std.bitmanip)$(BR)
            $(LINK2 core_bitop.html, core.bitop)$(BR)
        )
        $(TD $(D std.conv) provides powerful automatic conversions between
            built-in types as well as user-defined types that implement
            standard conversion primitives.$(BR)

            $(D std.typecons) provides various utilities for type construction
            and compile-time type introspection. It provides facilities for
            constructing scoped variables and reference-counted types, as well
            as miscellaneous useful generic types such as tuples and
            flags.$(BR)

            $(D std.bitmanip) provides various bit-level operations, bit
            arrays, and bit fields. $(D core.bitop) provides low-level bit
            manipulation primitives.$(BR)
        )
    )
    $(LEADINGROW Vector programming)
    $(TR
        $(TD
            $(LINK2 core_simd, core.simd)$(BR)
        )
        $(TD The $(D core.simd) module provides access to SIMD intrinsics in
        the compiler.)
    )
)

Macros:
	TITLE=Phobos Runtime Library
	WIKI=Phobos

