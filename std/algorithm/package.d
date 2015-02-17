// Written in the D programming language.

/**
This package implements generic algorithms oriented towards the processing of
sequences. Sequences processed by these functions define range-based
interfaces.  See also $(LINK2 std_range.html, Reference on ranges) and
$(WEB ddili.org/ders/d.en/ranges.html, tutorial on ranges).

$(SCRIPT inhibitQuickIndex = 1;)

Algorithms are categorized into the following submodules:

$(DIVC quickindex,
$(BOOKTABLE ,
$(TR $(TH Category) $(TH Submodule) $(TH Functions)
)
$(TR $(TDNW Searching)
     $(TDNW $(SUBMODULE searching))
     $(TD
        $(SUBREF searching, all)
        $(SUBREF searching, any)
        $(SUBREF searching, balancedParens)
        $(SUBREF searching, boyerMooreFinder)
        $(SUBREF searching, canFind)
        $(SUBREF searching, commonPrefix)
        $(SUBREF searching, count)
        $(SUBREF searching, countUntil)
        $(SUBREF searching, endsWith)
        $(SUBREF searching, find)
        $(SUBREF searching, findAdjacent)
        $(SUBREF searching, findAmong)
        $(SUBREF searching, findSkip)
        $(SUBREF searching, findSplit)
        $(SUBREF searching, findSplitAfter)
        $(SUBREF searching, findSplitBefore)
        $(SUBREF searching, minCount)
        $(SUBREF searching, minPos)
        $(SUBREF searching, skipOver)
        $(SUBREF searching, startsWith)
        $(SUBREF searching, until)
    )
)
$(TR $(TDNW Comparison)
    $(TDNW $(SUBMODULE comparison))
    $(TD
        $(SUBREF comparison, among)
        $(SUBREF comparison, castSwitch)
        $(SUBREF comparison, clamp)
        $(SUBREF comparison, cmp)
        $(SUBREF comparison, equal)
        $(SUBREF comparison, levenshteinDistance)
        $(SUBREF comparison, levenshteinDistanceAndPath)
        $(SUBREF comparison, max)
        $(SUBREF comparison, min)
        $(SUBREF comparison, mismatch)
        $(SUBREF comparison, predSwitch)
    )
)
$(TR $(TDNW Iteration)
    $(TDNW $(SUBMODULE iteration))
    $(TD
        $(SUBREF iteration, aggregate)
        $(SUBREF iteration, cache)
        $(SUBREF iteration, cacheBidirectional)
        $(SUBREF iteration, each)
        $(SUBREF iteration, filter)
        $(SUBREF iteration, filterBidirectional)
        $(SUBREF iteration, group)
        $(SUBREF iteration, groupBy)
        $(SUBREF iteration, joiner)
        $(SUBREF iteration, map)
        $(SUBREF iteration, reduce)
        $(SUBREF iteration, splitter)
        $(SUBREF iteration, sum)
        $(SUBREF iteration, uniq)
    )
)
$(TR $(TDNW Sorting)
    $(TDNW $(SUBMODULE sorting))
    $(TD
        $(SUBREF sorting, completeSort)
        $(SUBREF sorting, isPartitioned)
        $(SUBREF sorting, isSorted)
        $(SUBREF sorting, makeIndex)
        $(SUBREF sorting, multiSort)
        $(SUBREF sorting, nextEvenPermutation)
        $(SUBREF sorting, nextPermutation)
        $(SUBREF sorting, partialSort)
        $(SUBREF sorting, partition)
        $(SUBREF sorting, partition3)
        $(SUBREF sorting, schwartzSort)
        $(SUBREF sorting, sort)
        $(SUBREF sorting, topN)
        $(SUBREF sorting, topNCopy)
        $(SUBREF sorting, topNIndex)
    )
)
$(TR $(TDNW Set&nbsp;operations)
    $(TDNW $(SUBMODULE setops))
    $(TD
        $(SUBREF setops, cartesianProduct)
        $(SUBREF setops, largestPartialIntersection)
        $(SUBREF setops, largestPartialIntersectionWeighted)
        $(SUBREF setops, nWayUnion)
        $(SUBREF setops, setDifference)
        $(SUBREF setops, setIntersection)
        $(SUBREF setops, setSymmetricDifference)
        $(SUBREF setops, setUnion)
    )
)
$(TR $(TDNW Mutation)
    $(TDNW $(SUBMODULE mutation))
    $(TD
        $(SUBREF mutation, bringToFront)
        $(SUBREF mutation, copy)
        $(SUBREF mutation, fill)
        $(SUBREF mutation, initializeAll)
        $(SUBREF mutation, move)
        $(SUBREF mutation, moveAll)
        $(SUBREF mutation, moveSome)
        $(SUBREF mutation, remove)
        $(SUBREF mutation, reverse)
        $(SUBREF mutation, strip)
        $(SUBREF mutation, stripLeft)
        $(SUBREF mutation, stripRight)
        $(SUBREF mutation, swap)
        $(SUBREF mutation, swapRanges)
        $(SUBREF mutation, uninitializedFill)
    )
)
$(TR $(TDNW Utility)
    $(TDNW -)
    $(TD $(MYREF forward)
    )
))
)

Many functions in this package are parameterized with a function or a
$(GLOSSARY predicate). The predicate may be passed either as a
function name, a delegate name, a $(GLOSSARY functor) name, or a
compile-time string. The string may consist of $(B any) legal D
expression that uses the symbol $(D a) (for unary functions) or the
symbols $(D a) and $(D b) (for binary functions). These names will NOT
interfere with other homonym symbols in user code because they are
evaluated in a different context. The default for all binary
comparison predicates is $(D "a == b") for unordered operations and
$(D "a < b") for ordered operations.

Example:

----
int[] a = ...;
static bool greater(int a, int b)
{
    return a > b;
}
sort!(greater)(a);  // predicate as alias
sort!("a > b")(a);  // predicate as string
                    // (no ambiguity with array name)
sort(a);            // no predicate, "a < b" is implicit
----

Macros:
WIKI = Phobos/StdAlgorithm
SUBMODULE = $(LINK2 std_algorithm_$1.html, std.algorithm.$1)
SUBREF = $(LINK2 std_algorithm_$1.html#.$2, $(TT $2))$(NBSP)

Copyright: Andrei Alexandrescu 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_algorithm/package.d)
 */
module std.algorithm;
//debug = std_algorithm;

public import std.algorithm.comparison;
public import std.algorithm.iteration;
public import std.algorithm.mutation;
public import std.algorithm.setops;
public import std.algorithm.searching;
public import std.algorithm.sorting;

static import std.functional;
deprecated("Please use std.functional.forward instead.")
alias forward = std.functional.forward;
