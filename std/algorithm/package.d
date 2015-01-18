// Written in the D programming language.

/**
Implements algorithms oriented mainly towards processing of
sequences. Sequences processed by these functions define range-based interfaces.
See also $(LINK2 std_range.html, Reference on ranges) and
$(WEB ddili.org/ders/d.en/ranges.html, tutorial on ranges).

<script type="text/javascript">inhibitQuickIndex = 1</script>

$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW Searching) $(TD $(MYREF all) $(MYREF any) $(MYREF balancedParens) $(MYREF
boyerMooreFinder) $(MYREF canFind) $(MYREF commonPrefix) $(MYREF count)
$(MYREF countUntil) $(MYREF endsWith) $(MYREF find) $(MYREF
findAdjacent) $(MYREF findAmong) $(MYREF findSkip) $(MYREF findSplit)
$(MYREF findSplitAfter) $(MYREF findSplitBefore) $(MYREF minCount)
$(MYREF minPos) $(MYREF skipOver) $(MYREF startsWith)
$(MYREF until) )
)
$(TR $(TDNW Comparison) $(TD $(MYREF among) $(MYREF castSwitch) $(MYREF clamp)
$(MYREF cmp) $(MYREF equal) $(MYREF levenshteinDistance) $(MYREF
levenshteinDistanceAndPath) $(MYREF max) $(MYREF min) $(MYREF mismatch)
$(MYREF predSwitch))
)
$(TR $(TDNW Iteration) $(TD $(MYREF cache) $(MYREF cacheBidirectional)
$(MYREF each) $(MYREF filter) $(MYREF filterBidirectional)
$(MYREF group) $(MYREF groupBy) $(MYREF joiner) $(MYREF map) $(MYREF reduce)
$(MYREF splitter) $(MYREF sum) $(MYREF uniq) )
)
$(TR $(TDNW Sorting) $(TD $(MYREF completeSort) $(MYREF isPartitioned)
$(MYREF isSorted) $(MYREF makeIndex) $(MYREF multiSort) $(MYREF
nextEvenPermutation) $(MYREF nextPermutation) $(MYREF partialSort)
$(MYREF partition) $(MYREF partition3) $(MYREF schwartzSort) $(MYREF sort)
$(MYREF topN) $(MYREF topNCopy) )
)
$(TR $(TDNW Set&nbsp;operations) $(TD $(MYREF cartesianProduct) $(MYREF
largestPartialIntersection) $(MYREF largestPartialIntersectionWeighted)
$(MYREF nWayUnion) $(MYREF setDifference) $(MYREF setIntersection) $(MYREF
setSymmetricDifference) $(MYREF setUnion) )
)
$(TR $(TDNW Mutation) $(TD $(MYREF bringToFront) $(MYREF copy) $(MYREF
fill) $(MYREF initializeAll) $(MYREF move) $(MYREF moveAll) $(MYREF
moveSome) $(MYREF remove) $(MYREF reverse) $(MYREF strip) $(MYREF stripLeft)
$(MYREF stripRight) $(MYREF swap) $(MYREF swapRanges) $(MYREF uninitializedFill) )
)
$(TR $(TDNW Utility) $(TD $(MYREF forward) ))
)

Many functions in this module are parameterized with a function or a
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

$(BOOKTABLE Cheat Sheet,

$(TR $(TH Function Name) $(TH Description))

$(LEADINGROW Searching)

$(T2 all,
        $(D all!"a > 0"([1, 2, 3, 4])) returns $(D true) because all elements
        are positive)
$(T2 any,
        $(D any!"a > 0"([1, 2, -3, -4])) returns $(D true) because at least one
        element is positive)
$(T2 balancedParens,
        $(D balancedParens("((1 + 1) / 2)")) returns $(D true) because the
        string has balanced parentheses.)
$(T2 boyerMooreFinder,
        $(D find("hello world", boyerMooreFinder("or"))) returns $(D "orld")
        using the $(LUCKY Boyer-Moore _algorithm).)
$(T2 canFind,
        $(D canFind("hello world", "or")) returns $(D true).)
$(T2 count,
        Counts elements that are equal to a specified value or satisfy a
        predicate.  $(D count([1, 2, 1], 1)) returns $(D 2) and
        $(D count!"a < 0"([1, -3, 0])) returns $(D 1).)
$(T2 countUntil,
        $(D countUntil(a, b)) returns the number of steps taken in $(D a) to
        reach $(D b); for example, $(D countUntil("hello!", "o")) returns
        $(D 4).)
$(T2 commonPrefix,
        $(D commonPrefix("parakeet", "parachute")) returns $(D "para").)
$(T2 endsWith,
        $(D endsWith("rocks", "ks")) returns $(D true).)
$(T2 find,
        $(D find("hello world", "or")) returns $(D "orld") using linear search.
        (For binary search refer to $(XREF range,sortedRange).))
$(T2 findAdjacent,
        $(D findAdjacent([1, 2, 3, 3, 4])) returns the subrange starting with
        two equal adjacent elements, i.e. $(D [3, 3, 4]).)
$(T2 findAmong,
        $(D findAmong("abcd", "qcx")) returns $(D "cd") because $(D 'c') is
        among $(D "qcx").)
$(T2 findSkip,
        If $(D a = "abcde"), then $(D findSkip(a, "x")) returns $(D false) and
        leaves $(D a) unchanged, whereas $(D findSkip(a, 'c')) advances $(D a)
        to $(D "cde") and returns $(D true).)
$(T2 findSplit,
        $(D findSplit("abcdefg", "de")) returns the three ranges $(D "abc"),
        $(D "de"), and $(D "fg").)
$(T2 findSplitAfter,
        $(D findSplitAfter("abcdefg", "de")) returns the two ranges
        $(D "abcde") and $(D "fg").)
$(T2 findSplitBefore,
        $(D findSplitBefore("abcdefg", "de")) returns the two ranges $(D "abc")
        and $(D "defg").)
$(T2 minCount,
        $(D minCount([2, 1, 1, 4, 1])) returns $(D tuple(1, 3)).)
$(T2 minPos,
        $(D minPos([2, 3, 1, 3, 4, 1])) returns the subrange $(D [1, 3, 4, 1]),
        i.e., positions the range at the first occurrence of its minimal
        element.)
$(T2 mismatch,
        $(D mismatch("parakeet", "parachute")) returns the two ranges
        $(D "keet") and $(D "chute").)
$(T2 skipOver,
        Assume $(D a = "blah"). Then $(D skipOver(a, "bi")) leaves $(D a)
        unchanged and returns $(D false), whereas $(D skipOver(a, "bl"))
        advances $(D a) to refer to $(D "ah") and returns $(D true).)
$(T2 startsWith,
        $(D startsWith("hello, world", "hello")) returns $(D true).)
$(T2 until,
        Lazily iterates a range until a specific value is found.)

$(LEADINGROW Comparison)

$(T2 among,
        Checks if a value is among a set of values, e.g.
        $(D if (v.among(1, 2, 3)) // `v` is 1, 2 or 3))
$(T2 castSwitch,
        $(D (new A()).castSwitch((A a)=>1,(B b)=>2)) returns $(D 1).)
$(T2 clamp,
        $(D clamp(1, 3, 6)) returns $(D 3). $(D clamp(4, 3, 6)) returns $(D 4).)
$(T2 cmp,
        $(D cmp("abc", "abcd")) is $(D -1), $(D cmp("abc", "aba")) is $(D 1),
        and $(D cmp("abc", "abc")) is $(D 0).)
$(T2 equal,
        Compares ranges for element-by-element equality, e.g.
        $(D equal([1, 2, 3], [1.0, 2.0, 3.0])) returns $(D true).)
$(T2 levenshteinDistance,
        $(D levenshteinDistance("kitten", "sitting")) returns $(D 3) by using
        the $(LUCKY Levenshtein distance _algorithm).)
$(T2 levenshteinDistanceAndPath,
        $(D levenshteinDistanceAndPath("kitten", "sitting")) returns
        $(D tuple(3, "snnnsni")) by using the $(LUCKY Levenshtein distance
        _algorithm).)
$(T2 max,
        $(D max(3, 4, 2)) returns $(D 4).)
$(T2 min,
        $(D min(3, 4, 2)) returns $(D 2).)
$(T2 mismatch,
        $(D mismatch("oh hi", "ohayo")) returns $(D tuple(" hi", "ayo")).)
$(T2 predSwitch,
        $(D 2.predSwitch(1, "one", 2, "two", 3, "three")) returns $(D "two").)

$(LEADINGROW Iteration)

$(T2 cache,
        Eagerly evaluates and caches another range's $(D front).)
$(T2 cacheBidirectional,
        As above, but also provides $(D back) and $(D popBack).)
$(T2 each,
        $(D each!writeln([1, 2, 3])) eagerly prints the numbers $(D 1), $(D 2)
        and $(D 3) on their own lines.)
$(T2 filter,
        $(D filter!"a > 0"([1, -1, 2, 0, -3])) iterates over elements $(D 1)
        and $(D 2).)
$(T2 filterBidirectional,
        Similar to $(D filter), but also provides $(D back) and $(D popBack) at
        a small increase in cost.)
$(T2 group,
        $(D group([5, 2, 2, 3, 3])) returns a range containing the tuples
        $(D tuple(5, 1)), $(D tuple(2, 2)), and $(D tuple(3, 2)).)
$(T2 groupBy,
        $(D groupBy!((a,b) => a[1] == b[1])([[1, 1], [1, 2], [2, 2], [2, 1]]))
        returns a range containing 3 subranges: the first with just
        $(D [1, 1]); the second with the elements $(D [1, 2]) and $(D [2, 2]);
        and the third with just $(D [2, 1]).)
$(T2 joiner,
        $(D joiner(["hello", "world!"], "; ")) returns a range that iterates
        over the characters $(D "hello; world!"). No new string is created -
        the existing inputs are iterated.)
$(T2 map,
        $(D map!"2 * a"([1, 2, 3])) lazily returns a range with the numbers
        $(D 2), $(D 4), $(D 6).)
$(T2 reduce,
        $(D reduce!"a + b"([1, 2, 3, 4])) returns $(D 10).)
$(T2 splitter,
        Lazily splits a range by a separator.)
$(T2 sum,
        Same as $(D reduce), but specialized for accurate summation.)
$(T2 uniq,
        Iterates over the unique elements in a range, which is assumed sorted.)

$(LEADINGROW Sorting)

$(T2 completeSort,
        If $(D a = [10, 20, 30]) and $(D b = [40, 6, 15]), then
        $(D completeSort(a, b)) leaves $(D a = [6, 10, 15]) and $(D b = [20,
        30, 40]).
        The range $(D a) must be sorted prior to the call, and as a result the
        combination $(D $(XREF range,chain)(a, b)) is sorted.)
$(T2 isPartitioned,
        $(D isPartitioned!"a < 0"([-1, -2, 1, 0, 2])) returns $(D true) because
        the predicate is $(D true) for a portion of the range and $(D false)
        afterwards.)
$(T2 isSorted,
        $(D isSorted([1, 1, 2, 3])) returns $(D true).)
$(T2 makeIndex,
        Creates a separate index for a range.)
$(T2 nextEvenPermutation,
        Computes the next lexicographically greater even permutation of a range
        in-place.)
$(T2 nextPermutation,
        Computes the next lexicographically greater permutation of a range
        in-place.)
$(T2 partialSort,
        If $(D a = [5, 4, 3, 2, 1]), then $(D partialSort(a, 3)) leaves
        $(D a[0 .. 3] = [1, 2, 3]).
        The other elements of $(D a) are left in an unspecified order.)
$(T2 partition,
        Partitions a range according to a predicate.)
$(T2 partition3,
        Partitions a range in three parts (less than, equal, greater than the
        given pivot).)
$(T2 schwartzSort,
        Sorts with the help of the $(LUCKY Schwartzian transform).)
$(T2 sort,
        Sorts.)
$(T2 topN,
        Separates the top elements in a range.)
$(T2 topNCopy,
        Copies out the top elements of a range.)

$(LEADINGROW Set operations)

$(T2 cartesianProduct,
        Computes Cartesian product of two ranges.)
$(T2 largestPartialIntersection,
        Copies out the values that occur most frequently in a range of ranges.)
$(T2 largestPartialIntersectionWeighted,
        Copies out the values that occur most frequently (multiplied by
        per-value weights) in a range of ranges.)
$(T2 nWayUnion,
        Computes the union of a set of sets implemented as a range of sorted
        ranges.)
$(T2 setDifference,
        Lazily computes the set difference of two or more sorted ranges.)
$(T2 setIntersection,
        Lazily computes the intersection of two or more sorted ranges.)
$(T2 setSymmetricDifference,
        Lazily computes the symmetric set difference of two or more sorted
        ranges.)
$(T2 setUnion,
        Lazily computes the set union of two or more sorted ranges.)

$(LEADINGROW Mutation)

$(T2 bringToFront,
        If $(D a = [1, 2, 3]) and $(D b = [4, 5, 6, 7]),
        $(D bringToFront(a, b)) leaves $(D a = [4, 5, 6]) and
        $(D b = [7, 1, 2, 3]).)
$(T2 copy,
        Copies a range to another. If
        $(D a = [1, 2, 3]) and $(D b = new int[5]), then $(D copy(a, b))
        leaves $(D b = [1, 2, 3, 0, 0]) and returns $(D b[3 .. $]).)
$(T2 fill,
        Fills a range with a pattern,
        e.g., if $(D a = new int[3]), then $(D fill(a, 4))
        leaves $(D a = [4, 4, 4]) and $(D fill(a, [3, 4])) leaves
        $(D a = [3, 4, 3]).)
$(T2 initializeAll,
        If $(D a = [1.2, 3.4]), then $(D initializeAll(a)) leaves
        $(D a = [double.init, double.init]).)
$(T2 move,
        $(D move(a, b)) moves $(D a) into $(D b). $(D move(a)) reads $(D a)
        destructively.)
$(T2 moveAll,
        Moves all elements from one range to another.)
$(T2 moveSome,
        Moves as many elements as possible from one range to another.)
$(T2 remove,
        Removes elements from a range in-place, and returns the shortened
        range.)
$(T2 reverse,
        If $(D a = [1, 2, 3]), $(D reverse(a)) changes it to $(D [3, 2, 1]).)
$(T2 strip,
        Strips all leading and trailing elements equal to a value, or that
        satisfy a predicate.
        If $(D a = [1, 1, 0, 1, 1]), then $(D strip(a, 1)) and
        $(D strip!(e => e == 1)(a)) returns $(D [0]).)
$(T2 stripLeft,
        Strips all leading elements equal to a value, or that satisfy a
        predicate.  If $(D a = [1, 1, 0, 1, 1]), then $(D stripLeft(a, 1)) and
        $(D stripLeft!(e => e == 1)(a)) returns $(D [0, 1, 1]).)
$(T2 stripRight,
        Strips all trailing elements equal to a value, or that satisfy a
        predicate.
        If $(D a = [1, 1, 0, 1, 1]), then $(D stripRight(a, 1)) and
        $(D stripRight!(e => e == 1)(a)) returns $(D [1, 1, 0]).)
$(T2 swap,
        Swaps two values.)
$(T2 swapRanges,
        Swaps all elements of two ranges.)
$(T2 uninitializedFill,
        Fills a range (assumed uninitialized) with a value.)
)

Macros:
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
WIKI = Phobos/StdAlgorithm

Copyright: Andrei Alexandrescu 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_algorithm.d)
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

// each
/**
Eagerly iterates over $(D r) and calls $(D pred) over _each element.

Params:
    pred = predicate to apply to each element of the range
    r = range or iterable over which each iterates

Example:
---
void deleteOldBackups()
{
    import std.algorithm, std.datetime, std.file;
    auto cutoff = Clock.currTime() - 7.days;
    dirEntries("", "*~", SpanMode.depth)
        .filter!(de => de.timeLastModified < cutoff)
        .each!remove();
}
---

If the range supports it, the value can be mutated in place. Examples:
---
arr.each!((ref a) => a++);
arr.each!"a++";
---

If no predicate is specified, $(D each) will default to doing nothing
but consuming the entire range. $(D .front) will be evaluated, but this
can be avoided by explicitly specifying a predicate lambda with a
$(D lazy) parameter.

$(D each) also supports $(D opApply)-based iterators, so it will work
with e.g. $(XREF parallelism, parallel).

See_Also: $(XREF range,tee)

 */
