// Written in the D programming language.

/**
 * The only purpose of this module is to do the static construction for
 * std.date, to eliminate cyclic construction errors.
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_datebase.d)
 */
/*
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.datebase;

extern(C) void std_date_static_this();

shared static this()
{
    std_date_static_this;
}
