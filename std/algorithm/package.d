// Written in the D programming language.

/**
This package implements generic algorithms oriented towards the processing of
sequences. Sequences processed by these functions define range-based
interfaces.  See also $(LINK2 std_range.html, Reference on ranges) and
$(WEB ddili.org/ders/d.en/ranges.html, tutorial on ranges).

<script type="text/javascript">inhibitQuickIndex = 1</script>

Algorithms are categorized into the following submodules:

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

// FIXME
import std.functional; // : unaryFun, binaryFun;
import std.range.primitives;
// FIXME
import std.range; // : SortedRange;
import std.traits;
// FIXME
import std.typecons; // : tuple, Tuple;
// FIXME
import std.typetuple; // : TypeTuple, staticMap, allSatisfy, anySatisfy;

version(unittest) debug(std_algorithm) import std.stdio;

package T* addressOf(T)(ref T val) { return &val; }

// Same as std.string.format, but "self-importing".
// Helps reduce code and imports, particularly in static asserts.
// Also helps with missing imports errors.
package template algoFormat()
{
    import std.format : format;
    alias algoFormat = format;
}

/**
Forwards function arguments with saving ref-ness.
*/
template forward(args...)
{
    import std.typetuple;

    static if (args.length)
    {
        alias arg = args[0];
        static if (__traits(isRef, arg))
            alias fwd = arg;
        else
            @property fwd()(){ return move(arg); }
        alias forward = TypeTuple!(fwd, forward!(args[1..$]));
    }
    else
        alias forward = TypeTuple!();
}

///
@safe unittest
{
    class C
    {
        static int foo(int n) { return 1; }
        static int foo(ref int n) { return 2; }
    }
    int bar()(auto ref int x) { return C.foo(forward!x); }

    assert(bar(1) == 1);
    int i;
    assert(bar(i) == 2);
}

///
@safe unittest
{
    void foo(int n, ref string s) { s = null; foreach (i; 0..n) s ~= "Hello"; }

    // forwards all arguments which are bound to parameter tuple
    void bar(Args...)(auto ref Args args) { return foo(forward!args); }

    // forwards all arguments with swapping order
    void baz(Args...)(auto ref Args args) { return foo(forward!args[$/2..$], forward!args[0..$/2]); }

    string s;
    bar(1, s);
    assert(s == "Hello");
    baz(s, 2);
    assert(s == "HelloHello");
}

@safe unittest
{
    auto foo(TL...)(auto ref TL args)
    {
        string result = "";
        foreach (i, _; args)
        {
            //pragma(msg, "[",i,"] ", __traits(isRef, args[i]) ? "L" : "R");
            result ~= __traits(isRef, args[i]) ? "L" : "R";
        }
        return result;
    }

    string bar(TL...)(auto ref TL args)
    {
        return foo(forward!args);
    }
    string baz(TL...)(auto ref TL args)
    {
        int x;
        return foo(forward!args[3], forward!args[2], 1, forward!args[1], forward!args[0], x);
    }

    struct S {}
    S makeS(){ return S(); }
    int n;
    string s;
    assert(bar(S(), makeS(), n, s) == "RRLL");
    assert(baz(S(), makeS(), n, s) == "LLRRRL");
}

@safe unittest
{
    ref int foo(ref int a) { return a; }
    ref int bar(Args)(auto ref Args args)
    {
        return foo(forward!args);
    }
    static assert(!__traits(compiles, { auto x1 = bar(3); })); // case of NG
    int value = 3;
    auto x2 = bar(value); // case of OK
}

/**
Specifies whether the output of certain algorithm is desired in sorted
format.
 */
enum SortOutput
{
    no,  /// Don't sort output
    yes, /// Sort output
}

void topNIndex(
    alias less = "a < b",
    SwapStrategy ss = SwapStrategy.unstable,
    Range, RangeIndex)(Range r, RangeIndex index, SortOutput sorted = SortOutput.no)
