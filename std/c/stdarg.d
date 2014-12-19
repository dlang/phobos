
/**
 * $(RED Deprecated. Please use $(D core.stdc.stdarg) instead.  This module will
 *       be removed in December 2015.)
 * C's &lt;stdarg.h&gt;
 * Authors: Hauke Duden and Walter Bright, Digital Mars, www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdarg
 */

/* This is for use with extern(C) variable argument lists. */

deprecated("Please import core.stdc.stdarg instead. This module will be removed in December 2015.")
module std.c.stdarg;

public import core.stdc.stdarg;
