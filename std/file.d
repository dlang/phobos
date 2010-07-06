// Written in the D programming language.

/**
Utilities for manipulating files and scanning directories.

Macros:
 WIKI = Phobos/StdFile

Copyright: Copyright Digital Mars 2007 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu)

         Copyright Digital Mars 2007 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.file;

import core.memory;
import core.stdc.stdio, core.stdc.stdlib, core.stdc.string,
    core.stdc.errno, std.algorithm, std.array,
    std.conv, std.date, std.exception, std.format, std.path, std.process,
    std.range, std.regexp, std.stdio, std.string, std.traits, std.typecons,
    std.typetuple, std.utf;
version (Win32)
{
    import core.sys.windows.windows, std.windows.charset,
        std.windows.syserror, std.__fileinit;
/*
 * Since Win 9x does not support the "W" API's, first convert
 * to wchar, then convert to multibyte using the current code
 * page.
 * (Thanks to yaneurao for this)
 */
    version(Windows) alias std.windows.charset.toMBSz toMBSz;
    shared bool useWfuncs = true;        // initialized in std.__fileinit
}
version (Posix)
{
    import core.sys.posix.dirent, core.sys.posix.fcntl, core.sys.posix.sys.stat,
        core.sys.posix.sys.time, core.sys.posix.unistd, core.sys.posix.utime;
}

// @@@@ TEMPORARY - THIS SHOULD BE IN THE CORE @@@
// {{{
version (Posix)
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
    }
    else version (FreeBSD)
    {
        alias core.sys.posix.sys.stat.stat_t struct_stat64;
        alias core.sys.posix.sys.stat.fstat  fstat64;
        alias core.sys.posix.sys.stat.stat   stat64;
    }
    else
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

        extern(C) int fstat64(int, struct_stat64*);
        extern(C) int stat64(in char*, struct_stat64*);
    }
}
// }}}

/***********************************
 * Exception thrown for file I/O errors.
 */

class FileException : Exception
{
/**
OS error code.
 */
    immutable uint errno;

/**
Constructor taking the name of the file where error happened and a
message describing the error.
 */
    this(in char[] name, in char[] message)
    {
        super(text(name, ": ", message));
        errno = 0;
    }

    this(in char[] name, in char[] message, string sourceFile, int sourceLine)
    {
        super(text(name, ": ", message), sourceFile, sourceLine);
        errno = 0;
    }

/**
Constructor taking the name of the file where error happened and the
error number ($(LUCKY GetLastError) in Windows, $(D getErrno) in
Posix).
 */
    version(Windows) this(in char[] name, uint errno = GetLastError)
    {
        this(name, sysErrorString(errno));
        this.errno = errno;
    }

    version(Posix) this(in char[] name, uint errno = .getErrno)
    {
        auto s = strerror(errno);
        this(name, to!string(s));
        this.errno = errno;
    }

    version(Windows) this(in char[] name, string sourceFile, int sourceLine,
        uint errno = GetLastError)
    {
        this(name, sysErrorString(errno), sourceFile, sourceLine);
        this.errno = errno;
    }

    version(Posix) this(in char[] name, string sourceFile, int sourceLine,
        uint errno = .getErrno)
    {
        auto s = strerror(errno);
        this(name, to!string(s), sourceFile, sourceLine);
        this.errno = errno;
    }
}

private T cenforce(T, string file = __FILE__, uint line = __LINE__)
(T condition, lazy const(char)[] name)
{
    if (!condition)
    {
        throw new FileException(name, file, line);
    }
    return condition;
}

/* **********************************
 * Basic File operations.
 */

/********************************************
Read entire contents of file $(D name).

Returns: Untyped array of bytes _read.

Throws: $(D FileException) on error.
 */

version(Windows) void[] read(in char[] name, size_t upTo = size_t.max)
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
    auto buf = GC.malloc(size, GC.BlkAttr.NO_SCAN)[0 .. size];
    scope(failure) delete buf;

    DWORD numread = void;
    cenforce(ReadFile(h,buf.ptr, size, &numread, null) == 1
            && numread == size, name);
    return buf[0 .. size];
}

