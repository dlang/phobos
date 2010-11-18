// Written in the D programming language.

/**
Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)

         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.array;

import std.c.stdio;
import core.memory;
import std.algorithm, std.conv, std.encoding, std.exception, std.range,
    std.string, std.traits, std.typecons, std.utf;
private import std.c.string : memcpy;
private import std.intrinsic : bsr;
version(unittest) private import std.stdio;

/**
Returns a newly-allocated dynamic array consisting of a copy of the input
range, static array, dynamic array, or class or struct with an $(D opApply)
function $(D r).  Note that narrow strings are handled
as a special case in an overload.

Example:

----
auto a = array([1, 2, 3, 4, 5][]);
assert(a == [ 1, 2, 3, 4, 5 ]);
----
 */
ForeachType!Range[] array(Range)(Range r)
if (isIterable!Range && !isNarrowString!Range)
{
    alias ForeachType!Range E;
    static if (hasLength!Range)
    {
        if(r.length == 0) return null;

        // Determines whether the GC should scan the array.
        auto blkInfo = (typeid(E).flags & 1) ?
                       cast(GC.BlkAttr) 0 :
                       GC.BlkAttr.NO_SCAN;

        auto result = (cast(E*) enforce(GC.malloc(r.length * E.sizeof, blkInfo),
                text("Out of memory while allocating an array of ", r.length,
                        " objects of type ", E.stringof)))[0 .. r.length];
        size_t i = 0;
        foreach (e; r)
        {
            // hacky
            static if (is(typeof(e.opAssign(e))))
            {
                // this should be in-place construction
                auto voidArr = (cast(void*) (result.ptr + i))[0..E.sizeof];
                emplace!E(voidArr, e);
            }
            else
            {
                result[i] = e;
            }
            i++;
        }
        return result;
    }
    else
    {
        auto a = appender!(E[])();
        foreach (e; r)
        {
            a.put(e);
        }
        return a.data;
    }
    // // 2. Initialize the memory
    // size_t constructedElements = 0;
    // scope(failure)
    // {
    //     // Deconstruct only what was constructed
    //     foreach_reverse (i; 0 .. constructedElements)
    //     {
    //         try
    //         {
    //             //result[i].~E();
    //         }
    //         catch (Exception e)
    //         {
    //         }
    //     }
    //     // free the entire array
    //     std.gc.realloc(result, 0);
    // }
    // foreach (src; elements)
    // {
    //     static if (is(typeof(new(result + constructedElements) E(src))))
    //     {
    //         new(result + constructedElements) E(src);
    //     }
    //     else
    //     {
    //         result[constructedElements] = src;
    //     }
    //     ++constructedElements;
    // }
    // // 3. Success constructing all elements, type the array and return it
    // setTypeInfo(typeid(E), result);
    // return result[0 .. constructedElements];
}

/**
Convert a narrow string to an array type that fully supports random access.
This is handled as a special case and always returns a $(D dchar[]),
$(D const(dchar)[]), or $(D immutable(dchar)[]) depending on the constness of
the input.
*/
ElementType!String[] array(String)(String str) if(isNarrowString!String)
{
    static if(is(typeof(return) == immutable))
    {
        return to!(immutable(dchar)[])(str);
    }
    else static if(is(typeof(return) == const))
    {
        return to!(const(dchar)[])(str);
    }
    else
    {
        return to!(dchar[])(str);
    }
}

version(unittest)
{
    struct TestArray { int x; string toString() { return .to!string(x); } }

    struct OpAssign
    {
        uint num;
        this(uint num) { this.num = num; }

        // Templating opAssign to make sure the bugs with opAssign being
        // templated are fixed.
        void opAssign(T)(T rhs) { this.num = rhs.num; }
    }

    struct OpApply
    {
        int opApply(int delegate(ref int) dg)
        {
            int res;
            foreach(i; 0..10)
            {
                res = dg(i);
                if(res) break;
            }

            return res;
        }
    }
}

