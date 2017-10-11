// Written in the D programming language.

/**
This module implements experimental additions/modifications to $(MREF std, _algorithm).

Use this module to test out new functionality for $(REF wrap, std, _algorithm)

Source:    $(PHOBOSSRC std/experimental/_algorithm.d)

Copyright: Copyright the respective authors, 2008-
License:   $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   Andrea Fontana
           Razvan Nitu
 */
module std.experimental.algorithm;

import std.range : isInputRange, ElementType;

/**
Lazily produces a range with no duplicated elements from the input
range $(D r). The order of elements is the original order.

Params:
    Range r - the input range to eliminate duplicates from

Returns:
    A range containing all the unique elements
*/
auto distinct(Range)(Range r)
if (isInputRange!Range)
{
    import std.algorithm.iteration : filter;
    bool[ElementType!Range] justSeen;
    return r.filter!((k)
        {
            if (k in justSeen) return false;
            return justSeen[k] = true;
        });
}

///
@safe unittest
{
    import std.algorithm.comparison : equal;

    assert("AAAA".distinct.equal("A"));
    assert("ABAC".distinct.equal("ABC"));
    assert([1, 2, 3, 1, 2, 1, 1].distinct.equal([1, 2, 3]));
}
