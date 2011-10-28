// Written in the D programming language.

/**
This module defines the notion of range (by the membership tests $(D
isInputRange), $(D isForwardRange), $(D isBidirectionalRange), $(D
isRandomAccessRange)), range capability tests (such as $(D hasLength)
or $(D hasSlicing)), and a few useful _range incarnations.

Source: $(PHOBOSSRC std/_range.d)

Macros:

WIKI = Phobos/StdRange

Copyright: Copyright by authors 2008-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu), David Simcha. Credit
for some of the ideas in building this module goes to $(WEB
fantascienza.net/leonardo/so/, Leonardo Maffi).
 */
module std.range;

public import std.array;
import core.bitop;
import std.algorithm, std.conv, std.exception,  std.functional,
    std.traits, std.typecons, std.typetuple;

// For testing only.  This code is included in a string literal to be included
// in whatever module it's needed in, so that each module that uses it can be
// tested individually, without needing to link to std.range.
enum dummyRanges = q{
    // Used with the dummy ranges for testing higher order ranges.
    enum RangeType {
        Input,
        Forward,
        Bidirectional,
        Random
    }

    enum Length {
        Yes,
        No
    }

    enum ReturnBy {
        Reference,
        Value
    }

    // Range that's useful for testing other higher order ranges,
    // can be parametrized with attributes.  It just dumbs down an array of
    // numbers 1..10.
    struct DummyRange(ReturnBy _r, Length _l, RangeType _rt) {
        // These enums are so that the template params are visible outside
        // this instantiation.
        enum r = _r;
        enum l = _l;
        enum rt = _rt;

        uint[] arr = [1U, 2U, 3U, 4U, 5U, 6U, 7U, 8U, 9U, 10U];

        void reinit() {
            // Workaround for DMD bug 4378
            arr = [1U, 2U, 3U, 4U, 5U, 6U, 7U, 8U, 9U, 10U];
        }

        void popFront() {
            arr = arr[1..$];
        }

        @property bool empty() {
            return arr.length == 0;
        }

        static if(r == ReturnBy.Reference) {
            @property ref uint front() {
                return arr[0];
            }

            @property void front(uint val) {
                arr[0] = val;
            }

        } else {
            @property uint front() {
                return arr[0];
            }
        }

        static if(rt >= RangeType.Forward) {
            @property typeof(this) save() {
                return this;
            }
        }

        static if(rt >= RangeType.Bidirectional) {
            void popBack() {
                arr = arr[0..$ - 1];
            }

            static if(r == ReturnBy.Reference) {
                @property ref uint back() {
                    return arr[$ - 1];
                }

                @property void back(uint val) {
                    arr[$ - 1] = val;
                }

            } else {
                @property uint back() {
                    return arr[$ - 1];
                }
            }
        }

        static if(rt >= RangeType.Random) {
            static if(r == ReturnBy.Reference) {
                ref uint opIndex(size_t index) {
                    return arr[index];
                }

                void opIndexAssign(uint val, size_t index) {
                    arr[index] = val;
                }
            } else {
                @property uint opIndex(size_t index) {
                    return arr[index];
                }
            }

            typeof(this) opSlice(size_t lower, size_t upper) {
                auto ret = this;
                ret.arr = arr[lower..upper];
                return ret;
            }
        }

        static if(l == Length.Yes) {
            @property size_t length() {
                return arr.length;
            }
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
    {
        R r;              // can define a range object
        if (r.empty) {}   // can test for empty
        r.popFront();     // can invoke popFront()
        auto h = r.front; // can get the front of the range
    }()));
}

unittest
{
    struct A {}
    static assert(!isInputRange!(A));
    struct B
    {
        void popFront();
        @property bool empty();
        @property int front();
    }
    static assert(isInputRange!(B));
    static assert(isInputRange!(int[]));
    static assert(isInputRange!(char[]));
    static assert(!isInputRange!(char[4]));
}

/**
Outputs $(D e) to $(D r). The exact effect is dependent upon the two
types. which must be an output range. Several cases are accepted, as
described below. The code snippets are attempted in order, and the
first to compile "wins" and gets evaluated.

$(BOOKTABLE ,

$(TR $(TH Code Snippet) $(TH Scenario))

$(TR $(TD $(D r.put(e);)) $(TD $(D R) specifically defines a method
$(D put) accepting an $(D E).))

$(TR $(TD $(D r.put([ e ]);)) $(TD $(D R) specifically defines a
method $(D put) accepting an $(D E[]).))

$(TR $(TD $(D r.front = e; r.popFront();)) $(TD $(D R) is an input
range and $(D e) is assignable to $(D r.front).))

$(TR $(TD $(D for (; !e.empty; e.popFront()) put(r, e.front);)) $(TD
Copying range $(D E) to range $(D R).))

$(TR $(TD $(D r(e);)) $(TD $(D R) is e.g. a delegate accepting an $(D
E).))

$(TR $(TD $(D r([ e ]);)) $(TD $(D R) is e.g. a $(D delegate)
accepting an $(D E[]).))

)
 */
void put(R, E)(ref R r, E e)
{
    static if (hasMember!(R, "put") ||
    (isPointer!R && is(pointerTarget!R == struct) &&
     hasMember!(pointerTarget!R, "put")))
    {
        // commit to using the "put" method
        static if (!isArray!R && is(typeof(r.put(e))))
        {
            r.put(e);
        }
        else static if (!isArray!R && is(typeof(r.put((&e)[0..1]))))
        {
            r.put((&e)[0..1]);
        }
        else
        {
            static assert(false,
                    "Cannot put a "~E.stringof~" into a "~R.stringof);
        }
    }
    else
    {
        static if (isInputRange!R)
        {
            // Commit to using assignment to front
            static if (is(typeof(r.front = e, r.popFront())))
            {
                r.front = e;
                r.popFront();
            }
            else static if (isInputRange!E && is(typeof(put(r, e.front))))
            {
                for (; !e.empty; e.popFront()) put(r, e.front);
            }
            else
            {
                static assert(false,
                        "Cannot put a "~E.stringof~" into a "~R.stringof);
            }
        }
        else
        {
            // Commit to using opCall
            static if (is(typeof(r(e))))
            {
                r(e);
            }
            else static if (is(typeof(r((&e)[0..1]))))
            {
                r((&e)[0..1]);
            }
            else
            {
                static assert(false,
                        "Cannot put a "~E.stringof~" into a "~R.stringof);
            }
        }
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

/**
Returns $(D true) if $(D R) is an output range for elements of type
$(D E). An output range is defined functionally as a range that
supports the operation $(D put(r, e)) as defined above.
 */
template isOutputRange(R, E)
{
    enum bool isOutputRange = is(typeof({ R r; E e; put(r, e); }()));
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
R r2 = r1.save; // can save the current position into another range
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
    {
        R r1;
        R r2 = r1.save; // can call "save" against a range object
    }));
}

