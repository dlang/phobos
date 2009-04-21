// Written in the D programming language.
/**
This module defines a few useful _range incarnations. Credit for ideas
in building this module go to $(WEB
fantascienza.net/leonardo/so/dlibs/all.html, bearophile).

Author:

$(WEB erdani.org, Andrei Alexandrescu)

Macros:
WIKI = Phobos/StdRange
*/

module std.range;
public import std.array;
import std.contracts;
import std.traits;
import std.typecons;
import std.algorithm;
import std.functional;
version(unittest)
{
    import std.stdio;
}

/**
Returns $(D true) if $(D R) is an input range. An input range must
define the primitives $(D empty), $(D popFront), and $(D front). The
following code should compile for any input range.

----
R r;             // can define a range object
if (r.empty) {}  // can test for empty
r.popFront;          // can invoke next
auto h = r.front; // can get the front of the range
----

The semantics of an input range (not checkable during compilation) are
assumed to be the following ($(D r) is an object of type $(D R)):

$(UL $(LI $(D r.empty) returns $(D false) iff there is more data
available in the range.)  $(LI $(D r.front) returns the current element
in the range. It may return by value or by reference. Calling $(D
r.front) is allowed only if calling $(D r.empty) has, or would have,
returned $(D false).) $(LI $(D r.popFront) advances to the popFront element in
the range. Calling $(D r.popFront) is allowed only if calling $(D r.empty)
has, or would have, returned $(D false).))
 */