version(Posix) void[] read(in char[] name, in size_t upTo = size_t.max)
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
    auto result = GC.malloc(initialAlloc, GC.BlkAttr.NO_SCAN)
        [0 .. initialAlloc];
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

unittest
{
    write("std.file.deleteme", "1234");
    assert(read("std.file.deleteme", 2) == "12");
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

Throws: $(D FileException) on file error, $(D UtfException) on UTF
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
    enforce(std.process.system("echo abc>deleteme") == 0);
    scope(exit) remove("deleteme");
    enforce(chomp(readText("deleteme")) == "abc");
}

/*********************************************
 * Write $(D buffer) to file $(D name).
 * Throws: $(D FileException) on error.
 */

version(Windows) void write(in char[] name, const void[] buffer)
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
    cenforce(WriteFile(h, buffer.ptr, buffer.length, &numwritten, null) == 1
            && buffer.length == numwritten,
            name);
}

version(Posix) void write(in char[] name, in void[] buffer)
{
    return writeImpl(name, buffer, O_CREAT | O_WRONLY | O_TRUNC);
}

/*********************************************
 * Append $(D buffer) to file $(D name).
 * Throws: $(D FileException) on error.
 */

version(Windows) void append(in char[] name, in void[] buffer)
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
            && WriteFile(h,buffer.ptr,buffer.length,&numwritten,null) == 1
            && buffer.length == numwritten,
            name);
}

version(Posix) void append(in char[] name, in void[] buffer)
{
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

version(Windows) void rename(in char[] from, in char[] to)
{
    enforce(useWfuncs
            ? MoveFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to))
            : MoveFileA(toMBSz(from), toMBSz(to)),
            new FileException(
                text("Attempting to rename file ", from, " to ",
                        to)));
}

version(Posix) void rename(in char[] from, in char[] to)
{
    cenforce(std.c.stdio.rename(toStringz(from), toStringz(to)) == 0, to);
}

/***************************************************
Delete file $(D name).
Throws: $(D FileException) on error.
 */

version(Windows) void remove(in char[] name)
{
    cenforce(useWfuncs
            ? DeleteFileW(std.utf.toUTF16z(name))
            : DeleteFileA(toMBSz(name)),
            name);
}

version(Posix) void remove(in char[] name)
{
    cenforce(std.c.stdio.remove(toStringz(name)) == 0, name);
}

/***************************************************
Get size of file $(D name).

Throws: $(D FileException) on error (e.g., file not found).
 */

version(Windows) ulong getSize(in char[] name)
{
    HANDLE findhndl = void;
    uint resulth = void;
    uint resultl = void;

    if (useWfuncs)
    {
        WIN32_FIND_DATAW filefindbuf;

        findhndl = FindFirstFileW(std.utf.toUTF16z(name), &filefindbuf);
        resulth = filefindbuf.nFileSizeHigh;
        resultl = filefindbuf.nFileSizeLow;
    }
    else
    {
        WIN32_FIND_DATA filefindbuf;

        findhndl = FindFirstFileA(toMBSz(name), &filefindbuf);
        resulth = filefindbuf.nFileSizeHigh;
        resultl = filefindbuf.nFileSizeLow;
    }

    cenforce(findhndl != cast(HANDLE)-1 && FindClose(findhndl), name);
    return (cast(ulong) resulth << 32) + resultl;
}

version(Posix) ulong getSize(in char[] name)
{
    struct_stat64 statbuf = void;
    cenforce(stat64(toStringz(name), &statbuf) == 0, name);
    return statbuf.st_size;
}

unittest
{
    version(Windows)
        auto deleteme = std.path.join(std.process.getenv("TEMP"), "deleteme");
    else
        auto deleteme = "/tmp/deleteme";
    scope(exit) if (exists(deleteme)) remove(deleteme);
    // create a file of size 1
    write(deleteme, "a");
    assert(getSize(deleteme) == 1);
    // create a file of size 3
    write(deleteme, "abc");
    assert(getSize(deleteme) == 3);
}

/*************************
 * Get creation/access/modified times of file $(D name).
 * Throws: $(D FileException) on error.
 */

