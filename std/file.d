// Written in the D programming language.

/**
Utilities for manipulating files and scanning directories. Functions
in this module handle files as a unit, e.g., read or write one _file
at a time. For opening files and manipulating them via handles refer
to module $(LINK2 std_stdio.html,$(D std.stdio)).

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


version (Windows)
{
    import core.sys.windows.windows, std.windows.syserror;
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
    import core.thread;

    private @property string deleteme()
    {
        static _deleteme = "deleteme.dmd.unittest.pid";
        static _first = true;

        if(_first)
        {
            _deleteme = buildPath(tempDir(), _deleteme) ~ to!string(getpid());
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

    // Required by tempPath():
    private extern(Windows) DWORD GetTempPathW(DWORD nBufferLength,
                                               LPWSTR lpBuffer);
    // Required by rename():
    enum MOVEFILE_REPLACE_EXISTING = 1;
    private extern(Windows) DWORD MoveFileExW(LPCWSTR lpExistingFileName,
                                              LPCWSTR lpNewFileName,
                                              DWORD dwFlags);
}
else version (Posix)
{
    deprecated alias stat_t struct_stat64;
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
        in Windows, $(D_PARAM errno) in Posix).

        Params:
            name = Name of file for which the error occurred.
            msg  = Message describing the error.
            file = The file where the error occurred.
            line = The line where the error occurred.
     +/
    version(Windows) this(in char[] name,
                          uint errno = .GetLastError(),
                          string file = __FILE__,
                          size_t line = __LINE__)
    {
        this(name, sysErrorString(errno), file, line);
        this.errno = errno;
    }
    else version(Posix) this(in char[] name,
                             uint errno = .errno,
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
        throw new FileException(name, .errno, file, line);
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
        auto h = CreateFileW(std.utf.toUTF16z(name), defaults);

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

        stat_t statbuf = void;
        cenforce(fstat(fd, &statbuf) == 0, name);

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
        auto h = CreateFileW(std.utf.toUTF16z(name), defaults);

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

        auto h = CreateFileW(std.utf.toUTF16z(name), defaults);

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
 * If the target file exists, it is overwritten.
 * Throws: $(D FileException) on error.
 */
void rename(in char[] from, in char[] to)
{
    version(Windows)
    {
        enforce(MoveFileExW(std.utf.toUTF16z(from), std.utf.toUTF16z(to), MOVEFILE_REPLACE_EXISTING),
                new FileException(
                    text("Attempting to rename file ", from, " to ",
                            to)));
    }
    else version(Posix)
        cenforce(core.stdc.stdio.rename(toStringz(from), toStringz(to)) == 0, to);
}

unittest
{
    auto t1 = deleteme, t2 = deleteme~"2";
    scope(exit) foreach (t; [t1, t2]) if (t.exists) t.remove();
    write(t1, "1");
    rename(t1, t2);
    assert(readText(t2) == "1");
    write(t1, "2");
    rename(t1, t2);
    assert(readText(t2) == "2");
}


/***************************************************
Delete file $(D name).
Throws: $(D FileException) on error.
 */
void remove(in char[] name)
{
    version(Windows)
    {
        cenforce(DeleteFileW(std.utf.toUTF16z(name)), name);
    }
    else version(Posix)
        cenforce(core.stdc.stdio.remove(toStringz(name)) == 0,
            "Failed to remove file " ~ name);
}

version(Windows) private WIN32_FILE_ATTRIBUTE_DATA getFileAttributesWin(in char[] name)
{
    WIN32_FILE_ATTRIBUTE_DATA fad;
    enforce(GetFileAttributesExW(std.utf.toUTF16z(name), GET_FILEEX_INFO_LEVELS.GetFileExInfoStandard, &fad), new FileException(name.idup));
    return fad;
}

version(Windows) private ulong makeUlong(DWORD dwLow, DWORD dwHigh)
{
    ULARGE_INTEGER li;
    li.LowPart  = dwLow;
    li.HighPart = dwHigh;
    return li.QuadPart;
}

/***************************************************
Get size of file $(D name) in bytes.

Throws: $(D FileException) on error (e.g., file not found).
 */