unittest
{
    auto a = array([1, 2, 3, 4, 5][]);
    //writeln(a);
    assert(a == [ 1, 2, 3, 4, 5 ]);

    auto b = array([TestArray(1), TestArray(2)][]);
    //writeln(b);

    class C
    {
        int x;
        this(int y) { x = y; }
        override string toString() { return .to!string(x); }
    }
    auto c = array([new C(1), new C(2)][]);
    //writeln(c);

    auto d = array([1., 2.2, 3][]);
    assert(is(typeof(d) == double[]));
    //writeln(d);

    auto e = [OpAssign(1), OpAssign(2)];
    auto f = array(e);
    assert(e == f);

    assert(array(OpApply.init) == [0,1,2,3,4,5,6,7,8,9]);
    assert(array("ABC") == "ABC"d);
    assert(array("ABC".dup) == "ABC"d.dup);
}

template IndexType(C : T[], T)
{
    alias size_t IndexType;
}

unittest
{
    static assert(is(IndexType!(double[]) == size_t));
    static assert(!is(IndexType!(double) == size_t));
}

/**
Implements the range interface primitive $(D empty) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.empty) is
equivalent to $(D empty(array)).

Example:
----
void main()
{
    auto a = [ 1, 2, 3 ];
    assert(!a.empty);
    assert(a[3 .. $].empty);
}
----
 */

@property bool empty(T)(in T[] a) @safe pure nothrow
{
    return !a.length;
}

unittest
{
    auto a = [ 1, 2, 3 ];
    assert(!a.empty);
    assert(a[3 .. $].empty);
}

/**
Implements the range interface primitive $(D save) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.save) is
equivalent to $(D save(array)).

Example:
----
void main()
{
    auto a = [ 1, 2, 3 ];
    auto b = a.save;
    assert(b is a);
}
----
 */

@property T[] save(T)(T[] a) @safe pure nothrow
{
    return a;
}

/**
Implements the range interface primitive $(D popFront) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.popFront) is
equivalent to $(D popFront(array)).


Example:
----
void main()
{
    int[] a = [ 1, 2, 3 ];
    a.popFront;
    assert(a == [ 2, 3 ]);
}
----
*/

void popFront(A)(ref A a)
if(!isNarrowString!A && isDynamicArray!A && isMutable!A && !is(A == void[]))
{
    alias typeof(A[0]) T;
    assert(a.length, "Attempting to popFront() past the end of an array of "
            ~ T.stringof);
    a = a[1 .. $];
}

unittest
{
    //@@@BUG 2608@@@
    //auto a = [ 1, 2, 3 ];
    int[] a = [ 1, 2, 3 ];
    a.popFront;
    assert(a == [ 2, 3 ]);

    static assert(!__traits(compiles, popFront!(immutable int[])));
}

void popFront(A)(ref A a)
if(isNarrowString!A && isMutable!A)
{
    alias typeof(a[0]) T;
    assert(a.length, "Attempting to popFront() past the end of an array of "
            ~ T.stringof);
    a = a[std.utf.stride(a, 0) .. $];
}

unittest
{
    string s1 = "\xC2\xA9hello";
    s1.popFront();
    assert(s1 == "hello");
    wstring s2 = "\xC2\xA9hello";
    s2.popFront();
    assert(s2 == "hello");
    string s3 = "\u20AC100";
    //write(s3, '\n');

    static assert(!__traits(compiles, popFront!(immutable string)));
}

/**
Implements the range interface primitive $(D popBack) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.popBack) is
equivalent to $(D popBack(array)).


Example:
----
void main()
{
    int[] a = [ 1, 2, 3 ];
    a.popBack;
    assert(a == [ 1, 2 ]);
}
----
*/

void popBack(A)(ref A a)
if(isDynamicArray!A && !isNarrowString!A && isMutable!A && !is(A == void[]))
{
    assert(a.length);
    a = a[0 .. $ - 1];
}

unittest
{
    //@@@BUG 2608@@@
    //auto a = [ 1, 2, 3 ];
    int[] a = [ 1, 2, 3 ];
    a.popBack;
    assert(a == [ 1, 2 ]);

    static assert(!__traits(compiles, popBack!(immutable int[])));
}

