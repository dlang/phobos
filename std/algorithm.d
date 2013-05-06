// Written in the D programming language.

/**
<script type="text/javascript">inhibitQuickIndex = 1</script>

$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW Searching) $(TD $(MYREF balancedParens) $(MYREF
boyerMooreFinder) $(MYREF canFind) $(MYREF count) $(MYREF countUntil)
$(MYREF endsWith) $(MYREF commonPrefix) $(MYREF find) $(MYREF
findAdjacent) $(MYREF findAmong) $(MYREF findSkip) $(MYREF findSplit)
$(MYREF findSplitAfter) $(MYREF findSplitBefore) $(MYREF indexOf)
$(MYREF minCount) $(MYREF minPos) $(MYREF mismatch) $(MYREF skipOver)
$(MYREF startsWith) $(MYREF until) )
)
$(TR $(TDNW Comparison) $(TD $(MYREF cmp) $(MYREF equal) $(MYREF
levenshteinDistance) $(MYREF levenshteinDistanceAndPath) $(MYREF max)
$(MYREF min) $(MYREF mismatch) )
)
$(TR $(TDNW Iteration) $(TD $(MYREF filter) $(MYREF filterBidirectional)
$(MYREF group) $(MYREF joiner) $(MYREF map) $(MYREF reduce) $(MYREF
splitter) $(MYREF uniq) )
)
$(TR $(TDNW Sorting) $(TD $(MYREF completeSort) $(MYREF isPartitioned)
$(MYREF isSorted) $(MYREF makeIndex) $(MYREF partialSort) $(MYREF
partition) $(MYREF partition3) $(MYREF schwartzSort) $(MYREF sort)
$(MYREF topN) $(MYREF topNCopy) $(MYREF nextPermutation)
$(MYREF nextEvenPermutation) )
)
$(TR $(TDNW Set&nbsp;operations) $(TD $(MYREF cartesianProduct) $(MYREF
largestPartialIntersection) $(MYREF largestPartialIntersectionWeighted)
$(MYREF nWayUnion) $(MYREF setDifference) $(MYREF setIntersection) $(MYREF
setSymmetricDifference) $(MYREF setUnion) )
)
$(TR $(TDNW Mutation) $(TD $(MYREF bringToFront) $(MYREF copy) $(MYREF
fill) $(MYREF initializeAll) $(MYREF move) $(MYREF moveAll) $(MYREF
moveSome) $(MYREF remove) $(MYREF reverse) $(MYREF swap) $(MYREF
swapRanges) $(MYREF uninitializedFill) ))
)

Implements algorithms oriented mainly towards processing of
sequences. Some functions are semantic equivalents or supersets of
those found in the $(D $(LESS)_algorithm$(GREATER)) header in $(WEB
sgi.com/tech/stl/, Alexander Stepanov's Standard Template Library) for
C++.

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
$(TR $(TH Function Name) $(TH Description)
)
$(LEADINGROW Searching
)
$(TR $(TDNW $(LREF balancedParens)) $(TD $(D
balancedParens("((1 + 1) / 2)")) returns $(D true) because the string
has balanced parentheses.)
)
$(TR $(TDNW $(LREF boyerMooreFinder)) $(TD $(D find("hello
world", boyerMooreFinder("or"))) returns $(D "orld") using the $(LUCKY
Boyer-Moore _algorithm).)
)
$(TR $(TDNW $(LREF canFind)) $(TD $(D canFind("hello world",
"or")) returns $(D true).)
)
$(TR $(TDNW $(LREF count)) $(TD Counts elements that are equal
to a specified value or satisfy a predicate. $(D count([1, 2, 1], 1))
returns $(D 2) and $(D count!"a < 0"([1, -3, 0])) returns $(D 1).)
)
$(TR $(TDNW $(LREF countUntil)) $(TD $(D countUntil(a, b))
returns the number of steps taken in $(D a) to reach $(D b); for
example, $(D countUntil("hello!", "o")) returns $(D 4).)
)
$(TR $(TDNW $(LREF endsWith)) $(TD $(D endsWith("rocks", "ks"))
returns $(D true).)
)
$(TR $(TD $(LREF find)) $(TD $(D find("hello world",
"or")) returns $(D "orld") using linear search. (For binary search refer
to $(XREF range,sortedRange).))
)
$(TR $(TDNW $(LREF findAdjacent)) $(TD $(D findAdjacent([1, 2,
3, 3, 4])) returns the subrange starting with two equal adjacent
elements, i.e. $(D [3, 3, 4]).)
)
$(TR $(TDNW $(LREF findAmong)) $(TD $(D findAmong("abcd",
"qcx")) returns $(D "cd") because $(D 'c') is among $(D "qcx").)
)
$(TR $(TDNW $(LREF findSkip)) $(TD If $(D a = "abcde"), then
$(D findSkip(a, "x")) returns $(D false) and leaves $(D a) unchanged,
whereas $(D findSkip(a, 'c')) advances $(D a) to $(D "cde") and
returns $(D true).)
)
$(TR $(TDNW $(LREF findSplit)) $(TD $(D findSplit("abcdefg",
"de")) returns the three ranges $(D "abc"), $(D "de"), and $(D
"fg").)
)
$(TR $(TDNW $(LREF findSplitAfter)) $(TD $(D
findSplitAfter("abcdefg", "de")) returns the two ranges $(D "abcde")
and $(D "fg").)
)
$(TR $(TDNW $(LREF findSplitBefore)) $(TD $(D
findSplitBefore("abcdefg", "de")) returns the two ranges $(D "abc") and
$(D "defg").)
)
$(TR $(TDNW $(LREF minCount)) $(TD $(D minCount([2, 1, 1, 4,
1])) returns $(D tuple(1, 3)).)
)
$(TR $(TDNW $(LREF minPos)) $(TD $(D minPos([2, 3, 1, 3, 4,
1])) returns the subrange $(D [1, 3, 4, 1]), i.e., positions the range
at the first occurrence of its minimal element.)
)
$(TR $(TDNW $(LREF skipOver)) $(TD Assume $(D a = "blah"). Then
$(D skipOver(a, "bi")) leaves $(D a) unchanged and returns $(D false),
whereas $(D skipOver(a, "bl")) advances $(D a) to refer to $(D "ah")
and returns $(D true).)
)
$(TR $(TDNW $(LREF startsWith)) $(TD $(D startsWith("hello,
world", "hello")) returns $(D true).)
)
$(TR $(TDNW $(LREF until)) $(TD Lazily iterates a range
until a specific value is found.)
)
$(LEADINGROW Comparison
)
$(TR $(TDNW $(LREF cmp)) $(TD $(D cmp("abc", "abcd")) is $(D
-1), $(D cmp("abc", "aba")) is $(D 1), and $(D cmp("abc", "abc")) is
$(D 0).)
)
$(TR $(TDNW $(LREF equal)) $(TD Compares ranges for
element-by-element equality, e.g. $(D equal([1, 2, 3], [1.0, 2.0,
3.0])) returns $(D true).)
)
$(TR $(TDNW $(LREF levenshteinDistance)) $(TD $(D
levenshteinDistance("kitten", "sitting")) returns $(D 3) by using the
$(LUCKY Levenshtein distance _algorithm).)
)
$(TR $(TDNW $(LREF levenshteinDistanceAndPath)) $(TD $(D
levenshteinDistanceAndPath("kitten", "sitting")) returns $(D tuple(3,
"snnnsni")) by using the $(LUCKY Levenshtein distance _algorithm).)
)
$(TR $(TDNW $(LREF max)) $(TD $(D max(3, 4, 2)) returns $(D
4).)
)
$(TR $(TDNW $(LREF min)) $(TD $(D min(3, 4, 2)) returns $(D
2).)
)
$(TR $(TDNW $(LREF mismatch)) $(TD $(D mismatch("oh hi",
"ohayo")) returns $(D tuple(" hi", "ayo")).)
)
$(LEADINGROW Iteration
)
$(TR $(TDNW $(LREF filter)) $(TD $(D filter!"a > 0"([1, -1, 2,
0, -3])) iterates over elements $(D 1), $(D 2), and $(D 0).)
)
$(TR $(TDNW $(LREF filterBidirectional)) $(TD Similar to $(D
filter), but also provides $(D back) and $(D popBack) at a small
increase in cost.)
)
$(TR $(TDNW $(LREF group)) $(TD $(D group([5, 2, 2, 3, 3]))
returns a range containing the tuples $(D tuple(5, 1)),
$(D tuple(2, 2)), and $(D tuple(3, 2)).)
)
$(TR $(TDNW $(LREF joiner)) $(TD $(D joiner(["hello",
"world!"], ";")) returns a range that iterates over the characters $(D
"hello; world!"). No new string is created - the existing inputs are
iterated.)
)
$(TR $(TDNW $(LREF map)) $(TD $(D map!"2 * a"([1, 2, 3]))
lazily returns a range with the numbers $(D 2), $(D 4), $(D 6).)
)
$(TR $(TDNW $(LREF reduce)) $(TD $(D reduce!"a + b"([1, 2, 3,
4])) returns $(D 10).)
)
$(TR $(TDNW $(LREF splitter)) $(TD Lazily splits a range by a
separator.)
)
$(TR $(TDNW $(LREF uniq)) $(TD Iterates over the unique elements
in a range, which is assumed sorted.)
)
$(LEADINGROW Sorting
)
$(TR $(TDNW $(LREF completeSort)) $(TD If $(D a = [10, 20, 30])
and $(D b = [40, 6, 15]), then $(D completeSort(a, b)) leaves $(D a =
[6, 10, 15]) and $(D b = [20, 30, 40]). The range $(D a) must be
sorted prior to the call, and as a result the combination $(D $(XREF
range,chain)(a, b)) is sorted.)
)
$(TR $(TDNW $(LREF isPartitioned)) $(TD $(D isPartitioned!"a <
0"([-1, -2, 1, 0, 2])) returns $(D true) because the predicate is $(D
true) for a portion of the range and $(D false) afterwards.)
)
$(TR $(TDNW $(LREF isSorted)) $(TD $(D isSorted([1, 1, 2, 3]))
returns $(D true).)
)
$(TR $(TDNW $(LREF makeIndex)) $(TD Creates a separate index
for a range.)
)
$(TR $(TDNW $(LREF partialSort)) $(TD If $(D a = [5, 4, 3, 2,
1]), then $(D partialSort(a, 3)) leaves $(D a[0 .. 3] = [1, 2,
3]). The other elements of $(D a) are left in an unspecified order.)
)
$(TR $(TDNW $(LREF partition)) $(TD Partitions a range
according to a predicate.)
)
$(TR $(TDNW $(LREF schwartzSort)) $(TD Sorts with the help of
the $(LUCKY Schwartzian transform).)
)
$(TR $(TDNW $(LREF sort)) $(TD Sorts.)
)
$(TR $(TDNW $(LREF topN)) $(TD Separates the top elements in a
range.)
)
$(TR $(TDNW $(LREF topNCopy)) $(TD Copies out the top elements
of a range.)
)
$(TR $(TDNW $(LREF nextPermutation)) $(TD Computes the next lexicographically
greater permutation of a range in-place.)
)
$(TR $(TDNW $(LREF nextEvenPermutation)) $(TD Computes the next
lexicographically greater even permutation of a range in-place.)
)
$(LEADINGROW Set operations
)
$(TR $(TDNW $(LREF cartesianProduct)) $(TD Computes Cartesian product of two
ranges.)
)
$(TR $(TDNW $(LREF largestPartialIntersection)) $(TD Copies out
the values that occur most frequently in a range of ranges.)
)
$(TR $(TDNW $(LREF largestPartialIntersectionWeighted)) $(TD
Copies out the values that occur most frequently (multiplied by
per-value weights) in a range of ranges.)
)
$(TR $(TDNW $(LREF nWayUnion)) $(TD Computes the union of a set
of sets implemented as a range of sorted ranges.)
)
$(TR $(TDNW $(LREF setDifference)) $(TD Lazily computes the set
difference of two or more sorted ranges.)
)
$(TR $(TDNW $(LREF setIntersection)) $(TD Lazily computes the
intersection of two or more sorted ranges.)
)
$(TR $(TDNW $(LREF setSymmetricDifference)) $(TD Lazily
computes the symmetric set difference of two or more sorted ranges.)
)
$(TR $(TDNW $(LREF setUnion)) $(TD Lazily computes the set
union of two or more sorted ranges.)
)
$(LEADINGROW Mutation
)
$(TR $(TDNW $(LREF bringToFront)) $(TD If $(D a = [1, 2, 3])
and $(D b = [4, 5, 6, 7]), $(D bringToFront(a, b)) leaves $(D a = [4,
5, 6]) and $(D b = [7, 1, 2, 3]).)
)
$(TR $(TDNW $(LREF copy)) $(TD Copies a range to another. If
$(D a = [1, 2, 3]) and $(D b = new int[5]), then $(D copy(a, b))
leaves $(D b = [1, 2, 3, 0, 0]) and returns $(D b[3 .. $]).)
)
$(TR $(TDNW $(LREF fill)) $(TD Fills a range with a pattern,
e.g., if $(D a = new int[3]), then $(D fill(a, 4)) leaves $(D a = [4,
4, 4]) and $(D fill(a, [3, 4])) leaves $(D a = [3, 4, 3]).)
)
$(TR $(TDNW $(LREF initializeAll)) $(TD If $(D a = [1.2, 3.4]),
then $(D initializeAll(a)) leaves $(D a = [double.init,
double.init]).)
)
$(TR $(TDNW $(LREF move)) $(TD $(D move(a, b)) moves $(D a)
into $(D b). $(D move(a)) reads $(D a) destructively.)
)
$(TR $(TDNW $(LREF moveAll)) $(TD Moves all elements from one
range to another.)
)
$(TR $(TDNW $(LREF moveSome)) $(TD Moves as many elements as
possible from one range to another.)
)
$(TR $(TDNW $(LREF reverse)) $(TD If $(D a = [1, 2, 3]), $(D
reverse(a)) changes it to $(D [3, 2, 1]).)
)
$(TR $(TDNW $(LREF swap)) $(TD Swaps two values.)
)
$(TR $(TDNW $(LREF swapRanges)) $(TD Swaps all elements of two
ranges.)
)
$(TR $(TDNW $(LREF uninitializedFill)) $(TD Fills a range
(assumed uninitialized) with a value.)
)
)

Macros:
WIKI = Phobos/StdAlgorithm
MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>

Copyright: Andrei Alexandrescu 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_algorithm.d)
 */
module std.algorithm;
//debug = std_algorithm;

import std.c.string, core.bitop;
import std.array, std.ascii, std.container, std.conv, std.exception,
    std.functional, std.math, std.random, std.range, std.string,
    std.traits, std.typecons, std.typetuple, std.uni, std.utf;

version(unittest)
{
    import std.stdio;
    mixin(dummyRanges);
}

/**
$(D auto map(Range)(Range r) if (isInputRange!(Unqual!Range));)

Implements the homonym function (also known as $(D transform)) present
in many languages of functional flavor. The call $(D map!(fun)(range))
returns a range of which elements are obtained by applying $(D fun(x))
left to right for all $(D x) in $(D range). The original ranges are
not changed. Evaluation is done lazily.

Example:
----
int[] arr1 = [ 1, 2, 3, 4 ];
int[] arr2 = [ 5, 6 ];
auto squares = map!(a => a * a)(chain(arr1, arr2));
assert(equal(squares, [ 1, 4, 9, 16, 25, 36 ]));
----

Multiple functions can be passed to $(D map). In that case, the
element type of $(D map) is a tuple containing one element for each
function.

Example:

----
auto arr1 = [ 1, 2, 3, 4 ];
foreach (e; map!("a + a", "a * a")(arr1))
{
    writeln(e[0], " ", e[1]);
}
----

You may alias $(D map) with some function(s) to a symbol and use
it separately:

----
alias map!(to!string) stringize;
assert(equal(stringize([ 1, 2, 3, 4 ]), [ "1", "2", "3", "4" ]));
----
*/
template map(fun...) if (fun.length >= 1)
{
    auto map(Range)(Range r) if (isInputRange!(Unqual!Range))
    {
        static if (fun.length > 1)
        {
            alias adjoin!(staticMap!(unaryFun, fun)) _fun;
        }
        else
        {
            alias unaryFun!fun _fun;
        }

        return MapResult!(_fun, Range)(r);
    }
}

private struct MapResult(alias fun, Range)
{
    alias Unqual!Range R;
    //alias typeof(fun(.ElementType!R.init)) ElementType;
    R _input;

    static if (isBidirectionalRange!R)
    {
        @property auto ref back()
        {
            return fun(_input.back);
        }

        void popBack()
        {
            _input.popBack();
        }
    }

    this(R input)
    {
        _input = input;
    }

    static if (isInfinite!R)
    {
        // Propagate infinite-ness.
        enum bool empty = false;
    }
    else
    {
        @property bool empty()
        {
            return _input.empty;
        }
    }

    void popFront()
    {
        _input.popFront();
    }

    @property auto ref front()
    {
        return fun(_input.front);
    }

    static if (isRandomAccessRange!R)
    {
        static if (is(typeof(_input[ulong.max])))
            private alias ulong opIndex_t;
        else
            private alias uint opIndex_t;

        auto ref opIndex(opIndex_t index)
        {
            return fun(_input[index]);
        }
    }

    static if (hasLength!R || isSomeString!R)
    {
        @property auto length()
        {
            return _input.length;
        }

        alias length opDollar;
    }

    static if (!isInfinite!R && hasSlicing!R)
    {
        static if (is(typeof(_input[ulong.max .. ulong.max])))
            private alias ulong opSlice_t;
        else
            private alias uint opSlice_t;

        auto opSlice(opSlice_t lowerBound, opSlice_t upperBound)
        {
            return typeof(this)(_input[lowerBound..upperBound]);
        }
    }

    static if (isForwardRange!R)
    {
        @property auto save()
        {
            auto result = this;
            result._input = result._input.save;
            return result;
        }
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    alias map!(to!string) stringize;
    assert(equal(stringize([ 1, 2, 3, 4 ]), [ "1", "2", "3", "4" ]));
    uint counter;
    alias map!((a) { return counter++; }) count;
    assert(equal(count([ 10, 2, 30, 4 ]), [ 0, 1, 2, 3 ]));
    counter = 0;
    adjoin!((a) { return counter++; }, (a) { return counter++; })(1);
    alias map!((a) { return counter++; }, (a) { return counter++; }) countAndSquare;
    //assert(equal(countAndSquare([ 10, 2 ]), [ tuple(0u, 100), tuple(1u, 4) ]));
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] arr1 = [ 1, 2, 3, 4 ];
    const int[] arr1Const = arr1;
    int[] arr2 = [ 5, 6 ];
    auto squares = map!("a * a")(arr1Const);
    assert(squares[$ - 1] == 16);
    assert(equal(squares, [ 1, 4, 9, 16 ][]));
    assert(equal(map!("a * a")(chain(arr1, arr2)), [ 1, 4, 9, 16, 25, 36 ][]));

    // Test the caching stuff.
    assert(squares.back == 16);
    auto squares2 = squares.save;
    assert(squares2.back == 16);

    assert(squares2.front == 1);
    squares2.popFront();
    assert(squares2.front == 4);
    squares2.popBack();
    assert(squares2.front == 4);
    assert(squares2.back == 9);

    assert(equal(map!("a * a")(chain(arr1, arr2)), [ 1, 4, 9, 16, 25, 36 ][]));

    uint i;
    foreach (e; map!("a", "a * a")(arr1))
    {
        assert(e[0] == ++i);
        assert(e[1] == i * i);
    }

    // Test length.
    assert(squares.length == 4);
    assert(map!"a * a"(chain(arr1, arr2)).length == 6);

    // Test indexing.
    assert(squares[0] == 1);
    assert(squares[1] == 4);
    assert(squares[2] == 9);
    assert(squares[3] == 16);

    // Test slicing.
    auto squareSlice = squares[1..squares.length - 1];
    assert(equal(squareSlice, [4, 9][]));
    assert(squareSlice.back == 9);
    assert(squareSlice[1] == 9);

    // Test on a forward range to make sure it compiles when all the fancy
    // stuff is disabled.
    auto fibsSquares = map!"a * a"(recurrence!("a[n-1] + a[n-2]")(1, 1));
    assert(fibsSquares.front == 1);
    fibsSquares.popFront();
    fibsSquares.popFront();
    assert(fibsSquares.front == 4);
    fibsSquares.popFront();
    assert(fibsSquares.front == 9);

    auto repeatMap = map!"a"(repeat(1));
    static assert(isInfinite!(typeof(repeatMap)));

    auto intRange = map!"a"([1,2,3]);
    static assert(isRandomAccessRange!(typeof(intRange)));

    foreach (DummyType; AllDummyRanges)
    {
        DummyType d;
        auto m = map!"a * a"(d);

        static assert(propagatesRangeType!(typeof(m), DummyType));
        assert(equal(m, [1,4,9,16,25,36,49,64,81,100]));
    }

    //Test string access
    string  s1 = "hello world!";
    dstring s2 = "日本語";
    dstring s3 = "hello world!"d;
    auto ms1 = map!(std.ascii.toUpper)(s1);
    auto ms2 = map!(std.ascii.toUpper)(s2);
    auto ms3 = map!(std.ascii.toUpper)(s3);
    static assert(!is(ms1[0])); //narrow strings can't be indexed
    assert(ms2[0] == '日');
    assert(ms3[0] == 'H');
    static assert(!is(ms1[0..1])); //narrow strings can't be sliced
    assert(equal(ms2[0..2], "日本"w));
    assert(equal(ms3[0..2], "HE"));
}
unittest
{
    auto LL = iota(1L, 4L);
    auto m = map!"a*a"(LL);
    assert(equal(m, [1L, 4L, 9L]));
}

/**
$(D auto reduce(Args...)(Args args)
    if (Args.length > 0 && Args.length <= 2 && isIterable!(Args[$ - 1]));)

Implements the homonym function (also known as $(D accumulate), $(D
compress), $(D inject), or $(D foldl)) present in various programming
languages of functional flavor. The call $(D reduce!(fun)(seed,
range)) first assigns $(D seed) to an internal variable $(D result),
also called the accumulator. Then, for each element $(D x) in $(D
range), $(D result = fun(result, x)) gets evaluated. Finally, $(D
result) is returned. The one-argument version $(D reduce!(fun)(range))
works similarly, but it uses the first element of the range as the
seed (the range must be non-empty).

Many aggregate range operations turn out to be solved with $(D reduce)
quickly and easily. The example below illustrates $(D reduce)'s
remarkable power and flexibility.

Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];
// Sum all elements
auto sum = reduce!((a,b) => a + b)(0, arr);
assert(sum == 15);

// Sum again, using a string predicate with "a" and "b"
sum = reduce!"a + b"(0, arr);
assert(sum == 15);

// Compute the maximum of all elements
auto largest = reduce!(max)(arr);
assert(largest == 5);

// Max again, but with Uniform Function Call Syntax (UFCS)
largest = arr.reduce!(max);
assert(largest == 5);

// Compute the number of odd elements
auto odds = reduce!((a,b) => a + (b & 1))(0, arr);
assert(odds == 3);

// Compute the sum of squares
auto ssquares = reduce!((a,b) => a + b * b)(0, arr);
assert(ssquares == 55);

// Chain multiple ranges into seed
int[] a = [ 3, 4 ];
int[] b = [ 100 ];
auto r = reduce!("a + b")(chain(a, b));
assert(r == 107);

// Mixing convertible types is fair game, too
double[] c = [ 2.5, 3.0 ];
auto r1 = reduce!("a + b")(chain(a, b, c));
assert(approxEqual(r1, 112.5));

// To minimize nesting of parentheses, Uniform Function Call Syntax can be used
auto r2 = chain(a, b, c).reduce!("a + b");
assert(approxEqual(r2, 112.5));
----

$(DDOC_SECTION_H Multiple functions:) Sometimes it is very useful to
compute multiple aggregates in one pass. One advantage is that the
computation is faster because the looping overhead is shared. That's
why $(D reduce) accepts multiple functions. If two or more functions
are passed, $(D reduce) returns a $(XREF typecons, Tuple) object with
one member per passed-in function. The number of seeds must be
correspondingly increased.

Example:
----
double[] a = [ 3.0, 4, 7, 11, 3, 2, 5 ];
// Compute minimum and maximum in one pass
auto r = reduce!(min, max)(a);
// The type of r is Tuple!(int, int)
assert(approxEqual(r[0], 2));  // minimum
assert(approxEqual(r[1], 11)); // maximum

// Compute sum and sum of squares in one pass
r = reduce!("a + b", "a + b * b")(tuple(0.0, 0.0), a);
assert(approxEqual(r[0], 35));  // sum
assert(approxEqual(r[1], 233)); // sum of squares
// Compute average and standard deviation from the above
auto avg = r[0] / a.length;
auto stdev = sqrt(r[1] / a.length - avg * avg);
----
 */

template reduce(fun...) if (fun.length >= 1)
{
    auto reduce(Args...)(Args args)
    if (Args.length > 0 && Args.length <= 2 && isIterable!(Args[$ - 1]))
    {
        static if (isInputRange!(Args[$ - 1]))
        {
            static if (Args.length == 2)
            {
                alias args[0] seed;
                alias args[1] r;
                Unqual!(Args[0]) result = seed;
                for (; !r.empty; r.popFront())
                {
                    static if (fun.length == 1)
                    {
                        result = binaryFun!(fun[0])(result, r.front);
                    }
                    else
                    {
                        foreach (i, Unused; Args[0].Types)
                        {
                            result[i] = binaryFun!(fun[i])(result[i], r.front);
                        }
                    }
                }
                return result;
            }
            else
            {
                enforce(!args[$ - 1].empty,
                    "Cannot reduce an empty range w/o an explicit seed value.");
                alias args[0] r;
                static if (fun.length == 1)
                {
                    auto seed = r.front;
                    r.popFront();
                    return reduce(seed, r);
                }
                else
                {
                    static assert(fun.length > 1);
                    typeof(adjoin!(staticMap!(binaryFun, fun))(r.front, r.front))
                        result = void;
                    foreach (i, T; result.Types)
                    {
                        emplace(&result[i], r.front);
                    }
                    r.popFront();
                    return reduce(result, r);
                }
            }
        }
        else
        {   // opApply case.  Coded as a separate case because efficiently
            // handling all of the small details like avoiding unnecessary
            // copying, iterating by dchar over strings, and dealing with the
            // no explicit start value case would become an unreadable mess
            // if these were merged.
            alias args[$ - 1] r;
            alias Args[$ - 1] R;
            alias ForeachType!R E;

            static if (args.length == 2)
            {
                static if (fun.length == 1)
                {
                    auto result = Tuple!(Unqual!(Args[0]))(args[0]);
                }
                else
                {
                    Unqual!(Args[0]) result = args[0];
                }

                enum bool initialized = true;
            }
            else static if (fun.length == 1)
            {
                Tuple!(typeof(binaryFun!fun(E.init, E.init))) result = void;
                bool initialized = false;
            }
            else
            {
                typeof(adjoin!(staticMap!(binaryFun, fun))(E.init, E.init))
                    result = void;
                bool initialized = false;
            }

            // For now, just iterate using ref to avoid unnecessary copying.
            // When Bug 2443 is fixed, this may need to change.
            foreach (ref elem; r)
            {
                if (initialized)
                {
                    foreach (i, T; result.Types)
                    {
                        result[i] = binaryFun!(fun[i])(result[i], elem);
                    }
                }
                else
                {
                    static if (is(typeof(&initialized)))
                    {
                        initialized = true;
                    }

                    foreach (i, T; result.Types)
                    {
                        emplace(&result[i], elem);
                    }
                }
            }

            enforce(initialized,
                "Cannot reduce an empty iterable w/o an explicit seed value.");

            static if (fun.length == 1)
            {
                return result[0];
            }
            else
            {
                return result;
            }
        }
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    double[] a = [ 3, 4 ];
    auto r = reduce!("a + b")(0.0, a);
    assert(r == 7);
    r = reduce!("a + b")(a);
    assert(r == 7);
    r = reduce!(min)(a);
    assert(r == 3);
    double[] b = [ 100 ];
    auto r1 = reduce!("a + b")(chain(a, b));
    assert(r1 == 107);

    // two funs
    auto r2 = reduce!("a + b", "a - b")(tuple(0.0, 0.0), a);
    assert(r2[0] == 7 && r2[1] == -7);
    auto r3 = reduce!("a + b", "a - b")(a);
    assert(r3[0] == 7 && r3[1] == -1);

    a = [ 1, 2, 3, 4, 5 ];
    // Stringize with commas
    string rep = reduce!("a ~ `, ` ~ to!(string)(b)")("", a);
    assert(rep[2 .. $] == "1, 2, 3, 4, 5", "["~rep[2 .. $]~"]");

    // Test the opApply case.
    static struct OpApply
    {
        bool actEmpty;

        int opApply(int delegate(ref int) dg)
        {
            int res;
            if (actEmpty) return res;

            foreach (i; 0..100)
            {
                res = dg(i);
                if (res) break;
            }
            return res;
        }
    }

    OpApply oa;
    auto hundredSum = reduce!"a + b"(iota(100));
    assert(reduce!"a + b"(5, oa) == hundredSum + 5);
    assert(reduce!"a + b"(oa) == hundredSum);
    assert(reduce!("a + b", max)(oa) == tuple(hundredSum, 99));
    assert(reduce!("a + b", max)(tuple(5, 0), oa) == tuple(hundredSum + 5, 99));

    // Test for throwing on empty range plus no seed.
    try {
        reduce!"a + b"([1, 2][0..0]);
        assert(0);
    } catch(Exception) {}

    oa.actEmpty = true;
    try {
        reduce!"a + b"(oa);
        assert(0);
    } catch(Exception) {}
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    const float a = 0.0;
    const float[] b = [ 1.2, 3, 3.3 ];
    float[] c = [ 1.2, 3, 3.3 ];
    auto r = reduce!"a + b"(a, b);
    r = reduce!"a + b"(a, c);
}

/**
Fills $(D range) with a $(D filler).

Example:
----
int[] a = [ 1, 2, 3, 4 ];
fill(a, 5);
assert(a == [ 5, 5, 5, 5 ]);
----
 */
void fill(Range, Value)(Range range, Value filler)
    if (isInputRange!Range && is(typeof(range.front = filler)))
{
    alias ElementType!Range T;

    static if (is(typeof(range[] = filler)))
    {
        range[] = filler;
    }
    else static if (is(typeof(range[] = T(filler))))
    {
        range[] = T(filler);
    }
    else
    {
        for ( ; !range.empty; range.popFront() )
        {
            range.front = filler;
        }
    }
}

unittest
{
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
    alias DummyRange!(ReturnBy.Reference, Length.No, RangeType.Input) InputRange;
    enum filler = uint.max;
    InputRange range;
    fill(range, filler);
    foreach (value; range.arr)
        assert(value == filler);
}
unittest
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
unittest
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

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
int[] b = [ 8, 9 ];
fill(a, b);
assert(a == [ 8, 9, 8, 9, 8 ]);
----
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

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 3, 4, 5 ];
    int[] b = [1, 2];
    fill(a, b);
    assert(a == [ 1, 2, 1, 2, 1 ]);
    // fill should accept InputRange
    alias DummyRange!(ReturnBy.Reference, Length.No, RangeType.Input) InputRange;
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
Fills a range with a value. Assumes that the range does not currently
contain meaningful content. This is of interest for structs that
define copy constructors (for all other types, fill and
uninitializedFill are equivalent).

