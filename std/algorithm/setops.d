// Written in the D programming language.
/**
This is a submodule of $(LINK2 std_algorithm_package.html, std.algorithm).
It contains generic algorithms that implement set operations.

$(BOOKTABLE Cheat Sheet,

$(TR $(TH Function Name) $(TH Description))

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
)

Copyright: Andrei Alexandrescu 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/algorithm/_setops.d)

Macros:
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
 */
module std.algorithm.setops;

import std.range.primitives;

// FIXME
import std.functional; // : unaryFun, binaryFun;
import std.traits;
// FIXME
import std.typetuple; // : TypeTuple, staticMap, allSatisfy, anySatisfy;

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
*/
auto cartesianProduct(R1, R2)(R1 range1, R2 range2)
    if (!allSatisfy!(isForwardRange, R1, R2) ||
        anySatisfy!(isInfinite, R1, R2))
{
    import std.algorithm.iteration : map, joiner;

    static if (isInfinite!R1 && isInfinite!R2)
    {
        static if (isForwardRange!R1 && isForwardRange!R2)
        {
            import std.range : zip, repeat, take, chain, sequence;

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
    else static if (isInputRange!R1 && isForwardRange!R2 && !isInfinite!R2)
    {
        import std.range : zip, repeat;
        return joiner(map!((ElementType!R1 a) => zip(repeat(a), range2.save))
                          (range1));
    }
    else static if (isInputRange!R2 && isForwardRange!R1 && !isInfinite!R1)
    {
        import std.range : zip, repeat;
        return joiner(map!((ElementType!R2 a) => zip(range1.save, repeat(a)))
                          (range2));
    }
    else static assert(0, "cartesianProduct involving finite ranges must "~
                          "have at least one finite forward range");
}

///
@safe unittest
{
    import std.algorithm.searching : canFind;
    import std.range;
    import std.typecons : tuple;

    auto N = sequence!"n"(0);         // the range of natural numbers
    auto N2 = cartesianProduct(N, N); // the range of all pairs of natural numbers

    // Various arbitrary number pairs can be found in the range in finite time.
    assert(canFind(N2, tuple(0, 0)));
    assert(canFind(N2, tuple(123, 321)));
    assert(canFind(N2, tuple(11, 35)));
    assert(canFind(N2, tuple(279, 172)));
}

///
@safe unittest
{
    import std.algorithm.searching : canFind;
    import std.typecons : tuple;

    auto B = [ 1, 2, 3 ];
    auto C = [ 4, 5, 6 ];
    auto BC = cartesianProduct(B, C);

    foreach (n; [[1, 4], [2, 4], [3, 4], [1, 5], [2, 5], [3, 5], [1, 6],
                 [2, 6], [3, 6]])
    {
        assert(canFind(BC, tuple(n[0], n[1])));
    }
}

@safe unittest
{
    // Test cartesian product of two infinite ranges
    import std.algorithm.searching : canFind;
    import std.range;
    import std.typecons : tuple;

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

@safe unittest
{
    // Test cartesian product of an infinite input range and a finite forward
    // range.
    import std.algorithm.searching : canFind;
    import std.range;
    import std.typecons : tuple;

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

@safe unittest
{
    import std.algorithm.searching : canFind;
    import std.typecons : tuple;

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

@safe unittest
{
    import std.algorithm.searching : canFind;
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : map;
    import std.typecons : tuple;

    import std.range;
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

// Issue 13091
pure nothrow @safe @nogc unittest
{
    import std.algorithm: cartesianProduct;
    int[1] a = [1];
    foreach (t; cartesianProduct(a[], a[])) {}
}

/// ditto
auto cartesianProduct(RR...)(RR ranges)
    if (ranges.length >= 2 &&
        allSatisfy!(isForwardRange, RR) &&
        !anySatisfy!(isInfinite, RR))
{
    // This overload uses a much less template-heavy implementation when
    // all ranges are finite forward ranges, which is the most common use
    // case, so that we don't run out of resources too quickly.
    //
    // For infinite ranges or non-forward ranges, we fall back to the old
    // implementation which expands an exponential number of templates.
    import std.typecons : tuple;

    static struct Result
    {
        RR ranges;
        RR current;
        bool empty = true;

        this(RR _ranges)
        {
            ranges = _ranges;
            empty = false;
            foreach (i, r; ranges)
            {
                current[i] = r.save;
                if (current[i].empty)
                    empty = true;
            }
        }
        @property auto front()
        {
            import std.algorithm : algoFormat; // FIXME
            import std.range : iota;
            return mixin(algoFormat("tuple(%(current[%d].front%|,%))",
                                    iota(0, current.length)));
        }
        void popFront()
        {
            foreach_reverse (i, ref r; current)
            {
                r.popFront();
                if (!r.empty) break;

                static if (i==0)
                    empty = true;
                else
                    r = ranges[i].save; // rollover
            }
        }
        @property Result save()
        {
            Result copy = this;
            foreach (i, r; ranges)
            {
                copy.ranges[i] = r.save;
                copy.current[i] = current[i].save;
            }
            return copy;
        }
    }
    static assert(isForwardRange!Result);

    return Result(ranges);
}

@safe unittest
{
    // Issue 10693: cartesian product of empty ranges should be empty.
    int[] a, b, c, d, e;
    auto cprod = cartesianProduct(a,b,c,d,e);
    assert(cprod.empty);
    foreach (_; cprod) {} // should not crash

    // Test case where only one of the ranges is empty: the result should still
    // be empty.
    int[] p=[1], q=[];
    auto cprod2 = cartesianProduct(p,p,p,q,p);
    assert(cprod2.empty);
    foreach (_; cprod2) {} // should not crash
}

@safe unittest
{
    // .init value of cartesianProduct should be empty
    auto cprod = cartesianProduct([0,0], [1,1], [2,2]);
    assert(!cprod.empty);
    assert(cprod.init.empty);
}

@safe unittest
{
    // Issue 13393
    assert(!cartesianProduct([0],[0],[0]).save.empty);
}

/// ditto
auto cartesianProduct(R1, R2, RR...)(R1 range1, R2 range2, RR otherRanges)
    if (!allSatisfy!(isForwardRange, R1, R2, RR) ||
        anySatisfy!(isInfinite, R1, R2, RR))
{
    /* We implement the n-ary cartesian product by recursively invoking the
     * binary cartesian product. To make the resulting range nicer, we denest
     * one level of tuples so that a ternary cartesian product, for example,
     * returns 3-element tuples instead of nested 2-element tuples.
     */
    import std.algorithm : algoFormat; // FIXME
    import std.algorithm.iteration : map;
    import std.range : iota;

    enum string denest = algoFormat("tuple(a[0], %(a[1][%d]%|,%))",
                                iota(0, otherRanges.length+1));
    return map!denest(
        cartesianProduct(range1, cartesianProduct(range2, otherRanges))
    );
}

@safe unittest
{
    import std.algorithm.searching : canFind;
    import std.range;
    import std.typecons : tuple, Tuple;

    auto N = sequence!"n"(0);
    auto N3 = cartesianProduct(N, N, N);

    // Check that tuples are properly denested
    assert(is(ElementType!(typeof(N3)) == Tuple!(size_t,size_t,size_t)));

    assert(canFind(N3, tuple(0, 27, 7)));
    assert(canFind(N3, tuple(50, 23, 71)));
    assert(canFind(N3, tuple(9, 3, 0)));
}

@safe unittest
{
    import std.algorithm.searching : canFind;
    import std.range;
    import std.typecons : tuple, Tuple;

    auto N = sequence!"n"(0);
    auto N4 = cartesianProduct(N, N, N, N);

    // Check that tuples are properly denested
    assert(is(ElementType!(typeof(N4)) == Tuple!(size_t,size_t,size_t,size_t)));

    assert(canFind(N4, tuple(1, 2, 3, 4)));
    assert(canFind(N4, tuple(4, 3, 2, 1)));
    assert(canFind(N4, tuple(10, 31, 7, 12)));
}

// Issue 9878
///
@safe unittest
{
    import std.algorithm.comparison : equal;
    import std.typecons : tuple;

    auto A = [ 1, 2, 3 ];
    auto B = [ 'a', 'b', 'c' ];
    auto C = [ "x", "y", "z" ];
    auto ABC = cartesianProduct(A, B, C);

    assert(ABC.equal([
        tuple(1, 'a', "x"), tuple(1, 'a', "y"), tuple(1, 'a', "z"),
        tuple(1, 'b', "x"), tuple(1, 'b', "y"), tuple(1, 'b', "z"),
        tuple(1, 'c', "x"), tuple(1, 'c', "y"), tuple(1, 'c', "z"),
        tuple(2, 'a', "x"), tuple(2, 'a', "y"), tuple(2, 'a', "z"),
        tuple(2, 'b', "x"), tuple(2, 'b', "y"), tuple(2, 'b', "z"),
        tuple(2, 'c', "x"), tuple(2, 'c', "y"), tuple(2, 'c', "z"),
        tuple(3, 'a', "x"), tuple(3, 'a', "y"), tuple(3, 'a', "z"),
        tuple(3, 'b', "x"), tuple(3, 'b', "y"), tuple(3, 'b', "z"),
        tuple(3, 'c', "x"), tuple(3, 'c', "y"), tuple(3, 'c', "z")
    ]));
}

pure @safe nothrow @nogc unittest
{
    int[2] A = [1,2];
    auto C = cartesianProduct(A[], A[], A[]);
    assert(isForwardRange!(typeof(C)));

    C.popFront();
    auto front1 = C.front;
    auto D = C.save;
    C.popFront();
    assert(D.front == front1);
}

// Issue 13935
unittest
{
    import std.algorithm.iteration : map;
    auto seq = [1, 2].map!(x => x);
    foreach (pair; cartesianProduct(seq, seq)) {}
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
create a larger $(D tgt) range. In the example above, creating $(D b)
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

import std.algorithm : SortOutput; // FIXME

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
    import std.algorithm.iteration : group;
    import std.algorithm.sorting : topNCopy;

    if (tgt.empty) return;
    alias InfoType = ElementType!Range;
    bool heapComp(InfoType a, InfoType b)
    {
        return weights[a[0]] * a[1] > weights[b[0]] * b[1];
    }
    topNCopy!heapComp(group(nWayUnion!less(ror)), tgt, sorted);
}

unittest
{
    import std.conv : text;
    import std.typecons : tuple, Tuple;

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
    import std.conv : text;
    import std.typecons : tuple, Tuple;

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
    import std.typecons : tuple, Tuple;

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
    import std.container : Array;
    import std.typecons : Tuple;

    alias T = Tuple!(uint, uint);
    const Array!T arrayOne = Array!T( [ T(1,2), T(3,4) ] );
    const Array!T arrayTwo = Array!T([ T(1,2), T(3,4) ] );

    assert(arrayOne == arrayTwo);
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
 */
struct NWayUnion(alias less, RangeOfRanges)
{
    import std.container : BinaryHeap;

    private alias ElementType = .ElementType!(.ElementType!RangeOfRanges);
    private alias comp = binaryFun!less;
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
        import std.algorithm.mutation : remove, SwapStrategy;

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

///
unittest
{
    import std.algorithm.comparison : equal;

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
    assert(equal(nWayUnion(a), witness));
}

/**
Lazily computes the difference of $(D r1) and $(D r2). The two ranges
are assumed to be sorted by $(D less). The element types of the two
ranges must have a common type.
 */
struct SetDifference(alias less = "a < b", R1, R2)
    if (isInputRange!(R1) && isInputRange!(R2))
{
private:
    R1 r1;
    R2 r2;
    alias comp = binaryFun!(less);

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

    @property auto ref front()
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

///
@safe unittest
{
    import std.algorithm.comparison : equal;

    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    assert(equal(setDifference(a, b), [5, 9][]));
    static assert(isForwardRange!(typeof(setDifference(a, b))));
}

@safe unittest // Issue 10460
{
    import std.algorithm.comparison : equal;

    int[] a = [1, 2, 3, 4, 5];
    int[] b = [2, 4];
    foreach (ref e; setDifference(a, b))
        e = 0;
    assert(equal(a, [0, 2, 0, 4, 0]));
}

/**
Lazily computes the intersection of two or more input ranges $(D
ranges). The ranges are assumed to be sorted by $(D less). The element
types of the ranges must have a common type.
 */
struct SetIntersection(alias less = "a < b", Rs...)
    if (Rs.length >= 2 && allSatisfy!(isInputRange, Rs) &&
        !is(CommonType!(staticMap!(ElementType, Rs)) == void))
{
private:
    Rs _input;
    alias comp = binaryFun!less;
    alias ElementType = CommonType!(staticMap!(.ElementType, Rs));

    // Positions to the first elements that are all equal
    void adjustPosition()
    {
        if (empty) return;

        size_t done = Rs.length;
        static if (Rs.length > 1) while (true)
        {
            foreach (i, ref r; _input)
            {
                alias next = _input[(i + 1) % Rs.length];

                if (comp(next.front, r.front))
                {
                    do {
                        next.popFront();
                        if (next.empty) return;
                    } while(comp(next.front, r.front));
                    done = Rs.length;
                }
                if (--done == 0) return;
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
        foreach (ref r; _input)
        {
            if (r.empty) return true;
        }
        return false;
    }

    void popFront()
    {
        assert(!empty);
        static if (Rs.length > 1) foreach (i, ref r; _input)
        {
            alias next = _input[(i + 1) % Rs.length];
            assert(!comp(r.front, next.front));
        }

        foreach (ref r; _input)
        {
            r.popFront();
        }
        adjustPosition();
    }

    @property ElementType front()
    {
        assert(!empty);
        return _input[0].front;
    }

    static if (allSatisfy!(isForwardRange, Rs))
    {
        @property SetIntersection save()
        {
            auto ret = this;
            foreach (i, ref r; _input)
            {
                ret._input[i] = r.save;
            }
            return ret;
        }
    }
}

/// Ditto
SetIntersection!(less, Rs) setIntersection(alias less = "a < b", Rs...)(Rs ranges)
    if (Rs.length >= 2 && allSatisfy!(isInputRange, Rs) &&
        !is(CommonType!(staticMap!(ElementType, Rs)) == void))
{
    return typeof(return)(ranges);
}

///
@safe unittest
{
    import std.algorithm.comparison : equal;

    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    int[] c = [ 0, 1, 4, 5, 7, 8 ];
    assert(equal(setIntersection(a, a), a));
    assert(equal(setIntersection(a, b), [1, 2, 4, 7]));
    assert(equal(setIntersection(a, b, c), [1, 4, 7]));
}

@safe unittest
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : filter;

    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    int[] c = [ 0, 1, 4, 5, 7, 8 ];
    int[] d = [ 1, 3, 4 ];
    int[] e = [ 4, 5 ];

    assert(equal(setIntersection(a, a), a));
    assert(equal(setIntersection(a, a, a), a));
    assert(equal(setIntersection(a, b), [1, 2, 4, 7]));
    assert(equal(setIntersection(a, b, c), [1, 4, 7]));
    assert(equal(setIntersection(a, b, c, d), [1, 4]));
    assert(equal(setIntersection(a, b, c, d, e), [4]));

    auto inpA = a.filter!(_ => true), inpB = b.filter!(_ => true);
    auto inpC = c.filter!(_ => true), inpD = d.filter!(_ => true);
    assert(equal(setIntersection(inpA, inpB, inpC, inpD), [1, 4]));

    assert(equal(setIntersection(a, b, b, a), [1, 2, 4, 7]));
    assert(equal(setIntersection(a, c, b), [1, 4, 7]));
    assert(equal(setIntersection(b, a, c), [1, 4, 7]));
    assert(equal(setIntersection(b, c, a), [1, 4, 7]));
    assert(equal(setIntersection(c, a, b), [1, 4, 7]));
    assert(equal(setIntersection(c, b, a), [1, 4, 7]));
}

/**
Lazily computes the symmetric difference of $(D r1) and $(D r2),
i.e. the elements that are present in exactly one of $(D r1) and $(D
r2). The two ranges are assumed to be sorted by $(D less), and the
output is also sorted by $(D less). The element types of the two
ranges must have a common type.

If both arguments are ranges of L-values of the same type then
$(D SetSymmetricDifference) will also be a range of L-values of
that type.
 */
struct SetSymmetricDifference(alias less = "a < b", R1, R2)
    if (isInputRange!(R1) && isInputRange!(R2))
{
private:
    R1 r1;
    R2 r2;
    //bool usingR2;
    alias comp = binaryFun!(less);

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

    @property auto ref front()
    {
        assert(!empty);
        bool chooseR1 = r2.empty || !r1.empty && comp(r1.front, r2.front);
        assert(chooseR1 || r1.empty || comp(r2.front, r1.front));
        return chooseR1 ? r1.front : r2.front;
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

///
@safe unittest
{
    import std.algorithm.comparison : equal;

    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    assert(equal(setSymmetricDifference(a, b), [0, 5, 8, 9][]));
    static assert(isForwardRange!(typeof(setSymmetricDifference(a, b))));
}

@safe unittest // Issue 10460
{
    int[] a = [1, 2];
    double[] b = [2.0, 3.0];
    int[] c = [2, 3];

    alias R1 = typeof(setSymmetricDifference(a, b));
    static assert(is(ElementType!R1 == double));
    static assert(!hasLvalueElements!R1);

    alias R2 = typeof(setSymmetricDifference(a, c));
    static assert(is(ElementType!R2 == int));
    static assert(hasLvalueElements!R2);
}

/**
Lazily computes the union of two or more ranges $(D rs). The ranges
are assumed to be sorted by $(D less). Elements in the output are not
unique; the length of the output is the sum of the lengths of the
inputs. (The $(D length) member is offered if all ranges also have
length.) The element types of all ranges must have a common type.
 */
struct SetUnion(alias less = "a < b", Rs...) if (allSatisfy!(isInputRange, Rs))
{
private:
    Rs _r;
    alias comp = binaryFun!(less);
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
    alias ElementType = CommonType!(staticMap!(.ElementType, Rs));

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

        alias opDollar = length;
    }
}

/// Ditto
SetUnion!(less, Rs) setUnion(alias less = "a < b", Rs...)
(Rs rs)
{
    return typeof(return)(rs);
}

///
@safe unittest
{
    import std.algorithm.comparison : equal;

    int[] a = [ 1, 2, 4, 5, 7, 9 ];
    int[] b = [ 0, 1, 2, 4, 7, 8 ];
    int[] c = [ 10 ];

    assert(setUnion(a, b).length == a.length + b.length);
    assert(equal(setUnion(a, b), [0, 1, 1, 2, 2, 4, 4, 5, 7, 7, 8, 9][]));
    assert(equal(setUnion(a, c, b),
                    [0, 1, 1, 2, 2, 4, 4, 5, 7, 7, 8, 9, 10][]));

    static assert(isForwardRange!(typeof(setUnion(a, b))));
}

