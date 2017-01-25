/**
 * This module was renamed to disambiguate the term tuple, use
 * $(MREF std, meta) instead.
 *
 * Copyright: Copyright Digital Mars 2005 - 2015.
 * License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 * Source:    $(PHOBOSSRC std/_typetuple.d)
 */
// @@@DEPRECATED_2017-12@@@
deprecated("It will be removed from Phobos in December 2017. Use std.meta")
module std.typetuple;

public import std.meta;

// @@@DEPRECATED_2017-12@@@
deprecated("TypeTuple has been renamed to std.meta.AliasSeq. It will be removed from Phobos in December 2017")
alias TypeTuple = AliasSeq;
