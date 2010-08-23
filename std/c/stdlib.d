/**
 * C's &lt;stdlib.h&gt;
 * D Programming Language runtime library
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdlib
 */


module std.c.stdlib;

public import core.stdc.stdlib;

extern (C):

int setenv(const char*, const char*, int); /// extension to ISO C standard, not available on all platforms
int unsetenv(const char*); /// extension to ISO C standard, not available on all platforms
