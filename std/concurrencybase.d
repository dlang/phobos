// Written in the D programming language.

/**
 * The only purpose of this module is to do the static construction for
 * std.concurrency, to eliminate cyclic construction errors.
 *
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Source:    $(PHOBOSSRC std/_concurrencybase.d)
 */
module std.concurrencybase;

import core.sync.mutex;

extern(C) void std_concurrency_static_this();

shared static this()
{
    std_concurrency_static_this();
}