version(Windows) void getTimes(in char[] name,
        out d_time ftc, out d_time fta, out d_time ftm)
{
    HANDLE findhndl = void;

    if (useWfuncs)
    {
        WIN32_FIND_DATAW filefindbuf;

        findhndl = FindFirstFileW(std.utf.toUTF16z(name), &filefindbuf);
        ftc = std.date.FILETIME2d_time(&filefindbuf.ftCreationTime);
        fta = std.date.FILETIME2d_time(&filefindbuf.ftLastAccessTime);
        ftm = std.date.FILETIME2d_time(&filefindbuf.ftLastWriteTime);
    }
    else
    {
        WIN32_FIND_DATA filefindbuf;

        findhndl = FindFirstFileA(toMBSz(name), &filefindbuf);
        ftc = std.date.FILETIME2d_time(&filefindbuf.ftCreationTime);
        fta = std.date.FILETIME2d_time(&filefindbuf.ftLastAccessTime);
        ftm = std.date.FILETIME2d_time(&filefindbuf.ftLastWriteTime);
    }

    if (findhndl == cast(HANDLE)-1)
    {
        throw new FileException(name.idup);
    }
    FindClose(findhndl);
}

version(Posix) void getTimes(in char[] name,
        out d_time ftc, out d_time fta, out d_time ftm)
{
    struct_stat64 statbuf = void;
    cenforce(stat64(toStringz(name), &statbuf) == 0, name);
    ftc = cast(d_time) statbuf.st_ctime * std.date.ticksPerSecond;
    fta = cast(d_time) statbuf.st_atime * std.date.ticksPerSecond;
    ftm = cast(d_time) statbuf.st_mtime * std.date.ticksPerSecond;
}

/*
Get creation/access/modified times of file $(D name) as a tuple.

Throws: $(D FileException) on error.
 */

// Tuple!(d_time, "ftc", d_time, "fta", d_time, "ftm") getTimes(in char[] name)
// {
//     typeof(return) result = void;
//     getTimes(name, result.ftc, result.fta, result.ftm);
//     return result;
// }

// unittest
// {
//     auto t = getTimes(".").ftm;
// }

/**
   Returns the time of the last modification of file $(D name). If the
   file does not exist, throws a $(D FileException).
*/

version(Windows) d_time lastModified(in char[] name)
{
    d_time dummy = void, ftm = void;
    getTimes(name, dummy, dummy, ftm);
    return ftm;
}

version(Posix) d_time lastModified(in char[] name)
{
    struct_stat64 statbuf = void;
    cenforce(stat64(toStringz(name), &statbuf) == 0, name);
    return cast(d_time) statbuf.st_mtime * std.date.ticksPerSecond;
}

/**
Returns the time of the last modification of file $(D name). If the
file does not exist, returns $(D returnIfMissing).

A frequent usage pattern occurs in build automation tools such as
$(WEB gnu.org/software/make, make) or $(WEB
en.wikipedia.org/wiki/Apache_Ant, ant). To check whether file $(D
target) must be rebuilt from file $(D source) (i.e., $(D target) is
older than $(D source) or does not exist), use the comparison
below. The code throws a $(D FileException) if $(D source) does not
exist (as it should). On the other hand, the $(D d_time.min) default
makes a non-existing $(D target) seem infinitely old so the test
correctly prompts building it.

----
if (lastModified(source) >= lastModified(target, d_time.min))
{
    // must (re)build
}
else
{
    // target is up-to-date
}
----
*/

version(Windows) d_time lastModified(in char[] name, d_time returnIfMissing)
{
    if (!exists(name)) return returnIfMissing;
    d_time dummy = void, ftm = void;
    getTimes(name, dummy, dummy, ftm);
    return ftm;
}

version(Posix) d_time lastModified(in char[] name, d_time returnIfMissing)
{
    struct_stat64 statbuf = void;
    return stat64(toStringz(name), &statbuf) != 0
        ? returnIfMissing
        : cast(d_time) statbuf.st_mtime * std.date.ticksPerSecond;
}

unittest
{
    std.process.system("echo a>deleteme") == 0 || assert(false);
    scope(exit) remove("deleteme");
    assert(lastModified("deleteme") >
            lastModified("this file does not exist", d_time.min));
    //assert(lastModified("deleteme") > lastModified(__FILE__));
}

