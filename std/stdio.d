// Written in the D programming language.

/**
Standard I/O functions that extend $(B core.stdc.stdio).  $(B core.stdc.stdio)
is $(D_PARAM public)ally imported when importing $(B std.stdio).

Source: $(PHOBOSSRC std/_stdio.d)
Macros:
WIKI=Phobos/StdStdio

Copyright: Copyright Digital Mars 2007-.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           Alex Rønne Petersen
 */
module std.stdio;

public import core.stdc.stdio;
import std.typecons;// Flag
import std.stdiobase;
import core.stdc.stddef;// wchar_t
import std.range.primitives;// empty, front, isBidirectionalRange
import std.traits;// Unqual, isSomeChar, isSomeString


/++
If flag $(D KeepTerminator) is set to $(D KeepTerminator.yes), then the delimiter
is included in the strings returned.
+/
alias KeepTerminator = Flag!"keepTerminator";

version (CRuntime_Microsoft)
{
    version = MICROSOFT_STDIO;
}
else version (CRuntime_DigitalMars)
{
    // Specific to the way Digital Mars C does stdio
    version = DIGITAL_MARS_STDIO;
}

version (linux)
{
    // Specific to the way Gnu C does stdio
    version = GCC_IO;
}

version (OSX)
{
    version = GENERIC_IO;
}

version (FreeBSD)
{
    version = GENERIC_IO;
}

version (Solaris)
{
    version = GENERIC_IO;
}

version (Android)
{
    version = GENERIC_IO;
}

version(Windows)
{
    // core.stdc.stdio.fopen expects file names to be
    // encoded in CP_ACP on Windows instead of UTF-8.
    /+ Waiting for druntime pull 299
    +/
    extern (C) nothrow @nogc FILE* _wfopen(in wchar* filename, in wchar* mode);

    import core.sys.windows.windows : HANDLE;
}

version (DIGITAL_MARS_STDIO)
{
    extern (C)
    {
        /* **
         * Digital Mars under-the-hood C I/O functions.
         * Use _iobuf* for the unshared version of FILE*,
         * usable when the FILE is locked.
         */
      nothrow:
      @nogc:
        int _fputc_nlock(int, _iobuf*);
        int _fputwc_nlock(int, _iobuf*);
        int _fgetc_nlock(_iobuf*);
        int _fgetwc_nlock(_iobuf*);
        int __fp_lock(FILE*);
        void __fp_unlock(FILE*);

        int setmode(int, int);
    }
    alias FPUTC = _fputc_nlock;
    alias FPUTWC = _fputwc_nlock;
    alias FGETC = _fgetc_nlock;
    alias FGETWC = _fgetwc_nlock;

    alias FLOCK = __fp_lock;
    alias FUNLOCK = __fp_unlock;

    alias _setmode = setmode;
    enum _O_BINARY = 0x8000;
    int _fileno(FILE* f) { return f._file; }
    alias fileno = _fileno;
}
else version (MICROSOFT_STDIO)
{
    extern (C)
    {
        /* **
         * Microsoft under-the-hood C I/O functions
         */
      nothrow:
      @nogc:
        int _fputc_nolock(int, _iobuf*);
        int _fputwc_nolock(int, _iobuf*);
        int _fgetc_nolock(_iobuf*);
        int _fgetwc_nolock(_iobuf*);
        void _lock_file(FILE*);
        void _unlock_file(FILE*);
        int _setmode(int, int);
        int _fileno(FILE*);
        FILE* _fdopen(int, const (char)*);
    }
    alias FPUTC = _fputc_nolock;
    alias FPUTWC = _fputwc_nolock;
    alias FGETC = _fgetc_nolock;
    alias FGETWC = _fgetwc_nolock;

    alias FLOCK = _lock_file;
    alias FUNLOCK = _unlock_file;

    enum
    {
        _O_RDONLY = 0x0000,
        _O_APPEND = 0x0004,
        _O_TEXT   = 0x4000,
        _O_BINARY = 0x8000,
    }
}
else version (GCC_IO)
{
    /* **
     * Gnu under-the-hood C I/O functions; see
     * http://gnu.org/software/libc/manual/html_node/I_002fO-on-Streams.html
     */
    extern (C)
    {
      nothrow:
      @nogc:
        int fputc_unlocked(int, _iobuf*);
        int fputwc_unlocked(wchar_t, _iobuf*);
        int fgetc_unlocked(_iobuf*);
        int fgetwc_unlocked(_iobuf*);
        void flockfile(FILE*);
        void funlockfile(FILE*);
        ptrdiff_t getline(char**, size_t*, FILE*);
        ptrdiff_t getdelim (char**, size_t*, int, FILE*);

        private size_t fwrite_unlocked(const(void)* ptr,
                size_t size, size_t n, _iobuf *stream);
    }

    alias FPUTC = fputc_unlocked;
    alias FPUTWC = fputwc_unlocked;
    alias FGETC = fgetc_unlocked;
    alias FGETWC = fgetwc_unlocked;

    alias FLOCK = flockfile;
    alias FUNLOCK = funlockfile;
}
else version (GENERIC_IO)
{
    nothrow:
    @nogc:

    extern (C)
    {
        void flockfile(FILE*);
        void funlockfile(FILE*);
    }

    int fputc_unlocked(int c, _iobuf* fp) { return fputc(c, cast(shared) fp); }
    int fputwc_unlocked(wchar_t c, _iobuf* fp)
    {
        import core.stdc.wchar_ : fputwc;
        return fputwc(c, cast(shared) fp);
    }
    int fgetc_unlocked(_iobuf* fp) { return fgetc(cast(shared) fp); }
    int fgetwc_unlocked(_iobuf* fp)
    {
        import core.stdc.wchar_ : fgetwc;
        return fgetwc(cast(shared) fp);
    }

    alias FPUTC = fputc_unlocked;
    alias FPUTWC = fputwc_unlocked;
    alias FGETC = fgetc_unlocked;
    alias FGETWC = fgetwc_unlocked;

    alias FLOCK = flockfile;
    alias FUNLOCK = funlockfile;
}
else
{
    static assert(0, "unsupported C I/O system");
}

//------------------------------------------------------------------------------
struct ByRecord(Fields...)
{
private:
    import std.typecons : Tuple;

    File file;
    char[] line;
    Tuple!(Fields) current;
    string format;

public:
    this(File f, string format)
    {
        assert(f.isOpen);
        file = f;
        this.format = format;
        popFront(); // prime the range
    }

    /// Range primitive implementations.
    @property bool empty()
    {
        return !file.isOpen;
    }

    /// Ditto
    @property ref Tuple!(Fields) front()
    {
        return current;
    }

    /// Ditto
    void popFront()
    {
        import std.conv : text;
        import std.exception : enforce;
        import std.format : formattedRead;
        import std.string : chomp;

        enforce(file.isOpen);
        file.readln(line);
        if (!line.length)
        {
            file.detach();
        }
        else
        {
            line = chomp(line);
            formattedRead(line, format, &current);
            enforce(line.empty, text("Leftover characters in record: `",
                            line, "'"));
        }
    }
}

template byRecord(Fields...)
{
    ByRecord!(Fields) byRecord(File f, string format)
    {
        return typeof(return)(f, format);
    }
}

/**
Encapsulates a $(D FILE*). Generally D does not attempt to provide
thin wrappers over equivalent functions in the C standard library, but
manipulating $(D FILE*) values directly is unsafe and error-prone in
many ways. The $(D File) type ensures safe manipulation, automatic
file closing, and a lot of convenience.

The underlying $(D FILE*) handle is maintained in a reference-counted
manner, such that as soon as the last $(D File) variable bound to a
given $(D FILE*) goes out of scope, the underlying $(D FILE*) is
automatically closed.

Bugs:
$(D File) expects file names to be encoded in $(B CP_ACP) on $(I Windows)
instead of UTF-8 ($(BUGZILLA 7648)) thus must not be used in $(I Windows)
or cross-platform applications other than with an immediate ASCII string as
a file name to prevent accidental changes to result in incorrect behavior.
One can use $(XREF file, read)/$(XREF file, write)/$(XREF stream, _File)
instead.

Example:
----
// test.d
void main(string args[])
{
    auto f = File("test.txt", "w"); // open for writing
    f.write("Hello");
    if (args.length > 1)
    {
        auto g = f; // now g and f write to the same file
                    // internal reference count is 2
        g.write(", ", args[1]);
        // g exits scope, reference count decreases to 1
    }
    f.writeln("!");
    // f exits scope, reference count falls to zero,
    // underlying $(D FILE*) is closed.
}
----
<pre class=console>
% rdmd test.d Jimmy
% cat test.txt
Hello, Jimmy!
% __
</pre>
 */
struct File
{
    import std.traits : isScalarType, isArray;
    import std.range.primitives : ElementEncodingType;

    private struct Impl
    {
        FILE * handle = null; // Is null iff this Impl is closed by another File
        uint refs = uint.max / 2;
        bool isPopened; // true iff the stream has been created by popen()
    }
    private Impl* _p;
    private string _name;

    package this(FILE* handle, string name, uint refs = 1, bool isPopened = false) @trusted
    {
        import core.stdc.stdlib : malloc;
        import std.exception : enforce;

        assert(!_p);
        _p = cast(Impl*) enforce(malloc(Impl.sizeof), "Out of memory");
        _p.handle = handle;
        _p.refs = refs;
        _p.isPopened = isPopened;
        _name = name;
    }

/**
Constructor taking the name of the file to open and the open mode
(with the same semantics as in the C standard library $(WEB
cplusplus.com/reference/clibrary/cstdio/fopen.html, fopen)
function).

Copying one $(D File) object to another results in the two $(D File)
objects referring to the same underlying file.

The destructor automatically closes the file as soon as no $(D File)
object refers to it anymore.

Throws: $(D ErrnoException) if the file could not be opened.
 */
    this(string name, in char[] stdioOpenmode = "rb") @safe
    {
        import std.conv : text;
        import std.exception : errnoEnforce;

        this(errnoEnforce(.fopen(name, stdioOpenmode),
                        text("Cannot open file `", name, "' in mode `",
                                stdioOpenmode, "'")),
                name);
    }

    ~this() @safe
    {
        detach();
    }

    this(this) @safe nothrow
    {
        if (!_p) return;
        assert(_p.refs);
        ++_p.refs;
    }

/**
Assigns a file to another. The target of the assignment gets detached
from whatever file it was attached to, and attaches itself to the new
file.
 */
    void opAssign(File rhs) @safe
    {
        import std.algorithm : swap;

        swap(this, rhs);
    }

/**
First calls $(D detach) (throwing on failure), and then attempts to
_open file $(D name) with mode $(D stdioOpenmode). The mode has the
same semantics as in the C standard library $(WEB
cplusplus.com/reference/clibrary/cstdio/fopen.html, fopen) function.

Throws: $(D ErrnoException) in case of error.
 */
    void open(string name, in char[] stdioOpenmode = "rb") @safe
    {
        detach();
        this = File(name, stdioOpenmode);
    }

/**
First calls $(D detach) (throwing on failure), and then runs a command
by calling the C standard library function $(WEB
opengroup.org/onlinepubs/007908799/xsh/_popen.html, _popen).

Throws: $(D ErrnoException) in case of error.
 */
    version(Posix) void popen(string command, in char[] stdioOpenmode = "r") @safe
    {
        import std.exception : errnoEnforce;

        detach();
        this = File(errnoEnforce(.popen(command, stdioOpenmode),
                        "Cannot run command `"~command~"'"),
                command, 1, true);
    }

/**
First calls $(D detach) (throwing on failure), and then attempts to
associate the given file descriptor with the $(D File). The mode must
be compatible with the mode of the file descriptor.

Throws: $(D ErrnoException) in case of error.
 */
    void fdopen(int fd, in char[] stdioOpenmode = "rb") @safe
    {
        fdopen(fd, stdioOpenmode, null);
    }

    package void fdopen(int fd, in char[] stdioOpenmode, string name) @trusted
    {
        import std.internal.cstring : tempCString;
        import std.exception : errnoEnforce;

        detach();

        version (DIGITAL_MARS_STDIO)
        {
            // This is a re-implementation of DMC's fdopen, but without the
            // mucking with the file descriptor.  POSIX standard requires the
            // new fdopen'd file to retain the given file descriptor's
            // position.
            import core.stdc.stdio : fopen;
            auto fp = fopen("NUL", stdioOpenmode.tempCString());
            errnoEnforce(fp, "Cannot open placeholder NUL stream");
            FLOCK(fp);
            auto iob = cast(_iobuf*)fp;
            .close(iob._file);
            iob._file = fd;
            iob._flag &= ~_IOTRAN;
            FUNLOCK(fp);
        }
        else
        {
            version (Windows) // MSVCRT
                auto fp = _fdopen(fd, stdioOpenmode.tempCString());
            else version (Posix)
            {
                import core.sys.posix.stdio : fdopen;
                auto fp = fdopen(fd, stdioOpenmode.tempCString());
            }
            errnoEnforce(fp);
        }
        this = File(fp, name);
    }

    // Declare a dummy HANDLE to allow generating documentation
    // for Windows-only methods.
    version(StdDdoc) { version(Windows) {} else alias HANDLE = int; }

/**
First calls $(D detach) (throwing on failure), and then attempts to
associate the given Windows $(D HANDLE) with the $(D File). The mode must
be compatible with the access attributes of the handle. Windows only.

Throws: $(D ErrnoException) in case of error.
*/
    version(StdDdoc)
    void windowsHandleOpen(HANDLE handle, in char[] stdioOpenmode);

