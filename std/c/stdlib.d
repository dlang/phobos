/**
 * $(RED Deprecated. Please use $(D core.stdc.stdlib) or $(D core.sys.posix.stdlib)
 *       instead.  This module will be removed in December 2015.)
 * C's &lt;stdlib.h&gt;
 * D Programming Language runtime library
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdlib
 */


/// Please import core.stdc.stdlib or core.sys.posix.stdlib instead. This module will be deprecated in DMD 2.068.
module std.c.stdlib;

public import core.stdc.stdlib;
version(Posix) public import core.sys.posix.stdlib: setenv, unsetenv;
