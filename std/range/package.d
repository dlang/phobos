// Written in the D programming language.

/**
This module defines the notion of a range. Ranges generalize the concept of
arrays, lists, or anything that involves sequential access. This abstraction
enables the same set of algorithms (see $(LINK2 std_algorithm.html,
std.algorithm)) to be used with a vast variety of different concrete types. For
example, a linear search algorithm such as $(LINK2 std_algorithm.html#find,
std.algorithm.find) works not just for arrays, but for linked-lists, input
files, incoming network data, etc.

For more detailed information about the conceptual aspect of ranges and the
motivation behind them, see Andrei Alexandrescu's article
$(LINK2 http://www.informit.com/articles/printerfriendly.aspx?p=1407357&rll=1,
$(I On Iteration)).

Submodules:

This module has a few submodules:

The $(LINK2 std_range_primitives.html, $(D std._range.primitives)) submodule
provides basic _range functionality. It defines several templates for testing
whether a given object is a _range, what kind of _range it is, and provides
some common _range operations.

The $(LINK2 std_range_interfaces.html, $(D std._range.interfaces)) submodule
provides object-based interfaces for working with ranges via runtime
polymorphism.

The remainder of this module provides a rich set of _range creation and
composition templates that let you construct new ranges out of existing ranges:

$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF retro)))
        $(TD Iterates a bidirectional _range backwards.
    ))
    $(TR $(TD $(D $(LREF stride)))
        $(TD Iterates a _range with stride $(I n).
    ))
    $(TR $(TD $(D $(LREF chain)))
        $(TD Concatenates several ranges into a single _range.
    ))
    $(TR $(TD $(D $(LREF roundRobin)))
        $(TD Given $(I n) ranges, creates a new _range that return the $(I n)
        first elements of each _range, in turn, then the second element of each
        _range, and so on, in a round-robin fashion.
    ))
    $(TR $(TD $(D $(LREF radial)))
        $(TD Given a random-access _range and a starting point, creates a
        _range that alternately returns the next left and next right element to
        the starting point.
    ))
    $(TR $(TD $(D $(LREF take)))
        $(TD Creates a sub-_range consisting of only up to the first $(I n)
        elements of the given _range.
    ))
    $(TR $(TD $(D $(LREF takeExactly)))
        $(TD Like $(D take), but assumes the given _range actually has $(I n)
        elements, and therefore also defines the $(D length) property.
    ))
    $(TR $(TD $(D $(LREF takeOne)))
        $(TD Creates a random-access _range consisting of exactly the first
        element of the given _range.
    ))
    $(TR $(TD $(D $(LREF takeNone)))
        $(TD Creates a random-access _range consisting of zero elements of the
        given _range.
    ))
    $(TR $(TD $(D $(LREF drop)))
        $(TD Creates the _range that results from discarding the first $(I n)
        elements from the given _range.
    ))
    $(TR $(TD $(D $(LREF dropExactly)))
        $(TD Creates the _range that results from discarding exactly $(I n)
        of the first elements from the given _range.
    ))
    $(TR $(TD $(D $(LREF dropOne)))
        $(TD Creates the _range that results from discarding
        the first elements from the given _range.
    ))
    $(TR $(TD $(D $(LREF repeat)))
        $(TD Creates a _range that consists of a single element repeated $(I n)
        times, or an infinite _range repeating that element indefinitely.
    ))
    $(TR $(TD $(D $(LREF cycle)))
        $(TD Creates an infinite _range that repeats the given forward _range
        indefinitely. Good for implementing circular buffers.
    ))
    $(TR $(TD $(D $(LREF zip)))
        $(TD Given $(I n) _ranges, creates a _range that successively returns a
        tuple of all the first elements, a tuple of all the second elements,
        etc.
    ))
    $(TR $(TD $(D $(LREF lockstep)))
        $(TD Iterates $(I n) _ranges in lockstep, for use in a $(D foreach)
        loop. Similar to $(D zip), except that $(D lockstep) is designed
        especially for $(D foreach) loops.
    ))
    $(TR $(TD $(D $(LREF recurrence)))
        $(TD Creates a forward _range whose values are defined by a
        mathematical recurrence relation.
    ))
    $(TR $(TD $(D $(LREF sequence)))
        $(TD Similar to $(D recurrence), except that a random-access _range is
        created.
    ))
    $(TR $(TD $(D $(LREF iota)))
        $(TD Creates a _range consisting of numbers between a starting point
        and ending point, spaced apart by a given interval.
    ))
    $(TR $(TD $(D $(LREF frontTransversal)))
        $(TD Creates a _range that iterates over the first elements of the
        given ranges.
    ))
    $(TR $(TD $(D $(LREF transversal)))
        $(TD Creates a _range that iterates over the $(I n)'th elements of the
        given random-access ranges.
    ))
    $(TR $(TD $(D $(LREF transposed)))
        $(TD Transposes a _range of ranges.
    ))
    $(TR $(TD $(D $(LREF indexed)))
        $(TD Creates a _range that offers a view of a given _range as though
        its elements were reordered according to a given _range of indices.
    ))
    $(TR $(TD $(D $(LREF chunks)))
        $(TD Creates a _range that returns fixed-size chunks of the original
        _range.
    ))
    $(TR $(TD $(D $(LREF only)))
        $(TD Creates a _range that iterates over the given arguments.
    ))
    $(TR $(TD $(D $(LREF tee)))
        $(TD Creates a _range that wraps a given _range, forwarding along
        its elements while also calling a provided function with each element.
    ))
    $(TR $(TD $(D $(LREF enumerate)))
        $(TD Iterates a _range with an attached index variable.
    ))
    $(TR $(TD $(D $(LREF NullSink)))
        $(TD An output _range that discards the data it receives.
    ))
)

Ranges whose elements are sorted afford better efficiency with certain
operations. For this, the $(D $(LREF assumeSorted)) function can be used to
construct a $(D $(LREF SortedRange)) from a pre-sorted _range. The $(LINK2
std_algorithm.html#sort, $(D std.algorithm.sort)) function also conveniently
returns a $(D SortedRange). $(D SortedRange) objects provide some additional
_range operations that take advantage of the fact that the _range is sorted.

Source: $(PHOBOSSRC std/_range/_package.d)

Macros:

WIKI = Phobos/StdRange

Copyright: Copyright by authors 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu), David Simcha,
and Jonathan M Davis. Credit for some of the ideas in building this module goes
to $(WEB fantascienza.net/leonardo/so/, Leonardo Maffi).
 */
module std.range;

public import std.range.primitives;
public import std.range.interfaces;
public import std.array;
public import std.typecons : Flag, Yes, No;

import std.traits;
import std.typetuple;


/**
Iterates a bidirectional range backwards. The original range can be
accessed by using the $(D source) property. Applying retro twice to
the same range yields the original range.
 */
auto retro(Range)(Range r)
if (isBidirectionalRange!(Unqual!Range))
{
    // Check for retro(retro(r)) and just return r in that case
    static if (is(typeof(retro(r.source)) == Range))
    {
        return r.source;
    }
    else
    {
        static struct Result()
        {
            private alias R = Unqual!Range;

            // User code can get and set source, too
            R source;

            static if (hasLength!R)
            {
                private alias IndexType = CommonType!(size_t, typeof(source.length));

                IndexType retroIndex(IndexType n)
                {
                    return source.length - n - 1;
                }
            }

        public:
            alias Source = R;

            @property bool empty() { return source.empty; }
            @property auto save()
            {
                return Result(source.save);
            }
            @property auto ref front() { return source.back; }
            void popFront() { source.popBack(); }
            @property auto ref back() { return source.front; }
            void popBack() { source.popFront(); }

            static if(is(typeof(.moveBack(source))))
            {
                ElementType!R moveFront()
                {
                    return .moveBack(source);
                }
            }

            static if(is(typeof(.moveFront(source))))
            {
                ElementType!R moveBack()
                {
                    return .moveFront(source);
                }
            }

            static if (hasAssignableElements!R)
            {
                @property auto front(ElementType!R val)
                {
                    source.back = val;
                }

                @property auto back(ElementType!R val)
                {
                    source.front = val;
                }
            }

            static if (isRandomAccessRange!(R) && hasLength!(R))
            {
                auto ref opIndex(IndexType n) { return source[retroIndex(n)]; }

                static if (hasAssignableElements!R)
                {
                    void opIndexAssign(ElementType!R val, IndexType n)
                    {
                        source[retroIndex(n)] = val;
                    }
                }

                static if (is(typeof(.moveAt(source, 0))))
                {
                    ElementType!R moveAt(IndexType index)
                    {
                        return .moveAt(source, retroIndex(index));
                    }
                }

                static if (hasSlicing!R)
                    typeof(this) opSlice(IndexType a, IndexType b)
                    {
                        return typeof(this)(source[source.length - b .. source.length - a]);
                    }
            }

            static if (hasLength!R)
            {
                @property auto length()
                {
                    return source.length;
                }

                alias opDollar = length;
            }
        }

        return Result!()(r);
    }
}


///
@safe unittest
{
    import std.algorithm : equal;
    int[] a = [ 1, 2, 3, 4, 5 ];
    assert(equal(retro(a), [ 5, 4, 3, 2, 1 ][]));
    assert(retro(a).source is a);
    assert(retro(retro(a)) is a);
}

@safe unittest
{
    import std.algorithm : equal;
    static assert(isBidirectionalRange!(typeof(retro("hello"))));
    int[] a;
    static assert(is(typeof(a) == typeof(retro(retro(a)))));
    assert(retro(retro(a)) is a);
    static assert(isRandomAccessRange!(typeof(retro([1, 2, 3]))));
    void test(int[] input, int[] witness)
    {
        auto r = retro(input);
        assert(r.front == witness.front);
        assert(r.back == witness.back);
        assert(equal(r, witness));
    }
    test([ 1 ], [ 1 ]);
    test([ 1, 2 ], [ 2, 1 ]);
    test([ 1, 2, 3 ], [ 3, 2, 1 ]);
    test([ 1, 2, 3, 4 ], [ 4, 3, 2, 1 ]);
    test([ 1, 2, 3, 4, 5 ], [ 5, 4, 3, 2, 1 ]);
    test([ 1, 2, 3, 4, 5, 6 ], [ 6, 5, 4, 3, 2, 1 ]);

   immutable foo = [1,2,3].idup;
   auto r = retro(foo);
}

@safe unittest
{
    import std.internal.test.dummyrange;

    foreach(DummyType; AllDummyRanges) {
        static if (!isBidirectionalRange!DummyType) {
            static assert(!__traits(compiles, Retro!DummyType));
        } else {
            DummyType dummyRange;
            dummyRange.reinit();

            auto myRetro = retro(dummyRange);
            static assert(propagatesRangeType!(typeof(myRetro), DummyType));
            assert(myRetro.front == 10);
            assert(myRetro.back == 1);
            assert(myRetro.moveFront() == 10);
            assert(myRetro.moveBack() == 1);

            static if (isRandomAccessRange!DummyType && hasLength!DummyType) {
                assert(myRetro[0] == myRetro.front);
                assert(myRetro.moveAt(2) == 8);

                static if (DummyType.r == ReturnBy.Reference) {
                    {
                        myRetro[9]++;
                        scope(exit) myRetro[9]--;
                        assert(dummyRange[0] == 2);
                        myRetro.front++;
                        scope(exit) myRetro.front--;
                        assert(myRetro.front == 11);
                        myRetro.back++;
                        scope(exit) myRetro.back--;
                        assert(myRetro.back == 3);
                    }

                    {
                        myRetro.front = 0xFF;
                        scope(exit) myRetro.front = 10;
                        assert(dummyRange.back == 0xFF);

                        myRetro.back = 0xBB;
                        scope(exit) myRetro.back = 1;
                        assert(dummyRange.front == 0xBB);

                        myRetro[1] = 11;
                        scope(exit) myRetro[1] = 8;
                        assert(dummyRange[8] == 11);
                    }
                }
            }
        }
    }
}

@safe unittest
{
    import std.algorithm : equal;
    auto LL = iota(1L, 4L);
    auto r = retro(LL);
    assert(equal(r, [3L, 2L, 1L]));
}

// Issue 12662
@safe @nogc unittest
{
    int[3] src = [1,2,3];
    int[] data = src[];
    foreach_reverse (x; data) {}
    foreach (x; data.retro) {}
}


/**
Iterates range $(D r) with stride $(D n). If the range is a
random-access range, moves by indexing into the range; otherwise,
moves by successive calls to $(D popFront). Applying stride twice to
the same range results in a stride with a step that is the
product of the two applications.

Throws: $(D Exception) if $(D n == 0).
 */
auto stride(Range)(Range r, size_t n)
if (isInputRange!(Unqual!Range))
{
    import std.exception : enforce;
    import std.algorithm : min;

    enforce(n > 0, "Stride cannot have step zero.");

    static if (is(typeof(stride(r.source, n)) == Range))
    {
        // stride(stride(r, n1), n2) is stride(r, n1 * n2)
        return stride(r.source, r._n * n);
    }
    else
    {
        static struct Result
        {
            private alias R = Unqual!Range;
            public R source;
            private size_t _n;

            // Chop off the slack elements at the end
            static if (hasLength!R &&
                    (isRandomAccessRange!R && hasSlicing!R
                            || isBidirectionalRange!R))
                private void eliminateSlackElements()
                {
                    auto slack = source.length % _n;

                    if (slack)
                    {
                        slack--;
                    }
                    else if (!source.empty)
                    {
                        slack = min(_n, source.length) - 1;
                    }
                    else
                    {
                        slack = 0;
                    }
                    if (!slack) return;
                    static if (isRandomAccessRange!R && hasSlicing!R)
                    {
                        source = source[0 .. source.length - slack];
                    }
                    else static if (isBidirectionalRange!R)
                    {
                        foreach (i; 0 .. slack)
                        {
                            source.popBack();
                        }
                    }
                }

            static if (isForwardRange!R)
            {
                @property auto save()
                {
                    return Result(source.save, _n);
                }
            }

            static if (isInfinite!R)
            {
                enum bool empty = false;
            }
            else
            {
                @property bool empty()
                {
                    return source.empty;
                }
            }

            @property auto ref front()
            {
                return source.front;
            }

            static if (is(typeof(.moveFront(source))))
            {
                ElementType!R moveFront()
                {
                    return .moveFront(source);
                }
            }

            static if (hasAssignableElements!R)
            {
                @property auto front(ElementType!R val)
                {
                    source.front = val;
                }
            }

            void popFront()
            {
                static if (isRandomAccessRange!R && hasLength!R && hasSlicing!R)
                {
                    source = source[min(_n, source.length) .. source.length];
                }
                else
                {
                    static if (hasLength!R)
                    {
                        foreach (i; 0 .. min(source.length, _n))
                        {
                            source.popFront();
                        }
                    }
                    else
                    {
                        foreach (i; 0 .. _n)
                        {
                            source.popFront();
                            if (source.empty) break;
                        }
                    }
                }
            }

            static if (isBidirectionalRange!R && hasLength!R)
            {
                void popBack()
                {
                    popBackN(source, _n);
                }

                @property auto ref back()
                {
                    eliminateSlackElements();
                    return source.back;
                }

                static if (is(typeof(.moveBack(source))))
                {
                    ElementType!R moveBack()
                    {
                        eliminateSlackElements();
                        return .moveBack(source);
                    }
                }

                static if (hasAssignableElements!R)
                {
                    @property auto back(ElementType!R val)
                    {
                        eliminateSlackElements();
                        source.back = val;
                    }
                }
            }

            static if (isRandomAccessRange!R && hasLength!R)
            {
                auto ref opIndex(size_t n)
                {
                    return source[_n * n];
                }

                /**
                   Forwards to $(D moveAt(source, n)).
                */
                static if (is(typeof(.moveAt(source, 0))))
                {
                    ElementType!R moveAt(size_t n)
                    {
                        return .moveAt(source, _n * n);
                    }
                }

                static if (hasAssignableElements!R)
                {
                    void opIndexAssign(ElementType!R val, size_t n)
                    {
                        source[_n * n] = val;
                    }
                }
            }

            static if (hasSlicing!R && hasLength!R)
                typeof(this) opSlice(size_t lower, size_t upper)
                {
                    assert(upper >= lower && upper <= length);
                    immutable translatedUpper = (upper == 0) ? 0 :
                        (upper * _n - (_n - 1));
                    immutable translatedLower = min(lower * _n, translatedUpper);

                    assert(translatedLower <= translatedUpper);

                    return typeof(this)(source[translatedLower..translatedUpper], _n);
                }

            static if (hasLength!R)
            {
                @property auto length()
                {
                    return (source.length + _n - 1) / _n;
                }

                alias opDollar = length;
            }
        }
        return Result(r, n);
    }
}

///
unittest
{
    import std.algorithm : equal;

    int[] a = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 ];
    assert(equal(stride(a, 3), [ 1, 4, 7, 10 ][]));
    assert(stride(stride(a, 2), 3) == stride(a, 6));
}

@safe unittest
{
    import std.internal.test.dummyrange;
    import std.algorithm : equal;

    static assert(isRandomAccessRange!(typeof(stride([1, 2, 3], 2))));
    void test(size_t n, int[] input, int[] witness)
    {
        assert(equal(stride(input, n), witness));
    }
    test(1, [], []);
    int[] arr = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    assert(stride(stride(arr, 2), 3) is stride(arr, 6));
    test(1, arr, arr);
    test(2, arr, [1, 3, 5, 7, 9]);
    test(3, arr, [1, 4, 7, 10]);
    test(4, arr, [1, 5, 9]);

    // Test slicing.
    auto s1 = stride(arr, 1);
    assert(equal(s1[1..4], [2, 3, 4]));
    assert(s1[1..4].length == 3);
    assert(equal(s1[1..5], [2, 3, 4, 5]));
    assert(s1[1..5].length == 4);
    assert(s1[0..0].empty);
    assert(s1[3..3].empty);
    // assert(s1[$ .. $].empty);
    assert(s1[s1.opDollar .. s1.opDollar].empty);

    auto s2 = stride(arr, 2);
    assert(equal(s2[0..2], [1,3]));
    assert(s2[0..2].length == 2);
    assert(equal(s2[1..5], [3, 5, 7, 9]));
    assert(s2[1..5].length == 4);
    assert(s2[0..0].empty);
    assert(s2[3..3].empty);
    // assert(s2[$ .. $].empty);
    assert(s2[s2.opDollar .. s2.opDollar].empty);

    // Test fix for Bug 5035
    auto m = [1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4]; // 3 rows, 4 columns
    auto col = stride(m, 4);
    assert(equal(col, [1, 1, 1]));
    assert(equal(retro(col), [1, 1, 1]));

    immutable int[] immi = [ 1, 2, 3 ];
    static assert(isRandomAccessRange!(typeof(stride(immi, 1))));

    // Check for infiniteness propagation.
    static assert(isInfinite!(typeof(stride(repeat(1), 3))));

    foreach(DummyType; AllDummyRanges) {
        DummyType dummyRange;
        dummyRange.reinit();

        auto myStride = stride(dummyRange, 4);

        // Should fail if no length and bidirectional b/c there's no way
        // to know how much slack we have.
        static if (hasLength!DummyType || !isBidirectionalRange!DummyType) {
            static assert(propagatesRangeType!(typeof(myStride), DummyType));
        }
        assert(myStride.front == 1);
        assert(myStride.moveFront() == 1);
        assert(equal(myStride, [1, 5, 9]));

        static if (hasLength!DummyType) {
            assert(myStride.length == 3);
        }

        static if (isBidirectionalRange!DummyType && hasLength!DummyType) {
            assert(myStride.back == 9);
            assert(myStride.moveBack() == 9);
        }

        static if (isRandomAccessRange!DummyType && hasLength!DummyType) {
            assert(myStride[0] == 1);
            assert(myStride[1] == 5);
            assert(myStride.moveAt(1) == 5);
            assert(myStride[2] == 9);

            static assert(hasSlicing!(typeof(myStride)));
        }

        static if (DummyType.r == ReturnBy.Reference) {
            // Make sure reference is propagated.

            {
                myStride.front++;
                scope(exit) myStride.front--;
                assert(dummyRange.front == 2);
            }
            {
                myStride.front = 4;
                scope(exit) myStride.front = 1;
                assert(dummyRange.front == 4);
            }

            static if (isBidirectionalRange!DummyType && hasLength!DummyType) {
                {
                    myStride.back++;
                    scope(exit) myStride.back--;
                    assert(myStride.back == 10);
                }
                {
                    myStride.back = 111;
                    scope(exit) myStride.back = 9;
                    assert(myStride.back == 111);
                }

                static if (isRandomAccessRange!DummyType) {
                    {
                        myStride[1]++;
                        scope(exit) myStride[1]--;
                        assert(dummyRange[4] == 6);
                    }
                    {
                        myStride[1] = 55;
                        scope(exit) myStride[1] = 5;
                        assert(dummyRange[4] == 55);
                    }
                }
            }
        }
    }
}

@safe unittest
{
    import std.algorithm : equal;

    auto LL = iota(1L, 10L);
    auto s = stride(LL, 3);
    assert(equal(s, [1L, 4L, 7L]));
}

/**
Spans multiple ranges in sequence. The function $(D chain) takes any
number of ranges and returns a $(D Chain!(R1, R2,...)) object. The
ranges may be different, but they must have the same element type. The
result is a range that offers the $(D front), $(D popFront), and $(D
empty) primitives. If all input ranges offer random access and $(D
length), $(D Chain) offers them as well.

If only one range is offered to $(D Chain) or $(D chain), the $(D
Chain) type exits the picture by aliasing itself directly to that
range's type.
 */
auto chain(Ranges...)(Ranges rs)
if (Ranges.length > 0 &&
    allSatisfy!(isInputRange, staticMap!(Unqual, Ranges)) &&
    !is(CommonType!(staticMap!(ElementType, staticMap!(Unqual, Ranges))) == void))
{
    static if (Ranges.length == 1)
    {
        return rs[0];
    }
    else
    {
        static struct Result
        {
        private:
            alias R = staticMap!(Unqual, Ranges);
            alias RvalueElementType = CommonType!(staticMap!(.ElementType, R));
            private template sameET(A)
            {
                enum sameET = is(.ElementType!A == RvalueElementType);
            }

            enum bool allSameType = allSatisfy!(sameET, R);

// This doesn't work yet
            static if (allSameType)
            {
                alias ref RvalueElementType ElementType;
            }
            else
            {
                alias ElementType = RvalueElementType;
            }
            static if (allSameType && allSatisfy!(hasLvalueElements, R))
            {
                static ref RvalueElementType fixRef(ref RvalueElementType val)
                {
                    return val;
                }
            }
            else
            {
                static RvalueElementType fixRef(RvalueElementType val)
                {
                    return val;
                }
            }

// This is the entire state
            R source;
// TODO: use a vtable (or more) instead of linear iteration

        public:
            this(R input)
            {
                foreach (i, v; input)
                {
                    source[i] = v;
                }
            }

            import std.typetuple : anySatisfy;

            static if (anySatisfy!(isInfinite, R))
            {
// Propagate infiniteness.
                enum bool empty = false;
            }
            else
            {
                @property bool empty()
                {
                    foreach (i, Unused; R)
                    {
                        if (!source[i].empty) return false;
                    }
                    return true;
                }
            }

            static if (allSatisfy!(isForwardRange, R))
                @property auto save()
                {
                    typeof(this) result = this;
                    foreach (i, Unused; R)
                    {
                        result.source[i] = result.source[i].save;
                    }
                    return result;
                }

            void popFront()
            {
                foreach (i, Unused; R)
                {
                    if (source[i].empty) continue;
                    source[i].popFront();
                    return;
                }
            }

            @property auto ref front()
            {
                foreach (i, Unused; R)
                {
                    if (source[i].empty) continue;
                    return fixRef(source[i].front);
                }
                assert(false);
            }

            static if (allSameType && allSatisfy!(hasAssignableElements, R))
            {
                // @@@BUG@@@
                //@property void front(T)(T v) if (is(T : RvalueElementType))

                // Return type must be auto due to Bug 4706.
                @property auto front(RvalueElementType v)
                {
                    foreach (i, Unused; R)
                    {
                        if (source[i].empty) continue;
                        source[i].front = v;
                        return;
                    }
                    assert(false);
                }
            }

            static if (allSatisfy!(hasMobileElements, R))
            {
                RvalueElementType moveFront()
                {
                    foreach (i, Unused; R)
                    {
                        if (source[i].empty) continue;
                        return .moveFront(source[i]);
                    }
                    assert(false);
                }
            }

            static if (allSatisfy!(isBidirectionalRange, R))
            {
                @property auto ref back()
                {
                    foreach_reverse (i, Unused; R)
                    {
                        if (source[i].empty) continue;
                        return fixRef(source[i].back);
                    }
                    assert(false);
                }

                void popBack()
                {
                    foreach_reverse (i, Unused; R)
                    {
                        if (source[i].empty) continue;
                        source[i].popBack();
                        return;
                    }
                }

                static if (allSatisfy!(hasMobileElements, R))
                {
                    RvalueElementType moveBack()
                    {
                        foreach_reverse (i, Unused; R)
                        {
                            if (source[i].empty) continue;
                            return .moveBack(source[i]);
                        }
                        assert(false);
                    }
                }

                static if (allSameType && allSatisfy!(hasAssignableElements, R))
                {
                    // Return type must be auto due to extremely strange bug in DMD's
                    // function overloading.
                    @property auto back(RvalueElementType v)
                    {
                        foreach_reverse (i, Unused; R)
                        {
                            if (source[i].empty) continue;
                            source[i].back = v;
                            return;
                        }
                        assert(false);
                    }
                }
            }

            static if (allSatisfy!(hasLength, R))
            {
                @property size_t length()
                {
                    size_t result;
                    foreach (i, Unused; R)
                    {
                        result += source[i].length;
                    }
                    return result;
                }

                alias opDollar = length;
            }

            static if (allSatisfy!(isRandomAccessRange, R))
            {
                auto ref opIndex(size_t index)
                {
                    foreach (i, Range; R)
                    {
                        static if (isInfinite!(Range))
                        {
                            return source[i][index];
                        }
                        else
                        {
                            immutable length = source[i].length;
                            if (index < length) return fixRef(source[i][index]);
                            index -= length;
                        }
                    }
                    assert(false);
                }

                static if (allSatisfy!(hasMobileElements, R))
                {
                    RvalueElementType moveAt(size_t index)
                    {
                        foreach (i, Range; R)
                        {
                            static if (isInfinite!(Range))
                            {
                                return .moveAt(source[i], index);
                            }
                            else
                            {
                                immutable length = source[i].length;
                                if (index < length) return .moveAt(source[i], index);
                                index -= length;
                            }
                        }
                        assert(false);
                    }
                }

                static if (allSameType && allSatisfy!(hasAssignableElements, R))
                    void opIndexAssign(ElementType v, size_t index)
                    {
                        foreach (i, Range; R)
                        {
                            static if (isInfinite!(Range))
                            {
                                source[i][index] = v;
                            }
                            else
                            {
                                immutable length = source[i].length;
                                if (index < length)
                                {
                                    source[i][index] = v;
                                    return;
                                }
                                index -= length;
                            }
                        }
                        assert(false);
                    }
            }

            static if (allSatisfy!(hasLength, R) && allSatisfy!(hasSlicing, R))
                auto opSlice(size_t begin, size_t end)
                {
                    auto result = this;
                    foreach (i, Unused; R)
                    {
                        immutable len = result.source[i].length;
                        if (len < begin)
                        {
                            result.source[i] = result.source[i]
                                [len .. len];
                            begin -= len;
                        }
                        else
                        {
                            result.source[i] = result.source[i]
                                [begin .. len];
                            break;
                        }
                    }
                    auto cut = length;
                    cut = cut <= end ? 0 : cut - end;
                    foreach_reverse (i, Unused; R)
                    {
                        immutable len = result.source[i].length;
                        if (cut > len)
                        {
                            result.source[i] = result.source[i]
                                [0 .. 0];
                            cut -= len;
                        }
                        else
                        {
                            result.source[i] = result.source[i]
                                [0 .. len - cut];
                            break;
                        }
                    }
                    return result;
                }
        }
        return Result(rs);
    }
}

