/* Written by Walter Bright, Christopher E. Miller, and many others.
 * www.digitalmars.com
 * Placed into public domain.
 */

/// Please import core.sys.posix.pthread or the other core.sys.posix.* modules you need instead. This module will be deprecated in DMD 2.068.
module std.c.linux.pthread;

version (linux):
import std.c.linux.linux;

public import core.sys.posix.pthread;
