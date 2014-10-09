/**
 * C's &lt;_stdlib.h&gt;
 * D Programming Language runtime library
 *
 * $(RED Deprecated: Please use $(D core.stdc._stdlib) instead.
 *       This module will be removed in December 2015.)
 *
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdlib
 */
deprecated("Please use core.stdc.stdlib instead.")
module std.c.stdlib;

public import core.stdc.stdlib;

extern (C):

int setenv(const char*, const char*, int); /// extension to ISO C standard, not available on all platforms
int unsetenv(const char*); /// extension to ISO C standard, not available on all platforms
