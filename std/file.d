// Written in the D programming language.

/**
Utilities for manipulating files and scanning directories. Functions
in this module handle files as a unit, e.g., read or write one _file
at a time. For opening files and manipulating them via handles refer
to module $(D $(LINK2 std_stdio.html,std.stdio)).

Macros:
WIKI = Phobos/StdFile

Copyright: Copyright Digital Mars 2007 - 2011.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           Jonathan M Davis
Source:    $(PHOBOSSRC std/_file.d)
 */
module std.file;

import core.memory;
import core.stdc.stdio, core.stdc.stdlib, core.stdc.string,
       core.stdc.errno, std.algorithm, std.array, std.conv,
       std.datetime, std.exception, std.format, std.path, std.process,
       std.range, std.stdio, std.string, std.traits,
       std.typecons, std.typetuple, std.utf;

import std.metastrings; //For generating deprecation messages only. Remove once
                        //deprecation path complete.

version (Win32)
{
    import core.sys.windows.windows, std.windows.charset,
        std.windows.syserror, std.__fileinit : useWfuncs;
/*
 * Since Win 9x does not support the "W" API's, first convert
 * to wchar, then convert to multibyte using the current code
 * page.
 * (Thanks to yaneurao for this)
 */
    version(Windows) alias std.windows.charset.toMBSz toMBSz;
}
else version (Posix)
{
    import core.sys.posix.dirent, core.sys.posix.fcntl, core.sys.posix.sys.stat,
        core.sys.posix.sys.time, core.sys.posix.unistd, core.sys.posix.utime;
}
else
    static assert(false, "Module " ~ .stringof ~ " not implemented for this OS.");

version (unittest)
{
    import core.thread : Thread;

    private string deleteme()
    {
        static _deleteme = "deleteme.dmd.unittest";
        static _first = true;

        if(_first)
        {
            version(Windows)
                _deleteme = buildPath(std.process.getenv("TEMP"), _deleteme);
            else version(Posix)
                _deleteme = "/tmp/" ~ _deleteme;

            _first = false;
        }


        return _deleteme;
    }
}


// @@@@ TEMPORARY - THIS SHOULD BE IN THE CORE @@@
// {{{
version (Windows)
{
    enum FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
}
else version (Posix)
{
    version (OSX)
    {
        struct struct_stat64        // distinguish it from the stat() function
        {
            uint st_dev;        /// device
            ushort st_mode;
            ushort st_nlink;        /// link count
            ulong st_ino;        /// file serial number
            uint st_uid;        /// user ID of file's owner
            uint st_gid;        /// user ID of group's owner
            uint st_rdev;        /// if device then device number

            int st_atime;
            uint st_atimensec;
            int st_mtime;
            uint st_mtimensec;
            int st_ctime;
            uint st_ctimensec;
            int st_birthtime;
            uint st_birthtimensec;

            ulong st_size;
            long st_blocks;        /// number of allocated 512 byte blocks
            int st_blksize;        /// optimal I/O block size

            ulong st_ino64;
            uint st_flags;
            uint st_gen;
            int st_lspare; /* RESERVED: DO NOT USE! */
            long st_qspare[2]; /* RESERVED: DO NOT USE! */
        }

        extern(C) int fstat64(int, struct_stat64*);
        extern(C) int stat64(in char*, struct_stat64*);
        extern(C) int lstat64(in char*, struct_stat64*);
    }
    else version (FreeBSD)
    {
        alias core.sys.posix.sys.stat.stat_t struct_stat64;
        alias core.sys.posix.sys.stat.fstat  fstat64;
        alias core.sys.posix.sys.stat.stat   stat64;
        alias core.sys.posix.sys.stat.lstat  lstat64;
    }
    else
    {
        version(X86)
        {
            struct struct_stat64        // distinguish it from the stat() function
            {
                ulong st_dev;        /// device
                uint __pad1;
                uint st_ino;        /// file serial number
                uint st_mode;        /// file mode
                uint st_nlink;        /// link count
                uint st_uid;        /// user ID of file's owner
                uint st_gid;        /// user ID of group's owner
                ulong st_rdev;        /// if device then device number
                uint __pad2;
                align(4) ulong st_size;
                int st_blksize;        /// optimal I/O block size
                ulong st_blocks;        /// number of allocated 512 byte blocks
                int st_atime;
                uint st_atimensec;
                int st_mtime;
                uint st_mtimensec;
                int st_ctime;
                uint st_ctimensec;

                ulong st_ino64;
            }
            //static assert(struct_stat64.sizeof == 88); // copied from d1, but it's currently 96 bytes, not 88.
        }
        else version (X86_64)
        {
            struct struct_stat64
            {
                ulong st_dev;
                ulong st_ino;
                ulong st_nlink;
                uint  st_mode;
                uint  st_uid;
                uint  st_gid;
                int   __pad0;
                ulong st_rdev;
                long  st_size;
                long  st_blksize;
                long  st_blocks;
                long  st_atime;
                ulong st_atimensec;
                long  st_mtime;
                ulong st_mtimensec;
                long  st_ctime;
                ulong st_ctimensec;
                long[3]  __unused;
            }
            static assert(struct_stat64.sizeof == 144);
        }

        extern(C) int fstat64(int, struct_stat64*);
        extern(C) int stat64(in char*, struct_stat64*);
        extern(C) int lstat64(in char*, struct_stat64*);
    }
}
// }}}


/++
    Exception thrown for file I/O errors.
 +/
class FileException : Exception
{
    /++
        OS error code.
     +/
    immutable uint errno;

    /++
        Constructor which takes an error message.

        Params:
            name = Name of file for which the error occurred.
            msg  = Message describing the error.
            file = The file where the error occurred.
            line = The line where the error occurred.
     +/
    this(in char[] name, in char[] msg, string file = __FILE__, size_t line = __LINE__)
    {
        if(msg.empty)
            super(name.idup, file, line);
        else
            super(text(name, ": ", msg), file, line);

        errno = 0;
    }

    /++
        Constructor which takes the error number ($(LUCKY GetLastError)
        in Windows, $(D_PARAM getErrno) in Posix).

        Params:
            name = Name of file for which the error occurred.
            msg  = Message describing the error.
            file = The file where the error occurred.
            line = The line where the error occurred.
     +/
    version(Windows) this(in char[] name,
                          uint errno = GetLastError,
                          string file = __FILE__,
                          size_t line = __LINE__)
    {
        this(name, sysErrorString(errno), file, line);
        this.errno = errno;
    }

    /++
        Constructor which takes the error number ($(LUCKY GetLastError)
        in Windows, $(D_PARAM getErrno) in Posix).

        Params:
            name = Name of file for which the error occurred.
            msg  = Message describing the error.
            file = The file where the error occurred.
            line = The line where the error occurred.
     +/
    version(Posix) this(in char[] name,
                        uint errno = .getErrno,
                        string file = __FILE__,
                        size_t line = __LINE__)
    {
        auto s = strerror(errno);
        this(name, to!string(s), file, line);
        this.errno = errno;
    }
}

private T cenforce(T)(T condition, lazy const(char)[] name, string file = __FILE__, size_t line = __LINE__)
{
    if (!condition)
    {
      version (Windows)
      {
        throw new FileException(name, .GetLastError(), file, line);
      }
      else version (Posix)
      {
        throw new FileException(name, .getErrno(), file, line);
      }
    }
    return condition;
}

/* **********************************
 * Basic File operations.
 */

/********************************************
Read entire contents of file $(D name) and returns it as an untyped
array. If the file size is larger than $(D upTo), only $(D upTo)
bytes are read.

Example:

----
import std.file, std.stdio;
void main()
{
   auto bytes = cast(ubyte[]) read("filename", 5);
   if (bytes.length == 5)
       writefln("The fifth byte of the file is 0x%x", bytes[4]);
}
----

Returns: Untyped array of bytes _read.

Throws: $(D FileException) on error.
 */
void[] read(in char[] name, size_t upTo = size_t.max)
{
    version(Windows)
    {
        alias TypeTuple!(GENERIC_READ,
                FILE_SHARE_READ, (SECURITY_ATTRIBUTES*).init, OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
                HANDLE.init)
            defaults;
        auto h = useWfuncs
            ? CreateFileW(std.utf.toUTF16z(name), defaults)
            : CreateFileA(toMBSz(name), defaults);

        cenforce(h != INVALID_HANDLE_VALUE, name);
        scope(exit) cenforce(CloseHandle(h), name);
        auto size = GetFileSize(h, null);
        cenforce(size != INVALID_FILE_SIZE, name);
        size = min(upTo, size);
        auto buf = uninitializedArray!(ubyte[])(size);
        scope(failure) delete buf;

        DWORD numread = void;
        cenforce(ReadFile(h,buf.ptr, size, &numread, null) == 1
                && numread == size, name);
        return buf[0 .. size];
    }
    else version(Posix)
    {
        // A few internal configuration parameters {
        enum size_t
            minInitialAlloc = 1024 * 4,
            maxInitialAlloc = size_t.max / 2,
            sizeIncrement = 1024 * 16,
            maxSlackMemoryAllowed = 1024;
        // }

        immutable fd = core.sys.posix.fcntl.open(toStringz(name),
                core.sys.posix.fcntl.O_RDONLY);
        cenforce(fd != -1, name);
        scope(exit) core.sys.posix.unistd.close(fd);

        struct_stat64 statbuf = void;
        cenforce(fstat64(fd, &statbuf) == 0, name);
        //cenforce(core.sys.posix.sys.stat.fstat(fd, &statbuf) == 0, name);

        immutable initialAlloc = to!size_t(statbuf.st_size
            ? min(statbuf.st_size + 1, maxInitialAlloc)
            : minInitialAlloc);
        void[] result = uninitializedArray!(ubyte[])(initialAlloc);
        scope(failure) delete result;
        size_t size = 0;

        for (;;)
        {
            immutable actual = core.sys.posix.unistd.read(fd, result.ptr + size,
                    min(result.length, upTo) - size);
            cenforce(actual != -1, name);
            if (actual == 0) break;
            size += actual;
            if (size < result.length) continue;
            immutable newAlloc = size + sizeIncrement;
            result = GC.realloc(result.ptr, newAlloc, GC.BlkAttr.NO_SCAN)
                [0 .. newAlloc];
        }

        return result.length - size >= maxSlackMemoryAllowed
            ? GC.realloc(result.ptr, size, GC.BlkAttr.NO_SCAN)[0 .. size]
            : result[0 .. size];
    }
}

unittest
{
    write(deleteme, "1234");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    assert(read(deleteme, 2) == "12");
    assert(read(deleteme) == "1234");
}

version (linux) unittest
{
    // A file with "zero" length that doesn't have 0 length at all
    auto s = std.file.readText("/proc/sys/kernel/osrelease");
    assert(s.length > 0);
    //writefln("'%s'", s);
}

/********************************************
Read and validates (using $(XREF utf, validate)) a text file. $(D S)
can be a type of array of characters of any width and constancy. No
width conversion is performed; if the width of the characters in file
$(D name) is different from the width of elements of $(D S),
validation will fail.

Returns: Array of characters read.

Throws: $(D FileException) on file error, $(D UTFException) on UTF
decoding error.

Example:

----
enforce(system("echo abc>deleteme") == 0);
scope(exit) remove("deleteme");
enforce(chomp(readText("deleteme")) == "abc");
----
 */

S readText(S = string)(in char[] name)
{
    auto result = cast(S) read(name);
    std.utf.validate(result);
    return result;
}

unittest
{
    write(deleteme, "abc\n");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    enforce(chomp(readText(deleteme)) == "abc");
}

/*********************************************
Write $(D buffer) to file $(D name).
Throws: $(D FileException) on error.

Example:

----
import std.file;
void main()
{
   int[] a = [ 0, 1, 1, 2, 3, 5, 8 ];
   write("filename", a);
   assert(cast(int[]) read("filename") == a);
}
----
 */
void write(in char[] name, const void[] buffer)
{
    version(Windows)
    {
        alias TypeTuple!(GENERIC_WRITE, 0, null, CREATE_ALWAYS,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
                HANDLE.init)
            defaults;
        auto h = useWfuncs
            ? CreateFileW(std.utf.toUTF16z(name), defaults)
            : CreateFileA(toMBSz(name), defaults);

        cenforce(h != INVALID_HANDLE_VALUE, name);
        scope(exit) cenforce(CloseHandle(h), name);
        DWORD numwritten;
        cenforce(WriteFile(h, buffer.ptr, to!DWORD(buffer.length), &numwritten, null) == 1
                && buffer.length == numwritten,
                name);
    }
    else version(Posix)
        return writeImpl(name, buffer, O_CREAT | O_WRONLY | O_TRUNC);
}

/*********************************************
Appends $(D buffer) to file $(D name).
Throws: $(D FileException) on error.

Example:

----
import std.file;
void main()
{
   int[] a = [ 0, 1, 1, 2, 3, 5, 8 ];
   write("filename", a);
   int[] b = [ 13, 21 ];
   append("filename", b);
   assert(cast(int[]) read("filename") == a ~ b);
}
----
 */
void append(in char[] name, in void[] buffer)
{
    version(Windows)
    {
        alias TypeTuple!(GENERIC_WRITE,0,null,OPEN_ALWAYS,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,HANDLE.init)
            defaults;

        auto h = useWfuncs
            ? CreateFileW(std.utf.toUTF16z(name), defaults)
            : CreateFileA(toMBSz(name), defaults);

        cenforce(h != INVALID_HANDLE_VALUE, name);
        scope(exit) cenforce(CloseHandle(h), name);
        DWORD numwritten;
        cenforce(SetFilePointer(h, 0, null, FILE_END) != INVALID_SET_FILE_POINTER
                && WriteFile(h,buffer.ptr,to!DWORD(buffer.length),&numwritten,null) == 1
                && buffer.length == numwritten,
                name);
    }
    else version(Posix)
        return writeImpl(name, buffer, O_APPEND | O_WRONLY | O_CREAT);
}

