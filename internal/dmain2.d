/*
 * Placed into the Public Domain.
 * written by Walter Bright
 * www.digitalmars.com
 */

import object;
import std.c.stdio;
import std.c.string;
import std.c.stdlib;
import std.string;

extern (C) void _STI_monitor_staticctor();
extern (C) void _STD_monitor_staticdtor();
extern (C) void _STI_critical_init();
extern (C) void _STD_critical_term();
extern (C) void gc_init();
extern (C) void gc_term();
extern (C) void _minit();
extern (C) void _moduleCtor();
extern (C) void _moduleDtor();
extern (C) void _moduleUnitTests();

extern (C) bool no_catch_exceptions;

version (OSX)
{
    // The bottom of the stack
    extern (C) void* __osx_stack_end = cast(void*)0xC0000000;
}

version (FreeBSD)
{
    // The bottom of the stack
    extern (C) void* __libc_stack_end;
}

version (Solaris)
{
    // The bottom of the stack
    extern (C) void* __libc_stack_end;
}

/***********************************
 * The D main() function supplied by the user's program
 */
int main(char[][] args);
alias extern(C) int function(char[][] args) MainFunc;

/***********************************
 * Substitutes for the C main() function.
 * Just calls into d_run_main with the default main function.
 * Applications are free to implement their own
 * main function and call the _d_run_main function
 * themselves with any main function.
 */
extern (C) int main(size_t argc, char **argv)
{
    return _d_run_main(argc, argv, cast(void*)&main);
}

/***********************************
 * Run the given main function.
 * It's purpose is to wrap the D main()
 * function and catch any unhandled exceptions.
 */
extern (C) int _d_run_main(size_t argc, char **argv, void *p)
{
    char[] *am;
    char[][] args;
    int result;
    int myesp;
    int myebx;
    MainFunc main = cast(MainFunc)p;

    version (OSX)
    {   /* OSX does not provide a way to get at the top of the
         * stack, except for the magic value 0xC0000000.
         * But as far as the gc is concerned, argv is at the top
         * of the main thread's stack, so save the address of that.
         */
        __osx_stack_end = cast(void*)&argv;
`       /* 0xC0000000 is no longer valid for OSX 10.7 when ASLR is enabled.
         * Use pthread_get_stackaddr_np(pthread_self()) instead.
         * extern (C) void* pthread_get_stackaddr_np(pthread_t thread);
         */
    }

    version (FreeBSD)
    {   /* FreeBSD does not provide a way to get at the top of the
         * stack.
         * But as far as the gc is concerned, argv is at the top
         * of the main thread's stack, so save the address of that.
         */
        __libc_stack_end = cast(void*)&argv;
    }

    version (Solaris)
    {   /* As far as the gc is concerned, argv is at the top
         * of the main thread's stack, so save the address of that.
         */
        __libc_stack_end = cast(void*)&argv;
    }

    version (Posix)
    {
        _STI_monitor_staticctor();
        _STI_critical_init();
        gc_init();
        am = cast(char[] *) malloc(argc * (char[]).sizeof);
        // BUG: alloca() conflicts with try-catch-finally stack unwinding
        //am = (char[] *) alloca(argc * (char[]).sizeof);
    }
    version (Win32)
    {
        gc_init();
        _minit();
        am = cast(char[] *) alloca(argc * (char[]).sizeof);
    }

    if (no_catch_exceptions)
    {
        _moduleCtor();
        _moduleUnitTests();

        for (size_t i = 0; i < argc; i++)
        {
            auto len = strlen(argv[i]);
            am[i] = argv[i][0 .. len];
        }

        args = am[0 .. argc];

        result = main(args);
        _moduleDtor();
        gc_term();
    }
    else
    {
        try
        {
            _moduleCtor();
            _moduleUnitTests();

            for (size_t i = 0; i < argc; i++)
            {
                auto len = strlen(argv[i]);
                am[i] = argv[i][0 .. len];
            }

            args = am[0 .. argc];

            result = main(args);
            _moduleDtor();
            gc_term();
        }
        catch (Object o)
        {
            version (none)
            {
                printf("Error: ");
                o.print();
            }
            else
            {   auto s = o.toString();
                fprintf(stderr, "Error: %.*s\n", s.length, s.ptr);
            }
            exit(EXIT_FAILURE);
        }
    }

    version (Posix)
    {
        free(am);
        _STD_critical_term();
        _STD_monitor_staticdtor();
    }
    return result;
}

