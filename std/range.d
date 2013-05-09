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

This module defines several templates for testing whether a given object is a
_range, and what kind of _range it is:
$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF isInputRange)))
        $(TD Tests if something is an $(I input _range), defined to be
        something from which one can sequentially read data using the
        primitives $(D front), $(D popFront), and $(D empty).
    ))
    $(TR $(TD $(D $(LREF isOutputRange)))
        $(TD Tests if something is an $(I output _range), defined to be
        something to which one can sequentially write data using the $(D $(LREF
        put)) primitive.
    ))
    $(TR $(TD $(D $(LREF isForwardRange)))
        $(TD Tests if something is a $(I forward _range), defined to be an
        input _range with the additional capability that one can save one's
        current position with the $(D save) primitive, thus allowing one to
        iterate over the same _range multiple times.
    ))
    $(TR $(TD $(D $(LREF isBidirectionalRange)))
        $(TD Tests if something is a $(I bidirectional _range), that is, a
        forward _range that allows reverse traversal using the primitives $(D
        back) and $(D popBack).
    ))
    $(TR $(TD $(D $(LREF isRandomAccessRange)))
        $(TD Tests if something is a $(I random access _range), which is a
        bidirectional _range that also supports the array subscripting
        operation via the primitive $(D opIndex).
    ))
)

A number of templates are provided that test for various _range capabilities:

$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF hasMobileElements)))
        $(TD Tests if a given _range's elements can be moved around using the
        primitives $(D moveFront), $(D moveBack), or $(D moveAt).
    ))
    $(TR $(TD $(D $(LREF ElementType)))
        $(TD Returns the element type of a given _range.
    ))
    $(TR $(TD $(D $(LREF ElementEncodingType)))
        $(TD Returns the encoding element type of a given _range.
    ))
    $(TR $(TD $(D $(LREF hasSwappableElements)))
        $(TD Tests if a _range is a forward _range with swappable elements.
    ))
    $(TR $(TD $(D $(LREF hasAssignableElements)))
        $(TD Tests if a _range is a forward _range with mutable elements.
    ))
    $(TR $(TD $(D $(LREF hasLvalueElements)))
        $(TD Tests if a _range is a forward _range with elements that can be
        passed by reference and have their address taken.
    ))
    $(TR $(TD $(D $(LREF hasLength)))
        $(TD Tests if a given _range has the $(D length) attribute.
    ))
    $(TR $(TD $(D $(LREF isInfinite)))
        $(TD Tests if a given _range is an $(I infinite _range).
    ))
    $(TR $(TD $(D $(LREF hasSlicing)))
        $(TD Tests if a given _range supports the array slicing operation $(D
        R[x..y]).
    ))
    $(TR $(TD $(D $(LREF walkLength)))
        $(TD Computes the length of any _range in O(n) time.
    ))
)

A rich set of _range creation and composition templates are provided that let
you construct new ranges out of existing ranges:

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
    $(TR $(TD $(D $(LREF indexed)))
        $(TD Creates a _range that offers a view of a given _range as though
        its elements were reordered according to a given _range of indices.
    ))
    $(TR $(TD $(D $(LREF chunks)))
        $(TD Creates a _range that returns fixed-size chunks of the original
        _range.
    ))
    $(TR $(TD $(D $(LREF only)))
        $(TD Creates a _range that iterates over a single value.
    ))
)

These _range-construction tools are implemented using templates; but sometimes
an object-based interface for ranges is needed. For this purpose, this module
provides a number of object and $(D interface) definitions that can be used to
wrap around _range objects created by the above templates:

$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF InputRange)))
        $(TD Wrapper for input ranges.
    ))
    $(TR $(TD $(D $(LREF InputAssignable)))
        $(TD Wrapper for input ranges with assignable elements.
    ))
    $(TR $(TD $(D $(LREF ForwardRange)))
        $(TD Wrapper for forward ranges.
    ))
    $(TR $(TD $(D $(LREF ForwardAssignable)))
        $(TD Wrapper for forward ranges with assignable elements.
    ))
    $(TR $(TD $(D $(LREF BidirectionalRange)))
        $(TD Wrapper for bidirectional ranges.
    ))
    $(TR $(TD $(D $(LREF BidirectionalAssignable)))
        $(TD Wrapper for bidirectional ranges with assignable elements.
    ))
    $(TR $(TD $(D $(LREF RandomAccessFinite)))
        $(TD Wrapper for finite random-access ranges.
    ))
    $(TR $(TD $(D $(LREF RandomAccessAssignable)))
        $(TD Wrapper for finite random-access ranges with assignable elements.
    ))
    $(TR $(TD $(D $(LREF RandomAccessInfinite)))
        $(TD Wrapper for infinite random-access ranges.
    ))
    $(TR $(TD $(D $(LREF OutputRange)))
        $(TD Wrapper for output ranges.
    ))
    $(TR $(TD $(D $(LREF OutputRangeObject)))
        $(TD Class that implements the $(D OutputRange) interface and wraps the
        $(D put) methods in virtual functions.
    ))
    $(TR $(TD $(D $(LREF InputRangeObject)))
        $(TD Class that implements the $(D InputRange) interface and wraps the
        input _range methods in virtual functions.
    ))
)

Ranges whose elements are sorted afford better efficiency with certain
operations. For this, the $(D $(LREF assumeSorted)) function can be used to
construct a $(D $(LREF SortedRange)) from a pre-sorted _range. The $(LINK2
std_algorithm.html#sort, $(D std.algorithm.sort)) function also conveniently
returns a $(D SortedRange). $(D SortedRange) objects provide some additional
_range operations that take advantage of the fact that the _range is sorted.

Finally, this module also defines some convenience functions for
manipulating ranges:

$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF popFrontN)))
        $(TD Advances a given _range by up to $(I n) elements.
    ))
    $(TR $(TD $(D $(LREF popBackN)))
        $(TD Advances a given bidirectional _range from the right by up to
        $(I n) elements.
    ))
    $(TR $(TD $(D $(LREF popFrontExactly)))
        $(TD Advances a given _range by up exactly $(I n) elements.
    ))
    $(TR $(TD $(D $(LREF popBackExactly)))
        $(TD Advances a given bidirectional _range from the right by exactly
        $(I n) elements.
    ))
    $(TR $(TD $(D $(LREF moveFront)))
        $(TD Removes the front element of a _range.
    ))
    $(TR $(TD $(D $(LREF moveBack)))
        $(TD Removes the back element of a bidirectional _range.
    ))
    $(TR $(TD $(D $(LREF moveAt)))
        $(TD Removes the $(I i)'th element of a random-access _range.
    ))
)

Source: $(PHOBOSSRC std/_range.d)

Macros:

WIKI = Phobos/StdRange

Copyright: Copyright by authors 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu), David Simcha,
and Jonathan M Davis. Credit for some of the ideas in building this module goes
to $(WEB fantascienza.net/leonardo/so/, Leonardo Maffi).
 */
module std.range;

public import std.array;
import core.bitop, core.exception;
import std.algorithm, std.conv, std.exception,  std.functional,
    std.traits, std.typecons, std.typetuple, std.string;

// For testing only.  This code is included in a string literal to be included
// in whatever module it's needed in, so that each module that uses it can be
// tested individually, without needing to link to std.range.
enum dummyRanges = q{
    // Used with the dummy ranges for testing higher order ranges.
    enum RangeType
    {
        Input,
        Forward,
        Bidirectional,
        Random
    }

    enum Length
    {
        Yes,
        No
    }

    enum ReturnBy
    {
        Reference,
        Value
    }

    // Range that's useful for testing other higher order ranges,
    // can be parametrized with attributes.  It just dumbs down an array of
    // numbers 1..10.
    struct DummyRange(ReturnBy _r, Length _l, RangeType _rt)
    {
        // These enums are so that the template params are visible outside
        // this instantiation.
        enum r = _r;
        enum l = _l;
        enum rt = _rt;

        uint[] arr = [1U, 2U, 3U, 4U, 5U, 6U, 7U, 8U, 9U, 10U];

        void reinit()
        {
            // Workaround for DMD bug 4378
            arr = [1U, 2U, 3U, 4U, 5U, 6U, 7U, 8U, 9U, 10U];
        }

        void popFront()
        {
            arr = arr[1..$];
        }

        @property bool empty() const
        {
            return arr.length == 0;
        }

        static if(r == ReturnBy.Reference)
        {
            @property ref inout(uint) front() inout
            {
                return arr[0];
            }

            @property void front(uint val)
            {
                arr[0] = val;
            }
        }
        else
        {
            @property uint front() const
            {
                return arr[0];
            }
        }

        static if(rt >= RangeType.Forward)
        {
            @property typeof(this) save()
            {
                return this;
            }
        }

        static if(rt >= RangeType.Bidirectional)
        {
            void popBack()
            {
                arr = arr[0..$ - 1];
            }

            static if(r == ReturnBy.Reference)
            {
                @property ref inout(uint) back() inout
                {
                    return arr[$ - 1];
                }

                @property void back(uint val)
                {
                    arr[$ - 1] = val;
                }

            }
            else
            {
                @property uint back() const
                {
                    return arr[$ - 1];
                }
            }
        }

        static if(rt >= RangeType.Random)
        {
            static if(r == ReturnBy.Reference)
            {
                ref inout(uint) opIndex(size_t index) inout
                {
                    return arr[index];
                }

                void opIndexAssign(uint val, size_t index)
                {
                    arr[index] = val;
                }
            }
            else
            {
                uint opIndex(size_t index) const
                {
                    return arr[index];
                }
            }

            typeof(this) opSlice(size_t lower, size_t upper)
            {
                auto ret = this;
                ret.arr = arr[lower..upper];
                return ret;
            }
        }

        static if(l == Length.Yes)
        {
            @property size_t length() const
            {
                return arr.length;
            }

            alias length opDollar;
        }
    }

    enum dummyLength = 10;

    alias TypeTuple!(
        DummyRange!(ReturnBy.Reference, Length.Yes, RangeType.Forward),
        DummyRange!(ReturnBy.Reference, Length.Yes, RangeType.Bidirectional),
        DummyRange!(ReturnBy.Reference, Length.Yes, RangeType.Random),
        DummyRange!(ReturnBy.Reference, Length.No, RangeType.Forward),
        DummyRange!(ReturnBy.Reference, Length.No, RangeType.Bidirectional),
        DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Input),
        DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Forward),
        DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Bidirectional),
        DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Random),
        DummyRange!(ReturnBy.Value, Length.No, RangeType.Input),
        DummyRange!(ReturnBy.Value, Length.No, RangeType.Forward),
        DummyRange!(ReturnBy.Value, Length.No, RangeType.Bidirectional)
    ) AllDummyRanges;

};

version(unittest)
{
    import std.container, std.conv, std.math, std.stdio;

    mixin(dummyRanges);

    // Tests whether forward, bidirectional and random access properties are
    // propagated properly from the base range(s) R to the higher order range
    // H.  Useful in combination with DummyRange for testing several higher
    // order ranges.
    template propagatesRangeType(H, R...) {
        static if(allSatisfy!(isRandomAccessRange, R)) {
           enum bool propagatesRangeType = isRandomAccessRange!H;
        } else static if(allSatisfy!(isBidirectionalRange, R)) {
            enum bool propagatesRangeType = isBidirectionalRange!H;
        } else static if(allSatisfy!(isForwardRange, R)) {
            enum bool propagatesRangeType = isForwardRange!H;
        } else {
            enum bool propagatesRangeType = isInputRange!H;
        }
    }

    template propagatesLength(H, R...) {
        static if(allSatisfy!(hasLength, R)) {
            enum bool propagatesLength = hasLength!H;
        } else {
            enum bool propagatesLength = !hasLength!H;
        }
    }
}

/**
Returns $(D true) if $(D R) is an input range. An input range must
define the primitives $(D empty), $(D popFront), and $(D front). The
following code should compile for any input range.

----
R r;              // can define a range object
if (r.empty) {}   // can test for empty
r.popFront();     // can invoke popFront()
auto h = r.front; // can get the front of the range of non-void type
----

The semantics of an input range (not checkable during compilation) are
assumed to be the following ($(D r) is an object of type $(D R)):

$(UL $(LI $(D r.empty) returns $(D false) iff there is more data
available in the range.)  $(LI $(D r.front) returns the current
element in the range. It may return by value or by reference. Calling
$(D r.front) is allowed only if calling $(D r.empty) has, or would
have, returned $(D false).) $(LI $(D r.popFront) advances to the next
element in the range. Calling $(D r.popFront) is allowed only if
calling $(D r.empty) has, or would have, returned $(D false).))
 */
template isInputRange(R)
{
    enum bool isInputRange = is(typeof(
    (inout int = 0)
    {
        R r = void;       // can define a range object
        if (r.empty) {}   // can test for empty
        r.popFront();     // can invoke popFront()
        auto h = r.front; // can get the front of the range
    }));
}

unittest
{
    struct A {}
    struct B
    {
        void popFront();
        @property bool empty();
        @property int front();
    }
    static assert(!isInputRange!(A));
    static assert( isInputRange!(B));
    static assert( isInputRange!(int[]));
    static assert( isInputRange!(char[]));
    static assert(!isInputRange!(char[4]));
    static assert( isInputRange!(inout(int)[])); // bug 7824
}

/**
Outputs $(D e) to $(D r). The exact effect is dependent upon the two
types. Several cases are accepted, as described below. The code snippets
are attempted in order, and the first to compile "wins" and gets
evaluated.

$(BOOKTABLE ,
$(TR $(TH Code Snippet) $(TH Scenario
))
$(TR $(TD $(D r.put(e);)) $(TD $(D R) specifically defines a method
    $(D put) accepting an $(D E).
))
$(TR $(TD $(D r.put([ e ]);)) $(TD $(D R) specifically defines a
    method $(D put) accepting an $(D E[]).
))
$(TR $(TD $(D r.front = e; r.popFront();)) $(TD $(D R) is an input
    range and $(D e) is assignable to $(D r.front).
))
$(TR $(TD $(D for (; !e.empty; e.popFront()) put(r, e.front);)) $(TD
    Copying range $(D E) to range $(D R).
))
$(TR $(TD $(D r(e);)) $(TD $(D R) is e.g. a delegate accepting an $(D
    E).
))
$(TR $(TD $(D r([ e ]);)) $(TD $(D R) is e.g. a $(D delegate)
    accepting an $(D E[]).
))
)
 */
