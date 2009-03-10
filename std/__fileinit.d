/*
 * Placed in the Public Domain
 * Written by Walter Bright
 */

/* The only purpose of this module is to do the static construction
 * for std.file, to eliminate cyclic construction errors.
 */


module std.__fileinit;

version (Win32)
{

private import std.c.windows.windows;
private import std.file;

static this()
{
    // Win 95, 98, ME do not implement the W functions
    std.file.useWfuncs = (GetVersion() < 0x80000000);
}

}