// Posix implementation helper for write and append

version(Posix) private void writeImpl(in char[] name,
        in void[] buffer, in uint mode)
{
    immutable fd = core.sys.posix.fcntl.open(toStringz(name),
            mode, octal!666);
    cenforce(fd != -1, name);
    {
        scope(failure) core.sys.posix.unistd.close(fd);
        immutable size = buffer.length;
        cenforce(
            core.sys.posix.unistd.write(fd, buffer.ptr, size) == size,
            name);
    }
    cenforce(core.sys.posix.unistd.close(fd) == 0, name);
}

/***************************************************
 * Rename file $(D from) to $(D to).
 * Throws: $(D FileException) on error.
 */
void rename(in char[] from, in char[] to)
{
    version(Windows)
    {
        enforce(useWfuncs
                ? MoveFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to))
                : MoveFileA(toMBSz(from), toMBSz(to)),
                new FileException(
                    text("Attempting to rename file ", from, " to ",
                            to)));
    }
    else version(Posix)
        cenforce(std.c.stdio.rename(toStringz(from), toStringz(to)) == 0, to);
}

/***************************************************
Delete file $(D name).
Throws: $(D FileException) on error.
 */
void remove(in char[] name)
{
    version(Windows)
    {
        cenforce(useWfuncs
                ? DeleteFileW(std.utf.toUTF16z(name))
                : DeleteFileA(toMBSz(name)),
                name);
    }
    else version(Posix)
        cenforce(std.c.stdio.remove(toStringz(name)) == 0,
            "Failed to remove file " ~ name);
}

/***************************************************
Get size of file $(D name) in bytes.

Throws: $(D FileException) on error (e.g., file not found).
 */
ulong getSize(in char[] name)
{
    version(Windows)
    {
        HANDLE findhndl = void;
        uint resulth = void;
        uint resultl = void;
        const (char)[] file = name[];

        //FindFirstFileX can't handle file names which end in a backslash.
        if(file.endsWith(sep))
            file.popBackN(sep.length);

        if (useWfuncs)
        {
            WIN32_FIND_DATAW filefindbuf;

            findhndl = FindFirstFileW(std.utf.toUTF16z(file), &filefindbuf);
            resulth = filefindbuf.nFileSizeHigh;
            resultl = filefindbuf.nFileSizeLow;
        }
        else
        {
            WIN32_FIND_DATA filefindbuf;

            findhndl = FindFirstFileA(toMBSz(file), &filefindbuf);
            resulth = filefindbuf.nFileSizeHigh;
            resultl = filefindbuf.nFileSizeLow;
        }

        cenforce(findhndl != cast(HANDLE)-1 && FindClose(findhndl), file);
        return (cast(ulong) resulth << 32) + resultl;
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;
        cenforce(stat64(toStringz(name), &statbuf) == 0, name);
        return statbuf.st_size;
    }
}

unittest
{
    // create a file of size 1
    write(deleteme, "a");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    assert(getSize(deleteme) == 1);
    // create a file of size 3
    write(deleteme, "abc");
    assert(getSize(deleteme) == 3);
}

/*************************
 * $(RED Deprecated. It will be removed in February 2012. Please use either the
 *       version of $(D getTimes) which takes two arguments or $(D getTimesWin)
 *       (Windows-Only) instead.)
 */
version(StdDdoc) deprecated void getTimes(in char[] name,
                                          out d_time ftc,
                                          out d_time fta,
                                          out d_time ftm);
else version(Windows) deprecated void getTimes(C)(in C[] name,
                                                  out d_time ftc,
                                                  out d_time fta,
                                                  out d_time ftm) if(is(Unqual!C == char))
{
    pragma(msg, "Notice: As of Phobos 2.055, the version of std.file.getTimes " ~
                "with 3 arguments has been deprecated. It will be removed in " ~
                "February 2012. Please use either the version of getTimes with " ~
                "two arguments or getTimesWin (Windows-Only) instead.");

    HANDLE findhndl = void;

    if (useWfuncs)
    {
        WIN32_FIND_DATAW filefindbuf;

        findhndl = FindFirstFileW(std.utf.toUTF16z(name), &filefindbuf);
        ftc = FILETIME2d_time(&filefindbuf.ftCreationTime);
        fta = FILETIME2d_time(&filefindbuf.ftLastAccessTime);
        ftm = FILETIME2d_time(&filefindbuf.ftLastWriteTime);
    }
    else
    {
        WIN32_FIND_DATA filefindbuf;

        findhndl = FindFirstFileA(toMBSz(name), &filefindbuf);
        ftc = FILETIME2d_time(&filefindbuf.ftCreationTime);
        fta = FILETIME2d_time(&filefindbuf.ftLastAccessTime);
        ftm = FILETIME2d_time(&filefindbuf.ftLastWriteTime);
    }

    if (findhndl == cast(HANDLE)-1)
    {
        throw new FileException(name.idup);
    }
    FindClose(findhndl);
}
else version(Posix) deprecated void getTimes(C)(in C[] name,
                                                out d_time ftc,
                                                out d_time fta,
                                                out d_time ftm) if(is(Unqual!C == char))
{
    pragma(msg, "Notice: As of Phobos 2.055, the version of std.file.getTimes " ~
                "with 3 arguments has been deprecated. It will be removed in " ~
                "February 2012. Please use either the version of getTimes with " ~
                "two arguments or getTimesWin (Windows-Only) instead.");

    struct_stat64 statbuf = void;
    cenforce(stat64(toStringz(name), &statbuf) == 0, name);
    ftc = cast(d_time) statbuf.st_ctime * ticksPerSecond;
    fta = cast(d_time) statbuf.st_atime * ticksPerSecond;
    ftm = cast(d_time) statbuf.st_mtime * ticksPerSecond;
}


/++
    Get the access and modified times of file $(D name).

    Params:
        name                 = File name to get times for.
        fileAccessTime       = Time the file was last accessed.
        fileModificationTime = Time the file was last modified.

    Throws:
        $(D FileException) on error.
 +/
version(StdDdoc) void getTimes(in char[] name,
                               out SysTime fileAccessTime,
                               out SysTime fileModificationTime);
//Oh, how it would be nice of you could overload templated functions with
//non-templated functions. Untemplatize this when the old getTimes goes away.
else void getTimes(C)(in C[] name,
                      out SysTime fileAccessTime,
                      out SysTime fileModificationTime)
    if(is(Unqual!C == char))
{
    version(Windows)
    {
        HANDLE findhndl = void;

        if(useWfuncs)
        {
            WIN32_FIND_DATAW filefindbuf;

            findhndl = FindFirstFileW(std.utf.toUTF16z(name), &filefindbuf);
            fileAccessTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastAccessTime);
            fileModificationTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastWriteTime);
        }
        else
        {
            WIN32_FIND_DATA filefindbuf;

            findhndl = FindFirstFileA(toMBSz(name), &filefindbuf);
            fileAccessTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastAccessTime);
            fileModificationTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastWriteTime);
        }

        enforce(findhndl != cast(HANDLE)-1, new FileException(name.idup));

        FindClose(findhndl);
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;

        cenforce(stat64(toStringz(name), &statbuf) == 0, name);

        fileAccessTime = SysTime(unixTimeToStdTime(statbuf.st_atime));
        fileModificationTime = SysTime(unixTimeToStdTime(statbuf.st_mtime));
    }
}

unittest
{
    auto currTime = Clock.currTime();

    write(deleteme, "a");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }

    SysTime accessTime1 = void;
    SysTime modificationTime1 = void;

    getTimes(deleteme, accessTime1, modificationTime1);

    enum leeway = dur!"seconds"(2);

    {
        auto diffa = accessTime1 - currTime;
        auto diffm = modificationTime1 - currTime;
        scope(failure) writefln("[%s] [%s] [%s] [%s] [%s]", accessTime1, modificationTime1, currTime, diffa, diffm);

        assert(abs(diffa) <= leeway);
        assert(abs(diffm) <= leeway);
    }

    enum sleepTime = dur!"seconds"(2);
    Thread.sleep(sleepTime);

    currTime = Clock.currTime();
    write(deleteme, "b");

    SysTime accessTime2 = void;
    SysTime modificationTime2 = void;

    getTimes(deleteme, accessTime2, modificationTime2);

    {
        auto diffa = accessTime2 - currTime;
        auto diffm = modificationTime2 - currTime;
        scope(failure) writefln("[%s] [%s] [%s] [%s] [%s]", accessTime2, modificationTime2, currTime, diffa, diffm);

        //There is no guarantee that the access time will be updated.
        assert(abs(diffa) <= leeway + sleepTime);
        assert(abs(diffm) <= leeway);
    }

    assert(accessTime1 <= accessTime2);
    assert(modificationTime1 <= modificationTime2);
}


/++
    $(BLUE This function is Windows-Only.)

    Get creation/access/modified times of file $(D name).

    This is the same as $(D getTimes) except that it also gives you the file
    creation time - which isn't possible on Posix systems.

    Params:
        name                 = File name to get times for.
        fileCreationTime     = Time the file was created.
        fileAccessTime       = Time the file was last accessed.
        fileModificationTime = Time the file was last modified.

    Throws:
        $(D FileException) on error.
 +/
version(StdDdoc) void getTimesWin(in char[] name,
                                  out SysTime fileCreationTime,
                                  out SysTime fileAccessTime,
                                  out SysTime fileModificationTime);
else version(Windows) void getTimesWin(in char[] name,
                                       out SysTime fileCreationTime,
                                       out SysTime fileAccessTime,
                                       out SysTime fileModificationTime)
{
    HANDLE findhndl = void;

    if (useWfuncs)
    {
        WIN32_FIND_DATAW filefindbuf;

        findhndl = FindFirstFileW(std.utf.toUTF16z(name), &filefindbuf);
        fileCreationTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftCreationTime);
        fileAccessTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastAccessTime);
        fileModificationTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastWriteTime);
    }
    else
    {
        WIN32_FIND_DATA filefindbuf;

        findhndl = FindFirstFileA(toMBSz(name), &filefindbuf);
        fileCreationTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftCreationTime);
        fileAccessTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastAccessTime);
        fileModificationTime = std.datetime.FILETIMEToSysTime(&filefindbuf.ftLastWriteTime);
    }

    if(findhndl == cast(HANDLE)-1)
    {
        throw new FileException(name.idup);
    }

    FindClose(findhndl);
}

version(Windows) unittest
{
    auto currTime = Clock.currTime();

    write(deleteme, "a");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }

    SysTime creationTime1 = void;
    SysTime accessTime1 = void;
    SysTime modificationTime1 = void;

    getTimesWin(deleteme, creationTime1, accessTime1, modificationTime1);

    enum leeway = dur!"seconds"(3);

    {
        auto diffc = creationTime1 - currTime;
        auto diffa = accessTime1 - currTime;
        auto diffm = modificationTime1 - currTime;
        scope(failure)
        {
            writefln("[%s] [%s] [%s] [%s] [%s] [%s] [%s]",
                     creationTime1, accessTime1, modificationTime1, currTime, diffc, diffa, diffm);
        }

        assert(abs(diffc) <= leeway);
        assert(abs(diffa) <= leeway);
        assert(abs(diffm) <= leeway);
    }

    Thread.sleep(dur!"seconds"(2));

    currTime = Clock.currTime();
    write(deleteme, "b");

    SysTime creationTime2 = void;
    SysTime accessTime2 = void;
    SysTime modificationTime2 = void;

    getTimesWin(deleteme, creationTime2, accessTime2, modificationTime2);

    {
        auto diffa = accessTime2 - currTime;
        auto diffm = modificationTime2 - currTime;
        scope(failure)
        {
            writefln("[%s] [%s] [%s] [%s] [%s]",
                     accessTime2, modificationTime2, currTime, diffa, diffm);
        }

        assert(abs(diffa) <= leeway);
        assert(abs(diffm) <= leeway);
    }

    assert(creationTime1 == creationTime2);
    assert(accessTime1 <= accessTime2);
    assert(modificationTime1 <= modificationTime2);
}

/++
    $(RED Scheduled for deprecation in November 2011. Please use the
          $(D getTimes) with two arguments instead.)

    $(BLUE This function is Posix-Only.)

    Get file status change time, acces time, and modification times
    of file $(D name).

    $(D getTimes) is the same on both Windows and Posix, but it is not
    possible to get the file creation time on Posix systems, so
    $(D getTimes) cannot give you the file creation time. $(D getTimesWin)
    does the same thing on Windows as $(D getTimes) except that it also gives
    you the file creation time. This function was created to do the same
    thing that the old, 3 argument $(D getTimes) was doing on Posix - giving
    you the time that the file status last changed - but ultimately, that's
    not really very useful, and we don't like having functions which are
    OS-specific when we can reasonably avoid it. So, this function is being
    deprecated. You can use $(D DirEntry)'s  $(D statBuf) property if you
    really want to get at that information (along with all of the other
    OS-specific stuff that $(D stat) gives you).

    Params:
        name                 = File name to get times for.
        fileStatusChangeTime = Time the file's status was last changed.
        fileAccessTime       = Time the file was last accessed.
        fileModificationTime = Time the file was last modified.

    Throws:
        $(D FileException) on error.
 +/
version(StdDdoc) void getTimesPosix(in char[] name,
                                    out SysTime fileStatusChangeTime,
                                    out SysTime fileAccessTime,
                                    out SysTime fileModificationTime);
else version(Posix) void getTimesPosix(C)(in C[] name,
                                          out SysTime fileStatusChangeTime,
                                          out SysTime fileAccessTime,
                                          out SysTime fileModificationTime)
    if(is(Unqual!C == char))
{
    struct_stat64 statbuf = void;

    cenforce(stat64(toStringz(name), &statbuf) == 0, name);

    fileStatusChangeTime = SysTime(unixTimeToStdTime(statbuf.st_ctime));
    fileAccessTime = SysTime(unixTimeToStdTime(statbuf.st_atime));
    fileModificationTime = SysTime(unixTimeToStdTime(statbuf.st_mtime));
}


/++
 $(RED Deprecated. It will be removed in February 2012. Please use
       $(D timeLastModified) instead.)
 +/
version(StdDdoc) deprecated d_time lastModified(in char[] name);
else deprecated d_time lastModified(C)(in C[] name)
    if(is(Unqual!C == char))
{
    pragma(msg, hardDeprec!("2.055", "February 2012", "lastModified", "timeLastModified"));

    version(Windows)
    {
        d_time dummy = void, ftm = void;
        getTimes(name, dummy, dummy, ftm);
        return ftm;
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;
        cenforce(stat64(toStringz(name), &statbuf) == 0, name);
        return cast(d_time) statbuf.st_mtime * ticksPerSecond;
    }
}


/++
 $(RED Deprecated. It will be removed in February 2012. Please use
       $(D timeLastModified) instead.)
 +/
version(StdDdoc) deprecated d_time lastModified(in char[] name, d_time returnIfMissing);
else deprecated d_time lastModified(C)(in C[] name, d_time returnIfMissing)
    if(is(Unqual!C == char))
{
    pragma(msg, hardDeprec!("2.055", "February 2012", "lastModified", "timeLastModified"));

    version(Windows)
    {
        if (!exists(name)) return returnIfMissing;
        d_time dummy = void, ftm = void;
        getTimes(name, dummy, dummy, ftm);
        return ftm;
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;
        return stat64(toStringz(name), &statbuf) != 0
            ? returnIfMissing
            : cast(d_time) statbuf.st_mtime * ticksPerSecond;
    }
}

unittest
{
    //std.process.system("echo a>deleteme") == 0 || assert(false);
    if (exists(deleteme)) remove(deleteme);
    write(deleteme, "a\n");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    // assert(lastModified("deleteme") >
    //         lastModified("this file does not exist", d_time.min));
    //assert(lastModified("deleteme") > lastModified(__FILE__));
}

/++
    Returns the time that the given file was last modified.

    Throws:
        $(D FileException) if the given file does not exist.
+/
SysTime timeLastModified(in char[] name)
{
    version(Windows)
    {
        SysTime dummy = void;
        SysTime ftm = void;

        getTimesWin(name, dummy, dummy, ftm);

        return ftm;
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;

        cenforce(stat64(toStringz(name), &statbuf) == 0, name);

        return SysTime(unixTimeToStdTime(statbuf.st_mtime));
    }
}


/++
    Returns the time that the given file was last modified. If the
    file does not exist, returns $(D returnIfMissing).

    A frequent usage pattern occurs in build automation tools such as
    $(WEB gnu.org/software/make, make) or $(WEB
    en.wikipedia.org/wiki/Apache_Ant, ant). To check whether file $(D
    target) must be rebuilt from file $(D source) (i.e., $(D target) is
    older than $(D source) or does not exist), use the comparison
    below. The code throws a $(D FileException) if $(D source) does not
    exist (as it should). On the other hand, the $(D SysTime.min) default
    makes a non-existing $(D target) seem infinitely old so the test
    correctly prompts building it.

    Params:
        name            = The name of the file to get the modification time for.
        returnIfMissing = The time to return if the given file does not exist.

Examples:
--------------------
if(timeLastModified(source) >= timeLastModified(target, SysTime.min))
{
    // must (re)build
}
else
{
    // target is up-to-date
}
--------------------
+/
SysTime timeLastModified(in char[] name, SysTime returnIfMissing)
{
    version(Windows)
    {
        if(!exists(name))
            return returnIfMissing;

        SysTime dummy = void;
        SysTime ftm = void;

        getTimesWin(name, dummy, dummy, ftm);

        return ftm;
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;

        return stat64(toStringz(name), &statbuf) != 0 ?
               returnIfMissing :
               SysTime(unixTimeToStdTime(statbuf.st_mtime));
    }
}

unittest
{
    //std.process.system("echo a > deleteme") == 0 || assert(false);
    if(exists(deleteme))
        remove(deleteme);

    write(deleteme, "a\n");

    scope(exit)
    {
        assert(exists(deleteme));
        remove(deleteme);
    }

    // assert(lastModified("deleteme") >
    //         lastModified("this file does not exist", SysTime.min));
    //assert(lastModified("deleteme") > lastModified(__FILE__));
}


/++
    Returns whether the given file (or directory) exists.
 +/
@property bool exists(in char[] name)
{
    version(Windows)
    {
        auto result = useWfuncs
// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/
// fileio/base/getfileattributes.asp
            ? GetFileAttributesW(std.utf.toUTF16z(name))
            : GetFileAttributesA(toMBSz(name));
        return result != 0xFFFFFFFF;
    }
    else version(Posix)
    {
        return access(toStringz(name), 0) == 0;
    }
}

unittest
{
    assert(exists("."));
    assert(!exists("this file does not exist"));
    write(deleteme, "a\n");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    assert(exists(deleteme));
}


/++
 Returns the attributes of the given file.

 Note that the file attributes on Windows and Posix systems are
 completely different. On Windows, they're what is returned by $(WEB
 msdn.microsoft.com/en-us/library/aa364944(v=vs.85).aspx,
 GetFileAttributes), whereas on Posix systems, they're the $(LUCKY
 st_mode) value which is part of the $(D stat struct) gotten by
 calling the $(WEB en.wikipedia.org/wiki/Stat_%28Unix%29, $(D stat))
 function.

 On Posix systems, if the given file is a symbolic link, then
 attributes are the attributes of the file pointed to by the symbolic
 link.

 Params:
 name = The file to get the attributes of.
  +/
uint getAttributes(in char[] name)
{
    version(Windows)
    {
        auto result = useWfuncs ?
                      GetFileAttributesW(std.utf.toUTF16z(name)) :
                      GetFileAttributesA(toMBSz(name));

        enforce(result != uint.max, new FileException(name.idup));

        return result;
    }
    else version(Posix)
    {
        struct_stat64 statbuf = void;

        cenforce(stat64(toStringz(name), &statbuf) == 0, name);

        return statbuf.st_mode;
    }
}


/++
    If the given file is a symbolic link, then this returns the attributes of the
    symbolic link itself rather than file that it points to. If the given file
    is $(I not) a symbolic link, then this function returns the same result
    as getAttributes.

    On Windows, getLinkAttributes is identical to getAttributes. It exists on
    Windows so that you don't have to special-case code for Windows when dealing
    with symbolic links.

    Params:
        name = The file to get the symbolic link attributes of.

    Throws:
        $(D FileException) on error.
 +/
uint getLinkAttributes(in char[] name)
{
    version(Windows)
    {
        return getAttributes(name);
    }
    else version(Posix)
    {
        struct_stat64 lstatbuf = void;
        cenforce(lstat64(toStringz(name), &lstatbuf) == 0, name);
        return lstatbuf.st_mode;
    }
}


/++
    Returns whether the given file is a directory.

    Params:
        name = The path to the file.

    Throws:
        $(D FileException) if the given file does not exist.

Examples:
--------------------
assert(!"/etc/fonts/fonts.conf".isDir);
assert("/usr/share/include".isDir);
--------------------
  +/
@property bool isDir(in char[] name)
{
    version(Windows)
    {
        return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) != 0;
    }
    else version(Posix)
    {
        return (getAttributes(name) & S_IFMT) == S_IFDIR;
    }
}

unittest
{
    version(Windows)
    {
        if("C:\\Program Files\\".exists)
            assert("C:\\Program Files\\".isDir);

        if("C:\\Windows\\system.ini".exists)
            assert(!"C:\\Windows\\system.ini".isDir);
    }
    else version(Posix)
    {
        if("/usr/include".exists)
            assert("/usr/include".isDir);

        if("/usr/include/assert.h".exists)
            assert(!"/usr/include/assert.h".isDir);
    }
}

/++
 $(RED Deprecated. It will be removed in February 2012. Please use
       $(D isDir) instead.)
 +/
deprecated alias isDir isdir;


/++
    $(RED Scheduled for deprecation in November 2011.
          Please use $(D attrIsDir) instead.)

    Returns whether the given file attributes are for a directory.

    Params:
        attributes = The file attributes.
  +/
@property bool isDir(uint attributes) nothrow
{
    version(Windows)
    {
        return (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    }
    else version(Posix)
    {
        return (attributes & S_IFMT) == S_IFDIR;
    }
}


/++
    Returns whether the given file attributes are for a directory.

    Params:
        attributes = The file attributes.

Examples:
--------------------
assert(!attrIsDir(getAttributes("/etc/fonts/fonts.conf")));
assert(!attrIsDir(getLinkAttributes("/etc/fonts/fonts.conf")));
--------------------
  +/
bool attrIsDir(uint attributes) nothrow
{
    version(Windows)
    {
        return (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    }
    else version(Posix)
    {
        return (attributes & S_IFMT) == S_IFDIR;
    }
}

unittest
{
    version(Windows)
    {
        if("C:\\Program Files\\".exists)
        {
            assert(attrIsDir(getAttributes("C:\\Program Files\\")));
            assert(attrIsDir(getLinkAttributes("C:\\Program Files\\")));
        }

        if("C:\\Windows\\system.ini".exists)
        {
            assert(!attrIsDir(getAttributes("C:\\Windows\\system.ini")));
            assert(!attrIsDir(getLinkAttributes("C:\\Windows\\system.ini")));
        }
    }
    else version(Posix)
    {
        if("/usr/include".exists)
        {
            assert(attrIsDir(getAttributes("/usr/include")));
            assert(attrIsDir(getLinkAttributes("/usr/include")));
        }

        if("/usr/include/assert.h".exists)
        {
            assert(!attrIsDir(getAttributes("/usr/include/assert.h")));
            assert(!attrIsDir(getLinkAttributes("/usr/include/assert.h")));
        }
    }
}


/++
    Returns whether the given file (or directory) is a file.

    On Windows, if a file is not a directory, then it's a file. So,
    either $(D isFile) or $(D isDir) will return true for any given file.

    On Posix systems, if $(D isFile) is $(D true), that indicates that the file
    is a regular file (e.g. not a block not device). So, on Posix systems, it's
    possible for both $(D isFile) and $(D isDir) to be $(D false) for a
    particular file (in which case, it's a special file). You can use
    $(D getAttributes) to get the attributes to figure out what type of special
    it is, or you can use $(D dirEntry) to get at its $(D statBuf), which is the
    result from $(D stat). In either case, see the man page for $(D stat) for
    more information.

    Params:
        name = The path to the file.

    Throws:
        $(D FileException) if the given file does not exist.

Examples:
--------------------
assert("/etc/fonts/fonts.conf".isFile);
assert(!"/usr/share/include".isFile);
--------------------
  +/
@property bool isFile(in char[] name)
{
    version(Windows)
        return !name.isDir;
    else version(Posix)
        return (getAttributes(name) & S_IFMT) == S_IFREG;
}

unittest
{
    version(Windows)
    {
        if("C:\\Program Files\\".exists)
            assert(!"C:\\Program Files\\".isFile);

        if("C:\\Windows\\system.ini".exists)
            assert("C:\\Windows\\system.ini".isFile);
    }
    else version(Posix)
    {
        if("/usr/include".exists)
            assert(!"/usr/include".isFile);

        if("/usr/include/assert.h".exists)
            assert("/usr/include/assert.h".isFile);
    }
}

/++
 $(RED Deprecated. It will be removed in February 2012. Please use
       $(D isDir) instead.)
 +/
deprecated alias isFile isfile;


/++
    $(RED Scheduled for deprecation in November 2011.
          Please use $(D attrIsFile) instead.)

    Returns whether the given file attributes are for a file.

    On Windows, if a file is not a directory, it's a file. So,
    either $(D isFile) or $(D isDir) will return $(D true) for any given file.

    On Posix systems, if $(D isFile) is $(D true), that indicates that the file
    is a regular file (e.g. not a block not device). So, on Posix systems,
    it's possible for both $(D isFile) and $(D isDir) to be $(D false) for a
    particular file (in which case, it's a special file). If a file is a special
    file, you can use the attributes to check what type of special
    file it is (see the man page for $(D stat) for more information).

    Params:
        attributes = The file attributes.
  +/
@property bool isFile(uint attributes) nothrow
{
    version(Windows)
    {
        return (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
    }
    else version(Posix)
    {
        return (attributes & S_IFMT) == S_IFREG;
    }
}


/++
    Returns whether the given file attributes are for a file.

    On Windows, if a file is not a directory, it's a file. So, either
    $(D attrIsFile) or $(D attrIsDir) will return $(D true) for the
    attributes of any given file.

    On Posix systems, if $(D attrIsFile) is $(D true), that indicates that the
    file is a regular file (e.g. not a block not device). So, on Posix systems,
    it's possible for both $(D attrIsFile) and $(D attrIsDir) to be $(D false)
    for a particular file (in which case, it's a special file). If a file is a
    special file, you can use the attributes to check what type of special file
    it is (see the man page for $(D stat) for more information).

    Params:
        attributes = The file attributes.

Examples:
--------------------
assert(attrIsFile(getAttributes("/etc/fonts/fonts.conf")));
assert(attrIsFile(getLinkAttributes("/etc/fonts/fonts.conf")));
--------------------
  +/
bool attrIsFile(uint attributes) nothrow
{
    version(Windows)
    {
        return (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
    }
    else version(Posix)
    {
        return (attributes & S_IFMT) == S_IFREG;
    }
}

unittest
{
    version(Windows)
    {
        if("C:\\Program Files\\".exists)
        {
            assert(!attrIsFile(getAttributes("C:\\Program Files\\")));
            assert(!attrIsFile(getLinkAttributes("C:\\Program Files\\")));
        }

        if("C:\\Windows\\system.ini".exists)
        {
            assert(attrIsFile(getAttributes("C:\\Windows\\system.ini")));
            assert(attrIsFile(getLinkAttributes("C:\\Windows\\system.ini")));
        }
    }
    else version(Posix)
    {
        if("/usr/include".exists)
        {
            assert(!attrIsFile(getAttributes("/usr/include")));
            assert(!attrIsFile(getLinkAttributes("/usr/include")));
        }

        if("/usr/include/assert.h".exists)
        {
            assert(attrIsFile(getAttributes("/usr/include/assert.h")));
            assert(attrIsFile(getLinkAttributes("/usr/include/assert.h")));
        }
    }
}


/++
    Returns whether the given file is a symbolic link.

    On Windows, return $(D true) when the file is either a symbolic link or a
    junction point.

    Params:
        name = The path to the file.

    Throws:
        $(D FileException) if the given file does not exist.
  +/
@property bool isSymlink(C)(const(C)[] name)
{
    version(Windows)
        return (getAttributes(name) & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
    else version(Posix)
        return (getLinkAttributes(name) & S_IFMT) == S_IFLNK;
}

unittest
{
    version(Windows)
    {
        if("C:\\Program Files\\".exists)
            assert(!"C:\\Program Files\\".isSymlink);

        if("C:\\Users\\".exists && "C:\\Documents and Settings\\".exists)
            assert("C:\\Documents and Settings\\".isSymlink);

        enum fakeSymFile = "C:\\Windows\\system.ini";
        if(fakeSymFile.exists)
        {
            assert(!fakeSymFile.isSymlink);

            assert(!fakeSymFile.isSymlink);
            assert(!attrIsSymlink(getAttributes(fakeSymFile)));
            assert(!attrIsSymlink(getLinkAttributes(fakeSymFile)));

            assert(isFile(getAttributes(fakeSymFile)));
            assert(isFile(getLinkAttributes(fakeSymFile)));
            assert(!isDir(getAttributes(fakeSymFile)));
            assert(!isDir(getLinkAttributes(fakeSymFile)));

            assert(getAttributes(fakeSymFile) == getLinkAttributes(fakeSymFile));
        }
    }
    else version(Posix)
    {
        if("/usr/include".exists)
        {
            assert(!"/usr/include".isSymlink);

            immutable symfile = deleteme ~ "_slink\0";
            scope(exit) if(symfile.exists) symfile.remove();

            core.sys.posix.unistd.symlink("/usr/include", symfile.ptr);

            assert(symfile.isSymlink);
            assert(!attrIsSymlink(getAttributes(symfile)));
            assert(attrIsSymlink(getLinkAttributes(symfile)));

            assert(isDir(getAttributes(symfile)));
            assert(!isDir(getLinkAttributes(symfile)));

            assert(!isFile(getAttributes(symfile)));
            assert(!isFile(getLinkAttributes(symfile)));
        }

        if("/usr/include/assert.h".exists)
        {
            assert(!"/usr/include/assert.h".isSymlink);

            immutable symfile = deleteme ~ "_slink\0";
            scope(exit) if(symfile.exists) symfile.remove();

            core.sys.posix.unistd.symlink("/usr/include/assert.h", symfile.ptr);

            assert(symfile.isSymlink);
            assert(!attrIsSymlink(getAttributes(symfile)));
            assert(attrIsSymlink(getLinkAttributes(symfile)));

            assert(!isDir(getAttributes(symfile)));
            assert(!isDir(getLinkAttributes(symfile)));

            assert(isFile(getAttributes(symfile)));
            assert(!isFile(getLinkAttributes(symfile)));
        }
    }
}


/++
    $(RED Scheduled for deprecation in November 2011.
          Please use $(D attrIsSymlink) instead.)

    Returns whether the given file attributes are for a symbolic link.

    On Windows, return $(D true) when the file is either a symbolic link or a
    junction point.

    Params:
        attributes = The file attributes.
  +/
@property bool isSymLink(uint attributes) nothrow
{
    version(Windows)
        return (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
    else version(Posix)
        return (attributes & S_IFMT) == S_IFLNK;
}


/++
    Returns whether the given file attributes are for a symbolic link.

    On Windows, return $(D true) when the file is either a symbolic link or a
    junction point.

    Params:
        attributes = The file attributes.

Examples:
--------------------
core.sys.posix.unistd.symlink("/etc/fonts/fonts.conf", "/tmp/alink");

assert(!getAttributes("/tmp/alink").isSymlink);
assert(getLinkAttributes("/tmp/alink").isSymlink);
--------------------
  +/
bool attrIsSymlink(uint attributes) nothrow
{
    version(Windows)
        return (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
    else version(Posix)
        return (attributes & S_IFMT) == S_IFLNK;
}


/****************************************************
 * Change directory to $(D pathname).
 * Throws: $(D FileException) on error.
 */
void chdir(in char[] pathname)
{
    version(Windows)
    {
        enforce(useWfuncs
                ? SetCurrentDirectoryW(std.utf.toUTF16z(pathname))
                : SetCurrentDirectoryA(toMBSz(pathname)),
                new FileException(pathname.idup));
    }
    else version(Posix)
    {
        cenforce(core.sys.posix.unistd.chdir(toStringz(pathname)) == 0,
                pathname);
    }
}

/****************************************************
Make directory $(D pathname).

Throws: $(D FileException) on error.
 */
void mkdir(in char[] pathname)
{
    version(Windows)
    {
        enforce(useWfuncs
                ? CreateDirectoryW(std.utf.toUTF16z(pathname), null)
                : CreateDirectoryA(toMBSz(pathname), null),
                new FileException(pathname.idup));
    }
    else version(Posix)
    {
        cenforce(core.sys.posix.sys.stat.mkdir(toStringz(pathname), octal!777) == 0,
                 pathname);
    }
}

/****************************************************
 * Make directory and all parent directories as needed.
 */

void mkdirRecurse(in char[] pathname)
{
    const left = dirName(pathname);
    if (!exists(left))
    {
        version (Windows)
        {   /* Prevent infinite recursion if left is "d:\" and
             * drive d does not exist.
             */
            if (left.length >= 3 && left[$ - 2] == ':')
                throw new FileException(left.idup);
        }
        mkdirRecurse(left);
    }
    if (!baseName(pathname).empty)
    {
        mkdir(pathname);
    }
}

unittest
{
    // bug3570
    {
        immutable basepath = deleteme ~ "_dir";
        version (Windows)
        {
            immutable path = basepath ~ "\\fake\\here\\";
        }
        else version (Posix)
        {
            immutable path = basepath ~ `/fake/here/`;
        }

        mkdirRecurse(path);
        assert(basepath.exists && basepath.isDir);
        scope(exit) rmdirRecurse(basepath);
        assert(path.exists && path.isDir);
    }
}

/****************************************************
Remove directory $(D pathname).

Throws: $(D FileException) on error.
 */
void rmdir(in char[] pathname)
{
    version(Windows)
    {
        cenforce(useWfuncs
                ? RemoveDirectoryW(std.utf.toUTF16z(pathname))
                : RemoveDirectoryA(toMBSz(pathname)),
                pathname);
    }
    else version(Posix)
    {
        cenforce(core.sys.posix.unistd.rmdir(toStringz(pathname)) == 0,
                pathname);
    }
}

/++
    $(BLUE This function is Posix-Only.)

    Creates a symlink.

    Params:
        original = The file to link from.
        link     = The symlink to create.

    Throws:
        $(D FileException) on error (which includes if the symlink already
        exists).
  +/
version(StdDdoc) void symlink(C1, C2)(const(C1)[] original, const(C2)[] link);
else version(Posix) void symlink(C1, C2)(const(C1)[] original, const(C2)[] link)
{
    cenforce(core.sys.posix.unistd.symlink(toUTFz!(const char*)(original),
                                           toUTFz!(const char*)(link)) == 0,
             link);
}

version(Posix) unittest
{
    if("/usr/include".exists)
    {
        immutable symfile = deleteme ~ "_slink\0";
        scope(exit) if(symfile.exists) symfile.remove();

        symlink("/usr/include", symfile);

        assert(symfile.exists);
        assert(symfile.isSymlink);
        assert(!attrIsSymlink(getAttributes(symfile)));
        assert(attrIsSymlink(getLinkAttributes(symfile)));

        assert(isDir(getAttributes(symfile)));
        assert(!isDir(getLinkAttributes(symfile)));

        assert(!isFile(getAttributes(symfile)));
        assert(!isFile(getLinkAttributes(symfile)));
    }

    if("/usr/include/assert.h".exists)
    {
        assert(!"/usr/include/assert.h".isSymlink);

        immutable symfile = deleteme ~ "_slink\0";
        scope(exit) if(symfile.exists) symfile.remove();

        symlink("/usr/include/assert.h", symfile);

        assert(symfile.exists);
        assert(symfile.isSymlink);
        assert(!attrIsSymlink(getAttributes(symfile)));
        assert(attrIsSymlink(getLinkAttributes(symfile)));

        assert(!isDir(getAttributes(symfile)));
        assert(!isDir(getLinkAttributes(symfile)));

        assert(isFile(getAttributes(symfile)));
        assert(!isFile(getLinkAttributes(symfile)));
    }
}


/++
    $(BLUE This function is Posix-Only.)

    Returns the path to the file pointed to by a symlink. Note that the
    path could be either relative or absolute depending on the symlink.
    If the path is relative, it's relative to the symlink, not the current
    working directory.

    Throws:
        $(D FileException) on error.
  +/
version(StdDdoc) string readLink(C)(const(C)[] link);
else version(Posix) string readLink(C)(const(C)[] link)
{
    char[2048] buffer;
    immutable size = cenforce(core.sys.posix.unistd.readlink(toUTFz!(const char*)(link),
                                                             buffer,
                                                             buffer.length),
                              link);

    return to!string(buffer[0 .. (size >= buffer.length ? $ - 1 : size)]);
}

version(Posix) unittest
{
    foreach(file; ["/usr/include", "/usr/include/assert.h"])
    {
        if(file.exists)
        {
            immutable symfile = deleteme ~ "_slink\0";
            scope(exit) if(symfile.exists) symfile.remove();
            scope(failure) std.stdio.stderr.writefln("Failed file: %s", file);

            symlink(file, symfile);

            assert(readLink(symfile) == file);
        }
    }
}

/****************************************************
 * Get current directory.
 * Throws: $(D FileException) on error.
 */
version(Windows) string getcwd()
{
    /* GetCurrentDirectory's return value:
        1. function succeeds: the number of characters that are written to
    the buffer, not including the terminating null character.
        2. function fails: zero
        3. the buffer (lpBuffer) is not large enough: the required size of
    the buffer, in characters, including the null-terminating character.
    */
    ushort[4096] staticBuff = void; //enough for most common case
    if (useWfuncs)
    {
        auto buffW = cast(wchar[]) staticBuff;
        immutable n = cenforce(GetCurrentDirectoryW(to!DWORD(buffW.length), buffW.ptr),
                "getcwd");
        // we can do it because toUTFX always produces a fresh string
        if(n < buffW.length)
        {
            return toUTF8(buffW[0 .. n]);
        }
        else //staticBuff isn't enough
        {
            auto ptr = cast(wchar*) malloc(wchar.sizeof * n);
            scope(exit) free(ptr);
            immutable n2 = GetCurrentDirectoryW(n, ptr);
            cenforce(n2 && n2 < n, "getcwd");
            return toUTF8(ptr[0 .. n2]);
        }
    }
    else
    {
        auto buffA = cast(char[]) staticBuff;
        immutable n = cenforce(GetCurrentDirectoryA(to!DWORD(buffA.length), buffA.ptr),
                "getcwd");
        // fromMBSz doesn't always produce a fresh string
        if(n < buffA.length)
        {
            string res = fromMBSz(cast(immutable)buffA.ptr);
            return res.ptr == buffA.ptr ? res.idup : res;
        }
        else //staticBuff isn't enough
        {
            auto ptr = cast(char*) malloc(char.sizeof * n);
            scope(exit) free(ptr);
            immutable n2 = GetCurrentDirectoryA(n, ptr);
            cenforce(n2 && n2 < n, "getcwd");

            string res = fromMBSz(cast(immutable)ptr);
            return res.ptr == ptr ? res.idup : res;
        }
    }
}

version (Posix) string getcwd()
{
    auto p = cenforce(core.sys.posix.unistd.getcwd(null, 0),
            "cannot get cwd");
    scope(exit) std.c.stdlib.free(p);
    return p[0 .. std.c.string.strlen(p)].idup;
}

unittest
{
    auto s = getcwd();
    assert(s.length);
}


version(StdDdoc)
{
    /++
        Info on a file, similar to what you'd get from stat on a Posix system.

        A $(D DirEntry) is obtained by using the functions $(D dirEntry) (to get
        the $(D DirEntry) for a specific file) or $(D dirEntries) (to get a
        $(D DirEntry) for each file/directory in a particular directory).
      +/
    struct DirEntry
    {
        void _init(T...)(T);
    public:

        /++
            Returns the path to the file represented by this $(D DirEntry).

Examples:
--------------------
auto de1 = dirEntry("/etc/fonts/fonts.conf");
assert(de1.name == "/etc/fonts/fonts.conf");

auto de2 = dirEntry("/usr/share/include");
assert(de2.name == "/usr/share/include");
--------------------
          +/
        @property string name() const;


        /++
            Returns whether the file represented by this $(D DirEntry) is a
            directory.

Examples:
--------------------
auto de1 = dirEntry("/etc/fonts/fonts.conf");
assert(!de1.isDir);

auto de2 = dirEntry("/usr/share/include");
assert(de2.isDir);
--------------------
          +/
        @property bool isDir();

        /++
         $(RED Deprecated. It will be removed in February 2012. Please use
               $(D isDir) instead.)
         +/
        deprecated alias isDir isdir;


        /++
            Returns whether the file represented by this $(D DirEntry) is a file.

            On Windows, if a file is not a directory, then it's a file. So,
            either $(D isFile) or $(D isDir) will return $(D true).

            On Posix systems, if $(D isFile) is $(D true), that indicates that
            the file is a regular file (e.g. not a block not device). So, on
            Posix systems, it's possible for both $(D isFile) and $(D isDir) to
            be $(D false) for a particular file (in which case, it's a special
            file). You can use $(D attributes) or $(D statBuf) to get more
            information about a special file (see the stat man page for more
            details).

Examples:
--------------------
auto de1 = dirEntry("/etc/fonts/fonts.conf");
assert(de1.isFile);

auto de2 = dirEntry("/usr/share/include");
assert(!de2.isFile);
--------------------
          +/
        @property bool isFile();

        /++
         $(RED Deprecated. It will be removed in February 2012. Please use
               $(D isFile) instead.)
         +/
        deprecated alias isFile isfile;

        /++
            Returns whether the file represented by this $(D DirEntry) is a
            symbolic link.

            On Windows, return $(D true) when the file is either a symbolic
            link or a junction point.
          +/
        @property bool isSymlink();

        /++
            Returns the size of the the file represented by this $(D DirEntry)
            in bytes.
          +/
        @property ulong size();

        /++
            $(RED Deprecated. It will be removed in February 2012. Please use
                   $(D timeCreated) instead.)

            Returns the creation time of the file represented by this
            $(D DirEntry).

            $(RED Note that this property has existed for both Windows and Posix
                  systems but that it is $(I incorrect) on Posix systems. Posix
                  systems do not have access to the creation time of a file. On
                  Posix systems this property has incorrectly been the time that
                  the file's status status last changed. If you want that value,
                  then get it from the $(D statBuf) property, which gives you
                  access to the $(D stat) struct which Posix systems use (check
                  out $(D stat)'s man page for more details.))
          +/
        deprecated @property d_time creationTime() const;

        /++
            $(BLUE This function is Windows-Only.)

            Returns the creation time of the file represented by this
            $(D DirEntry).
          +/
        @property SysTime timeCreated() const;


        /++
            $(RED Scheduled for deprecation in November 2011. It will not be
                  replaced. You can use $(D attributes) to get at this
                  information if you need it.)

            $(BLUE This function is Posix-Only.)

            Returns the last time that the status of file represented by this
            $(D DirEntry) was changed (i.e. owner, group, link count, mode, etc.).
          +/
        @property SysTime timeStatusChanged();

        /++
            $(RED Deprecated. It will be removed in February 2012. Please use
                  $(D timeLastAccessed) instead.)

            Returns the time that the file represented by this $(D DirEntry) was
            last accessed.

            Note that many file systems do not update the access time for files
            (generally for performance reasons), so there's a good chance that
            $(D lastAccessTime) will return the same value as $(D lastWriteTime).
          +/
        deprecated @property d_time lastAccessTime();

        /++
            Returns the time that the file represented by this $(D DirEntry) was
            last accessed.

            Note that many file systems do not update the access time for files
            (generally for performance reasons), so there's a good chance that
            $(D timeLastAccessed) will return the same value as
            $(D timeLastModified).
          +/
        @property SysTime timeLastAccessed();

        /++
            $(RED Deprecated. It will be removed in February 2012. Please use
                  $(D timeLastModified) instead.)

            Returns the time that the file represented by this $(D DirEntry) was
            last modified.
          +/
        deprecated @property d_time lastWriteTime();

        /++
            Returns the time that the file represented by this $(D DirEntry) was
            last modified.
          +/
        @property SysTime timeLastModified();

        /++
            Returns the attributes of the file represented by this $(D DirEntry).

            Note that the file attributes on Windows and Posix systems are
            completely different. On, Windows, they're what is returned by
            $(D GetFileAttributes)
            $(WEB msdn.microsoft.com/en-us/library/aa364944(v=vs.85).aspx, GetFileAttributes)
            Whereas, an Posix systems, they're the $(D st_mode) value which is
            part of the $(D stat) struct gotten by calling $(D stat).

            On Posix systems, if the file represented by this $(D DirEntry) is a
            symbolic link, then attributes are the attributes of the file
            pointed to by the symbolic link.
          +/
        @property uint attributes();

        /++
            On Posix systems, if the file represented by this $(D DirEntry) is a
            symbolic link, then $(D linkAttributes) are the attributes of the
            symbolic link itself. Otherwise, $(D linkAttributes) is identical to
            $(D attributes).

            On Windows, $(D linkAttributes) is identical to $(D attributes). It
            exists on Windows so that you don't have to special-case code for
            Windows when dealing with symbolic links.
          +/
        @property uint linkAttributes();

        version(Windows) alias void* struct_stat64;

        /++
            $(BLUE This function is Posix-Only.)

            The $(D stat) struct gotten from calling $(D stat).
          +/
        @property struct_stat64 statBuf();
    }
}
else version(Windows)
{
    struct DirEntry
    {
    public:

        @property string name() const
        {
            return _name;
        }

        @property bool isDir() const
        {
            return (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        }

        deprecated alias isDir isdir;

        @property bool isFile() const
        {
            //Are there no options in Windows other than directory and file?
            //If there are, then this probably isn't the best way to determine
            //whether this DirEntry is a file or not.
            return !isDir;
        }

        deprecated alias isFile isfile;

        @property bool isSymlink() const
        {
            return (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
        }

        @property ulong size() const
        {
            return _size;
        }

        deprecated @property d_time creationTime() const
        {
            return sysTimeToDTime(_timeCreated);
        }

        @property SysTime timeCreated() const
        {
            return cast(SysTime)_timeCreated;
        }

        deprecated @property d_time lastAccessTime() const
        {
            return sysTimeToDTime(_timeLastAccessed);
        }

        @property SysTime timeLastAccessed() const
        {
            return cast(SysTime)_timeLastAccessed;
        }

        deprecated @property d_time lastWriteTime() const
        {
            return sysTimeToDTime(_timeLastModified);
        }

        @property SysTime timeLastModified() const
        {
            return cast(SysTime)_timeLastModified;
        }

        @property uint attributes() const
        {
            return _attributes;
        }

        @property uint linkAttributes() const
        {
            return _attributes;
        }

    private:

        void _init(in char[] path)
        {
            HANDLE findhndl = void;
            uint resulth = void;
            uint resultl = void;
            _name = path.idup;

            //FindFirstFileX can't handle file names which end in a backslash.
            if(_name.endsWith(sep))
                _name.popBackN(sep.length);

            if(useWfuncs)
            {
                WIN32_FIND_DATAW fd;

                findhndl = FindFirstFileW(std.utf.toUTF16z(_name), &fd);
                enforce(findhndl != INVALID_HANDLE_VALUE);

                _size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
                _timeCreated = std.datetime.FILETIMEToSysTime(&fd.ftCreationTime);
                _timeLastAccessed = std.datetime.FILETIMEToSysTime(&fd.ftLastAccessTime);
                _timeLastModified = std.datetime.FILETIMEToSysTime(&fd.ftLastWriteTime);
                _attributes = fd.dwFileAttributes;
            }
            else
            {
                WIN32_FIND_DATA fd;

                findhndl = FindFirstFileA(toMBSz(_name), &fd);
                enforce(findhndl != INVALID_HANDLE_VALUE);

                _size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
                _timeCreated = std.datetime.FILETIMEToSysTime(&fd.ftCreationTime);
                _timeLastAccessed = std.datetime.FILETIMEToSysTime(&fd.ftLastAccessTime);
                _timeLastModified = std.datetime.FILETIMEToSysTime(&fd.ftLastWriteTime);
                _attributes = fd.dwFileAttributes;
            }

            cenforce(findhndl != cast(HANDLE)-1 && FindClose(findhndl), _name);
        }

        void _init(in char[] path, in WIN32_FIND_DATA* fd)
        {
            auto clength = to!int(std.c.string.strlen(fd.cFileName.ptr));

            // Convert cFileName[] to unicode
            const wlength = MultiByteToWideChar(0, 0, fd.cFileName.ptr, clength, null, 0);
            auto wbuf = new wchar[wlength];
            const n = MultiByteToWideChar(0, 0, fd.cFileName.ptr, clength, wbuf.ptr, wlength);
            assert(n == wlength);
            // toUTF8() returns a new buffer
            _name = buildPath(path, std.utf.toUTF8(wbuf[0 .. wlength]));
            _size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
            _timeCreated = std.datetime.FILETIMEToSysTime(&fd.ftCreationTime);
            _timeLastAccessed = std.datetime.FILETIMEToSysTime(&fd.ftLastAccessTime);
            _timeLastModified = std.datetime.FILETIMEToSysTime(&fd.ftLastWriteTime);
            _attributes = fd.dwFileAttributes;
        }

        void _init(in char[] path, in WIN32_FIND_DATAW *fd)
        {
            size_t clength = std.string.wcslen(fd.cFileName.ptr);
            _name = std.utf.toUTF8(fd.cFileName[0 .. clength]);
            _name = buildPath(path, std.utf.toUTF8(fd.cFileName[0 .. clength]));
            _size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
            _timeCreated = std.datetime.FILETIMEToSysTime(&fd.ftCreationTime);
            _timeLastAccessed = std.datetime.FILETIMEToSysTime(&fd.ftLastAccessTime);
            _timeLastModified = std.datetime.FILETIMEToSysTime(&fd.ftLastWriteTime);
            _attributes = fd.dwFileAttributes;
        }


        string _name; /// The file or directory represented by this DirEntry.


        SysTime _timeCreated;      /// The time when the file was created.
        SysTime _timeLastAccessed; /// The time when the file was last accessed.
        SysTime _timeLastModified; /// The time when the file was last modified.

        ulong _size;       /// The size of the file in bytes.
        uint  _attributes; /// The file attributes from WIN32_FIND_DATAW.
    }
}
else version(Posix)
{
    struct DirEntry
    {
    public:

        @property string name() const
        {
            return _name;
        }

        @property bool isDir()
        {
            _ensureStatDone();

            return (_statBuf.st_mode & S_IFMT) == S_IFDIR;
        }

        deprecated alias isDir isdir;

        @property bool isFile()
        {
            _ensureStatDone();

            return (_statBuf.st_mode & S_IFMT) == S_IFREG;
        }

        deprecated alias isFile isfile;

        @property bool isSymlink()
        {
            _ensureLStatDone();

            return (_lstatMode & S_IFMT) == S_IFLNK;
        }

        // This property was not documented before, and it's almost
        // worthless, since the odds are high that it will be DT_UNKNOWN,
        // so it continues to be left undocumented.
        //
        // Will be removed in February 2012.
        deprecated @property ubyte d_type()
        {
            return _dType;
        }

        @property ulong size()
        {
            _ensureStatDone();
            return _statBuf.st_size;
        }

        deprecated @property d_time creationTime()
        {
            _ensureStatDone();

            return cast(d_time)_statBuf.st_ctime * ticksPerSecond;
        }

        @property SysTime timeStatusChanged()
        {
            _ensureStatDone();

            return SysTime(unixTimeToStdTime(_statBuf.st_ctime));
        }

        deprecated @property d_time lastAccessTime()
        {
            _ensureStatDone();

            return cast(d_time)_statBuf.st_atime * ticksPerSecond;
        }

        @property SysTime timeLastAccessed()
        {
            _ensureStatDone();

            return SysTime(unixTimeToStdTime(_statBuf.st_ctime));
        }

        deprecated @property d_time lastWriteTime()
        {
            _ensureStatDone();

            return cast(d_time)_statBuf.st_mtime * ticksPerSecond;
        }

        @property SysTime timeLastModified()
        {
            _ensureStatDone();

            return SysTime(unixTimeToStdTime(_statBuf.st_mtime));
        }

        @property uint attributes()
        {
            _ensureStatDone();

            return _statBuf.st_mode;
        }

        @property uint linkAttributes()
        {
            _ensureLStatDone();

            return _lstatMode;
        }

        @property struct_stat64 statBuf()
        {
            _ensureStatDone();

            return _statBuf;
        }

    private:

        void _init(in char[] path)
        {
            _name = path.idup;

            _didLStat = false;
            _didStat = false;
            _dTypeSet = false;
        }

        void _init(in char[] path, core.sys.posix.dirent.dirent* fd)
        {
            immutable len = std.c.string.strlen(fd.d_name.ptr);
            _name = buildPath(path, fd.d_name[0 .. len]);

            _didLStat = false;
            _didStat = false;

            //fd_d_type doesn't work for all file systems,
            //in which case the result is DT_UNKOWN. But we
            //can determine the correct type from lstat, so
            //we'll only set the dtype here if we could
            //correctly determine it (not lstat in the case
            //of DT_UNKNOWN in case we don't ever actually
            //need the dtype, thus potentially avoiding the
            //cost of calling lstat).
            if(fd.d_type != DT_UNKNOWN)
            {
                _dType = fd.d_type;
                _dTypeSet = true;
            }
            else
                _dTypeSet = false;
        }

        /++
            This is to support lazy evaluation, because doing stat's is
            expensive and not always needed.
         +/
        void _ensureStatDone()
        {
            if(_didStat)
                return;

            enforce(stat64(toStringz(_name), &_statBuf) == 0,
                    "Failed to stat file `" ~ _name ~ "'");

            _didStat = true;
        }

        /++
            This is to support lazy evaluation, because doing stat's is
            expensive and not always needed.
         +/
        void _ensureLStatDone()
        {
            if(_didLStat)
                return;

            struct_stat64 statbuf = void;

            enforce(lstat64(toStringz(_name), &statbuf) == 0,
                "Failed to stat file `" ~ _name ~ "'");

            _lstatMode = statbuf.st_mode;

            _dTypeSet = true;
            _didLStat = true;
        }


        string _name; /// The file or directory represented by this DirEntry.

        struct_stat64 _statBuf = void;  /// The result of stat().
        uint  _lstatMode;               /// The stat mode from lstat().
        ubyte _dType;                   /// The type of the file.

        bool _didLStat = false;   /// Whether lstat() has been called for this DirEntry.
        bool _didStat = false;    /// Whether stat() has been called for this DirEntry.
        bool _dTypeSet = false;   /// Whether the dType of the file has been set.
    }
}

unittest
{
    version(Windows)
    {
        if("C:\\Program Files\\".exists)
        {
            auto de = dirEntry("C:\\Program Files\\");
            assert(!de.isFile);
            assert(de.isDir);
            assert(!de.isSymlink);
        }

        if("C:\\Users\\".exists && "C:\\Documents and Settings\\".exists)
        {
            auto de = dirEntry("C:\\Documents and Settings\\");
            assert(de.isSymlink);
        }

        if("C:\\Windows\\system.ini".exists)
        {
            auto de = dirEntry("C:\\Windows\\system.ini");
            assert(de.isFile);
            assert(!de.isDir);
            assert(!de.isSymlink);
        }
    }
    else version(Posix)
    {
        if("/usr/include".exists)
        {
            {
                auto de = dirEntry("/usr/include");
                assert(!de.isFile);
                assert(de.isDir);
                assert(!de.isSymlink);
            }

            immutable symfile = deleteme ~ "_slink\0";
            scope(exit) if(symfile.exists) symfile.remove();

            core.sys.posix.unistd.symlink("/usr/include", symfile.ptr);

            {
                auto de = dirEntry(symfile);
                assert(!de.isFile);
                assert(de.isDir);
                assert(de.isSymlink);
            }
        }

        if("/usr/include/assert.h".exists)
        {
            auto de = dirEntry("/usr/include/assert.h");
            assert(de.isFile);
            assert(!de.isDir);
            assert(!de.isSymlink);
        }
    }
}


/******************************************************
 * $(RED Scheduled for deprecation in November 2011.
 *       Please use $(D dirEntries) instead.)
 *
 * For each file and directory $(D DirEntry) in $(D pathname[])
 * pass it to the callback delegate.
 *
 * Params:
 *        callback =        Delegate that processes each
 *                        DirEntry in turn. Returns true to
 *                        continue, false to stop.
 * Example:
 *        This program lists all the files in its
 *        path argument and all subdirectories thereof.
 * ----
 * import std.stdio;
 * import std.file;
 *
 * void main(string[] args)
 * {
 *    bool callback(DirEntry* de)
 *    {
 *      if(de.isDir)
 *        listdir(de.name, &callback);
 *      else
 *        writefln(de.name);

 *      return true;
 *    }
 *
 *    listdir(args[1], &callback);
 * }
 * ----
 */
alias listDir listdir;


/***************************************************
Copy file $(D from) to file $(D to). File timestamps are preserved.
 */
void copy(in char[] from, in char[] to)
{
    version(Windows)
    {
        immutable result = useWfuncs
            ? CopyFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to), false)
            : CopyFileA(toMBSz(from), toMBSz(to), false);
        if (!result)
            throw new FileException(to.idup);
    }
    else version(Posix)
    {
        immutable fd = core.sys.posix.fcntl.open(toStringz(from), O_RDONLY);
        cenforce(fd != -1, from);
        scope(exit) core.sys.posix.unistd.close(fd);

        struct_stat64 statbuf = void;
        cenforce(fstat64(fd, &statbuf) == 0, from);
        //cenforce(core.sys.posix.sys.stat.fstat(fd, &statbuf) == 0, from);

        auto toz = toStringz(to);
        immutable fdw = core.sys.posix.fcntl.open(toz,
                O_CREAT | O_WRONLY | O_TRUNC, octal!666);
        cenforce(fdw != -1, from);
        scope(failure) std.c.stdio.remove(toz);
        {
            scope(failure) core.sys.posix.unistd.close(fdw);
            auto BUFSIZ = 4096u * 16;
            auto buf = std.c.stdlib.malloc(BUFSIZ);
            if (!buf)
            {
                BUFSIZ = 4096;
                buf = std.c.stdlib.malloc(BUFSIZ);
                buf || assert(false, "Out of memory in std.file.copy");
            }
            scope(exit) std.c.stdlib.free(buf);

            for (auto size = statbuf.st_size; size; )
            {
                immutable toxfer = (size > BUFSIZ) ? BUFSIZ : cast(size_t) size;
                cenforce(
                    core.sys.posix.unistd.read(fd, buf, toxfer) == toxfer
                    && core.sys.posix.unistd.write(fdw, buf, toxfer) == toxfer,
                    from);
                assert(size >= toxfer);
                size -= toxfer;
            }
        }

        cenforce(core.sys.posix.unistd.close(fdw) != -1, from);

        utimbuf utim = void;
        utim.actime = cast(time_t)statbuf.st_atime;
        utim.modtime = cast(time_t)statbuf.st_mtime;

        cenforce(utime(toz, &utim) != -1, from);
    }
}

    /++
       $(RED Deprecated. It will be removed in February 2012. Please use the
             version which takes a $(XREF datetime, SysTime) instead.)

        Set access/modified times of file $(D name).

        Throws:
            $(D FileException) on error.
     +/
version(StdDdoc) deprecated void setTimes(in char[] name, d_time fta, d_time ftm);
else deprecated void setTimes(C)(in C[] name, d_time fta, d_time ftm)
    if(is(Unqual!C == char))
{
    pragma(msg, "Notice: As of Phobos 2.055, the version of std.file.setTimes " ~
                "which takes std.date.d_time has been deprecated. It will be " ~
                "removed in February 2012. Please use the version which takes " ~
                "std.datetime.SysTime instead.");

    version(Windows)
    {
        const ta = d_time2FILETIME(fta);
        const tm = d_time2FILETIME(ftm);
        alias TypeTuple!(GENERIC_WRITE, 0, null, OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL, HANDLE.init)
            defaults;
        auto h = useWfuncs
            ? CreateFileW(std.utf.toUTF16z(name), defaults)
            : CreateFileA(toMBSz(name), defaults);
        cenforce(h != INVALID_HANDLE_VALUE, name);
        scope(exit) cenforce(CloseHandle(h), name);

        cenforce(SetFileTime(h, null, &ta, &tm), name);
    }
    else version(Posix)
    {
        timeval[2] t = void;
        t[0].tv_sec = to!int(fta / ticksPerSecond);
        t[0].tv_usec = cast(int)
            (cast(long) ((cast(double) fta / ticksPerSecond)
                    * 1_000_000) % 1_000_000);
        t[1].tv_sec = to!int(ftm / ticksPerSecond);
        t[1].tv_usec = cast(int)
            (cast(long) ((cast(double) ftm / ticksPerSecond)
                    * 1_000_000) % 1_000_000);
        enforce(utimes(toStringz(name), t) == 0);
    }
}


/++
    Set access/modified times of file $(D name).

    Params:
        fileAccessTime       = Time the file was last accessed.
        fileModificationTime = Time the file was last modified.

    Throws:
        $(D FileException) on error.
 +/
version(StdDdoc) void setTimes(in char[] name,
                               SysTime fileAccessTime,
                               SysTime fileModificationTime);
else void setTimes(C)(in C[] name,
                      SysTime fileAccessTime,
                      SysTime fileModificationTime)
    if(is(Unqual!C == char))
{
    version(Windows)
    {
        const ta = SysTimeToFILETIME(fileAccessTime);
        const tm = SysTimeToFILETIME(fileModificationTime);
        alias TypeTuple!(GENERIC_WRITE,
                         0,
                         null,
                         OPEN_EXISTING,
                         FILE_ATTRIBUTE_NORMAL, HANDLE.init)
              defaults;
        auto h = useWfuncs ?
                 CreateFileW(std.utf.toUTF16z(name), defaults) :
                 CreateFileA(toMBSz(name), defaults);

        cenforce(h != INVALID_HANDLE_VALUE, name);

        scope(exit)
            cenforce(CloseHandle(h), name);

        cenforce(SetFileTime(h, null, &ta, &tm), name);
    }
    else version(Posix)
    {
        timeval[2] t = void;

        t[0] = fileAccessTime.toTimeVal();
        t[1] = fileModificationTime.toTimeVal();

        enforce(utimes(toStringz(name), t) == 0);
    }
}

/+
unittest
{
    write(deleteme, "a\n");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    SysTime ftc1, fta1, ftm1;
    getTimes(deleteme, ftc1, fta1, ftm1);
    enforce(collectException(setTimes("nonexistent", fta1, ftm1)));
    setTimes(deleteme, fta1 + dur!"seconds"(50), ftm1 + dur!"seconds"(50));
    SysTime ftc2, fta2, ftm2;
    getTimes(deleteme, ftc2, fta2, ftm2);
    assert(fta1 + dur!"seconds(50) == fta2, text(fta1 + dur!"seconds(50), "!=", fta2));
    assert(ftm1 + dur!"seconds(50) == ftm2);
}
+/


/++
    Remove directory and all of its content and subdirectories,
    recursively.

    Throws:
        $(D FileException) if there is an error (including if the given
        file is not a directory).
 +/
void rmdirRecurse(in char[] pathname)
{
    DirEntry de = dirEntry(pathname);

    rmdirRecurse(de);
}


/++
    Remove directory and all of its content and subdirectories,
    recursively.

    Throws:
        $(D FileException) if there is an error (including if the given
        file is not a directory).
 +/
void rmdirRecurse(ref DirEntry de)
{
    if(!de.isDir)
        throw new FileException(text("File ", de.name, " is not a directory"));

    if(de.isSymlink())
        remove(de.name);
    else
    {
        // all children, recursively depth-first
        foreach(DirEntry e; dirEntries(de.name, SpanMode.depth, false))
        {
            isDir(e.linkAttributes) ? rmdir(e.name) : remove(e.name);
        }

        // the dir itself
        rmdir(de.name);
    }
}

version(Windows) unittest
{
    auto d = deleteme ~ r".dir\a\b\c\d\e\f\g";
    mkdirRecurse(d);
    rmdirRecurse(deleteme ~ ".dir");
    enforce(!exists(deleteme ~ ".dir"));
}

version(Posix) unittest
{
    auto d = "/tmp/deleteme/a/b/c/d/e/f/g";
    enforce(collectException(mkdir(d)));
    mkdirRecurse(d);
    core.sys.posix.unistd.symlink("/tmp/deleteme/a/b/c", "/tmp/deleteme/link");
    rmdirRecurse("/tmp/deleteme/link");
    enforce(exists(d));
    rmdirRecurse("/tmp/deleteme");
    enforce(!exists("/tmp/deleteme"));

    d = "/tmp/deleteme/a/b/c/d/e/f/g";
    mkdirRecurse(d);
    std.process.system("ln -sf /tmp/deleteme/a/b/c /tmp/deleteme/link");
    rmdirRecurse("/tmp/deleteme");
    enforce(!exists("/tmp/deleteme"));
}

unittest
{
    void[] buf;

    buf = new void[10];
    (cast(byte[])buf)[] = 3;
    if (exists("unittest_write.tmp")) remove("unittest_write.tmp");
    write("unittest_write.tmp", buf);
    void buf2[] = read("unittest_write.tmp");
    assert(buf == buf2);

    copy("unittest_write.tmp", "unittest_write2.tmp");
    buf2 = read("unittest_write2.tmp");
    assert(buf == buf2);

    remove("unittest_write.tmp");
    assert(!exists("unittest_write.tmp"));
    remove("unittest_write2.tmp");
    assert(!exists("unittest_write2.tmp"));
}

unittest
{
    _listDir(".", delegate bool (DirEntry * de)
    {
        version(Windows)
        {
            auto s = std.string.format("%s : c %s, w %s, a %s",
                                       de.name,
                                       de.timeCreated,
                                       de.timeLastModified,
                                       de.timeLastAccessed);
        }
        else version(Posix)
        {
            auto s = std.string.format("%s : c %s, w %s, a %s",
                                       de.name,
                                       de.timeStatusChanged,
                                       de.timeLastModified,
                                       de.timeLastAccessed);
        }

        return true;
    }
    );
}

/**
 * Dictates directory spanning policy for $(D_PARAM dirEntries) (see below).
 */
enum SpanMode
{
    /** Only spans one directory. */
    shallow,
    /** Spans the directory depth-first, i.e. the content of any
     subdirectory is spanned before that subdirectory itself. Useful
     e.g. when recursively deleting files.  */
    depth,
    /** Spans the directory breadth-first, i.e. the content of any
     subdirectory is spanned right after that subdirectory itself. */
    breadth,
}

private struct DirIteratorImpl
{
    SpanMode _mode;
    // Whether we should follow symlinked directories while iterating.
    // It also indicates whether we should avoid functions which call
    // stat (since we should only need lstat in this case and it would
    // be more efficient to not call stat in addition to lstat).
    bool _followSymlink;
    DirEntry _cur;
    Appender!(DirHandle[]) _stack;
    Appender!(DirEntry[]) _stashed; //used in depth first mode
    //stack helpers
    void pushExtra(DirEntry de){ _stashed.put(de); }
    //ditto
    bool hasExtra(){ return !_stashed.data.empty; }
    //ditto
    DirEntry popExtra()
    {
        DirEntry de;
        de = _stashed.data[$-1];
        _stashed.shrinkTo(_stashed.data.length - 1);
        return de;

    }
    version(Windows)
    {
        struct DirHandle
        {
            string dirpath;
            HANDLE h;
        }

        bool stepIn(string directory)
        {
            string search_pattern = buildPath(directory, "*.*");
            if(useWfuncs)
            {
                WIN32_FIND_DATAW findinfo;
                HANDLE h = FindFirstFileW(toUTF16z(search_pattern), &findinfo);
                cenforce(h != INVALID_HANDLE_VALUE, directory);
                _stack.put(DirHandle(directory, h));
                return toNext(false, &findinfo);
            }
            else
            {
                WIN32_FIND_DATA findinfo;
                HANDLE h = FindFirstFileA(toMBSz(search_pattern), &findinfo);
                cenforce(h != INVALID_HANDLE_VALUE, directory);
                _stack.put(DirHandle(directory, h));
                return toNext(false, &findinfo);
            }
        }

        bool next()
        {
            if(_stack.data.empty)
                return false;
            bool result;
            if (useWfuncs)
            {
                WIN32_FIND_DATAW findinfo;
                result = toNext(true, &findinfo);

            }
            else
            {
                WIN32_FIND_DATA findinfo;
                result = toNext(true, &findinfo);
            }
            return result;
        }

        bool toNext(bool fetch, WIN32_FIND_DATAW* findinfo)
        {
            if(fetch)
            {
                if(FindNextFileW(_stack.data[$-1].h, findinfo) == FALSE)
                {
                    popDirStack();
                    return false;
                }
            }
            while( std.string.wcscmp(findinfo.cFileName.ptr, ".") == 0
                    || std.string.wcscmp(findinfo.cFileName.ptr, "..") == 0)
                if(FindNextFileW(_stack.data[$-1].h, findinfo) == FALSE)
                {
                    popDirStack();
                    return false;
                }
            _cur._init(_stack.data[$-1].dirpath, findinfo);
            return true;
        }

        bool toNext(bool fetch, WIN32_FIND_DATA* findinfo)
        {
            if(fetch)
            {
                if(FindNextFileA(_stack.data[$-1].h, findinfo) == FALSE)
                {
                    popDirStack();
                    return false;
                }
            }
            while( std.c.string.strcmp(findinfo.cFileName.ptr, ".") == 0
                    || std.c.string.strcmp(findinfo.cFileName.ptr, "..") == 0)
                if(FindNextFileA(_stack.data[$-1].h, findinfo) == FALSE)
                {
                    popDirStack();
                    return false;
                }
            _cur._init(_stack.data[$-1].dirpath, findinfo);
            return true;
        }

        void popDirStack()
        {
            assert(!_stack.data.empty);
            FindClose(_stack.data[$-1].h);
            _stack.shrinkTo(_stack.data.length-1);
        }

        void releaseDirStack()
        {
            foreach( d;  _stack.data)
                FindClose(d.h);
        }

        bool mayStepIn()
        {
            return _followSymlink ? _cur.isDir : _cur.isDir && !_cur.isSymlink;
        }
    }
    else version(Posix)
    {
        struct DirHandle
        {
            string dirpath;
            DIR*   h;
        }

        bool stepIn(string directory)
        {
            auto h = cenforce(opendir(toStringz(directory)), directory);
            _stack.put(DirHandle(directory, h));
            return next();
        }

        bool next()
        {
            if(_stack.data.empty)
                return false;
            for(dirent* fdata; (fdata = readdir(_stack.data[$-1].h)) != null; )
            {
                // Skip "." and ".."
                if(std.c.string.strcmp(fdata.d_name.ptr, ".")  &&
                   std.c.string.strcmp(fdata.d_name.ptr, "..") )
                {
                    _cur._init(_stack.data[$-1].dirpath, fdata);
                    return true;
                }
            }
            popDirStack();
            return false;
        }

        void popDirStack()
        {
            assert(!_stack.data.empty);
            closedir(_stack.data[$-1].h);
            _stack.shrinkTo(_stack.data.length-1);
        }

        void releaseDirStack()
        {
            foreach( d;  _stack.data)
                closedir(d.h);
        }

        bool mayStepIn()
        {
            return _followSymlink ? _cur.isDir : isDir(_cur.linkAttributes);
        }
    }

    this(string pathname, SpanMode mode, bool followSymlink)
    {
        _mode = mode;
        _followSymlink = followSymlink;
        _stack = appender(cast(DirHandle[])[]);
        if(_mode == SpanMode.depth)
            _stashed = appender(cast(DirEntry[])[]);
        if(stepIn(pathname))
        {
            if(_mode == SpanMode.depth)
                while(mayStepIn())
                {
                    auto thisDir = _cur;
                    if(stepIn(_cur.name))
                    {
                        pushExtra(thisDir);
                    }
                    else
                        break;
                }
        }
    }
    @property bool empty(){ return _stashed.data.empty && _stack.data.empty; }
    @property DirEntry front(){ return _cur; }
    void popFront()
    {
        switch(_mode)
        {
        case SpanMode.depth:
            if(next())
            {
                while(mayStepIn())
                {
                    auto thisDir = _cur;
                    if(stepIn(_cur.name))
                    {
                        pushExtra(thisDir);
                    }
                    else
                        break;
                }
            }
            else if(hasExtra())
                _cur = popExtra();
            break;
        case SpanMode.breadth:
            if(mayStepIn())
            {
                if(!stepIn(_cur.name))
                    while(!empty && !next()){}
            }
            else
                while(!empty && !next()){}
            break;
        default:
            next();
        }
    }

    ~this()
    {
        releaseDirStack();
    }
}

struct DirIterator
{
private:
    RefCounted!(DirIteratorImpl, RefCountedAutoInitialize.no) impl;
    this(string pathname, SpanMode mode, bool followSymlink)
    {
        impl = typeof(impl)(pathname, mode, followSymlink);
    }
public:
    @property bool empty(){ return impl.empty; }
    @property DirEntry front(){ return impl.front; }
    void popFront(){ impl.popFront(); }
    int opApply(int delegate(ref string name) dg)
    {
        foreach(DirEntry v; impl.refCountedPayload)
        {
            string s = v.name;
            if(dg(s))
                return 1;
        }
        return 0;
    }
    int opApply(int delegate(ref DirEntry name) dg)
    {
        foreach(DirEntry v; impl.refCountedPayload)
            if(dg(v))
                return 1;
        return 0;
    }
}
/++
    Returns an input range of DirEntry that lazily iterates a given directory,
    also provides two ways of foreach iteration. The iteration variable can be of
    type $(D_PARAM string) if only the name is needed, or $(D_PARAM DirEntry)
    if additional details are needed. The span mode dictates the how the
    directory is traversed. The name of the each directory entry iterated
    contains the absolute path.

    Params:
        path = The directory to iterate over.
        mode = Whether the directory's sub-directories should be iterated
               over depth-first ($(D_PARAM depth)), breadth-first
               ($(D_PARAM breadth)), or not at all ($(D_PARAM shallow)).
        followSymlink = Whether symbolic links which point to directories
                         should be treated as directories and their contents
                         iterated over.

Examples:
--------------------
// Iterate a directory in depth
foreach (string name; dirEntries("destroy/me", SpanMode.depth))
{
 remove(name);
}
// Iterate a directory in breadth
foreach (string name; dirEntries(".", SpanMode.breadth))
{
 writeln(name);
}
// Iterate a directory and get detailed info about it
foreach (DirEntry e; dirEntries("dmd-testing", SpanMode.breadth))
{
 writeln(e.name, "\t", e.size);
}
// Iterate over all *.d files in current directory and all its subdirectories
auto dFiles = filter!`endsWith(a.name,".d")`(dirEntries(".",SpanMode.depth));
foreach(d; dFiles)
    writeln(d.name);
// Hook it up with std.parallelism to compile them all in parallel:
foreach(d; parallel(dFiles, 1)) //passes by 1 file to each thread
{
    string cmd = "dmd -c "  ~ d.name;
    writeln(cmd);
    std.process.system(cmd);
}
--------------------
//
 +/
auto dirEntries(string path, SpanMode mode, bool followSymlink = true)
{
    return DirIterator(path, mode, followSymlink);
}

unittest
{
    string testdir = "deleteme.dmd.unittest.std.file"; // needs to be relative
    mkdirRecurse(buildPath(testdir, "somedir"));
    scope(exit) rmdirRecurse(testdir);
    write(buildPath(testdir, "somefile"), null);
    write(buildPath(testdir, "somedir", "somedeepfile"), null);

    // testing range interface
    size_t equalEntries(string relpath, SpanMode mode)
    {
        auto len = enforce(walkLength(dirEntries(absolutePath(relpath), mode)));
        assert(walkLength(dirEntries(relpath, mode)) == len);
        assert(equal(
                   map!(q{std.path.absolutePath(a.name)})(dirEntries(relpath, mode)),
                   map!(q{a.name})(dirEntries(absolutePath(relpath), mode))));
        return len;
    }

    assert(equalEntries(testdir, SpanMode.shallow) == 2);
    assert(equalEntries(testdir, SpanMode.depth) == 3);
    assert(equalEntries(testdir, SpanMode.breadth) == 3);

    // testing opApply
    foreach (string name; dirEntries(testdir, SpanMode.breadth))
    {
        //writeln(name);
        assert(name.startsWith(testdir));
    }
    foreach (DirEntry e; dirEntries(absolutePath(testdir), SpanMode.breadth))
    {
        //writeln(name);
        assert(e.isFile || e.isDir, e.name);
    }
}

/++
    Convenience wrapper for filtering file names with a glob pattern.

    Params:
        path = The directory to iterate over.
        pattern  = String with wildcards, such as $(RED "*.d"). The supported
                   wildcard strings are described under
                   $(XREF path, globMatch).
        mode = Whether the directory's sub-directories should be iterated
               over depth-first ($(D_PARAM depth)), breadth-first
               ($(D_PARAM breadth)), or not at all ($(D_PARAM shallow)).
        followSymlink = Whether symbolic links which point to directories
                         should be treated as directories and their contents
                         iterated over.

Examples:
--------------------
// Iterate over all D source files in current directory and all its
// subdirectories
auto dFiles = dirEntries(".","*.{d,di}",SpanMode.depth);
foreach(d; dFiles)
    writeln(d.name);
--------------------
//
 +/
auto dirEntries(string path, string pattern, SpanMode mode,
    bool followSymlink = true)
{
    bool f(DirEntry de) { return globMatch(baseName(de.name), pattern); }
    return filter!f(DirIterator(path, mode, followSymlink));
}

/++
    Returns a DirEntry for the given file (or directory).

    Params:
        name = The file (or directory) to get a DirEntry for.

    Throws:
        $(D FileException) if the file does not exist.
 +/
DirEntry dirEntry(in char[] name)
{
    if(!name.exists)
        throw new FileException(text("File ", name, " does not exist."));

    DirEntry dirEntry;

    dirEntry._init(name);

    return dirEntry;
}

//Test dirEntry with a directory.
unittest
{
    auto before = Clock.currTime();
    Thread.sleep(dur!"seconds"(2));
    immutable path = deleteme ~ "_dir";
    scope(exit) { if(path.exists) rmdirRecurse(path); }

    mkdir(path);
    Thread.sleep(dur!"seconds"(2));
    auto de = dirEntry(path);
    assert(de.name == path);
    assert(de.isDir);
    assert(!de.isFile);
    assert(!de.isSymlink);

    assert(de.isDir == path.isDir);
    assert(de.isFile == path.isFile);
    assert(de.isSymlink == path.isSymlink);
    assert(de.size == path.getSize());
    assert(de.attributes == getAttributes(path));
    assert(de.linkAttributes == getLinkAttributes(path));

    auto now = Clock.currTime();
    scope(failure) writefln("[%s] [%s] [%s] [%s]", before, de.timeLastAccessed, de.timeLastModified, now);
    assert(de.timeLastAccessed > before);
    assert(de.timeLastAccessed < now);
    assert(de.timeLastModified > before);
    assert(de.timeLastModified < now);

    assert(isDir(de.attributes));
    assert(isDir(de.linkAttributes));
    assert(!isFile(de.attributes));
    assert(!isFile(de.linkAttributes));
    assert(!attrIsSymlink(de.attributes));
    assert(!attrIsSymlink(de.linkAttributes));

    version(Windows)
    {
        assert(de.timeCreated > before);
        assert(de.timeCreated < now);
    }
    else version(Posix)
    {
        assert(de.timeStatusChanged > before);
        assert(de.timeStatusChanged < now);
        assert(de.attributes == de.statBuf.st_mode);
    }
}

//Test dirEntry with a file.
unittest
{
    auto before = Clock.currTime();
    Thread.sleep(dur!"seconds"(2));
    immutable path = deleteme ~ "_file";
    scope(exit) { if(path.exists) remove(path); }

    write(path, "hello world");
    Thread.sleep(dur!"seconds"(2));
    auto de = dirEntry(path);
    assert(de.name == path);
    assert(!de.isDir);
    assert(de.isFile);
    assert(!de.isSymlink);

    assert(de.isDir == path.isDir);
    assert(de.isFile == path.isFile);
    assert(de.isSymlink == path.isSymlink);
    assert(de.size == path.getSize());
    assert(de.attributes == getAttributes(path));
    assert(de.linkAttributes == getLinkAttributes(path));

    auto now = Clock.currTime();
    scope(failure) writefln("[%s] [%s] [%s] [%s]", before, de.timeLastAccessed, de.timeLastModified, now);
    assert(de.timeLastAccessed > before);
    assert(de.timeLastAccessed < now);
    assert(de.timeLastModified > before);
    assert(de.timeLastModified < now);

    assert(!isDir(de.attributes));
    assert(!isDir(de.linkAttributes));
    assert(isFile(de.attributes));
    assert(isFile(de.linkAttributes));
    assert(!isSymLink(de.attributes));
    assert(!isSymLink(de.linkAttributes));

    version(Windows)
    {
        assert(de.timeCreated > before);
        assert(de.timeCreated < now);
    }
    else version(Posix)
    {
        assert(de.timeStatusChanged > before);
        assert(de.timeStatusChanged < now);
        assert(de.attributes == de.statBuf.st_mode);
    }
}

//Test dirEntry with a symlink to a directory.
version(linux) unittest
{
    auto before = Clock.currTime();
    Thread.sleep(dur!"seconds"(2));
    immutable orig = deleteme ~ "_dir";
    mkdir(orig);
    immutable path = deleteme ~ "_slink";
    scope(exit) { if(orig.exists) rmdirRecurse(orig); }
    scope(exit) { if(path.exists) remove(path); }

    core.sys.posix.unistd.symlink((orig ~ "\0").ptr, (path ~ "\0").ptr);
    Thread.sleep(dur!"seconds"(2));
    auto de = dirEntry(path);
    assert(de.name == path);
    assert(de.isDir);
    assert(!de.isFile);
    assert(de.isSymlink);

    assert(de.isDir == path.isDir);
    assert(de.isFile == path.isFile);
    assert(de.isSymlink == path.isSymlink);
    assert(de.size == path.getSize());
    assert(de.attributes == getAttributes(path));
    assert(de.linkAttributes == getLinkAttributes(path));

    auto now = Clock.currTime();
    scope(failure) writefln("[%s] [%s] [%s] [%s]", before, de.timeLastAccessed, de.timeLastModified, now);
    assert(de.timeLastAccessed > before);
    assert(de.timeLastAccessed < now);
    assert(de.timeLastModified > before);
    assert(de.timeLastModified < now);

    assert(isDir(de.attributes));
    assert(!isDir(de.linkAttributes));
    assert(!isFile(de.attributes));
    assert(!isFile(de.linkAttributes));
    assert(!attrIsSymlink(de.attributes));
    assert(attrIsSymlink(de.linkAttributes));

    assert(de.timeStatusChanged > before);
    assert(de.timeStatusChanged < now);
    assert(de.attributes == de.statBuf.st_mode);
}

//Test dirEntry with a symlink to a file.
version(linux) unittest
{
    auto before = Clock.currTime();
    Thread.sleep(dur!"seconds"(2));
    immutable orig = deleteme ~ "_file";
    write(orig, "hello world");
    immutable path = deleteme ~ "_slink";
    scope(exit) { if(orig.exists) remove(orig); }
    scope(exit) { if(path.exists) remove(path); }

    core.sys.posix.unistd.symlink((orig ~ "\0").ptr, (path ~ "\0").ptr);
    Thread.sleep(dur!"seconds"(2));
    auto de = dirEntry(path);
    assert(de.name == path);
    assert(!de.isDir);
    assert(de.isFile);
    assert(de.isSymlink);

    assert(de.isDir == path.isDir);
    assert(de.isFile == path.isFile);
    assert(de.isSymlink == path.isSymlink);
    assert(de.size == path.getSize());
    assert(de.attributes == getAttributes(path));
    assert(de.linkAttributes == getLinkAttributes(path));

    auto now = Clock.currTime();
    scope(failure) writefln("[%s] [%s] [%s] [%s]", before, de.timeLastAccessed, de.timeLastModified, now);
    assert(de.timeLastAccessed > before);
    assert(de.timeLastAccessed < now);
    assert(de.timeLastModified > before);
    assert(de.timeLastModified < now);

    assert(!isDir(de.attributes));
    assert(!isDir(de.linkAttributes));
    assert(isFile(de.attributes));
    assert(!isFile(de.linkAttributes));
    assert(!attrIsSymlink(de.attributes));
    assert(attrIsSymlink(de.linkAttributes));

    assert(de.timeStatusChanged > before);
    assert(de.timeStatusChanged < now);
    assert(de.attributes == de.statBuf.st_mode);
}


/**
Reads an entire file into an array.

Example:
----
// Load file; each line is an int followed by comma, whitespace and a
// double.
auto a = slurp!(int, double)("filename", "%s, %s");
----
 */
Select!(Types.length == 1, Types[0][], Tuple!(Types)[])
slurp(Types...)(string filename, in char[] format)
{
    typeof(return) result;
    auto app = appender!(typeof(return))();
    ElementType!(typeof(return)) toAdd;
    auto f = File(filename);
    scope(exit) f.close;
    foreach (line; f.byLine())
    {
        formattedRead(line, format, &toAdd);
        enforce(line.empty,
                text("Trailing characters at the end of line: `", line,
                        "'"));
        app.put(toAdd);
    }
    return app.data;
}

unittest
{
    // Tuple!(int, double)[] x;
    // auto app = appender(&x);
    write(deleteme, "12 12.25\n345 1.125");
    scope(exit) { assert(exists(deleteme)); remove(deleteme); }
    auto a = slurp!(int, double)(deleteme, "%s %s");
    assert(a.length == 2);
    assert(a[0] == tuple(12, 12.25));
    assert(a[1] == tuple(345, 1.125));
}


/++
    $(RED Scheduled for deprecation in November 2011.
          Please use $(D dirEntries) instead.)

    Returns the contents of the given directory.

    The names in the contents do not include the pathname.

    Throws:
        $(D FileException) on error.

Examples:
    This program lists all the files and subdirectories in its
    path argument.
--------------------
import std.stdio;
import std.file;

void main(string[] args)
{
    auto dirs = std.file.listDir(args[1]);

    foreach(d; dirs)
        writefln(d);
}
--------------------
 +/
string[] listDir(C)(in C[] pathname)
{
    auto result = appender!(string[])();

    bool listing(string filename)
    {
        result.put(filename);
        return true; // continue
    }

    _listDir(pathname, &listing);

    return result.data;
}

unittest
{
    assert(listDir(".").length > 0);
}


/++
    $(RED Scheduled for deprecation in November 2011.
          Please use $(D dirEntries) instead.)

    Returns all the files in the directory and its sub-directories
    which match pattern or regular expression r.

    Params:
        pathname = The path of the directory to search.
        pattern  = String with wildcards, such as $(RED "*.d"). The supported
                   wildcard strings are described under fnmatch() in
                   $(LINK2 std_path.html, std.path).
        r        = Regular expression, for more powerful pattern matching.
        followSymlink = Whether symbolic links which point to directories
                         should be treated as directories and their contents
                         iterated over. Ignored on Windows.

Examples:
    This program lists all the files with a "d" extension in
    the path passed as the first argument.
--------------------
import std.stdio;
import std.file;

void main(string[] args)
{
  auto d_source_files = std.file.listDir(args[1], "*.d");

  foreach(d; d_source_files)
      writefln(d);
}
--------------------

    A regular expression version that searches for all files with "d" or
    "obj" extensions:
--------------------
import std.stdio;
import std.file;
import std.regexp;

void main(string[] args)
{
  auto d_source_files = std.file.listDir(args[1], RegExp(r"\.(d|obj)$"));

  foreach(d; d_source_files)
      writefln(d);
}
--------------------
 +/
string[] listDir(C, U)(in C[] pathname, U filter, bool followSymlink = true)
    if(is(C : char) && !is(U: bool delegate(string filename)))
{
    import std.regexp;
    auto result = appender!(string[])();
    bool callback(DirEntry* de)
    {
        if(followSymlink ? de.isDir : isDir(de.linkAttributes))
        {
            _listDir(de.name, &callback);
        }
        else
        {
            static if(is(U : const(C[])))
            {//pattern version
                if(std.path.fnmatch(de.name, filter))
                    result.put(de.name);
            }
            else static if(is(U : RegExp))
            {//RegExp version

                if(filter.test(de.name))
                    result.put(de.name);
            }
            else
                static assert(0,"There is no version of listDir that takes " ~ U.stringof);
        }
        return true; // continue
    }

    _listDir(pathname, &callback);

    return result.data;
}

/******************************************************
 * $(RED Scheduled for deprecation in November 2011.
 *       Please use $(D dirEntries) instead.)
 *
 * For each file and directory name in pathname[],
 * pass it to the callback delegate.
 *
 * Params:
 *        callback =        Delegate that processes each
 *                        filename in turn. Returns true to
 *                        continue, false to stop.
 * Example:
 *        This program lists all the files in its
 *        path argument, including the path.
 * ----
 * import std.stdio;
 * import std.path;
 * import std.file;
 *
 * void main(string[] args)
 * {
 *    auto pathname = args[1];
 *    string[] result;
 *
 *    bool listing(string filename)
 *    {
 *      result ~= buildPath(pathname, filename);
 *      return true; // continue
 *    }
 *
 *    listdir(pathname, &listing);
 *
 *    foreach (name; result)
 *      writefln("%s", name);
 * }
 * ----
 */
void listDir(C, U)(in C[] pathname, U callback)
    if(is(C : char) && is(U: bool delegate(string filename)))
{
    _listDir(pathname, callback);
}


//==============================================================================
// Private Section.
//==============================================================================
private:


void _listDir(in char[] pathname, bool delegate(string filename) callback)
{
    bool listing(DirEntry* de)
    {
        return callback(de.name.baseName);
    }

    _listDir(pathname, &listing);
}


version(Windows)
{
    void _listDir(in char[] pathname, bool delegate(DirEntry* de) callback)
    {
        DirEntry de;
        auto c = buildPath(pathname, "*.*");

        if(useWfuncs)
        {
            WIN32_FIND_DATAW fileinfo;

            auto h = FindFirstFileW(std.utf.toUTF16z(c), &fileinfo);
            if(h == INVALID_HANDLE_VALUE)
                return;

            scope(exit) FindClose(h);

            do
            {
                // Skip "." and ".."
                if(std.string.wcscmp(fileinfo.cFileName.ptr, ".") == 0 ||
                   std.string.wcscmp(fileinfo.cFileName.ptr, "..") == 0)
                {
                    continue;
                }

                de._init(pathname, &fileinfo);

                if(!callback(&de))
                    break;

            } while(FindNextFileW(h, &fileinfo) != FALSE);
        }
        else
        {
            WIN32_FIND_DATA fileinfo;

            auto h = FindFirstFileA(toMBSz(c), &fileinfo);

            if(h == INVALID_HANDLE_VALUE)
                return;

            scope(exit) FindClose(h);

            do
            {
                // Skip "." and ".."
                if(std.c.string.strcmp(fileinfo.cFileName.ptr, ".") == 0 ||
                   std.c.string.strcmp(fileinfo.cFileName.ptr, "..") == 0)
                {
                    continue;
                }

                de._init(pathname, &fileinfo);

                if(!callback(&de))
                    break;

            } while(FindNextFileA(h, &fileinfo) != FALSE);
        }
    }
}
else version(Posix)
{
    void _listDir(in char[] pathname, bool delegate(DirEntry* de) callback)
    {
        auto h = cenforce(opendir(toStringz(pathname)), pathname);
        scope(exit) closedir(h);

        DirEntry de;

        for(dirent* fdata; (fdata = readdir(h)) != null; )
        {
            // Skip "." and ".."
            if(!std.c.string.strcmp(fdata.d_name.ptr, ".") ||
               !std.c.string.strcmp(fdata.d_name.ptr, ".."))
            {
                continue;
            }

            de._init(pathname, fdata);

            if(!callback(&de))
                break;
        }
    }
}


//==============================================================================
// Stuff from std.date so that we don't have to import std.date and end up with
// the "scheduled for deprecation" pragma message from std.date showing up just
// because someone imports std.file.
//
// These will be removed either when the functions in std.file which use them
// are removed.
//==============================================================================
//

deprecated alias long d_time;
deprecated enum d_time d_time_nan = long.min;
deprecated enum ticksPerSecond = 1000;

version(Windows)
{
    deprecated d_time FILETIME2d_time(const FILETIME *ft)
    {
        auto sysTime = FILETIMEToSysTime(ft);

        return sysTimeToDTime(sysTime);
    }
}


template hardDeprec(string vers, string date, string oldFunc, string newFunc)
{
    enum hardDeprec = Format!("Notice: As of Phobos %s, std.file.%s has been deprecated " ~
                              "It will be removed in %s. Please use std.file.%s instead.",
                              vers, oldFunc, date, newFunc);
}
