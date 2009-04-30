
module std.c.posix.pthread;

version (linux)
{
    public import std.c.linux.pthread;
}
else version (OSX)
{
    // We really should separate osx out from linux
    public import std.c.linux.pthread;
}
else version (FreeBSD)
{
    public import std.c.freebsd.pthread;
}
else version (Solaris)
{
    public import std.c.solaris.pthread;
}
else
{
    static assert(0);
}

