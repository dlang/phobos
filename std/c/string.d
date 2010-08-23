
/**
 * C's &lt;string.h&gt;
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCString
 */

module std.c.string;

public import core.stdc.string;

extern (C):

version (Windows)
{
    int memicmp(in char* s1, in char* s2, size_t n);
}

version (linux)
{
    const(char)* strerror_r(int errnum, char* buf, size_t buflen);
}

version (OSX)
{
    int strerror_r(int errnum, char* buf, size_t buflen);
}

version (FreeBSD)
{
    int strerror_r(int errnum, char* buf, size_t buflen);
}