    version(Windows)
    void windowsHandleOpen(HANDLE handle, in char[] stdioOpenmode)
    {
        import std.exception : errnoEnforce;
        import std.format : format;

        // Create file descriptors from the handles
        version (DIGITAL_MARS_STDIO)
            auto fd = _handleToFD(handle, FHND_DEVICE);
        else // MSVCRT
        {
            int mode;
            modeLoop:
            foreach (c; stdioOpenmode)
                switch (c)
                {
                    case 'r': mode |= _O_RDONLY; break;
                    case '+': mode &=~_O_RDONLY; break;
                    case 'a': mode |= _O_APPEND; break;
                    case 'b': mode |= _O_BINARY; break;
                    case 't': mode |= _O_TEXT;   break;
                    case ',': break modeLoop;
                    default: break;
                }

            auto fd = _open_osfhandle(cast(intptr_t)handle, mode);
        }

        errnoEnforce(fd >= 0, "Cannot open Windows HANDLE");
        fdopen(fd, stdioOpenmode, "HANDLE(%s)".format(handle));
    }


/** Returns $(D true) if the file is opened. */
    @property bool isOpen() const @safe pure nothrow
    {
        return _p !is null && _p.handle;
    }

/**
Returns $(D true) if the file is at end (see $(WEB
cplusplus.com/reference/clibrary/cstdio/feof.html, feof)).

Throws: $(D Exception) if the file is not opened.
 */
    @property bool eof() const @trusted pure
    {
        import std.exception : enforce;

        enforce(_p && _p.handle, "Calling eof() against an unopened file.");
        return .feof(cast(FILE*) _p.handle) != 0;
    }

/** Returns the name of the last opened file, if any.
If a $(D File) was created with $(LREF tmpfile) and $(LREF wrapFile)
it has no name.*/
    @property string name() const @safe pure nothrow
    {
        return _name;
    }

/**
If the file is not opened, returns $(D false). Otherwise, returns
$(WEB cplusplus.com/reference/clibrary/cstdio/ferror.html, ferror) for
the file handle.
 */
    @property bool error() const @trusted pure nothrow
    {
        return !isOpen || .ferror(cast(FILE*) _p.handle);
    }

    @safe unittest
    {
        // Issue 12349
        static import std.file;
        auto deleteme = testFilename();
        auto f = File(deleteme, "w");
        scope(exit) std.file.remove(deleteme);

        f.close();
        assert(f.error);
    }

/**
Detaches from the underlying file. If the sole owner, calls $(D close).

Throws: $(D ErrnoException) on failure if closing the file.
  */
    void detach() @safe
    {
        if (!_p) return;
        if (_p.refs == 1)
            close();
        else
        {
            assert(_p.refs);
            --_p.refs;
            _p = null;
        }
    }

    @safe unittest
    {
        static import std.file;

        auto deleteme = testFilename();
        scope(exit) std.file.remove(deleteme);
        auto f = File(deleteme, "w");
        {
            auto f2 = f;
            f2.detach();
        }
        assert(f._p.refs == 1);
        f.close();
    }

/**
If the file was unopened, succeeds vacuously. Otherwise closes the
file (by calling $(WEB
cplusplus.com/reference/clibrary/cstdio/fclose.html, fclose)),
throwing on error. Even if an exception is thrown, afterwards the $(D
File) object is empty. This is different from $(D detach) in that it
always closes the file; consequently, all other $(D File) objects
referring to the same handle will see a closed file henceforth.

Throws: $(D ErrnoException) on error.
 */
    void close() @trusted
    {
        import core.stdc.stdlib : free;
        import std.exception : errnoEnforce;

        if (!_p) return; // succeed vacuously
        scope(exit)
        {
            assert(_p.refs);
            if(!--_p.refs)
                free(_p);
            _p = null; // start a new life
        }
        if (!_p.handle) return; // Impl is closed by another File

        scope(exit) _p.handle = null; // nullify the handle anyway
        version (Posix)
        {
            import std.format : format;
            import core.sys.posix.stdio : pclose;

            if (_p.isPopened)
            {
                auto res = pclose(_p.handle);
                errnoEnforce(res != -1,
                        "Could not close pipe `"~_name~"'");
                errnoEnforce(res == 0, format("Command returned %d", res));
                return;
            }
        }
        //fprintf(core.stdc.stdio.stderr, ("Closing file `"~name~"`.\n\0").ptr);
        errnoEnforce(.fclose(_p.handle) == 0,
                "Could not close file `"~_name~"'");
    }

/**
If the file is not opened, succeeds vacuously. Otherwise, returns
$(WEB cplusplus.com/reference/clibrary/cstdio/_clearerr.html,
_clearerr) for the file handle.
 */
    void clearerr() @safe pure nothrow
    {
        _p is null || _p.handle is null ||
        .clearerr(_p.handle);
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/_fflush.html, _fflush)
for the file handle.

Throws: $(D Exception) if the file is not opened or if the call to $(D fflush) fails.
 */
    void flush() @trusted
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to flush() in an unopened file");
        errnoEnforce(.fflush(_p.handle) == 0);
    }

    @safe unittest
    {
        // Issue 12349
        static import std.file;
        import std.exception: assertThrown;

        auto deleteme = testFilename();
        auto f = File(deleteme, "w");
        scope(exit) std.file.remove(deleteme);

        f.close();
        assertThrown(f.flush());
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/fread.html, fread) for the
file handle. The number of items to read and the size of
each item is inferred from the size and type of the input array, respectively.

Returns: The slice of $(D buffer) containing the data that was actually read.
This will be shorter than $(D buffer) if EOF was reached before the buffer
could be filled.

Throws: $(D Exception) if $(D buffer) is empty.
        $(D ErrnoException) if the file is not opened or the call to $(D fread) fails.

$(D rawRead) always reads in binary mode on Windows.
 */
    T[] rawRead(T)(T[] buffer)
    {
        import std.exception : enforce, errnoEnforce;

        enforce(buffer.length, "rawRead must take a non-empty buffer");
        version(Windows)
        {
            immutable fd = ._fileno(_p.handle);
            immutable mode = ._setmode(fd, _O_BINARY);
            scope(exit) ._setmode(fd, mode);
            version(DIGITAL_MARS_STDIO)
            {
                import core.atomic;

                // @@@BUG@@@ 4243
                immutable info = __fhnd_info[fd];
                atomicOp!"&="(__fhnd_info[fd], ~FHND_TEXT);
                scope(exit) __fhnd_info[fd] = info;
            }
        }
        immutable result =
            fread(buffer.ptr, T.sizeof, buffer.length, _p.handle);
        errnoEnforce(!error);
        return result ? buffer[0 .. result] : null;
    }

    unittest
    {
        static import std.file;

        auto deleteme = testFilename();
        std.file.write(deleteme, "\r\n\n\r\n");
        scope(exit) std.file.remove(deleteme);
        auto f = File(deleteme, "r");
        auto buf = f.rawRead(new char[5]);
        f.close();
        assert(buf == "\r\n\n\r\n");
        /+
        buf = stdin.rawRead(new char[5]);
        assert(buf == "\r\n\n\r\n");
        +/
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/fwrite.html, fwrite) for the file
handle. The number of items to write and the size of each
item is inferred from the size and type of the input array, respectively. An
error is thrown if the buffer could not be written in its entirety.

$(D rawWrite) always writes in binary mode on Windows.

Throws: $(D ErrnoException) if the file is not opened or if the call to $(D fwrite) fails.
 */
    void rawWrite(T)(in T[] buffer)
    {
        import std.conv : text;
        import std.exception : errnoEnforce;

        version(Windows)
        {
            flush(); // before changing translation mode
            immutable fd = ._fileno(_p.handle);
            immutable mode = ._setmode(fd, _O_BINARY);
            scope(exit) ._setmode(fd, mode);
            version(DIGITAL_MARS_STDIO)
            {
                import core.atomic;

                // @@@BUG@@@ 4243
                immutable info = __fhnd_info[fd];
                atomicOp!"&="(__fhnd_info[fd], ~FHND_TEXT);
                scope(exit) __fhnd_info[fd] = info;
            }
            scope(exit) flush(); // before restoring translation mode
        }
        auto result =
            .fwrite(buffer.ptr, T.sizeof, buffer.length, _p.handle);
        if (result == result.max) result = 0;
        errnoEnforce(result == buffer.length,
                text("Wrote ", result, " instead of ", buffer.length,
                        " objects of type ", T.stringof, " to file `",
                        _name, "'"));
    }

    unittest
    {
        static import std.file;

        auto deleteme = testFilename();
        auto f = File(deleteme, "w");
        scope(exit) std.file.remove(deleteme);
        f.rawWrite("\r\n\n\r\n");
        f.close();
        assert(std.file.read(deleteme) == "\r\n\n\r\n");
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/fseek.html, fseek)
for the file handle.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) if the call to $(D fseek) fails.
 */
    void seek(long offset, int origin = SEEK_SET) @trusted
    {
        import std.exception : enforce, errnoEnforce;
        import std.conv : to, text;

        enforce(isOpen, "Attempting to seek() in an unopened file");
        version (Windows)
        {
            errnoEnforce(fseek(_p.handle, to!int(offset), origin) == 0,
                    "Could not seek in file `"~_name~"'");
        }
        else version (Posix)
        {
            import core.sys.posix.stdio : fseeko, off_t;
            //static assert(off_t.sizeof == 8);
            errnoEnforce(fseeko(_p.handle, cast(off_t) offset, origin) == 0,
                    "Could not seek in file `"~_name~"'");
        }
    }

    unittest
    {
        static import std.file;

        auto deleteme = testFilename();
        auto f = File(deleteme, "w+");
        scope(exit) { f.close(); std.file.remove(deleteme); }
        f.rawWrite("abcdefghijklmnopqrstuvwxyz");
        f.seek(7);
        assert(f.readln() == "hijklmnopqrstuvwxyz");
        version (Windows)
        {
            // No test for large files yet
        }
        else
        {
            import std.conv : text;

            version (Android)
                auto bigOffset = int.max - 100;
            else
                auto bigOffset = cast(ulong) int.max + 100;
            f.seek(bigOffset);
            assert(f.tell == bigOffset, text(f.tell));
            // Uncomment the tests below only if you want to wait for
            // a long time
            // f.rawWrite("abcdefghijklmnopqrstuvwxyz");
            // f.seek(-3, SEEK_END);
            // assert(f.readln() == "xyz");
        }
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/ftell.html, ftell) for the
managed file handle.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) if the call to $(D ftell) fails.
 */
    @property ulong tell() const @trusted
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to tell() in an unopened file");
        version (Windows)
        {
            immutable result = ftell(cast(FILE*) _p.handle);
        }
        else version (Posix)
        {
            import core.sys.posix.stdio : ftello;
            immutable result = ftello(cast(FILE*) _p.handle);
        }
        errnoEnforce(result != -1,
                "Query ftell() failed for file `"~_name~"'");
        return result;
    }

    unittest
    {
        static import std.file;
        import std.conv : text;

        auto deleteme = testFilename();
        std.file.write(deleteme, "abcdefghijklmnopqrstuvwqxyz");
        scope(exit) { std.file.remove(deleteme); }
        auto f = File(deleteme);
        auto a = new ubyte[4];
        f.rawRead(a);
        assert(f.tell == 4, text(f.tell));
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/_rewind.html, _rewind)
for the file handle.

Throws: $(D Exception) if the file is not opened.
 */
    void rewind() @safe
    {
        import std.exception : enforce;

        enforce(isOpen, "Attempting to rewind() an unopened file");
        .rewind(_p.handle);
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/_setvbuf.html, _setvbuf) for
the file handle.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) if the call to $(D setvbuf) fails.
 */
    void setvbuf(size_t size, int mode = _IOFBF) @trusted
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to call setvbuf() on an unopened file");
        errnoEnforce(.setvbuf(_p.handle, null, mode, size) == 0,
                "Could not set buffering for file `"~_name~"'");
    }

/**
Calls $(WEB cplusplus.com/reference/clibrary/cstdio/_setvbuf.html,
_setvbuf) for the file handle.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) if the call to $(D setvbuf) fails.
*/
    void setvbuf(void[] buf, int mode = _IOFBF) @trusted
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to call setvbuf() on an unopened file");
        errnoEnforce(.setvbuf(_p.handle,
                        cast(char*) buf.ptr, mode, buf.length) == 0,
                "Could not set buffering for file `"~_name~"'");
    }


    version(Windows)
    {
        import core.sys.windows.windows;

        private BOOL lockImpl(alias F, Flags...)(ulong start, ulong length,
            Flags flags)
        {
            if (!start && !length)
                length = ulong.max;
            ULARGE_INTEGER liStart = void, liLength = void;
            liStart.QuadPart = start;
            liLength.QuadPart = length;
            OVERLAPPED overlapped;
            overlapped.Offset = liStart.LowPart;
            overlapped.OffsetHigh = liStart.HighPart;
            overlapped.hEvent = null;
            return F(windowsHandle, flags, 0, liLength.LowPart,
                liLength.HighPart, &overlapped);
        }

        private static T wenforce(T)(T cond, string str)
        {
            import std.windows.syserror;

            if (cond) return cond;
            throw new Exception(str ~ ": " ~ sysErrorString(GetLastError()));
        }
    }
    version(Posix)
    {
        private int lockImpl(int operation, short l_type,
            ulong start, ulong length)
        {
            import std.conv : to;
            import core.sys.posix.fcntl : fcntl, flock, off_t;
            import core.sys.posix.unistd : getpid;

            flock fl = void;
            fl.l_type   = l_type;
            fl.l_whence = SEEK_SET;
            fl.l_start  = to!off_t(start);
            fl.l_len    = to!off_t(length);
            fl.l_pid    = getpid();
            return fcntl(fileno, operation, &fl);
        }
    }

/**
Locks the specified file segment. If the file segment is already locked
by another process, waits until the existing lock is released.
If both $(D start) and $(D length) are zero, the entire file is locked.

Locks created using $(D lock) and $(D tryLock) have the following properties:
$(UL
 $(LI All locks are automatically released when the process terminates.)
 $(LI Locks are not inherited by child processes.)
 $(LI Closing a file will release all locks associated with the file. On POSIX,
      even locks acquired via a different $(D File) will be released as well.)
 $(LI Not all NFS implementations correctly implement file locking.)
)
 */
    void lock(LockType lockType = LockType.readWrite,
        ulong start = 0, ulong length = 0)
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to call lock() on an unopened file");
        version (Posix)
        {
            import core.sys.posix.fcntl : F_RDLCK, F_SETLKW, F_WRLCK;
            immutable short type = lockType == LockType.readWrite
                ? F_WRLCK : F_RDLCK;
            errnoEnforce(lockImpl(F_SETLKW, type, start, length) != -1,
                    "Could not set lock for file `"~_name~"'");
        }
        else
        version(Windows)
        {
            immutable type = lockType == LockType.readWrite ?
                LOCKFILE_EXCLUSIVE_LOCK : 0;
            wenforce(lockImpl!LockFileEx(start, length, type),
                    "Could not set lock for file `"~_name~"'");
        }
        else
            static assert(false);
    }

