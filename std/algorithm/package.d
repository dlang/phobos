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
$(MYREF minPos) $(MYREF mismatch) $(MYREF skipOver) $(MYREF startsWith)
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
public import std.algorithm.setops;
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
Assigns $(D value) to each element of input range $(D range).

Params:
        range = An $(XREF2 range, isInputRange, input range) that exposes references to its elements
                and has assignable elements
        value = Assigned to each element of range

See_Also:
        $(LREF uninitializedFill)
        $(LREF initializeAll)
 */
void fill(Range, Value)(Range range, Value value)
    if (isInputRange!Range && is(typeof(range.front = value)))
{
    alias T = ElementType!Range;

    static if (is(typeof(range[] = value)))
    {
        range[] = value;
    }
    else static if (is(typeof(range[] = T(value))))
    {
        range[] = T(value);
    }
    else
    {
        for ( ; !range.empty; range.popFront() )
        {
            range.front = value;
        }
    }
}

///
@safe unittest
{
    int[] a = [ 1, 2, 3, 4 ];
    fill(a, 5);
    assert(a == [ 5, 5, 5, 5 ]);
}

@safe unittest
{
    import std.conv : text;
    import std.internal.test.dummyrange;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[] a = [ 1, 2, 3 ];
    fill(a, 6);
    assert(a == [ 6, 6, 6 ], text(a));

    void fun0()
    {
        foreach (i; 0 .. 1000)
        {
            foreach (ref e; a) e = 6;
        }
    }
    void fun1() { foreach (i; 0 .. 1000) fill(a, 6); }
    //void fun2() { foreach (i; 0 .. 1000) fill2(a, 6); }
    //writeln(benchmark!(fun0, fun1, fun2)(10000));

    // fill should accept InputRange
    alias InputRange = DummyRange!(ReturnBy.Reference, Length.No, RangeType.Input);
    enum filler = uint.max;
    InputRange range;
    fill(range, filler);
    foreach (value; range.arr)
        assert(value == filler);
}

@safe unittest
{
    //ER8638_1 IS_NOT self assignable
    static struct ER8638_1
    {
        void opAssign(int){}
    }

    //ER8638_1 IS self assignable
    static struct ER8638_2
    {
        void opAssign(ER8638_2){}
        void opAssign(int){}
    }

    auto er8638_1 = new ER8638_1[](10);
    auto er8638_2 = new ER8638_2[](10);
    er8638_1.fill(5); //generic case
    er8638_2.fill(5); //opSlice(T.init) case
}

@safe unittest
{
    {
        int[] a = [1, 2, 3];
        immutable(int) b = 0;
        static assert(__traits(compiles, a.fill(b)));
    }
    {
        double[] a = [1, 2, 3];
        immutable(int) b = 0;
        static assert(__traits(compiles, a.fill(b)));
    }
}

/**
Fills $(D range) with a pattern copied from $(D filler). The length of
$(D range) does not have to be a multiple of the length of $(D
filler). If $(D filler) is empty, an exception is thrown.

Params:
    range = An $(XREF2 range, isInputRange, input range) that exposes
            references to its elements and has assignable elements.
    filler = The $(XREF2 range, isForwardRange, forward range) representing the
             _fill pattern.
 */
void fill(Range1, Range2)(Range1 range, Range2 filler)
    if (isInputRange!Range1
        && (isForwardRange!Range2
            || (isInputRange!Range2 && isInfinite!Range2))
        && is(typeof(Range1.init.front = Range2.init.front)))
{
    static if (isInfinite!Range2)
    {
        //Range2 is infinite, no need for bounds checking or saving
        static if (hasSlicing!Range2 && hasLength!Range1
            && is(typeof(filler[0 .. range.length])))
        {
            copy(filler[0 .. range.length], range);
        }
        else
        {
            //manual feed
            for ( ; !range.empty; range.popFront(), filler.popFront())
            {
                range.front = filler.front;
            }
        }
    }
    else
    {
        import std.exception : enforce;

        enforce(!filler.empty, "Cannot fill range with an empty filler");

        static if (hasLength!Range1 && hasLength!Range2
            && is(typeof(range.length > filler.length)))
        {
            //Case we have access to length
            auto len = filler.length;
            //Start by bulk copies
            while (range.length > len)
            {
                range = copy(filler.save, range);
            }

            //and finally fill the partial range. No need to save here.
            static if (hasSlicing!Range2 && is(typeof(filler[0 .. range.length])))
            {
                //use a quick copy
                auto len2 = range.length;
                range = copy(filler[0 .. len2], range);
            }
            else
            {
                //iterate. No need to check filler, it's length is longer than range's
                for (; !range.empty; range.popFront(), filler.popFront())
                {
                    range.front = filler.front;
                }
            }
        }
        else
        {
            //Most basic case.
            auto bck = filler.save;
            for (; !range.empty; range.popFront(), filler.popFront())
            {
                if (filler.empty) filler = bck.save;
                range.front = filler.front;
            }
        }
    }
}

///
@safe unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    int[] b = [ 8, 9 ];
    fill(a, b);
    assert(a == [ 8, 9, 8, 9, 8 ]);
}

@safe unittest
{
    import std.exception : assertThrown;
    import std.internal.test.dummyrange;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[] a = [ 1, 2, 3, 4, 5 ];
    int[] b = [1, 2];
    fill(a, b);
    assert(a == [ 1, 2, 1, 2, 1 ]);

    // fill should accept InputRange
    alias InputRange = DummyRange!(ReturnBy.Reference, Length.No, RangeType.Input);
    InputRange range;
    fill(range,[1,2]);
    foreach (i,value;range.arr)
    assert(value == (i%2==0?1:2));

    //test with a input being a "reference forward" range
    fill(a, new ReferenceForwardRange!int([8, 9]));
    assert(a == [8, 9, 8, 9, 8]);

    //test with a input being an "infinite input" range
    fill(a, new ReferenceInfiniteInputRange!int());
    assert(a == [0, 1, 2, 3, 4]);

    //empty filler test
    assertThrown(fill(a, a[$..$]));
}

/**
Initializes each element of $(D range) with $(D value).
Assumes that the elements of the range are uninitialized.
This is of interest for structs that
define copy constructors (for all other types, $(LREF fill) and
uninitializedFill are equivalent).

Params:
        range = An $(XREF2 range, isInputRange, input range) that exposes references to its elements
                and has assignable elements
        value = Assigned to each element of range

See_Also:
        $(LREF fill)
        $(LREF initializeAll)

Example:
----
struct S { ... }
S[] s = (cast(S*) malloc(5 * S.sizeof))[0 .. 5];
uninitializedFill(s, 42);
assert(s == [ 42, 42, 42, 42, 42 ]);
----
 */
void uninitializedFill(Range, Value)(Range range, Value value)
    if (isInputRange!Range && hasLvalueElements!Range && is(typeof(range.front = value)))
{
    alias T = ElementType!Range;
    static if (hasElaborateAssign!T)
    {
        import std.conv : emplaceRef;

        // Must construct stuff by the book
        for (; !range.empty; range.popFront())
            emplaceRef!T(range.front, value);
    }
    else
        // Doesn't matter whether fill is initialized or not
        return fill(range, value);
}

/**
Initializes all elements of $(D range) with their $(D .init) value.
Assumes that the elements of the range are uninitialized.

Params:
        range = An $(XREF2 range, isInputRange, input range) that exposes references to its elements
                and has assignable elements

See_Also:
        $(LREF fill)
        $(LREF uninitializeFill)

Example:
----
struct S { ... }
S[] s = (cast(S*) malloc(5 * S.sizeof))[0 .. 5];
initializeAll(s);
assert(s == [ 0, 0, 0, 0, 0 ]);
----
 */
void initializeAll(Range)(Range range)
    if (isInputRange!Range && hasLvalueElements!Range && hasAssignableElements!Range)
{
    import core.stdc.string : memset, memcpy;

    alias T = ElementType!Range;
    static if (hasElaborateAssign!T)
    {
        //Elaborate opAssign. Must go the memcpy road.
        //We avoid calling emplace here, because our goal is to initialize to
        //the static state of T.init,
        //So we want to avoid any un-necassarilly CC'ing of T.init
        auto p = typeid(T).init().ptr;
        if (p)
            for ( ; !range.empty ; range.popFront() )
                memcpy(addressOf(range.front), p, T.sizeof);
        else
            static if (isDynamicArray!Range)
                memset(range.ptr, 0, range.length * T.sizeof);
            else
                for ( ; !range.empty ; range.popFront() )
                    memset(addressOf(range.front), 0, T.sizeof);
    }
    else
        fill(range, T.init);
}

// ditto
void initializeAll(Range)(Range range)
    if (is(Range == char[]) || is(Range == wchar[]))
{
    alias T = ElementEncodingType!Range;
    range[] = T.init;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    //Test strings:
    //Must work on narrow strings.
    //Must reject const
    char[3] a = void;
    a[].initializeAll();
    assert(a[] == [char.init, char.init, char.init]);
    string s;
    assert(!__traits(compiles, s.initializeAll()));

    //Note: Cannot call uninitializedFill on narrow strings

    enum e {e1, e2}
    e[3] b1 = void;
    b1[].initializeAll();
    assert(b1[] == [e.e1, e.e1, e.e1]);
    e[3] b2 = void;
    b2[].uninitializedFill(e.e2);
    assert(b2[] == [e.e2, e.e2, e.e2]);

    static struct S1
    {
        int i;
    }
    static struct S2
    {
        int i = 1;
    }
    static struct S3
    {
        int i;
        this(this){}
    }
    static struct S4
    {
        int i = 1;
        this(this){}
    }
    static assert (!hasElaborateAssign!S1);
    static assert (!hasElaborateAssign!S2);
    static assert ( hasElaborateAssign!S3);
    static assert ( hasElaborateAssign!S4);
    assert (!typeid(S1).init().ptr);
    assert ( typeid(S2).init().ptr);
    assert (!typeid(S3).init().ptr);
    assert ( typeid(S4).init().ptr);

    foreach(S; TypeTuple!(S1, S2, S3, S4))
    {
        //initializeAll
        {
            //Array
            S[3] ss1 = void;
            ss1[].initializeAll();
            assert(ss1[] == [S.init, S.init, S.init]);

            //Not array
            S[3] ss2 = void;
            auto sf = ss2[].filter!"true"();

            sf.initializeAll();
            assert(ss2[] == [S.init, S.init, S.init]);
        }
        //uninitializedFill
        {
            //Array
            S[3] ss1 = void;
            ss1[].uninitializedFill(S(2));
            assert(ss1[] == [S(2), S(2), S(2)]);

            //Not array
            S[3] ss2 = void;
            auto sf = ss2[].filter!"true"();
            sf.uninitializedFill(S(2));
            assert(ss2[] == [S(2), S(2), S(2)]);
        }
    }
}