///
unittest
{
    import std.algorithm : equal;

    int[] arr1 = [ 1, 2, 3, 4 ];
    int[] arr2 = [ 5, 6 ];
    int[] arr3 = [ 7 ];
    auto s = chain(arr1, arr2, arr3);
    assert(s.length == 7);
    assert(s[5] == 6);
    assert(equal(s, [1, 2, 3, 4, 5, 6, 7][]));
}

@safe unittest
{
    import std.internal.test.dummyrange;
    import std.algorithm : equal;

    {
        int[] arr1 = [ 1, 2, 3, 4 ];
        int[] arr2 = [ 5, 6 ];
        int[] arr3 = [ 7 ];
        int[] witness = [ 1, 2, 3, 4, 5, 6, 7 ];
        auto s1 = chain(arr1);
        static assert(isRandomAccessRange!(typeof(s1)));
        auto s2 = chain(arr1, arr2);
        static assert(isBidirectionalRange!(typeof(s2)));
        static assert(isRandomAccessRange!(typeof(s2)));
        s2.front = 1;
        auto s = chain(arr1, arr2, arr3);
        assert(s[5] == 6);
        assert(equal(s, witness));
        assert(s[5] == 6);
    }
    {
        int[] arr1 = [ 1, 2, 3, 4 ];
        int[] witness = [ 1, 2, 3, 4 ];
        assert(equal(chain(arr1), witness));
    }
    {
        uint[] foo = [1,2,3,4,5];
        uint[] bar = [1,2,3,4,5];
        auto c = chain(foo, bar);
        c[3] = 42;
        assert(c[3] == 42);
        assert(c.moveFront() == 1);
        assert(c.moveBack() == 5);
        assert(c.moveAt(4) == 5);
        assert(c.moveAt(5) == 1);
    }

    // Make sure bug 3311 is fixed.  ChainImpl should compile even if not all
    // elements are mutable.
    auto c = chain( iota(0, 10), iota(0, 10) );

    // Test the case where infinite ranges are present.
    auto inf = chain([0,1,2][], cycle([4,5,6][]), [7,8,9][]); // infinite range
    assert(inf[0] == 0);
    assert(inf[3] == 4);
    assert(inf[6] == 4);
    assert(inf[7] == 5);
    static assert(isInfinite!(typeof(inf)));

    immutable int[] immi = [ 1, 2, 3 ];
    immutable float[] immf = [ 1, 2, 3 ];
    static assert(is(typeof(chain(immi, immf))));

    // Check that chain at least instantiates and compiles with every possible
    // pair of DummyRange types, in either order.

    foreach(DummyType1; AllDummyRanges) {
        DummyType1 dummy1;
        foreach(DummyType2; AllDummyRanges) {
            DummyType2 dummy2;
            auto myChain = chain(dummy1, dummy2);

            static assert(
                propagatesRangeType!(typeof(myChain), DummyType1, DummyType2)
            );

            assert(myChain.front == 1);
            foreach(i; 0..dummyLength) {
                myChain.popFront();
            }
            assert(myChain.front == 1);

            static if (isBidirectionalRange!DummyType1 &&
                      isBidirectionalRange!DummyType2) {
                assert(myChain.back == 10);
            }

            static if (isRandomAccessRange!DummyType1 &&
                      isRandomAccessRange!DummyType2) {
                assert(myChain[0] == 1);
            }

            static if (hasLvalueElements!DummyType1 && hasLvalueElements!DummyType2)
            {
                static assert(hasLvalueElements!(typeof(myChain)));
            }
            else
            {
                static assert(!hasLvalueElements!(typeof(myChain)));
            }
        }
    }
}

@safe unittest
{
    class Foo{}
    immutable(Foo)[] a;
    immutable(Foo)[] b;
    auto c = chain(a, b);
}

/**
$(D roundRobin(r1, r2, r3)) yields $(D r1.front), then $(D r2.front),
then $(D r3.front), after which it pops off one element from each and
continues again from $(D r1). For example, if two ranges are involved,
it alternately yields elements off the two ranges. $(D roundRobin)
stops after it has consumed all ranges (skipping over the ones that
finish early).
 */
auto roundRobin(Rs...)(Rs rs)
if (Rs.length > 1 && allSatisfy!(isInputRange, staticMap!(Unqual, Rs)))
{
    struct Result
    {
        import std.conv : to;

        public Rs source;
        private size_t _current = size_t.max;

        @property bool empty()
        {
            foreach (i, Unused; Rs)
            {
                if (!source[i].empty) return false;
            }
            return true;
        }

        @property auto ref front()
        {
            final switch (_current)
            {
                foreach (i, R; Rs)
                {
                    case i:
                        assert(!source[i].empty);
                        return source[i].front;
                }
            }
            assert(0);
        }

        void popFront()
        {
            final switch (_current)
            {
                foreach (i, R; Rs)
                {
                    case i:
                        source[i].popFront();
                        break;
                }
            }

            auto next = _current == (Rs.length - 1) ? 0 : (_current + 1);
            final switch (next)
            {
                foreach (i, R; Rs)
                {
                    case i:
                        if (!source[i].empty)
                        {
                            _current = i;
                            return;
                        }
                        if (i == _current)
                        {
                            _current = _current.max;
                            return;
                        }
                        goto case (i + 1) % Rs.length;
                }
            }
        }

        static if (allSatisfy!(isForwardRange, staticMap!(Unqual, Rs)))
            @property auto save()
            {
                Result result = this;
                foreach (i, Unused; Rs)
                {
                    result.source[i] = result.source[i].save;
                }
                return result;
            }

        static if (allSatisfy!(hasLength, Rs))
        {
            @property size_t length()
            {
                size_t result;
                foreach (i, R; Rs)
                {
                    result += source[i].length;
                }
                return result;
            }

            alias opDollar = length;
        }
    }

    return Result(rs, 0);
}

///
@safe unittest
{
    import std.algorithm : equal;

    int[] a = [ 1, 2, 3 ];
    int[] b = [ 10, 20, 30, 40 ];
    auto r = roundRobin(a, b);
    assert(equal(r, [ 1, 10, 2, 20, 3, 30, 40 ]));
}

/**
Iterates a random-access range starting from a given point and
progressively extending left and right from that point. If no initial
point is given, iteration starts from the middle of the
range. Iteration spans the entire range.
 */
auto radial(Range, I)(Range r, I startingIndex)
if (isRandomAccessRange!(Unqual!Range) && hasLength!(Unqual!Range) && isIntegral!I)
{
    if (!r.empty) ++startingIndex;
    return roundRobin(retro(r[0 .. startingIndex]), r[startingIndex .. r.length]);
}

/// Ditto
auto radial(R)(R r)
if (isRandomAccessRange!(Unqual!R) && hasLength!(Unqual!R))
{
    return .radial(r, (r.length - !r.empty) / 2);
}

///
@safe unittest
{
    import std.algorithm : equal;
    int[] a = [ 1, 2, 3, 4, 5 ];
    assert(equal(radial(a), [ 3, 4, 2, 5, 1 ]));
    a = [ 1, 2, 3, 4 ];
    assert(equal(radial(a), [ 2, 3, 1, 4 ]));
}

@safe unittest
{
    import std.conv : text;
    import std.exception : enforce;
    import std.algorithm : equal;
    import std.internal.test.dummyrange;

    void test(int[] input, int[] witness)
    {
        enforce(equal(radial(input), witness),
                text(radial(input), " vs. ", witness));
    }
    test([], []);
    test([ 1 ], [ 1 ]);
    test([ 1, 2 ], [ 1, 2 ]);
    test([ 1, 2, 3 ], [ 2, 3, 1 ]);
    test([ 1, 2, 3, 4 ], [ 2, 3, 1, 4 ]);
    test([ 1, 2, 3, 4, 5 ], [ 3, 4, 2, 5, 1 ]);
    test([ 1, 2, 3, 4, 5, 6 ], [ 3, 4, 2, 5, 1, 6 ]);

    int[] a = [ 1, 2, 3, 4, 5 ];
    assert(equal(radial(a, 1), [ 2, 3, 1, 4, 5 ][]));
    static assert(isForwardRange!(typeof(radial(a, 1))));

    auto r = radial([1,2,3,4,5]);
    for(auto rr = r.save; !rr.empty; rr.popFront())
    {
        assert(rr.front == moveFront(rr));
    }
    r.front = 5;
    assert(r.front == 5);

    // Test instantiation without lvalue elements.
    DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Random) dummy;
    assert(equal(radial(dummy, 4), [5, 6, 4, 7, 3, 8, 2, 9, 1, 10]));

    // immutable int[] immi = [ 1, 2 ];
    // static assert(is(typeof(radial(immi))));
}

@safe unittest
{
    import std.algorithm : equal;

    auto LL = iota(1L, 6L);
    auto r = radial(LL);
    assert(equal(r, [3L, 4L, 2L, 5L, 1L]));
}

/**
Lazily takes only up to $(D n) elements of a range. This is
particularly useful when using with infinite ranges. If the range
offers random access and $(D length), $(D Take) offers them as well.
 */
struct Take(Range)
if (isInputRange!(Unqual!Range) &&
    //take _cannot_ test hasSlicing on infinite ranges, because hasSlicing uses
    //take for slicing infinite ranges.
    !((!isInfinite!(Unqual!Range) && hasSlicing!(Unqual!Range)) || is(Range T == Take!T)))
{
    private alias R = Unqual!Range;

    // User accessible in read and write
    public R source;

    private size_t _maxAvailable;

    alias Source = R;

    @property bool empty()
    {
        return _maxAvailable == 0 || source.empty;
    }

    @property auto ref front()
    {
        assert(!empty,
            "Attempting to fetch the front of an empty "
            ~ Take.stringof);
        return source.front;
    }

    void popFront()
    {
        assert(!empty,
            "Attempting to popFront() past the end of a "
            ~ Take.stringof);
        source.popFront();
        --_maxAvailable;
    }

    static if (isForwardRange!R)
        @property Take save()
        {
            return Take(source.save, _maxAvailable);
        }

    static if (hasAssignableElements!R)
        @property auto front(ElementType!R v)
        {
            assert(!empty,
                "Attempting to assign to the front of an empty "
                ~ Take.stringof);
            // This has to return auto instead of void because of Bug 4706.
            source.front = v;
        }

    static if (hasMobileElements!R)
    {
        auto moveFront()
        {
            assert(!empty,
                "Attempting to move the front of an empty "
                ~ Take.stringof);
            return .moveFront(source);
        }
    }

    static if (isInfinite!R)
    {
        @property size_t length() const
        {
            return _maxAvailable;
        }

        alias opDollar = length;

        //Note: Due to Take/hasSlicing circular dependency,
        //This needs to be a restrained template.
        auto opSlice()(size_t i, size_t j)
        if (hasSlicing!R)
        {
            assert(i <= j, "Invalid slice bounds");
            assert(j - i <= length, "Attempting to slice past the end of a "
                ~ Take.stringof);
            return source[i .. j - i];
        }
    }
    else static if (hasLength!R)
    {
        @property size_t length()
        {
            import std.algorithm : min;
            return min(_maxAvailable, source.length);
        }

        alias opDollar = length;
    }

    static if (isRandomAccessRange!R)
    {
        void popBack()
        {
            assert(!empty,
                "Attempting to popBack() past the beginning of a "
                ~ Take.stringof);
            --_maxAvailable;
        }

        @property auto ref back()
        {
            assert(!empty,
                "Attempting to fetch the back of an empty "
                ~ Take.stringof);
            return source[this.length - 1];
        }

        auto ref opIndex(size_t index)
        {
            assert(index < length,
                "Attempting to index out of the bounds of a "
                ~ Take.stringof);
            return source[index];
        }

        static if (hasAssignableElements!R)
        {
            @property auto back(ElementType!R v)
            {
                // This has to return auto instead of void because of Bug 4706.
                assert(!empty,
                    "Attempting to assign to the back of an empty "
                    ~ Take.stringof);
                source[this.length - 1] = v;
            }

            void opIndexAssign(ElementType!R v, size_t index)
            {
                assert(index < length,
                    "Attempting to index out of the bounds of a "
                    ~ Take.stringof);
                source[index] = v;
            }
        }

        static if (hasMobileElements!R)
        {
            auto moveBack()
            {
                assert(!empty,
                    "Attempting to move the back of an empty "
                    ~ Take.stringof);
                return .moveAt(source, this.length - 1);
            }

            auto moveAt(size_t index)
            {
                assert(index < length,
                    "Attempting to index out of the bounds of a "
                    ~ Take.stringof);
                return .moveAt(source, index);
            }
        }
    }

    // Nonstandard
    @property size_t maxLength() const
    {
        return _maxAvailable;
    }
}

// This template simply aliases itself to R and is useful for consistency in
// generic code.
template Take(R)
if (isInputRange!(Unqual!R) &&
    ((!isInfinite!(Unqual!R) && hasSlicing!(Unqual!R)) || is(R T == Take!T)))
{
    alias Take = R;
}

// take for finite ranges with slicing
/// ditto
Take!R take(R)(R input, size_t n)
if (isInputRange!(Unqual!R) && !isInfinite!(Unqual!R) && hasSlicing!(Unqual!R) &&
    !is(R T == Take!T))
{
    // @@@BUG@@@
    //return input[0 .. min(n, $)];
    import std.algorithm : min;
    return input[0 .. min(n, input.length)];
}

///
@safe unittest
{
    import std.algorithm : equal;

    int[] arr1 = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    auto s = take(arr1, 5);
    assert(s.length == 5);
    assert(s[4] == 5);
    assert(equal(s, [ 1, 2, 3, 4, 5 ][]));
}

// take(take(r, n1), n2)
Take!R take(R)(R input, size_t n)
if (is(R T == Take!T))
{
    import std.algorithm : min;
    return R(input.source, min(n, input._maxAvailable));
}

// Regular take for input ranges
Take!(R) take(R)(R input, size_t n)
if (isInputRange!(Unqual!R) && (isInfinite!(Unqual!R) || !hasSlicing!(Unqual!R) && !is(R T == Take!T)))
{
    return Take!R(input, n);
}

@safe unittest
{
    import std.internal.test.dummyrange;
    import std.algorithm : equal;

    int[] arr1 = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    auto s = take(arr1, 5);
    assert(s.length == 5);
    assert(s[4] == 5);
    assert(equal(s, [ 1, 2, 3, 4, 5 ][]));
    assert(equal(retro(s), [ 5, 4, 3, 2, 1 ][]));

    // Test fix for bug 4464.
    static assert(is(typeof(s) == Take!(int[])));
    static assert(is(typeof(s) == int[]));

    // Test using narrow strings.
    auto myStr = "This is a string.";
    auto takeMyStr = take(myStr, 7);
    assert(equal(takeMyStr, "This is"));

    // Test fix for bug 5052.
    auto takeMyStrAgain = take(takeMyStr, 4);
    assert(equal(takeMyStrAgain, "This"));
    static assert (is (typeof(takeMyStrAgain) == typeof(takeMyStr)));
    takeMyStrAgain = take(takeMyStr, 10);
    assert(equal(takeMyStrAgain, "This is"));

    foreach(DummyType; AllDummyRanges) {
        DummyType dummy;
        auto t = take(dummy, 5);
        alias T = typeof(t);

        static if (isRandomAccessRange!DummyType) {
            static assert(isRandomAccessRange!T);
            assert(t[4] == 5);

            assert(moveAt(t, 1) == t[1]);
            assert(t.back == moveBack(t));
        } else static if (isForwardRange!DummyType) {
            static assert(isForwardRange!T);
        }

        for(auto tt = t; !tt.empty; tt.popFront())
        {
            assert(tt.front == moveFront(tt));
        }

        // Bidirectional ranges can't be propagated properly if they don't
        // also have random access.

        assert(equal(t, [1,2,3,4,5]));

        //Test that take doesn't wrap the result of take.
        assert(take(t, 4) == take(dummy, 4));
    }

    immutable myRepeat = repeat(1);
    static assert(is(Take!(typeof(myRepeat))));
}

@safe unittest
{
    // Check that one can declare variables of all Take types,
    // and that they match the return type of the corresponding
    // take().  (See issue 4464.)
    int[] r1;
    Take!(int[]) t1;
    t1 = take(r1, 1);

    string r2;
    Take!string t2;
    t2 = take(r2, 1);

    Take!(Take!string) t3;
    t3 = take(t2, 1);
}

@safe unittest
{
    alias R1 = typeof(repeat(1));
    alias R2 = typeof(cycle([1]));
    alias TR1 = Take!R1;
    alias TR2 = Take!R2;
    static assert(isBidirectionalRange!TR1);
    static assert(isBidirectionalRange!TR2);
}

@safe unittest //12731
{
    auto a = repeat(1);
    auto s = a[1 .. 5];
    s = s[1 .. 3];
}

@safe unittest //13151
{
    import std.algorithm : equal;

    auto r = take(repeat(1, 4), 3);
    assert(r.take(2).equal(repeat(1, 2)));
}


/**
Similar to $(LREF take), but assumes that $(D range) has at least $(D
n) elements. Consequently, the result of $(D takeExactly(range, n))
always defines the $(D length) property (and initializes it to $(D n))
even when $(D range) itself does not define $(D length).

The result of $(D takeExactly) is identical to that of $(LREF take) in
cases where the original range defines $(D length) or is infinite.
 */
auto takeExactly(R)(R range, size_t n)
if (isInputRange!R)
{
    static if (is(typeof(takeExactly(range._input, n)) == R))
    {
        assert(n <= range._n,
               "Attempted to take more than the length of the range with takeExactly.");
        // takeExactly(takeExactly(r, n1), n2) has the same type as
        // takeExactly(r, n1) and simply returns takeExactly(r, n2)
        range._n = n;
        return range;
    }
    //Also covers hasSlicing!R for finite ranges.
    else static if (hasLength!R)
    {
        assert(n <= range.length,
               "Attempted to take more than the length of the range with takeExactly.");
        return take(range, n);
    }
    else static if (isInfinite!R)
        return Take!R(range, n);
    else
    {
        static struct Result
        {
            R _input;
            private size_t _n;

            @property bool empty() const { return !_n; }
            @property auto ref front()
            {
                assert(_n > 0, "front() on an empty " ~ Result.stringof);
                return _input.front;
            }
            void popFront() { _input.popFront(); --_n; }
            @property size_t length() const { return _n; }
            alias opDollar = length;

            @property Take!R _takeExactly_Result_asTake()
            {
                return typeof(return)(_input, _n);
            }

            alias _takeExactly_Result_asTake this;

            static if (isForwardRange!R)
                @property auto save()
                {
                    return Result(_input.save, _n);
                }

            static if (hasMobileElements!R)
            {
                auto moveFront()
                {
                    assert(!empty,
                        "Attempting to move the front of an empty "
                        ~ typeof(this).stringof);
                    return .moveFront(_input);
                }
            }

            static if (hasAssignableElements!R)
            {
                @property auto ref front(ElementType!R v)
                {
                    assert(!empty,
                        "Attempting to assign to the front of an empty "
                        ~ typeof(this).stringof);
                    return _input.front = v;
                }
            }
        }

        return Result(range, n);
    }
}

///
@safe unittest
{
    import std.algorithm : equal;

    auto a = [ 1, 2, 3, 4, 5 ];

    auto b = takeExactly(a, 3);
    assert(equal(b, [1, 2, 3]));
    static assert(is(typeof(b.length) == size_t));
    assert(b.length == 3);
    assert(b.front == 1);
    assert(b.back == 3);
}

@safe unittest
{
    import std.algorithm : equal, filter;

    auto a = [ 1, 2, 3, 4, 5 ];
    auto b = takeExactly(a, 3);
    auto c = takeExactly(b, 2);

    auto d = filter!"a > 0"(a);
    auto e = takeExactly(d, 3);
    assert(equal(e, [1, 2, 3]));
    static assert(is(typeof(e.length) == size_t));
    assert(e.length == 3);
    assert(e.front == 1);

    assert(equal(takeExactly(e, 3), [1, 2, 3]));
}

@safe unittest
{
    import std.algorithm : equal;
    import std.internal.test.dummyrange;

    auto a = [ 1, 2, 3, 4, 5 ];
    //Test that take and takeExactly are the same for ranges which define length
    //but aren't sliceable.
    struct L
    {
        @property auto front() { return _arr[0]; }
        @property bool empty() { return _arr.empty; }
        void popFront() { _arr.popFront(); }
        @property size_t length() { return _arr.length; }
        int[] _arr;
    }
    static assert(is(typeof(take(L(a), 3)) == typeof(takeExactly(L(a), 3))));
    assert(take(L(a), 3) == takeExactly(L(a), 3));

    //Test that take and takeExactly are the same for ranges which are sliceable.
    static assert(is(typeof(take(a, 3)) == typeof(takeExactly(a, 3))));
    assert(take(a, 3) == takeExactly(a, 3));

    //Test that take and takeExactly are the same for infinite ranges.
    auto inf = repeat(1);
    static assert(is(typeof(take(inf, 5)) == Take!(typeof(inf))));
    assert(take(inf, 5) == takeExactly(inf, 5));

    //Test that take and takeExactly are _not_ the same for ranges which don't
    //define length.
    static assert(!is(typeof(take(filter!"true"(a), 3)) == typeof(takeExactly(filter!"true"(a), 3))));

    foreach(DummyType; AllDummyRanges)
    {
        {
            DummyType dummy;
            auto t = takeExactly(dummy, 5);

            //Test that takeExactly doesn't wrap the result of takeExactly.
            assert(takeExactly(t, 4) == takeExactly(dummy, 4));
        }

        static if(hasMobileElements!DummyType)
        {
            {
                auto t = takeExactly(DummyType.init, 4);
                assert(t.moveFront() == 1);
                assert(equal(t, [1, 2, 3, 4]));
            }
        }

        static if(hasAssignableElements!DummyType)
        {
            {
                auto t = takeExactly(DummyType.init, 4);
                t.front = 9;
                assert(equal(t, [9, 2, 3, 4]));
            }
        }
    }
}

@safe unittest
{
    import std.algorithm : equal;
    import std.internal.test.dummyrange;

    alias DummyType = DummyRange!(ReturnBy.Value, Length.No, RangeType.Forward);
    auto te = takeExactly(DummyType(), 5);
    Take!DummyType t = te;
    assert(equal(t, [1, 2, 3, 4, 5]));
    assert(equal(t, te));
}

/**
Returns a range with at most one element; for example, $(D
takeOne([42, 43, 44])) returns a range consisting of the integer $(D
42). Calling $(D popFront()) off that range renders it empty.

In effect $(D takeOne(r)) is somewhat equivalent to $(D take(r, 1)) but in
certain interfaces it is important to know statically that the range may only
have at most one element.

The type returned by $(D takeOne) is a random-access range with length
regardless of $(D R)'s capabilities (another feature that distinguishes
$(D takeOne) from $(D take)).
 */
auto takeOne(R)(R source) if (isInputRange!R)
{
    static if (hasSlicing!R)
    {
        return source[0 .. !source.empty];
    }
    else
    {
        static struct Result
        {
            private R _source;
            private bool _empty = true;
            @property bool empty() const { return _empty; }
            @property auto ref front() { assert(!empty); return _source.front; }
            void popFront() { assert(!empty); _empty = true; }
            void popBack() { assert(!empty); _empty = true; }
            static if (isForwardRange!(Unqual!R))
            {
                @property auto save() { return Result(_source.save, empty); }
            }
            @property auto ref back() { assert(!empty); return _source.front; }
            @property size_t length() const { return !empty; }
            alias opDollar = length;
            auto ref opIndex(size_t n) { assert(n < length); return _source.front; }
            auto opSlice(size_t m, size_t n)
            {
                assert(m <= n && n < length);
                return n > m ? this : Result(_source, false);
            }
            // Non-standard property
            @property R source() { return _source; }
        }

        return Result(source, source.empty);
    }
}

///
@safe unittest
{
    auto s = takeOne([42, 43, 44]);
    static assert(isRandomAccessRange!(typeof(s)));
    assert(s.length == 1);
    assert(!s.empty);
    assert(s.front == 42);
    s.front = 43;
    assert(s.front == 43);
    assert(s.back == 43);
    assert(s[0] == 43);
    s.popFront();
    assert(s.length == 0);
    assert(s.empty);
}

unittest
{
    struct NonForwardRange
    {
        enum empty = false;
        int front() { return 42; }
        void popFront() {}
    }

    static assert(!isForwardRange!NonForwardRange);

    auto s = takeOne(NonForwardRange());
    assert(s.front == 42);
}

/++
    Returns an empty range which is statically known to be empty and is
    guaranteed to have $(D length) and be random access regardless of $(D R)'s
    capabilities.
  +/
auto takeNone(R)()
    if(isInputRange!R)
{
    return typeof(takeOne(R.init)).init;
}

///
@safe unittest
{
    auto range = takeNone!(int[])();
    assert(range.length == 0);
    assert(range.empty);
}

@safe unittest
{
    enum ctfe = takeNone!(int[])();
    static assert(ctfe.length == 0);
    static assert(ctfe.empty);
}


/++
    Creates an empty range from the given range in $(BIGOH 1). If it can, it
    will return the same range type. If not, it will return
    $(D takeExactly(range, 0)).
  +/
auto takeNone(R)(R range)
    if(isInputRange!R)
{
    //Makes it so that calls to takeNone which don't use UFCS still work with a
    //member version if it's defined.
    static if(is(typeof(R.takeNone)))
        auto retval = range.takeNone();
    //@@@BUG@@@ 8339
    else static if(isDynamicArray!R)/+ ||
                   (is(R == struct) && __traits(compiles, {auto r = R.init;}) && R.init.empty))+/
    {
        auto retval = R.init;
    }
    //An infinite range sliced at [0 .. 0] would likely still not be empty...
    else static if(hasSlicing!R && !isInfinite!R)
        auto retval = range[0 .. 0];
    else
        auto retval = takeExactly(range, 0);

    //@@@BUG@@@ 7892 prevents this from being done in an out block.
    assert(retval.empty);
    return retval;
}

///
@safe unittest
{
    import std.algorithm : filter;
    assert(takeNone([42, 27, 19]).empty);
    assert(takeNone("dlang.org").empty);
    assert(takeNone(filter!"true"([42, 27, 19])).empty);
}

