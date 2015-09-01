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
        $(TDNW
            $(LINK2 std_algorithm.html, std.algorithm)$(BR)
            $(LINK2 std_range.html, std.range)$(BR)
            $(LINK2 std_range_primitives.html, std.range.primitives)$(BR)
            $(LINK2 std_range_interfaces.html, std.range.interfaces)$(BR)
        )
        $(TD Generic algorithms that work with $(LINK2 std_range.html, ranges)
            of any type, including strings, arrays, and other kinds of
            sequentially-accessed data. Algorithms include searching,
            comparison, iteration, sorting, set operations, and mutation.
        )
    )
    $(LEADINGROW Array manipulation)
    $(TR
        $(TDNW
            $(LINK2 std_array.html, std.array)$(BR)
            $(LINK2 std_algorithm.html, std.algorithm)$(BR)
        )
        $(TD Convenient operations commonly used with built-in arrays.
            Note that many common array operations are subsets of more generic
            algorithms that work with arbitrary ranges, so they are found in
            $(D std.algorithm).
        )
    )
    $(LEADINGROW Containers)
    $(TR
        $(TDNW
            $(LINK2 std_container_array.html, std.container.array)$(BR)
            $(LINK2 std_container_binaryheap.html, std.container.binaryheap)$(BR)
            $(LINK2 std_container_dlist.html, std.container.dlist)$(BR)
            $(LINK2 std_container_rbtree.html, std.container.rbtree)$(BR)
            $(LINK2 std_container_slist.html, std.container.slist)$(BR)
        )
        $(TD See $(LINK2 std_container.html, std.container.*) for an
            overview.
        )
    )
    $(LEADINGROW Data formats)
    $(TR
        $(TDNW
            $(LINK2 std_base64.html, std.base64)$(BR)
            $(LINK2 std_csv.html, std.csv)$(BR)
            $(LINK2 std_json.html, std.json)$(BR)
            $(LINK2 std_xml.html, std.xml)$(BR)
            $(LINK2 std_zip.html, std.zip)$(BR)
            $(LINK2 std_zlib.html, std.zlib)$(BR)
        )
        $(TD
            Encoding / decoding Base64 format.$(BR)
            Read Comma Separated Values and its variants from an input range of $(CODE dchar).$(BR)
            Read/write data in JSON format.$(BR)
            Read/write data in XML format.$(BR)
            Read/write data in the ZIP archive format.$(BR)
            Compress/decompress data using the zlib library.$(BR)
        )
    )
    $(LEADINGROW Data integrity)
    $(TR
        $(TDNW
            $(LINK2 std_digest_crc.html, std.digest.crc)$(BR)
            $(LINK2 std_digest_digest.html, std.digest.digest)$(BR)
            $(LINK2 std_digest_hmac.html, std.digest.hmac)$(BR)
            $(LINK2 std_digest_md.html, std.digest.md)$(BR)
            $(LINK2 std_digest_ripemd.html, std.digest.ripemd)$(BR)
            $(LINK2 std_digest_sha.html, std.digest.sha)$(BR)
        )
        $(TD
            Cyclic Redundancy Check (32-bit) implementation.$(BR)
            Compute digests such as md5, sha1 and crc32.$(BR)
            Compute HMAC digests of arbitrary data.$(BR)
            Compute MD5 hash of arbitrary data.$(BR)
            Compute RIPEMD-160 hash of arbitrary data.$(BR)
            Compute SHA1 and SHA2 hashes of arbitrary data.$(BR)
        )
    )
    $(LEADINGROW Date &amp; time)
    $(TR
        $(TDNW
            $(LINK2 std_datetime.html, std.datetime)$(BR)
            $(LINK2 core_time.html, core.time)
        )
        $(TD
            Provides convenient access to date and time representations.$(BR)
            Implements low-level time primitives.
        )
    )
    $(LEADINGROW Exception handling)
    $(TR
        $(TDNW
            $(LINK2 std_exception.html, std.exception)$(BR)
            $(LINK2 core_exception.html, core.exception)
        )
        $(TD
            Implements routines related to exceptions.$(BR)
            Defines built-in exception types and low-level
            language hooks required by the compiler.
        )
    )
    $(LEADINGROW External library bindings)
    $(TR
        $(TDNW
            $(LINK2 etc_c_curl.html, etc.c.curl)$(BR)
            $(LINK2 etc_c_odbc_sql.html, etc.c.odbc.sql)$(BR)
            $(LINK2 etc_c_odbc_sqlext.html, etc.c.odbc.sqlext)$(BR)
            $(LINK2 etc_c_odbc_sqltypes.html, etc.c.odbc.sqltypes)$(BR)
            $(LINK2 etc_c_odbc_sqlucode.html, etc.c.odbc.sqlucode)$(BR)
            $(LINK2 etc_c_sqlite3.html, etc.c.sqlite3)$(BR)
            $(LINK2 etc_c_zlib.html, etc.c.zlib)$(BR)
        )
        $(TD Various bindings to external C libraries.
            Interface to libcurl C library.$(BR)
            Interface to ODBC C library.$(BR)$(BR)$(BR)$(BR)
            Interface to SQLite C library.$(BR)
            Interface to zlib C library.$(BR)
        )
    )
    $(LEADINGROW I/O &amp; File system)
    $(TR
        $(TDNW
            $(LINK2 std_file.html, std.file)$(BR)
            $(LINK2 std_path.html, std.path)$(BR)
            $(LINK2 std_stdio.html, std.stdio)
        )
        $(TD
            Manipulate files and directories.$(BR)
            Manipulate strings that represent filesystem paths.$(BR)
            Perform buffered I/O.
        )
    )
    $(LEADINGROW Interoperability)
    $(TR
        $(TDNW
            $(LINK2 core_stdc_complex.html, core.stdc.complex)$(BR)
            $(LINK2 core_stdc_ctype.html, core.stdc.ctype)$(BR)
            $(LINK2 core_stdc_errno.html, core.stdc.errno)$(BR)
            $(LINK2 core_stdc_fenv.html, core.stdc.fenv)$(BR)
            $(LINK2 core_stdc_float_.html, core.stdc.float_)$(BR)
            $(LINK2 core_stdc_inttypes.html, core.stdc.inttypes)$(BR)
            $(LINK2 core_stdc_limits.html, core.stdc.limits)$(BR)
            $(LINK2 core_stdc_locale.html, core.stdc.locale)$(BR)
            $(LINK2 core_stdc_math.html, core.stdc.math)$(BR)
            $(LINK2 core_stdc_signal.html, core.stdc.signal)$(BR)
            $(LINK2 core_stdc_stdarg.html, core.stdc.stdarg)$(BR)
            $(LINK2 core_stdc_stddef.html, core.stdc.stddef)$(BR)
            $(LINK2 core_stdc_stdint.html, core.stdc.stdint)$(BR)
            $(LINK2 core_stdc_stdio.html, core.stdc.stdio)$(BR)
            $(LINK2 core_stdc_stdlib.html, core.stdc.stdlib)$(BR)
            $(LINK2 core_stdc_string.html, core.stdc.string)$(BR)
            $(LINK2 core_stdc_tgmath.html, core.stdc.tgmath)$(BR)
            $(LINK2 core_stdc_time.html, core.stdc.time)$(BR)
            $(LINK2 core_stdc_wchar_.html, core.stdc.wchar_)$(BR)
            $(LINK2 core_stdc_wctype.html, core.stdc.wctype)$(BR)
        )
        $(TD
            D bindings for standard C headers.$(BR)$(BR)
            These are mostly undocumented, as documentation
            for the functions these declarations provide
            bindings to can be found on external resources.
        )
    )
    $(LEADINGROW Memory management)
    $(TR
        $(TDNW
            $(LINK2 core_memory.html, core.memory)$(BR)
            $(LINK2 std_typecons.html, std.typecons)$(BR)
        )
        $(TD
            Control the built-in garbage collector.$(BR)
            Build scoped variables and reference-counted types.
        )
    )
    $(LEADINGROW Metaprogramming)
    $(TR
        $(TDNW
            $(LINK2 core_attribute.html, core.attribute)$(BR)
            $(LINK2 core_demangle.html, core.demangle)$(BR)
            $(LINK2 std_demangle.html, std.demangle)$(BR)
            $(LINK2 std_meta.html, std.meta)$(BR)
            $(LINK2 std_traits.html, std.traits)$(BR)
            $(LINK2 std_typecons.html, std.typecons)$(BR)
        )
        $(TD
            Definitions of special attributes recognized by the compiler.$(BR)
            Convert $(I mangled) D symbol identifiers to source representation.$(BR)
            A simple wrapper around core.demangle.$(BR)
            Construct and manipulate template argument lists (aka type lists).$(BR)
            Extract information about types and symbols at compile time.$(BR)
            Construct new, useful general purpose types.$(BR)
        )
    )
    $(LEADINGROW Multitasking)
    $(TR
        $(TDNW
            $(LINK2 std_concurrency.html, std.concurrency)$(BR)
            $(LINK2 std_parallelism.html, std.parallelism)$(BR)
            $(LINK2 std_process.html, std.process)$(BR)
            $(LINK2 core_atomic.html, core.atomic)$(BR)
            $(LINK2 core_sync_barrier.html, core.sync.barrier)$(BR)
            $(LINK2 core_sync_condition.html, core.sync.condition)$(BR)
            $(LINK2 core_sync_exception.html, core.sync.exception)$(BR)
            $(LINK2 core_sync_mutex.html, core.sync.mutex)$(BR)
            $(LINK2 core_sync_rwmutex.html, core.sync.rwmutex)$(BR)
            $(LINK2 core_sync_semaphore.html, core.sync.semaphore)$(BR)
            $(LINK2 core_thread.html, core.thread)$(BR)
        )
        $(TD
            Low level messaging API for threads.$(BR)
            High level primitives for SMP parallelism.$(BR)
            Starting and manipulating processes.$(BR)
            Basic support for lock-free concurrent programming.$(BR)
            Synchronize the progress of a group of threads.$(BR)
            Synchronized condition checking.$(BR)
            Base class for synchronization exceptions.$(BR)
            Mutex for mutually exclusive access.$(BR)
            Shared read access and mutually exclusive write access.$(BR)
            General use synchronization semaphore.$(BR)
            Thread creation and management.$(BR)
        )
    )
    $(LEADINGROW Networking)
    $(TR
        $(TDNW
            $(LINK2 std_socket.html, std.socket)$(BR)
            $(LINK2 std_net_curl.html, std.net.curl)$(BR)
            $(LINK2 std_net_isemail.html, std.net.isemail)$(BR)
            $(LINK2 std_uri.html, std.uri)$(BR)
        )
        $(TD
            Socket primitives.$(BR)
            Networking client functionality as provided by libcurl.$(BR)
            Validates an email address according to RFCs 5321, 5322 and others.$(BR)
            Encode and decode Uniform Resource Identifiers (URIs).$(BR)
        )
    )
    $(LEADINGROW Numeric)
    $(TR
        $(TDNW
            $(LINK2 std_bigint.html, std.bigint)$(BR)
            $(LINK2 std_complex.html, std.complex)$(BR)
            $(LINK2 std_math.html, std.math)$(BR)
            $(LINK2 std_mathspecial.html, std.mathspecial)$(BR)
            $(LINK2 std_numeric.html, std.numeric)$(BR)
            $(LINK2 std_random.html, std.random)$(BR)
            $(LINK2 core_checkedint.html, core.checkedint)$(BR)
            $(LINK2 core_math.html, core.math)$(BR)
        )
        $(TD
            An arbitrary-precision integer type.$(BR)
            A complex number type.$(BR)
            Elementary mathematical functions (powers, roots, trigonometry).$(BR)
            Families of transcendental functions.$(BR)
            Floating point numerics functions.$(BR)
            Pseudo-random number generators.$(BR)
            Range-checking integral arithmetic primitives.$(BR)
            Built-in mathematical intrinsics.$(BR)
        )
    )
    $(LEADINGROW Paradigms)
    $(TR
        $(TDNW
            $(LINK2 std_functional.html, std.functional)$(BR)
            $(LINK2 std_algorithm.html, std.algorithm)$(BR)
            $(LINK2 std_signals.html, std.signals)$(BR)
        )
        $(TD
            Functions that manipulate other functions.$(BR)
            Generic algorithms for processing sequences.$(BR)
            Signal-and-slots framework for event-driven programming.$(BR)
        )
    )
    $(LEADINGROW Runtime utilities)
    $(TR
        $(TDNW
            $(LINK2 object.html, object)$(BR)
            $(LINK2 std_getopt.html, std.getopt)$(BR)
            $(LINK2 std_compiler.html, std.compiler)$(BR)
            $(LINK2 std_system.html, std.system)$(BR)
            $(LINK2 core_cpuid.html, core.cpuid)$(BR)
            $(LINK2 core_memory.html, core.memory)$(BR)
            $(LINK2 core_runtime.html, core.runtime)$(BR)
        )
        $(TD
            Core language definitions. Automatically imported.$(BR)
            Parsing of command-line arguments.$(BR)
            Host compiler vendor string and language version.$(BR)
            Runtime environment, such as OS type and endianness.$(BR)
            Capabilities of the CPU the program is running on.$(BR)
            Control the built-in garbage collector.$(BR)
            Control and configure the D runtime.$(BR)
        )
    )
    $(LEADINGROW String manipulation)
    $(TR
        $(TDNW
            $(LINK2 std_string.html, std.string)$(BR)
            $(LINK2 std_array.html, std.array)$(BR)
            $(LINK2 std_algorithm.html, std.algorithm)$(BR)
            $(LINK2 std_uni.html, std.uni)$(BR)
            $(LINK2 std_utf.html, std.utf)$(BR)
            $(LINK2 std_format.html, std.format)$(BR)
            $(LINK2 std_path.html, std.path)$(BR)
            $(LINK2 std_regex.html, std.regex)$(BR)
            $(LINK2 std_ascii.html, std.ascii)$(BR)
            $(LINK2 std_encoding.html, std.encoding)$(BR)
            $(LINK2 std_windows_charset.html, std.windows.charset)$(BR)
            $(LINK2 std_outbuffer.html, std.outbuffer)$(BR)
        )
        $(TD
            Algorithms that work specifically with strings.$(BR)
            Manipulate builtin arrays.$(BR)
            Generic algorithms for processing sequences.$(BR)
            Fundamental Unicode algorithms and data structures.$(BR)
            Encode and decode UTF-8, UTF-16 and UTF-32 strings.$(BR)
            Format data into strings.$(BR)
            Manipulate strings that represent filesystem paths.$(BR)
            Regular expressions.$(BR)
            Routines specific to the ASCII subset of Unicode.$(BR)
            Handle and transcode between various text encodings.$(BR)
            Windows specific character set support.$(BR)
            Serialize data to $(CODE ubyte) arrays.$(BR)
        )
    )
    $(LEADINGROW Type manipulations)
    $(TR
        $(TDNW
            $(LINK2 std_conv.html, std.conv)$(BR)
            $(LINK2 std_typecons.html, std.typecons)$(BR)
            $(LINK2 std_bitmanip.html, std.bitmanip)$(BR)
            $(LINK2 std_variant.html, std.variant)$(BR)
            $(LINK2 core_bitop.html, core.bitop)$(BR)
        )
        $(TD
            Convert types from one type to another.$(BR)
            Type constructors for scoped variables, ref counted types, etc.$(BR)
            High level bit level manipulation, bit arrays, bit fields.$(BR)
            Discriminated unions and algebraic types.$(BR)
            Low level bit manipulation.$(BR)
        )
    )
    $(LEADINGROW Vector programming)
    $(TR
        $(TDNW
            $(LINK2 core_simd.html, core.simd)$(BR)
        )
        $(TD
             SIMD intrinsics
        )
    )

