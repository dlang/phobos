// Written in the D programming language.

/**
Standard I/O functions that extend $(B std.c.stdio).  $(B std.c.stdio)
is $(D_PARAM public)ally imported when importing $(B std.stdio).

Macros:
WIKI=Phobos/StdStdio

Copyright: Copyright Digital Mars 2007-.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu)
 */
module std.stdio;

public import core.stdc.stdio;
import std.stdiobase;
import core.memory, core.stdc.errno, core.stdc.stddef, core.stdc.stdlib,
    core.stdc.string, core.stdc.wchar_;
import std.algorithm, std.array, std.conv, std.exception, std.file, std.format,
    std.range, std.string, std.traits, std.typecons,
    std.typetuple, std.utf;

version (DigitalMars) version (Windows)
{
    // Specific to the way Digital Mars C does stdio
    version = DIGITAL_MARS_STDIO;
    import std.c.stdio : __fhnd_info, FHND_WCHAR, FHND_TEXT;
}

version (linux)
{
    // Specific to the way Gnu C does stdio
    version = GCC_IO;
    extern(C) FILE* fopen64(const char*, const char*);
}

version (OSX)
{
    version = GENERIC_IO;
    alias core.stdc.stdio.fopen fopen64;
}

version (FreeBSD)
{
    version = GENERIC_IO;
    alias core.stdc.stdio.fopen fopen64;
}

version(Windows)
{
    alias core.stdc.stdio.fopen fopen64;
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
        int _fputc_nlock(int, _iobuf*);
        int _fputwc_nlock(int, _iobuf*);
        int _fgetc_nlock(_iobuf*);
        int _fgetwc_nlock(_iobuf*);
        int __fp_lock(FILE*);
        void __fp_unlock(FILE*);

        int setmode(int, int);
    }
    alias _fputc_nlock FPUTC;
    alias _fputwc_nlock FPUTWC;
    alias _fgetc_nlock FGETC;
    alias _fgetwc_nlock FGETWC;

    alias __fp_lock FLOCK;
    alias __fp_unlock FUNLOCK;

    alias setmode _setmode;
    enum _O_BINARY = 0x8000;
    int _fileno(FILE* f) { return f._file; }
}
else version (GCC_IO)
{
    /* **
     * Gnu under-the-hood C I/O functions; see
     * http://www.gnu.org/software/libc/manual/html_node/I_002fO-on-Streams.html#I_002fO-on-Streams
     */
    //private import std.c.linux.linux;
    private import core.sys.posix.stdio;
    extern (C)
    {
        int fputc_unlocked(int, _iobuf*);
        int fputwc_unlocked(wchar_t, _iobuf*);
        int fgetc_unlocked(_iobuf*);
        int fgetwc_unlocked(_iobuf*);
        void flockfile(FILE*);
        void funlockfile(FILE*);
        ssize_t getline(char**, size_t*, FILE*);
        ssize_t getdelim (char**, size_t*, int, FILE*);

        private size_t fwrite_unlocked(const(void)* ptr,
                size_t size, size_t n, _iobuf *stream);
    }

    version (linux)
    {
        // declare fopen64 if not already
        static if (!is(typeof(fopen64)))
            extern (C) FILE* fopen64(in char*, in char*);
    }

    alias fputc_unlocked FPUTC;
    alias fputwc_unlocked FPUTWC;
    alias fgetc_unlocked FGETC;
    alias fgetwc_unlocked FGETWC;

    alias flockfile FLOCK;
    alias funlockfile FUNLOCK;
}
else version (GENERIC_IO)
{
    extern (C)
    {
        void flockfile(FILE*);
        void funlockfile(FILE*);
    }

    int fputc_unlocked(int c, _iobuf* fp) { return fputc(c, cast(shared) fp); }
    int fputwc_unlocked(wchar_t c, _iobuf* fp)
    {
        return fputwc(c, cast(shared) fp);
    }
    int fgetc_unlocked(_iobuf* fp) { return fgetc(cast(shared) fp); }
    int fgetwc_unlocked(_iobuf* fp) { return fgetwc(cast(shared) fp); }

    alias fputc_unlocked FPUTC;
    alias fputwc_unlocked FPUTWC;
    alias fgetc_unlocked FGETC;
    alias fgetwc_unlocked FGETWC;

    alias flockfile FLOCK;
    alias funlockfile FUNLOCK;
}
else
{
    static assert(0, "unsupported C I/O system");
}