@safe unittest
{
    import std.algorithm : filter;

    struct Dummy
    {
        mixin template genInput()
        {
            @property bool empty() { return _arr.empty; }
            @property auto front() { return _arr.front; }
            void popFront() { _arr.popFront(); }
            static assert(isInputRange!(typeof(this)));
        }
    }
    alias genInput = Dummy.genInput;

    static struct NormalStruct
    {
        //Disabled to make sure that the takeExactly version is used.
        @disable this();
        this(int[] arr) { _arr = arr; }
        mixin genInput;
        int[] _arr;
    }

    static struct SliceStruct
    {
        @disable this();
        this(int[] arr) { _arr = arr; }
        mixin genInput;
        @property auto save() { return this; }
        auto opSlice(size_t i, size_t j) { return typeof(this)(_arr[i .. j]); }
        @property size_t length() { return _arr.length; }
        int[] _arr;
    }

    static struct InitStruct
    {
        mixin genInput;
        int[] _arr;
    }

    static struct TakeNoneStruct
    {
        this(int[] arr) { _arr = arr; }
        @disable this();
        mixin genInput;
        auto takeNone() { return typeof(this)(null); }
        int[] _arr;
    }

    static class NormalClass
    {
        this(int[] arr) {_arr = arr;}
        mixin genInput;
        int[] _arr;
    }

    static class SliceClass
    {
        this(int[] arr) { _arr = arr; }
        mixin genInput;
        @property auto save() { return new typeof(this)(_arr); }
        auto opSlice(size_t i, size_t j) { return new typeof(this)(_arr[i .. j]); }
        @property size_t length() { return _arr.length; }
        int[] _arr;
    }

    static class TakeNoneClass
    {
        this(int[] arr) { _arr = arr; }
        mixin genInput;
        auto takeNone() { return new typeof(this)(null); }
        int[] _arr;
    }

    import std.format : format;

    foreach(range; TypeTuple!([1, 2, 3, 4, 5],
                              "hello world",
                              "hello world"w,
                              "hello world"d,
                              SliceStruct([1, 2, 3]),
                              //@@@BUG@@@ 8339 forces this to be takeExactly
                              //`InitStruct([1, 2, 3]),
                              TakeNoneStruct([1, 2, 3])))
    {
        static assert(takeNone(range).empty, typeof(range).stringof);
        assert(takeNone(range).empty);
        static assert(is(typeof(range) == typeof(takeNone(range))), typeof(range).stringof);
    }

    foreach(range; TypeTuple!(NormalStruct([1, 2, 3]),
                              InitStruct([1, 2, 3])))
    {
        static assert(takeNone(range).empty, typeof(range).stringof);
        assert(takeNone(range).empty);
        static assert(is(typeof(takeExactly(range, 0)) == typeof(takeNone(range))), typeof(range).stringof);
    }

    //Don't work in CTFE.
    auto normal = new NormalClass([1, 2, 3]);
    assert(takeNone(normal).empty);
    static assert(is(typeof(takeExactly(normal, 0)) == typeof(takeNone(normal))), typeof(normal).stringof);

    auto slice = new SliceClass([1, 2, 3]);
    assert(takeNone(slice).empty);
    static assert(is(SliceClass == typeof(takeNone(slice))), typeof(slice).stringof);

    auto taken = new TakeNoneClass([1, 2, 3]);
    assert(takeNone(taken).empty);
    static assert(is(TakeNoneClass == typeof(takeNone(taken))), typeof(taken).stringof);

    auto filtered = filter!"true"([1, 2, 3, 4, 5]);
    assert(takeNone(filtered).empty);
    //@@@BUG@@@ 8339 and 5941 force this to be takeExactly
    //static assert(is(typeof(filtered) == typeof(takeNone(filtered))), typeof(filtered).stringof);
}

/++
    Convenience function which calls
    $(D range.$(LREF popFrontN)(n)) and returns $(D range). $(D drop)
    makes it easier to pop elements from a range
    and then pass it to another function within a single expression,
    whereas $(D popFrontN) would require multiple statements.

    $(D dropBack) provides the same functionality but instead calls
    $(D range.popBackN(n)).

    Note: $(D drop) and $(D dropBack) will only pop $(I up to)
    $(D n) elements but will stop if the range is empty first.

  +/
R drop(R)(R range, size_t n)
    if(isInputRange!R)
{
    range.popFrontN(n);
    return range;
}
/// ditto
R dropBack(R)(R range, size_t n)
    if(isBidirectionalRange!R)
{
    range.popBackN(n);
    return range;
}

///
@safe unittest
{
    import std.algorithm : equal;

    assert([0, 2, 1, 5, 0, 3].drop(3) == [5, 0, 3]);
    assert("hello world".drop(6) == "world");
    assert("hello world".drop(50).empty);
    assert("hello world".take(6).drop(3).equal("lo "));
}

@safe unittest
{
    import std.algorithm : equal;

    assert([0, 2, 1, 5, 0, 3].dropBack(3) == [0, 2, 1]);
    assert("hello world".dropBack(6) == "hello");
    assert("hello world".dropBack(50).empty);
    assert("hello world".drop(4).dropBack(4).equal("o w"));
}

@safe unittest
{
    import std.algorithm : equal;
    import std.container.dlist;

    //Remove all but the first two elements
    auto a = DList!int(0, 1, 9, 9, 9, 9);
    a.remove(a[].drop(2));
    assert(a[].equal(a[].take(2)));
}

@safe unittest
{
    import std.algorithm : equal, filter;

    assert(drop("", 5).empty);
    assert(equal(drop(filter!"true"([0, 2, 1, 5, 0, 3]), 3), [5, 0, 3]));
}

@safe unittest
{
    import std.algorithm : equal;
    import std.container.dlist;

    //insert before the last two elements
    auto a = DList!int(0, 1, 2, 5, 6);
    a.insertAfter(a[].dropBack(2), [3, 4]);
    assert(a[].equal(iota(0, 7)));
}

/++
    Similar to $(LREF drop) and $(D dropBack) but they call
    $(D range.$(LREF popFrontExactly)(n)) and $(D range.popBackExactly(n))
    instead.

    Note: Unlike $(D drop), $(D dropExactly) will assume that the
    range holds at least $(D n) elements. This makes $(D dropExactly)
    faster than $(D drop), but it also means that if $(D range) does
    not contain at least $(D n) elements, it will attempt to call $(D popFront)
    on an empty range, which is undefined behavior. So, only use
    $(D popFrontExactly) when it is guaranteed that $(D range) holds at least
    $(D n) elements.
+/
R dropExactly(R)(R range, size_t n)
    if(isInputRange!R)
{
    popFrontExactly(range, n);
    return range;
}
/// ditto
R dropBackExactly(R)(R range, size_t n)
    if(isBidirectionalRange!R)
{
    popBackExactly(range, n);
    return range;
}

///
@safe unittest
{
    import std.algorithm : equal, filterBidirectional;

    auto a = [1, 2, 3];
    assert(a.dropExactly(2) == [3]);
    assert(a.dropBackExactly(2) == [1]);

    string s = "日本語";
    assert(s.dropExactly(2) == "語");
    assert(s.dropBackExactly(2) == "日");

    auto bd = filterBidirectional!"true"([1, 2, 3]);
    assert(bd.dropExactly(2).equal([3]));
    assert(bd.dropBackExactly(2).equal([1]));
}

/++
    Convenience function which calls
    $(D range.popFront()) and returns $(D range). $(D dropOne)
    makes it easier to pop an element from a range
    and then pass it to another function within a single expression,
    whereas $(D popFront) would require multiple statements.

    $(D dropBackOne) provides the same functionality but instead calls
    $(D range.popBack()).
+/
R dropOne(R)(R range)
    if (isInputRange!R)
{
    range.popFront();
    return range;
}
/// ditto
R dropBackOne(R)(R range)
    if (isBidirectionalRange!R)
{
    range.popBack();
    return range;
}

///
@safe unittest
{
    import std.algorithm : equal, filterBidirectional;

    import std.container.dlist;

    auto dl = DList!int(9, 1, 2, 3, 9);
    assert(dl[].dropOne().dropBackOne().equal([1, 2, 3]));

    auto a = [1, 2, 3];
    assert(a.dropOne() == [2, 3]);
    assert(a.dropBackOne() == [1, 2]);

    string s = "日本語";
    assert(s.dropOne() == "本語");
    assert(s.dropBackOne() == "日本");

    auto bd = filterBidirectional!"true"([1, 2, 3]);
    assert(bd.dropOne().equal([2, 3]));
    assert(bd.dropBackOne().equal([1, 2]));
}

/**
Repeats one value forever.

Models an infinite bidirectional and random access range, with slicing.
*/
struct Repeat(T)
{
private:
    //Store a non-qualified T when possible: This is to make Repeat assignable
    static if ((is(T == class) || is(T == interface)) && (is(T == const) || is(T == immutable)))
    {
        import std.typecons;
        alias UT = Rebindable!T;
    }
    else static if (is(T : Unqual!T) && is(Unqual!T : T))
        alias UT = Unqual!T;
    else
        alias UT = T;
    UT _value;

public:
    @property inout(T) front() inout { return _value; }
    @property inout(T) back() inout { return _value; }
    enum bool empty = false;
    void popFront() {}
    void popBack() {}
    @property auto save() inout { return this; }
    inout(T) opIndex(size_t) inout { return _value; }
    auto opSlice(size_t i, size_t j)
    in
    {
        import core.exception : RangeError;
        if (i > j) throw new RangeError();
    }
    body
    {
        return this.takeExactly(j - i);
    }
    private static struct DollarToken {}
    enum opDollar = DollarToken.init;
    auto opSlice(size_t, DollarToken) inout { return this; }
}

/// Ditto
Repeat!T repeat(T)(T value) { return Repeat!T(value); }

///
@safe unittest
{
    import std.algorithm : equal;

    assert(equal(5.repeat().take(4), [ 5, 5, 5, 5 ]));
}

@safe unittest
{
    import std.algorithm : equal;

    auto  r = repeat(5);
    alias R = typeof(r);
    static assert(isBidirectionalRange!R);
    static assert(isForwardRange!R);
    static assert(isInfinite!R);
    static assert(hasSlicing!R);

    assert(r.back == 5);
    assert(r.front == 5);
    assert(r.take(4).equal([ 5, 5, 5, 5 ]));
    assert(r[0 .. 4].equal([ 5, 5, 5, 5 ]));

    R r2 = r[5 .. $];
}

/**
   Repeats $(D value) exactly $(D n) times. Equivalent to $(D
   take(repeat(value), n)).
*/
Take!(Repeat!T) repeat(T)(T value, size_t n)
{
    return take(repeat(value), n);
}

///
@safe unittest
{
    import std.algorithm : equal;

    assert(equal(5.repeat(4), 5.repeat().take(4)));
}

@safe unittest //12007
{
    static class C{}
    Repeat!(immutable int) ri;
    ri = ri.save;
    Repeat!(immutable C) rc;
    rc = rc.save;

    import std.algorithm;
    immutable int[] A = [1,2,3];
    immutable int[] B = [4,5,6];

    auto AB = cartesianProduct(A,B);
}

/**
Repeats the given forward range ad infinitum. If the original range is
infinite (fact that would make $(D Cycle) the identity application),
$(D Cycle) detects that and aliases itself to the range type
itself. If the original range has random access, $(D Cycle) offers
random access and also offers a constructor taking an initial position
$(D index). $(D Cycle) works with static arrays in addition to ranges,
mostly for performance reasons.

Tip: This is a great way to implement simple circular buffers.
*/
struct Cycle(R)
    if (isForwardRange!R && !isInfinite!R)
{
    static if (isRandomAccessRange!R && hasLength!R)
    {
        private R _original;
        private size_t _index;

        this(R input, size_t index = 0)
        {
            _original = input;
            _index = index % _original.length;
        }

        @property auto ref front()
        {
            return _original[_index];
        }

        static if (is(typeof((cast(const R)_original)[_index])))
        {
            @property auto ref front() const
            {
                return _original[_index];
            }
        }

        static if (hasAssignableElements!R)
        {
            @property auto front(ElementType!R val)
            {
                _original[_index] = val;
            }
        }

        enum bool empty = false;

        void popFront()
        {
            ++_index;
            if (_index >= _original.length)
                _index = 0;
        }

        auto ref opIndex(size_t n)
        {
            return _original[(n + _index) % _original.length];
        }

        static if (is(typeof((cast(const R)_original)[_index])) &&
                   is(typeof((cast(const R)_original).length)))
        {
            auto ref opIndex(size_t n) const
            {
                return _original[(n + _index) % _original.length];
            }
        }

        static if (hasAssignableElements!R)
        {
            auto opIndexAssign(ElementType!R val, size_t n)
            {
                _original[(n + _index) % _original.length] = val;
            }
        }

        @property Cycle save()
        {
            //No need to call _original.save, because Cycle never actually modifies _original
            return Cycle(_original, _index);
        }

        private static struct DollarToken {}
        enum opDollar = DollarToken.init;

        auto opSlice(size_t i, size_t j)
        in
        {
            import core.exception : RangeError;
            if (i > j) throw new RangeError();
        }
        body
        {
            return this[i .. $].takeExactly(j - i);
        }

        auto opSlice(size_t i, DollarToken)
        {
            return typeof(this)(_original, _index + i);
        }
    }
    else
    {
        private R _original;
        private R _current;

        this(R input)
        {
            _original = input;
            _current = input.save;
        }

        @property auto ref front()
        {
            return _current.front;
        }

        static if (is(typeof((cast(const R)_current).front)))
        {
            @property auto ref front() const
            {
                return _current.front;
            }
        }

        static if (hasAssignableElements!R)
        {
            @property auto front(ElementType!R val)
            {
                return _current.front = val;
            }
        }

        enum bool empty = false;

        void popFront()
        {
            _current.popFront();
            if (_current.empty)
                _current = _original.save;
        }

        @property Cycle save()
        {
            //No need to call _original.save, because Cycle never actually modifies _original
            Cycle ret = this;
            ret._original = _original;
            ret._current =  _current.save;
            return ret;
        }
    }
}

template Cycle(R)
    if (isInfinite!R)
{
    alias Cycle = R;
}

struct Cycle(R)
    if (isStaticArray!R)
{
    private alias ElementType = typeof(R.init[0]);
    private ElementType* _ptr;
    private size_t _index;

nothrow:
    this(ref R input, size_t index = 0) @system
    {
        _ptr = input.ptr;
        _index = index % R.length;
    }

    @property ref inout(ElementType) front() inout @safe
    {
        static ref auto trustedPtrIdx(typeof(_ptr) p, size_t idx) @trusted
        {
            return p[idx];
        }
        return trustedPtrIdx(_ptr, _index);
    }

    enum bool empty = false;

    void popFront() @safe
    {
        ++_index;
        if (_index >= R.length)
            _index = 0;
    }

    ref inout(ElementType) opIndex(size_t n) inout @safe
    {
        static ref auto trustedPtrIdx(typeof(_ptr) p, size_t idx) @trusted
        {
            return p[idx % R.length];
        }
        return trustedPtrIdx(_ptr, n + _index);
    }

    @property inout(Cycle) save() inout @safe
    {
        return this;
    }

    private static struct DollarToken {}
    enum opDollar = DollarToken.init;

    auto opSlice(size_t i, size_t j) @safe
    in
    {
        import core.exception : RangeError;
        if (i > j) throw new RangeError();
    }
    body
    {
        return this[i .. $].takeExactly(j - i);
    }

    inout(typeof(this)) opSlice(size_t i, DollarToken) inout @safe
    {
        static auto trustedCtor(typeof(_ptr) p, size_t idx) @trusted
        {
            return cast(inout)Cycle(*cast(R*)(p), idx);
        }
        return trustedCtor(_ptr, _index + i);
    }
}

/// Ditto
Cycle!R cycle(R)(R input)
    if (isForwardRange!R && !isInfinite!R)
{
    return Cycle!R(input);
}

///
@safe unittest
{
    import std.algorithm : equal;

    assert(equal(take(cycle([1, 2][]), 5), [ 1, 2, 1, 2, 1 ][]));
}

/// Ditto
Cycle!R cycle(R)(R input, size_t index = 0)
    if (isRandomAccessRange!R && !isInfinite!R)
{
    return Cycle!R(input, index);
}

Cycle!R cycle(R)(R input)
    if (isInfinite!R)
{
    return input;
}

Cycle!R cycle(R)(ref R input, size_t index = 0) @system
    if (isStaticArray!R)
{
    return Cycle!R(input, index);
}

@safe unittest
{
    import std.internal.test.dummyrange;
    import std.algorithm : equal;

    static assert(isForwardRange!(Cycle!(uint[])));

    // Make sure ref is getting propagated properly.
    int[] nums = [1,2,3];
    auto c2 = cycle(nums);
    c2[3]++;
    assert(nums[0] == 2);

    immutable int[] immarr = [1, 2, 3];
    auto cycleimm = cycle(immarr);

    foreach(DummyType; AllDummyRanges)
    {
        static if (isForwardRange!DummyType)
        {
            DummyType dummy;
            auto cy = cycle(dummy);
            static assert(isForwardRange!(typeof(cy)));
            auto t = take(cy, 20);
            assert(equal(t, [1,2,3,4,5,6,7,8,9,10,1,2,3,4,5,6,7,8,9,10]));

            const cRange = cy;
            assert(cRange.front == 1);

            static if (hasAssignableElements!DummyType)
            {
                {
                    cy.front = 66;
                    scope(exit) cy.front = 1;
                    assert(dummy.front == 66);
                }

                static if (isRandomAccessRange!DummyType)
                {
                    import core.exception : RangeError;
                    import std.exception : assertThrown;

                    {
                        cy[10] = 66;
                        scope(exit) cy[10] = 1;
                        assert(dummy.front == 66);
                    }

                    assert(cRange[10] == 1);
                }
            }

            static if(hasSlicing!DummyType)
            {
                auto slice = cy[5 .. 15];
                assert(equal(slice, [6, 7, 8, 9, 10, 1, 2, 3, 4, 5]));
                static assert(is(typeof(slice) == typeof(takeExactly(cy, 5))));

                auto infSlice = cy[7 .. $];
                assert(equal(take(infSlice, 5), [8, 9, 10, 1, 2]));
                static assert(isInfinite!(typeof(infSlice)));
            }
        }
    }
}

@system unittest // For static arrays.
{
    import std.algorithm : equal;

    int[3] a = [ 1, 2, 3 ];
    static assert(isStaticArray!(typeof(a)));
    auto c = cycle(a);
    assert(a.ptr == c._ptr);
    assert(equal(take(cycle(a), 5), [ 1, 2, 3, 1, 2 ][]));
    static assert(isForwardRange!(typeof(c)));

    // Test qualifiers on slicing.
    alias C = typeof(c);
    static assert(is(typeof(c[1 .. $]) == C));
    const cConst = c;
    static assert(is(typeof(cConst[1 .. $]) == const(C)));
}

@safe unittest // For infinite ranges
{
    struct InfRange
    {
        void popFront() { }
        @property int front() { return 0; }
        enum empty = false;
    }

    InfRange i;
    auto c = cycle(i);
    assert (c == i);
}

@safe unittest
{
    import std.algorithm : equal;

    int[5] arr = [0, 1, 2, 3, 4];
    auto cleD = cycle(arr[]); //Dynamic
    assert(equal(cleD[5 .. 10], arr[]));

    //n is a multiple of 5 worth about 3/4 of size_t.max
    auto n = size_t.max/4 + size_t.max/2;
    n -= n % 5;

    //Test index overflow
    foreach (_ ; 0 .. 10)
    {
        cleD = cleD[n .. $];
        assert(equal(cleD[5 .. 10], arr[]));
    }
}

@system unittest
{
    import std.algorithm : equal;

    int[5] arr = [0, 1, 2, 3, 4];
    auto cleS = cycle(arr);   //Static
    assert(equal(cleS[5 .. 10], arr[]));

    //n is a multiple of 5 worth about 3/4 of size_t.max
    auto n = size_t.max/4 + size_t.max/2;
    n -= n % 5;

    //Test index overflow
    foreach (_ ; 0 .. 10)
    {
        cleS = cleS[n .. $];
        assert(equal(cleS[5 .. 10], arr[]));
    }
}

@system unittest
{
    import std.algorithm : equal;

    int[1] arr = [0];
    auto cleS = cycle(arr);
    cleS = cleS[10 .. $];
    assert(equal(cleS[5 .. 10], 0.repeat(5)));
    assert(cleS.front == 0);
}

unittest //10845
{
    import std.algorithm : equal, filter;

    auto a = inputRangeObject(iota(3).filter!"true");
    assert(equal(cycle(a).take(10), [0, 1, 2, 0, 1, 2, 0, 1, 2, 0]));
}

@safe unittest // 12177
{
    auto a = recurrence!q{a[n - 1] ~ a[n - 2]}("1", "0");
}

private alias lengthType(R) = typeof(R.init.length.init);

/**
   Iterate several ranges in lockstep. The element type is a proxy tuple
   that allows accessing the current element in the $(D n)th range by
   using $(D e[n]).
   $(D Zip) offers the lowest range facilities of all components, e.g. it
   offers random access iff all ranges offer random access, and also
   offers mutation and swapping if all ranges offer it. Due to this, $(D
   Zip) is extremely powerful because it allows manipulating several
   ranges in lockstep. For example, the following code sorts two arrays
   in parallel:
*/
struct Zip(Ranges...)
    if (Ranges.length && allSatisfy!(isInputRange, Ranges))
{
    import std.format : format; //for generic mixins
    import std.typecons : Tuple;

    alias R = Ranges;
    R ranges;
    alias ElementType = Tuple!(staticMap!(.ElementType, R));
    StoppingPolicy stoppingPolicy = StoppingPolicy.shortest;

/**
   Builds an object. Usually this is invoked indirectly by using the
   $(LREF zip) function.
 */
    this(R rs, StoppingPolicy s = StoppingPolicy.shortest)
    {
        ranges[] = rs[];
        stoppingPolicy = s;
    }

/**
   Returns $(D true) if the range is at end. The test depends on the
   stopping policy.
*/
    static if (allSatisfy!(isInfinite, R))
    {
        // BUG:  Doesn't propagate infiniteness if only some ranges are infinite
        //       and s == StoppingPolicy.longest.  This isn't fixable in the
        //       current design since StoppingPolicy is known only at runtime.
        enum bool empty = false;
    }
    else
    {
        @property bool empty()
        {
            import std.exception : enforce;

            final switch (stoppingPolicy)
            {
            case StoppingPolicy.shortest:
                foreach (i, Unused; R)
                {
                    if (ranges[i].empty) return true;
                }
                return false;
            case StoppingPolicy.longest:
                foreach (i, Unused; R)
                {
                    if (!ranges[i].empty) return false;
                }
                return true;
            case StoppingPolicy.requireSameLength:
                foreach (i, Unused; R[1 .. $])
                {
                    enforce(ranges[0].empty ==
                            ranges[i + 1].empty,
                            "Inequal-length ranges passed to Zip");
                }
                return ranges[0].empty;
            }
            assert(false);
        }
    }

    static if (allSatisfy!(isForwardRange, R))
    {
        @property Zip save()
        {
            //Zip(ranges[0].save, ranges[1].save, ..., stoppingPolicy)
            return mixin (q{Zip(%(ranges[%s]%|, %), stoppingPolicy)}.format(iota(0, R.length)));
        }
    }

    private .ElementType!(R[i]) tryGetInit(size_t i)()
    {
        alias E = .ElementType!(R[i]);
        static if (!is(typeof({static E i;})))
            throw new Exception("Range with non-default constructable elements exhausted.");
        else
            return E.init;
    }

/**
   Returns the current iterated element.
*/
    @property ElementType front()
    {
        @property tryGetFront(size_t i)(){return ranges[i].empty ? tryGetInit!i() : ranges[i].front;}
        //ElementType(tryGetFront!0, tryGetFront!1, ...)
        return mixin(q{ElementType(%(tryGetFront!%s, %))}.format(iota(0, R.length)));
    }

/**
   Sets the front of all iterated ranges.
*/
    static if (allSatisfy!(hasAssignableElements, R))
    {
        @property void front(ElementType v)
        {
            foreach (i, Unused; R)
            {
                if (!ranges[i].empty)
                {
                    ranges[i].front = v[i];
                }
            }
        }
    }

/**
   Moves out the front.
*/
    static if (allSatisfy!(hasMobileElements, R))
    {
        ElementType moveFront()
        {
            @property tryMoveFront(size_t i)(){return ranges[i].empty ? tryGetInit!i() : .moveFront(ranges[i]);}
            //ElementType(tryMoveFront!0, tryMoveFront!1, ...)
            return mixin(q{ElementType(%(tryMoveFront!%s, %))}.format(iota(0, R.length)));
        }
    }

/**
   Returns the rightmost element.
*/
    static if (allSatisfy!(isBidirectionalRange, R))
    {
        @property ElementType back()
        {
            //TODO: Fixme! BackElement != back of all ranges in case of jagged-ness

            @property tryGetBack(size_t i)(){return ranges[i].empty ? tryGetInit!i() : ranges[i].back;}
            //ElementType(tryGetBack!0, tryGetBack!1, ...)
            return mixin(q{ElementType(%(tryGetBack!%s, %))}.format(iota(0, R.length)));
        }

/**
   Moves out the back.
*/
        static if (allSatisfy!(hasMobileElements, R))
        {
            ElementType moveBack()
            {
                //TODO: Fixme! BackElement != back of all ranges in case of jagged-ness

                @property tryMoveBack(size_t i)(){return ranges[i].empty ? tryGetInit!i() : .moveFront(ranges[i]);}
                //ElementType(tryMoveBack!0, tryMoveBack!1, ...)
                return mixin(q{ElementType(%(tryMoveBack!%s, %))}.format(iota(0, R.length)));
            }
        }

/**
   Returns the current iterated element.
*/
        static if (allSatisfy!(hasAssignableElements, R))
        {
            @property void back(ElementType v)
            {
                //TODO: Fixme! BackElement != back of all ranges in case of jagged-ness.
                //Not sure the call is even legal for StoppingPolicy.longest

                foreach (i, Unused; R)
                {
                    if (!ranges[i].empty)
                    {
                        ranges[i].back = v[i];
                    }
                }
            }
        }
    }

/**
   Advances to the next element in all controlled ranges.
*/
    void popFront()
    {
        import std.exception : enforce;

        final switch (stoppingPolicy)
        {
        case StoppingPolicy.shortest:
            foreach (i, Unused; R)
            {
                assert(!ranges[i].empty);
                ranges[i].popFront();
            }
            break;
        case StoppingPolicy.longest:
            foreach (i, Unused; R)
            {
                if (!ranges[i].empty) ranges[i].popFront();
            }
            break;
        case StoppingPolicy.requireSameLength:
            foreach (i, Unused; R)
            {
                enforce(!ranges[i].empty, "Invalid Zip object");
                ranges[i].popFront();
            }
            break;
        }
    }

/**
   Calls $(D popBack) for all controlled ranges.
*/
    static if (allSatisfy!(isBidirectionalRange, R))
    {
        void popBack()
        {
            //TODO: Fixme! In case of jaggedness, this is wrong.
            import std.exception : enforce;

            final switch (stoppingPolicy)
            {
            case StoppingPolicy.shortest:
                foreach (i, Unused; R)
                {
                    assert(!ranges[i].empty);
                    ranges[i].popBack();
                }
                break;
            case StoppingPolicy.longest:
                foreach (i, Unused; R)
                {
                    if (!ranges[i].empty) ranges[i].popBack();
                }
                break;
            case StoppingPolicy.requireSameLength:
                foreach (i, Unused; R)
                {
                    enforce(!ranges[i].empty, "Invalid Zip object");
                    ranges[i].popBack();
                }
                break;
            }
        }
    }

/**
   Returns the length of this range. Defined only if all ranges define
   $(D length).
*/
    static if (allSatisfy!(hasLength, R))
    {
        @property auto length()
        {
            static if (Ranges.length == 1)
                return ranges[0].length;
            else
            {
                if (stoppingPolicy == StoppingPolicy.requireSameLength)
                    return ranges[0].length;

                //[min|max](ranges[0].length, ranges[1].length, ...)
                import std.algorithm : min, max;
                if (stoppingPolicy == StoppingPolicy.shortest)
                    return mixin(q{min(%(ranges[%s].length%|, %))}.format(iota(0, R.length)));
                else
                    return mixin(q{max(%(ranges[%s].length%|, %))}.format(iota(0, R.length)));
            }
        }

        alias opDollar = length;
    }

/**
   Returns a slice of the range. Defined only if all range define
   slicing.
*/
    static if (allSatisfy!(hasSlicing, R))
    {
        auto opSlice(size_t from, size_t to)
        {
            //Slicing an infinite range yields the type Take!R
            //For finite ranges, the type Take!R aliases to R
            alias ZipResult = Zip!(staticMap!(Take, R));

            //ZipResult(ranges[0][from .. to], ranges[1][from .. to], ..., stoppingPolicy)
            return mixin (q{ZipResult(%(ranges[%s][from .. to]%|, %), stoppingPolicy)}.format(iota(0, R.length)));
        }
    }

/**
   Returns the $(D n)th element in the composite range. Defined if all
   ranges offer random access.
*/
    static if (allSatisfy!(isRandomAccessRange, R))
    {
        ElementType opIndex(size_t n)
        {
            //TODO: Fixme! This may create an out of bounds access
            //for StoppingPolicy.longest

            //ElementType(ranges[0][n], ranges[1][n], ...)
            return mixin (q{ElementType(%(ranges[%s][n]%|, %))}.format(iota(0, R.length)));
        }

/**
   Assigns to the $(D n)th element in the composite range. Defined if
   all ranges offer random access.
*/
        static if (allSatisfy!(hasAssignableElements, R))
        {
            void opIndexAssign(ElementType v, size_t n)
            {
                //TODO: Fixme! Not sure the call is even legal for StoppingPolicy.longest
                foreach (i, Range; R)
                {
                    ranges[i][n] = v[i];
                }
            }
        }

/**
   Destructively reads the $(D n)th element in the composite
   range. Defined if all ranges offer random access.
*/
        static if (allSatisfy!(hasMobileElements, R))
        {
            ElementType moveAt(size_t n)
            {
                //TODO: Fixme! This may create an out of bounds access
                //for StoppingPolicy.longest

                //ElementType(.moveAt(ranges[0], n), .moveAt(ranges[1], n), ..., )
                return mixin (q{ElementType(%(.moveAt(ranges[%s], n)%|, %))}.format(iota(0, R.length)));
            }
        }
    }
}