/**
Attempts to lock the specified file segment.
If both $(D start) and $(D length) are zero, the entire file is locked.
Returns: $(D true) if the lock was successful, and $(D false) if the
specified file segment was already locked.
 */
    bool tryLock(LockType lockType = LockType.readWrite,
        ulong start = 0, ulong length = 0)
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to call tryLock() on an unopened file");
        version (Posix)
        {
            import core.stdc.errno : EACCES, EAGAIN, errno;
            import core.sys.posix.fcntl : F_RDLCK, F_SETLK, F_WRLCK;
            immutable short type = lockType == LockType.readWrite
                ? F_WRLCK : F_RDLCK;
            immutable res = lockImpl(F_SETLK, type, start, length);
            if (res == -1 && (errno == EACCES || errno == EAGAIN))
                return false;
            errnoEnforce(res != -1, "Could not set lock for file `"~_name~"'");
            return true;
        }
        else
        version(Windows)
        {
            immutable type = lockType == LockType.readWrite
                ? LOCKFILE_EXCLUSIVE_LOCK : 0;
            immutable res = lockImpl!LockFileEx(start, length,
                type | LOCKFILE_FAIL_IMMEDIATELY);
            if (!res && (GetLastError() == ERROR_IO_PENDING
                || GetLastError() == ERROR_LOCK_VIOLATION))
                return false;
            wenforce(res, "Could not set lock for file `"~_name~"'");
            return true;
        }
        else
            static assert(false);
    }

/**
Removes the lock over the specified file segment.
 */
    void unlock(ulong start = 0, ulong length = 0)
    {
        import std.exception : enforce, errnoEnforce;

        enforce(isOpen, "Attempting to call unlock() on an unopened file");
        version (Posix)
        {
            import core.sys.posix.fcntl : F_SETLK, F_UNLCK;
            errnoEnforce(lockImpl(F_SETLK, F_UNLCK, start, length) != -1,
                    "Could not remove lock for file `"~_name~"'");
        }
        else
        version(Windows)
        {
            wenforce(lockImpl!UnlockFileEx(start, length),
                "Could not remove lock for file `"~_name~"'");
        }
        else
            static assert(false);
    }

    version(Windows)
    unittest
    {
        static import std.file;
        auto deleteme = testFilename();
        scope(exit) std.file.remove(deleteme);
        auto f = File(deleteme, "wb");
        assert(f.tryLock());
        auto g = File(deleteme, "wb");
        assert(!g.tryLock());
        assert(!g.tryLock(LockType.read));
        f.unlock();
        f.lock(LockType.read);
        assert(!g.tryLock());
        assert(g.tryLock(LockType.read));
        f.unlock();
        g.unlock();
    }

    version(Posix)
    unittest
    {
        static import std.file;
        auto deleteme = testFilename();
        scope(exit) std.file.remove(deleteme);

        // Since locks are per-process, we cannot test lock failures within
        // the same process. fork() is used to create a second process.
        static void runForked(void delegate() code)
        {
            import core.stdc.stdlib : exit;
            import core.sys.posix.unistd;
            import core.sys.posix.sys.wait;
            int child, status;
            if ((child = fork()) == 0)
            {
                code();
                exit(0);
            }
            else
            {
                assert(wait(&status) != -1);
                assert(status == 0, "Fork crashed");
            }
        }

        auto f = File(deleteme, "w+b");

        runForked
        ({
            auto g = File(deleteme, "a+b");
            assert(g.tryLock());
            g.unlock();
            assert(g.tryLock(LockType.read));
        });

        assert(f.tryLock());
        runForked
        ({
            auto g = File(deleteme, "a+b");
            assert(!g.tryLock());
            assert(!g.tryLock(LockType.read));
        });
        f.unlock();

        f.lock(LockType.read);
        runForked
        ({
            auto g = File(deleteme, "a+b");
            assert(!g.tryLock());
            assert(g.tryLock(LockType.read));
            g.unlock();
        });
        f.unlock();
    }


/**
Writes its arguments in text format to the file.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) on an error writing to the file.
*/
    void write(S...)(S args)
    {
        import std.traits : isBoolean, isIntegral, isAggregateType;
        auto w = lockingTextWriter();
        foreach (arg; args)
        {
            alias A = typeof(arg);
            static if (isAggregateType!A || is(A == enum))
            {
                import std.format : formattedWrite;

                std.format.formattedWrite(w, "%s", arg);
            }
            else static if (isSomeString!A)
            {
                import std.range.primitives : put;
                put(w, arg);
            }
            else static if (isIntegral!A)
            {
                import std.conv : toTextRange;

                toTextRange(arg, w);
            }
            else static if (isBoolean!A)
            {
                put(w, arg ? "true" : "false");
            }
            else static if (isSomeChar!A)
            {
                import std.range.primitives : put;
                put(w, arg);
            }
            else
            {
                import std.format : formattedWrite;

                // Most general case
                std.format.formattedWrite(w, "%s", arg);
            }
        }
    }

/**
Writes its arguments in text format to the file, followed by a newline.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) on an error writing to the file.
*/
    void writeln(S...)(S args)
    {
        write(args, '\n');
    }

/**
Writes its arguments in text format to the file, according to the
format in the first argument.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) on an error writing to the file.
*/
    void writef(Char, A...)(in Char[] fmt, A args)
    {
        import std.format : formattedWrite;

        std.format.formattedWrite(lockingTextWriter(), fmt, args);
    }

/**
Writes its arguments in text format to the file, according to the
format in the first argument, followed by a newline.

Throws: $(D Exception) if the file is not opened.
        $(D ErrnoException) on an error writing to the file.
*/
    void writefln(Char, A...)(in Char[] fmt, A args)
    {
        import std.format : formattedWrite;

        auto w = lockingTextWriter();
        std.format.formattedWrite(w, fmt, args);
        w.put('\n');
    }

/**
Read line from the file handle and return it as a specified type.

This version manages its own read buffer, which means one memory allocation per call. If you are not
retaining a reference to the read data, consider the $(D File.readln(buf)) version, which may offer
better performance as it can reuse its read buffer.

Params:
    S = Template parameter; the type of the allocated buffer, and the type returned. Defaults to $(D string).
    terminator = Line terminator (by default, $(D '\n')).

Note:
    String terminators are not supported due to ambiguity with readln(buf) below.

Returns:
    The line that was read, including the line terminator character.

Throws:
    $(D StdioException) on I/O error, or $(D UnicodeException) on Unicode conversion error.

Example:
---
// Reads $(D stdin) and writes it to $(D stdout).
import std.stdio;

void main()
{
    string line;
    while ((line = stdin.readln()) !is null)
        write(line);
}
---
*/
    S readln(S = string)(dchar terminator = '\n')
    if (isSomeString!S)
    {
        Unqual!(ElementEncodingType!S)[] buf;
        readln(buf, terminator);
        return cast(S)buf;
    }

    unittest
    {
        static import std.file;
        import std.algorithm : equal;
        import std.typetuple : TypeTuple;

        auto deleteme = testFilename();
        std.file.write(deleteme, "hello\nworld\n");
        scope(exit) std.file.remove(deleteme);
        foreach (String; TypeTuple!(string, char[], wstring, wchar[], dstring, dchar[]))
        {
            auto witness = [ "hello\n", "world\n" ];
            auto f = File(deleteme);
            uint i = 0;
            String buf;
            while ((buf = f.readln!String()).length)
            {
                assert(i < witness.length);
                assert(equal(buf, witness[i++]));
            }
            assert(i == witness.length);
        }
    }

    unittest
    {
        static import std.file;
        import std.typecons : Tuple;

        auto deleteme = testFilename();
        std.file.write(deleteme, "cześć \U0002000D");
        scope(exit) std.file.remove(deleteme);
        uint[] lengths = [12,8,7];
        foreach (uint i, C; Tuple!(char, wchar, dchar).Types)
        {
            immutable(C)[] witness = "cześć \U0002000D";
            auto buf = File(deleteme).readln!(immutable(C)[])();
            assert(buf.length == lengths[i]);
            assert(buf == witness);
        }
    }

/**
Read line from the file handle and write it to $(D buf[]), including
terminating character.

This can be faster than $(D line = File.readln()) because you can reuse
the buffer for each call. Note that reusing the buffer means that you
must copy the previous contents if you wish to retain them.

Params:
buf = Buffer used to store the resulting line data. buf is
resized as necessary.
terminator = Line terminator (by default, $(D '\n')). Use
$(XREF ascii, newline) for portability (unless the file was opened in
text mode).

Returns:
0 for end of file, otherwise number of characters read

Throws: $(D StdioException) on I/O error, or $(D UnicodeException) on Unicode
conversion error.

Example:
---
// Read lines from $(D stdin) into a string
// Ignore lines starting with '#'
// Write the string to $(D stdout)

void main()
{
    string output;
    char[] buf;

    while (stdin.readln(buf))
    {
        if (buf[0] == '#')
            continue;

        output ~= buf;
    }

    write(output);
}
---

This method can be more efficient than the one in the previous example
because $(D stdin.readln(buf)) reuses (if possible) memory allocated
for $(D buf), whereas $(D line = stdin.readln()) makes a new memory allocation
for every line.
*/
    size_t readln(C)(ref C[] buf, dchar terminator = '\n')
    if (isSomeChar!C && is(Unqual!C == C) && !is(C == enum))
    {
        import std.exception : enforce;

        static if (is(C == char))
        {
            enforce(_p && _p.handle, "Attempt to read from an unopened file.");
            return readlnImpl(_p.handle, buf, terminator);
        }
        else
        {
            // TODO: optimize this
            string s = readln(terminator);
            buf.length = 0;
            if (!s.length) return 0;
            foreach (C c; s)
            {
                buf ~= c;
            }
            return buf.length;
        }
    }

/** ditto */
    size_t readln(C, R)(ref C[] buf, R terminator)
    if (isSomeChar!C && is(Unqual!C == C) && !is(C == enum) &&
        isBidirectionalRange!R && is(typeof(terminator.front == dchar.init)))
    {
        import std.algorithm : endsWith, swap;
        import std.range.primitives : back;

        auto last = terminator.back;
        C[] buf2;
        swap(buf, buf2);
        for (;;) {
            if (!readln(buf2, last) || endsWith(buf2, terminator)) {
                if (buf.empty) {
                    buf = buf2;
                } else {
                    buf ~= buf2;
                }
                break;
            }
            buf ~= buf2;
        }
        return buf.length;
    }

    unittest
    {
        static import std.file;
        import std.typecons : Tuple;

        auto deleteme = testFilename();
        std.file.write(deleteme, "hello\n\rworld\nhow\n\rare ya");
        scope(exit) std.file.remove(deleteme);
        foreach (C; Tuple!(char, wchar, dchar).Types)
        {
            immutable(C)[][] witness = [ "hello\n\r", "world\nhow\n\r", "are ya" ];
            auto f = File(deleteme);
            uint i = 0;
            C[] buf;
            while (f.readln(buf, "\n\r"))
            {
                assert(i < witness.length);
                assert(buf == witness[i++]);
            }
            assert(buf.length==0);
        }
    }

    /**
     * Read data from the file according to the specified
     * $(LINK2 std_format.html#format-string, format specifier) using
     * $(XREF format,formattedRead).
     */
    uint readf(Data...)(in char[] format, Data data)
    {
        import std.format : formattedRead;

        assert(isOpen);
        auto input = LockingTextReader(this);
        return formattedRead(input, format, data);
    }

    unittest
    {
        static import std.file;

        auto deleteme = testFilename();
        std.file.write(deleteme, "hello\nworld\ntrue\nfalse\n");
        scope(exit) std.file.remove(deleteme);
        string s;
        auto f = File(deleteme);
        f.readf("%s\n", &s);
        assert(s == "hello", "["~s~"]");
        f.readf("%s\n", &s);
        assert(s == "world", "["~s~"]");

        // Issue 11698
        bool b1, b2;
        f.readf("%s\n%s\n", &b1, &b2);
        assert(b1 == true && b2 == false);
    }

/**
 Returns a temporary file by calling $(WEB
 cplusplus.com/reference/clibrary/cstdio/_tmpfile.html, _tmpfile).
 Note that the created file has no $(LREF name).*/
    static File tmpfile() @safe
    {
        import std.exception : errnoEnforce;

        return File(errnoEnforce(.tmpfile(),
                "Could not create temporary file with tmpfile()"),
            null);
    }

/**
Unsafe function that wraps an existing $(D FILE*). The resulting $(D
File) never takes the initiative in closing the file.
Note that the created file has no $(LREF name)*/
    /*private*/ static File wrapFile(FILE* f) @safe
    {
        import std.exception : enforce;

        return File(enforce(f, "Could not wrap null FILE*"),
            null, /*uint.max / 2*/ 9999);
    }

/**
Returns the $(D FILE*) corresponding to this object.
 */
    FILE* getFP() @safe pure
    {
        import std.exception : enforce;

        enforce(_p && _p.handle,
                "Attempting to call getFP() on an unopened file");
        return _p.handle;
    }

    unittest
    {
        static import core.stdc.stdio;
        assert(stdout.getFP() == core.stdc.stdio.stdout);
    }

/**
Returns the file number corresponding to this object.
 */
    /*version(Posix) */@property int fileno() const @trusted
    {
        import std.exception : enforce;

        enforce(isOpen, "Attempting to call fileno() on an unopened file");
        return .fileno(cast(FILE*) _p.handle);
    }