/***************************************************
 * Does file (or directory) $(D name) exist?
 */

version(Windows) bool exists(in char[] name)
{
    auto result = useWfuncs
// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/
// fileio/base/getfileattributes.asp
        ? GetFileAttributesW(std.utf.toUTF16z(name))
        : GetFileAttributesA(toMBSz(name));
    return result != 0xFFFFFFFF;
}

version(Posix) bool exists(in char[] name)
{
    return access(toStringz(name), 0) == 0;
}

unittest
{
    assert(exists("."));
    assert(!exists("this file does not exist"));
    std.process.system("echo a >deleteme") == 0 || assert(false);
    scope(exit) remove("deleteme");
    assert(exists("deleteme"));
}

/***************************************************
Get file $(D name) attributes.

Throws: $(D FileException) on error.
 */

version(Windows) uint getAttributes(in char[] name)
{
    auto result = useWfuncs
        ? GetFileAttributesW(std.utf.toUTF16z(name))
        : GetFileAttributesA(toMBSz(name));
    enforce(result != uint.max,
            new FileException(name.idup));
    return result;
}

version(Posix) uint getAttributes(in char[] name)
{
    struct_stat64 statbuf = void;
    cenforce(stat64(toStringz(name), &statbuf) == 0, name);
    return statbuf.st_mode;
}

/****************************************************
 * Is $(D name) a directory?
 * Throws: $(D FileException) if $(D name) doesn't exist.
 */