void popBack(A)(ref A a)
if(is(A : const(char)[]) && isMutable!A)
{
    immutable n = a.length;
    const p = a.ptr + n;
    if (n >= 1 && (p[-1] & 0b1100_0000) != 0b1000_0000)
    {
        a = a[0 .. n - 1];
    }
    else if (n >= 2 && (p[-2] & 0b1100_0000) != 0b1000_0000)
    {
        a = a[0 .. n - 2];
    }
    else if (n >= 3 && (p[-3] & 0b1100_0000) != 0b1000_0000)
    {
        a = a[0 .. n - 3];
    }
    else if (n >= 4 && (p[-4] & 0b1100_0000) != 0b1000_0000)
    {
        a = a[0 .. n - 4];
    }
    else
    {
        assert(false, "Invalid UTF character at end of string");
    }
}

unittest
{
    string s = "hello\xE2\x89\xA0";
    s.popBack();
    assert(s == "hello", s);

    string s3 = "\xE2\x89\xA0";
    auto c = s3.back;
    assert(c == cast(dchar)'\u2260');
    s3.popBack();
    assert(s3 == "");

    static assert(!__traits(compiles, popBack!(immutable char[])));
}

void popBack(A)(ref A a)
if(is(A : const(wchar)[]) && isMutable!A)
{
    assert(a.length);
    if (a.length == 1)
    {
        a = a[0 .. 0];
        return;
    }
    immutable c = a[$ - 2];
    a = a[0 .. $ - 1 - (c >= 0xD800 && c <= 0xDBFF)];
}

unittest
{
    wstring s = "hello\xE2\x89\xA0";
    s.popBack();
    assert(s == "hello");

    static assert(!__traits(compiles, popBack!(immutable wchar[])));
}

/**
Implements the range interface primitive $(D front) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.front) is
equivalent to $(D front(array)).


Example:
----
void main()
{
    int[] a = [ 1, 2, 3 ];
    assert(a.front == 1);
}
----
*/
ref typeof(A[0]) front(A)(A a)
if (is(typeof(A[0])) && !isNarrowString!A && !is(typeof(A[0]) : const(void)))
{
    assert(a.length, "Attempting to fetch the front of an empty array");
    return a[0];
}

dchar front(A)(A a) if (is(typeof(A[0])) && isNarrowString!A)
{
    assert(a.length, "Attempting to fetch the front of an empty array");
    size_t i = 0;
    return decode(a, i);
}

/// Ditto
void front(T)(T[] a, T v) if (!isNarrowString!A)
{
    assert(a.length); a[0] = v;
}

/**
Implements the range interface primitive $(D back) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.back) is
equivalent to $(D back(array)).

Example:
----
void main()
{
    int[] a = [ 1, 2, 3 ];
    assert(a.back == 3);
}
----
*/
ref typeof(A.init[0]) back(A)(A a)
if (is(typeof(A.init[0])) && !isNarrowString!A
    && !is(typeof(A.init[0]) : const(void)))
{
    // @@@BUG@@@ The assert below crashes the unittest due to a bug in
    //   the compiler
    version (bug4426)
    {
        assert(a.length, "Attempting to fetch the back of an empty array");
    }
    else
    {
        assert(a.length);
    }
    return a[$ - 1];
}

unittest
{
    int[] a = [ 1, 2, 3 ];
    assert(a.back == 3);
    a.back += 4;
    assert(a.back == 7);
}

dchar back(A)(A a)
if (is(typeof(A.init[0])) && isNarrowString!A && a[0].sizeof < 4)
{
    assert(a.length, "Attempting to fetch the back of an empty array");
    auto n = a.length;
    const p = a.ptr + n;
    if (n >= 1 && (p[-1] & 0b1100_0000) != 0b1000_0000)
    {
        --n;
        return std.utf.decode(a, n);
    }
    else if (n >= 2 && (p[-2] & 0b1100_0000) != 0b1000_0000)
    {
        n -= 2;
        return decode(a, n);
    }
    else if (n >= 3 && (p[-3] & 0b1100_0000) != 0b1000_0000)
    {
        n -= 3;
        return decode(a, n);
    }
    else if (n >= 4 && (p[-4] & 0b1100_0000) != 0b1000_0000)
    {
        n -= 4;
        return decode(a, n);
    }
    else
    {
        throw new UtfException("Invalid UTF character at end of string");
    }
}

