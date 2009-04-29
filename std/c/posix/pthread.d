
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
version (FreeBSD)
{
    public import std.c.freebsd.pthread;
}
else
{
    static asssert(0);
}