/// Ditto
auto zip(Ranges...)(Ranges ranges)
    if (Ranges.length && allSatisfy!(isInputRange, Ranges))
{
    return Zip!Ranges(ranges);
}

///
pure unittest
{
    import std.algorithm : sort;
    int[] a = [ 1, 2, 3 ];
    string[] b = [ "a", "b", "c" ];
    sort!((c, d) => c[0] > d[0])(zip(a, b));
    assert(a == [ 3, 2, 1 ]);
    assert(b == [ "c", "b", "a" ]);
}

///
unittest
{
   int[] a = [ 1, 2, 3 ];
   string[] b = [ "a", "b", "c" ];

   size_t idx = 0;
   foreach (e; zip(a, b))
   {
       assert(e[0] == a[idx]);
       assert(e[1] == b[idx]);
       ++idx;
   }
}

/// Ditto
auto zip(Ranges...)(StoppingPolicy sp, Ranges ranges)
    if (Ranges.length && allSatisfy!(isInputRange, Ranges))
{
    return Zip!Ranges(ranges, sp);
}

/**
   Dictates how iteration in a $(D Zip) should stop. By default stop at
   the end of the shortest of all ranges.
*/
enum StoppingPolicy
{
    /// Stop when the shortest range is exhausted
    shortest,
    /// Stop when the longest range is exhausted
    longest,
    /// Require that all ranges are equal
    requireSameLength,
}

unittest
{
    import std.internal.test.dummyrange;
    import std.algorithm : swap, sort, filter, equal, map;

    import std.exception : assertThrown, assertNotThrown;
    import std.typecons : tuple;

    int[] a = [ 1, 2, 3 ];
    float[] b = [ 1.0, 2.0, 3.0 ];
    foreach (e; zip(a, b))
    {
        assert(e[0] == e[1]);
    }

    swap(a[0], a[1]);
    auto z = zip(a, b);
    //swap(z.front(), z.back());
    sort!("a[0] < b[0]")(zip(a, b));
    assert(a == [1, 2, 3]);
    assert(b == [2.0, 1.0, 3.0]);

    z = zip(StoppingPolicy.requireSameLength, a, b);
    assertNotThrown(z.popBack());
    assertNotThrown(z.popBack());
    assertNotThrown(z.popBack());
    assert(z.empty);
    assertThrown(z.popBack());

    a = [ 1, 2, 3 ];
    b = [ 1.0, 2.0, 3.0 ];
    sort!("a[0] > b[0]")(zip(StoppingPolicy.requireSameLength, a, b));
    assert(a == [3, 2, 1]);
    assert(b == [3.0, 2.0, 1.0]);

    a = [];
    b = [];
    assert(zip(StoppingPolicy.requireSameLength, a, b).empty);

    // Test infiniteness propagation.
    static assert(isInfinite!(typeof(zip(repeat(1), repeat(1)))));

    // Test stopping policies with both value and reference.
    auto a1 = [1, 2];
    auto a2 = [1, 2, 3];
    auto stuff = tuple(tuple(a1, a2),
            tuple(filter!"a"(a1), filter!"a"(a2)));

    alias FOO = Zip!(immutable(int)[], immutable(float)[]);

    foreach(t; stuff.expand) {
        auto arr1 = t[0];
        auto arr2 = t[1];
        auto zShortest = zip(arr1, arr2);
        assert(equal(map!"a[0]"(zShortest), [1, 2]));
        assert(equal(map!"a[1]"(zShortest), [1, 2]));

        try {
            auto zSame = zip(StoppingPolicy.requireSameLength, arr1, arr2);
            foreach(elem; zSame) {}
            assert(0);
        } catch (Throwable) { /* It's supposed to throw.*/ }

        auto zLongest = zip(StoppingPolicy.longest, arr1, arr2);
        assert(!zLongest.ranges[0].empty);
        assert(!zLongest.ranges[1].empty);

        zLongest.popFront();
        zLongest.popFront();
        assert(!zLongest.empty);
        assert(zLongest.ranges[0].empty);
        assert(!zLongest.ranges[1].empty);

        zLongest.popFront();
        assert(zLongest.empty);
    }

    // BUG 8900
    static assert(__traits(compiles, zip([1, 2], repeat('a'))));
    static assert(__traits(compiles, zip(repeat('a'), [1, 2])));

    // Doesn't work yet.  Issues w/ emplace.
    // static assert(is(Zip!(immutable int[], immutable float[])));


    // These unittests pass, but make the compiler consume an absurd amount
    // of RAM and time.  Therefore, they should only be run if explicitly
    // uncommented when making changes to Zip.  Also, running them using
    // make -fwin32.mak unittest makes the compiler completely run out of RAM.
    // You need to test just this module.
    /+
     foreach(DummyType1; AllDummyRanges) {
         DummyType1 d1;
         foreach(DummyType2; AllDummyRanges) {
             DummyType2 d2;
             auto r = zip(d1, d2);
             assert(equal(map!"a[0]"(r), [1,2,3,4,5,6,7,8,9,10]));
             assert(equal(map!"a[1]"(r), [1,2,3,4,5,6,7,8,9,10]));

             static if (isForwardRange!DummyType1 && isForwardRange!DummyType2) {
                 static assert(isForwardRange!(typeof(r)));
             }

             static if (isBidirectionalRange!DummyType1 &&
                     isBidirectionalRange!DummyType2) {
                 static assert(isBidirectionalRange!(typeof(r)));
             }
             static if (isRandomAccessRange!DummyType1 &&
                     isRandomAccessRange!DummyType2) {
                 static assert(isRandomAccessRange!(typeof(r)));
             }
         }
     }
    +/
}

pure unittest
{
    import std.algorithm : sort;

    auto a = [5,4,3,2,1];
    auto b = [3,1,2,5,6];
    auto z = zip(a, b);

    sort!"a[0] < b[0]"(z);

    assert(a == [1, 2, 3, 4, 5]);
    assert(b == [6, 5, 2, 1, 3]);
}

@safe pure unittest
{
    import std.typecons : tuple;
    import std.algorithm : equal;

    auto LL = iota(1L, 1000L);
    auto z = zip(LL, [4]);

    assert(equal(z, [tuple(1L,4)]));

    auto LL2 = iota(0L, 500L);
    auto z2 = zip([7], LL2);
    assert(equal(z2, [tuple(7, 0L)]));
}

// Text for Issue 11196
@safe pure unittest
{
    import std.exception : assertThrown;

    static struct S { @disable this(); }
    static assert(__traits(compiles, zip((S[5]).init[])));
    auto z = zip(StoppingPolicy.longest, cast(S[]) null, new int[1]);
    assertThrown(zip(StoppingPolicy.longest, cast(S[]) null, new int[1]).front);
}

@safe pure unittest //12007
{
    static struct R
    {
        enum empty = false;
        void popFront(){}
        int front(){return 1;} @property
        R save(){return this;} @property
        void opAssign(R) @disable;
    }
    R r;
    auto z = zip(r, r);
    auto zz = z.save;
}

/*
    Generate lockstep's opApply function as a mixin string.
    If withIndex is true prepend a size_t index to the delegate.
*/
private string lockstepMixin(Ranges...)(bool withIndex)
{
    import std.format : format;

    string[] params;
    string[] emptyChecks;
    string[] dgArgs;
    string[] popFronts;

    if (withIndex)
    {
        params ~= "size_t";
        dgArgs ~= "index";
    }

    foreach (idx, Range; Ranges)
    {
        params ~= format("%sElementType!(Ranges[%s])", hasLvalueElements!Range ? "ref " : "", idx);
        emptyChecks ~= format("!ranges[%s].empty", idx);
        dgArgs ~= format("ranges[%s].front", idx);
        popFronts ~= format("ranges[%s].popFront();", idx);
    }

    return format(
    q{
        int opApply(scope int delegate(%s) dg)
        {
            import std.exception : enforce;

            auto ranges = _ranges;
            int res;
            %s

            while (%s)
            {
                res = dg(%s);
                if (res) break;
                %s
                %s
            }

            if (_stoppingPolicy == StoppingPolicy.requireSameLength)
            {
                foreach(range; ranges)
                    enforce(range.empty);
            }
            return res;
        }
    }, params.join(", "), withIndex ? "size_t index = 0;" : "",
       emptyChecks.join(" && "), dgArgs.join(", "),
       popFronts.join("\n                "),
       withIndex ? "index++;" : "");
}

/**
   Iterate multiple ranges in lockstep using a $(D foreach) loop.  If only a single
   range is passed in, the $(D Lockstep) aliases itself away.  If the
   ranges are of different lengths and $(D s) == $(D StoppingPolicy.shortest)
   stop after the shortest range is empty.  If the ranges are of different
   lengths and $(D s) == $(D StoppingPolicy.requireSameLength), throw an
   exception.  $(D s) may not be $(D StoppingPolicy.longest), and passing this
   will throw an exception.

   By default $(D StoppingPolicy) is set to $(D StoppingPolicy.shortest).

   BUGS:  If a range does not offer lvalue access, but $(D ref) is used in the
   $(D foreach) loop, it will be silently accepted but any modifications
   to the variable will not be propagated to the underlying range.

   // Lockstep also supports iterating with an index variable:
   Example:
   -------
   foreach(index, a, b; lockstep(arr1, arr2)) {
       writefln("Index %s:  a = %s, b = %s", index, a, b);
   }
   -------
*/
struct Lockstep(Ranges...)
    if (Ranges.length > 1 && allSatisfy!(isInputRange, Ranges))
{
    this(R ranges, StoppingPolicy sp = StoppingPolicy.shortest)
    {
        import std.exception : enforce;

        _ranges = ranges;
        enforce(sp != StoppingPolicy.longest,
                "Can't use StoppingPolicy.Longest on Lockstep.");
        _stoppingPolicy = sp;
    }

    mixin(lockstepMixin!Ranges(false));
    mixin(lockstepMixin!Ranges(true));

private:
    alias R = Ranges;
    R _ranges;
    StoppingPolicy _stoppingPolicy;
}

// For generic programming, make sure Lockstep!(Range) is well defined for a
// single range.
template Lockstep(Range)
{
    alias Lockstep = Range;
}

/// Ditto
Lockstep!(Ranges) lockstep(Ranges...)(Ranges ranges)
    if (allSatisfy!(isInputRange, Ranges))
{
    return Lockstep!(Ranges)(ranges);
}
/// Ditto
Lockstep!(Ranges) lockstep(Ranges...)(Ranges ranges, StoppingPolicy s)
    if (allSatisfy!(isInputRange, Ranges))
{
    static if (Ranges.length > 1)
        return Lockstep!Ranges(ranges, s);
    else
        return ranges[0];
}

///
unittest
{
   auto arr1 = [1,2,3,4,5];
   auto arr2 = [6,7,8,9,10];

   foreach(ref a, ref b; lockstep(arr1, arr2))
   {
       a += b;
   }

   assert(arr1 == [7,9,11,13,15]);
}

unittest
{
    import std.conv : to;
    import std.algorithm : filter;

    // The filters are to make these the lowest common forward denominator ranges,
    // i.e. w/o ref return, random access, length, etc.
    auto foo = filter!"a"([1,2,3,4,5]);
    immutable bar = [6f,7f,8f,9f,10f].idup;
    auto l = lockstep(foo, bar);

    // Should work twice.  These are forward ranges with implicit save.
    foreach(i; 0..2)
    {
        uint[] res1;
        float[] res2;

        foreach(a, ref b; l) {
            res1 ~= a;
            res2 ~= b;
        }

        assert(res1 == [1,2,3,4,5]);
        assert(res2 == [6,7,8,9,10]);
        assert(bar == [6f,7f,8f,9f,10f]);
    }

    // Doc example.
    auto arr1 = [1,2,3,4,5];
    auto arr2 = [6,7,8,9,10];

    foreach(ref a, ref b; lockstep(arr1, arr2))
    {
        a += b;
    }

    assert(arr1 == [7,9,11,13,15]);

    // Make sure StoppingPolicy.requireSameLength doesn't throw.
    auto ls = lockstep(arr1, arr2, StoppingPolicy.requireSameLength);

    foreach(a, b; ls) {}

    // Make sure StoppingPolicy.requireSameLength throws.
    arr2.popBack();
    ls = lockstep(arr1, arr2, StoppingPolicy.requireSameLength);

    try {
        foreach(a, b; ls) {}
        assert(0);
    } catch (Exception) {}

    // Just make sure 1-range case instantiates.  This hangs the compiler
    // when no explicit stopping policy is specified due to Bug 4652.
    auto stuff = lockstep([1,2,3,4,5], StoppingPolicy.shortest);

    // Test with indexing.
    uint[] res1;
    float[] res2;
    size_t[] indices;
    foreach(i, a, b; lockstep(foo, bar))
    {
        indices ~= i;
        res1 ~= a;
        res2 ~= b;
    }

    assert(indices == to!(size_t[])([0, 1, 2, 3, 4]));
    assert(res1 == [1,2,3,4,5]);
    assert(res2 == [6f,7f,8f,9f,10f]);

    // Make sure we've worked around the relevant compiler bugs and this at least
    // compiles w/ >2 ranges.
    lockstep(foo, foo, foo);

    // Make sure it works with const.
    const(int[])[] foo2 = [[1, 2, 3]];
    const(int[])[] bar2 = [[4, 5, 6]];
    auto c = chain(foo2, bar2);

    foreach(f, b; lockstep(c, c)) {}

    // Regression 10468
    foreach (x, y; lockstep(iota(0, 10), iota(0, 10))) { }
}

/**
Creates a mathematical sequence given the initial values and a
recurrence function that computes the next value from the existing
values. The sequence comes in the form of an infinite forward
range. The type $(D Recurrence) itself is seldom used directly; most
often, recurrences are obtained by calling the function $(D
recurrence).

When calling $(D recurrence), the function that computes the next
value is specified as a template argument, and the initial values in
the recurrence are passed as regular arguments. For example, in a
Fibonacci sequence, there are two initial values (and therefore a
state size of 2) because computing the next Fibonacci value needs the
past two values.

The signature of this function should be:
----
auto fun(R)(R state, size_t n)
----
where $(D n) will be the index of the current value, and $(D state) will be an
opaque state vector that can be indexed with array-indexing notation
$(D state[i]), where valid values of $(D i) range from $(D (n - 1)) to
$(D (n - State.length)).

If the function is passed in string form, the state has name $(D "a")
and the zero-based index in the recurrence has name $(D "n"). The
given string must return the desired value for $(D a[n]) given $(D a[n
- 1]), $(D a[n - 2]), $(D a[n - 3]),..., $(D a[n - stateSize]). The
state size is dictated by the number of arguments passed to the call
to $(D recurrence). The $(D Recurrence) struct itself takes care of
managing the recurrence's state and shifting it appropriately.
 */
struct Recurrence(alias fun, StateType, size_t stateSize)
{
    private import std.functional : binaryFun;

    StateType[stateSize] _state;
    size_t _n;

    this(StateType[stateSize] initial) { _state = initial; }

    void popFront()
    {
        static auto trustedCycle(ref typeof(_state) s) @trusted
        {
            return cycle(s);
        }
        // The cast here is reasonable because fun may cause integer
        // promotion, but needs to return a StateType to make its operation
        // closed.  Therefore, we have no other choice.
        _state[_n % stateSize] = cast(StateType) binaryFun!(fun, "a", "n")(
            trustedCycle(_state), _n + stateSize);
        ++_n;
    }

    @property StateType front()
    {
        return _state[_n % stateSize];
    }

    @property typeof(this) save()
    {
        return this;
    }

    enum bool empty = false;
}

///
@safe unittest
{
    import std.algorithm : equal;

    // The Fibonacci numbers, using function in string form:
    // a[0] = 1, a[1] = 1, and compute a[n+1] = a[n-1] + a[n]
    auto fib = recurrence!("a[n-1] + a[n-2]")(1, 1);
    assert(fib.take(10).equal([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]));

    // The factorials, using function in lambda form:
    auto fac = recurrence!((a,n) => a[n-1] * n)(1);
    assert(take(fac, 10).equal([
        1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880
    ]));

    // The triangular numbers, using function in explicit form:
    static size_t genTriangular(R)(R state, size_t n)
    {
        return state[n-1] + n;
    }
    auto tri = recurrence!genTriangular(0);
    assert(take(tri, 10).equal([0, 1, 3, 6, 10, 15, 21, 28, 36, 45]));
}

/// Ditto
Recurrence!(fun, CommonType!(State), State.length)
recurrence(alias fun, State...)(State initial)
{
    CommonType!(State)[State.length] state;
    foreach (i, Unused; State)
    {
        state[i] = initial[i];
    }
    return typeof(return)(state);
}

@safe unittest
{
    import std.algorithm : equal;

    auto fib = recurrence!("a[n-1] + a[n-2]")(1, 1);
    static assert(isForwardRange!(typeof(fib)));

    int[] witness = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55 ];
    assert(equal(take(fib, 10), witness));
    foreach (e; take(fib, 10)) {}
    auto fact = recurrence!("n * a[n-1]")(1);
    assert( equal(take(fact, 10), [1, 1, 2, 2*3, 2*3*4, 2*3*4*5, 2*3*4*5*6,
                            2*3*4*5*6*7, 2*3*4*5*6*7*8, 2*3*4*5*6*7*8*9][]) );
    auto piapprox = recurrence!("a[n] + (n & 1 ? 4.0 : -4.0) / (2 * n + 3)")(4.0);
    foreach (e; take(piapprox, 20)) {}
    // Thanks to yebblies for this test and the associated fix
    auto r = recurrence!"a[n-2]"(1, 2);
    witness = [1, 2, 1, 2, 1];
    assert(equal(take(r, 5), witness));
}

/**
   $(D Sequence) is similar to $(D Recurrence) except that iteration is
   presented in the so-called $(WEB en.wikipedia.org/wiki/Closed_form,
   closed form). This means that the $(D n)th element in the series is
   computable directly from the initial values and $(D n) itself. This
   implies that the interface offered by $(D Sequence) is a random-access
   range, as opposed to the regular $(D Recurrence), which only offers
   forward iteration.

   The state of the sequence is stored as a $(D Tuple) so it can be
   heterogeneous.
*/
struct Sequence(alias fun, State)
{
private:
    import std.functional : binaryFun;

    alias compute = binaryFun!(fun, "a", "n");
    alias ElementType = typeof(compute(State.init, cast(size_t) 1));
    State _state;
    size_t _n;

    static struct DollarToken{}

public:
    this(State initial, size_t n = 0)
    {
        _state = initial;
        _n = n;
    }

    @property ElementType front()
    {
        return compute(_state, _n);
    }

    void popFront()
    {
        ++_n;
    }

    enum opDollar = DollarToken();

    auto opSlice(size_t lower, size_t upper)
    in
    {
        assert(upper >= lower);
    }
    body
    {
        return typeof(this)(_state, _n + lower).take(upper - lower);
    }

    auto opSlice(size_t lower, DollarToken)
    {
        return typeof(this)(_state, _n + lower);
    }

    ElementType opIndex(size_t n)
    {
        return compute(_state, n + _n);
    }

    enum bool empty = false;

    @property Sequence save() { return this; }
}

/// Ditto
auto sequence(alias fun, State...)(State args)
{
    import std.typecons : Tuple, tuple;
    alias Return = Sequence!(fun, Tuple!State);
    return Return(tuple(args));
}

/// Odd numbers, using function in string form:
@safe unittest
{
    auto odds = sequence!("a[0] + n * a[1]")(1, 2);
    assert(odds.front == 1);
    odds.popFront();
    assert(odds.front == 3);
    odds.popFront();
    assert(odds.front == 5);
}

/// Triangular numbers, using function in lambda form:
@safe unittest
{
    auto tri = sequence!((a,n) => n*(n+1)/2)();

    // Note random access
    assert(tri[0] == 0);
    assert(tri[3] == 6);
    assert(tri[1] == 1);
    assert(tri[4] == 10);
    assert(tri[2] == 3);
}

/// Fibonacci numbers, using function in explicit form:
@safe unittest
{
    import std.math : pow, round, sqrt;
    static ulong computeFib(S)(S state, size_t n)
    {
        // Binet's formula
        return cast(ulong)(round((pow(state[0], n+1) - pow(state[1], n+1)) /
                                 state[2]));
    }
    auto fib = sequence!computeFib(
        (1.0 + sqrt(5.0)) / 2.0,    // Golden Ratio
        (1.0 - sqrt(5.0)) / 2.0,    // Conjugate of Golden Ratio
        sqrt(5.0));

    // Note random access with [] operator
    assert(fib[1] == 1);
    assert(fib[4] == 5);
    assert(fib[3] == 3);
    assert(fib[2] == 2);
    assert(fib[9] == 55);
}

@safe unittest
{
    import std.typecons : Tuple, tuple;
    auto y = Sequence!("a[0] + n * a[1]", Tuple!(int, int))(tuple(0, 4));
    static assert(isForwardRange!(typeof(y)));

    //@@BUG
    //auto y = sequence!("a[0] + n * a[1]")(0, 4);
    //foreach (e; take(y, 15))
    {}                                 //writeln(e);

    auto odds = Sequence!("a[0] + n * a[1]", Tuple!(int, int))(
        tuple(1, 2));
    for(int currentOdd = 1; currentOdd <= 21; currentOdd += 2) {
        assert(odds.front == odds[0]);
        assert(odds[0] == currentOdd);
        odds.popFront();
    }
}

@safe unittest
{
    import std.algorithm : equal;

    auto odds = sequence!("a[0] + n * a[1]")(1, 2);
    static assert(hasSlicing!(typeof(odds)));

    //Note: don't use drop or take as the target of an equal,
    //since they'll both just forward to opSlice, making the tests irrelevant

    // static slicing tests
    assert(equal(odds[0 .. 5], [1,  3,  5,  7,  9]));
    assert(equal(odds[3 .. 7], [7,  9, 11, 13]));

    // relative slicing test, testing slicing is NOT agnostic of state
    auto odds_less5 = odds.drop(5); //this should actually call odds[5 .. $]
    assert(equal(odds_less5[0 ..  3], [11, 13, 15]));
    assert(equal(odds_less5[0 .. 10], odds[5 .. 15]));

    //Infinite slicing tests
    odds = odds[10 .. $];
    assert(equal(odds.take(3), [21, 23, 25]));
}

// Issue 5036
unittest
{
    auto s = sequence!((a, n) => new int)(0);
    assert(s.front != s.front);  // no caching
}

/**
   Construct a range of values that span the given starting and stopping
   values.

   Params:
   begin = The starting value.
   end = The value that serves as the stopping criterion. This value is not
        included in the range.
   step = The value to add to the current value at each iteration.

   Returns:
   A range that goes through the numbers $(D begin), $(D begin + step),
   $(D begin + 2 * step), $(D ...), up to and excluding $(D end).

   The two-argument overloads have $(D step = 1). If $(D begin < end && step <
   0) or $(D begin > end && step > 0) or $(D begin == end), then an empty range
   is returned.

   For built-in types, the range returned is a random access range. For
   user-defined types that support $(D ++), the range is an input
   range.

   Throws:
   $(D Exception) if $(D begin != end && step == 0), an exception is
   thrown.
*/
auto iota(B, E, S)(B begin, E end, S step)
if ((isIntegral!(CommonType!(B, E)) || isPointer!(CommonType!(B, E)))
        && isIntegral!S)
{
    import std.conv : unsigned;

    alias Value = CommonType!(Unqual!B, Unqual!E);
    alias StepType = Unqual!S;
    alias IndexType = typeof(unsigned((end - begin) / step));

    static struct Result
    {
        private Value current, pastLast;
        private StepType step;

        this(Value current, Value pastLast, StepType step)
        {
            import std.exception : enforce;

            if ((current < pastLast && step >= 0) ||
                    (current > pastLast && step <= 0))
            {
                enforce(step != 0);
                this.step = step;
                this.current = current;
                if (step > 0)
                {
                    this.pastLast = pastLast - 1;
                    this.pastLast -= (this.pastLast - current) % step;
                }
                else
                {
                    this.pastLast = pastLast + 1;
                    this.pastLast += (current - this.pastLast) % -step;
                }
                this.pastLast += step;
            }
            else
            {
                // Initialize an empty range
                this.current = this.pastLast = current;
                this.step = 1;
            }
        }

        @property bool empty() const { return current == pastLast; }
        @property inout(Value) front() inout { assert(!empty); return current; }
        void popFront() { assert(!empty); current += step; }

        @property inout(Value) back() inout { assert(!empty); return pastLast - step; }
        void popBack() { assert(!empty); pastLast -= step; }

        @property auto save() { return this; }

        inout(Value) opIndex(ulong n) inout
        {
            assert(n < this.length);

            // Just cast to Value here because doing so gives overflow behavior
            // consistent with calling popFront() n times.
            return cast(inout Value) (current + step * n);
        }
        inout(Result) opSlice() inout { return this; }
        inout(Result) opSlice(ulong lower, ulong upper) inout
        {
            assert(upper >= lower && upper <= this.length);

            return cast(inout Result)Result(cast(Value)(current + lower * step),
                                            cast(Value)(pastLast - (length - upper) * step),
                                            step);
        }
        @property IndexType length() const
        {
            if (step > 0)
            {
                return unsigned((pastLast - current) / step);
            }
            else
            {
                return unsigned((current - pastLast) / -step);
            }
        }

        alias opDollar = length;
    }

    return Result(begin, end, step);
}

/// Ditto
auto iota(B, E)(B begin, E end)
if (isFloatingPoint!(CommonType!(B, E)))
{
    return iota(begin, end, 1.0);
}

/// Ditto
auto iota(B, E)(B begin, E end)
if (isIntegral!(CommonType!(B, E)) || isPointer!(CommonType!(B, E)))
{
    import std.conv : unsigned;

    alias Value = CommonType!(Unqual!B, Unqual!E);
    alias IndexType = typeof(unsigned(end - begin));

    static struct Result
    {
        private Value current, pastLast;

        this(Value current, Value pastLast)
        {
            if (current < pastLast)
            {
                this.current = current;
                this.pastLast = pastLast;
            }
            else
            {
                // Initialize an empty range
                this.current = this.pastLast = current;
            }
        }

        @property bool empty() const { return current == pastLast; }
        @property inout(Value) front() inout { assert(!empty); return current; }
        void popFront() { assert(!empty); ++current; }

        @property inout(Value) back() inout { assert(!empty); return cast(inout(Value))(pastLast - 1); }
        void popBack() { assert(!empty); --pastLast; }

        @property auto save() { return this; }

        inout(Value) opIndex(ulong n) inout
        {
            assert(n < this.length);

            // Just cast to Value here because doing so gives overflow behavior
            // consistent with calling popFront() n times.
            return cast(inout Value) (current + n);
        }
        inout(Result) opSlice() inout { return this; }
        inout(Result) opSlice(ulong lower, ulong upper) inout
        {
            assert(upper >= lower && upper <= this.length);

            return cast(inout Result)Result(cast(Value)(current + lower),
                                            cast(Value)(pastLast - (length - upper)));
        }
        @property IndexType length() const
        {
            return unsigned(pastLast - current);
        }

        alias opDollar = length;
    }

    return Result(begin, end);
}