// overlap
/*
Returns the overlapping portion, if any, of two arrays. Unlike $(D
equal), $(D overlap) only compares the pointers in the ranges, not the
values referred by them. If $(D r1) and $(D r2) have an overlapping
slice, returns that slice. Otherwise, returns the null slice.

Example:
----
int[] a = [ 10, 11, 12, 13, 14 ];
int[] b = a[1 .. 3];
assert(overlap(a, b) == [ 11, 12 ]);
b = b.dup;
// overlap disappears even though the content is the same
assert(overlap(a, b).empty);
----
*/
T[] overlap(T)(T[] r1, T[] r2) @trusted pure nothrow
{
    T* max(T* a, T* b) nothrow { return a > b ? a : b; }
    T* min(T* a, T* b) nothrow { return a < b ? a : b; }
    auto b = max(r1.ptr, r2.ptr);
    auto e = min(r1.ptr + r1.length, r2.ptr + r2.length);
    return b < e ? b[0 .. e - b] : null;
}

unittest
{
    int[] a = [ 10, 11, 12, 13, 14 ];
    int[] b = a[1 .. 3];
    a[1] = 100;
    assert(overlap(a, b) == [ 100, 12 ]);

    assert(overlap(a, a[0 .. 2]) is a[0 .. 2]);
    assert(overlap(a, a[3 .. 5]) is a[3 .. 5]);
    assert(overlap(a[0 .. 2], a) is a[0 .. 2]);
    assert(overlap(a[3 .. 5], a) is a[3 .. 5]);

    assert(overlap(a, b.dup).empty);
}

/**
Inserts $(D stuff) in $(D container) at position $(D pos).
 */
void insert(T, Range)(ref T[] array, size_t pos, Range stuff)
{
    static if (is(typeof(stuff[0])))
    {
        // presumably an array
        alias stuff toInsert;
        //assert(!overlap(array, toInsert));
    }
    else
    {
        // presumably only one element
        auto toInsert = (&stuff)[0 .. 1];
    }

    // @@@BUG 2130@@@
    // immutable
    //     size_t delta = toInsert.length,
    //     size_t oldLength = array.length,
    //     size_t newLength = oldLength + delta;
    immutable
        delta = toInsert.length,
        oldLength = array.length,
        newLength = oldLength + delta;

    // Reallocate the array to make space for new content
    array = (cast(T*) core.memory.GC.realloc(array.ptr,
                    newLength * array[0].sizeof))[0 .. newLength];
    assert(array.length == newLength);

    // Move data in pos .. pos + stuff.length to the end of the array
    foreach_reverse (i; pos .. oldLength)
    {
        // This will be guaranteed to not throw
        move(array[i], array[i + delta]);
    }

    // Copy stuff into array
    foreach (e; toInsert)
    {
        array[pos++] = e;
    }
}

unittest
{
    int[] a = ([1, 4, 5]).dup;
    insert(a, 1u, [2, 3]);
    assert(a == [1, 2, 3, 4, 5]);
    insert(a, 1u, 99);
    assert(a == [1, 99, 2, 3, 4, 5]);
}

// @@@ TODO: document this
bool sameHead(T)(in T[] lhs, in T[] rhs)
{
    return lhs.ptr == rhs.ptr;
}

/**
Erases elements from $(D array) with indices ranging from $(D from)
(inclusive) to $(D to) (exclusive).
 */
// void erase(T)(ref T[] array, size_t from, size_t to)
// {
//     immutable newLength = array.length - (to - from);
//     foreach (i; to .. array.length)
//     {
//         move(array[i], array[from++]);
//     }
//     array.length = newLength;
// }

// unittest
// {
//     int[] a = [1, 2, 3, 4, 5];
//     erase(a, 1u, 3u);
//     assert(a == [1, 4, 5]);
// }

/**
Erases element from $(D array) at index $(D from).
 */
// void erase(T)(ref T[] array, size_t from)
// {
//     erase(array, from, from + 1);
// }