$(COMMENT
    $(LEADINGROW Undocumented modules (intentionally omitted).)
    $(TR
        $(TDNW
            $(LINK2 core_sync_config.html, core.sync.config)$(BR)
            $(LINK2 std_concurrencybase.html, std.concurrencybase)$(BR)
            $(LINK2 std_container_util.html, std.container.util)$(BR)
            $(LINK2 std_regex_internal_backtracking.html, std.regex.internal.backtracking)$(BR)
            $(LINK2 std_regex_internal_generator.html, std.regex.internal.generator)$(BR)
            $(LINK2 std_regex_internal_ir.html, std.regex.internal.ir)$(BR)
            $(LINK2 std_regex_internal_kickstart.html, std.regex.internal.kickstart)$(BR)
            $(LINK2 std_regex_internal_parser.html, std.regex.internal.parser)$(BR)
            $(LINK2 std_regex_internal_tests.html, std.regex.internal.tests)$(BR)
            $(LINK2 std_regex_internal_thompson.html, std.regex.internal.thompson)$(BR)
            $(LINK2 std_stdiobase.html, std.stdiobase)$(BR)
        )
        $(TD
             Internal modules.
        )
    )
    $(TR
        $(TDNW
            $(LINK2 core_vararg.html, core.vararg)$(BR)
            $(LINK2 std_c_fenv.html, std.c.fenv)$(BR)
            $(LINK2 std_c_linux_linux.html, std.c.linux_linux)$(BR)
            $(LINK2 std_c_linux_socket.html, std.c.linux_socket)$(BR)
            $(LINK2 std_c_locale.html, std.c.locale)$(BR)
            $(LINK2 std_c_math.html, std.c.math)$(BR)
            $(LINK2 std_c_process.html, std.c.process)$(BR)
            $(LINK2 std_c_stdarg.html, std.c.stdarg)$(BR)
            $(LINK2 std_c_stddef.html, std.c.stddef)$(BR)
            $(LINK2 std_c_stdio.html, std.c.stdio)$(BR)
            $(LINK2 std_c_stdlib.html, std.c.stdlib)$(BR)
            $(LINK2 std_c_string.html, std.c.string)$(BR)
            $(LINK2 std_c_time.html, std.c.time)$(BR)
            $(LINK2 std_c_wcharh.html, std.c.wcharh)$(BR)
            $(LINK2 std_stdint.html, std.stdint)$(BR)
        )
        $(TDN
             Redirect modules.
        )
    )
    $(TR
        $(TDNW
            $(LINK2 std_cstream.html, std.cstream)$(BR)
            $(LINK2 std_metastrings.html, std.metastrings)$(BR)
            $(LINK2 std_mmfile.html, std.mmfile)$(BR)
            $(LINK2 std_socketstream.html, std.socketstream)$(BR)
            $(LINK2 std_stream.html, std.stream)$(BR)
            $(LINK2 std_syserror.html, std.syserror)$(BR)
            $(LINK2 std_typetuple.html, std.typetuple)$(BR)
        )
        $(TD
             Deprecated modules.
        )
    )
    $(TR
        $(TDNW
            $(LINK2 std_experimental_logger.html, std.experimental.logger)$(BR)
            $(LINK2 std_experimental_logger_core.html, std.experimental.logger.core)$(BR)
            $(LINK2 std_experimental_logger_filelogger.html, std.experimental.logger.filelogger)$(BR)
            $(LINK2 std_experimental_logger_multilogger.html, std.experimental.logger.multilogger)$(BR)
            $(LINK2 std_experimental_logger_nulllogger.html, std.experimental.logger.nulllogger)$(BR)
        )
        $(TD
             Experimental modules.
        )
    )
)
)

Macros:
        TITLE=Phobos Runtime Library
        WIKI=Phobos
