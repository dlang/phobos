
module std.c.posix.socket;

version (linux)
{
    public import std.c.linux.socket;
}
else version (OSX)
{
    // We really should separate osx out from linux
    public import std.c.linux.socket;
}
else version (FreeBSD)
{
    public import std.c.freebsd.socket;
}
else version (Solaris)
{
    public import std.c.solaris.socket;
}
else
{
    static assert(0);
}