//------------------------------------------------------------------------------
struct ByRecord(Fields...)
{
private:
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
        popFront; // prime the range
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
        enforce(file.isOpen);
        file.readln(line);
        if (!line.length)
        {
            file.detach;
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
    private struct Impl
    {
        FILE * handle = null;
        uint refs = uint.max / 2;
        string name = null;
        this(FILE* h, uint r, string n)
        {
            handle = h;
            refs = r;
            name = n;
        }
    }
    private Impl * p;

/**
Constructor taking the name of the file to open and the open mode
(with the same semantics as in the C standard library $(WEB
cplusplus.com/reference/clibrary/cstdio/fopen.html, fopen)
function). Throws an exception if the file could not be opened.

Copying one $(D File) object to another results in the two $(D File)
objects referring to the same underlying file.

The destructor automatically closes the file as soon as no $(D File)
object refers to it anymore.
 */
    this(string name, in char[] stdioOpenmode = "rb")
    {
        p = new Impl(errnoEnforce(.fopen(name, stdioOpenmode),
                        text("Cannot open file `", name, "' in mode `",
                                stdioOpenmode, "'")),
                1, name);
    }

    ~this()
    {
        if (!p) return;
        if (p.refs == 1) close;
        else --p.refs;
    }

    this(this)
    {
        if (!p) return;
        assert(p.refs);
        ++p.refs;
    }

/**
Assigns a file to another. The target of the assignment gets detached
from whatever file it was attached to, and attaches itself to the new
file.
 */
    void opAssign(File rhs)
    {
        swap(p, rhs.p);
    }

/**
First calls $(D detach) (throwing on failure), and then attempts to
_open file $(D name) with mode $(D stdioOpenmode). The mode has the
same semantics as in the C standard library $(WEB
cplusplus.com/reference/clibrary/cstdio/fopen.html, fopen) function.
Throws exception in case of error.
 */
    void open(string name, in char[] stdioOpenmode = "rb")
    {
        detach;
        auto another = File(name, stdioOpenmode);
        swap(this, another);
    }

/**
First calls $(D detach) (throwing on failure), and then runs a command
by calling the C standard library function $(WEB
opengroup.org/onlinepubs/007908799/xsh/_popen.html, _popen).
 */
    version(Posix) void popen(string command, in char[] stdioOpenmode = "r")
    {
        detach;
        p = new Impl(errnoEnforce(.popen(command, stdioOpenmode),
                        "Cannot run command `"~command~"'"),
                1, command);
    }

/** Returns $(D true) if the file is opened. */
    @property bool isOpen() const
    {
        return p !is null && p.handle;
    }

/**
Returns $(D true) if the file is at end (see $(WEB
cplusplus.com/reference/clibrary/cstdio/feof.html, feof)). The file
must be opened, otherwise an exception is thrown.
 */
    @property bool eof() const
    {
        enforce(p && p.handle, "Calling eof() against an unopened file.");
        return .feof(cast(FILE*) p.handle) != 0;
    }

/** Returns the name of the file, if any. */
    @property string name() const
    {
        return p.name;
    }

/**
If the file is not opened, returns $(D false). Otherwise, returns
$(WEB cplusplus.com/reference/clibrary/cstdio/ferror.html, ferror) for
the file handle.
 */
    @property bool error() const
    {
        return !p.handle || .ferror(cast(FILE*) p.handle);
    }

/**
Detaches from the underlying file. If the sole owner, calls $(D close)
and throws if that fails.
  */
    void detach()
    {
        if (!p) return;
        // @@@BUG
        //if (p.refs == 1) close;
        p = null;
    }

/**
If the file was unopened, succeeds vacuously. Otherwise closes the
file (by calling $(WEB
cplusplus.com/reference/clibrary/cstdio/fclose.html, fclose)),
throwing on error. Even if an exception is thrown, afterwards the $(D
File) object is empty. This is different from $(D detach) in that it
always closes the file; consequently, all other $(D File) objects
referring to the same handle will see a closed file henceforth.
 */
    void close()
    {
        if (!p) return; // succeed vacuously
        if (!p.handle)
        {
            p = null; // start a new life
            return;
        }
        scope(exit)
        {
            p.handle = null; // nullify the handle anyway
            p.name = null;
            --p.refs;
            p = null;
        }
        //fprintf(std.c.stdio.stderr, ("Closing file `"~name~"`.\n\0").ptr);
        errnoEnforce(.fclose(p.handle) == 0,
                    "Could not close file `"~p.name~"'");
    }

/**
If the file is not opened, succeeds vacuously. Otherwise, returns
$(WEB cplusplus.com/reference/clibrary/cstdio/_clearerr.html,
_clearerr) for the file handle.
 */
    void clearerr()
    {
        p is null || p.handle is null ||
        .clearerr(p.handle);
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/_fflush.html, _fflush) for the
file handle and throws on error.
 */
    void flush()
    {
        errnoEnforce
        (.fflush(enforce(p.handle, "Calling fflush() on an unopened file"))
                == 0);
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/fread.html, fread) for the
file handle and throws on error.

$(D rawRead) always read in binary mode on Windows.
 */
    T[] rawRead(T)(T[] buffer)
    {
        enforce(buffer.length, "rawRead must take a non-empty buffer");
        version(Windows)
        {
            immutable fd = ._fileno(p.handle);
            immutable mode = ._setmode(fd, _O_BINARY);
            scope(exit) ._setmode(fd, mode);
            version(DIGITAL_MARS_STDIO)
            {
                // @@@BUG@@@ 4243
                immutable info = __fhnd_info[fd];
                __fhnd_info[fd] &= ~FHND_TEXT;
                scope(exit) __fhnd_info[fd] = info;
            }
        }
        immutable result =
            .fread(buffer.ptr, T.sizeof, buffer.length, p.handle);
        errnoEnforce(!error);
        return result ? buffer[0 .. result] : null;
    }

    unittest
    {
        std.file.write("deleteme", "\r\n\n\r\n");
        scope(exit) std.file.remove("deleteme");
        auto f = File("deleteme", "r");
        auto buf = f.rawRead(new char[5]);
        f.close();
        assert(buf == "\r\n\n\r\n");
        /+
        buf = stdin.rawRead(new char[5]);
        assert(buf == "\r\n\n\r\n");
        +/
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/fwrite.html, fwrite) for the
file handle and throws on error.

$(D rawWrite) always write in binary mode on Windows.
 */
    void rawWrite(T)(in T[] buffer)
    {
        version(Windows)
        {
            flush(); // before changing translation mode
            immutable fd = ._fileno(p.handle);
            immutable mode = ._setmode(fd, _O_BINARY);
            scope(exit) ._setmode(fd, mode);
            version(DIGITAL_MARS_STDIO)
            {
                // @@@BUG@@@ 4243
                immutable info = __fhnd_info[fd];
                __fhnd_info[fd] &= ~FHND_TEXT;
                scope(exit) __fhnd_info[fd] = info;
            }
            scope(exit) flush(); // before restoring translation mode
        }
        auto result =
            .fwrite(buffer.ptr, T.sizeof, buffer.length, p.handle);
        if (result == result.max) result = 0;
        errnoEnforce(result == buffer.length,
                text("Wrote ", result, " instead of ", buffer.length,
                        " objects of type ", T.stringof, " to file `",
                        p.name, "'"));
    }

    unittest
    {
        auto f = File("deleteme", "w");
        scope(exit) std.file.remove("deleteme");
        f.rawWrite("\r\n\n\r\n");
        f.close();
        assert(std.file.read("deleteme") == "\r\n\n\r\n");
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/fseek.html, fseek) for the
file handle. Throws on error.
 */
    void seek(long offset, int origin = SEEK_SET)
    {
        enforce(p && p.handle,
                "Attempting to seek() in an unopened file");
        // @@@ Dubious: why is fseek in std.c.stdio taking an int???
        errnoEnforce(core.stdc.stdio.fseek(
                    p.handle, to!int(offset), origin) == 0,
                "Could not seek in file `"~p.name~"'");
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/ftell.html, ftell) for the
managed file handle. Throws on error.
 */
    ulong tell() const
    {
        enforce(p && p.handle,
                "Attempting to tell() in an unopened file");
        immutable result = .ftell(cast(FILE*) p.handle);
        errnoEnforce(result != -1,
                "Query ftell() failed for file `"~p.name~"'");
        return result;
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/_rewind.html, _rewind) for the
file handle. Throws on error.
 */
    void rewind()
    {
        enforce(isOpen, "Attempting to rewind() an unopened file");
        .rewind(p.handle);
    }

/**
If the file is not opened, throws an exception. Otherwise, calls $(WEB
cplusplus.com/reference/clibrary/cstdio/_setvbuf.html, _setvbuf) for
the file handle.
 */
    void setvbuf(size_t size, int mode = _IOFBF)
    {
        enforce(isOpen, "Attempting to call setvbuf() on an unopened file");
        errnoEnforce(.setvbuf(p.handle, null, mode, size) == 0,
                "Could not set buffering for file `"~p.name~"'");
    }

/**
If the file is not opened, throws an exception. Otherwise, calls
$(WEB cplusplus.com/reference/clibrary/cstdio/_setvbuf.html,
_setvbuf) for the file handle. */
    void setvbuf(void[] buf, int mode = _IOFBF)
    {
        enforce(isOpen, "Attempting to call setvbuf() on an unopened file");
        errnoEnforce(.setvbuf(p.handle,
                        cast(char*) buf.ptr, mode, buf.length) == 0,
                "Could not set buffering for file `"~p.name~"'");
    }

/**
If the file is not opened, throws an exception. Otherwise, writes its
arguments in text format to the file. */
    void write(S...)(S args)
    {
        auto w = lockingTextWriter();
        foreach (arg; args)
        {
            static if (isSomeString!(typeof(arg)))
            {
                w.put(arg);
            }
            else
            {
                std.format.formattedWrite(w, "%s", arg);
            }
        }
    }

/**
If the file is not opened, throws an exception. Otherwise, writes its
arguments in text format to the file, followed by a newline. */
    void writeln(S...)(S args)
    {
        write(args, '\n');
        errnoEnforce(.fflush(p.handle) == 0,
                    "Could not flush file `"~p.name~"'");
    }

    private enum errorMessage =
        "You must pass a formatting string as the first"
        " argument to writef or writefln. If no formatting is needed,"
        " you may want to use write or writeln.";

/**
If the file is not opened, throws an exception. Otherwise, writes its
arguments in text format to the file, according to the format in the
first argument. */
    void writef(S...)(S args)// if (isSomeString!(S[0]))
    {
        assert(p);
        assert(p.handle);
        static assert(isSomeString!(S[0]), errorMessage);
        auto w = lockingTextWriter;
        std.format.formattedWrite(w, args);
    }

/**
Same as writef, plus adds a newline. */
    void writefln(S...)(S args)
    {
        static assert(isSomeString!(S[0]), errorMessage);
        auto w = lockingTextWriter;
        std.format.formattedWrite(w, args);
        w.put('\n');
        .fflush(p.handle);
    }

/**********************************
Read line from stream $(D fp) and write it to $(D buf[]), including
terminating character.

This is often faster than $(D File.readln(dchar)) because the buffer
is reused each call. Note that reusing the buffer means that the
previous contents of it has to be copied if needed.

Params:
fp = input stream
buf = buffer used to store the resulting line data. buf is
resized as necessary.

Returns:
0 for end of file, otherwise number of characters read

Throws: $(D StdioException) on error

Example:
---
// Reads $(D stdin) and writes it to $(D stdout).
import std.stdio;

int main()
{
    char[] buf;
    while (stdin.readln(buf))
        write(buf);
    return 0;
}
---

This method is more efficient than the one in the previous example
because $(D stdin.readln(buf)) reuses (if possible) memory allocated
by $(D buf), whereas $(D buf = stdin.readln()) makes a new memory allocation
with every line.  */
    S readln(S = string)(dchar terminator = '\n')
    {
        Unqual!(typeof(S.init[0]))[] buf;
        readln(buf, terminator);
        return assumeUnique(buf);
    }

    unittest
    {
        std.file.write("deleteme", "hello\nworld\n");
        scope(exit) std.file.remove("deleteme");
        foreach (C; Tuple!(char, wchar, dchar).Types)
        {
            auto witness = [ "hello\n", "world\n" ];
            auto f = File("deleteme");
            uint i = 0;
            immutable(C)[] buf;
            while ((buf = f.readln!(typeof(buf))()).length)
            {
                assert(i < witness.length);
                assert(equal(buf, witness[i++]));
            }
            assert(i == witness.length);
        }
    }

/** ditto */
    size_t readln(C)(ref C[] buf, dchar terminator = '\n') if (isSomeChar!C)
    {
        static if (is(C == char))
        {
            enforce(p && p.handle, "Attempt to read from an unopened file.");
            return readlnImpl(p.handle, buf, terminator);
        }
        else
        {
            // TODO: optimize this
            string s = readln(terminator);
            if (!s.length) return 0;
            buf.length = 0;
            foreach (wchar c; s)
            {
                buf ~= c;
            }
            return buf.length;
        }
    }

/** ditto */
    size_t readln(C, R)(ref C[] buf, R terminator)
        if (isBidirectionalRange!R && is(typeof(terminator.front == buf[0])))
    {
        auto last = terminator.back();
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
        std.file.write("deleteme", "hello\n\rworld\nhow\n\rare ya");
        auto witness = [ "hello\n\r", "world\nhow\n\r", "are ya" ];
        scope(exit) std.file.remove("deleteme");
        auto f = File("deleteme");
        uint i = 0;
        char[] buf;
        while (f.readln(buf, "\n\r"))
        {
            assert(i < witness.length);
            assert(buf == witness[i++]);
        }
    }

    size_t readf(Data...)(in char[] format, Data data)
    {
        assert(isOpen);
        auto input = LockingTextReader(this);
        formattedRead(input, format, data);
        return 1;
    }

    unittest
    {
        std.file.write("deleteme", "hello\nworld\n");
        scope(exit) std.file.remove("deleteme");
        string s;
        auto f = File("deleteme");
        f.readf("%s\n", &s);
        assert(s == "hello", "["~s~"]");
    }

/**
 Returns a temporary file by calling $(WEB
 cplusplus.com/reference/clibrary/cstdio/_tmpfile.html, _tmpfile). */
    static File tmpfile()
    {
        auto h = errnoEnforce(core.stdc.stdio.tmpfile,
                "Could not create temporary file with tmpfile()");
        File result = void;
        result.p = new Impl(h, 1, null);
        return result;
    }

/**
Unsafe function that wraps an existing $(D FILE*). The resulting $(D
File) never takes the initiative in closing the file. */
    /*private*/ static File wrapFile(FILE* f)
    {
        File result = void;
        //result.p = new Impl(f, uint.max / 2, null);
        result.p = new Impl(f, 9999, null);
        return result;
    }

/**
Returns the $(D FILE*) corresponding to this object.
 */
    FILE* getFP()
    {
        enforce(p && p.handle,
                "Attempting to call getFP() on an unopened file");
        return p.handle;
    }

    unittest
    {
        assert(stdout.getFP == std.c.stdio.stdout);
    }

/**
Returns the file number corresponding to this object.
 */
    version(Posix) int fileno() const
    {
        enforce(p && p.handle,
                "Attempting to call fileno() on an unopened file");
        return core.stdc.stdio.fileno(cast(FILE*) p.handle);
    }

/**
Range that reads one line at a time. */
    enum KeepTerminator : bool { no, yes }
    /// ditto
    struct ByLine(Char, Terminator)
    {
        File file;
        Char[] line;
        Terminator terminator;
        KeepTerminator keepTerminator;

        this(File f, KeepTerminator kt = KeepTerminator.no,
                Terminator terminator = '\n')
        {
            file = f;
            this.terminator = terminator;
            keepTerminator = kt;
            popFront; // prime the range
            // @@@BUG@@@ line below should not exist
            //if (file.p) ++file.p.refs;
        }

        /// Range primitive implementations.
        bool empty() const
        {
            return !file.isOpen;
        }

        /// Ditto
        Char[] front()
        {
            return line;
        }

        /// Ditto
        void popFront()
        {
            enforce(file.isOpen);
            file.readln(line, terminator);
            if (!line.length)
                file.detach;
            else if (keepTerminator == KeepTerminator.no
                    && std.algorithm.endsWith(line, terminator))
                line.length = line.length - 1;
        }
    }

/**
Convenience function that returns the $(D LinesReader) corresponding
to this file. */
    ByLine!(Char, Terminator) byLine(Terminator = char, Char = char)
    (KeepTerminator keepTerminator = KeepTerminator.no,
            Terminator terminator = '\n')
    {
        return typeof(return)(this, keepTerminator, terminator);
    }

    unittest
    {
        //printf("Entering test at line %d\n", __LINE__);
        scope(failure) printf("Failed test at line %d\n", __LINE__);
        std.file.write("testingByLine", "asd\ndef\nasdf");
        auto witness = [ "asd", "def", "asdf" ];
        uint i;
        auto f = File("testingByLine");
        scope(exit)
        {
            f.close;
            assert(!f.isOpen);
            //std.file.remove("testingByLine");
        }
        foreach (line; f.byLine())
        {
            assert(line == witness[i++]);
        }
        assert(i == witness.length);
        i = 0;
        f.rewind;
        foreach (line; f.byLine(KeepTerminator.yes))
        {
            assert(line == witness[i++] ~ '\n' || i == witness.length);
        }
        assert(i == witness.length);
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
        // scope(failure) printf("Failed test at line %d\n", __LINE__);
        // std.file.write("deleteme", "1 2\n4 1\n5 100");
        // scope(exit) std.file.remove("deleteme");
        // File f = File("deleteme");
        // scope(exit) f.close;
        // auto t = [ tuple(1, 2), tuple(4, 1), tuple(5, 100) ];
        // uint i;
        // foreach (e; f.byRecord!(int, int)("%s %s"))
        // {
        //     //.writeln(e);
        //     assert(e == t[i++]);
        // }
    }

/**
Iterates through a file a chunk at a time by using $(D foreach).

Example:

---------
void main()
{
  foreach (ubyte[] buffer; stdin.byChunk(4096))
  {
    ... use buffer ...
  }
}
---------

The content of $(D buffer) is reused across calls. In the example
above, $(D buffer.length) is 4096 for all iterations, except for the
last one, in which case $(D buffer.length) may be less than 4096 (but
always greater than zero).

In case of an I/O error, an $(D StdioException) is thrown.
 */
    chunks byChunk(size_t chunkSize)
    {
        return chunks(this, chunkSize);
    }

/**
$(D Range) that locks the file and allows fast writing to it.
 */
    struct LockingTextWriter
    {
        //@@@ Hacky implementation due to bugs, see the correct
        //implementation at the end of this struct
        FILE* fps;          // the shared file handle
        _iobuf* handle;     // the unshared version of fps
        int orientation;

        this(ref File f)
        {
            enforce(f.p && f.p.handle);
            fps = f.p.handle;
            orientation = fwide(fps, 0);
            FLOCK(fps);
            handle = cast(_iobuf*)fps;
        }

        ~this()
        {
            FUNLOCK(fps);
            fps = null;
            handle = null;
        }

        /// Range primitive implementations.
        void put(A)(A writeme) if (is(ElementType!A : const(dchar)))
        {
            static if (isSomeString!A)
                alias typeof(writeme[0]) C;
            else
                alias ElementType!A C;
            static assert(!is(C == void));
            // writeln("typeof(A.init[0]) = ", typeof(A.init[0]),
            //         ", ElementType!A = ", ElementType!A);
            if (writeme[0].sizeof == 1 && orientation <= 0)
            {
                //file.write(writeme); causes infinite recursion!!!
                //file.rawWrite(writeme);
                auto result =
                    .fwrite(writeme.ptr, C.sizeof, writeme.length, fps);
                //if (result == result.max) result = 0;
                if (result != writeme.length) errnoEnforce(0);
            }
            else
            {
                // put each character in turn
                foreach (dchar c; writeme)
                {
                    put(c);
                }
            }
        }

        // @@@BUG@@@ 2340
        //void front(C)(C c) if (is(C : dchar)) {
        /// ditto
        void put(C)(C c) if (is(C : const(dchar)))
        {
            static if (c.sizeof == 1)
            {
                // simple char
                if (orientation <= 0) FPUTC(c, handle);
                else FPUTWC(c, handle);
            }
            else static if (c.sizeof == 2)
            {
                if (orientation <= 0)
                {
                    if (c <= 0x7F)
                    {
                        FPUTC(c, handle);
                    }
                    else
                    {
                        char[4] buf;
                        auto b = std.utf.toUTF8(buf, c);
                        foreach (i ; 0 .. b.length)
                            FPUTC(b[i], handle);
                    }
                }
                else
                {
                    FPUTWC(c, handle);
                }
            }
            else // 32-bit characters
            {
                if (orientation <= 0)
                {
                    if (c <= 0x7F)
                    {
                        FPUTC(c, handle);
                    }
                    else
                    {
                        char[4] buf = void;
                        auto b = std.utf.toUTF8(buf, c);
                        foreach (i ; 0 .. b.length)
                            FPUTC(b[i], handle);
                    }
                }
                else
                {
                    version (Windows)
                    {
                        assert(isValidDchar(c));
                        if (c <= 0xFFFF)
                        {
                            FPUTWC(c, handle);
                        }
                        else
                        {
                            FPUTWC(cast(wchar)
                                    ((((c - 0x10000) >> 10) & 0x3FF)
                                            + 0xD800), handle);
                            FPUTWC(cast(wchar)
                                    (((c - 0x10000) & 0x3FF) + 0xDC00),
                                    handle);
                        }
                    }
                    else version (Posix)
                    {
                        FPUTWC(c, handle);
                    }
                    else
                    {
                        static assert(0);
                    }
                }
            }
        }

        //@@@BUG correct implementation is below:

        // File file;
        // int orientation;

        // this(File f)
        // {
        //     enforce(f.isOpen);
        //     swap(file, f);
        //     // @@@BUG@@@ This line should NOT be there!
        //     file.p.refs++;
        //     orientation = fwide(file.p.handle, 0);
        //     //FLOCK(file.p.handle);
        // }

        // // @@@BUG@@@ uncomment and you get a linker error
        // // this(this)
        // // {
        // //     //FLOCK(file.p.handle);
        // // }

        // ~this()
        // {
        //     if (!file.p.handle) return;
        //     //FUNLOCK(file.p.handle);
        // }

        // void opAssign(LockingTextWriter rhs)
        // {
        //     swap(this, rhs);
        // }
    }

/// Convenience function.
    LockingTextWriter lockingTextWriter()
    {
        return LockingTextWriter(this);
    }
}

struct LockingTextReader
{
    private File _f;
    private dchar _crt;

