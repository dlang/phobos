
// Copyright (c) 2001 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

import stdio;
import string;

/***********************************
 */

class FileException : Exception
{
    import syserror;

    uint errno;			// operating system error code

    this(char[] name)
    {
	this(name, "file I/O");
    }

    this(char[] name, char[] message)
    {
	msg = name ~ ": " ~ message;
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

    namez = toCharz(name);
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

void write(char[] name, byte[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    h = CreateFileA(toCharz(name),GENERIC_WRITE,0,null,CREATE_ALWAYS,
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

void append(char[] name, byte[] buffer)
{
    HANDLE h;
    DWORD numwritten;

    h = CreateFileA(toCharz(name),GENERIC_WRITE,0,null,OPEN_ALWAYS,
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

    result = MoveFileA(toCharz(from), toCharz(to));
    if (!result)
	throw new FileException(to, GetLastError());
}


/***************************************************
 * Delete a file.
 */

void remove(char[] name)
{
    BOOL result;

    result = DeleteFileA(toCharz(name));
    if (!result)
	throw new FileException(name, GetLastError());
}


/***************************************************
 * Get file size.
 */

uint getSize(char[] name)
{
    WIN32_FIND_DATA filefindbuf;
    HANDLE findhndl;

    findhndl = FindFirstFileA(toCharz(name), filefindbuf);
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

    result = GetFileAttributesA(toCharz(name));
    if (result == 0xFFFFFFFF)
    {
	throw new FileException(name, GetLastError());
    }
    return result;
}