unittest
{
    static assert(!isForwardRange!(int));
    static assert(isForwardRange!(int[]));
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
    enum bool isBidirectionalRange = isForwardRange!R
        // @@@BUG@@@: parens shouldn't be needed here
        && is(typeof(R.init.back()) == typeof(R.init.front()))
        && is(typeof({ R r; r.popBack(); }));
}

unittest
{
    struct A {}
    static assert(!isBidirectionalRange!(A));
    struct B
    {
        void popFront();
        bool empty();
        int front();
    }
    static assert(!isBidirectionalRange!(B));
    struct C
    {
        @property bool empty();
        @property C save();
        void popFront();
        @property int front();
        void popBack();
        @property int back();
    }
    static assert(isBidirectionalRange!(C));
    static assert(isBidirectionalRange!(int[]));
    static assert(isBidirectionalRange!(char[]));
}

/**
Returns $(D true) if $(D R) is a random-access range. A random-access
range is a bidirectional range that also offers the primitive $(D
opIndex), OR an infinite forward range that offers $(D opIndex). In
either case, the range must either offer $(D length) or be
infinite. The following code should compile for any random-access
range.

----
R r;
static assert(isForwardRange!R);  // range is forward
static assert(isBidirectionalRange!R || isInfinite!R);
                                  // range is bidirectional or infinite
auto e = r[1];                    // can index
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
    enum bool isRandomAccessRange =
        (isBidirectionalRange!R || isForwardRange!R && isInfinite!R)
        && is(typeof(R.init[1]))
        && !isNarrowString!R
        && (hasLength!R || isInfinite!R);
}

unittest
{
    struct A {}
    static assert(!isRandomAccessRange!(A));
    struct B
    {
        void popFront();
        bool empty();
        int front();
    }
    static assert(!isRandomAccessRange!(B));
    struct C
    {
        void popFront();
        bool empty();
        int front();
        void popBack();
        int back();
    }
    static assert(!isRandomAccessRange!(C));
    struct D
    {
        bool empty();
        @property D save();
        int front();
        void popFront();
        int back();
        void popBack();
        ref int opIndex(uint);
        @property size_t length();
        //int opSlice(uint, uint);
    }
    static assert(isRandomAccessRange!(D));
    static assert(isRandomAccessRange!(int[]));
}

/**
Returns $(D true) iff the range supports the $(D moveFront) primitive,
as well as $(D moveBack) and $(D moveAt) if it's a bidirectional or
random access range.  These may be explicitly implemented, or may work
via the default behavior of the module level functions $(D moveFront)
and friends.
 */
template hasMobileElements(R)
{
    enum bool hasMobileElements = is(typeof({
        R r;
        return moveFront(r);
    })) && (!isBidirectionalRange!R || is(typeof({
        R r;
        return moveBack(r);
    }))) && (!isRandomAccessRange!R || is(typeof({
        R r;
        return moveAt(r, 0);
    })));
}

unittest {
    static struct HasPostblit {
        this(this) {}
    }

    auto nonMobile = map!"a"(repeat(HasPostblit.init));
    static assert(!hasMobileElements!(typeof(nonMobile)));
    static assert(hasMobileElements!(int[]));
    static assert(hasMobileElements!(typeof(iota(1000))));
}

/**
The element type of $(D R). $(D R) does not have to be a range. The
element type is determined as the type yielded by $(D r.front) for an
object $(D r) or type $(D R). For example, $(D ElementType!(T[])) is
$(D T). If $(D R) is not a range, $(D ElementType!R) is $(D void).
 */
template ElementType(R)
{
    static if (is(typeof({return R.init.front();}()) T))
        alias T ElementType;
    else
        alias void ElementType;
}

unittest
{
    enum XYZ : string { a = "foo" };
    auto x = front(XYZ.a);
    static assert(is(ElementType!(XYZ) : dchar));
    immutable char[3] a = "abc";
    static assert(is(ElementType!(typeof(a)) : dchar));
    int[] i;
    static assert(is(ElementType!(typeof(i)) : int));
    void[] buf;
    static assert(is(ElementType!(typeof(buf)) : void));
}

/**
The encoding element type of $(D R). For narrow strings ($(D char[]),
$(D wchar[]) and their qualified variants including $(D string) and
$(D wstring)), $(D ElementEncodingType) is the character type of the
string. For all other ranges, $(D ElementEncodingType) is the same as
$(D ElementType).
 */
template ElementEncodingType(R)
{
    static if (isNarrowString!R)
        alias typeof(R.init[0]) ElementEncodingType;
    else
        alias ElementType!R ElementEncodingType;
}

unittest
{
    enum XYZ : string { a = "foo" };
    auto x = front(XYZ.a);
    static assert(is(ElementType!(XYZ) : dchar));
    static assert(is(ElementEncodingType!(char[]) == char));
    static assert(is(ElementEncodingType!(string) == immutable char));
    immutable char[3] a = "abc";
    static assert(is(ElementType!(typeof(a)) : dchar));
    int[] i;
    static assert(is(ElementType!(typeof(i)) == int));
    static assert(is(ElementEncodingType!(typeof(i)) == int));
    void[] buf;
    static assert(is(ElementType!(typeof(buf)) : void));
}

/**
Returns $(D true) if $(D R) is a forward range and has swappable
elements. The following code should compile for any random-access
range.

----
R r;
static assert(isForwardRange!(R));   // range is forward
swap(r.front, r.front);              // can swap elements of the range
----
 */
template hasSwappableElements(R)
{
    enum bool hasSwappableElements = isForwardRange!R && is(typeof(
    {
        R r;
        swap(r.front, r.front);             // can swap elements of the range
    }));
}

unittest
{
    static assert(!hasSwappableElements!(const int[]));
    static assert(!hasSwappableElements!(const(int)[]));
    static assert(hasSwappableElements!(int[]));
    //static assert(hasSwappableElements!(char[]));
}

/**
Returns $(D true) if $(D R) is a forward range and has mutable
elements. The following code should compile for any random-access
range.

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
    {
        R r;
        static assert(isForwardRange!(R)); // range is forward
        auto e = r.front;
        r.front = e;                       // can assign elements of the range
    }));
}

unittest
{
    static assert(!hasAssignableElements!(const int[]));
    static assert(!hasAssignableElements!(const(int)[]));
    static assert(hasAssignableElements!(int[]));
}

/**
Tests whether $(D R) has lvalue elements.  These are defined as elements that
can be passed by reference and have their address taken.
*/
template hasLvalueElements(R)
{
    enum bool hasLvalueElements =
        is(typeof(&R.init.front()) == ElementType!(R)*);
}

unittest {
    static assert(hasLvalueElements!(int[]));
    static assert(!hasLvalueElements!(typeof(iota(3))));
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
    enum bool hasLength = is(typeof(R.init.length) : ulong) &&
        !isNarrowString!R;
}

unittest
{
    static assert(!hasLength!(char[]));
    static assert(hasLength!(int[]));
    struct A { ulong length; }
    static assert(hasLength!(A));
    struct B { size_t length() { return 0; } }
    static assert(!hasLength!(B));
    struct C { @property size_t length() { return 0; } }
    static assert(hasLength!(C));
}

