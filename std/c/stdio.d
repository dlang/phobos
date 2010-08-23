
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

version (Win32)
{
    extern shared ubyte[_NFILE] __fhnd_info;

    enum
    {
        FHND_APPEND     = 0x04,
        FHND_DEVICE     = 0x08,
        FHND_TEXT       = 0x10,
        FHND_BYTE       = 0x20,
        FHND_WCHAR      = 0x40,
    }
}
