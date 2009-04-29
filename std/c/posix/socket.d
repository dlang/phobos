
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
version (FreeBSD)
{
    public import std.c.freebsd.socket;
}
else
{
    static asssert(0);
}

