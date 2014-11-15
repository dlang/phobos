
/**
 * $(RED Deprecated. Please use $(D core.stdc.fenv) instead.  This module will
 *       be removed in December 2015.)
 * C's &lt;fenv.h&gt;
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCFenv
 */

deprecated("Please import core.stdc.fenv instead. This module will be removed in December 2015.")
module std.c.fenv;

public import core.stdc.fenv;