version(Windows) bool isdir(in char[] name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

version(Posix) bool isdir(in char[] name)
{
    return (getAttributes(name) & S_IFMT) == S_IFDIR;
}

/****************************************************
 * Is $(D name) a file?
 * Throws: $(D FileException) if $(D name) doesn't exist.
 */

version(Windows) bool isfile(in char[] name)
{
    return !isdir(name);
}

version(Posix) bool isfile(in char[] name)
{
    return (getAttributes(name) & S_IFMT) == S_IFREG;        // regular file
}

/****************************************************
 * Change directory to $(D pathname).
 * Throws: $(D FileException) on error.
 */

version(Windows) void chdir(in char[] pathname)
{
    enforce(useWfuncs
            ? SetCurrentDirectoryW(std.utf.toUTF16z(pathname))
            : SetCurrentDirectoryA(toMBSz(pathname)),
            new FileException(pathname.idup));
}

version(Posix) void chdir(in char[] pathname)
{
    cenforce(core.sys.posix.unistd.chdir(toStringz(pathname)) == 0,
            pathname);
}

/****************************************************
Make directory $(D pathname).

Throws: $(D FileException) on error.
 */

version(Windows) void mkdir(in char[] pathname)
{
    enforce(useWfuncs
            ? CreateDirectoryW(std.utf.toUTF16z(pathname), null)
            : CreateDirectoryA(toMBSz(pathname), null),
            new FileException(pathname.idup));
}

version(Posix) void mkdir(in char[] pathname)
{
    cenforce(core.sys.posix.sys.stat.mkdir(toStringz(pathname), 0777) == 0,
            pathname);
}

/****************************************************
 * Make directory and all parent directories as needed.
 */

void mkdirRecurse(in char[] pathname)
{
    const left = dirname(pathname);
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
    mkdir(pathname);
}

/****************************************************
Remove directory $(D pathname).

Throws: $(D FileException) on error.
 */

version(Windows) void rmdir(in char[] pathname)
{
    cenforce(useWfuncs
            ? RemoveDirectoryW(std.utf.toUTF16z(pathname))
            : RemoveDirectoryA(toMBSz(pathname)),
            pathname);
}

version(Posix) void rmdir(in char[] pathname)
{
    cenforce(core.sys.posix.unistd.rmdir(toStringz(pathname)) == 0,
            pathname);
}

/****************************************************
 * Get current directory.
 * Throws: $(D FileException) on error.
 */

version(Windows) string getcwd()
{
    // A bit odd API: calling GetCurrentDirectory(0, null) returns
    // length including the \0, whereas calling with non-zero
    // params returns length excluding the \0.
    if (useWfuncs)
    {
        auto dir =
            new wchar[enforce(GetCurrentDirectoryW(0, null), "getcwd")];
        dir = dir[0 .. GetCurrentDirectoryW(dir.length, dir.ptr)];
        cenforce(dir.length, "getcwd");
        return to!string(dir);
    }
    else
    {
        auto dir =
            new char[enforce(GetCurrentDirectoryA(0, null), "getcwd")];
        dir = dir[0 .. GetCurrentDirectoryA(dir.length, dir.ptr)];
        cenforce(dir.length, "getcwd");
        return assumeUnique(dir);
    }
}

version(Posix) string getcwd()
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

/***************************************************
 * Directory Entry
 */

version(Windows) struct DirEntry
{
    string name;                        /// file or directory name
    ulong size = ~0UL;                        /// size of file in bytes
    d_time creationTime = d_time_nan;        /// time of file creation
    d_time lastAccessTime = d_time_nan;        /// time file was last accessed
    d_time lastWriteTime = d_time_nan;        /// time file was last written to
    uint attributes;                // Windows file attributes OR'd together

    void init(in char[] path, in WIN32_FIND_DATA *fd)
    {
        auto clength = std.c.string.strlen(fd.cFileName.ptr);

        // Convert cFileName[] to unicode
        const wlength = MultiByteToWideChar(0, 0, fd.cFileName.ptr,
                clength, null,0);
        auto wbuf = new wchar[wlength];
        const n = MultiByteToWideChar(0, 0, fd.cFileName.ptr, clength,
                wbuf.ptr, wlength);
        assert(n == wlength);
        // toUTF8() returns a new buffer
        name = std.path.join(path, std.utf.toUTF8(wbuf[0 .. wlength]));

        size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
        creationTime = std.date.FILETIME2d_time(&fd.ftCreationTime);
        lastAccessTime = std.date.FILETIME2d_time(&fd.ftLastAccessTime);
        lastWriteTime = std.date.FILETIME2d_time(&fd.ftLastWriteTime);
        attributes = fd.dwFileAttributes;
    }

    void init(in char[] path, in WIN32_FIND_DATAW *fd)
    {
        size_t clength = std.string.wcslen(fd.cFileName.ptr);
        name = std.path.join(path,
                std.utf.toUTF8(fd.cFileName[0 .. clength]));
        size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
        creationTime = std.date.FILETIME2d_time(&fd.ftCreationTime);
        lastAccessTime = std.date.FILETIME2d_time(&fd.ftLastAccessTime);
        lastWriteTime = std.date.FILETIME2d_time(&fd.ftLastWriteTime);
        attributes = fd.dwFileAttributes;
    }

    /****
     * Return $(D true) if DirEntry is a directory.
     */
    bool isdir() const
    {
        return (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    }

    /****
     * Return !=0 if DirEntry is a file.
     */
    bool isfile() const
    {
        return !isdir;
    }
}

version(Posix) struct DirEntry
{
    string name;                        /// file or directory name
    ulong _size = ~0UL;                        /// size of file in bytes
    d_time _creationTime = d_time_nan;        /// time of file creation
    d_time _lastAccessTime = d_time_nan; /// time file was last accessed
    d_time _lastWriteTime = d_time_nan;        /// time file was last written to
    ubyte d_type;
    struct_stat64 statbuf;
    bool didstat;                        // done lazy evaluation of stat()

    void init(in char[] path, core.sys.posix.dirent.dirent *fd)
    {
        immutable len = std.c.string.strlen(fd.d_name.ptr);
        name = std.path.join(path, fd.d_name[0 .. len].idup);
        d_type = fd.d_type;
        didstat = false;
    }

    bool isdir() const
    {
        return (d_type & DT_DIR) != 0;
    }

    bool isfile() const
    {
        return (d_type & DT_REG) != 0;
    }

    ulong size()
    {
        ensureStatDone;
        return _size;
    }

    d_time creationTime()
    {
        ensureStatDone;
        return _creationTime;
    }

    d_time lastAccessTime()
    {
        ensureStatDone;
        return _lastAccessTime;
    }

    d_time lastWriteTime()
    {
        ensureStatDone;
        return _lastWriteTime;
    }

    /* This is to support lazy evaluation, because doing stat's is
     * expensive and not always needed.
     */

    void ensureStatDone()
    {
        if (didstat) return;
        enforce(stat64(toStringz(name), &statbuf) == 0,
                "Failed to stat file `"~name~"'");
        _size = statbuf.st_size;
        _creationTime = cast(d_time)statbuf.st_ctime
            * std.date.ticksPerSecond;
        _lastAccessTime = cast(d_time)statbuf.st_atime
            * std.date.ticksPerSecond;
        _lastWriteTime = cast(d_time)statbuf.st_mtime
            * std.date.ticksPerSecond;
        didstat = true;
    }
}

/******************************************************
 * For each file and directory DirEntry in pathname[],
 * pass it to the callback delegate.
 *
 * Note:
 *
 * This function is being phased out. New code should use $(D_PARAM
 * dirEntries) (see below).
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
 *      if (de.isdir)
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

version(Windows) void listdir(in char[] pathname,
        bool delegate(DirEntry* de) callback)
{
    DirEntry de;
    auto c = std.path.join(pathname, "*.*");
    if (useWfuncs)
    {
        WIN32_FIND_DATAW fileinfo;

        auto h = FindFirstFileW(std.utf.toUTF16z(c), &fileinfo);
        if (h == INVALID_HANDLE_VALUE)
            return;
        scope(exit) FindClose(h);
        do
        {
            // Skip "." and ".."
            if (std.string.wcscmp(fileinfo.cFileName.ptr, ".") == 0 ||
                    std.string.wcscmp(fileinfo.cFileName.ptr, "..") == 0)
                continue;

            de.init(pathname, &fileinfo);
            if (!callback(&de))
                break;
        } while (FindNextFileW(h, &fileinfo) != FALSE);
    }
    else
    {
        WIN32_FIND_DATA fileinfo;

        auto h = FindFirstFileA(toMBSz(c), &fileinfo);
        if (h == INVALID_HANDLE_VALUE)
            return;

        scope(exit) FindClose(h);
        do
        {
            // Skip "." and ".."
            if (std.c.string.strcmp(fileinfo.cFileName.ptr, ".") == 0 ||
                    std.c.string.strcmp(fileinfo.cFileName.ptr, "..") == 0)
                continue;

            de.init(pathname, &fileinfo);
            if (!callback(&de))
                break;
        } while (FindNextFileA(h,&fileinfo) != FALSE);
    }
}

version(Posix) void listdir(in char[] pathname,
        bool delegate(DirEntry* de) callback)
{
    auto h = cenforce(opendir(toStringz(pathname)), pathname);
    scope(exit) closedir(h);
    DirEntry de;
    for (dirent* fdata; (fdata = readdir(h)) != null; )
    {
        // Skip "." and ".."
        if (!std.c.string.strcmp(fdata.d_name.ptr, ".") ||
                !std.c.string.strcmp(fdata.d_name.ptr, ".."))
            continue;
        de.init(pathname, fdata);
        if (!callback(&de))
            break;
    }
}

/***************************************************
Copy file $(D from) to file $(D to). File timestamps are preserved.
 */

version(Windows) void copy(in char[] from, in char[] to)
{
    immutable result = useWfuncs
        ? CopyFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to), false)
        : CopyFileA(toMBSz(from), toMBSz(to), false);
    if (!result)
        throw new FileException(to.idup);
}

version(Posix) void copy(in char[] from, in char[] to)
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

/*************************
 * Set access/modified times of file $(D name).
 * Throws: $(D FileException) on error.
 */

version(Windows) void setTimes(in char[] name, d_time fta, d_time ftm)
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

version(Posix) void setTimes(in char[] name, d_time fta, d_time ftm)
{
    timeval[2] t = void;
    t[0].tv_sec = to!int(fta / std.date.ticksPerSecond);
    t[0].tv_usec = cast(int)
        (cast(long) ((cast(double) fta / std.date.ticksPerSecond)
                * 1_000_000) % 1_000_000);
    t[1].tv_sec = to!int(ftm / std.date.ticksPerSecond);
    t[1].tv_usec = cast(int)
        (cast(long) ((cast(double) ftm / std.date.ticksPerSecond)
                * 1_000_000) % 1_000_000);
    enforce(utimes(toStringz(name), t) == 0);
}
/+
unittest
{
    system("echo a>deleteme") == 0 || assert(false);
    scope(exit) remove("deleteme");
    d_time ftc1, fta1, ftm1;
    getTimes("deleteme", ftc1, fta1, ftm1);
    enforce(collectException(setTimes("nonexistent", fta1, ftm1)));
    setTimes("deleteme", fta1 + 1000, ftm1 + 1000);
    d_time ftc2, fta2, ftm2;
    getTimes("deleteme", ftc2, fta2, ftm2);
    assert(fta1 + 1000 == fta2, text(fta1 + 1000, "!=", fta2));
    assert(ftm1 + 1000 == ftm2);
}
+/

