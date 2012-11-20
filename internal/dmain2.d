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

version (Windows)
{
    import std.c.stddef; // wchar_t

    extern (Windows)
    {
        void*      LocalFree(void*);
        wchar_t*   GetCommandLineW();
        wchar_t**  CommandLineToArgvW(wchar_t*, int*);
        int WideCharToMultiByte(uint, uint, wchar_t*, int, char*, int, char*, int*);
        int MultiByteToWideChar(uint, uint, in char*, int, wchar_t*, int);
    }
    pragma(lib, "shell32.lib"); // needed for CommandLineToArgvW
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
    //printf("main(argc = %lld, argv = %p)\n", argc, argv);
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
        /* 0xC0000000 is no longer valid for OSX 10.7 when ASLR is enabled.
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
    version (Win64)
    {
        auto fp = __iob_func();
        stdin  = &fp[0];
        stdout = &fp[1];
        stderr = &fp[2];

        _STI_monitor_staticctor();
        _STI_critical_init();
        gc_init();
        //_minit();
        // BUG: alloca() conflicts with try-catch-finally stack unwinding
        am = cast(char[] *) malloc(argc * (char[]).sizeof);
    }

    void setArgs()
    {
        args = am[0 .. argc];
        version (Windows)
        {
            wchar_t*  wcbuf = GetCommandLineW();
            size_t    wclen = wcslen(wcbuf);
            int       wargc = 0;
            wchar_t** wargs = CommandLineToArgvW(wcbuf, &wargc);
            assert(wargc == argc);

            // This is required because WideCharToMultiByte requires int as input.
            assert(wclen <= int.max, "wclen must not exceed int.max");

            char*     cargp = null;
            size_t    cargl = WideCharToMultiByte(65001, 0, wcbuf, cast(int)wclen, null, 0, null, null);

            cargp = cast(char*) malloc(cargl);

            for (size_t i = 0, p = 0; i < wargc; i++)
            {
                size_t wlen = wcslen(wargs[i]);
                assert(wlen <= int.max, "wlen cannot exceed int.max");
                int clen = WideCharToMultiByte(65001, 0, &wargs[i][0], cast(int)wlen, null, 0, null, null);
                args[i]  = cargp[p .. p+clen];
                if (clen==0) continue;
                p += clen; assert(p <= cargl);
                WideCharToMultiByte(65001, 0, &wargs[i][0], cast(int)wlen, &args[i][0], clen, null, null);
            }
            LocalFree(wargs);
            wargs = null;
            wargc = 0;
        }
        else
        {
            for (size_t i = 0; i < argc; i++)
            {
                auto len = strlen(argv[i]);
                args[i] = argv[i][0 .. len];
            }
        }
    }

    if (no_catch_exceptions)
    {
        _moduleCtor();
        _moduleUnitTests();

        setArgs();

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

            setArgs();

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
    version (Win64)
    {
        _STD_critical_term();
        _STD_monitor_staticdtor();
    }
    return result;
}

