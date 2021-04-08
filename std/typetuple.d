/**
 * This module was renamed to disambiguate the term tuple, use
 * $(MREF std, meta) instead.
 *
 * $(RED Warning: This module will be removed from Phobos in 2.107.0.)
 *
 * Copyright: Copyright The D Language Foundation 2005 - 2015.
 * License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 * Source:    $(PHOBOSSRC std/typetuple.d)
 *
 * $(SCRIPT inhibitQuickIndex = 1;)
 */
// @@@DEPRECATED_[2.107.0]@@@
deprecated("Will be removed from Phobos in 2.107.0. Use std.meta : AliasSeq instead.")
module std.typetuple;

public import std.meta;

/**
 * Alternate name for $(REF AliasSeq, std,meta) for legacy compatibility.
 *
 * Will be removed in 2.107.0.
 */
// @@@DEPRECATED_[2.107.0]@@@
deprecated("TypeTuple will be removed in 2.107.0. Use std.meta : AliasSeq instead.")
alias TypeTuple = AliasSeq;

deprecated @safe unittest
{
    import std.typetuple;
    alias TL = TypeTuple!(int, double);

    int foo(TL td)  // same as int foo(int, double);
    {
        return td[0] + cast(int) td[1];
    }
    assert(foo(1, 2.5) == 3);
}

deprecated @safe unittest
{
    alias TL = TypeTuple!(int, double);

    alias Types = TypeTuple!(TL, char);
    static assert(is(Types == TypeTuple!(int, double, char)));
}