/// Ditto
auto iota(E)(E end)
{
    E begin = 0;
    return iota(begin, end);
}

/// Ditto
// Specialization for floating-point types
auto iota(B, E, S)(B begin, E end, S step)
if (isFloatingPoint!(CommonType!(B, E, S)))
{
    alias Value = Unqual!(CommonType!(B, E, S));
    static struct Result
    {
        private Value start, step;
        private size_t index, count;

        this(Value start, Value end, Value step)
        {
            import std.conv : to;
            import std.exception : enforce;

            this.start = start;
            this.step = step;
            enforce(step != 0);
            immutable fcount = (end - start) / step;
            enforce(fcount >= 0, "iota: incorrect startup parameters");
            count = to!size_t(fcount);
            auto pastEnd = start + count * step;
            if (step > 0)
            {
                if (pastEnd < end) ++count;
                assert(start + count * step >= end);
            }
            else
            {
                if (pastEnd > end) ++count;
                assert(start + count * step <= end);
            }
        }

        @property bool empty() const { return index == count; }
        @property Value front() const { assert(!empty); return start + step * index; }
        void popFront()
        {
            assert(!empty);
            ++index;
        }
        @property Value back() const
        {
            assert(!empty);
            return start + step * (count - 1);
        }
        void popBack()
        {
            assert(!empty);
            --count;
        }

        @property auto save() { return this; }

        Value opIndex(size_t n) const
        {
            assert(n < count);
            return start + step * (n + index);
        }
        inout(Result) opSlice() inout
        {
            return this;
        }
        inout(Result) opSlice(size_t lower, size_t upper) inout
        {
            assert(upper >= lower && upper <= count);

            Result ret = this;
            ret.index += lower;
            ret.count = upper - lower + ret.index;
            return cast(inout Result)ret;
        }
        @property size_t length() const
        {
            return count - index;
        }

        alias opDollar = length;
    }

    return Result(begin, end, step);
}

///
@safe unittest
{
    import std.algorithm : equal;
    import std.math : approxEqual;

    auto r = iota(0, 10, 1);
    assert(equal(r, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9][]));
    r = iota(0, 11, 3);
    assert(equal(r, [0, 3, 6, 9][]));
    assert(r[2] == 6);
    auto rf = iota(0.0, 0.5, 0.1);
    assert(approxEqual(rf, [0.0, 0.1, 0.2, 0.3, 0.4]));
}

unittest
{
    int[] a = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    auto r1 = iota(a.ptr, a.ptr + a.length, 1);
    assert(r1.front == a.ptr);
    assert(r1.back == a.ptr + a.length - 1);
}

@safe unittest
{
    import std.math : approxEqual, nextUp, nextDown;
    import std.algorithm : count, equal;

    static assert(hasLength!(typeof(iota(0, 2))));
    auto r = iota(0, 10, 1);
    assert(r[$ - 1] == 9);
    assert(equal(r, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9][]));

    auto rSlice = r[2..8];
    assert(equal(rSlice, [2, 3, 4, 5, 6, 7]));

    rSlice.popFront();
    assert(rSlice[0] == rSlice.front);
    assert(rSlice.front == 3);

    rSlice.popBack();
    assert(rSlice[rSlice.length - 1] == rSlice.back);
    assert(rSlice.back == 6);

    rSlice = r[0..4];
    assert(equal(rSlice, [0, 1, 2, 3]));

    auto rr = iota(10);
    assert(equal(rr, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9][]));

    r = iota(0, -10, -1);
    assert(equal(r, [0, -1, -2, -3, -4, -5, -6, -7, -8, -9][]));
    rSlice = r[3..9];
    assert(equal(rSlice, [-3, -4, -5, -6, -7, -8]));

    r = iota(0, -6, -3);
    assert(equal(r, [0, -3][]));
    rSlice = r[1..2];
    assert(equal(rSlice, [-3]));

    r = iota(0, -7, -3);
    assert(equal(r, [0, -3, -6][]));
    rSlice = r[1..3];
    assert(equal(rSlice, [-3, -6]));

    r = iota(0, 11, 3);
    assert(equal(r, [0, 3, 6, 9][]));
    assert(r[2] == 6);
    rSlice = r[1..3];
    assert(equal(rSlice, [3, 6]));

    auto rf = iota(0.0, 0.5, 0.1);
    assert(approxEqual(rf, [0.0, 0.1, 0.2, 0.3, 0.4][]));
    assert(rf.length == 5);

    rf.popFront();
    assert(rf.length == 4);

    auto rfSlice = rf[1..4];
    assert(rfSlice.length == 3);
    assert(approxEqual(rfSlice, [0.2, 0.3, 0.4]));

    rfSlice.popFront();
    assert(approxEqual(rfSlice[0], 0.3));

    rf.popFront();
    assert(rf.length == 3);

    rfSlice = rf[1..3];
    assert(rfSlice.length == 2);
    assert(approxEqual(rfSlice, [0.3, 0.4]));
    assert(approxEqual(rfSlice[0], 0.3));

    // With something just above 0.5
    rf = iota(0.0, nextUp(0.5), 0.1);
    assert(approxEqual(rf, [0.0, 0.1, 0.2, 0.3, 0.4, 0.5][]));
    rf.popBack();
    assert(rf[rf.length - 1] == rf.back);
    assert(approxEqual(rf.back, 0.4));
    assert(rf.length == 5);

    // going down
    rf = iota(0.0, -0.5, -0.1);
    assert(approxEqual(rf, [0.0, -0.1, -0.2, -0.3, -0.4][]));
    rfSlice = rf[2..5];
    assert(approxEqual(rfSlice, [-0.2, -0.3, -0.4]));

    rf = iota(0.0, nextDown(-0.5), -0.1);
    assert(approxEqual(rf, [0.0, -0.1, -0.2, -0.3, -0.4, -0.5][]));

    // iota of longs
    auto rl = iota(5_000_000L);
    assert(rl.length == 5_000_000L);

    // iota of longs with steps
    auto iota_of_longs_with_steps = iota(50L, 101L, 10);
    assert(iota_of_longs_with_steps.length == 6);
    assert(equal(iota_of_longs_with_steps, [50L, 60L, 70L, 80L, 90L, 100L]));

    // iota of unsigned zero length (issue 6222, actually trying to consume it
    // is the only way to find something is wrong because the public
    // properties are all correct)
    auto iota_zero_unsigned = iota(0, 0u, 3);
    assert(count(iota_zero_unsigned) == 0);

    // unsigned reverse iota can be buggy if .length doesn't take them into
    // account (issue 7982).
    assert(iota(10u, 0u, -1).length == 10);
    assert(iota(10u, 0u, -2).length == 5);
    assert(iota(uint.max, uint.max-10, -1).length == 10);
    assert(iota(uint.max, uint.max-10, -2).length == 5);
    assert(iota(uint.max, 0u, -1).length == uint.max);

    // Issue 8920
    foreach (Type; TypeTuple!(byte, ubyte, short, ushort,
        int, uint, long, ulong))
    {
        Type val;
        foreach (i; iota(cast(Type)0, cast(Type)10)) { val++; }
        assert(val == 10);
    }
}

@safe unittest
{
    import std.algorithm : copy;
    auto idx = new size_t[100];
    copy(iota(0, idx.length), idx);
}

@safe unittest
{
    foreach(range; TypeTuple!(iota(2, 27, 4),
                              iota(3, 9),
                              iota(2.7, 12.3, .1),
                              iota(3.2, 9.7)))
    {
        const cRange = range;
        const e = cRange.empty;
        const f = cRange.front;
        const b = cRange.back;
        const i = cRange[2];
        const s1 = cRange[];
        const s2 = cRange[0 .. 3];
        const l = cRange.length;
    }
}

unittest
{
    //The ptr stuff can't be done at compile time, so we unfortunately end
    //up with some code duplication here.
    auto arr = [0, 5, 3, 5, 5, 7, 9, 2, 0, 42, 7, 6];

    {
        const cRange = iota(arr.ptr, arr.ptr + arr.length, 3);
        const e = cRange.empty;
        const f = cRange.front;
        const b = cRange.back;
        const i = cRange[2];
        const s1 = cRange[];
        const s2 = cRange[0 .. 3];
        const l = cRange.length;
    }

    {
        const cRange = iota(arr.ptr, arr.ptr + arr.length);
        const e = cRange.empty;
        const f = cRange.front;
        const b = cRange.back;
        const i = cRange[2];
        const s1 = cRange[];
        const s2 = cRange[0 .. 3];
        const l = cRange.length;
    }
}

/* Generic overload that handles arbitrary types that support arithmetic
 * operations.
 */
/// ditto
auto iota(B, E)(B begin, E end)
    if (!isIntegral!(CommonType!(B, E)) &&
        !isFloatingPoint!(CommonType!(B, E)) &&
        !isPointer!(CommonType!(B, E)) &&
        is(typeof((ref B b) { ++b; })) &&
        (is(typeof(B.init < E.init)) || is(typeof(B.init == E.init))) )
{
    static struct Result
    {
        B current;
        E end;

        @property bool empty()
        {
            static if (is(typeof(B.init < E.init)))
                return !(current < end);
            else static if (is(typeof(B.init != E.init)))
                return current == end;
            else
                static assert(0);
        }
        @property auto front() { return current; }
        void popFront()
        {
            assert(!empty);
            ++current;
        }
    }
    return Result(begin, end);
}

/**
User-defined types such as $(XREF bigint, BigInt) are also supported, as long
as they can be incremented with $(D ++) and compared with $(D <) or $(D ==).
*/
// Issue 6447
unittest
{
    import std.algorithm.comparison : equal;
    import std.bigint;

    auto s = BigInt(1_000_000_000_000);
    auto e = BigInt(1_000_000_000_003);
    auto r = iota(s, e);
    assert(r.equal([
        BigInt(1_000_000_000_000),
        BigInt(1_000_000_000_001),
        BigInt(1_000_000_000_002)
    ]));
}

unittest
{
    import std.algorithm.comparison : equal;

    // Test iota() for a type that only supports ++ and != but does not have
    // '<'-ordering.
    struct Cyclic(int wrapAround)
    {
        int current;

        this(int start) { current = start % wrapAround; }

        bool opEquals(Cyclic c) { return current == c.current; }
        bool opEquals(int i) { return current == i; }
        void opUnary(string op)() if (op == "++")
        {
            current = (current + 1) % wrapAround;
        }
    }
    alias Cycle5 = Cyclic!5;

    // Easy case
    auto i1 = iota(Cycle5(1), Cycle5(4));
    assert(i1.equal([1, 2, 3]));

    // Wraparound case
    auto i2 = iota(Cycle5(3), Cycle5(2));
    assert(i2.equal([3, 4, 0, 1 ]));
}

/**
   Options for the $(LREF FrontTransversal) and $(LREF Transversal) ranges
   (below).
*/
enum TransverseOptions
{
/**
   When transversed, the elements of a range of ranges are assumed to
   have different lengths (e.g. a jagged array).
*/
    assumeJagged,                      //default
    /**
       The transversal enforces that the elements of a range of ranges have
       all the same length (e.g. an array of arrays, all having the same
       length). Checking is done once upon construction of the transversal
       range.
    */
        enforceNotJagged,
    /**
       The transversal assumes, without verifying, that the elements of a
       range of ranges have all the same length. This option is useful if
       checking was already done from the outside of the range.
    */
        assumeNotJagged,
        }

/**
   Given a range of ranges, iterate transversally through the first
   elements of each of the enclosed ranges.
*/
struct FrontTransversal(Ror,
        TransverseOptions opt = TransverseOptions.assumeJagged)
{
    alias RangeOfRanges = Unqual!(Ror);
    alias RangeType     = .ElementType!RangeOfRanges;
    alias ElementType   = .ElementType!RangeType;

    private void prime()
    {
        static if (opt == TransverseOptions.assumeJagged)
        {
            while (!_input.empty && _input.front.empty)
            {
                _input.popFront();
            }
            static if (isBidirectionalRange!RangeOfRanges)
            {
                while (!_input.empty && _input.back.empty)
                {
                    _input.popBack();
                }
            }
        }
    }

/**
   Construction from an input.
*/
    this(RangeOfRanges input)
    {
        _input = input;
        prime();
        static if (opt == TransverseOptions.enforceNotJagged)
            // (isRandomAccessRange!RangeOfRanges
            //     && hasLength!RangeType)
        {
            import std.exception : enforce;

            if (empty) return;
            immutable commonLength = _input.front.length;
            foreach (e; _input)
            {
                enforce(e.length == commonLength);
            }
        }
    }

/**
   Forward range primitives.
*/
    static if (isInfinite!RangeOfRanges)
    {
        enum bool empty = false;
    }
    else
    {
        @property bool empty()
        {
            return _input.empty;
        }
    }

    /// Ditto
    @property auto ref front()
    {
        assert(!empty);
        return _input.front.front;
    }

    /// Ditto
    static if (hasMobileElements!RangeType)
    {
        ElementType moveFront()
        {
            return .moveFront(_input.front);
        }
    }

    static if (hasAssignableElements!RangeType)
    {
        @property auto front(ElementType val)
        {
            _input.front.front = val;
        }
    }

    /// Ditto
    void popFront()
    {
        assert(!empty);
        _input.popFront();
        prime();
    }

/**
   Duplicates this $(D frontTransversal). Note that only the encapsulating
   range of range will be duplicated. Underlying ranges will not be
   duplicated.
*/
    static if (isForwardRange!RangeOfRanges)
    {
        @property FrontTransversal save()
        {
            return FrontTransversal(_input.save);
        }
    }

    static if (isBidirectionalRange!RangeOfRanges)
    {
/**
   Bidirectional primitives. They are offered if $(D
   isBidirectionalRange!RangeOfRanges).
*/
        @property auto ref back()
        {
            assert(!empty);
            return _input.back.front;
        }
        /// Ditto
        void popBack()
        {
            assert(!empty);
            _input.popBack();
            prime();
        }

        /// Ditto
        static if (hasMobileElements!RangeType)
        {
            ElementType moveBack()
            {
                return .moveFront(_input.back);
            }
        }

        static if (hasAssignableElements!RangeType)
        {
            @property auto back(ElementType val)
            {
                _input.back.front = val;
            }
        }
    }

    static if (isRandomAccessRange!RangeOfRanges &&
            (opt == TransverseOptions.assumeNotJagged ||
                    opt == TransverseOptions.enforceNotJagged))
    {
/**
   Random-access primitive. It is offered if $(D
   isRandomAccessRange!RangeOfRanges && (opt ==
   TransverseOptions.assumeNotJagged || opt ==
   TransverseOptions.enforceNotJagged)).
*/
        auto ref opIndex(size_t n)
        {
            return _input[n].front;
        }

        /// Ditto
        static if (hasMobileElements!RangeType)
        {
            ElementType moveAt(size_t n)
            {
                return .moveFront(_input[n]);
            }
        }
        /// Ditto
        static if (hasAssignableElements!RangeType)
        {
            void opIndexAssign(ElementType val, size_t n)
            {
                _input[n].front = val;
            }
        }

/**
   Slicing if offered if $(D RangeOfRanges) supports slicing and all the
   conditions for supporting indexing are met.
*/
        static if (hasSlicing!RangeOfRanges)
        {
            typeof(this) opSlice(size_t lower, size_t upper)
            {
                return typeof(this)(_input[lower..upper]);
            }
        }
    }

    auto opSlice() { return this; }

private:
    RangeOfRanges _input;
}

/// Ditto
FrontTransversal!(RangeOfRanges, opt) frontTransversal(
    TransverseOptions opt = TransverseOptions.assumeJagged,
    RangeOfRanges)
(RangeOfRanges rr)
{
    return typeof(return)(rr);
}

///
@safe unittest
{
    import std.algorithm : equal;
    int[][] x = new int[][2];
    x[0] = [1, 2];
    x[1] = [3, 4];
    auto ror = frontTransversal(x);
    assert(equal(ror, [ 1, 3 ][]));
}

@safe unittest
{
    import std.internal.test.dummyrange;
    import std.algorithm : equal;

    static assert(is(FrontTransversal!(immutable int[][])));

    foreach(DummyType; AllDummyRanges) {
        auto dummies =
            [DummyType.init, DummyType.init, DummyType.init, DummyType.init];

        foreach(i, ref elem; dummies) {
            // Just violate the DummyRange abstraction to get what I want.
            elem.arr = elem.arr[i..$ - (3 - i)];
        }

        auto ft = frontTransversal!(TransverseOptions.assumeNotJagged)(dummies);
        static if (isForwardRange!DummyType) {
            static assert(isForwardRange!(typeof(ft)));
        }

        assert(equal(ft, [1, 2, 3, 4]));

        // Test slicing.
        assert(equal(ft[0..2], [1, 2]));
        assert(equal(ft[1..3], [2, 3]));

        assert(ft.front == ft.moveFront());
        assert(ft.back == ft.moveBack());
        assert(ft.moveAt(1) == ft[1]);


        // Test infiniteness propagation.
        static assert(isInfinite!(typeof(frontTransversal(repeat("foo")))));

        static if (DummyType.r == ReturnBy.Reference) {
            {
                ft.front++;
                scope(exit) ft.front--;
                assert(dummies.front.front == 2);
            }

            {
                ft.front = 5;
                scope(exit) ft.front = 1;
                assert(dummies[0].front == 5);
            }

            {
                ft.back = 88;
                scope(exit) ft.back = 4;
                assert(dummies.back.front == 88);
            }

            {
                ft[1] = 99;
                scope(exit) ft[1] = 2;
                assert(dummies[1].front == 99);
            }
        }
    }
}

/**
   Given a range of ranges, iterate transversally through the the $(D
   n)th element of each of the enclosed ranges. All elements of the
   enclosing range must offer random access.
*/
struct Transversal(Ror,
        TransverseOptions opt = TransverseOptions.assumeJagged)
{
    private alias RangeOfRanges = Unqual!Ror;
    private alias InnerRange = ElementType!RangeOfRanges;
    private alias E = ElementType!InnerRange;

    private void prime()
    {
        static if (opt == TransverseOptions.assumeJagged)
        {
            while (!_input.empty && _input.front.length <= _n)
            {
                _input.popFront();
            }
            static if (isBidirectionalRange!RangeOfRanges)
            {
                while (!_input.empty && _input.back.length <= _n)
                {
                    _input.popBack();
                }
            }
        }
    }

/**
   Construction from an input and an index.
*/
    this(RangeOfRanges input, size_t n)
    {
        _input = input;
        _n = n;
        prime();
        static if (opt == TransverseOptions.enforceNotJagged)
        {
            import std.exception : enforce;

            if (empty) return;
            immutable commonLength = _input.front.length;
            foreach (e; _input)
            {
                enforce(e.length == commonLength);
            }
        }
    }

/**
   Forward range primitives.
*/
    static if (isInfinite!(RangeOfRanges))
    {
        enum bool empty = false;
    }
    else
    {
        @property bool empty()
        {
            return _input.empty;
        }
    }

    /// Ditto
    @property auto ref front()
    {
        assert(!empty);
        return _input.front[_n];
    }

    /// Ditto
    static if (hasMobileElements!InnerRange)
    {
        E moveFront()
        {
            return .moveAt(_input.front, _n);
        }
    }

    /// Ditto
    static if (hasAssignableElements!InnerRange)
    {
        @property auto front(E val)
        {
            _input.front[_n] = val;
        }
    }


    /// Ditto
    void popFront()
    {
        assert(!empty);
        _input.popFront();
        prime();
    }

    /// Ditto
    static if (isForwardRange!RangeOfRanges)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret._input = _input.save;
            return ret;
        }
    }

    static if (isBidirectionalRange!RangeOfRanges)
    {
/**
   Bidirectional primitives. They are offered if $(D
   isBidirectionalRange!RangeOfRanges).
*/
        @property auto ref back()
        {
            return _input.back[_n];
        }

        /// Ditto
        void popBack()
        {
            assert(!empty);
            _input.popBack();
            prime();
        }

        /// Ditto
        static if (hasMobileElements!InnerRange)
        {
            E moveBack()
            {
                return .moveAt(_input.back, _n);
            }
        }

        /// Ditto
        static if (hasAssignableElements!InnerRange)
        {
            @property auto back(E val)
            {
                _input.back[_n] = val;
            }
        }

    }

    static if (isRandomAccessRange!RangeOfRanges &&
            (opt == TransverseOptions.assumeNotJagged ||
                    opt == TransverseOptions.enforceNotJagged))
    {
/**
   Random-access primitive. It is offered if $(D
   isRandomAccessRange!RangeOfRanges && (opt ==
   TransverseOptions.assumeNotJagged || opt ==
   TransverseOptions.enforceNotJagged)).
*/
        auto ref opIndex(size_t n)
        {
            return _input[n][_n];
        }

        /// Ditto
        static if (hasMobileElements!InnerRange)
        {
            E moveAt(size_t n)
            {
                return .moveAt(_input[n], _n);
            }
        }

        /// Ditto
        static if (hasAssignableElements!InnerRange)
        {
            void opIndexAssign(E val, size_t n)
            {
                _input[n][_n] = val;
            }
        }

        /// Ditto
        static if(hasLength!RangeOfRanges)
        {
            @property size_t length()
            {
                return _input.length;
            }

            alias opDollar = length;
        }

/**
   Slicing if offered if $(D RangeOfRanges) supports slicing and all the
   conditions for supporting indexing are met.
*/
        static if (hasSlicing!RangeOfRanges)
        {
            typeof(this) opSlice(size_t lower, size_t upper)
            {
                return typeof(this)(_input[lower..upper], _n);
            }
        }
    }

    auto opSlice() { return this; }

private:
    RangeOfRanges _input;
    size_t _n;
}

/// Ditto
Transversal!(RangeOfRanges, opt) transversal
(TransverseOptions opt = TransverseOptions.assumeJagged, RangeOfRanges)
(RangeOfRanges rr, size_t n)
{
    return typeof(return)(rr, n);
}

///
@safe unittest
{
    import std.algorithm : equal;
    int[][] x = new int[][2];
    x[0] = [1, 2];
    x[1] = [3, 4];
    auto ror = transversal(x, 1);
    assert(equal(ror, [ 2, 4 ][]));
}

@safe unittest
{
    import std.internal.test.dummyrange;

    int[][] x = new int[][2];
    x[0] = [ 1, 2 ];
    x[1] = [3, 4];
    auto ror = transversal!(TransverseOptions.assumeNotJagged)(x, 1);
    auto witness = [ 2, 4 ];
    uint i;
    foreach (e; ror) assert(e == witness[i++]);
    assert(i == 2);
    assert(ror.length == 2);

    static assert(is(Transversal!(immutable int[][])));

    // Make sure ref, assign is being propagated.
    {
        ror.front++;
        scope(exit) ror.front--;
        assert(x[0][1] == 3);
    }
    {
        ror.front = 5;
        scope(exit) ror.front = 2;
        assert(x[0][1] == 5);
        assert(ror.moveFront() == 5);
    }
    {
        ror.back = 999;
        scope(exit) ror.back = 4;
        assert(x[1][1] == 999);
        assert(ror.moveBack() == 999);
    }
    {
        ror[0] = 999;
        scope(exit) ror[0] = 2;
        assert(x[0][1] == 999);
        assert(ror.moveAt(0) == 999);
    }

    // Test w/o ref return.
    alias D = DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Random);
    auto drs = [D.init, D.init];
    foreach(num; 0..10) {
        auto t = transversal!(TransverseOptions.enforceNotJagged)(drs, num);
        assert(t[0] == t[1]);
        assert(t[1] == num + 1);
    }

    static assert(isInfinite!(typeof(transversal(repeat([1,2,3]), 1))));

    // Test slicing.
    auto mat = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]];
    auto mat1 = transversal!(TransverseOptions.assumeNotJagged)(mat, 1)[1..3];
    assert(mat1[0] == 6);
    assert(mat1[1] == 10);
}

struct Transposed(RangeOfRanges)
    if (isForwardRange!RangeOfRanges &&
        isInputRange!(ElementType!RangeOfRanges) &&
        hasAssignableElements!RangeOfRanges)
{
    //alias ElementType = typeof(map!"a.front"(RangeOfRanges.init));

    this(RangeOfRanges input)
    {
        this._input = input;
    }

    @property auto front()
    {
        import std.algorithm : filter, map;
        return _input.save
                     .filter!(a => !a.empty)
                     .map!(a => a.front);
    }

    void popFront()
    {
        // Advance the position of each subrange.
        auto r = _input.save;
        while (!r.empty)
        {
            auto e = r.front;
            if (!e.empty)
            {
                e.popFront();
                r.front = e;
            }

            r.popFront();
        }
    }

    // ElementType opIndex(size_t n)
    // {
    //     return _input[n].front;
    // }

    @property bool empty()
    {
        if (_input.empty) return true;
        foreach (e; _input.save)
        {
            if (!e.empty) return false;
        }
        return true;
    }

    @property Transposed save()
    {
        return Transposed(_input.save);
    }

    auto opSlice() { return this; }

private:
    RangeOfRanges _input;
}

@safe unittest
{
    // Boundary case: transpose of empty range should be empty
    int[][] ror = [];
    assert(transposed(ror).empty);
}

// Issue 9507
unittest
{
    import std.algorithm : equal;

    auto r = [[1,2], [3], [4,5], [], [6]];
    assert(r.transposed.equal!equal([
        [1, 3, 4, 6],
        [2, 5]
    ]));
}

/**
Given a range of ranges, returns a range of ranges where the $(I i)'th subrange
contains the $(I i)'th elements of the original subranges.
 */
Transposed!RangeOfRanges transposed(RangeOfRanges)(RangeOfRanges rr)
    if (isForwardRange!RangeOfRanges &&
        isInputRange!(ElementType!RangeOfRanges) &&
        hasAssignableElements!RangeOfRanges)
{
    return Transposed!RangeOfRanges(rr);
}

/// Example
@safe unittest
{
    import std.algorithm : equal;
    int[][] ror = [
        [1, 2, 3],
        [4, 5, 6]
    ];
    auto xp = transposed(ror);
    assert(equal!"a.equal(b)"(xp, [
        [1, 4],
        [2, 5],
        [3, 6]
    ]));
}

///
@safe unittest
{
    int[][] x = new int[][2];
    x[0] = [1, 2];
    x[1] = [3, 4];
    auto tr = transposed(x);
    int[][] witness = [ [ 1, 3 ], [ 2, 4 ] ];
    uint i;

    foreach (e; tr)
    {
        assert(array(e) == witness[i++]);
    }
}

// Issue 8764
@safe unittest
{
    import std.algorithm : equal;
    ulong[1] t0 = [ 123 ];

    assert(!hasAssignableElements!(typeof(t0[].chunks(1))));
    assert(!is(typeof(transposed(t0[].chunks(1)))));
    assert(is(typeof(transposed(t0[].chunks(1).array()))));

    auto t1 = transposed(t0[].chunks(1).array());
    assert(equal!"a.equal(b)"(t1, [[123]]));
}

