// @@@DEPRECATED_2017-06@@@

/**
 * $(RED Deprecated. Use $(D core.stdc.stdlib) or $(D core.sys.posix.stdlib)
 *       instead. This module will be removed in June 2017.)
 *
 * C's &lt;stdlib.h&gt;
 * D Programming Language runtime library
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 */
deprecated("Import core.stdc.stdlib or core.sys.posix.stdlib instead")
module std.c.stdlib;

public import core.stdc.stdlib;
version(Posix) public import core.sys.posix.stdlib : setenv, unsetenv;