/**
Returns the underlying operating system $(D HANDLE) (Windows only).
*/
    version(StdDdoc)
    @property HANDLE windowsHandle();

    version(Windows)
    @property HANDLE windowsHandle()
    {
        version (DIGITAL_MARS_STDIO)
            return _fdToHandle(fileno);
        else
            return cast(HANDLE)_get_osfhandle(fileno);
    }


// Note: This was documented until 2013/08
/*
Range that reads one line at a time.  Returned by $(LREF byLine).

Allows to directly use range operations on lines of a file.
*/
    struct ByLine(Char, Terminator)
    {
    private:
        import std.typecons;

        /* Ref-counting stops the source range's ByLineImpl
         * from getting out of sync after the range is copied, e.g.
         * when accessing range.front, then using std.range.take,
         * then accessing range.front again. */
        alias Impl = RefCounted!(ByLineImpl!(Char, Terminator),
            RefCountedAutoInitialize.no);
        Impl impl;

        static if (isScalarType!Terminator)
            enum defTerm = '\n';
        else
            enum defTerm = cast(Terminator)"\n";

    public:
        this(File f, KeepTerminator kt = KeepTerminator.no,
                Terminator terminator = defTerm)
        {
            impl = Impl(f, kt, terminator);
        }

        @property bool empty()
        {
            return impl.refCountedPayload.empty;
        }

        @property Char[] front()
        {
            return impl.refCountedPayload.front;
        }

        void popFront()
        {
            impl.refCountedPayload.popFront();
        }
    }

    private struct ByLineImpl(Char, Terminator)
    {
    private:
        File file;
        Char[] line;
        Terminator terminator;
        KeepTerminator keepTerminator;

    public:
        this(File f, KeepTerminator kt, Terminator terminator)
        {
            file = f;
            this.terminator = terminator;
            keepTerminator = kt;
            popFront();
        }

        // Range primitive implementations.
        @property bool empty()
        {
            if (line !is null) return false;
            if (!file.isOpen) return true;

            // First read ever, must make sure stream is not empty. We
            // do so by reading a character and putting it back. Doing
            // so is guaranteed to work on all files opened in all
            // buffering modes.
            auto fp = file.getFP();
            auto c = fgetc(fp);
            if (c == -1)
            {
                file.detach();
                return true;
            }
            ungetc(c, fp) == c
                || assert(false, "Bug in cstdlib implementation");
            return false;
        }

        @property Char[] front()
        {
            return line;
        }

        void popFront()
        {
            import std.algorithm : endsWith;

            assert(file.isOpen);
            assumeSafeAppend(line);
            file.readln(line, terminator);
            if (line.empty)
            {
                file.detach();
                line = null;
            }
            else if (keepTerminator == KeepTerminator.no
                    && std.algorithm.endsWith(line, terminator))
            {
                static if (isScalarType!Terminator)
                    enum tlen = 1;
                else static if (isArray!Terminator)
                {
                    static assert(
                        is(Unqual!(ElementEncodingType!Terminator) == Char));
                    const tlen = terminator.length;
                }
                else
                    static assert(false);
                line = line.ptr[0 .. line.length - tlen];
            }
        }
    }

/**
Returns an input range set up to read from the file handle one line
at a time.

The element type for the range will be $(D Char[]). Range primitives
may throw $(D StdioException) on I/O error.

Note:
Each $(D front) will not persist after $(D
popFront) is called, so the caller must copy its contents (e.g. by
calling $(D to!string)) when retention is needed. If the caller needs
to retain a copy of every line, use the $(LREF byLineCopy) function
instead.

Params:
Char = Character type for each line, defaulting to $(D char).
keepTerminator = Use $(D KeepTerminator.yes) to include the
terminator at the end of each line.
terminator = Line separator ($(D '\n') by default). Use
$(XREF ascii, newline) for portability (unless the file was opened in
text mode).

Example:
----
import std.algorithm, std.stdio, std.string;
// Count words in a file using ranges.
void main()
{
    auto file = File("file.txt"); // Open for reading
    const wordCount = file.byLine()            // Read lines
                          .map!split           // Split into words
                          .map!(a => a.length) // Count words per line
                          .sum();              // Total word count
    writeln(wordCount);
}
----

Example:
----
import std.range, std.stdio;
// Read lines using foreach.
void main()
{
    auto file = File("file.txt"); // Open for reading
    auto range = file.byLine();
    // Print first three lines
    foreach (line; range.take(3))
        writeln(line);
    // Print remaining lines beginning with '#'
    foreach (line; range)
    {
        if (!line.empty && line[0] == '#')
            writeln(line);
    }
}
----
Notice that neither example accesses the line data returned by
$(D front) after the corresponding $(D popFront) call is made (because
the contents may well have changed).
*/
    auto byLine(Terminator = char, Char = char)
            (KeepTerminator keepTerminator = KeepTerminator.no,
            Terminator terminator = '\n')
    if (isScalarType!Terminator)
    {
        return ByLine!(Char, Terminator)(this, keepTerminator, terminator);
    }

/// ditto
    auto byLine(Terminator, Char = char)
            (KeepTerminator keepTerminator, Terminator terminator)
    if (is(Unqual!(ElementEncodingType!Terminator) == Char))
    {
        return ByLine!(Char, Terminator)(this, keepTerminator, terminator);
    }

    private struct ByLineCopy(Char, Terminator)
    {
    private:
        import std.typecons;

        /* Ref-counting stops the source range's ByLineCopyImpl
         * from getting out of sync after the range is copied, e.g.
         * when accessing range.front, then using std.range.take,
         * then accessing range.front again. */
        alias Impl = RefCounted!(ByLineCopyImpl!(Char, Terminator),
            RefCountedAutoInitialize.no);
        Impl impl;

    public:
        this(File f, KeepTerminator kt, Terminator terminator)
        {
            impl = Impl(f, kt, terminator);
        }

        @property bool empty()
        {
            return impl.refCountedPayload.empty;
        }

        @property Char[] front()
        {
            return impl.refCountedPayload.front;
        }

        void popFront()
        {
            impl.refCountedPayload.popFront();
        }
    }

    private struct ByLineCopyImpl(Char, Terminator)
    {
        ByLineImpl!(Unqual!Char, Terminator) impl;
        bool gotFront;
        Char[] line;

    public:
        this(File f, KeepTerminator kt, Terminator terminator)
        {
            impl = ByLineImpl!(Unqual!Char, Terminator)(f, kt, terminator);
        }

        @property bool empty()
        {
            return impl.empty;
        }

        @property front()
        {
            if (!gotFront)
            {
                line = impl.front.dup;
                gotFront = true;
            }
            return line;
        }

        void popFront()
        {
            impl.popFront();
            gotFront = false;
        }
    }

/**
Returns an input range set up to read from the file handle one line
at a time. Each line will be newly allocated. $(D front) will cache
its value to allow repeated calls without unnecessary allocations.

Note: Due to caching byLineCopy can be more memory-efficient than
$(D File.byLine.map!idup).

The element type for the range will be $(D Char[]). Range
primitives may throw $(D StdioException) on I/O error.

Params:
Char = Character type for each line, defaulting to $(D immutable char).
keepTerminator = Use $(D KeepTerminator.yes) to include the
terminator at the end of each line.
terminator = Line separator ($(D '\n') by default). Use
$(XREF ascii, newline) for portability (unless the file was opened in
text mode).

Example:
----
import std.algorithm, std.array, std.stdio;
// Print sorted lines of a file.
void main()
{
    auto sortedLines = File("file.txt")   // Open for reading
                       .byLineCopy()      // Read persistent lines
                       .array()           // into an array
                       .sort();           // then sort them
    foreach (line; sortedLines)
        writeln(line);
}
----
See_Also:
$(XREF file,readText)
*/
    auto byLineCopy(Terminator = char, Char = immutable char)
            (KeepTerminator keepTerminator = KeepTerminator.no,
            Terminator terminator = '\n')
    if (isScalarType!Terminator)
    {
        return ByLineCopy!(Char, Terminator)(this, keepTerminator, terminator);
    }

/// ditto
    auto byLineCopy(Terminator, Char = immutable char)
            (KeepTerminator keepTerminator, Terminator terminator)
    if (is(Unqual!(ElementEncodingType!Terminator) == Unqual!Char))
    {
        return ByLineCopy!(Char, Terminator)(this, keepTerminator, terminator);
    }

    unittest
    {
        static assert(is(typeof(File("").byLine.front) == char[]));
        static assert(is(typeof(File("").byLineCopy.front) == string));
        static assert(
            is(typeof(File("").byLineCopy!(char, char).front) == char[]));
    }

    unittest
    {
        static import std.file;
        import std.algorithm : equal;
        import std.range;

        //printf("Entering test at line %d\n", __LINE__);
        scope(failure) printf("Failed test at line %d\n", __LINE__);
        auto deleteme = testFilename();
        std.file.write(deleteme, "");
        scope(success) std.file.remove(deleteme);

        // Test empty file
        auto f = File(deleteme);
        foreach (line; f.byLine())
        {
            assert(false);
        }
        f.detach();
        assert(!f.isOpen);

        void test(Terminator)(string txt, in string[] witness,
                KeepTerminator kt, Terminator term, bool popFirstLine = false)
        {
            import std.conv : text;
            import std.algorithm : sort;
            import std.range.primitives : walkLength;

            uint i;
            std.file.write(deleteme, txt);
            auto f = File(deleteme);
            scope(exit)
            {
                f.close();
                assert(!f.isOpen);
            }
            auto lines = f.byLine(kt, term);
            if (popFirstLine)
            {
                lines.popFront();
                i = 1;
            }
            assert(lines.empty || lines.front is lines.front);
            foreach (line; lines)
            {
                assert(line == witness[i++]);
            }
            assert(i == witness.length, text(i, " != ", witness.length));

            // Issue 11830
            auto walkedLength = File(deleteme).byLine(kt, term).walkLength;
            assert(walkedLength == witness.length, text(walkedLength, " != ", witness.length));

            // test persistent lines
            assert(File(deleteme).byLineCopy(kt, term).array.sort() == witness.dup.sort());
        }

        KeepTerminator kt = KeepTerminator.no;
        test("", null, kt, '\n');
        test("\n", [ "" ], kt, '\n');
        test("asd\ndef\nasdf", [ "asd", "def", "asdf" ], kt, '\n');
        test("asd\ndef\nasdf", [ "asd", "def", "asdf" ], kt, '\n', true);
        test("asd\ndef\nasdf\n", [ "asd", "def", "asdf" ], kt, '\n');
        test("foo", [ "foo" ], kt, '\n', true);
        test("bob\r\nmarge\r\nsteve\r\n", ["bob", "marge", "steve"],
            kt, "\r\n");
        test("sue\r", ["sue"], kt, '\r');

        kt = KeepTerminator.yes;
        test("", null, kt, '\n');
        test("\n", [ "\n" ], kt, '\n');
        test("asd\ndef\nasdf", [ "asd\n", "def\n", "asdf" ], kt, '\n');
        test("asd\ndef\nasdf\n", [ "asd\n", "def\n", "asdf\n" ], kt, '\n');
        test("asd\ndef\nasdf\n", [ "asd\n", "def\n", "asdf\n" ], kt, '\n', true);
        test("foo", [ "foo" ], kt, '\n');
        test("bob\r\nmarge\r\nsteve\r\n", ["bob\r\n", "marge\r\n", "steve\r\n"],
            kt, "\r\n");
        test("sue\r", ["sue\r"], kt, '\r');
    }

    unittest
    {
        import std.algorithm : equal;
        import std.range;

        version(Win64)
        {
            static import std.file;

            /* the C function tmpfile doesn't seem to work, even when called from C */
            auto deleteme = testFilename();
            auto file = File(deleteme, "w+");
            scope(success) std.file.remove(deleteme);
        }
        else version(Android)
        {
            static import std.file;

            /* the C function tmpfile doesn't work when called from a shared
               library apk:
               https://code.google.com/p/android/issues/detail?id=66815 */
            auto deleteme = testFilename();
            auto file = File(deleteme, "w+");
            scope(success) std.file.remove(deleteme);
        }
        else
            auto file = File.tmpfile();
        file.write("1\n2\n3\n");

        // bug 9599
        file.rewind();
        File.ByLine!(char, char) fbl = file.byLine();
        auto fbl2 = fbl;
        assert(fbl.front == "1");
        assert(fbl.front is fbl2.front);
        assert(fbl.take(1).equal(["1"]));
        assert(fbl.equal(["2", "3"]));
        assert(fbl.empty);
        assert(file.isOpen); // we still have a valid reference

        file.rewind();
        fbl = file.byLine();
        assert(!fbl.drop(2).empty);
        assert(fbl.equal(["3"]));
        assert(fbl.empty);
        assert(file.isOpen);

        file.detach();
        assert(!file.isOpen);
    }

    unittest
    {
        auto deleteme = testFilename();
        std.file.write(deleteme, "hi");
        scope(success) std.file.remove(deleteme);

        auto blc = File(deleteme).byLineCopy;
        assert(!blc.empty);
        // check front is cached
        assert(blc.front is blc.front);
    }

    template byRecord(Fields...)
    {
        ByRecord!(Fields) byRecord(string format)
        {
            return typeof(return)(this, format);
        }
    }

    unittest
    {
        // static import std.file;
        //
        // auto deleteme = testFilename();
        // rndGen.popFront();
        // scope(failure) printf("Failed test at line %d\n", __LINE__);
        // std.file.write(deleteme, "1 2\n4 1\n5 100");
        // scope(exit) std.file.remove(deleteme);
        // File f = File(deleteme);
        // scope(exit) f.close();
        // auto t = [ tuple(1, 2), tuple(4, 1), tuple(5, 100) ];
        // uint i;
        // foreach (e; f.byRecord!(int, int)("%s %s"))
        // {
        //     //.writeln(e);
        //     assert(e == t[i++]);
        // }
    }

    // Note: This was documented until 2013/08
    /*
     * Range that reads a chunk at a time.
     */
    struct ByChunk
    {
    private:
        File    file_;
        ubyte[] chunk_;

        void prime()
        {
            chunk_ = file_.rawRead(chunk_);
            if (chunk_.length == 0)
                file_.detach();
        }

    public:
        this(File file, size_t size)
        {
            this(file, new ubyte[](size));
        }

        this(File file, ubyte[] buffer)
        {
            import std.exception;
            enforce(buffer.length, "size must be larger than 0");
            file_ = file;
            chunk_ = buffer;
            prime();
        }

        // $(D ByChunk)'s input range primitive operations.
        @property nothrow
        bool empty() const
        {
            return !file_.isOpen;
        }

        /// Ditto
        @property nothrow
        ubyte[] front()
        {
            version(assert)
            {
                import core.exception : RangeError;
                if (empty)
                    throw new RangeError();
            }
            return chunk_;
        }

        /// Ditto
        void popFront()
        {
            version(assert)
            {
                import core.exception : RangeError;
                if (empty)
                    throw new RangeError();
            }
            prime();
        }
    }