/**
This struct takes two ranges, $(D source) and $(D indices), and creates a view
of $(D source) as if its elements were reordered according to $(D indices).
$(D indices) may include only a subset of the elements of $(D source) and
may also repeat elements.

$(D Source) must be a random access range.  The returned range will be
bidirectional or random-access if $(D Indices) is bidirectional or
random-access, respectively.
*/
struct Indexed(Source, Indices)
    if(isRandomAccessRange!Source && isInputRange!Indices &&
        is(typeof(Source.init[ElementType!(Indices).init])))
{
    this(Source source, Indices indices)
    {
        this._source = source;
        this._indices = indices;
    }

    /// Range primitives
    @property auto ref front()
    {
        assert(!empty);
        return _source[_indices.front];
    }

    /// Ditto
    void popFront()
    {
        assert(!empty);
        _indices.popFront();
    }

    static if(isInfinite!Indices)
    {
        enum bool empty = false;
    }
    else
    {
        /// Ditto
        @property bool empty()
        {
            return _indices.empty;
        }
    }

    static if(isForwardRange!Indices)
    {
        /// Ditto
        @property typeof(this) save()
        {
            // Don't need to save _source because it's never consumed.
            return typeof(this)(_source, _indices.save);
        }
    }

    /// Ditto
    static if(hasAssignableElements!Source)
    {
        @property auto ref front(ElementType!Source newVal)
        {
            assert(!empty);
            return _source[_indices.front] = newVal;
        }
    }


    static if(hasMobileElements!Source)
    {
        /// Ditto
        auto moveFront()
        {
            assert(!empty);
            return .moveAt(_source, _indices.front);
        }
    }

    static if(isBidirectionalRange!Indices)
    {
        /// Ditto
        @property auto ref back()
        {
            assert(!empty);
            return _source[_indices.back];
        }

        /// Ditto
        void popBack()
        {
           assert(!empty);
           _indices.popBack();
        }

        /// Ditto
        static if(hasAssignableElements!Source)
        {
            @property auto ref back(ElementType!Source newVal)
            {
                assert(!empty);
                return _source[_indices.back] = newVal;
            }
        }


        static if(hasMobileElements!Source)
        {
            /// Ditto
            auto moveBack()
            {
                assert(!empty);
                return .moveAt(_source, _indices.back);
            }
        }
    }

    static if(hasLength!Indices)
    {
        /// Ditto
         @property size_t length()
        {
            return _indices.length;
        }

        alias opDollar = length;
    }

    static if(isRandomAccessRange!Indices)
    {
        /// Ditto
        auto ref opIndex(size_t index)
        {
            return _source[_indices[index]];
        }

        /// Ditto
        typeof(this) opSlice(size_t a, size_t b)
        {
            return typeof(this)(_source, _indices[a..b]);
        }


        static if(hasAssignableElements!Source)
        {
            /// Ditto
            auto opIndexAssign(ElementType!Source newVal, size_t index)
            {
                return _source[_indices[index]] = newVal;
            }
        }


        static if(hasMobileElements!Source)
        {
            /// Ditto
            auto moveAt(size_t index)
            {
                return .moveAt(_source, _indices[index]);
            }
        }
    }

    // All this stuff is useful if someone wants to index an Indexed
    // without adding a layer of indirection.

    /**
    Returns the source range.
    */
    @property Source source()
    {
        return _source;
    }

    /**
    Returns the indices range.
    */
     @property Indices indices()
    {
        return _indices;
    }

    static if(isRandomAccessRange!Indices)
    {
        /**
        Returns the physical index into the source range corresponding to a
        given logical index.  This is useful, for example, when indexing
        an $(D Indexed) without adding another layer of indirection.

        Examples:
        ---
        auto ind = indexed([1, 2, 3, 4, 5], [1, 3, 4]);
        assert(ind.physicalIndex(0) == 1);
        ---
        */
        size_t physicalIndex(size_t logicalIndex)
        {
            return _indices[logicalIndex];
        }
    }

private:
    Source _source;
    Indices _indices;

}

/// Ditto
Indexed!(Source, Indices) indexed(Source, Indices)(Source source, Indices indices)
{
    return typeof(return)(source, indices);
}

///
@safe unittest
{
    import std.algorithm : equal;
    auto source = [1, 2, 3, 4, 5];
    auto indices = [4, 3, 1, 2, 0, 4];
    auto ind = indexed(source, indices);
    assert(equal(ind, [5, 4, 2, 3, 1, 5]));
    assert(equal(retro(ind), [5, 1, 3, 2, 4, 5]));
}

@safe unittest
{
    {
        auto ind = indexed([1, 2, 3, 4, 5], [1, 3, 4]);
        assert(ind.physicalIndex(0) == 1);
    }

    auto source = [1, 2, 3, 4, 5];
    auto indices = [4, 3, 1, 2, 0, 4];
    auto ind = indexed(source, indices);

    // When elements of indices are duplicated and Source has lvalue elements,
    // these are aliased in ind.
    ind[0]++;
    assert(ind[0] == 6);
    assert(ind[5] == 6);
}

@safe unittest
{
    import std.internal.test.dummyrange;

    foreach(DummyType; AllDummyRanges)
    {
        auto d = DummyType.init;
        auto r = indexed([1, 2, 3, 4, 5], d);
        static assert(propagatesRangeType!(DummyType, typeof(r)));
        static assert(propagatesLength!(DummyType, typeof(r)));
    }
}

/**
This range iterates over fixed-sized chunks of size $(D chunkSize) of a
$(D source) range. $(D Source) must be a forward range.

If $(D !isInfinite!Source) and $(D source.walkLength) is not evenly
divisible by $(D chunkSize), the back element of this range will contain
fewer than $(D chunkSize) elements.
*/
struct Chunks(Source)
    if (isForwardRange!Source)
{
    /// Standard constructor
    this(Source source, size_t chunkSize)
    {
        assert(chunkSize != 0, "Cannot create a Chunk with an empty chunkSize");
        _source = source;
        _chunkSize = chunkSize;
    }

    /// Forward range primitives. Always present.
    @property auto front()
    {
        assert(!empty);
        return _source.save.take(_chunkSize);
    }

    /// Ditto
    void popFront()
    {
        assert(!empty);
        _source.popFrontN(_chunkSize);
    }

    static if (!isInfinite!Source)
        /// Ditto
        @property bool empty()
        {
            return _source.empty;
        }
    else
        // undocumented
        enum empty = false;

    /// Ditto
    @property typeof(this) save()
    {
        return typeof(this)(_source.save, _chunkSize);
    }

    static if (hasLength!Source)
    {
        /// Length. Only if $(D hasLength!Source) is $(D true)
        @property size_t length()
        {
            // Note: _source.length + _chunkSize may actually overflow.
            // We cast to ulong to mitigate the problem on x86 machines.
            // For x64 machines, we just suppose we'll never overflow.
            // The "safe" code would require either an extra branch, or a
            //   modulo operation, which is too expensive for such a rare case
            return cast(size_t)((cast(ulong)(_source.length) + _chunkSize - 1) / _chunkSize);
        }
        //Note: No point in defining opDollar here without slicing.
        //opDollar is defined below in the hasSlicing!Source section
    }

    static if (hasSlicing!Source)
    {
        //Used for various purposes
        private enum hasSliceToEnd = is(typeof(Source.init[_chunkSize .. $]) == Source);

        /**
        Indexing and slicing operations. Provided only if
        $(D hasSlicing!Source) is $(D true).
         */
        auto opIndex(size_t index)
        {
            immutable start = index * _chunkSize;
            immutable end   = start + _chunkSize;

            static if (isInfinite!Source)
                return _source[start .. end];
            else
            {
                import std.algorithm : min;
                immutable len = _source.length;
                assert(start < len, "chunks index out of bounds");
                return _source[start .. min(end, len)];
            }
        }

        /// Ditto
        static if (hasLength!Source)
            typeof(this) opSlice(size_t lower, size_t upper)
            {
                import std.algorithm : min;
                assert(lower <= upper && upper <= length, "chunks slicing index out of bounds");
                immutable len = _source.length;
                return chunks(_source[min(lower * _chunkSize, len) .. min(upper * _chunkSize, len)], _chunkSize);
            }
        else static if (hasSliceToEnd)
            //For slicing an infinite chunk, we need to slice the source to the end.
            typeof(takeExactly(this, 0)) opSlice(size_t lower, size_t upper)
            {
                assert(lower <= upper, "chunks slicing index out of bounds");
                return chunks(_source[lower * _chunkSize .. $], _chunkSize).takeExactly(upper - lower);
            }

        static if (isInfinite!Source)
        {
            static if (hasSliceToEnd)
            {
                private static struct DollarToken{}
                DollarToken opDollar()
                {
                    return DollarToken();
                }
                //Slice to dollar
                typeof(this) opSlice(size_t lower, DollarToken)
                {
                    return typeof(this)(_source[lower * _chunkSize .. $], _chunkSize);
                }
            }
        }
        else
        {
            //Dollar token carries a static type, with no extra information.
            //It can lazily transform into _source.length on algorithmic
            //operations such as : chunks[$/2, $-1];
            private static struct DollarToken
            {
                Chunks!Source* mom;
                @property size_t momLength()
                {
                    return mom.length;
                }
                alias momLength this;
            }
            DollarToken opDollar()
            {
                return DollarToken(&this);
            }

            //Slice overloads optimized for using dollar. Without this, to slice to end, we would...
            //1. Evaluate chunks.length
            //2. Multiply by _chunksSize
            //3. To finally just compare it (with min) to the original length of source (!)
            //These overloads avoid that.
            typeof(this) opSlice(DollarToken, DollarToken)
            {
                static if (hasSliceToEnd)
                    return chunks(_source[$ .. $], _chunkSize);
                else
                {
                    immutable len = _source.length;
                    return chunks(_source[len .. len], _chunkSize);
                }
            }
            typeof(this) opSlice(size_t lower, DollarToken)
            {
                import std.algorithm : min;
                assert(lower <= length, "chunks slicing index out of bounds");
                static if (hasSliceToEnd)
                    return chunks(_source[min(lower * _chunkSize, _source.length) .. $], _chunkSize);
                else
                {
                    immutable len = _source.length;
                    return chunks(_source[min(lower * _chunkSize, len) .. len], _chunkSize);
                }
            }
            typeof(this) opSlice(DollarToken, size_t upper)
            {
                assert(upper == length, "chunks slicing index out of bounds");
                return this[$ .. $];
            }
        }
    }

    //Bidirectional range primitives
    static if (hasSlicing!Source && hasLength!Source)
    {
        /**
        Bidirectional range primitives. Provided only if both
        $(D hasSlicing!Source) and $(D hasLength!Source) are $(D true).
         */
        @property auto back()
        {
            assert(!empty, "back called on empty chunks");
            immutable len = _source.length;
            immutable start = (len - 1) / _chunkSize * _chunkSize;
            return _source[start .. len];
        }

        /// Ditto
        void popBack()
        {
            assert(!empty, "popBack() called on empty chunks");
            immutable end = (_source.length - 1) / _chunkSize * _chunkSize;
            _source = _source[0 .. end];
        }
    }

private:
    Source _source;
    size_t _chunkSize;
}

/// Ditto
Chunks!Source chunks(Source)(Source source, size_t chunkSize)
if (isForwardRange!Source)
{
    return typeof(return)(source, chunkSize);
}

///
@safe unittest
{
    import std.algorithm : equal;
    auto source = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto chunks = chunks(source, 4);
    assert(chunks[0] == [1, 2, 3, 4]);
    assert(chunks[1] == [5, 6, 7, 8]);
    assert(chunks[2] == [9, 10]);
    assert(chunks.back == chunks[2]);
    assert(chunks.front == chunks[0]);
    assert(chunks.length == 3);
    assert(equal(retro(array(chunks)), array(retro(chunks))));
}

@safe unittest
{
    auto source = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto chunks = chunks(source, 4);
    auto chunks2 = chunks.save;
    chunks.popFront();
    assert(chunks[0] == [5, 6, 7, 8]);
    assert(chunks[1] == [9, 10]);
    chunks2.popBack();
    assert(chunks2[1] == [5, 6, 7, 8]);
    assert(chunks2.length == 2);

    static assert(isRandomAccessRange!(typeof(chunks)));
}

@safe unittest
{
    import std.algorithm : equal;

    //Extra toying with slicing and indexing.
    auto chunks1 = [0, 0, 1, 1, 2, 2, 3, 3, 4].chunks(2);
    auto chunks2 = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4].chunks(2);

    assert (chunks1.length == 5);
    assert (chunks2.length == 5);
    assert (chunks1[4] == [4]);
    assert (chunks2[4] == [4, 4]);
    assert (chunks1.back == [4]);
    assert (chunks2.back == [4, 4]);

    assert (chunks1[0 .. 1].equal([[0, 0]]));
    assert (chunks1[0 .. 2].equal([[0, 0], [1, 1]]));
    assert (chunks1[4 .. 5].equal([[4]]));
    assert (chunks2[4 .. 5].equal([[4, 4]]));

    assert (chunks1[0 .. 0].equal((int[][]).init));
    assert (chunks1[5 .. 5].equal((int[][]).init));
    assert (chunks2[5 .. 5].equal((int[][]).init));

    //Fun with opDollar
    assert (chunks1[$ .. $].equal((int[][]).init)); //Quick
    assert (chunks2[$ .. $].equal((int[][]).init)); //Quick
    assert (chunks1[$ - 1 .. $].equal([[4]]));      //Semiquick
    assert (chunks2[$ - 1 .. $].equal([[4, 4]]));   //Semiquick
    assert (chunks1[$ .. 5].equal((int[][]).init)); //Semiquick
    assert (chunks2[$ .. 5].equal((int[][]).init)); //Semiquick

    assert (chunks1[$ / 2 .. $ - 1].equal([[2, 2], [3, 3]])); //Slow
}

unittest
{
    import std.algorithm : equal, filter;

    //ForwardRange
    auto r = filter!"true"([1, 2, 3, 4, 5]).chunks(2);
    assert(equal!"equal(a, b)"(r, [[1, 2], [3, 4], [5]]));

    //InfiniteRange w/o RA
    auto fibsByPairs = recurrence!"a[n-1] + a[n-2]"(1, 1).chunks(2);
    assert(equal!`equal(a, b)`(fibsByPairs.take(2),         [[ 1,  1], [ 2,  3]]));

    //InfiniteRange w/ RA and slicing
    auto odds = sequence!("a[0] + n * a[1]")(1, 2);
    auto oddsByPairs = odds.chunks(2);
    assert(equal!`equal(a, b)`(oddsByPairs.take(2),         [[ 1,  3], [ 5,  7]]));

    //Requires phobos#991 for Sequence to have slice to end
    static assert(hasSlicing!(typeof(odds)));
    assert(equal!`equal(a, b)`(oddsByPairs[3 .. 5],         [[13, 15], [17, 19]]));
    assert(equal!`equal(a, b)`(oddsByPairs[3 .. $].take(2), [[13, 15], [17, 19]]));
}

private struct OnlyResult(T, size_t arity)
{
    private this(Values...)(auto ref Values values)
    {
        this.data = [values];
        this.backIndex = arity;
    }

    bool empty() @property
    {
        return frontIndex >= backIndex;
    }

    T front() @property
    {
        assert(!empty);
        return data[frontIndex];
    }

    void popFront()
    {
        assert(!empty);
        ++frontIndex;
    }

    T back() @property
    {
        assert(!empty);
        return data[backIndex - 1];
    }

    void popBack()
    {
        assert(!empty);
        --backIndex;
    }

    OnlyResult save() @property
    {
        return this;
    }

    size_t length() @property
    {
        return backIndex - frontIndex;
    }

    alias opDollar = length;

    T opIndex(size_t idx)
    {
        // data[i + idx] will not throw a RangeError
        // when i + idx points to elements popped
        // with popBack
        version(assert)
        {
            import core.exception  : RangeError;
            if (idx >= length)
                throw new RangeError;
        }
        return data[frontIndex + idx];
    }

    OnlyResult opSlice()
    {
        return this;
    }

    OnlyResult opSlice(size_t from, size_t to)
    {
        OnlyResult result = this;
        result.frontIndex += from;
        result.backIndex = this.frontIndex + to;

        version(assert)
        {
            import core.exception : RangeError;
            if (to < from || to > length)
                throw new RangeError;
        }
        return result;
    }

    private size_t frontIndex = 0;
    private size_t backIndex = 0;

    // @@@BUG@@@ 10643
    version(none)
    {
        static if(hasElaborateAssign!T)
            private T[arity] data;
        else
            private T[arity] data = void;
    }
    else
        private T[arity] data;
}

// Specialize for single-element results
private struct OnlyResult(T, size_t arity : 1)
{
    @property T front() { assert(!_empty); return _value; }
    @property T back() { assert(!_empty); return _value; }
    @property bool empty() const { return _empty; }
    @property size_t length() const { return !_empty; }
    @property auto save() { return this; }
    void popFront() { assert(!_empty); _empty = true; }
    void popBack() { assert(!_empty); _empty = true; }
    alias opDollar = length;

    private this()(auto ref T value)
    {
        this._value = value;
        this._empty = false;
    }

    T opIndex(size_t i)
    {
        version (assert)
        {
            import core.exception : RangeError;
            if (_empty || i != 0)
                throw new RangeError;
        }
        return _value;
    }

    OnlyResult opSlice()
    {
        return this;
    }

    OnlyResult opSlice(size_t from, size_t to)
    {
        version (assert)
        {
            import core.exception : RangeError;
            if (from > to || to > length)
                throw new RangeError;
        }
        OnlyResult copy = this;
        copy._empty = _empty || from == to;
        return copy;
    }

    private Unqual!T _value;
    private bool _empty = true;
}

// Specialize for the empty range
private struct OnlyResult(T, size_t arity : 0)
{
    private static struct EmptyElementType {}

    bool empty() @property { return true; }
    size_t length() @property { return 0; }
    alias opDollar = length;
    EmptyElementType front() @property { assert(false); }
    void popFront() { assert(false); }
    EmptyElementType back() @property { assert(false); }
    void popBack() { assert(false); }
    OnlyResult save() @property { return this; }

    EmptyElementType opIndex(size_t i)
    {
        version(assert)
        {
            import core.exception : RangeError;
            throw new RangeError;
        }
        assert(false);
    }

    OnlyResult opSlice() { return this; }

    OnlyResult opSlice(size_t from, size_t to)
    {
        version(assert)
        {
            import core.exception : RangeError;
            if (from != 0 || to != 0)
                throw new RangeError;
        }
        return this;
    }
}

/**
Assemble $(D values) into a range that carries all its
elements in-situ.

Useful when a single value or multiple disconnected values
must be passed to an algorithm expecting a range, without
having to perform dynamic memory allocation.

As copying the range means copying all elements, it can be
safely returned from functions. For the same reason, copying
the returned range may be expensive for a large number of arguments.
 */
auto only(Values...)(auto ref Values values)
    if(!is(CommonType!Values == void) || Values.length == 0)
{
    return OnlyResult!(CommonType!Values, Values.length)(values);
}

///
@safe unittest
{
    import std.algorithm;
    import std.uni;

    assert(equal(only('♡'), "♡"));
    assert([1, 2, 3, 4].findSplitBefore(only(3))[0] == [1, 2]);

    assert(only("one", "two", "three").joiner(" ").equal("one two three"));

    string title = "The D Programming Language";
    assert(filter!isUpper(title).map!only().join(".") == "T.D.P.L");
}

unittest
{
    // Verify that the same common type and same arity
    // results in the same template instantiation
    static assert(is(typeof(only(byte.init, int.init)) ==
        typeof(only(int.init, byte.init))));

    static assert(is(typeof(only((const(char)[]).init, string.init)) ==
        typeof(only((const(char)[]).init, (const(char)[]).init))));
}

// Tests the zero-element result
@safe unittest
{
    import std.algorithm : equal;

    auto emptyRange = only();

    alias EmptyRange = typeof(emptyRange);
    static assert(isInputRange!EmptyRange);
    static assert(isForwardRange!EmptyRange);
    static assert(isBidirectionalRange!EmptyRange);
    static assert(isRandomAccessRange!EmptyRange);
    static assert(hasLength!EmptyRange);
    static assert(hasSlicing!EmptyRange);

    assert(emptyRange.empty);
    assert(emptyRange.length == 0);
    assert(emptyRange.equal(emptyRange[]));
    assert(emptyRange.equal(emptyRange.save));
    assert(emptyRange[0 .. 0].equal(emptyRange));
}

// Tests the single-element result
@safe unittest
{
    import std.algorithm : equal;
    import std.typecons : tuple;
    foreach (x; tuple(1, '1', 1.0, "1", [1]))
    {
        auto a = only(x);
        typeof(x)[] e = [];
        assert(a.front == x);
        assert(a.back == x);
        assert(!a.empty);
        assert(a.length == 1);
        assert(equal(a, a[]));
        assert(equal(a, a[0..1]));
        assert(equal(a[0..0], e));
        assert(equal(a[1..1], e));
        assert(a[0] == x);

        auto b = a.save;
        assert(equal(a, b));
        a.popFront();
        assert(a.empty && a.length == 0 && a[].empty);
        b.popBack();
        assert(b.empty && b.length == 0 && b[].empty);

        alias A = typeof(a);
        static assert(isInputRange!A);
        static assert(isForwardRange!A);
        static assert(isBidirectionalRange!A);
        static assert(isRandomAccessRange!A);
        static assert(hasLength!A);
        static assert(hasSlicing!A);
    }

    auto imm = only!(immutable int)(1);
    immutable int[] imme = [];
    assert(imm.front == 1);
    assert(imm.back == 1);
    assert(!imm.empty);
    assert(imm.init.empty); // Issue 13441
    assert(imm.length == 1);
    assert(equal(imm, imm[]));
    assert(equal(imm, imm[0..1]));
    assert(equal(imm[0..0], imme));
    assert(equal(imm[1..1], imme));
    assert(imm[0] == 1);
}

// Tests multiple-element results
@safe unittest
{
    import std.algorithm : equal, joiner;
    static assert(!__traits(compiles, only(1, "1")));

    auto nums = only!(byte, uint, long)(1, 2, 3);
    static assert(is(ElementType!(typeof(nums)) == long));
    assert(nums.length == 3);

    foreach(i; 0 .. 3)
        assert(nums[i] == i + 1);

    auto saved = nums.save;

    foreach(i; 1 .. 4)
    {
        assert(nums.front == nums[0]);
        assert(nums.front == i);
        nums.popFront();
        assert(nums.length == 3 - i);
    }

    assert(nums.empty);

    assert(saved.equal(only(1, 2, 3)));
    assert(saved.equal(saved[]));
    assert(saved[0 .. 1].equal(only(1)));
    assert(saved[0 .. 2].equal(only(1, 2)));
    assert(saved[0 .. 3].equal(saved));
    assert(saved[1 .. 3].equal(only(2, 3)));
    assert(saved[2 .. 3].equal(only(3)));
    assert(saved[0 .. 0].empty);
    assert(saved[3 .. 3].empty);

    alias data = TypeTuple!("one", "two", "three", "four");
    static joined =
        ["one two", "one two three", "one two three four"];
    string[] joinedRange = joined;

    foreach(argCount; TypeTuple!(2, 3, 4))
    {
        auto values = only(data[0 .. argCount]);
        alias Values = typeof(values);
        static assert(is(ElementType!Values == string));
        static assert(isInputRange!Values);
        static assert(isForwardRange!Values);
        static assert(isBidirectionalRange!Values);
        static assert(isRandomAccessRange!Values);
        static assert(hasSlicing!Values);
        static assert(hasLength!Values);

        assert(values.length == argCount);
        assert(values[0 .. $].equal(values[0 .. values.length]));
        assert(values.joiner(" ").equal(joinedRange.front));
        joinedRange.popFront();
    }

    assert(saved.retro.equal(only(3, 2, 1)));
    assert(saved.length == 3);

    assert(saved.back == 3);
    saved.popBack();
    assert(saved.length == 2);
    assert(saved.back == 2);

    assert(saved.front == 1);
    saved.popFront();
    assert(saved.length == 1);
    assert(saved.front == 2);

    saved.popBack();
    assert(saved.empty);

    auto imm = only!(immutable int, immutable int)(42, 24);
    alias Imm = typeof(imm);
    static assert(is(ElementType!Imm == immutable(int)));
    assert(!imm.empty);
    assert(imm.init.empty); // Issue 13441
    assert(imm.front == 42);
    imm.popFront();
    assert(imm.front == 24);
    imm.popFront();
    assert(imm.empty);

    static struct Test { int* a; }
    immutable(Test) test;
    cast(void)only(test, test); // Works with mutable indirection
}

/**
Iterate over $(D range) with an attached index variable.

Each element is a $(XREF typecons, Tuple) containing the index
and the element, in that order, where the index member is named $(D index)
and the element member is named $(D value).

The index starts at $(D start) and is incremented by one on every iteration.

Bidirectionality is propagated only if $(D range) has length.

Overflow:
If $(D range) has length, then it is an error to pass a value for $(D start)
so that $(D start + range.length) is bigger than $(D Enumerator.max), thus it is
ensured that overflow cannot happen.

If $(D range) does not have length, and $(D popFront) is called when
$(D front.index == Enumerator.max), the index will overflow and
continue from $(D Enumerator.min).

Examples:
Useful for using $(D foreach) with an index loop variable:
----
    import std.stdio : stdin, stdout;
    import std.range : enumerate;

    foreach (lineNum, line; stdin.byLine().enumerate(1))
        stdout.writefln("line #%s: %s", lineNum, line);
----
*/
auto enumerate(Enumerator = size_t, Range)(Range range, Enumerator start = 0)
    if (isIntegral!Enumerator && isInputRange!Range)
in
{
    static if (hasLength!Range)
    {
        // TODO: core.checkedint supports mixed signedness yet?
        import core.checkedint : adds, addu;
        import std.conv : ConvException, to;
        import core.exception : RangeError;

        alias LengthType = typeof(range.length);
        bool overflow;
        static if(isSigned!Enumerator && isSigned!LengthType)
            auto result = adds(start, range.length, overflow);
        else static if(isSigned!Enumerator)
        {
            Largest!(Enumerator, Signed!LengthType) signedLength;
            try signedLength = to!(typeof(signedLength))(range.length);
            catch(ConvException)
                overflow = true;
            catch(Exception)
                assert(false);

            auto result = adds(start, signedLength, overflow);
        }
        else
        {
            static if(isSigned!LengthType)
                assert(range.length >= 0);
            auto result = addu(start, range.length, overflow);
        }

        if (overflow || result > Enumerator.max)
            throw new RangeError("overflow in `start + range.length`");
    }
}
body
{
    // TODO: Relax isIntegral!Enumerator to allow user-defined integral types
    static struct Result
    {
        import std.typecons : Tuple;

        private:
        alias ElemType = Tuple!(Enumerator, "index", ElementType!Range, "value");
        Range range;
        Enumerator index;

        public:
        ElemType front() @property
        {
            assert(!range.empty);
            return typeof(return)(index, range.front);
        }

        static if (isInfinite!Range)
            enum bool empty = false;
        else
        {
            bool empty() @property
            {
                return range.empty;
            }
        }

        void popFront()
        {
            assert(!range.empty);
            range.popFront();
            ++index; // When !hasLength!Range, overflow is expected
        }

        static if (isForwardRange!Range)
        {
            Result save() @property
            {
                return typeof(return)(range.save, index);
            }
        }

        static if (hasLength!Range)
        {
            size_t length() @property
            {
                return range.length;
            }

            alias opDollar = length;

            static if (isBidirectionalRange!Range)
            {
                ElemType back() @property
                {
                    assert(!range.empty);
                    return typeof(return)(cast(Enumerator)(index + range.length - 1), range.back);
                }

                void popBack()
                {
                    assert(!range.empty);
                    range.popBack();
                }
            }
        }

        static if (isRandomAccessRange!Range)
        {
             ElemType opIndex(size_t i)
             {
                return typeof(return)(cast(Enumerator)(index + i), range[i]);
             }
        }

        static if (hasSlicing!Range)
        {
            static if (hasLength!Range)
            {
                Result opSlice(size_t i, size_t j)
                {
                    return typeof(return)(range[i .. j], cast(Enumerator)(index + i));
                }
            }
            else
            {
                static struct DollarToken {}
                enum opDollar = DollarToken.init;

                Result opSlice(size_t i, DollarToken)
                {
                    return typeof(return)(range[i .. $], cast(Enumerator)(index + i));
                }

                auto opSlice(size_t i, size_t j)
                {
                    return this[i .. $].takeExactly(j - 1);
                }
            }
        }
    }

    return Result(range, start);
}

/// Can start enumeration from a negative position:
pure @safe nothrow unittest
{
    import std.array : assocArray;
    import std.range : enumerate;

    bool[int] aa = true.repeat(3).enumerate(-1).assocArray();
    assert(aa[-1]);
    assert(aa[0]);
    assert(aa[1]);
}

