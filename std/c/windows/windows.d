
/* Windows is a registered trademark of Microsoft Corporation in the United
States and other countries. */

module std.c.windows.windows;

public import core.sys.windows.windows;

version (Windows)
{
}
else
{
    static assert(0);           // Windows only
}
