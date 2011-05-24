
module std.c.posix.posix;

version (linux)
{
    public import std.c.linux.linux;
}
else version (OSX)
{
    public import std.c.osx.osx;
}
else version (FreeBSD)
{
    public import std.c.freebsd.freebsd;
}
else version (Solaris)
{
    public import std.c.solaris.solaris;
}
else
{
    static assert(0);
}

