/**
 * C's &lt;_fenv.h&gt;
 *
 * $(RED Deprecated: Please use $(D core.stdc._fenv) instead.
 *       This module will be removed in December 2015.)
 *
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCFenv
 */
deprecated("Please use core.stdc.fenv instead.")
module std.c.fenv;

public import core.stdc.fenv;