void put(R, E)(ref R r, E e)
{
    static if(is(PointerTarget!R == struct))
        enum usingPut = hasMember!(PointerTarget!R, "put");
    else
        enum usingPut = hasMember!(R, "put");

    enum usingFront = !usingPut && isInputRange!R;
    enum usingCall = !usingPut && !usingFront;

    static if (usingPut && is(typeof(r.put(e))))
    {
        r.put(e);
    }
    else static if (usingPut && is(typeof(r.put((E[]).init))))
    {
        r.put((&e)[0..1]);
    }
    else static if (usingFront && is(typeof(r.front = e, r.popFront())))
    {
        r.front = e;
        r.popFront();
    }
    else static if ((usingPut || usingFront) && isInputRange!E && is(typeof(put(r, e.front))))
    {
        for (; !e.empty; e.popFront()) put(r, e.front);
    }
    else static if (usingCall && is(typeof(r(e))))
    {
        r(e);
    }
    else static if (usingCall && is(typeof(r((E[]).init))))
    {
        r((&e)[0..1]);
    }
    else
    {
        static assert(false,
                "Cannot put a "~E.stringof~" into a "~R.stringof);
    }
}

unittest
{
    struct A {}
    static assert(!isInputRange!(A));
    struct B
    {
        void put(int) {}
    }
    B b;
    put(b, 5);
}

unittest
{
    int[] a = [1, 2, 3], b = [10, 20];
    auto c = a;
    put(a, b);
    assert(c == [10, 20, 3]);
    assert(a == [3]);
}

unittest
{
    int[] a = new int[10];
    int b;
    static assert(isInputRange!(typeof(a)));
    put(a, b);
}

unittest
{
    void myprint(in char[] s) { }
    auto r = &myprint;
    put(r, 'a');
}

unittest
{
    int[] a = new int[10];
    static assert(!__traits(compiles, put(a, 1.0L)));
    static assert( __traits(compiles, put(a, 1)));
    /*
     * a[0] = 65;       // OK
     * a[0] = 'A';      // OK
     * a[0] = "ABC"[0]; // OK
     * put(a, "ABC");   // OK
     */
    static assert( __traits(compiles, put(a, "ABC")));
}

unittest
{
    char[] a = new char[10];
    static assert(!__traits(compiles, put(a, 1.0L)));
    static assert(!__traits(compiles, put(a, 1)));
    // char[] is NOT output range.
    static assert(!__traits(compiles, put(a, 'a')));
    static assert(!__traits(compiles, put(a, "ABC")));
}

unittest
{
    // Test fix for bug 7476.
    struct LockingTextWriter
    {
        void put(dchar c){}
    }
    struct RetroResult
    {
        bool end = false;
        @property bool empty() const { return end; }
        @property dchar front(){ return 'a'; }
        void popFront(){ end = true; }
    }
    LockingTextWriter w;
    RetroResult r;
    put(w, r);
}

/**
Returns $(D true) if $(D R) is an output range for elements of type
$(D E). An output range is defined functionally as a range that
supports the operation $(D put(r, e)) as defined above.
 */
template isOutputRange(R, E)
{
    enum bool isOutputRange = is(typeof(
    (inout int = 0)
    {
        R r = void;
        E e;
        put(r, e);
    }));
}

unittest
{
    void myprint(in char[] s) { writeln('[', s, ']'); }
    static assert(isOutputRange!(typeof(&myprint), char));

    auto app = appender!string();
    string s;
    static assert( isOutputRange!(Appender!string, string));
    static assert( isOutputRange!(Appender!string*, string));
    static assert(!isOutputRange!(Appender!string, int));
    static assert(!isOutputRange!(char[], char));
    static assert(!isOutputRange!(wchar[], wchar));
    static assert( isOutputRange!(dchar[], char));
    static assert( isOutputRange!(dchar[], wchar));
    static assert( isOutputRange!(dchar[], dchar));

    static assert(!isOutputRange!(const(int)[], int));
    static assert(!isOutputRange!(inout(int)[], int));
}

/**
Returns $(D true) if $(D R) is a forward range. A forward range is an
input range $(D r) that can save "checkpoints" by saving $(D r.save)
to another value of type $(D R). Notable examples of input ranges that
are $(I not) forward ranges are file/socket ranges; copying such a
range will not save the position in the stream, and they most likely
reuse an internal buffer as the entire stream does not sit in
memory. Subsequently, advancing either the original or the copy will
advance the stream, so the copies are not independent.

The following code should compile for any forward range.

----
static assert(isInputRange!R);
R r1;
static assert (is(typeof(r1.save) == R));
----

Saving a range is not duplicating it; in the example above, $(D r1)
and $(D r2) still refer to the same underlying data. They just
navigate that data independently.

The semantics of a forward range (not checkable during compilation)
are the same as for an input range, with the additional requirement
that backtracking must be possible by saving a copy of the range
object with $(D save) and using it later.
 */
template isForwardRange(R)
{
    enum bool isForwardRange = isInputRange!R && is(typeof(
    (inout int = 0)
    {
        R r1 = void;
        static assert (is(typeof(r1.save) == R));
    }));
}

unittest
{
    static assert(!isForwardRange!(int));
    static assert( isForwardRange!(int[]));
    static assert( isForwardRange!(inout(int)[]));
}

/**
Returns $(D true) if $(D R) is a bidirectional range. A bidirectional
range is a forward range that also offers the primitives $(D back) and
$(D popBack). The following code should compile for any bidirectional
range.

----
R r;
static assert(isForwardRange!R);           // is forward range
r.popBack();                               // can invoke popBack
auto t = r.back;                           // can get the back of the range
auto w = r.front;
static assert(is(typeof(t) == typeof(w))); // same type for front and back
----

The semantics of a bidirectional range (not checkable during
compilation) are assumed to be the following ($(D r) is an object of
type $(D R)):

$(UL $(LI $(D r.back) returns (possibly a reference to) the last
element in the range. Calling $(D r.back) is allowed only if calling
$(D r.empty) has, or would have, returned $(D false).))
 */
template isBidirectionalRange(R)
{
    enum bool isBidirectionalRange = isForwardRange!R && is(typeof(
    (inout int = 0)
    {
        R r = void;
        r.popBack();
        auto t = r.back;
        auto w = r.front;
        static assert(is(typeof(t) == typeof(w)));
    }));
}

unittest
{
    struct A {}
    struct B
    {
        void popFront();
        @property bool empty();
        @property int front();
    }
    struct C
    {
        @property bool empty();
        @property C save();
        void popFront();
        @property int front();
        void popBack();
        @property int back();
    }
    static assert(!isBidirectionalRange!(A));
    static assert(!isBidirectionalRange!(B));
    static assert( isBidirectionalRange!(C));
    static assert( isBidirectionalRange!(int[]));
    static assert( isBidirectionalRange!(char[]));
    static assert( isBidirectionalRange!(inout(int)[]));
}

/**
Returns $(D true) if $(D R) is a random-access range. A random-access
range is a bidirectional range that also offers the primitive $(D
opIndex), OR an infinite forward range that offers $(D opIndex). In
either case, the range must either offer $(D length) or be
infinite. The following code should compile for any random-access
range.

----
// range is finite and bidirectional or infinite and forward.
static assert(isBidirectionalRange!R ||
              isForwardRange!R && isInfinite!R);

R r = void;
auto e = r[1]; // can index
static assert(is(typeof(e) == typeof(r.front))); // same type for indexed and front
static assert(!isNarrowString!R); // narrow strings cannot be indexed as ranges
static assert(hasLength!R || isInfinite!R); // must have length or be infinite

// $ must work as it does with arrays if opIndex works with $
static if(is(typeof(r[$])))
{
    static assert(is(typeof(r.front) == typeof(r[$])));

    // $ - 1 doesn't make sense with infinite ranges but needs to work
    // with finite ones.
    static if(!isInfinite!R)
        static assert(is(typeof(r.front) == typeof(r[$ - 1])));
}
----

The semantics of a random-access range (not checkable during
compilation) are assumed to be the following ($(D r) is an object of
type $(D R)): $(UL $(LI $(D r.opIndex(n)) returns a reference to the
$(D n)th element in the range.))

Although $(D char[]) and $(D wchar[]) (as well as their qualified
versions including $(D string) and $(D wstring)) are arrays, $(D
isRandomAccessRange) yields $(D false) for them because they use
variable-length encodings (UTF-8 and UTF-16 respectively). These types
are bidirectional ranges only.
 */
template isRandomAccessRange(R)
{
    enum bool isRandomAccessRange = is(typeof(
    (inout int = 0)
    {
        static assert(isBidirectionalRange!R ||
                      isForwardRange!R && isInfinite!R);
        R r = void;
        auto e = r[1];
        static assert(is(typeof(e) == typeof(r.front)));
        static assert(!isNarrowString!R);
        static assert(hasLength!R || isInfinite!R);

        static if(is(typeof(r[$])))
        {
            static assert(is(typeof(r.front) == typeof(r[$])));

            static if(!isInfinite!R)
                static assert(is(typeof(r.front) == typeof(r[$ - 1])));
        }
    }));
}

unittest
{
    struct A {}
    struct B
    {
        void popFront();
        @property bool empty();
        @property int front();
    }
    struct C
    {
        void popFront();
        @property bool empty();
        @property int front();
        void popBack();
        @property int back();
    }
    struct D
    {
        @property bool empty();
        @property D save();
        @property int front();
        void popFront();
        @property int back();
        void popBack();
        ref int opIndex(uint);
        @property size_t length();
        alias length opDollar;
        //int opSlice(uint, uint);
    }
    static assert(!isRandomAccessRange!(A));
    static assert(!isRandomAccessRange!(B));
    static assert(!isRandomAccessRange!(C));
    static assert( isRandomAccessRange!(D));
    static assert( isRandomAccessRange!(int[]));
    static assert( isRandomAccessRange!(inout(int)[]));
}

unittest
{
    // Test fix for bug 6935.
    struct R
    {
        @disable this();

        @disable static @property R init();

        @property bool empty() const { return false; }
        @property int front() const { return 0; }
        void popFront() {}

        @property R save() { return this; }

        @property int back() const { return 0; }
        void popBack(){}

        int opIndex(size_t n) const { return 0; }
        @property size_t length() const { return 0; }
        alias length opDollar;

        void put(int e){  }
    }
    static assert(isInputRange!R);
    static assert(isForwardRange!R);
    static assert(isBidirectionalRange!R);
    static assert(isRandomAccessRange!R);
    static assert(isOutputRange!(R, int));
}

/**
Returns $(D true) iff $(D R) supports the $(D moveFront) primitive,
as well as $(D moveBack) and $(D moveAt) if it's a bidirectional or
random access range.  These may be explicitly implemented, or may work
via the default behavior of the module level functions $(D moveFront)
and friends.
 */
template hasMobileElements(R)
{
    enum bool hasMobileElements = is(typeof(
    (inout int = 0)
    {
        R r = void;
        return moveFront(r);
    }))
    && (!isBidirectionalRange!R || is(typeof(
    (inout int = 0)
    {
        R r = void;
        return moveBack(r);
    })))
    && (!isRandomAccessRange!R || is(typeof(
    (inout int = 0)
    {
        R r = void;
        return moveAt(r, 0);
    })));
}

unittest
{
    static struct HasPostblit
    {
        this(this) {}
    }

    auto nonMobile = map!"a"(repeat(HasPostblit.init));
    static assert(!hasMobileElements!(typeof(nonMobile)));
    static assert( hasMobileElements!(int[]));
    static assert( hasMobileElements!(inout(int)[]));
    static assert( hasMobileElements!(typeof(iota(1000))));
}

/**
The element type of $(D R). $(D R) does not have to be a range. The
element type is determined as the type yielded by $(D r.front) for an
object $(D r) of type $(D R). For example, $(D ElementType!(T[])) is
$(D T) if $(D T[]) isn't a narrow string; if it is, the element type is
$(D dchar). If $(D R) doesn't have $(D front), $(D ElementType!R) is
$(D void).
 */
template ElementType(R)
{
    static if (is(typeof((inout int = 0){ R r = void; return r.front; }()) T))
        alias T ElementType;
    else
        alias void ElementType;
}

unittest
{
    enum XYZ : string { a = "foo" }
    auto x = XYZ.a.front;
    immutable char[3] a = "abc";
    int[] i;
    void[] buf;
    static assert(is(ElementType!(XYZ) : dchar));
    static assert(is(ElementType!(typeof(a)) : dchar));
    static assert(is(ElementType!(typeof(i)) : int));
    static assert(is(ElementType!(typeof(buf)) : void));
    static assert(is(ElementType!(inout(int)[]) : inout(int)));
}

/**
The encoding element type of $(D R). For narrow strings ($(D char[]),
$(D wchar[]) and their qualified variants including $(D string) and
$(D wstring)), $(D ElementEncodingType) is the character type of the
string. For all other types, $(D ElementEncodingType) is the same as
$(D ElementType).
 */
template ElementEncodingType(R)
{
    static if (isNarrowString!R)
        alias typeof((inout int = 0){ R r = void; return r[0]; }()) ElementEncodingType;
    else
        alias ElementType!R ElementEncodingType;
}

unittest
{
    enum XYZ : string { a = "foo" }
    auto x = XYZ.a.front;
    immutable char[3] a = "abc";
    int[] i;
    void[] buf;
    static assert(is(ElementType!(XYZ) : dchar));
    static assert(is(ElementEncodingType!(char[]) == char));
    static assert(is(ElementEncodingType!(string) == immutable char));
    static assert(is(ElementType!(typeof(a)) : dchar));
    static assert(is(ElementType!(typeof(i)) == int));
    static assert(is(ElementEncodingType!(typeof(i)) == int));
    static assert(is(ElementType!(typeof(buf)) : void));

    static assert(is(ElementEncodingType!(inout char[]) : inout(char)));
}

