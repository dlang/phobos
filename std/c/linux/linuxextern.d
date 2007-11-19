
/* Written by Walter Bright.
 * www.digitalmars.com
 * Placed into public domain.
 * Linux(R) is the registered trademark of Linus Torvalds in the U.S. and other
 * countries.
 */

/* These are all the globals defined by the linux C runtime library.
 * Put them separate so they'll be externed - do not link in linuxextern.o
 */

module std.c.linux.linuxextern;

extern (C)
{
    extern void* __libc_stack_end;
    extern int __data_start;
    extern int _end;
    extern int timezone;

    extern void *_deh_beg;
    extern void *_deh_end;
}