// unittest
// {
//     int[] a = [1, 2, 3, 4, 5];
//     erase(a, 2u);
//     assert(a == [1, 2, 4, 5]);
// }

/**
Replaces elements from $(D array) with indices ranging from $(D from)
(inclusive) to $(D to) (exclusive) with the range $(D stuff). Expands
or shrinks the array as needed.
 */
void replace(T, Range)(ref T[] array, size_t from, size_t to, Range stuff)
    if (is(ElementType!Range == T))
{
    // container = container[0 .. from] ~ stuff ~ container[to .. $];
    if (overlap(array, stuff))
    {
        // use slower/conservative method
        array = array[0 .. from] ~ stuff ~ array[to .. $];
    }
    else if (stuff.length <= to - from)
    {
        // replacement reduces length
        // BUG 2128
        //immutable stuffEnd = from + stuff.length;
        auto stuffEnd = from + stuff.length;
        array[from .. stuffEnd] = stuff;
        array = remove(array, tuple(stuffEnd, to));
    }
    else
    {
        // replacement increases length
        // @@@TODO@@@: optimize this
        immutable replaceLen = to - from;
        array[from .. to] = stuff[0 .. replaceLen];
        insert(array, to, stuff[replaceLen .. $]);
    }
}


void replace(T, Range)(ref T[] array, size_t from, size_t to, Range stuff)
    if (!is(ElementType!Range == T) && is(Unqual!Range == void*))
{
    replace(array, from, to, cast(T[])[]);
}



unittest
{
    int[] a = [1, 4, 5];
    replace(a, 1u, 2u, [2, 3, 4]);
    assert(a == [1, 2, 3, 4, 5]);
    replace(a, 1u, 2u, cast(int[])[]);
    assert(a == [1, 3, 4, 5]);
    replace(a, 1u, 2u, null);
    assert(a == [1, 4, 5]);
}

/**
Implements an output range that appends data to an array. This is
recommended over $(D a ~= data) when appending many elements because it is more
efficient.

Example:
----
auto app = appender!string();
string b = "abcdefg";
foreach (char c; b) app.put(c);
assert(app.data == "abcdefg");

int[] a = [ 1, 2 ];
auto app2 = appender(a);
app2.put(3);
app2.put([ 4, 5, 6 ]);
assert(app2.data == [ 1, 2, 3, 4, 5, 6 ]);
----
 */

struct Appender(A : T[], T)
{
    private struct Data
    {
        size_t capacity;
        Unqual!(T)[] arr;
    }