/**
Returns $(D true) if $(D R) is a forward range and has swappable
elements. The following code should compile for any range
with swappable elements.

----
R r;
static assert(isForwardRange!(R));   // range is forward
swap(r.front, r.front);              // can swap elements of the range
----
 */
template hasSwappableElements(R)
{
    enum bool hasSwappableElements = isForwardRange!R && is(typeof(
    (inout int = 0)
    {
        R r = void;
        swap(r.front, r.front);             // can swap elements of the range
    }));
}

unittest
{
    static assert(!hasSwappableElements!(const int[]));
    static assert(!hasSwappableElements!(const(int)[]));
    static assert(!hasSwappableElements!(inout(int)[]));
    static assert( hasSwappableElements!(int[]));
  //static assert( hasSwappableElements!(char[]));
}

/**
Returns $(D true) if $(D R) is a forward range and has mutable
elements. The following code should compile for any range
with assignable elements.

----
R r;
static assert(isForwardRange!R);  // range is forward
auto e = r.front;
r.front = e;                      // can assign elements of the range
----
 */
template hasAssignableElements(R)
{
    enum bool hasAssignableElements = isForwardRange!R && is(typeof(
    (inout int = 0)
    {
        R r = void;
        static assert(isForwardRange!(R)); // range is forward
        auto e = r.front;
        r.front = e;                       // can assign elements of the range
    }));
}

unittest
{
    static assert(!hasAssignableElements!(const int[]));
    static assert(!hasAssignableElements!(const(int)[]));
    static assert( hasAssignableElements!(int[]));
    static assert(!hasAssignableElements!(inout(int)[]));
}

/**
Tests whether $(D R) has lvalue elements.  These are defined as elements that
can be passed by reference and have their address taken.
*/
template hasLvalueElements(R)
{
    enum bool hasLvalueElements = is(typeof(
    (inout int = 0)
    {
        void checkRef(ref ElementType!R stuff) {}
        R r = void;
        static assert(is(typeof(checkRef(r.front))));
    }));
}

unittest
{
    static assert( hasLvalueElements!(int[]));
    static assert( hasLvalueElements!(const(int)[]));
    static assert( hasLvalueElements!(inout(int)[]));
    static assert( hasLvalueElements!(immutable(int)[]));
    static assert(!hasLvalueElements!(typeof(iota(3))));

    auto c = chain([1, 2, 3], [4, 5, 6]);
    static assert( hasLvalueElements!(typeof(c)));

    // bugfix 6336
    struct S { immutable int value; }
    static assert( isInputRange!(S[]));
    static assert( hasLvalueElements!(S[]));
}

/**
Returns $(D true) if $(D R) has a $(D length) member that returns an
integral type. $(D R) does not have to be a range. Note that $(D
length) is an optional primitive as no range must implement it. Some
ranges do not store their length explicitly, some cannot compute it
without actually exhausting the range (e.g. socket streams), and some
other ranges may be infinite.

Although narrow string types ($(D char[]), $(D wchar[]), and their
qualified derivatives) do define a $(D length) property, $(D
hasLength) yields $(D false) for them. This is because a narrow
string's length does not reflect the number of characters, but instead
the number of encoding units, and as such is not useful with
range-oriented algorithms.
 */
template hasLength(R)
{
    enum bool hasLength = !isNarrowString!R && is(typeof(
    (inout int = 0)
    {
        R r = void;
        static assert(is(typeof(r.length) : ulong));
    }));
}

unittest
{
    static assert(!hasLength!(char[]));
    static assert( hasLength!(int[]));
    static assert( hasLength!(inout(int)[]));

    struct A { ulong length; }
    struct B { size_t length() { return 0; } }
    struct C { @property size_t length() { return 0; } }
    static assert( hasLength!(A));
    static assert(!hasLength!(B));
    static assert( hasLength!(C));
}

/**
Returns $(D true) if $(D R) is an infinite input range. An
infinite input range is an input range that has a statically-defined
enumerated member called $(D empty) that is always $(D false),
for example:

----
struct MyInfiniteRange
{
    enum bool empty = false;
    ...
}
----
 */

template isInfinite(R)
{
    static if (isInputRange!R && __traits(compiles, { enum e = R.empty; }))
        enum bool isInfinite = !R.empty;
    else
        enum bool isInfinite = false;
}

unittest
{
    static assert(!isInfinite!(int[]));
    static assert( isInfinite!(Repeat!(int)));
}

/**
Returns $(D true) if $(D R) offers a slicing operator with integral boundaries
that returns a forward range type.

For finite ranges, the result of $(D opSlice) must be of the same type as the
original range type. If the range defines $(D opDollar), then it must support
subtraction.

For infinite ranges, when $(I not) using $(D opDollar), the result of
$(D opSlice) must be the result of $(LREF take) or $(LREF takeExactly) on the
original range (they both return the same type for infinite ranges). However,
when using $(D opDollar), the result of $(D opSlice) must be that of the
original range type.

The following code must compile for $(D hasSlicing) to be $(D true):

----
R r = void;

static if(isInfinite!R)
    typeof(take(r, 1)) s = r[1 .. 2];
else
{
    static assert(is(typeof(r[1 .. 2]) == R));
    R s = r[1 .. 2];
}

s = r[1 .. 2];

static if(is(typeof(r[0 .. $])))
{
    static assert(is(typeof(r[0 .. $]) == R));
    R t = r[0 .. $];
    t = r[0 .. $];

    static if(!isInfinite!R)
    {
        static assert(is(typeof(r[0 .. $ - 1]) == R));
        R u = r[0 .. $ - 1];
        u = r[0 .. $ - 1];
    }
}

static assert(isForwardRange!(typeof(r[1 .. 2])));
static assert(hasLength!(typeof(r[1 .. 2])));
----
 */
template hasSlicing(R)
{
    enum bool hasSlicing = isForwardRange!R && !isNarrowString!R && is(typeof(
    (inout int = 0)
    {
        R r = void;

        static if(isInfinite!R)
            typeof(take(r, 1)) s = r[1 .. 2];
        else
        {
            static assert(is(typeof(r[1 .. 2]) == R));
            R s = r[1 .. 2];
        }

        s = r[1 .. 2];

        static if(is(typeof(r[0 .. $])))
        {
            static assert(is(typeof(r[0 .. $]) == R));
            R t = r[0 .. $];
            t = r[0 .. $];

            static if(!isInfinite!R)
            {
                static assert(is(typeof(r[0 .. $ - 1]) == R));
                R u = r[0 .. $ - 1];
                u = r[0 .. $ - 1];
            }
        }

        static assert(isForwardRange!(typeof(r[1 .. 2])));
        static assert(hasLength!(typeof(r[1 .. 2])));
    }));
}

unittest
{
    static assert( hasSlicing!(int[]));
    static assert( hasSlicing!(const(int)[]));
    static assert(!hasSlicing!(const int[]));
    static assert( hasSlicing!(inout(int)[]));
    static assert(!hasSlicing!(inout int []));
    static assert( hasSlicing!(immutable(int)[]));
    static assert(!hasSlicing!(immutable int[]));
    static assert(!hasSlicing!string);
    static assert( hasSlicing!dstring);

    enum rangeFuncs = "@property int front();" ~
                      "void popFront();" ~
                      "@property bool empty();" ~
                      "@property auto save() { return this; }" ~
                      "@property size_t length();";

    struct A { mixin(rangeFuncs); int opSlice(size_t, size_t); }
    struct B { mixin(rangeFuncs); B opSlice(size_t, size_t); }
    struct C { mixin(rangeFuncs); @disable this(); C opSlice(size_t, size_t); }
    struct D { mixin(rangeFuncs); int[] opSlice(size_t, size_t); }
    static assert(!hasSlicing!(A));
    static assert( hasSlicing!(B));
    static assert( hasSlicing!(C));
    static assert(!hasSlicing!(D));

    struct InfOnes
    {
        enum empty = false;
        void popFront() {}
        @property int front() { return 1; }
        @property InfOnes save() { return this; }
        auto opSlice(size_t i, size_t j) { return takeExactly(this, j - i); }
        auto opSlice(size_t i, Dollar d) { return this; }

        struct Dollar {}
        Dollar opDollar() const { return Dollar.init; }
    }

    static assert(hasSlicing!InfOnes);
}

/**
This is a best-effort implementation of $(D length) for any kind of
range.

If $(D hasLength!Range), simply returns $(D range.length) without
checking $(D upTo) (when specified).

Otherwise, walks the range through its length and returns the number
of elements seen. Performes $(BIGOH n) evaluations of $(D range.empty)
and $(D range.popFront()), where $(D n) is the effective length of $(D
range).

The $(D upTo) parameter is useful to "cut the losses" in case
the interest is in seeing whether the range has at least some number
of elements. If the parameter $(D upTo) is specified, stops if $(D
upTo) steps have been taken and returns $(D upTo).

Infinite ranges are compatible, provided the parameter $(D upTo) is
specified, in which case the implementation simply returns upTo.
 */
auto walkLength(Range)(Range range)
    if (isInputRange!Range && !isInfinite!Range)
{
    static if (hasLength!Range)
        return range.length;
    else
    {
        size_t result;
        for ( ; !range.empty ; range.popFront() )
            ++result;
        return result;
    }
}
/// ditto
auto walkLength(Range)(Range range, const size_t upTo)
    if (isInputRange!Range)
{
    static if (hasLength!Range)
        return range.length;
    else static if (isInfinite!Range)
        return upTo;
    else
    {
        size_t result;
        for ( ; result < upTo && !range.empty ; range.popFront() )
            ++result;
        return result;
    }
}

unittest
{
    //hasLength Range
    int[] a = [ 1, 2, 3 ];
    assert(walkLength(a) == 3);
    assert(walkLength(a, 0) == 3);
    assert(walkLength(a, 2) == 3);
    assert(walkLength(a, 4) == 3);

    //Forward Range
    auto b = filter!"true"([1, 2, 3, 4]);
    assert(b.walkLength() == 4);
    assert(b.walkLength(0) == 0);
    assert(b.walkLength(2) == 2);
    assert(b.walkLength(4) == 4);
    assert(b.walkLength(6) == 4);

    //Infinite Range
    auto fibs = recurrence!"a[n-1] + a[n-2]"(1, 1);
    assert(!__traits(compiles, fibs.walkLength()));
    assert(fibs.take(10).walkLength() == 10);
    assert(fibs.walkLength(55) == 55);
}

/**
Iterates a bidirectional range backwards. The original range can be
accessed by using the $(D source) property. Applying retro twice to
the same range yields the original range.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
assert(equal(retro(a), [ 5, 4, 3, 2, 1 ][]));
assert(retro(a).source is a);
assert(retro(retro(a)) is a);
----
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
        static struct Result
        {
            private alias Unqual!Range R;

            // User code can get and set source, too
            R source;

            static if (hasLength!R)
            {
                private alias CommonType!(size_t, typeof(source.length)) IndexType;

                IndexType retroIndex(IndexType n)
                {
                    return source.length - n - 1;
                }
            }

        public:
            alias R Source;

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

                alias length opDollar;
            }
        }

        return Result(r);
    }
}

unittest
{
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

   // static assert(is(Retro!(immutable int[])));
   immutable foo = [1,2,3].idup;
   retro(foo);

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
unittest
{
    auto LL = iota(1L, 4L);
    auto r = retro(LL);
    assert(equal(r, [3L, 2L, 1L]));
}


/**
Iterates range $(D r) with stride $(D n). If the range is a
random-access range, moves by indexing into the range; otherwise,
moves by successive calls to $(D popFront). Applying stride twice to
the same range results in a stride with a step that is the
product of the two applications.

Throws: $(D Exception) if $(D n == 0).

Example:
----
int[] a = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 ];
assert(equal(stride(a, 3), [ 1, 4, 7, 10 ][]));
assert(stride(stride(a, 2), 3) == stride(a, 6));
----
 */
auto stride(Range)(Range r, size_t n)
if (isInputRange!(Unqual!Range))
{
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
            private alias Unqual!Range R;
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

                alias length opDollar;
            }
        }
        return Result(r, n);
    }
}

