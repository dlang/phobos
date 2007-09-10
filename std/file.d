
// Copyright (c) 2001-2003 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

module std.file;

private import std.c.stdio;
private import std.path;
private import std.string;

/***********************************
 */

class FileException : Exception
{
    private import std.syserror;

    uint errno;			// operating system error code

    this(char[] name)
    {
	this(name, "file I/O");
    }

    this(char[] name, char[] message)
    {
	super(name ~ ": " ~ message);
    }

    this(char[] name, uint errno)
    {
	this(name, SysError.msg(errno));
	this.errno = errno;
    }
}

/***********************************
 * Basic File operations.
 */

/* =========================== Win32 ======================= */

version (Win32)
{

private import std.c.windows.windows;

/********************************************
 * Read a file.
 * Returns:
 *	array of bytes read
 */

void[] read(char[] name)
{
    DWORD size;
    DWORD numread;
    HANDLE h;
    byte[] buf;
    char* namez;

    namez = toStringz(name);
    h = CreateFileA(namez,GENERIC_READ,FILE_SHARE_READ,null,OPEN_EXISTING,
	FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,(HANDLE)null);
    if (h == INVALID_HANDLE_VALUE)
	goto err1;

    size = GetFileSize(h, null);
    buf = new byte[size];

    if (ReadFile(h,buf,size,&numread,null) != 1)
	goto err2;

    if (numread != size)
	goto err2;

    if (!CloseHandle(h))
	goto err;

    return buf;

err2:
    CloseHandle(h);
err:
    delete buf;
err1:
    throw new FileException(name, GetLastError());
}

/*********************************************
 * Write a file.
 * Returns:
 *	0	success
 */

void write(char[] name, void[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    h = CreateFileA(toStringz(name),GENERIC_WRITE,0,null,CREATE_ALWAYS,
	FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,(HANDLE)null);
    if (h == INVALID_HANDLE_VALUE)
	goto err;

    if (WriteFile(h,buffer,buffer.length,&numwritten,null) != 1)
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
 * Append to a file.
 */

void append(char[] name, void[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    h = CreateFileA(toStringz(name),GENERIC_WRITE,0,null,OPEN_ALWAYS,
	FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,(HANDLE)null);
    if (h == INVALID_HANDLE_VALUE)
	goto err;

    SetFilePointer(h, 0, null, FILE_END);

    if (WriteFile(h,buffer,buffer.length,&numwritten,null) != 1)
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
 * Rename a file.
 */

void rename(char[] from, char[] to)
{
    BOOL result;

    result = MoveFileA(toStringz(from), toStringz(to));
    if (!result)
	throw new FileException(to, GetLastError());
}


/***************************************************
 * Delete a file.
 */

void remove(char[] name)
{
    BOOL result;

    result = DeleteFileA(toStringz(name));
    if (!result)
	throw new FileException(name, GetLastError());
}


/***************************************************
 * Get file size.
 */

ulong getSize(char[] name)
{
    WIN32_FIND_DATA filefindbuf;
    HANDLE findhndl;

    findhndl = FindFirstFileA(toStringz(name), &filefindbuf);
    if (findhndl == (HANDLE)-1)
    {
	throw new FileException(name, GetLastError());
    }
    FindClose(findhndl);
    return filefindbuf.nFileSizeLow;
}


/***************************************************
 * Get file attributes.
 */

uint getAttributes(char[] name)
{
    uint result;

    result = GetFileAttributesA(toStringz(name));
    if (result == 0xFFFFFFFF)
    {
	throw new FileException(name, GetLastError());
    }
    return result;
}

/****************************************************
 * Is name a file?
 */

int isfile(char[] name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

/****************************************************
 * Is name a directory?
 */

int isdir(char[] name)
{
    return (getAttributes(name) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

/****************************************************
 * Change directory.
 */

void chdir(char[] pathname)
{
    if (!SetCurrentDirectoryA(toStringz(pathname)))
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Make directory.
 */

void mkdir(char[] pathname)
{
    if (!CreateDirectoryA(toStringz(pathname), null))
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Remove directory.
 */

void rmdir(char[] pathname)
{
    if (!RemoveDirectoryA(toStringz(pathname)))
    {
	throw new FileException(pathname, GetLastError());
    }
}

/****************************************************
 * Get current directory.
 */

char[] getcwd()
{
    char[] dir;
    int length;
    char c;

    length = GetCurrentDirectoryA(0, &c);
    if (!length)
    {
	throw new FileException("getcwd", GetLastError());
    }
    dir = new char[length];
    length = GetCurrentDirectoryA(length, dir);
    if (!length)
    {
	throw new FileException("getcwd", GetLastError());
    }
    return dir[0 .. length];		// leave off terminating 0
}

/***************************************************
 * Return contents of directory.
 */

char[][] listdir(char[] pathname)
{
    char[][] result;
    char[] c;
    HANDLE h;
    WIN32_FIND_DATA fileinfo;

    c = std.path.join(pathname, "*.*");
    h = FindFirstFileA(toStringz(c), &fileinfo);
    if (h != INVALID_HANDLE_VALUE)
    {
        do
        {   int i;
	    int clength;

            // Skip "." and ".."
            if (std.string.strcmp(fileinfo.cFileName, ".") == 0 ||
                std.string.strcmp(fileinfo.cFileName, "..") == 0)
                continue;

	    i = result.length;
	    result.length = i + 1;
	    clength = std.string.strlen(fileinfo.cFileName);
	    result[i] = new char[clength];
	    result[i][] = fileinfo.cFileName[0 .. clength];
        } while (FindNextFileA(h,&fileinfo) != FALSE);
        FindClose(h);
    }
    return result;
}

}

/* =========================== linux ======================= */

version (linux)
{

private import std.c.linux.linux;

/********************************************
 * Read a file.
 * Returns:
 *	array of bytes read
 */

void[] read(char[] name)
{
    uint size;
    uint numread;
    int fd;
    struct_stat statbuf;
    byte[] buf;
    char *namez;

    namez = toStringz(name);
    //printf("file.read('%s')\n",namez);
    fd = std.c.linux.linux.open(namez, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",getErrno());
        goto err1;
    }

    //printf("\tfile opened\n");
    if (std.c.linux.linux.fstat(fd, &statbuf))
    {
        //printf("\tfstat error, errno = %d\n",getErrno());
        goto err2;
    }
    size = statbuf.st_size;
    buf = new byte[size];

    numread = std.c.linux.linux.read(fd, (char*)buf, size);
    if (numread != size)
    {
        //printf("\tread error, errno = %d\n",getErrno());
        goto err2;
    }

    if (std.c.linux.linux.close(fd) == -1)
    {
	//printf("\tclose error, errno = %d\n",getErrno());
        goto err;
    }

    return buf;

err2:
    std.c.linux.linux.close(fd);
err:
    delete buf;

err1:
    throw new FileException(name, getErrno());
}

/*********************************************
 * Write a file.
 * Returns:
 *	0	success
 */

void write(char[] name, void[] buffer)
{
    int fd;
    int numwritten;
    char *namez;

    namez = toStringz(name);
    fd = std.c.linux.linux.open(namez, O_CREAT | O_WRONLY | O_TRUNC, 0660);
    if (fd == -1)
        goto err;

    numwritten = std.c.linux.linux.write(fd, buffer, buffer.length);
    if (buffer.length != numwritten)
        goto err2;

    if (std.c.linux.linux.close(fd) == -1)
        goto err;

    return;

err2:
    std.c.linux.linux.close(fd);
err:
    throw new FileException(name, getErrno());
}


/*********************************************
 * Append to a file.
 */

void append(char[] name, void[] buffer)
{
    int fd;
    int numwritten;
    char *namez;

    namez = toStringz(name);
    fd = std.c.linux.linux.open(namez, O_APPEND | O_WRONLY | O_CREAT, 0660);
    if (fd == -1)
        goto err;

    numwritten = std.c.linux.linux.write(fd, buffer, buffer.length);
    if (buffer.length != numwritten)
        goto err2;

    if (std.c.linux.linux.close(fd) == -1)
        goto err;

    return;

err2:
    std.c.linux.linux.close(fd);
err:
    throw new FileException(name, getErrno());
}


/***************************************************
 * Rename a file.
 */

void rename(char[] from, char[] to)
{
    char *fromz = toStringz(from);
    char *toz = toStringz(to);

    if (std.c.stdio.rename(fromz, toz) == -1)
	throw new FileException(to, getErrno());
}


/***************************************************
 * Delete a file.
 */

void remove(char[] name)
{
    if (std.c.stdio.remove(toStringz(name)) == -1)
	throw new FileException(name, getErrno());
}


/***************************************************
 * Get file size.
 */

ulong getSize(char[] name)
{
    uint size;
    int fd;
    struct_stat statbuf;
    char *namez;

    namez = toStringz(name);
    //printf("file.getSize('%s')\n",namez);
    fd = std.c.linux.linux.open(namez, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",getErrno());
        goto err1;
    }

    //printf("\tfile opened\n");
    if (std.c.linux.linux.fstat(fd, &statbuf))
    {
        //printf("\tfstat error, errno = %d\n",getErrno());
        goto err2;
    }
    size = statbuf.st_size;

    if (std.c.linux.linux.close(fd) == -1)
    {
	//printf("\tclose error, errno = %d\n",getErrno());
        goto err;
    }

    return size;

err2:
    std.c.linux.linux.close(fd);
err:
err1:
    throw new FileException(name, getErrno());
}


/***************************************************
 * Get file attributes.
 */

uint getAttributes(char[] name)
{
    struct_stat statbuf;
    char *namez;

    namez = toStringz(name);
    if (std.c.linux.linux.stat(namez, &statbuf))
    {
	throw new FileException(name, getErrno());
    }

    return statbuf.st_mode;
}

/****************************************************
 * Is name a file?
 */

int isfile(char[] name)
{
    return getAttributes(name) & S_IFREG;	// regular file
}

/****************************************************
 * Is name a directory?
 */

int isdir(char[] name)
{
    return getAttributes(name) & S_IFDIR;
}

/****************************************************
 * Change directory.
 */

void chdir(char[] pathname)
{
    if (std.c.linux.linux.chdir(toStringz(pathname)) == 0)
    {
	throw new FileException(pathname, getErrno());
    }
}

/****************************************************
 * Make directory.
 */

void mkdir(char[] pathname)
{
    if (std.c.linux.linux.mkdir(toStringz(pathname), 0777) == 0)
    {
	throw new FileException(pathname, getErrno());
    }
}

/****************************************************
 * Remove directory.
 */

void rmdir(char[] pathname)
{
    if (std.c.linux.linux.rmdir(toStringz(pathname)) == 0)
    {
	throw new FileException(pathname, getErrno());
    }
}

/****************************************************
 * Get current directory.
 */

char[] getcwd()
{   char* p;

    p = std.c.linux.linux.getcwd(null, 0);
    if (!p)
    {
	throw new FileException("cannot get cwd", getErrno());
    }

    int length = std.string.strlen(p);
    char[] buf = new char[length];
    buf[] = p[0 .. length];
    std.c.stdlib.free(p);
    return buf;
}

/***************************************************
 * Return contents of directory.
 */

char[][] listdir(char[] pathname)
{
    assert(0);		// BUG: not implemented
    return null;
}

}