    private Data* _data;

/**
Construct an appender with a given array.  Note that this does not copy the
data.  If the array has a larger capacity as determined by arr.capacity,
it will be used by the appender.  After initializing an appender on an array,
appending to the original array will reallocate.
*/
    this(T[] arr)
    {
        // initialize to a given array.
        _data = new Data;
        _data.arr = cast(Unqual!(T)[])arr;

        // We want to use up as much of the block the array is in as possible.
        // if we consume all the block that we can, then array appending is
        // safe WRT built-in append, and we can use the entire block.
        auto cap = arr.capacity;
        if(cap > arr.length)
            arr.length = cap;
        // we assume no reallocation occurred
        assert(arr.ptr is _data.arr.ptr);
        _data.capacity = arr.length;
    }

/**
Reserve at least newCapacity elements for appending.  Note that more elements
may be reserved than requested.  If newCapacity < capacity, then nothing is
done.
*/
    void reserve(size_t newCapacity)
    {
        if(!_data)
            _data = new Data;
        if(_data.capacity < newCapacity)
        {
            // need to increase capacity
            auto bi = GC.qalloc(newCapacity * T.sizeof, (typeid(T[]).next.flags & 1) ? 0 : GC.BlkAttr.NO_SCAN);
            _data.capacity = bi.size / T.sizeof;
            if(_data.arr.length)
                memcpy(bi.base, _data.arr.ptr, _data.arr.length * T.sizeof);
            _data.arr = (cast(Unqual!(T)*)bi.base)[0.._data.arr.length];
        }
    }

/**
Returns the capacity of the array (the maximum number of elements the
managed array can accommodate before triggering a reallocation).  If any
appending will reallocate, capacity returns 0.
 */
    @property size_t capacity()
    {
        return _data ? _data.capacity : 0;
    }

/**
Returns the managed array.
 */
    @property T[] data()
    {
        return cast(typeof(return))(_data ? _data.arr : null);
    }

/**
Appends one item to the managed array.
 */
    void put(U)(U item) if (isImplicitlyConvertible!(U, T) ||
            isSomeChar!T && isSomeChar!U)
    {
        static if (isSomeChar!T && isSomeChar!U && T.sizeof < U.sizeof)
        {
            // must do some transcoding around here
            Unqual!T[T.sizeof == 1 ? 4 : 2] encoded;
            auto len = std.utf.encode(encoded, item);
            put(encoded[0 .. len]);
        }
        else
        {
            if (!_data)
                _data = new Data;
            immutable len = _data.arr.length;
            if (len >= _data.capacity)
            {
                // Time to reallocate.
                // We need to almost duplicate what's in druntime, except we
                // have better access to the capacity field.
                auto newlen = newCapacity(len + 1);
                // first, try extending the current block
                auto u = GC.extend(_data.arr.ptr, T.sizeof, (newlen - len) * T.sizeof);
                if(u)
                {
                    // extend worked, update the capacity
                    _data.capacity = u / T.sizeof;
                    _data.arr = _data.arr.ptr[0..len + 1];
                }
                else
                {
                    // didn't work, must reallocate
                    auto bi = GC.qalloc(newlen * T.sizeof, (typeid(T[]).next.flags & 1) ? 0 : GC.BlkAttr.NO_SCAN);
                    _data.capacity = bi.size / T.sizeof;
                    if(len)
                        memcpy(bi.base, _data.arr.ptr, len * T.sizeof);
                    _data.arr = (cast(Unqual!(T)*)bi.base)[0..len + 1];
                    // leave the old data, for safety reasons
                }
            }
            else
            {
                _data.arr = _data.arr.ptr[0 .. len + 1];
            }
            _data.arr.ptr[len] = cast(Unqual!T)item;
        }
    }

    private static size_t newCapacity(size_t newlength)
    {
        long mult = 100 + (1000L) / (bsr(newlength * T.sizeof) + 1);
        // limit to doubling the length, we don't want to grow too much
        if(mult > 200)
            mult = 200;
        auto newext = cast(size_t)((newlength * mult + 99) / 100);
        return newext > newlength ? newext : newlength;
    }

    // Const fixing hack.
    void put(Range)(Range items)
    if(isInputRange!(Unqual!Range) && !isInputRange!Range) {
        alias put!(Unqual!Range) p;
        p(items);
    }

/**
Appends an entire range to the managed array.
 */
    void put(Range)(Range items) if (isInputRange!Range
            && is(typeof(Appender.init.put(items.front))))
    {
        // note, we disable this branch for appending one type of char to
        // another because we can't trust the length portion.
        static if (!(isSomeChar!T && isSomeChar!(ElementType!Range) &&
                     !is(Range == Unqual!(T)[])) &&
                   is(typeof(items.length) == size_t))
        {
            // make sure we have enough space, then add the items
            immutable len = _data ? _data.arr.length : 0;
            immutable newlen = len + items.length;
            reserve(newlen);
            _data.arr = _data.arr.ptr[0..newlen];
            static if(is(typeof(_data.arr[] = items)))
            {
                _data.arr.ptr[len..newlen] = items;
            }
            else
            {
                for(size_t i = len; !items.empty; items.popFront(), ++i)
                    _data.arr.ptr[i] = items.front;
            }
        }
        else
        {
            //pragma(msg, Range.stringof);
            // Generic input range
            for (; !items.empty; items.popFront())
            {
                put(items.front);
            }
        }
    }