/****************************************************
Remove directory and all of its content and subdirectories,
recursively.
 */

void rmdirRecurse(in char[] pathname)
{
    // all children, recursively depth-first
    foreach (DirEntry e; dirEntries(pathname.idup, SpanMode.depth))
    {
        e.isdir ? rmdir(e.name) : remove(e.name);
    }
    // the dir itself
    rmdir(pathname);
}

version(Windows) unittest
{
    auto d = r"\deleteme\a\b\c\d\e\f\g";
    mkdirRecurse(d);
    rmdirRecurse(r"\deleteme");
    enforce(!exists(r"\deleteme"));
}

version(Posix) unittest
{
    auto d = "/tmp/deleteme/a/b/c/d/e/f/g";
    enforce(collectException(mkdir(d)));
    mkdirRecurse(d);
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
    listdir (".", delegate bool (DirEntry * de)
    {
        auto s = std.string.format("%s : c %s, w %s, a %s", de.name,
                toUTCString (de.creationTime),
                toUTCString (de.lastWriteTime),
                toUTCString (de.lastAccessTime));
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

struct DirIterator
{
    string pathname;
    SpanMode mode;

    private int doIt(D)(D dg, DirEntry * de)
    {
        alias ParameterTypeTuple!(D) Parms;
        static if (is(Parms[0] : const(char)[]))
        {
            return dg(de.name);
        }
        else static if (is(Parms[0] : DirEntry))
        {
            return dg(*de);
        }
        else
        {
            static assert(false, "Dunno how to enumerate directory entries"
                          " against type " ~ Parms[0].stringof);
        }
    }

    int opApply(D)(scope D dg)
    {
        int result = 0;
        // worklist used only in breadth-first traversal
        string[] worklist = [ pathname ];

        bool callback(DirEntry* de)
        {
            switch (mode)
            {
            case SpanMode.shallow:
                result = doIt(dg, de);
                break;
            case SpanMode.breadth:
                result = doIt(dg, de);
                if (!result && de.isdir)
                {
                    worklist ~= de.name;
                }
                break;
            default:
                assert(mode == SpanMode.depth);
                if (de.isdir)
                {
                    listdir(de.name, &callback);
                }
                if (!result)
                {
                    result = doIt(dg, de);
                }
                break;
            }
            return result == 0;
        }
        // consume the worklist
        while (worklist.length)
        {
            auto listThis = worklist[$ - 1];
            worklist.length = worklist.length - 1;
            listdir(listThis, &callback);
        }
        return result;
    }
}

/**
 * Iterates a directory using foreach. The iteration variable can be
 * of type $(D_PARAM string) if only the name is needed, or $(D_PARAM
 * DirEntry) if additional details are needed. The span mode dictates
 * the how the directory is traversed. The name of the directory entry
 * includes the $(D_PARAM path) prefix.
 *
 * Example:
 *
 * ----
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
 * ----
 */

DirIterator dirEntries(string path, SpanMode mode)
{
    DirIterator result;
    result.pathname = path;
    result.mode = mode;
    return result;
}

unittest
{
    version (linux)
    {
        assert(std.process.system("mkdir --parents dmd-testing") == 0);
        scope(exit) std.process.system("rm -rf dmd-testing");
        assert(std.process.system("mkdir --parents dmd-testing/somedir") == 0);
        assert(std.process.system("touch dmd-testing/somefile") == 0);
        assert(std.process.system("touch dmd-testing/somedir/somedeepfile")
                == 0);
        foreach (string name; dirEntries("dmd-testing", SpanMode.shallow))
        {
        }
        foreach (string name; dirEntries("dmd-testing", SpanMode.depth))
        {
            //writeln(name);
        }
        foreach (string name; dirEntries("dmd-testing", SpanMode.breadth))
        {
            //writeln(name);
        }
        foreach (DirEntry e; dirEntries("dmd-testing", SpanMode.breadth))
        {
            //writeln(e.name);
        }
    }
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
    auto app = appender(&result);
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
    return result;
}

unittest
{
    // Tuple!(int, double)[] x;
    // auto app = appender(&x);
    write("deleteme", "12 12.25\n345 1.125");
    scope(exit) remove("deleteme");
    auto a = slurp!(int, double)("deleteme", "%s %s");
    assert(a.length == 2);
    assert(a[0] == tuple(12, 12.25));
    assert(a[1] == tuple(345, 1.125));
}

/***************************************************
 * Return contents of directory pathname[].
 * The names in the contents do not include the pathname.
 * Throws: $(D FileException) on error
 * Example:
 *        This program lists all the files and subdirectories in its
 *        path argument.
 * ----
 * import std.stdio;
 * import std.file;
 *
 * void main(string[] args)
 * {
 *    auto dirs = std.file.listdir(args[1]);
 *
 *    foreach (d; dirs)
 *        writefln(d);
 * }
 * ----
 */

string[] listdir(in char[] pathname)
{
    auto result = appender!(string[])();

    bool listing(string filename)
    {
        result.put(filename);
        return true; // continue
    }

    listdir(pathname, &listing);
    return result.data;
}

unittest
{
    assert(listdir(".").length > 0);
}

/*****************************************************
 * Return all the files in the directory and its subdirectories
 * that match pattern or regular expression r.
 * Params:
 *        pathname = Directory name
 *        pattern = String with wildcards, such as $(RED "*.d"). The supported
 *                wildcard strings are described under fnmatch() in
 *                $(LINK2 std_path.html, std.path).
 *        r = Regular expression, for more powerful _pattern matching.
 * Example:
 *        This program lists all the files with a "d" extension in
 *        the path passed as the first argument.
 * ----
 * import std.stdio;
 * import std.file;
 *
 * void main(string[] args)
 * {
 *    auto d_source_files = std.file.listdir(args[1], "*.d");
 *
 *    foreach (d; d_source_files)
 *        writefln(d);
 * }
 * ----
 * A regular expression version that searches for all files with "d" or
 * "obj" extensions:
 * ----
 * import std.stdio;
 * import std.file;
 * import std.regexp;
 *
 * void main(string[] args)
 * {
 *    auto d_source_files = std.file.listdir(args[1], RegExp(r"\.(d|obj)$"));
 *
 *    foreach (d; d_source_files)
 *        writefln(d);
 * }
 * ----
 */

string[] listdir(in char[] pathname, in char[] pattern)
{
    auto result = appender!(string[])();

    bool callback(DirEntry* de)
    {
        if (de.isdir)
            listdir(de.name, &callback);
        else
        {
            if (std.path.fnmatch(de.name, pattern))
                result.put(de.name);
        }
        return true; // continue
    }

    listdir(pathname, &callback);
    return result.data;
}

/** Ditto */

string[] listdir(in char[] pathname, RegExp r)
{
    auto result = appender!(string[])();

    bool callback(DirEntry* de)
    {
        if (de.isdir)
            listdir(de.name, &callback);
        else
        {
            if (r.test(de.name))
                result.put(de.name);
        }
        return true; // continue
    }

    listdir(pathname, &callback);
    return result.data;
}

/******************************************************
 * For each file and directory name in pathname[],
 * pass it to the callback delegate.
 *
 * Note:
 *
 * This function is being phased out. New code should use $(D_PARAM
 * dirEntries) (see below).
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
 *      result ~= std.path.join(pathname, filename);
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

void listdir(in char[] pathname, bool delegate(string filename) callback)
{
    bool listing(DirEntry* de)
    {
        return callback(std.path.getBaseName(de.name));
    }

    listdir(pathname, &listing);
}