unittest
{
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
    assert(s1[s1.opDollar() .. s1.opDollar()].empty);

    auto s2 = stride(arr, 2);
    assert(equal(s2[0..2], [1,3]));
    assert(s2[0..2].length == 2);
    assert(equal(s2[1..5], [3, 5, 7, 9]));
    assert(s2[1..5].length == 4);
    assert(s2[0..0].empty);
    assert(s2[3..3].empty);
    // assert(s2[$ .. $].empty);
    assert(s2[s2.opDollar() .. s2.opDollar()].empty);

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
unittest
{
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

Example:
----
int[] arr1 = [ 1, 2, 3, 4 ];
int[] arr2 = [ 5, 6 ];
int[] arr3 = [ 7 ];
auto s = chain(arr1, arr2, arr3);
assert(s.length == 7);
assert(s[5] == 6);
assert(equal(s, [1, 2, 3, 4, 5, 6, 7][]));
----
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
            alias staticMap!(Unqual, Ranges) R;
            alias CommonType!(staticMap!(.ElementType, R)) RvalueElementType;
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
                alias RvalueElementType ElementType;
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
            Tuple!R source;
// TODO: use a vtable (or more) instead of linear iteration

        public:
            this(R input)
            {
                foreach (i, v; input)
                {
                    source[i] = v;
                }
            }

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

                alias length opDollar;
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

unittest
{
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

/**
$(D roundRobin(r1, r2, r3)) yields $(D r1.front), then $(D r2.front),
then $(D r3.front), after which it pops off one element from each and
continues again from $(D r1). For example, if two ranges are involved,
it alternately yields elements off the two ranges. $(D roundRobin)
stops after it has consumed all ranges (skipping over the ones that
finish early).

Example:
----
int[] a = [ 1, 2, 3, 4];
int[] b = [ 10, 20 ];
assert(equal(roundRobin(a, b), [1, 10, 2, 20, 3, 4]));
----
 */
auto roundRobin(Rs...)(Rs rs)
if (Rs.length > 1 && allSatisfy!(isInputRange, staticMap!(Unqual, Rs)))
{
    struct Result
    {
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
            static string makeSwitch()
            {
                string result = "switch (_current) {\n";
                foreach (i, R; Rs)
                {
                    auto si = to!string(i);
                    result ~= "case "~si~": "~
                        "assert(!source["~si~"].empty); return source["~si~"].front;\n";
                }
                return result ~ "default: assert(0); }";
            }

            mixin(makeSwitch());
        }

        void popFront()
        {
            static string makeSwitchPopFront()
            {
                string result = "switch (_current) {\n";
                foreach (i, R; Rs)
                {
                    auto si = to!string(i);
                    result ~= "case "~si~": source["~si~"].popFront(); break;\n";
                }
                return result ~ "default: assert(0); }";
            }

            static string makeSwitchIncrementCounter()
            {
                string result =
                    "auto next = _current == Rs.length - 1 ? 0 : _current + 1;\n"
                    "switch (next) {\n";
                foreach (i, R; Rs)
                {
                    auto si = to!string(i);
                    auto si_1 = to!string(i ? i - 1 : Rs.length - 1);
                    result ~= "case "~si~": "
                        "if (!source["~si~"].empty) { _current = "~si~"; return; }\n"
                        "if ("~si~" == _current) { _current = _current.max; return; }\n"
                        "goto case "~to!string((i + 1) % Rs.length)~";\n";
                }
                return result ~ "default: assert(0); }";
            }

            mixin(makeSwitchPopFront());
            mixin(makeSwitchIncrementCounter());
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

            alias length opDollar;
        }
    }

    return Result(rs, 0);
}

unittest
{
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

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
assert(equal(radial(a), [ 3, 4, 2, 5, 1 ]));
a = [ 1, 2, 3, 4 ];
assert(equal(radial(a), [ 2, 3, 1, 4 ]));
----
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

unittest
{
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
unittest
{
    auto LL = iota(1L, 6L);
    auto r = radial(LL);
    assert(equal(r, [3L, 4L, 2L, 5L, 1L]));
}

/**
Lazily takes only up to $(D n) elements of a range. This is
particularly useful when using with infinite ranges. If the range
offers random access and $(D length), $(D Take) offers them as well.

Example:
----
int[] arr1 = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
auto s = take(arr1, 5);
assert(s.length == 5);
assert(s[4] == 5);
assert(equal(s, [ 1, 2, 3, 4, 5 ][]));
----
 */
struct Take(Range)
if (isInputRange!(Unqual!Range) &&
    //take _cannot_ test hasSlicing on infinite ranges, because hasSlicing uses
    //take for slicing infinite ranges.
    !((!isInfinite!(Unqual!Range) && hasSlicing!(Unqual!Range)) || is(Range T == Take!T)))
{
    private alias Unqual!Range R;

    // User accessible in read and write
    public R source;

    private size_t _maxAvailable;

    alias R Source;

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

        alias length opDollar;
    }
    else static if (hasLength!R)
    {
        @property size_t length()
        {
            return min(_maxAvailable, source.length);
        }

        alias length opDollar;
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
            auto back(ElementType!R v)
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
    alias R Take;
}

// take for finite ranges with slicing
/// ditto
Take!R take(R)(R input, size_t n)
if (isInputRange!(Unqual!R) && !isInfinite!(Unqual!R) && hasSlicing!(Unqual!R))
{
    // @@@BUG@@@
    //return input[0 .. min(n, $)];
    return input[0 .. min(n, input.length)];
}

// take(take(r, n1), n2)
Take!R take(R)(R input, size_t n)
if (is(R T == Take!T))
{
    return R(input.source, min(n, input._maxAvailable));
}

// Regular take for input ranges
Take!(R) take(R)(R input, size_t n)
if (isInputRange!(Unqual!R) && (isInfinite!(Unqual!R) || !hasSlicing!(Unqual!R) && !is(R T == Take!T)))
{
    return Take!R(input, n);
}

unittest
{
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
        alias typeof(t) T;

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

unittest
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
            alias length opDollar;

            static if (isForwardRange!R)
                @property auto save()
                {
                    return Result(_input.save, _n);
                }
        }

        return Result(range, n);
    }
}

unittest
{
    auto a = [ 1, 2, 3, 4, 5 ];

    auto b = takeExactly(a, 3);
    assert(equal(b, [1, 2, 3]));
    static assert(is(typeof(b.length) == size_t));
    assert(b.length == 3);
    assert(b.front == 1);
    assert(b.back == 3);

    auto c = takeExactly(b, 2);

    auto d = filter!"a > 0"(a);
    auto e = takeExactly(d, 3);
    assert(equal(e, [1, 2, 3]));
    static assert(is(typeof(e.length) == size_t));
    assert(e.length == 3);
    assert(e.front == 1);

    assert(equal(takeExactly(e, 3), [1, 2, 3]));

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
        DummyType dummy;
        auto t = takeExactly(dummy, 5);

        //Test that takeExactly doesn't wrap the result of takeExactly.
        assert(takeExactly(t, 4) == takeExactly(dummy, 4));
    }
}

/**
Returns a range with at most one element; for example, $(D
takeOne([42, 43, 44])) returns a range consisting of the integer $(D
42). Calling $(D popFront()) off that range renders it empty.

----
auto s = takeOne([42, 43, 44]);
static assert(isRandomAccessRange!(typeof(s)));
assert(s.length == 1);
assert(!s.empty);
assert(s.front == 42);
s.front() = 43;
assert(s.front == 43);
assert(s.back == 43);
assert(s[0] == 43);
s.popFront();
assert(s.length == 0);
assert(s.empty);
----

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
            @property auto save() { return Result(_source.save, empty); }
            @property auto ref back() { assert(!empty); return _source.front; }
            @property size_t length() const { return !empty; }
            alias length opDollar;
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

unittest
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

/++
    Returns an empty range which is statically known to be empty and is
    guaranteed to have $(D length) and be random access regardless of $(D R)'s
    capabilities.

    Examples:
--------------------
auto range = takeNone!(int[])();
assert(range.length == 0);
assert(range.empty);
--------------------
  +/
auto takeNone(R)()
    if(isInputRange!R)
{
    return typeof(takeOne(R.init)).init;
}

unittest
{
    auto range = takeNone!(int[])();
    assert(range.length == 0);
    assert(range.empty);

    enum ctfe = takeNone!(int[])();
    static assert(ctfe.length == 0);
    static assert(ctfe.empty);
}


/++
    Creates an empty range from the given range in $(BIGOH 1). If it can, it
    will return the same range type. If not, it will return
    $(D takeExactly(range, 0)).

    Examples:
--------------------
assert(takeNone([42, 27, 19]).empty);
assert(takeNone("dlang.org").empty);
assert(takeNone(filter!"true"([42, 27, 19])).empty);
--------------------
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

//Verify Examples.
unittest
{
    assert(takeNone([42, 27, 19]).empty);
    assert(takeNone("dlang.org").empty);
    assert(takeNone(filter!"true"([42, 27, 19])).empty);
}

unittest
{
    string genInput()
    {
        return "@property bool empty() { return _arr.empty; }" ~
                "@property auto front() { return _arr.front; }" ~
                "void popFront() { _arr.popFront(); }" ~
                "static assert(isInputRange!(typeof(this)));";
    }

    static struct NormalStruct
    {
        //Disabled to make sure that the takeExactly version is used.
        @disable this();
        this(int[] arr) { _arr = arr; }
        mixin(genInput());
        int[] _arr;
    }

    static struct SliceStruct
    {
        @disable this();
        this(int[] arr) { _arr = arr; }
        mixin(genInput());
        @property auto save() { return this; }
        auto opSlice(size_t i, size_t j) { return typeof(this)(_arr[i .. j]); }
        @property size_t length() { return _arr.length; }
        int[] _arr;
    }

    static struct InitStruct
    {
        mixin(genInput());
        int[] _arr;
    }

    static struct TakeNoneStruct
    {
        this(int[] arr) { _arr = arr; }
        @disable this();
        mixin(genInput());
        auto takeNone() { return typeof(this)(null); }
        int[] _arr;
    }

    static class NormalClass
    {
        this(int[] arr) {_arr = arr;}
        mixin(genInput());
        int[] _arr;
    }

    static class SliceClass
    {
        this(int[] arr) { _arr = arr; }
        mixin(genInput());
        @property auto save() { return new typeof(this)(_arr); }
        auto opSlice(size_t i, size_t j) { return new typeof(this)(_arr[i .. j]); }
        @property size_t length() { return _arr.length; }
        int[] _arr;
    }

    static class TakeNoneClass
    {
        this(int[] arr) { _arr = arr; }
        mixin(genInput());
        auto takeNone() { return new typeof(this)(null); }
        int[] _arr;
    }

    foreach(range; TypeTuple!(`[1, 2, 3, 4, 5]`,
                              `"hello world"`,
                              `"hello world"w`,
                              `"hello world"d`,
                              `SliceStruct([1, 2, 3])`,
                              //@@@BUG@@@ 8339 forces this to be takeExactly
                              //`InitStruct([1, 2, 3])`,
                              `TakeNoneStruct([1, 2, 3])`))
    {
        mixin(format("enum a = takeNone(%s).empty;", range));
        assert(a, typeof(range).stringof);
        mixin(format("assert(takeNone(%s).empty);", range));
        mixin(format("static assert(is(typeof(%s) == typeof(takeNone(%s))), typeof(%s).stringof);",
                     range, range, range));
    }

    foreach(range; TypeTuple!(`NormalStruct([1, 2, 3])`,
                              `InitStruct([1, 2, 3])`))
    {
        mixin(format("enum a = takeNone(%s).empty;", range));
        assert(a, typeof(range).stringof);
        mixin(format("assert(takeNone(%s).empty);", range));
        mixin(format("static assert(is(typeof(takeExactly(%s, 0)) == typeof(takeNone(%s))), typeof(%s).stringof);",
                     range, range, range));
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

    Examples:
--------------------
assert([0, 2, 1, 5, 0, 3].drop(3) == [5, 0, 3]);
assert("hello world".drop(6) == "world");
assert("hello world".drop(50).empty);
assert("hello world".take(6).drop(3).equal("lo "));
--------------------

--------------------
//Remove all but the first two elements
auto a = DList!int(0, 1, 9, 9, 9);
a.remove(a[].drop(2));
assert(a[].equal(a[].take(2)));
--------------------

--------------------
assert([0, 2, 1, 5, 0, 3].dropBack(3) == [0, 2, 1]);
assert("hello world".dropBack(6) == "hello");
assert("hello world".dropBack(50).empty);
assert("hello world".drop(4).dropBack(4).equal("o w"));
--------------------

--------------------
//insert before the last two elements
auto a = DList!int(0, 1, 2, 5, 6);
a.insertAfter(a[].dropBack(2), [3, 4]);
assert(a[].equal(iota(0, 7)));
--------------------
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

//Verify Examples
unittest
{
    assert([0, 2, 1, 5, 0, 3].drop(3) == [5, 0, 3]);
    assert("hello world".drop(6) == "world");
    assert("hello world".drop(50).empty);
    assert("hello world".take(6).drop(3).equal("lo "));
}
unittest
{
    //Remove all but the first two elements
    auto a = DList!int(0, 1, 9, 9, 9, 9);
    a.remove(a[].drop(2));
    assert(a[].equal(a[].take(2)));
}
unittest
{
    assert(drop("", 5).empty);
    assert(equal(drop(filter!"true"([0, 2, 1, 5, 0, 3]), 3), [5, 0, 3]));
}
unittest
{
    assert([0, 2, 1, 5, 0, 3].dropBack(3) == [0, 2, 1]);
    assert("hello world".dropBack(6) == "hello");
    assert("hello world".dropBack(50).empty);
    assert("hello world".drop(4).dropBack(4).equal("o w"));
}
unittest
{
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

unittest
{
    //RA+slicing
    auto a = [1, 2, 3];
    assert(a.dropExactly(1) == [2, 3]);
    assert(a.dropBackExactly(1) == [1, 2]);

    //UTF string
    string s = "日本語";
    assert(s.dropExactly(1) == "本語");
    assert(s.dropBackExactly(1) == "日本");

    //Bidirectional
    auto bd = filterBidirectional!"true"([1, 2, 3]);
    assert(bd.dropExactly(1).equal([2, 3]));
    assert(bd.dropBackExactly(1).equal([1, 2]));
}

/++
    Convenience function which calls
    $(D range.popFront()) and returns $(D range). $(D dropOne)
    makes it easier to pop an element from a range
    and then pass it to another function within a single expression,
    whereas $(D popFront) would require multiple statements.

    $(D dropBackOne) provides the same functionality but instead calls
    $(D range.popBack()).

    Example:
----
auto dl = DList!int(9, 1, 2, 3, 9);
assert(dl[].dropOne().dropBackOne().equal([1, 2, 3]));
----
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

unittest
{
    auto dl = DList!int(9, 1, 2, 3, 9);
    assert(dl[].dropOne().dropBackOne().equal([1, 2, 3]));
}
unittest
{
    //RA+slicing
    auto a = [1, 2, 3];
    assert(a.dropOne() == [2, 3]);
    assert(a.dropBackOne() == [1, 2]);

    //UTF string
    string s = "日本語";
    assert(s.dropOne() == "本語");
    assert(s.dropBackOne() == "日本");

    //Bidirectional
    auto bd = filterBidirectional!"true"([1, 2, 3]);
    assert(bd.dropOne().equal([2, 3]));
    assert(bd.dropBackOne().equal([1, 2]));
}

/**
    Eagerly advances $(D r) itself (not a copy) up to $(D n) times (by
    calling $(D r.popFront)). $(D popFrontN) takes $(D r) by $(D ref),
    so it mutates the original range. Completes in $(BIGOH 1) steps for ranges
    that support slicing and have length.
    Completes in $(BIGOH n) time for all other ranges.

    Returns:
    How much $(D r) was actually advanced, which may be less than $(D n) if
    $(D r) did not have at least $(D n) elements.

    $(D popBackN) will behave the same but instead removes elements from
    the back of the (bidirectional) range instead of the front.

    Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
a.popFrontN(2);
assert(a == [ 3, 4, 5 ]);
a.popFrontN(7);
assert(a == [ ]);
----

----
int[] a = [ 1, 2, 3, 4, 5 ];
a.popBackN(2);
assert(a == [ 1, 2, 3 ]);
a.popBackN(7);
assert(a == [ ]);
----
*/
size_t popFrontN(Range)(ref Range r, size_t n)
    if (isInputRange!Range)
{
    static if (hasLength!Range)
        n = min(n, r.length);

    static if (hasSlicing!Range && is(typeof(r = r[n .. $])))
    {
        r = r[n .. $];
    }
    else static if (hasSlicing!Range && hasLength!Range) //TODO: Remove once hasSlicing forces opDollar.
    {
        r = r[n .. r.length];
    }
    else
    {
        static if (hasLength!Range)
        {
            foreach (i; 0 .. n)
                r.popFront();
        }
        else
        {
            foreach (i; 0 .. n)
            {
                if (r.empty) return i;
                r.popFront();
            }
        }
    }
    return n;
}
/// ditto
size_t popBackN(Range)(ref Range r, size_t n)
    if (isBidirectionalRange!Range)
{
    static if (hasLength!Range)
        n = min(n, r.length);

    static if (hasSlicing!Range && is(typeof(r = r[0 .. $ - n])))
    {
        r = r[0 .. $ - n];
    }
    else static if (hasSlicing!Range && hasLength!Range) //TODO: Remove once hasSlicing forces opDollar.
    {
        r = r[0 .. r.length - n];
    }
    else
    {
        static if (hasLength!Range)
        {
            foreach (i; 0 .. n)
                r.popBack();
        }
        else
        {
            foreach (i; 0 .. n)
            {
                if (r.empty) return i;
                r.popBack();
            }
        }
    }
    return n;
}

unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    a.popFrontN(2);
    assert(a == [ 3, 4, 5 ]);
    a.popFrontN(7);
    assert(a == [ ]);
}
unittest
{
    auto LL = iota(1L, 7L);
    auto r = popFrontN(LL, 2);
    assert(equal(LL, [3L, 4L, 5L, 6L]));
    assert(r == 2);
}
unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    a.popBackN(2);
    assert(a == [ 1, 2, 3 ]);
    a.popBackN(7);
    assert(a == [ ]);
}
unittest
{
    auto LL = iota(1L, 7L);
    auto r = popBackN(LL, 2);
    assert(equal(LL, [1L, 2L, 3L, 4L]));
    assert(r == 2);
}