    // only allow overwriting data on non-immutable and non-const data
    static if(!is(T == immutable) && !is(T == const))
    {
/**
Clears the managed array.
*/
        void clear()
        {
            if (_data)
            {
                _data.arr = _data.arr.ptr[0..0];
            }
        }

/**
Shrinks the managed array to the given length.  Passing in a length that's
greater than the current array length throws an enforce exception.
*/
        void shrinkTo(size_t newlength)
        {
            if(_data)
            {
                enforce(newlength <= _data.arr.length);
                _data.arr = _data.arr.ptr[0..newlength];
            }
            else
                enforce(newlength == 0);
        }
    }
}

/**
An appender that can update an array in-place.  It forwards all calls to an
underlying appender implementation.  Any calls made to the appender also update
the pointer to the original array passed in.
*/
struct RefAppender(A : T[], T)
{
    private
    {
        Appender!(A, T) impl;
        T[] *arr;
    }

/**
Construct a ref appender with a given array reference.  This does not copy the
data.  If the array has a larger capacity as determined by arr.capacity, it
will be used by the appender.  $(D RefAppender) assumes that arr is a non-null value.

Note, do not use builtin appending (i.e. ~=) on the original array passed in
until you are done with the appender, because calls to the appender override
those appends.
*/
    this(T[] *arr)
    {
        impl = Appender!(A, T)(*arr);
        this.arr = arr;
    }

    auto opDispatch(string fn, Args...)(Args args) if (is(typeof(mixin("impl." ~ fn ~ "(args)"))))
    {
        // we do it this way because we can't cache a void return
        scope(exit) *this.arr = impl.data;
        mixin("return impl." ~ fn ~ "(args);");
    }

/**
Returns the capacity of the array (the maximum number of elements the
managed array can accommodate before triggering a reallocation).  If any
appending will reallocate, capacity returns 0.
 */
    @property size_t capacity()
    {
        return impl.capacity;
    }

/**
Returns the managed array.
 */
    @property T[] data()
    {
        return impl.data;
    }
}

/**
Convenience function that returns an $(D Appender!(A)) object
initialized with $(D array).
 */
Appender!(E[]) appender(A : E[], E)(A array = null)
{
    return Appender!(E[])(array);
}

unittest
{
    auto app = appender!(char[])();
    string b = "abcdefg";
    foreach (char c; b) app.put(c);
    assert(app.data == "abcdefg");

    int[] a = [ 1, 2 ];
    auto app2 = appender(a);
    assert(app2.data == [ 1, 2 ]);
    app2.put(3);
    app2.put([ 4, 5, 6 ][]);
    assert(app2.data == [ 1, 2, 3, 4, 5, 6 ]);
}

/**
Convenience function that returns a $(D RefAppender!(A)) object
initialized with $(D array).  Don't use null for the array pointer, use the
other version of appender instead.
 */
RefAppender!(E[]) appender(A : E[]*, E)(A array)
{
    return RefAppender!(E[])(array);
}

unittest
{
    auto arr = new char[0];
    auto app = appender(&arr);
    string b = "abcdefg";
    foreach (char c; b) app.put(c);
    assert(app.data == "abcdefg");
    assert(arr == "abcdefg");

    int[] a = [ 1, 2 ];
    auto app2 = appender(&a);
    assert(app2.data == [ 1, 2 ]);
    assert(a == [ 1, 2 ]);
    app2.put(3);
    app2.put([ 4, 5, 6 ][]);
    assert(app2.data == [ 1, 2, 3, 4, 5, 6 ]);
    assert(a == [ 1, 2, 3, 4, 5, 6 ]);
}

/*
A simple slice type only holding pointers to the beginning and the end
of an array. Experimental duplication of the built-in slice - do not
use yet.
 */
struct SimpleSlice(T)
{
    private T * _b, _e;

    this(U...)(U values)
    {
        _b = cast(T*) core.memory.GC.malloc(U.length * T.sizeof);
        _e = _b + U.length;
        foreach (i, Unused; U) _b[i] = values[i];
    }