/**
Returns an input range set up to read from the file handle a chunk at a
time.

The element type for the range will be $(D ubyte[]). Range primitives
may throw $(D StdioException) on I/O error.

Example:
---------
void main()
{
    // Read standard input 4KB at a time
    foreach (ubyte[] buffer; stdin.byChunk(4096))
    {
        ... use buffer ...
    }
}
---------

The parameter may be a number (as shown in the example above) dictating the
size of each chunk. Alternatively, $(D byChunk) accepts a
user-provided buffer that it uses directly.

Example:
---------
void main()
{
    // Read standard input 4KB at a time
    foreach (ubyte[] buffer; stdin.byChunk(new ubyte[4096]))
    {
        ... use buffer ...
    }
}
---------

In either case, the content of the buffer is reused across calls. That means
$(D front) will not persist after $(D popFront) is called, so if retention is
needed, the caller must copy its contents (e.g. by calling $(D buffer.dup)).

In the  example above, $(D buffer.length) is 4096 for all iterations, except
for the last one, in which case $(D buffer.length) may be less than 4096 (but
always greater than zero).

With the mentioned limitations, $(D byChunks) works with any algorithm
compatible with input ranges.

Example:
---
// Efficient file copy, 1MB at a time.
import std.algorithm, std.stdio;
void main()
{
    stdin.byChunk(1024 * 1024).copy(stdout.lockingTextWriter());
}
---

Returns: A call to $(D byChunk) returns a range initialized with the $(D File)
object and the appropriate buffer.

Throws: If the user-provided size is zero or the user-provided buffer
is empty, throws an $(D Exception). In case of an I/O error throws
$(D StdioException).
 */
    auto byChunk(size_t chunkSize)
    {
        return ByChunk(this, chunkSize);
    }
/// Ditto
    ByChunk byChunk(ubyte[] buffer)
    {
        return ByChunk(this, buffer);
    }

    unittest
    {
        static import std.file;

        scope(failure) printf("Failed test at line %d\n", __LINE__);

        auto deleteme = testFilename();
        std.file.write(deleteme, "asd\ndef\nasdf");

        auto witness = ["asd\n", "def\n", "asdf" ];
        auto f = File(deleteme);
        scope(exit)
        {
            f.close();
            assert(!f.isOpen);
            std.file.remove(deleteme);
        }

        uint i;
        foreach (chunk; f.byChunk(4))
            assert(chunk == cast(ubyte[])witness[i++]);

        assert(i == witness.length);
    }

    unittest
    {
        static import std.file;

        scope(failure) printf("Failed test at line %d\n", __LINE__);

        auto deleteme = testFilename();
        std.file.write(deleteme, "asd\ndef\nasdf");

        auto witness = ["asd\n", "def\n", "asdf" ];
        auto f = File(deleteme);
        scope(exit)
        {
            f.close();
            assert(!f.isOpen);
            std.file.remove(deleteme);
        }

        uint i;
        foreach (chunk; f.byChunk(new ubyte[4]))
            assert(chunk == cast(ubyte[])witness[i++]);

        assert(i == witness.length);
    }

    // Note: This was documented until 2013/08
/*
$(D Range) that locks the file and allows fast writing to it.
 */
    struct LockingTextWriter
    {
    private:
        import std.range.primitives : ElementType, isInfinite, isInputRange;
        FILE* fps_;          // the shared file handle
        _iobuf* handle_;     // the unshared version of fps
        int orientation_;
    public:
        deprecated("accessing fps/handle/orientation directly can break LockingTextWriter integrity")
        {
            alias fps = fps_;
            alias handle = handle_;
            alias orientation = orientation_;
        }

        this(ref File f) @trusted
        {
            import core.stdc.wchar_ : fwide;
            import std.exception : enforce;

            enforce(f._p && f._p.handle);
            fps_ = f._p.handle;
            orientation_ = fwide(fps_, 0);
            FLOCK(fps_);
            handle_ = cast(_iobuf*)fps_;
        }

        ~this() @trusted
        {
            if(fps_)
            {
                FUNLOCK(fps_);
                fps_ = null;
                handle_ = null;
            }
        }

        this(this) @trusted
        {
            if(fps_)
            {
                FLOCK(fps_);
            }
        }

        /// Range primitive implementations.
        void put(A)(A writeme)
            if (is(ElementType!A : const(dchar)) &&
                isInputRange!A &&
                !isInfinite!A)
        {
            import std.exception : errnoEnforce;

            alias C = ElementEncodingType!A;
            static assert(!is(C == void));
            static if (isSomeString!A && C.sizeof == 1)
            {
                if (orientation_ <= 0)
                {
                    //file.write(writeme); causes infinite recursion!!!
                    //file.rawWrite(writeme);
                    static auto trustedFwrite(in void* ptr, size_t size, size_t nmemb, FILE* stream) @trusted
                    {
                        return .fwrite(ptr, size, nmemb, stream);
                    }
                    auto result =
                        trustedFwrite(writeme.ptr, C.sizeof, writeme.length, fps_);
                    if (result != writeme.length) errnoEnforce(0);
                    return;
                }
            }

            // put each character in turn
            foreach (dchar c; writeme)
            {
                put(c);
            }
        }

        // @@@BUG@@@ 2340
        //void front(C)(C c) if (is(C : dchar)) {
        /// ditto
        void put(C)(C c) @safe if (is(C : const(dchar)))
        {
            import std.traits : ParameterTypeTuple;
            static auto trustedFPUTC(int ch, _iobuf* h) @trusted
            {
                return FPUTC(ch, h);
            }
            static auto trustedFPUTWC(ParameterTypeTuple!FPUTWC[0] ch, _iobuf* h) @trusted
            {
                return FPUTWC(ch, h);
            }

            static if (c.sizeof == 1)
            {
                // simple char
                if (orientation_ <= 0) trustedFPUTC(c, handle_);
                else trustedFPUTWC(c, handle_);
            }
            else static if (c.sizeof == 2)
            {
                import std.utf : toUTF8;

                if (orientation_ <= 0)
                {
                    if (c <= 0x7F)
                    {
                        trustedFPUTC(c, handle_);
                    }
                    else
                    {
                        char[4] buf;
                        auto b = std.utf.toUTF8(buf, c);
                        foreach (i ; 0 .. b.length)
                            trustedFPUTC(b[i], handle_);
                    }
                }
                else
                {
                    trustedFPUTWC(c, handle_);
                }
            }
            else // 32-bit characters
            {
                import std.utf : toUTF8;

                if (orientation_ <= 0)
                {
                    if (c <= 0x7F)
                    {
                        trustedFPUTC(c, handle_);
                    }
                    else
                    {
                        char[4] buf = void;
                        auto b = std.utf.toUTF8(buf, c);
                        foreach (i ; 0 .. b.length)
                            trustedFPUTC(b[i], handle_);
                    }
                }
                else
                {
                    version (Windows)
                    {
                        import std.utf : isValidDchar;

                        assert(isValidDchar(c));
                        if (c <= 0xFFFF)
                        {
                            trustedFPUTWC(c, handle_);
                        }
                        else
                        {
                            trustedFPUTWC(cast(wchar)
                                    ((((c - 0x10000) >> 10) & 0x3FF)
                                            + 0xD800), handle_);
                            trustedFPUTWC(cast(wchar)
                                    (((c - 0x10000) & 0x3FF) + 0xDC00),
                                    handle_);
                        }
                    }
                    else version (Posix)
                    {
                        trustedFPUTWC(c, handle_);
                    }
                    else
                    {
                        static assert(0);
                    }
                }
            }
        }
    }

/** Returns an output range that locks the file and allows fast writing to it.

See $(LREF byChunk) for an example.
*/
    auto lockingTextWriter() @safe
    {
        return LockingTextWriter(this);
    }

/// Get the size of the file, ulong.max if file is not searchable, but still throws if an actual error occurs.
    @property ulong size() @safe
    {
        import std.exception : collectException;

        ulong pos = void;
        if (collectException(pos = tell)) return ulong.max;
        scope(exit) seek(pos);
        seek(0, SEEK_END);
        return tell;
    }
}

unittest
{
    @system struct SystemToString
    {
        string toString()
        {
            return "system";
        }
    }

    @trusted struct TrustedToString
    {
        string toString()
        {
            return "trusted";
        }
    }

    @safe struct SafeToString
    {
        string toString()
        {
            return "safe";
        }
    }

    @system void systemTests()
    {
        //system code can write to files/stdout with anything!
        if(false)
        {
            auto f = File();

            f.write("just a string");
            f.write("string with arg: ", 47);
            f.write(SystemToString());
            f.write(TrustedToString());
            f.write(SafeToString());

            write("just a string");
            write("string with arg: ", 47);
            write(SystemToString());
            write(TrustedToString());
            write(SafeToString());

            f.writeln("just a string");
            f.writeln("string with arg: ", 47);
            f.writeln(SystemToString());
            f.writeln(TrustedToString());
            f.writeln(SafeToString());

            writeln("just a string");
            writeln("string with arg: ", 47);
            writeln(SystemToString());
            writeln(TrustedToString());
            writeln(SafeToString());

            f.writef("string with arg: %s", 47);
            f.writef("%s", SystemToString());
            f.writef("%s", TrustedToString());
            f.writef("%s", SafeToString());

            writef("string with arg: %s", 47);
            writef("%s", SystemToString());
            writef("%s", TrustedToString());
            writef("%s", SafeToString());

            f.writefln("string with arg: %s", 47);
            f.writefln("%s", SystemToString());
            f.writefln("%s", TrustedToString());
            f.writefln("%s", SafeToString());

            writefln("string with arg: %s", 47);
            writefln("%s", SystemToString());
            writefln("%s", TrustedToString());
            writefln("%s", SafeToString());
        }
    }

    @safe void safeTests()
    {
        auto f = File();

        //safe code can write to files only with @safe and @trusted code...
        if(false)
        {
            f.write("just a string");
            f.write("string with arg: ", 47);
            f.write(TrustedToString());
            f.write(SafeToString());

            write("just a string");
            write("string with arg: ", 47);
            write(TrustedToString());
            write(SafeToString());

            f.writeln("just a string");
            f.writeln("string with arg: ", 47);
            f.writeln(TrustedToString());
            f.writeln(SafeToString());

            writeln("just a string");
            writeln("string with arg: ", 47);
            writeln(TrustedToString());
            writeln(SafeToString());

            f.writef("string with arg: %s", 47);
            f.writef("%s", TrustedToString());
            f.writef("%s", SafeToString());

            writef("string with arg: %s", 47);
            writef("%s", TrustedToString());
            writef("%s", SafeToString());

            f.writefln("string with arg: %s", 47);
            f.writefln("%s", TrustedToString());
            f.writefln("%s", SafeToString());

            writefln("string with arg: %s", 47);
            writefln("%s", TrustedToString());
            writefln("%s", SafeToString());
        }

        static assert(!__traits(compiles, f.write(SystemToString().toString())));
        static assert(!__traits(compiles, f.writeln(SystemToString())));
        static assert(!__traits(compiles, f.writef("%s", SystemToString())));
        static assert(!__traits(compiles, f.writefln("%s", SystemToString())));

        static assert(!__traits(compiles, write(SystemToString().toString())));
        static assert(!__traits(compiles, writeln(SystemToString())));
        static assert(!__traits(compiles, writef("%s", SystemToString())));
        static assert(!__traits(compiles, writefln("%s", SystemToString())));
    }

    systemTests();
    safeTests();
}

unittest
{
    static import std.file;
    import std.exception : collectException;

    auto deleteme = testFilename();
    scope(exit) collectException(std.file.remove(deleteme));
    std.file.write(deleteme, "1 2 3");
    auto f = File(deleteme);
    assert(f.size == 5);
    assert(f.tell == 0);
}

unittest
{
    static import std.file;
    import std.range;

    auto deleteme = testFilename();
    scope(exit) std.file.remove(deleteme);

    {
        File f = File(deleteme, "w");
        auto writer = f.lockingTextWriter();
        static assert(isOutputRange!(typeof(writer), dchar));
        writer.put("日本語");
        writer.put("日本語"w);
        writer.put("日本語"d);
        writer.put('日');
        writer.put(chain(only('本'), only('語')));
        writer.put(repeat('#', 12)); // BUG 11945
    }
    assert(File(deleteme).readln() == "日本語日本語日本語日本語############");
}

/// Used to specify the lock type for $(D File.lock) and $(D File.tryLock).
enum LockType
{
    /// Specifies a _read (shared) lock. A _read lock denies all processes
    /// write access to the specified region of the file, including the
    /// process that first locks the region. All processes can _read the
    /// locked region. Multiple simultaneous _read locks are allowed, as
    /// long as there are no exclusive locks.
    read,
    /// Specifies a read/write (exclusive) lock. A read/write lock denies all
    /// other processes both read and write access to the locked file region.
    /// If a segment has an exclusive lock, it may not have any shared locks
    /// or other exclusive locks.
    readWrite
}

struct LockingTextReader
{
    private File _f;
    private dchar _front;

