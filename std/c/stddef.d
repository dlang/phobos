/*
 * Written by Walter Bright
 * Digital Mars
 * www.digitalmars.com
 * Placed into Public Domain.
 */

module std.c.stddef;

version (Win32)
{
    alias wchar wchar_t;
}
else version (linux)
{
    alias dchar wchar_t;
}
else
{
    static assert(0);
}