template each(alias pred = "a")
{
    alias BinaryArgs = TypeTuple!(pred, "i", "a");

    enum isRangeUnaryIterable(R) =
        is(typeof(unaryFun!pred(R.init.front)));

    enum isRangeBinaryIterable(R) =
        is(typeof(binaryFun!BinaryArgs(0, R.init.front)));

    enum isRangeIterable(R) =
        isInputRange!R &&
        (isRangeUnaryIterable!R || isRangeBinaryIterable!R);

    enum isForeachUnaryIterable(R) =
        is(typeof((R r) {
            foreach (ref a; r)
                cast(void)unaryFun!pred(a);
        }));

    enum isForeachBinaryIterable(R) =
        is(typeof((R r) {
            foreach (i, ref a; r)
                cast(void)binaryFun!BinaryArgs(i, a);
        }));

    enum isForeachIterable(R) =
        (!isForwardRange!R || isDynamicArray!R) &&
        (isForeachUnaryIterable!R || isForeachBinaryIterable!R);

    void each(Range)(Range r)
    if (isRangeIterable!Range && !isForeachIterable!Range)
    {
        debug(each) pragma(msg, "Using while for ", Range.stringof);
        static if (isRangeUnaryIterable!Range)
        {
            while (!r.empty)
            {
                cast(void)unaryFun!pred(r.front);
                r.popFront();
            }
        }
        else // if (isRangeBinaryIterable!Range)
        {
            size_t i = 0;
            while (!r.empty)
            {
                cast(void)binaryFun!BinaryArgs(i, r.front);
                r.popFront();
                i++;
            }
        }
    }

    void each(Iterable)(Iterable r)
        if (isForeachIterable!Iterable)
    {
        debug(each) pragma(msg, "Using foreach for ", Iterable.stringof);
        static if (isForeachUnaryIterable!Iterable)
        {
            foreach (ref e; r)
                cast(void)unaryFun!pred(e);
        }
        else // if (isForeachBinaryIterable!Iterable)
        {
            foreach (i, ref e; r)
                cast(void)binaryFun!BinaryArgs(i, e);
        }
    }
}