    this(File f)
    {
        import std.exception : enforce;
        enforce(f.isOpen);
        _f = f;
        FLOCK(_f._p.handle);
        readFront();
    }

    this(this)
    {
        FLOCK(_f._p.handle);
    }

    ~this()
    {
        // File locking has its own reference count
        if (_f.isOpen) FUNLOCK(_f._p.handle);
    }

    void opAssign(LockingTextReader r)
    {
        import std.algorithm : swap;
        swap(this, r);
    }

    @property bool empty()
    {
        return !_f.isOpen || _f.eof;
    }

    @property dchar front()
    {
        version(assert)
        {
            import core.exception : RangeError;
            if (empty)
                throw new RangeError();
        }
        return _front;
    }

    /* Read a utf8 sequence from the file, removing the chars from the stream.
    Returns an empty result when at EOF. */
    private char[] takeFront(return ref char[4] buf)
    {
        import std.utf : stride, UTFException;
        {
            immutable int c = FGETC(cast(_iobuf*) _f._p.handle);
            if (c == EOF)
                return buf[0 .. 0];
            buf[0] = cast(char) c;
        }
        immutable seqLen = stride(buf[]);
        foreach(ref u; buf[1 .. seqLen])
        {
            immutable int c = FGETC(cast(_iobuf*) _f._p.handle);
            if (c == EOF) // incomplete sequence
                throw new UTFException("Invalid UTF-8 sequence");
            u = cast(char) c;
        }
        return buf[0 .. seqLen];
    }

    /* Read a utf8 sequence from the file into _front, putting the chars back so
    that they can be read again.
    Destroys/closes the file when at EOF. */
    private void readFront()
    {
        import std.exception : enforce;
        import std.utf : decodeFront;

        char[4] buf;
        auto chars = takeFront(buf);

        if (chars.empty)
        {
            .destroy(_f);
            assert(empty);
            return;
        }

        auto s = chars;
        _front = decodeFront(s);

        // Put everything back.
        foreach(immutable i; 0 .. chars.length)
        {
            immutable c = chars[$ - 1 - i];
            enforce(ungetc(c, cast(FILE*) _f._p.handle) == c);
        }
    }

    void popFront()
    {
        version(assert)
        {
            import core.exception : RangeError;
            if (empty)
                throw new RangeError();
        }

        // Pop the current front.
        char[4] buf;
        takeFront(buf);

        // Read the next front, leaving the chars on the stream.
        readFront();
    }

    // void unget(dchar c)
    // {
    //     ungetc(c, cast(FILE*) _f._p.handle);
    // }
}

unittest
{
    static import std.file;
    import std.range.primitives : isInputRange;

    static assert(isInputRange!LockingTextReader);
    auto deleteme = testFilename();
    std.file.write(deleteme, "1 2 3");
    scope(exit) std.file.remove(deleteme);
    int x, y;
    auto f = File(deleteme);
    f.readf("%s ", &x);
    assert(x == 1);
    f.readf("%d ", &x);
    assert(x == 2);
    f.readf("%d ", &x);
    assert(x == 3);
    //pragma(msg, "--- todo: readf ---");
}

unittest // bugzilla 13686
{
    static import std.file;
    import std.algorithm : equal;

    auto deleteme = testFilename();
    std.file.write(deleteme, "Тест");
    scope(exit) std.file.remove(deleteme);

    string s;
    File(deleteme).readf("%s", &s);
    assert(s == "Тест");

    auto ltr = LockingTextReader(File(deleteme));
    assert(equal(ltr, "Тест"));
}

unittest // bugzilla 12320
{
    static import std.file;
    auto deleteme = testFilename();
    std.file.write(deleteme, "ab");
    scope(exit) std.file.remove(deleteme);
    auto ltr = LockingTextReader(File(deleteme));
    assert(ltr.front == 'a');
    ltr.popFront();
    assert(ltr.front == 'b');
    ltr.popFront();
    assert(ltr.empty);
}

/**
 * Indicates whether $(D T) is a file handle of some kind.
 */
template isFileHandle(T)
{
    enum isFileHandle = is(T : FILE*) ||
        is(T : File);
}

unittest
{
    static assert(isFileHandle!(FILE*));
    static assert(isFileHandle!(File));
}

/**
 * $(RED Deprecated. Please use $(D isFileHandle) instead. This alias will be
 *       removed in June 2015.)
 */
deprecated("Please use isFileHandle instead.")
alias isStreamingDevice = isFileHandle;

/**
 * Property used by writeln/etc. so it can infer @safe since stdout is __gshared
 */
private @property File trustedStdout() @trusted { return stdout; }

/***********************************
For each argument $(D arg) in $(D args), format the argument (as per
$(LINK2 std_conv.html, to!(string)(arg))) and write the resulting
string to $(D args[0]). A call without any arguments will fail to
compile.

Throws: In case of an I/O error, throws an $(D StdioException).
 */
void write(T...)(T args) if (!is(T[0] : File))
{
    trustedStdout.write(args);
}

unittest
{
    static import std.file;

    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    void[] buf;
    if (false) write(buf);
    // test write
    auto deleteme = testFilename();
    auto f = File(deleteme, "w");
    f.write("Hello, ",  "world number ", 42, "!");
    f.close();
    scope(exit) { std.file.remove(deleteme); }
    assert(cast(char[]) std.file.read(deleteme) == "Hello, world number 42!");
    // // test write on stdout
    //auto saveStdout = stdout;
    //scope(exit) stdout = saveStdout;
    //stdout.open(file, "w");
    Object obj;
    //write("Hello, ",  "world number ", 42, "! ", obj);
    //stdout.close();
    // auto result = cast(char[]) std.file.read(file);
    // assert(result == "Hello, world number 42! null", result);
}

/***********************************
 * Equivalent to $(D write(args, '\n')).  Calling $(D writeln) without
 * arguments is valid and just prints a newline to the standard
 * output.
 */
void writeln(T...)(T args)
{
    import std.traits : isAggregateType;
    static if (T.length == 0)
    {
        import std.exception : enforce;

        enforce(fputc('\n', .stdout._p.handle) == '\n');
    }
    else static if (T.length == 1 &&
                    is(typeof(args[0]) : const(char)[]) &&
                    !is(typeof(args[0]) == enum) &&
                    !is(Unqual!(typeof(args[0])) == typeof(null)) &&
                    !isAggregateType!(typeof(args[0])))
    {
        import std.exception : enforce;

        // Specialization for strings - a very frequent case
        auto w = .trustedStdout.lockingTextWriter();

        static if (isStaticArray!(typeof(args[0])))
        {
            w.put(args[0][]);
        }
        else
        {
            w.put(args[0]);
        }
        w.put('\n');
    }
    else
    {
        // Most general instance
        trustedStdout.write(args, '\n');
    }
}

unittest
{
    // Just make sure the call compiles
    if (false) writeln();

    if (false) writeln("wyda");

    // bug 8040
    if (false) writeln(null);
    if (false) writeln(">", null, "<");

    // Bugzilla 14041
    if (false)
    {
        char[8] a;
        writeln(a);
    }
}

unittest
{
    static import std.file;

    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);

    // test writeln
    auto deleteme = testFilename();
    auto f = File(deleteme, "w");
    scope(exit) { std.file.remove(deleteme); }
    f.writeln("Hello, ",  "world number ", 42, "!");
    f.close();
    version (Windows)
        assert(cast(char[]) std.file.read(deleteme) ==
                "Hello, world number 42!\r\n");
    else
        assert(cast(char[]) std.file.read(deleteme) ==
                "Hello, world number 42!\n");

    // test writeln on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout.open(deleteme, "w");
    writeln("Hello, ",  "world number ", 42, "!");
    stdout.close();
    version (Windows)
        assert(cast(char[]) std.file.read(deleteme) ==
                "Hello, world number 42!\r\n");
    else
        assert(cast(char[]) std.file.read(deleteme) ==
                "Hello, world number 42!\n");

    stdout.open(deleteme, "w");
    writeln("Hello!"c);
    writeln("Hello!"w);    // bug 8386
    writeln("Hello!"d);    // bug 8386
    writeln("embedded\0null"c); // bug 8730
    stdout.close();
    version (Windows)
        assert(cast(char[]) std.file.read(deleteme) ==
            "Hello!\r\nHello!\r\nHello!\r\nembedded\0null\r\n");
    else
        assert(cast(char[]) std.file.read(deleteme) ==
            "Hello!\nHello!\nHello!\nembedded\0null\n");
}

unittest
{
    static import std.file;

    auto deleteme = testFilename();
    auto f = File(deleteme, "w");
    scope(exit) { std.file.remove(deleteme); }

    enum EI : int    { A, B }
    enum ED : double { A, B }
    enum EC : char   { A, B }
    enum ES : string { A = "aaa", B = "bbb" }

    f.writeln(EI.A);  // false, but A on 2.058
    f.writeln(EI.B);  // true, but B on 2.058

    f.writeln(ED.A);  // A
    f.writeln(ED.B);  // B

    f.writeln(EC.A);  // A
    f.writeln(EC.B);  // B

    f.writeln(ES.A);  // A
    f.writeln(ES.B);  // B

    f.close();
    version (Windows)
        assert(cast(char[]) std.file.read(deleteme) ==
                "A\r\nB\r\nA\r\nB\r\nA\r\nB\r\nA\r\nB\r\n");
    else
        assert(cast(char[]) std.file.read(deleteme) ==
                "A\nB\nA\nB\nA\nB\nA\nB\n");
}

unittest
{
    static auto useInit(T)(T ltw)
    {
        T val;
        val = ltw;
        val = T.init;
        return val;
    }
    useInit(stdout.lockingTextWriter());
}


/***********************************
Writes formatted data to standard output (without a trailing newline).

Params:
args = The first argument $(D args[0]) should be the format string, specifying
how to format the rest of the arguments. For a full description of the syntax
of the format string and how it controls the formatting of the rest of the
arguments, please refer to the documentation for $(XREF format,
formattedWrite).

Note: In older versions of Phobos, it used to be possible to write:

------
writef(stderr, "%s", "message");
------

to print a message to $(D stderr). This syntax is no longer supported, and has
been superceded by:

------
stderr.writef("%s", "message");
------

*/

void writef(T...)(T args)
{
    trustedStdout.writef(args);
}

unittest
{
    static import std.file;

    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);

    // test writef
    auto deleteme = testFilename();
    auto f = File(deleteme, "w");
    scope(exit) { std.file.remove(deleteme); }
    f.writef("Hello, %s world number %s!", "nice", 42);
    f.close();
    assert(cast(char[]) std.file.read(deleteme) ==  "Hello, nice world number 42!");
    // test write on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout.open(deleteme, "w");
    writef("Hello, %s world number %s!", "nice", 42);
    stdout.close();
    assert(cast(char[]) std.file.read(deleteme) == "Hello, nice world number 42!");
}

/***********************************
 * Equivalent to $(D writef(args, '\n')).
 */
void writefln(T...)(T args)
{
    trustedStdout.writefln(args);
}

unittest
{
    static import std.file;

    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);

    // test writefln
    auto deleteme = testFilename();
    auto f = File(deleteme, "w");
    scope(exit) { std.file.remove(deleteme); }
    f.writefln("Hello, %s world number %s!", "nice", 42);
    f.close();
    version (Windows)
        assert(cast(char[]) std.file.read(deleteme) ==
                "Hello, nice world number 42!\r\n");
    else
        assert(cast(char[]) std.file.read(deleteme) ==
                "Hello, nice world number 42!\n",
                cast(char[]) std.file.read(deleteme));
    // test write on stdout
    // auto saveStdout = stdout;
    // scope(exit) stdout = saveStdout;
    // stdout.open(file, "w");
    // assert(stdout.isOpen);
    // writefln("Hello, %s world number %s!", "nice", 42);
    // foreach (F ; TypeTuple!(ifloat, idouble, ireal))
    // {
    //     F a = 5i;
    //     F b = a % 2;
    //     writeln(b);
    // }
    // stdout.close();
    // auto read = cast(char[]) std.file.read(file);
    // version (Windows)
    //     assert(read == "Hello, nice world number 42!\r\n1\r\n1\r\n1\r\n", read);
    // else
    //     assert(read == "Hello, nice world number 42!\n1\n1\n1\n", "["~read~"]");
}

/**
 * Read data from $(D stdin) according to the specified
 * $(LINK2 std_format.html#format-string, format specifier) using
 * $(XREF format,formattedRead).
 */
uint readf(A...)(in char[] format, A args)
{
    return stdin.readf(format, args);
}

unittest
{
    float f;
    if (false) uint x = readf("%s", &f);

    char a;
    wchar b;
    dchar c;
    if (false) readf("%s %s %s", &a,&b,&c);
}

/**********************************
 * Read line from $(D stdin).
 *
 * This version manages its own read buffer, which means one memory allocation per call. If you are not
 * retaining a reference to the read data, consider the $(D readln(buf)) version, which may offer
 * better performance as it can reuse its read buffer.
 *
 * Returns:
 *        The line that was read, including the line terminator character.
 * Params:
 *        S = Template parameter; the type of the allocated buffer, and the type returned. Defaults to $(D string).
 *        terminator = Line terminator (by default, $(D '\n')).
 * Note:
 *        String terminators are not supported due to ambiguity with readln(buf) below.
 * Throws:
 *        $(D StdioException) on I/O error, or $(D UnicodeException) on Unicode conversion error.
 * Example:
 *        Reads $(D stdin) and writes it to $(D stdout).
---
import std.stdio;

void main()
{
    string line;
    while ((line = readln()) !is null)
        write(line);
}
---
*/
S readln(S = string)(dchar terminator = '\n')
if (isSomeString!S)
{
    return stdin.readln!S(terminator);
}

