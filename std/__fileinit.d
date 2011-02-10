// Written in the D programming language.

/**
 * The only purpose of this module is to do the static construction for
 * std.file, to eliminate cyclic construction errors.
 *
 * Copyright: Copyright Digital Mars 2008 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/___fileinit.d)
 */

/*          Copyright Digital Mars 2008 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.__fileinit;

version (Win32)
{

private import std.c.windows.windows;
shared bool useWfuncs = true;

shared static this()
{
    // Win 95, 98, ME do not implement the W functions
    useWfuncs = (GetVersion() < 0x80000000);
}

}
