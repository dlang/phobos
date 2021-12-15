module std2xalpha.algorithm.iteration;

import v1 = std.algorithm.iteration;

// These symbols support std2xalpha
alias
    cache = v1.canon!"std2xalpha".cache,
    cacheBidirectional = v1.canon!"std2xalpha".cacheBidirectional;

// Unchanged for now
alias
    cacheBidirectional = v1.cacheBidirectional,
    map = v1.map,
    each = v1.each,
    filter = v1.filter,
    filterBidirectional = v1.filterBidirectional,
    group = v1.group,
    Group = v1.Group,
    chunkBy = v1.chunkBy,
    splitWhen = v1.splitWhen,
    joiner = v1.joiner,
    reduce = v1.reduce,
    fold = v1.fold,
    cumulativeFold = v1.cumulativeFold,
    splitter = v1.splitter,
    substitute = v1.substitute,
    sum = v1.sum,
    mean = v1.mean,
    uniq = v1.uniq,
    permutations = v1.permutations,
    Permutations = v1.Permutations
;

///
unittest
{
    //import old = std.algorithm.iteration;
    // `ö` and `ü` are two bytes wide and both start with 0xC3
    auto s1 = "öabc", s2 = "üabc";
    auto c1 = cache(s1);
    auto x = c1.front;
    static assert(is(typeof(x) == immutable char));
    assert(c1.front == 0xc3);
}
