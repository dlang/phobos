/**
 * This module was renamed to disambiguate the term tuple, use $(DDLINK std_meta, std.meta, std.meta) instead.
 *
 * Copyright: Copyright Digital Mars 2005 - 2015.
 * License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 * Source:    $(PHOBOSSRC std/_typetuple.d)
 */
module std.typetuple;

public import std.meta;

/**
 * Alternate name for $(LREF AliasSeq) for legacy compatibility.
 */
alias TypeTuple = AliasSeq;

///
unittest
{
    import std.typetuple;
    alias TL = TypeTuple!(int, double);

    int foo(TL td)  // same as int foo(int, double);
    {
        return td[0] + cast(int)td[1];
    }
}

///
unittest
{
    alias TL = TypeTuple!(int, double);

    alias Types = TypeTuple!(TL, char);
    static assert(is(Types == TypeTuple!(int, double, char)));
}
