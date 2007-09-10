
// Copyright (C) 2003 by Digital Mars, www.digitalmars.com
// All Rights Reserved
// Written by Walter Bright

/* These are all the globals defined by the linux C runtime library.
 * Put them separate so they'll be externed - do not link in linuxextern.o
 */

extern (C)
{
    void* __libc_stack_end;
    int __data_start;
    int _end;
    int timezone;

    void *_deh_beg;
    void *_deh_end;
}