/**
Returns $(D true) if $(D Range) is an infinite input range. An
infinite input range is an input range that has a statically-defined
enumerated member called $(D empty) that is always $(D false), for
example:

----
struct MyInfiniteRange
{
    enum bool empty = false;
    ...
}
----
 */

template isInfinite(Range)
{
    static if (isInputRange!Range && is(char[1 + Range.empty]))
        enum bool isInfinite = !Range.empty;
    else
        enum bool isInfinite = false;
}

unittest
{
    assert(!isInfinite!(int[]));
    assert(isInfinite!(Repeat!(int)));
}

/**
Returns $(D true) if $(D Range) offers a slicing operator with
integral boundaries, that in turn returns an input range type. The
following code should compile for $(D hasSlicing) to be $(D true):

----
Range r;
auto s = r[1 .. 2];
static assert(isInputRange!(typeof(s)));
----
 */
template hasSlicing(Range)
{
    enum bool hasSlicing = !isNarrowString!Range && is(typeof(
    {
        Range r;
        auto s = r[1 .. 2];
        static assert(isInputRange!(typeof(s)));
    }));
}

unittest
{
    static assert(hasSlicing!(int[]));
    struct A { int opSlice(uint, uint); }
    static assert(!hasSlicing!(A));
    struct B { int[] opSlice(uint, uint); }
    static assert(hasSlicing!(B));
    static assert(!hasSlicing!string);
}

/**
This is a best-effort implementation of $(D length) for any kind of
range.

If $(D hasLength!(Range)), simply returns $(D range.length) without
checking $(D upTo).

Otherwise, walks the range through its length and returns the number
of elements seen. Performes $(BIGOH n) evaluations of $(D range.empty)
and $(D range.popFront()), where $(D n) is the effective length of $(D
range). The $(D upTo) parameter is useful to "cut the losses" in case
the interest is in seeing whether the range has at least some number
of elements. If the parameter $(D upTo) is specified, stops if $(D
upTo) steps have been taken and returns $(D upTo).
 */
auto walkLength(Range)(Range range, const size_t upTo = size_t.max)
if (isInputRange!Range)
{
    static if (hasLength!Range)
    {
        return range.length;
    }
    else
    {
        size_t result;
        // Optimize this tight loop by specializing for the common
        // case upTo == default parameter
        if (upTo == size_t.max)
            for (; !range.empty; range.popFront()) ++result;
        else
            for (; result < upTo && !range.empty; range.popFront()) ++result;
        return result;
    }
}

