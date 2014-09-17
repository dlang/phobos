/* Written by Walter Bright, Christopher E. Miller, and many others.
 * www.digitalmars.com
 * Placed into public domain.
 */

deprecated("Please import core.sys.posix.pthread or the other core.sys.posix.* modules you need instead. This module will be removed in April 2015.")
module std.c.linux.pthread;

import std.c.linux.linux;

public import core.sys.posix.pthread;
