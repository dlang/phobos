// Written in the D programming language.
/**
This is a submodule of $(LINK2 std_algorithm_package.html, std.algorithm).
It contains generic _sorting algorithms.

$(BOOKTABLE Cheat Sheet,

$(TR $(TH Function Name) $(TH Description))

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
$(T2 topNIndex,
        Builds an index of the top elements of a range.)
)

Copyright: Andrei Alexandrescu 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/algorithm/_sorting.d)

Macros:
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
 */
module std.algorithm.sorting;

import std.algorithm : SortOutput; // FIXME
import std.algorithm.mutation : SwapStrategy;
import std.functional; // : unaryFun, binaryFun;
import std.range.primitives;
// FIXME
import std.range; // : SortedRange;
import std.traits;

// completeSort
/**
Sorts the random-access range $(D chain(lhs, rhs)) according to
predicate $(D less). The left-hand side of the range $(D lhs) is
assumed to be already sorted; $(D rhs) is assumed to be unsorted. The
exact strategy chosen depends on the relative sizes of $(D lhs) and
$(D rhs).  Performs $(BIGOH lhs.length + rhs.length * log(rhs.length))
(best case) to $(BIGOH (lhs.length + rhs.length) * log(lhs.length +
rhs.length)) (worst-case) evaluations of $(D swap).
*/
void completeSort(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
        Range1, Range2)(SortedRange!(Range1, less) lhs, Range2 rhs)