pure @safe nothrow unittest
{
    import std.internal.test.dummyrange;

    import std.typecons : tuple;

    static struct HasSlicing
    {
        typeof(this) front() @property { return typeof(this).init; }
        bool empty() @property { return true; }
        void popFront() {}

        typeof(this) opSlice(size_t, size_t)
        {
            return typeof(this)();
        }
    }

    foreach (DummyType; TypeTuple!(AllDummyRanges, HasSlicing))
    {
        alias R = typeof(enumerate(DummyType.init));
        static assert(isInputRange!R);
        static assert(isForwardRange!R == isForwardRange!DummyType);
        static assert(isRandomAccessRange!R == isRandomAccessRange!DummyType);
        static assert(!hasAssignableElements!R);

        static if (hasLength!DummyType)
        {
            static assert(hasLength!R);
            static assert(isBidirectionalRange!R ==
                isBidirectionalRange!DummyType);
        }

        static assert(hasSlicing!R == hasSlicing!DummyType);
    }

    static immutable values = ["zero", "one", "two", "three"];
    auto enumerated = values[].enumerate();
    assert(!enumerated.empty);
    assert(enumerated.front == tuple(0, "zero"));
    assert(enumerated.back == tuple(3, "three"));

    typeof(enumerated) saved = enumerated.save;
    saved.popFront();
    assert(enumerated.front == tuple(0, "zero"));
    assert(saved.front == tuple(1, "one"));
    assert(saved.length == enumerated.length - 1);
    saved.popBack();
    assert(enumerated.back == tuple(3, "three"));
    assert(saved.back == tuple(2, "two"));
    saved.popFront();
    assert(saved.front == tuple(2, "two"));
    assert(saved.back == tuple(2, "two"));
    saved.popFront();
    assert(saved.empty);

    size_t control = 0;
    foreach (i, v; enumerated)
    {
        static assert(is(typeof(i) == size_t));
        static assert(is(typeof(v) == typeof(values[0])));
        assert(i == control);
        assert(v == values[i]);
        assert(tuple(i, v) == enumerated[i]);
        ++control;
    }

    assert(enumerated[0 .. $].front == tuple(0, "zero"));
    assert(enumerated[$ - 1 .. $].front == tuple(3, "three"));

    foreach(i; 0 .. 10)
    {
        auto shifted = values[0 .. 2].enumerate(i);
        assert(shifted.front == tuple(i, "zero"));
        assert(shifted[0] == shifted.front);

        auto next = tuple(i + 1, "one");
        assert(shifted[1] == next);
        shifted.popFront();
        assert(shifted.front == next);
        shifted.popFront();
        assert(shifted.empty);
    }

    foreach(T; TypeTuple!(ubyte, byte, uint, int))
    {
        auto inf = 42.repeat().enumerate(T.max);
        alias Inf = typeof(inf);
        static assert(isInfinite!Inf);
        static assert(hasSlicing!Inf);

        // test overflow
        assert(inf.front == tuple(T.max, 42));
        inf.popFront();
        assert(inf.front == tuple(T.min, 42));

        // test slicing
        inf = inf[42 .. $];
        assert(inf.front == tuple(T.min + 42, 42));
        auto window = inf[0 .. 2];
        assert(window.length == 1);
        assert(window.front == inf.front);
        window.popFront();
        assert(window.empty);
    }
}

pure @safe unittest
{
    import std.algorithm : equal;
    static immutable int[] values = [0, 1, 2, 3, 4];
    foreach(T; TypeTuple!(ubyte, ushort, uint, ulong))
    {
        auto enumerated = values.enumerate!T();
        static assert(is(typeof(enumerated.front.index) == T));
        assert(enumerated.equal(values[].zip(values)));

        foreach(T i; 0 .. 5)
        {
            auto subset = values[cast(size_t)i .. $];
            auto offsetEnumerated = subset.enumerate(i);
            static assert(is(typeof(enumerated.front.index) == T));
            assert(offsetEnumerated.equal(subset.zip(subset)));
        }
    }
}

version(none) // @@@BUG@@@ 10939
{
    // Re-enable (or remove) if 10939 is resolved.
    /+pure+/ unittest // Impure because of std.conv.to
    {
        import core.exception : RangeError;
        import std.exception : assertNotThrown, assertThrown;

        static immutable values = [42];

        static struct SignedLengthRange
        {
            immutable(int)[] _values = values;

            int front() @property { assert(false); }
            bool empty() @property { assert(false); }
            void popFront() { assert(false); }

            int length() @property
            {
                return cast(int)_values.length;
            }
        }

        SignedLengthRange svalues;
        foreach(Enumerator; TypeTuple!(ubyte, byte, ushort, short, uint, int, ulong, long))
        {
            assertThrown!RangeError(values[].enumerate!Enumerator(Enumerator.max));
            assertNotThrown!RangeError(values[].enumerate!Enumerator(Enumerator.max - values.length));
            assertThrown!RangeError(values[].enumerate!Enumerator(Enumerator.max - values.length + 1));

            assertThrown!RangeError(svalues.enumerate!Enumerator(Enumerator.max));
            assertNotThrown!RangeError(svalues.enumerate!Enumerator(Enumerator.max - values.length));
            assertThrown!RangeError(svalues.enumerate!Enumerator(Enumerator.max - values.length + 1));
        }

        foreach(Enumerator; TypeTuple!(byte, short, int))
        {
            assertThrown!RangeError(repeat(0, uint.max).enumerate!Enumerator());
        }

        assertNotThrown!RangeError(repeat(0, uint.max).enumerate!long());
    }
}

/**
  Returns true if $(D fn) accepts variables of type T1 and T2 in any order.
  The following code should compile:
  ---
  T1 foo();
  T2 bar();

  fn(foo(), bar());
  fn(bar(), foo());
  ---
*/
template isTwoWayCompatible(alias fn, T1, T2)
{
    enum isTwoWayCompatible = is(typeof( (){
            T1 foo();
            T2 bar();

            fn(foo(), bar());
            fn(bar(), foo());
        }
    ));
}


/**
   Policy used with the searching primitives $(D lowerBound), $(D
   upperBound), and $(D equalRange) of $(LREF SortedRange) below.
 */
enum SearchPolicy
{
    /**
       Searches in a linear fashion.
    */
    linear,

    /**
       Searches with a step that is grows linearly (1, 2, 3,...)
       leading to a quadratic search schedule (indexes tried are 0, 1,
       3, 6, 10, 15, 21, 28,...) Once the search overshoots its target,
       the remaining interval is searched using binary search. The
       search is completed in $(BIGOH sqrt(n)) time. Use it when you
       are reasonably confident that the value is around the beginning
       of the range.
    */
    trot,

    /**
       Performs a $(LUCKY galloping search algorithm), i.e. searches
       with a step that doubles every time, (1, 2, 4, 8, ...)  leading
       to an exponential search schedule (indexes tried are 0, 1, 3,
       7, 15, 31, 63,...) Once the search overshoots its target, the
       remaining interval is searched using binary search. A value is
       found in $(BIGOH log(n)) time.
    */
        gallop,

    /**
       Searches using a classic interval halving policy. The search
       starts in the middle of the range, and each search step cuts
       the range in half. This policy finds a value in $(BIGOH log(n))
       time but is less cache friendly than $(D gallop) for large
       ranges. The $(D binarySearch) policy is used as the last step
       of $(D trot), $(D gallop), $(D trotBackwards), and $(D
       gallopBackwards) strategies.
    */
        binarySearch,

    /**
       Similar to $(D trot) but starts backwards. Use it when
       confident that the value is around the end of the range.
    */
        trotBackwards,

    /**
       Similar to $(D gallop) but starts backwards. Use it when
       confident that the value is around the end of the range.
    */
        gallopBackwards
        }

/**
Represents a sorted range. In addition to the regular range
primitives, supports additional operations that take advantage of the
ordering, such as merge and binary search. To obtain a $(D
SortedRange) from an unsorted range $(D r), use $(XREF algorithm,
sort) which sorts $(D r) in place and returns the corresponding $(D
SortedRange). To construct a $(D SortedRange) from a range $(D r) that
is known to be already sorted, use $(LREF assumeSorted) described
below.
*/
struct SortedRange(Range, alias pred = "a < b")
if (isInputRange!Range)
{
    private import std.functional : binaryFun;

    private alias predFun = binaryFun!pred;
    private bool geq(L, R)(L lhs, R rhs)
    {
        return !predFun(lhs, rhs);
    }
    private bool gt(L, R)(L lhs, R rhs)
    {
        return predFun(rhs, lhs);
    }
    private Range _input;

    // Undocummented because a clearer way to invoke is by calling
    // assumeSorted.
    this(Range input)
    out
    {
        // moved out of the body as a workaround for Issue 12661
        dbgVerifySorted();
    }
    body
    {
        this._input = input;
    }

    // Assertion only.
    private void dbgVerifySorted()
    {
        if(!__ctfe)
        debug
        {
            import core.bitop : bsr;
            import std.conv : text;
            import std.random : MinstdRand, uniform;

            static if (isRandomAccessRange!Range)
            {
                import std.algorithm : isSorted;
                // Check the sortedness of the input
                if (this._input.length < 2) return;
                immutable size_t msb = bsr(this._input.length) + 1;
                assert(msb > 0 && msb <= this._input.length);
                immutable step = this._input.length / msb;
                static MinstdRand gen;
                immutable start = uniform(0, step, gen);
                auto st = stride(this._input, step);
                static if (is(typeof(text(st))))
                {
                    assert(isSorted!pred(st), text(st));
                }
                else
                {
                    assert(isSorted!pred(st));
                }
            }
        }
    }

    /// Range primitives.
    @property bool empty()             //const
    {
        return this._input.empty;
    }

    /// Ditto
    static if (isForwardRange!Range)
    @property auto save()
    {
        // Avoid the constructor
        typeof(this) result = this;
        result._input = _input.save;
        return result;
    }

    /// Ditto
    @property auto ref front()
    {
        return _input.front;
    }

    /// Ditto
    void popFront()
    {
        _input.popFront();
    }

    /// Ditto
    static if (isBidirectionalRange!Range)
    {
        @property auto ref back()
        {
            return _input.back;
        }

        /// Ditto
        void popBack()
        {
            _input.popBack();
        }
    }

    /// Ditto
    static if (isRandomAccessRange!Range)
        auto ref opIndex(size_t i)
        {
            return _input[i];
        }

    /// Ditto
    static if (hasSlicing!Range)
        auto opSlice(size_t a, size_t b)
        {
            assert(a <= b);
            typeof(this) result = this;
            result._input = _input[a .. b];// skip checking
            return result;
        }

    /// Ditto
    static if (hasLength!Range)
    {
        @property size_t length()          //const
        {
            return _input.length;
        }
        alias opDollar = length;
    }

/**
   Releases the controlled range and returns it.
*/
    auto release()
    {
        import std.algorithm : move;
        return move(_input);
    }

    // Assuming a predicate "test" that returns 0 for a left portion
    // of the range and then 1 for the rest, returns the index at
    // which the first 1 appears. Used internally by the search routines.
    private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
    if (sp == SearchPolicy.binarySearch && isRandomAccessRange!Range)
    {
        size_t first = 0, count = _input.length;
        while (count > 0)
        {
            immutable step = count / 2, it = first + step;
            if (!test(_input[it], v))
            {
                first = it + 1;
                count -= step + 1;
            }
            else
            {
                count = step;
            }
        }
        return first;
    }

    // Specialization for trot and gallop
    private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
    if ((sp == SearchPolicy.trot || sp == SearchPolicy.gallop)
        && isRandomAccessRange!Range)
    {
        if (empty || test(front, v)) return 0;
        immutable count = length;
        if (count == 1) return 1;
        size_t below = 0, above = 1, step = 2;
        while (!test(_input[above], v))
        {
            // Still too small, update below and increase gait
            below = above;
            immutable next = above + step;
            if (next >= count)
            {
                // Overshot - the next step took us beyond the end. So
                // now adjust next and simply exit the loop to do the
                // binary search thingie.
                above = count;
                break;
            }
            // Still in business, increase step and continue
            above = next;
            static if (sp == SearchPolicy.trot)
                ++step;
            else
                step <<= 1;
        }
        return below + this[below .. above].getTransitionIndex!(
            SearchPolicy.binarySearch, test, V)(v);
    }

    // Specialization for trotBackwards and gallopBackwards
    private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
    if ((sp == SearchPolicy.trotBackwards || sp == SearchPolicy.gallopBackwards)
        && isRandomAccessRange!Range)
    {
        immutable count = length;
        if (empty || !test(back, v)) return count;
        if (count == 1) return 0;
        size_t below = count - 2, above = count - 1, step = 2;
        while (test(_input[below], v))
        {
            // Still too large, update above and increase gait
            above = below;
            if (below < step)
            {
                // Overshot - the next step took us beyond the end. So
                // now adjust next and simply fall through to do the
                // binary search thingie.
                below = 0;
                break;
            }
            // Still in business, increase step and continue
            below -= step;
            static if (sp == SearchPolicy.trot)
                ++step;
            else
                step <<= 1;
        }
        return below + this[below .. above].getTransitionIndex!(
            SearchPolicy.binarySearch, test, V)(v);
    }

// lowerBound
/**
   This function uses a search with policy $(D sp) to find the
   largest left subrange on which $(D pred(x, value)) is $(D true) for
   all $(D x) (e.g., if $(D pred) is "less than", returns the portion of
   the range with elements strictly smaller than $(D value)). The search
   schedule and its complexity are documented in
   $(LREF SearchPolicy).  See also STL's
   $(WEB sgi.com/tech/stl/lower_bound.html, lower_bound).

   Example:
   ----
   auto a = assumeSorted([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ]);
   auto p = a.lowerBound(4);
   assert(equal(p, [ 0, 1, 2, 3 ]));
   ----
*/
    auto lowerBound(SearchPolicy sp = SearchPolicy.binarySearch, V)(V value)
    if (isTwoWayCompatible!(predFun, ElementType!Range, V)
         && hasSlicing!Range)
    {
        return this[0 .. getTransitionIndex!(sp, geq)(value)];
    }

// upperBound
/**
This function searches with policy $(D sp) to find the largest right
subrange on which $(D pred(value, x)) is $(D true) for all $(D x)
(e.g., if $(D pred) is "less than", returns the portion of the range
with elements strictly greater than $(D value)). The search schedule
and its complexity are documented in $(LREF SearchPolicy).

For ranges that do not offer random access, $(D SearchPolicy.linear)
is the only policy allowed (and it must be specified explicitly lest it exposes
user code to unexpected inefficiencies). For random-access searches, all
policies are allowed, and $(D SearchPolicy.binarySearch) is the default.

See_Also: STL's $(WEB sgi.com/tech/stl/lower_bound.html,upper_bound).

Example:
----
auto a = assumeSorted([ 1, 2, 3, 3, 3, 4, 4, 5, 6 ]);
auto p = a.upperBound(3);
assert(equal(p, [4, 4, 5, 6]));
----
*/
    auto upperBound(SearchPolicy sp = SearchPolicy.binarySearch, V)(V value)
    if (isTwoWayCompatible!(predFun, ElementType!Range, V))
    {
        static assert(hasSlicing!Range || sp == SearchPolicy.linear,
            "Specify SearchPolicy.linear explicitly for "
            ~ typeof(this).stringof);
        static if (sp == SearchPolicy.linear)
        {
            for (; !_input.empty && !predFun(value, _input.front);
                 _input.popFront())
            {
            }
            return this;
        }
        else
        {
            return this[getTransitionIndex!(sp, gt)(value) .. length];
        }
    }

// equalRange
/**
   Returns the subrange containing all elements $(D e) for which both $(D
   pred(e, value)) and $(D pred(value, e)) evaluate to $(D false) (e.g.,
   if $(D pred) is "less than", returns the portion of the range with
   elements equal to $(D value)). Uses a classic binary search with
   interval halving until it finds a value that satisfies the condition,
   then uses $(D SearchPolicy.gallopBackwards) to find the left boundary
   and $(D SearchPolicy.gallop) to find the right boundary. These
   policies are justified by the fact that the two boundaries are likely
   to be near the first found value (i.e., equal ranges are relatively
   small). Completes the entire search in $(BIGOH log(n)) time. See also
   STL's $(WEB sgi.com/tech/stl/equal_range.html, equal_range).

   Example:
   ----
   auto a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
   auto r = equalRange(a, 3);
   assert(equal(r, [ 3, 3, 3 ]));
   ----
*/
    auto equalRange(V)(V value)
    if (isTwoWayCompatible!(predFun, ElementType!Range, V)
        && isRandomAccessRange!Range)
    {
        size_t first = 0, count = _input.length;
        while (count > 0)
        {
            immutable step = count / 2;
            auto it = first + step;
            if (predFun(_input[it], value))
            {
                // Less than value, bump left bound up
                first = it + 1;
                count -= step + 1;
            }
            else if (predFun(value, _input[it]))
            {
                // Greater than value, chop count
                count = step;
            }
            else
            {
                // Equal to value, do binary searches in the
                // leftover portions
                // Gallop towards the left end as it's likely nearby
                immutable left = first
                    + this[first .. it]
                    .lowerBound!(SearchPolicy.gallopBackwards)(value).length;
                first += count;
                // Gallop towards the right end as it's likely nearby
                immutable right = first
                    - this[it + 1 .. first]
                    .upperBound!(SearchPolicy.gallop)(value).length;
                return this[left .. right];
            }
        }
        return this.init;
    }

// trisect
/**
Returns a tuple $(D r) such that $(D r[0]) is the same as the result
of $(D lowerBound(value)), $(D r[1]) is the same as the result of $(D
equalRange(value)), and $(D r[2]) is the same as the result of $(D
upperBound(value)). The call is faster than computing all three
separately. Uses a search schedule similar to $(D
equalRange). Completes the entire search in $(BIGOH log(n)) time.

Example:
----
auto a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
auto r = assumeSorted(a).trisect(3);
assert(equal(r[0], [ 1, 2 ]));
assert(equal(r[1], [ 3, 3, 3 ]));
assert(equal(r[2], [ 4, 4, 5, 6 ]));
----
*/
    auto trisect(V)(V value)
    if (isTwoWayCompatible!(predFun, ElementType!Range, V)
        && isRandomAccessRange!Range)
    {
        import std.typecons : tuple;
        size_t first = 0, count = _input.length;
        while (count > 0)
        {
            immutable step = count / 2;
            auto it = first + step;
            if (predFun(_input[it], value))
            {
                // Less than value, bump left bound up
                first = it + 1;
                count -= step + 1;
            }
            else if (predFun(value, _input[it]))
            {
                // Greater than value, chop count
                count = step;
            }
            else
            {
                // Equal to value, do binary searches in the
                // leftover portions
                // Gallop towards the left end as it's likely nearby
                immutable left = first
                    + this[first .. it]
                    .lowerBound!(SearchPolicy.gallopBackwards)(value).length;
                first += count;
                // Gallop towards the right end as it's likely nearby
                immutable right = first
                    - this[it + 1 .. first]
                    .upperBound!(SearchPolicy.gallop)(value).length;
                return tuple(this[0 .. left], this[left .. right],
                        this[right .. length]);
            }
        }
        // No equal element was found
        return tuple(this[0 .. first], this.init, this[first .. length]);
    }

// contains
/**
Returns $(D true) if and only if $(D value) can be found in $(D
range), which is assumed to be sorted. Performs $(BIGOH log(r.length))
evaluations of $(D pred). See also STL's $(WEB
sgi.com/tech/stl/binary_search.html, binary_search).
 */

    bool contains(V)(V value)
    if (isRandomAccessRange!Range)
    {
        size_t first = 0, count = _input.length;
        while (count > 0)
        {
            immutable step = count / 2, it = first + step;
            if (predFun(_input[it], value))
            {
                // Less than value, bump left bound up
                first = it + 1;
                count -= step + 1;
            }
            else if (predFun(value, _input[it]))
            {
                // Greater than value, chop count
                count = step;
            }
            else
            {
                // Found!!!
                return true;
            }
        }
        return false;
    }
}

///
unittest
{
    import std.algorithm : sort;
    auto a = [ 1, 2, 3, 42, 52, 64 ];
    auto r = assumeSorted(a);
    assert(r.contains(3));
    assert(!r.contains(32));
    auto r1 = sort!"a > b"(a);
    assert(r1.contains(3));
    assert(!r1.contains(32));
    assert(r1.release() == [ 64, 52, 42, 3, 2, 1 ]);
}

/**
$(D SortedRange) could accept ranges weaker than random-access, but it
is unable to provide interesting functionality for them. Therefore,
$(D SortedRange) is currently restricted to random-access ranges.

No copy of the original range is ever made. If the underlying range is
changed concurrently with its corresponding $(D SortedRange) in ways
that break its sortedness, $(D SortedRange) will work erratically.
*/
@safe unittest
{
    import std.algorithm : swap;
    auto a = [ 1, 2, 3, 42, 52, 64 ];
    auto r = assumeSorted(a);
    assert(r.contains(42));
    swap(a[3], a[5]);         // illegal to break sortedness of original range
    assert(!r.contains(42));  // passes although it shouldn't
}

@safe unittest
{
    import std.algorithm : equal;

    auto a = [ 10, 20, 30, 30, 30, 40, 40, 50, 60 ];
    auto r = assumeSorted(a).trisect(30);
    assert(equal(r[0], [ 10, 20 ]));
    assert(equal(r[1], [ 30, 30, 30 ]));
    assert(equal(r[2], [ 40, 40, 50, 60 ]));

    r = assumeSorted(a).trisect(35);
    assert(equal(r[0], [ 10, 20, 30, 30, 30 ]));
    assert(r[1].empty);
    assert(equal(r[2], [ 40, 40, 50, 60 ]));
}

@safe unittest
{
    import std.algorithm : equal;
    auto a = [ "A", "AG", "B", "E", "F" ];
    auto r = assumeSorted!"cmp(a,b) < 0"(a).trisect("B"w);
    assert(equal(r[0], [ "A", "AG" ]));
    assert(equal(r[1], [ "B" ]));
    assert(equal(r[2], [ "E", "F" ]));
    r = assumeSorted!"cmp(a,b) < 0"(a).trisect("A"d);
    assert(r[0].empty);
    assert(equal(r[1], [ "A" ]));
    assert(equal(r[2], [ "AG", "B", "E", "F" ]));
}

@safe unittest
{
    import std.algorithm : equal;
    static void test(SearchPolicy pol)()
    {
        auto a = [ 1, 2, 3, 42, 52, 64 ];
        auto r = assumeSorted(a);
        assert(equal(r.lowerBound(42), [1, 2, 3]));

        assert(equal(r.lowerBound!(pol)(42), [1, 2, 3]));
        assert(equal(r.lowerBound!(pol)(41), [1, 2, 3]));
        assert(equal(r.lowerBound!(pol)(43), [1, 2, 3, 42]));
        assert(equal(r.lowerBound!(pol)(51), [1, 2, 3, 42]));
        assert(equal(r.lowerBound!(pol)(3), [1, 2]));
        assert(equal(r.lowerBound!(pol)(55), [1, 2, 3, 42, 52]));
        assert(equal(r.lowerBound!(pol)(420), a));
        assert(equal(r.lowerBound!(pol)(0), a[0 .. 0]));

        assert(equal(r.upperBound!(pol)(42), [52, 64]));
        assert(equal(r.upperBound!(pol)(41), [42, 52, 64]));
        assert(equal(r.upperBound!(pol)(43), [52, 64]));
        assert(equal(r.upperBound!(pol)(51), [52, 64]));
        assert(equal(r.upperBound!(pol)(53), [64]));
        assert(equal(r.upperBound!(pol)(55), [64]));
        assert(equal(r.upperBound!(pol)(420), a[0 .. 0]));
        assert(equal(r.upperBound!(pol)(0), a));
    }

    test!(SearchPolicy.trot)();
    test!(SearchPolicy.gallop)();
    test!(SearchPolicy.trotBackwards)();
    test!(SearchPolicy.gallopBackwards)();
    test!(SearchPolicy.binarySearch)();
}

@safe unittest
{
    // Check for small arrays
    int[] a;
    auto r = assumeSorted(a);
    a = [ 1 ];
    r = assumeSorted(a);
    a = [ 1, 2 ];
    r = assumeSorted(a);
    a = [ 1, 2, 3 ];
    r = assumeSorted(a);
}

@safe unittest
{
    import std.algorithm : swap;
    auto a = [ 1, 2, 3, 42, 52, 64 ];
    auto r = assumeSorted(a);
    assert(r.contains(42));
    swap(a[3], a[5]);                  // illegal to break sortedness of original range
    assert(!r.contains(42));            // passes although it shouldn't
}

@safe unittest
{
    immutable(int)[] arr = [ 1, 2, 3 ];
    auto s = assumeSorted(arr);
}

// Test on an input range
unittest
{
    import std.stdio, std.file, std.path, std.conv, std.uuid;
    auto name = buildPath(tempDir(), "test.std.range.line-" ~ text(__LINE__) ~
                          "." ~ randomUUID().toString());
    auto f = File(name, "w");
    scope(exit) if (exists(name)) remove(name);
    // write a sorted range of lines to the file
    f.write("abc\ndef\nghi\njkl");
    f.close();
    f.open(name, "r");
    auto r = assumeSorted(f.byLine());
    auto r1 = r.upperBound!(SearchPolicy.linear)("def");
    assert(r1.front == "ghi", r1.front);
    f.close();
}

/**
Assumes $(D r) is sorted by predicate $(D pred) and returns the
corresponding $(D SortedRange!(pred, R)) having $(D r) as support. To
keep the checking costs low, the cost is $(BIGOH 1) in release mode
(no checks for sortedness are performed). In debug mode, a few random
elements of $(D r) are checked for sortedness. The size of the sample
is proportional $(BIGOH log(r.length)). That way, checking has no
effect on the complexity of subsequent operations specific to sorted
ranges (such as binary search). The probability of an arbitrary
unsorted range failing the test is very high (however, an
almost-sorted range is likely to pass it). To check for sortedness at
cost $(BIGOH n), use $(XREF algorithm,isSorted).
 */
auto assumeSorted(alias pred = "a < b", R)(R r)
if (isInputRange!(Unqual!R))
{
    return SortedRange!(Unqual!R, pred)(r);
}

@safe unittest
{
    import std.algorithm : equal;
    static assert(isRandomAccessRange!(SortedRange!(int[])));
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
    auto p = assumeSorted(a).lowerBound(4);
    assert(equal(p, [0, 1, 2, 3]));
    p = assumeSorted(a).lowerBound(5);
    assert(equal(p, [0, 1, 2, 3, 4]));
    p = assumeSorted(a).lowerBound(6);
    assert(equal(p, [ 0, 1, 2, 3, 4, 5]));
    p = assumeSorted(a).lowerBound(6.9);
    assert(equal(p, [ 0, 1, 2, 3, 4, 5, 6]));
}

@safe unittest
{
    import std.algorithm : equal;
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    auto p = assumeSorted(a).upperBound(3);
    assert(equal(p, [4, 4, 5, 6 ]));
    p = assumeSorted(a).upperBound(4.2);
    assert(equal(p, [ 5, 6 ]));
}

@safe unittest
{
    import std.conv : text;
    import std.algorithm : equal;

    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    auto p = assumeSorted(a).equalRange(3);
    assert(equal(p, [ 3, 3, 3 ]), text(p));
    p = assumeSorted(a).equalRange(4);
    assert(equal(p, [ 4, 4 ]), text(p));
    p = assumeSorted(a).equalRange(2);
    assert(equal(p, [ 2 ]));
    p = assumeSorted(a).equalRange(0);
    assert(p.empty);
    p = assumeSorted(a).equalRange(7);
    assert(p.empty);
    p = assumeSorted(a).equalRange(3.0);
    assert(equal(p, [ 3, 3, 3]));
}

@safe unittest
{
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    if (a.length)
    {
        auto b = a[a.length / 2];
        //auto r = sort(a);
        //assert(r.contains(b));
    }
}

@safe unittest
{
    auto a = [ 5, 7, 34, 345, 677 ];
    auto r = assumeSorted(a);
    a = null;
    r = assumeSorted(a);
    a = [ 1 ];
    r = assumeSorted(a);
}