uninitializedFill will only operate on ranges that expose references to its
members and have assignable elements.

Example:
----
struct S { ... }
S[] s = (cast(S*) malloc(5 * S.sizeof))[0 .. 5];
uninitializedFill(s, 42);
assert(s == [ 42, 42, 42, 42, 42 ]);
----
 */
void uninitializedFill(Range, Value)(Range range, Value filler)
    if (isInputRange!Range && hasLvalueElements!Range && is(typeof(range.front = filler)))
{
    alias ElementType!Range T;
    static if (hasElaborateAssign!T)
        // Must construct stuff by the book
        for (; !range.empty; range.popFront())
            emplace(&range.front(), filler);
    else
        // Doesn't matter whether fill is initialized or not
        return fill(range, filler);
}

deprecated("Cannot reliably call uninitializedFill on range that does not expose references. Use fill instead.")
void uninitializedFill(Range, Value)(Range range, Value filler)
    if (isInputRange!Range && !hasLvalueElements!Range && is(typeof(range.front = filler)))
{
    static assert(hasElaborateAssign!T, "Cannot execute uninitializedFill a range that does not expose references, and whose objects have an elaborate assign.");
    return fill(range, filler);
}

/**
Initializes all elements of a range with their $(D .init)
value. Assumes that the range does not currently contain meaningful
content.

initializeAll will operate on ranges that expose references to its
members and have assignable elements, as well as on (mutable) strings.

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
    alias ElementType!Range T;
    static if (hasElaborateAssign!T)
    {
        //Elaborate opAssign. Must go the memcpy road.
        //We avoid calling emplace here, because our goal is to initialize to
        //the static state of T.init,
        //So we want to avoid any un-necassarilly CC'ing of T.init
        auto p = typeid(T).init().ptr;
        if (p)
            for ( ; !range.empty ; range.popFront() )
                memcpy(&range.front(), p, T.sizeof);
        else
            static if (isDynamicArray!Range)
                memset(range.ptr, 0, range.length * T.sizeof);
            else
                for ( ; !range.empty ; range.popFront() )
                    memset(&range.front(), 0, T.sizeof);
    }
    else
        fill(range, T.init);
}

// ditto
void initializeAll(Range)(Range range)
    if (is(Range == char[]) || is(Range == wchar[]))
{
    alias ElementEncodingType!Range T;
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
        this(this){};
    }
    static struct S4
    {
        int i = 1;
        this(this){};
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

/**
$(D auto filter(Range)(Range rs) if (isInputRange!(Unqual!Range));)

Implements the homonym function present in various programming
languages of functional flavor. The call $(D filter!(predicate)(range))
returns a new range only containing elements $(D x) in $(D range) for
which $(D predicate(x)) is $(D true).

Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];

// Sum all elements
auto small = filter!(a => a < 3)(arr);
assert(equal(small, [ 1, 2 ]));

// Sum again, but with Uniform Function Call Syntax (UFCS)
auto sum = arr.filter!(a => a < 3);
assert(equal(sum, [ 1, 2 ]));

// In combination with chain() to span multiple ranges
int[] a = [ 3, -2, 400 ];
int[] b = [ 100, -101, 102 ];
auto r = chain(a, b).filter!(a => a > 0);
assert(equal(r, [ 3, 400, 100, 102 ]));

// Mixing convertible types is fair game, too
double[] c = [ 2.5, 3.0 ];
auto r1 = chain(c, a, b).filter!(a => cast(int) a != a);
assert(approxEqual(r1, [ 2.5 ]));
----
 */
template filter(alias pred) if (is(typeof(unaryFun!pred)))
{
    auto filter(Range)(Range rs) if (isInputRange!(Unqual!Range))
    {
        return FilterResult!(unaryFun!pred, Range)(rs);
    }
}

private struct FilterResult(alias pred, Range)
{
    alias Unqual!Range R;
    R _input;

    this(R r)
    {
        _input = r;
        while (!_input.empty && !pred(_input.front))
        {
            _input.popFront();
        }
    }

    auto opSlice() { return this; }

    static if (isInfinite!Range)
    {
        enum bool empty = false;
    }
    else
    {
        @property bool empty() { return _input.empty; }
    }

    void popFront()
    {
        do
        {
            _input.popFront();
        } while (!_input.empty && !pred(_input.front));
    }

    @property auto ref front()
    {
        return _input.front;
    }

    static if (isForwardRange!R)
    {
        @property auto save()
        {
            return typeof(this)(_input);
        }
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 3, 4, 2 ];
    auto r = filter!("a > 3")(a);
    static assert(isForwardRange!(typeof(r)));
    assert(equal(r, [ 4 ][]));

    a = [ 1, 22, 3, 42, 5 ];
    auto under10 = filter!("a < 10")(a);
    assert(equal(under10, [1, 3, 5][]));
    static assert(isForwardRange!(typeof(under10)));
    under10.front = 4;
    assert(equal(under10, [4, 3, 5][]));
    under10.front = 40;
    assert(equal(under10, [40, 3, 5][]));
    under10.front = 1;

    auto infinite = filter!"a > 2"(repeat(3));
    static assert(isInfinite!(typeof(infinite)));
    static assert(isForwardRange!(typeof(infinite)));

    foreach (DummyType; AllDummyRanges) {
        DummyType d;
        auto f = filter!"a & 1"(d);
        assert(equal(f, [1,3,5,7,9]));

        static if (isForwardRange!DummyType) {
            static assert(isForwardRange!(typeof(f)));
        }
    }

    // With delegates
    int x = 10;
    int overX(int a) { return a > x; }
    typeof(filter!overX(a)) getFilter()
    {
        return filter!overX(a);
    }
    auto r1 = getFilter();
    assert(equal(r1, [22, 42]));

    // With chain
    auto nums = [0,1,2,3,4];
    assert(equal(filter!overX(chain(a, nums)), [22, 42]));

    // With copying of inner struct Filter to Map
    auto arr = [1,2,3,4,5];
    auto m = map!"a + 1"(filter!"a < 4"(arr));
}

unittest
{
    int[] a = [ 3, 4 ];
    const aConst = a;
    auto r = filter!("a > 3")(aConst);
    assert(equal(r, [ 4 ][]));

    a = [ 1, 22, 3, 42, 5 ];
    auto under10 = filter!("a < 10")(a);
    assert(equal(under10, [1, 3, 5][]));
    assert(equal(under10.save, [1, 3, 5][]));
    assert(equal(under10.save, under10));

    // With copying of inner struct Filter to Map
    auto arr = [1,2,3,4,5];
    auto m = map!"a + 1"(filter!"a < 4"(arr));
}

unittest
{
    assert(equal(compose!(map!"2 * a", filter!"a & 1")([1,2,3,4,5]),
                    [2,6,10]));
    assert(equal(pipe!(filter!"a & 1", map!"2 * a")([1,2,3,4,5]),
            [2,6,10]));
}

unittest
{
    int x = 10;
    int underX(int a) { return a < x; }
    const(int)[] list = [ 1, 2, 10, 11, 3, 4 ];
    assert(equal(filter!underX(list), [ 1, 2, 3, 4 ]));
}

/**
 * $(D auto filterBidirectional(Range)(Range r) if (isBidirectionalRange!(Unqual!Range));)
 *
 * Similar to $(D filter), except it defines a bidirectional
 * range. There is a speed disadvantage - the constructor spends time
 * finding the last element in the range that satisfies the filtering
 * condition (in addition to finding the first one). The advantage is
 * that the filtered range can be spanned from both directions. Also,
 * $(XREF range, retro) can be applied against the filtered range.
 *
Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];
auto small = filterBidirectional!("a < 3")(arr);
assert(small.back == 2);
assert(equal(small, [ 1, 2 ]));
assert(equal(retro(small), [ 2, 1 ]));
// In combination with chain() to span multiple ranges
int[] a = [ 3, -2, 400 ];
int[] b = [ 100, -101, 102 ];
auto r = filterBidirectional!("a > 0")(chain(a, b));
assert(r.back == 102);
----
 */
template filterBidirectional(alias pred)
{
    auto filterBidirectional(Range)(Range r) if (isBidirectionalRange!(Unqual!Range))
    {
        return FilterBidiResult!(unaryFun!pred, Range)(r);
    }
}

private struct FilterBidiResult(alias pred, Range)
{
    alias Unqual!Range R;
    R _input;

    this(R r)
    {
        _input = r;
        while (!_input.empty && !pred(_input.front)) _input.popFront();
        while (!_input.empty && !pred(_input.back)) _input.popBack();
    }

    @property bool empty() { return _input.empty; }

    void popFront()
    {
        do
        {
            _input.popFront();
        } while (!_input.empty && !pred(_input.front));
    }

    @property auto ref front()
    {
        return _input.front;
    }

    void popBack()
    {
        do
        {
            _input.popBack();
        } while (!_input.empty && !pred(_input.back));
    }

    @property auto ref back()
    {
        return _input.back;
    }

    @property auto save()
    {
        return typeof(this)(_input.save);
    }
}

unittest
{
    int[] arr = [ 1, 2, 3, 4, 5 ];
    auto small = filterBidirectional!("a < 3")(arr);
    static assert(isBidirectionalRange!(typeof(small)));
    assert(small.back == 2);
    assert(equal(small, [ 1, 2 ]));
    assert(equal(retro(small), [ 2, 1 ]));
    // In combination with chain() to span multiple ranges
    int[] a = [ 3, -2, 400 ];
    int[] b = [ 100, -101, 102 ];
    auto r = filterBidirectional!("a > 0")(chain(a, b));
    assert(r.back == 102);
}