/**********************************
 * Read line from $(D stdin) and write it to buf[], including terminating character.
 *
 * This can be faster than $(D line = readln()) because you can reuse
 * the buffer for each call. Note that reusing the buffer means that you
 * must copy the previous contents if you wish to retain them.
 *
 * Returns:
 *        $(D size_t) 0 for end of file, otherwise number of characters read
 * Params:
 *        buf = Buffer used to store the resulting line data. buf is resized as necessary.
 *        terminator = Line terminator (by default, $(D '\n')). Use $(XREF ascii, newline)
 *        for portability (unless the file was opened in text mode).
 * Throws:
 *        $(D StdioException) on I/O error, or $(D UnicodeException) on Unicode conversion error.
 * Example:
 *        Reads $(D stdin) and writes it to $(D stdout).
---
import std.stdio;

void main()
{
    char[] buf;
    while (readln(buf))
        write(buf);
}
---
*/
size_t readln(C)(ref C[] buf, dchar terminator = '\n')
if (isSomeChar!C && is(Unqual!C == C) && !is(C == enum))
{
    return stdin.readln(buf, terminator);
}

/** ditto */
size_t readln(C, R)(ref C[] buf, R terminator)
if (isSomeChar!C && is(Unqual!C == C) && !is(C == enum) &&
    isBidirectionalRange!R && is(typeof(terminator.front == dchar.init)))
{
    return stdin.readln(buf, terminator);
}

unittest
{
    import std.typetuple : TypeTuple;

    //we can't actually test readln, so at the very least,
    //we test compilability
    void foo()
    {
        readln();
        readln('\t');
        foreach (String; TypeTuple!(string, char[], wstring, wchar[], dstring, dchar[]))
        {
            readln!String();
            readln!String('\t');
        }
        foreach (String; TypeTuple!(char[], wchar[], dchar[]))
        {
            String buf;
            readln(buf);
            readln(buf, '\t');
            readln(buf, "<br />");
        }
    }
}

/*
 * Convenience function that forwards to $(D core.sys.posix.stdio.fopen)
 * (to $(D _wfopen) on Windows)
 * with appropriately-constructed C-style strings.
 */
private FILE* fopen(in char[] name, in char[] mode = "r") @trusted nothrow @nogc
{
    import std.internal.cstring : tempCString;

    version(Windows)
    {
        import std.internal.cstring : tempCStringW;
        return _wfopen(name.tempCStringW(), mode.tempCStringW());
    }
    else version(Posix)
    {
        /*
         * The new opengroup large file support API is transparently
         * included in the normal C bindings. http://opengroup.org/platform/lfs.html#1.0
         * if _FILE_OFFSET_BITS in druntime is 64, off_t is 64 bit and
         * the normal functions work fine. If not, then large file support
         * probably isn't available. Do not use the old transitional API
         * (the native extern(C) fopen64, http://www.unix.org/version2/whatsnew/lfs20mar.html#3.0)
         */
        import core.sys.posix.stdio : fopen;
        return fopen(name.tempCString(), mode.tempCString());
    }
    else
    {
        return .fopen(name.tempCString(), mode.tempCString());
    }
}

version (Posix)
{
    /***********************************
     * Convenience function that forwards to $(D core.sys.posix.stdio.popen)
     * with appropriately-constructed C-style strings.
     */
    FILE* popen(in char[] name, in char[] mode = "r") @trusted nothrow @nogc
    {
        import core.sys.posix.stdio : popen;
        import std.internal.cstring : tempCString;

        return popen(name.tempCString(), mode.tempCString());
    }
}

/*
 * Convenience function that forwards to $(D core.stdc.stdio.fwrite)
 * and throws an exception upon error
 */
private void binaryWrite(T)(FILE* f, T obj)
{
    immutable result = fwrite(obj.ptr, obj[0].sizeof, obj.length, f);
    if (result != obj.length) StdioException();
}

/**
 * Iterates through the lines of a file by using $(D foreach).
 *
 * Example:
 *
---------
void main()
{
  foreach (string line; lines(stdin))
  {
    ... use line ...
  }
}
---------
The line terminator ($(D '\n') by default) is part of the string read (it
could be missing in the last line of the file). Several types are
supported for $(D line), and the behavior of $(D lines)
changes accordingly:

$(OL $(LI If $(D line) has type $(D string), $(D
wstring), or $(D dstring), a new string of the respective type
is allocated every read.) $(LI If $(D line) has type $(D
char[]), $(D wchar[]), $(D dchar[]), the line's content
will be reused (overwritten) across reads.) $(LI If $(D line)
has type $(D immutable(ubyte)[]), the behavior is similar to
case (1), except that no UTF checking is attempted upon input.) $(LI
If $(D line) has type $(D ubyte[]), the behavior is
similar to case (2), except that no UTF checking is attempted upon
input.))

In all cases, a two-symbols versions is also accepted, in which case
the first symbol (of integral type, e.g. $(D ulong) or $(D
uint)) tracks the zero-based number of the current line.

Example:
----
  foreach (ulong i, string line; lines(stdin))
  {
    ... use line ...
  }
----

 In case of an I/O error, an $(D StdioException) is thrown.

See_Also:
$(LREF byLine)
 */

struct lines
{
    private File f;
    private dchar terminator = '\n';
    // private string fileName;  // Curretly, no use

    /**
    Constructor.
    Params:
    f = File to read lines from.
    terminator = Line separator ($(D '\n') by default).
    */
    this(File f, dchar terminator = '\n')
    {
        this.f = f;
        this.terminator = terminator;
    }

    // Keep these commented lines for later, when Walter fixes the
    // exception model.

//     static lines opCall(string fName, dchar terminator = '\n')
//     {
//         auto f = enforce(fopen(fName),
//             new StdioException("Cannot open file `"~fName~"' for reading"));
//         auto result = lines(f, terminator);
//         result.fileName = fName;
//         return result;
//     }

    int opApply(D)(scope D dg)
    {
//         scope(exit) {
//             if (fileName.length && fclose(f))
//                 StdioException("Could not close file `"~fileName~"'");
//         }
        import std.traits : ParameterTypeTuple;
        alias Parms = ParameterTypeTuple!(dg);
        static if (isSomeString!(Parms[$ - 1]))
        {
            enum bool duplicate = is(Parms[$ - 1] == string)
                || is(Parms[$ - 1] == wstring) || is(Parms[$ - 1] == dstring);
            int result = 0;
            static if (is(Parms[$ - 1] : const(char)[]))
                alias C = char;
            else static if (is(Parms[$ - 1] : const(wchar)[]))
                alias C = wchar;
            else static if (is(Parms[$ - 1] : const(dchar)[]))
                alias C = dchar;
            C[] line;
            static if (Parms.length == 2)
                Parms[0] i = 0;
            for (;;)
            {
                import std.conv : to;

                if (!f.readln(line, terminator)) break;
                auto copy = to!(Parms[$ - 1])(line);
                static if (Parms.length == 2)
                {
                    result = dg(i, copy);
                    ++i;
                }
                else
                {
                    result = dg(copy);
                }
                if (result != 0) break;
            }
            return result;
        }
        else
        {
            // raw read
            return opApplyRaw(dg);
        }
    }
    // no UTF checking
    int opApplyRaw(D)(scope D dg)
    {
        import std.exception : assumeUnique;
        import std.conv : to;
        import std.traits : ParameterTypeTuple;

        alias Parms = ParameterTypeTuple!(dg);
        enum duplicate = is(Parms[$ - 1] : immutable(ubyte)[]);
        int result = 1;
        int c = void;
        FLOCK(f._p.handle);
        scope(exit) FUNLOCK(f._p.handle);
        ubyte[] buffer;
        static if (Parms.length == 2)
            Parms[0] line = 0;
        while ((c = FGETC(cast(_iobuf*)f._p.handle)) != -1)
        {
            buffer ~= to!(ubyte)(c);
            if (c == terminator)
            {
                static if (duplicate)
                    auto arg = assumeUnique(buffer);
                else
                    alias arg = buffer;
                // unlock the file while calling the delegate
                FUNLOCK(f._p.handle);
                scope(exit) FLOCK(f._p.handle);
                static if (Parms.length == 1)
                {
                    result = dg(arg);
                }
                else
                {
                    result = dg(line, arg);
                    ++line;
                }
                if (result) break;
                static if (!duplicate)
                    buffer.length = 0;
            }
        }
        // can only reach when FGETC returned -1
        if (!f.eof) throw new StdioException("Error in reading file"); // error occured
        return result;
    }
}

unittest
{
    static import std.file;
    import std.typetuple : TypeTuple;

    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);

    auto deleteme = testFilename();
    scope(exit) { std.file.remove(deleteme); }

    alias TestedWith =
          TypeTuple!(string, wstring, dstring,
                     char[], wchar[], dchar[]);
    foreach (T; TestedWith) {
        // test looping with an empty file
        std.file.write(deleteme, "");
        auto f = File(deleteme, "r");
        foreach (T line; lines(f))
        {
            assert(false);
        }
        f.close();

        // test looping with a file with three lines
        std.file.write(deleteme, "Line one\nline two\nline three\n");
        f.open(deleteme, "r");
        uint i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(line == "Line one\n");
            else if (i == 1) assert(line == "line two\n");
            else if (i == 2) assert(line == "line three\n");
            else assert(false);
            ++i;
        }
        f.close();

        // test looping with a file with three lines, last without a newline
        std.file.write(deleteme, "Line one\nline two\nline three");
        f.open(deleteme, "r");
        i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(line == "Line one\n");
            else if (i == 1) assert(line == "line two\n");
            else if (i == 2) assert(line == "line three");
            else assert(false);
            ++i;
        }
        f.close();
    }

    // test with ubyte[] inputs
    //@@@BUG 2612@@@
    //alias TestedWith2 = TypeTuple!(immutable(ubyte)[], ubyte[]);
    alias TestedWith2 = TypeTuple!(immutable(ubyte)[], ubyte[]);
    foreach (T; TestedWith2) {
        // test looping with an empty file
        std.file.write(deleteme, "");
        auto f = File(deleteme, "r");
        foreach (T line; lines(f))
        {
            assert(false);
        }
        f.close();

        // test looping with a file with three lines
        std.file.write(deleteme, "Line one\nline two\nline three\n");
        f.open(deleteme, "r");
        uint i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n",
                T.stringof ~ " " ~ cast(char[]) line);
            else if (i == 2) assert(cast(char[]) line == "line three\n");
            else assert(false);
            ++i;
        }
        f.close();

        // test looping with a file with three lines, last without a newline
        std.file.write(deleteme, "Line one\nline two\nline three");
        f.open(deleteme, "r");
        i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n");
            else if (i == 2) assert(cast(char[]) line == "line three");
            else assert(false);
            ++i;
        }
        f.close();

    }

    foreach (T; TypeTuple!(ubyte[]))
    {
        // test looping with a file with three lines, last without a newline
        // using a counter too this time
        std.file.write(deleteme, "Line one\nline two\nline three");
        auto f = File(deleteme, "r");
        uint i = 0;
        foreach (ulong j, T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n");
            else if (i == 2) assert(cast(char[]) line == "line three");
            else assert(false);
            ++i;
        }
        f.close();
    }
}

/**
Iterates through a file a chunk at a time by using $(D foreach).

Example:

---------
void main()
{
    foreach (ubyte[] buffer; chunks(stdin, 4096))
    {
        ... use buffer ...
    }
}
---------

The content of $(D buffer) is reused across calls. In the
 example above, $(D buffer.length) is 4096 for all iterations,
 except for the last one, in which case $(D buffer.length) may
 be less than 4096 (but always greater than zero).

 In case of an I/O error, an $(D StdioException) is thrown.
*/
auto chunks(File f, size_t size)
{
    return ChunksImpl(f, size);
}
private struct ChunksImpl
{
    private File f;
    private size_t size;
    // private string fileName; // Currently, no use

    this(File f, size_t size)
    in
    {
        assert(size, "size must be larger than 0");
    }
    body
    {
        this.f = f;
        this.size = size;
    }

//     static chunks opCall(string fName, size_t size)
//     {
//         auto f = enforce(fopen(fName),
//             new StdioException("Cannot open file `"~fName~"' for reading"));
//         auto result = chunks(f, size);
//         result.fileName  = fName;
//         return result;
//     }

    int opApply(D)(scope D dg)
    {
        import core.stdc.stdlib : alloca;
        enum maxStackSize = 1024 * 16;
        ubyte[] buffer = void;
        if (size < maxStackSize)
            buffer = (cast(ubyte*) alloca(size))[0 .. size];
        else
            buffer = new ubyte[size];
        size_t r = void;
        int result = 1;
        uint tally = 0;
        while ((r = fread(buffer.ptr, buffer[0].sizeof, size, f._p.handle)) > 0)
        {
            assert(r <= size);
            if (r != size)
            {
                // error occured
                if (!f.eof) throw new StdioException(null);
                buffer.length = r;
            }
            static if (is(typeof(dg(tally, buffer)))) {
                if ((result = dg(tally, buffer)) != 0) break;
            } else {
                if ((result = dg(buffer)) != 0) break;
            }
            ++tally;
        }
        return result;
    }
}

unittest
{
    static import std.file;

    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);

    auto deleteme = testFilename();
    scope(exit) { std.file.remove(deleteme); }

    // test looping with an empty file
    std.file.write(deleteme, "");
    auto f = File(deleteme, "r");
    foreach (ubyte[] line; chunks(f, 4))
    {
        assert(false);
    }
    f.close();

    // test looping with a file with three lines
    std.file.write(deleteme, "Line one\nline two\nline three\n");
    f = File(deleteme, "r");
    uint i = 0;
    foreach (ubyte[] line; chunks(f, 3))
    {
        if (i == 0) assert(cast(char[]) line == "Lin");
        else if (i == 1) assert(cast(char[]) line == "e o");
        else if (i == 2) assert(cast(char[]) line == "ne\n");
        else break;
        ++i;
    }
    f.close();
}

/*********************
 * Thrown if I/O errors happen.
 */