// move
/**
Moves $(D source) into $(D target) via a destructive copy.

Params:
    source = Data to copy. If a destructor or postblit is defined, it is reset
        to its $(D .init) value after it is moved into target.  Note that data
        with internal pointers that point to itself cannot be moved, and will
        trigger an assertion failure.
    target = Where to copy into. The destructor, if any, is invoked before the
        copy is performed.
*/
void move(T)(ref T source, ref T target)
{
    import core.stdc.string : memcpy;

    static if (hasAliasing!T) if (!__ctfe)
    {
        import std.exception : doesPointTo;
        assert(!doesPointTo(source, source), "Cannot move object with internal pointer.");
    }

    static if (is(T == struct))
    {
        if (&source == &target) return;
        // Most complicated case. Destroy whatever target had in it
        // and bitblast source over it
        static if (hasElaborateDestructor!T) typeid(T).destroy(&target);

        static if (hasElaborateAssign!T || !isAssignable!T)
            memcpy(&target, &source, T.sizeof);
        else
            target = source;

        // If the source defines a destructor or a postblit hook, we must obliterate the
        // object in order to avoid double freeing and undue aliasing
        static if (hasElaborateDestructor!T || hasElaborateCopyConstructor!T)
        {
            static T empty;
            static if (T.tupleof.length > 0 &&
                       T.tupleof[$-1].stringof.endsWith("this"))
            {
                // If T is nested struct, keep original context pointer
                memcpy(&source, &empty, T.sizeof - (void*).sizeof);
            }
            else
            {
                memcpy(&source, &empty, T.sizeof);
            }
        }
    }
    else
    {
        // Primitive data (including pointers and arrays) or class -
        // assignment works great
        target = source;
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    import std.exception : assertCTFEable;
    assertCTFEable!((){
        Object obj1 = new Object;
        Object obj2 = obj1;
        Object obj3;
        move(obj2, obj3);
        assert(obj3 is obj1);

        static struct S1 { int a = 1, b = 2; }
        S1 s11 = { 10, 11 };
        S1 s12;
        move(s11, s12);
        assert(s11.a == 10 && s11.b == 11 && s12.a == 10 && s12.b == 11);

        static struct S2 { int a = 1; int * b; }
        S2 s21 = { 10, null };
        s21.b = new int;
        S2 s22;
        move(s21, s22);
        assert(s21 == s22);
    });
    // Issue 5661 test(1)
    static struct S3
    {
        static struct X { int n = 0; ~this(){n = 0;} }
        X x;
    }
    static assert(hasElaborateDestructor!S3);
    S3 s31, s32;
    s31.x.n = 1;
    move(s31, s32);
    assert(s31.x.n == 0);
    assert(s32.x.n == 1);

    // Issue 5661 test(2)
    static struct S4
    {
        static struct X { int n = 0; this(this){n = 0;} }
        X x;
    }
    static assert(hasElaborateCopyConstructor!S4);
    S4 s41, s42;
    s41.x.n = 1;
    move(s41, s42);
    assert(s41.x.n == 0);
    assert(s42.x.n == 1);
}

/// Ditto
T move(T)(ref T source)
{
    import core.stdc.string : memcpy;

    static if (hasAliasing!T) if (!__ctfe)
    {
        import std.exception : doesPointTo;
        assert(!doesPointTo(source, source), "Cannot move object with internal pointer.");
    }

    T result = void;
    static if (is(T == struct))
    {
        // Can avoid destructing result.
        static if (hasElaborateAssign!T || !isAssignable!T)
            memcpy(&result, &source, T.sizeof);
        else
            result = source;

        // If the source defines a destructor or a postblit hook, we must obliterate the
        // object in order to avoid double freeing and undue aliasing
        static if (hasElaborateDestructor!T || hasElaborateCopyConstructor!T)
        {
            static T empty;
            static if (T.tupleof.length > 0 &&
                       T.tupleof[$-1].stringof.endsWith("this"))
            {
                // If T is nested struct, keep original context pointer
                memcpy(&source, &empty, T.sizeof - (void*).sizeof);
            }
            else
            {
                memcpy(&source, &empty, T.sizeof);
            }
        }
    }
    else
    {
        // Primitive data (including pointers and arrays) or class -
        // assignment works great
        result = source;
    }
    return result;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    import std.exception : assertCTFEable;
    assertCTFEable!((){
        Object obj1 = new Object;
        Object obj2 = obj1;
        Object obj3 = move(obj2);
        assert(obj3 is obj1);

        static struct S1 { int a = 1, b = 2; }
        S1 s11 = { 10, 11 };
        S1 s12 = move(s11);
        assert(s11.a == 10 && s11.b == 11 && s12.a == 10 && s12.b == 11);

        static struct S2 { int a = 1; int * b; }
        S2 s21 = { 10, null };
        s21.b = new int;
        S2 s22 = move(s21);
        assert(s21 == s22);
    });

    // Issue 5661 test(1)
    static struct S3
    {
        static struct X { int n = 0; ~this(){n = 0;} }
        X x;
    }
    static assert(hasElaborateDestructor!S3);
    S3 s31;
    s31.x.n = 1;
    S3 s32 = move(s31);
    assert(s31.x.n == 0);
    assert(s32.x.n == 1);

    // Issue 5661 test(2)
    static struct S4
    {
        static struct X { int n = 0; this(this){n = 0;} }
        X x;
    }
    static assert(hasElaborateCopyConstructor!S4);
    S4 s41;
    s41.x.n = 1;
    S4 s42 = move(s41);
    assert(s41.x.n == 0);
    assert(s42.x.n == 1);
}

unittest//Issue 6217
{
    auto x = map!"a"([1,2,3]);
    x = move(x);
}

unittest// Issue 8055
{
    static struct S
    {
        int x;
        ~this()
        {
            assert(x == 0);
        }
    }
    S foo(S s)
    {
        return move(s);
    }
    S a;
    a.x = 0;
    auto b = foo(a);
    assert(b.x == 0);
}

unittest// Issue 8057
{
    int n = 10;
    struct S
    {
        int x;
        ~this()
        {
            // Access to enclosing scope
            assert(n == 10);
        }
    }
    S foo(S s)
    {
        // Move nested struct
        return move(s);
    }
    S a;
    a.x = 1;
    auto b = foo(a);
    assert(b.x == 1);

    // Regression 8171
    static struct Array(T)
    {
        // nested struct has no member
        struct Payload
        {
            ~this() {}
        }
    }
    Array!int.Payload x = void;
    static assert(__traits(compiles, move(x)    ));
    static assert(__traits(compiles, move(x, x) ));
}

// moveAll
/**
For each element $(D a) in $(D src) and each element $(D b) in $(D
tgt) in lockstep in increasing order, calls $(D move(a, b)).

Preconditions:
$(D walkLength(src) <= walkLength(tgt)).
An exception will be thrown if this condition does not hold, i.e., there is not
enough room in $(D tgt) to accommodate all of $(D src).

Params:
    src = An $(XREF2 range, isInputRange, input range) with movable elements.
    tgt = An $(XREF2 range, isInputRange, input range) with elements that
        elements from $(D src) can be moved into.

Returns: The leftover portion of $(D tgt) after all elements from $(D src) have
been moved.
 */
Range2 moveAll(Range1, Range2)(Range1 src, Range2 tgt)
if (isInputRange!Range1 && isInputRange!Range2
        && is(typeof(move(src.front, tgt.front))))
{
    import std.exception : enforce;

    static if (isRandomAccessRange!Range1 && hasLength!Range1 && hasLength!Range2
         && hasSlicing!Range2 && isRandomAccessRange!Range2)
    {
        auto toMove = src.length;
        enforce(toMove <= tgt.length);  // shouldn't this be an assert?
        foreach (idx; 0 .. toMove)
            move(src[idx], tgt[idx]);
        return tgt[toMove .. tgt.length];
    }
    else
    {
        for (; !src.empty; src.popFront(), tgt.popFront())
        {
            enforce(!tgt.empty);  //ditto?
            move(src.front, tgt.front);
        }
        return tgt;
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 3 ];
    int[] b = new int[5];
    assert(moveAll(a, b) is b[3 .. $]);
    assert(a == b[0 .. 3]);
    assert(a == [ 1, 2, 3 ]);
}

// moveSome
/**
For each element $(D a) in $(D src) and each element $(D b) in $(D
tgt) in lockstep in increasing order, calls $(D move(a, b)). Stops
when either $(D src) or $(D tgt) have been exhausted.

Params:
    src = An $(XREF2 range, isInputRange, input range) with movable elements.
    tgt = An $(XREF2 range, isInputRange, input range) with elements that
        elements from $(D src) can be moved into.

Returns: The leftover portions of the two ranges after one or the other of the
ranges have been exhausted.
 */
Tuple!(Range1, Range2) moveSome(Range1, Range2)(Range1 src, Range2 tgt)
if (isInputRange!Range1 && isInputRange!Range2
        && is(typeof(move(src.front, tgt.front))))
{
    import std.exception : enforce;

    for (; !src.empty && !tgt.empty; src.popFront(), tgt.popFront())
    {
        enforce(!tgt.empty);
        move(src.front, tgt.front);
    }
    return tuple(src, tgt);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
   int[] a = [ 1, 2, 3, 4, 5 ];
    int[] b = new int[3];
    assert(moveSome(a, b)[0] is a[3 .. $]);
    assert(a[0 .. 3] == b);
    assert(a == [ 1, 2, 3, 4, 5 ]);
}

// swap
/**
Swaps $(D lhs) and $(D rhs). The instances $(D lhs) and $(D rhs) are moved in
memory, without ever calling $(D opAssign), nor any other function. $(D T)
need not be assignable at all to be swapped.

If $(D lhs) and $(D rhs) reference the same instance, then nothing is done.

$(D lhs) and $(D rhs) must be mutable. If $(D T) is a struct or union, then
its fields must also all be (recursively) mutable.

Params:
    lhs = Data to be swapped with $(D rhs).
    rhs = Data to be swapped with $(D lhs).
*/
void swap(T)(ref T lhs, ref T rhs) @trusted pure nothrow @nogc
if (isBlitAssignable!T && !is(typeof(lhs.proxySwap(rhs))))
{
    static if (hasAliasing!T) if (!__ctfe)
    {
        import std.exception : doesPointTo;
        assert(!doesPointTo(lhs, lhs), "Swap: lhs internal pointer.");
        assert(!doesPointTo(rhs, rhs), "Swap: rhs internal pointer.");
        assert(!doesPointTo(lhs, rhs), "Swap: lhs points to rhs.");
        assert(!doesPointTo(rhs, lhs), "Swap: rhs points to lhs.");
    }

    static if (hasElaborateAssign!T || !isAssignable!T)
    {
        if (&lhs != &rhs)
        {
            // For structs with non-trivial assignment, move memory directly
            ubyte[T.sizeof] t = void;
            auto a = (cast(ubyte*) &lhs)[0 .. T.sizeof];
            auto b = (cast(ubyte*) &rhs)[0 .. T.sizeof];
            t[] = a[];
            a[] = b[];
            b[] = t[];
        }
    }
    else
    {
        //Avoid assigning overlapping arrays. Dynamic arrays are fine, because
        //it's their ptr and length properties which get assigned rather
        //than their elements when assigning them, but static arrays are value
        //types and therefore all of their elements get copied as part of
        //assigning them, which would be assigning overlapping arrays if lhs
        //and rhs were the same array.
        static if (isStaticArray!T)
        {
            if (lhs.ptr == rhs.ptr)
                return;
        }

        // For non-struct types, suffice to do the classic swap
        auto tmp = lhs;
        lhs = rhs;
        rhs = tmp;
    }
}

// Not yet documented
void swap(T)(ref T lhs, ref T rhs) if (is(typeof(lhs.proxySwap(rhs))))
{
    lhs.proxySwap(rhs);
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int a = 42, b = 34;
    swap(a, b);
    assert(a == 34 && b == 42);

    static struct S { int x; char c; int[] y; }
    S s1 = { 0, 'z', [ 1, 2 ] };
    S s2 = { 42, 'a', [ 4, 6 ] };
    //writeln(s2.tupleof.stringof);
    swap(s1, s2);
    assert(s1.x == 42);
    assert(s1.c == 'a');
    assert(s1.y == [ 4, 6 ]);

    assert(s2.x == 0);
    assert(s2.c == 'z');
    assert(s2.y == [ 1, 2 ]);

    immutable int imm1, imm2;
    static assert(!__traits(compiles, swap(imm1, imm2)));
}

@safe unittest
{
    static struct NoCopy
    {
        this(this) { assert(0); }
        int n;
        string s;
    }
    NoCopy nc1, nc2;
    nc1.n = 127; nc1.s = "abc";
    nc2.n = 513; nc2.s = "uvwxyz";
    swap(nc1, nc2);
    assert(nc1.n == 513 && nc1.s == "uvwxyz");
    assert(nc2.n == 127 && nc2.s == "abc");
    swap(nc1, nc1);
    swap(nc2, nc2);
    assert(nc1.n == 513 && nc1.s == "uvwxyz");
    assert(nc2.n == 127 && nc2.s == "abc");

    static struct NoCopyHolder
    {
        NoCopy noCopy;
    }
    NoCopyHolder h1, h2;
    h1.noCopy.n = 31; h1.noCopy.s = "abc";
    h2.noCopy.n = 65; h2.noCopy.s = null;
    swap(h1, h2);
    assert(h1.noCopy.n == 65 && h1.noCopy.s == null);
    assert(h2.noCopy.n == 31 && h2.noCopy.s == "abc");
    swap(h1, h1);
    swap(h2, h2);
    assert(h1.noCopy.n == 65 && h1.noCopy.s == null);
    assert(h2.noCopy.n == 31 && h2.noCopy.s == "abc");

    const NoCopy const1, const2;
    static assert(!__traits(compiles, swap(const1, const2)));
}

@safe unittest
{
    //Bug# 4789
    int[1] s = [1];
    swap(s, s);
}

@safe unittest
{
    static struct NoAssign
    {
        int i;
        void opAssign(NoAssign) @disable;
    }
    auto s1 = NoAssign(1);
    auto s2 = NoAssign(2);
    swap(s1, s2);
    assert(s1.i == 2);
    assert(s2.i == 1);
}

@safe unittest
{
    struct S
    {
        const int i;
    }
    S s;
    static assert(!__traits(compiles, swap(s, s)));
}

@safe unittest
{
    //11853
    alias T = Tuple!(int, double);
    static assert(isAssignable!T);
}

@safe unittest
{
    // 12024
    import std.datetime;
    SysTime a, b;
}

unittest // 9975
{
    import std.exception : doesPointTo, mayPointTo;
    static struct S2
    {
        union
        {
            size_t sz;
            string s;
        }
    }
    S2 a , b;
    a.sz = -1;
    assert(!doesPointTo(a, b));
    assert( mayPointTo(a, b));
    swap(a, b);

    //Note: we can catch an error here, because there is no RAII in this test
    import std.exception : assertThrown;
    void* p, pp;
    p = &p;
    assertThrown!Error(move(p));
    assertThrown!Error(move(p, pp));
    assertThrown!Error(swap(p, pp));
}

unittest
{
    static struct A
    {
        int* x;
        this(this) { x = new int; }
    }
    A a1, a2;
    swap(a1, a2);

    static struct B
    {
        int* x;
        void opAssign(B) { x = new int; }
    }
    B b1, b2;
    swap(b1, b2);
}

void swapFront(R1, R2)(R1 r1, R2 r2)
    if (isInputRange!R1 && isInputRange!R2)
{
    static if (is(typeof(swap(r1.front, r2.front))))
    {
        swap(r1.front, r2.front);
    }
    else
    {
        auto t1 = moveFront(r1), t2 = moveFront(r2);
        r1.front = move(t2);
        r2.front = move(t1);
    }
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

// find
/**
Finds an individual element in an input range. Elements of $(D
haystack) are compared with $(D needle) by using predicate $(D
pred). Performs $(BIGOH walkLength(haystack)) evaluations of $(D
pred).

To _find the last occurrence of $(D needle) in $(D haystack), call $(D
find(retro(haystack), needle)). See $(XREF range, retro).

Params:

pred = The predicate for comparing each element with the needle, defaulting to
$(D "a == b").
The negated predicate $(D "a != b") can be used to search instead for the first
element $(I not) matching the needle.

haystack = The $(XREF2 range, isInputRange, input range) searched in.

needle = The element searched for.

Constraints:

$(D isInputRange!InputRange && is(typeof(binaryFun!pred(haystack.front, needle)
: bool)))

Returns:

$(D haystack) advanced such that the front element is the one searched for;
that is, until $(D binaryFun!pred(haystack.front, needle)) is $(D true). If no
such position exists, returns an empty $(D haystack).

See_Also:
     $(WEB sgi.com/tech/stl/_find.html, STL's _find)
 */
InputRange find(alias pred = "a == b", InputRange, Element)(InputRange haystack, Element needle)
if (isInputRange!InputRange &&
    is (typeof(binaryFun!pred(haystack.front, needle)) : bool))
{
    alias R = InputRange;
    alias E = Element;
    alias predFun = binaryFun!pred;
    static if (is(typeof(pred == "a == b")))
        enum isDefaultPred = pred == "a == b";
    else
        enum isDefaultPred = false;
    enum  isIntegralNeedle = isSomeChar!E || isIntegral!E || isBoolean!E;

    alias EType  = ElementType!R;

    static if (isNarrowString!R)
    {
        alias EEType = ElementEncodingType!R;
        alias UEEType = Unqual!EEType;

        //These are two special cases which can search without decoding the UTF stream.
        static if (isDefaultPred && isIntegralNeedle)
        {
            import std.utf : canSearchInCodeUnits;

            //This special case deals with UTF8 search, when the needle
            //is represented by a single code point.
            //Note: "needle <= 0x7F" properly handles sign via unsigned promotion
            static if (is(UEEType == char))
            {
                if (!__ctfe && canSearchInCodeUnits!char(needle))
                {
                    static R trustedMemchr(ref R haystack, ref E needle) @trusted nothrow pure
                    {
                        import core.stdc.string : memchr;
                        auto ptr = memchr(haystack.ptr, needle, haystack.length);
                        return ptr ?
                             haystack[ptr - haystack.ptr .. $] :
                             haystack[$ .. $];
                    }
                    return trustedMemchr(haystack, needle);
                }
            }

            //Ditto, but for UTF16
            static if (is(UEEType == wchar))
            {
                if (canSearchInCodeUnits!wchar(needle))
                {
                    foreach (i, ref EEType e; haystack)
                    {
                        if (e == needle)
                            return haystack[i .. $];
                    }
                    return haystack[$ .. $];
                }
            }
        }

        //Previous conditonal optimizations did not succeed. Fallback to
        //unconditional implementations
        static if (isDefaultPred)
        {
            import std.utf : encode;

            //In case of default pred, it is faster to do string/string search.
            UEEType[is(UEEType == char) ? 4 : 2] buf;

            size_t len = encode(buf, needle);
            return find(haystack, buf[0 .. len]);
        }
        else
        {
            import std.utf : decode;

            //Explicit pred: we must test each character by the book.
            //We choose a manual decoding approach, because it is faster than
            //the built-in foreach, or doing a front/popFront for-loop.
            immutable len = haystack.length;
            size_t i = 0, next = 0;
            while (next < len)
            {
                if (predFun(decode(haystack, next), needle))
                    return haystack[i .. $];
                i = next;
            }
            return haystack[$ .. $];
        }
    }
    else static if (isArray!R)
    {
        //10403 optimization
        static if (isDefaultPred && isIntegral!EType && EType.sizeof == 1 && isIntegralNeedle)
        {
            R findHelper(ref R haystack, ref E needle) @trusted nothrow pure
            {
                import core.stdc.string : memchr;

                EType* ptr = null;
                //Note: we use "min/max" to handle sign mismatch.
                if (min(EType.min, needle) == EType.min &&
                    max(EType.max, needle) == EType.max)
                {
                    ptr = cast(EType*) memchr(haystack.ptr, needle,
                        haystack.length);
                }

                return ptr ?
                    haystack[ptr - haystack.ptr .. $] :
                    haystack[$ .. $];
            }

            if (!__ctfe)
                return findHelper(haystack, needle);
        }

        //Default implementation.
        foreach (i, ref e; haystack)
            if (predFun(e, needle))
                return haystack[i .. $];
        return haystack[$ .. $];
    }
    else
    {
        //Everything else. Walk.
        for ( ; !haystack.empty; haystack.popFront() )
        {
            if (predFun(haystack.front, needle))
                break;
        }
        return haystack;
    }
}

///
@safe unittest
{
    import std.container : SList;

    assert(find("hello, world", ',') == ", world");
    assert(find([1, 2, 3, 5], 4) == []);
    assert(equal(find(SList!int(1, 2, 3, 4, 5)[], 4), SList!int(4, 5)[]));
    assert(find!"a > b"([1, 2, 3, 5], 2) == [3, 5]);

    auto a = [ 1, 2, 3 ];
    assert(find(a, 5).empty);       // not found
    assert(!find(a, 2).empty);      // found

    // Case-insensitive find of a string
    string[] s = [ "Hello", "world", "!" ];
    assert(!find!("toLower(a) == b")(s, "hello").empty);
}

@safe unittest
{
    import std.container : SList;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto lst = SList!int(1, 2, 5, 7, 3);
    assert(lst.front == 1);
    auto r = find(lst[], 5);
    assert(equal(r, SList!int(5, 7, 3)[]));
    assert(find([1, 2, 3, 5], 4).empty);
    assert(equal(find!"a > b"("hello", 'k'), "llo"));
}

@safe pure nothrow unittest
{
    int[] a1 = [1, 2, 3];
    assert(!find              ([1, 2, 3], 2).empty);
    assert(!find!((a,b)=>a==b)([1, 2, 3], 2).empty);
    ubyte[] a2 = [1, 2, 3];
    ubyte   b2 = 2;
    assert(!find              ([1, 2, 3], 2).empty);
    assert(!find!((a,b)=>a==b)([1, 2, 3], 2).empty);
}

@safe pure unittest
{
    foreach(R; TypeTuple!(string, wstring, dstring))
    {
        foreach(E; TypeTuple!(char, wchar, dchar))
        {
            R r1 = "hello world";
            E e1 = 'w';
            assert(find              ("hello world", 'w') == "world");
            assert(find!((a,b)=>a==b)("hello world", 'w') == "world");
            R r2 = "日c語";
            E e2 = 'c';
            assert(find              ("日c語", 'c') == "c語");
            assert(find!((a,b)=>a==b)("日c語", 'c') == "c語");
            static if (E.sizeof >= 2)
            {
                R r3 = "hello world";
                E e3 = 'w';
                assert(find              ("日本語", '本') == "本語");
                assert(find!((a,b)=>a==b)("日本語", '本') == "本語");
            }
        }
    }
}

@safe unittest
{
    //CTFE
    static assert (find("abc", 'b') == "bc");
    static assert (find("日b語", 'b') == "b語");
    static assert (find("日本語", '本') == "本語");
    static assert (find([1, 2, 3], 2)  == [2, 3]);

    int[] a1 = [1, 2, 3];
    static assert(find              ([1, 2, 3], 2));
    static assert(find!((a,b)=>a==b)([1, 2, 3], 2));
    ubyte[] a2 = [1, 2, 3];
    ubyte   b2 = 2;
    static assert(find              ([1, 2, 3], 2));
    static assert(find!((a,b)=>a==b)([1, 2, 3], 2));
}

@safe unittest
{
    import std.exception : assertCTFEable;

    void dg() @safe pure nothrow
    {
        byte[]  sarr = [1, 2, 3, 4];
        ubyte[] uarr = [1, 2, 3, 4];
        foreach(arr; TypeTuple!(sarr, uarr))
        {
            foreach(T; TypeTuple!(byte, ubyte, int, uint))
            {
                assert(find(arr, cast(T) 3) == arr[2 .. $]);
                assert(find(arr, cast(T) 9) == arr[$ .. $]);
            }
            assert(find(arr, 256) == arr[$ .. $]);
        }
    }
    dg();
    assertCTFEable!dg;
}

@safe unittest
{
    // Bugzilla 11603
    enum Foo : ubyte { A }
    assert([Foo.A].find(Foo.A).empty == false);

    ubyte x = 0;
    assert([x].find(x).empty == false);
}

/**
Advances the input range $(D haystack) by calling $(D haystack.popFront)
until either $(D pred(haystack.front)), or $(D
haystack.empty). Performs $(BIGOH haystack.length) evaluations of $(D
pred).

To _find the last element of a bidirectional $(D haystack) satisfying
$(D pred), call $(D find!(pred)(retro(haystack))). See $(XREF
range, retro).

Params:

pred = The predicate for determining if a given element is the one being
searched for.

haystack = The $(XREF2 range, isInputRange, input range) to search in.

Returns:

$(D haystack) advanced such that the front element is the one searched for;
that is, until $(D binaryFun!pred(haystack.front, needle)) is $(D true). If no
such position exists, returns an empty $(D haystack).

See_Also:
     $(WEB sgi.com/tech/stl/find_if.html, STL's find_if)
*/
InputRange find(alias pred, InputRange)(InputRange haystack)
if (isInputRange!InputRange)
{
    alias R = InputRange;
    alias predFun = unaryFun!pred;
    static if (isNarrowString!R)
    {
        import std.utf : decode;

        immutable len = haystack.length;
        size_t i = 0, next = 0;
        while (next < len)
        {
            if (predFun(decode(haystack, next)))
                return haystack[i .. $];
            i = next;
        }
        return haystack[$ .. $];
    }
    else static if (!isInfinite!R && hasSlicing!R && is(typeof(haystack[cast(size_t)0 .. $])))
    {
        size_t i = 0;
        foreach (ref e; haystack)
        {
            if (predFun(e))
                return haystack[i .. $];
            ++i;
        }
        return haystack[$ .. $];
    }
    else
    {
        //standard range
        for ( ; !haystack.empty; haystack.popFront() )
        {
            if (predFun(haystack.front))
                break;
        }
        return haystack;
    }
}

///
@safe unittest
{
    auto arr = [ 1, 2, 3, 4, 1 ];
    assert(find!("a > 2")(arr) == [ 3, 4, 1 ]);

    // with predicate alias
    bool pred(int x) { return x + 1 > 1.5; }
    assert(find!(pred)(arr) == arr);
}

@safe pure unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] r = [ 1, 2, 3 ];
    assert(find!(a=>a > 2)(r) == [3]);
    bool pred(int x) { return x + 1 > 1.5; }
    assert(find!(pred)(r) == r);

    assert(find!(a=>a > 'v')("hello world") == "world");
    assert(find!(a=>a%4 == 0)("日本語") == "本語");
}

/**
Finds the first occurrence of a forward range in another forward range.

Performs $(BIGOH walkLength(haystack) * walkLength(needle)) comparisons in the
worst case.  There are specializations that improve performance by taking
advantage of bidirectional or random access in the given ranges (where
possible), depending on the statistics of the two ranges' content.

Params:

pred = The predicate to use for comparing respective elements from the haystack
and the needle. Defaults to simple equality $(D "a == b").

haystack = The $(XREF2 range, isForwardRange, forward range) searched in.

needle = The $(XREF2 range, isForwardRange, forward range) searched for.

Returns:

$(D haystack) advanced such that $(D needle) is a prefix of it (if no
such position exists, returns $(D haystack) advanced to termination).
 */