    void opAssign(R)(R anotherSlice)
    {
        static if (is(typeof(*_b = anotherSlice)))
        {
            // assign all elements to a value
            foreach (p; _b .. _e)
            {
                *p = anotherSlice;
            }
        }
        else
        {
            // assign another slice to this
            enforce(anotherSlice.length == length);
            auto p = _b;
            foreach (p; _b .. _e)
            {
                *p = anotherSlice.front;
                anotherSlice.popFront;
            }
        }
    }

/**
   Range primitives.
 */
    bool empty() const
    {
        assert(_b <= _e);
        return _b == _e;
    }

/// Ditto
    ref T front()
    {
        assert(!empty);
        return *_b;
    }

/// Ditto
    void popFront()
    {
        assert(!empty);
        ++_b;
    }

/// Ditto
    ref T back()
    {
        assert(!empty);
        return _e[-1];
    }

/// Ditto
    void popBack()
    {
        assert(!empty);
        --_e;
    }

/// Ditto
    T opIndex(size_t n)
    {
        assert(n < length);
        return _b[n];
    }

/// Ditto
    const(T) opIndex(size_t n) const
    {
        assert(n < length);
        return _b[n];
    }

/// Ditto
    void opIndexAssign(T value, size_t n)
    {
        assert(n < length);
        _b[n] = value;
    }

/// Ditto
    SimpleSliceLvalue!T opSlice()
    {
        typeof(return) result = void;
        result._b = _b;
        result._e = _e;
        return result;
    }

/// Ditto
    SimpleSliceLvalue!T opSlice(size_t x, size_t y)
    {
        enforce(x <= y && y <= length);
        typeof(return) result = { _b + x, _b + y };
        return result;
    }

    @property
    {
        /// Returns the length of the slice.
        size_t length() const
        {
            return _e - _b;
        }

        /**
        Sets the length of the slice. Newly added elements will be filled with
        $(D T.init).
         */
        void length(size_t newLength)
        {
            immutable oldLength = length;
            _b = cast(T*) core.memory.GC.realloc(_b, newLength * T.sizeof);
            _e = _b + newLength;
            this[oldLength .. $] = T.init;
        }
    }

/// Concatenation.
    SimpleSlice opCat(R)(R another)
    {
        immutable newLen = length + another.length;
        typeof(return) result = void;
        result._b = cast(T*)
            core.memory.GC.malloc(newLen * T.sizeof);
        result._e = result._b + newLen;
        result[0 .. this.length] = this;
        result[this.length .. result.length] = another;
        return result;
    }

/// Concatenation with rebinding.
    void opCatAssign(R)(R another)
    {
        auto newThis = this ~ another;
        move(newThis, this);
    }
}

// Support for mass assignment
struct SimpleSliceLvalue(T)
{
    private SimpleSlice!T _s;
    alias _s this;

    void opAssign(R)(R anotherSlice)
    {
        static if (is(typeof(*_b = anotherSlice)))
        {
            // assign all elements to a value
            foreach (p; _b .. _e)
            {
                *p = anotherSlice;
            }
        }
        else
        {
            // assign another slice to this
            enforce(anotherSlice.length == length);
            auto p = _b;
            foreach (p; _b .. _e)
            {
                *p = anotherSlice.front;
                anotherSlice.popFront;
            }
        }
    }
}

unittest
{
    // SimpleSlice!(int) s;

    // s = SimpleSlice!(int)(4, 5, 6);
    // assert(equal(s, [4, 5, 6][]));
    // assert(s.length == 3);
    // assert(s[0] == 4);
    // assert(s[1] == 5);
    // assert(s[2] == 6);

    // assert(s[] == s);
    // assert(s[0 .. s.length] == s);
    // assert(equal(s[0 .. s.length - 1], [4, 5][]));

    // auto s1 = s ~ s[0 .. 1];
    // assert(equal(s1, [4, 5, 6, 4][]));

    // assert(s1[3] == 4);
    // s1[3] = 42;
    // assert(s1[3] == 42);

    // const s2 = s;
    // assert(s2.length == 3);
    // assert(!s2.empty);
    // assert(s2[0] == s[0]);

    // s[0 .. 2] = 10;
    // assert(equal(s, [10, 10, 6][]));

    // s ~= [ 5, 9 ][];
    // assert(equal(s, [10, 10, 6, 5, 9][]));

    // s.length = 7;
    // assert(equal(s, [10, 10, 6, 5, 9, 0, 0][]));
}