if (hasLength!(Range2) && hasSlicing!(Range2))
{
    import std.algorithm : bringToFront; // FIXME
    import std.range : chain, assumeSorted;
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

///
unittest
{
    import std.range : assumeSorted;
    int[] a = [ 1, 2, 3 ];
    int[] b = [ 4, 0, 6, 5 ];
    completeSort(assumeSorted(a), b);
    assert(a == [ 0, 1, 2 ]);
    assert(b == [ 3, 4, 5, 6 ]);
}

// isSorted
/**
Checks whether a forward range is sorted according to the comparison
operation $(D less). Performs $(BIGOH r.length) evaluations of $(D
less).
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
                "Predicate for isSorted is not antisymmetric. Both" ~
                        " pred(a, b) and pred(b, a) are true for certain values.");
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
                "Predicate for isSorted is not antisymmetric. Both" ~
                        " pred(a, b) and pred(b, a) are true for certain values.");
            return false;
        }
    }
    return true;
}

///
@safe unittest
{
    int[] arr = [4, 3, 2, 1];
    assert(!isSorted(arr));
    sort(arr);
    assert(isSorted(arr));
    sort!("a > b")(arr);
    assert(isSorted!("a > b")(arr));
}

@safe unittest
{
    import std.conv : to;

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

Returns:

The right part of $(D r) after partitioning.

If $(D ss == SwapStrategy.stable), $(D partition) preserves the
relative ordering of all elements $(D a), $(D b) in $(D r) for which
$(D pred(a) == pred(b)). If $(D ss == SwapStrategy.semistable), $(D
partition) preserves the relative ordering of all elements $(D a), $(D
b) in the left part of $(D r) for which $(D pred(a) == pred(b)).

See_Also:
    STL's $(WEB sgi.com/tech/stl/_partition.html, _partition)$(BR)
    STL's $(WEB sgi.com/tech/stl/stable_partition.html, stable_partition)
*/
Range partition(alias predicate,
        SwapStrategy ss = SwapStrategy.unstable, Range)(Range r)
    if ((ss == SwapStrategy.stable && isRandomAccessRange!(Range))
            || (ss != SwapStrategy.stable && isForwardRange!(Range)))
{
    import std.algorithm : bringToFront, swap; // FIXME;
    alias pred = unaryFun!(predicate);
    if (r.empty) return r;
    static if (ss == SwapStrategy.stable)
    {
        if (r.length == 1)
        {
            if (pred(r.front)) r.popFront();
            return r;
        }
        const middle = r.length / 2;
        alias recurse = .partition!(pred, ss, Range);
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

///
@safe unittest
{
    import std.algorithm : count, find; // FIXME
    import std.conv : text;

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
}

@safe unittest
{
    import std.algorithm : rndstuff; // FIXME
    static bool even(int a) { return (a & 1) == 0; }

    // test with random data
    auto a = rndstuff!int();
    partition!even(a);
    assert(isPartitioned!even(a));
    auto b = rndstuff!string();
    partition!`a.length < 5`(b);
    assert(isPartitioned!`a.length < 5`(b));
}

/**
Returns $(D true) if $(D r) is partitioned according to predicate $(D
pred).
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

///
@safe unittest
{
    int[] r = [ 1, 3, 5, 7, 8, 2, 4, ];
    assert(isPartitioned!"a & 1"(r));
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

    import std.algorithm : swap, swapRanges; // FIXME
    import std.algorithm.comparison : min;
    import std.typecons : tuple;

    alias lessFun = binaryFun!less;
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

///
@safe unittest
{
    auto a = [ 8, 3, 4, 1, 4, 7, 4 ];
    auto pieces = partition3(a, 4);
    assert(pieces[0] == [ 1, 3 ]);
    assert(pieces[1] == [ 4, 4, 4 ]);
    assert(pieces[2] == [ 8, 7 ]);
}

@safe unittest
{
    import std.random : uniform;

    auto a = new int[](uniform(0, 100));
    foreach (ref e; a)
    {
        e = uniform(0, 50);
    }
    auto pieces = partition3(a, 25);
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
    import std.algorithm : addressOf; // FIXME
    import std.exception : enforce;

    // assume collection already ordered
    size_t i;
    for (; !r.empty; r.popFront(), ++i)
        index[i] = addressOf(r.front);
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
    import std.exception : enforce;
    import std.conv : to;

    alias IndexType = Unqual!(ElementType!RangeIndex);
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

///
unittest
{
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
}

unittest
{
    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");
    immutable(int)[] arr = [ 2, 3, 1, 5, 0 ];
    // index using pointers
    auto index1 = new immutable(int)*[arr.length];
    alias ImmRange = typeof(arr);
    alias ImmIndex = typeof(index1);
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

private template validPredicates(E, less...)
{
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
 */
template multiSort(less...) //if (less.length > 1)
{
    void multiSort(Range)(Range r)
    if (validPredicates!(ElementType!Range, less))
    {
        static if (is(typeof(less[$ - 1]) == SwapStrategy))
        {
            enum ss = less[$ - 1];
            alias funs = less[0 .. $ - 1];
        }
        else
        {
            alias ss = SwapStrategy.unstable;
            alias funs = less;
        }
        alias lessFun = binaryFun!(funs[0]);

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

///
@safe unittest
{
    static struct Point { int x, y; }
    auto pts1 = [ Point(0, 0), Point(5, 5), Point(0, 1), Point(0, 2) ];
    auto pts2 = [ Point(0, 0), Point(0, 1), Point(0, 2), Point(5, 5) ];
    multiSort!("a.x < b.x", "a.y < b.y", SwapStrategy.unstable)(pts1);
    assert(pts1 == pts2);
}

@safe unittest
{
    import std.algorithm.comparison : equal;
    import std.range;

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

@safe unittest //issue 9160 (L-value only comparators)
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
    import std.algorithm.mutation : swapAt;

    // This algorithm sorts the first, middle and last elements of r,
    // then returns the index of the middle element.  In effect, it uses the
    // median-of-three heuristic.

    alias pred = binaryFun!(less);
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
    import std.algorithm.mutation : swapAt;

    alias pred = binaryFun!(less);
    if (r.length < 2)
    {
        return;
    }

    immutable maxJ = r.length - 1;
    for (size_t i = r.length - 2; i != size_t.max; --i)
    {
        size_t j = i;

        static if (hasAssignableElements!Range)
        {
            auto temp = r[i];

            for (; j < maxJ && pred(r[j + 1], temp); ++j)
            {
                r[j] = r[j + 1];
            }

            r[j] = temp;
        }
        else
        {
            for (; j < maxJ && pred(r[j + 1], r[j]); ++j)
            {
                swapAt(r, j, j + 1);
            }
        }
    }
}

@safe unittest
{
    import std.random : Random, uniform;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    auto rnd = Random(1);
    auto a = new int[uniform(100, 200, rnd)];
    foreach (ref e; a) {
        e = uniform(-100, 100, rnd);
    }

    optimisticInsertionSort!(binaryFun!("a < b"), int[])(a);
    assert(isSorted(a));
}

// sort
/**
Sorts a random-access range according to the predicate $(D less). Performs
$(BIGOH r.length * log(r.length)) evaluations of $(D less). Stable sorting
requires $(D hasAssignableElements!Range) to be true.

$(D sort) returns a $(XREF range, SortedRange) over the original range, which
functions that can take advantage of sorted data can then use to know that the
range is sorted and adjust accordingly. The $(XREF range, SortedRange) is a
wrapper around the original range, so both it and the original range are sorted,
but other functions won't know that the original range has been sorted, whereas
they $(I can) know that $(XREF range, SortedRange) has been sorted.

The predicate is expected to satisfy certain rules in order for $(D sort) to
behave as expected - otherwise, the program may fail on certain inputs (but not
others) when not compiled in release mode, due to the cursory $(D assumeSorted)
check. Specifically, $(D sort) expects $(D less(a,b) && less(b,c)) to imply
$(D less(a,c)) (transitivity), and, conversely, $(D !less(a,b) && !less(b,c)) to
imply $(D !less(a,c)). Note that the default predicate ($(D "a < b")) does not
always satisfy these conditions for floating point types, because the expression
will always be $(D false) when either $(D a) or $(D b) is NaN.

Returns: The initial range wrapped as a $(D SortedRange) with the predicate
$(D binaryFun!less).

Algorithms: $(WEB en.wikipedia.org/wiki/Introsort) is used for unstable sorting and
$(WEB en.wikipedia.org/wiki/Timsort, Timsort) is used for stable sorting.
Each algorithm has benefits beyond stability. Introsort is generally faster but
Timsort may achieve greater speeds on data with low entropy or if predicate calls
are expensive. Introsort performs no allocations whereas Timsort will perform one
or more allocations per call. Both algorithms have $(BIGOH n log n) worst-case
time complexity.

See_Also:
    $(XREF range, assumeSorted)$(BR)
    $(XREF range, SortedRange)$(BR)
    $(XREF algorithm, SwapStrategy)$(BR)
    $(XREF functional, binaryFun)
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
    import std.range : assumeSorted;
    alias lessFun = binaryFun!(less);
    alias LessRet = typeof(lessFun(r.front, r.front));    // instantiate lessFun
    static if (is(LessRet == bool))
    {
        static if (ss == SwapStrategy.unstable)
            quickSortImpl!(lessFun)(r, r.length);
        else //use Tim Sort for semistable & stable
            TimSortImpl!(lessFun, Range).sort(r, null);

        enum maxLen = 8;
        assert(isSorted!lessFun(r), "Failed to sort range of type " ~ Range.stringof);
    }
    else
    {
        static assert(false, "Invalid predicate passed to sort: " ~ less.stringof);
    }
    return assumeSorted!less(r);
}

///
@safe pure nothrow unittest
{
    int[] array = [ 1, 2, 3, 4 ];
    // sort in descending order
    sort!("a > b")(array);
    assert(array == [ 4, 3, 2, 1 ]);
    // sort in ascending order
    sort(array);
    assert(array == [ 1, 2, 3, 4 ]);
    // sort with a delegate
    bool myComp(int x, int y) @safe pure nothrow { return x > y; }
    sort!(myComp)(array);
    assert(array == [ 4, 3, 2, 1 ]);
}
///
unittest
{
    // Showcase stable sorting
    string[] words = [ "aBc", "a", "abc", "b", "ABC", "c" ];
    sort!("toUpper(a) < toUpper(b)", SwapStrategy.stable)(words);
    assert(words == [ "a", "aBc", "abc", "ABC", "b", "c" ]);
}

unittest
{
    import std.algorithm : rndstuff; // FIXME
    import std.algorithm : swapRanges; // FIXME
    import std.random : Random, unpredictableSeed, uniform;
    import std.uni : toUpper;

    debug(std_algorithm) scope(success)
        writeln("unittest @", __FILE__, ":", __LINE__, " done.");

    // sort using delegate
    auto a = new int[100];
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

    {
        // Issue 10317
        enum E_10317 { a, b }
        auto a_10317 = new E_10317[10];
        sort(a_10317);
    }

    {
        // Issue 7767
        // Unstable sort should complete without an excessive number of predicate calls
        // This would suggest it's running in quadratic time

        // Compilation error if predicate is not static, i.e. a nested function
        static uint comp;
        static bool pred(size_t a, size_t b)
        {
            ++comp;
            return a < b;
        }

        size_t[] arr;
        arr.length = 1024;

        foreach(k; 0..arr.length) arr[k] = k;
        swapRanges(arr[0..$/2], arr[$/2..$]);

        sort!(pred, SwapStrategy.unstable)(arr);
        assert(comp < 25_000);
    }

    {
        import std.algorithm : swap; // FIXME

        bool proxySwapCalled;
        struct S
        {
            int i;
            alias i this;
            void proxySwap(ref S other) { swap(i, other.i); proxySwapCalled = true; }
            @disable void opAssign(S value);
        }

        alias R = S[];
        R r = [S(3), S(2), S(1)];
        static assert(hasSwappableElements!R);
        static assert(!hasAssignableElements!R);
        r.sort();
        assert(proxySwapCalled);
    }
}

private void quickSortImpl(alias less, Range)(Range r, size_t depth)
{
    import std.algorithm : swap; // FIXME
    import std.algorithm.mutation : swapAt;
    import std.algorithm.comparison : min;

    alias Elem = ElementType!(Range);
    enum size_t optimisticInsertionSortGetsBetter = 25;
    static assert(optimisticInsertionSortGetsBetter >= 1);

    // partition
    while (r.length > optimisticInsertionSortGetsBetter)
    {
        if (depth == 0)
        {
            HeapSortImpl!(less, Range).heapSort(r);
            return;
        }
        depth = depth >= depth.max / 2 ? (depth / 3) * 2 : (depth * 2) / 3;

        const pivotIdx = getPivot!(less)(r);
        auto pivot = r[pivotIdx];

        alias pred = binaryFun!(less);

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
        .quickSortImpl!(less, Range)(right, depth);
        r = left;
    }
    // residual sort
    static if (optimisticInsertionSortGetsBetter > 1)
    {
        optimisticInsertionSort!(less, Range)(r);
    }
}

// Bottom-Up Heap-Sort Implementation
private template HeapSortImpl(alias less, Range)
{
    import std.algorithm.mutation : swapAt;

    static assert(isRandomAccessRange!Range);
    static assert(hasLength!Range);
    static assert(hasSwappableElements!Range || hasAssignableElements!Range);

    alias lessFun = binaryFun!less;

    //template because of @@@12410@@@
    void heapSort()(Range r)
    {
        // If true, there is nothing to do
        if(r.length < 2) return;

        // Build Heap
        size_t i = r.length / 2;
        while(i > 0) sift(r, --i, r.length);

        // Sort
        i = r.length - 1;
        while(i > 0)
        {
            swapAt(r, 0, i);
            sift(r, 0, i);
            --i;
        }
    }

    //template because of @@@12410@@@
    void sift()(Range r, size_t parent, immutable size_t end)
    {
        immutable root = parent;
        size_t child = void;

        // Sift down
        while(true)
        {
            child = parent * 2 + 1;

            if(child >= end) break;

            if(child + 1 < end && lessFun(r[child], r[child + 1])) child += 1;

            swapAt(r, parent, child);
            parent = child;
        }

        child = parent;

        // Sift up
        while(child > root)
        {
            parent = (child - 1) / 2;
            if(lessFun(r[parent], r[child]))
            {
                swapAt(r, parent, child);
                child = parent;
            }
            else break;
        }
    }
}

// Tim Sort implementation
private template TimSortImpl(alias pred, R)
{
    import core.bitop : bsr;
    import std.array : uninitializedArray;

    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasSlicing!R);
    static assert(hasAssignableElements!R);

    alias T = ElementType!R;

    alias less = binaryFun!pred;
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
        import std.algorithm.comparison : min;

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
        import std.algorithm : reverse; // FIXME

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
    import std.algorithm : move; // FIXME

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
    import std.algorithm : copy; // FIXME

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
    import std.algorithm : copy; // FIXME

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
            alias gap = center;

            static if (forwardReverse)
            {
                static if (!lowerUpper) alias comp = lessEqual; // reverse lower
                static if (lowerUpper)  alias comp = less;      // reverse upper

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
                static if (!lowerUpper) alias comp = greater;      // forward lower
                static if (lowerUpper)  alias comp = greaterEqual; // forward upper

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

    alias gallopForwardLower = gallopSearch!(false, false);
    alias gallopForwardUpper = gallopSearch!(false,  true);
    alias gallopReverseLower = gallopSearch!( true, false);
    alias gallopReverseUpper = gallopSearch!( true,  true);
}

unittest
{
    import std.random : Random, uniform, randomShuffle;

    // Element type with two fields
    static struct E
    {
        size_t value, index;
    }

    // Generates data especially for testing sorting with Timsort
    static E[] genSampleData(uint seed)
    {
    import std.algorithm : swap, swapRanges; // FIXME

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
    assert(isSorted!"a < b"(sort!("a < b", SwapStrategy.stable)(
       [83, 42, 85, 86, 87, 22, 89, 30, 91, 46, 93, 94, 95, 6,
         97, 14, 33, 10, 101, 102, 103, 26, 105, 106, 107, 6]
    )));

}

unittest
{
    //test stable sort + zip
    import std.range;
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
    import core.stdc.stdlib : malloc, free;
    import std.conv : emplace;
    import std.string : representation;
    import std.range : zip, SortedRange;

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
    import std.typecons : Tuple;
    Tuple!(char)[] chars;
    schwartzSort!"a[0]"(chars);
}

unittest
{
    // issue 5924
    import std.typecons : Tuple;
    Tuple!(char)[] chars;
    schwartzSort!((Tuple!(char) c){ return c[0]; })(chars);
}

unittest
{
    import std.algorithm.iteration : map;
    import std.math : log2;

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
    auto arr = new double[][3];
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
    import std.algorithm.iteration : map;
    import std.math : log2;

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
    auto arr = new double[][3];
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
*/
void partialSort(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
    Range)(Range r, size_t n)
    if (isRandomAccessRange!(Range) && hasLength!(Range) && hasSlicing!(Range))
{
    topN!(less, ss)(r, n);
    sort!(less, ss)(r[0 .. n]);
}

///
@safe unittest
{
    int[] a = [ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ];
    partialSort(a, 5);
    assert(a[0 .. 5] == [ 0, 1, 2, 3, 4 ]);
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
(if stable) evaluations of $(D less) and $(D swap).

If $(D n >= r.length), the algorithm has no effect.

See_Also:
    $(LREF topNIndex),
    $(WEB sgi.com/tech/stl/nth_element.html, STL's nth_element)

BUGS:

Stable topN has not been implemented yet.
*/
void topN(alias less = "a < b",
        SwapStrategy ss = SwapStrategy.unstable,
        Range)(Range r, size_t nth)
    if (isRandomAccessRange!(Range) && hasLength!Range)
{
    import std.algorithm : swap; // FIXME
    import std.random : uniform;

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

///
@safe unittest
{
    int[] v = [ 25, 7, 9, 2, 0, 5, 21 ];
    auto n = 4;
    topN!"a < b"(v, n);
    assert(v[n] == 9);
}

@safe unittest
{
    import std.algorithm.comparison : max, min;
    import std.algorithm.iteration : reduce;

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

@safe unittest
{
    import std.algorithm.comparison : max, min;
    import std.algorithm.iteration : reduce;
    import std.random : uniform;

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
    import std.container : BinaryHeap;

    static assert(ss == SwapStrategy.unstable,
            "Stable topN not yet implemented");
    auto heap = BinaryHeap!Range1(r1);
    for (; !r2.empty; r2.popFront())
    {
        heap.conditionalInsert(r2.front);
    }
}

///
unittest
{
    int[] a = [ 5, 7, 2, 6, 7 ];
    int[] b = [ 2, 1, 5, 6, 7, 3, 0 ];
    topN(a, b);
    sort(a);
    assert(a == [0, 1, 2, 2, 3]);
}

/**
Copies the top $(D n) elements of the input range $(D source) into the
random-access range $(D target), where $(D n =
target.length). Elements of $(D source) are not touched. If $(D
sorted) is $(D true), the target is sorted. Otherwise, the target
respects the $(WEB en.wikipedia.org/wiki/Binary_heap, heap property).
 */
TRange topNCopy(alias less = "a < b", SRange, TRange)
    (SRange source, TRange target, SortOutput sorted = SortOutput.no)
    if (isInputRange!(SRange) && isRandomAccessRange!(TRange)
            && hasLength!(TRange) && hasSlicing!(TRange))
{
    import std.container : BinaryHeap;

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

///
unittest
{
    int[] a = [ 10, 16, 2, 3, 1, 5, 0 ];
    int[] b = new int[3];
    topNCopy(a, b, SortOutput.yes);
    assert(b == [ 0, 1, 2 ]);
}

unittest
{
    import std.random : Random, unpredictableSeed, uniform, randomShuffle;

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
Given a range of elements, constructs an index of its top $(I n) elements
(i.e., the first $(I n) elements if the range were sorted).

Similar to $(LREF topN), except that the range is not modified.

Params:
    less = A binary predicate that defines the ordering of range elements.
        Defaults to $(D a < b).
    ss = $(RED (Not implemented yet.)) Specify the swapping strategy.
    r = A $(XREF2 range, isRandomAccessRange, random-access range) of elements
        to make an index for.
    index = A $(XREF2 range, isRandomAccessRange, random-access range) with
        assignable elements to build the index in. The length of this range
        determines how many top elements to index in $(D r).

        This index range can either have integral elements, in which case the
        constructed index will consist of zero-based numerical indices into
        $(D r); or it can have pointers to the element type of $(D r), in which
        case the constructed index will be pointers to the top elements in
        $(D r).
    sorted = Determines whether to sort the index by the elements they refer
        to.

See_also: $(LREF topN), $(LREF topNCopy).

BUGS:
The swapping strategy parameter is not implemented yet; currently it is
ignored.
*/
void topNIndex(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
               Range, RangeIndex)
              (Range r, RangeIndex index, SortOutput sorted = SortOutput.no)
    if (isRandomAccessRange!Range &&
        isRandomAccessRange!RangeIndex &&
        hasAssignableElements!RangeIndex &&
        isIntegral!(ElementType!(RangeIndex)))
{
    static assert(ss == SwapStrategy.unstable,
                  "Stable swap strategy not implemented yet.");

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

/// ditto
void topNIndex(alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable,
               Range, RangeIndex)
              (Range r, RangeIndex index, SortOutput sorted = SortOutput.no)
    if (isRandomAccessRange!Range &&
        isRandomAccessRange!RangeIndex &&
        hasAssignableElements!RangeIndex &&
        is(ElementType!(RangeIndex) == ElementType!(Range)*))
{
    static assert(ss == SwapStrategy.unstable,
                  "Stable swap strategy not implemented yet.");

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

///
unittest
{
    // Construct index to top 3 elements using numerical indices:
    int[] a = [ 10, 2, 7, 5, 8, 1 ];
    int[] index = new int[3];
    topNIndex(a, index, SortOutput.yes);
    assert(index == [5, 1, 3]); // because a[5]==1, a[1]==2, a[3]==5

    // Construct index to top 3 elements using pointer indices:
    int*[] ptrIndex = new int*[3];
    topNIndex(a, ptrIndex, SortOutput.yes);
    assert(ptrIndex == [ &a[5], &a[1], &a[3] ]);
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
do
{
    // use the current permutation and
    // proceed to the next permutation of the array.
} while (nextPermutation(a));
----
 * Returns: false if the range was lexicographically the greatest, in which
 * case the range is reversed back to the lexicographically smallest
 * permutation; otherwise returns true.
 */
bool nextPermutation(alias less="a < b", BidirectionalRange)
                    (BidirectionalRange range)
    if (isBidirectionalRange!BidirectionalRange &&
        hasSwappableElements!BidirectionalRange)
{
    import std.algorithm : find, reverse, swap; // FIXME
    import std.range : retro, takeExactly;
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

///
@safe unittest
{
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
}

///
@safe unittest
{
    // Step through permutations of an array containing duplicate elements:
    int[] a = [1,1,2];
    assert(nextPermutation(a) == true);
    assert(a == [1,2,1]);
    assert(nextPermutation(a) == true);
    assert(a == [2,1,1]);
    assert(nextPermutation(a) == false);
    assert(a == [1,1,2]);
}

@safe unittest
{
    // Boundary cases: arrays of 0 or 1 element.
    int[] a1 = [];
    assert(!nextPermutation(a1));
    assert(a1 == []);

    int[] a2 = [1];
    assert(!nextPermutation(a2));
    assert(a2 == [1]);
}

@safe unittest
{
    import std.algorithm.comparison : equal;

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

@safe unittest
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

// Issue 13594
@safe unittest
{
    int[3] a = [1,2,3];
    assert(nextPermutation(a[]));
    assert(a == [1,3,2]);
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
do
{
    // use the current permutation and
    // proceed to the next even permutation of the array.
} while (nextEvenPermutation(a));
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
do
{
    // use the current permutation and
    // proceed to the next odd permutation of the original array
    // (which is an even permutation of the first odd permutation).
} while (nextEvenPermutation(a));
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
 */
bool nextEvenPermutation(alias less="a < b", BidirectionalRange)
                        (BidirectionalRange range)
    if (isBidirectionalRange!BidirectionalRange &&
        hasSwappableElements!BidirectionalRange)
{
    import std.algorithm : find, reverse, swap; // FIXME
    import std.range : retro, takeExactly;
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

///
@safe unittest
{
    // Step through even permutations of a sorted array in lexicographic order
    int[] a = [1,2,3];
    assert(nextEvenPermutation(a) == true);
    assert(a == [2,3,1]);
    assert(nextEvenPermutation(a) == true);
    assert(a == [3,1,2]);
    assert(nextEvenPermutation(a) == false);
    assert(a == [1,2,3]);
}

@safe unittest
{
    auto a3 = [ 1, 2, 3, 4 ];
    int count = 1;
    while (nextEvenPermutation(a3)) count++;
    assert(count == 12);
}

@safe unittest
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

@safe unittest
{
    // Test various cases of rollover
    auto a = [ 3, 1, 2 ];
    assert(nextEvenPermutation(a) == false);
    assert(a == [ 1, 2, 3 ]);

    auto b = [ 3, 2, 1 ];
    assert(nextEvenPermutation(b) == false);
    assert(b == [ 1, 3, 2 ]);
}

@safe unittest
{
    // Issue 13594
    int[3] a = [1,2,3];
    assert(nextEvenPermutation(a[]));
    assert(a == [2,3,1]);
}

/**
Even permutations are useful for generating coordinates of certain geometric
shapes. Here's a non-trivial example:
*/
@safe unittest
{
    import std.math : sqrt;

    // Print the 60 vertices of a uniform truncated icosahedron (soccer ball)
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

