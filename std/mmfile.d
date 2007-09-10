// Copyright (c) 2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright and Matthew Wilson (Sysesis Software Pty Ltd.)
// www.digitalmars.com
// www.synesis.com.au/software

/*
 * Memory mapped files.
 */

module mmfile;

private import std.file;
private import std.c.stdio;
private import std.path;
private import std.string;

//debug = MMFILE;

version (Win32)
{
    private import std.c.windows.windows;
    private import std.utf;

    private int useWfuncs = 1;
    private uint dwVersion;

    static this()
    {	// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/sysinfo/base/getversion.asp
	dwVersion = GetVersion();

	// Win 95, 98, ME do not implement the W functions
	useWfuncs = (dwVersion < 0x80000000);
    }
}
else version (linux)
{
    private import std.c.linux.linux;
}
else
{
    static assert(0);
}


auto class MmFile
{
    enum Mode
    {	Read,		// read existing file
	ReadWriteNew,	// delete existing file, write new file
	ReadWrite,	// read/write existing file, create if not existing
	ReadCopyOnWrite, // read/write existing file, copy on write
    }

    /* Open for reading
     */
    this(char[] filename)
    {
	this(filename, Mode.Read, 0, null);
    }

    /* Open
     */
    this(char[] filename, Mode mode, size_t size, void* address)
    {
	this.filename = filename;

	version (Win32)
	{
	    void* p;
	    uint dwDesiredAccess2;
	    uint dwShareMode;
	    uint dwCreationDisposition;
	    uint dwDesiredAccess;
	    uint flProtect;

	    if (dwVersion & 0x80000000 && (dwVersion & 0xFF) == 3)
	    {
		throw new FileException(filename,
		    "Win32s does not implement mm files");
	    }

	    switch (mode)
	    {
		case Mode.Read:
		    dwDesiredAccess2 = GENERIC_READ;
		    dwShareMode = FILE_SHARE_READ;
		    dwCreationDisposition = OPEN_EXISTING;
		    flProtect = PAGE_READONLY;
		    dwDesiredAccess = FILE_MAP_READ;
		    break;

		case Mode.ReadWriteNew:
		    assert(size != 0);
		    dwDesiredAccess2 = GENERIC_READ | GENERIC_WRITE;
		    dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
		    dwCreationDisposition = CREATE_ALWAYS;
		    flProtect = PAGE_READWRITE;
		    dwDesiredAccess = FILE_MAP_WRITE;
		    break;

		case Mode.ReadWrite:
		    dwDesiredAccess2 = GENERIC_READ | GENERIC_WRITE;
		    dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
		    dwCreationDisposition = OPEN_ALWAYS;
		    flProtect = PAGE_READWRITE;
		    dwDesiredAccess = FILE_MAP_WRITE;
		    break;

		case Mode.ReadCopyOnWrite:
		    if (dwVersion & 0x80000000)
		    {
			throw new FileException(filename,
			    "Win9x does not implement copy on write");
		    }
		    dwDesiredAccess2 = GENERIC_READ | GENERIC_WRITE;
		    dwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
		    dwCreationDisposition = OPEN_EXISTING;
		    flProtect = PAGE_WRITECOPY;
		    dwDesiredAccess = FILE_MAP_COPY;
		    break;
	    }

	    if (useWfuncs)
	    {
		wchar* namez = std.utf.toUTF16z(filename);
		hFile = CreateFileW(namez,
			dwDesiredAccess2,
			dwShareMode,
			null,
			dwCreationDisposition,
			FILE_ATTRIBUTE_NORMAL,
			cast(HANDLE)null);
	    }
	    else
	    {
		char* namez = std.file.toMBSz(filename);
		hFile = CreateFileA(namez,
			dwDesiredAccess2,
			dwShareMode,
			null,
			dwCreationDisposition,
			FILE_ATTRIBUTE_NORMAL,
			cast(HANDLE)null);
	    }
	    if (hFile == INVALID_HANDLE_VALUE)
		goto err1;

	    hFileMap = CreateFileMappingA(hFile, null, flProtect, 0, size, null);
	    if (hFileMap == null)               // mapping failed
		goto err1;

	    p = MapViewOfFileEx(hFileMap, dwDesiredAccess, 0, 0, size, address);
	    if (p == null)                      // mapping view failed
	    {
		goto err1;
	    }
	    if (size == 0)
		size = GetFileSize(hFile, null);

	    debug (MMFILE) printf("MmFile.this(): p = %p, size = %d\n", p, size);
	    data = p[0 .. size];
	    return;

	  err1:
	    if (hFileMap != null)
		CloseHandle(hFileMap);
	    hFileMap = null;

	    if (hFile != INVALID_HANDLE_VALUE)
		CloseHandle(hFile);
	    hFile = INVALID_HANDLE_VALUE;

	    errNo();
	}
	else version (linux)
	{
	    char* namez = toStringz(filename);
	    void* p;
	    int fd;
	    int prot;
	    int flags;
	    int oflag;
	    int fmode;

	    switch (mode)
	    {
		case Mode.Read:
		    flags = MAP_SHARED;
		    prot = PROT_READ;
		    oflag = O_RDONLY;
		    fmode = 0;
		    break;

		case Mode.ReadWriteNew:
		    assert(size != 0);
		    flags = MAP_SHARED;
		    prot = PROT_READ | PROT_WRITE;
		    oflag = O_CREAT | O_RDWR | O_TRUNC;
		    fmode = 0660;
		    break;

		case Mode.ReadWrite:
		    flags = MAP_SHARED;
		    prot = PROT_READ | PROT_WRITE;
		    oflag = O_CREAT | O_RDWR;
		    fmode = 0660;
		    break;

		case Mode.ReadCopyOnWrite:
		    flags = MAP_PRIVATE;
		    prot = PROT_READ | PROT_WRITE;
		    oflag = O_RDWR;
		    fmode = 0;
		    break;
	    }

	    if (filename.length)
	    {
		struct_stat statbuf;

		fd = std.c.linux.linux.open(namez, oflag, fmode);
		if (fd == -1)
		{
		    printf("\topen error, errno = %d\n",getErrno());
		    errNo();
		}

		if (std.c.linux.linux.fstat(fd, &statbuf))
		{
		    //printf("\tfstat error, errno = %d\n",getErrno());
		    std.c.linux.linux.close(fd);
		    errNo();
		}

		if (prot & PROT_WRITE && size > statbuf.st_size)
		{
		    // Need to make the file size bytes big
		    std.c.linux.linux.lseek(fd, size - 1, SEEK_SET);
		    char c = 0;
		    std.c.linux.linux.write(fd, &c, 1);
		}
		else if (prot & PROT_READ && size == 0)
		    size = statbuf.st_size;
	    }
	    else
	    {
		fd = -1;
		flags |= MAP_ANONYMOUS;
	    }

	    p = mmap(address, size, prot, flags, fd, 0);
	    //printf(" p = %x, size = %d\n", p, size);

	    /* Memory mapping stays active even if we close the handle.
	     * Closing it now avoids worrys about closing it during error
	     * recovery.
	     */
	    if (fd != -1 && std.c.linux.linux.close(fd) == -1)
		errNo();

	    if (p == MAP_FAILED)		// in sys/mman.h
		errNo();
	    data = p[0 .. size];
	}
	else
	{
	    static assert(0);
	}
    }

    ~this()
    {
	debug (MMFILE) printf("MmFile.~this()\n");
	version (Win32)
	{
	    /* Note that under Windows 95, UnmapViewOfFile() seems to return
	     * random values, not TRUE or FALSE.
	     */
	    if (data && UnmapViewOfFile(data) == FALSE &&
		(dwVersion & 0x80000000) == 0)
		errNo();
	    data = null;

	    if (hFileMap != null && CloseHandle(hFileMap) != TRUE)
		errNo();
	    hFileMap = null;

	    if (hFile != INVALID_HANDLE_VALUE && CloseHandle(hFile) != TRUE)
		errNo();
	    hFile = INVALID_HANDLE_VALUE;
	}
	else version (linux)
	{
	    int i;

	    i = munmap(cast(void*)data, data.length);
	    if (i != 0)
		errNo();
	}
	else
	{
	    static assert(0);
	}
	data = null;
    }

    /* Flush any pending output.
     */
    void flush()
    {
	debug (MMFILE) printf("MmFile.flush()\n");
	version (Win32)
	{
	    FlushViewOfFile(data, data.length);
	}
	else version (linux)
	{
	    int i;

	    i = msync(cast(void*)data, data.length, MS_SYNC);	// sys/mman.h
	    if (i != 0)
		errNo();
	}
	else
	{
	    static assert(0);
	}
    }

    size_t length()
    {
	debug (MMFILE) printf("MmFile.length()\n");
	return data.length;
    }

    void[] opSlice()
    {
	debug (MMFILE) printf("MmFile.opSlice()\n");
	return data;
    }

    void[] opSlice(size_t i1, size_t i2)
    {
	debug (MMFILE) printf("MmFile.opSlice(%d, %d)\n", i1, i2);
	return data[i1 .. i2];
    }

    ubyte opIndex(size_t i)
    {
	debug (MMFILE) printf("MmFile.opIndex(%d)\n", i);
	return (cast(ubyte[])data)[i];
    }

    ubyte opIndex(size_t i, ubyte value)
    {
	debug (MMFILE) printf("MmFile.opIndex(%d, %d)\n", i, value);
	return (cast(ubyte[])data)[i] = value;
    }


  private:
    char[] filename;
    void[] data;

    version (Win32)
    {
	HANDLE hFile = INVALID_HANDLE_VALUE;
	HANDLE hFileMap = null;
    }
    else version (linux)
    {
    }
    else
    {
	static assert(0);
    }

    // Report error, where errno gives the error number
    void errNo()
    {
	version (Win32)
	{
	    throw new FileException(filename, GetLastError());
	}
	else version (linux)
	{
	    throw new FileException(filename, getErrno());
	}
	else
	{
	    static assert(0);
	}
    }
}

/*
	version (Win32)
	{
	}
	else version (linux)
	{
	}
	else
	{
	    static assert(0);
	}
*/

