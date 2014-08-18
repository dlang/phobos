/*
Module which declares the global "environ" variable (POSIX only).

This variable is defined by the C runtime, and contains the environment
variables for the current process.

This module is only meant to be used internally in Phobos. Its API is
subject to change without notice.  Please see std/process.d for author,
copyright and licence information.
*/
module std.internal.process.environ;

version (Posix):

version (OSX)
{
    extern(C) char*** _NSGetEnviron() nothrow;
    private __gshared const(char**)* environPtr;
    shared static this() { environPtr = _NSGetEnviron(); }
    const(char**) environ() @property @trusted nothrow { return *environPtr; }
}
else
{
    extern(C) extern __gshared const char** environ;
}

unittest
{
    import core.thread: Thread;
    new Thread({assert(environ !is null);}).start();
}