    this(File f)
    {
        enforce(f.isOpen);
        _f = f;
        FLOCK(_f.p.handle);
    }

    this(this)
    {
        FLOCK(_f.p.handle);
    }

    ~this()
    {
        // File locking has its own reference count
        if (_f.isOpen) FUNLOCK(_f.p.handle);
    }

    void opAssign(LockingTextReader r)
    {
        swap(this, r);
    }

    @property bool empty()
    {
        if (!_f.isOpen || _f.eof) return true;
        if (_crt == _crt.init)
        {
            _crt = FGETC(cast(_iobuf*) _f.p.handle);
            if (_crt == -1)
            {
                clear(_f);
                return true;
            }
            else
            {
                enforce(ungetc(_crt, cast(FILE*) _f.p.handle) == _crt);
            }
        }
        return false;
    }

    dchar front()
    {
        enforce(!empty);
        return _crt;
    }

    void popFront()
    {
        enforce(!empty);
        if (FGETC(cast(_iobuf*) _f.p.handle) == -1)
        {
            enforce(_f.eof);
        }
        _crt = _crt.init;
    }

    // void unget(dchar c)
    // {
    //     ungetc(c, cast(FILE*) _f.p.handle);
    // }
}

unittest
{
    std.file.write("deleteme", "1 2 3");
    int x, y;
    auto f = File("deleteme");
    f.readf("%s ", &x);
    assert(x == 1);
    f.readf("%d ", &x);
    assert(x == 2);
    f.readf("%d ", &x);
    assert(x == 3);
    //pragma(msg, "--- todo: readf ---");
}

private
void writefx(FILE* fps, TypeInfo[] arguments, void* argptr, int newline=false)
{
    int orientation = fwide(fps, 0);    // move this inside the lock?

    /* Do the file stream locking at the outermost level
     * rather than character by character.
     */
    FLOCK(fps);
    scope(exit) FUNLOCK(fps);

    auto fp = cast(_iobuf*)fps;     // fp is locked version

    if (orientation <= 0)                // byte orientation or no orientation
    {
        void putc(dchar c)
        {
            if (c <= 0x7F)
            {
                FPUTC(c, fp);
            }
            else
            {
                char[4] buf = void;
                foreach (i; 0 .. std.utf.toUTF8(buf, c).length)
                    FPUTC(buf[i], fp);
            }
        }

        std.format.doFormat(&putc, arguments, argptr);
        if (newline)
            FPUTC('\n', fp);
    }
    else if (orientation > 0)                // wide orientation
    {
        version (Windows)
        {
            void putcw(dchar c)
            {
                assert(isValidDchar(c));
                if (c <= 0xFFFF)
                {
                    FPUTWC(c, fp);
                }
                else
                {
                    FPUTWC(cast(wchar) ((((c - 0x10000) >> 10) & 0x3FF) +
                                    0xD800), fp);
                    FPUTWC(cast(wchar) (((c - 0x10000) & 0x3FF) + 0xDC00), fp);
                }
            }
        }
        else version (Posix)
        {
            void putcw(dchar c)
            {
                FPUTWC(c, fp);
            }
        }
        else
        {
            static assert(0);
        }

        std.format.doFormat(&putcw, arguments, argptr);
        if (newline)
            FPUTWC('\n', fp);
    }
}

template isStreamingDevice(T)
{
    enum isStreamingDevice = is(T : FILE*) ||
        is(T : File);
}

/***********************************
For each argument $(D arg) in $(D args), format the argument (as per
$(LINK2 std_conv.html, to!(string)(arg))) and write the resulting
string to $(D args[0]). A call without any arguments will fail to
compile.

Throws: In case of an I/O error, throws an $(D StdioException).
 */
void write(T...)(T args) if (!is(T[0] : File))
{
    stdout.write(args);
}

unittest
{
    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    void[] buf;
    write(buf);
    // test write
    string file = "dmd-build-test.deleteme.txt";
    auto f = File(file, "w");
//    scope(exit) { std.file.remove(file); }
     f.write("Hello, ",  "world number ", 42, "!");
     f.close;
     assert(cast(char[]) std.file.read(file) == "Hello, world number 42!");
    // // test write on stdout
    //auto saveStdout = stdout;
    //scope(exit) stdout = saveStdout;
    //stdout.open(file, "w");
    Object obj;
    //write("Hello, ",  "world number ", 42, "! ", obj);
    //stdout.close;
    // auto result = cast(char[]) std.file.read(file);
    // assert(result == "Hello, world number 42! null", result);
}

/***********************************
 * Equivalent to $(D write(args, '\n')).  Calling $(D writeln) without
 * arguments is valid and just prints a newline to the standard
 * output.
 */
void writeln(T...)(T args) if (T.length == 0)
{
    enforce(fputc('\n', .stdout.p.handle) == '\n');
}

unittest
{
    // Just make sure the call compiles
    if (false) writeln();
}

/// ditto
void writeln(T...)(T args)
if (T.length == 1 && is(typeof(args[0]) : const(char)[]))
{
    enforce(fprintf(.stdout.p.handle, "%.*s\n",
                    cast(int) args[0].length, args[0].ptr) >= 0);
}

unittest
{
    if (false) writeln("wyda");
}

/// Ditto
void writeln(T...)(T args)
if (T.length > 1 || T.length == 1 && !is(typeof(args[0]) : const(char)[]))
{
    stdout.write(args, '\n');
}

unittest
{
        //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    // test writeln
    string file = "dmd-build-test.deleteme.txt";
    auto f = File(file, "w");
    scope(exit) { std.file.remove(file); }
    f.writeln("Hello, ",  "world number ", 42, "!");
    f.close;
    version (Windows)
        assert(cast(char[]) std.file.read(file) ==
                "Hello, world number 42!\r\n");
    else
        assert(cast(char[]) std.file.read(file) ==
                "Hello, world number 42!\n");
    // test writeln on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout.open(file, "w");
    writeln("Hello, ",  "world number ", 42, "!");
    stdout.close;
    version (Windows)
        assert(cast(char[]) std.file.read(file) ==
                "Hello, world number 42!\r\n");
    else
        assert(cast(char[]) std.file.read(file) ==
                "Hello, world number 42!\n");
}

/***********************************
 * If the first argument $(D args[0]) is a $(D FILE*), use
 * $(LINK2 std_format.html#format-string, the format specifier) in
 * $(D args[1]) to control the formatting of $(D
 * args[2..$]), and write the resulting string to $(D args[0]).
 * If $(D arg[0]) is not a $(D FILE*), the call is
 * equivalent to $(D writef(stdout, args)).
 *

IMPORTANT:

New behavior starting with D 2.006: unlike previous versions,
$(D writef) (and also $(D writefln)) only scans its first
string argument for format specifiers, but not subsequent string
arguments. This decision was made because the old behavior made it
unduly hard to simply print string variables that occasionally
embedded percent signs.

Also new starting with 2.006 is support for positional
parameters with
$(LINK2 http://opengroup.org/onlinepubs/009695399/functions/printf.html,
POSIX) syntax.

Example:

-------------------------
writef("Date: %2$s %1$s", "October", 5); // "Date: 5 October"
------------------------

The positional and non-positional styles can be mixed in the same
format string. (POSIX leaves this behavior undefined.) The internal
counter for non-positional parameters tracks the popFront parameter after
the largest positional parameter already used.

New starting with 2.008: raw format specifiers. Using the "%r"
specifier makes $(D writef) simply write the binary
representation of the argument. Use "%-r" to write numbers in little
endian format, "%+r" to write numbers in big endian format, and "%r"
to write numbers in platform-native format.

*/

void writef(T...)(T args)
{
    stdout.writef(args);
}

unittest
{
    //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    // test writef
    string file = "dmd-build-test.deleteme.txt";
    auto f = File(file, "w");
    scope(exit) { std.file.remove(file); }
    f.writef("Hello, %s world number %s!", "nice", 42);
    f.close;
    assert(cast(char[]) std.file.read(file) ==  "Hello, nice world number 42!");
    // test write on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout.open(file, "w");
    writef("Hello, %s world number %s!", "nice", 42);
    stdout.close;
    assert(cast(char[]) std.file.read(file) == "Hello, nice world number 42!");
}

/***********************************
 * Equivalent to $(D writef(args, '\n')).
 */
void writefln(T...)(T args)
{
    stdout.writefln(args);
}

unittest
{
        //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    // test writefln
    string file = "dmd-build-test.deleteme.txt";
    auto f = File(file, "w");
    scope(exit) { std.file.remove(file); }
    f.writefln("Hello, %s world number %s!", "nice", 42);
    f.close;
    version (Windows)
        assert(cast(char[]) std.file.read(file) ==
                "Hello, nice world number 42!\r\n");
    else
        assert(cast(char[]) std.file.read(file) ==
                "Hello, nice world number 42!\n",
                cast(char[]) std.file.read(file));
    // test write on stdout
    auto saveStdout = stdout;
    scope(exit) stdout = saveStdout;
    stdout.open(file, "w");
    assert(stdout.isOpen);
    writefln("Hello, %s world number %s!", "nice", 42);
    foreach (F ; TypeTuple!(ifloat, idouble, ireal))
    {
        F a = 5i;
        F b = a % 2;
        writeln(b);
    }
    stdout.close;
    auto read = cast(char[]) std.file.read(file);
    version (Windows)
        assert(read == "Hello, nice world number 42!\r\n1\r\n1\r\n1\r\n", read);
    else
        assert(read == "Hello, nice world number 42!\n1\n1\n1\n", "["~read~"]");
}

/**
 * Formatted read one line from stdin.
 */
void readf(A...)(in char[] format, A args)
{
    return stdin.readf(format, args);
}

unittest
{
    float f;
    if (false) readf("%s", &f);
}

/**********************************
 * Read line from stream $(D fp).
 * Returns:
 *        $(D null) for end of file,
 *        $(D char[]) for line read from $(D fp), including terminating character
 * Params:
 *        $(D fp) = input stream
 *        $(D terminator) = line terminator, '\n' by default
 * Throws:
 *        $(D StdioException) on error
 * Example:
 *        Reads $(D stdin) and writes it to $(D stdout).
---
import std.stdio;

int main()
{
    char[] buf;
    while ((buf = readln()) != null)
        write(buf);
    return 0;
}
---
*/
string readln(dchar terminator = '\n')
{
    return stdin.readln(terminator);
}

/** ditto */
size_t readln(ref char[] buf, dchar terminator = '\n')
{
    return stdin.readln(buf, terminator);
}

/*
 * Convenience function that forwards to $(D std.c.stdio.fopen)
 * with appropriately-constructed C-style strings.
 */
private FILE* fopen(in char[] name, in char[] mode = "r")
{
    const namez = toStringz(name), modez = toStringz(mode);
    return fopen64(namez, modez);
}

version (Posix)
{
    extern(C) FILE* popen(const char*, const char*);

/***********************************
 * Convenience function that forwards to $(D std.c.stdio.popen)
 * with appropriately-constructed C-style strings.
 */
    FILE* popen(in char[] name, in char[] mode = "r")
    {
        return popen(toStringz(name), toStringz(mode));
    }
}

/*
 * Convenience function that forwards to $(D std.c.stdio.fwrite)
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
 The line terminator ('\n' by default) is part of the string read (it
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
 */

struct lines
{
    private File f;
    private dchar terminator = '\n';
    // private string fileName;  // Curretly, no use

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
        alias ParameterTypeTuple!(dg) Parms;
        static if (isSomeString!(Parms[$ - 1]))
        {
            enum bool duplicate = is(Parms[$ - 1] == string)
                || is(Parms[$ - 1] == wstring) || is(Parms[$ - 1] == dstring);
            int result = 0;
            static if (is(Parms[$ - 1] : const(char)[]))
                alias char C;
            else static if (is(Parms[$ - 1] : const(wchar)[]))
                alias wchar C;
            else static if (is(Parms[$ - 1] : const(dchar)[]))
                alias dchar C;
            C[] line;
            static if (Parms.length == 2)
                Parms[0] i = 0;
            for (;;)
            {
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
        alias ParameterTypeTuple!(dg) Parms;
        enum duplicate = is(Parms[$ - 1] : immutable(ubyte)[]);
        int result = 1;
        int c = void;
        FLOCK(f.p.handle);
        scope(exit) FUNLOCK(f.p.handle);
        ubyte[] buffer;
        static if (Parms.length == 2)
            Parms[0] line = 0;
        while ((c = FGETC(cast(_iobuf*)f.p.handle)) != -1)
        {
            buffer ~= to!(ubyte)(c);
            if (c == terminator)
            {
                static if (duplicate)
                    auto arg = assumeUnique(buffer);
                else
                    alias buffer arg;
                // unlock the file while calling the delegate
                FUNLOCK(f.p.handle);
                scope(exit) FLOCK(f.p.handle);
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
        //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    string file = "dmd-build-test.deleteme.txt";
    scope(exit) { std.file.remove(file); }
    alias TypeTuple!(string, wstring, dstring,
                     char[], wchar[], dchar[])
        TestedWith;
    foreach (T; TestedWith) {
        // test looping with an empty file
        std.file.write(file, "");
        auto f = File(file, "r");
        foreach (T line; lines(f))
        {
            assert(false);
        }
        f.close;

        // test looping with a file with three lines
        std.file.write(file, "Line one\nline two\nline three\n");
        f.open(file, "r");
        uint i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(line == "Line one\n");
            else if (i == 1) assert(line == "line two\n");
            else if (i == 2) assert(line == "line three\n");
            else assert(false);
            ++i;
        }
        f.close;

        // test looping with a file with three lines, last without a newline
        std.file.write(file, "Line one\nline two\nline three");
        f.open(file, "r");
        i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(line == "Line one\n");
            else if (i == 1) assert(line == "line two\n");
            else if (i == 2) assert(line == "line three");
            else assert(false);
            ++i;
        }
        f.close;
    }

    // test with ubyte[] inputs
    //@@@BUG 2612@@@
    //alias TypeTuple!(immutable(ubyte)[], ubyte[]) TestedWith2;
    alias TypeTuple!(immutable(ubyte)[], ubyte[]) TestedWith2;
    foreach (T; TestedWith2) {
        // test looping with an empty file
        std.file.write(file, "");
        auto f = File(file, "r");
        foreach (T line; lines(f))
        {
            assert(false);
        }
        f.close;

        // test looping with a file with three lines
        std.file.write(file, "Line one\nline two\nline three\n");
        f.open(file, "r");
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
        f.close;

        // test looping with a file with three lines, last without a newline
        std.file.write(file, "Line one\nline two\nline three");
        f.open(file, "r");
        i = 0;
        foreach (T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n");
            else if (i == 2) assert(cast(char[]) line == "line three");
            else assert(false);
            ++i;
        }
        f.close;

    }

    foreach (T; TypeTuple!(ubyte[]))
    {
        // test looping with a file with three lines, last without a newline
        // using a counter too this time
        std.file.write(file, "Line one\nline two\nline three");
        auto f = File(file, "r");
        uint i = 0;
        foreach (ulong j, T line; lines(f))
        {
            if (i == 0) assert(cast(char[]) line == "Line one\n");
            else if (i == 1) assert(cast(char[]) line == "line two\n");
            else if (i == 2) assert(cast(char[]) line == "line three");
            else assert(false);
            ++i;
        }
        f.close;
    }
}

/**
Iterates through a file a chunk at a time by using $(D
foreach).

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

struct chunks
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
        const maxStackSize = 1024 * 16;
        ubyte[] buffer = void;
        if (size < maxStackSize)
            buffer = (cast(ubyte*) alloca(size))[0 .. size];
        else
            buffer = new ubyte[size];
        size_t r = void;
        int result = 1;
        uint tally = 0;
        while ((r = core.stdc.stdio.fread(buffer.ptr,
                                buffer[0].sizeof, size, f.p.handle)) > 0)
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
        //printf("Entering test at line %d\n", __LINE__);
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    string file = "dmd-build-test.deleteme.txt";
    scope(exit) { std.file.remove(file); }
    // test looping with an empty file
    std.file.write(file, "");
    auto f = File(file, "r");
    foreach (ubyte[] line; chunks(f, 4))
    {
        assert(false);
    }
    f.close;

    // test looping with a file with three lines
    std.file.write(file, "Line one\nline two\nline three\n");
    f = File(file, "r");
    uint i = 0;
    foreach (ubyte[] line; chunks(f, 3))
    {
        if (i == 0) assert(cast(char[]) line == "Lin");
        else if (i == 1) assert(cast(char[]) line == "e o");
        else if (i == 2) assert(cast(char[]) line == "ne\n");
        else break;
        ++i;
    }
    f.close;
}

/*********************
 * Thrown if I/O errors happen.
 */
class StdioException : Exception
{
    /// Operating system error code.
    uint errno;

/**
Initialize with a message and an error code. */
    this(string message, uint e = .getErrno)
    {
        errno = e;
        version (Posix)
        {
            char[256] buf = void;
            version (linux)
            {
                auto s = std.c.string.strerror_r(errno, buf.ptr, buf.length);
            }
            else
            {
                std.c.string.strerror_r(errno, buf.ptr, buf.length);
                auto s = buf.ptr;
            }
        }
        else
        {
            auto s = std.c.string.strerror(errno);
        }
        auto sysmsg = to!string(s);
        super(message ? message ~ "(" ~ sysmsg ~ ")" : sysmsg);
    }

/** Convenience functions that throw an $(D StdioException). */
    static void opCall(string msg)
    {
        throw new StdioException(msg);
    }

/// ditto
    static void opCall()
    {
        throw new StdioException(null, .getErrno);
    }
}

extern(C) void std_stdio_static_this()
{
    //Bind stdin, stdout, stderr
    __gshared File.Impl stdinImpl;
    stdinImpl.handle = core.stdc.stdio.stdin;
    .stdin.p = &stdinImpl;
    // stdout
    __gshared File.Impl stdoutImpl;
    stdoutImpl.handle = core.stdc.stdio.stdout;
    .stdout.p = &stdoutImpl;
    // stderr
    __gshared File.Impl stderrImpl;
    stderrImpl.handle = core.stdc.stdio.stderr;
    .stderr.p = &stderrImpl;
}

//---------
__gshared
{
    File stdin;
    File stdout;
    File stderr;
}

unittest
{
    scope(failure) printf("Failed test at line %d\n", __LINE__);
    std.file.write("deleteme", "1 2\n4 1\n5 100");
    scope(exit) std.file.remove("deleteme");
    {
        File f = File("deleteme");
        scope(exit) f.close;
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
        auto app = appender(&buf);
        buf.length = 0;
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
                std.utf.encode(buf, c);
            }
        }
        if (ferror(fps))
            StdioException();
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
        if(buf.ptr is null)
        {
            sz = 128;
            auto p = cast(char*) GC.malloc(sz, GC.BlkAttr.NO_SCAN);
            buf = p[0 .. 0];
        } else {
            buf.length = 0;
        }

        auto app = appender(&buf);
        int c;
        while((c = FGETC(fp)) != -1) {
            app.put(cast(char) c);
            if(buf[$ - 1] == terminator) {
                return buf.length;
            }

        }

        if (ferror(fps))
            StdioException();
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
                buf = cast(char[])GC.malloc(i, GC.BlkAttr.NO_SCAN)[0 .. i];
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
                buf = cast(char[])GC.malloc(i, GC.BlkAttr.NO_SCAN)[0 .. i];
            }
            memcpy(buf.ptr, p, i);
            buf = buf[0 .. i];
        }
        fp._cnt -= i;
        fp._ptr += i;
        return i;
    }
}

version (GCC_IO)
private size_t readlnImpl(FILE* fps, ref char[] buf, dchar terminator = '\n')
{
    if (fwide(fps, 0) > 0)
    {   /* Stream is in wide characters.
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
    FLOCK(fps);
    scope(exit) FUNLOCK(fps);
    auto fp = cast(_iobuf*)fps;
    if (fwide(fps, 0) > 0)
    {   /* Stream is in wide characters.
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
    buf.length = 0;
    for (int c; (c = FGETC(fp)) != -1; )
    {
        buf ~= cast(char)c;
        if (c == terminator)
            break;
    }
    if (ferror(fps))
        StdioException();
    return buf.length;
}
