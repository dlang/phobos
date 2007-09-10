
// Copyright (c) 2001-2002 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

import c.stdio;
import string;

/***********************************
 */

class FileError : Error
{
    import syserror;

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

import windows;

/********************************************
 * Read a file.
 * Returns:
 *	array of bytes read
 */

byte[] read(char[] name)
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
    throw new FileError(name, GetLastError());
}

/*********************************************
 * Write a file.
 * Returns:
 *	0	success
 */

void write(char[] name, byte[] buffer)
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
    throw new FileError(name, GetLastError());
}


/*********************************************
 * Append to a file.
 */

void append(char[] name, byte[] buffer)
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
    throw new FileError(name, GetLastError());
}


/***************************************************
 * Rename a file.
 */

void rename(char[] from, char[] to)
{
    BOOL result;

    result = MoveFileA(toStringz(from), toStringz(to));
    if (!result)
	throw new FileError(to, GetLastError());
}


/***************************************************
 * Delete a file.
 */

void remove(char[] name)
{
    BOOL result;

    result = DeleteFileA(toStringz(name));
    if (!result)
	throw new FileError(name, GetLastError());
}


/***************************************************
 * Get file size.
 */

uint getSize(char[] name)
{
    WIN32_FIND_DATA filefindbuf;
    HANDLE findhndl;

    findhndl = FindFirstFileA(toStringz(name), &filefindbuf);
    if (findhndl == (HANDLE)-1)
    {
	throw new FileError(name, GetLastError());
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
	throw new FileError(name, GetLastError());
    }
    return result;
}

}

/* =========================== linux ======================= */

version (linux)
{

import linux;

/********************************************
 * Read a file.
 * Returns:
 *	array of bytes read
 */

byte[] read(char[] name)
{
    uint size;
    uint numread;
    int fd;
    stat statbuf;
    byte[] buf;
    char *namez;

    namez = toStringz(name);
    //printf("file.read('%s')\n",namez);
    fd = linux.open(namez, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",getErrno());
        goto err1;
    }

    //printf("\tfile opened\n");
    if (linux.fstat(fd, &statbuf))
    {
        //printf("\tfstat error, errno = %d\n",getErrno());
        goto err2;
    }
    size = statbuf.st_size;
    buf = new byte[size];

    numread = linux.read(fd, (char*)buf, size);
    if (numread != size)
    {
        //printf("\tread error, errno = %d\n",getErrno());
        goto err2;
    }

    if (linux.close(fd) == -1)
    {
	//printf("\tclose error, errno = %d\n",getErrno());
        goto err;
    }

    return buf;

err2:
    linux.close(fd);
err:
    delete buf;

err1:
    throw new FileError(name, getErrno());
}

/*********************************************
 * Write a file.
 * Returns:
 *	0	success
 */

void write(char[] name, byte[] buffer)
{
    int fd;
    int numwritten;
    int len;
    char *namez;

    namez = toStringz(name);
    fd = linux.open(namez, O_CREAT | O_WRONLY | O_TRUNC, 0660);
    if (fd == -1)
        goto err;

    numwritten = linux.write(fd, buffer, len);
    if (len != numwritten)
        goto err2;

    if (linux.close(fd) == -1)
        goto err;

    return;

err2:
    linux.close(fd);
err:
    throw new FileError(name, getErrno());
}


/*********************************************
 * Append to a file.
 */

void append(char[] name, byte[] buffer)
{
    int fd;
    int numwritten;
    int len;
    char *namez;

    namez = toStringz(name);
    fd = linux.open(namez, O_APPEND | O_WRONLY | O_CREAT, 0660);
    if (fd == -1)
        goto err;

    numwritten = linux.write(fd, buffer, len);
    if (len != numwritten)
        goto err2;

    if (linux.close(fd) == -1)
        goto err;

    return;

err2:
    linux.close(fd);
err:
    throw new FileError(name, getErrno());
}


/***************************************************
 * Rename a file.
 */

void rename(char[] from, char[] to)
{
    char *fromz = toStringz(from);
    char *toz = toStringz(to);

    if (c.stdio.rename(fromz, toz) == -1)
	throw new FileError(to, getErrno());
}


/***************************************************
 * Delete a file.
 */

void remove(char[] name)
{
    if (c.stdio.remove(toStringz(name)) == -1)
	throw new FileError(name, getErrno());
}


/***************************************************
 * Get file size.
 */

uint getSize(char[] name)
{
    uint size;
    int fd;
    stat statbuf;
    char *namez;

    namez = toStringz(name);
    //printf("file.getSize('%s')\n",namez);
    fd = linux.open(namez, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",getErrno());
        goto err1;
    }

    //printf("\tfile opened\n");
    if (linux.fstat(fd, &statbuf))
    {
        //printf("\tfstat error, errno = %d\n",getErrno());
        goto err2;
    }
    size = statbuf.st_size;

    if (linux.close(fd) == -1)
    {
	//printf("\tclose error, errno = %d\n",getErrno());
        goto err;
    }

    return size;

err2:
    linux.close(fd);
err:
err1:
    throw new FileError(name, getErrno());
}


/***************************************************
 * Get file attributes.
 */

uint getAttributes(char[] name)
{
    return 0;
}

}