// move
/**
Moves $(D source) into $(D target) via a destructive
copy. Specifically: $(UL $(LI If $(D hasAliasing!T) is true (see
$(XREF traits, hasAliasing)), then the representation of $(D source)
is bitwise copied into $(D target) and then $(D source = T.init) is
evaluated.)  $(LI Otherwise, $(D target = source) is evaluated.)) See
also $(XREF exception, pointsTo).

Preconditions:
$(D &source == &target || !pointsTo(source, source))
*/
void move(T)(ref T source, ref T target)
{
    assert(!pointsTo(source, source));
    static if (is(T == struct))
    {
        if (&source == &target) return;
        // Most complicated case. Destroy whatever target had in it
        // and bitblast source over it
        static if (hasElaborateDestructor!T) typeid(T).destroy(&target);

        memcpy(&target, &source, T.sizeof);

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
        // static if (is(typeof(source = null)))
        // {
        //     // Nullify the source to help the garbage collector
        //     source = null;
        // }
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
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
    // Can avoid to check aliasing.

    T result = void;
    static if (is(T == struct))
    {
        // Can avoid destructing result.

        memcpy(&result, &source, T.sizeof);

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
tgt) in lockstep in increasing order, calls $(D move(a, b)). Returns
the leftover portion of $(D tgt). Throws an exeption if there is not
enough room in $(D tgt) to acommodate all of $(D src).

Preconditions:
$(D walkLength(src) <= walkLength(tgt))
 */
Range2 moveAll(Range1, Range2)(Range1 src, Range2 tgt)
if (isInputRange!Range1 && isInputRange!Range2
        && is(typeof(move(src.front, tgt.front))))
{
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
when either $(D src) or $(D tgt) have been exhausted. Returns the
leftover portions of the two ranges.
 */
Tuple!(Range1, Range2) moveSome(Range1, Range2)(Range1 src, Range2 tgt)
if (isInputRange!Range1 && isInputRange!Range2
        && is(typeof(move(src.front, tgt.front))))
{
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
Swaps $(D lhs) and $(D rhs). See also $(XREF exception, pointsTo).

Preconditions:

$(D !pointsTo(lhs, lhs) && !pointsTo(lhs, rhs) && !pointsTo(rhs, lhs)
&& !pointsTo(rhs, rhs))
 */
void swap(T)(ref T lhs, ref T rhs) @trusted pure nothrow
if (isMutable!T && !is(typeof(T.init.proxySwap(T.init))))
{
    static if (hasElaborateAssign!T)
    {
      if (&lhs != &rhs) {
        // For structs with non-trivial assignment, move memory directly
        // First check for undue aliasing
        assert(!pointsTo(lhs, rhs) && !pointsTo(rhs, lhs)
            && !pointsTo(lhs, lhs) && !pointsTo(rhs, rhs));
        // Swap bits
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
void swap(T)(T lhs, T rhs) if (is(typeof(T.init.proxySwap(T.init))))
{
    lhs.proxySwap(rhs);
}

unittest
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

unittest
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

unittest
{
    //Bug# 4789
    int[1] s = [1];
    swap(s, s);
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

Example:
---
int foo(int n) { return 1; }
int foo(ref int n) { return 2; }
int bar()(auto ref int x) { return foo(forward!x); }

assert(bar(1) == 1);
int i;
assert(bar(i) == 2);
---

---
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
---
*/
template forward(args...)
{
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

unittest
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

unittest
{
    void foo(int n, ref string s) { s = null; foreach (i; 0..n) s ~= "Hello"; }

    void bar(Args...)(auto ref Args args) { return foo(forward!args); }

    void baz(Args...)(auto ref Args args) { return foo(forward!args[$/2..$], forward!args[0..$/2]); }

    string s;
    bar(1, s);
    assert(s == "Hello");
    baz(s, 2);
    assert(s == "HelloHello");
}

unittest
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

unittest
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

// splitter
/**
Splits a range using an element as a separator. This can be used with
any narrow string type or sliceable range type, but is most popular
with string types.

Two adjacent separators are considered to surround an empty element in
the split range.

If the empty range is given, the result is a range with one empty
element. If a range with one separator is given, the result is a range
with two empty elements.

Example:
---
assert(equal(splitter("hello  world", ' '), [ "hello", "", "world" ]));
int[] a = [ 1, 2, 0, 0, 3, 0, 4, 5, 0 ];
int[][] w = [ [1, 2], [], [3], [4, 5] ];
assert(equal(splitter(a, 0), w));
a = null;
assert(equal(splitter(a, 0), [ (int[]).init ]));
a = [ 0 ];
assert(equal(splitter(a, 0), [ (int[]).init, (int[]).init ]));
a = [ 0, 1 ];
assert(equal(splitter(a, 0), [ [], [1] ]));
----
*/
auto splitter(Range, Separator)(Range r, Separator s)
if (is(typeof(ElementType!Range.init == Separator.init))
        && ((hasSlicing!Range && hasLength!Range) || isNarrowString!Range))
{
    static struct Result
    {
    private:
        Range _input;
        Separator _separator;
        // Do we need hasLength!Range? popFront uses _input.length...
        alias typeof(unsigned(_input.length)) IndexType;
        enum IndexType _unComputed = IndexType.max - 1, _atEnd = IndexType.max;
        IndexType _frontLength = _unComputed;
        IndexType _backLength = _unComputed;

        static if (isBidirectionalRange!Range)
        {
            static IndexType lastIndexOf(Range haystack, Separator needle)
            {
                auto r = haystack.retro().find(needle);
                return r.retro().length - 1;
            }
        }

    public:
        this(Range input, Separator separator)
        {
            _input = input;
            _separator = separator;
        }

        static if (isInfinite!Range)
        {
            enum bool empty = false;
        }
        else
        {
            @property bool empty()
            {
                return _frontLength == _atEnd;
            }
        }

        @property Range front()
        {
            assert(!empty);
            if (_frontLength == _unComputed)
            {
                auto r = _input.find(_separator);
                _frontLength = _input.length - r.length;
            }
            return _input[0 .. _frontLength];
        }

        void popFront()
        {
            assert(!empty);
            if (_frontLength == _unComputed)
            {
                front;
            }
            assert(_frontLength <= _input.length);
            if (_frontLength == _input.length)
            {
                // no more input and need to fetch => done
                _frontLength = _atEnd;

                // Probably don't need this, but just for consistency:
                _backLength = _atEnd;
            }
            else
            {
                _input = _input[_frontLength .. _input.length];
                skipOver(_input, _separator) || assert(false);
                _frontLength = _unComputed;
            }
        }

        static if (isForwardRange!Range)
        {
            @property typeof(this) save()
            {
                auto ret = this;
                ret._input = _input.save;
                return ret;
            }
        }

        static if (isBidirectionalRange!Range)
        {
            @property Range back()
            {
                assert(!empty);
                if (_backLength == _unComputed)
                {
                    immutable lastIndex = lastIndexOf(_input, _separator);
                    if (lastIndex == -1)
                    {
                        _backLength = _input.length;
                    }
                    else
                    {
                        _backLength = _input.length - lastIndex - 1;
                    }
                }
                return _input[_input.length - _backLength .. _input.length];
            }

            void popBack()
            {
                assert(!empty);
                if (_backLength == _unComputed)
                {
                    // evaluate back to make sure it's computed
                    back;
                }
                assert(_backLength <= _input.length);
                if (_backLength == _input.length)
                {
                    // no more input and need to fetch => done
                    _frontLength = _atEnd;
                    _backLength = _atEnd;
                }
                else
                {
                    _input = _input[0 .. _input.length - _backLength];
                    if (!_input.empty && _input.back == _separator)
                    {
                        _input.popBack();
                    }
                    else
                    {
                        assert(false);
                    }
                    _backLength = _unComputed;
                }
            }
        }
    }

    return Result(r, s);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    assert(equal(splitter("hello  world", ' '), [ "hello", "", "world" ]));
    int[] a = [ 1, 2, 0, 0, 3, 0, 4, 5, 0 ];
    int[][] w = [ [1, 2], [], [3], [4, 5], [] ];
    static assert(isForwardRange!(typeof(splitter(a, 0))));

    // foreach (x; splitter(a, 0)) {
    //     writeln("[", x, "]");
    // }
    assert(equal(splitter(a, 0), w));
    a = null;
    assert(equal(splitter(a, 0), [ (int[]).init ][]));
    a = [ 0 ];
    assert(equal(splitter(a, 0), [ (int[]).init, (int[]).init ][]));
    a = [ 0, 1 ];
    assert(equal(splitter(a, 0), [ [], [1] ][]));

    // Thoroughly exercise the bidirectional stuff.
    auto str = "abc abcd abcde ab abcdefg abcdefghij ab ac ar an at ada";
    assert(equal(
        retro(splitter(str, 'a')),
        retro(array(splitter(str, 'a')))
    ));

    // Test interleaving front and back.
    auto split = splitter(str, 'a');
    assert(split.front == "");
    assert(split.back == "");
    split.popBack();
    assert(split.back == "d");
    split.popFront();
    assert(split.front == "bc ");
    assert(split.back == "d");
    split.popFront();
    split.popBack();
    assert(split.back == "t ");
    split.popBack();
    split.popBack();
    split.popFront();
    split.popFront();
    assert(split.front == "b ");
    assert(split.back == "r ");

    foreach (DummyType; AllDummyRanges) {  // Bug 4408
        static if (isRandomAccessRange!DummyType) {
            static assert(isBidirectionalRange!DummyType);
            DummyType d;
            auto s = splitter(d, 5);
            assert(equal(s.front, [1,2,3,4]));
            assert(equal(s.back, [6,7,8,9,10]));

            auto s2 = splitter(d, [4, 5]);
            assert(equal(s2.front, [1,2,3]));
            assert(equal(s2.back, [6,7,8,9,10]));
        }
    }
}
unittest
{
    auto L = retro(iota(1L, 10L));
    auto s = splitter(L, 5L);
    assert(equal(s.front, [9L, 8L, 7L, 6L]));
    s.popFront();
    assert(equal(s.front, [4L, 3L, 2L, 1L]));
    s.popFront();
    assert(s.empty);
}

/**
Splits a range using another range as a separator. This can be used
with any narrow string type or sliceable range type, but is most popular
with string types.
 */
auto splitter(Range, Separator)(Range r, Separator s)
if (is(typeof(Range.init.front == Separator.init.front) : bool)
        && (hasSlicing!Range || isNarrowString!Range))
{
    static struct Result
    {
    private:
        Range _input;
        Separator _separator;
        alias typeof(unsigned(_input.length)) RIndexType;
        // _frontLength == size_t.max means empty
        RIndexType _frontLength = RIndexType.max;
        static if (isBidirectionalRange!Range)
            RIndexType _backLength = RIndexType.max;

        @property auto separatorLength() { return _separator.length; }

        void ensureFrontLength()
        {
            if (_frontLength != _frontLength.max) return;
            assert(!_input.empty);
            // compute front length
            _frontLength = _input.length - find(_input, _separator).length;
            static if (isBidirectionalRange!Range)
                if (_frontLength == _input.length) _backLength = _frontLength;
        }

        void ensureBackLength()
        {
            static if (isBidirectionalRange!Range)
                if (_backLength != _backLength.max) return;
            assert(!_input.empty);
            // compute back length
            static if (isBidirectionalRange!Range)
            {
                _backLength = _input.length -
                    find(retro(_input), retro(_separator)).source.length;
            }
        }

    public:
        this(Range input, Separator separator)
        {
            _input = input;
            _separator = separator;
        }

        @property Range front()
        {
            assert(!empty);
            ensureFrontLength();
            return _input[0 .. _frontLength];
        }

        static if (isInfinite!Range)
        {
            enum bool empty = false;  // Propagate infiniteness
        }
        else
        {
            @property bool empty()
            {
                return _frontLength == RIndexType.max && _input.empty;
            }
        }

        void popFront()
        {
            assert(!empty);
            ensureFrontLength();
            if (_frontLength == _input.length)
            {
                // done, there's no separator in sight
                _input = _input[_frontLength .. _frontLength];
                _frontLength = _frontLength.max;
                static if (isBidirectionalRange!Range)
                    _backLength = _backLength.max;
                return;
            }
            if (_frontLength + separatorLength == _input.length)
            {
                // Special case: popping the first-to-last item; there is
                // an empty item right after this.
                _input = _input[_input.length .. _input.length];
                _frontLength = 0;
                static if (isBidirectionalRange!Range)
                    _backLength = 0;
                return;
            }
            // Normal case, pop one item and the separator, get ready for
            // reading the next item
            _input = _input[_frontLength + separatorLength .. _input.length];
            // mark _frontLength as uninitialized
            _frontLength = _frontLength.max;
        }

        static if (isForwardRange!Range)
        {
            @property typeof(this) save()
            {
                auto ret = this;
                ret._input = _input.save;
                return ret;
            }
        }

// Bidirectional functionality as suggested by Brad Roberts.
        static if (isBidirectionalRange!Range)
        {
            @property Range back()
            {
                ensureBackLength();
                return _input[_input.length - _backLength .. _input.length];
            }

            void popBack()
            {
                ensureBackLength();
                if (_backLength == _input.length)
                {
                    // done
                    _input = _input[0 .. 0];
                    _frontLength = _frontLength.max;
                    _backLength = _backLength.max;
                    return;
                }
                if (_backLength + separatorLength == _input.length)
                {
                    // Special case: popping the first-to-first item; there is
                    // an empty item right before this. Leave the separator in.
                    _input = _input[0 .. 0];
                    _frontLength = 0;
                    _backLength = 0;
                    return;
                }
                // Normal case
                _input = _input[0 .. _input.length - _backLength - separatorLength];
                _backLength = _backLength.max;
            }
        }
    }

    return Result(r, s);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto s = ",abc, de, fg,hi,";
    auto sp0 = splitter(s, ',');
    // //foreach (e; sp0) writeln("[", e, "]");
    assert(equal(sp0, ["", "abc", " de", " fg", "hi", ""][]));

    auto s1 = ", abc, de,  fg, hi, ";
    auto sp1 = splitter(s1, ", ");
    //foreach (e; sp1) writeln("[", e, "]");
    assert(equal(sp1, ["", "abc", "de", " fg", "hi", ""][]));
    static assert(isForwardRange!(typeof(sp1)));

    int[] a = [ 1, 2, 0, 3, 0, 4, 5, 0 ];
    int[][] w = [ [1, 2], [3], [4, 5], [] ];
    uint i;
    foreach (e; splitter(a, 0))
    {
        assert(i < w.length);
        assert(e == w[i++]);
    }
    assert(i == w.length);
    // // Now go back
    // auto s2 = splitter(a, 0);

    // foreach (e; retro(s2))
    // {
    //     assert(i > 0);
    //     assert(equal(e, w[--i]), text(e));
    // }
    // assert(i == 0);

    wstring names = ",peter,paul,jerry,";
    auto words = split(names, ",");
    assert(walkLength(words) == 5, text(walkLength(words)));
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto s6 = ",";
    auto sp6 = splitter(s6, ',');
    foreach (e; sp6)
    {
        //writeln("{", e, "}");
    }
    assert(equal(sp6, ["", ""][]));
}

auto splitter(alias isTerminator, Range)(Range input)
if (is(typeof(unaryFun!(isTerminator)(ElementType!(Range).init))))
{
    return SplitterResult!(unaryFun!isTerminator, Range)(input);
}

private struct SplitterResult(alias isTerminator, Range)
{
    private Range _input;
    private size_t _end;

    this(Range input)
    {
        _input = input;
        if (_input.empty)
        {
            _end = _end.max;
        }
        else
        {
            // Chase first terminator
            while (_end < _input.length && !isTerminator(_input[_end]))
            {
                ++_end;
            }
        }
    }

    static if (isInfinite!Range)
    {
        enum bool empty = false;  // Propagate infiniteness.
    }
    else
    {
        @property bool empty()
        {
            return _end == _end.max;
        }
    }

    @property Range front()
    {
        assert(!empty);
        return _input[0 .. _end];
    }

    void popFront()
    {
        assert(!empty);
        if (_input.empty)
        {
            _end = _end.max;
            return;
        }
        // Skip over existing word
        _input = _input[_end .. _input.length];
        // Skip terminator
        for (;;)
        {
            if (_input.empty)
            {
                // Nothing following the terminator - done
                _end = _end.max;
                return;
            }
            if (!isTerminator(_input.front))
            {
                // Found a legit next field
                break;
            }
            _input.popFront();
        }
        assert(!_input.empty && !isTerminator(_input.front));
        // Prepare _end
        _end = 1;
        while (_end < _input.length && !isTerminator(_input[_end]))
        {
            ++_end;
        }
    }

    static if (isForwardRange!Range)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret._input = _input.save;
            return ret;
        }
    }
}

unittest
{
    auto L = iota(1L, 10L);
    auto s = splitter(L, [5L, 6L]);
    assert(equal(s.front, [1L, 2L, 3L, 4L]));
    s.popFront();
    assert(equal(s.front, [7L, 8L, 9L]));
    s.popFront();
    assert(s.empty);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    void compare(string sentence, string[] witness)
    {
        foreach (word; splitter!"a == ' '"(sentence))
        {
            assert(word == witness.front, word);
            witness.popFront();
        }
        assert(witness.empty, witness[0]);
    }

    compare(" Mary    has a little lamb.   ",
            ["", "Mary", "has", "a", "little", "lamb."]);
    compare("Mary    has a little lamb.   ",
            ["Mary", "has", "a", "little", "lamb."]);
    compare("Mary    has a little lamb.",
            ["Mary", "has", "a", "little", "lamb."]);
    compare("", []);
    compare(" ", [""]);

    static assert(isForwardRange!(typeof(splitter!"a == ' '"("ABC"))));

    foreach (DummyType; AllDummyRanges)
    {
        static if (isRandomAccessRange!DummyType)
        {
            auto rangeSplit = splitter!"a == 5"(DummyType.init);
            assert(equal(rangeSplit.front, [1,2,3,4]));
            rangeSplit.popFront();
            assert(equal(rangeSplit.front, [6,7,8,9,10]));
        }
    }
}

auto splitter(Range)(Range input)
if (isSomeString!Range)
{
    return splitter!(std.uni.isWhite)(input);
}

unittest
{
    // TDPL example, page 8
    uint[string] dictionary;
    char[][3] lines;
    lines[0] = "line one".dup;
    lines[1] = "line \ttwo".dup;
    lines[2] = "yah            last   line\ryah".dup;
    foreach (line; lines) {
       foreach (word; splitter(strip(line))) {
            if (word in dictionary) continue; // Nothing to do
            auto newID = dictionary.length;
            dictionary[to!string(word)] = cast(uint)newID;
        }
    }
    assert(dictionary.length == 5);
    assert(dictionary["line"]== 0);
    assert(dictionary["one"]== 1);
    assert(dictionary["two"]== 2);
    assert(dictionary["yah"]== 3);
    assert(dictionary["last"]== 4);
}

// joiner
/**
Lazily joins a range of ranges with a separator. The separator itself
is a range. If you do not provide a separator, then the ranges are
joined directly without anything in between them.

Example:
----
assert(equal(joiner([""], "xyz"), ""));
assert(equal(joiner(["", ""], "xyz"), "xyz"));
assert(equal(joiner(["", "abc"], "xyz"), "xyzabc"));
assert(equal(joiner(["abc", ""], "xyz"), "abcxyz"));
assert(equal(joiner(["abc", "def"], "xyz"), "abcxyzdef"));
assert(equal(joiner(["Mary", "has", "a", "little", "lamb"], "..."),
  "Mary...has...a...little...lamb"));
assert(equal(joiner(["abc", "def"]), "abcdef"));
----
 */
auto joiner(RoR, Separator)(RoR r, Separator sep)
if (isInputRange!RoR && isInputRange!(ElementType!RoR)
        && isForwardRange!Separator
        && is(ElementType!Separator : ElementType!(ElementType!RoR)))
{
    static struct Result
    {
        private RoR _items;
        private ElementType!RoR _current;
        private Separator _sep, _currentSep;

        // This is a mixin instead of a function for the following reason (as
        // explained by Kenji Hara): "This is necessary from 2.061.  If a
        // struct has a nested struct member, it must be directly initialized
        // in its constructor to avoid leaving undefined state.  If you change
        // setItem to a function, the initialization of _current field is
        // wrapped into private member function, then compiler could not detect
        // that is correctly initialized while constructing.  To avoid the
        // compiler error check, string mixin is used."
        private enum setItem =
        q{
            if (!_items.empty)
            {
                // If we're exporting .save, we must not consume any of the
                // subranges, since RoR.save does not guarantee that the states
                // of the subranges are also saved.
                static if (isForwardRange!RoR &&
                           isForwardRange!(ElementType!RoR))
                    _current = _items.front.save;
                else
                    _current = _items.front;
            }
        };

        private void useSeparator()
        {
            // Separator must always come after an item.
            assert(_currentSep.empty && !_items.empty,
                    "joiner: internal error");
            _items.popFront();

            // If there are no more items, we're done, since separators are not
            // terminators.
            if (_items.empty) return;

            if (_sep.empty)
            {
                // Advance to the next range in the
                // input
                while (_items.front.empty)
                {
                    _items.popFront();
                    if (_items.empty) return;
                }
                mixin(setItem);
            }
            else
            {
                _currentSep = _sep.save;
                assert(!_currentSep.empty);
            }
        }

        private enum useItem =
        q{
            // FIXME: this will crash if either _currentSep or _current are
            // class objects, because .init is null when the ctor invokes this
            // mixin.
            //assert(_currentSep.empty && _current.empty,
            //        "joiner: internal error");

            // Use the input
            if (_items.empty) return;
            mixin(setItem);
            if (_current.empty)
            {
                // No data in the current item - toggle to use the separator
                useSeparator();
            }
        };

        this(RoR items, Separator sep)
        {
            _items = items;
            _sep = sep;
            mixin(useItem); // _current should be initialized in place
        }

        @property auto empty()
        {
            return _items.empty;
        }

        @property ElementType!(ElementType!RoR) front()
        {
            if (!_currentSep.empty) return _currentSep.front;
            assert(!_current.empty);
            return _current.front;
        }

        void popFront()
        {
            assert(!_items.empty);
            // Using separator?
            if (!_currentSep.empty)
            {
                _currentSep.popFront();
                if (!_currentSep.empty) return;
                mixin(useItem);
            }
            else
            {
                // we're using the range
                _current.popFront();
                if (!_current.empty) return;
                useSeparator();
            }
        }

        static if (isForwardRange!RoR && isForwardRange!(ElementType!RoR))
        {
            @property auto save()
            {
                Result copy = this;
                copy._items = _items.save;
                copy._current = _current.save;
                copy._sep = _sep.save;
                copy._currentSep = _currentSep.save;
                return copy;
            }
        }
    }
    return Result(r, sep);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    static assert(isInputRange!(typeof(joiner([""], ""))));
    static assert(isForwardRange!(typeof(joiner([""], ""))));
    assert(equal(joiner([""], "xyz"), ""), text(joiner([""], "xyz")));
    assert(equal(joiner(["", ""], "xyz"), "xyz"), text(joiner(["", ""], "xyz")));
    assert(equal(joiner(["", "abc"], "xyz"), "xyzabc"));
    assert(equal(joiner(["abc", ""], "xyz"), "abcxyz"));
    assert(equal(joiner(["abc", "def"], "xyz"), "abcxyzdef"));
    assert(equal(joiner(["Mary", "has", "a", "little", "lamb"], "..."),
                    "Mary...has...a...little...lamb"));
    assert(equal(joiner(["abc", "def"]), "abcdef"));
}

unittest
{
    // joiner() should work for non-forward ranges too.
    InputRange!string r = inputRangeObject(["abc", "def"]);
    assert (equal(joiner(r, "xyz"), "abcxyzdef"));
}

unittest
{
    // Related to issue 8061
    auto r = joiner([
        inputRangeObject("abc"),
        inputRangeObject("def"),
    ], "-*-");

    assert(equal(r, "abc-*-def"));

    // Test case where separator is specified but is empty.
    auto s = joiner([
        inputRangeObject("abc"),
        inputRangeObject("def"),
    ], "");

    assert(equal(s, "abcdef"));

    // Test empty separator with some empty elements
    auto t = joiner([
        inputRangeObject("abc"),
        inputRangeObject(""),
        inputRangeObject("def"),
        inputRangeObject(""),
    ], "");

    assert(equal(t, "abcdef"));

    // Test empty elements with non-empty separator
    auto u = joiner([
        inputRangeObject(""),
        inputRangeObject("abc"),
        inputRangeObject(""),
        inputRangeObject("def"),
        inputRangeObject(""),
    ], "+-");

    assert(equal(u, "+-abc+-+-def+-"));
}

unittest
{
    // Transience correctness test
    struct TransientRange
    {
        int[][] src;
        int[] buf;

        this(int[][] _src)
        {
            src = _src;
            buf.length = 100;
        }
        @property bool empty() { return src.empty; }
        @property int[] front()
        {
            assert(src.front.length <= buf.length);
            buf[0 .. src.front.length] = src.front[0..$];
            return buf[0 .. src.front.length];
        }
        void popFront() { src.popFront(); }
    }

    // Test embedded empty elements
    auto tr1 = TransientRange([[], [1,2,3], [], [4]]);
    assert(equal(joiner(tr1, [0]), [0,1,2,3,0,0,4]));

    // Test trailing empty elements
    auto tr2 = TransientRange([[], [1,2,3], []]);
    assert(equal(joiner(tr2, [0]), [0,1,2,3,0]));

    // Test no empty elements
    auto tr3 = TransientRange([[1,2], [3,4]]);
    assert(equal(joiner(tr3, [0,1]), [1,2,0,1,3,4]));

    // Test consecutive empty elements
    auto tr4 = TransientRange([[1,2], [], [], [], [3,4]]);
    assert(equal(joiner(tr4, [0,1]), [1,2,0,1,0,1,0,1,0,1,3,4]));

    // Test consecutive trailing empty elements
    auto tr5 = TransientRange([[1,2], [3,4], [], []]);
    assert(equal(joiner(tr5, [0,1]), [1,2,0,1,3,4,0,1,0,1]));
}

/// Ditto
auto joiner(RoR)(RoR r)
if (isInputRange!RoR && isInputRange!(ElementType!RoR))
{
    static struct Result
    {
    private:
        RoR _items;
        ElementType!RoR _current;
        enum prepare =
        q{
            // Skip over empty subranges.
            if (_items.empty) return;
            while (_items.front.empty)
            {
                _items.popFront();
                if (_items.empty) return;
            }
            // We cannot export .save method unless we ensure subranges are not
            // consumed when a .save'd copy of ourselves is iterated over. So
            // we need to .save each subrange we traverse.
            static if (isForwardRange!RoR && isForwardRange!(ElementType!RoR))
                _current = _items.front.save;
            else
                _current = _items.front;
        };
    public:
        this(RoR r)
        {
            _items = r;
            mixin(prepare); // _current should be initialized in place
        }
        static if (isInfinite!RoR)
        {
            enum bool empty = false;
        }
        else
        {
            @property auto empty()
            {
                return _items.empty;
            }
        }
        @property auto ref front()
        {
            assert(!empty);
            return _current.front;
        }
        void popFront()
        {
            assert(!_current.empty);
            _current.popFront();
            if (_current.empty)
            {
                assert(!_items.empty);
                _items.popFront();
                mixin(prepare);
            }
        }
        static if (isForwardRange!RoR && isForwardRange!(ElementType!RoR))
        {
            @property auto save()
            {
                Result copy = this;
                copy._items = _items.save;
                copy._current = _current.save;
                return copy;
            }
        }
    }
    return Result(r);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    static assert(isInputRange!(typeof(joiner([""]))));
    static assert(isForwardRange!(typeof(joiner([""]))));
    assert(equal(joiner([""]), ""));
    assert(equal(joiner(["", ""]), ""));
    assert(equal(joiner(["", "abc"]), "abc"));
    assert(equal(joiner(["abc", ""]), "abc"));
    assert(equal(joiner(["abc", "def"]), "abcdef"));
    assert(equal(joiner(["Mary", "has", "a", "little", "lamb"]),
                    "Maryhasalittlelamb"));
    assert(equal(joiner(std.range.repeat("abc", 3)), "abcabcabc"));

    // joiner allows in-place mutation!
    auto a = [ [1, 2, 3], [42, 43] ];
    auto j = joiner(a);
    j.front = 44;
    assert(a == [ [44, 2, 3], [42, 43] ]);

    // bugzilla 8240
    assert(equal(joiner([inputRangeObject("")]), ""));

    // issue 8792
    auto b = [[1], [2], [3]];
    auto jb = joiner(b);
    auto js = jb.save;
    assert(equal(jb, js));

    auto js2 = jb.save;
    jb.popFront();
    assert(!equal(jb, js));
    assert(equal(js2, js));
    js.popFront();
    assert(equal(jb, js));
    assert(!equal(js2, js));
}

unittest
{
    struct TransientRange
    {
        int[] _buf;
        int[][] _values;
        this(int[][] values)
        {
            _values = values;
            _buf = new int[128];
        }
        @property bool empty()
        {
            return _values.length == 0;
        }
        @property auto front()
        {
            foreach (i; 0 .. _values.front.length)
            {
                _buf[i] = _values[0][i];
            }
            return _buf[0 .. _values.front.length];
        }
        void popFront()
        {
            _values = _values[1 .. $];
        }
    }

    auto rr = TransientRange([[1,2], [3,4,5], [], [6,7]]);

    // Can't use array() or equal() directly because they fail with transient
    // .front.
    int[] result;
    foreach (c; rr.joiner()) {
        result ~= c;
    }

    assert(equal(result, [1,2,3,4,5,6,7]));
}

// Temporarily disable this unittest due to issue 9131 on OSX/64.
version = Issue9131;
version(Issue9131) {} else
unittest
{
    struct TransientRange
    {
        dchar[128] _buf;
        dstring[] _values;
        this(dstring[] values)
        {
            _values = values;
        }
        @property bool empty()
        {
            return _values.length == 0;
        }
        @property auto front()
        {
            foreach (i; 0 .. _values.front.length)
            {
                _buf[i] = _values[0][i];
            }
            return _buf[0 .. _values.front.length];
        }
        void popFront()
        {
            _values = _values[1 .. $];
        }
    }

    auto rr = TransientRange(["abc"d, "12"d, "def"d, "34"d]);

    // Can't use array() or equal() directly because they fail with transient
    // .front.
    dchar[] result;
    foreach (c; rr.joiner()) {
        result ~= c;
    }

    assert(equal(result, "abc12def34"d),
        "Unexpected result: '%s'"d.format(result));
}

// Issue 8061
unittest
{
    auto r = joiner([inputRangeObject("ab"), inputRangeObject("cd")]);
    assert(isForwardRange!(typeof(r)));

    auto str = to!string(r);
    assert(str == "abcd");
}

// uniq
/**
Iterates unique consecutive elements of the given range (functionality
akin to the $(WEB wikipedia.org/wiki/_Uniq, _uniq) system
utility). Equivalence of elements is assessed by using the predicate
$(D pred), by default $(D "a == b"). If the given range is
bidirectional, $(D uniq) also yields a bidirectional range.

Example:
----
int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
assert(equal(uniq(arr), [ 1, 2, 3, 4, 5 ][]));
----
*/
auto uniq(alias pred = "a == b", Range)(Range r)
if (isInputRange!Range && is(typeof(binaryFun!pred(r.front, r.front)) == bool))
{
    return UniqResult!(binaryFun!pred, Range)(r);
}

private struct UniqResult(alias pred, Range)
{
    Range _input;

    this(Range input)
    {
        _input = input;
    }

    auto opSlice()
    {
        return this;
    }

    void popFront()
    {
        auto last = _input.front;
        do
        {
            _input.popFront();
        }
        while (!_input.empty && pred(last, _input.front));
    }

    @property ElementType!Range front() { return _input.front; }

    static if (isBidirectionalRange!Range)
    {
        void popBack()
        {
            auto last = _input.back;
            do
            {
                _input.popBack();
            }
            while (!_input.empty && pred(last, _input.back));
        }

        @property ElementType!Range back() { return _input.back; }
    }

    static if (isInfinite!Range)
    {
        enum bool empty = false;  // Propagate infiniteness.
    }
    else
    {
        @property bool empty() { return _input.empty; }
    }

    static if (isForwardRange!Range) {
        @property typeof(this) save() {
            return typeof(this)(_input.save);
        }
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
    auto r = uniq(arr);
    static assert(isForwardRange!(typeof(r)));

    assert(equal(r, [ 1, 2, 3, 4, 5 ][]));
    assert(equal(retro(r), retro([ 1, 2, 3, 4, 5 ][])));

    foreach (DummyType; AllDummyRanges) {
        DummyType d;
        auto u = uniq(d);
        assert(equal(u, [1,2,3,4,5,6,7,8,9,10]));

        static assert(d.rt == RangeType.Input || isForwardRange!(typeof(u)));

        static if (d.rt >= RangeType.Bidirectional) {
            assert(equal(retro(u), [10,9,8,7,6,5,4,3,2,1]));
        }
    }
}

// group
/**
Similarly to $(D uniq), $(D group) iterates unique consecutive
elements of the given range. The element type is $(D
Tuple!(ElementType!R, uint)) because it includes the count of
equivalent elements seen. Equivalence of elements is assessed by using
the predicate $(D pred), by default $(D "a == b").

$(D Group) is an input range if $(D R) is an input range, and a
forward range in all other cases.

Example:
----
int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
assert(equal(group(arr), [ tuple(1, 1u), tuple(2, 4u), tuple(3, 1u),
    tuple(4, 3u), tuple(5, 1u) ][]));
----
*/
struct Group(alias pred, R) if (isInputRange!R)
{
    private R _input;
    private Tuple!(ElementType!R, uint) _current;
    private alias binaryFun!pred comp;

    this(R input)
    {
        _input = input;
        if (!_input.empty) popFront();
    }

    void popFront()
    {
        if (_input.empty)
        {
            _current[1] = 0;
        }
        else
        {
            _current = tuple(_input.front, 1u);
            _input.popFront();
            while (!_input.empty && comp(_current[0], _input.front))
            {
                ++_current[1];
                _input.popFront();
            }
        }
    }

    static if (isInfinite!R)
    {
        enum bool empty = false;  // Propagate infiniteness.
    }
    else
    {
        @property bool empty()
        {
            return _current[1] == 0;
        }
    }

    @property ref Tuple!(ElementType!R, uint) front()
    {
        assert(!empty);
        return _current;
    }

    static if (isForwardRange!R) {
        @property typeof(this) save() {
            typeof(this) ret = this;
            ret._input = this._input.save;
            ret._current = this._current;
            return ret;
        }
    }
}

/// Ditto
Group!(pred, Range) group(alias pred = "a == b", Range)(Range r)
{
    return typeof(return)(r);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
    assert(equal(group(arr), [ tuple(1, 1u), tuple(2, 4u), tuple(3, 1u),
                            tuple(4, 3u), tuple(5, 1u) ][]));
    static assert(isForwardRange!(typeof(group(arr))));

    foreach (DummyType; AllDummyRanges) {
        DummyType d;
        auto g = group(d);

        static assert(d.rt == RangeType.Input || isForwardRange!(typeof(g)));

        assert(equal(g, [tuple(1, 1u), tuple(2, 1u), tuple(3, 1u), tuple(4, 1u),
            tuple(5, 1u), tuple(6, 1u), tuple(7, 1u), tuple(8, 1u),
            tuple(9, 1u), tuple(10, 1u)]));
    }
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
pred). See also $(WEB sgi.com/tech/stl/_find.html, STL's _find).

To _find the last occurence of $(D needle) in $(D haystack), call $(D
find(retro(haystack), needle)). See also $(XREF range, retro).

Params:

haystack = The range searched in.

needle = The element searched for.

Constraints:

$(D isInputRange!R && is(typeof(binaryFun!pred(haystack.front, needle)
: bool)))

Returns:

$(D haystack) advanced such that $(D binaryFun!pred(haystack.front,
needle)) is $(D true) (if no such position exists, returns $(D
haystack) after exhaustion).

Example:

----
assert(find("hello, world", ',') == ", world");
assert(find([1, 2, 3, 5], 4) == []);
assert(find(SList!int(1, 2, 3, 4, 5)[], 4) == SList!int(4, 5)[]);
assert(find!"a > b"([1, 2, 3, 5], 2) == [3, 5]);

auto a = [ 1, 2, 3 ];
assert(find(a, 5).empty);       // not found
assert(!find(a, 2).empty);      // found

// Case-insensitive find of a string
string[] s = [ "Hello", "world", "!" ];
assert(!find!("toLower(a) == b")(s, "hello").empty);
----
 */
R find(alias pred = "a == b", R, E)(R haystack, E needle)
if (isInputRange!R &&
        is(typeof(binaryFun!pred(haystack.front, needle)) : bool))
{
    for (; !haystack.empty; haystack.popFront())
    {
        if (binaryFun!pred(haystack.front, needle)) break;
    }
    return haystack;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto lst = SList!int(1, 2, 5, 7, 3);
    assert(lst.front == 1);
    auto r = find(lst[], 5);
    assert(equal(r, SList!int(5, 7, 3)[]));
    assert(find([1, 2, 3, 5], 4).empty);
}

/**
Finds a forward range in another. Elements are compared for
equality. Performs $(BIGOH walkLength(haystack) * walkLength(needle))
comparisons in the worst case. Specializations taking advantage of
bidirectional or random access (where present) may accelerate search
depending on the statistics of the two ranges' content.

Params:

haystack = The range searched in.

needle = The range searched for.

Constraints:

$(D isForwardRange!R1 && isForwardRange!R2 &&
is(typeof(binaryFun!pred(haystack.front, needle.front) : bool)))

Returns:

$(D haystack) advanced such that $(D needle) is a prefix of it (if no
such position exists, returns $(D haystack) advanced to termination).

----
assert(find("hello, world", "World").empty);
assert(find("hello, world", "wo") == "world");
assert(find([1, 2, 3, 4], SList!(2, 3)[]) == [2, 3, 4]);
----
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
        alias Select!(haystack[0].sizeof == 1, ubyte[],
                Select!(haystack[0].sizeof == 2, ushort[], uint[]))
            Representation;
        // Will use the array specialization
        return cast(R1) .find!(pred, Representation, Representation)
            (cast(Representation) haystack, cast(Representation) needle);
    }
    else
    {
        return simpleMindedFind!pred(haystack, needle);
    }
}

unittest
{
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
    for (auto i = needle.save; !i.empty && !binaryFun!pred(i.back, needleBack);
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

unittest
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

unittest
{
    assert(find([ 1, 2, 3 ], SList!int(2, 3)[]) == [ 2, 3 ]);
    assert(find([ 1, 2, 1, 2, 3, 3 ], SList!int(2, 3)[]) == [ 2, 3, 3 ]);
}

//Bug# 8334
unittest
{
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
        static if (hasLength!R2)
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

unittest
{
    // Test simpleMindedFind for the case where both haystack and needle have
    // length.
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    struct CustomString
    {
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

haystack = The target of the search. Must be an $(GLOSSARY input
range). If any of $(D needles) is a range with elements comparable to
elements in $(D haystack), then $(D haystack) must be a $(GLOSSARY
forward range) such that the search can backtrack.

needles = One or more items to search for. Each of $(D needles) must
be either comparable to one element in $(D haystack), or be itself a
$(GLOSSARY forward range) with elements comparable with elements in
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

Example:
----
int[] a = [ 1, 4, 2, 3 ];
assert(find(a, 4) == [ 4, 2, 3 ]);
assert(find(a, [ 1, 4 ]) == [ 1, 4, 2, 3 ]);
assert(find(a, [ 1, 3 ], 4) == tuple([ 4, 2, 3 ], 2));
// Mixed types allowed if comparable
assert(find(a, 5, [ 1.2, 3.5 ], 2.0, [ 1 ]) == tuple([ 2, 3 ], 3));
----

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

unittest
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

unittest
{
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

unittest
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

unittest
{
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

/// Ditto
struct BoyerMooreFinder(alias pred, Range)
{
private:
    size_t skip[];
    ptrdiff_t[ElementType!(Range)] occ;
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

    alias length opDollar;
}

/// Ditto
BoyerMooreFinder!(binaryFun!(pred), Range) boyerMooreFinder
(alias pred = "a == b", Range)
(Range needle) if (isRandomAccessRange!(Range) || isSomeString!Range)
{
    return typeof(return)(needle);
}

// Oddly this is not disabled by bug 4759
Range1 find(Range1, alias pred, Range2)(
    Range1 haystack, BoyerMooreFinder!(pred, Range2) needle)
{
    return needle.beFound(haystack);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    string h = "/homes/aalexand/d/dmd/bin/../lib/libphobos.a(dmain2.o)"
        "(.gnu.linkonce.tmain+0x74): In function `main' undefined reference"
        " to `_Dmain':";
    string[] ns = ["libphobos", "function", " undefined", "`", ":"];
    foreach (n ; ns) {
        auto p = find(h, boyerMooreFinder(n));
        assert(!p.empty);
    }

    int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    //writeln(find(a, boyerMooreFinder(b)));
    assert(find(a, boyerMooreFinder(b)) == [ 1, 2, 3, 4, 5 ]);
    assert(find(b, boyerMooreFinder(a)).empty);
}

unittest
{
    auto bm = boyerMooreFinder("for");
    auto match = find("Moor", bm);
    assert(match.empty);
}

/**
Advances the input range $(D haystack) by calling $(D haystack.popFront)
until either $(D pred(haystack.front)), or $(D
haystack.empty). Performs $(BIGOH haystack.length) evaluations of $(D
pred). See also $(WEB sgi.com/tech/stl/find_if.html, STL's find_if).

To find the last element of a bidirectional $(D haystack) satisfying
$(D pred), call $(D find!(pred)(retro(haystack))). See also $(XREF
range, retro).

Example:
----
auto arr = [ 1, 2, 3, 4, 1 ];
assert(find!("a > 2")(arr) == [ 3, 4, 1 ]);

// with predicate alias
bool pred(int x) { return x + 1 > 1.5; }
assert(find!(pred)(arr) == arr);
----
*/
Range find(alias pred, Range)(Range haystack) if (isInputRange!(Range))
{
    alias unaryFun!(pred) predFun;
    for (; !haystack.empty && !predFun(haystack.front); haystack.popFront())
    {
    }
    return haystack;
}

unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 3 ];
    assert(find!("a > 2")(a) == [3]);
    bool pred(int x) { return x + 1 > 1.5; }
    assert(find!(pred)(a) == a);
}

// findSkip
/**
 * If $(D needle) occurs in $(D haystack), positions $(D haystack)
 * right after the first occurrence of $(D needle) and returns $(D
 * true). Otherwise, leaves $(D haystack) as is and returns $(D
 * false).
 *
 * Example:
----
string s = "abcdef";
assert(findSkip(s, "cd") && s == "ef");
s = "abcdef";
assert(!findSkip(s, "cxd") && s == "abcdef");
assert(findSkip(s, "def") && s.empty);
----
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

unittest
{
    string s = "abcdef";
    assert(findSkip(s, "cd") && s == "ef");
    s = "abcdef";
    assert(!findSkip(s, "cxd") && s == "abcdef");
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

Example:
----
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
----
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

unittest
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

unittest
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
    Returns the number of elements which must be popped from the front of
    $(D haystack) before reaching an element for which
    $(D startsWith!pred(haystack, needles)) is $(D true). If
    $(D startsWith!pred(haystack, needles)) is not $(D true) for any element in
    $(D haystack), then $(D -1) is returned.

    $(D needles) may be either an element or a range.

    Examples:
--------------------
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
--------------------
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

//Verify Examples.
unittest
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
unittest
{
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

unittest
{
    assert(countUntil("hello world", "world", "asd") == 6);
    assert(countUntil("hello world", "world", "ello") == 1);
    assert(countUntil("hello world", "world", "") == 0);
    assert(countUntil("hello world", "world", 'l') == 2);
}

/++
    Returns the number of elements which must be popped from $(D haystack)
    before $(D pred(haystack.front)) is $(D true).

    Examples:
--------------------
assert(countUntil!(std.uni.isWhite)("hello world") == 5);
assert(countUntil!(std.ascii.isDigit)("hello world") == -1);
assert(countUntil!"a > 20"([0, 7, 12, 22, 9]) == 3);
--------------------
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
        alias ElementType!R T; //For narrow strings forces dchar iteration
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

//Verify Examples.
unittest
{
    assert(countUntil!(std.uni.isWhite)("hello world") == 5);
    assert(countUntil!(std.ascii.isDigit)("hello world") == -1);
    assert(countUntil!"a > 20"([0, 7, 12, 22, 9]) == 3);
}
unittest
{
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

// Explicitly undocumented. It will be removed in November 2013.
deprecated("Please use std.algorithm.countUntil instead.")
ptrdiff_t indexOf(alias pred = "a == b", R1, R2)(R1 haystack, R2 needle)
if (is(typeof(startsWith!pred(haystack, needle))))
{
    return countUntil!pred(haystack, needle);
}

/**
Interval option specifier for $(D until) (below) and others.
 */
enum OpenRight
{
    no, /// Interval is closed to the right (last element included)
    yes /// Interval is open to the right (last element is not included)
}

/**
Lazily iterates $(D range) until value $(D sentinel) is found, at
which point it stops.

Example:
----
int[] a = [ 1, 2, 4, 7, 7, 2, 4, 7, 3, 5];
assert(equal(a.until(7), [1, 2, 4][]));
assert(equal(a.until(7, OpenRight.no), [1, 2, 4, 7][]));
----
 */
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

    @property ElementType!Range front()
    {
        assert(!empty);
        return _input.front;
    }

    private bool predSatisfied()
    {
        static if (is(Sentinel == void))
            return unaryFun!pred(_input.front);
        else
            return startsWith!pred(_input, _sentinel);
    }

    void popFront()
    {
        assert(!empty);
        if (!_openRight)
        {
            if (predSatisfied())
            {
                _done = true;
                return;
            }
            _input.popFront();
            _done = _input.empty;
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

/// Ditto
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

unittest
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

/**
If the range $(D doesThisStart) starts with $(I any) of the $(D
withOneOfThese) ranges or elements, returns 1 if it starts with $(D
withOneOfThese[0]), 2 if it starts with $(D withOneOfThese[1]), and so
on. If none match, returns 0. In the case where $(D doesThisStart) starts
with multiple of the ranges or elements in $(D withOneOfThese), then the
shortest one matches (if there are two which match which are of the same
length (e.g. $(D "a") and $(D 'a')), then the left-most of them in the argument
list matches).

Example:
----
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
----
 */
uint startsWith(alias pred = "a == b", Range, Needles...)(Range doesThisStart, Needles withOneOfThese)
if (isInputRange!Range && Needles.length > 1 &&
    is(typeof(.startsWith!pred(doesThisStart, withOneOfThese[0])) : bool ) &&
    is(typeof(.startsWith!pred(doesThisStart, withOneOfThese[1 .. $])) : uint))
{
    alias doesThisStart haystack;
    alias withOneOfThese needles;

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
    alias doesThisStart haystack;
    alias withThis needle;

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
            if (!binaryFun!pred(needle[j], haystack[j]))
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

unittest
{
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
        {
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
        }
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
If $(D startsWith(r1, r2)), consume the corresponding elements off $(D
r1) and return $(D true). Otherwise, leave $(D r1) unchanged and
return $(D false).
 */
bool skipOver(alias pred = "a == b", R1, R2)(ref R1 r1, R2 r2)
if (is(typeof(binaryFun!pred(r1.front, r2.front))))
{
    auto r = r1.save;
    while (!r2.empty && !r.empty && binaryFun!pred(r.front, r2.front))
    {
        r.popFront();
        r2.popFront();
    }
    return r2.empty ? (r1 = r, true) : false;
}

unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
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
Checks whether a range starts with an element, and if so, consume that
element off $(D r) and return $(D true). Otherwise, leave $(D r)
unchanged and return $(D false).
 */
bool skipOver(alias pred = "a == b", R, E)(ref R r, E e)
if (is(typeof(binaryFun!pred(r.front, e))))
{
    return binaryFun!pred(r.front, e)
        ? (r.popFront(), true)
        : false;
}

unittest {
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

unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto s1 = "Hello world";
    skipAll(s1, 'H', 'e');
    assert(s1 == "llo world");
}

/**
The reciprocal of $(D startsWith).

Example:
----
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
----
 */
uint endsWith(alias pred = "a == b", Range, Needles...)(Range doesThisEnd, Needles withOneOfThese)
if (isBidirectionalRange!Range && Needles.length > 1 &&
    is(typeof(.endsWith!pred(doesThisEnd, withOneOfThese[0])) : bool) &&
    is(typeof(.endsWith!pred(doesThisEnd, withOneOfThese[1 .. $])) : uint))
{
    alias doesThisEnd haystack;
    alias withOneOfThese needles;

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
    alias doesThisEnd haystack;
    alias withThis needle;

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

unittest
{
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
        {
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
        }
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
Returns the common prefix of two ranges. Example:

----
assert(commonPrefix("hello, world", "hello, there") == "hello, ");
----

If the first argument is a string, then the result is a slice of $(D r1) which
contains the characters that both ranges start with. For all other types, the
type of the result is the same as the result of $(D takeExactly(r1, n)), where
$(D n) is the number of elements that both ranges start with.

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
        auto result = r1.save;
        size_t i = 0;
        for (;
             !r1.empty && !r2.empty && binaryFun!pred(r1.front, r2.front);
             ++i, r1.popFront(), r2.popFront())
        {}
        return takeExactly(result, i);
    }
}

auto commonPrefix(alias pred, R1, R2)(R1 r1, R2 r2)
if (isNarrowString!R1 && isInputRange!R2 &&
    is(typeof(binaryFun!pred(r1.front, r2.front))))
{
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

auto commonPrefix(R1, R2)(R1 r1, R2 r2)
if (isNarrowString!R1 && isInputRange!R2 && !isNarrowString!R2 &&
    is(typeof(r1.front == r2.front)))
{
    return commonPrefix!"a == b"(r1, r2);
}

auto commonPrefix(R1, R2)(R1 r1, R2 r2)
if (isNarrowString!R1 && isNarrowString!R2)
{
    static if (ElementEncodingType!R1.sizeof == ElementEncodingType!R2.sizeof)
    {
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

unittest
{
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
        {
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
        }

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
evaluations of $(D pred). See also $(WEB
sgi.com/tech/stl/adjacent_find.html, STL's adjacent_find).

Example:
----
int[] a = [ 11, 10, 10, 9, 8, 8, 7, 8, 9 ];
auto r = findAdjacent(a);
assert(r == [ 10, 10, 9, 8, 8, 7, 8, 9 ]);
p = findAdjacent!("a < b")(a);
assert(p == [ 7, 8, 9 ]);
----
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

unittest
{
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
Advances $(D seq) by calling $(D seq.popFront) until either $(D
find!(pred)(choices, seq.front)) is $(D true), or $(D seq) becomes
empty. Performs $(BIGOH seq.length * choices.length) evaluations of
$(D pred). See also $(WEB sgi.com/tech/stl/find_first_of.html, STL's
find_first_of).

Example:
----
int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
int[] b = [ 3, 1, 2 ];
assert(findAmong(a, b) == a[2 .. $]);
----
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

unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ -1, 0, 2, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(findAmong(a, b) == [2, 1, 2, 3, 4, 5 ]);
    assert(findAmong(b, [ 4, 6, 7 ][]).empty);
    assert(findAmong!("a==b")(a, b).length == a.length - 2);
    assert(findAmong!("a==b")(b, [ 4, 6, 7 ][]).empty);
}

// count
/**
The first version counts the number of elements $(D x) in $(D r) for
which $(D pred(x, value)) is $(D true). $(D pred) defaults to
equality. Performs $(BIGOH r.length) evaluations of $(D pred).

The second version returns the number of times $(D needle) occurs in
$(D haystack). Throws an exception if $(D needle.empty), as the _count
of the empty range in any range would be infinite. Overlapped counts
are not considered, for example $(D count("aaa", "aa")) is $(D 1), not
$(D 2).

The third version counts the elements for which $(D pred(x)) is $(D
true). Performs $(BIGOH r.length) evaluations of $(D pred).

Note: Regardless of the overload, $(D count) will not accept
infinite ranges for $(D haystack).

Example:
----
// count elements in range
int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
assert(count(a, 2) == 3);
assert(count!("a > b")(a, 2) == 5);
// count range in range
assert(count("abcadfabf", "ab") == 2);
assert(count("ababab", "abab") == 1);
assert(count("ababab", "abx") == 0);
// fuzzy count range in range
assert(count!"std.uni.toLower(a) == std.uni.toLower(b)"("AbcAdFaBf", "ab") == 2);
// count predicate in range
assert(count!("a > 1")(a) == 8);
----
*/
size_t count(alias pred = "a == b", Range, E)(Range haystack, E needle)
    if (isInputRange!Range && !isInfinite!Range &&
        is(typeof(binaryFun!pred(haystack.front, needle)) : bool))
{
    bool pred2(ElementType!Range a) { return binaryFun!pred(a, needle); }
    return count!pred2(haystack);
}

unittest
{
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

unittest
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
    enforce(!needle.empty, "Cannot count occurrences of an empty range");
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

unittest
{
    assert(count("abcadfabf", "ab") == 2);
    assert(count("ababab", "abab") == 1);
    assert(count("ababab", "abx") == 0);
    assert(count!"std.uni.toLower(a) == std.uni.toLower(b)"("AbcAdFaBf", "ab") == 2);
}

/// Ditto
size_t count(alias pred = "true", R)(R haystack)
    if (isInputRange!R && !isInfinite!R &&
        is(typeof(unaryFun!pred(haystack.front)) : bool))
{
    size_t result;
    alias ElementType!R T; //For narrow strings forces dchar iteration
    foreach (T elem; haystack)
        if (unaryFun!pred(elem)) ++result;
    return result;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
    assert(count!("a == 3")(a) == 2);
    assert(count("日本語") == 3);
}

// balancedParens
/**
Checks whether $(D r) has "balanced parentheses", i.e. all instances
of $(D lPar) are closed by corresponding instances of $(D rPar). The
parameter $(D maxNestingLevel) controls the nesting level allowed. The
most common uses are the default or $(D 0). In the latter case, no
nesting is allowed.

Example:
----
auto s = "1 + $(LPAREN)2 * (3 + 1 / 2)";
assert(!balancedParens(s, '(', ')'));
s = "1 + (2 * (3 + 1) / 2)";
assert(balancedParens(s, '(', ')'));
s = "1 + (2 * (3 + 1) / 2)";
assert(!balancedParens(s, '(', ')', 1));
s = "1 + (2 * 3 + 1) / (2 - 5)";
assert(balancedParens(s, '(', ')', 1));
----
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

unittest
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

// equal
/**
Returns $(D true) if and only if the two ranges compare equal element
for element, according to binary predicate $(D pred). The ranges may
have different element types, as long as $(D pred(a, b)) evaluates to
$(D bool) for $(D a) in $(D r1) and $(D b) in $(D r2). Performs
$(BIGOH min(r1.length, r2.length)) evaluations of $(D pred). See also
$(WEB sgi.com/tech/stl/_equal.html, STL's _equal).

Example:
----
int[] a = [ 1, 2, 4, 3 ];
assert(!equal(a, a[1..$]));
assert(equal(a, a));

// different types
double[] b = [ 1.0, 2, 4, 3];
assert(!equal(a, b[1..$]));
assert(equal(a, b));

// predicated: ensure that two vectors are approximately equal
double[] c = [ 1.005, 2, 4, 3];
assert(equal!(approxEqual)(b, c));
----
*/
bool equal(Range1, Range2)(Range1 r1, Range2 r2)
    if (isInputRange!Range1 && isInputRange!Range2
        && is(typeof(r1.front == r2.front)))
{
    static if (isArray!Range1 && isArray!Range2
        && is(typeof(r1 == r2)))
    {
        //Ranges are comparable. Let the compiler do the comparison.
        return r1 == r2;
    }
    else
    {
        //Need to do an actual compare, delegate to predicate version
        return equal!"a==b"(r1, r2);
    }
}

/// Ditto
bool equal(alias pred, Range1, Range2)(Range1 r1, Range2 r2)
    if (isInputRange!Range1 && isInputRange!Range2
        && is(typeof(binaryFun!pred(r1.front, r2.front))))
{
    //Try a fast implementation when the ranges have comparable lengths
    static if (hasLength!Range1 && hasLength!Range2
        && is(typeof(r1.length == r2.length)))
    {
        auto len1 = r1.length;
        auto len2 = r2.length;
        if (len1 != len2) return false; //Short circuit return

        //Lengths are the same, so we need to do an actual comparison
        //Good news is we can sqeeze out a bit of performance by not checking if r2 is empty
        for (; !r1.empty; r1.popFront(), r2.popFront())
        {
            if (!binaryFun!(pred)(r1.front, r2.front)) return false;
        }
        return true;
    }
    else
    {
        //Generic case, we have to walk both ranges making sure neither is empty
        for (; !r1.empty; r1.popFront(), r2.popFront())
        {
            if (r2.empty) return false;
            if (!binaryFun!(pred)(r1.front, r2.front)) return false;
        }
        return r2.empty;
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 3];
    assert(!equal(a, a[1..$]));
    assert(equal(a, a));
    // test with different types
    double[] b = [ 1.0, 2, 4, 3];
    assert(!equal(a, b[1..$]));
    assert(equal(a, b));

    // predicated
    double[] c = [ 1.005, 2, 4, 3];
    assert(equal!(approxEqual)(b, c));

    // various strings
    assert(equal("æøå", "æøå")); //UTF8 vs UTF8
    assert(!equal("???", "æøå")); //UTF8 vs UTF8
    assert(equal("æøå"w, "æøå"d)); //UTF16 vs UTF32
    assert(!equal("???"w, "æøå"d));//UTF16 vs UTF32
    assert(equal("æøå"d, "æøå"d)); //UTF32 vs UTF32
    assert(!equal("???"d, "æøå"d));//UTF32 vs UTF32
    assert(!equal("hello", "world"));

    // same strings, but "explicit non default" comparison (to test the non optimized array comparison)
    assert( equal!("a==b")("æøå", "æøå")); //UTF8 vs UTF8
    assert(!equal!("a==b")("???", "æøå")); //UTF8 vs UTF8
    assert( equal!("a==b")("æøå"w, "æøå"d)); //UTF16 vs UTF32
    assert(!equal!("a==b")("???"w, "æøå"d));//UTF16 vs UTF32
    assert( equal!("a==b")("æøå"d, "æøå"d)); //UTF32 vs UTF32
    assert(!equal!("a==b")("???"d, "æøå"d));//UTF32 vs UTF32
    assert(!equal!("a==b")("hello", "world"));

    //Array of string
    assert(equal(["hello", "world"], ["hello", "world"]));
    assert(!equal(["hello", "world"], ["hello"]));
    assert(!equal(["hello", "world"], ["hello", "Bob!"]));

    //Should not compile, because "string == dstring" is illegal
    static assert(!is(typeof(equal(["hello", "world"], ["hello"d, "world"d]))));
    //However, arrays of non-matching string can be compared using equal!equal. Neat-o!
    equal!equal(["hello", "world"], ["hello"d, "world"d]);

    //Tests, with more fancy map ranges
    assert(equal([2, 4, 8, 6], map!"a*2"(a)));
    assert(equal!approxEqual(map!"a*2"(b), map!"a*2"(c)));
    assert(!equal([2, 4, 1, 3], map!"a*2"(a)));
    assert(!equal([2, 4, 1], map!"a*2"(a)));
    assert(!equal!approxEqual(map!"a*3"(b), map!"a*2"(c)));

    //Tests with some fancy reference ranges.
    ReferenceInputRange!int cir = new ReferenceInputRange!int([1, 2, 4, 3]);
    ReferenceForwardRange!int cfr = new ReferenceForwardRange!int([1, 2, 4, 3]);
    assert(equal(cir, a));
    cir = new ReferenceInputRange!int([1, 2, 4, 3]);
    assert(equal(cir, cfr.save));
    assert(equal(cfr.save, cfr.save));
    cir = new ReferenceInputRange!int([1, 2, 8, 1]);
    assert(!equal(cir, cfr));

    //Test with an infinte range
    ReferenceInfiniteForwardRange!int ifr = new ReferenceInfiniteForwardRange!int;
    assert(!equal(a, ifr));
}

// cmp
/**********************************
Performs three-way lexicographical comparison on two input ranges
according to predicate $(D pred). Iterating $(D r1) and $(D r2) in
lockstep, $(D cmp) compares each element $(D e1) of $(D r1) with the
corresponding element $(D e2) in $(D r2). If $(D binaryFun!pred(e1,
e2)), $(D cmp) returns a negative value. If $(D binaryFun!pred(e2,
e1)), $(D cmp) returns a positive value. If one of the ranges has been
finished, $(D cmp) returns a negative value if $(D r1) has fewer
elements than $(D r2), a positive value if $(D r1) has more elements
than $(D r2), and $(D 0) if the ranges have the same number of
elements.

If the ranges are strings, $(D cmp) performs UTF decoding
appropriately and compares the ranges one code point at a time.
*/

int cmp(alias pred = "a < b", R1, R2)(R1 r1, R2 r2)
if (isInputRange!R1 && isInputRange!R2 && !(isSomeString!R1 && isSomeString!R2))
{
    for (;; r1.popFront(), r2.popFront())
    {
        if (r1.empty) return -cast(int)!r2.empty;
        if (r2.empty) return !r1.empty;
        auto a = r1.front, b = r2.front;
        if (binaryFun!pred(a, b)) return -1;
        if (binaryFun!pred(b, a)) return 1;
    }
}

// Specialization for strings (for speed purposes)
int cmp(alias pred = "a < b", R1, R2)(R1 r1, R2 r2) if (isSomeString!R1 && isSomeString!R2)
{
    static if (is(typeof(pred) : string))
        enum isLessThan = pred == "a < b";
    else
        enum isLessThan = false;

    // For speed only
    static int threeWay(size_t a, size_t b)
    {
        static if (size_t.sizeof == int.sizeof && isLessThan)
            return a - b;
        else
            return binaryFun!pred(b, a) ? 1 : binaryFun!pred(a, b) ? -1 : 0;
    }
    // For speed only
    // @@@BUG@@@ overloading should be allowed for nested functions
    static int threeWayInt(int a, int b)
    {
        static if (isLessThan)
            return a - b;
        else
            return binaryFun!pred(b, a) ? 1 : binaryFun!pred(a, b) ? -1 : 0;
    }

    static if (typeof(r1[0]).sizeof == typeof(r2[0]).sizeof && isLessThan)
    {
        static if (typeof(r1[0]).sizeof == 1)
        {
            immutable len = min(r1.length, r2.length);
            immutable result = std.c.string.memcmp(r1.ptr, r2.ptr, len);
            if (result) return result;
        }
        else
        {
            auto p1 = r1.ptr, p2 = r2.ptr,
                pEnd = p1 + min(r1.length, r2.length);
            for (; p1 != pEnd; ++p1, ++p2)
            {
                if (*p1 != *p2) return threeWayInt(cast(int) *p1, cast(int) *p2);
            }
        }
        return threeWay(r1.length, r2.length);
    }
    else
    {
        for (size_t i1, i2;;)
        {
            if (i1 == r1.length) return threeWay(i2, r2.length);
            if (i2 == r2.length) return threeWay(r1.length, i1);
            immutable c1 = std.utf.decode(r1, i1),
                c2 = std.utf.decode(r2, i2);
            if (c1 != c2) return threeWayInt(cast(int) c1, cast(int) c2);
        }
    }
}

unittest
{
    int result;

    debug(string) printf("string.cmp.unittest\n");
    result = cmp("abc", "abc");
    assert(result == 0);
    //    result = cmp(null, null);
    //    assert(result == 0);
    result = cmp("", "");
    assert(result == 0);
    result = cmp("abc", "abcd");
    assert(result < 0);
    result = cmp("abcd", "abc");
    assert(result > 0);
    result = cmp("abc"d, "abd");
    assert(result < 0);
    result = cmp("bbc", "abc"w);
    assert(result > 0);
    result = cmp("aaa", "aaaa"d);
    assert(result < 0);
    result = cmp("aaaa", "aaa"d);
    assert(result > 0);
    result = cmp("aaa", "aaa"d);
    assert(result == 0);
    result = cmp(cast(int[])[], cast(int[])[]);
    assert(result == 0);
    result = cmp([1, 2, 3], [1, 2, 3]);
    assert(result == 0);
    result = cmp([1, 3, 2], [1, 2, 3]);
    assert(result > 0);
    result = cmp([1, 2, 3], [1L, 2, 3, 4]);
    assert(result < 0);
    result = cmp([1L, 2, 3], [1, 2]);
    assert(result > 0);
}

// MinType
template MinType(T...)
{
    static assert(T.length >= 2);
    static if (T.length == 2)
    {
        static if (!is(typeof(T[0].min)))
            alias CommonType!(T[0 .. 2]) MinType;
        else
        {
            enum hasMostNegative = is(typeof(mostNegative!(T[0]))) &&
                                   is(typeof(mostNegative!(T[1])));
            static if (hasMostNegative && mostNegative!(T[1]) < mostNegative!(T[0]))
                alias T[1] MinType;
            else static if (hasMostNegative && mostNegative!(T[1]) > mostNegative!(T[0]))
                alias T[0] MinType;
            else static if (T[1].max < T[0].max)
                alias T[1] MinType;
            else
                alias T[0] MinType;
        }
    }
    else
    {
        alias MinType!(MinType!(T[0 .. 2]), T[2 .. $]) MinType;
    }
}

// min
/**
Returns the minimum of the passed-in values. The type of the result is
computed by using $(XREF traits, CommonType).
*/
MinType!(T1, T2, T) min(T1, T2, T...)(T1 a, T2 b, T xs)
    if (is(typeof(a < b)))
{
    static if (T.length == 0)
    {
        static if (isIntegral!T1 && isIntegral!T2 &&
                   (mostNegative!T1 < 0) != (mostNegative!T2 < 0))
        {
            static if (mostNegative!T1 < 0)
                immutable chooseB = b < a && a > 0;
            else
                immutable chooseB = b < a || b < 0;
        }
        else
            immutable chooseB = b < a;
        return cast(typeof(return)) (chooseB ? b : a);
    }
    else
    {
        return min(min(a, b), xs);
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int a = 5;
    short b = 6;
    double c = 2;
    auto d = min(a, b);
    static assert(is(typeof(d) == int));
    assert(d == 5);
    auto e = min(a, b, c);
    static assert(is(typeof(e) == double));
    assert(e == 2);
    // mixed signedness test
    a = -10;
    uint f = 10;
    static assert(is(typeof(min(a, f)) == int));
    assert(min(a, f) == -10);

    //Test user-defined types
    import std.datetime;
    assert(min(Date(2012, 12, 21), Date(1982, 1, 4)) == Date(1982, 1, 4));
    assert(min(Date(1982, 1, 4), Date(2012, 12, 21)) == Date(1982, 1, 4));
    assert(min(Date(1982, 1, 4), Date.min) == Date.min);
    assert(min(Date.min, Date(1982, 1, 4)) == Date.min);
    assert(min(Date(1982, 1, 4), Date.max) == Date(1982, 1, 4));
    assert(min(Date.max, Date(1982, 1, 4)) == Date(1982, 1, 4));
    assert(min(Date.min, Date.max) == Date.min);
    assert(min(Date.max, Date.min) == Date.min);
}

// MaxType
template MaxType(T...)
{
    static assert(T.length >= 2);
    static if (T.length == 2)
    {
        static if (!is(typeof(T[0].min)))
            alias CommonType!(T[0 .. 2]) MaxType;
        else static if (T[1].max > T[0].max)
            alias T[1] MaxType;
        else
            alias T[0] MaxType;
    }
    else
    {
        alias MaxType!(MaxType!(T[0], T[1]), T[2 .. $]) MaxType;
    }
}

// max
/**
Returns the maximum of the passed-in values. The type of the result is
computed by using $(XREF traits, CommonType).

Example:
----
int a = 5;
short b = 6;
double c = 2;
auto d = max(a, b);
assert(is(typeof(d) == int));
assert(d == 6);
auto e = min(a, b, c);
assert(is(typeof(e) == double));
assert(e == 2);
----
*/
MaxType!(T1, T2, T) max(T1, T2, T...)(T1 a, T2 b, T xs)
    if (is(typeof(a < b)))
{
    static if (T.length == 0)
    {
        static if (isIntegral!T1 && isIntegral!T2 &&
                   (mostNegative!T1 < 0) != (mostNegative!T2 < 0))
        {
            static if (mostNegative!T1 < 0)
                immutable chooseB = b > a || a < 0;
            else
                immutable chooseB = b > a && b > 0;
        }
        else
            immutable chooseB = b > a;
        return cast(typeof(return)) (chooseB ? b : a);
    }
    else
    {
        return max(max(a, b), xs);
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int a = 5;
    short b = 6;
    double c = 2;
    auto d = max(a, b);
    static assert(is(typeof(d) == int));
    assert(d == 6);
    auto e = max(a, b, c);
    static assert(is(typeof(e) == double));
    assert(e == 6);
    // mixed sign
    a = -5;
    uint f = 5;
    static assert(is(typeof(max(a, f)) == uint));
    assert(max(a, f) == 5);

    //Test user-defined types
    import std.datetime;
    assert(max(Date(2012, 12, 21), Date(1982, 1, 4)) == Date(2012, 12, 21));
    assert(max(Date(1982, 1, 4), Date(2012, 12, 21)) == Date(2012, 12, 21));
    assert(max(Date(1982, 1, 4), Date.min) == Date(1982, 1, 4));
    assert(max(Date.min, Date(1982, 1, 4)) == Date(1982, 1, 4));
    assert(max(Date(1982, 1, 4), Date.max) == Date.max);
    assert(max(Date.max, Date(1982, 1, 4)) == Date.max);
    assert(max(Date.min, Date.max) == Date.max);
    assert(max(Date.max, Date.min) == Date.max);
}

/**
Returns the minimum element of a range together with the number of
occurrences. The function can actually be used for counting the
maximum or any other ordering predicate (that's why $(D maxCount) is
not provided).

Example:
----
int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
// Minimum is 1 and occurs 3 times
assert(minCount(a) == tuple(1, 3));
// Maximum is 4 and occurs 2 times
assert(minCount!("a > b")(a) == tuple(4, 2));
----
 */
Tuple!(ElementType!Range, size_t)
minCount(alias pred = "a < b", Range)(Range range)
    if (isInputRange!Range && !isInfinite!Range &&
        is(typeof(binaryFun!pred(range.front, range.front))))
{
    enforce(!range.empty, "Can't count elements from an empty range");
    size_t occurrences = 1;
    auto v = range.front;
    for (range.popFront(); !range.empty; range.popFront())
    {
        auto v2 = range.front;
        if (binaryFun!pred(v, v2)) continue;
        if (binaryFun!pred(v2, v))
        {
            // change the min
            move(v2, v);
            occurrences = 1;
        }
        else
        {
            ++occurrences;
        }
    }
    return typeof(return)(v, occurrences);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    assert(minCount(a) == tuple(1, 3));
    assert(minCount!("a > b")(a) == tuple(4, 2));
    int[][] b = [ [4], [2, 4], [4], [4] ];
    auto c = minCount!("a[0] < b[0]")(b);
    assert(c == tuple([2, 4], 1), text(c[0]));

    //Test empty range
    assertThrown(minCount(a[$..$]));

    //test with reference ranges. Test both input and forward.
    assert(minCount(new ReferenceInputRange!int([1, 2, 1, 0, 2, 0])) == tuple(0, 2));
    assert(minCount(new ReferenceForwardRange!int([1, 2, 1, 0, 2, 0])) == tuple(0, 2));

}

// minPos
/**
Returns the position of the minimum element of forward range $(D
range), i.e. a subrange of $(D range) starting at the position of its
smallest element and with the same ending as $(D range). The function
can actually be used for counting the maximum or any other ordering
predicate (that's why $(D maxPos) is not provided).

Example:
----
int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
// Minimum is 1 and first occurs in position 3
assert(minPos(a) == [ 1, 2, 4, 1, 1, 2 ]);
// Maximum is 4 and first occurs in position 2
assert(minPos!("a > b")(a) == [ 4, 1, 2, 4, 1, 1, 2 ]);
----
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

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 2, 3, 4, 1, 2, 4, 1, 1, 2 ];
    // Minimum is 1 and first occurs in position 3
    assert(minPos(a) == [ 1, 2, 4, 1, 1, 2 ]);
    // Maximum is 4 and first occurs in position 5
    assert(minPos!("a > b")(a) == [ 4, 1, 2, 4, 1, 1, 2 ]);

    //Test that an empty range works
    int[] b = a[$..$];
    assert(equal(minPos(b), b));

    //test with reference range.
    assert( equal( minPos(new ReferenceForwardRange!int([1, 2, 1, 0, 2, 0])), [0, 2, 0] ) );
}
unittest
{
    //Rvalue range
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    assert(Array!int(2, 3, 4, 1, 2, 4, 1, 1, 2)
               []
               .minPos()
               .equal([ 1, 2, 4, 1, 1, 2 ]));
}
unittest
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

// mismatch
/**
Sequentially compares elements in $(D r1) and $(D r2) in lockstep, and
stops at the first mismatch (according to $(D pred), by default
equality). Returns a tuple with the reduced ranges that start with the
two mismatched values. Performs $(BIGOH min(r1.length, r2.length))
evaluations of $(D pred). See also $(WEB
sgi.com/tech/stl/_mismatch.html, STL's _mismatch).

Example:
----
int[]    x = [ 1,  5, 2, 7,   4, 3 ];
double[] y = [ 1.0, 5, 2, 7.3, 4, 8 ];
auto m = mismatch(x, y);
assert(m[0] == x[3 .. $]);
assert(m[1] == y[3 .. $]);
----
*/

Tuple!(Range1, Range2)
mismatch(alias pred = "a == b", Range1, Range2)(Range1 r1, Range2 r2)
    if (isInputRange!(Range1) && isInputRange!(Range2))
{
    for (; !r1.empty && !r2.empty; r1.popFront(), r2.popFront())
    {
        if (!binaryFun!(pred)(r1.front, r2.front)) break;
    }
    return tuple(r1, r2);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    // doc example
    int[]    x = [ 1,  5, 2, 7,   4, 3 ];
    double[] y = [ 1.0, 5, 2, 7.3, 4, 8 ];
    auto m = mismatch(x, y);
    assert(m[0] == [ 7, 4, 3 ]);
    assert(m[1] == [ 7.3, 4, 8 ]);

    int[] a = [ 1, 2, 3 ];
    int[] b = [ 1, 2, 4, 5 ];
    auto mm = mismatch(a, b);
    assert(mm[0] == [3]);
    assert(mm[1] == [4, 5]);
}

// levenshteinDistance
/**
Encodes $(WEB realityinteractive.com/rgrzywinski/archives/000249.html,
edit operations) necessary to transform one sequence into
another. Given sequences $(D s) (source) and $(D t) (target), a
sequence of $(D EditOp) encodes the steps that need to be taken to
convert $(D s) into $(D t). For example, if $(D s = "cat") and $(D
"cars"), the minimal sequence that transforms $(D s) into $(D t) is:
skip two characters, replace 't' with 'r', and insert an 's'. Working
with edit operations is useful in applications such as spell-checkers
(to find the closest word to a given misspelled word), approximate
searches, diff-style programs that compute the difference between
files, efficient encoding of patches, DNA sequence analysis, and
plagiarism detection.
*/

enum EditOp : char
{
    /** Current items are equal; no editing is necessary. */
    none = 'n',
    /** Substitute current item in target with current item in source. */
    substitute = 's',
    /** Insert current item from the source into the target. */
    insert = 'i',
    /** Remove current item from the target. */
    remove = 'r'
}

struct Levenshtein(Range, alias equals, CostType = size_t)
{
    void deletionIncrement(CostType n)
    {
        _deletionIncrement = n;
        InitMatrix();
    }

    void insertionIncrement(CostType n)
    {
        _insertionIncrement = n;
        InitMatrix();
    }

    CostType distance(Range s, Range t)
    {
        auto slen = walkLength(s.save), tlen = walkLength(t.save);
        AllocMatrix(slen + 1, tlen + 1);
        foreach (i; 1 .. rows)
        {
            auto sfront = s.front;
            s.popFront();
            auto tt = t;
            foreach (j; 1 .. cols)
            {
                auto cSub = _matrix[i - 1][j - 1]
                    + (equals(sfront, tt.front) ? 0 : _substitutionIncrement);
                tt.popFront();
                auto cIns = _matrix[i][j - 1] + _insertionIncrement;
                auto cDel = _matrix[i - 1][j] + _deletionIncrement;
                switch (min_index(cSub, cIns, cDel)) {
                case 0:
                    _matrix[i][j] = cSub;
                    break;
                case 1:
                    _matrix[i][j] = cIns;
                    break;
                default:
                    _matrix[i][j] = cDel;
                    break;
                }
            }
        }
        return _matrix[slen][tlen];
    }

    EditOp[] path(Range s, Range t)
    {
        distance(s, t);
        return path();
    }

    EditOp[] path()
    {
        EditOp[] result;
        size_t i = rows - 1, j = cols - 1;
        // restore the path
        while (i || j) {
            auto cIns = j == 0 ? CostType.max : _matrix[i][j - 1];
            auto cDel = i == 0 ? CostType.max : _matrix[i - 1][j];
            auto cSub = i == 0 || j == 0
                ? CostType.max
                : _matrix[i - 1][j - 1];
            switch (min_index(cSub, cIns, cDel)) {
            case 0:
                result ~= _matrix[i - 1][j - 1] == _matrix[i][j]
                    ? EditOp.none
                    : EditOp.substitute;
                --i;
                --j;
                break;
            case 1:
                result ~= EditOp.insert;
                --j;
                break;
            default:
                result ~= EditOp.remove;
                --i;
                break;
            }
        }
        reverse(result);
        return result;
    }

private:
    CostType _deletionIncrement = 1,
        _insertionIncrement = 1,
        _substitutionIncrement = 1;
    CostType[][] _matrix;
    size_t rows, cols;

    void AllocMatrix(size_t r, size_t c) {
        rows = r;
        cols = c;
        if (!_matrix || _matrix.length < r || _matrix[0].length < c) {
            delete _matrix;
            _matrix = new CostType[][](r, c);
            InitMatrix();
        }
    }

    void InitMatrix() {
        foreach (i, row; _matrix) {
            row[0] = i * _deletionIncrement;
        }
        if (!_matrix) return;
        for (auto i = 0u; i != _matrix[0].length; ++i) {
            _matrix[0][i] = i * _insertionIncrement;
        }
    }

    static uint min_index(CostType i0, CostType i1, CostType i2)
    {
        if (i0 <= i1)
        {
            return i0 <= i2 ? 0 : 2;
        }
        else
        {
            return i1 <= i2 ? 1 : 2;
        }
    }
}

/**
Returns the $(WEB wikipedia.org/wiki/Levenshtein_distance, Levenshtein
distance) between $(D s) and $(D t). The Levenshtein distance computes
the minimal amount of edit operations necessary to transform $(D s)
into $(D t).  Performs $(BIGOH s.length * t.length) evaluations of $(D
equals) and occupies $(BIGOH s.length * t.length) storage.

Example:
----
assert(levenshteinDistance("cat", "rat") == 1);
assert(levenshteinDistance("parks", "spark") == 2);
assert(levenshteinDistance("kitten", "sitting") == 3);
// ignore case
assert(levenshteinDistance!("std.uni.toUpper(a) == std.uni.toUpper(b)")
    ("parks", "SPARK") == 2);
----
*/
size_t levenshteinDistance(alias equals = "a == b", Range1, Range2)
    (Range1 s, Range2 t)
    if (isForwardRange!(Range1) && isForwardRange!(Range2))
{
    Levenshtein!(Range1, binaryFun!(equals), size_t) lev;
    return lev.distance(s, t);
}

//Verify Examples.
unittest
{
    assert(levenshteinDistance("cat", "rat") == 1);
    assert(levenshteinDistance("parks", "spark") == 2);
    assert(levenshteinDistance("kitten", "sitting") == 3);
    assert(levenshteinDistance!("std.uni.toUpper(a) == std.uni.toUpper(b)")
        ("parks", "SPARK") == 2);
}

/**
Returns the Levenshtein distance and the edit path between $(D s) and
$(D t).

Example:
---
string a = "Saturday", b = "Sunday";
auto p = levenshteinDistanceAndPath(a, b);
assert(p[0] == 3);
assert(equal(p[1], "nrrnsnnn"));
---
*/
Tuple!(size_t, EditOp[])
levenshteinDistanceAndPath(alias equals = "a == b", Range1, Range2)
    (Range1 s, Range2 t)
    if (isForwardRange!(Range1) && isForwardRange!(Range2))
{
    Levenshtein!(Range1, binaryFun!(equals)) lev;
    auto d = lev.distance(s, t);
    return tuple(d, lev.path());
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    assert(levenshteinDistance("a", "a") == 0);
    assert(levenshteinDistance("a", "b") == 1);
    assert(levenshteinDistance("aa", "ab") == 1);
    assert(levenshteinDistance("aa", "abc") == 2);
    assert(levenshteinDistance("Saturday", "Sunday") == 3);
    assert(levenshteinDistance("kitten", "sitting") == 3);
    //lev.deletionIncrement = 2;
    //lev.insertionIncrement = 100;
    string a = "Saturday", b = "Sunday";
    auto p = levenshteinDistanceAndPath(a, b);
    assert(cast(string) p[1] == "nrrnsnnn");
}

// copy
/**
Copies the content of $(D source) into $(D target) and returns the
remaining (unfilled) part of $(D target). See also $(WEB
sgi.com/tech/stl/_copy.html, STL's _copy). If a behavior similar to
$(WEB sgi.com/tech/stl/copy_backward.html, STL's copy_backward) is
needed, use $(D copy(retro(source), retro(target))). See also $(XREF
range, retro).

Example:
----
int[] a = [ 1, 5 ];
int[] b = [ 9, 8 ];
int[] c = new int[a.length + b.length + 10];
auto d = copy(b, copy(a, c));
assert(c[0 .. a.length + b.length] == a ~ b);
assert(d.length == 10);
----

As long as the target range elements support assignment from source
range elements, different types of ranges are accepted.

Example:
----
float[] a = [ 1.0f, 5 ];
double[] b = new double[a.length];
auto d = copy(a, b);
----

To copy at most $(D n) elements from range $(D a) to range $(D b), you
may want to use $(D copy(take(a, n), b)). To copy those elements from
range $(D a) that satisfy predicate $(D pred) to range $(D b), you may
want to use $(D copy(filter!(pred)(a), b)).

Example:
----
int[] a = [ 1, 5, 8, 9, 10, 1, 2, 0 ];
auto b = new int[a.length];
auto c = copy(filter!("(a & 1) == 1")(a), b);
assert(b[0 .. $ - c.length] == [ 1, 5, 9, 1 ]);
----

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
        immutable overlaps = source.ptr < target.ptr + target.length &&
                             target.ptr < source.ptr + source.length;

        if (overlaps)
        {
            return genericImpl(source, target);
        }
        else
        {
            // Array specialization.  This uses optimized memory copying
            // routines under the hood and is about 10-20x faster than the
            // generic implementation.
            enforce(target.length >= source.length,
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

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    {
        int[] a = [ 1, 5 ];
        int[] b = [ 9, 8 ];
        int[] c = new int[a.length + b.length + 10];
        auto d = copy(b, copy(a, c));
        assert(c[0 .. a.length + b.length] == a ~ b);
        assert(d.length == 10);
    }
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

Example:
----
int[] a = [ 100, 101, 102, 103 ];
int[] b = [ 0, 1, 2, 3 ];
auto c = swapRanges(a[1 .. 3], b[2 .. 4]);
assert(c[0].empty && c[1].empty);
assert(a == [ 100, 2, 3, 103 ]);
assert(b == [ 0, 1, 101, 102 ]);
----
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

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
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
swap). See also $(WEB sgi.com/tech/stl/_reverse.html, STL's _reverse).

Example:
----
int[] arr = [ 1, 2, 3 ];
reverse(arr);
assert(arr == [ 3, 2, 1 ]);
----
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

unittest
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

Example:
----
char[] arr = "hello\U00010143\u0100\U00010143".dup;
reverse(arr);
assert(arr == "\U00010143\u0100\U00010143olleh");
----
*/
void reverse(Char)(Char[] s)
if (isNarrowString!(Char[]) && !is(Char == const) && !is(Char == immutable))
{
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

unittest
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

The simplest use of $(D bringToFront) is for rotating elements in a
buffer. For example:

----
auto arr = [4, 5, 6, 7, 1, 2, 3];
bringToFront(arr[0 .. 4], arr[4 .. $]);
assert(arr == [ 1, 2, 3, 4, 5, 6, 7 ]);
----

The $(D front) range may actually "step over" the $(D back)
range. This is very useful with forward ranges that cannot compute
comfortably right-bounded subranges like $(D arr[0 .. 4]) above. In
the example below, $(D r2) is a right subrange of $(D r1).

----
auto list = SList!(int)(4, 5, 6, 7, 1, 2, 3);
auto r1 = list[];
auto r2 = list[]; popFrontN(r2, 4);
assert(equal(r2, [ 1, 2, 3 ]));
bringToFront(r1, r2);
assert(equal(list[], [ 1, 2, 3, 4, 5, 6, 7 ]));
----

Elements can be swapped across ranges of different types:

----
auto list = SList!(int)(4, 5, 6, 7);
auto vec = [ 1, 2, 3 ];
bringToFront(list[], vec);
assert(equal(list[], [ 1, 2, 3, 4 ]));
assert(equal(vec, [ 5, 6, 7 ]));
----

Performs $(BIGOH max(front.length, back.length)) evaluations of $(D
swap). See also $(WEB sgi.com/tech/stl/_rotate.html, STL's rotate).

Preconditions:

Either $(D front) and $(D back) are disjoint, or $(D back) is
reachable from $(D front) and $(D front) is not reachable from $(D
back).

Returns:

The number of elements brought to the front, i.e., the length of $(D
back).
*/
size_t bringToFront(Range1, Range2)(Range1 front, Range2 back)
    if (isInputRange!Range1 && isForwardRange!Range2)
{
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

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    // doc example
    {
        int[] arr = [4, 5, 6, 7, 1, 2, 3];
        auto p = bringToFront(arr[0 .. 4], arr[4 .. $]);
        assert(p == arr.length - 4);
        assert(arr == [ 1, 2, 3, 4, 5, 6, 7 ], text(arr));
    }
    {
        auto list = SList!(int)(4, 5, 6, 7, 1, 2, 3);
        auto r1 = list[];
        auto r2 = list[]; popFrontN(r2, 4);
        assert(equal(r2, [ 1, 2, 3 ]));
        bringToFront(r1, r2);
        assert(equal(list[], [ 1, 2, 3, 4, 5, 6, 7 ]));
    }
    {
        auto list = SList!(int)(4, 5, 6, 7);
        auto vec = [ 1, 2, 3 ];
        bringToFront(list[], vec);
        assert(equal(list[], [ 1, 2, 3, 4 ]));
        assert(equal(vec, [ 5, 6, 7 ]));
    }
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
SwapStrategy.unstable && isRandomAccessRange!Range &&
hasLength!Range), then elements are moved from the end of the range
into the slots to be filled. In this case, the absolute minimum of
moves is performed.)  $(LI Otherwise, if $(D s ==
SwapStrategy.unstable && isBidirectionalRange!Range &&
hasLength!Range), then elements are still moved from the end of the
range, but time is spent on advancing between slots by repeated calls
to $(D range.popFront).)  $(LI Otherwise, elements are moved incrementally
towards the front of $(D range); a given element is never moved
several times, but more elements are moved than in the previous
cases.))
 */
Range remove
(SwapStrategy s = SwapStrategy.stable, Range, Offset...)
(Range range, Offset offset)
if (isBidirectionalRange!Range && hasLength!Range && s != SwapStrategy.stable
    && Offset.length >= 1)
{
    enum bool tupleLeft = is(typeof(offset[0][0]))
        && is(typeof(offset[0][1]));
    enum bool tupleRight = is(typeof(offset[$ - 1][0]))
        && is(typeof(offset[$ - 1][1]));
    static if (!tupleLeft)
    {
        alias offset[0] lStart;
        auto lEnd = lStart + 1;
    }
    else
    {
        auto lStart = offset[0][0];
        auto lEnd = offset[0][1];
    }
    static if (!tupleRight)
    {
        alias offset[$ - 1] rStart;
        auto rEnd = rStart + 1;
    }
    else
    {
        auto rStart = offset[$ - 1][0];
        auto rEnd = offset[$ - 1][1];
    }
    // Begin. Test first to see if we need to remove the rightmost
    // element(s) in the range. In that case, life is simple - chop
    // and recurse.
    if (rEnd == range.length)
    {
        // must remove the last elements of the range
        range.popBackN(rEnd - rStart);
        static if (Offset.length > 1)
        {
            return .remove!(s, Range, Offset[0 .. $ - 1])
                (range, offset[0 .. $ - 1]);
        }
        else
        {
            return range;
        }
    }

    // Ok, there are "live" elements at the end of the range
    auto t = range;
    auto lDelta = lEnd - lStart, rDelta = rEnd - rStart;
    auto rid = min(lDelta, rDelta);
    foreach (i; 0 .. rid)
    {
        move(range.back, t.front);
        range.popBack();
        t.popFront();
    }
    if (rEnd - rStart == lEnd - lStart)
    {
        // We got rid of both left and right
        static if (Offset.length > 2)
        {
            return .remove!(s, Range, Offset[1 .. $ - 1])
                (range, offset[1 .. $ - 1]);
        }
        else
        {
            return range;
        }
    }
    else if (rEnd - rStart < lEnd - lStart)
    {
        // We got rid of the entire right subrange
        static if (Offset.length > 2)
        {
            return .remove!(s, Range)
                (range, tuple(lStart + rid, lEnd),
                        offset[1 .. $ - 1]);
        }
        else
        {
            auto tmp = tuple(lStart + rid, lEnd);
            return .remove!(s, Range, typeof(tmp))
                (range, tmp);
        }
    }
    else
    {
        // We got rid of the entire left subrange
        static if (Offset.length > 2)
        {
            return .remove!(s, Range)
                (range, offset[1 .. $ - 1],
                        tuple(rStart, lEnd - rid));
        }
        else
        {
            auto tmp = tuple(rStart, lEnd - rid);
            return .remove!(s, Range, typeof(tmp))
                (range, tmp);
        }
    }
}

// Ditto
Range remove
(SwapStrategy s = SwapStrategy.stable, Range, Offset...)
(Range range, Offset offset)
if ((isForwardRange!Range && !isBidirectionalRange!Range
                || !hasLength!Range || s == SwapStrategy.stable)
        && Offset.length >= 1)
{
    auto result = range;
    auto src = range, tgt = range;
    size_t pos;
    foreach (i; offset)
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
        assert(pos <= from);
        for (; pos < from; ++pos, src.popFront(), tgt.popFront())
        {
            move(src.front, tgt.front);
        }
        // now skip source to the "to" position
        src.popFrontN(delta);
        pos += delta;
        foreach (j; 0 .. delta) result.popBack();
    }
    // leftover move
    moveAll(src, tgt);
    return result;
}

unittest
{
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
}

/**
Reduces the length of the bidirectional range $(D range) by removing
elements that satisfy $(D pred). If $(D s = SwapStrategy.unstable),
elements are moved from the right end of the range over the elements
to eliminate. If $(D s = SwapStrategy.stable) (the default),
elements are moved progressively to front such that their relative
order is preserved. Returns the filtered range.

Example:
----
int[] a = [ 1, 2, 3, 2, 3, 4, 5, 2, 5, 6 ];
assert(remove!("a == 2")(a) == [ 1, 3, 3, 4, 5, 5, 6 ]);
----
 */
Range remove(alias pred, SwapStrategy s = SwapStrategy.stable, Range)
(Range range)
if (isBidirectionalRange!Range)
{
    auto result = range;
    static if (s != SwapStrategy.stable)
    {
        for (;!range.empty;)
        {
            if (!unaryFun!(pred)(range.front))
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

unittest
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
//     alias Iterator!(Range) It;
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
//     alias Iterator!(Range) It;
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

// partition
/**
Partitions a range in two using $(D pred) as a
predicate. Specifically, reorders the range $(D r = [left,
right$(RPAREN)) using $(D swap) such that all elements $(D i) for
which $(D pred(i)) is $(D true) come before all elements $(D j) for
which $(D pred(j)) returns $(D false).

Performs $(BIGOH r.length) (if unstable or semistable) or $(BIGOH
r.length * log(r.length)) (if stable) evaluations of $(D less) and $(D
swap). The unstable version computes the minimum possible evaluations
of $(D swap) (roughly half of those performed by the semistable
version).

See also STL's $(WEB sgi.com/tech/stl/_partition.html, _partition) and
$(WEB sgi.com/tech/stl/stable_partition.html, stable_partition).

Returns:

The right part of $(D r) after partitioning.

If $(D ss == SwapStrategy.stable), $(D partition) preserves the
relative ordering of all elements $(D a), $(D b) in $(D r) for which
$(D pred(a) == pred(b)). If $(D ss == SwapStrategy.semistable), $(D
partition) preserves the relative ordering of all elements $(D a), $(D
b) in the left part of $(D r) for which $(D pred(a) == pred(b)).

Example:

----
auto Arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
auto arr = Arr.dup;
static bool even(int a) { return (a & 1) == 0; }
// Partition arr such that even numbers come first
auto r = partition!(even)(arr);
// Now arr is separated in evens and odds.
// Numbers may have become shuffled due to instability
assert(r == arr[5 .. $]);
assert(count!(even)(arr[0 .. 5]) == 5);
assert(find!(even)(r).empty);

// Can also specify the predicate as a string.
// Use 'a' as the predicate argument name
arr[] = Arr[];
r = partition!(q{(a & 1) == 0})(arr);
assert(r == arr[5 .. $]);

// Now for a stable partition:
arr[] = Arr[];
r = partition!(q{(a & 1) == 0}, SwapStrategy.stable)(arr);
// Now arr is [2 4 6 8 10 1 3 5 7 9], and r points to 1
assert(arr == [2, 4, 6, 8, 10, 1, 3, 5, 7, 9] && r == arr[5 .. $]);

// In case the predicate needs to hold its own state, use a delegate:
arr[] = Arr[];
int x = 3;
// Put stuff greater than 3 on the left
bool fun(int a) { return a > x; }
r = partition!(fun, SwapStrategy.semistable)(arr);
// Now arr is [4 5 6 7 8 9 10 2 3 1] and r points to 2
assert(arr == [4, 5, 6, 7, 8, 9, 10, 2, 3, 1] && r == arr[7 .. $]);
----
*/
Range partition(alias predicate,
        SwapStrategy ss = SwapStrategy.unstable, Range)(Range r)
    if ((ss == SwapStrategy.stable && isRandomAccessRange!(Range))
            || (ss != SwapStrategy.stable && isForwardRange!(Range)))
{
    alias unaryFun!(predicate) pred;
    if (r.empty) return r;
    static if (ss == SwapStrategy.stable)
    {
        if (r.length == 1)
        {
            if (pred(r.front)) r.popFront();
            return r;
        }
        const middle = r.length / 2;
        alias .partition!(pred, ss, Range) recurse;
        auto lower = recurse(r[0 .. middle]);
        auto upper = recurse(r[middle .. $]);
        bringToFront(lower, r[middle .. r.length - upper.length]);
        return r[r.length - lower.length - upper.length .. r.length];
    }
    else static if (ss == SwapStrategy.semistable)
    {
        for (; !r.empty; r.popFront())
        {
            // skip the initial portion of "correct" elements
            if (pred(r.front)) continue;
            // hit the first "bad" element
            auto result = r;
            for (r.popFront(); !r.empty; r.popFront())
            {
                if (!pred(r.front)) continue;
                swap(result.front, r.front);
                result.popFront();
            }
            return result;
        }
        return r;
    }
    else // ss == SwapStrategy.unstable
    {
        // Inspired from www.stepanovpapers.com/PAM3-partition_notes.pdf,
        // section "Bidirectional Partition Algorithm (Hoare)"
        auto result = r;
        for (;;)
        {
            for (;;)
            {
                if (r.empty) return result;
                if (!pred(r.front)) break;
                r.popFront();
                result.popFront();
            }
            // found the left bound
            assert(!r.empty);
            for (;;)
            {
                if (pred(r.back)) break;
                r.popBack();
                if (r.empty) return result;
            }
            // found the right bound, swap & make progress
            static if (is(typeof(swap(r.front, r.back))))
            {
                swap(r.front, r.back);
            }
            else
            {
                auto t1 = moveFront(r), t2 = moveBack(r);
                r.front = t2;
                r.back = t1;
            }
            r.popFront();
            result.popFront();
            r.popBack();
        }
    }
}

unittest // partition
{
    auto Arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto arr = Arr.dup;
    static bool even(int a) { return (a & 1) == 0; }
// Partition a such that even numbers come first
    auto p1 = partition!(even)(arr);
// Now arr is separated in evens and odds.
    assert(p1 == arr[5 .. $], text(p1));
    assert(count!(even)(arr[0 .. $ - p1.length]) == p1.length);
    assert(find!(even)(p1).empty);
// Notice that numbers have become shuffled due to instability
    arr[] = Arr[];
// Can also specify the predicate as a string.
// Use 'a' as the predicate argument name
    p1 = partition!(q{(a & 1) == 0})(arr);
    assert(p1 == arr[5 .. $]);
// Same result as above. Now for a stable partition:
    arr[] = Arr[];
    p1 = partition!(q{(a & 1) == 0}, SwapStrategy.stable)(arr);
// Now arr is [2 4 6 8 10 1 3 5 7 9], and p points to 1
    assert(arr == [2, 4, 6, 8, 10, 1, 3, 5, 7, 9], text(arr));
    assert(p1 == arr[5 .. $], text(p1));
// In case the predicate needs to hold its own state, use a delegate:
    arr[] = Arr[];
    int x = 3;
// Put stuff greater than 3 on the left
    bool fun(int a) { return a > x; }
    p1 = partition!(fun, SwapStrategy.semistable)(arr);
// Now arr is [4 5 6 7 8 9 10 2 3 1] and p points to 2
    assert(arr == [4, 5, 6, 7, 8, 9, 10, 2, 3, 1] && p1 == arr[7 .. $]);

    // test with random data
    auto a = rndstuff!(int)();
    partition!(even)(a);
    assert(isPartitioned!(even)(a));
    auto b = rndstuff!(string)();
    partition!(`a.length < 5`)(b);
    assert(isPartitioned!(`a.length < 5`)(b));
}

/**
Returns $(D true) if $(D r) is partitioned according to predicate $(D
pred).

Example:
----
int[] r = [ 1, 3, 5, 7, 8, 2, 4, ];
assert(isPartitioned!("a & 1")(r));
----
 */
bool isPartitioned(alias pred, Range)(Range r)
    if (isForwardRange!(Range))
{
    for (; !r.empty; r.popFront())
    {
        if (unaryFun!(pred)(r.front)) continue;
        for (r.popFront(); !r.empty; r.popFront())
        {
            if (unaryFun!(pred)(r.front)) return false;
        }
        break;
    }
    return true;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] r = [ 1, 3, 5, 7, 8, 2, 4, ];
    assert(isPartitioned!("a & 1")(r));
}

// partition3
/**
Rearranges elements in $(D r) in three adjacent ranges and returns
them. The first and leftmost range only contains elements in $(D r)
less than $(D pivot). The second and middle range only contains
elements in $(D r) that are equal to $(D pivot). Finally, the third
and rightmost range only contains elements in $(D r) that are greater
than $(D pivot). The less-than test is defined by the binary function
$(D less).

Example:
----
auto a = [ 8, 3, 4, 1, 4, 7, 4 ];
auto pieces = partition3(a, 4);
assert(a == [ 1, 3, 4, 4, 4, 7, 8 ]);
assert(pieces[0] == [ 1, 3 ]);
assert(pieces[1] == [ 4, 4, 4 ]);
assert(pieces[2] == [ 7, 8 ]);
----

BUGS: stable $(D partition3) has not been implemented yet.
 */
auto partition3(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable, Range, E)
(Range r, E pivot)
if (ss == SwapStrategy.unstable && isRandomAccessRange!Range
        && hasSwappableElements!Range && hasLength!Range
        && is(typeof(binaryFun!less(r.front, pivot)) == bool)
        && is(typeof(binaryFun!less(pivot, r.front)) == bool)
        && is(typeof(binaryFun!less(r.front, r.front)) == bool))
{
    // The algorithm is described in "Engineering a sort function" by
    // Jon Bentley et al, pp 1257.

    alias binaryFun!less lessFun;
    size_t i, j, k = r.length, l = k;

 bigloop:
    for (;;)
    {
        for (;; ++j)
        {
            if (j == k) break bigloop;
            assert(j < r.length);
            if (lessFun(r[j], pivot)) continue;
            if (lessFun(pivot, r[j])) break;
            swap(r[i++], r[j]);
        }
        assert(j < k);
        for (;;)
        {
            assert(k > 0);
            if (!lessFun(pivot, r[--k]))
            {
                if (lessFun(r[k], pivot)) break;
                swap(r[k], r[--l]);
            }
            if (j == k) break bigloop;
        }
        // Here we know r[j] > pivot && r[k] < pivot
        swap(r[j++], r[k]);
    }

    // Swap the equal ranges from the extremes into the middle
    auto strictlyLess = j - i, strictlyGreater = l - k;
    auto swapLen = min(i, strictlyLess);
    swapRanges(r[0 .. swapLen], r[j - swapLen .. j]);
    swapLen = min(r.length - l, strictlyGreater);
    swapRanges(r[k .. k + swapLen], r[r.length - swapLen .. r.length]);
    return tuple(r[0 .. strictlyLess],
            r[strictlyLess .. r.length - strictlyGreater],
            r[r.length - strictlyGreater .. r.length]);
}

unittest
{
    auto a = [ 8, 3, 4, 1, 4, 7, 4 ];
    auto pieces = partition3(a, 4);
    assert(a == [ 1, 3, 4, 4, 4, 8, 7 ]);
    assert(pieces[0] == [ 1, 3 ]);
    assert(pieces[1] == [ 4, 4, 4 ]);
    assert(pieces[2] == [ 8, 7 ]);

    a = null;
    pieces = partition3(a, 4);
    assert(a.empty);
    assert(pieces[0].empty);
    assert(pieces[1].empty);
    assert(pieces[2].empty);

    a.length = uniform(0, 100);
    foreach (ref e; a)
    {
        e = uniform(0, 50);
    }
    pieces = partition3(a, 25);
    assert(pieces[0].length + pieces[1].length + pieces[2].length == a.length);
    foreach (e; pieces[0])
    {
        assert(e < 25);
    }
    foreach (e; pieces[1])
    {
        assert(e == 25);
    }
    foreach (e; pieces[2])
    {
        assert(e > 25);
    }
}

// topN
/**
Reorders the range $(D r) using $(D swap) such that $(D r[nth]) refers
to the element that would fall there if the range were fully
sorted. In addition, it also partitions $(D r) such that all elements
$(D e1) from $(D r[0]) to $(D r[nth]) satisfy $(D !less(r[nth], e1)),
and all elements $(D e2) from $(D r[nth]) to $(D r[r.length]) satisfy
$(D !less(e2, r[nth])). Effectively, it finds the nth smallest
(according to $(D less)) elements in $(D r). Performs an expected
$(BIGOH r.length) (if unstable) or $(BIGOH r.length * log(r.length))
(if stable) evaluations of $(D less) and $(D swap). See also $(WEB
sgi.com/tech/stl/nth_element.html, STL's nth_element).

If $(D n >= r.length), the algorithm has no effect.

Examples:
----
int[] v = [ 25, 7, 9, 2, 0, 5, 21 ];
auto n = 4;
topN!(less)(v, n);
assert(v[n] == 9);
// Equivalent form:
topN!("a < b")(v, n);
assert(v[n] == 9);
----

BUGS:

Stable topN has not been implemented yet.
*/
void topN(alias less = "a < b",
        SwapStrategy ss = SwapStrategy.unstable,
        Range)(Range r, size_t nth)
    if (isRandomAccessRange!(Range) && hasLength!Range)
{
    static assert(ss == SwapStrategy.unstable,
            "Stable topN not yet implemented");
    while (r.length > nth)
    {
        auto pivot = uniform(0, r.length);
        swap(r[pivot], r.back);
        assert(!binaryFun!(less)(r.back, r.back));
        auto right = partition!((a) => binaryFun!less(a, r.back), ss)(r);
        assert(right.length >= 1);
        swap(right.front, r.back);
        pivot = r.length - right.length;
        if (pivot == nth)
        {
            return;
        }
        if (pivot < nth)
        {
            ++pivot;
            r = r[pivot .. $];
            nth -= pivot;
        }
        else
        {
            assert(pivot < r.length);
            r = r[0 .. pivot];
        }
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    //scope(failure) writeln(stderr, "Failure testing algorithm");
    //auto v = ([ 25, 7, 9, 2, 0, 5, 21 ]).dup;
    int[] v = [ 7, 6, 5, 4, 3, 2, 1, 0 ];
    ptrdiff_t n = 3;
    topN!("a < b")(v, n);
    assert(reduce!max(v[0 .. n]) <= v[n]);
    assert(reduce!min(v[n + 1 .. $]) >= v[n]);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 3;
    topN(v, n);
    assert(reduce!max(v[0 .. n]) <= v[n]);
    assert(reduce!min(v[n + 1 .. $]) >= v[n]);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 1;
    topN(v, n);
    assert(reduce!max(v[0 .. n]) <= v[n]);
    assert(reduce!min(v[n + 1 .. $]) >= v[n]);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = v.length - 1;
    topN(v, n);
    assert(v[n] == 7);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 0;
    topN(v, n);
    assert(v[n] == 1);

    double[][] v1 = [[-10, -5], [-10, -3], [-10, -5], [-10, -4],
            [-10, -5], [-9, -5], [-9, -3], [-9, -5],];

    // double[][] v1 = [ [-10, -5], [-10, -4], [-9, -5], [-9, -5],
    //         [-10, -5], [-10, -3], [-10, -5], [-9, -3],];
    double[]*[] idx = [ &v1[0], &v1[1], &v1[2], &v1[3], &v1[4], &v1[5], &v1[6],
            &v1[7], ];

    auto mid = v1.length / 2;
    topN!((a, b){ return (*a)[1] < (*b)[1]; })(idx, mid);
    foreach (e; idx[0 .. mid]) assert((*e)[1] <= (*idx[mid])[1]);
    foreach (e; idx[mid .. $]) assert((*e)[1] >= (*idx[mid])[1]);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = new int[uniform(1, 10000)];
        foreach (ref e; a) e = uniform(-1000, 1000);
    auto k = uniform(0, a.length);
    topN(a, k);
    if (k > 0)
    {
        auto left = reduce!max(a[0 .. k]);
        assert(left <= a[k]);
    }
    if (k + 1 < a.length)
    {
        auto right = reduce!min(a[k + 1 .. $]);
        assert(right >= a[k]);
    }
}

/**
Stores the smallest elements of the two ranges in the left-hand range.
 */
void topN(alias less = "a < b",
        SwapStrategy ss = SwapStrategy.unstable,
        Range1, Range2)(Range1 r1, Range2 r2)
    if (isRandomAccessRange!(Range1) && hasLength!Range1 &&
            isInputRange!Range2 && is(ElementType!Range1 == ElementType!Range2))
{
    static assert(ss == SwapStrategy.unstable,
            "Stable topN not yet implemented");
    auto heap = BinaryHeap!Range1(r1);
    for (; !r2.empty; r2.popFront())
    {
        heap.conditionalInsert(r2.front);
    }
}

/// Ditto
unittest
{
    int[] a = [ 5, 7, 2, 6, 7 ];
    int[] b = [ 2, 1, 5, 6, 7, 3, 0 ];
    topN(a, b);
    sort(a);
    assert(a == [0, 1, 2, 2, 3]);
}

// sort
/**
Sorts a random-access range according to the predicate $(D less). Performs
$(BIGOH r.length * log(r.length)) (if unstable) or $(BIGOH r.length *
log(r.length) * log(r.length)) (if stable) evaluations of $(D less)
and $(D swap). See also STL's $(WEB sgi.com/tech/stl/_sort.html, _sort)
and $(WEB sgi.com/tech/stl/stable_sort.html, stable_sort).

$(D sort) returns a $(XREF range, SortedRange) over the original range, which
functions that can take advantage of sorted data can then use to know that the
range is sorted and adjust accordingly. The $(XREF range, SortedRange) is a
wrapper around the original range, so both it and the original range are sorted,
but other functions won't know that the original range has been sorted, whereas
they $(I can) know that $(XREF range, SortedRange) has been sorted.

See_Also:
    $(XREF range, assumeSorted)

Remark: Stable sort is implementated as Timsort, the original code at
$(WEB github.com/Xinok/XSort, XSort) by Xinok, public domain.

Example:
----
int[] array = [ 1, 2, 3, 4 ];
// sort in descending order
sort!("a > b")(array);
assert(array == [ 4, 3, 2, 1 ]);
// sort in ascending order
sort(array);
assert(array == [ 1, 2, 3, 4 ]);
// sort with a delegate
bool myComp(int x, int y) { return x > y; }
sort!(myComp)(array);
assert(array == [ 4, 3, 2, 1 ]);
// Showcase stable sorting
string[] words = [ "aBc", "a", "abc", "b", "ABC", "c" ];
sort!("toUpper(a) < toUpper(b)", SwapStrategy.stable)(words);
assert(words == [ "a", "aBc", "abc", "ABC", "b", "c" ]);
----
*/

SortedRange!(Range, less)
sort(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
        Range)(Range r)
    if (((ss == SwapStrategy.unstable && (hasSwappableElements!Range ||
                                          hasAssignableElements!Range)) ||
         (ss != SwapStrategy.unstable && hasAssignableElements!Range)) &&
        isRandomAccessRange!Range &&
        hasSlicing!Range &&
        hasLength!Range)
    /+ Unstable sorting uses the quicksort algorithm, which uses swapAt,
       which either uses swap(...), requiring swappable elements, or just
       swaps using assignment.
       Stable sorting uses TimSort, which needs to copy elements into a buffer,
       requiring assignable elements. +/
{
    alias binaryFun!(less) lessFun;
    alias typeof(lessFun(r.front, r.front)) LessRet;    // instantiate lessFun
    static if (is(LessRet == bool))
    {
        static if (ss == SwapStrategy.unstable)
            quickSortImpl!(lessFun)(r);
        else //use Tim Sort for semistable & stable
            TimSortImpl!(lessFun, Range).sort(r, null);
        static if (is(typeof(text(r))))
        {
            enum maxLen = 8;
            assert(isSorted!lessFun(r), text("Failed to sort range of type ",
                            Range.stringof, ". Actual result is: ",
                            r[0 .. r.length > maxLen ? maxLen : r.length ],
                            r.length > maxLen ? "..." : ""));
        }
        else
            assert(isSorted!lessFun(r), text("Unable to sort range of type ",
                            Range.stringof, ": <unable to print elements>"));
    }
    else
    {
        static assert(false, "Invalid predicate passed to sort: "~less);
    }
    return assumeSorted!less(r);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    // sort using delegate
    int a[] = new int[100];
    auto rnd = Random(unpredictableSeed);
    foreach (ref e; a) {
        e = uniform(-100, 100, rnd);
    }

    int i = 0;
    bool greater2(int a, int b) { return a + i > b + i; }
    bool delegate(int, int) greater = &greater2;
    sort!(greater)(a);
    assert(isSorted!(greater)(a));

    // sort using string
    sort!("a < b")(a);
    assert(isSorted!("a < b")(a));

    // sort using function; all elements equal
    foreach (ref e; a) {
        e = 5;
    }
    static bool less(int a, int b) { return a < b; }
    sort!(less)(a);
    assert(isSorted!(less)(a));

    string[] words = [ "aBc", "a", "abc", "b", "ABC", "c" ];
    bool lessi(string a, string b) { return toUpper(a) < toUpper(b); }
    sort!(lessi, SwapStrategy.stable)(words);
    assert(words == [ "a", "aBc", "abc", "ABC", "b", "c" ]);

    // sort using ternary predicate
    //sort!("b - a")(a);
    //assert(isSorted!(less)(a));

    a = rndstuff!(int)();
    sort(a);
    assert(isSorted(a));
    auto b = rndstuff!(string)();
    sort!("toLower(a) < toLower(b)")(b);
    assert(isSorted!("toUpper(a) < toUpper(b)")(b));
}

private template validPredicates(E, less...) {
    static if (less.length == 0)
        enum validPredicates = true;
    else static if (less.length == 1 && is(typeof(less[0]) == SwapStrategy))
        enum validPredicates = true;
    else
        enum validPredicates =
            is(typeof((E a, E b){ bool r = binaryFun!(less[0])(a, b); }))
            && validPredicates!(E, less[1 .. $]);
}

/**
$(D void multiSort(Range)(Range r)
    if (validPredicates!(ElementType!Range, less));)

Sorts a range by multiple keys. The call $(D multiSort!("a.id < b.id",
"a.date > b.date")(r)) sorts the range $(D r) by $(D id) ascending,
and sorts elements that have the same $(D id) by $(D date)
descending. Such a call is equivalent to $(D sort!"a.id != b.id ? a.id
< b.id : a.date > b.date"(r)), but $(D multiSort) is faster because it
does fewer comparisons (in addition to being more convenient).

Example:
----
static struct Point { int x, y; }
auto pts1 = [ Point(0, 0), Point(5, 5), Point(0, 1), Point(0, 2) ];
auto pts2 = [ Point(0, 0), Point(0, 1), Point(0, 2), Point(5, 5) ];
multiSort!("a.x < b.x", "a.y < b.y", SwapStrategy.unstable)(pts1);
assert(pts1 == pts2);
----
 */
template multiSort(less...) //if (less.length > 1)
{
    void multiSort(Range)(Range r)
    if (validPredicates!(ElementType!Range, less))
    {
        static if (is(typeof(less[$ - 1]) == SwapStrategy))
        {
            enum ss = less[$ - 1];
            alias less[0 .. $ - 1] funs;
        }
        else
        {
            alias SwapStrategy.unstable ss;
            alias less funs;
        }
        alias binaryFun!(funs[0]) lessFun;

        static if (funs.length > 1)
        {
            while (r.length > 1)
            {
                auto p = getPivot!lessFun(r);
                auto t = partition3!(less[0], ss)(r, r[p]);
                if (t[0].length <= t[2].length)
                {
                    .multiSort!less(t[0]);
                    .multiSort!(less[1 .. $])(t[1]);
                    r = t[2];
                }
                else
                {
                    .multiSort!(less[1 .. $])(t[1]);
                    .multiSort!less(t[2]);
                    r = t[0];
                }
            }
        }
        else
        {
            sort!(lessFun, ss)(r);
        }
    }
}

unittest
{
    static struct Point { int x, y; }
    auto pts1 = [ Point(5, 6), Point(1, 0), Point(5, 7), Point(1, 1), Point(1, 2), Point(0, 1) ];
    auto pts2 = [ Point(0, 1), Point(1, 0), Point(1, 1), Point(1, 2), Point(5, 6), Point(5, 7) ];
    static assert(validPredicates!(Point, "a.x < b.x", "a.y < b.y"));
    multiSort!("a.x < b.x", "a.y < b.y", SwapStrategy.unstable)(pts1);
    assert(pts1 == pts2);

    auto pts3 = indexed(pts1, iota(pts1.length));
    multiSort!("a.x < b.x", "a.y < b.y", SwapStrategy.unstable)(pts3);
    assert(equal(pts3, pts2));
}

unittest //issue 9160 (L-value only comparators)
{
    static struct A
    {
        int x;
        int y;
    }

    static bool byX(const ref A lhs, const ref A rhs)
    {
        return lhs.x < rhs.x;
    }

    static bool byY(const ref A lhs, const ref A rhs)
    {
        return lhs.y < rhs.y;
    }

    auto points = [ A(4, 1), A(2, 4)];
    multiSort!(byX, byY)(points);
    assert(points[0] == A(2, 4));
    assert(points[1] == A(4, 1));
}

private size_t getPivot(alias less, Range)(Range r)
{
    // This algorithm sorts the first, middle and last elements of r,
    // then returns the index of the middle element.  In effect, it uses the
    // median-of-three heuristic.

    alias binaryFun!(less) pred;
    immutable len = r.length;
    immutable size_t mid = len / 2;
    immutable uint result = ((cast(uint) (pred(r[0], r[mid]))) << 2) |
                            ((cast(uint) (pred(r[0], r[len - 1]))) << 1) |
                            (cast(uint) (pred(r[mid], r[len - 1])));

    switch(result) {
        case 0b001:
            swapAt(r, 0, len - 1);
            swapAt(r, 0, mid);
            break;
        case 0b110:
            swapAt(r, mid, len - 1);
            break;
        case 0b011:
            swapAt(r, 0, mid);
            break;
        case 0b100:
            swapAt(r, mid, len - 1);
            swapAt(r, 0, mid);
            break;
        case 0b000:
            swapAt(r, 0, len - 1);
            break;
        case 0b111:
            break;
        default:
            assert(0);
    }

    return mid;
}

private void optimisticInsertionSort(alias less, Range)(Range r)
{
    alias binaryFun!(less) pred;
    if (r.length < 2) {
        return ;
    }

    immutable maxJ = r.length - 1;
    for (size_t i = r.length - 2; i != size_t.max; --i) {
        size_t j = i;
        auto temp = r[i];

        for (; j < maxJ && pred(r[j + 1], temp); ++j) {
            r[j] = r[j + 1];
        }

        r[j] = temp;
    }
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto rnd = Random(1);
    int a[] = new int[uniform(100, 200, rnd)];
    foreach (ref e; a) {
        e = uniform(-100, 100, rnd);
    }

    optimisticInsertionSort!(binaryFun!("a < b"), int[])(a);
    assert(isSorted(a));
}

//private
void swapAt(R)(R r, size_t i1, size_t i2)
{
    static if (is(typeof(&r[i1])))
    {
        swap(r[i1], r[i2]);
    }
    else
    {
        if (i1 == i2) return;
        auto t1 = moveAt(r, i1);
        auto t2 = moveAt(r, i2);
        r[i2] = t1;
        r[i1] = t2;
    }
}

private void quickSortImpl(alias less, Range)(Range r)
{
    alias ElementType!(Range) Elem;
    enum size_t optimisticInsertionSortGetsBetter = 25;
    static assert(optimisticInsertionSortGetsBetter >= 1);

    // partition
    while (r.length > optimisticInsertionSortGetsBetter)
    {
        const pivotIdx = getPivot!(less)(r);
        auto pivot = r[pivotIdx];

        alias binaryFun!(less) pred;

        // partition
        swapAt(r, pivotIdx, r.length - 1);
        size_t lessI = size_t.max, greaterI = r.length - 1;

        while (true)
        {
            while (pred(r[++lessI], pivot)) {}
            while (greaterI > 0 && pred(pivot, r[--greaterI])) {}

            if (lessI >= greaterI)
            {
                break;
            }
            swapAt(r, lessI, greaterI);
        }

        swapAt(r, r.length - 1, lessI);
        auto right = r[lessI + 1 .. r.length];

        auto left = r[0 .. min(lessI, greaterI + 1)];
        if (right.length > left.length)
        {
            swap(left, right);
        }
        .quickSortImpl!(less, Range)(right);
        r = left;
    }
    // residual sort
    static if (optimisticInsertionSortGetsBetter > 1)
    {
        optimisticInsertionSort!(less, Range)(r);
    }
}

/+
    Tim Sort for Random-Access Ranges

    Written and tested for DMD 2.059 and Phobos

    Authors:  Xinok
    License:  Public Domain
+/

// Tim Sort implementation
private template TimSortImpl(alias pred, R)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasSlicing!R);
    static assert(hasAssignableElements!R);

    alias ElementType!R T;

    alias binaryFun!pred less;
    bool greater(T a, T b){ return less(b, a); }
    bool greaterEqual(T a, T b){ return !less(a, b); }
    bool lessEqual(T a, T b){ return !less(b, a); }

    enum minimalMerge = 128;
    enum minimalGallop = 7;
    enum minimalStorage = 256;
    enum stackSize = 40;

    struct Slice{ size_t base, length; }

    // Entry point for tim sort
    void sort(R range, T[] temp)
    {
        // Do insertion sort on small range
        if (range.length <= minimalMerge)
        {
            binaryInsertionSort(range);
            return;
        }

        immutable minRun = minRunLength(range.length);
        immutable minTemp = min(range.length / 2, minimalStorage);
        size_t minGallop = minimalGallop;
        Slice[stackSize] stack = void;
        size_t stackLen = 0;

        // Allocate temporary memory if not provided by user
        if (temp.length < minTemp)
        {
            if (__ctfe) temp.length = minTemp;
            else temp = uninitializedArray!(T[])(minTemp);
        }

        for (size_t i = 0; i < range.length; )
        {
            // Find length of first run in list
            size_t runLen = firstRun(range[i .. range.length]);

            // If run has less than minRun elements, extend using insertion sort
            if (runLen < minRun)
            {
                // Do not run farther than the length of the range
                immutable force = range.length - i > minRun ? minRun : range.length - i;
                binaryInsertionSort(range[i .. i + force], runLen);
                runLen = force;
            }

            // Push run onto stack
            stack[stackLen++] = Slice(i, runLen);
            i += runLen;

            // Collapse stack so that (e1 >= e2 + e3 && e2 >= e3)
            // STACK is | ... e1 e2 e3 >
            while (stackLen > 1)
            {
                immutable run3 = stackLen - 1;
                immutable run2 = stackLen - 2;
                immutable run1 = stackLen - 3;
                if (stackLen >= 3 && stack[run1].length <= stack[run2].length + stack[run3].length)
                {
                    immutable at = stack[run1].length <= stack[run3].length
                        ? run1 : run2;
                    mergeAt(range, stack[0 .. stackLen], at, minGallop, temp);
                    --stackLen;
                }
                else if (stack[run2].length <= stack[run3].length)
                {
                    mergeAt(range, stack[0 .. stackLen], run2, minGallop, temp);
                    --stackLen;
                }
                else break;
            }
        }

        // Force collapse stack until there is only one run left
        while (stackLen > 1)
        {
            immutable run3 = stackLen - 1;
            immutable run2 = stackLen - 2;
            immutable run1 = stackLen - 3;
            immutable at = stackLen >= 3 && stack[run1].length <= stack[run3].length
                ? run1 : run2;
            mergeAt(range, stack[0 .. stackLen], at, minGallop, temp);
            --stackLen;
        }
    }

    // Calculates optimal value for minRun:
    // take first 6 bits of n and add 1 if any lower bits are set
    pure size_t minRunLength(size_t n)
    {
        immutable shift = bsr(n)-5;
        auto result = (n>>shift) + !!(n & ~((1<<shift)-1));
        return result;
    }

    // Returns length of first run in range
    size_t firstRun(R range)
    out(ret)
    {
        assert(ret <= range.length);
    }
    body
    {
        if (range.length < 2) return range.length;

        size_t i = 2;
        if (lessEqual(range[0], range[1]))
        {
            while (i < range.length && lessEqual(range[i-1], range[i])) ++i;
        }
        else
        {
            while (i < range.length && greater(range[i-1], range[i])) ++i;
            reverse(range[0 .. i]);
        }
        return i;
    }

    // A binary insertion sort for building runs up to minRun length
    void binaryInsertionSort(R range, size_t sortedLen = 1)
    out
    {
        if (!__ctfe) assert(isSorted!pred(range));
    }
    body
    {
        for (; sortedLen < range.length; ++sortedLen)
        {
            T item = moveAt(range, sortedLen);
            size_t lower = 0;
            size_t upper = sortedLen;
            while (upper != lower)
            {
                size_t center = (lower + upper) / 2;
                if (less(item, range[center])) upper = center;
                else lower = center + 1;
            }
            //Currently (DMD 2.061) moveAll+retro is slightly less
            //efficient then stright 'for' loop
            //11 instructions vs 7 in the innermost loop [checked on Win32]
            //moveAll(retro(range[lower .. sortedLen]),
            //            retro(range[lower+1 .. sortedLen+1]));
            for(upper=sortedLen; upper>lower; upper--)
                range[upper] = moveAt(range, upper-1);
            range[lower] = move(item);
        }
    }

    // Merge two runs in stack (at, at + 1)
    void mergeAt(R range, Slice[] stack, immutable size_t at, ref size_t minGallop, ref T[] temp)
    in
    {
        assert(stack.length >= 2);
        assert(at == stack.length - 2 || at == stack.length - 3);
    }
    body
    {
        immutable base = stack[at].base;
        immutable mid  = stack[at].length;
        immutable len  = stack[at + 1].length + mid;

        // Pop run from stack
        stack[at] = Slice(base, len);
        if (at == stack.length - 3) stack[$ - 2] = stack[$ - 1];

        // Merge runs (at, at + 1)
        return merge(range[base .. base + len], mid, minGallop, temp);
    }

    // Merge two runs in a range. Mid is the starting index of the second run.
    // minGallop and temp are references; The calling function must receive the updated values.
    void merge(R range, size_t mid, ref size_t minGallop, ref T[] temp)
    in
    {
        if (!__ctfe)
        {
            assert(isSorted!pred(range[0 .. mid]));
            assert(isSorted!pred(range[mid .. range.length]));
        }
    }
    body
    {
        assert(mid < range.length);

        // Reduce range of elements
        immutable firstElement = gallopForwardUpper(range[0 .. mid], range[mid]);
        immutable lastElement  = gallopReverseLower(range[mid .. range.length], range[mid - 1]) + mid;
        range = range[firstElement .. lastElement];
        mid -= firstElement;

        if (mid == 0 || mid == range.length) return;

        // Call function which will copy smaller run into temporary memory
        if (mid <= range.length / 2)
        {
            temp = ensureCapacity(mid, temp);
            minGallop = mergeLo(range, mid, minGallop, temp);
        }
        else
        {
            temp = ensureCapacity(range.length - mid, temp);
            minGallop = mergeHi(range, mid, minGallop, temp);
        }
    }

    // Enlarge size of temporary memory if needed
    T[] ensureCapacity(size_t minCapacity, T[] temp)
    out(ret)
    {
        assert(ret.length >= minCapacity);
    }
    body
    {
        if (temp.length < minCapacity)
        {
            size_t newSize = 1<<(bsr(minCapacity)+1);
            //Test for overflow
            if (newSize < minCapacity) newSize = minCapacity;

            if (__ctfe) temp.length = newSize;
            else temp = uninitializedArray!(T[])(newSize);
        }
        return temp;
    }

    // Merge front to back. Returns new value of minGallop.
    // temp must be large enough to store range[0 .. mid]
    size_t mergeLo(R range, immutable size_t mid, size_t minGallop, T[] temp)
    out
    {
        if (!__ctfe) assert(isSorted!pred(range));
    }
    body
    {
        assert(mid <= range.length);
        assert(temp.length >= mid);

        // Copy run into temporary memory
        temp = temp[0 .. mid];
        copy(range[0 .. mid], temp);

        // Move first element into place
        range[0] = range[mid];

        size_t i = 1, lef = 0, rig = mid + 1;
        size_t count_lef, count_rig;
        immutable lef_end = temp.length - 1;

        if (lef < lef_end && rig < range.length)
        outer: while(true)
        {
            count_lef = 0;
            count_rig = 0;

            // Linear merge
            while ((count_lef | count_rig) < minGallop)
            {
                if (lessEqual(temp[lef], range[rig]))
                {
                    range[i++] = temp[lef++];
                    if(lef >= lef_end) break outer;
                    ++count_lef;
                    count_rig = 0;
                }
                else
                {
                    range[i++] = range[rig++];
                    if(rig >= range.length) break outer;
                    count_lef = 0;
                    ++count_rig;
                }
            }

            // Gallop merge
            do
            {
                count_lef = gallopForwardUpper(temp[lef .. $], range[rig]);
                foreach (j; 0 .. count_lef) range[i++] = temp[lef++];
                if(lef >= temp.length) break outer;

                count_rig = gallopForwardLower(range[rig .. range.length], temp[lef]);
                foreach (j; 0 .. count_rig) range[i++] = range[rig++];
                if (rig >= range.length) while(true)
                {
                    range[i++] = temp[lef++];
                    if(lef >= temp.length) break outer;
                }

                if (minGallop > 0) --minGallop;
            }
            while (count_lef >= minimalGallop || count_rig >= minimalGallop);

            minGallop += 2;
        }

        // Move remaining elements from right
        while (rig < range.length)
            range[i++] = range[rig++];

        // Move remaining elements from left
        while (lef < temp.length)
            range[i++] = temp[lef++];

        return minGallop > 0 ? minGallop : 1;
    }

    // Merge back to front. Returns new value of minGallop.
    // temp must be large enough to store range[mid .. range.length]
    size_t mergeHi(R range, immutable size_t mid, size_t minGallop, T[] temp)
    out
    {
        if (!__ctfe) assert(isSorted!pred(range));
    }
    body
    {
        assert(mid <= range.length);
        assert(temp.length >= range.length - mid);

        // Copy run into temporary memory
        temp = temp[0 .. range.length - mid];
        copy(range[mid .. range.length], temp);

        // Move first element into place
        range[range.length - 1] = range[mid - 1];

        size_t i = range.length - 2, lef = mid - 2, rig = temp.length - 1;
        size_t count_lef, count_rig;

        outer:
        while(true)
        {
            count_lef = 0;
            count_rig = 0;

            // Linear merge
            while((count_lef | count_rig) < minGallop)
            {
                if(greaterEqual(temp[rig], range[lef]))
                {
                    range[i--] = temp[rig];
                    if(rig == 1)
                    {
                        // Move remaining elements from left
                        while(true)
                        {
                            range[i--] = range[lef];
                            if(lef == 0) break;
                            --lef;
                        }

                        // Move last element into place
                        range[i] = temp[0];

                        break outer;
                    }
                    --rig;
                    count_lef = 0;
                    ++count_rig;
                }
                else
                {
                    range[i--] = range[lef];
                    if(lef == 0) while(true)
                    {
                        range[i--] = temp[rig];
                        if(rig == 0) break outer;
                        --rig;
                    }
                    --lef;
                    ++count_lef;
                    count_rig = 0;
                }
            }

            // Gallop merge
            do
            {
                count_rig = rig - gallopReverseLower(temp[0 .. rig], range[lef]);
                foreach(j; 0 .. count_rig)
                {
                    range[i--] = temp[rig];
                    if(rig == 0) break outer;
                    --rig;
                }

                count_lef = lef - gallopReverseUpper(range[0 .. lef], temp[rig]);
                foreach(j; 0 .. count_lef)
                {
                    range[i--] = range[lef];
                    if(lef == 0) while(true)
                    {
                        range[i--] = temp[rig];
                        if(rig == 0) break outer;
                        --rig;
                    }
                    --lef;
                }

                if(minGallop > 0) --minGallop;
            }
            while(count_lef >= minimalGallop || count_rig >= minimalGallop);

            minGallop += 2;
        }

        return minGallop > 0 ? minGallop : 1;
    }

    // false = forward / lower, true = reverse / upper
    template gallopSearch(bool forwardReverse, bool lowerUpper)
    {
        // Gallop search on range according to attributes forwardReverse and lowerUpper
        size_t gallopSearch(R)(R range, T value)
        out(ret)
        {
            assert(ret <= range.length);
        }
        body
        {
            size_t lower = 0, center = 1, upper = range.length;
            alias center gap;

            static if (forwardReverse)
            {
                static if (!lowerUpper) alias lessEqual comp; // reverse lower
                static if (lowerUpper)  alias less comp;      // reverse upper

                // Gallop Search Reverse
                while (gap <= upper)
                {
                    if (comp(value, range[upper - gap]))
                    {
                        upper -= gap;
                        gap *= 2;
                    }
                    else
                    {
                        lower = upper - gap;
                        break;
                    }
                }

                // Binary Search Reverse
                while (upper != lower)
                {
                    center = lower + (upper - lower) / 2;
                    if (comp(value, range[center])) upper = center;
                    else lower = center + 1;
                }
            }
            else
            {
                static if (!lowerUpper) alias greater comp;      // forward lower
                static if (lowerUpper)  alias greaterEqual comp; // forward upper

                // Gallop Search Forward
                while (lower + gap < upper)
                {
                    if (comp(value, range[lower + gap]))
                    {
                        lower += gap;
                        gap *= 2;
                    }
                    else
                    {
                        upper = lower + gap;
                        break;
                    }
                }

                // Binary Search Forward
                while (lower != upper)
                {
                    center = lower + (upper - lower) / 2;
                    if (comp(value, range[center])) lower = center + 1;
                    else upper = center;
                }
            }

            return lower;
        }
    }

    alias gallopSearch!(false, false) gallopForwardLower;
    alias gallopSearch!(false, true)  gallopForwardUpper;
    alias gallopSearch!(true, false)  gallopReverseLower;
    alias gallopSearch!(true, true)   gallopReverseUpper;
}

unittest
{
    import std.random;

    // Element type with two fields
    static struct E
    {
        size_t value, index;
    }

    // Generates data especially for testing sorting with Timsort
    static E[] genSampleData(uint seed)
    {
        auto rnd = Random(seed);

        E[] arr;
        arr.length = 64 * 64;

        // We want duplicate values for testing stability
        foreach(i, ref v; arr) v.value = i / 64;

        // Swap ranges at random middle point (test large merge operation)
        immutable mid = uniform(arr.length / 4, arr.length / 4 * 3, rnd);
        swapRanges(arr[0 .. mid], arr[mid .. $]);

        // Shuffle last 1/8 of the array (test insertion sort and linear merge)
        randomShuffle(arr[$ / 8 * 7 .. $], rnd);

        // Swap few random elements (test galloping mode)
        foreach(i; 0 .. arr.length / 64)
        {
            immutable a = uniform(0, arr.length, rnd), b = uniform(0, arr.length, rnd);
            swap(arr[a], arr[b]);
        }

        // Now that our test array is prepped, store original index value
        // This will allow us to confirm the array was sorted stably
        foreach(i, ref v; arr) v.index = i;

        return arr;
    }

    // Tests the Timsort function for correctness and stability
    static bool testSort(uint seed)
    {
        auto arr = genSampleData(seed);

        // Now sort the array!
        static bool comp(E a, E b)
        {
            return a.value < b.value;
        }

        sort!(comp, SwapStrategy.stable)(arr);

        // Test that the array was sorted correctly
        assert(isSorted!comp(arr));

        // Test that the array was sorted stably
        foreach(i; 0 .. arr.length - 1)
        {
            if(arr[i].value == arr[i + 1].value) assert(arr[i].index < arr[i + 1].index);
        }

        return true;
    }

    enum seed = 310614065;
    testSort(seed);

    //@@BUG: Timsort fails with CTFE as of DMD 2.060
    // enum result = testSort(seed);
}

unittest
{//bugzilla 4584
    assert(isSorted!"a<b"(sort!("a<b", SwapStrategy.stable)(
       [83, 42, 85, 86, 87, 22, 89, 30, 91, 46, 93, 94, 95, 6,
         97, 14, 33, 10, 101, 102, 103, 26, 105, 106, 107, 6]
    )));

}

unittest
{
    //test stable sort + zip
    auto x = [10, 50, 60, 60, 20];
    dchar[] y = "abcde"d.dup;

    sort!("a[0] < b[0]", SwapStrategy.stable)(zip(x, y));
    assert(x == [10, 20, 50, 60, 60]);
    assert(y == "aebcd"d);
}

// schwartzSort
/**
Sorts a range using an algorithm akin to the $(WEB
wikipedia.org/wiki/Schwartzian_transform, Schwartzian transform), also
known as the decorate-sort-undecorate pattern in Python and Lisp. (Not
to be confused with $(WEB youtube.com/watch?v=UHw6KXbvazs, the other
Schwartz).) This function is helpful when the sort comparison includes
an expensive computation. The complexity is the same as that of the
corresponding $(D sort), but $(D schwartzSort) evaluates $(D
transform) only $(D r.length) times (less than half when compared to
regular sorting). The usage can be best illustrated with an example.

Examples:
----
uint hashFun(string) { ... expensive computation ... }
string[] array = ...;
// Sort strings by hash, slow
sort!((a, b) => hashFun(a) < hashFun(b))(array);
// Sort strings by hash, fast (only computes arr.length hashes):
schwartzSort!(hashFun, "a < b")(array);
----

The $(D schwartzSort) function might require less temporary data and
be faster than the Perl idiom or the decorate-sort-undecorate idiom
present in Python and Lisp. This is because sorting is done in-place
and only minimal extra data (one array of transformed elements) is
created.

To check whether an array was sorted and benefit of the speedup of
Schwartz sorting, a function $(D schwartzIsSorted) is not provided
because the effect can be achieved by calling $(D
isSorted!less(map!transform(r))).

Returns: The initial range wrapped as a $(D SortedRange) with the
predicate $(D (a, b) => binaryFun!less(transform(a),
transform(b))).
 */
SortedRange!(R, ((a, b) => binaryFun!less(unaryFun!transform(a),
                                          unaryFun!transform(b))))
schwartzSort(alias transform, alias less = "a < b",
        SwapStrategy ss = SwapStrategy.unstable, R)(R r)
    if (isRandomAccessRange!R && hasLength!R)
{
    import core.stdc.stdlib;
    alias T = typeof(unaryFun!transform(r.front));
    auto xform1 = (cast(T*) malloc(r.length * T.sizeof))[0 .. r.length];
    size_t length;
    scope(exit)
    {
        static if (hasElaborateDestructor!T)
        {
            foreach (i; 0 .. length) collectException(destroy(xform1[i]));
        }
        free(xform1.ptr);
    }
    for (; length != r.length; ++length)
    {
        emplace(xform1.ptr + length, unaryFun!transform(r[length]));
    }
    // Make sure we use ubyte[] and ushort[], not char[] and wchar[]
    // for the intermediate array, lest zip gets confused.
    static if (isNarrowString!(typeof(xform1)))
    {
        auto xform = xform1.representation();
    }
    else
    {
        alias xform = xform1;
    }
    zip(xform, r).sort!((a, b) => binaryFun!less(a[0], b[0]), ss)();
    return typeof(return)(r);
}

unittest
{
    // issue 4909
    Tuple!(char)[] chars;
    schwartzSort!"a[0]"(chars);
}

unittest
{
    // issue 5924
    Tuple!(char)[] chars;
    schwartzSort!((Tuple!(char) c){ return c[0]; })(chars);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    static double entropy(double[] probs) {
        double result = 0;
        foreach (p; probs) {
            if (!p) continue;
            //enforce(p > 0 && p <= 1, "Wrong probability passed to entropy");
            result -= p * log2(p);
        }
        return result;
    }

    auto lowEnt = ([ 1.0, 0, 0 ]).dup,
        midEnt = ([ 0.1, 0.1, 0.8 ]).dup,
        highEnt = ([ 0.31, 0.29, 0.4 ]).dup;
    double arr[][] = new double[][3];
    arr[0] = midEnt;
    arr[1] = lowEnt;
    arr[2] = highEnt;

    schwartzSort!(entropy, q{a > b})(arr);
    assert(arr[0] == highEnt);
    assert(arr[1] == midEnt);
    assert(arr[2] == lowEnt);
    assert(isSorted!("a > b")(map!(entropy)(arr)));
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    static double entropy(double[] probs) {
        double result = 0;
        foreach (p; probs) {
            if (!p) continue;
            //enforce(p > 0 && p <= 1, "Wrong probability passed to entropy");
            result -= p * log2(p);
        }
        return result;
    }

    auto lowEnt = ([ 1.0, 0, 0 ]).dup,
        midEnt = ([ 0.1, 0.1, 0.8 ]).dup,
        highEnt = ([ 0.31, 0.29, 0.4 ]).dup;
    double arr[][] = new double[][3];
    arr[0] = midEnt;
    arr[1] = lowEnt;
    arr[2] = highEnt;

    schwartzSort!(entropy, q{a < b})(arr);
    assert(arr[0] == lowEnt);
    assert(arr[1] == midEnt);
    assert(arr[2] == highEnt);
    assert(isSorted!("a < b")(map!(entropy)(arr)));
}

// partialSort
/**
Reorders the random-access range $(D r) such that the range $(D r[0
.. mid]) is the same as if the entire $(D r) were sorted, and leaves
the range $(D r[mid .. r.length]) in no particular order. Performs
$(BIGOH r.length * log(mid)) evaluations of $(D pred). The
implementation simply calls $(D topN!(less, ss)(r, n)) and then $(D
sort!(less, ss)(r[0 .. n])).

Example:
----
int[] a = [ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ];
partialSort(a, 5);
assert(a[0 .. 5] == [ 0, 1, 2, 3, 4 ]);
----
*/
void partialSort(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
    Range)(Range r, size_t n)
    if (isRandomAccessRange!(Range) && hasLength!(Range) && hasSlicing!(Range))
{
    topN!(less, ss)(r, n);
    sort!(less, ss)(r[0 .. n]);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ];
    partialSort(a, 5);
    assert(a[0 .. 5] == [ 0, 1, 2, 3, 4 ]);
}

// completeSort
/**
Sorts the random-access range $(D chain(lhs, rhs)) according to
predicate $(D less). The left-hand side of the range $(D lhs) is
assumed to be already sorted; $(D rhs) is assumed to be unsorted. The
exact strategy chosen depends on the relative sizes of $(D lhs) and
$(D rhs).  Performs $(BIGOH lhs.length + rhs.length * log(rhs.length))
(best case) to $(BIGOH (lhs.length + rhs.length) * log(lhs.length +
rhs.length)) (worst-case) evaluations of $(D swap).

Example:
----
int[] a = [ 1, 2, 3 ];
int[] b = [ 4, 0, 6, 5 ];
completeSort(assumeSorted(a), b);
assert(a == [ 0, 1, 2 ]);
assert(b == [ 3, 4, 5, 6 ]);
----
*/
void completeSort(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
        Range1, Range2)(SortedRange!(Range1, less) lhs, Range2 rhs)
if (hasLength!(Range2) && hasSlicing!(Range2))
{
    // Probably this algorithm can be optimized by using in-place
    // merge
    auto lhsOriginal = lhs.release();
    foreach (i; 0 .. rhs.length)
    {
        auto sortedSoFar = chain(lhsOriginal, rhs[0 .. i]);
        auto ub = assumeSorted!less(sortedSoFar).upperBound(rhs[i]);
        if (!ub.length) continue;
        bringToFront(ub.release(), rhs[i .. i + 1]);
    }
}

unittest
{
    debug(std_algorithm) scope(success)
       writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 3 ];
    int[] b = [ 4, 0, 6, 5 ];
    // @@@BUG@@@ The call below should work
    // completeSort(assumeSorted(a), b);
    completeSort!("a < b", SwapStrategy.unstable, int[], int[])(
        assumeSorted(a), b);
    assert(a == [ 0, 1, 2 ]);
    assert(b == [ 3, 4, 5, 6 ]);
}

// isSorted
/**
Checks whether a forward range is sorted according to the comparison
operation $(D less). Performs $(BIGOH r.length) evaluations of $(D
less).

Example:
----
int[] arr = [4, 3, 2, 1];
assert(!isSorted(arr));
sort(arr);
assert(isSorted(arr));
sort!("a > b")(arr);
assert(isSorted!("a > b")(arr));
----
*/
bool isSorted(alias less = "a < b", Range)(Range r) if (isForwardRange!(Range))
{
    if (r.empty) return true;

    static if (isRandomAccessRange!Range && hasLength!Range)
    {
        immutable limit = r.length - 1;
        foreach (i; 0 .. limit)
        {
            if (!binaryFun!less(r[i + 1], r[i])) continue;
            assert(
                !binaryFun!less(r[i], r[i + 1]),
                text("Predicate for isSorted is not antisymmetric. Both"
                        " pred(a, b) and pred(b, a) are true for a=", r[i],
                        " and b=", r[i+1], " in positions ", i, " and ",
                        i + 1));
            return false;
        }
    }
    else
    {
        auto ahead = r;
        ahead.popFront();
        size_t i;

        for (; !ahead.empty; ahead.popFront(), r.popFront(), ++i)
        {
            if (!binaryFun!less(ahead.front, r.front)) continue;
            // Check for antisymmetric predicate
            assert(
                !binaryFun!less(r.front, ahead.front),
                text("Predicate for isSorted is not antisymmetric. Both"
                        " pred(a, b) and pred(b, a) are true for a=", r.front,
                        " and b=", ahead.front, " in positions ", i, " and ",
                        i + 1));
            return false;
        }
    }
    return true;
}

unittest
{
    // Issue 9457
    auto x = "abcd";
    assert(isSorted(x));
    auto y = "acbd";
    assert(!isSorted(y));

    int[] a = [1, 2, 3];
    assert(isSorted(a));
    int[] b = [1, 3, 2];
    assert(!isSorted(b));

    dchar[] ds = "コーヒーが好きです"d.dup;
    sort(ds);
    string s = to!string(ds);
    assert(isSorted(ds));  // random-access
    assert(isSorted(s));   // bidirectional
}

// makeIndex
/**
Computes an index for $(D r) based on the comparison $(D less). The
index is a sorted array of pointers or indices into the original
range. This technique is similar to sorting, but it is more flexible
because (1) it allows "sorting" of immutable collections, (2) allows
binary search even if the original collection does not offer random
access, (3) allows multiple indexes, each on a different predicate,
and (4) may be faster when dealing with large objects. However, using
an index may also be slower under certain circumstances due to the
extra indirection, and is always larger than a sorting-based solution
because it needs space for the index in addition to the original
collection. The complexity is the same as $(D sort)'s.

The first overload of $(D makeIndex) writes to a range containing
pointers, and the second writes to a range containing offsets. The
first overload requires $(D Range) to be a forward range, and the
latter requires it to be a random-access range.

$(D makeIndex) overwrites its second argument with the result, but
never reallocates it.

Returns: The pointer-based version returns a $(D SortedRange) wrapper
over index, of type $(D SortedRange!(RangeIndex, (a, b) =>
binaryFun!less(*a, *b))) thus reflecting the ordering of the
index. The index-based version returns $(D void) because the ordering
relation involves not only $(D index) but also $(D r).

Throws: If the second argument's length is less than that of the range
indexed, an exception is thrown.

Example:
----
immutable(int[]) arr = [ 2, 3, 1, 5, 0 ];
// index using pointers
auto index1 = new immutable(int)*[arr.length];
makeIndex!("a < b")(arr, index1);
assert(isSorted!("*a < *b")(index1));
// index using offsets
auto index2 = new size_t[arr.length];
makeIndex!("a < b")(arr, index2);
assert(isSorted!
    ((size_t a, size_t b){ return arr[a] < arr[b];})
    (index2));
----
*/
SortedRange!(RangeIndex, (a, b) => binaryFun!less(*a, *b))
makeIndex(
    alias less = "a < b",
    SwapStrategy ss = SwapStrategy.unstable,
    Range,
    RangeIndex)
(Range r, RangeIndex index)
    if (isForwardRange!(Range) && isRandomAccessRange!(RangeIndex)
            && is(ElementType!(RangeIndex) : ElementType!(Range)*))
{
    // assume collection already ordered
    size_t i;
    for (; !r.empty; r.popFront(), ++i)
        index[i] = &(r.front);
    enforce(index.length == i);
    // sort the index
    sort!((a, b) => binaryFun!less(*a, *b), ss)(index);
    return typeof(return)(index);
}

/// Ditto
void makeIndex(
    alias less = "a < b",
    SwapStrategy ss = SwapStrategy.unstable,
    Range,
    RangeIndex)
(Range r, RangeIndex index)
if (isRandomAccessRange!Range && !isInfinite!Range &&
    isRandomAccessRange!RangeIndex && !isInfinite!RangeIndex &&
    isIntegral!(ElementType!RangeIndex))
{
    alias Unqual!(ElementType!RangeIndex) IndexType;
    enforce(r.length == index.length,
        "r and index must be same length for makeIndex.");
    static if (IndexType.sizeof < size_t.sizeof)
    {
        enforce(r.length <= IndexType.max, "Cannot create an index with " ~
            "element type " ~ IndexType.stringof ~ " with length " ~
            to!string(r.length) ~ ".");
    }

    for (IndexType i = 0; i < r.length; ++i)
    {
        index[cast(size_t) i] = i;
    }

    // sort the index
    sort!((a, b) => binaryFun!less(r[cast(size_t) a], r[cast(size_t) b]), ss)
      (index);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    immutable(int)[] arr = [ 2, 3, 1, 5, 0 ];
    // index using pointers
    auto index1 = new immutable(int)*[arr.length];
    alias typeof(arr) ImmRange;
    alias typeof(index1) ImmIndex;
    static assert(isForwardRange!(ImmRange));
    static assert(isRandomAccessRange!(ImmIndex));
    static assert(!isIntegral!(ElementType!(ImmIndex)));
    static assert(is(ElementType!(ImmIndex) : ElementType!(ImmRange)*));
    makeIndex!("a < b")(arr, index1);
    assert(isSorted!("*a < *b")(index1));

    // index using offsets
    auto index2 = new long[arr.length];
    makeIndex(arr, index2);
    assert(isSorted!
            ((long a, long b){
                return arr[cast(size_t) a] < arr[cast(size_t) b];
            })(index2));

    // index strings using offsets
    string[] arr1 = ["I", "have", "no", "chocolate"];
    auto index3 = new byte[arr1.length];
    makeIndex(arr1, index3);
    assert(isSorted!
            ((byte a, byte b){ return arr1[a] < arr1[b];})
            (index3));
}

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
    alias binaryFun!(less) lessFun;
    static assert(ss == SwapStrategy.unstable,
            "Stable indexing not yet implemented");
    alias Iterator!(SRange) SIter;
    alias std.iterator.ElementType!(TRange) TElem;
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
    partialIndex!("std.uni.toUpper(a) < std.uni.toUpper(b)")(b, index);
    assert(isSorted!("std.uni.toUpper(*a) < std.uni.toUpper(*b)")(index));

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
//     alias Iterator!(Range) Iter;
//     auto result = new Iter[r.length];
//     // assume collection already ordered
//     size_t i = 0;
//     foreach (it; begin(r) .. end(r))
//     {
//         result[i++] = it;
//     }
//     // sort the index
//     alias typeof(transform(*result[0])) Transformed;
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
/**
Returns $(D true) if and only if $(D value) can be found in $(D
range). Performs $(BIGOH needle.length) evaluations of $(D pred).
 */
bool canFind(alias pred = "a == b", R, E)(R haystack, E needle)
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
size_t canFind(alias pred = "a == b", Range, Ranges...)(Range haystack, Ranges needles)
if (Ranges.length > 1 &&
    allSatisfy!(isForwardRange, Ranges) &&
    is(typeof(find!pred(haystack, needles))))
{
    return find!pred(haystack, needles)[1];
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto a = rndstuff!(int)();
    if (a.length)
    {
        auto b = a[a.length / 2];
        assert(canFind(a, b));
    }

    assert(canFind([0, 1, 2, 3], 2) == true);
    assert(canFind([0, 1, 2, 3], [1, 2], [2, 3]));
    assert(canFind([0, 1, 2, 3], [1, 2], [2, 3]) == 1);
    assert(canFind([0, 1, 2, 3], [1, 7], [2, 3]));
    assert(canFind([0, 1, 2, 3], [1, 7], [2, 3]) == 2);

    assert(canFind([0, 1, 2, 3], 4) == false);
    assert(!canFind([0, 1, 2, 3], [1, 3], [2, 4]));
    assert(canFind([0, 1, 2, 3], [1, 3], [2, 4]) == 0);
}

//Explictly Undocumented. Do not use. It may be deprecated in the future.
//Use any instead.
bool canFind(alias pred, Range)(Range range)
{
    return any!pred(range);
}

/**
Returns $(D true) if and only if a value $(D v) satisfying the
predicate $(D pred) can be found in the forward range $(D
range). Performs $(BIGOH r.length) evaluations of $(D pred).
 */
bool any(alias pred, Range)(Range range)
if (is(typeof(find!pred(range))))
{
    return !find!pred(range).empty;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto a = [ 1, 2, 0, 4 ];
    assert(any!"a == 2"(a));
}

/**
Returns $(D true) if and only if all values in $(D range) satisfy the
predicate $(D pred).  Performs $(BIGOH r.length) evaluations of $(D pred).

Examples:
---
assert(all!"a & 1"([1, 3, 5, 7, 9]));
assert(!all!"a & 1"([1, 2, 3, 5, 7, 9]));
---
*/
bool all(alias pred, R)(R range)
if (isInputRange!R && is(typeof(unaryFun!pred(range.front))))
{
    // dmd @@@BUG9578@@@ workaround
    // return find!(not!(unaryFun!pred))(range).empty;
    bool notPred(ElementType!R a) { return !unaryFun!pred(a); }
    return find!notPred(range).empty;
}

unittest
{
    assert(all!"a & 1"([1, 3, 5, 7, 9]));
    assert(!all!"a & 1"([1, 2, 3, 5, 7, 9]));
    int x = 1;
    assert(all!(a => a > x)([2, 3]));
}

/**
Copies the top $(D n) elements of the input range $(D source) into the
random-access range $(D target), where $(D n =
target.length). Elements of $(D source) are not touched. If $(D
sorted) is $(D true), the target is sorted. Otherwise, the target
respects the $(WEB en.wikipedia.org/wiki/Binary_heap, heap property).

Example:
----
int[] a = [ 10, 16, 2, 3, 1, 5, 0 ];
int[] b = new int[3];
topNCopy(a, b, true);
assert(b == [ 0, 1, 2 ]);
----
 */
TRange topNCopy(alias less = "a < b", SRange, TRange)
    (SRange source, TRange target, SortOutput sorted = SortOutput.no)
    if (isInputRange!(SRange) && isRandomAccessRange!(TRange)
            && hasLength!(TRange) && hasSlicing!(TRange))
{
    if (target.empty) return target;
    auto heap = BinaryHeap!(TRange, less)(target, 0);
    foreach (e; source) heap.conditionalInsert(e);
    auto result = target[0 .. heap.length];
    if (sorted == SortOutput.yes)
    {
        while (!heap.empty) heap.removeFront();
    }
    return result;
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 10, 16, 2, 3, 1, 5, 0 ];
    int[] b = new int[3];
    topNCopy(a, b, SortOutput.yes);
    assert(b == [ 0, 1, 2 ]);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    auto r = Random(unpredictableSeed);
    ptrdiff_t[] a = new ptrdiff_t[uniform(1, 1000, r)];
    foreach (i, ref e; a) e = i;
    randomShuffle(a, r);
    auto n = uniform(0, a.length, r);
    ptrdiff_t[] b = new ptrdiff_t[n];
    topNCopy!(binaryFun!("a < b"))(a, b, SortOutput.yes);
    assert(isSorted!(binaryFun!("a < b"))(b));
}

/**
Lazily computes the union of two or more ranges $(D rs). The ranges
are assumed to be sorted by $(D less). Elements in the output are not
unique; the length of the output is the sum of the lengths of the
inputs. (The $(D length) member is offered if all ranges also have
length.) The element types of all ranges must have a common type.

Example:
----
int[] a = [ 1, 2, 4, 5, 7, 9 ];
int[] b = [ 0, 1, 2, 4, 7, 8 ];
int[] c = [ 10 ];
assert(setUnion(a, b).length == a.length + b.length);
assert(equal(setUnion(a, b), [0, 1, 1, 2, 2, 4, 4, 5, 7, 7, 8, 9][]));
assert(equal(setUnion(a, c, b),
    [0, 1, 1, 2, 2, 4, 4, 5, 7, 7, 8, 9, 10][]));
----
 */
struct SetUnion(alias less = "a < b", Rs...) if (allSatisfy!(isInputRange, Rs))
{
private:
    Rs _r;
    alias binaryFun!(less) comp;
    uint _crt;

    void adjustPosition(uint candidate = 0)()
    {
        static if (candidate == Rs.length)
        {
            _crt = _crt.max;
        }
        else
        {
            if (_r[candidate].empty)
            {
                adjustPosition!(candidate + 1)();
                return;
            }
            foreach (i, U; Rs[candidate + 1 .. $])
            {
                enum j = candidate + i + 1;
                if (_r[j].empty) continue;
                if (comp(_r[j].front, _r[candidate].front))
                {
                    // a new candidate was found
                    adjustPosition!(j)();
                    return;
                }
            }
            // Found a successful candidate
            _crt = candidate;
        }
    }

public:
    alias CommonType!(staticMap!(.ElementType, Rs)) ElementType;

    this(Rs rs)
    {
        this._r = rs;
        adjustPosition();
    }

    @property bool empty()
    {
        return _crt == _crt.max;
    }

    void popFront()
    {
        // Assumes _crt is correct
        assert(!empty);
        foreach (i, U; Rs)
        {
            if (i < _crt) continue;
            // found _crt
            assert(!_r[i].empty);
            _r[i].popFront();
            adjustPosition();
            return;
        }
        assert(false);
    }

    @property ElementType front()
    {
        assert(!empty);
        // Assume _crt is correct
        foreach (i, U; Rs)
        {
            if (i < _crt) continue;
            assert(!_r[i].empty);
            return _r[i].front;
        }
        assert(false);
    }

    static if (allSatisfy!(isForwardRange, Rs))
    {
        @property auto save()
        {
            auto ret = this;
            foreach (ti, elem; _r)
            {
                ret._r[ti] = elem.save;
            }
            return ret;
        }
    }

    static if (allSatisfy!(hasLength, Rs))
    {
        @property size_t length()
        {
            size_t result;
            foreach (i, U; Rs)
            {
                result += _r[i].length;
            }
            return result;
        }

        alias length opDollar;
    }
}

/// Ditto
SetUnion!(less, Rs) setUnion(alias less = "a < b", Rs...)
(Rs rs)
{
    return typeof(return)(rs);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    int[] c = [ 10 ];
    //foreach (e; setUnion(a, b)) writeln(e);
    assert(setUnion(a, b).length == a.length + b.length);
    assert(equal(setUnion(a, b), [0, 1, 1, 2, 2, 4, 4, 5, 7, 7, 8, 9][]));
    assert(equal(setUnion(a, c, b),
                    [0, 1, 1, 2, 2, 4, 4, 5, 7, 7, 8, 9, 10][]));

    static assert(isForwardRange!(typeof(setUnion(a, b))));
}

/**
Lazily computes the intersection of two or more input ranges $(D
rs). The ranges are assumed to be sorted by $(D less). The element
types of all ranges must have a common type.

Example:
----
int[] a = [ 1, 2, 4, 5, 7, 9 ];
int[] b = [ 0, 1, 2, 4, 7, 8 ];
int[] c = [ 0, 1, 4, 5, 7, 8 ];
assert(equal(setIntersection(a, a), a));
assert(equal(setIntersection(a, b), [1, 2, 4, 7][]));
assert(equal(setIntersection(a, b, c), [1, 4, 7][]));
----
 */
struct SetIntersection(alias less = "a < b", Rs...)
if (allSatisfy!(isInputRange, Rs))
{
    static assert(Rs.length == 2);
private:
    Rs _input;
    alias binaryFun!(less) comp;
    alias CommonType!(staticMap!(.ElementType, Rs)) ElementType;

    void adjustPosition()
    {
        // Positions to the first two elements that are equal
        while (!empty)
        {
            if (comp(_input[0].front, _input[1].front))
            {
                _input[0].popFront();
            }
            else if (comp(_input[1].front, _input[0].front))
            {
                _input[1].popFront();
            }
            else
            {
                break;
            }
        }
    }

public:
    this(Rs input)
    {
        this._input = input;
        // position to the first element
        adjustPosition();
    }

    @property bool empty()
    {
        foreach (i, U; Rs)
        {
            if (_input[i].empty) return true;
        }
        return false;
    }

    void popFront()
    {
        assert(!empty);
        assert(!comp(_input[0].front, _input[1].front)
                && !comp(_input[1].front, _input[0].front));
        _input[0].popFront();
        _input[1].popFront();
        adjustPosition();
    }

    @property ElementType front()
    {
        assert(!empty);
        return _input[0].front;
    }

    static if (allSatisfy!(isForwardRange, Rs))
    {
        @property auto save()
        {
            auto ret = this;
            foreach (ti, elem; _input)
            {
                ret._input[ti] = elem.save;
            }
            return ret;
        }
    }
}

/// Ditto
SetIntersection!(less, Rs) setIntersection(alias less = "a < b", Rs...)
(Rs ranges)
if (allSatisfy!(isInputRange, Rs))
{
    return typeof(return)(ranges);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    int[] c = [ 0, 1, 4, 5, 7, 8 ];
    //foreach (e; setIntersection(a, b, c)) writeln(e);
    assert(equal(setIntersection(a, b), [1, 2, 4, 7][]));
    assert(equal(setIntersection(a, a), a));

    static assert(isForwardRange!(typeof(setIntersection(a, a))));
    // assert(equal(setIntersection(a, b, b, a), [1, 2, 4, 7][]));
    // assert(equal(setIntersection(a, b, c), [1, 4, 7][]));
    // assert(equal(setIntersection(a, c, b), [1, 4, 7][]));
    // assert(equal(setIntersection(b, a, c), [1, 4, 7][]));
    // assert(equal(setIntersection(b, c, a), [1, 4, 7][]));
    // assert(equal(setIntersection(c, a, b), [1, 4, 7][]));
    // assert(equal(setIntersection(c, b, a), [1, 4, 7][]));
}

/**
Lazily computes the difference of $(D r1) and $(D r2). The two ranges
are assumed to be sorted by $(D less). The element types of the two
ranges must have a common type.

Example:
----
int[] a = [ 1, 2, 4, 5, 7, 9 ];
int[] b = [ 0, 1, 2, 4, 7, 8 ];
assert(equal(setDifference(a, b), [5, 9][]));
----
 */
struct SetDifference(alias less = "a < b", R1, R2)
    if (isInputRange!(R1) && isInputRange!(R2))
{
private:
    R1 r1;
    R2 r2;
    alias binaryFun!(less) comp;

    void adjustPosition()
    {
        while (!r1.empty)
        {
            if (r2.empty || comp(r1.front, r2.front)) break;
            if (comp(r2.front, r1.front))
            {
                r2.popFront();
            }
            else
            {
                // both are equal
                r1.popFront();
                r2.popFront();
            }
        }
    }

public:
    this(R1 r1, R2 r2)
    {
        this.r1 = r1;
        this.r2 = r2;
        // position to the first element
        adjustPosition();
    }

    void popFront()
    {
        r1.popFront();
        adjustPosition();
    }

    @property ElementType!(R1) front()
    {
        assert(!empty);
        return r1.front;
    }

    static if (isForwardRange!R1 && isForwardRange!R2)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret.r1 = r1.save;
            ret.r2 = r2.save;
            return ret;
        }
    }

    @property bool empty() { return r1.empty; }
}

/// Ditto
SetDifference!(less, R1, R2) setDifference(alias less = "a < b", R1, R2)
(R1 r1, R2 r2)
{
    return typeof(return)(r1, r2);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    //foreach (e; setDifference(a, b)) writeln(e);
    assert(equal(setDifference(a, b), [5, 9][]));
    static assert(isForwardRange!(typeof(setDifference(a, b))));
}

/**
Lazily computes the symmetric difference of $(D r1) and $(D r2),
i.e. the elements that are present in exactly one of $(D r1) and $(D
r2). The two ranges are assumed to be sorted by $(D less), and the
output is also sorted by $(D less). The element types of the two
ranges must have a common type.

Example:
----
int[] a = [ 1, 2, 4, 5, 7, 9 ];
int[] b = [ 0, 1, 2, 4, 7, 8 ];
assert(equal(setSymmetricDifference(a, b), [0, 5, 8, 9][]));
----
 */
struct SetSymmetricDifference(alias less = "a < b", R1, R2)
    if (isInputRange!(R1) && isInputRange!(R2))
{
private:
    R1 r1;
    R2 r2;
    //bool usingR2;
    alias binaryFun!(less) comp;

    void adjustPosition()
    {
        while (!r1.empty && !r2.empty)
        {
            if (comp(r1.front, r2.front) || comp(r2.front, r1.front))
            {
                break;
            }
            // equal, pop both
            r1.popFront();
            r2.popFront();
        }
    }

public:
    this(R1 r1, R2 r2)
    {
        this.r1 = r1;
        this.r2 = r2;
        // position to the first element
        adjustPosition();
    }

    void popFront()
    {
        assert(!empty);
        if (r1.empty) r2.popFront();
        else if (r2.empty) r1.popFront();
        else
        {
            // neither is empty
            if (comp(r1.front, r2.front))
            {
                r1.popFront();
            }
            else
            {
                assert(comp(r2.front, r1.front));
                r2.popFront();
            }
        }
        adjustPosition();
    }

    @property ElementType!(R1) front()
    {
        assert(!empty);
        if (r2.empty || !r1.empty && comp(r1.front, r2.front))
        {
            return r1.front;
        }
        assert(r1.empty || comp(r2.front, r1.front));
        return r2.front;
    }

    static if (isForwardRange!R1 && isForwardRange!R2)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret.r1 = r1.save;
            ret.r2 = r2.save;
            return ret;
        }
    }

    ref auto opSlice() { return this; }

    @property bool empty() { return r1.empty && r2.empty; }
}

/// Ditto
SetSymmetricDifference!(less, R1, R2)
setSymmetricDifference(alias less = "a < b", R1, R2)
(R1 r1, R2 r2)
{
    return typeof(return)(r1, r2);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    //foreach (e; setSymmetricDifference(a, b)) writeln(e);
    assert(equal(setSymmetricDifference(a, b), [0, 5, 8, 9][]));

    static assert(isForwardRange!(typeof(setSymmetricDifference(a, b))));
}

// Internal random array generators

version(unittest)
{
    private enum size_t maxArraySize = 50;
    private enum size_t minArraySize = maxArraySize - 1;

    private string[] rndstuff(T : string)()
    {
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

    private int[] rndstuff(T : int)()
    {
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

    private double[] rndstuff(T : double)()
    {
        double[] result;
        foreach (i; rndstuff!(int)())
        {
            result ~= i / 50.0;
        }
        return result;
    }

        //Reference type input range
    private class ReferenceInputRange(T)
    {
        this(Range)(Range r) if (isInputRange!Range) {_payload = array(r);}
        final @property ref T front(){return _payload.front;}
        final void popFront(){_payload.popFront();}
        final @property bool empty(){return _payload.empty;}
        protected T[] _payload;
    }

    //Reference forward range
    private class ReferenceForwardRange(T) : ReferenceInputRange!T
    {
        this(Range)(Range r) if (isInputRange!Range) {super(r);}
        final @property ReferenceForwardRange save()
        {return new ReferenceForwardRange!T(_payload);}
    }

    //Infinite input range
    private class ReferenceInfiniteInputRange(T)
    {
        this(T first = T.init) {_val = first;}
        final @property T front(){return _val;}
        final void popFront(){++_val;}
        enum bool empty = false;
        protected T _val;
    }

    //Infinite forward range
    private class ReferenceInfiniteForwardRange(T) : ReferenceInfiniteInputRange!T
    {
        this(T first = T.init) {super(first);}
        final @property ReferenceInfiniteForwardRange save()
        {return new ReferenceInfiniteForwardRange!T(_val);}
    }
}

// NWayUnion
/**
Computes the union of multiple sets. The input sets are passed as a
range of ranges and each is assumed to be sorted by $(D
less). Computation is done lazily, one union element at a time. The
complexity of one $(D popFront) operation is $(BIGOH
log(ror.length)). However, the length of $(D ror) decreases as ranges
in it are exhausted, so the complexity of a full pass through $(D
NWayUnion) is dependent on the distribution of the lengths of ranges
contained within $(D ror). If all ranges have the same length $(D n)
(worst case scenario), the complexity of a full pass through $(D
NWayUnion) is $(BIGOH n * ror.length * log(ror.length)), i.e., $(D
log(ror.length)) times worse than just spanning all ranges in
turn. The output comes sorted (unstably) by $(D less).

Warning: Because $(D NWayUnion) does not allocate extra memory, it
will leave $(D ror) modified. Namely, $(D NWayUnion) assumes ownership
of $(D ror) and discretionarily swaps and advances elements of it. If
you want $(D ror) to preserve its contents after the call, you may
want to pass a duplicate to $(D NWayUnion) (and perhaps cache the
duplicate in between calls).

Example:
----
double[][] a =
[
    [ 1, 4, 7, 8 ],
    [ 1, 7 ],
    [ 1, 7, 8],
    [ 4 ],
    [ 7 ],
];
auto witness = [
    1, 1, 1, 4, 4, 7, 7, 7, 7, 8, 8
];
assert(equal(nWayUnion(a), witness[]));
----
 */
struct NWayUnion(alias less, RangeOfRanges)
{
    private alias .ElementType!(.ElementType!RangeOfRanges) ElementType;
    private alias binaryFun!less comp;
    private RangeOfRanges _ror;
    static bool compFront(.ElementType!RangeOfRanges a,
            .ElementType!RangeOfRanges b)
    {
        // revert comparison order so we get the smallest elements first
        return comp(b.front, a.front);
    }
    BinaryHeap!(RangeOfRanges, compFront) _heap;

    this(RangeOfRanges ror)
    {
        // Preemptively get rid of all empty ranges in the input
        // No need for stability either
        _ror = remove!("a.empty", SwapStrategy.unstable)(ror);
        //Build the heap across the range
        _heap.acquire(_ror);
    }

    @property bool empty() { return _ror.empty; }

    @property auto ref front()
    {
        return _heap.front.front;
    }

    void popFront()
    {
        _heap.removeFront();
        // let's look at the guy just popped
        _ror.back.popFront();
        if (_ror.back.empty)
        {
            _ror.popBack();
            // nothing else to do: the empty range is not in the
            // heap and not in _ror
            return;
        }
        // Put the popped range back in the heap
        _heap.conditionalInsert(_ror.back) || assert(false);
    }
}

/// Ditto
NWayUnion!(less, RangeOfRanges) nWayUnion
(alias less = "a < b", RangeOfRanges)
(RangeOfRanges ror)
{
    return typeof(return)(ror);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    double[][] a =
    [
        [ 1, 4, 7, 8 ],
        [ 1, 7 ],
        [ 1, 7, 8],
        [ 4 ],
        [ 7 ],
    ];
    auto witness = [
        1, 1, 1, 4, 4, 7, 7, 7, 7, 8, 8
    ];
    //foreach (e; nWayUnion(a)) writeln(e);
    assert(equal(nWayUnion(a), witness[]));
}

// largestPartialIntersection
/**
Given a range of sorted forward ranges $(D ror), copies to $(D tgt)
the elements that are common to most ranges, along with their number
of occurrences. All ranges in $(D ror) are assumed to be sorted by $(D
less). Only the most frequent $(D tgt.length) elements are returned.

Example:
----
// Figure which number can be found in most arrays of the set of
// arrays below.
double[][] a =
[
    [ 1, 4, 7, 8 ],
    [ 1, 7 ],
    [ 1, 7, 8],
    [ 4 ],
    [ 7 ],
];
auto b = new Tuple!(double, uint)[1];
largestPartialIntersection(a, b);
// First member is the item, second is the occurrence count
assert(b[0] == tuple(7.0, 4u));
----

$(D 7.0) is the correct answer because it occurs in $(D 4) out of the
$(D 5) inputs, more than any other number. The second member of the
resulting tuple is indeed $(D 4) (recording the number of occurrences
of $(D 7.0)). If more of the top-frequent numbers are needed, just
create a larger $(D tgt) range. In the axample above, creating $(D b)
with length $(D 2) yields $(D tuple(1.0, 3u)) in the second position.

The function $(D largestPartialIntersection) is useful for
e.g. searching an $(LUCKY inverted index) for the documents most
likely to contain some terms of interest. The complexity of the search
is $(BIGOH n * log(tgt.length)), where $(D n) is the sum of lengths of
all input ranges. This approach is faster than keeping an associative
array of the occurrences and then selecting its top items, and also
requires less memory ($(D largestPartialIntersection) builds its
result directly in $(D tgt) and requires no extra memory).

Warning: Because $(D largestPartialIntersection) does not allocate
extra memory, it will leave $(D ror) modified. Namely, $(D
largestPartialIntersection) assumes ownership of $(D ror) and
discretionarily swaps and advances elements of it. If you want $(D
ror) to preserve its contents after the call, you may want to pass a
duplicate to $(D largestPartialIntersection) (and perhaps cache the
duplicate in between calls).
 */
void largestPartialIntersection
(alias less = "a < b", RangeOfRanges, Range)
(RangeOfRanges ror, Range tgt, SortOutput sorted = SortOutput.no)
{
    struct UnitWeights
    {
        static int opIndex(ElementType!(ElementType!RangeOfRanges)) { return 1; }
    }
    return largestPartialIntersectionWeighted!less(ror, tgt, UnitWeights(),
            sorted);
}

// largestPartialIntersectionWeighted
/**
Similar to $(D largestPartialIntersection), but associates a weight
with each distinct element in the intersection.

Example:
----
// Figure which number can be found in most arrays of the set of
// arrays below, with specific per-element weights
double[][] a =
[
    [ 1, 4, 7, 8 ],
    [ 1, 7 ],
    [ 1, 7, 8],
    [ 4 ],
    [ 7 ],
];
auto b = new Tuple!(double, uint)[1];
double[double] weights = [ 1:1.2, 4:2.3, 7:1.1, 8:1.1 ];
largestPartialIntersectionWeighted(a, b, weights);
// First member is the item, second is the occurrence count
assert(b[0] == tuple(4.0, 2u));
----

The correct answer in this case is $(D 4.0), which, although only
appears two times, has a total weight $(D 4.6) (three times its weight
$(D 2.3)). The value $(D 7) is weighted with $(D 1.1) and occurs four
times for a total weight $(D 4.4).
 */
void largestPartialIntersectionWeighted
(alias less = "a < b", RangeOfRanges, Range, WeightsAA)
(RangeOfRanges ror, Range tgt, WeightsAA weights, SortOutput sorted = SortOutput.no)
{
    if (tgt.empty) return;
    alias ElementType!Range InfoType;
    bool heapComp(InfoType a, InfoType b)
    {
        return weights[a[0]] * a[1] > weights[b[0]] * b[1];
    }
    topNCopy!heapComp(group(nWayUnion!less(ror)), tgt, sorted);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    double[][] a =
        [
            [ 1, 4, 7, 8 ],
            [ 1, 7 ],
            [ 1, 7, 8],
            [ 4 ],
            [ 7 ],
        ];
    auto b = new Tuple!(double, uint)[2];
    largestPartialIntersection(a, b, SortOutput.yes);
    //sort(b);
    //writeln(b);
    assert(b == [ tuple(7.0, 4u), tuple(1.0, 3u) ][], text(b));
    assert(a[0].empty);
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    string[][] a =
        [
            [ "1", "4", "7", "8" ],
            [ "1", "7" ],
            [ "1", "7", "8"],
            [ "4" ],
            [ "7" ],
        ];
    auto b = new Tuple!(string, uint)[2];
    largestPartialIntersection(a, b, SortOutput.yes);
    //writeln(b);
    assert(b == [ tuple("7", 4u), tuple("1", 3u) ][], text(b));
}

unittest
{
    //scope(success) writeln("unittest @", __FILE__, ":", __LINE__, " done.");
// Figure which number can be found in most arrays of the set of
// arrays below, with specific per-element weights
    double[][] a =
        [
            [ 1, 4, 7, 8 ],
            [ 1, 7 ],
            [ 1, 7, 8],
            [ 4 ],
            [ 7 ],
            ];
    auto b = new Tuple!(double, uint)[1];
    double[double] weights = [ 1:1.2, 4:2.3, 7:1.1, 8:1.1 ];
    largestPartialIntersectionWeighted(a, b, weights);
// First member is the item, second is the occurrence count
    //writeln(b[0]);
    assert(b[0] == tuple(4.0, 2u));
}

unittest
{
    alias Tuple!(uint, uint) T;
    const Array!T arrayOne = Array!T( [ T(1,2), T(3,4) ] );
    const Array!T arrayTwo = Array!T([ T(1,2), T(3,4) ] );

    assert(arrayOne == arrayTwo);
}

// nextPermutation
/**
 * Permutes $(D range) in-place to the next lexicographically greater
 * permutation.
 *
 * The predicate $(D less) defines the lexicographical ordering to be used on
 * the range.
 *
 * If the range is currently the lexicographically greatest permutation, it is
 * permuted back to the least permutation and false is returned.  Otherwise,
 * true is returned. One can thus generate all permutations of a range by
 * sorting it according to $(D less), which produces the lexicographically
 * least permutation, and then calling nextPermutation until it returns false.
 * This is guaranteed to generate all distinct permutations of the range
 * exactly once.  If there are $(I N) elements in the range and all of them are
 * unique, then $(I N)! permutations will be generated. Otherwise, if there are
 * some duplicated elements, fewer permutations will be produced.
----
// Enumerate all permutations
int[] a = [1,2,3,4,5];
while (nextPermutation(a))
{
    // a now contains the next permutation of the array.
}
----
 * Returns: false if the range was lexicographically the greatest, in which
 * case the range is reversed back to the lexicographically smallest
 * permutation; otherwise returns true.
 *
 * Example:
----
// Step through all permutations of a sorted array in lexicographic order
int[] a = [1,2,3];
assert(nextPermutation(a) == true);
assert(a == [1,3,2]);
assert(nextPermutation(a) == true);
assert(a == [2,1,3]);
assert(nextPermutation(a) == true);
assert(a == [2,3,1]);
assert(nextPermutation(a) == true);
assert(a == [3,1,2]);
assert(nextPermutation(a) == true);
assert(a == [3,2,1]);
assert(nextPermutation(a) == false);
assert(a == [1,2,3]);
----
----
// Step through permutations of an array containing duplicate elements:
int[] a = [1,1,2];
assert(nextPermutation(a) == true);
assert(a == [1,2,1]);
assert(nextPermutation(a) == true);
assert(a == [2,1,1]);
assert(nextPermutation(a) == false);
assert(a == [1,1,2]);
----
 */
bool nextPermutation(alias less="a<b", BidirectionalRange)
                    (ref BidirectionalRange range)
    if (isBidirectionalRange!BidirectionalRange &&
        hasSwappableElements!BidirectionalRange)
{
    // Ranges of 0 or 1 element have no distinct permutations.
    if (range.empty) return false;

    auto i = retro(range);
    auto last = i.save;

    // Find last occurring increasing pair of elements
    size_t n = 1;
    for (i.popFront(); !i.empty; i.popFront(), last.popFront(), n++)
    {
        if (binaryFun!less(i.front, last.front))
            break;
    }

    if (i.empty) {
        // Entire range is decreasing: it's lexicographically the greatest. So
        // wrap it around.
        range.reverse();
        return false;
    }

    // Find last element greater than i.front.
    auto j = find!((a) => binaryFun!less(i.front, a))(
                   takeExactly(retro(range), n));

    assert(!j.empty);   // shouldn't happen since i.front < last.front
    swap(i.front, j.front);
    reverse(takeExactly(retro(range), n));

    return true;
}

unittest
{
    // Boundary cases: arrays of 0 or 1 element.
    int[] a1 = [];
    assert(!nextPermutation(a1));
    assert(a1 == []);

    int[] a2 = [1];
    assert(!nextPermutation(a2));
    assert(a2 == [1]);
}

unittest
{
    int[] a = [1,2,3];
    assert(nextPermutation(a) == true);
    assert(a == [1,3,2]);
    assert(nextPermutation(a) == true);
    assert(a == [2,1,3]);
    assert(nextPermutation(a) == true);
    assert(a == [2,3,1]);
    assert(nextPermutation(a) == true);
    assert(a == [3,1,2]);
    assert(nextPermutation(a) == true);
    assert(a == [3,2,1]);
    assert(nextPermutation(a) == false);
    assert(a == [1,2,3]);
}

unittest
{
    auto a1 = [1, 2, 3, 4];

    assert(nextPermutation(a1));
    assert(equal(a1, [1, 2, 4, 3]));

    assert(nextPermutation(a1));
    assert(equal(a1, [1, 3, 2, 4]));

    assert(nextPermutation(a1));
    assert(equal(a1, [1, 3, 4, 2]));

    assert(nextPermutation(a1));
    assert(equal(a1, [1, 4, 2, 3]));

    assert(nextPermutation(a1));
    assert(equal(a1, [1, 4, 3, 2]));

    assert(nextPermutation(a1));
    assert(equal(a1, [2, 1, 3, 4]));

    assert(nextPermutation(a1));
    assert(equal(a1, [2, 1, 4, 3]));

    assert(nextPermutation(a1));
    assert(equal(a1, [2, 3, 1, 4]));

    assert(nextPermutation(a1));
    assert(equal(a1, [2, 3, 4, 1]));

    assert(nextPermutation(a1));
    assert(equal(a1, [2, 4, 1, 3]));

    assert(nextPermutation(a1));
    assert(equal(a1, [2, 4, 3, 1]));

    assert(nextPermutation(a1));
    assert(equal(a1, [3, 1, 2, 4]));

    assert(nextPermutation(a1));
    assert(equal(a1, [3, 1, 4, 2]));

    assert(nextPermutation(a1));
    assert(equal(a1, [3, 2, 1, 4]));

    assert(nextPermutation(a1));
    assert(equal(a1, [3, 2, 4, 1]));

    assert(nextPermutation(a1));
    assert(equal(a1, [3, 4, 1, 2]));

    assert(nextPermutation(a1));
    assert(equal(a1, [3, 4, 2, 1]));

    assert(nextPermutation(a1));
    assert(equal(a1, [4, 1, 2, 3]));

    assert(nextPermutation(a1));
    assert(equal(a1, [4, 1, 3, 2]));

    assert(nextPermutation(a1));
    assert(equal(a1, [4, 2, 1, 3]));

    assert(nextPermutation(a1));
    assert(equal(a1, [4, 2, 3, 1]));

    assert(nextPermutation(a1));
    assert(equal(a1, [4, 3, 1, 2]));

    assert(nextPermutation(a1));
    assert(equal(a1, [4, 3, 2, 1]));

    assert(!nextPermutation(a1));
    assert(equal(a1, [1, 2, 3, 4]));
}

unittest
{
    // Test array with duplicate elements
    int[] a = [1,1,2];
    assert(nextPermutation(a) == true);
    assert(a == [1,2,1]);
    assert(nextPermutation(a) == true);
    assert(a == [2,1,1]);
    assert(nextPermutation(a) == false);
    assert(a == [1,1,2]);
}

unittest
{
    // Test with non-default sorting order
    int[] a = [3,2,1];
    assert(nextPermutation!"a > b"(a) == true);
    assert(a == [3,1,2]);
    assert(nextPermutation!"a > b"(a) == true);
    assert(a == [2,3,1]);
    assert(nextPermutation!"a > b"(a) == true);
    assert(a == [2,1,3]);
    assert(nextPermutation!"a > b"(a) == true);
    assert(a == [1,3,2]);
    assert(nextPermutation!"a > b"(a) == true);
    assert(a == [1,2,3]);
    assert(nextPermutation!"a > b"(a) == false);
    assert(a == [3,2,1]);
}

// nextEvenPermutation
/**
 * Permutes $(D range) in-place to the next lexicographically greater $(I even)
 * permutation.
 *
 * The predicate $(D less) defines the lexicographical ordering to be used on
 * the range.
 *
 * An even permutation is one which is produced by swapping an even number of
 * pairs of elements in the original range. The set of $(I even) permutations
 * is distinct from the set of $(I all) permutations only when there are no
 * duplicate elements in the range. If the range has $(I N) unique elements,
 * then there are exactly $(I N)!/2 even permutations.
 *
 * If the range is already the lexicographically greatest even permutation, it
 * is permuted back to the least even permutation and false is returned.
 * Otherwise, true is returned, and the range is modified in-place to be the
 * lexicographically next even permutation.
 *
 * One can thus generate the even permutations of a range with unique elements
 * by starting with the lexicographically smallest permutation, and repeatedly
 * calling nextEvenPermutation until it returns false.
----
// Enumerate even permutations
int[] a = [1,2,3,4,5];
while (nextEvenPermutation(a))
{
    // a now contains the next even permutation of the array.
}
----
 * One can also generate the $(I odd) permutations of a range by noting that
 * permutations obey the rule that even + even = even, and odd + even = odd.
 * Thus, by swapping the last two elements of a lexicographically least range,
 * it is turned into the first odd permutation. Then calling
 * nextEvenPermutation on this first odd permutation will generate the next
 * even permutation relative to this odd permutation, which is actually the
 * next odd permutation of the original range. Thus, by repeatedly calling
 * nextEvenPermutation until it returns false, one enumerates the odd
 * permutations of the original range.
----
// Enumerate odd permutations
int[] a = [1,2,3,4,5];
swap(a[$-2], a[$-1]);    // a is now the first odd permutation of [1,2,3,4,5]
while (nextEvenPermutation(a))
{
    // a now contains the next odd permutation of the original array
    // (which is an even permutation of the first odd permutation).
}
----
 *
 * Warning: Since even permutations are only distinct from all permutations
 * when the range elements are unique, this function assumes that there are no
 * duplicate elements under the specified ordering. If this is not _true, some
 * permutations may fail to be generated. When the range has non-unique
 * elements, you should use $(MYREF nextPermutation) instead.
 *
 * Returns: false if the range was lexicographically the greatest, in which
 * case the range is reversed back to the lexicographically smallest
 * permutation; otherwise returns true.
 *
 * Examples:
----
// Step through even permutations of a sorted array in lexicographic order
int[] a = [1,2,3];
assert(nextEvenPermutation(a) == true);
assert(a == [2,3,1]);
assert(nextEvenPermutation(a) == true);
assert(a == [3,1,2]);
assert(nextEvenPermutation(a) == false);
assert(a == [1,2,3]);
----
 * Even permutations are useful for generating coordinates of certain geometric
 * shapes. Here's a non-trivial example:
----
// Print the 60 vertices of a uniform truncated icosahedron (soccer ball)
import std.math, std.stdio;
enum real Phi = (1.0 + sqrt(5.0)) / 2.0;    // Golden ratio
real[][] seeds = [
    [0.0, 1.0, 3.0*Phi],
    [1.0, 2.0+Phi, 2.0*Phi],
    [Phi, 2.0, Phi^^3]
];
foreach (seed; seeds)
{
    // Loop over even permutations of each seed
    do
    {
        // Loop over all sign changes of each permutation
        size_t i;
        do
        {
            // Generate all possible sign changes
            for (i=0; i < seed.length; i++)
            {
                if (seed[i] != 0.0)
                {
                    seed[i] = -seed[i];
                    if (seed[i] < 0.0)
                        break;
                }
            }
            writeln(seed);
        } while (i < seed.length);
    } while (nextEvenPermutation(seed));
}
----
 */
bool nextEvenPermutation(alias less="a<b", BidirectionalRange)
                        (ref BidirectionalRange range)
    if (isBidirectionalRange!BidirectionalRange &&
        hasSwappableElements!BidirectionalRange)
{
    // Ranges of 0 or 1 element have no distinct permutations.
    if (range.empty) return false;

    bool oddParity = false;
    bool ret = true;
    do
    {
        auto i = retro(range);
        auto last = i.save;

        // Find last occurring increasing pair of elements
        size_t n = 1;
        for (i.popFront(); !i.empty;
            i.popFront(), last.popFront(), n++)
        {
            if (binaryFun!less(i.front, last.front))
                break;
        }

        if (!i.empty)
        {
            // Find last element greater than i.front.
            auto j = find!((a) => binaryFun!less(i.front, a))(
                           takeExactly(retro(range), n));

            // shouldn't happen since i.front < last.front
            assert(!j.empty);

            swap(i.front, j.front);
            oddParity = !oddParity;
        }
        else
        {
            // Entire range is decreasing: it's lexicographically
            // the greatest.
            ret = false;
        }

        reverse(takeExactly(retro(range), n));
        if ((n / 2) % 2 == 1)
            oddParity = !oddParity;
    } while(oddParity);

    return ret;
}

unittest
{
    auto a2 = [ 1, 2, 3 ];

    assert(nextEvenPermutation(a2));
    assert(equal(a2, [ 2, 3, 1 ]));

    assert(nextEvenPermutation(a2));
    assert(equal(a2, [ 3, 1, 2 ]));

    assert(!nextEvenPermutation(a2));
    assert(equal(a2, [ 1, 2, 3 ]));

    auto a3 = [ 1, 2, 3, 4 ];
    int count = 1;
    while (nextEvenPermutation(a3)) count++;
    assert(count == 12);
}

unittest
{
    // Test with non-default sorting order
    auto a = [ 3, 2, 1 ];

    assert(nextEvenPermutation!"a > b"(a) == true);
    assert(a == [ 2, 1, 3 ]);
    assert(nextEvenPermutation!"a > b"(a) == true);
    assert(a == [ 1, 3, 2 ]);
    assert(nextEvenPermutation!"a > b"(a) == false);
    assert(a == [ 3, 2, 1 ]);
}

unittest
{
    // Test various cases of rollover
    auto a = [ 3, 1, 2 ];
    assert(nextEvenPermutation(a) == false);
    assert(a == [ 1, 2, 3 ]);

    auto b = [ 3, 2, 1 ];
    assert(nextEvenPermutation(b) == false);
    assert(b == [ 1, 3, 2 ]);
}

unittest
{
    // Verify correctness of ddoc example.
    enum real Phi = (1.0 + sqrt(5.0)) / 2.0;    // Golden ratio
    real[][] seeds = [
        [0.0, 1.0, 3.0*Phi],
        [1.0, 2.0+Phi, 2.0*Phi],
        [Phi, 2.0, Phi^^3]
    ];
    size_t n;
    foreach (seed; seeds)
    {
        // Loop over even permutations of each seed
        do
        {
            // Loop over all sign changes of each permutation
            size_t i;
            do
            {
                // Generate all possible sign changes
                for (i=0; i < seed.length; i++)
                {
                    if (seed[i] != 0.0)
                    {
                        seed[i] = -seed[i];
                        if (seed[i] < 0.0)
                            break;
                    }
                }
                n++;
            } while (i < seed.length);
        } while (nextEvenPermutation(seed));
    }
    assert(n == 60);
}

// cartesianProduct
/**
Lazily computes the Cartesian product of two or more ranges. The product is a
_range of tuples of elements from each respective range.

The conditions for the two-range case are as follows:

If both ranges are finite, then one must be (at least) a forward range and the
other an input range.

If one _range is infinite and the other finite, then the finite _range must
be a forward _range, and the infinite range can be an input _range.

If both ranges are infinite, then both must be forward ranges.

When there are more than two ranges, the above conditions apply to each
adjacent pair of ranges.

Examples:
---
auto N = sequence!"n"(0);         // the range of natural numbers
auto N2 = cartesianProduct(N, N); // the range of all pairs of natural numbers

// Various arbitrary number pairs can be found in the range in finite time.
assert(canFind(N2, tuple(0, 0)));
assert(canFind(N2, tuple(123, 321)));
assert(canFind(N2, tuple(11, 35)));
assert(canFind(N2, tuple(279, 172)));
---

---
auto B = [ 1, 2, 3 ];
auto C = [ 4, 5, 6 ];
auto BC = cartesianProduct(B, C);

foreach (n; [[1, 4], [2, 4], [3, 4], [1, 5], [2, 5], [3, 5], [1, 6],
             [2, 6], [3, 6]])
{
    assert(canFind(BC, tuple(n[0], n[1])));
}
---

---
auto A = [ 1, 2, 3 ];
auto B = [ 'a', 'b', 'c' ];
auto C = [ "x", "y", "z" ];
auto ABC = cartesianProduct(A, B, C);

assert(ABC.equal([
    tuple(1, 'a', "x"), tuple(2, 'a', "x"), tuple(3, 'a', "x"),
    tuple(1, 'b', "x"), tuple(2, 'b', "x"), tuple(3, 'b', "x"),
    tuple(1, 'c', "x"), tuple(2, 'c', "x"), tuple(3, 'c', "x"),
    tuple(1, 'a', "y"), tuple(2, 'a', "y"), tuple(3, 'a', "y"),
    tuple(1, 'b', "y"), tuple(2, 'b', "y"), tuple(3, 'b', "y"),
    tuple(1, 'c', "y"), tuple(2, 'c', "y"), tuple(3, 'c', "y"),
    tuple(1, 'a', "z"), tuple(2, 'a', "z"), tuple(3, 'a', "z"),
    tuple(1, 'b', "z"), tuple(2, 'b', "z"), tuple(3, 'b', "z"),
    tuple(1, 'c', "z"), tuple(2, 'c', "z"), tuple(3, 'c', "z")
]));
---
*/
auto cartesianProduct(R1, R2)(R1 range1, R2 range2)
{
    static if (isInfinite!R1 && isInfinite!R2)
    {
        static if (isForwardRange!R1 && isForwardRange!R2)
        {
            // This algorithm traverses the cartesian product by alternately
            // covering the right and bottom edges of an increasing square area
            // over the infinite table of combinations. This schedule allows us
            // to require only forward ranges.
            return zip(sequence!"n"(cast(size_t)0), range1.save, range2.save,
                       repeat(range1), repeat(range2))
                .map!(function(a) => chain(
                    zip(repeat(a[1]), take(a[4].save, a[0])),
                    zip(take(a[3].save, a[0]+1), repeat(a[2]))
                ))()
                .joiner();
        }
        else static assert(0, "cartesianProduct of infinite ranges requires "~
                              "forward ranges");
    }
    else static if (isInputRange!R2 && isForwardRange!R1 && !isInfinite!R1)
    {
        return joiner(map!((ElementType!R2 a) => zip(range1.save, repeat(a)))
                          (range2));
    }
    else static if (isInputRange!R1 && isForwardRange!R2 && !isInfinite!R2)
    {
        return joiner(map!((ElementType!R1 a) => zip(repeat(a), range2.save))
                          (range1));
    }
    else static assert(0, "cartesianProduct involving finite ranges must "~
                          "have at least one finite forward range");
}

unittest
{
    // Test cartesian product of two infinite ranges
    auto Even = sequence!"2*n"(0);
    auto Odd = sequence!"2*n+1"(0);
    auto EvenOdd = cartesianProduct(Even, Odd);

    foreach (pair; [[0, 1], [2, 1], [0, 3], [2, 3], [4, 1], [4, 3], [0, 5],
                    [2, 5], [4, 5], [6, 1], [6, 3], [6, 5]])
    {
        assert(canFind(EvenOdd, tuple(pair[0], pair[1])));
    }

    // This should terminate in finite time
    assert(canFind(EvenOdd, tuple(124, 73)));
    assert(canFind(EvenOdd, tuple(0, 97)));
    assert(canFind(EvenOdd, tuple(42, 1)));
}

unittest
{
    // Test cartesian product of an infinite input range and a finite forward
    // range.
    auto N = sequence!"n"(0);
    auto M = [100, 200, 300];
    auto NM = cartesianProduct(N,M);

    foreach (pair; [[0, 100], [0, 200], [0, 300], [1, 100], [1, 200], [1, 300],
                    [2, 100], [2, 200], [2, 300], [3, 100], [3, 200],
                    [3, 300]])
    {
        assert(canFind(NM, tuple(pair[0], pair[1])));
    }

    // We can't solve the halting problem, so we can only check a finite
    // initial segment here.
    assert(!canFind(NM.take(100), tuple(100, 0)));
    assert(!canFind(NM.take(100), tuple(1, 1)));
    assert(!canFind(NM.take(100), tuple(100, 200)));

    auto MN = cartesianProduct(M,N);
    foreach (pair; [[100, 0], [200, 0], [300, 0], [100, 1], [200, 1], [300, 1],
                    [100, 2], [200, 2], [300, 2], [100, 3], [200, 3],
                    [300, 3]])
    {
        assert(canFind(MN, tuple(pair[0], pair[1])));
    }

    // We can't solve the halting problem, so we can only check a finite
    // initial segment here.
    assert(!canFind(MN.take(100), tuple(0, 100)));
    assert(!canFind(MN.take(100), tuple(0, 1)));
    assert(!canFind(MN.take(100), tuple(100, 200)));
}

unittest
{
    // Test cartesian product of two finite ranges.
    auto X = [1, 2, 3];
    auto Y = [4, 5, 6];
    auto XY = cartesianProduct(X, Y);
    auto Expected = [[1, 4], [1, 5], [1, 6], [2, 4], [2, 5], [2, 6], [3, 4],
                     [3, 5], [3, 6]];

    // Verify Expected ⊆ XY
    foreach (pair; Expected)
    {
        assert(canFind(XY, tuple(pair[0], pair[1])));
    }

    // Verify XY ⊆ Expected
    foreach (pair; XY)
    {
        assert(canFind(Expected, [pair[0], pair[1]]));
    }

    // And therefore, by set comprehension, XY == Expected
}

unittest
{
    auto N = sequence!"n"(0);

    // To force the template to fall to the second case, we wrap N in a struct
    // that doesn't allow bidirectional access.
    struct FwdRangeWrapper(R)
    {
        R impl;

        // Input range API
        @property auto front() { return impl.front; }
        void popFront() { impl.popFront(); }
        static if (isInfinite!R)
            enum empty = false;
        else
            @property bool empty() { return impl.empty; }

        // Forward range API
        @property auto save() { return typeof(this)(impl.save); }
    }
    auto fwdWrap(R)(R range) { return FwdRangeWrapper!R(range); }

    // General test: two infinite bidirectional ranges
    auto N2 = cartesianProduct(N, N);

    assert(canFind(N2, tuple(0, 0)));
    assert(canFind(N2, tuple(123, 321)));
    assert(canFind(N2, tuple(11, 35)));
    assert(canFind(N2, tuple(279, 172)));

    // Test first case: forward range with bidirectional range
    auto fwdN = fwdWrap(N);
    auto N2_a = cartesianProduct(fwdN, N);

    assert(canFind(N2_a, tuple(0, 0)));
    assert(canFind(N2_a, tuple(123, 321)));
    assert(canFind(N2_a, tuple(11, 35)));
    assert(canFind(N2_a, tuple(279, 172)));

    // Test second case: bidirectional range with forward range
    auto N2_b = cartesianProduct(N, fwdN);

    assert(canFind(N2_b, tuple(0, 0)));
    assert(canFind(N2_b, tuple(123, 321)));
    assert(canFind(N2_b, tuple(11, 35)));
    assert(canFind(N2_b, tuple(279, 172)));

    // Test third case: finite forward range with (infinite) input range
    static struct InpRangeWrapper(R)
    {
        R impl;

        // Input range API
        @property auto front() { return impl.front; }
        void popFront() { impl.popFront(); }
        static if (isInfinite!R)
            enum empty = false;
        else
            @property bool empty() { return impl.empty; }
    }
    auto inpWrap(R)(R r) { return InpRangeWrapper!R(r); }

    auto inpN = inpWrap(N);
    auto B = [ 1, 2, 3 ];
    auto fwdB = fwdWrap(B);
    auto BN = cartesianProduct(fwdB, inpN);

    assert(equal(map!"[a[0],a[1]]"(BN.take(10)), [[1, 0], [2, 0], [3, 0],
                 [1, 1], [2, 1], [3, 1], [1, 2], [2, 2], [3, 2], [1, 3]]));

    // Test fourth case: (infinite) input range with finite forward range
    auto NB = cartesianProduct(inpN, fwdB);

    assert(equal(map!"[a[0],a[1]]"(NB.take(10)), [[0, 1], [0, 2], [0, 3],
                 [1, 1], [1, 2], [1, 3], [2, 1], [2, 2], [2, 3], [3, 1]]));

    // General finite range case
    auto C = [ 4, 5, 6 ];
    auto BC = cartesianProduct(B, C);

    foreach (n; [[1, 4], [2, 4], [3, 4], [1, 5], [2, 5], [3, 5], [1, 6],
                 [2, 6], [3, 6]])
    {
        assert(canFind(BC, tuple(n[0], n[1])));
    }
}

/// ditto
auto cartesianProduct(R1, R2, RR...)(R1 range1, R2 range2, RR otherRanges)
{
    /* We implement the n-ary cartesian product by recursively invoking the
     * binary cartesian product. To make the resulting range nicer, we denest
     * one level of tuples so that a ternary cartesian product, for example,
     * returns 3-element tuples instead of nested 2-element tuples.
     */
    enum string denest = format("tuple(a[0], %(a[1][%d]%|,%))",
                                iota(0, otherRanges.length+1));
    return map!denest(
        cartesianProduct(range1, cartesianProduct(range2, otherRanges))
    );
}

unittest
{
    auto N = sequence!"n"(0);
    auto N3 = cartesianProduct(N, N, N);

    // Check that tuples are properly denested
    assert(is(ElementType!(typeof(N3)) == Tuple!(size_t,size_t,size_t)));

    assert(canFind(N3, tuple(0, 27, 7)));
    assert(canFind(N3, tuple(50, 23, 71)));
    assert(canFind(N3, tuple(9, 3, 0)));
}

version(none)
// This unittest causes `make -f posix.mak unittest` to run out of memory. Why?
unittest
{
    auto N = sequence!"n"(0);
    auto N4 = cartesianProduct(N, N, N, N);

    // Check that tuples are properly denested
    assert(is(ElementType!(typeof(N4)) == Tuple!(size_t,size_t,size_t,size_t)));

    assert(canFind(N4, tuple(1, 2, 3, 4)));
    assert(canFind(N4, tuple(4, 3, 2, 1)));
    assert(canFind(N4, tuple(10, 31, 7, 12)));
}

unittest
{
    auto A = [ 1, 2, 3 ];
    auto B = [ 'a', 'b', 'c' ];
    auto C = [ "x", "y", "z" ];
    auto ABC = cartesianProduct(A, B, C);

    assert(ABC.equal([
        tuple(1, 'a', "x"), tuple(2, 'a', "x"), tuple(3, 'a', "x"),
        tuple(1, 'b', "x"), tuple(2, 'b', "x"), tuple(3, 'b', "x"),
        tuple(1, 'c', "x"), tuple(2, 'c', "x"), tuple(3, 'c', "x"),
        tuple(1, 'a', "y"), tuple(2, 'a', "y"), tuple(3, 'a', "y"),
        tuple(1, 'b', "y"), tuple(2, 'b', "y"), tuple(3, 'b', "y"),
        tuple(1, 'c', "y"), tuple(2, 'c', "y"), tuple(3, 'c', "y"),
        tuple(1, 'a', "z"), tuple(2, 'a', "z"), tuple(3, 'a', "z"),
        tuple(1, 'b', "z"), tuple(2, 'b', "z"), tuple(3, 'b', "z"),
        tuple(1, 'c', "z"), tuple(2, 'c', "z"), tuple(3, 'c', "z"),
    ]));
}
