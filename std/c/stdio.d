/**
 * C's &lt;_stdio.h&gt; for the D programming language
 *
 * $(RED Deprecated: Please use $(D core.stdc._stdio) instead.
 *       This module will be removed in December 2015.)
 *
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdio
 */
deprecated("Please use core.stdc.stdio instead.")
module std.c.stdio;

public import core.stdc.stdio;

extern (C):

version (Windows)
{
    extern shared ubyte[_NFILE] __fhnd_info;
}