unittest
{
    int[] a = [ 1, 2, 3 ];
    assert(walkLength(a) == 3);
    assert(walkLength(a, 0) == 3);
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
            void popBack() { source.popFront; }

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
random-access range, moves by indexing into the range; otehrwise,
moves by successive calls to $(D popFront). Applying stride twice to
the same range results in a stride that with a step that is the
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
                    immutable translatedLower = lower * _n;
                    immutable translatedUpper = (upper == 0) ? 0 :
                        (upper * _n - (_n - 1));
                    return typeof(this)(source[translatedLower..translatedUpper], _n);
                }

            static if (hasLength!R)
                @property auto length()
                {
                    return (source.length + _n - 1) / _n;
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

    auto s2 = stride(arr, 2);
    assert(equal(s2[0..2], [1,3]));
    assert(s2[0..2].length == 2);
    assert(equal(s2[1..5], [3, 5, 7, 9]));
    assert(s2[1..5].length == 4);
    assert(s2[0..0].empty);

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
if (Ranges.length > 0 && allSatisfy!(isInputRange, staticMap!(Unqual, Ranges)))
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
                    typeof(this) result;
                    foreach (i, Unused; R)
                    {
                        result.source[i] = source[i].save;
                    }
                    return result;
                }

            void popFront()
            {
                foreach (i, Unused; R)
                {
                    if (source[i].empty) continue;
                    source[i].popFront;
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
                @property size_t length()
                {
                    size_t result;
                    foreach (i, Unused; R)
                    {
                        result += source[i].length;
                    }
                    return result;
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

        bool empty()
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
            auto save()
            {
                Result result;
                result._current = _current;
                foreach (i, Unused; Rs)
                {
                    result.source[i] = source[i].save;
                }
                return result;
            }

        static if (allSatisfy!(hasLength, Rs))
        {
            size_t length()
            {
                size_t result;
                foreach (i, R; Rs)
                {
                    result += source[i].length;
                }
                return result;
            }
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
    r.front() = 5;
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
if (isInputRange!(Unqual!Range)
        && !(hasSlicing!(Unqual!Range) || is(Range T == Take!T)))
{
    private alias Unqual!Range R;

    // User accessible in read and write
    public R source;

    private size_t _maxAvailable;
    private enum bool byRef = is(typeof(&_input.front) == ElementType!(R)*);

    alias R Source;

    @property bool empty()
    {
        return _maxAvailable == 0 || source.empty;
    }

    @property auto ref front()
    {
        assert(_maxAvailable > 0,
                "Attempting to fetch the front of an empty " ~ Take.stringof);
        return source.front;
    }

    void popFront()
    {
        assert(_maxAvailable > 0,
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
            assert(_maxAvailable);
            // This has to return auto instead of void because of Bug 4706.
            source.front = v;
        }

    static if (hasMobileElements!R)
    {
        auto moveFront()
        {
            assert(_maxAvailable);
            return .moveFront(source);
        }
    }

    static if (isInfinite!R)
    {
        @property size_t length() const
        {
            return _maxAvailable;
        }
    }
    else static if (hasLength!R)
    {
        @property size_t length()
        {
            return min(_maxAvailable, source.length);
        }
    }

    static if (isRandomAccessRange!R)
    {
        void popBack()
        {
            assert(_maxAvailable > 0,
                "Attempting to popBack() past the beginning of a "
                ~ Take.stringof);
            --_maxAvailable;
        }

        @property auto ref back()
        {
            assert(_maxAvailable);
            return source[this.length - 1];
        }

        auto ref opIndex(size_t index)
        {
            assert(index < this.length,
                "Attempting to index out of the bounds of a "
                ~ Take.stringof);
            return source[index];
        }

        static if (hasAssignableElements!R)
        {
            auto back(ElementType!R v)
            {
                // This has to return auto instead of void because of Bug 4706.
                assert(_maxAvailable);
                source[this.length - 1] = v;
            }

            void opIndexAssign(ElementType!R v, size_t index)
            {
                assert(index < this.length,
                        "Attempting to index out of the bounds of a "
                        ~ Take.stringof);
                source[index] = v;
            }
        }

        static if (hasMobileElements!R)
        {
            auto moveBack()
            {
                assert(_maxAvailable);
                return .moveAt(source, this.length - 1);
            }

            auto moveAt(size_t index)
            {
                assert(index < this.length,
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
if (isInputRange!(Unqual!R) && (hasSlicing!(Unqual!R) || is(R T == Take!T)))
{
    alias R Take;
}

// take for ranges with slicing (finite or infinite)
/// ditto
Take!R take(R)(R input, size_t n)
if (isInputRange!(Unqual!R) && hasSlicing!(Unqual!R))
{
    static if (hasLength!R)
    {
        // @@@BUG@@@
        //return input[0 .. min(n, $)];
        return input[0 .. min(n, input.length)];
    }
    else
    {
        static assert(isInfinite!R,
                "Nonsensical finite range with slicing but no length");
        return input[0 .. n];
    }
}

// take(take(r, n1), n2)
Take!(R) take(R)(R input, size_t n)
if (is(R T == Take!T))
{
    return R(input.source, min(n, input._maxAvailable));
}

// Regular take for input ranges
Take!(R) take(R)(R input, size_t n)
if (isInputRange!(Unqual!R) && !hasSlicing!(Unqual!R) && !is(R T == Take!T))
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

If $(D R) has slicing, $(D takeExactly) simply returns a slice of $(D
range). Otherwise if $(D R) is an input range, the type of the result
is an input range with length. Finally, if $(D R) is a forward range
(including bidirectional), the type of the result is a forward range
with length.
 */
auto takeExactly(R)(R range, size_t n)
if (isInputRange!R && !hasSlicing!R)
{
    static if (is(typeof(takeExactly(range._input, n)) == R))
    {
        // takeExactly(takeExactly(r, n1), n2) has the same type as
        // takeExactly(r, n1) and simply returns takeExactly(r, n2)
        range._n = n;
        return range;
    }
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
                return _input.front();
            }
            void popFront() { _input.popFront(); --_n; }
            @property size_t length() const { return _n; }

            static if (isForwardRange!R)
                auto save() { return this; }
        }

        return Result(range, n);
    }
}

auto takeExactly(R)(R range, size_t n)
if (hasSlicing!R)
{
    return range[0 .. n];
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

    assert(equal(takeExactly(e, 4), [1, 2, 3, 4]));
    // b[1]++;
}

/**
Returns a range with at most one element; for example, $(D
takeOne([42, 43, 44])) returns a range consisting of the integer $(D
42). Calling $(D popFront()) off that range renders it empty.

Sometimes an empty range with the same signature is needed. For such
ranges use $(D takeNone!R()). For example:

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
s = takeNone!(int[])();
assert(s.length == 0);
assert(s.empty);
----

In effect $(D takeOne(r)) is somewhat equivalent to $(take(r, 1)) and
$(D takeNone(r)) is equivalent to $(D take(r, 0)), but in certain
interfaces it is important to know statically that the range may only
have at most one element.

The type returned by $(D takeOne) and $(D takeNone) is a random-access
range with length regardless of $(D R)'s capability (another feature
that distinguishes $(D takeOne)/$(D takeNone) from $(D take)).
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
            auto save() { return Result(_source.save, empty); }
            @property auto ref back() { assert(!empty); return _source.front; }
            @property size_t length() const { return !empty; }
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

/// Ditto
auto takeNone(R)() if (isInputRange!R)
{
    return typeof(takeOne(R.init)).init;
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
    s = takeNone!(int[])();
    assert(s.length == 0);
    assert(s.empty);
}


/++
    Convenience function which calls $(D $(LREF popFrontN)(range, n)) and
    returns $(D range).

    Examples:
--------------------
assert(drop([0, 2, 1, 5, 0, 3], 3) == [5, 0, 3]);
assert(drop("hello world", 6) == "world");
assert(drop("hello world", 50).empty);
assert(equal(drop(take("hello world", 6), 3), "lo "));
--------------------
  +/
R drop(R)(R range, size_t n)
    if(isInputRange!R)
{
    popFrontN(range, n);
    return range;
}

//Verify Examples
unittest
{
    assert(drop([0, 2, 1, 5, 0, 3], 3) == [5, 0, 3]);
    assert(drop("hello world", 6) == "world");
    assert(drop("hello world", 50).empty);
    assert(equal(drop(take("hello world", 6), 3), "lo "));
}

unittest
{
    assert(drop("", 5).empty);
    assert(equal(drop(filter!"true"([0, 2, 1, 5, 0, 3]), 3), [5, 0, 3]));
}


/**
Eagerly advances $(D r) itself (not a copy) $(D n) times (by calling
$(D r.popFront) at most $(D n) times). The pass of $(D r) into $(D
popFrontN) is by reference, so the original range is
affected. Completes in $(BIGOH 1) steps for ranges that support
slicing, and in $(BIGOH n) time for all other ranges.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
a.popFrontN(2);
assert(a == [ 3, 4, 5 ]);
----
*/
size_t popFrontN(Range)(ref Range r, size_t n) if (isInputRange!(Range))
{
    static if (hasSlicing!Range && hasLength!Range)
    {
        n = min(n, r.length);
        r = r[n .. r.length];
    }
    else
    {
        static if (hasLength!Range)
        {
            n = min(n, r.length);
            foreach (i; 0 .. n)
            {
                r.popFront();
            }
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

unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    a.popFrontN(2);
    assert(a == [ 3, 4, 5 ]);
}

/**
   Eagerly reduces $(D r) itself (not a copy) $(D n) times from its right
   side (by calling $(D r.popBack) $(D n) times). The pass of $(D r) into
   $(D popBackN) is by reference, so the original range is
   affected. Completes in $(BIGOH 1) steps for ranges that support
   slicing, and in $(BIGOH n) time for all other ranges.

   Returns the actual number of elements popped.

   Example:
   ----
   int[] a = [ 1, 2, 3, 4, 5 ];
   a.popBackN(2);
   assert(a == [ 1, 2, 3 ]);
   ----
*/
size_t popBackN(Range)(ref Range r, size_t n) if (isInputRange!(Range))
{
    static if (hasSlicing!(Range) && hasLength!(Range))
    {
        n = cast(size_t) min(n, r.length);
        auto newLen = r.length - n;
        r = r[0 .. newLen];
    }
    else
    {
        foreach (i; 0 .. n)
        {
            if (r.empty) return i;
            r.popBack;
        }
    }
    return n;
}

unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    a.popBackN(2);
    assert(a == [ 1, 2, 3 ]);
}
unittest
{
    auto LL = iota(1L, 7L);
    auto r = popBackN(LL, 2);
    assert(equal(LL, [1L, 2L, 3L, 4L]));
    assert(r == 2);
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
    @property T back() { return _value; }
    /// Ditto
    enum bool empty = false;
    /// Ditto
    void popFront() {}
    /// Ditto
    void popBack() {}
    /// Ditto
    @property Repeat!T save() { return this; }
    /// Ditto
    T opIndex(size_t) { return _value; }
}

/// Ditto
Repeat!(T) repeat(T)(T value) { return Repeat!(T)(value); }

unittest
{
    enforce(equal(take(repeat(5), 4), [ 5, 5, 5, 5 ][]));
    static assert(isForwardRange!(Repeat!(uint)));
}

/**
   Repeats $(D value) exactly $(D n) times. Equivalent to $(D
   take(repeat(value), n)).
*/
Take!(Repeat!T) repeat(T)(T value, size_t n)
{
    return take(repeat(value), n);
}

/// Equivalent to $(D repeat(value, n)). Scheduled for deprecation.
Take!(Repeat!T) replicate(T)(T value, size_t n)
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
$(D index). $(D Cycle) is specialized for statically-sized arrays,
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

    static if (isRandomAccessRange!(R) && hasLength!(R))
    {
        R _original;
        size_t _index;
        this(R input, size_t index = 0) { _original = input; _index = index; }
        /// Range primitive implementations.
        @property auto ref front()
        {
            return _original[_index % _original.length];
        }
        /// Ditto
        static if (hasAssignableElements!R)
        {
            @property auto front(ElementType!R val)
            {
                _original[_index % _original.length] = val;
            }
        }
        /// Ditto
        enum bool empty = false;
        /// Ditto
        void popFront() { ++_index; }
        auto ref opIndex(size_t n)
        {
            return _original[(n + _index) % _original.length];
        }
        /// Ditto
        static if (hasAssignableElements!R)
        {
            auto opIndexAssign(ElementType!R val, size_t n)
            {
                _original[(n + _index) % _original.length] = val;
            }
        }
        /// Ditto
        @property Cycle!(R) save() {
            return Cycle!(R)(this._original.save, this._index);
        }
    }
    else
    {
        R _original, _current;
        this(R input) { _original = input; _current = input.save; }
        /// Range primitive implementations.
        @property auto ref front() { return _current.front; }
        /// Ditto
        static if (hasAssignableElements!R)
        {
            @property auto front(ElementType!R val)
            {
                _current.front = val;
            }
        }
        /// Ditto
        static if (isBidirectionalRange!(R))
            @property auto ref back() { return _current.back; }
        /// Ditto
        enum bool empty = false;
        /// Ditto
        void popFront()
        {
            _current.popFront;
            if (_current.empty) _current = _original;
        }

        @property Cycle!R save() {
            Cycle!R ret;
            ret._original = this._original.save;
            ret._current =  this._current.save;
            return ret;
        }
    }
}

/// Ditto
template Cycle(R) if (isInfinite!R)
{
    alias R Cycle;
}

/// Ditto
struct Cycle(R) if (isStaticArray!R)
{
    private alias typeof(R[0]) ElementType;
    private ElementType* _ptr;
    private size_t _index;

    this(ref R input, size_t index = 0)
    {
        _ptr = input.ptr;
        _index = index;
    }
    /// Range primitive implementations.
    @property ref ElementType front()
    {
        return _ptr[_index % R.length];
    }
    /// Ditto
    enum bool empty = false;
    /// Ditto
    void popFront() { ++_index; }
    ref ElementType opIndex(size_t n)
    {
        return _ptr[(n + _index) % R.length];
    }

    @property Cycle!(R) save() {
        return this;
    }
}

/// Ditto
Cycle!R cycle(R)(R input)
if (isForwardRange!(Unqual!R) && !isInfinite!(Unqual!R))
{
    return Cycle!(R)(input);
}

/// Ditto
Cycle!R cycle(R)(R input, size_t index)
if (isRandomAccessRange!(Unqual!R) && !isInfinite!(Unqual!R))
{
    return Cycle!R(input, index);
}

/// Ditto
Cycle!(R) cycle(R)(R input) if (isInfinite!(R))
{
    return input;
}

/// Ditto
Cycle!(R) cycle(R)(ref R input, size_t index = 0) if (isStaticArray!R)
{
    return Cycle!(R)(input, index);
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

    foreach(DummyType; AllDummyRanges) {
        static if (isForwardRange!(DummyType)) {
            DummyType dummy;
            auto cy = cycle(dummy);
            static assert(isForwardRange!(typeof(cy)));
            auto t = take(cy, 20);
            assert(equal(t, [1,2,3,4,5,6,7,8,9,10,1,2,3,4,5,6,7,8,9,10]));

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
                }
            }
        }
    }
}

unittest // For infinite ranges
{
    struct InfRange
    {
        void popFront() { }
        int front() { return 0; }
        enum empty = false;
    }

    InfRange i;
    auto c = cycle(i);
    assert (c == i);
}

private template lengthType(R) { alias typeof(R.init.length) lengthType; }

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
if(Ranges.length && allSatisfy!(isInputRange, staticMap!(Unqual, Ranges)))
{
    alias staticMap!(Unqual, Ranges) R;
    Tuple!R ranges;
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
        bool empty()
        {
            final switch (stoppingPolicy)
            {
            case StoppingPolicy.shortest:
                foreach (i, Unused; R)
                {
                    if (ranges[i].empty) return true;
                }
                break;
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
                            ranges.field[i + 1].empty,
                            "Inequal-length ranges passed to Zip");
                }
                break;
            }
            return false;
        }
    }

    static if (allSatisfy!(isForwardRange, R))
        @property Zip save()
        {
            Zip result;
            result.stoppingPolicy = stoppingPolicy;
            foreach (i, Unused; R)
            {
                result.ranges[i] = ranges[i].save;
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
            @property ElementType moveBack()
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
                    enforce(!ranges[0].empty, "Invalid Zip object");
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
        @property auto length()
        {
            CommonType!(staticMap!(lengthType, R)) result = ranges[0].length;
            if (stoppingPolicy == StoppingPolicy.requireSameLength)
                return result;
            foreach (i, Unused; R[1 .. $])
            {
                if (stoppingPolicy == StoppingPolicy.shortest)
                {
                    result = min(ranges.field[i + 1].length, result);
                }
                else
                {
                    assert(stoppingPolicy == StoppingPolicy.longest);
                    result = max(ranges.field[i + 1].length, result);
                }
            }
            return result;
        }

/**
   Returns a slice of the range. Defined only if all range define
   slicing.
*/
    static if (allSatisfy!(hasSlicing, R))
        Zip opSlice(size_t from, size_t to)
        {
            Zip result = void;
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
auto zip(R...)(R ranges)
if (allSatisfy!(isInputRange, staticMap!(Unqual, R)))
{
    return Zip!R(ranges);
}

/// Ditto
auto zip(R...)(StoppingPolicy sp, R ranges)
if (allSatisfy!(isInputRange, staticMap!(Unqual, R)))
{
    return Zip!R(ranges, sp);
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
    float[] b = [ 1., 2, 3 ];
    foreach (e; zip(a, b))
    {
        assert(e[0] == e[1]);
    }

    swap(a[0], a[1]);
    auto z = zip(a, b);
    //swap(z.front(), z.back());
    sort!("a[0] < b[0]")(zip(a, b));
    assert(a == [1, 2, 3]);
    assert(b == [2., 1, 3]);

    // Test infiniteness propagation.
    static assert(isInfinite!(typeof(zip(repeat(1), repeat(1)))));

    // Test stopping policies with both value and reference.
    auto a1 = [1, 2];
    auto a2 = [1, 2, 3];
    auto stuff = tuple(tuple(a1, a2),
            tuple(filter!"a"(a1), filter!"a"(a2)));

    alias Zip!(immutable int[], immutable float[]) FOO;

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

/* CTFE function to generate opApply loop for Lockstep.*/
private string lockstepApply(Ranges...)(bool withIndex) if (Ranges.length > 0)
{
    // Since there's basically no way to make this code readable as-is, I've
    // included formatting to make the generated code look "normal" when
    // printed out via pragma(msg).
    string ret = "int opApply(scope int delegate(";

    if (withIndex)
    {
        ret ~= "ref size_t, ";
    }

    foreach (ti, Unused; Ranges)
    {
        ret ~= "ref ElementType!(Ranges[" ~ to!string(ti) ~ "]), ";
    }

    // Remove trailing ,
    ret = ret[0..$ - 2];
    ret ~= ") dg) {\n";

    // Shallow copy _ranges to be consistent w/ regular foreach.
    ret ~= "\tauto ranges = _ranges;\n";
    ret ~= "\tint res;\n";

    if (withIndex)
    {
        ret ~= "\tsize_t index = 0;\n";
    }

    // For every range not offering ref return, declare a variable to statically
    // copy to so we have lvalue access.
    foreach(ti, Range; Ranges)
    {
        static if (!hasLvalueElements!Range) {
            // Don't have lvalue access.
            ret ~= "\tElementType!(R[" ~ to!string(ti) ~ "]) front" ~
                to!string(ti) ~ ";\n";
        }
    }

    // Check for emptiness.
    ret ~= "\twhile(";                 //someEmpty) {\n";
    foreach(ti, Unused; Ranges) {
        ret ~= "!ranges[" ~ to!string(ti) ~ "].empty && ";
    }
    // Strip trailing &&
    ret = ret[0..$ - 4];
    ret ~= ") {\n";

    // Populate the dummy variables for everything that doesn't have lvalue
    // elements.
    foreach(ti, Range; Ranges)
    {
        static if (!hasLvalueElements!Range)
        {
            immutable tiString = to!string(ti);
            ret ~= "\t\tfront" ~ tiString ~ " = ranges["
                ~ tiString ~ "].front;\n";
        }
    }


    // Create code to call the delegate.
    ret ~= "\t\tres = dg(";
    if (withIndex)
    {
        ret ~= "index, ";
    }


    foreach(ti, Range; Ranges)
    {
        static if (hasLvalueElements!Range)
        {
            ret ~= "ranges[" ~ to!string(ti) ~ "].front, ";
        }
        else
        {
            ret ~= "front" ~ to!string(ti) ~ ", ";
        }
    }

    // Remove trailing ,
    ret = ret[0..$ - 2];
    ret ~= ");\n";
    ret ~= "\t\tif(res) break;\n";
    foreach(ti, Range; Ranges)
    {
        ret ~= "\t\tranges[" ~ to!(string)(ti) ~ "].popFront();\n";
    }

    if (withIndex)
    {
        ret ~= "\t\tindex++;\n";
    }

    ret ~= "\t}\n";
    ret ~= "\tif(_s == StoppingPolicy.requireSameLength) {\n";
    ret ~= "\t\tforeach(range; ranges)\n";
    ret ~= "\t\t\tenforce(range.empty);\n";
    ret ~= "\t}\n";
    ret ~= "\treturn res;\n}";

    return ret;
}

/**
   Iterate multiple ranges in lockstep using a $(D foreach) loop.  If only a single
   range is passed in, the $(D Lockstep) aliases itself away.  If the
   ranges are of different lengths and $(D s) == $(D StoppingPolicy.shortest)
   stop after the shortest range is empty.  If the ranges are of different
   lengths and $(D s) == $(D StoppingPolicy.requireSameLength), throw an
   exception.  $(D s) may not be $(D StoppingPolicy.longest), and passing this
   will throw an exception.

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
if(Ranges.length > 1 && allSatisfy!(isInputRange, staticMap!(Unqual, Ranges)))
{
private:
    alias staticMap!(Unqual, Ranges) R;
    R _ranges;
    StoppingPolicy _s;

public:
    this(R ranges, StoppingPolicy s = StoppingPolicy.shortest)
    {
        _ranges = ranges;
        enforce(s != StoppingPolicy.longest,
                "Can't use StoppingPolicy.Longest on Lockstep.");
        this._s = s;
    }

    mixin(lockstepApply!(Ranges)(false));
    mixin(lockstepApply!(Ranges)(true));
}

// For generic programming, make sure Lockstep!(Range) is well defined for a
// single range.
template Lockstep(Range)
{
    alias Range Lockstep;
}

version(StdDdoc)
{
    /// Ditto
    Lockstep!(Ranges) lockstep(Ranges...)(Ranges ranges) { assert(0); }
    /// Ditto
    Lockstep!(Ranges) lockstep(Ranges...)(Ranges ranges, StoppingPolicy s)
    {
        assert(0);
    }
}
else
{
    // Work around DMD bugs 4676, 4652.
    auto lockstep(Args...)(Args args)
        if (allSatisfy!(isInputRange, staticMap!(Unqual, Args)) || (
                    allSatisfy!(isInputRange, staticMap!(Unqual, Args[0..$ - 1])) &&
                    is(Args[$ - 1] == StoppingPolicy))
            )
        {
            static if (is(Args[$ - 1] == StoppingPolicy))
            {
                alias args[0..$ - 1] ranges;
                alias Args[0..$ - 1] Ranges;
                alias args[$ - 1] stoppingPolicy;
            }
            else
            {
                alias Args Ranges;
                alias args ranges;
                auto stoppingPolicy = StoppingPolicy.shortest;
            }

            static if (Ranges.length > 1)
            {
                return Lockstep!(Ranges)(ranges, stoppingPolicy);
            }
            else
            {
                return ranges[0];
            }
        }
}

unittest {
    // The filters are to make these the lowest common forward denominator ranges,
    // i.e. w/o ref return, random access, length, etc.
    auto foo = filter!"a"([1,2,3,4,5]);
    immutable bar = [6f,7f,8f,9f,10f].idup;
    auto l = lockstep(foo, bar);

    // Should work twice.  These are forward ranges with implicit save.
    foreach(i; 0..2) {
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
    arr2.popBack;
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
to $(D recurrence). The $(D Recurrence) class itself takes care of
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
    auto piapprox = recurrence!("a[n] + (n & 1 ? 4. : -4.) / (2 * n + 3)")(4.);
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

public:
    this(State initial, size_t n = 0)
    {
        this._state = initial;
        this._n = n;
        this._cache = compute(this._state, this._n);
    }

    @property ElementType front()
    {
        //return ElementType.init;
        return this._cache;
    }

    ElementType moveFront()
    {
        return move(this._cache);
    }

    void popFront()
    {
        this._cache = compute(this._state, ++this._n);
    }



    ElementType opIndex(size_t n)
    {
        //return ElementType.init;
        return compute(this._state, n + this._n);
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

/**
   Returns a range that goes through the numbers $(D begin), $(D begin +
   step), $(D begin + 2 * step), $(D ...), up to and excluding $(D
   end). The range offered is a random access range. The two-arguments
   version has $(D step = 1). If $(D begin < end && step <= 0) or $(D
   begin > end && step >= 0), then an empty range is returned. If $(D
   begin != end) and $(D step == 0), an exception is thrown.

   Throws:
   $(D Exception) if $(D step == 0)

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
            if ((current <= pastLast && step >= 0) ||
                    (current >= pastLast && step <= 0))
            {
                enforce(step != 0);
                this.step = step;
                this.current = current;
                if (step > 0)
                {
                    this.pastLast = pastLast - 1;
                }
                else
                {
                    this.pastLast = pastLast + 1;
                }
                this.pastLast -= (this.pastLast - current) % step;
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
        @property Value front() { return current; }
        alias front moveFront;
        void popFront() { current += step; }
        @property Value back() { return pastLast - step; }
        alias back moveBack;
        void popBack() { pastLast -= step; }
        @property auto save() { return this; }
        Value opIndex(ulong n)
        {
            // Just cast to Value here because doing so gives overflow behavior
            // consistent with calling popFront() n times.
            return cast(Value) (current + step * n);
        }
        auto opSlice() { return this; }
        auto opSlice(ulong lower, ulong upper)
        {
            assert(upper >= lower && upper <= this.length);

            auto ret = this;
            ret.current += lower * step;
            ret.pastLast -= (this.length - upper) * step;
            return ret;
        }
        @property IndexType length() const
        {
            return unsigned((pastLast - current) / step);
        }
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
        @property Value front() { return current; }
        alias front moveFront;
        void popFront() { ++current; }
        @property Value back() { return pastLast - 1; }
        alias back moveBack;
        void popBack() { --pastLast; }
        @property auto save() { return this; }
        Value opIndex(ulong n)
        {
            // Just cast to Value here because doing so gives overflow behavior
            // consistent with calling popFront() n times.
            return cast(Value) (current + n);
        }
        auto opSlice() { return this; }
        auto opSlice(ulong lower, ulong upper)
        {
            assert(upper >= lower && upper <= this.length);

            auto ret = this;
            ret.current += lower;
            ret.pastLast -= this.length - upper;
            return ret;
        }
        @property IndexType length() const
        {
            return unsigned(pastLast - current);
        }
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
        @property Value front() { return start + step * index; }
        alias front moveFront;
        void popFront()
        {
            assert(!empty);
            ++index;
        }
        @property Value back()
        {
            assert(!empty);
            return start + step * (count - 1);
        }
        alias back moveBack;
        void popBack()
        {
            assert(!empty);
            --count;
        }
        @property auto save() { return this; }
        Value opIndex(size_t n)
        {
            assert(n < count);
            return start + step * (n + index);
        }
        auto opSlice()
        {
            return this;
        }
        auto opSlice(size_t lower, size_t upper)
        {
            assert(upper >= lower && upper <= count);

            auto ret = this;
            ret.index += lower;
            ret.count = upper - lower + ret.index;
            return ret;
        }
        @property size_t length() const
        {
            return count - index;
        }
    }

    return Result(begin, end, step);
}

unittest
{
    static assert(hasLength!(typeof(iota(0, 2))));
    auto r = iota(0, 10, 1);
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
}

unittest
{
    auto idx = new size_t[100];
    copy(iota(0, idx.length), idx);
}

/**
   Options for the $(D FrontTransversal) and $(D Transversal) ranges
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
    alias Unqual!(Ror) RangeOfRanges;
    alias typeof(RangeOfRanges.init.front().front()) ElementType;

    private void prime()
    {
        static if (opt == TransverseOptions.assumeJagged)
        {
            while (!_input.empty && _input.front.empty)
            {
                _input.popFront;
            }
            static if (isBidirectionalRange!RangeOfRanges)
            {
                while (!_input.empty && _input.back.empty)
                {
                    _input.popBack;
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
        prime;
        static if (opt == TransverseOptions.enforceNotJagged)
            // (isRandomAccessRange!RangeOfRanges
            //     && hasLength!(.ElementType!RangeOfRanges))
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
    static if (hasMobileElements!(.ElementType!RangeOfRanges))
    {
        ElementType moveFront()
        {
            return .moveFront(_input.front);
        }
    }

    static if (hasAssignableElements!(.ElementType!RangeOfRanges))
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
        _input.popFront;
        prime;
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
            assert(!empty);
            return _input.back.front;
        }
        /// Ditto
        void popBack()
        {
            assert(!empty);
            _input.popBack;
            prime;
        }

        /// Ditto
        static if (hasMobileElements!(.ElementType!RangeOfRanges))
        {
            ElementType moveBack()
            {
                return .moveFront(_input.back);
            }
        }

        static if (hasAssignableElements!(.ElementType!RangeOfRanges))
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
        static if (hasMobileElements!(.ElementType!RangeOfRanges))
        {
            ElementType moveAt(size_t n)
            {
                return .moveFront(_input[n]);
            }
        }
        /// Ditto
        static if (hasAssignableElements!(.ElementType!RangeOfRanges))
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
                _input.popFront;
            }
            static if (isBidirectionalRange!RangeOfRanges)
            {
                while (!_input.empty && _input.back.length <= _n)
                {
                    _input.popBack;
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
        prime;
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
        _input.popFront;
        prime;
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
            _input.popBack;
            prime;
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
        assert(ror.moveFront == 5);
    }
    {
        ror.back = 999;
        scope(exit) ror.back = 4;
        assert(x[1][1] == 999);
        assert(ror.moveBack == 999);
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
            e.popFront;
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
Indexed!(Source, Indices) indexed(Source, Indices)
(Source source, Indices indices)
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
struct Chunks(Source) if(hasSlicing!Source && hasLength!Source) 
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
   Moves the front of $(D r) out and returns it. Leaves $(D r.front) in a
   destroyable state that does not allocate any resources (usually equal
   to its $(D .init) value).
*/
ElementType!R moveFront(R)(R r)
{
    static if (is(typeof(&r.moveFront))) {
        return r.moveFront();
    } else static if (!hasElaborateCopyConstructor!(ElementType!(R))) {
        return r.front;
    } else static if (is(typeof(&r.front()) == ElementType!R*)) {
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
        ref int front() { static int x = 42; return x; }
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
    } else static if (!hasElaborateCopyConstructor!(ElementType!(R))) {
        return r.back;
    } else static if (is(typeof(&r.back()) == ElementType!R*)) {
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
 * $(D isInputRange) and friends check for conformance to structural
 * interfaces, not for implementation of these $(D interface) types.
 *
 * Examples:
 * ---
 * class UsesRanges {
 *     void useRange(InputRange range) {
 *         // Function body.
 *     }
 * }
 *
 * // Create a range type.
 * auto squares = map!"a * a"(iota(10));
 *
 * // Wrap it in an interface.
 * auto squaresWrapped = inputRangeObject(squares);
 *
 * // Use it.
 * auto usesRanges = new UsesRanges;
 * usesRanges.useRange(squaresWrapped);
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
     *
     * BUGS:  If a $(D ref) variable is provided as the loop variable,
     *        changes made to the loop variable will not be propagated to the
     *        underlying range.  If the address of the loop variable is escaped,
     *        undefined behavior will result.  This is related to DMD bug 2443.
     */
    int opApply(int delegate(ref E));

    /// Ditto
    int opApply(int delegate(ref size_t, ref E));

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
    alias MostDerivedInputRangeImpl!(Unqual!R).ret MostDerivedInputRange;
}

private template MostDerivedInputRangeImpl(R) {
    private alias ElementType!R E;

    static if (isRandomAccessRange!R) {
        static if (isInfinite!R) {
            alias RandomAccessInfinite!E ret;
        } else static if (hasAssignableElements!R) {
            alias RandomFiniteAssignable!E ret;
        } else {
            alias RandomAccessFinite!E ret;
        }
    } else static if (isBidirectionalRange!R) {
        static if (hasAssignableElements!R) {
            alias BidirectionalAssignable!E ret;
        } else {
            alias BidirectionalRange!E ret;
        }
    } else static if (isForwardRange!R) {
        static if (hasAssignableElements!R) {
            alias ForwardAssignable!E ret;
        } else {
            alias ForwardRange!E ret;
        }
    } else {
        static if (hasAssignableElements!R) {
            alias InputAssignable!E ret;
        } else {
            alias InputRange!E ret;
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

                @property E moveBack() {
                    return .moveBack(_range);
                }

                @property void popBack() { return _range.popBack; }

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
            int opApply(int delegate(ref E) dg) {
                int res;

                for(auto r = _range; !r.empty; r.popFront()) {
                    // Work around Bug 2443.  This is slightly unsafe, but
                    // probably not in any way that matters in practice.
                    auto front = r.front;
                    res = dg(front);
                    if (res) break;
                }

                return res;
            }

            int opApply(int delegate(ref size_t, ref E) dg) {
                int res;

                size_t i = 0;
                for(auto r = _range; !r.empty; r.popFront()) {
                    // Work around Bug 2443.  This is slightly unsafe, but
                    // probably not in any way that matters in practice.
                    auto front = r.front;
                    res = dg(i, front);
                    if (res) break;
                    i++;
                }

                return res;
            }
        }
    }
}

/**Convenience function for creating a $(D InputRangeObject) of the proper type.*/
InputRangeObject!R inputRangeObject(R)(R range) if (isInputRange!R) {
    static if (is(R : InputRange!(ElementType!R))) {
        return range;
    } else {
        return new InputRangeObject!R(range);
    }
}

/**Convenience function for creating a $(D OutputRangeObject) with a base range
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
    assert(arr.moveFront == 0);
    assert(arr.moveBack == 4);
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
   Policy used with the searching primitives $(D lowerBound), $(D
   upperBound), and $(D equalRange) of $(LREF SortedRange) below.
 */
enum SearchPolicy
{
    /**
       Searches with a step that is grows linearly (1, 2, 3,...)
       leading to a quadratic search schedule (indexes tried are 0, 1,
       3, 5, 8, 12, 17, 23,...) Once the search overshoots its target,
       the remaining interval is searched using binary search. The
       search is completed in $(BIGOH sqrt(n)) time. Use it when you
       are reasonably confident that the value is around the beginning
       of the range.
    */
    trot,

    /**
       Performs a $(LUCKY galloping search algorithm), i.e. searches
       with a step that doubles every time, (1, 2, 4, 8, ...)  leading
       to an exponential search schedule (indexes tried are 0, 1, 2,
       4, 8, 16, 32,...) Once the search overshoots its target, the
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
   assert(r.canFind(3));
   assert(!r.canFind(32));
   auto r1 = sort!"a > b"(a);
   assert(r1.canFind(3));
   assert(!r1.canFind(32));
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
   assert(r.canFind(42));
   swap(a[3], a[5]);                      // illegal to break sortedness of original range
   assert(!r.canFind(42));                // passes although it shouldn't
   ----
*/
struct SortedRange(Range, alias pred = "a < b")
if (isRandomAccessRange!Range)
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
        typeof(this) result;
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
    auto opSlice(size_t a, size_t b)
    {
        assert(a <= b);
        typeof(this) result;
        result._input = _input[a .. b];// skip checking
        return result;
    }

    /// Ditto
    @property size_t length()          //const
    {
        return _input.length;
    }

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
   $(LREF SearchPolicy).  See also STL's $(WEB
   sgi.com/tech/stl/lower_bound.html, lower_bound).

   Example:
   ----
   auto a = assumeSorted([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ]);
   auto p = a.lowerBound(4);
   assert(equal(p, [ 0, 1, 2, 3 ]));
   ----
*/
    auto lowerBound(SearchPolicy sp = SearchPolicy.binarySearch, V)(V value)
    if (is(V : ElementType!Range))
    {
        ElementType!Range v = value;
        return this[0 .. getTransitionIndex!(sp, geq)(v)];
    }

// upperBound
/**
   This function uses binary search with policy $(D sp) to find the
   largest right subrange on which $(D pred(value, x)) is $(D true)
   for all $(D x) (e.g., if $(D pred) is "less than", returns the
   portion of the range with elements strictly greater than $(D
   value)). The search schedule and its complexity are documented in
   $(LREF SearchPolicy).  See also STL's $(WEB
   sgi.com/tech/stl/lower_bound.html,upper_bound).

   Example:
   ----
   auto a = assumeSorted([ 1, 2, 3, 3, 3, 4, 4, 5, 6 ]);
   auto p = a.upperBound(3);
   assert(equal(p, [4, 4, 5, 6]));
   ----
*/
    auto upperBound(SearchPolicy sp = SearchPolicy.binarySearch, V)(V value)
    if (is(V : ElementType!Range))
    {
        ElementType!Range v = value;
        return this[getTransitionIndex!(sp, gt)(v) .. length];
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
    auto equalRange(V)(V value) if (is(V : ElementType!Range))
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
    auto trisect(V)(V value) if (is(V : ElementType!Range))
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

/**
 * Deprecated alias for $(D contains).
 */
    alias contains canFind;
}

// Doc examples
unittest
{
    auto a = [ 1, 2, 3, 42, 52, 64 ];
    auto r = assumeSorted(a);
    assert(r.canFind(3));
    assert(!r.canFind(32));
    auto r1 = sort!"a > b"(a);
    assert(r1.canFind(3));
    assert(!r1.canFind(32));
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
    assert(r.canFind(42));
    swap(a[3], a[5]);                  // illegal to break sortedness of original range
    assert(!r.canFind(42));            // passes although it shouldn't
}

unittest
{
    immutable(int)[] arr = [ 1, 2, 3 ];
    auto s = assumeSorted(arr);
}

/**
Assumes $(D r) is sorted by predicate $(D pred) and returns the
corresponding $(D SortedRange!(pred, R)) having $(D r) as support. To
keep the checking costs low, the cost is $(BIGOH(1)) in release mode
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
}

unittest
{
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    auto p = assumeSorted(a).upperBound(3);
    assert(equal(p, [4, 4, 5, 6 ]));
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
}

unittest
{
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    if (a.length)
    {
        auto b = a[a.length / 2];
        //auto r = sort(a);
        //assert(r.canFind(b));
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
