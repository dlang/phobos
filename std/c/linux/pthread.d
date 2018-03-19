// @@@DEPRECATED_2017-06@@@

/* Written by Walter Bright, Christopher E. Miller, and many others.
 * www.digitalmars.com
 * Placed into public domain.
 */

/++
    $(RED Deprecated. Use $(core.sys.posix.pthread) or the appropriate
          $(D core.sys.posix.*) modules instead. This module will be removed in
          June 2017.)
  +/
deprecated("Import core.sys.posix.pthread or the appropriate core.sys.posix.* modules instead")
module std.c.linux.pthread;

version (linux):
public import core.sys.posix.pthread;
