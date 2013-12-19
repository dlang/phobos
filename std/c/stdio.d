
/**
 * C's &lt;stdio.h&gt; for the D programming language
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdio
 */



module std.c.stdio;

public import core.stdc.stdio;

extern (C):

version (Windows)
{
    extern shared ubyte[_NFILE] __fhnd_info;
}
