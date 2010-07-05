
// Copyright (C) 2001-2009 by Digital Mars, http://www.digitalmars.com
// All Rights Reserved
// Written by Walter Bright

//import std.c.linux.linuxextern;

version (FreeBSD)
    import std.c.freebsd.freebsd;
else version (Solaris)
    import std.c.solaris.solaris;
else
    import std.c.linux.linux;

version (OSX)
{
    extern (C)
    {
        uint get_end();
        uint get_etext();
        uint get_edata();

        extern void* __osx_stack_end;   // set by D startup code
    }
}

version (FreeBSD)
{
    extern (C)
    {
        extern char etext;
    }
}

version (Solaris)
{
    extern (C)
    {
        extern char etext;
    }
}

/+
extern (C)
{
    // from <sys/mman.h>
    void* mmap(void* addr, uint len, int prot, int flags, int fd, uint offset);
    int munmap(void* addr, uint len);
    const void* MAP_FAILED = cast(void*)-1;

    // from <bits/mman.h>
    enum { PROT_NONE = 0, PROT_READ = 1, PROT_WRITE = 2, PROT_EXEC = 4 }
    enum { MAP_SHARED = 1, MAP_PRIVATE = 2, MAP_TYPE = 0x0F,
           MAP_FIXED = 0x10, MAP_FILE = 0, MAP_ANON = 0x20 }
}
+/

/***********************************
 * Map memory.
 */

void *os_mem_map(uint nbytes)
{   void *p;

    //errno = 0;
    p = mmap(null, nbytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    return (p == MAP_FAILED) ? null : p;
}

/***********************************
 * Commit memory.
 * Returns:
 *      0       success
 *      !=0     failure
 */

int os_mem_commit(void *base, uint offset, uint nbytes)
{
    return 0;
}


/***********************************
 * Decommit memory.
 * Returns:
 *      0       success
 *      !=0     failure
 */

int os_mem_decommit(void *base, uint offset, uint nbytes)
{
    return 0;
}

/***********************************
 * Unmap memory allocated with os_mem_map().
 * Returns:
 *      0       success
 *      !=0     failure
 */

int os_mem_unmap(void *base, uint nbytes)
{
    return munmap(base, nbytes);
}


/**********************************************
 * Determine "bottom" of stack (actually the top on x86 systems).
 */

void *os_query_stackBottom()
{
    version (none)
    {   // See discussion: http://autopackage.org/forums/viewtopic.php?t=22
        static void** libc_stack_end;

        if (libc_stack_end == libc_stack_end.init)
        {
            void* handle = dlopen(null, RTLD_NOW);
            libc_stack_end = cast(void **)dlsym(handle, "__libc_stack_end");
            dlclose(handle);
        }
        return *libc_stack_end;
    }
    else version (OSX)
    {
        /* A better method would be to set this value as the address
         * of a local variable defined in extern(C) main().
         */
        //return cast(void*)0xC0000000;
        return __osx_stack_end;
    }
    else
    {   // This doesn't resolve on all versions of Linux
        return __libc_stack_end;
    }
}


/**********************************************
 * Determine base address and size of static data segment.
 */

void os_query_staticdataseg(void **base, uint *nbytes)
{
    version (OSX)
    {   /* These are probably wrong.
         * See http://www.manpagez.com/man/3/get_etext/
         * Should use dylib(3) instead.
         *
         * EDIT: should be handled by _d_osx_image_init() now. - SK
         */
        //*base = cast(void *)get_etext();
        //*nbytes = cast(byte *)get_end() - cast(byte *)get_etext();
        *base = null;
        *nbytes = 0;
    }
    else version (FreeBSD)
    {
        *base = cast(void *)&etext;
        *nbytes = cast(byte *)&_end - cast(byte *)&etext;
    }
    else version (Solaris)
    {
        *base = cast(void *)&etext;
        *nbytes = cast(byte *)&_end - cast(byte *)&etext;
    }
    else
    {
        *base = cast(void *)&__data_start;
        *nbytes = cast(byte *)&_end - cast(byte *)&__data_start;
    }
}