/**
    Eagerly advances $(D r) itself (not a copy) exactly $(D n) times (by
    calling $(D r.popFront)). $(D popFrontExactly) takes $(D r) by $(D ref),
    so it mutates the original range. Completes in $(BIGOH 1) steps for ranges
    that support slicing, and have either length or are infinite.
    Completes in $(BIGOH n) time for all other ranges.

    Note: Unlike $(LREF popFrontN), $(D popFrontExactly) will assume that the
    range holds at least $(D n) elements. This makes $(D popFrontExactly)
    faster than $(D popFrontN), but it also means that if $(D range) does
    not contain at least $(D n) elements, it will attempt to call $(D popFront)
    on an empty range, which is undefined behavior. So, only use
    $(D popFrontExactly) when it is guaranteed that $(D range) holds at least
    $(D n) elements.

    $(D popBackExactly) will behave the same but instead removes elements from
    the back of the (bidirectional) range instead of the front.
*/
void popFrontExactly(Range)(ref Range r, size_t n)
    if (isInputRange!Range)
{
    static if (hasLength!Range)
        assert(n <= r.length, "range is smaller than amount of items to pop");

    static if (hasSlicing!Range && is(typeof(r = r[n .. $])))
        r = r[n .. $];
    else static if (hasSlicing!Range && hasLength!Range) //TODO: Remove once hasSlicing forces opDollar.
        r = r[n .. r.length];
    else
        foreach (i; 0 .. n)
            r.popFront();
}
/// ditto
void popBackExactly(Range)(ref Range r, size_t n)
    if (isBidirectionalRange!Range)
{
    static if (hasLength!Range)
        assert(n <= r.length, "range is smaller than amount of items to pop");

    static if (hasSlicing!Range && is(typeof(r = r[0 .. $ - n])))
        r = r[0 .. $ - n];
    else static if (hasSlicing!Range && hasLength!Range) //TODO: Remove once hasSlicing forces opDollar.
        r = r[0 .. r.length - n];
    else
        foreach (i; 0 .. n)
            r.popBack();
}

unittest
{
    //RA+slicing
    auto a = [1, 2, 3];
    a.popFrontExactly(1);
    assert(a == [2, 3]);
    a.popBackExactly(1);
    assert(a == [2]);

    //UTF string
    string s = "日本語";
    s.popFrontExactly(1);
    assert(s == "本語");
    s.popBackExactly(1);
    assert(s == "本");

    //Bidirectional
    auto bd = filterBidirectional!"true"([1, 2, 3]);
    bd.popFrontExactly(1);
    assert(bd.equal([2, 3]));
    bd.popBackExactly(1);
    assert(bd.equal([2]));
}

/**
Repeats one value forever.

Example:
----
enforce(equal(take(repeat(5), 4), [ 5, 5, 5, 5 ][]));
----
*/
struct Repeat(T)
{
    private T _value;
    /// Range primitive implementations.
    @property T front() { return _value; }
    /// Ditto
    enum bool empty = false;
    /// Ditto
    void popFront() {}
    /// Ditto
    @property Repeat!T save() { return this; }
    /// Ditto
    T opIndex(size_t) { return _value; }
    /// Ditto
    auto opSlice(size_t i, size_t j)
    {
        version (assert)
            if (i > j) throw new RangeError();
        return this.takeExactly(j - i);
    }
    /// Ditto
    version (StdDdoc)
        auto opDollar(){return DollarToken();} //Opaque signature for Ddoc
    else
        enum opDollar = DollarToken(); //Implementation defined signature

    private static struct DollarToken{}
    auto opSlice(size_t, DollarToken){return this;}
}

/// Ditto
Repeat!(T) repeat(T)(T value) { return Repeat!(T)(value); }

