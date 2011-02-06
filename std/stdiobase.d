// Written in the D programming language.

/**
 * The only purpose of this module is to do the static construction for
 * std.stdio, to eliminate cyclic construction errors.
 *
 * Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB erdani.org, Andrei Alexandrescu)
 * Source:    $(PHOBOSSRC std/_stdiobase.d)
 */
/*          Copyright Andrei Alexandrescu 2008 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.stdiobase;

extern(C) void std_stdio_static_this();

shared static this()
{
    std_stdio_static_this();
}