unittest
{
    bool ok = true;
    try
    {
        auto r2 = assumeSorted([ 677, 345, 34, 7, 5 ]);
        debug ok = false;
    }
    catch (Throwable)
    {
    }
    assert(ok);
}


/++
    Wrapper which effectively makes it possible to pass a range by reference.
    Both the original range and the RefRange will always have the exact same
    elements. Any operation done on one will affect the other. So, for instance,
    if it's passed to a function which would implicitly copy the original range
    if it were passed to it, the original range is $(I not) copied but is
    consumed as if it were a reference type.

    Note that $(D save) works as normal and operates on a new range, so if
    $(D save) is ever called on the RefRange, then no operations on the saved
    range will affect the original.

  +/
struct RefRange(R)
    if(isForwardRange!R)
{
public:

    /++ +/
    this(R* range) @safe pure nothrow
    {
        _range = range;
    }


    /++
        This does not assign the pointer of $(D rhs) to this $(D RefRange).
        Rather it assigns the range pointed to by $(D rhs) to the range pointed
        to by this $(D RefRange). This is because $(I any) operation on a
        $(D RefRange) is the same is if it occurred to the original range. The
        one exception is when a $(D RefRange) is assigned $(D null) either
        directly or because $(D rhs) is $(D null). In that case, $(D RefRange)
        no longer refers to the original range but is $(D null).
      +/
    auto opAssign(RefRange rhs)
    {
        if(_range && rhs._range)
            *_range = *rhs._range;
        else
            _range = rhs._range;

        return this;
    }

    /++ +/
    auto opAssign(typeof(null) rhs)
    {
        _range = null;
    }


    /++
        A pointer to the wrapped range.
      +/
    @property inout(R*) ptr() @safe inout pure nothrow
    {
        return _range;
    }


    version(StdDdoc)
    {
        /++ +/
        @property auto front() {assert(0);}
        /++ Ditto +/
        @property auto front() const {assert(0);}
        /++ Ditto +/
        @property auto front(ElementType!R value) {assert(0);}
    }
    else
    {
        @property auto front()
        {
            return (*_range).front;
        }

        static if(is(typeof((*(cast(const R*)_range)).front))) @property ElementType!R front() const
        {
            return (*_range).front;
        }

        static if(is(typeof((*_range).front = (*_range).front))) @property auto front(ElementType!R value)
        {
            return (*_range).front = value;
        }
    }


    version(StdDdoc)
    {
        @property bool empty(); ///
        @property bool empty() const; ///Ditto
    }
    else static if(isInfinite!R)
        enum empty = false;
    else
    {
        @property bool empty()
        {
            return (*_range).empty;
        }

        static if(is(typeof((*cast(const R*)_range).empty))) @property bool empty() const
        {
            return (*_range).empty;
        }
    }


    /++ +/
    void popFront()
    {
        return (*_range).popFront();
    }


    version(StdDdoc)
    {
        /++ +/
        @property auto save() {assert(0);}
        /++ Ditto +/
        @property auto save() const {assert(0);}
        /++ Ditto +/
        auto opSlice() {assert(0);}
        /++ Ditto +/
        auto opSlice() const {assert(0);}
    }
    else
    {
        static if(isSafe!((R* r) => (*r).save))
        {
            @property auto save() @trusted
            {
                mixin(_genSave());
            }

            static if(is(typeof((*cast(const R*)_range).save))) @property auto save() @trusted const
            {
                mixin(_genSave());
            }
        }
        else
        {
            @property auto save()
            {
                mixin(_genSave());
            }

            static if(is(typeof((*cast(const R*)_range).save))) @property auto save() const
            {
                mixin(_genSave());
            }
        }

        auto opSlice()()
        {
            return save;
        }

        auto opSlice()() const
        {
            return save;
        }

        private static string _genSave() @safe pure nothrow
        {
            return `import std.conv;` ~
                   `alias S = typeof((*_range).save);` ~
                   `static assert(isForwardRange!S, S.stringof ~ " is not a forward range.");` ~
                   `auto mem = new void[S.sizeof];` ~
                   `emplace!S(mem, cast(S)(*_range).save);` ~
                   `return RefRange!S(cast(S*)mem.ptr);`;
        }

        static assert(isForwardRange!RefRange);
    }


    version(StdDdoc)
    {
        /++
            Only defined if $(D isBidirectionalRange!R) is $(D true).
          +/
        @property auto back() {assert(0);}
        /++ Ditto +/
        @property auto back() const {assert(0);}
        /++ Ditto +/
        @property auto back(ElementType!R value) {assert(0);}
    }
    else static if(isBidirectionalRange!R)
    {
        @property auto back()
        {
            return (*_range).back;
        }

        static if(is(typeof((*(cast(const R*)_range)).back))) @property ElementType!R back() const
        {
            return (*_range).back;
        }

        static if(is(typeof((*_range).back = (*_range).back))) @property auto back(ElementType!R value)
        {
            return (*_range).back = value;
        }
    }


    /++ Ditto +/
    static if(isBidirectionalRange!R) void popBack()
    {
        return (*_range).popBack();
    }


    version(StdDdoc)
    {
        /++
            Only defined if $(D isRandomAccesRange!R) is $(D true).
          +/
        auto ref opIndex(IndexType)(IndexType index) {assert(0);}

        /++ Ditto +/
        auto ref opIndex(IndexType)(IndexType index) const {assert(0);}
    }
    else static if(isRandomAccessRange!R)
    {
        auto ref opIndex(IndexType)(IndexType index)
            if(is(typeof((*_range)[index])))
        {
            return (*_range)[index];
        }

        auto ref opIndex(IndexType)(IndexType index) const
            if(is(typeof((*cast(const R*)_range)[index])))
        {
            return (*_range)[index];
        }
    }


    /++
        Only defined if $(D hasMobileElements!R) and $(D isForwardRange!R) are
        $(D true).
      +/
    static if(hasMobileElements!R && isForwardRange!R) auto moveFront()
    {
        return (*_range).moveFront();
    }


    /++
        Only defined if $(D hasMobileElements!R) and $(D isBidirectionalRange!R)
        are $(D true).
      +/
    static if(hasMobileElements!R && isBidirectionalRange!R) auto moveBack()
    {
        return (*_range).moveBack();
    }


    /++
        Only defined if $(D hasMobileElements!R) and $(D isRandomAccessRange!R)
        are $(D true).
      +/
    static if(hasMobileElements!R && isRandomAccessRange!R) auto moveAt(IndexType)(IndexType index)
        if(is(typeof((*_range).moveAt(index))))
    {
        return (*_range).moveAt(index);
    }


    version(StdDdoc)
    {
        /++
            Only defined if $(D hasLength!R) is $(D true).
          +/
        @property auto length() {assert(0);}

        /++ Ditto +/
        @property auto length() const {assert(0);}
    }
    else static if(hasLength!R)
    {
        @property auto length()
        {
            return (*_range).length;
        }

        static if(is(typeof((*cast(const R*)_range).length))) @property auto length() const
        {
            return (*_range).length;
        }
    }


    version(StdDdoc)
    {
        /++
            Only defined if $(D hasSlicing!R) is $(D true).
          +/
        auto opSlice(IndexType1, IndexType2)
                    (IndexType1 begin, IndexType2 end) {assert(0);}

        /++ Ditto +/
        auto opSlice(IndexType1, IndexType2)
                    (IndexType1 begin, IndexType2 end) const {assert(0);}
    }
    else static if(hasSlicing!R)
    {
        auto opSlice(IndexType1, IndexType2)
                    (IndexType1 begin, IndexType2 end)
            if(is(typeof((*_range)[begin .. end])))
        {
            mixin(_genOpSlice());
        }

        auto opSlice(IndexType1, IndexType2)
                    (IndexType1 begin, IndexType2 end) const
            if(is(typeof((*cast(const R*)_range)[begin .. end])))
        {
            mixin(_genOpSlice());
        }

        private static string _genOpSlice() @safe pure nothrow
        {
            return `import std.conv;` ~
                   `alias S = typeof((*_range)[begin .. end]);` ~
                   `static assert(hasSlicing!S, S.stringof ~ " is not sliceable.");` ~
                   `auto mem = new void[S.sizeof];` ~
                   `emplace!S(mem, cast(S)(*_range)[begin .. end]);` ~
                   `return RefRange!S(cast(S*)mem.ptr);`;
        }
    }


private:

    R* _range;
}

/// Basic Example
unittest
{
    import std.algorithm;
    ubyte[] buffer = [1, 9, 45, 12, 22];
    auto found1 = find(buffer, 45);
    assert(found1 == [45, 12, 22]);
    assert(buffer == [1, 9, 45, 12, 22]);

    auto wrapped1 = refRange(&buffer);
    auto found2 = find(wrapped1, 45);
    assert(*found2.ptr == [45, 12, 22]);
    assert(buffer == [45, 12, 22]);

    auto found3 = find(wrapped1.save, 22);
    assert(*found3.ptr == [22]);
    assert(buffer == [45, 12, 22]);

    string str = "hello world";
    auto wrappedStr = refRange(&str);
    assert(str.front == 'h');
    str.popFrontN(5);
    assert(str == " world");
    assert(wrappedStr.front == ' ');
    assert(*wrappedStr.ptr == " world");
}

/// opAssign Example.
unittest
{
    ubyte[] buffer1 = [1, 2, 3, 4, 5];
    ubyte[] buffer2 = [6, 7, 8, 9, 10];
    auto wrapped1 = refRange(&buffer1);
    auto wrapped2 = refRange(&buffer2);
    assert(wrapped1.ptr is &buffer1);
    assert(wrapped2.ptr is &buffer2);
    assert(wrapped1.ptr !is wrapped2.ptr);
    assert(buffer1 != buffer2);

    wrapped1 = wrapped2;

    //Everything points to the same stuff as before.
    assert(wrapped1.ptr is &buffer1);
    assert(wrapped2.ptr is &buffer2);
    assert(wrapped1.ptr !is wrapped2.ptr);

    //But buffer1 has changed due to the assignment.
    assert(buffer1 == [6, 7, 8, 9, 10]);
    assert(buffer2 == [6, 7, 8, 9, 10]);

    buffer2 = [11, 12, 13, 14, 15];

    //Everything points to the same stuff as before.
    assert(wrapped1.ptr is &buffer1);
    assert(wrapped2.ptr is &buffer2);
    assert(wrapped1.ptr !is wrapped2.ptr);

    //But buffer2 has changed due to the assignment.
    assert(buffer1 == [6, 7, 8, 9, 10]);
    assert(buffer2 == [11, 12, 13, 14, 15]);

    wrapped2 = null;

    //The pointer changed for wrapped2 but not wrapped1.
    assert(wrapped1.ptr is &buffer1);
    assert(wrapped2.ptr is null);
    assert(wrapped1.ptr !is wrapped2.ptr);

    //buffer2 is not affected by the assignment.
    assert(buffer1 == [6, 7, 8, 9, 10]);
    assert(buffer2 == [11, 12, 13, 14, 15]);
}

unittest
{
    import std.algorithm;
    {
        ubyte[] buffer = [1, 2, 3, 4, 5];
        auto wrapper = refRange(&buffer);
        auto p = wrapper.ptr;
        auto f = wrapper.front;
        wrapper.front = f;
        auto e = wrapper.empty;
        wrapper.popFront();
        auto s = wrapper.save;
        auto b = wrapper.back;
        wrapper.back = b;
        wrapper.popBack();
        auto i = wrapper[0];
        wrapper.moveFront();
        wrapper.moveBack();
        wrapper.moveAt(0);
        auto l = wrapper.length;
        auto sl = wrapper[0 .. 1];
    }

    {
        ubyte[] buffer = [1, 2, 3, 4, 5];
        const wrapper = refRange(&buffer);
        const p = wrapper.ptr;
        const f = wrapper.front;
        const e = wrapper.empty;
        const s = wrapper.save;
        const b = wrapper.back;
        const i = wrapper[0];
        const l = wrapper.length;
        const sl = wrapper[0 .. 1];
    }

    {
        ubyte[] buffer = [1, 2, 3, 4, 5];
        auto filtered = filter!"true"(buffer);
        auto wrapper = refRange(&filtered);
        auto p = wrapper.ptr;
        auto f = wrapper.front;
        wrapper.front = f;
        auto e = wrapper.empty;
        wrapper.popFront();
        auto s = wrapper.save;
        wrapper.moveFront();
    }

    {
        ubyte[] buffer = [1, 2, 3, 4, 5];
        auto filtered = filter!"true"(buffer);
        const wrapper = refRange(&filtered);
        const p = wrapper.ptr;

        //Cannot currently be const. filter needs to be updated to handle const.
        /+
        const f = wrapper.front;
        const e = wrapper.empty;
        const s = wrapper.save;
        +/
    }

    {
        string str = "hello world";
        auto wrapper = refRange(&str);
        auto p = wrapper.ptr;
        auto f = wrapper.front;
        auto e = wrapper.empty;
        wrapper.popFront();
        auto s = wrapper.save;
        auto b = wrapper.back;
        wrapper.popBack();
    }
}

//Test assignment.
unittest
{
    ubyte[] buffer1 = [1, 2, 3, 4, 5];
    ubyte[] buffer2 = [6, 7, 8, 9, 10];
    RefRange!(ubyte[]) wrapper1;
    RefRange!(ubyte[]) wrapper2 = refRange(&buffer2);
    assert(wrapper1.ptr is null);
    assert(wrapper2.ptr is &buffer2);

    wrapper1 = refRange(&buffer1);
    assert(wrapper1.ptr is &buffer1);

    wrapper1 = wrapper2;
    assert(wrapper1.ptr is &buffer1);
    assert(buffer1 == buffer2);

    wrapper1 = RefRange!(ubyte[]).init;
    assert(wrapper1.ptr is null);
    assert(wrapper2.ptr is &buffer2);
    assert(buffer1 == buffer2);
    assert(buffer1 == [6, 7, 8, 9, 10]);

    wrapper2 = null;
    assert(wrapper2.ptr is null);
    assert(buffer2 == [6, 7, 8, 9, 10]);
}

unittest
{
    import std.algorithm;

    //Test that ranges are properly consumed.
    {
        int[] arr = [1, 42, 2, 41, 3, 40, 4, 42, 9];
        auto wrapper = refRange(&arr);

        assert(*find(wrapper, 41).ptr == [41, 3, 40, 4, 42, 9]);
        assert(arr == [41, 3, 40, 4, 42, 9]);

        assert(*drop(wrapper, 2).ptr == [40, 4, 42, 9]);
        assert(arr == [40, 4, 42, 9]);

        assert(equal(until(wrapper, 42), [40, 4]));
        assert(arr == [42, 9]);

        assert(find(wrapper, 12).empty);
        assert(arr.empty);
    }

    {
        string str = "Hello, world-like object.";
        auto wrapper = refRange(&str);

        assert(*find(wrapper, "l").ptr == "llo, world-like object.");
        assert(str == "llo, world-like object.");

        assert(equal(take(wrapper, 5), "llo, "));
        assert(str == "world-like object.");
    }

    //Test that operating on saved ranges does not consume the original.
    {
        int[] arr = [1, 42, 2, 41, 3, 40, 4, 42, 9];
        auto wrapper = refRange(&arr);
        auto saved = wrapper.save;
        saved.popFrontN(3);
        assert(*saved.ptr == [41, 3, 40, 4, 42, 9]);
        assert(arr == [1, 42, 2, 41, 3, 40, 4, 42, 9]);
    }

    {
        string str = "Hello, world-like object.";
        auto wrapper = refRange(&str);
        auto saved = wrapper.save;
        saved.popFrontN(13);
        assert(*saved.ptr == "like object.");
        assert(str == "Hello, world-like object.");
    }

    //Test that functions which use save work properly.
    {
        int[] arr = [1, 42];
        auto wrapper = refRange(&arr);
        assert(equal(commonPrefix(wrapper, [1, 27]), [1]));
    }

    {
        int[] arr = [4, 5, 6, 7, 1, 2, 3];
        auto wrapper = refRange(&arr);
        assert(bringToFront(wrapper[0 .. 4], wrapper[4 .. arr.length]) == 3);
        assert(arr == [1, 2, 3, 4, 5, 6, 7]);
    }

    //Test bidirectional functions.
    {
        int[] arr = [1, 42, 2, 41, 3, 40, 4, 42, 9];
        auto wrapper = refRange(&arr);

        assert(wrapper.back == 9);
        assert(arr == [1, 42, 2, 41, 3, 40, 4, 42, 9]);

        wrapper.popBack();
        assert(arr == [1, 42, 2, 41, 3, 40, 4, 42]);
    }

    {
        string str = "Hello, world-like object.";
        auto wrapper = refRange(&str);

        assert(wrapper.back == '.');
        assert(str == "Hello, world-like object.");

        wrapper.popBack();
        assert(str == "Hello, world-like object");
    }

    //Test random access functions.
    {
        int[] arr = [1, 42, 2, 41, 3, 40, 4, 42, 9];
        auto wrapper = refRange(&arr);

        assert(wrapper[2] == 2);
        assert(arr == [1, 42, 2, 41, 3, 40, 4, 42, 9]);

        assert(*wrapper[3 .. 6].ptr != null, [41, 3, 40]);
        assert(arr == [1, 42, 2, 41, 3, 40, 4, 42, 9]);
    }

    //Test move functions.
    {
        int[] arr = [1, 42, 2, 41, 3, 40, 4, 42, 9];
        auto wrapper = refRange(&arr);

        auto t1 = wrapper.moveFront();
        auto t2 = wrapper.moveBack();
        wrapper.front = t2;
        wrapper.back = t1;
        assert(arr == [9, 42, 2, 41, 3, 40, 4, 42, 1]);

        sort(wrapper.save);
        assert(arr == [1, 2, 3, 4, 9, 40, 41, 42, 42]);
    }
}

unittest
{
    struct S
    {
        @property int front() @safe const pure nothrow { return 0; }
        enum bool empty = false;
        void popFront() @safe pure nothrow { }
        @property auto save() @safe pure nothrow { return this; }
    }

    S s;
    auto wrapper = refRange(&s);
    static assert(isInfinite!(typeof(wrapper)));
}

unittest
{
    class C
    {
        @property int front() @safe const pure nothrow { return 0; }
        @property bool empty() @safe const pure nothrow { return false; }
        void popFront() @safe pure nothrow { }
        @property auto save() @safe pure nothrow { return this; }
    }
    static assert(isForwardRange!C);

    auto c = new C;
    auto cWrapper = refRange(&c);
    static assert(is(typeof(cWrapper) == C));
    assert(cWrapper is c);

    struct S
    {
        @property int front() @safe const pure nothrow { return 0; }
        @property bool empty() @safe const pure nothrow { return false; }
        void popFront() @safe pure nothrow { }

        int i = 27;
    }
    static assert(isInputRange!S);
    static assert(!isForwardRange!S);

    auto s = S(42);
    auto sWrapper = refRange(&s);
    static assert(is(typeof(sWrapper) == S));
    assert(sWrapper == s);
}

/++
    Helper function for constructing a $(LREF RefRange).

    If the given range is not a forward range or it is a class type (and thus is
    already a reference type), then the original range is returned rather than
    a $(LREF RefRange).
  +/
auto refRange(R)(R* range)
    if(isForwardRange!R && !is(R == class))
{
    return RefRange!R(range);
}

auto refRange(R)(R* range)
    if((!isForwardRange!R && isInputRange!R) ||
       is(R == class))
{
    return *range;
}

/*****************************************************************************/

@safe unittest    // bug 9060
{
    import std.algorithm : map, joiner, group, until;
    // fix for std.algorithm
    auto r = map!(x => 0)([1]);
    chain(r, r);
    zip(r, r);
    roundRobin(r, r);

    struct NRAR {
        typeof(r) input;
        @property empty() { return input.empty; }
        @property front() { return input.front; }
        void popFront()   { input.popFront(); }
        @property save()  { return NRAR(input.save); }
    }
    auto n1 = NRAR(r);
    cycle(n1);  // non random access range version

    assumeSorted(r);

    // fix for std.range
    joiner([r], [9]);

    struct NRAR2 {
        NRAR input;
        @property empty() { return true; }
        @property front() { return input; }
        void popFront() { }
        @property save()  { return NRAR2(input.save); }
    }
    auto n2 = NRAR2(n1);
    joiner(n2);

    group(r);

    until(r, 7);
    static void foo(R)(R r) { until!(x => x > 7)(r); }
    foo(r);
}


/*********************************
 * An OutputRange that discards the data it receives.
 */
struct NullSink
{
    void put(E)(E){}
}

@safe unittest
{
    import std.algorithm : map, copy;
    [4, 5, 6].map!(x => x * 2).copy(NullSink());
}


/++
  Implements a "tee" style pipe, wrapping an input range so that elements
  of the range can be passed to a provided function or $(LREF OutputRange)
  as they are iterated over. This is useful for printing out intermediate
  values in a long chain of range code, performing some operation with
  side-effects on each call to $(D front) or $(D popFront), or diverting
  the elements of a range into an auxiliary $(LREF OutputRange).

  It is important to note that as the resultant range is evaluated lazily,
  in the case of the version of $(D tee) that takes a function, the function
  will not actually be executed until the range is "walked" using functions
  that evaluate ranges, such as $(XREF array,array) or
  $(XREF algorithm,reduce).

  See_Also: $(XREF argorithm,each)
+/

auto tee(Flag!"pipeOnPop" pipeOnPop = Yes.pipeOnPop, R1, R2)(R1 inputRange, R2 outputRange)
if (isInputRange!R1 && isOutputRange!(R2, ElementType!R1))
{
    static struct Result
    {
        private R1 _input;
        private R2 _output;
        static if (!pipeOnPop)
        {
            private bool _frontAccessed;
        }

        static if (hasLength!R1)
        {
            @property length()
            {
                return _input.length;
            }
        }

        static if (isInfinite!R1)
        {
            enum bool empty = false;
        }
        else
        {
            @property bool empty() { return _input.empty; }
        }

        void popFront()
        {
            assert(!_input.empty);
            static if (pipeOnPop)
            {
                put(_output, _input.front);
            }
            else
            {
                _frontAccessed = false;
            }
            _input.popFront();
        }

        @property auto ref front()
        {
            static if (!pipeOnPop)
            {
                if (!_frontAccessed)
                {
                    _frontAccessed = true;
                    put(_output, _input.front);
                }
            }
            return _input.front;
        }
    }

    return Result(inputRange, outputRange);
}

/++
  Overload for taking a function or template lambda as an $(LREF OutputRange)
+/
auto tee(alias fun, Flag!"pipeOnPop" pipeOnPop = Yes.pipeOnPop, R1)(R1 inputRange)
if (is(typeof(fun) == void) || isSomeFunction!fun)
{
    /*
        Distinguish between function literals and template lambdas
        when using either as an $(LREF OutputRange). Since a template
        has no type, typeof(template) will always return void.
        If it's a template lambda, it's first necessary to instantiate
        it with $(D ElementType!R1).
    */
    static if (is(typeof(fun) == void))
        alias _fun = fun!(ElementType!R1);
    else
        alias _fun = fun;

    static if (isFunctionPointer!_fun || isDelegate!_fun)
    {
        return tee!pipeOnPop(inputRange, _fun);
    }
    else
    {
        return tee!pipeOnPop(inputRange, &_fun);
    }
}

//
@safe unittest
{
    import std.algorithm : equal, filter, map;

    // Pass-through
    int[] values = [1, 4, 9, 16, 25];

    auto newValues = values.tee!(a => a + 1).array;
    assert(equal(newValues, values));

    int count = 0;
    auto newValues4 = values.filter!(a => a < 10)
                            .tee!(a => count++)
                            .map!(a => a + 1)
                            .filter!(a => a < 10);

    //Fine, equal also evaluates any lazy ranges passed to it.
    //count is not 3 until equal evaluates newValues3
    assert(equal(newValues4, [2, 5]));
    assert(count == 3);
}

//
@safe unittest
{
    import std.algorithm : equal, filter, map;

    int[] values = [1, 4, 9, 16, 25];

    int count = 0;
    auto newValues = values.filter!(a => a < 10)
        .tee!(a => count++, No.pipeOnPop)
        .map!(a => a + 1)
        .filter!(a => a < 10);

    auto val = newValues.front;
    assert(count == 1);
    //front is only evaluated once per element
    val = newValues.front;
    assert(count == 1);

    //popFront() called, fun will be called
    //again on the next access to front
    newValues.popFront();
    newValues.front;
    assert(count == 2);

    int[] preMap = new int[](3), postMap = [];
    auto mappedValues = values.filter!(a => a < 10)
        //Note the two different ways of using tee
        .tee(preMap)
        .map!(a => a + 1)
        .tee!(a => postMap ~= a)
        .filter!(a => a < 10);
    assert(equal(mappedValues, [2, 5]));
    assert(equal(preMap, [1, 4, 9]));
    assert(equal(postMap, [2, 5, 10]));
}

//
@safe unittest
{
    import std.algorithm : filter, equal, map;

    char[] txt = "Line one, Line 2".dup;

    bool isVowel(dchar c)
    {
        return std.string.indexOf("AaEeIiOoUu", c) != -1;
    }

    int vowelCount = 0;
    int shiftedCount = 0;
    auto removeVowels = txt.tee!(c => isVowel(c) ? vowelCount++ : 0)
                                .filter!(c => !isVowel(c))
                                .map!(c => (c == ' ') ? c : c + 1)
                                .tee!(c => isVowel(c) ? shiftedCount++ : 0);
    assert(equal(removeVowels, "Mo o- Mo 3"));
    assert(vowelCount == 6);
    assert(shiftedCount == 3);
}

@safe unittest
{
    // Manually stride to test different pipe behavior.
    void testRange(Range)(Range r)
    {
        const int strideLen = 3;
        int i = 0;
        ElementType!Range elem1;
        ElementType!Range elem2;
        while (!r.empty)
        {
            if (i % strideLen == 0)
            {
                //Make sure front is only
                //evaluated once per item
                elem1 = r.front;
                elem2 = r.front;
                assert(elem1 == elem2);
            }
            r.popFront();
            i++;
        }
    }

    string txt = "abcdefghijklmnopqrstuvwxyz";

    int popCount = 0;
    auto pipeOnPop = txt.tee!(a => popCount++);
    testRange(pipeOnPop);
    assert(popCount == 26);

    int frontCount = 0;
    auto pipeOnFront = txt.tee!(a => frontCount++, No.pipeOnPop);
    testRange(pipeOnFront);
    assert(frontCount == 9);
}

@safe unittest
{
    import std.algorithm : equal;

    //Test diverting elements to an OutputRange
    string txt = "abcdefghijklmnopqrstuvwxyz";

    dchar[] asink1 = [];
    auto fsink = (dchar c) { asink1 ~= c; };
    auto result1 = txt.tee(fsink).array;
    assert(equal(txt, result1) && (equal(result1, asink1)));

    dchar[] _asink1 = [];
    auto _result1 = txt.tee!((dchar c) { _asink1 ~= c; })().array;
    assert(equal(txt, _result1) && (equal(_result1, _asink1)));

    dchar[] asink2 = new dchar[](txt.length);
    void fsink2(dchar c) { static int i = 0; asink2[i] = c; i++; }
    auto result2 = txt.tee(&fsink2).array;
    assert(equal(txt, result2) && equal(result2, asink2));

    dchar[] asink3 = new dchar[](txt.length);
    auto result3 = txt.tee(asink3).array;
    assert(equal(txt, result3) && equal(result3, asink3));

    foreach (CharType; TypeTuple!(char, wchar, dchar))
    {
        auto appSink = appender!(CharType[])();
        auto appResult = txt.tee(appSink).array;
        assert(equal(txt, appResult) && equal(appResult, appSink.data));
    }

    foreach (StringType; TypeTuple!(string, wstring, dstring))
    {
        auto appSink = appender!StringType();
        auto appResult = txt.tee(appSink).array;
        assert(equal(txt, appResult) && equal(appResult, appSink.data));
    }
}

@safe unittest
{
    // Issue 13483
    static void func1(T)(T x) {}
    void func2(int x) {}

    auto r = [1, 2, 3, 4].tee!func1.tee!func2;
}
