
// Copyright (c) 2001 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

import object;
import stdio;

class FileException : Exception
{
    this(char[] name)
    {
	msg = "file I/O " ~ name;
    }
}


class File
{

    import windows;

    /********************************************
     * Read a file.
     * Output:
     *	*pbuffer is set to a malloc'd buffer with the file contents
     *	*psize is set to file size
     * Returns:
     *	0	success
     *	!=0	error
     */

    static char[] read(char[] name)
    {
	DWORD size;
	DWORD numread;
	HANDLE h;
	char[] buf;

	h = CreateFileA((char*)name,GENERIC_READ,FILE_SHARE_READ,null,OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,(HANDLE)null);
	if (h == INVALID_HANDLE_VALUE)
	    goto err1;

	size = GetFileSize(h, null);
	buf = new char[size + 3];

	if (ReadFile(h,buf,size,&numread,null) != 1)
	    goto err2;

	if (numread != size)
	    goto err2;

	if (!CloseHandle(h))
	    goto err;

	// Always store a 0 past end of buffer so scanner has a sentinel
	buf[size] = 0;
	buf[size + 1] = 0;
	buf[size + 2] = 0;
	return buf;

    err2:
	CloseHandle(h);
    err:
	delete buf;
    err1:
	throw new FileException(name);
    }

    /*********************************************
     * Write a file.
     * Returns:
     *	0	success
     */

    static void write(char[] name, char[] buffer)
    {
	HANDLE h;
	DWORD numwritten;

	h = CreateFileA(name,GENERIC_WRITE,0,null,CREATE_ALWAYS,
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
	throw new FileException(name);
    }


    /*********************************************
     * Append to a file.
     */

    static void append(char[] name, char[] buffer)
    {
	HANDLE h;
	DWORD numwritten;

	h = CreateFileA(name,GENERIC_WRITE,0,null,OPEN_ALWAYS,
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
	throw new FileException(name);
    }

}
