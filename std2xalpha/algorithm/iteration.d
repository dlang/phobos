module std2xalpha.algorithm.iteration;

import v1 = std.algorithm.iteration;

// These symbols support std2xalpha
alias
    cache = v1.canon!"std2xalpha".cache,
    cacheBidirectional = v1.canon!"std2xalpha".cacheBidirectional;

// Unchanged for now
alias
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
    import old = std.algorithm.iteration;
    auto s = "öabc"; // ö in UTF8 is 0xC3 0xB6
    auto c0 = old.cache(s);
    auto c1 = cache(s);
    auto x0 = c0.front;
    auto x1 = c1.front;
    static assert(is(typeof(x0) == dchar), typeof(x0));
    static assert(is(typeof(x1) == immutable char));
    assert(x0 == 'ö');
    assert(x1 == 0xc3);
}

///
unittest
{
    import old = std.algorithm.iteration;
    auto s = "öabcö"; // ö in UTF8 is 0xC3 0xB6
    auto c0 = old.cacheBidirectional(s);
    auto c1 = cacheBidirectional(s);
    auto x0 = c0.back;
    auto x1 = c1.back;
    static assert(is(typeof(x0) == dchar));
    static assert(is(typeof(x1) == immutable char));
    assert(x0 == 'ö');
    assert(x1 == 0xb6);
}
