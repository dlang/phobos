
module std.c.posix.posix;

version (linux)
{
    public import std.c.linux.linux;
}
else version (OSX)
{
    // We really should separate osx out from linux
    public import std.c.linux.linux;
}
version (FreeBSD)
{
    public import std.c.freebsd.freebsd;
}
else
{
    static asssert(0);
}