if (isIntegral!(ElementType!(RangeIndex)))
{
    import std.container : BinaryHeap;
    import std.exception : enforce;

    if (index.empty) return;
    enforce(ElementType!(RangeIndex).max >= index.length,
            "Index type too small");
    bool indirectLess(ElementType!(RangeIndex) a, ElementType!(RangeIndex) b)
    {
        return binaryFun!(less)(r[a], r[b]);
    }
    auto heap = BinaryHeap!(RangeIndex, indirectLess)(index, 0);
    foreach (i; 0 .. r.length)
    {
        heap.conditionalInsert(cast(ElementType!RangeIndex) i);
    }
    if (sorted == SortOutput.yes)
    {
        while (!heap.empty) heap.removeFront();
    }
}

void topNIndex(
    alias less = "a < b",
    SwapStrategy ss = SwapStrategy.unstable,
    Range, RangeIndex)(Range r, RangeIndex index,
            SortOutput sorted = SortOutput.no)
if (is(ElementType!(RangeIndex) == ElementType!(Range)*))
{
    import std.container : BinaryHeap;

    if (index.empty) return;
    static bool indirectLess(const ElementType!(RangeIndex) a,
            const ElementType!(RangeIndex) b)
    {
        return binaryFun!less(*a, *b);
    }
    auto heap = BinaryHeap!(RangeIndex, indirectLess)(index, 0);
    foreach (i; 0 .. r.length)
    {
        heap.conditionalInsert(&r[i]);
    }
    if (sorted == SortOutput.yes)
    {
        while (!heap.empty) heap.removeFront();
    }
}

unittest
{
    import std.conv : text;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    {
        int[] a = [ 10, 8, 9, 2, 4, 6, 7, 1, 3, 5 ];
        int*[] b = new int*[5];
        topNIndex!("a > b")(a, b, SortOutput.yes);
        //foreach (e; b) writeln(*e);
        assert(b == [ &a[0], &a[2], &a[1], &a[6], &a[5]]);
    }
    {
        int[] a = [ 10, 8, 9, 2, 4, 6, 7, 1, 3, 5 ];
        auto b = new ubyte[5];
        topNIndex!("a > b")(a, b, SortOutput.yes);
        //foreach (e; b) writeln(e, ":", a[e]);
        assert(b == [ cast(ubyte) 0, cast(ubyte)2, cast(ubyte)1, cast(ubyte)6, cast(ubyte)5], text(b));
    }
}

// Internal random array generators
version(unittest)
{
    package enum size_t maxArraySize = 50;
    package enum size_t minArraySize = maxArraySize - 1;

    package string[] rndstuff(T : string)()
    {
        import std.random : Random, unpredictableSeed, uniform;

        static Random rnd;
        static bool first = true;
        if (first)
        {
            rnd = Random(unpredictableSeed);
            first = false;
        }
        string[] result =
            new string[uniform(minArraySize, maxArraySize, rnd)];
        string alpha = "abcdefghijABCDEFGHIJ";
        foreach (ref s; result)
        {
            foreach (i; 0 .. uniform(0u, 20u, rnd))
            {
                auto j = uniform(0, alpha.length - 1, rnd);
                s ~= alpha[j];
            }
        }
        return result;
    }

    package int[] rndstuff(T : int)()
    {
        import std.random : Random, unpredictableSeed, uniform;

        static Random rnd;
        static bool first = true;
        if (first)
        {
            rnd = Random(unpredictableSeed);
            first = false;
        }
        int[] result = new int[uniform(minArraySize, maxArraySize, rnd)];
        foreach (ref i; result)
        {
            i = uniform(-100, 100, rnd);
        }
        return result;
    }

    package double[] rndstuff(T : double)()
    {
        double[] result;
        foreach (i; rndstuff!(int)())
        {
            result ~= i / 50.0;
        }
        return result;
    }
}