template isInputRange(R)
{
    enum bool isInputRange = is(typeof(
    {
        R r;             // can define a range object
        if (r.empty) {}  // can test for empty
        r.popFront;          // can invoke next
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
        bool empty();
        int front();
    }
    static assert(isInputRange!(B));
    static assert(isInputRange!(int[]));
    static assert(isInputRange!(char[]));
}

/**
Returns $(D true) if $(D R) is an output range. An output range must
define the primitive $(D put) that accepts an object of type $(D
E). The following code should compile for any output range.

----
R r;             // can define a range object
E e;
r.put(e);        // can write an element to the range
----
The semantics of an output range (not checkable during compilation)
are assumed to be the following ($(D r) is an object of type $(D R)):

$(UL $(LI $(D r.put(e)) puts $(D e) in the range (in a range-dependent
manner) and advances to the popFront position in the range. Successive
calls to $(D r.put) add elements to the range. $(D put) may throw to
signal failure.))
 */
template isOutputRange(R, E)
{
    enum bool isOutputRange = is(typeof(
    {
        R r;            // can define a range object
        E e;
        r.put(e);       // can write element to range
    }()));
}

unittest
{
    struct A {}
    static assert(!isInputRange!(A));
    struct B
    {
        void put(int);
    }
    static assert(isOutputRange!(B, int));
    static assert(isOutputRange!(int[], int));
}

/**
Returns $(D true) if $(D R) is a forward range. A forward range is an
input range that can save "checkpoints" by simply copying it to
another value of the same type. Notable examples of input ranges that
are $(I not) forward ranges are file/socket ranges; copying such a
range will not save the position in the stream, and they most likely
reuse an internal buffer as the entire stream does not sit in
memory. Subsequently, advancing either the original or the copy will
advance the stream, so the copies are not independent. The following
code should compile for any forward range.

----
static assert(isInputRange!(R));
R r1;
R r2 = r1;           // can copy a range to another
----

The semantics of a forward range (not checkable during compilation)
are the same as for an input range, with the additional requirement
that backtracking must be possible by saving a copy of the range
object.
 */
template isForwardRange(R)
{
    enum bool isForwardRange = isInputRange!(R) && is(typeof(
    {
        R r1;
        R r2 = r1;           // can copy a range object
    }()));
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
static assert(isForwardRange!(R)); // range is an input range
r.popBack;                        // can invoke retreat
auto t = r.back;                   // can get the back of the range
----
The semantics of a bidirectional range (not checkable during compilation)
are assumed to be the following ($(D r) is an object of type $(D R)):

$(UL $(LI $(D r.back) returns (possibly a reference to) the last
element in the range. Calling $(D r.back) is allowed only if calling
$(D r.empty) has, or would have, returned $(D false).))
 */
template isBidirectionalRange(R)
{
    enum bool isBidirectionalRange = isForwardRange!(R) && is(typeof(
    {
        R r;
        r.popBack;         // can invoke retreat
        auto h = r.back;    // can get the back of the range
    }()));
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
        void popFront();
        bool empty();
        int front();
        void popBack();
        int back();
    }
    static assert(isBidirectionalRange!(C));
    static assert(isBidirectionalRange!(int[]));
    static assert(isBidirectionalRange!(char[]));
}

/**
Returns $(D true) if $(D R) is a random-access range. A random-access
range is a forward range that also offers the primitive $(D
opIndex), OR an infinite input range that offers $(D opIndex). The
following code should compile for any random-access range.

----
R r;
static assert(isForwardRange!(R)); // range is forward
static assert(isBidirectionalRange!(R) || isInfinite!(R));
                                  // range is bidirectional or infinite
auto e = r[1];                    // can index
----

The semantics of a random-access range (not checkable during
compilation) are assumed to be the following ($(D r) is an object of
type $(D R)):
$(UL $(LI $(D r.opIndex(n)) returns a reference to the $(D n)th
element in the range.))
 */
template isRandomAccessRange(R)
{
    enum bool isRandomAccessRange =
        (isBidirectionalRange!(R) || isInfinite!(R))
        && is(typeof(
    {
        R r;
        auto e = r[1];     // can index
    }()));
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
        void popFront();
        bool empty();
        int front();
        void popBack();
        int back();
        ref int opIndex(uint);
        //int opSlice(uint, uint);
    }
    static assert(isRandomAccessRange!(D));
    static assert(isRandomAccessRange!(int[]));
}

/**
The element type of $(D R). $(D R) does not have to be a range. The
element type is determined as the type yielded by $(D r.front) for an
object $(D r) or type $(D R). For example, $(D ElementType!(T[])) is
$(D T).
 */
template ElementType(R)
{
    //alias typeof({ R r; return front(r[]); }()) ElementType;
    static if (is(typeof(R.front()) T))
        alias T ElementType;
    else
        alias void ElementType;
}

unittest
{
    enum XYZ : string { a = "foo" };
    auto x = front(XYZ.a);
    static assert(is(ElementType!(XYZ) : char));
    immutable char[3] a = "abc";
    static assert(is(ElementType!(typeof(a)) : char));
    int[] i;
    static assert(is(ElementType!(typeof(i)) : int));
}

/**
Returns $(D true) if $(D R) is a forward range and has swappable
elements. The following code should compile for any random-access
range.

----
R r;
static assert(isForwardRange!(R));  // range is forward
swap(r.front, r.front);              // can swap elements of the range
----
 */
template hasSwappableElements(R)
{
    enum bool hasSwappableElements = isForwardRange!(R) && is(typeof(
    {
        R r;
        static assert(isForwardRange!(R)); // range is forward
        swap(r.front, r.front);             // can swap elements of the range
    }()));
}

unittest
{
    static assert(!hasSwappableElements!(const int[]));
    static assert(!hasSwappableElements!(const(int)[]));
    static assert(hasSwappableElements!(int[]));
    static assert(hasSwappableElements!(char[]));
}

/**
Returns $(D true) if $(D R) is a forward range and has mutable
elements. The following code should compile for any random-access
range.

----
R r;
static assert(isForwardRange!(R));  // range is forward
auto e = r.front;
r.front = e;                         // can assign elements of the range
----
 */
template hasAssignableElements(R)
{
    enum bool hasAssignableElements = isForwardRange!(R) && is(typeof(
    {
        R r;
        static assert(isForwardRange!(R)); // range is forward
        auto e = r.front;
        r.front = e;                       // can assign elements of the range
    }()));
}

unittest
{
    static assert(!hasAssignableElements!(const int[]));
    static assert(!hasAssignableElements!(const(int)[]));
    static assert(hasAssignableElements!(int[]));
}

/**
Returns $(D true) if $(D R) has a $(D length) member that returns an
integral type. $(D R) does not have to be a range. Note that $(D
length) is an optional primitive as no range must implement it. Some
ranges do not store their length explicitly, some cannot compute it
without actually exhausting the range (e.g. socket streams), and some
other ranges may be infinite.
 */
template hasLength(R)
{
    enum bool hasLength = is(typeof(R.init.length) : ulong);
}

unittest
{
    static assert(hasLength!(int[]));
    struct A { ulong length; }
    static assert(hasLength!(A));
}

/**
Returns $(D true) if $(D Range) is an infinite input range. An
infinite input range is an input range that has a statically-defined
$(empty) member that is always $(D false), for example:

----
struct InfiniteRange
{
    enum bool empty = false;
    ...
}
----
 */

template isInfinite(Range)
{
    static if (isInputRange!(Range) && is(char[1 + Range.empty]))
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
    enum bool hasSlicing = is(typeof(
    {
        Range r;
        auto s = r[1 .. 2];
        static assert(isInputRange!(typeof(s)));
    }()));
}

unittest
{
    static assert(hasSlicing!(int[]));
    struct A { int opSlice(uint, uint); }
    static assert(!hasSlicing!(A));
    struct B { int[] opSlice(uint, uint); }
    static assert(hasSlicing!(B));
}

/**
This is a best-effort implementation of $(D length) for any kind of
range.
 
If $(D hasLength!(Range)), simply returns $(D range.length) without
checking $(D upTo).

Otherwise, walks the range through its length and returns the number
of elements seen. Performes $(BIGOH n) evaluations of $(D range.empty)
and $(D range.popFront), where $(D n) is the effective length of $(D
range). The $(D upTo) parameter is useful to "cut the losses" in case
the interest is in seeing whether the range has at least some number
of elements. If the parameter $(D upTo) is specified, stops if $(D
upTo) steps have been taken and returns $(D upTo).
 */
size_t walkLength(Range)(Range range, size_t upTo = size_t.max)
if (isInputRange!(Range))
{
    static if (hasLength!(Range))
    {
        return range.length;
    }
    else
    {
        size_t result;
        for (; result < upTo && !range.empty; range.popFront) ++result;
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
Iterates a bidirectional range backwards.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
assert(equal(retro(a) == [ 5, 4, 3, 2, 1 ][]));
----
 */
struct Retro(R) if (isBidirectionalRange!(R))
{
private:
    R _input;
    
public:
/**
Returns $(D this).
 */
    ref Retro opSlice()
    {
        return this;
    }

/**
Forwards to $(D _input.empty).
 */
    bool empty()
    {
        return _input.empty;
    }

/**
Forwards to $(D _input.popBack).
 */
    void popFront()
    {
        _input.popBack;
    }

/**
Forwards to $(D _input.popFront).
 */
    void popBack()
    {
        _input.popFront;
    }

/**
Forwards to $(D _input.back).
 */
    ref ElementType!(R) front()
    {
        return _input.back;
    }

/**
Forwards to $(D _input.front).
 */
    ref ElementType!(R) back()
    {
        return _input.front;
    }

/**
Forwards to $(D _input[_input.length - n + 1]). Defined only if $(D R)
is a random access range and if $(D R) defines $(D R.length).
 */
    static if (isRandomAccessRange!(R) && hasLength!(R))
        ref ElementType!(R) opIndex(uint n)
        {
            return _input[_input.length - n + 1];
        }

/**
Range primitive operation that returns the length of the
range. Forwards to $(D _input.length) and is defined only if $(D
hasLength!(R)).
 */
    static if (hasLength!(R))
        size_t length()
        {
            return _input.length;
        }
}

/// Ditto
Retro!(R) retro(R)(R input)
    if (isBidirectionalRange!(R))
{ return Retro!(R)(input); }

unittest
{
    static assert(isRandomAccessRange!(Retro!(int[])));
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
}

/**
Iterates range $(D r) with stride $(D n). If the range is a
random-access range, moves by indexing into the range; otehrwise,
moves by successive calls to $(D popFront).

Example:
----
int[] a = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 ];
assert(equal(stride(a, 3) == [ 1, 4, 7, 10 ][]));
----
 */
struct Stride(R) if (isInputRange!(R))
{
private:
    R _input;
    size_t _n;
    
public:
/**
Initializes the stride.
 */
    this(R input, size_t n)
    {
        _input = input;
        _n = n;
        static if (hasLength!(R))
        {
            auto slack = _input.length % _n;
            if (slack) slack--;
            if (!slack) return;
            static if (isRandomAccessRange!(R) && hasSlicing!(R))
            {
                _input = _input[0 .. _input.length - slack];
            }
            else
            {
                foreach (i; 0 .. slack)
                {
                    if (_input.empty) break;
                    _input.popBack;
                }
            }
        }
    }
    
/**
Returns $(D this).
 */
    Stride opSlice()
    {
        return this;
    }

/**
Forwards to $(D _input.empty).
 */
    bool empty()
    {
        return _input.empty;
    }

/**
@@@
 */
    void popFront()
    {
        static if (isRandomAccessRange!(R) && hasLength!(R) && hasSlicing!(R))
        {
            _input = _input[
                _n < _input.length ? _n : _input.length
                .. _input.length];
        }
        else
            foreach (i; 0 .. _n)
            {
                _input.popFront;
                if (_input.empty) break;
            }
    }

/**
Forwards to $(D _input.popFront).
 */
    static if (hasLength!(R))
        void popBack() 
        {
            enforce(_input.length >= _n);
            static if (isRandomAccessRange!(R) && hasSlicing!(R))
            {
                _input = _input[0 .. _input.length - _n];
            }
            else
            {
                foreach (i; 0 .. _n)
                {
                    if (_input.empty) break;
                    _input.popBack;
                }
            }
        }

/**
Forwards to $(D _input.front).
 */
    ref ElementType!(R) front()
    {
        return _input.front;
    }

/**
Forwards to $(D _input.back) after getting rid of any slack items.
 */
    ref ElementType!(R) back()
    {
        return _input.back;
    }

/**
Forwards to $(D _input[_input.length - n + 1]). Defined only if $(D R)
is a random access range and if $(D R) defines $(D R.length).
 */
    static if (isRandomAccessRange!(R) && hasLength!(R))
        ref ElementType!(R) opIndex(uint n)
        {
            return _input[_n * n];
        }

/**
Range primitive operation that returns the length of the
range. Forwards to $(D _input.length) and is defined only if $(D
hasLength!(R)).
 */
    static if (hasLength!(R))
        size_t length()
        {
            return _input.length / _n;
        }
}

/// Ditto
Stride!(R) stride(R)(R input, size_t n)
    if (isInputRange!(R))
{
    enforce(n > 0);
    return Stride!(R)(input, n);
}

unittest
{
    static assert(isRandomAccessRange!(Stride!(int[])));
    void test(size_t n, int[] input, int[] witness)
    {
        //foreach (e; stride(input, n)) writeln(e);
        assert(equal(stride(input, n), witness));
    }
    test(1, [], []);
    int[] arr = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    test(1, arr, arr);
    test(2, arr, [1, 3, 5, 7, 9]);
    test(3, arr, [1, 4, 7, 10]);
    test(4, arr, [1, 5, 9]);
}

/**
Spans multiple ranges in sequence. The function $(D chain) takes any
number of ranges and returns a $(D Chain!(R1, R2,...)) object. The
ranges may be different, but they must have the same element type. The
result is a range that offers the $(D front), $(D popFront), and $(D empty)
primitives. If all input ranges offer random access and $(D length),
$(D Chain) offers them as well.

If only one range is offered to $(D Chain) or $(D chain), the $(D Chain)
type exits the picture by aliasing itself directly to that range's
type.

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

template Chain(R...) if (allSatisfy!(isInputRange, R))
{
    static if (R.length > 1)
        alias ChainImpl!(R) Chain;
    else
        alias R[0] Chain;
}

struct ChainImpl(R...)
{
private:
    alias CommonType!(staticMap!(.ElementType, R)) ElementType;
    template sameET(A) { enum sameET = is(.ElementType!(A) == ElementType); }
    enum bool allSameType = allSatisfy!(sameET, R);
    
    Tuple!(R) _input;
    
public:
    this(R input)
    {
        foreach (i, v; input)
        {
            _input.field[i] = v;
        }
    }
    
    bool empty()
    {
        foreach (i, Unused; R)
        {
            if (!_input.field[i].empty) return false;
        }
        return true;
    }
    
    void popFront()
    {
        foreach (i, Unused; R)
        {
            if (_input.field[i].empty) continue;
            _input.field[i].popFront;
            return;
        }
    }
    
    //@@@BUG 2597@@@ 
    //auto front()
    //@@@AWKWARD!!!@@@
    mixin(
        (allSameType ? "ref " : "")~
        q{ElementType front()
            {
                foreach (i, Unused; R)
                {
                    if (_input.field[i].empty) continue;
                    return _input.field[i].front;
                }
                assert(false);
            }
        });

    static if (allSatisfy!(isBidirectionalRange, R))
    {
        mixin(
            (allSameType ? "ref " : "")~
            q{ElementType back()
                {
                    foreach_reverse (i, Unused; R)
                    {
                        if (_input.field[i].empty) continue;
                        return _input.field[i].back;
                    }
                    assert(false);
                }
            });

        void popBack()
        {
            foreach_reverse (i, Unused; R)
            {
                if (_input.field[i].empty) continue;
                _input.field[i].popBack;
                return;
            }
        }    
    }
    
    static if (allSatisfy!(hasLength, R))
        size_t length()
        {
            size_t result;
            foreach (i, Unused; R)
            {
                result += _input.field[i].length;
            }
            return result;
        }

    static if (allSatisfy!(isRandomAccessRange, R))
        mixin(
            (allSameType ? "ref " : "")~
            q{ElementType opIndex(uint index)
                {
                    foreach (i, Unused; R)
                    {
                        immutable length = _input.field[i].length;
                        if (index < length) return _input.field[i][index];
                        index -= length;
                    }
                    assert(false);
                }
            });
/**
Returns $(D this).
 */
    ChainImpl opSlice()
    {
        return this;
    }


    static if (allSatisfy!(hasLength, R) && allSatisfy!(hasSlicing, R))
        ChainImpl opSlice(size_t begin, size_t end)
        {
            auto result = this;
            foreach (i, Unused; R)
            {
                immutable len = result._input.field[i].length;
                if (len < begin)
                {
                    result._input.field[i] = result._input.field[i]
                        [len .. len];
                    begin -= len;
                }
                else
                {
                    result._input.field[i] = result._input.field[i]
                        [begin .. len];
                    break;
                }
            }
            auto cut = length;
            cut = cut <= end ? 0 : cut - end;
            foreach_reverse (i, Unused; R)
            {
                immutable len = result._input.field[i].length;
                if (cut > len)
                {
                    result._input.field[i] = result._input.field[i]
                        [0 .. 0];
                    cut -= len;
                }
                else
                {
                    result._input.field[i] = result._input.field[i]
                        [0 .. len - cut];
                    break;
                }
            }
            return result;
        }
}

/// Ditto
Chain!(R) chain(R...)(R input)
{
    static if (input.length > 1)
        return Chain!(R)(input);
    else
        return input[0];
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
        s2.front() = 1;
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
}

/**
Iterates a random-access range starting from a given point and
progressively extending left and right from that point. If no initial
point is given, iteration starts from the middle of the
range. Iteration spans the entire range.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
assert(equal(radial(a) == [ 3, 2, 4, 1, 5 ][]));
a = [ 1, 2, 3, 4 ];
assert(equal(radial(a) == [ 2, 3, 1, 4 ][]));
----
 */
struct Radial(R) if (isRandomAccessRange!(R) && hasLength!(R))
{
private:
    R _low, _up;
    bool _upIsActive;
    
public:
/**
Takes a range and starts iterating from its median point. Ranges with
an even length start iterating from the element to the left of the
median. The second iterated element, if any, is the one to the right
of the first iterated element. A convenient way to use this
constructor is by calling the helper function $(D radial(input)).
 */
    this(R input)
    {
        auto mid = (input.length + 1) / 2;
        _low = input[0 .. mid];
        _up = input[mid .. $];
    }

/**
Takes a range and starts iterating from $(D input[mid]). The second
iterated element, if any, is the one to the right of the first
iterated element. If there is no element to the right of $(D
input[mid]), iteration continues downwards with $(D input[mid - 1])
etc. A convenient way to use this constructor is by calling the helper
function $(D radial(input, startingPoint)).
 */
    this(R input, size_t startingPoint)
    {
        _low = input[0 .. startingPoint + 1];
        _up = input[startingPoint + 1 .. $];
        if (_low.empty) _upIsActive = true;
    }

/**
Returns $(D this).
 */
    ref Radial opSlice()
    {
        return this;
    }

/**
Range primitive operation that returns $(D true) iff there are no more
elements to be iterated.
 */
    bool empty()
    {
        return _low.empty && _up.empty;
    }

/**
Range primitive operation that advances the range to its next
element.
 */
    void popFront()
    {
        assert(!empty);
        // We started with low active
        if (!_upIsActive)
        {
            // Consumed the low part, now look in the upper part
            if (_up.empty)
            {
                // no more stuff up, attempt to continue in the low area
                _low.popBack;
            }
            else
            {
                // more stuff available in the upper area
                _upIsActive = true;
            }
        }
        else
        {
            // we consumed both the lower and the upper area, must
            // make real progress up there
            if (!_up.empty) _up.popFront;
            if (!_low.empty) _low.popBack;
            if (!_low.empty) _upIsActive = false;
        }
    }

/**
Range primitive operation that returns the currently iterated
element. Throws if the range is empty.
 */
    ref ElementType!(R) front()
    {
        enforce(!empty, "Calling front() against an empty "
                ~typeof(this).stringof);
        if (!_upIsActive)
        {
            // @@@ Damndest thing... removing the enforce below causes
            // a segfault in release unittest
            enforce(!_low.empty);
            return _low.back;
        }
        enforce(!_up.empty);
        return _up.front;
    }
}

/// Ditto
Radial!(R) radial(R)(R r)
    if (isRandomAccessRange!(R) && hasLength!(R))
{
    return Radial!(R)(r);
}

/// Ditto
Radial!(R) radial(R)(R r, size_t startingIndex)
    if (isRandomAccessRange!(R) && hasLength!(R))
{
    return Radial!(R)(r, startingIndex);
}

unittest
{
    void test(int[] input, int[] witness)
    {
        enforce(equal(radial(input), witness));
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
}

/**
Lazily takes only up to $(D n) elements of a range. This is
particulary useful when using with infinite ranges. If the range
offers random access and $(D length), $(D Take) offers them as well.

Example:
----
int[] arr1 = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
auto s = take(5, arr1);
assert(s.length == 5);
assert(s[4] == 5);
assert(equal(s, [ 1, 2, 3, 4, 5 ][]));
----
 */

struct Take(R) if (isInputRange!(R))
{
private:
    size_t _maxAvailable;
    R _input;
    
public:
    bool empty()
    {
        return _maxAvailable == 0 || _input.empty;
    }
    
    void popFront()
    {
        enforce(_maxAvailable > 0);
        _input.popFront;
        --_maxAvailable;
    }
    
    //@@@BUG 2597@@@ 
    //auto front()
    static if (is(typeof(&(R.init.front()))))
    {
        ref ElementType!(R) front()
        {
            enforce(_maxAvailable > 0);
            return _input.front;
        }
    }
    else
    {
        ElementType!(R) front()
        {
            enforce(_maxAvailable > 0);
            return _input.front;
        }
    }

    static if (isInfinite!(R))
    {
        size_t length()
        {
            return _maxAvailable;
        }
    }
    else static if (hasLength!(R))
    {
        size_t length()
        {
            return min(_maxAvailable, _input.length);
        }
    }

    static if (isRandomAccessRange!(R))
        ref ElementType!(R) opIndex(uint index)
        {
            enforce(_maxAvailable > index);
            return _input[index];
        }

    static if (isBidirectionalRange!(R))
        /*ref*/ ElementType!(R) back()
        {
            return _input.back;
        }
    else static if (isRandomAccessRange!(R))
        /*ref*/ ElementType!(R) back()
        {
            return _input[length];
        }
}

/// Ditto
Take!(R) take(R)(size_t n, R input) if (isInputRange!(R))
{
    return Take!(R)(n, input);
}

version(none) unittest
{
    int[] arr1 = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
    auto s = take(5, arr1);
    assert(s.length == 5);
    assert(s[4] == 5);
    assert(equal(s, [ 1, 2, 3, 4, 5 ][]));
}

/+
/**
Eagerly advances a copy of $(D r) $(D n) times (by calling $(D r.popFront)
$(D n) times) and returns it. The pass of $(D r) into $(D drop) is by
value, so the original range remains unchanged. Completes in $(BIGOH
1) steps for ranges that support slicing, and in $(BIGOH n) time for
all other ranges.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
int[] b = drop(2, a);
assert(a == [ 1, 2, 3, 4, 5 ]);
assert(b == [ 3, 4, 5 ]);
----
 */
Range drop(Range)(size_t n, Range r) if (isInputRange!(Range))
{
    static if (hasSlicing!(Range))
    {
        return r[n .. r.length];
    }
    else
    {
        while (--n) r.popFront;
        return r;
    }
}

version(none) unittest
{
    assert(equal(drop(2, [1, 2, 3, 4][]), [ 3, 4 ][]));
}
+/

/**
Eagerly advances $(D r) itself (not a copy) $(D n) times (by calling
$(D r.popFront) $(D n) times). The pass of $(D r) into $(D drop) is by
reference, so the original range is affected. Completes in $(BIGOH 1)
steps for ranges that support slicing, and in $(BIGOH n) time for all
other ranges.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
a.advance(2);
assert(a == [ 3, 4, 5 ]);
----
 */
size_t advance(Range)(ref Range r, size_t n) if (isInputRange!(Range))
{
    static if (hasSlicing!(Range) && hasLength!(Range))
    {
        n = min(n, r.length);
        r = r[n .. r.length];
    }
    else
    {
        foreach (i; 0 .. n)
        {
            if (r.empty) return i;
            r.popFront;
        }
    }
    return n;
}

version(none) unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    a.advance(2);
    assert(a == [ 3, 4, 5 ]);
}

/**
Eagerly retreats $(D r) itself (not a copy) $(D n) times (by calling
$(D r.popBack) $(D n) times). The pass of $(D r) into $(D
advanceRight) is by reference, so the original range is
affected. Completes in $(BIGOH 1) steps for ranges that support
slicing, and in $(BIGOH n) time for all other ranges.

Example:
----
int[] a = [ 1, 2, 3, 4, 5 ];
a.advanceRight(2);
assert(a == [ 1, 2, 3 ]);
----
 */
size_t retreatN(Range)(ref Range r, size_t n) if (isInputRange!(Range))
{
    static if (hasSlicing!(Range) && hasLength!(Range))
    {
        auto newLen = n < r.length ? r.length - n : 0;
        n = r.length - newLen;
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

version(none) unittest
{
    int[] a = [ 1, 2, 3, 4, 5 ];
    a.retreatN(2);
    assert(a == [ 1, 2, 3 ]);
}

/**
Repeats one value forever. Example:
----
enforce(equal(take(4, repeat(5)), [ 5, 5, 5, 5 ][]));
----
 */

struct Repeat(T)
{
    private T _value;
    /// Range primitive implementations.
    ref T front() { return _value; }
    /// Ditto
    ref T back() { return _value; }
    /// Ditto
    enum bool empty = false;
    /// Ditto
    void popFront() {}
    /// Ditto
    ref T opIndex(uint) { return _value; }
}

/// Ditto
Repeat!(T) repeat(T)(T value) { return Repeat!(T)(value); }

version(none) unittest
{
    enforce(equal(take(4, repeat(5)), [ 5, 5, 5, 5 ][]));
}

/**
Replicates $(D value) exactly $(D n) times. Equivalent to $(D take(n,
repeat(value))).
 */
Take!(Repeat!(T)) replicate(T)(size_t n, T value)
{
    return take(n, repeat(value));
}

version(none) unittest
{
    enforce(equal(replicate(4, 5), [ 5, 5, 5, 5 ][]));
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
assert(equal(take(5, cycle([1, 2][])), [ 1, 2, 1, 2, 1 ][]));
----

Tip: This is a great way to implement simple circular buffers.
 */
struct Cycle(R) if (isForwardRange!(R))
{
    static if (isInfinite!(R))
    {
        alias R Cycle;
    }
    else static if (isRandomAccessRange!(R) && hasLength!(R))
    {
        R _original;
        size_t _index;
        this(R input, size_t index = 0) { _original = input; _index = index; }
        /// Range primitive implementations.
        ref ElementType!(R) front()
        {
            return _original[_index % _original.length];
        }
        /// Ditto
        enum bool empty = false;
        /// Ditto
        void popFront() { ++_index; }
        ref ElementType!(R) opIndex(size_t n)
        {
            return _original[(n + _index) % _original.length];
        }
    }
    else
    {
        R _original, _current;
        this(R input) { _original = input; _current = input; }
        /// Range primitive implementations.
        ref ElementType!(R) front() { return _current.front; }
        /// Ditto
        static if (isBidirectionalRange!(R))
            ref ElementType!(R) back() { return _current.back; }
        /// Ditto
        enum bool empty = false;
        /// Ditto
        void popFront() { _current.popFront; if (_current.empty) _current = _original; }
    }
}

/// Ditto
struct Cycle(R) if (isStaticArray!(R))
{
    private alias typeof(R[0]) ElementType;
    private ElementType* _ptr;
    private size_t _index;
    this(/*ref*/ R input, size_t index = 0)
    {
        _ptr = input.ptr;
        _index = index;
    }
    /// Range primitive implementations.
    ref ElementType front()
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
}

/// Ditto
Cycle!(R) cycle(R)(R input)
    if (isForwardRange!(R) || isStaticArray!(R))
{
    return Cycle!(R)(input);
}

/// Ditto
Cycle!(R) cycle(R)(R input, size_t index)
    if (isRandomAccessRange!(R) || isStaticArray!(R))
{
    return Cycle!(R)(input, index);
}

version(none) unittest
{
    assert(equal(take(5, cycle([1, 2][])), [ 1, 2, 1, 2, 1 ][]));
    int[3] a = [ 1, 2, 3 ];
    auto c = cycle(a);
    assert(a.ptr == c._ptr);
    assert(equal(take(5, cycle(a)), [ 1, 2, 3, 1, 2 ][]));
}

/**
Policy that controls whether or not a range (e.g. $(XREF range,
SListRange)) iterating a container can modify its topology. By
topology of a container we understand the layout of the container's
slots and the links between them, regardless of the actual content of
the container's elements. For example, a singly-linked list with three
elements has the topology of three cells linked by pointers. The
topology is not concerned with the content of the nodes, only with the
shape of the three connected cells.
 */
enum Topology
{
/** The range cannot change the container's topology (whereas it can
    change its content). This is useful if e.g. the container must
    control creation and destruction of its slots.
 */
    fixed,
/** The range can change the underlying container's structure. This is
    useful if the range is free-floating and is not owned by any
    container.
 */
    flexible
}

/**
Defines a simple and efficient singly-linked list. The list implements
the forward range concept. By default the list has flexible topology,
e.g. appending to it is possible.

Example:
----
SListRange!(int, Topology.flexible) lst(2, 3);
lst = cons(1, lst);
assert(equal(lst, [1, 2, 3][]));
----
 */
struct SListRange(T, Topology topology = Topology.flexible)
{
private:
    struct Node { T _value; Node * _popFront; }
    Node * _root;
    
public:
/**
Constructor taking an array of values. 

Example:
----
auto lst = SListRange!(int)(1, 2, 3, 4, 5);
assert(equal(lst, [1, 2, 3, 4, 5][]));
----
*/
    this(T[] values...)
    {
        _root = (new Node[values.length]).ptr;
        foreach (i, e; values)
        {
            _root[i]._value = e;
            if (i > 0)
                _root[i - 1]._popFront = &_root[i];
        }
    }
    
/**
Returns $(D this).
 */
    ref SListRange opSlice()
    {
        return this;
    }

/**
Range primitive operation that returns $(D true) iff there are no more
elements to be iterated.
 */
    bool empty() const
    {
        return _root is null;
    }

/**
Range primitive operation that advances the range to its _next
element. Forwards to $(D _input.popBack).
 */
    void popFront()
    {
        enforce(_root);
        _root = _root._popFront;
    }

/**
Range primitive operation that returns the currently iterated
element. Forwards to $(D _input.back).
 */
    ref T front()
    {
        enforce(_root);
        return _root._value;
    }

/**
   Returns $(D true) iff $(D this) list and $(D rhs) have the same front.
*/
    bool sameHead(in SListRange!(T, topology) rhs) const
    {
        return _root == rhs._root;
    }
}

/**
 Prepends $(D value) to the root of the list.
 */
SListRange!(T, t) cons(T, Topology t)(T front, SListRange!(T, t) tail)
{
    typeof(return) result;
    result._root = new typeof(return).Node;
    result._root._value = front;
    result._root._popFront = tail._root;
    return result;
}

unittest
{
    {
        SListRange!(int, Topology.flexible) lst;
        lst = cons(3, lst);
        lst = cons(2, lst);
        lst = cons(1, lst);
        assert(equal(lst, [1, 2, 3][]));
    }
    {
        auto lst = SListRange!(int)(1, 2, 3);
        assert(equal(lst, [1, 2, 3][]));
        uint i;
        foreach (e; lst)
        {
            assert(e == ++i);
        }
    }
    {
        auto lst = SListRange!(int)(1, 2, 3);
        assert(equal(lst, [1, 2, 3][]));
    }
}

/**
Iterate several ranges in lockstep. The element type is a proxy tuple
that allows accessing the current element in the $(D n)th range by
using $(D e.at!(n)).

Example:
----
int[] a = [ 1, 2, 3 ];
string[] b = [ "a", "b", "c" ];
// prints 1:a 2:b 3:c 
foreach (e; zip(a, b))
{
    write(e.at!(0), ':', e.at!(1), ' ');
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
sort!("a.at!(0) > b.at!(0)")(zip(a, b));
assert(a == [ 3, 2, 1 ]);
assert(b == [ "c", "b", "a" ]);
----
 */
struct Zip(R...) if (R.length && allSatisfy!(isInputRange, R))
{
    Tuple!(R) ranges;
    StoppingPolicy stoppingPolicy = StoppingPolicy.shortest;

/**
Builds an object. Usually this is invoked indirectly by using the
$(XREF range,zip) function.
 */
    this(R rs, StoppingPolicy s = StoppingPolicy.shortest)
    {
        stoppingPolicy = s;
        foreach (i, Unused; R)
        {
            ranges.field[i] = rs[i];
        }
    }

/**
Returns $(D true) if the range is at end. The test depends on the
stopping policy.
 */
    bool empty()
    {
        bool firstRangeIsEmpty = ranges.field[0].empty;
        if (firstRangeIsEmpty && stoppingPolicy == StoppingPolicy.shortest)
            return true;
        foreach (i, Unused; R[1 .. $])
        {
            switch (stoppingPolicy)
            {
            case StoppingPolicy.shortest: 
                if (ranges.field[i + 1].empty) return true;
                break;
            case StoppingPolicy.longest:
                if (!ranges.field[i + 1].empty) return false;
                break;
            default:
                assert(stoppingPolicy == StoppingPolicy.requireSameLength);
                enforce(firstRangeIsEmpty == ranges.field[i + 1].empty,
                        "Inequal-length ranges passed to Zip");
                break;
            }
        }
        return firstRangeIsEmpty;
    }

/**
Returns a proxy for the current iterated element.
 */
    Proxy front()
    {
        Proxy result;
        foreach (i, Unused; R)
        {
            result.ptrs.field[i] = &ranges.field[i].front;
        }
        return result;
    }

/**
Returns a proxy for the rightmost element.
 */
    Proxy back()
    {
        Proxy result;
        foreach (i, Unused; R)
        {
            result.ptrs.field[i] = &ranges.field[i].back;
        }
        return result;
    }

/**
Advances to the popFront element in all controlled ranges.
 */
    void popFront()
    {
        foreach (i, Unused; R)
        {
            ranges.field[i].popFront;
        }
    }

/**
Calls $(D popBack) for all controlled ranges.
 */
    void popBack()
    {
        foreach (i, Unused; R)
        {
            ranges.field[i].popBack;
        }
    }

/**
Returns the length of this range. Defined only if all ranges define
$(D length).
 */
    static if (allSatisfy!(hasLength, R))
        size_t length()
        {
            auto result = ranges.field[0].length;
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
        Zip!(R) opSlice(size_t from, size_t to)
        {
            Zip!(R) result;
            foreach (i, Unused; R)
            {
                result.ranges.field[i] = ranges.field[i][from .. to];
            }
            return result;
        }

/**
Proxy type returned by the access function.
*/
    struct Proxy
    {
        template ElemPtr(Range)
        {
            alias std.range.ElementType!(Range)* ElemPtr;
        }
        Tuple!(staticMap!(ElemPtr, R)) ptrs;

/**
Returns the current element in the $(D i)th range.
 */
        /*ref*/ std.range.ElementType!(R[i]) at(int i)()
        {
            return *ptrs.field[i];
        }

/**
Returns whether the current element exists in the $(D i)th range. This
function returns $(D false) if e.g. one of the ranges has exhausted in
the $(D StoppingPolicy.longest) policy.
 */
        bool hasAt(int i)()
        {
            return *ptrs.field[i];
        }

        void proxySwap(Proxy rhs)
        {
            foreach (i, Unused; R)
            {
                .swap(*ptrs.field[i], *rhs.ptrs.field[i]);
            }
        }
    }

/**
Returns the $(D n)th element in the composite range. Defined if all
ranges offer random access.
 */
    static if (allSatisfy!(isRandomAccessRange, R))
        Proxy opIndex(size_t n)
        {
            Proxy result;
            foreach (i, Unused; R)
            {
                result.ptrs.field[i] = &ranges.field[i][n];
            }
            return result;
        }
}

/// Ditto
Zip!(R) zip(R...)(R ranges)
    //if (allSatisfy!(isInputRange, R))
{
    return Zip!(R)(ranges);
}

/// Ditto
Zip!(R) zip(R...)(StoppingPolicy sp, R ranges)
    //if (allSatisfy!(isInputRange, R))
{
    return Zip!(R)(ranges, sp);
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

version(none) unittest
{
    int[] a = [ 1, 2, 3 ];
    float[] b = [ 1., 2, 3 ];
    foreach (e; zip(a, b))
    {
        assert(e.at!(0) == e.at!(1));
    }
    auto z = zip(a, b);
    swap(z.front(), z.back());
    //@@@BUG@@@
    //sort!("a.at!(0) < b.at!(0)")(zip(a, b));
}

/**
Creates a mathematical sequence given the initial values and a
recurrence function that computes the popFront value from the existing
values. The sequence comes in the form of an infinite forward
range. The type $(D Recurrence) itself is seldom used directly; most
often, recurrences are obtained by calling the function $(D
recurrence).

When calling $(D recurrence), the function that computes the next
value is specified as a template argument, and the initial values in
the recurrence are passed as regular arguments. For example, in a
Fibonacci sequence, there are two initial values (and therefore a
state size of 2) because computing the popFront Fibonacci value needs the
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
foreach (e; take(10, fib)) { writeln(e); }
// print the first 10 factorials
foreach (e; take(10, recurrence!("a[n-1] * n")(1))) { writeln(e); }
----
 */
struct Recurrence(alias fun, StateType, size_t stateSize)
{
    StateType[stateSize] _state;
    size_t _n;

    this(StateType[stateSize] initial) { _state = initial; }

    void popFront()
    {
        _state[_n % stateSize] = binaryFun!(fun, "a", "n")(
            cycle(_state, _n), _n);
        ++_n;
    }

    StateType front()
    {
        return _state[_n % stateSize];
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

version(none) unittest
{
    auto fib = recurrence!("a[n-1] + a[n-2]")(1, 1);
    int[] witness = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55 ];
    //foreach (e; take(10, fib)) writeln(e);
    assert(equal(take(10, fib), witness));
    foreach (e; take(10, fib)) {}//writeln(e);
    //writeln(s.front);
    auto fact = recurrence!("a[n - 1] * n")(1);
    foreach (e; take(10, fact)) {}//writeln(e);
    auto piapprox = recurrence!("a[n] + (n & 1 ? 4. : -4.) / (2 * n + 3)")(4.);
    foreach (e; take(20, piapprox)) {}//writeln(e);
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
    alias typeof(compute(State.init, 1u)) ElementType;
    State _state;
    size_t _n;
    ElementType _cache;

public:
    this(State initial, size_t n = 0)
    {
        this._state = initial;
        this._cache = compute(this._state, this._n);
    }
    
    ElementType front()
    {
        //return ElementType.init;
        return this._cache;
    }

    void popFront()
    {
        this._cache = compute(this._state, ++this._n);
    }

    ElementType opIndex(size_t n)
    {
        //return ElementType.init;
        return compute(this._state, n);
    }

     enum bool empty = false;
}

/// Ditto
Sequence!(fun, Tuple!(State)) sequence
    (alias fun, State...)(State args)
{
    return typeof(return)(tuple(args));
}

version(none) unittest
{
    // alias Sequence!("a.field[0] += a.field[1]",
    //         Tuple!(int, int)) Gen;
    // Gen x = Gen(tuple(0, 5));
    // foreach (e; take(15, x))
    // {}//writeln(e);

    auto y = Sequence!("a.field[0] + n * a.field[1]", Tuple!(int, int))
        (tuple(0, 4));
    //@@BUG
    //auto y = sequence!("a.field[0] + n * a.field[1]")(0, 4);
    //foreach (e; take(15, y))
    {}//writeln(e);
}

/**
Returns a range that goes through the numbers $(D begin), $(D begin +
step), $(D begin + 2 * step), $(D ...), up to and excluding $(D
end). The range offered is a random access range.

Example:
----
auto r = iota(0, 10, 1);
assert(equal(r, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9][]));
r = iota(0, 11, 3);
assert(equal(r, [0, 3, 6, 9][]));
assert(r[2] == 6);
----
 */
Take!(Sequence!("a.field[0] + n * a.field[1]",
                Tuple!(CommonType!(B, E), S)))
iota(B, E, S)(B begin, E end, S step)
{
    enforce(step != 0);
    alias Sequence!("a.field[0] + n * a.field[1]", Tuple!(B, S)) Seq;
    return take((end - begin + step - 1) / step, Seq(tuple(begin, step), 0u));
}

version(none) unittest
{
    auto r = iota(0, 10, 1);
    assert(equal(r, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9][]));
    r = iota(0, 11, 3);
    assert(equal(r, [0, 3, 6, 9][]));
    assert(r[2] == 6);

    int[] a = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    auto r1 = iota(a.ptr, a.ptr + a.length, 1);
    assert(r1.front == a.ptr);
    assert(r1.back == a.ptr + a.length);
}

/*
 *  Copyright (C) 2004-2009 by Digital Mars, www.digitalmars.com
 *  Written by Andrei Alexandrescu, www.erdani.org
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */
