// Written in the D programming language.

/**
Utilities for manipulating files and scanning directories.

Authors:

$(WEB digitalmars.com, Walter Bright), $(WEB erdani.org, Andrei
Alexandrescu)

Macros:

WIKI = Phobos/StdFile
*/

/*
 *  Copyright (C) 2001-2004 by Digital Mars, www.digitalmars.com
 * Written by Walter Bright, Christopher E. Miller, Andre Fornacon
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module std.file;

private import core.memory;
private import std.c.stdio;
private import std.c.stdlib;
private import std.path;
private import std.string;
private import std.regexp;
private import std.c.string;
private import std.traits;
private import std.conv;
private import std.contracts;
private import std.utf;
version (unittest) {
    private import std.stdio; // for testing only
}

/* =========================== Win32 ======================= */

version (Win32)
{

private import std.c.windows.windows;
private import std.utf;
private import std.windows.syserror;
private import std.windows.charset;
private import std.date;

bool useWfuncs = true;

static this()
{
    // Win 95, 98, ME do not implement the W functions
    useWfuncs = (GetVersion() < 0x80000000);
}

/***********************************
 * Exception thrown for file I/O errors.
 */

class FileException : Exception
{
    uint errno;			// operating system error code

    this(string name)
    {
	this(name, "file I/O");
    }

    this(string name, string message)
    {
	super(name ~ ": " ~ message);
    }

    this(string name, uint errno)
    {
	this(name, sysErrorString(errno));
	this.errno = errno;
    }
}

/* **********************************
 * Basic File operations.
 */

/********************************************
 * Read file $(D name), return array of bytes read.
 *
 * Throws: $(D FileException) on error.
 */

void[] read(in string name)
{
    DWORD numread;
    HANDLE h;

    if (useWfuncs)
    {
	const(wchar*) namez = std.utf.toUTF16z(name);
	h = CreateFileW(namez,GENERIC_READ,FILE_SHARE_READ,null,OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    else
    {
	const(char*) namez = toMBSz(name);
	h = CreateFileA(namez,GENERIC_READ,FILE_SHARE_READ,null,OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }

    if (h == INVALID_HANDLE_VALUE)
	goto err1;

    auto size = GetFileSize(h, null);
    if (size == INVALID_FILE_SIZE)
	goto err2;

    auto buf = GC.malloc(size, GC.BlkAttr.NO_SCAN)[0 .. size];

    if (ReadFile(h,buf.ptr,size,&numread,null) != 1)
	goto err2;

    if (numread != size)
	goto err2;

    if (!CloseHandle(h))
	goto err;

    return buf[0 .. size];

err2:
    CloseHandle(h);
err:
    delete buf;
err1:
    throw new FileException(name, GetLastError());
}

/*********************************************
 * Write buffer[] to file name[].
 * Throws: $(D FileException) on error.
 */

void write(in string name, const void[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    if (useWfuncs)
    {
	const(wchar*) namez = std.utf.toUTF16z(name);
	h = CreateFileW(namez,GENERIC_WRITE,0,null,CREATE_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    else
    {
	const(char*) namez = toMBSz(name);
	h = CreateFileA(namez,GENERIC_WRITE,0,null,CREATE_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    if (h == INVALID_HANDLE_VALUE)
	goto err;

    if (WriteFile(h,buffer.ptr,buffer.length,&numwritten,null) != 1)
	goto err2;

    if (buffer.length != numwritten)
	goto err2;

    if (!CloseHandle(h))
	goto err;
    return;

err2:
    CloseHandle(h);
err:
    throw new FileException(name, GetLastError());
}


/*********************************************
 * Append buffer[] to file name[].
 * Throws: $(D FileException) on error.
 */

void append(in string name, in void[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    if (useWfuncs)
    {
	const(wchar*) namez = std.utf.toUTF16z(name);
	h = CreateFileW(namez,GENERIC_WRITE,0,null,OPEN_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    else
    {
	const(char*) namez = toMBSz(name);
	h = CreateFileA(namez,GENERIC_WRITE,0,null,OPEN_ALWAYS,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,cast(HANDLE)null);
    }
    if (h == INVALID_HANDLE_VALUE)
	goto err;

    SetFilePointer(h, 0, null, FILE_END);

    if (WriteFile(h,buffer.ptr,buffer.length,&numwritten,null) != 1)
	goto err2;

    if (buffer.length != numwritten)
	goto err2;

    if (!CloseHandle(h))
	goto err;
    return;

err2:
    CloseHandle(h);
err:
    throw new FileException(name, GetLastError());
}


/***************************************************
 * Rename file from[] to to[].
 * Throws: $(D FileException) on error.
 */

void rename(in string from, in string to)
{
    BOOL result = void;

    if (useWfuncs)
	result = MoveFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to));
    else
	result = MoveFileA(toMBSz(from), toMBSz(to));
    if (!result)
	throw new FileException(to, GetLastError());
}


/***************************************************
 * Delete file name[].
 * Throws: $(D FileException) on error.
 */

void remove(in string name)
{
    BOOL result = void;

    if (useWfuncs)
	result = DeleteFileW(std.utf.toUTF16z(name));
    else
	result = DeleteFileA(toMBSz(name));
    if (!result)
	throw new FileException(name, GetLastError());
}


/***************************************************
 * Get size of file name[].
 * Throws: $(D FileException) on error.
 */

ulong getSize(in string name)
{
    HANDLE findhndl;
    uint resulth;
    uint resultl;

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

    if (findhndl == cast(HANDLE)-1)
    {
	throw new FileException(name, GetLastError());
    }
    FindClose(findhndl);
    return (cast(ulong)resulth << 32) + resultl;
}

/*************************
 * Get creation/access/modified times of file $(D name).
 * Throws: $(D FileException) on error.
 */

void getTimes(in string name, out d_time ftc, out d_time fta, out d_time ftm)
{
    HANDLE findhndl;

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
	throw new FileException(name, GetLastError());
    }
    FindClose(findhndl);
}


/***************************************************
 * Does file name[] (or directory) exist?
 * Return 1 if it does, 0 if not.
 */

bool exists(in string name)
{
    uint result;

    if (useWfuncs)
	// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/fileio/base/getfileattributes.asp
	result = GetFileAttributesW(std.utf.toUTF16z(name));
    else
	result = GetFileAttributesA(toMBSz(name));

    return result != 0xFFFFFFFF;
}

/***************************************************
 * Get file name[] attributes.
 * Throws: $(D FileException) on error.
 */

uint getAttributes(string name)
{
    uint result;

    if (useWfuncs)
	result = GetFileAttributesW(std.utf.toUTF16z(name));
    else
	result = GetFileAttributesA(toMBSz(name));
    if (result == 0xFFFFFFFF)
    {
	throw new FileException(name, GetLastError());
    }
    return result;
}

/****************************************************
 * Is name[] a file?
 * Throws: $(D FileException) if name[] doesn't exist.
 */

bool isfile(in string name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

/****************************************************
 * Is name[] a directory?
 * Throws: $(D FileException) if name[] doesn't exist.
 */

bool isdir(in string name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

/****************************************************
 * Change directory to pathname[].
 * Throws: $(D FileException) on error.
 */

void chdir(in string pathname)
{   BOOL result;

    if (useWfuncs)
	result = SetCurrentDirectoryW(std.utf.toUTF16z(pathname));
    else
	result = SetCurrentDirectoryA(toMBSz(pathname));

    if (!result)
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Make directory pathname[].
 * Throws: $(D FileException) on error.
 */

void mkdir(in string pathname)
{   BOOL result = void;

    if (useWfuncs)
	result = CreateDirectoryW(std.utf.toUTF16z(pathname), null);
    else
	result = CreateDirectoryA(toMBSz(pathname), null);

    if (!result)
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Make directory and all parent directories as needed.
 */

void mkdirRecurse(string pathname)
{
    invariant left = dirname(pathname);
    exists(left) || mkdirRecurse(left);
    mkdir(pathname);
}

/****************************************************
 * Remove directory pathname[].
 * Throws: $(D FileException) on error.
 */

void rmdir(in string pathname)
{   BOOL result = void;

    if (useWfuncs)
	result = RemoveDirectoryW(std.utf.toUTF16z(pathname));
    else
	result = RemoveDirectoryA(toMBSz(pathname));

    if (!result)
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Remove directory and all of its content and subdirectories,
 * recursively.
 */

void rmdirRecurse(string pathname)
{
    // all children, recursively depth-first
    foreach (DirEntry e; dirEntries(pathname, SpanMode.depth))
    {
        e.isdir ? rmdir(e.name) : remove(e.name);
    }
    // the dir itself
    rmdir(pathname);
}

unittest
{
    auto d = r"c:\deleteme\a\b\c\d\e\f\g";
    mkdirRecurse(d);
    rmdirRecurse(r"c:\deleteme");
    enforce(!exists(r"c:\deleteme"));
}

/****************************************************
 * Get current directory.
 * Throws: $(D FileException) on error.
 */

string getcwd()
{
    if (useWfuncs)
    {
	wchar c;

	auto len = GetCurrentDirectoryW(0, &c);
	if (!len)
	    goto Lerr;
	auto dir = new wchar[len];
	len = GetCurrentDirectoryW(len, dir.ptr);
	if (!len)
	    goto Lerr;
	return std.utf.toUTF8(dir[0 .. len]); // leave off terminating 0
    }
    else
    {
	char c;

	auto len = GetCurrentDirectoryA(0, &c);
	if (!len)
	    goto Lerr;
	auto dir = new char[len];
	len = GetCurrentDirectoryA(len, dir.ptr);
	if (!len)
	    goto Lerr;
	return cast(string)dir[0 .. len];	// leave off terminating 0
    }

Lerr:
    throw new FileException("getcwd", GetLastError());
}

/***************************************************
 * Directory Entry
 */

struct DirEntry
{
    string name;			/// file or directory name
    ulong size = ~0UL;			/// size of file in bytes
    d_time creationTime = d_time_nan;	/// time of file creation
    d_time lastAccessTime = d_time_nan;	/// time file was last accessed
    d_time lastWriteTime = d_time_nan;	/// time file was last written to
    uint attributes;		// Windows file attributes OR'd together

    void init(string path, in WIN32_FIND_DATA *fd)
    {
	wchar[] wbuf;
	size_t clength;
	size_t wlength;
	size_t n;

	clength = std.c.string.strlen(fd.cFileName.ptr);

	// Convert cFileName[] to unicode
	wlength = MultiByteToWideChar(0,0,fd.cFileName.ptr,clength,null,0);
	if (wlength > wbuf.length)
	    wbuf.length = wlength;
	n = MultiByteToWideChar(0,0,fd.cFileName.ptr,clength,cast(wchar*)wbuf,wlength);
	assert(n == wlength);
	// toUTF8() returns a new buffer
	name = std.path.join(path, std.utf.toUTF8(wbuf[0 .. wlength]));

	size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
	creationTime = std.date.FILETIME2d_time(&fd.ftCreationTime);
	lastAccessTime = std.date.FILETIME2d_time(&fd.ftLastAccessTime);
	lastWriteTime = std.date.FILETIME2d_time(&fd.ftLastWriteTime);
	attributes = fd.dwFileAttributes;
    }

    void init(string path, in WIN32_FIND_DATAW *fd)
    {
	size_t clength = std.string.wcslen(fd.cFileName.ptr);
	name = std.path.join(path, std.utf.toUTF8(fd.cFileName[0 .. clength]));
	size = (cast(ulong)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
	creationTime = std.date.FILETIME2d_time(&fd.ftCreationTime);
	lastAccessTime = std.date.FILETIME2d_time(&fd.ftLastAccessTime);
	lastWriteTime = std.date.FILETIME2d_time(&fd.ftLastWriteTime);
	attributes = fd.dwFileAttributes;
    }

    /****
     * Return !=0 if DirEntry is a directory.
     */
    uint isdir()
    {
	return attributes & FILE_ATTRIBUTE_DIRECTORY;
    }

    /****
     * Return !=0 if DirEntry is a file.
     */
    uint isfile()
    {
	return !(attributes & FILE_ATTRIBUTE_DIRECTORY);
    }
}


/***************************************************
 * Return contents of directory pathname[].
 * The names in the contents do not include the pathname.
 * Throws: $(D FileException) on error
 * Example:
 *	This program lists all the files and subdirectories in its
 *	path argument.
 * ----
 * import std.stdio;
 * import std.file;
 *
 * void main(string[] args)
 * {
 *    auto dirs = std.file.listdir(args[1]);
 *
 *    foreach (d; dirs)
 *	writefln(d);
 * }
 * ----
 */

string[] listdir(string pathname)
{
    string[] result;

    bool listing(string filename)
    {
	result ~= filename;
	return true; // continue
    }

    listdir(pathname, &listing);
    return result;
}


/*****************************************************
 * Return all the files in the directory and its subdirectories
 * that match pattern or regular expression r.
 * Params:
 *	pathname = Directory name
 *	pattern = String with wildcards, such as $(RED "*.d"). The supported
 *		wildcard strings are described under fnmatch() in
 *		$(LINK2 std_path.html, std.path).
 *	r = Regular expression, for more powerful _pattern matching.
 * Example:
 *	This program lists all the files with a "d" extension in
 *	the path passed as the first argument.
 * ----
 * import std.stdio;
 * import std.file;
 *
 * void main(string[] args)
 * {
 *    auto d_source_files = std.file.listdir(args[1], "*.d");
 *
 *    foreach (d; d_source_files)
 *	writefln(d);
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
 *	writefln(d);
 * }
 * ----
 */

string[] listdir(string pathname, string pattern)
{   string[] result;

    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (std.path.fnmatch(de.name, pattern))
		result ~= de.name;
	}
	return true; // continue
    }

    listdir(pathname, &callback);
    return result;
}

/** Ditto */

string[] listdir(string pathname, RegExp r)
{   string[] result;

    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (r.test(de.name))
		result ~= de.name;
	}
	return true; // continue
    }

    listdir(pathname, &callback);
    return result;
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
 *	callback =	Delegate that processes each
 *			filename in turn. Returns true to
 *			continue, false to stop.
 * Example:
 *	This program lists all the files in its
 *	path argument, including the path.
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

void listdir(in string pathname, bool delegate(string filename) callback)
{
    bool listing(DirEntry* de)
    {
	return callback(std.path.getBaseName(de.name));
    }

    listdir(pathname, &listing);
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
 *	callback =	Delegate that processes each
 *			DirEntry in turn. Returns true to
 *			continue, false to stop.
 * Example:
 *	This program lists all the files in its
 *	path argument and all subdirectories thereof.
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

void listdir(in string pathname, bool delegate(DirEntry* de) callback)
{
    string c;
    HANDLE h;
    DirEntry de;

    c = std.path.join(pathname, "*.*");
    if (useWfuncs)
    {
	WIN32_FIND_DATAW fileinfo;

	h = FindFirstFileW(std.utf.toUTF16z(c), &fileinfo);
	if (h != INVALID_HANDLE_VALUE)
	{
	    try
	    {
		do
		{
		    // Skip "." and ".."
		    if (std.string.wcscmp(fileinfo.cFileName.ptr, ".") == 0 ||
			std.string.wcscmp(fileinfo.cFileName.ptr, "..") == 0)
			continue;

		    de.init(pathname, &fileinfo);
		    if (!callback(&de))
			break;
		} while (FindNextFileW(h,&fileinfo) != FALSE);
	    }
	    finally
	    {
		FindClose(h);
	    }
	}
    }
    else
    {
	WIN32_FIND_DATA fileinfo;

	h = FindFirstFileA(toMBSz(c), &fileinfo);
	if (h != INVALID_HANDLE_VALUE)	// should we throw exception if invalid?
	{
	    try
	    {
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
	    finally
	    {
		FindClose(h);
	    }
	}
    }
}

/******************************************
 * Since Win 9x does not support the "W" API's, first convert
 * to wchar, then convert to multibyte using the current code
 * page.
 * (Thanks to yaneurao for this)
 * Deprecated: use std.windows.charset.toMBSz instead.
 */

const(char)* toMBSz(in string s)
{
    return std.windows.charset.toMBSz(s);
}


/***************************************************
 * Copy a file from[] to[].
 */

void copy(in string from, in string to)
{
    invariant result = useWfuncs
	? CopyFileW(std.utf.toUTF16z(from), std.utf.toUTF16z(to), false)
        : CopyFileA(toMBSz(from), toMBSz(to), false);
    if (!result)
         throw new FileException(to, GetLastError);
}


}

/* =========================== Posix ======================= */

version (Posix)
{

private import std.date;
private import std.c.linux.linux;

/***********************************
 */

class FileException : Exception
{
    uint errno;			// operating system error code

    this(string name)
    {
	this(name, "file I/O");
    }

    this(string name, string message)
    {
	super(name ~ ": " ~ message);
    }

    this(string name, uint errno)
    {
        char[1024] buf = void;
	auto s = strerror_r(errno, buf.ptr, buf.length);
	this(name, std.string.toString(s));
	this.errno = errno;
    }
}

private T cenforce(T)(T condition, lazy const(char)[] name)
{
    if (!condition) throw new FileException(name.idup, getErrno());
    return condition;
}


/********************************************
 * Read a file.
 * Returns:
 *	array of bytes read
 */

void[] read(string name)
{
    invariant fd = std.c.linux.linux.open(toStringz(name), O_RDONLY);
    cenforce(fd != -1, name);
    scope(exit) std.c.linux.linux.close(fd);

    struct_stat statbuf = void;
    cenforce(std.c.linux.linux.fstat(fd, &statbuf) == 0, name);

    void[] buf;
    auto size = statbuf.st_size;
    if (size == 0)
    {	/* The size could be 0 if the file is a device or a procFS file,
	 * so we just have to try reading it.
	 */
	int readsize = 1024;
	while (1)
	{
	    buf = GC.realloc(buf.ptr, size + readsize, GC.BlkAttr.NO_SCAN)[0 .. cast(int)size + readsize];
	    enforce(buf, "Out of memory");
	    scope(failure) delete buf;

	    auto toread = readsize;
	    while (toread)
	    {
		auto numread = std.c.linux.linux.read(fd, buf.ptr + size, toread);
		cenforce(numread != -1, name);
		size += numread;
		if (numread == 0)
		{   if (size == 0)			// it really was 0 size
			delete buf;			// don't need the buffer
		    return buf[0 .. size];		// end of file
		}
		toread -= numread;
	    }
	}
    }
    else
    {
	buf = GC.malloc(size, GC.BlkAttr.NO_SCAN)[0 .. size];
	enforce(buf, "Out of memory");
	scope(failure) delete buf;

	cenforce(std.c.linux.linux.read(fd, buf.ptr, size) == size, name);

	return buf[0 .. size];
    }
}

unittest
{
    version (linux)
    {	// A file with "zero" length that doesn't have 0 length at all
	char[] s = cast(char[])std.file.read("/proc/sys/kernel/osrelease");
	assert(s.length > 0);
	//writefln("'%s'", s);
    }
}

/********************************************
 * Read and validates (using $(XREF utf, validate)) a text file. $(D
 * S) can be a type of array of characters of any width and constancy.
 *
 * Returns: array of characters read
 *
 * Throws: $(D FileException) on file error, $(D UtfException) on UTF
 * decoding error.
 *
 */

S readText(S = string)(in string name)
{
    auto result = cast(S) read(name);
    std.utf.validate(result);
    return result;
}

// Implementation helper for write and append

private void writeImpl(in string name, in void[] buffer, in uint mode)
{
    invariant fd = std.c.linux.linux.open(toStringz(name),
            mode, 0660);
    cenforce(fd != -1, name);
    {
        scope(failure) std.c.linux.linux.close(fd);
        invariant size = buffer.length;
        cenforce(std.c.linux.linux.write(fd, buffer.ptr, size) == size, name);
    }
    cenforce(std.c.linux.linux.close(fd) == 0, name);
}


/*********************************************
 * Write a file.
 */

void write(in string name, in void[] buffer)
{
    return writeImpl(name, buffer, O_CREAT | O_WRONLY | O_TRUNC);
}

/*********************************************
 * Append to a file.
 */

void append(in string name, in void[] buffer)
{
    return writeImpl(name, buffer, O_APPEND | O_WRONLY | O_CREAT);
}

/***************************************************
 * Rename a file.
 */

void rename(in string from, in string to)
{
    cenforce(std.c.stdio.rename(toStringz(from), toStringz(to)) == 0, to);
}

/***************************************************
 * Delete a file.
 */

void remove(in string name)
{
    cenforce(std.c.stdio.remove(toStringz(name)) == 0, name);
}


/***************************************************
 * Get file size.
 */

ulong getSize(in string name)
{
    struct_stat statbuf = void;
    cenforce(std.c.linux.linux.stat(toStringz(name), &statbuf) == 0, name);
    return statbuf.st_size;
}

unittest
{
    scope(exit) system("rm -f /tmp/deleteme");
    // create a file of size 1
    assert(system("echo > /tmp/deleteme") == 0);
    assert(getSize("/tmp/deleteme") == 1);
    // create a file of size 3
    assert(system("echo ab > /tmp/deleteme") == 0);
    assert(getSize("/tmp/deleteme") == 3);
}

/***************************************************
 * Get file attributes.
 */

uint getAttributes(in string name)
{
    struct_stat statbuf = void;
    cenforce(std.c.linux.linux.stat(toStringz(name), &statbuf) == 0, name);
    return statbuf.st_mode;
}

/*************************
 * Get creation/access/modified times of file $(D name).
 * Throws: $(D FileException) on error.
 */

void getTimes(in string name, out d_time ftc, out d_time fta, out d_time ftm)
{
    struct_stat statbuf = void;
    cenforce(std.c.linux.linux.stat(toStringz(name), &statbuf) == 0, name);
    version (linux)
    {
	ftc = cast(d_time) statbuf.st_ctime * std.date.TicksPerSecond;
	fta = cast(d_time) statbuf.st_atime * std.date.TicksPerSecond;
	ftm = cast(d_time) statbuf.st_mtime * std.date.TicksPerSecond;
    }
    else version (OSX)
    {	// BUG: should add in tv_nsec field
	ftc = cast(d_time)statbuf.st_ctimespec.tv_sec * std.date.TicksPerSecond;
	fta = cast(d_time)statbuf.st_atimespec.tv_sec * std.date.TicksPerSecond;
	ftm = cast(d_time)statbuf.st_mtimespec.tv_sec * std.date.TicksPerSecond;
    }
    else
    {
	static assert(0);
    }
}

/*************************
 * Set access/modified times of file $(D name).
 * Throws: $(D FileException) on error.
 */

void setTimes(in string name, d_time fta, d_time ftm)
{
    version (linux)
    {
version (none) // does not compile
{
        // utimbuf times = {
        //     cast(__time_t) (fta / std.date.TicksPerSecond),
        //     cast(__time_t) (ftm / std.date.TicksPerSecond) };
        // enforce(utime(toStringz(name), &times) == 0);
        timeval[2] t = void;
        t[0].tv_sec = fta / std.date.TicksPerSecond;
        t[0].tv_usec = cast(long) ((cast(double) fta / std.date.TicksPerSecond)
                * 1_000_000) % 1_000_000;
        t[1].tv_sec = ftm / std.date.TicksPerSecond;
        t[1].tv_usec = cast(long) ((cast(double) ftm / std.date.TicksPerSecond)
                * 1_000_000) % 1_000_000;
        enforce(utime(toStringz(name), t.ptr) == 0);
}
else
{
	assert(0);
}
    }
    else
    {
        if (true) enforce(false, "Not implemented");
    }
}

unittest
{
    system("touch deleteme") == 0 || assert(false);
    scope(exit) remove("deleteme");
    d_time ftc1, fta1, ftm1;
    getTimes("deleteme", ftc1, fta1, ftm1);
    setTimes("deleteme", fta1 + 1000, ftm1 + 1000);
    d_time ftc2, fta2, ftm2;
    getTimes("deleteme", ftc2, fta2, ftm2);
    assert(fta1 + 1000 == fta2);
    assert(ftm1 + 1000 == ftm2);
}

/**
   Returns the time of the last modification of file $(D name). If the
   file does not exist, throws a $(D FileException).
*/

d_time lastModified(in string name)
{
    struct_stat statbuf = void;
    cenforce(std.c.linux.linux.stat(toStringz(name), &statbuf) == 0, name);
  version (linux)
    return cast(d_time) statbuf.st_mtime * std.date.TicksPerSecond;
  else version (OSX)
    return cast(d_time)statbuf.st_mtimespec.tv_sec * std.date.TicksPerSecond;
  else
    static assert(0);
}

/**
Returns the time of the last modification of file $(D name). If the
file does not exist, returns $(D returnIfMissing).

A frequent usage pattern occurs in build automation tools such as
$(WEB www.gnu.org/software/make, make) or $(WEB
en.wikipedia.org/wiki/Apache_Ant, ant). To check whether file $(D
target) must be rebuilt from file $(D source) (i.e., $(D target) is
older than $(D source) or does not exist), use the comparison below.

----------------------------
if (lastModified(source) >= lastModified(target, d_time.min))
{
    ... must (re)build ...
}
else
{
    ... target's up-to-date ...
}
----------------------------

The code above throws a $(D FileException) if $(D source) does not
exist (as it should). On the other hand, the $(D d_time.min) default
makes a non-existing $(D target) seem infinitely old so the test
correctly prompts building it.

*/

d_time lastModified(string name, d_time returnIfMissing)
{
    struct_stat statbuf = void;
  version (linux)
  {
    return std.c.linux.linux.stat(toStringz(name), &statbuf) != 0
        ? returnIfMissing
        : cast(d_time) statbuf.st_mtime * std.date.TicksPerSecond;
  }
  else version (OSX)
  {
    return std.c.linux.linux.stat(toStringz(name), &statbuf) != 0
        ? returnIfMissing
	: cast(d_time)statbuf.st_mtimespec.tv_sec * std.date.TicksPerSecond;
  }
  else
  {
    assert(0);
  }
}

unittest
{
    system("touch deleteme") == 0 || assert(false);
    scope(exit) remove("deleteme");
    assert(lastModified("deleteme") >
        lastModified("this file does not exist", d_time.min));
    assert(lastModified("deleteme") > lastModified(__FILE__));
}

/****************************************************
 * Does file/directory exist?
 */

bool exists(in char[] name)
{
    return access(toStringz(name), 0) == 0;
}

unittest
{
    assert(exists("."));
    assert(!exists("this file does not exist"));
    system("touch deleteme") == 0 || assert(false);
    scope(exit) remove("deleteme");
    assert(exists("deleteme"));
}

/****************************************************
 * Is name a file?
 */

bool isfile(in string name)
{
    return (getAttributes(name) & S_IFMT) == S_IFREG;	// regular file
}

/****************************************************
 * Is name a directory?
 */

bool isdir(in string name)
{
    return (getAttributes(name) & S_IFMT) == S_IFDIR;
}

/****************************************************
 * Change directory.
 */

void chdir(string pathname)
{
    cenforce(std.c.linux.linux.chdir(toStringz(pathname)) == 0, pathname);
}

/****************************************************
 * Make directory.
 */

void mkdir(in char[] pathname)
{
    cenforce(std.c.linux.linux.mkdir(toStringz(pathname), 0777) == 0, pathname);
}

/****************************************************
 * Make directory and all parent directories as needed.
 */

void mkdirRecurse(in char[] pathname)
{
    auto left = dirname(pathname);
    exists(left) || mkdirRecurse(left);
    mkdir(pathname);
}

/****************************************************
 * Remove directory.
 */

void rmdir(string pathname)
{
    cenforce(std.c.linux.linux.rmdir(toStringz(pathname)) == 0, pathname);
}

/****************************************************
Remove directory and all of its content and subdirectories,
recursively.
 */

void rmdirRecurse(string pathname)
{
    // all children, recursively depth-first
    foreach (DirEntry e; dirEntries(pathname, SpanMode.depth))
    {
        e.isdir ? rmdir(e.name) : remove(e.name);
    }
    // the dir itself
    rmdir(pathname);
}

unittest
{
    auto d = "/tmp/deleteme/a/b/c/d/e/f/g";
    enforce(collectException(mkdir(d)));
    mkdirRecurse(d);
    rmdirRecurse("/tmp/deleteme");
    enforce(!exists("/tmp/deleteme"));
}

/****************************************************
 * Get current directory.
 */

string getcwd()
{
    auto p = cenforce(std.c.linux.linux.getcwd(null, 0),
            "cannot get cwd");
    scope(exit) std.c.stdlib.free(p);
    return p[0 .. std.c.string.strlen(p)].idup;
}

/***************************************************
 * Directory Entry
 */

struct DirEntry
{
    string name;			/// file or directory name
    ulong _size = ~0UL;			// size of file in bytes
    d_time _creationTime = d_time_nan;	// time of file creation
    d_time _lastAccessTime = d_time_nan; // time file was last accessed
    d_time _lastWriteTime = d_time_nan;	// time file was last written to
    ubyte d_type;
    struct_stat statbuf;
    bool didstat;			// done lazy evaluation of stat()

    void init(string path, dirent *fd)
    {
        invariant len = std.c.string.strlen(fd.d_name.ptr);
	name = std.path.join(path, fd.d_name[0 .. len].idup);
	d_type = fd.d_type;
	didstat = false;
    }

    bool isdir()
    {
	return (d_type & DT_DIR) != 0;
    }

    bool isfile()
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
	enforce(std.c.linux.linux.stat(toStringz(name), &statbuf) == 0,
                "Failed to stat file `"~name~"'");
	_size = cast(ulong)statbuf.st_size;
	version (linux)
	{
	    _creationTime = cast(d_time)statbuf.st_ctime * std.date.TicksPerSecond;
	    _lastAccessTime = cast(d_time)statbuf.st_atime * std.date.TicksPerSecond;
	    _lastWriteTime = cast(d_time)statbuf.st_mtime * std.date.TicksPerSecond;
	}
	else version (OSX)
	{
	    _creationTime =   cast(d_time)statbuf.st_ctimespec.tv_sec * std.date.TicksPerSecond;
	    _lastAccessTime = cast(d_time)statbuf.st_atimespec.tv_sec * std.date.TicksPerSecond;
	    _lastWriteTime =  cast(d_time)statbuf.st_mtimespec.tv_sec * std.date.TicksPerSecond;
	}
	else
	{
	    static assert(0);
	}

	didstat = true;
    }
}


/***************************************************
 * Return contents of directory.
 */

string[] listdir(string pathname)
{
    string[] result;
    bool listing(string filename)
    {
	result ~= filename;
	return true; // continue
    }

    listdir(pathname, &listing);
    return result;
}

string[] listdir(string pathname, string pattern)
{   string[] result;
    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (std.path.fnmatch(de.name, pattern))
		result ~= de.name;
	}
	return true; // continue
    }
    
    listdir(pathname, &callback);
    return result;
}

string[] listdir(string pathname, RegExp r)
{   string[] result;

    bool callback(DirEntry* de)
    {
	if (de.isdir)
	    listdir(de.name, &callback);
	else
	{   if (r.test(de.name))
		result ~= de.name;
	}
	return true; // continue
    }

    listdir(pathname, &callback);
    return result;
}

void listdir(string pathname, bool delegate(string filename) callback)
{
    bool listing(DirEntry* de)
    {
	return callback(std.path.getBaseName(de.name));
    }

    listdir(pathname, &listing);
}

void listdir(string pathname, bool delegate(DirEntry* de) callback)
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
 * Copy a file. File timestamps are preserved.
 */

void copy(in string from, in string to)
{
    version (all)
    {
        invariant fd = std.c.linux.linux.open(toStringz(from), O_RDONLY);
        cenforce(fd != -1, from);
        scope(exit) std.c.linux.linux.close(fd);

        struct_stat statbuf = void;
        cenforce(std.c.linux.linux.fstat(fd, &statbuf) == 0, from);

        auto toz = toStringz(to);
        invariant fdw = std.c.linux.linux.open(toz,
                O_CREAT | O_WRONLY | O_TRUNC, 0660);
        cenforce(fdw != -1, from);
        scope(failure) std.c.stdio.remove(toz);
        {
            scope(failure) std.c.linux.linux.close(fdw);
            auto BUFSIZ = 4096u * 16;
            auto buf = std.c.stdlib.malloc(BUFSIZ);
            if (!buf)
            {
                BUFSIZ = 4096;
                buf = enforce(std.c.stdlib.malloc(BUFSIZ), "Out of memory");
            }
            scope(exit) std.c.stdlib.free(buf);

            for (size_t size = statbuf.st_size; size; )
            {
                invariant toxfer = (size > BUFSIZ) ? BUFSIZ : size;
                cenforce(std.c.linux.linux.read(fd, buf, toxfer) == toxfer
                        && std.c.linux.linux.write(fdw, buf, toxfer) == toxfer,
                        from);
                assert(size >= toxfer);
                size -= toxfer;
            }
        }

        cenforce(std.c.linux.linux.close(fdw) != -1, from);

    utimbuf utim = void;
    version (linux)
    {
	utim.actime = cast(__time_t)statbuf.st_atime;
	utim.modtime = cast(__time_t)statbuf.st_mtime;
    }
    else version (OSX)
    {
	utim.actime = cast(__time_t)statbuf.st_atimespec.tv_sec;
	utim.modtime = cast(__time_t)statbuf.st_mtimespec.tv_sec;
    }
    else
    {
	static assert(0);
    }


        cenforce(utime(toz, &utim) != -1, from);
    }
    else
    {
        void[] buffer;
        buffer = read(from);
        write(to, buffer);
        delete buffer;
    }
}



}

unittest
{
    //printf("std.file.unittest\n");
    void[] buf;

    buf = new void[10];
    (cast(byte[])buf)[] = 3;
    write("unittest_write.tmp", buf);
    void buf2[] = read("unittest_write.tmp");
    assert(buf == buf2);

    copy("unittest_write.tmp", "unittest_write2.tmp");
    buf2 = read("unittest_write2.tmp");
    assert(buf == buf2);

    remove("unittest_write.tmp");
    if (exists("unittest_write.tmp"))
	assert(0);
    remove("unittest_write2.tmp");
    if (exists("unittest_write2.tmp"))
	assert(0);
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
        static if (is(Parms[0] : string))
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

    int opApply(D)(D dg)
    {
        int result = 0;
        string[] worklist = [ pathname ]; // used only in breadth-first traversal

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
    assert(system("mkdir --parents dmd-testing") == 0);
    scope(exit) system("rm -rf dmd-testing");
    assert(system("mkdir --parents dmd-testing/somedir") == 0);
    assert(system("touch dmd-testing/somefile") == 0);
    assert(system("touch dmd-testing/somedir/somedeepfile") == 0);
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