ulong getSize(in char[] name)
{
    version(Windows)
    {
        with (getFileAttributesWin(name))
            return makeUlong(nFileSizeLow, nFileSizeHigh);
    }
    else version(Posix)
    {
        stat_t statbuf = void;
        cenforce(stat(toStringz(name), &statbuf) == 0, name);
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


/++
    Get the access and modified times of file or folder $(D name).

    Params:
        name             = File/Folder name to get times for.
        accessTime       = Time the file/folder was last accessed.
        modificationTime = Time the file/folder was last modified.

    Throws:
        $(D FileException) on error.
 +/
void getTimes(in char[] name,
              out SysTime accessTime,
              out SysTime modificationTime)
{
    version(Windows)
    {
        with (getFileAttributesWin(name))
        {
            accessTime = std.datetime.FILETIMEToSysTime(&ftLastAccessTime);
            modificationTime = std.datetime.FILETIMEToSysTime(&ftLastWriteTime);
        }
    }
    else version(Posix)
    {
        stat_t statbuf = void;

        cenforce(stat(toStringz(name), &statbuf) == 0, name);

        accessTime = SysTime(unixTimeToStdTime(statbuf.st_atime));
        modificationTime = SysTime(unixTimeToStdTime(statbuf.st_mtime));
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

    enum leeway = dur!"seconds"(5);

    {
        auto diffa = accessTime1 - currTime;
        auto diffm = modificationTime1 - currTime;
        scope(failure) writefln("[%s] [%s] [%s] [%s] [%s]", accessTime1, modificationTime1, currTime, diffa, diffm);

        assert(abs(diffa) <= leeway);
        assert(abs(diffm) <= leeway);
    }

    version(fullFileTests)
    {
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
    with (getFileAttributesWin(name))
    {
        fileCreationTime = std.datetime.FILETIMEToSysTime(&ftCreationTime);
        fileAccessTime = std.datetime.FILETIMEToSysTime(&ftLastAccessTime);
        fileModificationTime = std.datetime.FILETIMEToSysTime(&ftLastWriteTime);
    }
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

    enum leeway = dur!"seconds"(5);

    {
        auto diffc = creationTime1 - currTime;
        auto diffa = accessTime1 - currTime;
        auto diffm = modificationTime1 - currTime;
        scope(failure)
        {
            writefln("[%s] [%s] [%s] [%s] [%s] [%s] [%s]",
                     creationTime1, accessTime1, modificationTime1, currTime, diffc, diffa, diffm);
        }

        // Deleting and recreating a file doesn't seem to always reset the "file creation time"
        //assert(abs(diffc) <= leeway);
        assert(abs(diffa) <= leeway);
        assert(abs(diffm) <= leeway);
    }

    version(fullFileTests)
    {
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
}


/++
    Set access/modified times of file or folder $(D name).

    Params:
        name             = File/Folder name to get times for.
        accessTime       = Time the file/folder was last accessed.
        modificationTime = Time the file/folder was last modified.

    Throws:
        $(D FileException) on error.
 +/
void setTimes(in char[] name,
              SysTime accessTime,
              SysTime modificationTime)
{
    version(Windows)
    {
        const ta = SysTimeToFILETIME(accessTime);
        const tm = SysTimeToFILETIME(modificationTime);
        alias TypeTuple!(GENERIC_WRITE,
                         0,
                         null,
                         OPEN_EXISTING,
                         FILE_ATTRIBUTE_NORMAL |
                         FILE_ATTRIBUTE_DIRECTORY |
                         FILE_FLAG_BACKUP_SEMANTICS,
                         HANDLE.init)
              defaults;
        auto h = CreateFileW(std.utf.toUTF16z(name), defaults);

        cenforce(h != INVALID_HANDLE_VALUE, name);

        scope(exit)
            cenforce(CloseHandle(h), name);

        cenforce(SetFileTime(h, null, &ta, &tm), name);
    }
    else version(Posix)
    {
        timeval[2] t = void;

        t[0] = accessTime.toTimeVal();
        t[1] = modificationTime.toTimeVal();

        cenforce(utimes(toStringz(name), t) == 0, name);
    }
}

unittest
{
    string dir = deleteme ~ r".dir/a/b/c";
    string file = dir ~ "/file";

    if (!exists(dir)) mkdirRecurse(dir);
    { auto f = File(file, "w"); }

    foreach (path; [file, dir])  // test file and dir
    {
        SysTime atime = SysTime(DateTime(2010, 10, 4, 0, 0, 30));
        SysTime mtime = SysTime(DateTime(2011, 10, 4, 0, 0, 30));
        setTimes(path, atime, mtime);

        SysTime atime_res;
        SysTime mtime_res;
        getTimes(path, atime_res, mtime_res);
        assert(atime == atime_res);
        assert(mtime == mtime_res);
    }

    rmdirRecurse(dir);
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
        stat_t statbuf = void;

        cenforce(stat(toStringz(name), &statbuf) == 0, name);

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
        stat_t statbuf = void;

        return stat(toStringz(name), &statbuf) != 0 ?
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
// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/
// fileio/base/getfileattributes.asp
        return GetFileAttributesW(std.utf.toUTF16z(name)) != 0xFFFFFFFF;
    }
    else version(Posix)
    {
        /*
            The reason why we use stat (and not access) here is
            the quirky behavior of access for SUID programs: if
            we used access, a file may not appear to "exist",
            despite that the program would be able to open it
            just fine. The behavior in question is described as
            follows in the access man page:

            > The check is done using the calling process's real
            > UID and GID, rather than the effective IDs as is
            > done when actually attempting an operation (e.g.,
            > open(2)) on the file. This allows set-user-ID
            > programs to easily determine the invoking user's
            > authority.

            While various operating systems provide eaccess or
            euidaccess functions, these are not part of POSIX -
            so it's safer to use stat instead.
        */

        stat_t statbuf = void;
        return stat(toStringz(name), &statbuf) == 0;
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

 Throws: $(D FileException) on error.
  +/
uint getAttributes(in char[] name)
{
    version(Windows)
    {
        immutable result = GetFileAttributesW(std.utf.toUTF16z(name));

        enforce(result != uint.max, new FileException(name.idup));

        return result;
    }
    else version(Posix)
    {
        stat_t statbuf = void;

        cenforce(stat(toStringz(name), &statbuf) == 0, name);

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
        stat_t lstatbuf = void;
        cenforce(lstat(toStringz(name), &lstatbuf) == 0, name);
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

    On Windows, returns $(D true) when the file is either a symbolic link or a
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

            assert(attrIsFile(getAttributes(fakeSymFile)));
            assert(attrIsFile(getLinkAttributes(fakeSymFile)));
            assert(!attrIsDir(getAttributes(fakeSymFile)));
            assert(!attrIsDir(getLinkAttributes(fakeSymFile)));

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

            assert(attrIsDir(getAttributes(symfile)));
            assert(!attrIsDir(getLinkAttributes(symfile)));

            assert(!attrIsFile(getAttributes(symfile)));
            assert(!attrIsFile(getLinkAttributes(symfile)));
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

            assert(!attrIsDir(getAttributes(symfile)));
            assert(!attrIsDir(getLinkAttributes(symfile)));

            assert(attrIsFile(getAttributes(symfile)));
            assert(!attrIsFile(getLinkAttributes(symfile)));
        }
    }
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
        enforce(SetCurrentDirectoryW(std.utf.toUTF16z(pathname)),
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
        enforce(CreateDirectoryW(std.utf.toUTF16z(pathname), null),
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
 *
 * Throws: $(D FileException) on error.
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
        cenforce(RemoveDirectoryW(std.utf.toUTF16z(pathname)),
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

    Note:
        Relative paths are relative to the current working directory,
        not the files being linked to or from.

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

        assert(attrIsDir(getAttributes(symfile)));
        assert(!attrIsDir(getLinkAttributes(symfile)));

        assert(!attrIsFile(getAttributes(symfile)));
        assert(!attrIsFile(getLinkAttributes(symfile)));
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

        assert(!attrIsDir(getAttributes(symfile)));
        assert(!attrIsDir(getLinkAttributes(symfile)));

        assert(attrIsFile(getAttributes(symfile)));
        assert(!attrIsFile(getLinkAttributes(symfile)));
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
    enum bufferLen = 2048;
    enum maxCodeUnits = 6;
    char[bufferLen] buffer;
    auto linkPtr = toUTFz!(const char*)(link);
    auto size = core.sys.posix.unistd.readlink(linkPtr,
                                               buffer.ptr,
                                               buffer.length);
    cenforce(size != -1, link);

    if(size <= bufferLen - maxCodeUnits)
        return to!string(buffer[0 .. size]);

    auto dynamicBuffer = new char[](bufferLen * 3 / 2);

    foreach(i; 0 .. 10)
    {
        size = core.sys.posix.unistd.readlink(linkPtr,
                                              dynamicBuffer.ptr,
                                              dynamicBuffer.length);
        cenforce(size != -1, link);

        if(size <= dynamicBuffer.length - maxCodeUnits)
        {
            dynamicBuffer.length = size;
            return assumeUnique(dynamicBuffer);
        }

        dynamicBuffer.length = dynamicBuffer.length * 3 / 2;
    }

    throw new FileException(format("Path for %s is too long to read.", link));
}

version(Posix) unittest
{
    foreach(file; ["/usr/include", "/usr/include/assert.h"])
    {
        if(file.exists)
        {
            immutable symfile = deleteme ~ "_slink\0";
            scope(exit) if(symfile.exists) symfile.remove();

            symlink(file, symfile);
            assert(readLink(symfile) == file, format("Failed file: %s", file));
        }
    }

    assertThrown!FileException(readLink("/doesnotexist"));
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
    wchar[4096] buffW = void; //enough for most common case
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
else version (Posix) string getcwd()
{
    auto p = cenforce(core.sys.posix.unistd.getcwd(null, 0),
            "cannot get cwd");
    scope(exit) core.stdc.stdlib.free(p);
    return p[0 .. core.stdc.string.strlen(p)].idup;
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
            $(BLUE This function is Windows-Only.)

            Returns the creation time of the file represented by this
            $(D DirEntry).
          +/
        @property SysTime timeCreated() const;

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

        version(Windows)
            alias void* stat_t;

        /++
            $(BLUE This function is Posix-Only.)

            The $(D stat) struct gotten from calling $(D stat).
          +/
        @property stat_t statBuf();
    }
}
else version(Windows)
{
    struct DirEntry
    {
    public:
        alias name this;

        @property string name() const pure nothrow
        {
            return _name;
        }

        @property bool isDir() const pure nothrow
        {
            return (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        }

        @property bool isFile() const pure nothrow
        {
            //Are there no options in Windows other than directory and file?
            //If there are, then this probably isn't the best way to determine
            //whether this DirEntry is a file or not.
            return !isDir;
        }

        @property bool isSymlink() const pure nothrow
        {
            return (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
        }

        @property ulong size() const pure nothrow
        {
            return _size;
        }

        @property SysTime timeCreated() const pure nothrow
        {
            return cast(SysTime)_timeCreated;
        }

        @property SysTime timeLastAccessed() const pure nothrow
        {
            return cast(SysTime)_timeLastAccessed;
        }

        @property SysTime timeLastModified() const pure nothrow
        {
            return cast(SysTime)_timeLastModified;
        }

        @property uint attributes() const pure nothrow
        {
            return _attributes;
        }

        @property uint linkAttributes() const pure nothrow
        {
            return _attributes;
        }

    private:

        void _init(in char[] path)
        {
            _name = path.idup;

            with (getFileAttributesWin(path))
            {
                _size = makeUlong(nFileSizeLow, nFileSizeHigh);
                _timeCreated = std.datetime.FILETIMEToSysTime(&ftCreationTime);
                _timeLastAccessed = std.datetime.FILETIMEToSysTime(&ftLastAccessTime);
                _timeLastModified = std.datetime.FILETIMEToSysTime(&ftLastWriteTime);
                _attributes = dwFileAttributes;
            }
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
        alias name this;

        @property string name() const pure nothrow
        {
            return _name;
        }

        @property bool isDir()
        {
            _ensureStatDone();

            return (_statBuf.st_mode & S_IFMT) == S_IFDIR;
        }

        @property bool isFile()
        {
            _ensureStatDone();

            return (_statBuf.st_mode & S_IFMT) == S_IFREG;
        }

        @property bool isSymlink()
        {
            _ensureLStatDone();

            return (_lstatMode & S_IFMT) == S_IFLNK;
        }

        @property ulong size()
        {
            _ensureStatDone();
            return _statBuf.st_size;
        }

        @property SysTime timeStatusChanged()
        {
            _ensureStatDone();

            return SysTime(unixTimeToStdTime(_statBuf.st_ctime));
        }

        @property SysTime timeLastAccessed()
        {
            _ensureStatDone();

            return SysTime(unixTimeToStdTime(_statBuf.st_ctime));
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

        @property stat_t statBuf()
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

            enforce(stat(toStringz(_name), &_statBuf) == 0,
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

            stat_t statbuf = void;

            enforce(lstat(toStringz(_name), &statbuf) == 0,
                "Failed to stat file `" ~ _name ~ "'");

            _lstatMode = statbuf.st_mode;

            _dTypeSet = true;
            _didLStat = true;
        }


        string _name; /// The file or directory represented by this DirEntry.

        stat_t _statBuf = void;  /// The result of stat().
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

/***************************************************
Copy file $(D from) to file $(D to). File timestamps are preserved.
If the target file exists, it is overwritten.

Throws: $(D FileException) on error.
 */
void copy(in char[] from, in char[] to)
{
    version(Windows)
    {
        immutable result = CopyFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to), false);
        if (!result)
            throw new FileException(to.idup);
    }
    else version(Posix)
    {
        immutable fd = core.sys.posix.fcntl.open(toStringz(from), O_RDONLY);
        cenforce(fd != -1, from);
        scope(exit) core.sys.posix.unistd.close(fd);

        stat_t statbuf = void;
        cenforce(fstat(fd, &statbuf) == 0, from);
        //cenforce(core.sys.posix.sys.stat.fstat(fd, &statbuf) == 0, from);

        auto toz = toStringz(to);
        immutable fdw = core.sys.posix.fcntl.open(toz,
                O_CREAT | O_WRONLY | O_TRUNC, octal!666);
        cenforce(fdw != -1, from);
        scope(failure) core.stdc.stdio.remove(toz);
        {
            scope(failure) core.sys.posix.unistd.close(fdw);
            auto BUFSIZ = 4096u * 16;
            auto buf = core.stdc.stdlib.malloc(BUFSIZ);
            if (!buf)
            {
                BUFSIZ = 4096;
                buf = core.stdc.stdlib.malloc(BUFSIZ);
                buf || assert(false, "Out of memory in std.file.copy");
            }
            scope(exit) core.stdc.stdlib.free(buf);

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

unittest
{
    auto t1 = deleteme, t2 = deleteme~"2";
    scope(exit) foreach (t; [t1, t2]) if (t.exists) t.remove();
    write(t1, "1");
    copy(t1, t2);
    assert(readText(t2) == "1");
    write(t1, "2");
    copy(t1, t2);
    assert(readText(t2) == "2");
}


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

    if(de.isSymlink)
        remove(de.name);
    else
    {
        // all children, recursively depth-first
        foreach(DirEntry e; dirEntries(de.name, SpanMode.depth, false))
        {
            attrIsDir(e.linkAttributes) ? rmdir(e.name) : remove(e.name);
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
    collectException(rmdirRecurse(deleteme));
    auto d = deleteme~"/a/b/c/d/e/f/g";
    enforce(collectException(mkdir(d)));
    mkdirRecurse(d);
    core.sys.posix.unistd.symlink((deleteme~"/a/b/c\0").ptr,
            (deleteme~"/link\0").ptr);
    rmdirRecurse(deleteme~"/link");
    enforce(exists(d));
    rmdirRecurse(deleteme);
    enforce(!exists(deleteme));

    d = deleteme~"/a/b/c/d/e/f/g";
    mkdirRecurse(d);
    std.process.system("ln -sf "~deleteme~"/a/b/c "~deleteme~"/link");
    rmdirRecurse(deleteme);
    enforce(!exists(deleteme));
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
            WIN32_FIND_DATAW findinfo;
            HANDLE h = FindFirstFileW(toUTF16z(search_pattern), &findinfo);
            cenforce(h != INVALID_HANDLE_VALUE, directory);
            _stack.put(DirHandle(directory, h));
            return toNext(false, &findinfo);
        }

        bool next()
        {
            if(_stack.data.empty)
                return false;
            WIN32_FIND_DATAW findinfo;
            return toNext(true, &findinfo);
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
            while( core.stdc.string.strcmp(findinfo.cFileName.ptr, ".") == 0
                    || core.stdc.string.strcmp(findinfo.cFileName.ptr, "..") == 0)
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
                if(core.stdc.string.strcmp(fdata.d_name.ptr, ".")  &&
                   core.stdc.string.strcmp(fdata.d_name.ptr, "..") )
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
            return _followSymlink ? _cur.isDir : attrIsDir(_cur.linkAttributes);
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

    Throws:
        $(D FileException) if the directory does not exist.

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
 +/
auto dirEntries(string path, SpanMode mode, bool followSymlink = true)
{
    return DirIterator(path, mode, followSymlink);
}

unittest
{
    string testdir = "deleteme.dmd.unittest.std.file" ~ to!string(getpid()); // needs to be relative
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

unittest
{
    //issue 7264
    foreach (string name; dirEntries(".", "*.d", SpanMode.breadth))
    {

    }
    foreach (entry; dirEntries(".", SpanMode.breadth))
    {
        static assert(is(typeof(entry) == DirEntry));
    }
    //issue 7138
    auto a = array(dirEntries(".", SpanMode.shallow));
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

    Throws:
        $(D FileException) if the directory does not exist.

Examples:
--------------------
// Iterate over all D source files in current directory and all its
// subdirectories
auto dFiles = dirEntries(".","*.{d,di}",SpanMode.depth);
foreach(d; dFiles)
    writeln(d.name);
--------------------
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
        throw new FileException(text("File ", name, " does not exist"));

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

    assert(attrIsDir(de.attributes));
    assert(attrIsDir(de.linkAttributes));
    assert(!attrIsFile(de.attributes));
    assert(!attrIsFile(de.linkAttributes));
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

    assert(!attrIsDir(de.attributes));
    assert(!attrIsDir(de.linkAttributes));
    assert(attrIsFile(de.attributes));
    assert(attrIsFile(de.linkAttributes));
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

    assert(attrIsDir(de.attributes));
    assert(!attrIsDir(de.linkAttributes));
    assert(!attrIsFile(de.attributes));
    assert(!attrIsFile(de.linkAttributes));
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

    assert(!attrIsDir(de.attributes));
    assert(!attrIsDir(de.linkAttributes));
    assert(attrIsFile(de.attributes));
    assert(!attrIsFile(de.linkAttributes));
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
    scope(exit) f.close();
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


/**
Returns the path to a directory for temporary files.

On Windows, this function returns the result of calling the Windows API function
$(LINK2 http://msdn.microsoft.com/en-us/library/windows/desktop/aa364992.aspx, $(D GetTempPath)).

On POSIX platforms, it searches through the following list of directories
and returns the first one which is found to exist:
$(OL
    $(LI The directory given by the $(D TMPDIR) environment variable.)
    $(LI The directory given by the $(D TEMP) environment variable.)
    $(LI The directory given by the $(D TMP) environment variable.)
    $(LI $(D /tmp))
    $(LI $(D /var/tmp))
    $(LI $(D /usr/tmp))
)

On all platforms, $(D tempDir) returns $(D ".") on failure, representing
the current working directory.

The return value of the function is cached, so the procedures described
above will only be performed the first time the function is called.  All
subsequent runs will return the same string, regardless of whether
environment variables and directory structures have changed in the
meantime.

The POSIX $(D tempDir) algorithm is inspired by Python's
$(LINK2 http://docs.python.org/library/tempfile.html#tempfile.tempdir, $(D tempfile.tempdir)).
*/
string tempDir()
{
    static string cache;
    if (cache is null)
    {
        version(Windows)
        {
            wchar[MAX_PATH] buf;
            DWORD len = GetTempPathW(buf.length, buf.ptr);
            if (len) cache = toUTF8(buf[0 .. len]);
        }
        else version(Posix)
        {
            // This function looks through the list of alternative directories
            // and returns the first one which exists and is a directory.
            static string findExistingDir(T...)(lazy T alternatives)
            {
                foreach (dir; alternatives)
                    if (!dir.empty && exists(dir)) return dir;
                return null;
            }

            cache = findExistingDir(environment.get("TMPDIR"),
                                    environment.get("TEMP"),
                                    environment.get("TMP"),
                                    "/tmp",
                                    "/var/tmp",
                                    "/usr/tmp");
        }
        else static assert (false, "Unsupported platform");

        if (cache is null) cache = ".";
    }
    return cache;
}