class StdioException : Exception
{
    static import core.stdc.errno;
    /// Operating system error code.
    uint errno;

/**
Initialize with a message and an error code.
*/
    this(string message, uint e = core.stdc.errno.errno)
    {
        import std.conv : to;

        errno = e;
        version (Posix)
        {
            import core.stdc.string : strerror_r;

            char[256] buf = void;
            version (linux)
            {
                auto s = core.stdc.string.strerror_r(errno, buf.ptr, buf.length);
            }
            else
            {
                core.stdc.string.strerror_r(errno, buf.ptr, buf.length);
                auto s = buf.ptr;
            }
        }
        else
        {
            import core.stdc.string : strerror;

            auto s = core.stdc.string.strerror(errno);
        }
        auto sysmsg = to!string(s);
        // If e is 0, we don't use the system error message.  (The message
        // is "Success", which is rather pointless for an exception.)
        super(e == 0 ? message
                     : (message.ptr ? message ~ " (" ~ sysmsg ~ ")" : sysmsg));
    }

/** Convenience functions that throw an $(D StdioException). */
    static void opCall(string msg)
    {
        throw new StdioException(msg);
    }

/// ditto
    static void opCall()
    {
        throw new StdioException(null, core.stdc.errno.errno);
    }
}

extern(C) void std_stdio_static_this()
{
    static import core.stdc.stdio;
    //Bind stdin, stdout, stderr
    __gshared File.Impl stdinImpl;
    stdinImpl.handle = core.stdc.stdio.stdin;
    .stdin._p = &stdinImpl;
    // stdout
    __gshared File.Impl stdoutImpl;
    stdoutImpl.handle = core.stdc.stdio.stdout;
    .stdout._p = &stdoutImpl;
    // stderr
    __gshared File.Impl stderrImpl;
    stderrImpl.handle = core.stdc.stdio.stderr;
    .stderr._p = &stderrImpl;
}

//---------
__gshared
{
    /** The standard input stream.
     */
    File stdin;
    ///
    unittest
    {
        // Read stdin, sort lines, write to stdout
        import std.stdio, std.array, std.algorithm : sort, copy;

        void main() {
            stdin                       // read from stdin
            .byLineCopy(KeepTerminator.yes) // copying each line
            .array()                    // convert to array of lines
            .sort()                     // sort the lines
            .copy(                      // copy output of .sort to an OutputRange
                stdout.lockingTextWriter()); // the OutputRange
        }
    }

    File stdout; /// The standard output stream.
    File stderr; /// The standard error stream.
}

unittest
{
    static import std.file;
    import std.typecons : tuple;

    scope(failure) printf("Failed test at line %d\n", __LINE__);
    auto deleteme = testFilename();

    std.file.write(deleteme, "1 2\n4 1\n5 100");
    scope(exit) std.file.remove(deleteme);
    {
        File f = File(deleteme);
        scope(exit) f.close();
        auto t = [ tuple(1, 2), tuple(4, 1), tuple(5, 100) ];
        uint i;
        foreach (e; f.byRecord!(int, int)("%s %s"))
        {
            //writeln(e);
            assert(e == t[i++]);
        }
        assert(i == 3);
    }
}

// Private implementation of readln
version (DIGITAL_MARS_STDIO)
private size_t readlnImpl(FILE* fps, ref char[] buf, dchar terminator = '\n')
{
    import core.memory;
    import core.stdc.string : memcpy;
    import std.array : appender, uninitializedArray;

    FLOCK(fps);
    scope(exit) FUNLOCK(fps);

    /* Since fps is now locked, we can create an "unshared" version
     * of fp.
     */
    auto fp = cast(_iobuf*)fps;

    if (__fhnd_info[fp._file] & FHND_WCHAR)
    {   /* Stream is in wide characters.
         * Read them and convert to chars.
         */
        static assert(wchar_t.sizeof == 2);
        auto app = appender(buf);
        app.clear();
        for (int c = void; (c = FGETWC(fp)) != -1; )
        {
            if ((c & ~0x7F) == 0)
            {   app.put(cast(char) c);
                if (c == terminator)
                    break;
            }
            else
            {
                if (c >= 0xD800 && c <= 0xDBFF)
                {
                    int c2 = void;
                    if ((c2 = FGETWC(fp)) != -1 ||
                            c2 < 0xDC00 && c2 > 0xDFFF)
                    {
                        StdioException("unpaired UTF-16 surrogate");
                    }
                    c = ((c - 0xD7C0) << 10) + (c2 - 0xDC00);
                }
                //std.utf.encode(buf, c);
                app.put(cast(dchar)c);
            }
        }
        if (ferror(fps))
            StdioException();
        buf = app.data;
        return buf.length;
    }

    auto sz = GC.sizeOf(buf.ptr);
    //auto sz = buf.length;
    buf = buf.ptr[0 .. sz];
    if (fp._flag & _IONBF)
    {
        /* Use this for unbuffered I/O, when running
         * across buffer boundaries, or for any but the common
         * cases.
         */
      L1:
        auto app = appender(buf);
        app.clear();
        if(app.capacity == 0)
            app.reserve(128); // get at least 128 bytes available

        int c;
        while((c = FGETC(fp)) != -1) {
            app.put(cast(char) c);
            if(c == terminator) {
                buf = app.data;
                return buf.length;
            }

        }

        if (ferror(fps))
            StdioException();
        buf = app.data;
        return buf.length;
    }
    else
    {
        int u = fp._cnt;
        char* p = fp._ptr;
        int i;
        if (fp._flag & _IOTRAN)
        {   /* Translated mode ignores \r and treats ^Z as end-of-file
             */
            char c;
            while (1)
            {
                if (i == u)                // if end of buffer
                    goto L1;        // give up
                c = p[i];
                i++;
                if (c != '\r')
                {
                    if (c == terminator)
                        break;
                    if (c != 0x1A)
                        continue;
                    goto L1;
                }
                else
                {   if (i != u && p[i] == terminator)
                        break;
                    goto L1;
                }
            }
            if (i > sz)
            {
                buf = uninitializedArray!(char[])(i);
            }
            if (i - 1)
                memcpy(buf.ptr, p, i - 1);
            buf[i - 1] = cast(char)terminator;
            buf = buf[0 .. i];
            if (terminator == '\n' && c == '\r')
                i++;
        }
        else
        {
            while (1)
            {
                if (i == u)                // if end of buffer
                    goto L1;        // give up
                auto c = p[i];
                i++;
                if (c == terminator)
                    break;
            }
            if (i > sz)
            {
                buf = uninitializedArray!(char[])(i);
            }
            memcpy(buf.ptr, p, i);
            buf = buf[0 .. i];
        }
        fp._cnt -= i;
        fp._ptr += i;
        return i;
    }
}

version (MICROSOFT_STDIO)
private size_t readlnImpl(FILE* fps, ref char[] buf, dchar terminator = '\n')
{
    import core.memory;
    import std.array : appender, uninitializedArray;

    FLOCK(fps);
    scope(exit) FUNLOCK(fps);

    /* Since fps is now locked, we can create an "unshared" version
     * of fp.
     */
    auto fp = cast(_iobuf*)fps;

    auto sz = GC.sizeOf(buf.ptr);
    //auto sz = buf.length;
    buf = buf.ptr[0 .. sz];

    auto app = appender(buf);
    app.clear();
    if(app.capacity == 0)
        app.reserve(128); // get at least 128 bytes available

    int c;
    while((c = FGETC(fp)) != -1) {
        app.put(cast(char) c);
        if(c == terminator) {
            buf = app.data;
            return buf.length;
        }

    }

    if (ferror(fps))
        StdioException();
    buf = app.data;
    return buf.length;
}

version (GCC_IO)
private size_t readlnImpl(FILE* fps, ref char[] buf, dchar terminator = '\n')
{
    import core.memory;
    import core.stdc.stdlib : free;
    import core.stdc.wchar_ : fwide;
    import std.utf : encode;

    if (fwide(fps, 0) > 0)
    {
        /* Stream is in wide characters.
         * Read them and convert to chars.
         */
        FLOCK(fps);
        scope(exit) FUNLOCK(fps);
        auto fp = cast(_iobuf*)fps;
        version (Windows)
        {
            buf.length = 0;
            for (int c = void; (c = FGETWC(fp)) != -1; )
            {
                if ((c & ~0x7F) == 0)
                {   buf ~= c;
                    if (c == terminator)
                        break;
                }
                else
                {
                    if (c >= 0xD800 && c <= 0xDBFF)
                    {
                        int c2 = void;
                        if ((c2 = FGETWC(fp)) != -1 ||
                                c2 < 0xDC00 && c2 > 0xDFFF)
                        {
                            StdioException("unpaired UTF-16 surrogate");
                        }
                        c = ((c - 0xD7C0) << 10) + (c2 - 0xDC00);
                    }
                    std.utf.encode(buf, c);
                }
            }
            if (ferror(fp))
                StdioException();
            return buf.length;
        }
        else version (Posix)
        {
            buf.length = 0;
            for (int c; (c = FGETWC(fp)) != -1; )
            {
                if ((c & ~0x7F) == 0)
                    buf ~= cast(char)c;
                else
                    std.utf.encode(buf, cast(dchar)c);
                if (c == terminator)
                    break;
            }
            if (ferror(fps))
                StdioException();
            return buf.length;
        }
        else
        {
            static assert(0);
        }
    }

    char *lineptr = null;
    size_t n = 0;
    auto s = getdelim(&lineptr, &n, terminator, fps);
    scope(exit) free(lineptr);
    if (s < 0)
    {
        if (ferror(fps))
            StdioException();
        buf.length = 0;                // end of file
        return 0;
    }
    buf = buf.ptr[0 .. GC.sizeOf(buf.ptr)];
    if (s <= buf.length)
    {
        buf.length = s;
        buf[] = lineptr[0 .. s];
    }
    else
    {
        buf = lineptr[0 .. s].dup;
    }
    return s;
}

version (GENERIC_IO)
private size_t readlnImpl(FILE* fps, ref char[] buf, dchar terminator = '\n')
{
    import core.stdc.wchar_ : fwide;
    import std.utf : encode;

    FLOCK(fps);
    scope(exit) FUNLOCK(fps);
    auto fp = cast(_iobuf*)fps;
    if (fwide(fps, 0) > 0)
    {
        /* Stream is in wide characters.
         * Read them and convert to chars.
         */
        version (Windows)
        {
            buf.length = 0;
            for (int c; (c = FGETWC(fp)) != -1; )
            {
                if ((c & ~0x7F) == 0)
                {   buf ~= c;
                    if (c == terminator)
                        break;
                }
                else
                {
                    if (c >= 0xD800 && c <= 0xDBFF)
                    {
                        int c2 = void;
                        if ((c2 = FGETWC(fp)) != -1 ||
                                c2 < 0xDC00 && c2 > 0xDFFF)
                        {
                            StdioException("unpaired UTF-16 surrogate");
                        }
                        c = ((c - 0xD7C0) << 10) + (c2 - 0xDC00);
                    }
                    std.utf.encode(buf, c);
                }
            }
            if (ferror(fp))
                StdioException();
            return buf.length;
        }
        else version (Posix)
        {
            buf.length = 0;
            for (int c; (c = FGETWC(fp)) != -1; )
            {
                if ((c & ~0x7F) == 0)
                    buf ~= cast(char)c;
                else
                    std.utf.encode(buf, cast(dchar)c);
                if (c == terminator)
                    break;
            }
            if (ferror(fps))
                StdioException();
            return buf.length;
        }
        else
        {
            static assert(0);
        }
    }

    // Narrow stream
    // First, fill the existing buffer
    for (size_t bufPos = 0; bufPos < buf.length; )
    {
        immutable c = FGETC(fp);
        if (c == -1)
        {
            buf.length = bufPos;
            goto endGame;
        }
        buf.ptr[bufPos++] = cast(char) c;
        if (c == terminator)
        {
            // No need to test for errors in file
            buf.length = bufPos;
            return bufPos;
        }
    }
    // Then, append to it
    for (int c; (c = FGETC(fp)) != -1; )
    {
        buf ~= cast(char)c;
        if (c == terminator)
        {
            // No need to test for errors in file
            return buf.length;
        }
    }

  endGame:
    if (ferror(fps))
        StdioException();
    return buf.length;
}


/** Experimental network access via the File interface

        Opens a TCP connection to the given host and port, then returns
        a File struct with read and write access through the same interface
        as any other file (meaning writef and the byLine ranges work!).

        Authors:
                Adam D. Ruppe

        Bugs:
                Only works on Linux
*/
version(linux)
{
    File openNetwork(string host, ushort port)
    {
        static import sock = core.sys.posix.sys.socket;
        static import core.sys.posix.unistd;
        import core.stdc.string : memcpy;
        import core.sys.posix.arpa.inet : htons;
        import core.sys.posix.netdb : gethostbyname;
        import core.sys.posix.netinet.in_ : sockaddr_in;
        import std.conv : to;
        import std.exception : enforce;
        import std.internal.cstring : tempCString;

        auto h = enforce( gethostbyname(host.tempCString()),
            new StdioException("gethostbyname"));

        int s = sock.socket(sock.AF_INET, sock.SOCK_STREAM, 0);
        enforce(s != -1, new StdioException("socket"));

        scope(failure)
        {
            // want to make sure it doesn't dangle if something throws. Upon
            // normal exit, the File struct's reference counting takes care of
            // closing, so we don't need to worry about success
            core.sys.posix.unistd.close(s);
        }

        sockaddr_in addr;

        addr.sin_family = sock.AF_INET;
        addr.sin_port = htons(port);
        memcpy(&addr.sin_addr.s_addr, h.h_addr, h.h_length);

        enforce(sock.connect(s, cast(sock.sockaddr*) &addr, addr.sizeof) != -1,
            new StdioException("Connect failed"));

        File f;
        f.fdopen(s, "w+", host ~ ":" ~ to!string(port));
        return f;
    }
}

version(unittest) string testFilename(string file = __FILE__, size_t line = __LINE__) @safe pure
{
    import std.conv : text;
    import std.path : baseName;

    // Non-ASCII characters can't be used because of snn.lib @@@BUG8643@@@
    version(DIGITAL_MARS_STDIO)
        return text("deleteme-.", baseName(file), ".", line);
    else

        // filename intentionally contains non-ASCII (Russian) characters
        return text("deleteme-детка.", baseName(file), ".", line);
}