unittest
{
    auto  r = repeat(5);
    alias R = typeof(r);
    static assert(isForwardRange!R);
    static assert(isInfinite!R);
    static assert(hasSlicing!R);

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

// Explicitly undocumented. It will be removed in November 2013.
deprecated("Please use std.range.repeat instead.") Take!(Repeat!T) replicate(T)(T value, size_t n)
{
    return repeat(value, n);
}

unittest
{
    enforce(equal(repeat(5, 4), [ 5, 5, 5, 5 ][]));
}

/**
Repeats the given forward range ad infinitum. If the original range is
infinite (fact that would make $(D Cycle) the identity application),
$(D Cycle) detects that and aliases itself to the range type
itself. If the original range has random access, $(D Cycle) offers
random access and also offers a constructor taking an initial position
$(D index). $(D Cycle) works with static arrays in addition to ranges,
mostly for performance reasons.

Example:
----
assert(equal(take(cycle([1, 2][]), 5), [ 1, 2, 1, 2, 1 ][]));
----

Tip: This is a great way to implement simple circular buffers.
*/
struct Cycle(Range)
    if (isForwardRange!(Unqual!Range) && !isInfinite!(Unqual!Range))
{
    alias Unqual!Range R;

    static if (isRandomAccessRange!R && hasLength!R)
    {
        R _original;
        size_t _index;

        this(R input, size_t index = 0) { _original = input; _index = index; }

        @property auto ref front()
        {
            return _original[_index % _original.length];
        }

        static if (is(typeof((cast(const R)_original)[0])) &&
                   is(typeof((cast(const R)_original).length)))
        {
            @property auto ref front() const
            {
                return _original[_index % _original.length];
            }
        }

        static if (hasAssignableElements!R)
        {
            @property auto front(ElementType!R val)
            {
                _original[_index % _original.length] = val;
            }
        }

        enum bool empty = false;

        void popFront() { ++_index; }

        auto ref opIndex(size_t n)
        {
            return _original[(n + _index) % _original.length];
        }

        static if (is(typeof((cast(const R)_original)[0])) &&
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
            return Cycle(this._original.save, this._index);
        }

        private static struct DollarToken {}

        DollarToken opDollar()
        {
            return DollarToken.init;
        }

        auto opSlice(size_t i, size_t j)
        {
            version (assert) if (i > j) throw new RangeError();
            auto retval = this.save;
            retval._index += i;
            return takeExactly(retval, j - i);
        }

        auto opSlice(size_t i, DollarToken)
        {
            auto retval = this.save;
            retval._index += i;
            return retval;
        }
    }
    else
    {
        R _original;
        R _current;

        this(R input) { _original = input; _current = input.save; }

        @property auto ref front() { return _current.front; }

        static if (is(typeof((cast(const R)_current).front)))
            @property auto ref front() const
            {
                return _current.front;
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
            if (_current.empty) _current = _original;
        }

        @property Cycle save()
        {
            Cycle ret = this;
            ret._original = this._original.save;
            ret._current =  this._current.save;
            return ret;
        }
    }
}

template Cycle(R)
    if (isInfinite!R)
{
    alias R Cycle;
}

struct Cycle(R)
    if (isStaticArray!R)
{
    private alias typeof(R.init[0]) ElementType;
    private ElementType* _ptr;
    private size_t _index;

    this(ref R input, size_t index = 0)
    {
        _ptr = input.ptr;
        _index = index;
    }

    @property auto ref inout(ElementType) front() inout
    {
        return _ptr[_index % R.length];
    }

    enum bool empty = false;

    void popFront() { ++_index; }

    ref inout(ElementType) opIndex(size_t n) inout
    {
        return _ptr[(n + _index) % R.length];
    }

    @property Cycle save()
    {
        return this;
    }

    private static struct DollarToken {}

    DollarToken opDollar()
    {
        return DollarToken.init;
    }

    auto opSlice(size_t i, size_t j)
    {
        version (assert) if (i > j) throw new RangeError();
        auto retval = this.save;
        retval._index += i;
        return takeExactly(retval, j - i);
    }

    auto opSlice(size_t i, DollarToken)
    {
        auto retval = this.save;
        retval._index += i;
        return retval;
    }
}

/// Ditto
Cycle!R cycle(R)(R input)
    if (isForwardRange!(Unqual!R) && !isInfinite!(Unqual!R))
{
    return Cycle!R(input);
}

/// Ditto
Cycle!R cycle(R)(R input, size_t index = 0)
    if (isRandomAccessRange!(Unqual!R) && !isInfinite!(Unqual!R))
{
    return Cycle!R(input, index);
}

Cycle!R cycle(R)(R input)
    if (isInfinite!R)
{
    return input;
}

Cycle!R cycle(R)(ref R input, size_t index = 0)
    if (isStaticArray!R)
{
    return Cycle!R(input, index);
}

unittest
{
    assert(equal(take(cycle([1, 2][]), 5), [ 1, 2, 1, 2, 1 ][]));
    static assert(isForwardRange!(Cycle!(uint[])));

    int[3] a = [ 1, 2, 3 ];
    static assert(isStaticArray!(typeof(a)));
    auto c = cycle(a);
    assert(a.ptr == c._ptr);
    assert(equal(take(cycle(a), 5), [ 1, 2, 3, 1, 2 ][]));
    static assert(isForwardRange!(typeof(c)));

    // Make sure ref is getting propagated properly.
    int[] nums = [1,2,3];
    auto c2 = cycle(nums);
    c2[3]++;
    assert(nums[0] == 2);

    static assert(is(Cycle!(immutable int[])));

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
                    {
                        cy[10] = 66;
                        scope(exit) cy[10] = 1;
                        assert(dummy.front == 66);
                    }

                    assert(cRange[10] == 1);

                    assertThrown!RangeError(cy[2..1]);
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

unittest // For infinite ranges
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

private template lengthType(R) { alias typeof((inout int = 0){ R r = void; return r.length; }()) lengthType; }

/**
   Iterate several ranges in lockstep. The element type is a proxy tuple
   that allows accessing the current element in the $(D n)th range by
   using $(D e[n]).

   Example:
   ----
   int[] a = [ 1, 2, 3 ];
   string[] b = [ "a", "b", "c" ];
   // prints 1:a 2:b 3:c
   foreach (e; zip(a, b))
   {
   write(e[0], ':', e[1], ' ');
   }
   ----

   $(D Zip) offers the lowest range facilities of all components, e.g. it
   offers random access iff all ranges offer random access, and also
   offers mutation and swapping if all ranges offer it. Due to this, $(D
   Zip) is extremely powerful because it allows manipulating several
   ranges in lockstep. For example, the following code sorts two arrays
   in parallel:

   ----
   int[] a = [ 1, 2, 3 ];
   string[] b = [ "a", "b", "c" ];
   sort!("a[0] > b[0]")(zip(a, b));
   assert(a == [ 3, 2, 1 ]);
   assert(b == [ "c", "b", "a" ]);
   ----
*/
struct Zip(Ranges...)
    if (Ranges.length && allSatisfy!(isInputRange, Ranges))
{
    alias R = Ranges;
    R ranges;
    alias Tuple!(staticMap!(.ElementType, R)) ElementType;
    StoppingPolicy stoppingPolicy = StoppingPolicy.shortest;

/**
   Builds an object. Usually this is invoked indirectly by using the
   $(LREF zip) function.
 */
    this(R rs, StoppingPolicy s = StoppingPolicy.shortest)
    {
        stoppingPolicy = s;
        foreach (i, Unused; R)
        {
            ranges[i] = rs[i];
        }
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
        @property Zip save()
        {
            Zip result = this;
            foreach (i, Unused; R)
            {
                result.ranges[i] = result.ranges[i].save;
            }
            return result;
        }

/**
   Returns the current iterated element.
*/
    @property ElementType front()
    {
        ElementType result = void;
        foreach (i, Unused; R)
        {
            auto addr = cast(Unqual!(typeof(result[i]))*) &result[i];
            if (ranges[i].empty)
            {
                emplace(addr);
            }
            else
            {
                emplace(addr, ranges[i].front);
            }
        }
        return result;
    }

    static if (allSatisfy!(hasAssignableElements, R))
    {
/**
   Sets the front of all iterated ranges.
*/
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
            ElementType result = void;
            foreach (i, Unused; R)
            {
                auto addr = cast(Unqual!(typeof(result[i]))*) &result[i];
                if (!ranges[i].empty)
                {
                    emplace(addr, .moveFront(ranges[i]));
                }
                else
                {
                    emplace(addr);
                }
            }
            return result;
        }
    }

/**
   Returns the rightmost element.
*/
    static if (allSatisfy!(isBidirectionalRange, R))
    {
        @property ElementType back()
        {
            ElementType result = void;
            foreach (i, Unused; R)
            {
                auto addr = cast(Unqual!(typeof(result[i]))*) &result[i];
                if (!ranges[i].empty)
                {
                    emplace(addr, ranges[i].back);
                }
                else
                {
                    emplace(addr);
                }
            }
            return result;
        }

/**
   Moves out the back.
*/
        static if (allSatisfy!(hasMobileElements, R))
        {
            ElementType moveBack()
            {
                ElementType result = void;
                foreach (i, Unused; R)
                {
                    auto addr = cast(Unqual!(typeof(result[i]))*) &result[i];
                    if (!ranges[i].empty)
                    {
                        emplace(addr, .moveBack(ranges[i]));
                    }
                    else
                    {
                        emplace(addr);
                    }
                }
                return result;
            }
        }

/**
   Returns the current iterated element.
*/
        static if (allSatisfy!(hasAssignableElements, R))
        {
            @property void back(ElementType v)
            {
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

    static if (allSatisfy!(isBidirectionalRange, R))
/**
   Calls $(D popBack) for all controlled ranges.
*/
        void popBack()
        {
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

/**
   Returns the length of this range. Defined only if all ranges define
   $(D length).
*/
    static if (allSatisfy!(hasLength, R))
    {
        @property auto length()
        {
            CommonType!(staticMap!(lengthType, R)) result = ranges[0].length;
            if (stoppingPolicy == StoppingPolicy.requireSameLength)
                return result;
            foreach (i, Unused; R[1 .. $])
            {
                if (stoppingPolicy == StoppingPolicy.shortest)
                {
                    result = min(ranges[i + 1].length, result);
                }
                else
                {
                    assert(stoppingPolicy == StoppingPolicy.longest);
                    result = max(ranges[i + 1].length, result);
                }
            }
            return result;
        }

        alias length opDollar;
    }

/**
   Returns a slice of the range. Defined only if all range define
   slicing.
*/
    static if (allSatisfy!(hasSlicing, R))
        auto opSlice(size_t from, size_t to)
        {
            //Slicing an infinite range yields the type Take!R
            //For finite ranges, the type Take!R aliases to R
            Zip!(staticMap!(Take, R)) result = void;
            emplace(&result.stoppingPolicy, stoppingPolicy);
            foreach (i, Unused; R)
            {
                emplace(&result.ranges[i], ranges[i][from .. to]);
            }
            return result;
        }

    static if (allSatisfy!(isRandomAccessRange, R))
    {
/**
   Returns the $(D n)th element in the composite range. Defined if all
   ranges offer random access.
*/
        ElementType opIndex(size_t n)
        {
            ElementType result = void;
            foreach (i, Range; R)
            {
                auto addr = cast(Unqual!(typeof(result[i]))*) &result[i];
                emplace(addr, ranges[i][n]);
            }
            return result;
        }

        static if (allSatisfy!(hasAssignableElements, R))
        {
/**
   Assigns to the $(D n)th element in the composite range. Defined if
   all ranges offer random access.
*/
            void opIndexAssign(ElementType v, size_t n)
            {
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
                ElementType result = void;
                foreach (i, Range; R)
                {
                    auto addr = cast(Unqual!(typeof(result[i]))*) &result[i];
                    emplace(addr, .moveAt(ranges[i], n));
                }
                return result;
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
    assertNotThrown((z.popBack(), z.popBack(), z.popBack()));
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

    alias Zip!(immutable(int)[], immutable(float)[]) FOO;

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
        } catch { /* It's supposed to throw.*/ }

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

unittest
{
    auto a = [5,4,3,2,1];
    auto b = [3,1,2,5,6];
    auto z = zip(a, b);

    sort!"a[0] < b[0]"(z);

    assert(a == [1, 2, 3, 4, 5]);
    assert(b == [6, 5, 2, 1, 3]);
}
unittest
{
    auto LL = iota(1L, 1000L);
    auto z = zip(LL, [4]);

    assert(equal(z, [tuple(1L,4)]));

    auto LL2 = iota(0L, 500L);
    auto z2 = zip([7], LL2);
    assert(equal(z2, [tuple(7, 0L)]));
}

/*
    Generate lockstep's opApply function as a mixin string.
    If withIndex is true prepend a size_t index to the delegate.
*/
private string lockstepMixin(Ranges...)(bool withIndex)
{
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
        params ~= format("ref ElementType!(Ranges[%s])", idx);
        emptyChecks ~= format("!ranges[%s].empty", idx);
        dgArgs ~= format("ranges[%s].front", idx);
        popFronts ~= format("ranges[%s].popFront();", idx);
    }

    return format(
    q{
        int opApply(scope int delegate(%s) dg)
        {
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
       withIndex ? "index++;" : "").outdent();
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

   Examples:
   ---
   auto arr1 = [1,2,3,4,5];
   auto arr2 = [6,7,8,9,10];

   foreach(ref a, ref b; lockstep(arr1, arr2))
   {
       a += b;
   }

   assert(arr1 == [7,9,11,13,15]);

   // Lockstep also supports iterating with an index variable:
   foreach(index, a, b; lockstep(arr1, arr2)) {
       writefln("Index %s:  a = %s, b = %s", index, a, b);
   }
   ---
*/
struct Lockstep(Ranges...)
    if (Ranges.length > 1 && allSatisfy!(isInputRange, Ranges))
{
    this(R ranges, StoppingPolicy sp = StoppingPolicy.shortest)
    {
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
    alias Range Lockstep;
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

unittest
{
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
    } catch {}

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

If the function is passed in string form, the state has name $(D "a")
and the zero-based index in the recurrence has name $(D "n"). The
given string must return the desired value for $(D a[n]) given $(D a[n
- 1]), $(D a[n - 2]), $(D a[n - 3]),..., $(D a[n - stateSize]). The
state size is dictated by the number of arguments passed to the call
to $(D recurrence). The $(D Recurrence) struct itself takes care of
managing the recurrence's state and shifting it appropriately.

Example:
----
// a[0] = 1, a[1] = 1, and compute a[n+1] = a[n-1] + a[n]
auto fib = recurrence!("a[n-1] + a[n-2]")(1, 1);
// print the first 10 Fibonacci numbers
foreach (e; take(fib, 10)) { writeln(e); }
// print the first 10 factorials
foreach (e; take(recurrence!("a[n-1] * n")(1), 10)) { writeln(e); }
----
 */
struct Recurrence(alias fun, StateType, size_t stateSize)
{
    StateType[stateSize] _state;
    size_t _n;

    this(StateType[stateSize] initial) { _state = initial; }

    void popFront()
    {
        // The cast here is reasonable because fun may cause integer
        // promotion, but needs to return a StateType to make its operation
        // closed.  Therefore, we have no other choice.
        _state[_n % stateSize] = cast(StateType) binaryFun!(fun, "a", "n")(
            cycle(_state), _n + stateSize);
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

unittest
{
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

   Example:
   ----
   // a[0] = 1, a[1] = 2, a[n] = a[0] + n * a[1]
   auto odds = sequence!("a[0] + n * a[1]")(1, 2);
   ----
*/
struct Sequence(alias fun, State)
{
private:
    alias binaryFun!(fun, "a", "n") compute;
    alias typeof(compute(State.init, cast(size_t) 1)) ElementType;
    State _state;
    size_t _n;
    ElementType _cache;

    static struct DollarToken{}

public:
    this(State initial, size_t n = 0)
    {
        _state = initial;
        _n = n;
        _cache = compute(_state, _n);
    }

    @property ElementType front()
    {
        return _cache;
    }

    ElementType moveFront()
    {
        return move(this._cache);
    }

    void popFront()
    {
        _cache = compute(_state, ++_n);
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
Sequence!(fun, Tuple!(State)) sequence(alias fun, State...)(State args)
{
    return typeof(return)(tuple(args));
}

unittest
{
    auto y = Sequence!("a[0] + n * a[1]", Tuple!(int, int))
        (tuple(0, 4));
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



unittest
{
    // documentation example
    auto odds = sequence!("a[0] + n * a[1]")(1, 2);
    assert(odds.front == 1);
    odds.popFront();
    assert(odds.front == 3);
    odds.popFront();
    assert(odds.front == 5);
}

unittest
{
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

/**
   Returns a range that goes through the numbers $(D begin), $(D begin +
   step), $(D begin + 2 * step), $(D ...), up to and excluding $(D
   end). The range offered is a random access range. The two-arguments
   version has $(D step = 1). If $(D begin < end && step < 0) or $(D
   begin > end && step > 0) or $(D begin == end), then an empty range is
   returned.

   Throws:
   $(D Exception) if $(D begin != end && step == 0), an exception is
   thrown.

   Example:
   ----
   auto r = iota(0, 10, 1);
   assert(equal(r, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9][]));
   r = iota(0, 11, 3);
   assert(equal(r, [0, 3, 6, 9][]));
   assert(r[2] == 6);
   auto rf = iota(0.0, 0.5, 0.1);
   assert(approxEqual(rf, [0.0, 0.1, 0.2, 0.3, 0.4]));
   ----
*/
auto iota(B, E, S)(B begin, E end, S step)
if ((isIntegral!(CommonType!(B, E)) || isPointer!(CommonType!(B, E)))
        && isIntegral!S)
{
    alias CommonType!(Unqual!B, Unqual!E) Value;
    alias typeof(unsigned((end - begin) / step)) IndexType;

    static struct Result
    {
        private Value current, pastLast;
        private S step;

        this(Value current, Value pastLast, S step)
        {
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

        alias length opDollar;
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
    alias CommonType!(Unqual!B, Unqual!E) Value;
    alias typeof(unsigned(end - begin)) IndexType;

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

        alias length opDollar;
    }

    return Result(begin, end);
}

/// Ditto
auto iota(E)(E end)
{
    E begin = 0;
    return iota(begin, end);
}

// Specialization for floating-point types
auto iota(B, E, S)(B begin, E end, S step)
if (isFloatingPoint!(CommonType!(B, E, S)))
{
    alias CommonType!(B, E, S) Value;
    static struct Result
    {
        private Value start, step;
        private size_t index, count;

        this(Value start, Value end, Value step)
        {
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

        alias length opDollar;
    }

    return Result(begin, end, step);
}

unittest
{
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

    int[] a = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    auto r1 = iota(a.ptr, a.ptr + a.length, 1);
    assert(r1.front == a.ptr);
    assert(r1.back == a.ptr + a.length - 1);

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

unittest
{
    auto idx = new size_t[100];
    copy(iota(0, idx.length), idx);
}

unittest
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

   Example:
   ----
   int[][] x = new int[][2];
   x[0] = [1, 2];
   x[1] = [3, 4];
   auto ror = frontTransversal(x);
   assert(equal(ror, [ 1, 3 ][]));
   ---
*/
struct FrontTransversal(Ror,
        TransverseOptions opt = TransverseOptions.assumeJagged)
{
    alias Unqual!(Ror)               RangeOfRanges;
    alias .ElementType!RangeOfRanges RangeType;
    alias .ElementType!RangeType     ElementType;

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

unittest {
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

   Example:
   ----
   int[][] x = new int[][2];
   x[0] = [1, 2];
   x[1] = [3, 4];
   auto ror = transversal(x, 1);
   assert(equal(ror, [ 2, 4 ][]));
   ---
*/
struct Transversal(Ror,
        TransverseOptions opt = TransverseOptions.assumeJagged)
{
    private alias Unqual!Ror RangeOfRanges;
    private alias ElementType!RangeOfRanges InnerRange;
    private alias ElementType!InnerRange E;

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

            alias length opDollar;
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

unittest
{
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
    alias DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Random) D;
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
{
    //alias typeof(map!"a.front"(RangeOfRanges.init)) ElementType;

    this(RangeOfRanges input)
    {
        this._input = input;
    }

    @property auto front()
    {
        return map!"a.front"(_input);
    }

    void popFront()
    {
        foreach (ref e; _input)
        {
            if (e.empty) continue;
            e.popFront();
        }
    }

    // ElementType opIndex(size_t n)
    // {
    //     return _input[n].front;
    // }

    @property bool empty()
    {
        foreach (e; _input)
            if (!e.empty) return false;
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

auto transposed(RangeOfRanges)(RangeOfRanges rr)
{
    return Transposed!RangeOfRanges(rr);
}

unittest
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

/**
This struct takes two ranges, $(D source) and $(D indices), and creates a view
of $(D source) as if its elements were reordered according to $(D indices).
$(D indices) may include only a subset of the elements of $(D source) and
may also repeat elements.

$(D Source) must be a random access range.  The returned range will be
bidirectional or random-access if $(D Indices) is bidirectional or
random-access, respectively.

Examples:
---
auto source = [1, 2, 3, 4, 5];
auto indices = [4, 3, 1, 2, 0, 4];
auto ind = indexed(source, indices);
assert(equal(ind, [5, 4, 2, 3, 1, 5]));

// When elements of indices are duplicated and Source has lvalue elements,
// these are aliased in ind.
ind[0]++;
assert(ind[0] == 6);
assert(ind[5] == 6);
---
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

        alias length opDollar;
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

unittest
{
    {
        // Test examples.
        auto ind = indexed([1, 2, 3, 4, 5], [1, 3, 4]);
        assert(ind.physicalIndex(0) == 1);
    }

    auto source = [1, 2, 3, 4, 5];
    auto indices = [4, 3, 1, 2, 0, 4];
    auto ind = indexed(source, indices);
    assert(equal(ind, [5, 4, 2, 3, 1, 5]));
    assert(equal(retro(ind), [5, 1, 3, 2, 4, 5]));

    // When elements of indices are duplicated and Source has lvalue elements,
    // these are aliased in ind.
    ind[0]++;
    assert(ind[0] == 6);
    assert(ind[5] == 6);

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
$(D source) range.  $(D Source) must be an input range with slicing and length.
If $(D source.length) is not evenly divisible by $(D chunkSize), the back
element of this range will contain fewer than $(D chunkSize) elements.

Examples:
---
auto source = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
auto chunks = chunks(source, 4);
assert(chunks[0] == [1, 2, 3, 4]);
assert(chunks[1] == [5, 6, 7, 8]);
assert(chunks[2] == [9, 10]);
assert(chunks.back == chunks[2]);
assert(chunks.front == chunks[0]);
assert(chunks.length == 3);
---
*/
struct Chunks(Source) if(isInputRange!Source && hasSlicing!Source && hasLength!Source)
{
    ///
    this(Source source, size_t chunkSize)
    {
        this._source = source;
        this._chunkSize = chunkSize;
    }

    /// Range primitives.
    @property auto front()
    {
        assert(!empty);
        return _source[0..min(_chunkSize, _source.length)];
    }

    /// Ditto
    void popFront()
    {
        assert(!empty);
        popFrontN(_source, _chunkSize);
    }

    /// Ditto
    @property bool empty()
    {
        return _source.empty;
    }

    static if(isForwardRange!Source)
    {
        /// Ditto
        @property typeof(this) save()
        {
            return typeof(this)(_source.save, _chunkSize);
        }
    }

    /// Ditto
    auto opIndex(size_t index)
    {
        immutable end = min(_source.length, (index + 1) * _chunkSize);
        return _source[index * _chunkSize..end];
    }

    /// Ditto
    typeof(this) opSlice(size_t lower, size_t upper)
    {
        immutable start = lower * _chunkSize;
        immutable end = min(_source.length, upper * _chunkSize);
        return typeof(this)(_source[start..end], _chunkSize);
    }

    /// Ditto
    @property size_t length()
    {
        return (_source.length / _chunkSize) +
            (_source.length % _chunkSize > 0);
    }

    alias length opDollar;

    /// Ditto
    @property auto back()
    {
        assert(!empty);

        immutable remainder = _source.length % _chunkSize;
        immutable len = _source.length;

        if(remainder == 0)
        {
            // Return a full chunk.
            return _source[len - _chunkSize..len];
        }
        else
        {
            return _source[len - remainder..len];
        }
    }

    /// Ditto
    void popBack()
    {
        assert(!empty);

        immutable remainder = _source.length % _chunkSize;
        immutable len = _source.length;

        if(remainder == 0)
        {
            _source = _source[0..len - _chunkSize];
        }
        else
        {
            _source = _source[0..len - remainder];
        }
    }

private:
    Source _source;
    size_t _chunkSize;
}

/// Ditto
Chunks!(Source) chunks(Source)(Source source, size_t chunkSize)
{
    return typeof(return)(source, chunkSize);
}

unittest
{
    auto source = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto chunks = chunks(source, 4);
    assert(chunks[0] == [1, 2, 3, 4]);
    assert(chunks[1] == [5, 6, 7, 8]);
    assert(chunks[2] == [9, 10]);
    assert(chunks.back == chunks[2]);
    assert(chunks.front == chunks[0]);
    assert(chunks.length == 3);
    assert(equal(retro(array(chunks)), array(retro(chunks))));

    auto chunks2 = chunks.save;
    chunks.popFront();
    assert(chunks[0] == [5, 6, 7, 8]);
    assert(chunks[1] == [9, 10]);
    chunks2.popBack();
    assert(chunks2[1] == [5, 6, 7, 8]);
    assert(chunks2.length == 2);

    static assert(isRandomAccessRange!(typeof(chunks)));
}

/**
This range iterates a single element. This is useful when a sole value
must be passed to an algorithm expecting a range.

Example:
----
assert(equal(only('♡'), "♡"));
assert([1, 2, 3, 4].findSplitBefore(only(3))[0] == [1, 2]);

string title = "The D Programming Language";
assert(filter!isUpper(title).map!only().join(".") == "T.D.P.L");
----
 */
auto only(T)(T value)
{
    static struct Result
    {
        this(T value) { _value = value; }

        @property T front() { assert(!_empty); return _value; }
        @property T back() { assert(!_empty); return _value; }
        @property bool empty() const { return _empty; }
        @property size_t length() const { return !_empty; }
        @property auto save() { return this; }
        void popFront() { assert(!_empty); _empty = true; }
        void popBack() { assert(!_empty); _empty = true; }
        auto opSlice() { return this; }

        T opIndex(size_t i)
        {
            version (assert)
                if (_empty || i != 0)
                    throw new RangeError;
            return _value;
        }

        auto opSlice(size_t from, size_t to)
        {
            version (assert)
                if (from > to || to > length)
                    throw new RangeError;
            Result copy = this;
            copy._empty = _empty || from == to;
            return copy;
        }

        private Unqual!T _value;
        private bool _empty = false;
    }
    return Result(value);
}

unittest
{
    // Examples
    assert(equal(only('♡'), "♡"));
    assert([1, 2, 3, 4].findSplitBefore(only(3))[0] == [1, 2]);

    import std.uni;
    string title = "The D Programming Language";
    assert(filter!isUpper(title).map!only().join(".") == "T.D.P.L");

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

        alias typeof(a) A;
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
    assert(imm.length == 1);
    assert(equal(imm, imm[]));
    assert(equal(imm, imm[0..1]));
    assert(equal(imm[0..0], imme));
    assert(equal(imm[1..1], imme));
    assert(imm[0] == 1);
}

/**
   Moves the front of $(D r) out and returns it. Leaves $(D r.front) in a
   destroyable state that does not allocate any resources (usually equal
   to its $(D .init) value).
*/
ElementType!R moveFront(R)(R r)
{
    static if (is(typeof(&r.moveFront))) {
        return r.moveFront();
    } else static if (!hasElaborateCopyConstructor!(ElementType!R)) {
        return r.front;
    } else static if (is(typeof(&(r.front())) == ElementType!R*)) {
        return move(r.front);
    } else {
        static assert(0,
                "Cannot move front of a range with a postblit and an rvalue front.");
    }
}

unittest
{
    struct R
    {
        @property ref int front() { static int x = 42; return x; }
        this(this){}
    }
    R r;
    assert(moveFront(r) == 42);
}

/**
   Moves the back of $(D r) out and returns it. Leaves $(D r.back) in a
   destroyable state that does not allocate any resources (usually equal
   to its $(D .init) value).
*/
ElementType!R moveBack(R)(R r)
{
    static if (is(typeof(&r.moveBack))) {
        return r.moveBack();
    } else static if (!hasElaborateCopyConstructor!(ElementType!R)) {
        return r.back;
    } else static if (is(typeof(&(r.back())) == ElementType!R*)) {
        return move(r.back);
    } else {
        static assert(0,
                "Cannot move back of a range with a postblit and an rvalue back.");
    }
}

unittest
{
    struct TestRange
    {
        int payload;
        @property bool empty() { return false; }
        @property TestRange save() { return this; }
        @property ref int front() { return payload; }
        @property ref int back() { return payload; }
        void popFront() { }
        void popBack() { }
    }
    static assert(isBidirectionalRange!TestRange);
    TestRange r;
    auto x = moveBack(r);
}

/**
   Moves element at index $(D i) of $(D r) out and returns it. Leaves $(D
   r.front) in a destroyable state that does not allocate any resources
   (usually equal to its $(D .init) value).
*/
ElementType!R moveAt(R, I)(R r, I i) if (isIntegral!I)
{
    static if (is(typeof(&r.moveAt))) {
        return r.moveAt(i);
    } else static if (!hasElaborateCopyConstructor!(ElementType!(R))) {
        return r[i];
    } else static if (is(typeof(&r[i]) == ElementType!R*)) {
        return move(r[i]);
    } else {
        static assert(0,
                "Cannot move element of a range with a postblit and rvalue elements.");
    }
}

unittest
{
    auto a = [ 1, 2, 3 ];
    assert(moveFront(a) == 1);
    // define a perfunctory input range
    struct InputRange
    {
        @property bool empty() { return false; }
        @property int front() { return 42; }
        void popFront() {}
        int moveFront() { return 43; }
    }
    InputRange r;
    assert(moveFront(r) == 43);

    foreach(DummyType; AllDummyRanges) {
        auto d = DummyType.init;
        assert(moveFront(d) == 1);

        static if (isBidirectionalRange!DummyType) {
            assert(moveBack(d) == 10);
        }

        static if (isRandomAccessRange!DummyType) {
            assert(moveAt(d, 2) == 3);
        }
    }
}

/**These interfaces are intended to provide virtual function-based wrappers
 * around input ranges with element type E.  This is useful where a well-defined
 * binary interface is required, such as when a DLL function or virtual function
 * needs to accept a generic range as a parameter.  Note that
 * $(LREF isInputRange) and friends check for conformance to structural
 * interfaces, not for implementation of these $(D interface) types.
 *
 * Examples:
 * ---
 * void useRange(InputRange!int range) {
 *     // Function body.
 * }
 *
 * // Create a range type.
 * auto squares = map!"a * a"(iota(10));
 *
 * // Wrap it in an interface.
 * auto squaresWrapped = inputRangeObject(squares);
 *
 * // Use it.
 * useRange(squaresWrapped);
 * ---
 *
 * Limitations:
 *
 * These interfaces are not capable of forwarding $(D ref) access to elements.
 *
 * Infiniteness of the wrapped range is not propagated.
 *
 * Length is not propagated in the case of non-random access ranges.
 *
 * See_Also:
 * $(LREF inputRangeObject)
 */
interface InputRange(E) {
    ///
    @property E front();

    ///
    E moveFront();

    ///
    void popFront();

    ///
    @property bool empty();

    /* Measurements of the benefits of using opApply instead of range primitives
     * for foreach, using timings for iterating over an iota(100_000_000) range
     * with an empty loop body, using the same hardware in each case:
     *
     * Bare Iota struct, range primitives:  278 milliseconds
     * InputRangeObject, opApply:           436 milliseconds  (1.57x penalty)
     * InputRangeObject, range primitives:  877 milliseconds  (3.15x penalty)
     */

    /**$(D foreach) iteration uses opApply, since one delegate call per loop
     * iteration is faster than three virtual function calls.
     */
    int opApply(int delegate(E));

    /// Ditto
    int opApply(int delegate(size_t, E));

}

/**Interface for a forward range of type $(D E).*/
interface ForwardRange(E) : InputRange!E {
    ///
    @property ForwardRange!E save();
}

/**Interface for a bidirectional range of type $(D E).*/
interface BidirectionalRange(E) : ForwardRange!(E) {
    ///
    @property BidirectionalRange!E save();

    ///
    @property E back();

    ///
    E moveBack();

    ///
    void popBack();
}

/**Interface for a finite random access range of type $(D E).*/
interface RandomAccessFinite(E) : BidirectionalRange!(E) {
    ///
    @property RandomAccessFinite!E save();

    ///
    E opIndex(size_t);

    ///
    E moveAt(size_t);

    ///
    @property size_t length();

    ///
    alias length opDollar;

    // Can't support slicing until issues with requiring slicing for all
    // finite random access ranges are fully resolved.
    version(none) {
        ///
        RandomAccessFinite!E opSlice(size_t, size_t);
    }
}

/**Interface for an infinite random access range of type $(D E).*/
interface RandomAccessInfinite(E) : ForwardRange!E {
    ///
    E moveAt(size_t);

    ///
    @property RandomAccessInfinite!E save();

    ///
    E opIndex(size_t);
}

/**Adds assignable elements to InputRange.*/
interface InputAssignable(E) : InputRange!E {
    ///
    @property void front(E newVal);
}

/**Adds assignable elements to ForwardRange.*/
interface ForwardAssignable(E) : InputAssignable!E, ForwardRange!E {
    ///
    @property ForwardAssignable!E save();
}

/**Adds assignable elements to BidirectionalRange.*/
interface BidirectionalAssignable(E) : ForwardAssignable!E, BidirectionalRange!E {
    ///
    @property BidirectionalAssignable!E save();

    ///
    @property void back(E newVal);
}

/**Adds assignable elements to RandomAccessFinite.*/
interface RandomFiniteAssignable(E) : RandomAccessFinite!E, BidirectionalAssignable!E {
    ///
    @property RandomFiniteAssignable!E save();

    ///
    void opIndexAssign(E val, size_t index);
}

/**Interface for an output range of type $(D E).  Usage is similar to the
 * $(D InputRange) interface and descendants.*/
interface OutputRange(E) {
    ///
    void put(E);
}

// CTFE function that generates mixin code for one put() method for each
// type E.
private string putMethods(E...)() {
    string ret;

    foreach(ti, Unused; E) {
        ret ~= "void put(E[" ~ to!string(ti) ~ "] e) { .put(_range, e); }";
    }

    return ret;
}

/**Implements the $(D OutputRange) interface for all types E and wraps the
 * $(D put) method for each type $(D E) in a virtual function.
 */
class OutputRangeObject(R, E...) : staticMap!(OutputRange, E) {
    // @BUG 4689:  There should be constraints on this template class, but
    // DMD won't let me put them in.
    private R _range;

    this(R range) {
        this._range = range;
    }

    mixin(putMethods!E());
}


/**Returns the interface type that best matches $(D R).*/
template MostDerivedInputRange(R) if (isInputRange!(Unqual!R)) {
    private alias ElementType!R E;

    static if (isRandomAccessRange!R) {
        static if (isInfinite!R) {
            alias RandomAccessInfinite!E MostDerivedInputRange;
        } else static if (hasAssignableElements!R) {
            alias RandomFiniteAssignable!E MostDerivedInputRange;
        } else {
            alias RandomAccessFinite!E MostDerivedInputRange;
        }
    } else static if (isBidirectionalRange!R) {
        static if (hasAssignableElements!R) {
            alias BidirectionalAssignable!E MostDerivedInputRange;
        } else {
            alias BidirectionalRange!E MostDerivedInputRange;
        }
    } else static if (isForwardRange!R) {
        static if (hasAssignableElements!R) {
            alias ForwardAssignable!E MostDerivedInputRange;
        } else {
            alias ForwardRange!E MostDerivedInputRange;
        }
    } else {
        static if (hasAssignableElements!R) {
            alias InputAssignable!E MostDerivedInputRange;
        } else {
            alias InputRange!E MostDerivedInputRange;
        }
    }
}

/**Implements the most derived interface that $(D R) works with and wraps
 * all relevant range primitives in virtual functions.  If $(D R) is already
 * derived from the $(D InputRange) interface, aliases itself away.
 */
template InputRangeObject(R) if (isInputRange!(Unqual!R)) {
    static if (is(R : InputRange!(ElementType!R))) {
        alias R InputRangeObject;
    } else static if (!is(Unqual!R == R)) {
        alias InputRangeObject!(Unqual!R) InputRangeObject;
    } else {

        ///
        class InputRangeObject : MostDerivedInputRange!(R) {
            private R _range;
            private alias ElementType!R E;

            this(R range) {
                this._range = range;
            }

            @property E front() { return _range.front; }

            E moveFront() {
                return .moveFront(_range);
            }

            void popFront() { _range.popFront(); }
            @property bool empty() { return _range.empty; }

            static if (isForwardRange!R) {
                @property typeof(this) save() {
                    return new typeof(this)(_range.save);
                }
            }

            static if (hasAssignableElements!R) {
                @property void front(E newVal) {
                    _range.front = newVal;
                }
            }

            static if (isBidirectionalRange!R) {
                @property E back() { return _range.back; }

                E moveBack() {
                    return .moveBack(_range);
                }

                void popBack() { return _range.popBack(); }

                static if (hasAssignableElements!R) {
                    @property void back(E newVal) {
                        _range.back = newVal;
                    }
                }
            }

            static if (isRandomAccessRange!R) {
                E opIndex(size_t index) {
                    return _range[index];
                }

                E moveAt(size_t index) {
                    return .moveAt(_range, index);
                }

                static if (hasAssignableElements!R) {
                    void opIndexAssign(E val, size_t index) {
                        _range[index] = val;
                    }
                }

                static if (!isInfinite!R) {
                    @property size_t length() {
                        return _range.length;
                    }

                    alias length opDollar;

                    // Can't support slicing until all the issues with
                    // requiring slicing support for finite random access
                    // ranges are resolved.
                    version(none) {
                        typeof(this) opSlice(size_t lower, size_t upper) {
                            return new typeof(this)(_range[lower..upper]);
                        }
                    }
                }
            }

            // Optimization:  One delegate call is faster than three virtual
            // function calls.  Use opApply for foreach syntax.
            int opApply(int delegate(E) dg) {
                int res;

                for(auto r = _range; !r.empty; r.popFront()) {
                    res = dg(r.front);
                    if (res) break;
                }

                return res;
            }

            int opApply(int delegate(size_t, E) dg) {
                int res;

                size_t i = 0;
                for(auto r = _range; !r.empty; r.popFront()) {
                    res = dg(i, r.front);
                    if (res) break;
                    i++;
                }

                return res;
            }
        }
    }
}

/**Convenience function for creating an $(D InputRangeObject) of the proper type.
 * See $(LREF InputRange) for an example.
 */
InputRangeObject!R inputRangeObject(R)(R range) if (isInputRange!R) {
    static if (is(R : InputRange!(ElementType!R))) {
        return range;
    } else {
        return new InputRangeObject!R(range);
    }
}

/**Convenience function for creating an $(D OutputRangeObject) with a base range
 * of type $(D R) that accepts types $(D E).

 Examples:
 ---
 uint[] outputArray;
 auto app = appender(&outputArray);
 auto appWrapped = outputRangeObject!(uint, uint[])(app);
 static assert(is(typeof(appWrapped) : OutputRange!(uint[])));
 static assert(is(typeof(appWrapped) : OutputRange!(uint)));
 ---
*/
template outputRangeObject(E...) {

    ///
    OutputRangeObject!(R, E) outputRangeObject(R)(R range) {
        return new OutputRangeObject!(R, E)(range);
    }
}

unittest {
    static void testEquality(R)(iInputRange r1, R r2) {
        assert(equal(r1, r2));
    }

    auto arr = [1,2,3,4];
    RandomFiniteAssignable!int arrWrapped = inputRangeObject(arr);
    static assert(isRandomAccessRange!(typeof(arrWrapped)));
    //    static assert(hasSlicing!(typeof(arrWrapped)));
    static assert(hasLength!(typeof(arrWrapped)));
    arrWrapped[0] = 0;
    assert(arr[0] == 0);
    assert(arr.moveFront() == 0);
    assert(arr.moveBack() == 4);
    assert(arr.moveAt(1) == 2);

    foreach(elem; arrWrapped) {}
    foreach(i, elem; arrWrapped) {}

    assert(inputRangeObject(arrWrapped) is arrWrapped);

    foreach(DummyType; AllDummyRanges) {
        auto d = DummyType.init;
        static assert(propagatesRangeType!(DummyType,
                        typeof(inputRangeObject(d))));
        static assert(propagatesRangeType!(DummyType,
                        MostDerivedInputRange!DummyType));
        InputRange!uint wrapped = inputRangeObject(d);
        assert(equal(wrapped, d));
    }

    // Test output range stuff.
    auto app = appender!(uint[])();
    auto appWrapped = outputRangeObject!(uint, uint[])(app);
    static assert(is(typeof(appWrapped) : OutputRange!(uint[])));
    static assert(is(typeof(appWrapped) : OutputRange!(uint)));

    appWrapped.put(1);
    appWrapped.put([2, 3]);
    assert(app.data.length == 3);
    assert(equal(app.data, [1,2,3]));
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
   Represents a sorted random-access range. In addition to the regular
   range primitives, supports fast operations using binary search. To
   obtain a $(D SortedRange) from an unsorted range $(D r), use
   $(XREF algorithm, sort) which sorts $(D r) in place and returns the
   corresponding $(D SortedRange). To construct a $(D SortedRange)
   from a range $(D r) that is known to be already sorted, use
   $(LREF assumeSorted) described below.

   Example:

   ----
   auto a = [ 1, 2, 3, 42, 52, 64 ];
   auto r = assumeSorted(a);
   assert(r.contains(3));
   assert(!r.contains(32));
   auto r1 = sort!"a > b"(a);
   assert(r1.contains(3));
   assert(!r1.contains(32));
   assert(r1.release() == [ 64, 52, 42, 3, 2, 1 ]);
   ----

   $(D SortedRange) could accept ranges weaker than random-access, but it
   is unable to provide interesting functionality for them. Therefore,
   $(D SortedRange) is currently restricted to random-access ranges.

   No copy of the original range is ever made. If the underlying range is
   changed concurrently with its corresponding $(D SortedRange) in ways
   that break its sortedness, $(D SortedRange) will work erratically.

   Example:

   ----
   auto a = [ 1, 2, 3, 42, 52, 64 ];
   auto r = assumeSorted(a);
   assert(r.contains(42));
   swap(a[3], a[5]);                      // illegal to break sortedness of original range
   assert(!r.contains(42));                // passes although it shouldn't
   ----
*/
struct SortedRange(Range, alias pred = "a < b")
if (isRandomAccessRange!Range && hasLength!Range)
{
    private alias binaryFun!pred predFun;
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
    {
        this._input = input;
        if(!__ctfe)
        debug
        {
            import std.random;

            // Check the sortedness of the input
            if (this._input.length < 2) return;
            immutable size_t msb = bsr(this._input.length) + 1;
            assert(msb > 0 && msb <= this._input.length);
            immutable step = this._input.length / msb;
            static MinstdRand gen;
            immutable start = uniform(0, step, gen);
            auto st = stride(this._input, step);
            assert(isSorted!pred(st), text(st));
        }
    }

    /// Range primitives.
    @property bool empty()             //const
    {
        return this._input.empty;
    }

    /// Ditto
    @property auto save()
    {
        // Avoid the constructor
        typeof(this) result = this;
        result._input = _input.save;
        return result;
    }

    /// Ditto
    @property auto front()
    {
        return _input.front;
    }

    /// Ditto
    void popFront()
    {
        _input.popFront();
    }

    /// Ditto
    @property auto back()
    {
        return _input.back;
    }

    /// Ditto
    void popBack()
    {
        _input.popBack();
    }

    /// Ditto
    auto opIndex(size_t i)
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
    @property size_t length()          //const
    {
        return _input.length;
    }

    alias length opDollar;

/**
   Releases the controlled range and returns it.
*/
    auto release()
    {
        return move(_input);
    }

    // Assuming a predicate "test" that returns 0 for a left portion
    // of the range and then 1 for the rest, returns the index at
    // which the first 1 appears. Used internally by the search routines.
    private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
    if (sp == SearchPolicy.binarySearch)
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
    if (sp == SearchPolicy.trot || sp == SearchPolicy.gallop)
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
    if (sp == SearchPolicy.trotBackwards || sp == SearchPolicy.gallopBackwards)
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
   This function uses binary search with policy $(D sp) to find the
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
    if (isTwoWayCompatible!(predFun, ElementType!Range, V))
    {
        return this[0 .. getTransitionIndex!(sp, geq)(value)];
    }

// upperBound
/**
   This function uses binary search with policy $(D sp) to find the
   largest right subrange on which $(D pred(value, x)) is $(D true)
   for all $(D x) (e.g., if $(D pred) is "less than", returns the
   portion of the range with elements strictly greater than $(D
   value)). The search schedule and its complexity are documented in
   $(LREF SearchPolicy).  See also STL's
   $(WEB sgi.com/tech/stl/lower_bound.html,upper_bound).

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
        return this[getTransitionIndex!(sp, gt)(value) .. length];
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
    if (isTwoWayCompatible!(predFun, ElementType!Range, V))
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
    if (isTwoWayCompatible!(predFun, ElementType!Range, V))
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

    // Explicitly undocumented. It will be removed in November 2013.
    deprecated("Please use contains instead.") alias contains canFind;
}

// Doc examples
unittest
{
    auto a = [ 1, 2, 3, 42, 52, 64 ];
    auto r = assumeSorted(a);
    assert(r.contains(3));
    assert(!r.contains(32));
    auto r1 = sort!"a > b"(a);
    assert(r1.contains(3));
    assert(!r1.contains(32));
    assert(r1.release() == [ 64, 52, 42, 3, 2, 1 ]);
}

unittest
{
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

unittest
{
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

unittest
{
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

unittest
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

unittest
{
    auto a = [ 1, 2, 3, 42, 52, 64 ];
    auto r = assumeSorted(a);
    assert(r.contains(42));
    swap(a[3], a[5]);                  // illegal to break sortedness of original range
    assert(!r.contains(42));            // passes although it shouldn't
}

unittest
{
    immutable(int)[] arr = [ 1, 2, 3 ];
    auto s = assumeSorted(arr);
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
if (isRandomAccessRange!(Unqual!R))
{
    return SortedRange!(Unqual!R, pred)(r);
}

unittest
{
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

unittest
{
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    auto p = assumeSorted(a).upperBound(3);
    assert(equal(p, [4, 4, 5, 6 ]));
    p = assumeSorted(a).upperBound(4.2);
    assert(equal(p, [ 5, 6 ]));
}

unittest
{
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

unittest
{
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    if (a.length)
    {
        auto b = a[a.length / 2];
        //auto r = sort(a);
        //assert(r.contains(b));
    }
}

unittest
{
    auto a = [ 5, 7, 34, 345, 677 ];
    auto r = assumeSorted(a);
    a = null;
    r = assumeSorted(a);
    a = [ 1 ];
    r = assumeSorted(a);
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

    Examples:
--------------------
import std.algorithm;
ubyte[] buffer = [1, 9, 45, 12, 22];
auto found1 = find(buffer, 45);
assert(found1 == [45, 12, 22]);
assert(buffer == [1, 9, 45, 12, 22]);

auto wrapped1 = refRange(&buffer);
auto found2 = find(wrapped1, 45);
assert(*found2.ptr == [45, 12, 22]);
assert(buffer == [45, 12, 22]);

auto found3 = find(wrapped2.save, 22);
assert(*found3.ptr == [22]);
assert(buffer == [45, 12, 22]);

string str = "hello world";
auto wrappedStr = refRange(&str);
assert(str.front == 'h');
str.popFrontN(5);
assert(str == " world");
assert(wrappedStr.front == ' ');
assert(*wrappedStr.ptr == " world");
--------------------
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

    Examples:
--------------------
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
--------------------
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
        private static void _testSave(R)(R* range)
        {
            (*range).save;
        }

        static if(isSafe!(_testSave!R))
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
                   `alias typeof((*_range).save) S;` ~
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
                   `alias typeof((*_range)[begin .. end]) S;` ~
                   `static assert(hasSlicing!S, S.stringof ~ " is not sliceable.");` ~
                   `auto mem = new void[S.sizeof];` ~
                   `emplace!S(mem, cast(S)(*_range)[begin .. end]);` ~
                   `return RefRange!S(cast(S*)mem.ptr);`;
        }
    }


private:

    R* _range;
}

//Verify Example.
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

//Verify opAssign Example.
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

        assert(*wrapper[3 .. 6].ptr, [41, 3, 40]);
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

unittest    // bug 9060
{
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