unittest
{
    long[] arr;
    // Note: each over arrays should resolve to the
    // foreach variant, but as this is a performance
    // improvement it is not unit-testable.
    iota(5).each!(n => arr ~= n);
    assert(arr == [0, 1, 2, 3, 4]);

    // in-place mutation
    arr.each!((ref n) => n++);
    assert(arr == [1, 2, 3, 4, 5]);

    // by-ref lambdas should not be allowed for non-ref ranges
    static assert(!is(typeof(arr.map!(n => n).each!((ref n) => n++))));

    // default predicate (walk / consume)
    auto m = arr.map!(n => n);
    (&m).each();
    assert(m.empty);

    // in-place mutation with index
    arr[] = 0;
    arr.each!"a=i"();
    assert(arr == [0, 1, 2, 3, 4]);

    // opApply iterators
    static assert(is(typeof({
        import std.parallelism;
        arr.parallel.each!"a++";
    })));
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

// overwriteAdjacent
/*
Reduces $(D r) by shifting it to the left until no adjacent elements
$(D a), $(D b) remain in $(D r) such that $(D pred(a, b)). Shifting is
performed by evaluating $(D move(source, target)) as a primitive. The
algorithm is stable and runs in $(BIGOH r.length) time. Returns the
reduced range.

The default $(XREF _algorithm, move) performs a potentially
destructive assignment of $(D source) to $(D target), so the objects
beyond the returned range should be considered "empty". By default $(D
pred) compares for equality, in which case $(D overwriteAdjacent)
collapses adjacent duplicate elements to one (functionality akin to
the $(WEB wikipedia.org/wiki/Uniq, uniq) system utility).

Example:
----
int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
auto r = overwriteAdjacent(arr);
assert(r == [ 1, 2, 3, 4, 5 ]);
----
*/
// Range overwriteAdjacent(alias pred, alias move, Range)(Range r)
// {
//     if (r.empty) return r;
//     //auto target = begin(r), e = end(r);
//     auto target = r;
//     auto source = r;
//     source.popFront();
//     while (!source.empty)
//     {
//         if (!pred(target.front, source.front))
//         {
//             target.popFront();
//             continue;
//         }
//         // found an equal *source and *target
//         for (;;)
//         {
//             //@@@
//             //move(source.front, target.front);
//             target[0] = source[0];
//             source.popFront();
//             if (source.empty) break;
//             if (!pred(target.front, source.front)) target.popFront();
//         }
//         break;
//     }
//     return range(begin(r), target + 1);
// }

// /// Ditto
// Range overwriteAdjacent(
//     string fun = "a == b",
//     alias move = .move,
//     Range)(Range r)
// {
//     return .overwriteAdjacent!(binaryFun!(fun), move, Range)(r);
// }

// unittest
// {
//     int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
//     auto r = overwriteAdjacent(arr);
//     assert(r == [ 1, 2, 3, 4, 5 ]);
//     assert(arr == [ 1, 2, 3, 4, 5, 3, 4, 4, 4, 5 ]);

// }

// eliminate
/* *
Reduces $(D r) by overwriting all elements $(D x) that satisfy $(D
pred(x)). Returns the reduced range.

Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];
// eliminate even elements
auto r = eliminate!("(a & 1) == 0")(arr);
assert(r == [ 1, 3, 5 ]);
assert(arr == [ 1, 3, 5, 4, 5 ]);
----
*/
// Range eliminate(alias pred,
//                 SwapStrategy ss = SwapStrategy.unstable,
//                 alias move = .move,
//                 Range)(Range r)
// {
//     alias It = Iterator!(Range);
//     static void assignIter(It a, It b) { move(*b, *a); }
//     return range(begin(r), partitionold!(not!(pred), ss, assignIter, Range)(r));
// }

// unittest
// {
//     int[] arr = [ 1, 2, 3, 4, 5 ];
// // eliminate even elements
//     auto r = eliminate!("(a & 1) == 0")(arr);
//     assert(find!("(a & 1) == 0")(r).empty);
// }

/* *
Reduces $(D r) by overwriting all elements $(D x) that satisfy $(D
pred(x, v)). Returns the reduced range.

Example:
----
int[] arr = [ 1, 2, 3, 2, 4, 5, 2 ];
// keep elements different from 2
auto r = eliminate(arr, 2);
assert(r == [ 1, 3, 4, 5 ]);
assert(arr == [ 1, 3, 4, 5, 4, 5, 2  ]);
----
*/
// Range eliminate(alias pred = "a == b",
//                 SwapStrategy ss = SwapStrategy.semistable,
//                 Range, Value)(Range r, Value v)
// {
//     alias It = Iterator!(Range);
//     bool comp(typeof(*It) a) { return !binaryFun!(pred)(a, v); }
//     static void assignIterB(It a, It b) { *a = *b; }
//     return range(begin(r),
//             partitionold!(comp,
//                     ss, assignIterB, Range)(r));
// }

// unittest
// {
//     int[] arr = [ 1, 2, 3, 2, 4, 5, 2 ];
// // keep elements different from 2
//     auto r = eliminate(arr, 2);
//     assert(r == [ 1, 3, 4, 5 ]);
//     assert(arr == [ 1, 3, 4, 5, 4, 5, 2  ]);
// }

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
/+

// topNIndexImpl
// @@@BUG1904
/*private*/ void topNIndexImpl(
    alias less,
    bool sortAfter,
    SwapStrategy ss,
    SRange, TRange)(SRange source, TRange target)
{
    alias lessFun = binaryFun!(less);
    static assert(ss == SwapStrategy.unstable,
            "Stable indexing not yet implemented");
    alias SIter = Iterator!(SRange);
    alias TElem = std.iterator.ElementType!(TRange);
    enum usingInt = isIntegral!(TElem);

    static if (usingInt)
    {
        enforce(source.length <= TElem.max,
                "Numeric overflow at risk in computing topNIndexImpl");
    }

    // types and functions used within
    SIter index2iter(TElem a)
    {
        static if (!usingInt)
            return a;
        else
            return begin(source) + a;
    }
    bool indirectLess(TElem a, TElem b)
    {
        return lessFun(*index2iter(a), *index2iter(b));
    }
    void indirectCopy(SIter from, ref TElem to)
    {
        static if (!usingInt)
            to = from;
        else
            to = cast(TElem)(from - begin(source));
    }

    // copy beginning of collection into the target
    auto sb = begin(source), se = end(source),
        tb = begin(target), te = end(target);
    for (; sb != se; ++sb, ++tb)
    {
        if (tb == te) break;
        indirectCopy(sb, *tb);
    }

    // if the index's size is same as the source size, just quicksort it
    // otherwise, heap-insert stuff in it.
    if (sb == se)
    {
        // everything in source is now in target... just sort the thing
        static if (sortAfter) sort!(indirectLess, ss)(target);
    }
    else
    {
        // heap-insert
        te = tb;
        tb = begin(target);
        target = range(tb, te);
        makeHeap!(indirectLess)(target);
        // add stuff to heap
        for (; sb != se; ++sb)
        {
            if (!lessFun(*sb, *index2iter(*tb))) continue;
            // copy the source over the smallest
            indirectCopy(sb, *tb);
            heapify!(indirectLess)(target, tb);
        }
        static if (sortAfter) sortHeap!(indirectLess)(target);
    }
}

/**
topNIndex
*/
void topNIndex(
    alias less,
    SwapStrategy ss = SwapStrategy.unstable,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(less, false, ss)(source, target);
}

/// Ditto
void topNIndex(
    string less,
    SwapStrategy ss = SwapStrategy.unstable,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(binaryFun!(less), false, ss)(source, target);
}

// partialIndex
/**
Computes an index for $(D source) based on the comparison $(D less)
and deposits the result in $(D target). It is acceptable that $(D
target.length < source.length), in which case only the smallest $(D
target.length) elements in $(D source) get indexed. The target
provides a sorted "view" into $(D source). This technique is similar
to sorting and partial sorting, but it is more flexible because (1) it
allows "sorting" of immutable collections, (2) allows binary search
even if the original collection does not offer random access, (3)
allows multiple indexes, each on a different comparison criterion, (4)
may be faster when dealing with large objects. However, using an index
may also be slower under certain circumstances due to the extra
indirection, and is always larger than a sorting-based solution
because it needs space for the index in addition to the original
collection. The complexity is $(BIGOH source.length *
log(target.length)).

Two types of indexes are accepted. They are selected by simply passing
the appropriate $(D target) argument: $(OL $(LI Indexes of type $(D
Iterator!(Source)), in which case the index will be sorted with the
predicate $(D less(*a, *b));) $(LI Indexes of an integral type
(e.g. $(D size_t)), in which case the index will be sorted with the
predicate $(D less(source[a], source[b])).))

Example:

----
immutable arr = [ 2, 3, 1 ];
int* index[3];
partialIndex(arr, index);
assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
assert(isSorted!("*a < *b")(index));
----
*/
void partialIndex(
    alias less,
    SwapStrategy ss = SwapStrategy.unstable,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(less, true, ss)(source, target);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    immutable arr = [ 2, 3, 1 ];
    auto index = new immutable(int)*[3];
    partialIndex!(binaryFun!("a < b"))(arr, index);
    assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
    assert(isSorted!("*a < *b")(index));
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    static bool less(int a, int b) { return a < b; }
    {
        string[] x = ([ "c", "a", "b", "d" ]).dup;
        // test with integrals
        auto index1 = new size_t[x.length];
        partialIndex!(q{a < b})(x, index1);
        assert(index1[0] == 1 && index1[1] == 2 && index1[2] == 0
               && index1[3] == 3);
        // half-sized
        index1 = new size_t[x.length / 2];
        partialIndex!(q{a < b})(x, index1);
        assert(index1[0] == 1 && index1[1] == 2);

        // and with iterators
        auto index = new string*[x.length];
        partialIndex!(q{a < b})(x, index);
        assert(isSorted!(q{*a < *b})(index));
        assert(*index[0] == "a" && *index[1] == "b" && *index[2] == "c"
               && *index[3] == "d");
    }

    {
        immutable arr = [ 2, 3, 1 ];
        auto index = new immutable(int)*[arr.length];
        partialIndex!(less)(arr, index);
        assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
        assert(isSorted!(q{*a < *b})(index));
    }

    // random data
    auto b = rndstuff!(string)();
    auto index = new string*[b.length];
    partialIndex!((a, b) => std.uni.toUpper(a) < std.uni.toUpper(b))(b, index);
    assert(isSorted!((a, b) => std.uni.toUpper(*a) < std.uni.toUpper(*b))(index));

    // random data with indexes
    auto index1 = new size_t[b.length];
    bool cmp(string x, string y) { return std.uni.toUpper(x) < std.uni.toUpper(y); }
    partialIndex!(cmp)(b, index1);
    bool check(size_t x, size_t y) { return std.uni.toUpper(b[x]) < std.uni.toUpper(b[y]); }
    assert(isSorted!(check)(index1));
}

// Commented out for now, needs reimplementation

// // schwartzMakeIndex
// /**
// Similar to $(D makeIndex) but using $(D schwartzSort) to sort the
// index.

// Example:

// ----
// string[] arr = [ "ab", "c", "Ab", "C" ];
// auto index = schwartzMakeIndex!(toUpper, less, SwapStrategy.stable)(arr);
// assert(*index[0] == "ab" && *index[1] == "Ab"
//     && *index[2] == "c" && *index[2] == "C");
// assert(isSorted!("toUpper(*a) < toUpper(*b)")(index));
// ----
// */
// Iterator!(Range)[] schwartzMakeIndex(
//     alias transform,
//     alias less,
//     SwapStrategy ss = SwapStrategy.unstable,
//     Range)(Range r)
// {
//     alias Iter = Iterator!(Range);
//     auto result = new Iter[r.length];
//     // assume collection already ordered
//     size_t i = 0;
//     foreach (it; begin(r) .. end(r))
//     {
//         result[i++] = it;
//     }
//     // sort the index
//     alias Transformed = typeof(transform(*result[0]));
//     static bool indirectLess(Transformed a, Transformed b)
//     {
//         return less(a, b);
//     }
//     static Transformed indirectTransform(Iter a)
//     {
//         return transform(*a);
//     }
//     schwartzSort!(indirectTransform, less, ss)(result);
//     return result;
// }

// /// Ditto
// Iterator!(Range)[] schwartzMakeIndex(
//     alias transform,
//     string less = q{a < b},
//     SwapStrategy ss = SwapStrategy.unstable,
//     Range)(Range r)
// {
//     return .schwartzMakeIndex!(
//         transform, binaryFun!(less), ss, Range)(r);
// }

// version (wyda) unittest
// {
//     string[] arr = [ "D", "ab", "c", "Ab", "C" ];
//     auto index = schwartzMakeIndex!(toUpper, "a < b",
//                                     SwapStrategy.stable)(arr);
//     assert(isSorted!(q{toUpper(*a) < toUpper(*b)})(index));
//     assert(*index[0] == "ab" && *index[1] == "Ab"
//            && *index[2] == "c" && *index[3] == "C");

//     // random data
//     auto b = rndstuff!(string)();
//     auto index1 = schwartzMakeIndex!(toUpper)(b);
//     assert(isSorted!("toUpper(*a) < toUpper(*b)")(index1));
// }

+/

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