R1 find(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (isForwardRange!R1 && isForwardRange!R2
        && is(typeof(binaryFun!pred(haystack.front, needle.front)) : bool)
        && !isRandomAccessRange!R1)
{
    static if (is(typeof(pred == "a == b")) && pred == "a == b" && isSomeString!R1 && isSomeString!R2
            && haystack[0].sizeof == needle[0].sizeof)
    {
        //return cast(R1) find(representation(haystack), representation(needle));
        // Specialization for simple string search
        alias Representation =
            Select!(haystack[0].sizeof == 1, ubyte[],
                Select!(haystack[0].sizeof == 2, ushort[], uint[]));
        // Will use the array specialization
        static TO force(TO, T)(T r) @trusted { return cast(TO)r; }
        return force!R1(.find!(pred, Representation, Representation)
            (force!Representation(haystack), force!Representation(needle)));
    }
    else
    {
        return simpleMindedFind!pred(haystack, needle);
    }
}

///
@safe unittest
{
    import std.container : SList;

    assert(find("hello, world", "World").empty);
    assert(find("hello, world", "wo") == "world");
    assert([1, 2, 3, 4].find(SList!int(2, 3)[]) == [2, 3, 4]);
    alias C = Tuple!(int, "x", int, "y");
    auto a = [C(1,0), C(2,0), C(3,1), C(4,0)];
    assert(a.find!"a.x == b"([2, 3]) == [C(2,0), C(3,1), C(4,0)]);
    assert(a[1 .. $].find!"a.x == b"([2, 3]) == [C(2,0), C(3,1), C(4,0)]);
}

@safe unittest
{
    import std.container : SList;
    alias C = Tuple!(int, "x", int, "y");
    assert([C(1,0), C(2,0), C(3,1), C(4,0)].find!"a.x == b"(SList!int(2, 3)[]) == [C(2,0), C(3,1), C(4,0)]);
}

@safe unittest
{
    import std.container : SList;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto lst = SList!int(1, 2, 5, 7, 3);
    static assert(isForwardRange!(int[]));
    static assert(isForwardRange!(typeof(lst[])));
    auto r = find(lst[], [2, 5]);
    assert(equal(r, SList!int(2, 5, 7, 3)[]));
}

// Specialization for searching a random-access range for a
// bidirectional range
R1 find(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (isRandomAccessRange!R1 && isBidirectionalRange!R2
        && is(typeof(binaryFun!pred(haystack.front, needle.front)) : bool))
{
    if (needle.empty) return haystack;
    const needleLength = walkLength(needle.save);
    if (needleLength > haystack.length)
    {
        // @@@BUG@@@
        //return haystack[$ .. $];
        return haystack[haystack.length .. haystack.length];
    }
    // @@@BUG@@@
    // auto needleBack = moveBack(needle);
    // Stage 1: find the step
    size_t step = 1;
    auto needleBack = needle.back;
    needle.popBack();
    for (auto i = needle.save; !i.empty && i.back != needleBack;
         i.popBack(), ++step)
    {
    }
    // Stage 2: linear find
    size_t scout = needleLength - 1;
    for (;;)
    {
        if (scout >= haystack.length)
        {
            return haystack[haystack.length .. haystack.length];
        }
        if (!binaryFun!pred(haystack[scout], needleBack))
        {
            ++scout;
            continue;
        }
        // Found a match with the last element in the needle
        auto cand = haystack[scout + 1 - needleLength .. haystack.length];
        if (startsWith!pred(cand, needle))
        {
            // found
            return cand;
        }
        // Continue with the stride
        scout += step;
    }
}

@safe unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    // @@@BUG@@@ removing static below makes unittest fail
    static struct BiRange
    {
        int[] payload;
        @property bool empty() { return payload.empty; }
        @property BiRange save() { return this; }
        @property ref int front() { return payload[0]; }
        @property ref int back() { return payload[$ - 1]; }
        void popFront() { return payload.popFront(); }
        void popBack() { return payload.popBack(); }
    }
    //static assert(isBidirectionalRange!BiRange);
    auto r = BiRange([1, 2, 3, 10, 11, 4]);
    //assert(equal(find(r, [3, 10]), BiRange([3, 10, 11, 4])));
    //assert(find("abc", "bc").length == 2);
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    //assert(find!"a == b"("abc", "bc").length == 2);
}

// Leftover specialization: searching a random-access range for a
// non-bidirectional forward range
R1 find(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (isRandomAccessRange!R1 && isForwardRange!R2 && !isBidirectionalRange!R2 &&
    is(typeof(binaryFun!pred(haystack.front, needle.front)) : bool))
{
    static if (!is(ElementType!R1 == ElementType!R2))
    {
        return simpleMindedFind!pred(haystack, needle);
    }
    else
    {
        // Prepare the search with needle's first element
        if (needle.empty)
            return haystack;

        haystack = .find!pred(haystack, needle.front);

        static if (hasLength!R1 && hasLength!R2 && is(typeof(takeNone(haystack)) == R1))
        {
            if (needle.length > haystack.length)
                return takeNone(haystack);
        }
        else
        {
            if (haystack.empty)
                return haystack;
        }

        needle.popFront();
        size_t matchLen = 1;

        // Loop invariant: haystack[0 .. matchLen] matches everything in
        // the initial needle that was popped out of needle.
        for (;;)
        {
            // Extend matchLength as much as possible
            for (;;)
            {
                if (needle.empty || haystack.empty)
                    return haystack;

                static if (hasLength!R1 && is(typeof(takeNone(haystack)) == R1))
                {
                    if (matchLen == haystack.length)
                        return takeNone(haystack);
                }

                if (!binaryFun!pred(haystack[matchLen], needle.front))
                    break;

                ++matchLen;
                needle.popFront();
            }

            auto bestMatch = haystack[0 .. matchLen];
            haystack.popFront();
            haystack = .find!pred(haystack, bestMatch);
        }
    }
}

@safe unittest
{
    import std.container : SList;

    assert(find([ 1, 2, 3 ], SList!int(2, 3)[]) == [ 2, 3 ]);
    assert(find([ 1, 2, 1, 2, 3, 3 ], SList!int(2, 3)[]) == [ 2, 3, 3 ]);
}

//Bug# 8334
@safe unittest
{
    import std.range;

    auto haystack = [1, 2, 3, 4, 1, 9, 12, 42];
    auto needle = [12, 42, 27];

    //different overload of find, but it's the base case.
    assert(find(haystack, needle).empty);

    assert(find(haystack, takeExactly(filter!"true"(needle), 3)).empty);
    assert(find(haystack, filter!"true"(needle)).empty);
}

// Internally used by some find() overloads above. Can't make it
// private due to bugs in the compiler.
/*private*/ R1 simpleMindedFind(alias pred, R1, R2)(R1 haystack, R2 needle)
{
    enum estimateNeedleLength = hasLength!R1 && !hasLength!R2;

    static if (hasLength!R1)
    {
        static if (!hasLength!R2)
            size_t estimatedNeedleLength = 0;
        else
            immutable size_t estimatedNeedleLength = needle.length;
    }

    bool haystackTooShort()
    {
        static if (estimateNeedleLength)
        {
            return haystack.length < estimatedNeedleLength;
        }
        else
        {
            return haystack.empty;
        }
    }

  searching:
    for (;; haystack.popFront())
    {
        if (haystackTooShort())
        {
            // Failed search
            static if (hasLength!R1)
            {
                static if (is(typeof(haystack[haystack.length ..
                                                haystack.length]) : R1))
                    return haystack[haystack.length .. haystack.length];
                else
                    return R1.init;
            }
            else
            {
                assert(haystack.empty);
                return haystack;
            }
        }
        static if (estimateNeedleLength)
            size_t matchLength = 0;
        for (auto h = haystack.save, n = needle.save;
             !n.empty;
             h.popFront(), n.popFront())
        {
            if (h.empty || !binaryFun!pred(h.front, n.front))
            {
                // Failed searching n in h
                static if (estimateNeedleLength)
                {
                    if (estimatedNeedleLength < matchLength)
                        estimatedNeedleLength = matchLength;
                }
                continue searching;
            }
            static if (estimateNeedleLength)
                ++matchLength;
        }
        break;
    }
    return haystack;
}

@safe unittest
{
    // Test simpleMindedFind for the case where both haystack and needle have
    // length.
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    struct CustomString
    {
    @safe:
        string _impl;

        // This is what triggers issue 7992.
        @property size_t length() const { return _impl.length; }
        @property void length(size_t len) { _impl.length = len; }

        // This is for conformance to the forward range API (we deliberately
        // make it non-random access so that we will end up in
        // simpleMindedFind).
        @property bool empty() const { return _impl.empty; }
        @property dchar front() const { return _impl.front; }
        void popFront() { _impl.popFront(); }
        @property CustomString save() { return this; }
    }

    // If issue 7992 occurs, this will throw an exception from calling
    // popFront() on an empty range.
    auto r = find(CustomString("a"), CustomString("b"));
}

/**
Finds two or more $(D needles) into a $(D haystack). The predicate $(D
pred) is used throughout to compare elements. By default, elements are
compared for equality.

Params:

pred = The predicate to use for comparing elements.

haystack = The target of the search. Must be an input range.
If any of $(D needles) is a range with elements comparable to
elements in $(D haystack), then $(D haystack) must be a forward range
such that the search can backtrack.

needles = One or more items to search for. Each of $(D needles) must
be either comparable to one element in $(D haystack), or be itself a
forward range with elements comparable with elements in
$(D haystack).

Returns:

A tuple containing $(D haystack) positioned to match one of the
needles and also the 1-based index of the matching element in $(D
needles) (0 if none of $(D needles) matched, 1 if $(D needles[0])
matched, 2 if $(D needles[1]) matched...). The first needle to be found
will be the one that matches. If multiple needles are found at the
same spot in the range, then the shortest one is the one which matches
(if multiple needles of the same length are found at the same spot (e.g
$(D "a") and $(D 'a')), then the left-most of them in the argument list
matches).

The relationship between $(D haystack) and $(D needles) simply means
that one can e.g. search for individual $(D int)s or arrays of $(D
int)s in an array of $(D int)s. In addition, if elements are
individually comparable, searches of heterogeneous types are allowed
as well: a $(D double[]) can be searched for an $(D int) or a $(D
short[]), and conversely a $(D long) can be searched for a $(D float)
or a $(D double[]). This makes for efficient searches without the need
to coerce one side of the comparison into the other's side type.

The complexity of the search is $(BIGOH haystack.length *
max(needles.length)). (For needles that are individual items, length
is considered to be 1.) The strategy used in searching several
subranges at once maximizes cache usage by moving in $(D haystack) as
few times as possible.
 */
Tuple!(Range, size_t) find(alias pred = "a == b", Range, Ranges...)
(Range haystack, Ranges needles)
if (Ranges.length > 1 && is(typeof(startsWith!pred(haystack, needles))))
{
    for (;; haystack.popFront())
    {
        size_t r = startsWith!pred(haystack, needles);
        if (r || haystack.empty)
        {
            return tuple(haystack, r);
        }
    }
}

///
@safe unittest
{
    int[] a = [ 1, 4, 2, 3 ];
    assert(find(a, 4) == [ 4, 2, 3 ]);
    assert(find(a, [ 1, 4 ]) == [ 1, 4, 2, 3 ]);
    assert(find(a, [ 1, 3 ], 4) == tuple([ 4, 2, 3 ], 2));
    // Mixed types allowed if comparable
    assert(find(a, 5, [ 1.2, 3.5 ], 2.0) == tuple([ 2, 3 ], 3));
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto s1 = "Mary has a little lamb";
    //writeln(find(s1, "has a", "has an"));
    assert(find(s1, "has a", "has an") == tuple("has a little lamb", 1));
    assert(find(s1, 't', "has a", "has an") == tuple("has a little lamb", 2));
    assert(find(s1, 't', "has a", 'y', "has an") == tuple("y has a little lamb", 3));
    assert(find("abc", "bc").length == 2);
}

@safe unittest
{
    import std.uni : toUpper;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[] a = [ 1, 2, 3 ];
    assert(find(a, 5).empty);
    assert(find(a, 2) == [2, 3]);

    foreach (T; TypeTuple!(int, double))
    {
        auto b = rndstuff!(T)();
        if (!b.length) continue;
        b[$ / 2] = 200;
        b[$ / 4] = 200;
        assert(find(b, 200).length == b.length - b.length / 4);
    }

    // Case-insensitive find of a string
    string[] s = [ "Hello", "world", "!" ];
    //writeln(find!("toUpper(a) == toUpper(b)")(s, "hello"));
    assert(find!("toUpper(a) == toUpper(b)")(s, "hello").length == 3);

    static bool f(string a, string b) { return toUpper(a) == toUpper(b); }
    assert(find!(f)(s, "hello").length == 3);
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[] a = [ 1, 2, 3, 2, 6 ];
    assert(find(std.range.retro(a), 5).empty);
    assert(equal(find(std.range.retro(a), 2), [ 2, 3, 2, 1 ][]));

    foreach (T; TypeTuple!(int, double))
    {
        auto b = rndstuff!(T)();
        if (!b.length) continue;
        b[$ / 2] = 200;
        b[$ / 4] = 200;
        assert(find(std.range.retro(b), 200).length ==
                b.length - (b.length - 1) / 2);
    }
}

@safe unittest
{
    import std.internal.test.dummyrange;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(find(a, b) == [ 1, 2, 3, 4, 5 ]);
    assert(find(b, a).empty);

    foreach (DummyType; AllDummyRanges) {
        DummyType d;
        auto findRes = find(d, 5);
        assert(equal(findRes, [5,6,7,8,9,10]));
    }
}

/**
 * Sets up Boyer-Moore matching for use with $(D find) below.
 * By default, elements are compared for equality.
 *
 * $(D BoyerMooreFinder) allocates GC memory.
 *
 * Params:
 * pred = Predicate used to compare elements.
 * needle = A random-access range with length and slicing.
 *
 * Returns:
 * An instance of $(D BoyerMooreFinder) that can be used with $(D find()) to
 * invoke the Boyer-Moore matching algorithm for finding of $(D needle) in a
 * given haystack.
 */
BoyerMooreFinder!(binaryFun!(pred), Range) boyerMooreFinder
(alias pred = "a == b", Range)
(Range needle) if (isRandomAccessRange!(Range) || isSomeString!Range)
{
    return typeof(return)(needle);
}

/// Ditto
struct BoyerMooreFinder(alias pred, Range)
{
private:
    size_t[] skip;                              // GC allocated
    ptrdiff_t[ElementType!(Range)] occ;         // GC allocated
    Range needle;

    ptrdiff_t occurrence(ElementType!(Range) c)
    {
        auto p = c in occ;
        return p ? *p : -1;
    }

/*
This helper function checks whether the last "portion" bytes of
"needle" (which is "nlen" bytes long) exist within the "needle" at
offset "offset" (counted from the end of the string), and whether the
character preceding "offset" is not a match.  Notice that the range
being checked may reach beyond the beginning of the string. Such range
is ignored.
 */
    static bool needlematch(R)(R needle,
                              size_t portion, size_t offset)
    {
        ptrdiff_t virtual_begin = needle.length - offset - portion;
        ptrdiff_t ignore = 0;
        if (virtual_begin < 0) {
            ignore = -virtual_begin;
            virtual_begin = 0;
        }
        if (virtual_begin > 0
            && needle[virtual_begin - 1] == needle[$ - portion - 1])
            return 0;

        immutable delta = portion - ignore;
        return equal(needle[needle.length - delta .. needle.length],
                needle[virtual_begin .. virtual_begin + delta]);
    }

public:
    this(Range needle)
    {
        if (!needle.length) return;
        this.needle = needle;
        /* Populate table with the analysis of the needle */
        /* But ignoring the last letter */
        foreach (i, n ; needle[0 .. $ - 1])
        {
            this.occ[n] = i;
        }
        /* Preprocess #2: init skip[] */
        /* Note: This step could be made a lot faster.
         * A simple implementation is shown here. */
        this.skip = new size_t[needle.length];
        foreach (a; 0 .. needle.length)
        {
            size_t value = 0;
            while (value < needle.length
                   && !needlematch(needle, a, value))
            {
                ++value;
            }
            this.skip[needle.length - a - 1] = value;
        }
    }

    Range beFound(Range haystack)
    {
        if (!needle.length) return haystack;
        if (needle.length > haystack.length) return haystack[$ .. $];
        /* Search: */
        auto limit = haystack.length - needle.length;
        for (size_t hpos = 0; hpos <= limit; )
        {
            size_t npos = needle.length - 1;
            while (pred(needle[npos], haystack[npos+hpos]))
            {
                if (npos == 0) return haystack[hpos .. $];
                --npos;
            }
            hpos += max(skip[npos], cast(sizediff_t) npos - occurrence(haystack[npos+hpos]));
        }
        return haystack[$ .. $];
    }

    @property size_t length()
    {
        return needle.length;
    }

    alias opDollar = length;
}

/**
 * Finds $(D needle) in $(D haystack) efficiently using the
 * $(LUCKY Boyer-Moore) method.
 *
 * Params:
 * haystack = A random-access range with length and slicing.
 * needle = A $(LREF BoyerMooreFinder).
 *
 * Returns:
 * $(D haystack) advanced such that $(D needle) is a prefix of it (if no
 * such position exists, returns $(D haystack) advanced to termination).
 */
Range1 find(Range1, alias pred, Range2)(
    Range1 haystack, BoyerMooreFinder!(pred, Range2) needle)
{
    return needle.beFound(haystack);
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    string h = "/homes/aalexand/d/dmd/bin/../lib/libphobos.a(dmain2.o)"~
        "(.gnu.linkonce.tmain+0x74): In function `main' undefined reference"~
        " to `_Dmain':";
    string[] ns = ["libphobos", "function", " undefined", "`", ":"];
    foreach (n ; ns) {
        auto p = find(h, boyerMooreFinder(n));
        assert(!p.empty);
    }
}

///
@safe unittest
{
    int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];

    assert(find(a, boyerMooreFinder(b)) == [ 1, 2, 3, 4, 5 ]);
    assert(find(b, boyerMooreFinder(a)).empty);
}

@safe unittest
{
    auto bm = boyerMooreFinder("for");
    auto match = find("Moor", bm);
    assert(match.empty);
}

// findSkip
/**
 * Finds $(D needle) in $(D haystack) and positions $(D haystack)
 * right after the first occurrence of $(D needle).
 *
 * Params:
 *  haystack = The $(XREF2 range, isForwardRange, forward range) to search in.
 *  needle = The $(XREF2 range, isForwardRange, forward range) to search for.
 *
 * Returns: $(D true) if the needle was found, in which case $(D haystack) is
 * positioned after the end of the first occurrence of $(D needle); otherwise
 * $(D false), leaving $(D haystack) untouched.
 */
bool findSkip(alias pred = "a == b", R1, R2)(ref R1 haystack, R2 needle)
if (isForwardRange!R1 && isForwardRange!R2
        && is(typeof(binaryFun!pred(haystack.front, needle.front))))
{
    auto parts = findSplit!pred(haystack, needle);
    if (parts[1].empty) return false;
    // found
    haystack = parts[2];
    return true;
}

///
@safe unittest
{
    // Needle is found; s is replaced by the substring following the first
    // occurrence of the needle.
    string s = "abcdef";
    assert(findSkip(s, "cd") && s == "ef");

    // Needle is not found; s is left untouched.
    s = "abcdef";
    assert(!findSkip(s, "cxd") && s == "abcdef");

    // If the needle occurs at the end of the range, the range is left empty.
    s = "abcdef";
    assert(findSkip(s, "def") && s.empty);
}

/**
These functions find the first occurrence of $(D needle) in $(D
haystack) and then split $(D haystack) as follows.

$(D findSplit) returns a tuple $(D result) containing $(I three)
ranges. $(D result[0]) is the portion of $(D haystack) before $(D
needle), $(D result[1]) is the portion of $(D haystack) that matches
$(D needle), and $(D result[2]) is the portion of $(D haystack) after
the match. If $(D needle) was not found, $(D result[0])
comprehends $(D haystack) entirely and $(D result[1]) and $(D result[2])
are empty.

$(D findSplitBefore) returns a tuple $(D result) containing two
ranges. $(D result[0]) is the portion of $(D haystack) before $(D
needle), and $(D result[1]) is the balance of $(D haystack) starting
with the match. If $(D needle) was not found, $(D result[0])
comprehends $(D haystack) entirely and $(D result[1]) is empty.

$(D findSplitAfter) returns a tuple $(D result) containing two ranges.
$(D result[0]) is the portion of $(D haystack) up to and including the
match, and $(D result[1]) is the balance of $(D haystack) starting
after the match. If $(D needle) was not found, $(D result[0]) is empty
and $(D result[1]) is $(D haystack).

In all cases, the concatenation of the returned ranges spans the
entire $(D haystack).

If $(D haystack) is a random-access range, all three components of the
tuple have the same type as $(D haystack). Otherwise, $(D haystack)
must be a forward range and the type of $(D result[0]) and $(D
result[1]) is the same as $(XREF range,takeExactly).
 */
auto findSplit(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (isForwardRange!R1 && isForwardRange!R2)
{
    static if (isSomeString!R1 && isSomeString!R2
            || isRandomAccessRange!R1 && hasLength!R2)
    {
        auto balance = find!pred(haystack, needle);
        immutable pos1 = haystack.length - balance.length;
        immutable pos2 = balance.empty ? pos1 : pos1 + needle.length;
        return tuple(haystack[0 .. pos1],
                haystack[pos1 .. pos2],
                haystack[pos2 .. haystack.length]);
    }
    else
    {
        import std.range : takeExactly;
        auto original = haystack.save;
        auto h = haystack.save;
        auto n = needle.save;
        size_t pos1, pos2;
        while (!n.empty && !h.empty)
        {
            if (binaryFun!pred(h.front, n.front))
            {
                h.popFront();
                n.popFront();
                ++pos2;
            }
            else
            {
                haystack.popFront();
                n = needle.save;
                h = haystack.save;
                pos2 = ++pos1;
            }
        }
        return tuple(takeExactly(original, pos1),
                takeExactly(haystack, pos2 - pos1),
                h);
    }
}

/// Ditto
auto findSplitBefore(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (isForwardRange!R1 && isForwardRange!R2)
{
    static if (isSomeString!R1 && isSomeString!R2
            || isRandomAccessRange!R1 && hasLength!R2)
    {
        auto balance = find!pred(haystack, needle);
        immutable pos = haystack.length - balance.length;
        return tuple(haystack[0 .. pos], haystack[pos .. haystack.length]);
    }
    else
    {
        import std.range : takeExactly;
        auto original = haystack.save;
        auto h = haystack.save;
        auto n = needle.save;
        size_t pos;
        while (!n.empty && !h.empty)
        {
            if (binaryFun!pred(h.front, n.front))
            {
                h.popFront();
                n.popFront();
            }
            else
            {
                haystack.popFront();
                n = needle.save;
                h = haystack.save;
                ++pos;
            }
        }
        return tuple(takeExactly(original, pos), haystack);
    }
}

/// Ditto
auto findSplitAfter(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (isForwardRange!R1 && isForwardRange!R2)
{
    static if (isSomeString!R1 && isSomeString!R2
            || isRandomAccessRange!R1 && hasLength!R2)
    {
        auto balance = find!pred(haystack, needle);
        immutable pos = balance.empty ? 0 : haystack.length - balance.length + needle.length;
        return tuple(haystack[0 .. pos], haystack[pos .. haystack.length]);
    }
    else
    {
        import std.range : takeExactly;
        auto original = haystack.save;
        auto h = haystack.save;
        auto n = needle.save;
        size_t pos1, pos2;
        while (!n.empty)
        {
            if (h.empty)
            {
                // Failed search
                return tuple(takeExactly(original, 0), original);
            }
            if (binaryFun!pred(h.front, n.front))
            {
                h.popFront();
                n.popFront();
                ++pos2;
            }
            else
            {
                haystack.popFront();
                n = needle.save;
                h = haystack.save;
                pos2 = ++pos1;
            }
        }
        return tuple(takeExactly(original, pos2), h);
    }
}

///
@safe unittest
{
    auto a = "Carl Sagan Memorial Station";
    auto r = findSplit(a, "Velikovsky");
    assert(r[0] == a);
    assert(r[1].empty);
    assert(r[2].empty);
    r = findSplit(a, " ");
    assert(r[0] == "Carl");
    assert(r[1] == " ");
    assert(r[2] == "Sagan Memorial Station");
    auto r1 = findSplitBefore(a, "Sagan");
    assert(r1[0] == "Carl ", r1[0]);
    assert(r1[1] == "Sagan Memorial Station");
    auto r2 = findSplitAfter(a, "Sagan");
    assert(r2[0] == "Carl Sagan");
    assert(r2[1] == " Memorial Station");
}

@safe unittest
{
    auto a = [ 1, 2, 3, 4, 5, 6, 7, 8 ];
    auto r = findSplit(a, [9, 1]);
    assert(r[0] == a);
    assert(r[1].empty);
    assert(r[2].empty);
    r = findSplit(a, [3]);
    assert(r[0] == a[0 .. 2]);
    assert(r[1] == a[2 .. 3]);
    assert(r[2] == a[3 .. $]);

    auto r1 = findSplitBefore(a, [9, 1]);
    assert(r1[0] == a);
    assert(r1[1].empty);
    r1 = findSplitBefore(a, [3, 4]);
    assert(r1[0] == a[0 .. 2]);
    assert(r1[1] == a[2 .. $]);

    r1 = findSplitAfter(a, [9, 1]);
    assert(r1[0].empty);
    assert(r1[1] == a);
    r1 = findSplitAfter(a, [3, 4]);
    assert(r1[0] == a[0 .. 4]);
    assert(r1[1] == a[4 .. $]);
}

@safe unittest
{
    auto a = [ 1, 2, 3, 4, 5, 6, 7, 8 ];
    auto fwd = filter!"a > 0"(a);
    auto r = findSplit(fwd, [9, 1]);
    assert(equal(r[0], a));
    assert(r[1].empty);
    assert(r[2].empty);
    r = findSplit(fwd, [3]);
    assert(equal(r[0],  a[0 .. 2]));
    assert(equal(r[1], a[2 .. 3]));
    assert(equal(r[2], a[3 .. $]));

    auto r1 = findSplitBefore(fwd, [9, 1]);
    assert(equal(r1[0], a));
    assert(r1[1].empty);
    r1 = findSplitBefore(fwd, [3, 4]);
    assert(equal(r1[0], a[0 .. 2]));
    assert(equal(r1[1], a[2 .. $]));

    r1 = findSplitAfter(fwd, [9, 1]);
    assert(r1[0].empty);
    assert(equal(r1[1], a));
    r1 = findSplitAfter(fwd, [3, 4]);
    assert(equal(r1[0], a[0 .. 4]));
    assert(equal(r1[1], a[4 .. $]));
}

/++
    Counts elements in the given $(XREF2 range, isForwardRange, forward range)
    until the given predicate is true for one of the given $(D needles).

    Params:
        pred = The predicate for determining when to stop counting.
        haystack = The $(XREF2 range, isInputRange, input range) to be counted.
        needles = Either a single element, or a $(XREF2 range, isForwardRange,
            forward range) of elements, to be evaluated in turn against each
            element in $(D haystack) under the given predicate.

    Returns: The number of elements which must be popped from the front of
    $(D haystack) before reaching an element for which
    $(D startsWith!pred(haystack, needles)) is $(D true). If
    $(D startsWith!pred(haystack, needles)) is not $(D true) for any element in
    $(D haystack), then $(D -1) is returned.
  +/
ptrdiff_t countUntil(alias pred = "a == b", R, Rs...)(R haystack, Rs needles)
    if (isForwardRange!R
        && Rs.length > 0
        && isForwardRange!(Rs[0]) == isInputRange!(Rs[0])
        && is(typeof(startsWith!pred(haystack, needles[0])))
        && (Rs.length == 1
            || is(typeof(countUntil!pred(haystack, needles[1 .. $])))))
{
    typeof(return) result;

    static if (needles.length == 1)
    {
        static if (hasLength!R) //Note: Narrow strings don't have length.
        {
            //We delegate to find because find is very efficient.
            //We store the length of the haystack so we don't have to save it.
            auto len = haystack.length;
            auto r2 = find!pred(haystack, needles[0]);
            if (!r2.empty)
              return cast(typeof(return)) (len - r2.length);
        }
        else
        {
            import std.range : dropOne;

            if (needles[0].empty)
              return 0;

            //Default case, slower route doing startsWith iteration
            for ( ; !haystack.empty ; ++result )
            {
                //We compare the first elements of the ranges here before
                //forwarding to startsWith. This avoids making useless saves to
                //haystack/needle if they aren't even going to be mutated anyways.
                //It also cuts down on the amount of pops on haystack.
                if (binaryFun!pred(haystack.front, needles[0].front))
                {
                    //Here, we need to save the needle before popping it.
                    //haystack we pop in all paths, so we do that, and then save.
                    haystack.popFront();
                    if (startsWith!pred(haystack.save, needles[0].save.dropOne()))
                      return result;
                }
                else
                  haystack.popFront();
            }
        }
    }
    else
    {
        foreach (i, Ri; Rs)
        {
            static if (isForwardRange!Ri)
            {
                if (needles[i].empty)
                  return 0;
            }
        }
        Tuple!Rs t;
        foreach (i, Ri; Rs)
        {
            static if (!isForwardRange!Ri)
            {
                t[i] = needles[i];
            }
        }
        for (; !haystack.empty ; ++result, haystack.popFront())
        {
            foreach (i, Ri; Rs)
            {
                static if (isForwardRange!Ri)
                {
                    t[i] = needles[i].save;
                }
            }
            if (startsWith!pred(haystack.save, t.expand))
            {
                return result;
            }
        }
    }

    //Because of @@@8804@@@: Avoids both "unreachable code" or "no return statement"
    static if (isInfinite!R) assert(0);
    else return -1;
}

/// ditto
ptrdiff_t countUntil(alias pred = "a == b", R, N)(R haystack, N needle)
    if (isInputRange!R &&
        is(typeof(binaryFun!pred(haystack.front, needle)) : bool))
{
    bool pred2(ElementType!R a) { return binaryFun!pred(a, needle); }
    return countUntil!pred2(haystack);
}

///
@safe unittest
{
    assert(countUntil("hello world", "world") == 6);
    assert(countUntil("hello world", 'r') == 8);
    assert(countUntil("hello world", "programming") == -1);
    assert(countUntil("日本語", "本語") == 1);
    assert(countUntil("日本語", '語')   == 2);
    assert(countUntil("日本語", "五") == -1);
    assert(countUntil("日本語", '五') == -1);
    assert(countUntil([0, 7, 12, 22, 9], [12, 22]) == 2);
    assert(countUntil([0, 7, 12, 22, 9], 9) == 4);
    assert(countUntil!"a > b"([0, 7, 12, 22, 9], 20) == 3);
}

@safe unittest
{
    import std.internal.test.dummyrange;

    assert(countUntil("日本語", "") == 0);
    assert(countUntil("日本語"d, "") == 0);

    assert(countUntil("", "") == 0);
    assert(countUntil("".filter!"true"(), "") == 0);

    auto rf = [0, 20, 12, 22, 9].filter!"true"();
    assert(rf.countUntil!"a > b"((int[]).init) == 0);
    assert(rf.countUntil!"a > b"(20) == 3);
    assert(rf.countUntil!"a > b"([20, 8]) == 3);
    assert(rf.countUntil!"a > b"([20, 10]) == -1);
    assert(rf.countUntil!"a > b"([20, 8, 0]) == -1);

    auto r = new ReferenceForwardRange!int([0, 1, 2, 3, 4, 5, 6]);
    auto r2 = new ReferenceForwardRange!int([3, 4]);
    auto r3 = new ReferenceForwardRange!int([3, 5]);
    assert(r.save.countUntil(3)  == 3);
    assert(r.save.countUntil(r2) == 3);
    assert(r.save.countUntil(7)  == -1);
    assert(r.save.countUntil(r3) == -1);
}

@safe unittest
{
    assert(countUntil("hello world", "world", "asd") == 6);
    assert(countUntil("hello world", "world", "ello") == 1);
    assert(countUntil("hello world", "world", "") == 0);
    assert(countUntil("hello world", "world", 'l') == 2);
}

/++
    Similar to the previous overload of $(D countUntil), except that this one
    evaluates only the predicate $(D pred).

    Params:
        pred = Predicate to when to stop counting.
        haystack = An $(XREF2 range, isInputRange, input range) of elements
          to be counted.
    Returns: The number of elements which must be popped from $(D haystack)
    before $(D pred(haystack.front)) is $(D true).
  +/
ptrdiff_t countUntil(alias pred, R)(R haystack)
    if (isInputRange!R &&
        is(typeof(unaryFun!pred(haystack.front)) : bool))
{
    typeof(return) i;
    static if (isRandomAccessRange!R)
    {
        //Optimized RA implementation. Since we want to count *and* iterate at
        //the same time, it is more efficient this way.
        static if (hasLength!R)
        {
            immutable len = cast(typeof(return)) haystack.length;
            for ( ; i < len ; ++i )
                if (unaryFun!pred(haystack[i])) return i;
        }
        else //if (isInfinite!R)
        {
            for ( ;  ; ++i )
                if (unaryFun!pred(haystack[i])) return i;
        }
    }
    else static if (hasLength!R)
    {
        //For those odd ranges that have a length, but aren't RA.
        //It is faster to quick find, and then compare the lengths
        auto r2 = find!pred(haystack.save);
        if (!r2.empty) return cast(typeof(return)) (haystack.length - r2.length);
    }
    else //Everything else
    {
        alias T = ElementType!R; //For narrow strings forces dchar iteration
        foreach (T elem; haystack)
        {
            if (unaryFun!pred(elem)) return i;
            ++i;
        }
    }

    //Because of @@@8804@@@: Avoids both "unreachable code" or "no return statement"
    static if (isInfinite!R) assert(0);
    else return -1;
}

///
@safe unittest
{
    import std.ascii : isDigit;
    import std.uni : isWhite;

    assert(countUntil!(std.uni.isWhite)("hello world") == 5);
    assert(countUntil!(std.ascii.isDigit)("hello world") == -1);
    assert(countUntil!"a > 20"([0, 7, 12, 22, 9]) == 3);
}

@safe unittest
{
    import std.internal.test.dummyrange;

    // References
    {
        // input
        ReferenceInputRange!int r;
        r = new ReferenceInputRange!int([0, 1, 2, 3, 4, 5, 6]);
        assert(r.countUntil(3) == 3);
        r = new ReferenceInputRange!int([0, 1, 2, 3, 4, 5, 6]);
        assert(r.countUntil(7) == -1);
    }
    {
        // forward
        auto r = new ReferenceForwardRange!int([0, 1, 2, 3, 4, 5, 6]);
        assert(r.save.countUntil([3, 4]) == 3);
        assert(r.save.countUntil(3) == 3);
        assert(r.save.countUntil([3, 7]) == -1);
        assert(r.save.countUntil(7) == -1);
    }
    {
        // infinite forward
        auto r = new ReferenceInfiniteForwardRange!int(0);
        assert(r.save.countUntil([3, 4]) == 3);
        assert(r.save.countUntil(3) == 3);
    }
}

/**
Interval option specifier for $(D until) (below) and others.
 */
enum OpenRight
{
    no, /// Interval is closed to the right (last element included)
    yes /// Interval is open to the right (last element is not included)
}

struct Until(alias pred, Range, Sentinel) if (isInputRange!Range)
{
    private Range _input;
    static if (!is(Sentinel == void))
        private Sentinel _sentinel;
    // mixin(bitfields!(
    //             OpenRight, "_openRight", 1,
    //             bool,  "_done", 1,
    //             uint, "", 6));
    //             OpenRight, "_openRight", 1,
    //             bool,  "_done", 1,
    OpenRight _openRight;
    bool _done;

    static if (!is(Sentinel == void))
        this(Range input, Sentinel sentinel,
                OpenRight openRight = OpenRight.yes)
        {
            _input = input;
            _sentinel = sentinel;
            _openRight = openRight;
            _done = _input.empty || openRight && predSatisfied();
        }
    else
        this(Range input, OpenRight openRight = OpenRight.yes)
        {
            _input = input;
            _openRight = openRight;
            _done = _input.empty || openRight && predSatisfied();
        }

    @property bool empty()
    {
        return _done;
    }

    @property auto ref front()
    {
        assert(!empty);
        return _input.front;
    }

    private bool predSatisfied()
    {
        static if (is(Sentinel == void))
            return cast(bool) unaryFun!pred(_input.front);
        else
            return cast(bool) startsWith!pred(_input, _sentinel);
    }

    void popFront()
    {
        assert(!empty);
        if (!_openRight)
        {
            _done = predSatisfied();
            _input.popFront();
            _done = _done || _input.empty;
        }
        else
        {
            _input.popFront();
            _done = _input.empty || predSatisfied();
        }
    }

    static if (isForwardRange!Range)
    {
        static if (!is(Sentinel == void))
            @property Until save()
            {
                Until result = this;
                result._input     = _input.save;
                result._sentinel  = _sentinel;
                result._openRight = _openRight;
                result._done      = _done;
                return result;
            }
        else
            @property Until save()
            {
                Until result = this;
                result._input     = _input.save;
                result._openRight = _openRight;
                result._done      = _done;
                return result;
            }
    }
}

/**
Lazily iterates $(D range) _until the element $(D e) for which
$(D pred(e, sentinel)) is true.

Params:
    pred = Predicate to determine when to stop.
    range = The $(XREF2 range, isInputRange, input range) to iterate over.
    sentinel = The element to stop at.
    openRight = Determines whether the element for which the given predicate is
        true should be included in the resulting range ($(D OpenRight.no)), or
        not ($(D OpenRight.yes)).

Returns:
    An $(XREF2 range, isInputRange, input range) that iterates over the
    original range's elements, but ends when the specified predicate becomes
    true. If the original range is a $(XREF2 range, isForwardRange, forward
    range) or higher, this range will be a forward range.
 */
Until!(pred, Range, Sentinel)
until(alias pred = "a == b", Range, Sentinel)
(Range range, Sentinel sentinel, OpenRight openRight = OpenRight.yes)
if (!is(Sentinel == OpenRight))
{
    return typeof(return)(range, sentinel, openRight);
}

/// Ditto
Until!(pred, Range, void)
until(alias pred, Range)
(Range range, OpenRight openRight = OpenRight.yes)
{
    return typeof(return)(range, openRight);
}

///
@safe unittest
{
    int[] a = [ 1, 2, 4, 7, 7, 2, 4, 7, 3, 5];
    assert(equal(a.until(7), [1, 2, 4][]));
    assert(equal(a.until(7, OpenRight.no), [1, 2, 4, 7][]));
}

@safe unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 7, 7, 2, 4, 7, 3, 5];

    static assert(isForwardRange!(typeof(a.until(7))));
    static assert(isForwardRange!(typeof(until!"a == 2"(a, OpenRight.no))));

    assert(equal(a.until(7), [1, 2, 4][]));
    assert(equal(a.until([7, 2]), [1, 2, 4, 7][]));
    assert(equal(a.until(7, OpenRight.no), [1, 2, 4, 7][]));
    assert(equal(until!"a == 2"(a, OpenRight.no), [1, 2][]));
}

unittest // bugzilla 13171
{
    import std.range;
    auto a = [1, 2, 3, 4];
    assert(equal(refRange(&a).until(3, OpenRight.no), [1, 2, 3]));
    assert(a == [4]);
}

@safe unittest // Issue 10460
{
    auto a = [1, 2, 3, 4];
    foreach (ref e; a.until(3))
        e = 0;
    assert(equal(a, [0, 0, 3, 4]));
}

unittest // Issue 13124
{
    auto s = "hello how\nare you";
    s.until!(c => c.among!('\n', '\r'));
}

/**
Checks whether the given $(XREF2 range, isInputRange, input range) starts with
(one of) the given needle(s).

Params:

    pred = Predicate to use in comparing the elements of the haystack and the
        needle(s).

    doesThisStart = The input range to check.

    withOneOfThese = The needles against which the range is to be checked,
        which may be individual elements or input ranges of elements.

    withThis = The single needle to check, which may be either a single element
        or an input range of elements.

Returns:

0 if the needle(s) do not occur at the beginning of the given range;
otherwise the position of the matching needle, that is, 1 if the range starts
with $(D withOneOfThese[0]), 2 if it starts with $(D withOneOfThese[1]), and so
on.

In the case where $(D doesThisStart) starts with multiple of the ranges or
elements in $(D withOneOfThese), then the shortest one matches (if there are
two which match which are of the same length (e.g. $(D "a") and $(D 'a')), then
the left-most of them in the argument
list matches).
 */
uint startsWith(alias pred = "a == b", Range, Needles...)(Range doesThisStart, Needles withOneOfThese)
if (isInputRange!Range && Needles.length > 1 &&
    is(typeof(.startsWith!pred(doesThisStart, withOneOfThese[0])) : bool ) &&
    is(typeof(.startsWith!pred(doesThisStart, withOneOfThese[1 .. $])) : uint))
{
    alias haystack = doesThisStart;
    alias needles  = withOneOfThese;

    // Make one pass looking for empty ranges in needles
    foreach (i, Unused; Needles)
    {
        // Empty range matches everything
        static if (!is(typeof(binaryFun!pred(haystack.front, needles[i])) : bool))
        {
            if (needles[i].empty) return i + 1;
        }
    }

    for (; !haystack.empty; haystack.popFront())
    {
        foreach (i, Unused; Needles)
        {
            static if (is(typeof(binaryFun!pred(haystack.front, needles[i])) : bool))
            {
                // Single-element
                if (binaryFun!pred(haystack.front, needles[i]))
                {
                    // found, but instead of returning, we just stop searching.
                    // This is to account for one-element
                    // range matches (consider startsWith("ab", "a",
                    // 'a') should return 1, not 2).
                    break;
                }
            }
            else
            {
                if (binaryFun!pred(haystack.front, needles[i].front))
                {
                    continue;
                }
            }

            // This code executed on failure to match
            // Out with this guy, check for the others
            uint result = startsWith!pred(haystack, needles[0 .. i], needles[i + 1 .. $]);
            if (result > i) ++result;
            return result;
        }

        // If execution reaches this point, then the front matches for all
        // needle ranges, or a needle element has been matched.
        // What we need to do now is iterate, lopping off the front of
        // the range and checking if the result is empty, or finding an
        // element needle and returning.
        // If neither happens, we drop to the end and loop.
        foreach (i, Unused; Needles)
        {
            static if (is(typeof(binaryFun!pred(haystack.front, needles[i])) : bool))
            {
                // Test has passed in the previous loop
                return i + 1;
            }
            else
            {
                needles[i].popFront();
                if (needles[i].empty) return i + 1;
            }
        }
    }
    return 0;
}

/// Ditto
bool startsWith(alias pred = "a == b", R1, R2)(R1 doesThisStart, R2 withThis)
if (isInputRange!R1 &&
    isInputRange!R2 &&
    is(typeof(binaryFun!pred(doesThisStart.front, withThis.front)) : bool))
{
    alias haystack = doesThisStart;
    alias needle   = withThis;

    static if (is(typeof(pred) : string))
        enum isDefaultPred = pred == "a == b";
    else
        enum isDefaultPred = false;

    //Note: While narrow strings don't have a "true" length, for a narrow string to start with another
    //narrow string *of the same type*, it must have *at least* as many code units.
    static if ((hasLength!R1 && hasLength!R2) ||
        (isNarrowString!R1 && isNarrowString!R2 && ElementEncodingType!R1.sizeof == ElementEncodingType!R2.sizeof))
    {
        if (haystack.length < needle.length)
            return false;
    }

    static if (isDefaultPred && isArray!R1 && isArray!R2 &&
               is(Unqual!(ElementEncodingType!R1) == Unqual!(ElementEncodingType!R2)))
    {
        //Array slice comparison mode
        return haystack[0 .. needle.length] == needle;
    }
    else static if (isRandomAccessRange!R1 && isRandomAccessRange!R2 && hasLength!R2)
    {
        //RA dual indexing mode
        foreach (j; 0 .. needle.length)
        {
            if (!binaryFun!pred(haystack[j], needle[j]))
                // not found
                return false;
        }
        // found!
        return true;
    }
    else
    {
        //Standard input range mode
        if (needle.empty) return true;
        static if (hasLength!R1 && hasLength!R2)
        {
            //We have previously checked that haystack.length > needle.length,
            //So no need to check haystack.empty during iteration
            for ( ; ; haystack.popFront() )
            {
                if (!binaryFun!pred(haystack.front, needle.front)) break;
                needle.popFront();
                if (needle.empty) return true;
            }
        }
        else
        {
            for ( ; !haystack.empty ; haystack.popFront() )
            {
                if (!binaryFun!pred(haystack.front, needle.front)) break;
                needle.popFront();
                if (needle.empty) return true;
            }
        }
        return false;
    }
}

/// Ditto
bool startsWith(alias pred = "a == b", R, E)(R doesThisStart, E withThis)
if (isInputRange!R &&
    is(typeof(binaryFun!pred(doesThisStart.front, withThis)) : bool))
{
    return doesThisStart.empty
        ? false
        : binaryFun!pred(doesThisStart.front, withThis);
}

///
@safe unittest
{
    assert(startsWith("abc", ""));
    assert(startsWith("abc", "a"));
    assert(!startsWith("abc", "b"));
    assert(startsWith("abc", 'a', "b") == 1);
    assert(startsWith("abc", "b", "a") == 2);
    assert(startsWith("abc", "a", "a") == 1);
    assert(startsWith("abc", "ab", "a") == 2);
    assert(startsWith("abc", "x", "a", "b") == 2);
    assert(startsWith("abc", "x", "aa", "ab") == 3);
    assert(startsWith("abc", "x", "aaa", "sab") == 0);
    assert(startsWith("abc", "x", "aaa", "a", "sab") == 3);
    alias C = Tuple!(int, "x", int, "y");
    assert(startsWith!"a.x == b"([ C(1,1), C(1,2), C(2,2) ], [1, 1]));
    assert(startsWith!"a.x == b"([ C(1,1), C(2,1), C(2,2) ], [1, 1], [1, 2], [1, 3]) == 2);
}

@safe unittest
{
    import std.conv : to;
    import std.range;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    foreach (S; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        assert(!startsWith(to!S("abc"), 'c'));
        assert(startsWith(to!S("abc"), 'a', 'c') == 1);
        assert(!startsWith(to!S("abc"), 'x', 'n', 'b'));
        assert(startsWith(to!S("abc"), 'x', 'n', 'a') == 3);
        assert(startsWith(to!S("\uFF28abc"), 'a', '\uFF28', 'c') == 2);

        foreach (T; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
        (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
            //Lots of strings
            assert(startsWith(to!S("abc"), to!T("")));
            assert(startsWith(to!S("ab"), to!T("a")));
            assert(startsWith(to!S("abc"), to!T("a")));
            assert(!startsWith(to!S("abc"), to!T("b")));
            assert(!startsWith(to!S("abc"), to!T("b"), "bc", "abcd", "xyz"));
            assert(startsWith(to!S("abc"), to!T("ab"), 'a') == 2);
            assert(startsWith(to!S("abc"), to!T("a"), "b") == 1);
            assert(startsWith(to!S("abc"), to!T("b"), "a") == 2);
            assert(startsWith(to!S("abc"), to!T("a"), 'a') == 1);
            assert(startsWith(to!S("abc"), 'a', to!T("a")) == 1);
            assert(startsWith(to!S("abc"), to!T("x"), "a", "b") == 2);
            assert(startsWith(to!S("abc"), to!T("x"), "aa", "ab") == 3);
            assert(startsWith(to!S("abc"), to!T("x"), "aaa", "sab") == 0);
            assert(startsWith(to!S("abc"), 'a'));
            assert(!startsWith(to!S("abc"), to!T("sab")));
            assert(startsWith(to!S("abc"), 'x', to!T("aaa"), 'a', "sab") == 3);

            //Unicode
            assert(startsWith(to!S("\uFF28el\uFF4co"), to!T("\uFF28el")));
            assert(startsWith(to!S("\uFF28el\uFF4co"), to!T("Hel"), to!T("\uFF28el")) == 2);
            assert(startsWith(to!S("日本語"), to!T("日本")));
            assert(startsWith(to!S("日本語"), to!T("日本語")));
            assert(!startsWith(to!S("日本"), to!T("日本語")));

            //Empty
            assert(startsWith(to!S(""),  T.init));
            assert(!startsWith(to!S(""), 'a'));
            assert(startsWith(to!S("a"), T.init));
            assert(startsWith(to!S("a"), T.init, "") == 1);
            assert(startsWith(to!S("a"), T.init, 'a') == 1);
            assert(startsWith(to!S("a"), 'a', T.init) == 2);
        }();
    }

    //Length but no RA
    assert(!startsWith("abc".takeExactly(3), "abcd".takeExactly(4)));
    assert(startsWith("abc".takeExactly(3), "abcd".takeExactly(3)));
    assert(startsWith("abc".takeExactly(3), "abcd".takeExactly(1)));

    foreach (T; TypeTuple!(int, short))
    {
        immutable arr = cast(T[])[0, 1, 2, 3, 4, 5];

        //RA range
        assert(startsWith(arr, cast(int[])null));
        assert(!startsWith(arr, 5));
        assert(!startsWith(arr, 1));
        assert(startsWith(arr, 0));
        assert(startsWith(arr, 5, 0, 1) == 2);
        assert(startsWith(arr, [0]));
        assert(startsWith(arr, [0, 1]));
        assert(startsWith(arr, [0, 1], 7) == 1);
        assert(!startsWith(arr, [0, 1, 7]));
        assert(startsWith(arr, [0, 1, 7], [0, 1, 2]) == 2);

        //Normal input range
        assert(!startsWith(filter!"true"(arr), 1));
        assert(startsWith(filter!"true"(arr), 0));
        assert(startsWith(filter!"true"(arr), [0]));
        assert(startsWith(filter!"true"(arr), [0, 1]));
        assert(startsWith(filter!"true"(arr), [0, 1], 7) == 1);
        assert(!startsWith(filter!"true"(arr), [0, 1, 7]));
        assert(startsWith(filter!"true"(arr), [0, 1, 7], [0, 1, 2]) == 2);
        assert(startsWith(arr, filter!"true"([0, 1])));
        assert(startsWith(arr, filter!"true"([0, 1]), 7) == 1);
        assert(!startsWith(arr, filter!"true"([0, 1, 7])));
        assert(startsWith(arr, [0, 1, 7], filter!"true"([0, 1, 2])) == 2);

        //Non-default pred
        assert(startsWith!("a%10 == b%10")(arr, [10, 11]));
        assert(!startsWith!("a%10 == b%10")(arr, [10, 12]));
    }
}

/**
Skip over the initial portion of the first given range that matches the second
range, or do nothing if there is no match.

Params:
    pred = The predicate that determines whether elements from each respective
        range match. Defaults to equality $(D "a == b").
    r1 = The $(XREF2 range, isForwardRange, forward range) to move forward.
    r2 = The $(XREF2 range, isInputRange, input range) representing the initial
         segment of $(D r1) to skip over.

Returns:
true if the initial segment of $(D r1) matches $(D r2), and $(D r1) has been
advanced to the point past this segment; otherwise false, and $(D r1) is left
in its original position.
 */
bool skipOver(alias pred = "a == b", R1, R2)(ref R1 r1, R2 r2)
    if (is(typeof(binaryFun!pred(r1.front, r2.front))) &&
        isForwardRange!R1 &&
        isInputRange!R2)
{
    auto r = r1.save;
    while (!r2.empty && !r.empty && binaryFun!pred(r.front, r2.front))
    {
        r.popFront();
        r2.popFront();
    }
    if (r2.empty)
        r1 = r;
    return r2.empty;
}

///
@safe unittest
{
    auto s1 = "Hello world";
    assert(!skipOver(s1, "Ha"));
    assert(s1 == "Hello world");
    assert(skipOver(s1, "Hell") && s1 == "o world");

    string[]  r1 = ["abc", "def", "hij"];
    dstring[] r2 = ["abc"d];
    assert(!skipOver!((a, b) => a.equal(b))(r1, ["def"d]));
    assert(r1 == ["abc", "def", "hij"]);
    assert(skipOver!((a, b) => a.equal(b))(r1, r2));
    assert(r1 == ["def", "hij"]);
}

/**
Skip over the first element of the given range if it matches the given element,
otherwise do nothing.

Params:
    pred = The predicate that determines whether an element from the range
        matches the given element.

    r = The $(XREF range, isInputRange, input range) to skip over.

    e = The element to match.

Returns:
true if the first element matches the given element according to the given
predicate, and the range has been advanced by one element; otherwise false, and
the range is left untouched.
 */
bool skipOver(alias pred = "a == b", R, E)(ref R r, E e)
    if (is(typeof(binaryFun!pred(r.front, e))) && isInputRange!R)
{
    if (r.empty || !binaryFun!pred(r.front, e))
        return false;
    r.popFront();
    return true;
}

///
@safe unittest
{
    auto s1 = "Hello world";
    assert(!skipOver(s1, 'a'));
    assert(s1 == "Hello world");
    assert(skipOver(s1, 'H') && s1 == "ello world");

    string[] r = ["abc", "def", "hij"];
    dstring e = "abc"d;
    assert(!skipOver!((a, b) => a.equal(b))(r, "def"d));
    assert(r == ["abc", "def", "hij"]);
    assert(skipOver!((a, b) => a.equal(b))(r, e));
    assert(r == ["def", "hij"]);

    auto s2 = "";
    assert(!s2.skipOver('a'));
}

/* (Not yet documented.)
Consume all elements from $(D r) that are equal to one of the elements
$(D es).
 */
void skipAll(alias pred = "a == b", R, Es...)(ref R r, Es es)
//if (is(typeof(binaryFun!pred(r1.front, es[0]))))
{
  loop:
    for (; !r.empty; r.popFront())
    {
        foreach (i, E; Es)
        {
            if (binaryFun!pred(r.front, es[i]))
            {
                continue loop;
            }
        }
        break;
    }
}

@safe unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto s1 = "Hello world";
    skipAll(s1, 'H', 'e');
    assert(s1 == "llo world");
}

/**
Checks if the given range ends with (one of) the given needle(s).
The reciprocal of $(D startsWith).

Params:
    pred = The predicate to use for comparing elements between the range and
        the needle(s).

    doesThisEnd = The $(XREF2 range, isBidirectionalRange, bidirectional range)
        to check.

    withOneOfThese = The needles to check against, which may be single
        elements, or bidirectional ranges of elements.

    withThis = The single element to check.

Returns:
0 if the needle(s) do not occur at the end of the given range;
otherwise the position of the matching needle, that is, 1 if the range ends
with $(D withOneOfThese[0]), 2 if it ends with $(D withOneOfThese[1]), and so
on.
 */
uint endsWith(alias pred = "a == b", Range, Needles...)(Range doesThisEnd, Needles withOneOfThese)
if (isBidirectionalRange!Range && Needles.length > 1 &&
    is(typeof(.endsWith!pred(doesThisEnd, withOneOfThese[0])) : bool) &&
    is(typeof(.endsWith!pred(doesThisEnd, withOneOfThese[1 .. $])) : uint))
{
    alias haystack = doesThisEnd;
    alias needles  = withOneOfThese;

    // Make one pass looking for empty ranges in needles
    foreach (i, Unused; Needles)
    {
        // Empty range matches everything
        static if (!is(typeof(binaryFun!pred(haystack.back, needles[i])) : bool))
        {
            if (needles[i].empty) return i + 1;
        }
    }

    for (; !haystack.empty; haystack.popBack())
    {
        foreach (i, Unused; Needles)
        {
            static if (is(typeof(binaryFun!pred(haystack.back, needles[i])) : bool))
            {
                // Single-element
                if (binaryFun!pred(haystack.back, needles[i]))
                {
                    // found, but continue to account for one-element
                    // range matches (consider endsWith("ab", "b",
                    // 'b') should return 1, not 2).
                    continue;
                }
            }
            else
            {
                if (binaryFun!pred(haystack.back, needles[i].back))
                    continue;
            }

            // This code executed on failure to match
            // Out with this guy, check for the others
            uint result = endsWith!pred(haystack, needles[0 .. i], needles[i + 1 .. $]);
            if (result > i) ++result;
            return result;
        }

        // If execution reaches this point, then the back matches for all
        // needles ranges. What we need to do now is to lop off the back of
        // all ranges involved and recurse.
        foreach (i, Unused; Needles)
        {
            static if (is(typeof(binaryFun!pred(haystack.back, needles[i])) : bool))
            {
                // Test has passed in the previous loop
                return i + 1;
            }
            else
            {
                needles[i].popBack();
                if (needles[i].empty) return i + 1;
            }
        }
    }
    return 0;
}

/// Ditto
bool endsWith(alias pred = "a == b", R1, R2)(R1 doesThisEnd, R2 withThis)
if (isBidirectionalRange!R1 &&
    isBidirectionalRange!R2 &&
    is(typeof(binaryFun!pred(doesThisEnd.back, withThis.back)) : bool))
{
    alias haystack = doesThisEnd;
    alias needle   = withThis;

    static if (is(typeof(pred) : string))
        enum isDefaultPred = pred == "a == b";
    else
        enum isDefaultPred = false;

    static if (isDefaultPred && isArray!R1 && isArray!R2 &&
               is(Unqual!(ElementEncodingType!R1) == Unqual!(ElementEncodingType!R2)))
    {
        if (haystack.length < needle.length) return false;

        return haystack[$ - needle.length .. $] == needle;
    }
    else
    {
        import std.range : retro;
        return startsWith!pred(retro(doesThisEnd), retro(withThis));
    }
}

/// Ditto
bool endsWith(alias pred = "a == b", R, E)(R doesThisEnd, E withThis)
if (isBidirectionalRange!R &&
    is(typeof(binaryFun!pred(doesThisEnd.back, withThis)) : bool))
{
    return doesThisEnd.empty
        ? false
        : binaryFun!pred(doesThisEnd.back, withThis);
}

///
@safe unittest
{
    assert(endsWith("abc", ""));
    assert(!endsWith("abc", "b"));
    assert(endsWith("abc", "a", 'c') == 2);
    assert(endsWith("abc", "c", "a") == 1);
    assert(endsWith("abc", "c", "c") == 1);
    assert(endsWith("abc", "bc", "c") == 2);
    assert(endsWith("abc", "x", "c", "b") == 2);
    assert(endsWith("abc", "x", "aa", "bc") == 3);
    assert(endsWith("abc", "x", "aaa", "sab") == 0);
    assert(endsWith("abc", "x", "aaa", 'c', "sab") == 3);
}

@safe unittest
{
    import std.conv : to;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    foreach (S; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        assert(!endsWith(to!S("abc"), 'a'));
        assert(endsWith(to!S("abc"), 'a', 'c') == 2);
        assert(!endsWith(to!S("abc"), 'x', 'n', 'b'));
        assert(endsWith(to!S("abc"), 'x', 'n', 'c') == 3);
        assert(endsWith(to!S("abc\uFF28"), 'a', '\uFF28', 'c') == 2);

        foreach (T; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
        (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
            //Lots of strings
            assert(endsWith(to!S("abc"), to!T("")));
            assert(!endsWith(to!S("abc"), to!T("a")));
            assert(!endsWith(to!S("abc"), to!T("b")));
            assert(endsWith(to!S("abc"), to!T("bc"), 'c') == 2);
            assert(endsWith(to!S("abc"), to!T("a"), "c") == 2);
            assert(endsWith(to!S("abc"), to!T("c"), "a") == 1);
            assert(endsWith(to!S("abc"), to!T("c"), "c") == 1);
            assert(endsWith(to!S("abc"), to!T("x"), 'c', "b") == 2);
            assert(endsWith(to!S("abc"), 'x', to!T("aa"), "bc") == 3);
            assert(endsWith(to!S("abc"), to!T("x"), "aaa", "sab") == 0);
            assert(endsWith(to!S("abc"), to!T("x"), "aaa", "c", "sab") == 3);
            assert(endsWith(to!S("\uFF28el\uFF4co"), to!T("l\uFF4co")));
            assert(endsWith(to!S("\uFF28el\uFF4co"), to!T("lo"), to!T("l\uFF4co")) == 2);

            //Unicode
            assert(endsWith(to!S("\uFF28el\uFF4co"), to!T("l\uFF4co")));
            assert(endsWith(to!S("\uFF28el\uFF4co"), to!T("lo"), to!T("l\uFF4co")) == 2);
            assert(endsWith(to!S("日本語"), to!T("本語")));
            assert(endsWith(to!S("日本語"), to!T("日本語")));
            assert(!endsWith(to!S("本語"), to!T("日本語")));

            //Empty
            assert(endsWith(to!S(""),  T.init));
            assert(!endsWith(to!S(""), 'a'));
            assert(endsWith(to!S("a"), T.init));
            assert(endsWith(to!S("a"), T.init, "") == 1);
            assert(endsWith(to!S("a"), T.init, 'a') == 1);
            assert(endsWith(to!S("a"), 'a', T.init) == 2);
        }();
    }

    foreach (T; TypeTuple!(int, short))
    {
        immutable arr = cast(T[])[0, 1, 2, 3, 4, 5];

        //RA range
        assert(endsWith(arr, cast(int[])null));
        assert(!endsWith(arr, 0));
        assert(!endsWith(arr, 4));
        assert(endsWith(arr, 5));
        assert(endsWith(arr, 0, 4, 5) == 3);
        assert(endsWith(arr, [5]));
        assert(endsWith(arr, [4, 5]));
        assert(endsWith(arr, [4, 5], 7) == 1);
        assert(!endsWith(arr, [2, 4, 5]));
        assert(endsWith(arr, [2, 4, 5], [3, 4, 5]) == 2);

        //Normal input range
        assert(!endsWith(filterBidirectional!"true"(arr), 4));
        assert(endsWith(filterBidirectional!"true"(arr), 5));
        assert(endsWith(filterBidirectional!"true"(arr), [5]));
        assert(endsWith(filterBidirectional!"true"(arr), [4, 5]));
        assert(endsWith(filterBidirectional!"true"(arr), [4, 5], 7) == 1);
        assert(!endsWith(filterBidirectional!"true"(arr), [2, 4, 5]));
        assert(endsWith(filterBidirectional!"true"(arr), [2, 4, 5], [3, 4, 5]) == 2);
        assert(endsWith(arr, filterBidirectional!"true"([4, 5])));
        assert(endsWith(arr, filterBidirectional!"true"([4, 5]), 7) == 1);
        assert(!endsWith(arr, filterBidirectional!"true"([2, 4, 5])));
        assert(endsWith(arr, [2, 4, 5], filterBidirectional!"true"([3, 4, 5])) == 2);

        //Non-default pred
        assert(endsWith!("a%10 == b%10")(arr, [14, 15]));
        assert(!endsWith!("a%10 == b%10")(arr, [15, 14]));
    }
}

/**
Returns the common prefix of two ranges.

Params:
    pred = The predicate to use in comparing elements for commonality. Defaults
        to equality $(D "a == b").

    r1 = A $(XREF2 range, isForwardRange, forward range) of elements.

    r2 = An $(XREF2 range, isInputRange, input range) of elements.

Returns:
A slice of $(D r1) which contains the characters that both ranges start with,
if the first argument is a string; otherwise, the same as the result of
$(D takeExactly(r1, n)), where $(D n) is the number of elements in the common
prefix of both ranges.

See_Also:
    $(XREF range, takeExactly)
 */
auto commonPrefix(alias pred = "a == b", R1, R2)(R1 r1, R2 r2)
if (isForwardRange!R1 && isInputRange!R2 &&
    !isNarrowString!R1 &&
    is(typeof(binaryFun!pred(r1.front, r2.front))))
{
    static if (isRandomAccessRange!R1 && isRandomAccessRange!R2 &&
               hasLength!R1 && hasLength!R2 &&
               hasSlicing!R1)
    {
        immutable limit = min(r1.length, r2.length);
        foreach (i; 0 .. limit)
        {
            if (!binaryFun!pred(r1[i], r2[i]))
            {
                return r1[0 .. i];
            }
        }
        return r1[0 .. limit];
    }
    else
    {
        import std.range : takeExactly;
        auto result = r1.save;
        size_t i = 0;
        for (;
             !r1.empty && !r2.empty && binaryFun!pred(r1.front, r2.front);
             ++i, r1.popFront(), r2.popFront())
        {}
        return takeExactly(result, i);
    }
}

///
@safe unittest
{
    assert(commonPrefix("hello, world", "hello, there") == "hello, ");
}

/// ditto
auto commonPrefix(alias pred, R1, R2)(R1 r1, R2 r2)
if (isNarrowString!R1 && isInputRange!R2 &&
    is(typeof(binaryFun!pred(r1.front, r2.front))))
{
    import std.utf : decode;

    auto result = r1.save;
    immutable len = r1.length;
    size_t i = 0;

    for (size_t j = 0; i < len && !r2.empty; r2.popFront(), i = j)
    {
        immutable f = decode(r1, j);
        if (!binaryFun!pred(f, r2.front))
            break;
    }

    return result[0 .. i];
}

/// ditto
auto commonPrefix(R1, R2)(R1 r1, R2 r2)
if (isNarrowString!R1 && isInputRange!R2 && !isNarrowString!R2 &&
    is(typeof(r1.front == r2.front)))
{
    return commonPrefix!"a == b"(r1, r2);
}

/// ditto
auto commonPrefix(R1, R2)(R1 r1, R2 r2)
if (isNarrowString!R1 && isNarrowString!R2)
{
    static if (ElementEncodingType!R1.sizeof == ElementEncodingType!R2.sizeof)
    {
        import std.utf : stride, UTFException;

        immutable limit = min(r1.length, r2.length);
        for (size_t i = 0; i < limit;)
        {
            immutable codeLen = std.utf.stride(r1, i);
            size_t j = 0;

            for (; j < codeLen && i < limit; ++i, ++j)
            {
                if (r1[i] != r2[i])
                    return r1[0 .. i - j];
            }

            if (i == limit && j < codeLen)
                throw new UTFException("Invalid UTF-8 sequence", i);
        }
        return r1[0 .. limit];
    }
    else
        return commonPrefix!"a == b"(r1, r2);
}

@safe unittest
{
    import std.conv : to;
    import std.exception : assertThrown;
    import std.utf : UTFException;
    import std.range;

    assert(commonPrefix([1, 2, 3], [1, 2, 3, 4, 5]) == [1, 2, 3]);
    assert(commonPrefix([1, 2, 3, 4, 5], [1, 2, 3]) == [1, 2, 3]);
    assert(commonPrefix([1, 2, 3, 4], [1, 2, 3, 4]) == [1, 2, 3, 4]);
    assert(commonPrefix([1, 2, 3], [7, 2, 3, 4, 5]).empty);
    assert(commonPrefix([7, 2, 3, 4, 5], [1, 2, 3]).empty);
    assert(commonPrefix([1, 2, 3], cast(int[])null).empty);
    assert(commonPrefix(cast(int[])null, [1, 2, 3]).empty);
    assert(commonPrefix(cast(int[])null, cast(int[])null).empty);

    foreach (S; TypeTuple!(char[], const(char)[], string,
                           wchar[], const(wchar)[], wstring,
                           dchar[], const(dchar)[], dstring))
    {
        foreach(T; TypeTuple!(string, wstring, dstring))
        (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
            assert(commonPrefix(to!S(""), to!T("")).empty);
            assert(commonPrefix(to!S(""), to!T("hello")).empty);
            assert(commonPrefix(to!S("hello"), to!T("")).empty);
            assert(commonPrefix(to!S("hello, world"), to!T("hello, there")) == to!S("hello, "));
            assert(commonPrefix(to!S("hello, there"), to!T("hello, world")) == to!S("hello, "));
            assert(commonPrefix(to!S("hello, "), to!T("hello, world")) == to!S("hello, "));
            assert(commonPrefix(to!S("hello, world"), to!T("hello, ")) == to!S("hello, "));
            assert(commonPrefix(to!S("hello, world"), to!T("hello, world")) == to!S("hello, world"));

            //Bug# 8890
            assert(commonPrefix(to!S("Пиво"), to!T("Пони"))== to!S("П"));
            assert(commonPrefix(to!S("Пони"), to!T("Пиво"))== to!S("П"));
            assert(commonPrefix(to!S("Пиво"), to!T("Пиво"))== to!S("Пиво"));
            assert(commonPrefix(to!S("\U0010FFFF\U0010FFFB\U0010FFFE"),
                                to!T("\U0010FFFF\U0010FFFB\U0010FFFC")) == to!S("\U0010FFFF\U0010FFFB"));
            assert(commonPrefix(to!S("\U0010FFFF\U0010FFFB\U0010FFFC"),
                                to!T("\U0010FFFF\U0010FFFB\U0010FFFE")) == to!S("\U0010FFFF\U0010FFFB"));
            assert(commonPrefix!"a != b"(to!S("Пиво"), to!T("онво")) == to!S("Пи"));
            assert(commonPrefix!"a != b"(to!S("онво"), to!T("Пиво")) == to!S("он"));
        }();

        static assert(is(typeof(commonPrefix(to!S("Пиво"), filter!"true"("Пони"))) == S));
        assert(equal(commonPrefix(to!S("Пиво"), filter!"true"("Пони")), to!S("П")));

        static assert(is(typeof(commonPrefix(filter!"true"("Пиво"), to!S("Пони"))) ==
                      typeof(takeExactly(filter!"true"("П"), 1))));
        assert(equal(commonPrefix(filter!"true"("Пиво"), to!S("Пони")), takeExactly(filter!"true"("П"), 1)));
    }

    assertThrown!UTFException(commonPrefix("\U0010FFFF\U0010FFFB", "\U0010FFFF\U0010FFFB"[0 .. $ - 1]));

    assert(commonPrefix("12345"d, [49, 50, 51, 60, 60]) == "123"d);
    assert(commonPrefix([49, 50, 51, 60, 60], "12345" ) == [49, 50, 51]);
    assert(commonPrefix([49, 50, 51, 60, 60], "12345"d) == [49, 50, 51]);

    assert(commonPrefix!"a == ('0' + b)"("12345" , [1, 2, 3, 9, 9]) == "123");
    assert(commonPrefix!"a == ('0' + b)"("12345"d, [1, 2, 3, 9, 9]) == "123"d);
    assert(commonPrefix!"('0' + a) == b"([1, 2, 3, 9, 9], "12345" ) == [1, 2, 3]);
    assert(commonPrefix!"('0' + a) == b"([1, 2, 3, 9, 9], "12345"d) == [1, 2, 3]);
}

// findAdjacent
/**
Advances $(D r) until it finds the first two adjacent elements $(D a),
$(D b) that satisfy $(D pred(a, b)). Performs $(BIGOH r.length)
evaluations of $(D pred).

Params:
    pred = The predicate to satisfy.
    r = A $(XREF2 range, isForwardRange, forward range) to search in.

Returns:
$(D r) advanced to the first occurrence of two adjacent elements that satisfy
the given predicate. If there are no such two elements, returns $(D r) advanced
until empty.

See_Also:
     $(WEB sgi.com/tech/stl/adjacent_find.html, STL's adjacent_find)
*/
Range findAdjacent(alias pred = "a == b", Range)(Range r)
    if (isForwardRange!(Range))
{
    auto ahead = r.save;
    if (!ahead.empty)
    {
        for (ahead.popFront(); !ahead.empty; r.popFront(), ahead.popFront())
        {
            if (binaryFun!(pred)(r.front, ahead.front)) return r;
        }
    }
    static if (!isInfinite!Range)
        return ahead;
}

///
@safe unittest
{
    int[] a = [ 11, 10, 10, 9, 8, 8, 7, 8, 9 ];
    auto r = findAdjacent(a);
    assert(r == [ 10, 10, 9, 8, 8, 7, 8, 9 ]);
    auto p = findAdjacent!("a < b")(a);
    assert(p == [ 7, 8, 9 ]);

}

@safe unittest
{
    import std.internal.test.dummyrange;
    import std.range;

    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 11, 10, 10, 9, 8, 8, 7, 8, 9 ];
    auto p = findAdjacent(a);
    assert(p == [10, 10, 9, 8, 8, 7, 8, 9 ]);
    p = findAdjacent!("a < b")(a);
    assert(p == [7, 8, 9]);
    // empty
    a = [];
    p = findAdjacent(a);
    assert(p.empty);
    // not found
    a = [ 1, 2, 3, 4, 5 ];
    p = findAdjacent(a);
    assert(p.empty);
    p = findAdjacent!"a > b"(a);
    assert(p.empty);
    ReferenceForwardRange!int rfr = new ReferenceForwardRange!int([1, 2, 3, 2, 2, 3]);
    assert(equal(findAdjacent(rfr), [2, 2, 3]));

    // Issue 9350
    assert(!repeat(1).findAdjacent().empty);
}

// findAmong
/**
Searches the given range for an element that matches one of the given choices.

Advances $(D seq) by calling $(D seq.popFront) until either
$(D find!(pred)(choices, seq.front)) is $(D true), or $(D seq) becomes empty.
Performs $(BIGOH seq.length * choices.length) evaluations of $(D pred).

Params:
    pred = The predicate to use for determining a match.
    seq = The $(XREF2 range, isInputRange, input range) to search.
    choices = A $(XREF2 range, isForwardRange, forward range) of possible
        choices.

Returns:
$(D seq) advanced to the first matching element, or until empty if there are no
matching elements.

See_Also:
    $(WEB sgi.com/tech/stl/find_first_of.html, STL's find_first_of)
*/
Range1 findAmong(alias pred = "a == b", Range1, Range2)(
    Range1 seq, Range2 choices)
    if (isInputRange!Range1 && isForwardRange!Range2)
{
    for (; !seq.empty && find!pred(choices, seq.front).empty; seq.popFront())
    {
    }
    return seq;
}

///
@safe unittest
{
    int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
    int[] b = [ 3, 1, 2 ];
    assert(findAmong(a, b) == a[2 .. $]);
}

@safe unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ -1, 0, 2, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(findAmong(a, b) == [2, 1, 2, 3, 4, 5 ]);
    assert(findAmong(b, [ 4, 6, 7 ][]).empty);
    assert(findAmong!("a == b")(a, b).length == a.length - 2);
    assert(findAmong!("a == b")(b, [ 4, 6, 7 ][]).empty);
}

// count
/**
The first version counts the number of elements $(D x) in $(D r) for
which $(D pred(x, value)) is $(D true). $(D pred) defaults to
equality. Performs $(BIGOH haystack.length) evaluations of $(D pred).

The second version returns the number of times $(D needle) occurs in
$(D haystack). Throws an exception if $(D needle.empty), as the _count
of the empty range in any range would be infinite. Overlapped counts
are not considered, for example $(D count("aaa", "aa")) is $(D 1), not
$(D 2).

The third version counts the elements for which $(D pred(x)) is $(D
true). Performs $(BIGOH haystack.length) evaluations of $(D pred).

Note: Regardless of the overload, $(D count) will not accept
infinite ranges for $(D haystack).
*/
size_t count(alias pred = "a == b", Range, E)(Range haystack, E needle)
    if (isInputRange!Range && !isInfinite!Range &&
        is(typeof(binaryFun!pred(haystack.front, needle)) : bool))
{
    bool pred2(ElementType!Range a) { return binaryFun!pred(a, needle); }
    return count!pred2(haystack);
}

///
@safe unittest
{
    import std.uni : toLower;

    // count elements in range
    int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
    assert(count(a, 2) == 3);
    assert(count!("a > b")(a, 2) == 5);
    // count range in range
    assert(count("abcadfabf", "ab") == 2);
    assert(count("ababab", "abab") == 1);
    assert(count("ababab", "abx") == 0);
    // fuzzy count range in range
    assert(count!((a, b) => std.uni.toLower(a) == std.uni.toLower(b))("AbcAdFaBf", "ab") == 2);
    // count predicate in range
    assert(count!("a > 1")(a) == 8);
}

@safe unittest
{
    import std.conv : text;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
    assert(count(a, 2) == 3, text(count(a, 2)));
    assert(count!("a > b")(a, 2) == 5, text(count!("a > b")(a, 2)));

    // check strings
    assert(count("日本語")  == 3);
    assert(count("日本語"w) == 3);
    assert(count("日本語"d) == 3);

    assert(count!("a == '日'")("日本語")  == 1);
    assert(count!("a == '本'")("日本語"w) == 1);
    assert(count!("a == '語'")("日本語"d) == 1);
}

@safe unittest
{
    debug(std_algorithm) printf("algorithm.count.unittest\n");
    string s = "This is a fofofof list";
    string sub = "fof";
    assert(count(s, sub) == 2);
}

/// Ditto
size_t count(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
    if (isForwardRange!R1 && !isInfinite!R1 &&
        isForwardRange!R2 &&
        is(typeof(binaryFun!pred(haystack.front, needle.front)) : bool))
{
    assert(!needle.empty, "Cannot count occurrences of an empty range");

    static if (isInfinite!R2)
    {
        //Note: This is the special case of looking for an infinite inside a finite...
        //"How many instances of the Fibonacci sequence can you count in [1, 2, 3]?" - "None."
        return 0;
    }
    else
    {
        size_t result;
        //Note: haystack is not saved, because findskip is designed to modify it
        for ( ; findSkip!pred(haystack, needle.save) ; ++result)
        {}
        return result;
    }
}

/// Ditto
size_t count(alias pred = "true", R)(R haystack)
    if (isInputRange!R && !isInfinite!R &&
        is(typeof(unaryFun!pred(haystack.front)) : bool))
{
    size_t result;
    alias T = ElementType!R; //For narrow strings forces dchar iteration
    foreach (T elem; haystack)
        if (unaryFun!pred(elem)) ++result;
    return result;
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
    assert(count!("a == 3")(a) == 2);
    assert(count("日本語") == 3);
}

// Issue 11253
@safe nothrow unittest
{
    assert([1, 2, 3].count([2, 3]) == 1);
}

// balancedParens
/**
Checks whether $(D r) has "balanced parentheses", i.e. all instances
of $(D lPar) are closed by corresponding instances of $(D rPar). The
parameter $(D maxNestingLevel) controls the nesting level allowed. The
most common uses are the default or $(D 0). In the latter case, no
nesting is allowed.
*/
bool balancedParens(Range, E)(Range r, E lPar, E rPar,
        size_t maxNestingLevel = size_t.max)
if (isInputRange!(Range) && is(typeof(r.front == lPar)))
{
    size_t count;
    for (; !r.empty; r.popFront())
    {
        if (r.front == lPar)
        {
            if (count > maxNestingLevel) return false;
            ++count;
        }
        else if (r.front == rPar)
        {
            if (!count) return false;
            --count;
        }
    }
    return count == 0;
}

///
@safe unittest
{
    auto s = "1 + (2 * (3 + 1 / 2)";
    assert(!balancedParens(s, '(', ')'));
    s = "1 + (2 * (3 + 1) / 2)";
    assert(balancedParens(s, '(', ')'));
    s = "1 + (2 * (3 + 1) / 2)";
    assert(!balancedParens(s, '(', ')', 0));
    s = "1 + (2 * 3 + 1) / (2 - 5)";
    assert(balancedParens(s, '(', ')', 0));
}

/**
Returns the minimum element of a range together with the number of
occurrences. The function can actually be used for counting the
maximum or any other ordering predicate (that's why $(D maxCount) is
not provided).
 */
Tuple!(ElementType!Range, size_t)
minCount(alias pred = "a < b", Range)(Range range)
    if (isInputRange!Range && !isInfinite!Range &&
        is(typeof(binaryFun!pred(range.front, range.front))))
{
    import std.exception : enforce;

    alias T  = ElementType!Range;
    alias UT = Unqual!T;
    alias RetType = Tuple!(T, size_t);

    static assert (is(typeof(RetType(range.front, 1))),
        algoFormat("Error: Cannot call minCount on a %s, because it is not possible "~
               "to copy the result value (a %s) into a Tuple.", Range.stringof, T.stringof));

    enforce(!range.empty, "Can't count elements from an empty range");
    size_t occurrences = 1;

    static if (isForwardRange!Range)
    {
        Range least = range.save;
        for (range.popFront(); !range.empty; range.popFront())
        {
            if (binaryFun!pred(least.front, range.front)) continue;
            if (binaryFun!pred(range.front, least.front))
            {
                // change the min
                least = range.save;
                occurrences = 1;
            }
            else
                ++occurrences;
        }
        return RetType(least.front, occurrences);
    }
    else static if (isAssignable!(UT, T) || (!hasElaborateAssign!UT && isAssignable!UT))
    {
        UT v = UT.init;
        static if (isAssignable!(UT, T)) v = range.front;
        else                             v = cast(UT)range.front;

        for (range.popFront(); !range.empty; range.popFront())
        {
            if (binaryFun!pred(*cast(T*)&v, range.front)) continue;
            if (binaryFun!pred(range.front, *cast(T*)&v))
            {
                // change the min
                static if (isAssignable!(UT, T)) v = range.front;
                else                             v = cast(UT)range.front; //Safe because !hasElaborateAssign!UT
                occurrences = 1;
            }
            else
                ++occurrences;
        }
        return RetType(*cast(T*)&v, occurrences);
    }
    else static if (hasLvalueElements!Range)
    {
        T* p = addressOf(range.front);
        for (range.popFront(); !range.empty; range.popFront())
        {
            if (binaryFun!pred(*p, range.front)) continue;
            if (binaryFun!pred(range.front, *p))
            {
                // change the min
                p = addressOf(range.front);
                occurrences = 1;
            }
            else
                ++occurrences;
        }
        return RetType(*p, occurrences);
    }
    else
        static assert(false,
            algoFormat("Sorry, can't find the minCount of a %s: Don't know how "~
                   "to keep track of the smallest %s element.", Range.stringof, T.stringof));
}

///
unittest
{
    import std.conv : text;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    // Minimum is 1 and occurs 3 times
    assert(minCount(a) == tuple(1, 3));
    // Maximum is 4 and occurs 2 times
    assert(minCount!("a > b")(a) == tuple(4, 2));
}

unittest
{
    import std.conv : text;
    import std.exception : assertThrown;
    import std.internal.test.dummyrange;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    int[][] b = [ [4], [2, 4], [4], [4] ];
    auto c = minCount!("a[0] < b[0]")(b);
    assert(c == tuple([2, 4], 1), text(c[0]));

    //Test empty range
    assertThrown(minCount(b[$..$]));

    //test with reference ranges. Test both input and forward.
    assert(minCount(new ReferenceInputRange!int([1, 2, 1, 0, 2, 0])) == tuple(0, 2));
    assert(minCount(new ReferenceForwardRange!int([1, 2, 1, 0, 2, 0])) == tuple(0, 2));
}

unittest
{
    import std.conv : text;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    static struct R(T) //input range
    {
        T[] arr;
        alias arr this;
    }

    immutable         a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    R!(immutable int) b = R!(immutable int)(a);

    assert(minCount(a) == tuple(1, 3));
    assert(minCount(b) == tuple(1, 3));
    assert(minCount!((ref immutable int a, ref immutable int b) => (a > b))(a) == tuple(4, 2));
    assert(minCount!((ref immutable int a, ref immutable int b) => (a > b))(b) == tuple(4, 2));

    immutable(int[])[] c = [ [4], [2, 4], [4], [4] ];
    assert(minCount!("a[0] < b[0]")(c) == tuple([2, 4], 1), text(c[0]));

    static struct S1
    {
        int i;
    }
    alias IS1 = immutable(S1);
    static assert( isAssignable!S1);
    static assert( isAssignable!(S1, IS1));

    static struct S2
    {
        int* p;
        this(ref immutable int i) immutable {p = &i;}
        this(ref int i) {p = &i;}
        @property ref inout(int) i() inout {return *p;}
        bool opEquals(const S2 other) const {return i == other.i;}
    }
    alias IS2 = immutable(S2);
    static assert( isAssignable!S2);
    static assert(!isAssignable!(S2, IS2));
    static assert(!hasElaborateAssign!S2);

    static struct S3
    {
        int i;
        void opAssign(ref S3 other) @disable;
    }
    static assert(!isAssignable!S3);

    foreach (Type; TypeTuple!(S1, IS1, S2, IS2, S3))
    {
        static if (is(Type == immutable)) alias V = immutable int;
        else                              alias V = int;
        V one = 1, two = 2;
        auto r1 = [Type(two), Type(one), Type(one)];
        auto r2 = R!Type(r1);
        assert(minCount!"a.i < b.i"(r1) == tuple(Type(one), 2));
        assert(minCount!"a.i < b.i"(r2) == tuple(Type(one), 2));
        assert(one == 1 && two == 2);
    }
}

// minPos
/**
Returns the position of the minimum element of forward range $(D
range), i.e. a subrange of $(D range) starting at the position of its
smallest element and with the same ending as $(D range). The function
can actually be used for finding the maximum or any other ordering
predicate (that's why $(D maxPos) is not provided).
 */
Range minPos(alias pred = "a < b", Range)(Range range)
    if (isForwardRange!Range && !isInfinite!Range &&
        is(typeof(binaryFun!pred(range.front, range.front))))
{
    if (range.empty) return range;
    auto result = range.save;

    for (range.popFront(); !range.empty; range.popFront())
    {
        //Note: Unlike minCount, we do not care to find equivalence, so a single pred call is enough
        if (binaryFun!pred(range.front, result.front))
        {
            // change the min
            result = range.save;
        }
    }
    return result;
}

///
@safe unittest
{
    int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    // Minimum is 1 and first occurs in position 3
    assert(minPos(a) == [ 1, 2, 4, 1, 1, 2 ]);
    // Maximum is 4 and first occurs in position 2
    assert(minPos!("a > b")(a) == [ 4, 1, 2, 4, 1, 1, 2 ]);
}

@safe unittest
{
    import std.internal.test.dummyrange;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    //Test that an empty range works
    int[] b = a[$..$];
    assert(equal(minPos(b), b));

    //test with reference range.
    assert( equal( minPos(new ReferenceForwardRange!int([1, 2, 1, 0, 2, 0])), [0, 2, 0] ) );
}

unittest
{
    //Rvalue range
    import std.container : Array;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    assert(Array!int(2, 3, 4, 1, 2, 4, 1, 1, 2)
               []
               .minPos()
               .equal([ 1, 2, 4, 1, 1, 2 ]));
}

@safe unittest
{
    //BUG 9299
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    immutable a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    // Minimum is 1 and first occurs in position 3
    assert(minPos(a) == [ 1, 2, 4, 1, 1, 2 ]);
    // Maximum is 4 and first occurs in position 5
    assert(minPos!("a > b")(a) == [ 4, 1, 2, 4, 1, 1, 2 ]);

    immutable(int[])[] b = [ [4], [2, 4], [4], [4] ];
    assert(minPos!("a[0] < b[0]")(b) == [ [2, 4], [4], [4] ]);
}

// copy
/**
Copies the content of $(D source) into $(D target) and returns the
remaining (unfilled) part of $(D target).

Preconditions: $(D target) shall have enough room to accomodate
$(D source).

See_Also:
    $(WEB sgi.com/tech/stl/_copy.html, STL's _copy)
 */
Range2 copy(Range1, Range2)(Range1 source, Range2 target)
if (isInputRange!Range1 && isOutputRange!(Range2, ElementType!Range1))
{
    static Range2 genericImpl(Range1 source, Range2 target)
    {
        // Specialize for 2 random access ranges.
        // Typically 2 random access ranges are faster iterated by common
        // index then by x.popFront(), y.popFront() pair
        static if (isRandomAccessRange!Range1 && hasLength!Range1
            && hasSlicing!Range2 && isRandomAccessRange!Range2 && hasLength!Range2)
        {
            assert(target.length >= source.length,
                "Cannot copy a source range into a smaller target range.");

            auto len = source.length;
            foreach (idx; 0 .. len)
                target[idx] = source[idx];
            return target[len .. target.length];
        }
        else
        {
            put(target, source);
            return target;
        }
    }

    static if (isArray!Range1 && isArray!Range2 &&
               is(Unqual!(typeof(source[0])) == Unqual!(typeof(target[0]))))
    {
        immutable overlaps = () @trusted {
            return source.ptr < target.ptr + target.length &&
                   target.ptr < source.ptr + source.length; }();

        if (overlaps)
        {
            return genericImpl(source, target);
        }
        else
        {
            // Array specialization.  This uses optimized memory copying
            // routines under the hood and is about 10-20x faster than the
            // generic implementation.
            assert(target.length >= source.length,
                "Cannot copy a source array into a smaller target array.");
            target[0..source.length] = source[];

            return target[source.length..$];
        }
    }
    else
    {
        return genericImpl(source, target);
    }
}

///
@safe unittest
{
    int[] a = [ 1, 5 ];
    int[] b = [ 9, 8 ];
    int[] buf = new int[a.length + b.length + 10];
    auto rem = copy(a, buf);    // copy a into buf
    rem = copy(b, rem);         // copy b into remainder of buf
    assert(buf[0 .. a.length + b.length] == [1, 5, 9, 8]);
    assert(rem.length == 10);   // unused slots in buf
}

/**
As long as the target range elements support assignment from source
range elements, different types of ranges are accepted:
*/
@safe unittest
{
    float[] src = [ 1.0f, 5 ];
    double[] dest = new double[src.length];
    copy(src, dest);
}

/**
To _copy at most $(D n) elements from a range, you may want to use
$(XREF range, take):
*/
@safe unittest
{
    import std.range;
    int[] src = [ 1, 5, 8, 9, 10 ];
    auto dest = new int[3];
    copy(take(src, dest.length), dest);
    assert(dest[0 .. $] == [ 1, 5, 8 ]);
}

/**
To _copy just those elements from a range that satisfy a predicate you
may want to use $(LREF filter):
*/
@safe unittest
{
    int[] src = [ 1, 5, 8, 9, 10, 1, 2, 0 ];
    auto dest = new int[src.length];
    auto rem = copy(src.filter!(a => (a & 1) == 1), dest);
    assert(dest[0 .. $ - rem.length] == [ 1, 5, 9, 1 ]);
}

/**
$(XREF range, retro) can be used to achieve behavior similar to
$(WEB sgi.com/tech/stl/copy_backward.html, STL's copy_backward'):
*/
@safe unittest
{
    import std.algorithm, std.range;
    int[] src = [1, 2, 4];
    int[] dest = [0, 0, 0, 0, 0];
    copy(src.retro, dest.retro);
    assert(dest == [0, 0, 1, 2, 4]);
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    {
        int[] a = [ 1, 5 ];
        int[] b = [ 9, 8 ];
        auto e = copy(filter!("a > 1")(a), b);
        assert(b[0] == 5 && e.length == 1);
    }

    {
        int[] a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        copy(a[5..10], a[4..9]);
        assert(a[4..9] == [6, 7, 8, 9, 10]);
    }

    {   // Test for bug 7898
        enum v =
        {
            import std.algorithm;
            int[] arr1 = [10, 20, 30, 40, 50];
            int[] arr2 = arr1.dup;
            copy(arr1, arr2);
            return 35;
        }();
    }
}

// swapRanges
/**
Swaps all elements of $(D r1) with successive elements in $(D r2).
Returns a tuple containing the remainder portions of $(D r1) and $(D
r2) that were not swapped (one of them will be empty). The ranges may
be of different types but must have the same element type and support
swapping.
*/
Tuple!(Range1, Range2)
swapRanges(Range1, Range2)(Range1 r1, Range2 r2)
    if (isInputRange!(Range1) && isInputRange!(Range2)
            && hasSwappableElements!(Range1) && hasSwappableElements!(Range2)
            && is(ElementType!(Range1) == ElementType!(Range2)))
{
    for (; !r1.empty && !r2.empty; r1.popFront(), r2.popFront())
    {
        swap(r1.front, r2.front);
    }
    return tuple(r1, r2);
}

///
@safe unittest
{
    int[] a = [ 100, 101, 102, 103 ];
    int[] b = [ 0, 1, 2, 3 ];
    auto c = swapRanges(a[1 .. 3], b[2 .. 4]);
    assert(c[0].empty && c[1].empty);
    assert(a == [ 100, 2, 3, 103 ]);
    assert(b == [ 0, 1, 101, 102 ]);
}

// reverse
/**
Reverses $(D r) in-place.  Performs $(D r.length / 2) evaluations of $(D
swap).

See_Also:
    $(WEB sgi.com/tech/stl/_reverse.html, STL's _reverse)
*/
void reverse(Range)(Range r)
if (isBidirectionalRange!Range && !isRandomAccessRange!Range
    && hasSwappableElements!Range)
{
    while (!r.empty)
    {
        swap(r.front, r.back);
        r.popFront();
        if (r.empty) break;
        r.popBack();
    }
}

///
@safe unittest
{
    int[] arr = [ 1, 2, 3 ];
    reverse(arr);
    assert(arr == [ 3, 2, 1 ]);
}

///ditto
void reverse(Range)(Range r)
if (isRandomAccessRange!Range && hasLength!Range)
{
    //swapAt is in fact the only way to swap non lvalue ranges
    immutable last = r.length-1;
    immutable steps = r.length/2;
    for (size_t i = 0; i < steps; i++)
    {
        swapAt(r, i, last-i);
    }
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] range = null;
    reverse(range);
    range = [ 1 ];
    reverse(range);
    assert(range == [1]);
    range = [1, 2];
    reverse(range);
    assert(range == [2, 1]);
    range = [1, 2, 3];
    reverse(range);
    assert(range == [3, 2, 1]);
}

/**
Reverses $(D r) in-place, where $(D r) is a narrow string (having
elements of type $(D char) or $(D wchar)). UTF sequences consisting of
multiple code units are preserved properly.
*/
void reverse(Char)(Char[] s)
if (isNarrowString!(Char[]) && !is(Char == const) && !is(Char == immutable))
{
    import std.string : representation;
    import std.utf : stride;

    auto r = representation(s);
    for (size_t i = 0; i < s.length; )
    {
        immutable step = std.utf.stride(s, i);
        if (step > 1)
        {
            .reverse(r[i .. i + step]);
            i += step;
        }
        else
        {
            ++i;
        }
    }
    reverse(r);
}

///
@safe unittest
{
    char[] arr = "hello\U00010143\u0100\U00010143".dup;
    reverse(arr);
    assert(arr == "\U00010143\u0100\U00010143olleh");
}

@safe unittest
{
    void test(string a, string b)
    {
        auto c = a.dup;
        reverse(c);
        assert(c == b, c ~ " != " ~ b);
    }

    test("a", "a");
    test(" ", " ");
    test("\u2029", "\u2029");
    test("\u0100", "\u0100");
    test("\u0430", "\u0430");
    test("\U00010143", "\U00010143");
    test("abcdefcdef", "fedcfedcba");
    test("hello\U00010143\u0100\U00010143", "\U00010143\u0100\U00010143olleh");
}

/**
    The strip group of functions allow stripping of either leading, trailing,
    or both leading and trailing elements.

    The $(D stripLeft) function will strip the $(D front) of the range,
    the $(D stripRight) function will strip the $(D back) of the range,
    while the $(D strip) function will strip both the $(D front) and $(D back)
    of the range.

    Note that the $(D strip) and $(D stripRight) functions require the range to
    be a $(LREF BidirectionalRange) range.

    All of these functions come in two varieties: one takes a target element,
    where the range will be stripped as long as this element can be found.
    The other takes a lambda predicate, where the range will be stripped as
    long as the predicate returns true.
*/
Range strip(Range, E)(Range range, E element)
    if (isBidirectionalRange!Range && is(typeof(range.front == element) : bool))
{
    return range.stripLeft(element).stripRight(element);
}

/// ditto
Range strip(alias pred, Range)(Range range)
    if (isBidirectionalRange!Range && is(typeof(pred(range.back)) : bool))
{
    return range.stripLeft!pred().stripRight!pred();
}

/// ditto
Range stripLeft(Range, E)(Range range, E element)
    if (isInputRange!Range && is(typeof(range.front == element) : bool))
{
    return find!((auto ref a) => a != element)(range);
}

/// ditto
Range stripLeft(alias pred, Range)(Range range)
    if (isInputRange!Range && is(typeof(pred(range.front)) : bool))
{
    import std.functional : not;

    return find!(not!pred)(range);
}

/// ditto
Range stripRight(Range, E)(Range range, E element)
    if (isBidirectionalRange!Range && is(typeof(range.back == element) : bool))
{
    for (; !range.empty; range.popBack())
    {
        if (range.back != element)
            break;
    }
    return range;
}

/// ditto
Range stripRight(alias pred, Range)(Range range)
    if (isBidirectionalRange!Range && is(typeof(pred(range.back)) : bool))
{
    for (; !range.empty; range.popBack())
    {
        if (!pred(range.back))
            break;
    }
    return range;
}

/// Strip leading and trailing elements equal to the target element.
@safe pure unittest
{
    assert("  foobar  ".strip(' ') == "foobar");
    assert("00223.444500".strip('0') == "223.4445");
    assert("ëëêéüŗōpéêëë".strip('ë') == "êéüŗōpéê");
    assert([1, 1, 0, 1, 1].strip(1) == [0]);
    assert([0.0, 0.01, 0.01, 0.0].strip(0).length == 2);
}

/// Strip leading and trailing elements while the predicate returns true.
@safe pure unittest
{
    assert("  foobar  ".strip!(a => a == ' ')() == "foobar");
    assert("00223.444500".strip!(a => a == '0')() == "223.4445");
    assert("ëëêéüŗōpéêëë".strip!(a => a == 'ë')() == "êéüŗōpéê");
    assert([1, 1, 0, 1, 1].strip!(a => a == 1)() == [0]);
    assert([0.0, 0.01, 0.5, 0.6, 0.01, 0.0].strip!(a => a < 0.4)().length == 2);
}

/// Strip leading elements equal to the target element.
@safe pure unittest
{
    assert("  foobar  ".stripLeft(' ') == "foobar  ");
    assert("00223.444500".stripLeft('0') == "223.444500");
    assert("ůůűniçodêéé".stripLeft('ů') == "űniçodêéé");
    assert([1, 1, 0, 1, 1].stripLeft(1) == [0, 1, 1]);
    assert([0.0, 0.01, 0.01, 0.0].stripLeft(0).length == 3);
}

/// Strip leading elements while the predicate returns true.
@safe pure unittest
{
    assert("  foobar  ".stripLeft!(a => a == ' ')() == "foobar  ");
    assert("00223.444500".stripLeft!(a => a == '0')() == "223.444500");
    assert("ůůűniçodêéé".stripLeft!(a => a == 'ů')() == "űniçodêéé");
    assert([1, 1, 0, 1, 1].stripLeft!(a => a == 1)() == [0, 1, 1]);
    assert([0.0, 0.01, 0.10, 0.5, 0.6].stripLeft!(a => a < 0.4)().length == 2);
}

/// Strip trailing elements equal to the target element.
@safe pure unittest
{
    assert("  foobar  ".stripRight(' ') == "  foobar");
    assert("00223.444500".stripRight('0') == "00223.4445");
    assert("ùniçodêéé".stripRight('é') == "ùniçodê");
    assert([1, 1, 0, 1, 1].stripRight(1) == [1, 1, 0]);
    assert([0.0, 0.01, 0.01, 0.0].stripRight(0).length == 3);
}

/// Strip trailing elements while the predicate returns true.
@safe pure unittest
{
    assert("  foobar  ".stripRight!(a => a == ' ')() == "  foobar");
    assert("00223.444500".stripRight!(a => a == '0')() == "00223.4445");
    assert("ùniçodêéé".stripRight!(a => a == 'é')() == "ùniçodê");
    assert([1, 1, 0, 1, 1].stripRight!(a => a == 1)() == [1, 1, 0]);
    assert([0.0, 0.01, 0.10, 0.5, 0.6].stripRight!(a => a > 0.4)().length == 3);
}

// bringToFront
/**
The $(D bringToFront) function has considerable flexibility and
usefulness. It can rotate elements in one buffer left or right, swap
buffers of equal length, and even move elements across disjoint
buffers of different types and different lengths.

$(D bringToFront) takes two ranges $(D front) and $(D back), which may
be of different types. Considering the concatenation of $(D front) and
$(D back) one unified range, $(D bringToFront) rotates that unified
range such that all elements in $(D back) are brought to the beginning
of the unified range. The relative ordering of elements in $(D front)
and $(D back), respectively, remains unchanged.

Performs $(BIGOH max(front.length, back.length)) evaluations of $(D
swap).

Preconditions:

Either $(D front) and $(D back) are disjoint, or $(D back) is
reachable from $(D front) and $(D front) is not reachable from $(D
back).

Returns:

The number of elements brought to the front, i.e., the length of $(D
back).

See_Also:
    $(WEB sgi.com/tech/stl/_rotate.html, STL's rotate)
*/
size_t bringToFront(Range1, Range2)(Range1 front, Range2 back)
    if (isInputRange!Range1 && isForwardRange!Range2)
{
    import std.range: Take, take;
    enum bool sameHeadExists = is(typeof(front.sameHead(back)));
    size_t result;
    for (bool semidone; !front.empty && !back.empty; )
    {
        static if (sameHeadExists)
        {
            if (front.sameHead(back)) break; // shortcut
        }
        // Swap elements until front and/or back ends.
        auto back0 = back.save;
        size_t nswaps;
        do
        {
            static if (sameHeadExists)
            {
                // Detect the stepping-over condition.
                if (front.sameHead(back0)) back0 = back.save;
            }
            swapFront(front, back);
            ++nswaps;
            front.popFront();
            back.popFront();
        }
        while (!front.empty && !back.empty);

        if (!semidone) result += nswaps;

        // Now deal with the remaining elements.
        if (back.empty)
        {
            if (front.empty) break;
            // Right side was shorter, which means that we've brought
            // all the back elements to the front.
            semidone = true;
            // Next pass: bringToFront(front, back0) to adjust the rest.
            back = back0;
        }
        else
        {
            assert(front.empty);
            // Left side was shorter. Let's step into the back.
            static if (is(Range1 == Take!Range2))
            {
                front = take(back0, nswaps);
            }
            else
            {
                immutable subresult = bringToFront(take(back0, nswaps),
                                                   back);
                if (!semidone) result += subresult;
                break; // done
            }
        }
    }
    return result;
}

/**
The simplest use of $(D bringToFront) is for rotating elements in a
buffer. For example:
*/
@safe unittest
{
    auto arr = [4, 5, 6, 7, 1, 2, 3];
    auto p = bringToFront(arr[0 .. 4], arr[4 .. $]);
    assert(p == arr.length - 4);
    assert(arr == [ 1, 2, 3, 4, 5, 6, 7 ]);
}

/**
The $(D front) range may actually "step over" the $(D back)
range. This is very useful with forward ranges that cannot compute
comfortably right-bounded subranges like $(D arr[0 .. 4]) above. In
the example below, $(D r2) is a right subrange of $(D r1).
*/
@safe unittest
{
    import std.container : SList;

    auto list = SList!(int)(4, 5, 6, 7, 1, 2, 3);
    auto r1 = list[];
    auto r2 = list[]; popFrontN(r2, 4);
    assert(equal(r2, [ 1, 2, 3 ]));
    bringToFront(r1, r2);
    assert(equal(list[], [ 1, 2, 3, 4, 5, 6, 7 ]));
}


/**
Elements can be swapped across ranges of different types:
*/
@safe unittest
{
    import std.container : SList;

    auto list = SList!(int)(4, 5, 6, 7);
    auto vec = [ 1, 2, 3 ];
    bringToFront(list[], vec);
    assert(equal(list[], [ 1, 2, 3, 4 ]));
    assert(equal(vec, [ 5, 6, 7 ]));
}

@safe unittest
{
    import std.conv : text;
    import std.random : Random, unpredictableSeed, uniform;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    // a more elaborate test
    {
        auto rnd = Random(unpredictableSeed);
        int[] a = new int[uniform(100, 200, rnd)];
        int[] b = new int[uniform(100, 200, rnd)];
        foreach (ref e; a) e = uniform(-100, 100, rnd);
        foreach (ref e; b) e = uniform(-100, 100, rnd);
        int[] c = a ~ b;
        // writeln("a= ", a);
        // writeln("b= ", b);
        auto n = bringToFront(c[0 .. a.length], c[a.length .. $]);
        //writeln("c= ", c);
        assert(n == b.length);
        assert(c == b ~ a, text(c, "\n", a, "\n", b));
    }
    // different types, moveFront, no sameHead
    {
        static struct R(T)
        {
            T[] data;
            size_t i;
            @property
            {
                R save() { return this; }
                bool empty() { return i >= data.length; }
                T front() { return data[i]; }
                T front(real e) { return data[i] = cast(T) e; }
            }
            void popFront() { ++i; }
        }
        auto a = R!int([1, 2, 3, 4, 5]);
        auto b = R!real([6, 7, 8, 9]);
        auto n = bringToFront(a, b);
        assert(n == 4);
        assert(a.data == [6, 7, 8, 9, 1]);
        assert(b.data == [2, 3, 4, 5]);
    }
    // front steps over back
    {
        int[] arr, r1, r2;

        // back is shorter
        arr = [4, 5, 6, 7, 1, 2, 3];
        r1 = arr;
        r2 = arr[4 .. $];
        bringToFront(r1, r2) == 3 || assert(0);
        assert(equal(arr, [1, 2, 3, 4, 5, 6, 7]));

        // front is shorter
        arr = [5, 6, 7, 1, 2, 3, 4];
        r1 = arr;
        r2 = arr[3 .. $];
        bringToFront(r1, r2) == 4 || assert(0);
        assert(equal(arr, [1, 2, 3, 4, 5, 6, 7]));
    }
}

// SwapStrategy
/**
Defines the swapping strategy for algorithms that need to swap
elements in a range (such as partition and sort). The strategy
concerns the swapping of elements that are not the core concern of the
algorithm. For example, consider an algorithm that sorts $(D [ "abc",
"b", "aBc" ]) according to $(D toUpper(a) < toUpper(b)). That
algorithm might choose to swap the two equivalent strings $(D "abc")
and $(D "aBc"). That does not affect the sorting since both $(D [
"abc", "aBc", "b" ]) and $(D [ "aBc", "abc", "b" ]) are valid
outcomes.

Some situations require that the algorithm must NOT ever change the
relative ordering of equivalent elements (in the example above, only
$(D [ "abc", "aBc", "b" ]) would be the correct result). Such
algorithms are called $(B stable). If the ordering algorithm may swap
equivalent elements discretionarily, the ordering is called $(B
unstable).

Yet another class of algorithms may choose an intermediate tradeoff by
being stable only on a well-defined subrange of the range. There is no
established terminology for such behavior; this library calls it $(B
semistable).

Generally, the $(D stable) ordering strategy may be more costly in
time and/or space than the other two because it imposes additional
constraints. Similarly, $(D semistable) may be costlier than $(D
unstable). As (semi-)stability is not needed very often, the ordering
algorithms in this module parameterized by $(D SwapStrategy) all
choose $(D SwapStrategy.unstable) as the default.
*/

enum SwapStrategy
{
    /**
       Allows freely swapping of elements as long as the output
       satisfies the algorithm's requirements.
    */
    unstable,
    /**
       In algorithms partitioning ranges in two, preserve relative
       ordering of elements only to the left of the partition point.
    */
    semistable,
    /**
       Preserve the relative ordering of elements to the largest
       extent allowed by the algorithm's requirements.
    */
    stable,
}

/**
Eliminates elements at given offsets from $(D range) and returns the
shortened range. In the simplest call, one element is removed.

----
int[] a = [ 3, 5, 7, 8 ];
assert(remove(a, 1) == [ 3, 7, 8 ]);
assert(a == [ 3, 7, 8, 8 ]);
----

In the case above the element at offset $(D 1) is removed and $(D
remove) returns the range smaller by one element. The original array
has remained of the same length because all functions in $(D
std.algorithm) only change $(I content), not $(I topology). The value
$(D 8) is repeated because $(XREF algorithm, move) was invoked to move
elements around and on integers $(D move) simply copies the source to
the destination. To replace $(D a) with the effect of the removal,
simply assign $(D a = remove(a, 1)). The slice will be rebound to the
shorter array and the operation completes with maximal efficiency.

Multiple indices can be passed into $(D remove). In that case,
elements at the respective indices are all removed. The indices must
be passed in increasing order, otherwise an exception occurs.

----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
assert(remove(a, 1, 3, 5) ==
    [ 0, 2, 4, 6, 7, 8, 9, 10 ]);
----

(Note how all indices refer to slots in the $(I original) array, not
in the array as it is being progressively shortened.) Finally, any
combination of integral offsets and tuples composed of two integral
offsets can be passed in.

----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
assert(remove(a, 1, tuple(3, 5), 9) == [ 0, 2, 6, 7, 8, 10 ]);
----

In this case, the slots at positions 1, 3, 4, and 9 are removed from
the array. The tuple passes in a range closed to the left and open to
the right (consistent with built-in slices), e.g. $(D tuple(3, 5))
means indices $(D 3) and $(D 4) but not $(D 5).

If the need is to remove some elements in the range but the order of
the remaining elements does not have to be preserved, you may want to
pass $(D SwapStrategy.unstable) to $(D remove).

----
int[] a = [ 0, 1, 2, 3 ];
assert(remove!(SwapStrategy.unstable)(a, 1) == [ 0, 3, 2 ]);
----

In the case above, the element at slot $(D 1) is removed, but replaced
with the last element of the range. Taking advantage of the relaxation
of the stability requirement, $(D remove) moved elements from the end
of the array over the slots to be removed. This way there is less data
movement to be done which improves the execution time of the function.

The function $(D remove) works on any forward range. The moving
strategy is (listed from fastest to slowest): $(UL $(LI If $(D s ==
SwapStrategy.unstable && isRandomAccessRange!Range && hasLength!Range
&& hasLvalueElements!Range), then elements are moved from the end
of the range into the slots to be filled. In this case, the absolute
minimum of moves is performed.)  $(LI Otherwise, if $(D s ==
SwapStrategy.unstable && isBidirectionalRange!Range && hasLength!Range
&& hasLvalueElements!Range), then elements are still moved from the
end of the range, but time is spent on advancing between slots by repeated
calls to $(D range.popFront).)  $(LI Otherwise, elements are moved
incrementally towards the front of $(D range); a given element is never
moved several times, but more elements are moved than in the previous
cases.))
 */
Range remove
(SwapStrategy s = SwapStrategy.stable, Range, Offset...)
(Range range, Offset offset)
if (s != SwapStrategy.stable
    && isBidirectionalRange!Range
    && hasLvalueElements!Range
    && hasLength!Range
    && Offset.length >= 1)
{
    Tuple!(size_t, "pos", size_t, "len")[offset.length] blackouts;
    foreach (i, v; offset)
    {
        static if (is(typeof(v[0]) : size_t) && is(typeof(v[1]) : size_t))
        {
            blackouts[i].pos = v[0];
            blackouts[i].len = v[1] - v[0];
        }
        else
        {
            static assert(is(typeof(v) : size_t), typeof(v).stringof);
            blackouts[i].pos = v;
            blackouts[i].len = 1;
        }
        static if (i > 0)
        {
            import std.exception : enforce;

            enforce(blackouts[i - 1].pos + blackouts[i - 1].len
                    <= blackouts[i].pos,
                "remove(): incorrect ordering of elements to remove");
        }
    }

    size_t left = 0, right = offset.length - 1;
    auto tgt = range.save;
    size_t steps = 0;

    while (left <= right)
    {
        // Look for a blackout on the right
        if (blackouts[right].pos + blackouts[right].len >= range.length)
        {
            range.popBackExactly(blackouts[right].len);

            // Since right is unsigned, we must check for this case, otherwise
            // we might turn it into size_t.max and the loop condition will not
            // fail when it should.
            if (right > 0)
            {
                --right;
                continue;
            }
            else
                break;
        }
        // Advance to next blackout on the left
        assert(blackouts[left].pos >= steps);
        tgt.popFrontExactly(blackouts[left].pos - steps);
        steps = blackouts[left].pos;
        auto toMove = min(
            blackouts[left].len,
            range.length - (blackouts[right].pos + blackouts[right].len));
        foreach (i; 0 .. toMove)
        {
            move(range.back, tgt.front);
            range.popBack();
            tgt.popFront();
        }
        steps += toMove;
        if (toMove == blackouts[left].len)
        {
            // Filled the entire left hole
            ++left;
            continue;
        }
    }

    return range;
}

// Ditto
Range remove
(SwapStrategy s = SwapStrategy.stable, Range, Offset...)
(Range range, Offset offset)
if (s == SwapStrategy.stable
    && isBidirectionalRange!Range
    && hasLvalueElements!Range
    && Offset.length >= 1)
{
    auto result = range;
    auto src = range, tgt = range;
    size_t pos;
    foreach (pass, i; offset)
    {
        static if (is(typeof(i[0])) && is(typeof(i[1])))
        {
            auto from = i[0], delta = i[1] - i[0];
        }
        else
        {
            auto from = i;
            enum delta = 1;
        }

        static if (pass > 0)
        {
            import std.exception : enforce;
            enforce(pos <= from,
                    "remove(): incorrect ordering of elements to remove");

            for (; pos < from; ++pos, src.popFront(), tgt.popFront())
            {
                move(src.front, tgt.front);
            }
        }
        else
        {
            src.popFrontExactly(from);
            tgt.popFrontExactly(from);
            pos = from;
        }
        // now skip source to the "to" position
        src.popFrontExactly(delta);
        result.popBackExactly(delta);
        pos += delta;
    }
    // leftover move
    moveAll(src, tgt);
    return result;
}

@safe unittest
{
    import std.exception : assertThrown;
    import std.range;

    // http://d.puremagic.com/issues/show_bug.cgi?id=10173
    int[] test = iota(0, 10).array();
    assertThrown(remove!(SwapStrategy.stable)(test, tuple(2, 4), tuple(1, 3)));
    assertThrown(remove!(SwapStrategy.unstable)(test, tuple(2, 4), tuple(1, 3)));
    assertThrown(remove!(SwapStrategy.stable)(test, 2, 4, 1, 3));
    assertThrown(remove!(SwapStrategy.unstable)(test, 2, 4, 1, 3));
}

@safe unittest
{
    import std.range;
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    //writeln(remove!(SwapStrategy.stable)(a, 1));
    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(remove!(SwapStrategy.stable)(a, 1) ==
        [ 0, 2, 3, 4, 5, 6, 7, 8, 9, 10 ]);

    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(remove!(SwapStrategy.unstable)(a, 0, 10) ==
           [ 9, 1, 2, 3, 4, 5, 6, 7, 8 ]);

    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(remove!(SwapStrategy.unstable)(a, 0, tuple(9, 11)) ==
            [ 8, 1, 2, 3, 4, 5, 6, 7 ]);
    // http://d.puremagic.com/issues/show_bug.cgi?id=5224
    a = [ 1, 2, 3, 4 ];
    assert(remove!(SwapStrategy.unstable)(a, 2) ==
           [ 1, 2, 4 ]);

    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    //writeln(remove!(SwapStrategy.stable)(a, 1, 5));
    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(remove!(SwapStrategy.stable)(a, 1, 5) ==
        [ 0, 2, 3, 4, 6, 7, 8, 9, 10 ]);

    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    //writeln(remove!(SwapStrategy.stable)(a, 1, 3, 5));
    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(remove!(SwapStrategy.stable)(a, 1, 3, 5)
            == [ 0, 2, 4, 6, 7, 8, 9, 10]);
    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    //writeln(remove!(SwapStrategy.stable)(a, 1, tuple(3, 5)));
    a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(remove!(SwapStrategy.stable)(a, 1, tuple(3, 5))
            == [ 0, 2, 5, 6, 7, 8, 9, 10]);

    a = iota(0, 10).array();
    assert(remove!(SwapStrategy.unstable)(a, tuple(1, 4), tuple(6, 7))
            == [0, 9, 8, 7, 4, 5]);
}

@safe unittest
{
    // Issue 11576
    auto arr = [1,2,3];
    arr = arr.remove!(SwapStrategy.unstable)(2);
    assert(arr == [1,2]);

}

@safe unittest
{
    import std.range;
    // Bug# 12889
    int[1][] arr = [[0], [1], [2], [3], [4], [5], [6]];
    auto orig = arr.dup;
    foreach (i; iota(arr.length))
    {
        assert(orig == arr.remove!(SwapStrategy.unstable)(tuple(i,i)));
        assert(orig == arr.remove!(SwapStrategy.stable)(tuple(i,i)));
    }
}

/**
Reduces the length of the bidirectional range $(D range) by removing
elements that satisfy $(D pred). If $(D s = SwapStrategy.unstable),
elements are moved from the right end of the range over the elements
to eliminate. If $(D s = SwapStrategy.stable) (the default),
elements are moved progressively to front such that their relative
order is preserved. Returns the filtered range.
*/
Range remove(alias pred, SwapStrategy s = SwapStrategy.stable, Range)
(Range range)
if (isBidirectionalRange!Range
    && hasLvalueElements!Range)
{
    auto result = range;
    static if (s != SwapStrategy.stable)
    {
        for (;!range.empty;)
        {
            if (!unaryFun!pred(range.front))
            {
                range.popFront();
                continue;
            }
            move(range.back, range.front);
            range.popBack();
            result.popBack();
        }
    }
    else
    {
        auto tgt = range;
        for (; !range.empty; range.popFront())
        {
            if (unaryFun!(pred)(range.front))
            {
                // yank this guy
                result.popBack();
                continue;
            }
            // keep this guy
            move(range.front, tgt.front);
            tgt.popFront();
        }
    }
    return result;
}

///
@safe unittest
{
    static immutable base = [1, 2, 3, 2, 4, 2, 5, 2];

    int[] arr = base[].dup;

    // using a string-based predicate
    assert(remove!("a == 2")(arr) == [ 1, 3, 4, 5 ]);

    // The original array contents have been modified,
    // so we need to reset it to its original state.
    // The length is unmodified however.
    arr[] = base[];

    // using a lambda predicate
    assert(remove!(a => a == 2)(arr) == [ 1, 3, 4, 5 ]);
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 3, 2, 3, 4, 5, 2, 5, 6 ];
    assert(remove!("a == 2", SwapStrategy.unstable)(a) ==
            [ 1, 6, 3, 5, 3, 4, 5 ]);
    a = [ 1, 2, 3, 2, 3, 4, 5, 2, 5, 6 ];
    //writeln(remove!("a != 2", SwapStrategy.stable)(a));
    assert(remove!("a == 2", SwapStrategy.stable)(a) ==
            [ 1, 3, 3, 4, 5, 5, 6 ]);
}

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
enum SortOutput {
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

// canFind
/++
Convenience function. Like find, but only returns whether or not the search
was successful.

See_Also:
$(LREF among) for checking a value against multiple possibilities.
 +/
template canFind(alias pred="a == b")
{
    /++
    Returns $(D true) if and only if any value $(D v) found in the
    input range $(D range) satisfies the predicate $(D pred).
    Performs (at most) $(BIGOH haystack.length) evaluations of $(D pred).
     +/
    bool canFind(Range)(Range haystack)
    if (is(typeof(find!pred(haystack))))
    {
        return any!pred(haystack);
    }

    /++
    Returns $(D true) if and only if $(D needle) can be found in $(D
    range). Performs $(BIGOH haystack.length) evaluations of $(D pred).
     +/
    bool canFind(Range, Element)(Range haystack, Element needle)
    if (is(typeof(find!pred(haystack, needle))))
    {
        return !find!pred(haystack, needle).empty;
    }

    /++
    Returns the 1-based index of the first needle found in $(D haystack). If no
    needle is found, then $(D 0) is returned.

    So, if used directly in the condition of an if statement or loop, the result
    will be $(D true) if one of the needles is found and $(D false) if none are
    found, whereas if the result is used elsewhere, it can either be cast to
    $(D bool) for the same effect or used to get which needle was found first
    without having to deal with the tuple that $(D LREF find) returns for the
    same operation.
     +/
    size_t canFind(Range, Ranges...)(Range haystack, Ranges needles)
    if (Ranges.length > 1 &&
        allSatisfy!(isForwardRange, Ranges) &&
        is(typeof(find!pred(haystack, needles))))
    {
        return find!pred(haystack, needles)[1];
    }
}

///
@safe unittest
{
    assert(canFind([0, 1, 2, 3], 2) == true);
    assert(canFind([0, 1, 2, 3], [1, 2], [2, 3]));
    assert(canFind([0, 1, 2, 3], [1, 2], [2, 3]) == 1);
    assert(canFind([0, 1, 2, 3], [1, 7], [2, 3]));
    assert(canFind([0, 1, 2, 3], [1, 7], [2, 3]) == 2);

    assert(canFind([0, 1, 2, 3], 4) == false);
    assert(!canFind([0, 1, 2, 3], [1, 3], [2, 4]));
    assert(canFind([0, 1, 2, 3], [1, 3], [2, 4]) == 0);
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto a = rndstuff!(int)();
    if (a.length)
    {
        auto b = a[a.length / 2];
        assert(canFind(a, b));
    }
}

@safe unittest
{
    assert(equal!(canFind!"a < b")([[1, 2, 3], [7, 8, 9]], [2, 8]));
}

/++
Checks if $(I _any) of the elements verifies $(D pred).
$(D !any) can be used to verify that $(I none) of the elements verify
$(D pred).
 +/
template any(alias pred = "a")
{
    /++
    Returns $(D true) if and only if $(I _any) value $(D v) found in the
    input range $(D range) satisfies the predicate $(D pred).
    Performs (at most) $(BIGOH range.length) evaluations of $(D pred).
     +/
    bool any(Range)(Range range)
    if (isInputRange!Range && is(typeof(unaryFun!pred(range.front))))
    {
        return !find!pred(range).empty;
    }
}

///
@safe unittest
{
    import std.ascii : isWhite;
    assert( all!(any!isWhite)(["a a", "b b"]));
    assert(!any!(all!isWhite)(["a a", "b b"]));
}

/++
$(D any) can also be used without a predicate, if its items can be
evaluated to true or false in a conditional statement. $(D !any) can be a
convenient way to quickly test that $(I none) of the elements of a range
evaluate to true.
 +/
@safe unittest
{
    int[3] vals1 = [0, 0, 0];
    assert(!any(vals1[])); //none of vals1 evaluate to true

    int[3] vals2 = [2, 0, 2];
    assert( any(vals2[]));
    assert(!all(vals2[]));

    int[3] vals3 = [3, 3, 3];
    assert( any(vals3[]));
    assert( all(vals3[]));
}

@safe unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto a = [ 1, 2, 0, 4 ];
    assert(any!"a == 2"(a));
}

/++
Checks if $(I _all) of the elements verify $(D pred).
 +/
template all(alias pred = "a")
{
    /++
    Returns $(D true) if and only if $(I _all) values $(D v) found in the
    input range $(D range) satisfy the predicate $(D pred).
    Performs (at most) $(BIGOH range.length) evaluations of $(D pred).
     +/
    bool all(Range)(Range range)
    if (isInputRange!Range && is(typeof(unaryFun!pred(range.front))))
    {
        import std.functional : not;

        return find!(not!(unaryFun!pred))(range).empty;
    }
}

///
@safe unittest
{
    assert( all!"a & 1"([1, 3, 5, 7, 9]));
    assert(!all!"a & 1"([1, 2, 3, 5, 7, 9]));
}

/++
$(D all) can also be used without a predicate, if its items can be
evaluated to true or false in a conditional statement. This can be a
convenient way to quickly evaluate that $(I _all) of the elements of a range
are true.
 +/
@safe unittest
{
    int[3] vals = [5, 3, 18];
    assert( all(vals[]));
}

@safe unittest
{
    int x = 1;
    assert(all!(a => a > x)([2, 3]));
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
